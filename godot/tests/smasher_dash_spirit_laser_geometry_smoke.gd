extends SceneTree

# 잔영호법(dash_spirit) 레이저 회귀 씰.
#   1) Y 앵커: 원본은 바닥에서 24px 떠 있는 패들 기준(`PLAYER.centery + 30`)이라
#      레이저가 바닥선 위에 놓이지만, Godot 패들은 바닥에 딱 붙으므로 같은 +30을
#      쓰면 레이저 전체가 플레이필드 바닥선 아래로 깔린다.
#   2) 실루엣: 원본은 "매우 얇고 긴 타원형"(글로우 5겹 + 메인 + 양 끝 10px 인셋
#      코어)이다. draw_line 기반 직각 캡 막대로 되돌아가면 코어 인셋과 글로우
#      사다리가 사라지므로 레이어 계약으로 봉인한다.

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const SmasherDashSpiritState := preload("res://scripts/characters/smasher_dash_spirit_state.gd")
const SmasherDashSpiritRenderer := preload("res://scripts/characters/smasher_dash_spirit_renderer.gd")
const VaporParticleTextureCache := preload("res://scripts/effects/vapor_particle_texture_cache.gd")

const VIEW_SIZE := Vector2i(760, 750)

# 원본 `ui/hud_display.py draw_dash_spirit_lasers()` 리터럴. 검증 대상 모듈의
# 상수를 되읽으면 항진식이 되므로(상수를 바꾸면 기대값도 같이 바뀜) 여기서는
# 파이썬 원본 숫자를 그대로 박아둔다.
const ORIGIN_GLOW_LAYERS := 5
const ORIGIN_MAIN_HALF_HEIGHT := 5.0
const ORIGIN_CORE_HALF_HEIGHT := 3.0
const ORIGIN_CORE_END_INSET := 10.0
const ORIGIN_MAX_GLOW_HALF_HEIGHT := 15.0  # ellipse_height(5) + i(5) * 2

# 원본 절대 Y(챔피언). `_compute_player_floor_bottom()`이 확대 시
# `PLAYER_VISUAL_OVERHANG(25) * (scale-1)`만큼 바닥선을 같이 내리고 오버행 25가
# 기본 패들 반높이와 같아서 `PLAYER.centery`가 701로 고정된다 → 레이저는
# `701 + 30 = 731`, 즉 플레이필드 바닥(750)에서 19px 위에 스케일 불변으로 놓인다.
const ORIGIN_ABSOLUTE_LASER_Y := 731.0
const ORIGIN_FLOOR_INSET := 19.0

var _failures: Array[String] = []
var _probe: DashSpiritLaserProbe = null
var _frame_count := 0


class GuaranteedDashSpiritPerkState:
	extends RefCounted

	var star_level := 1

	func _init(configured_star_level: int = 1) -> void:
		star_level = configured_star_level

	func get_runtime_skill_bonus(_perk_id: String) -> float:
		return 1.0

	func get_runtime_skill_level(_perk_id: String) -> int:
		return star_level


class DashSpiritLaserProbe:
	extends Node2D

	var state: Object = null
	var particle_state: Object = null
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		if state != null:
			state.draw(self, Vector2.ZERO)
		# 증발 파티클 드로우 경로도 같은 `_draw()`로 관통시킨다.
		if particle_state != null:
			particle_state.draw(self, Vector2.ZERO)


func _init() -> void:
	get_root().size = VIEW_SIZE
	# 패들 스케일 레그. 원본 바닥선이 오버행만큼 같이 내려가 centery가 701로
	# 고정되므로, 원본 레이저 절대 Y는 스케일과 무관하게 챔피언 기준 731이다.
	# 중심 기준 오프셋으로 앵커하면 확대 패들에서만 위로 뜬다(주니어 -14px /
	# 벌크업 -5px) — 기본 155x50 레그만으로는 못 잡으므로 3레그로 봉인한다.
	var base_state: RefCounted = null
	for leg: Array in [
		["챔피언 기본 1.0배", 1.0],
		["주니어 리그 1.5배", 1.5],
		["벌크업 1.2배", 1.2],
	]:
		var state: RefCounted = _verify_laser_anchor(str(leg[0]), float(leg[1]))
		if base_state == null:
			base_state = state
	if base_state == null:
		_finish()
		return

	_verify_half_dash_never_spawns()
	_verify_length_matches_dash_frames()
	_verify_duration_scales_by_star()
	var particle_state: RefCounted = _verify_evaporation_particles()

	_probe = DashSpiritLaserProbe.new()
	_probe.name = "DashSpiritLaserProbe"
	_probe.state = base_state
	_probe.particle_state = particle_state
	get_root().add_child(_probe)
	# 렌더러가 실제로 밴드 텍스처를 소비하는지 봉인한다. 알파 프로파일만 보면
	# 렌더러가 그 텍스처를 안 쓰고 원 3겹으로 되돌아가도 GREEN이 된다.
	VaporParticleTextureCache.reset_for_test()
	_probe.queue_redraw()


