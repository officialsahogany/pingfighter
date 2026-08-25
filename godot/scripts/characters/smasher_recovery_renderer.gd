extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

# 경신보 (Gyeongsinbo) modular VFX pieces. Procedural primitives lost this
# effect: `draw_line` has no caps, so uniform-width rays read as square bars,
# and eight evenly divided spokes read as a bicycle wheel no matter how much
# angular jitter is layered on. The authored set carries the silhouette now and
# the runtime only drives envelope, scroll, and tint.
const STEP_SIGIL_TEXTURE_PATH := "res://assets/sprites/characters/smasher/gyeongsinbo/gyeongsinbo_step_sigil_imagegen_v1.png"
const DUST_BLOOM_TEXTURE_PATH := "res://assets/sprites/characters/smasher/gyeongsinbo/gyeongsinbo_dust_bloom_imagegen_v1.png"
const QI_TRAIL_TEXTURE_PATH := "res://assets/sprites/characters/smasher/gyeongsinbo/gyeongsinbo_qi_trail_imagegen_v1.png"
const GROUND_CRACK_TEXTURE_PATH := "res://assets/sprites/characters/smasher/gyeongsinbo/gyeongsinbo_ground_crack_imagegen_v1.png"

# ⚠️이 렌더러는 배틀 씬의 공용 캔버스에 immediate `_draw()` 로 그린다. 그 안에서
# `canvas.material` 을 갈아끼우는 "1패스 머터리얼 스왑"은 커맨드 단위로 적용되지
# 않는다 — 머터리얼은 CanvasItem 단위 속성이라 마지막 대입만 남고, 결과는 전부
# 캔버스 원래 머터리얼로 그려진다. 2026-08-02 픽셀 실측에서 LIGHT_BLEND_MODE 를
# ADD ↔ MIX 로 뒤집어도 jade=9261 / dust=581 / rupture=10275 가 자릿수까지
# 동일했다. 그래서 이 레이어들은 전부 MIX 로 합성된다는 전제로 알파/명도를
# 맞춰 두었다. 진짜 가산이 필요하면 자기 머터리얼을 가진 자식 CanvasItem 호스트가
# 필요하고(참고 `viper_wall_leap_blast_fx_host.gd` 는 Sprite2D 자식이라 동작한다),
# 그건 배틀 씬 z-슬롯 제약을 같이 풀어야 하는 별개 작업이다.
const COMPOSITE_BLEND_MODE := "mix"

const MAX_RENDERED_BURST_PARTICLES := 24
const MAX_RENDERED_LIGHT_PARTICLES := 28
const MAX_RENDERED_DUST_PUFFS := 10
const TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const TIMER_STACK_SPACING := 18.0
const TIMER_STACK_KEY := "recovery_boost"
const TIMER_STACK_INDEX := 0
const ACTIVE_FADE_IN_FRAMES := 18.0
const ACTIVE_FADE_OUT_FRAMES := 18.0

# The skill is drawn after the player on the shared battle canvas. Keep the
# authored shapes readable, but budget their stacked alpha so the character
# silhouette survives both the sustained state and the activation overlap.
const SIGIL_INNER_BASE_ALPHA := 0.17
const SIGIL_INNER_BREATH_ALPHA := 0.08
const SIGIL_GLINT_BASE_ALPHA := 0.07
const SIGIL_GLINT_BREATH_ALPHA := 0.05
const QI_TRAIL_BASE_ALPHA := 0.23
const QI_TRAIL_LANE_ALPHA_STEP := 0.07
const CAST_FLASH_ALPHA_SCALE := 0.10
const CAST_RING_ALPHA_SCALE := 0.22
const CAST_CRACK_BASE_ALPHA := 0.32
const CAST_CRACK_COMPRESSION_ALPHA := 0.08
const CAST_CORE_BASE_ALPHA := 0.10
const CAST_CORE_COMPRESSION_ALPHA := 0.10
const CAST_GLOW_BASE_ALPHA := 0.06
const CAST_GLOW_COMPRESSION_ALPHA := 0.10

