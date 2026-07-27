extends RefCounted

const SHOCKWAVE_GROW_SECONDS := 0.09
const RING_COUNT := 6
const RING_DELAY_SECONDS := 0.055
const RING_LIFE_SECONDS := 0.42


func prewarm() -> void:
	pass


func draw_wild_roar(
	canvas: CanvasItem,
	shake_offset: Vector2,
	field_size: Vector2,
	vfx_timer: float,
	vfx_duration: float,
	origin: Vector2,
	roar_radius: float,
	screen_flash_state_alpha: float,
	screen_flash_draw_alpha_cap: float,
	particles: Array[Dictionary],
	last_reflected: bool,
	last_ball_pos: Vector2,
	last_reflect_dir: Vector2,
	particle_life_seconds: float
) -> void:
	if canvas == null:
		return
	var elapsed := maxf(0.0, vfx_duration - vfx_timer)
	_draw_screen_flash(
		canvas,
		field_size,
		vfx_timer,
		vfx_duration,
		screen_flash_state_alpha,
		screen_flash_draw_alpha_cap
	)
	_draw_roar_zone(canvas, origin + shake_offset, elapsed, vfx_timer, vfx_duration, roar_radius)
	_draw_particles(canvas, particles, shake_offset, particle_life_seconds)
	if last_reflected:
		_draw_ball_glow(canvas, last_ball_pos + shake_offset, last_reflect_dir, elapsed)


func get_ring_projection_for_tests(elapsed: float, roar_radius: float, ring_index: int) -> Dictionary:
	if ring_index < 0 or ring_index >= RING_COUNT or roar_radius <= 0.0:
		return {}
	var ring_elapsed := elapsed - float(ring_index) * RING_DELAY_SECONDS
	if ring_elapsed < 0.0 or ring_elapsed > RING_LIFE_SECONDS:
		return {}
	var t := clampf(ring_elapsed / RING_LIFE_SECONDS, 0.0, 1.0)
	return {
		"radius": lerpf(roar_radius * 0.16, roar_radius, 1.0 - pow(1.0 - t, 2.0)),
		"alpha": (1.0 - t) * (0.66 if ring_index == 0 else 0.42),
		"width": lerpf(4.5, 1.4, t),
		"secondary": ring_index % 2 == 0,
	}


func _draw_screen_flash(
	canvas: CanvasItem,
	field_size: Vector2,
	vfx_timer: float,
	vfx_duration: float,
	state_alpha_cap: float,
	draw_alpha_cap: float
) -> void:
	var flash_fade := clampf(vfx_timer / maxf(0.001, vfx_duration), 0.0, 1.0)
	var state_alpha := state_alpha_cap * flash_fade
	var draw_alpha := minf(state_alpha, draw_alpha_cap)
	if draw_alpha <= 0.0:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, field_size), Color(1.0, 0.88, 0.28, draw_alpha * 0.34), true)


func _draw_roar_zone(
	canvas: CanvasItem,
	center: Vector2,
	elapsed: float,
	vfx_timer: float,
	vfx_duration: float,
	roar_radius: float
) -> void:
	var grow := clampf(elapsed / SHOCKWAVE_GROW_SECONDS, 0.0, 1.0)
	var eased_grow := 1.0 - pow(1.0 - grow, 3.0)
	var base_alpha := clampf(vfx_timer / maxf(0.001, vfx_duration), 0.0, 1.0)
	canvas.draw_circle(center, roar_radius * eased_grow, Color(1.0, 0.70, 0.08, 0.055 * base_alpha))
	for ring_index in range(RING_COUNT):
		var ring := get_ring_projection_for_tests(elapsed, roar_radius, ring_index)
		if ring.is_empty():
			continue
		var radius := float(ring.get("radius", 0.0))
		var alpha := float(ring.get("alpha", 0.0))
		canvas.draw_arc(center, radius, 0.0, TAU, 72, Color(1.0, 0.82, 0.16, alpha), float(ring.get("width", 1.4)), true)
		if bool(ring.get("secondary", false)):
			canvas.draw_arc(center, radius * 0.78, 0.0, TAU, 56, Color(0.35, 0.95, 1.0, alpha * 0.28), 1.4, true)
	for spoke_index in range(10):
		var angle := TAU * float(spoke_index) / 10.0 + elapsed * 2.2
		var start := center + Vector2(cos(angle), sin(angle)) * roar_radius * 0.18 * eased_grow
		var end := center + Vector2(cos(angle), sin(angle)) * roar_radius * (0.54 + 0.20 * sin(elapsed * 8.0 + float(spoke_index)))
		canvas.draw_line(start, end, Color(1.0, 0.90, 0.34, 0.18 * base_alpha), 2.0, true)


func _draw_particles(
	canvas: CanvasItem,
	particles: Array[Dictionary],
	shake_offset: Vector2,
	particle_life_seconds: float
) -> void:
	for particle in particles:
		var max_life := maxf(0.001, float(particle.get("max_life", particle_life_seconds)))
		var alpha := clampf(float(particle.get("life", 0.0)) / max_life, 0.0, 1.0)
		var color: Color = particle.get("color", Color(1.0, 0.82, 0.2, 1.0))
		color.a *= alpha
		canvas.draw_circle(
			_as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset,
			float(particle.get("size", 3.0)) * (0.55 + alpha * 0.45),
			color
		)


func _draw_ball_glow(
	canvas: CanvasItem,
	center: Vector2,
	reflect_dir: Vector2,
	elapsed: float
) -> void:
	var alpha := clampf(1.0 - elapsed / 0.75, 0.0, 1.0)
	if alpha <= 0.0:
		return
	canvas.draw_circle(center, 33.0, Color(1.0, 0.84, 0.18, 0.22 * alpha))
	canvas.draw_arc(center, 41.0, 0.0, TAU, 48, Color(1.0, 0.95, 0.40, 0.48 * alpha), 2.2, true)
	var streak_end := center + reflect_dir * 54.0
	canvas.draw_line(center, streak_end, Color(1.0, 0.94, 0.35, 0.62 * alpha), 4.0, true)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value as Vector2 if value is Vector2 else fallback
