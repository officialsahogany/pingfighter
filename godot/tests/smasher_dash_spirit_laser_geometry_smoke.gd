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

	func get_runtime_skill_bonus(_perk_id: String) -> float:
		return 1.0


class DashSpiritLaserProbe:
	extends Node2D

	var state: Object = null
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		if state != null:
			state.draw(self, Vector2.ZERO)


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

	_probe = DashSpiritLaserProbe.new()
	_probe.name = "DashSpiritLaserProbe"
	_probe.state = base_state
	get_root().add_child(_probe)
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
	_finish()
	return true


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
