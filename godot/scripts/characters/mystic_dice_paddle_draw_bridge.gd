extends Node2D

# Procedural child renderer for the Mystic Dice paddle aura. Its Control parent
# owns the full-playfield clip rect, so this CanvasItem cannot draw into the
# screen letterbox even if a future effect primitive crosses the playfield edge.

const PARTICLE_COUNT := 34
const PARTICLE_SPAWN_WINDOW := 2.35
const MIN_PARTICLE_LIFE := 0.45
const MAX_PARTICLE_LIFE := 0.78

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


func _draw_paddle_aura(paddle_size: Vector2, elapsed: float, intensity: float, render_scale: float) -> void:
	var pulse := 0.82 + 0.18 * sin(elapsed * 8.0)
	var expanded_size := paddle_size + Vector2(18.0, 14.0) * pulse * render_scale
	var rect := Rect2(-expanded_size * 0.5, expanded_size)
	var outer_alpha := 0.30 * intensity * pulse
	var inner_alpha := 0.52 * intensity
	draw_rect(rect, Color(0.38, 0.34, 1.0, outer_alpha), false, 5.0 * render_scale, true)
	draw_rect(rect.grow(-4.0 * render_scale), Color(0.38, 0.90, 1.0, inner_alpha), false, 2.0 * render_scale, true)
	var end_radius := maxf(5.0 * render_scale, paddle_size.y * 0.34)
	var end_x := paddle_size.x * 0.5
	draw_circle(Vector2(-end_x, 0.0), end_radius, Color(0.50, 0.34, 1.0, 0.16 * intensity))
	draw_circle(Vector2(end_x, 0.0), end_radius, Color(0.34, 0.88, 1.0, 0.16 * intensity))


func _draw_particles(paddle_size: Vector2, elapsed: float, intensity: float, render_scale: float) -> void:
	for particle_index: int in range(PARTICLE_COUNT):
		var spawn_time := _particle_spawn_time(particle_index)
		var life := _particle_life(particle_index)
		var age := elapsed - spawn_time
		if age < 0.0 or age > life:
			continue
		var progress := clampf(age / life, 0.0, 1.0)
		var origin_x := lerpf(-paddle_size.x * 0.46, paddle_size.x * 0.46, _unit(particle_index * 11 + 3))
		var origin_y := lerpf(-paddle_size.y * 0.16, paddle_size.y * 0.20, _unit(particle_index * 17 + 5))
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
