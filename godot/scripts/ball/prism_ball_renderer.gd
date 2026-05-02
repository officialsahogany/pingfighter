extends RefCounted

const BALL_SIZE := 28.6

const PRISM_BALL_COLORS: Array[Color] = [
	Color(1.0, 0.0, 0.0),
	Color(1.0, 127.0 / 255.0, 0.0),
	Color(1.0, 1.0, 0.0),
	Color(0.0, 1.0, 0.0),
	Color(0.0, 127.0 / 255.0, 1.0),
	Color(0.0, 0.0, 1.0),
	Color(127.0 / 255.0, 0.0, 1.0),
]


func draw(canvas: CanvasItem, pos: Vector2) -> void:
	var prism_time: float = float(Time.get_ticks_msec()) * 0.003
	var prism_center_radius: float = BALL_SIZE * 0.5

	for ring_idx in range(3):
		var ring_angle_offset: float = float(ring_idx) * 45.0
		var ring_tilt: float = 20.0 + float(ring_idx) * 20.0
		var ring_radius: float = prism_center_radius + 8.0 + float(ring_idx) * 6.0

		for point_idx in range(28):
			var angle_deg: float = prism_time * 80.0 + ring_angle_offset + float(point_idx) * (360.0 / 28.0)
			var angle: float = deg_to_rad(angle_deg)
			var tilt_rad: float = deg_to_rad(ring_tilt)
			var x_offset: float = cos(angle) * ring_radius
			var y_offset: float = sin(angle) * ring_radius * cos(tilt_rad)
			var z_depth: float = sin(angle) * sin(tilt_rad)
			var depth_factor: float = (z_depth + 1.0) * 0.5
			var color_index: int = int(fmod(float(point_idx) + prism_time * 10.0 + float(ring_idx) * 2.0, float(PRISM_BALL_COLORS.size())))
			var color: Color = PRISM_BALL_COLORS[color_index]
			var point_alpha: float = (80.0 + depth_factor * 150.0) / 255.0
			var point_size: float = max(2.0, floor(2.0 + depth_factor * 3.0))
			canvas.draw_circle(pos + Vector2(x_offset, y_offset), point_size, Color(color.r, color.g, color.b, point_alpha))

	var core_color_index: int = int(fmod(prism_time * 30.0, float(PRISM_BALL_COLORS.size())))
	var core_color: Color = PRISM_BALL_COLORS[core_color_index]
	canvas.draw_circle(pos, prism_center_radius + 5.0, Color(core_color.r, core_color.g, core_color.b, 40.0 / 255.0))
	canvas.draw_circle(pos, prism_center_radius, Color(1.0, 1.0, 1.0, 80.0 / 255.0))
	canvas.draw_circle(pos, prism_center_radius * 0.5, Color(1.0, 1.0, 1.0, 200.0 / 255.0))
	canvas.draw_circle(pos + Vector2(-4.0, -4.0), 3.0, Color(1.0, 1.0, 1.0))