func _verify_laser_anchor(leg_name: String, paddle_scale: float) -> RefCounted:
	var state: RefCounted = SmasherDashSpiritState.new()
	var paddle_size := Vector2(
		BattleSceneConfig.PADDLE_WIDTH * paddle_scale,
		BattleSceneConfig.PADDLE_HEIGHT * paddle_scale
	)
	# 실제 런타임 기하: 패들 크기가 바뀔 때마다 `player_pos.y = 750 - height`로
	# 하단이 바닥에 재앵커된다 (battle_scene_bootstrap / player_control_config_builder).
	var player_pos := Vector2(
		BattleSceneConfig.WIDTH * 0.5 - paddle_size.x * 0.5,
		BattleSceneConfig.HEIGHT - paddle_size.y
	)
	_expect(
		state.try_spawn_from_dash(1.0, false, player_pos, paddle_size, {"runtime_perk_state": GuaranteedDashSpiritPerkState.new()}, 15.0, 1.0),
		"[%s] 확률 100%% 픽스처에서 잔영호법 레이저가 생성돼야 한다" % leg_name
	)
	if state.lasers.is_empty():
		return null

	var laser: Dictionary = state.lasers[0] as Dictionary
	var start: Vector2 = laser.get("start", Vector2.ZERO) as Vector2
	var end: Vector2 = laser.get("end", Vector2.ZERO) as Vector2
	var half_length: float = absf(end.x - start.x) * 0.5
	_expect(is_equal_approx(start.y, end.y), "[%s] 레이저는 수평이어야 한다 (start.y == end.y)" % leg_name)
	_expect(
		is_equal_approx(half_length * 2.0, 210.0),
		"[%s] 풀대쉬 레이저 길이는 패들 크기와 무관하게 210px여야 한다 (got %.1f)" % [leg_name, half_length * 2.0]
	)

	# 원본 절대 위치 파리티(챔피언 기준): 바닥선 750 - 19 = 731. 스케일 불변.
	_expect(
		is_equal_approx(start.y, ORIGIN_ABSOLUTE_LASER_Y),
		"[%s] 레이저 Y는 원본 절대 위치(%.1f)와 일치해야 한다 (got %.1f)" % [leg_name, ORIGIN_ABSOLUTE_LASER_Y, start.y]
	)
	# 패들 하단 기준 앵커임을 직접 못박는다(중심 기준으로 되돌리면 확대 레그에서 깨짐).
	_expect(
		is_equal_approx(start.y, player_pos.y + paddle_size.y - ORIGIN_FLOOR_INSET),
		"[%s] 레이저는 패들 하단에서 %.0fpx 위에 앵커돼야 한다 (got %.1f)" % [leg_name, ORIGIN_FLOOR_INSET, start.y]
	)

	# 아래는 사용자가 신고한 실제 증상(바닥 아래로 깔림)을 결과로 단언한다.
	var layers: Array[Dictionary] = state.renderer.build_laser_layers(half_length, 1.0)
	var max_half_height: float = 0.0
	for layer in layers:
		max_half_height = maxf(max_half_height, float(layer.get("half_height", 0.0)))
	_expect(
		start.y + max_half_height <= BattleSceneConfig.HEIGHT,
		"[%s] 레이저 최외곽 글로우까지 플레이필드 바닥선(%.0f) 위에 있어야 한다 (bottom=%.1f)" % [leg_name, BattleSceneConfig.HEIGHT, start.y + max_half_height]
	)
	_expect(
		start.y > player_pos.y,
		"[%s] 레이저는 패들 상단보다 아래(패들 뒤쪽)에 있어야 한다" % leg_name
	)

	_verify_ellipse_layer_contract(half_length)
	return state


