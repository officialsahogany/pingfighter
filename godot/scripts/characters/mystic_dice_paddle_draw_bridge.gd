extends Node2D

# Procedural child renderer for the Mystic Dice paddle aura. Its Control parent
# owns the full-playfield clip rect, so this CanvasItem cannot draw into the
# screen letterbox even if a future effect primitive crosses the playfield edge.

const PARTICLE_COUNT := 34
const PARTICLE_SPAWN_WINDOW := 2.35
const MIN_PARTICLE_LIFE := 0.45
const MAX_PARTICLE_LIFE := 0.78

const GROUND_POOL_LAYERS := 4
const PLUME_LAYERS := 6
const ELLIPSE_SEGMENTS := 28

const AURA_DEEP := Color(0.42, 0.34, 1.0)
const AURA_MID := Color(0.40, 0.62, 1.0)
const AURA_LIT := Color(0.62, 0.94, 1.0)

const PALETTE: Array[Color] = [
	Color(0.36, 0.88, 1.0),
	Color(0.48, 0.52, 1.0),
	Color(0.70, 0.34, 1.0),
	Color(0.88, 0.64, 1.0),
]

var _state: Dictionary = {}


func _init() -> void:
	set_process(false)


func sync_state(next_state: Dictionary, active: bool) -> void:
	_state = next_state.duplicate(true)
	if not active or not _can_draw_state(_state):
		set_active(false)
		return
	position = (
		_vector2(_state.get("screen_pos", Vector2.ZERO), Vector2.ZERO)
		- _vector2(_state.get("clip_position", Vector2.ZERO), Vector2.ZERO)
	)
	set_active(true)
	queue_redraw()


func set_active(active: bool) -> void:
	visible = active
	set_process(false)


func get_debug_status() -> Dictionary:
	return {
		"active": visible,
		"processing": is_processing(),
		"visible_particle_count": _visible_particle_count(),
		"position": position,
		"state": _state.duplicate(true),
	}


