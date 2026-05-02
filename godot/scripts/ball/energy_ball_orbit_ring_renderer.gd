extends RefCounted


func draw_ring(
	canvas: CanvasItem,
	pos: Vector2,
	time_seconds: float,
	ball_ring_color: Color,
	ball_inner_color: Color,
	ring_rotation: float,
	ring_tilt: float,
	ring_radius: float,
	ring_idx: int
) -> void:
	var orbit_points: PackedVector2Array = PackedVector2Array()
	for point_idx in range(24):
		var angle_deg: float = ring_rotation + float(point_idx) * (360.0 / 24.0)
		var angle: float = deg_to_rad(angle_deg)
		var tilt_rad: float = deg_to_rad(ring_tilt)
		var x_offset: float = cos(angle) * ring_radius
		var y_offset: float = sin(angle) * ring_radius * cos(tilt_rad)
		var z_depth: float = sin(angle) * sin(tilt_rad)
		var depth_factor: float = (z_depth + 1.0) * 0.5
		var orbit_pos: Vector2 = pos + Vector2(x_offset, y_offset)
		var point_radius: float = max(1.0, floor(1.7 + depth_factor * 1.3))
		var ring_color: Color = _get_ring_point_color(ball_ring_color, depth_factor, ring_idx)
		orbit_points.append(orbit_pos)
		canvas.draw_circle(orbit_pos, point_radius, ring_color)

	_draw_ring_lines(canvas, orbit_points, ball_ring_color)
	_draw_bright_points(canvas, pos, time_seconds, ball_inner_color, ring_rotation, ring_tilt, ring_radius)


func _get_ring_point_color(ball_ring_color: Color, depth_factor: float, ring_idx: int) -> Color:
	return Color(
		clamp(ball_ring_color.r * 0.3 + depth_factor * ball_ring_color.r * 0.7 + float(ring_idx) * 0.02, 0.0, 1.0),
		clamp(ball_ring_color.g * 0.3 + depth_factor * ball_ring_color.g * 0.7 + float(ring_idx) * 0.04, 0.0, 1.0),
		clamp(ball_ring_color.b * 0.3 + depth_factor * ball_ring_color.b * 0.7, 0.0, 1.0),
		(15.0 + depth_factor * 35.0) / 255.0
	)


func _draw_ring_lines(canvas: CanvasItem, orbit_points: PackedVector2Array, ball_ring_color: Color) -> void:
	if orbit_points.size() <= 2:
		return
	for point_idx in range(orbit_points.size()):
		var start: Vector2 = orbit_points[point_idx]
		var next_index: int = (point_idx + 1) % orbit_points.size()
		var end: Vector2 = orbit_points[next_index]
		canvas.draw_line(start, end, Color(ball_ring_color.r, ball_ring_color.g, ball_ring_color.b, 10.0 / 255.0), 1.0)


func _draw_bright_points(
	canvas: CanvasItem,
	pos: Vector2,
	time_seconds: float,
	ball_inner_color: Color,
	ring_rotation: float,
	ring_tilt: float,
	ring_radius: float
) -> void:
	for bright_idx in range(3):
		var bright_angle_deg: float = ring_rotation + float(bright_idx) * 120.0
		var bright_angle: float = deg_to_rad(bright_angle_deg)
		var tilt_rad: float = deg_to_rad(ring_tilt)
		var x_offset: float = cos(bright_angle) * ring_radius
		var y_offset: float = sin(bright_angle) * ring_radius * cos(tilt_rad)
		var z_depth: float = sin(bright_angle) * sin(tilt_rad)
		if z_depth > -0.3:
			var bright_pos: Vector2 = pos + Vector2(x_offset, y_offset)
			var bright_pulse: float = (sin(time_seconds * 10.0 + float(bright_idx)) + 1.0) * 0.5
			var bright_size: float = 0.72 + bright_pulse * 0.85
			var bright_alpha: float = (40.0 + bright_pulse * 35.0) / 255.0
			canvas.draw_circle(bright_pos, bright_size + 1.0, Color(ball_inner_color.r, ball_inner_color.g, ball_inner_color.b, bright_alpha * 0.5))
			canvas.draw_circle(bright_pos, bright_size, Color(150.0 / 255.0, 210.0 / 255.0, 1.0, bright_alpha))