func _process(_delta: float) -> bool:
	_frame_count += 1
	if _frame_count < 3:
		return false
	_expect(_probe != null and _probe.draw_count > 0, "트리 부착 CanvasItem._draw()로 실제 렌더러가 관통돼야 한다")
	_expect(
		VaporParticleTextureCache.is_built(),
		"실 드로우 경로가 사전-합성 밴드 텍스처를 소비해야 한다 (원 3겹 누적 합성으로 되돌아가면 미소비)"
	)
	_finish()
	return true


# 원본은 하프대쉬 경로에 `create_dash_spirit_laser` 호출 자체가 없다.
# Godot은 공통 `_start_dash`에서 생성하므로 상태 쪽에서 끊어야 한다.
func _verify_half_dash_never_spawns() -> void:
	var state: RefCounted = SmasherDashSpiritState.new()
	var spawned: bool = state.try_spawn_from_dash(
		1.0,
		true,
		Vector2(302.5, 700.0),
		Vector2(155.0, 50.0),
		{"runtime_perk_state": GuaranteedDashSpiritPerkState.new()},
		11.0,
		1.0
	)
	_expect(not spawned, "하프대쉬는 확률 100%여도 잔영호법을 생성하지 않아야 한다 (원본에 호출 없음)")
	_expect(state.lasers.is_empty(), "하프대쉬 후 레이저 리스트가 비어 있어야 한다 (got %d)" % state.lasers.size())


# 원본은 `int(rolling_timer)`으로 지속프레임을 먼저 정수화한 뒤 `× 14`를 쓴다.
# Godot 지속프레임은 실수(비천보 Lv.5 = 15 × 1.35 = 20.25)라 정수화를 빠뜨리면
# 원본보다 1~3px 길어진다.
func _verify_length_matches_dash_frames() -> void:
	for leg: Array in [
		["기본 15f", 15.0, 210.0],
		["비천보 Lv.1 16.05f", 16.05, 224.0],
		["비천보 Lv.5 20.25f", 20.25, 280.0],
	]:
		var state: RefCounted = SmasherDashSpiritState.new()
		var spawned: bool = state.try_spawn_from_dash(
			1.0,
			false,
			Vector2(302.5, 700.0),
			Vector2(155.0, 50.0),
			{"runtime_perk_state": GuaranteedDashSpiritPerkState.new()},
			float(leg[1]),
			1.0
		)
		if not spawned or state.lasers.is_empty():
			_expect(false, "[%s] 풀대쉬 레이저가 생성돼야 한다" % str(leg[0]))
			continue
		var laser: Dictionary = state.lasers[0] as Dictionary
		var length: float = absf((laser.get("end", Vector2.ZERO) as Vector2).x - (laser.get("start", Vector2.ZERO) as Vector2).x)
		_expect(
			is_equal_approx(length, float(leg[2])),
			"[%s] 레이저 길이는 원본 `int(frames) × 14` = %.0fpx여야 한다 (got %.1f)" % [str(leg[0]), float(leg[2]), length]
		)


