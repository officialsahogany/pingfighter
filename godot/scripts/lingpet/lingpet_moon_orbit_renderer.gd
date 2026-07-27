extends RefCounted


func prewarm() -> void:
	pass


func draw_moon_orbit(
	canvas: CanvasItem,
	shake_offset: Vector2,
	visual_time_seconds: float,
	projectile_active: bool,
	projectile_pos: Vector2,
	projectile_vel: Vector2,
	projectile_radius: float,
	trail: Array[Vector2],
	orbit_active: bool,
	orbit_pos: Vector2,
	orbit_timer: float,
	orbit_duration: float,
	orbit_seed: int,
	orbit_half_width: float,
	orbit_half_height: float,
	orbit_drop_y: float,
	burst_timer: float,
	burst_duration: float,
	particles: Array
) -> void:
	if canvas == null:
		return
	if orbit_active:
		_draw_orbit_field(
			canvas,
			orbit_pos + shake_offset,
			visual_time_seconds,
			orbit_timer,
			orbit_duration,
			orbit_seed,
			orbit_half_width,
			orbit_half_height
		)
	if not particles.is_empty():
		_draw_particles(canvas, particles, shake_offset)
	if burst_timer > 0.0:
		_draw_burst(canvas, orbit_pos - Vector2(0.0, orbit_drop_y) + shake_offset, burst_timer, burst_duration)
	if projectile_active:
		_draw_projectile(canvas, projectile_pos + shake_offset, projectile_vel, projectile_radius, trail, shake_offset)


func get_ellipse_points_for_tests(
	center: Vector2,
	rx: float,
	ry: float,
	segments: int,
	closed: bool
) -> PackedVector2Array:
	if rx <= 0.5 or ry <= 0.5 or segments < 3:
		return PackedVector2Array()
	var points := PackedVector2Array()
	var point_count := segments + 1 if closed else segments
	for index in range(point_count):
		var angle: float = TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


func _draw_projectile(
	canvas: CanvasItem,
	pos: Vector2,
	projectile_vel: Vector2,
	projectile_radius: float,
	trail: Array[Vector2],
	shake_offset: Vector2
) -> void:
	for index in range(trail.size()):
		var trail_pos: Vector2 = trail[index] + shake_offset
		var ratio: float = float(index + 1) / float(maxi(1, trail.size()))
		canvas.draw_circle(trail_pos, lerpf(2.0, 5.0, ratio), Color(0.72, 0.48, 1.0, 0.10 + 0.26 * ratio))
		if index > 0:
			var prev_pos: Vector2 = trail[index - 1] + shake_offset
			canvas.draw_line(prev_pos, trail_pos, Color(0.96, 0.82, 1.0, 0.34 * ratio), maxf(1.0, 2.6 * ratio), true)

	var direction: Vector2 = projectile_vel.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2(0.0, -1.0)
	var side: Vector2 = direction.orthogonal()
	var core_points := PackedVector2Array([
		pos + direction * 18.0 + side * 2.0,
		pos + side * 11.0,
		pos - direction * 12.0 + side * 3.0,
		pos - direction * 17.0 - side * 2.0,
		pos - side * 10.0,
	])
	canvas.draw_colored_polygon(core_points, Color(0.56, 0.32, 1.0, 0.84))
	canvas.draw_polyline(PackedVector2Array([core_points[0], core_points[1], core_points[2], core_points[3], core_points[4], core_points[0]]), Color(0.92, 0.78, 1.0, 0.92), 1.5, true)
	canvas.draw_circle(pos, projectile_radius + 6.0, Color(0.62, 0.36, 1.0, 0.18))