func _draw() -> void:
	if not visible or not _can_draw_state(_state):
		return
	var render_scale := maxf(0.001, float(_state.get("render_scale", 1.0)))
	var paddle_size := (
		_vector2(_state.get("paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
		* render_scale
	)
	var intensity := clampf(float(_state.get("intensity", 0.0)), 0.0, 1.0)
	var elapsed := clampf(float(_state.get("elapsed_seconds", 0.0)), 0.0, 3.0)
	_draw_paddle_aura(paddle_size, elapsed, intensity, render_scale)
	_draw_particles(paddle_size, elapsed, intensity, render_scale)


# 오라는 직선 모서리를 하나도 그리지 않는다. 구 구현은 패들 rect 외곽선
# 두 겹을 그렸고 인게임에서 디버그 히트박스로 읽혔다(2026-08-09 사용자
# 리포트). 같은 "이 패들이 축복받았다" 신호를 바닥 웅덩이 + 상승 기둥 +
# 양끝 위습(전부 타원/원)으로만 만든다.
func _draw_paddle_aura(paddle_size: Vector2, elapsed: float, intensity: float, render_scale: float) -> void:
	var pulse := 0.84 + 0.16 * sin(elapsed * 7.0)
	var half_width := maxf(1.0, paddle_size.x * 0.5)
	var bottom_y := paddle_size.y * 0.5
	_draw_ground_pool(half_width, bottom_y, pulse, intensity, render_scale)
	_draw_rising_plume(half_width, bottom_y, paddle_size.y, elapsed, intensity, render_scale)
	_draw_edge_wisps(half_width, bottom_y, paddle_size.y, pulse, intensity, render_scale)


# 바닥 축복 웅덩이. 플레이어 패들 밑면은 필드 바닥에 밀착하므로 타원을
# 패들 중심에 놓으면 아래쪽이 잘려 다시 직선이 생긴다 — 중심을 반지름만큼
# 들어 올려 바닥선에 접하게 한다(바닥밀착 패들 지면 VFX 트랩).
func _draw_ground_pool(half_width: float, bottom_y: float, pulse: float, intensity: float, render_scale: float) -> void:
	var base_radius_x := (half_width + 15.0 * render_scale) * (0.94 + 0.06 * pulse)
	var base_radius_y := maxf(3.0 * render_scale, base_radius_x * 0.26)
	for layer_index: int in range(GROUND_POOL_LAYERS):
		var layer_ratio := float(layer_index) / float(GROUND_POOL_LAYERS)
		var radius_x := base_radius_x * (1.0 - layer_ratio * 0.42)
		var radius_y := base_radius_y * (1.0 - layer_ratio * 0.42)
		var color := AURA_DEEP.lerp(AURA_LIT, layer_ratio)
		var alpha := (0.09 + 0.15 * layer_ratio) * intensity * pulse
		draw_colored_polygon(
			_ellipse_points(Vector2(0.0, bottom_y - radius_y), radius_x, radius_y),
			Color(color.r, color.g, color.b, alpha)
		)


# 상승 기둥: 발밑에서 위로 좁아지며 사라지는 타원 겹. 캐릭터 위로는 낮은
# 알파로만 걸쳐 실루엣을 덮지 않는다.
func _draw_rising_plume(half_width: float, bottom_y: float, paddle_height: float, elapsed: float, intensity: float, render_scale: float) -> void:
	var breathe := 0.92 + 0.08 * sin(elapsed * 4.6 + 1.1)
	var reach := (paddle_height * 1.15 + 22.0 * render_scale) * breathe
	for layer_index: int in range(PLUME_LAYERS):
		var layer_ratio := float(layer_index) / float(PLUME_LAYERS - 1)
		var radius_x := lerpf(half_width * 0.86, half_width * 0.22, layer_ratio)
		var radius_y := maxf(2.0 * render_scale, radius_x * 0.40)
		var color := AURA_MID.lerp(AURA_LIT, layer_ratio)
		var alpha := (1.0 - layer_ratio) * (1.0 - layer_ratio) * 0.13 * intensity
		draw_colored_polygon(
			_ellipse_points(
				Vector2(0.0, bottom_y - radius_y - reach * layer_ratio),
				radius_x,
				radius_y
			),
			Color(color.r, color.g, color.b, alpha)
		)


# 양끝 위습: 실제 타격 폭을 알려 주던 끝단 발광을 유지하되 두 겹으로 흩는다.
func _draw_edge_wisps(half_width: float, bottom_y: float, paddle_height: float, pulse: float, intensity: float, render_scale: float) -> void:
	var radius := maxf(6.0 * render_scale, paddle_height * 0.42) * (0.92 + 0.08 * pulse)
	var wisp_y := bottom_y - radius * 0.72
	for side_index: int in range(2):
		var side_sign := -1.0 if side_index == 0 else 1.0
		var color: Color = AURA_DEEP if side_index == 0 else AURA_LIT
		var center := Vector2(side_sign * half_width, wisp_y)
		draw_circle(center, radius * 1.35, Color(color.r, color.g, color.b, 0.07 * intensity))
		draw_circle(center, radius * 0.78, Color(color.r, color.g, color.b, 0.13 * intensity))


# 볼록 타원이라 항상 삼각분할 가능하다(애니메이션 폴리곤 삼각분할 트랩).
func _ellipse_points(center: Vector2, radius_x: float, radius_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(ELLIPSE_SEGMENTS)
	for segment_index: int in range(ELLIPSE_SEGMENTS):
		var angle := TAU * float(segment_index) / float(ELLIPSE_SEGMENTS)
		points[segment_index] = center + Vector2(
			cos(angle) * radius_x,
			sin(angle) * radius_y
		)
	return points


func _draw_particles(paddle_size: Vector2, elapsed: float, intensity: float, render_scale: float) -> void:
	for particle_index: int in range(PARTICLE_COUNT):
		var spawn_time := _particle_spawn_time(particle_index)
		var life := _particle_life(particle_index)
		var age := elapsed - spawn_time
		if age < 0.0 or age > life:
			continue
		var progress := clampf(age / life, 0.0, 1.0)
		var origin_x := lerpf(-paddle_size.x * 0.46, paddle_size.x * 0.46, _unit(particle_index * 11 + 3))
		# 모트도 바닥 웅덩이에서 피어오르도록 발밑 밴드에서 스폰한다.
		var origin_y := lerpf(paddle_size.y * 0.10, paddle_size.y * 0.46, _unit(particle_index * 17 + 5))
		var velocity_x := lerpf(-14.0, 14.0, _unit(particle_index * 23 + 7)) * render_scale
		var velocity_y := -lerpf(34.0, 76.0, _unit(particle_index * 29 + 11)) * render_scale
		var drift := sin(age * 9.0 + float(particle_index) * 1.7) * (3.0 + progress * 6.0) * render_scale
		var particle_position := Vector2(
			origin_x + velocity_x * age + drift,
			origin_y + velocity_y * age
		)
		var base_radius := lerpf(2.2, 5.8, _unit(particle_index * 31 + 13))
		var radius := maxf(0.5 * render_scale, base_radius * (1.0 - progress * 0.78) * render_scale)
		var alpha := pow(1.0 - progress, 1.35) * intensity
		var color: Color = PALETTE[particle_index % PALETTE.size()]
		draw_circle(particle_position, radius * 2.2, Color(color.r, color.g, color.b, alpha * 0.12))
		draw_circle(particle_position, radius * 1.45, Color(color.r, color.g, color.b, alpha * 0.24))
		draw_circle(particle_position, radius, Color(color.r, color.g, color.b, alpha * 0.92))


func _visible_particle_count() -> int:
	if not _can_draw_state(_state):
		return 0
	var elapsed := clampf(float(_state.get("elapsed_seconds", 0.0)), 0.0, 3.0)
	var count := 0
	for particle_index: int in range(PARTICLE_COUNT):
		var age := elapsed - _particle_spawn_time(particle_index)
		if age >= 0.0 and age <= _particle_life(particle_index):
			count += 1
	return count


func _particle_spawn_time(particle_index: int) -> float:
	var lane := float(particle_index) / float(PARTICLE_COUNT)
	return lane * PARTICLE_SPAWN_WINDOW + _unit(particle_index * 37 + 17) * 0.08


func _particle_life(particle_index: int) -> float:
	return lerpf(MIN_PARTICLE_LIFE, MAX_PARTICLE_LIFE, _unit(particle_index * 41 + 19))


func _unit(seed_value: int) -> float:
	var hashed := sin(float(seed_value) * 12.9898 + 78.233) * 43758.5453
	return hashed - floor(hashed)


func _can_draw_state(candidate: Dictionary) -> bool:
	return (
		bool(candidate.get("active", false))
		and candidate.get("screen_pos", null) is Vector2
		and candidate.get("clip_position", null) is Vector2
		and float(candidate.get("intensity", 0.0)) > 0.0
	)


func _vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