func _verify_duration_scales_by_star() -> void:
	const BASE_DURATION := 360.0
	var measured_durations: Array[float] = []
	for leg: Array in [
		[1, 1.0],
		[2, 1.2],
		[3, 1.4],
	]:
		var star_level := int(leg[0])
		var expected_ratio := float(leg[1])
		var state: RefCounted = SmasherDashSpiritState.new()
		var spawned: bool = state.try_spawn_from_dash(
			1.0,
			false,
			Vector2(302.5, 700.0),
			Vector2(155.0, 50.0),
			{"runtime_perk_state": GuaranteedDashSpiritPerkState.new(star_level)},
			15.0,
			1.0
		)
		if not spawned or state.lasers.is_empty():
			_expect(false, "[%d성] 지속시간 검증용 레이저가 생성돼야 한다" % star_level)
			continue
		var laser: Dictionary = state.lasers[0] as Dictionary
		var duration := float(laser.get("duration", 0.0))
		measured_durations.append(duration)
		_expect(
			is_equal_approx(duration / BASE_DURATION, expected_ratio),
			"[%d성] 지속시간은 기본값의 ×%.1f여야 한다 (got %.3f)" % [star_level, expected_ratio, duration / BASE_DURATION]
		)
		_expect(
			is_equal_approx(float(laser.get("remaining_time", 0.0)), duration),
			"[%d성] 생성 시 단일 남은시간 키가 전체 지속시간과 같아야 한다" % star_level
		)
		state.update_effects(1.0)
		laser = state.lasers[0] as Dictionary
		_expect(
			is_equal_approx(float(laser.get("remaining_time", 0.0)), duration - 1.0),
			"[%d성] 갱신은 공통 remaining_time 키 하나만 감소시켜야 한다" % star_level
		)

	var source := FileAccess.get_file_as_string("res://scripts/characters/smasher_dash_spirit_state.gd")
	var duration_body := _function_body(source, "static func get_laser_duration_frames(")
	_expect(
		duration_body.contains("LASER_DURATION_BASE_FRAMES")
		and duration_body.contains("LASER_DURATION_BONUS_PER_STAR")
		and duration_body.contains("normalized_star - 1"),
		"GRT-054: 지속시간은 기본값 × (1 + 별당 보너스 × (성급-1)) 식에서 파생돼야 한다"
	)
	_expect(
		not source.contains("432.0") and not source.contains("504.0"),
		"GRT-054 RED: 2·3성 파생 지속시간 리터럴을 생산 코드에 추가하면 안 된다"
	)
	_expect(
		not source.contains("remaining_time_star") and not source.contains("star_remaining_time"),
		"GRT-007: 성급별 별도 타이머 키를 만들지 않고 effect family의 remaining_time 하나를 공유해야 한다"
	)
	if measured_durations.size() == 3:
		print(
			"smasher_dash_spirit_laser_geometry_smoke: duration=%.1f/%.1f/%.1f ratio=%.1f/%.1f/%.1f timer_key=remaining_time"
			% [
				measured_durations[0],
				measured_durations[1],
				measured_durations[2],
				measured_durations[0] / BASE_DURATION,
				measured_durations[1] / BASE_DURATION,
				measured_durations[2] / BASE_DURATION,
			]
		)


# 원본 수량 `min(60, max(30, length // 5))`과 3겹 원 렌더 계약.
func _verify_evaporation_particles() -> RefCounted:
	var first_state: RefCounted = null
	for leg: Array in [
		["210px 레이저", 15.0, 42],
		["154px 레이저", 11.0, 30],
	]:
		var state: RefCounted = SmasherDashSpiritState.new()
		state.try_spawn_from_dash(
			1.0,
			false,
			Vector2(302.5, 700.0),
			Vector2(155.0, 50.0),
			{"runtime_perk_state": GuaranteedDashSpiritPerkState.new()},
			float(leg[1]),
			1.0
		)
		if state.lasers.is_empty():
			_expect(false, "[%s] 파티클 검증용 레이저가 생성돼야 한다" % str(leg[0]))
			continue
		# 무적 프레임(10)을 지나야 충돌이 성립한다.
		state.update_effects(11.0)
		var laser: Dictionary = state.lasers[0] as Dictionary
		var laser_start: Vector2 = laser.get("start", Vector2.ZERO) as Vector2
		var laser_end: Vector2 = laser.get("end", Vector2.ZERO) as Vector2
		var hit_pos: Vector2 = (laser_start + laser_end) * 0.5
		var result: Dictionary = state.resolve_ball_collision(
			{"ball_pos": hit_pos, "ball_vel": Vector2(3.0, 6.0)},
			{"ball_size": 28.6, "player_pos": Vector2(302.5, 700.0), "player_paddle_size": Vector2(155.0, 50.0)},
			{}
		)
		_expect(bool(result.get("dash_spirit_blocked", false)), "[%s] 레이저 중앙 충돌은 차단으로 성립해야 한다" % str(leg[0]))
		_expect(
			state.evaporation_particles.size() == int(leg[2]),
			"[%s] 증발 파티클은 원본 수량 %d개여야 한다 (got %d)" % [str(leg[0]), int(leg[2]), state.evaporation_particles.size()]
		)
		_expect(
			int(leg[2]) <= SmasherDashSpiritState.MAX_EVAPORATION_PARTICLES,
			"[%s] 상한(%d)이 1회 버스트(%d)를 잘라내면 안 된다" % [str(leg[0]), SmasherDashSpiritState.MAX_EVAPORATION_PARTICLES, int(leg[2])]
		)
		if first_state == null:
			first_state = state

	_verify_particle_alpha_profile()
	_verify_particle_capacity()
	return first_state