func _draw_orbit_field(
	canvas: CanvasItem,
	center: Vector2,
	visual_time_seconds: float,
	orbit_timer: float,
	orbit_duration: float,
	orbit_seed: int,
	orbit_half_width: float,
	orbit_half_height: float
) -> void:
	var safe_duration := maxf(0.001, orbit_duration)
	var life_ratio: float = clampf(orbit_timer / safe_duration, 0.0, 1.0)
	var appear_lin: float = clampf((safe_duration - orbit_timer) / 0.28, 0.0, 1.0)
	var fade: float = clampf(life_ratio / 0.20, 0.0, 1.0)
	var alpha: float = clampf(appear_lin * fade, 0.0, 1.0)
	if alpha <= 0.01:
		return
	var seed_phase: float = float(orbit_seed) * 0.017
	var pulse: float = 0.92 + 0.08 * sin(visual_time_seconds * 2.1 + seed_phase)
	var rx: float = orbit_half_width * (0.76 + 0.24 * appear_lin)
	var ry: float = orbit_half_height * (0.80 + 0.20 * appear_lin)
	_draw_ellipse_fill(canvas, center, rx, ry, Color(0.18, 0.08, 0.36, alpha * 0.34))
	_draw_ellipse_outline(canvas, center, rx * pulse, ry * pulse, Color(0.72, 0.48, 1.0, alpha * 0.64), 2.0)
	_draw_ellipse_outline(canvas, center, rx * 0.66, ry * 0.55, Color(0.96, 0.82, 1.0, alpha * 0.32), 1.4)
	for index in range(3):
		var phase: float = fmod(visual_time_seconds * (0.28 + index * 0.09) + float(index) * 0.28 + seed_phase, 1.0)
		var arc_center := center + Vector2((phase - 0.5) * rx * 0.42, sin(phase * TAU) * ry * 0.12)
		_draw_crescent_arc(canvas, arc_center, rx * (0.24 + index * 0.05), ry * (0.30 + index * 0.04), phase, Color(0.88, 0.72, 1.0, alpha * (0.38 - index * 0.07)))


func _draw_burst(
	canvas: CanvasItem,
	center: Vector2,
	burst_timer: float,
	burst_duration: float
) -> void:
	var ratio: float = clampf(burst_timer / maxf(0.001, burst_duration), 0.0, 1.0)
	var expansion: float = 1.0 - ratio
	var rx: float = lerpf(30.0, 112.0, expansion)
	var ry: float = lerpf(12.0, 42.0, expansion)
	_draw_ellipse_outline(canvas, center, rx, ry, Color(0.88, 0.70, 1.0, 0.72 * ratio), 2.2)
	_draw_ellipse_fill(canvas, center, rx * 0.62, ry * 0.62, Color(0.46, 0.18, 1.0, 0.20 * ratio))


func _draw_particles(canvas: CanvasItem, particles: Array, shake_offset: Vector2) -> void:
	for particle in particles:
		var max_life: float = maxf(0.01, float(particle["max_life"]))
		var life_t: float = clampf(float(particle["life"]) / max_life, 0.0, 1.0)
		var alpha: float = clampf(life_t * 1.35, 0.0, 1.0)
		if alpha <= 0.02:
			continue
		var pos: Vector2 = (particle["pos"] as Vector2) + shake_offset
		var size: float = float(particle["size"]) * (0.76 + 0.24 * life_t)
		var color := Color(0.90, 0.74, 1.0, alpha * 0.78) if int(particle["kind"]) == 0 else Color(0.68, 0.46, 1.0, alpha * 0.48)
		canvas.draw_circle(pos, size, color)


func _draw_ellipse_fill(canvas: CanvasItem, center: Vector2, rx: float, ry: float, color: Color) -> void:
	if color.a <= 0.0:
		return
	var points := get_ellipse_points_for_tests(center, rx, ry, 48, false)
	if points.size() < 3:
		return
	canvas.draw_colored_polygon(points, color)


func _draw_ellipse_outline(canvas: CanvasItem, center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	if color.a <= 0.0:
		return
	var points := get_ellipse_points_for_tests(center, rx, ry, 64, true)
	if points.size() < 4:
		return
	canvas.draw_polyline(points, color, maxf(1.0, width), true)


func _draw_crescent_arc(canvas: CanvasItem, center: Vector2, rx: float, ry: float, phase: float, color: Color) -> void:
	if rx <= 0.5 or ry <= 0.5 or color.a <= 0.0:
		return
	var points := PackedVector2Array()
	var start_angle: float = -PI * 0.78 + phase * TAU
	var end_angle: float = start_angle + PI * 1.24
	var segments := 20
	for index in range(segments + 1):
		var t: float = float(index) / float(segments)
		var angle: float = lerpf(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	canvas.draw_polyline(points, color, 1.8, true)
