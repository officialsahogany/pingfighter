extends RefCounted


func draw_knee_pads_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	flash_center: Vector2,
	flash_timer_frames: float,
	particles: Array,
	flash_duration_frames: float,
	particle_render_limit: int,
	ring_segments: int
) -> void:
	if canvas == null:
		return
	var center: Vector2 = flash_center + shake_offset
	if flash_timer_frames > 0.0:
		var progress: float = 1.0 - clamp(flash_timer_frames / flash_duration_frames, 0.0, 1.0)
		var alpha: float = clamp(flash_timer_frames / flash_duration_frames, 0.0, 1.0)
		for ring_index in range(3):
			var radius: float = 16.0 + progress * 74.0 + float(ring_index) * 13.0
			var ring_alpha: float = max(0.0, alpha * (0.62 - float(ring_index) * 0.13))
			canvas.draw_arc(center, radius, 0.0, TAU, ring_segments, Color(1.0, 0.86, 0.12, ring_alpha), 3.0, true)
		for ray_index in range(8):
			var angle: float = float(ray_index) / 8.0 * TAU + progress * 1.7
			var ray_len: float = 24.0 + progress * 48.0
			var start_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * 10.0
			var end_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * ray_len
			canvas.draw_line(start_pos, end_pos, Color(1.0, 0.93, 0.28, alpha * 0.55), 4.0, true)
			canvas.draw_line(start_pos, end_pos, Color(1.0, 1.0, 1.0, alpha * 0.35), 1.3, true)
		canvas.draw_circle(center, 30.0 * alpha + 6.0, Color(1.0, 0.86, 0.0, alpha * 0.24))
		canvas.draw_circle(center, 7.0 + 6.0 * (1.0 - progress), Color.WHITE, alpha * 0.88)

	for particle_index in range(_recent_start(particles, particle_render_limit), particles.size()):
		var particle: Dictionary = _as_dict(particles[particle_index])
		var life: float = max(0.0, float(particle.get("life", 0.0)))
		var max_life: float = max(0.1, float(particle.get("max_life", 30.0)))
		var particle_alpha: float = clamp(life / max_life, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 2.0)))
		var color: Color = _as_color(particle.get("color", Color(1.0, 0.78, 0.0)), Color(1.0, 0.78, 0.0))
		color.a = particle_alpha
		canvas.draw_circle(pos, size * 2.1, Color(color.r, color.g, color.b, particle_alpha * 0.18))
		canvas.draw_circle(pos, size, color)


func draw_soul_burst_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	center_base: Vector2,
	dash_direction: float,
	wind_trails: Array,
	shockwaves: Array,
	particles: Array,
	alpha_cutoff: float,
	wind_trail_render_limit: int,
	shockwave_render_limit: int,
	particle_render_limit: int,
	ellipse_segments: int
) -> void:
	if canvas == null:
		return
	var center: Vector2 = center_base + shake_offset
	var direction: float = dash_direction
	if abs(direction) <= 0.01:
		direction = 1.0

	for trail_index in range(_recent_start(wind_trails, wind_trail_render_limit), wind_trails.size()):
		var trail: Dictionary = _as_dict(wind_trails[trail_index])
		var life: float = float(trail.get("life", 0.0))
		var max_life: float = max(0.1, float(trail.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= alpha_cutoff:
			continue
		var offset: Vector2 = _as_vector2(trail.get("offset", Vector2.ZERO), Vector2.ZERO)
		var length: float = float(trail.get("length", 60.0))
		var base: Vector2 = center + offset
		var start_pos: Vector2 = base - Vector2(direction * length, 0.0)
		var end_pos: Vector2 = base + Vector2(direction * length * 0.26, 0.0)
		var width: float = float(trail.get("width", 2.0))
		canvas.draw_line(start_pos, end_pos, Color(42.0 / 255.0, 0.0, 72.0 / 255.0, 0.22 * alpha), width + 5.0, true)
		canvas.draw_line(start_pos, end_pos, Color(180.0 / 255.0, 86.0 / 255.0, 1.0, 0.58 * alpha), width + 1.2, true)
		canvas.draw_line(start_pos.lerp(end_pos, 0.38), end_pos, Color(245.0 / 255.0, 220.0 / 255.0, 1.0, 0.42 * alpha), max(1.0, width * 0.45), true)

	for wave_index in range(_recent_start(shockwaves, shockwave_render_limit), shockwaves.size()):
		var wave: Dictionary = _as_dict(shockwaves[wave_index])
		var life: float = float(wave.get("life", 0.0))
		var max_life: float = max(0.1, float(wave.get("max_life", 1.0)))
		var progress: float = 1.0 - clamp(life / max_life, 0.0, 1.0)
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= alpha_cutoff:
			continue
		var radius: float = lerp(float(wave.get("start_radius", 20.0)), float(wave.get("max_radius", 92.0)), progress)
		var squeeze: float = float(wave.get("squeeze", 0.72))
		var ring_color := Color(165.0 / 255.0, 72.0 / 255.0, 1.0, 0.62 * alpha)
		canvas.draw_arc(center, radius, 0.0, TAU, ellipse_segments, Color(45.0 / 255.0, 0.0, 80.0 / 255.0, 0.18 * alpha), 7.0, true)
		draw_soul_burst_ellipse_arc(canvas, center, radius, radius * squeeze, ring_color, 3.0, ellipse_segments)
		draw_soul_burst_ellipse_arc(canvas, center, radius * 0.74, radius * squeeze * 0.74, Color(1.0, 230.0 / 255.0, 1.0, 0.35 * alpha), 1.2, ellipse_segments)

	for particle_index in range(_recent_start(particles, particle_render_limit), particles.size()):
		var particle_value = particles[particle_index]
		var particle: Dictionary = _as_dict(particle_value)
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(0.1, float(particle.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= alpha_cutoff:
			continue
		var pos: Vector2 = _as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 2.0)))
		var color: Color = _as_color(particle.get("color", Color(0.72, 0.32, 1.0, 1.0)), Color(0.72, 0.32, 1.0, 1.0))
		canvas.draw_circle(pos, size * 2.2, Color(color.r, color.g, color.b, 0.18 * alpha))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, color.a * alpha))
		canvas.draw_circle(pos, max(1.0, size * 0.38), Color(1.0, 0.88, 1.0, 0.68 * alpha))


func draw_soul_burst_ellipse_arc(
	canvas: CanvasItem,
	center: Vector2,
	radius_x: float,
	radius_y: float,
	color: Color,
	width: float,
	ellipse_segments: int
) -> void:
	if canvas == null:
		return
	var points := PackedVector2Array()
	for idx in range(ellipse_segments + 1):
		var angle: float = TAU * float(idx) / float(ellipse_segments)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	canvas.draw_polyline(points, color, width, true)


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


func _recent_start(source: Array, render_limit: int) -> int:
	if render_limit < 0:
		return 0
	return max(0, source.size() - max(0, render_limit))