# P1 봉인: 원본은 알파 블렌딩 없는 `pygame.draw.circle` 덮어쓰기라 최종 알파가
# 바깥 a / 중간 a/2 / 중심 a/3 (가운데가 옅은 속 빈 기포)이다. 캔버스에 원
# 3겹을 겹쳐 그리면 source-over로 중심이 ~0.854까지 차오르므로, 밴드를 미리
# 구운 텍스처 1장으로 그린다. 여기서는 그 구워진 알파 프로파일을 직접 읽는다.
func _verify_particle_alpha_profile() -> void:
	var texture: ImageTexture = VaporParticleTextureCache.get_texture()
	if texture == null:
		_expect(false, "증발 파티클 밴드 텍스처가 생성돼야 한다")
		return
	var image: Image = texture.get_image()
	var size: int = image.get_width()
	var center: float = (float(size) - 1.0) * 0.5
	# 정규화 거리 -> 원본 밴드 알파(파티클 알파 대비 상대값).
	for probe: Array in [
		[0.00, 1.0 / 3.0, "중심"],
		[0.20, 1.0 / 3.0, "중심 밴드 안쪽"],
		[0.50, 0.5, "중간 밴드"],
		[0.85, 1.0, "바깥 밴드"],
	]:
		var normalized: float = float(probe[0])
		var expected: float = float(probe[1])
		var pixel_x: int = int(round(center + normalized * center))
		var actual: float = image.get_pixel(pixel_x, int(round(center))).a
		_expect(
			absf(actual - expected) <= 0.02,
			"%s 알파는 원본 밴드 %.3f여야 한다 (got %.3f)" % [str(probe[2]), expected, actual]
		)
	# 방향성까지 못박는다: 중심이 바깥보다 진해지면(=source-over 누적) 실패.
	var center_alpha: float = image.get_pixel(int(round(center)), int(round(center))).a
	var rim_alpha: float = image.get_pixel(int(round(center + 0.85 * center)), int(round(center))).a
	_expect(
		center_alpha < rim_alpha,
		"기포는 가운데가 더 옅어야 한다 — 중심 %.3f >= 바깥 %.3f 이면 원 3겹 누적 합성 회귀" % [center_alpha, rim_alpha]
	)


# P2 봉인: 원본 리스트에는 총량 상한이 없다. 도달 가능한 최대 버스트(60)와
# 연속 2버스트(120)가 잘리지 않아야 한다.
func _verify_particle_capacity() -> void:
	var state: RefCounted = SmasherDashSpiritState.new()
	var deps := {"runtime_perk_state": GuaranteedDashSpiritPerkState.new()}
	var burst_sizes: Array[int] = []
	# 22프레임 = 308px 레이저 -> 원본 수량 상한 60개 버스트.
	for _round_index in range(2):
		state.try_spawn_from_dash(1.0, false, Vector2(302.5, 700.0), Vector2(155.0, 50.0), deps, 22.0, 1.0)
		if state.lasers.is_empty():
			_expect(false, "최대 버스트 검증용 레이저가 생성돼야 한다")
			return
		state.update_effects(11.0)
		var laser: Dictionary = state.lasers[0] as Dictionary
		var before: int = state.evaporation_particles.size()
		var hit_pos: Vector2 = ((laser.get("start", Vector2.ZERO) as Vector2) + (laser.get("end", Vector2.ZERO) as Vector2)) * 0.5
		state.resolve_ball_collision(
			{"ball_pos": hit_pos, "ball_vel": Vector2(3.0, 6.0)},
			{"ball_size": 28.6, "player_pos": Vector2(302.5, 700.0), "player_paddle_size": Vector2(155.0, 50.0)},
			{}
		)
		burst_sizes.append(state.evaporation_particles.size() - before)
	_expect(burst_sizes.size() == 2 and burst_sizes[0] == 60, "308px 레이저는 원본 상한 60개를 띄워야 한다 (got %s)" % [burst_sizes])
	_expect(
		state.evaporation_particles.size() == 120,
		"연속 2버스트(60+60)가 상한에 잘리면 안 된다 (got %d)" % state.evaporation_particles.size()
	)
	_expect(
		SmasherDashSpiritRenderer.MAX_RENDERED_EVAPORATION_PARTICLES >= 120,
		"렌더 상한도 연속 2버스트를 자르면 안 된다 (got %d)" % SmasherDashSpiritRenderer.MAX_RENDERED_EVAPORATION_PARTICLES
	)