# 플레이어 패들 밑면은 750 바닥에 딱 붙어 있어 "발밑" 아래로는 그릴 자리가 없다.
# 지면 계열 피스는 전부 넓고 납작하게 눕히고 하단을 이 선에 클램프해 잘림을 없앤다.
const FIELD_BOTTOM_Y := 745.0
const SIGIL_ASPECT := 0.24
const CRACK_ASPECT := 0.26
const QI_TRAIL_ASPECT := 0.34

const SIGIL_TINT := Color(0.42, 1.0, 0.70)
const DUST_TINT := Color(0.80, 0.87, 0.80)
const QI_TINT := Color(0.55, 1.0, 0.78)
const CRACK_TINT := Color(0.62, 1.0, 0.74)

static var _step_sigil_texture: Texture2D = null
static var _dust_bloom_texture: Texture2D = null
static var _qi_trail_texture: Texture2D = null
static var _ground_crack_texture: Texture2D = null
static var _uv_quad := PackedVector2Array([
	Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
])
static var _uv_quad_mirrored := PackedVector2Array([
	Vector2(1.0, 0.0), Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0),
])

var _prewarm_step_index := 0


func prewarm_step() -> bool:
	match _prewarm_step_index:
		0:
			_step_sigil_texture = ProjectResourceLoader.load_texture(STEP_SIGIL_TEXTURE_PATH)
		1:
			_dust_bloom_texture = ProjectResourceLoader.load_texture(DUST_BLOOM_TEXTURE_PATH)
		2:
			_qi_trail_texture = ProjectResourceLoader.load_texture(QI_TRAIL_TEXTURE_PATH)
		3:
			_ground_crack_texture = ProjectResourceLoader.load_texture(GROUND_CRACK_TEXTURE_PATH)
		4:
			ImpactFlareTextureCache.get_glow_texture()
		5:
			ImpactFlareTextureCache.get_sparkle_texture()
		6:
			ImpactShockwaveTextureCache.get_full_ring_texture()
		_:
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func build_pipeline_status() -> Dictionary:
	while not prewarm_step():
		pass
	return {
		"gyeongsinbo_texture_piece_count": 4,
		"gyeongsinbo_texture_pieces_ready": (
			_is_png_texture_ready(STEP_SIGIL_TEXTURE_PATH, _step_sigil_texture)
			and _is_png_texture_ready(DUST_BLOOM_TEXTURE_PATH, _dust_bloom_texture)
			and _is_png_texture_ready(QI_TRAIL_TEXTURE_PATH, _qi_trail_texture)
			and _is_png_texture_ready(GROUND_CRACK_TEXTURE_PATH, _ground_crack_texture)
		),
	}


func draw(
	canvas: CanvasItem,
	shake_offset: Vector2,
	timer_stack: Object,
	visual_time_msec: float,
	effect_center: Vector2,
	effect_timer_frames: float,
	effect_total_frames: float,
	flash_alpha: float,
	speed_boost_timer_frames: float,
	speed_boost_total_frames: float,
	last_player_pos: Vector2,
	last_player_size: Vector2,
	last_move_direction: float,
	wave_rings: Array[Dictionary],
	burst_particles: Array[Dictionary],
	light_particles: Array[Dictionary],
	dust_puffs: Array[Dictionary] = []
) -> void:
	if canvas == null:
		return
	_draw_lightness_step_aura(
		canvas,
		shake_offset,
		visual_time_msec,
		speed_boost_timer_frames,
		speed_boost_total_frames,
		last_player_pos,
		last_player_size,
		last_move_direction
	)
	_draw_speed_trail(canvas, shake_offset, last_player_pos, light_particles, dust_puffs)
	_draw_recovery_burst(
		canvas,
		shake_offset,
		effect_center,
		effect_timer_frames,
		effect_total_frames,
		flash_alpha,
		wave_rings,
		burst_particles
	)
	_draw_speed_boost_timer(
		canvas,
		timer_stack,
		visual_time_msec,
		speed_boost_timer_frames,
		speed_boost_total_frames
	)


func get_timer_projection_for_tests(
	visual_time_msec: float,
	speed_boost_timer_frames: float,
	speed_boost_total_frames: float
) -> Vector4:
	var ratio: float = clamp(speed_boost_timer_frames / max(1.0, speed_boost_total_frames), 0.0, 1.0)
	var remaining_seconds: float = max(0.0, speed_boost_timer_frames) / 60.0
	var warning_pulse: float = abs(sin(visual_time_msec * 0.015))
	var icon_pulse: float = abs(sin(visual_time_msec * 0.012))
	return Vector4(ratio, remaining_seconds, warning_pulse, icon_pulse)


func get_active_projection_for_tests(
	visual_time_msec: float,
	speed_boost_timer_frames: float,
	speed_boost_total_frames: float
) -> Vector4:
	if speed_boost_timer_frames <= 0.0 or speed_boost_total_frames <= 0.0:
		return Vector4.ZERO
	var elapsed_frames: float = max(0.0, speed_boost_total_frames - speed_boost_timer_frames)
	var fade_in: float = clamp(elapsed_frames / ACTIVE_FADE_IN_FRAMES, 0.0, 1.0)
	var fade_out: float = clamp(speed_boost_timer_frames / ACTIVE_FADE_OUT_FRAMES, 0.0, 1.0)
	var envelope: float = min(fade_in, fade_out)
	var breath: float = 0.5 + 0.5 * sin(visual_time_msec * 0.0062)
	var sweep: float = fposmod(visual_time_msec * 0.00115, 1.0)
	var ratio: float = clamp(speed_boost_timer_frames / speed_boost_total_frames, 0.0, 1.0)
	return Vector4(envelope, breath, sweep, ratio)


func get_cast_projection_for_tests(
	effect_timer_frames: float,
	effect_total_frames: float
) -> Vector4:
	if effect_timer_frames <= 0.0 or effect_total_frames <= 0.0:
		return Vector4.ZERO
	var progress: float = clamp(1.0 - effect_timer_frames / effect_total_frames, 0.0, 1.0)
	var compression: float = clamp(1.0 - progress / 0.18, 0.0, 1.0)
	var rupture: float = pow(clamp(1.0 - progress / 0.84, 0.0, 1.0), 0.72)
	var shock_progress: float = clamp(progress / 0.74, 0.0, 1.0)
	var shockwave: float = sin(shock_progress * PI)
	return Vector4(progress, compression, rupture, shockwave)


func get_ground_layout_for_tests(anchor_y: float, height: float) -> float:
	return min(anchor_y, FIELD_BOTTOM_Y - height * 0.5)


func _draw_lightness_step_aura(
	canvas: CanvasItem,
	shake_offset: Vector2,
	visual_time_msec: float,
	speed_boost_timer_frames: float,
	speed_boost_total_frames: float,
	last_player_pos: Vector2,
	last_player_size: Vector2,
	last_move_direction: float
) -> void:
	if speed_boost_timer_frames <= 0.0:
		return
	var projection := get_active_projection_for_tests(
		visual_time_msec,
		speed_boost_timer_frames,
		speed_boost_total_frames
	)
	var envelope: float = projection.x
	if envelope <= 0.001:
		return
	var breath: float = projection.y
	var sweep: float = projection.z
	var direction: float = -1.0 if last_move_direction < 0.0 else 1.0
	var safe_size := Vector2(max(1.0, last_player_size.x), max(1.0, last_player_size.y))
	var foot_x: float = last_player_pos.x + safe_size.x * 0.5 + shake_offset.x
	_draw_step_sigil(canvas, foot_x, last_player_pos.y + shake_offset.y, safe_size, visual_time_msec, breath, envelope)
	_draw_qi_trail(canvas, foot_x, last_player_pos.y + shake_offset.y, safe_size, direction, sweep, breath, envelope)