func _verify_ellipse_layer_contract(half_length: float) -> void:
	var renderer: RefCounted = SmasherDashSpiritRenderer.new()
	var layers: Array[Dictionary] = renderer.build_laser_layers(half_length, 1.0)
	_expect(
		layers.size() == ORIGIN_GLOW_LAYERS + 2,
		"원본 레이어 구성은 글로우 %d겹 + 메인 + 코어여야 한다 (got %d)" % [ORIGIN_GLOW_LAYERS, layers.size()]
	)
	if layers.size() != ORIGIN_GLOW_LAYERS + 2:
		return

	# 글로우 사다리: 뒤에서 앞으로 갈수록 작아지고 진해진다.
	var back_glow: Dictionary = layers[0]
	var front_glow: Dictionary = layers[ORIGIN_GLOW_LAYERS - 1]
	_expect(
		is_equal_approx(float(back_glow.get("half_height", 0.0)), ORIGIN_MAX_GLOW_HALF_HEIGHT),
		"최외곽 글로우 반높이는 원본 %.0fpx여야 한다 (got %.1f)" % [ORIGIN_MAX_GLOW_HALF_HEIGHT, float(back_glow.get("half_height", 0.0))]
	)
	_expect(
		float(back_glow.get("half_height", 0.0)) > float(front_glow.get("half_height", 0.0)),
		"글로우는 뒤로 갈수록 커져야 한다"
	)
	_expect(
		(back_glow.get("color", Color.WHITE) as Color).a < (front_glow.get("color", Color.WHITE) as Color).a,
		"글로우는 뒤로 갈수록 옅어져야 한다"
	)

	var main_layer: Dictionary = layers[ORIGIN_GLOW_LAYERS]
	var core_layer: Dictionary = layers[ORIGIN_GLOW_LAYERS + 1]
	_expect(
		is_equal_approx(float(main_layer.get("half_width", 0.0)), half_length),
		"메인 타원은 레이저 전체 길이를 덮어야 한다"
	)
	_expect(
		is_equal_approx(float(main_layer.get("half_height", 0.0)), ORIGIN_MAIN_HALF_HEIGHT),
		"메인 타원 반높이는 원본 %.0fpx여야 한다 (got %.1f)" % [ORIGIN_MAIN_HALF_HEIGHT, float(main_layer.get("half_height", 0.0))]
	)
	# 끝단이 둥글게 수렴하는 원본 실루엣의 핵심: 코어가 양 끝에서 10px씩 안쪽에 있다.
	_expect(
		is_equal_approx(float(core_layer.get("half_width", 0.0)), half_length - ORIGIN_CORE_END_INSET),
		"코어는 양 끝에서 %.0fpx 인셋돼야 한다 — 직각 캡 막대 회귀 방지 (got %.1f, expected %.1f)" % [ORIGIN_CORE_END_INSET, float(core_layer.get("half_width", 0.0)), half_length - ORIGIN_CORE_END_INSET]
	)
	_expect(
		float(core_layer.get("half_width", 0.0)) < float(main_layer.get("half_width", 0.0)),
		"코어는 메인보다 짧아야 한다 (끝단 테이퍼)"
	)
	_expect(
		is_equal_approx(float(core_layer.get("half_height", 0.0)), ORIGIN_CORE_HALF_HEIGHT),
		"코어 반높이는 원본 %.0fpx여야 한다 (got %.1f)" % [ORIGIN_CORE_HALF_HEIGHT, float(core_layer.get("half_height", 0.0))]
	)


func _finish() -> void:
	if _probe != null:
		_probe.queue_free()
		_probe = null
	if _failures.is_empty():
		print("smasher_dash_spirit_laser_geometry_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	var next_static := source.find("\n\nstatic func ", start + signature.length())
	if next < 0 or (next_static >= 0 and next_static < next):
		next = next_static
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)