func _draw_step_sigil(
	canvas: CanvasItem,
	foot_x: float,
	player_top_y: float,
	safe_size: Vector2,
	visual_time_msec: float,
	breath: float,
	envelope: float
) -> void:
	var texture: Texture2D = _get_step_sigil_texture()
	if texture == null:
		return
	var outer_width: float = clamp(safe_size.x * 1.94, 240.0, 380.0) * (0.97 + breath * 0.05)
	var outer_size := Vector2(outer_width, outer_width * SIGIL_ASPECT)
	var anchor_y: float = player_top_y + safe_size.y * 0.58
	var outer_center := Vector2(foot_x, get_ground_layout_for_tests(anchor_y, outer_size.y))
	var inner_size := outer_size * Vector2(0.63, 0.66)
	var inner_center := Vector2(foot_x, get_ground_layout_for_tests(anchor_y - 2.0, inner_size.y))

	# 보법진은 지면에 누워 있으므로 화면에서 기울지 않는다 — 쿼드를 돌리면 납작한
	# 타원이 대각선으로 서면서 세로 폭이 배로 늘어 바닥선 밖으로 잘려 나간다.
	# 회전은 UV 로만 걸어 "지면 위에서 도는 진"으로 읽히게 한다.
	var outer_spin: float = visual_time_msec * 0.00034
	var inner_spin: float = -visual_time_msec * 0.00061 + 1.9
	# Keep the soft inner seal and edge glint, but omit the sharp full-size
	# circle that enclosed the character during left/right movement.
	_draw_spun_ground_quad(
		canvas,
		texture,
		inner_center,
		inner_size,
		inner_spin,
		Color(
			0.74,
			1.0,
			0.82,
			(SIGIL_INNER_BASE_ALPHA + breath * SIGIL_INNER_BREATH_ALPHA) * envelope
		)
	)
	# 먹빛 획이 섞인 아트라 MIX 한 겹만으로는 어두운 플레이필드에서 발광이 죽는다.
	# 밝은 획만 살려 올리는 가산 한 겹을 덧대 "빛나는 진"으로 읽히게 한다.
	_draw_spun_ground_quad(
		canvas,
		texture,
		outer_center,
		outer_size * 1.02,
		outer_spin,
		Color(
			SIGIL_TINT.r,
			SIGIL_TINT.g,
			SIGIL_TINT.b,
			(SIGIL_GLINT_BASE_ALPHA + breath * SIGIL_GLINT_BREATH_ALPHA) * envelope
		)
	)


func _draw_qi_trail(
	canvas: CanvasItem,
	foot_x: float,
	player_top_y: float,
	safe_size: Vector2,
	direction: float,
	sweep: float,
	breath: float,
	envelope: float
) -> void:
	var texture: Texture2D = _get_qi_trail_texture()
	if texture == null:
		return
	for lane in range(2):
		var lane_phase: float = fposmod(sweep + float(lane) * 0.5, 1.0)
		var width: float = clamp(safe_size.x * (1.02 + float(lane) * 0.22), 130.0, 260.0)
		var size := Vector2(width, width * QI_TRAIL_ASPECT)
		# 진행 반대쪽으로 흘러나가며 옅어진다 — 이동 방향이 곧 잔영의 방향이다.
		var trail_x: float = foot_x - direction * (safe_size.x * 0.24 + lane_phase * safe_size.x * 0.46)
		var anchor_y: float = player_top_y + safe_size.y * (0.20 + float(lane) * 0.18)
		var tilt: float = direction * (0.07 + lane_phase * 0.11) - float(lane) * 0.13
		# 기운 쿼드의 실제 세로 폭으로 클램프해야 한다. size.y 로 재면 기울어진 만큼
		# 바닥선 밖으로 삐져나간다.
		var center := Vector2(trail_x, get_ground_layout_for_tests(anchor_y, _rotated_extent_y(size, tilt)))
		var alpha: float = (
			(QI_TRAIL_BASE_ALPHA - float(lane) * QI_TRAIL_LANE_ALPHA_STEP)
			* (1.0 - lane_phase * 0.55)
			* (0.82 + breath * 0.24)
			* envelope
		)
		_draw_textured_quad(
			canvas,
			texture,
			center,
			size,
			tilt,
			Color(QI_TINT.r, QI_TINT.g, QI_TINT.b, alpha),
			direction < 0.0
		)


func _draw_dust_puffs(canvas: CanvasItem, shake_offset: Vector2, dust_puffs: Array[Dictionary]) -> void:
	if dust_puffs.is_empty():
		return
	var texture: Texture2D = _get_dust_bloom_texture()
	if texture == null:
		return
	var puff_start: int = max(0, dust_puffs.size() - MAX_RENDERED_DUST_PUFFS)
	for index in range(puff_start, dust_puffs.size()):
		var puff: Dictionary = dust_puffs[index]
		var life: float = float(puff.get("life", 0.0))
		var max_life: float = max(1.0, float(puff.get("max_life", 1.0)))
		var age: float = clamp(life / max_life, 0.0, 1.0)
		# 피어오르며 커지고, 뒷심 없이 빠르게 사그라든다.
		var width: float = max(6.0, float(puff.get("size", 60.0)) * (0.62 + age * 0.86))
		var size := Vector2(width, width * 0.72)
		var alpha: float = pow(1.0 - age, 1.45) * float(puff.get("alpha", 0.5))
		if alpha <= 0.004:
			continue
		var anchor := _as_vector2(puff.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var spin: float = float(puff.get("spin", 0.0)) + age * float(puff.get("spin_rate", 0.0))
		var center := Vector2(anchor.x, get_ground_layout_for_tests(anchor.y, _rotated_extent_y(size, spin)))
		_draw_textured_quad(
			canvas,
			texture,
			center,
			size,
			spin,
			Color(DUST_TINT.r, DUST_TINT.g, DUST_TINT.b, alpha),
			bool(puff.get("mirrored", false))
		)


func _draw_recovery_burst(
	canvas: CanvasItem,
	shake_offset: Vector2,
	effect_center: Vector2,
	effect_timer_frames: float,
	effect_total_frames: float,
	flash_alpha: float,
	wave_rings: Array[Dictionary],
	burst_particles: Array[Dictionary]
) -> void:
	var center := effect_center + shake_offset
	_draw_cast_rupture(canvas, center, effect_timer_frames, effect_total_frames)
	if flash_alpha > 0.01:
		ImpactFlareTextureCache.draw_glow(
			canvas,
			center,
			48.0 + (1.0 - flash_alpha) * 28.0,
			Color(0.58, 1.0, 0.75),
			flash_alpha * CAST_FLASH_ALPHA_SCALE
		)
	for ring in wave_rings:
		ImpactShockwaveTextureCache.draw_full_ring(
			canvas,
			center,
			float(ring.get("radius", 12.0)),
			Color(0.35, 1.0, 0.68),
			float(ring.get("alpha", 0.0)) * CAST_RING_ALPHA_SCALE
		)
	var particle_start: int = max(0, burst_particles.size() - MAX_RENDERED_BURST_PARTICLES)
	for index in range(particle_start, burst_particles.size()):
		var particle: Dictionary = burst_particles[index]
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
		var alpha: float = clamp(1.0 - life / max_life, 0.0, 1.0)
		var size: float = max(0.8, float(particle.get("size", 2.0)) * (0.65 + alpha * 0.55))
		var color: Color = _get_recovery_particle_color(float(particle.get("hue", 0.0)), alpha)
		ImpactFlareTextureCache.draw_sparkle(
			canvas,
			_as_vector2(particle.get("pos", effect_center), effect_center) + shake_offset,
			size * 1.45,
			color,
			min(0.72, color.a)
		)


func _draw_cast_rupture(
	canvas: CanvasItem,
	center: Vector2,
	effect_timer_frames: float,
	effect_total_frames: float
) -> void:
	var projection := get_cast_projection_for_tests(effect_timer_frames, effect_total_frames)
	var progress: float = projection.x
	var compression: float = projection.y
	var rupture: float = projection.z
	if rupture <= 0.001:
		return
	var texture: Texture2D = _get_ground_crack_texture()
	if texture == null:
		return
	# 균열은 넓고 납작하게 눕혀 지면을 따라 번지게 한다. 세로로 세우면 패들 밑동이
	# 바닥선 밖으로 나가 절반이 잘린다.
	var width: float = 268.0 + progress * 322.0
	var size := Vector2(width, width * CRACK_ASPECT)
	var crack_center := Vector2(center.x, get_ground_layout_for_tests(center.y, size.y))
	_draw_textured_quad(
		canvas,
		texture,
		crack_center,
		size,
		0.0,
		Color(
			CRACK_TINT.r,
			CRACK_TINT.g,
			CRACK_TINT.b,
			(CAST_CRACK_BASE_ALPHA + compression * CAST_CRACK_COMPRESSION_ALPHA) * rupture
		)
	)
	# 균열 골격 위에 좁고 밝은 한 겹을 더 얹어 발동 순간의 백열 코어를 만든다.
	_draw_textured_quad(
		canvas,
		texture,
		crack_center,
		size * (0.52 + compression * 0.16),
		0.0,
		Color(
			0.90,
			1.0,
			0.86,
			(CAST_CORE_BASE_ALPHA + compression * CAST_CORE_COMPRESSION_ALPHA) * rupture
		)
	)
	ImpactFlareTextureCache.draw_glow(
		canvas,
		crack_center,
		30.0 + progress * 56.0,
		Color(0.86, 1.0, 0.78),
		(CAST_GLOW_BASE_ALPHA + compression * CAST_GLOW_COMPRESSION_ALPHA) * rupture
	)


func _draw_speed_trail(
	canvas: CanvasItem,
	shake_offset: Vector2,
	last_player_pos: Vector2,
	light_particles: Array[Dictionary],
	dust_puffs: Array[Dictionary]
) -> void:
	_draw_dust_puffs(canvas, shake_offset, dust_puffs)
	if light_particles.is_empty():
		return
	var particle_start: int = max(0, light_particles.size() - MAX_RENDERED_LIGHT_PARTICLES)
	for index in range(particle_start, light_particles.size()):
		var particle: Dictionary = light_particles[index]
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
		var alpha: float = clamp(1.0 - life / max_life, 0.0, 1.0)
		var size: float = max(0.6, float(particle.get("size", 2.0)) * (0.55 + alpha * 0.55))
		var color: Color = _get_trail_particle_color(float(particle.get("hue", 0.0)), alpha)
		ImpactFlareTextureCache.draw_sparkle(
			canvas,
			_as_vector2(particle.get("pos", last_player_pos), last_player_pos) + shake_offset,
			size * 1.35,
			color,
			min(0.52, color.a)
		)


func _draw_speed_boost_timer(
	canvas: CanvasItem,
	timer_stack: Object,
	visual_time_msec: float,
	speed_boost_timer_frames: float,
	speed_boost_total_frames: float
) -> void:
	if speed_boost_timer_frames <= 0.0:
		return
	var projection := get_timer_projection_for_tests(
		visual_time_msec,
		speed_boost_timer_frames,
		speed_boost_total_frames
	)
	var ratio: float = projection.x
	var remaining_seconds: float = projection.y
	var stack_index: int = _claim_timer_stack_index(timer_stack, TIMER_STACK_KEY, TIMER_STACK_INDEX)
	var frame_rect := Rect2(_get_timer_bar_position(stack_index), TIMER_BAR_SIZE)
	var outer_rect := frame_rect.grow(5.0)
	var mid_rect := frame_rect.grow(3.0)
	var border_rect := frame_rect.grow(2.0)
	canvas.draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 0.28))
	canvas.draw_rect(outer_rect, Color(18.0 / 255.0, 42.0 / 255.0, 34.0 / 255.0, 0.94))
	canvas.draw_rect(mid_rect, Color(42.0 / 255.0, 150.0 / 255.0, 105.0 / 255.0, 0.92))
	canvas.draw_rect(mid_rect, Color(145.0 / 255.0, 1.0, 190.0 / 255.0, 0.80), false, 2.0)
	canvas.draw_rect(border_rect, Color(12.0 / 255.0, 28.0 / 255.0, 24.0 / 255.0, 0.96))
	canvas.draw_rect(frame_rect, Color(0.03, 0.08, 0.06, 0.94))

	var base_color: Color
	var highlight_color: Color
	if remaining_seconds > 3.0:
		base_color = Color(65.0 / 255.0, 1.0, 145.0 / 255.0, 0.98)
		highlight_color = Color(170.0 / 255.0, 1.0, 210.0 / 255.0, 0.98)
	elif remaining_seconds > 1.5:
		base_color = Color(70.0 / 255.0, 230.0 / 255.0, 120.0 / 255.0, 0.98)
		highlight_color = Color(1.0, 230.0 / 255.0, 110.0 / 255.0, 0.95)
	else:
		var pulse: float = projection.z
		base_color = Color((130.0 + 80.0 * pulse) / 255.0, (210.0 + 45.0 * pulse) / 255.0, (75.0 + 55.0 * pulse) / 255.0, 0.99)
		highlight_color = Color(1.0, (210.0 + 35.0 * pulse) / 255.0, (90.0 + 75.0 * pulse) / 255.0, 0.99)

	var fill_width: float = max(1.0, (frame_rect.size.x - 4.0) * ratio)
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, base_color)
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.34))), highlight_color)
	for index in range(1, 10):
		var tick_x: float = frame_rect.position.x + 2.0 + (frame_rect.size.x - 4.0) * (float(index) / 10.0)
		canvas.draw_line(
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 4.0),
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(150.0 / 255.0, 230.0 / 255.0, 185.0 / 255.0, 0.84),
			1.0
		)

	var icon_size := Vector2(19.0, 19.0)
	var icon_center := frame_rect.position + Vector2(-19.0, frame_rect.size.y * 0.5)
	var icon_pulse: float = projection.w
	ImpactFlareTextureCache.draw_glow(canvas, icon_center, 16.0, Color(0.0, 0.0, 0.0), 0.26)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, icon_center, 13.0, Color(85.0 / 255.0, 1.0, 150.0 / 255.0), 0.34 + 0.22 * icon_pulse)
	canvas.draw_line(icon_center + Vector2(-icon_size.x * 0.35, icon_size.y * 0.12), icon_center + Vector2(icon_size.x * 0.15, -icon_size.y * 0.28), Color(0.72, 1.0, 0.82, 0.95), 3.0, true)
	canvas.draw_line(icon_center + Vector2(icon_size.x * 0.15, -icon_size.y * 0.28), icon_center + Vector2(icon_size.x * 0.35, icon_size.y * 0.10), Color(0.72, 1.0, 0.82, 0.95), 3.0, true)


func _draw_textured_quad(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	size: Vector2,
	rotation_radians: float,
	color: Color,
	mirrored: bool = false
) -> void:
	if canvas == null or texture == null or color.a <= 0.003:
		return
	if size.x <= 0.5 or size.y <= 0.5:
		return
	var half := size * 0.5
	var axis_x := Vector2(cos(rotation_radians), sin(rotation_radians)) * half.x
	var axis_y := Vector2(-sin(rotation_radians), cos(rotation_radians)) * half.y
	var points := PackedVector2Array([
		center - axis_x - axis_y,
		center + axis_x - axis_y,
		center + axis_x + axis_y,
		center - axis_x + axis_y,
	])
	# draw_polygon needs NORMALIZED [0,1] UVs — feeding a pixel rect clamps every
	# UV past 1.0 to the sheet's transparent edge texel and the quad renders
	# invisible with no error at all.
	canvas.draw_polygon(
		points,
		PackedColorArray([color, color, color, color]),
		_uv_quad_mirrored if mirrored else _uv_quad,
		texture
	)


func _draw_spun_ground_quad(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	size: Vector2,
	spin_radians: float,
	color: Color
) -> void:
	if canvas == null or texture == null or color.a <= 0.003:
		return
	if size.x <= 0.5 or size.y <= 0.5:
		return
	var half := size * 0.5
	var points := PackedVector2Array([
		center - half,
		center + Vector2(half.x, -half.y),
		center + half,
		center + Vector2(-half.x, half.y),
	])
	# 텍스처 마진이 완전 투명이라 [0,1] 밖으로 도는 코너는 투명 에지 텍셀을 물어
	# 사각 박스를 남기지 않는다.
	canvas.draw_polygon(
		points,
		PackedColorArray([color, color, color, color]),
		_build_spun_uvs(spin_radians),
		texture
	)


func _build_spun_uvs(spin_radians: float) -> PackedVector2Array:
	var spin_cos: float = cos(spin_radians)
	var spin_sin: float = sin(spin_radians)
	var uvs := PackedVector2Array()
	uvs.resize(4)
	for index in range(4):
		var offset: Vector2 = _uv_quad[index] - Vector2(0.5, 0.5)
		uvs[index] = Vector2(
			offset.x * spin_cos - offset.y * spin_sin,
			offset.x * spin_sin + offset.y * spin_cos
		) + Vector2(0.5, 0.5)
	return uvs


func _rotated_extent_y(size: Vector2, rotation_radians: float) -> float:
	return absf(size.x * sin(rotation_radians)) + absf(size.y * cos(rotation_radians))


func _get_timer_bar_position(stack_index: int) -> Vector2:
	return Vector2(
		760.0 - TIMER_BAR_SIZE.x - TIMER_BAR_MARGIN.x,
		750.0 - TIMER_BAR_MARGIN.y - float(max(0, stack_index)) * TIMER_STACK_SPACING
	)


func _claim_timer_stack_index(timer_stack: Object, key: String, fallback_index: int) -> int:
	if timer_stack != null and timer_stack.has_method("claim"):
		var claimed: int = int(timer_stack.claim(key, true))
		if claimed >= 0:
			return claimed
	return fallback_index


func _get_recovery_particle_color(hue: float, alpha: float) -> Color:
	if hue < 0.34:
		return Color(0.28, 1.0, 0.62, 0.82 * alpha)
	if hue < 0.68:
		return Color(1.0, 0.86, 0.36, 0.74 * alpha)
	return Color(0.92, 1.0, 0.84, 0.82 * alpha)


func _get_trail_particle_color(hue: float, alpha: float) -> Color:
	if hue < 0.45:
		return Color(0.18, 1.0, 0.62, 0.54 * alpha)
	if hue < 0.78:
		return Color(1.0, 0.82, 0.34, 0.45 * alpha)
	return Color(0.70, 1.0, 0.90, 0.50 * alpha)


func _get_step_sigil_texture() -> Texture2D:
	if _step_sigil_texture == null:
		_step_sigil_texture = ProjectResourceLoader.load_texture(STEP_SIGIL_TEXTURE_PATH)
	return _step_sigil_texture


func _get_dust_bloom_texture() -> Texture2D:
	if _dust_bloom_texture == null:
		_dust_bloom_texture = ProjectResourceLoader.load_texture(DUST_BLOOM_TEXTURE_PATH)
	return _dust_bloom_texture


func _get_qi_trail_texture() -> Texture2D:
	if _qi_trail_texture == null:
		_qi_trail_texture = ProjectResourceLoader.load_texture(QI_TRAIL_TEXTURE_PATH)
	return _qi_trail_texture


func _get_ground_crack_texture() -> Texture2D:
	if _ground_crack_texture == null:
		_ground_crack_texture = ProjectResourceLoader.load_texture(GROUND_CRACK_TEXTURE_PATH)
	return _ground_crack_texture




static func _is_png_texture_ready(path: String, texture: Texture2D) -> bool:
	if not ResourceLoader.exists(path):
		return false
	return texture != null and texture.get_width() > 0 and texture.get_height() > 0


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
