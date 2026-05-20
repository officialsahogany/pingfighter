extends RefCounted

const BALL_VISUAL_SCALE := 1.575
const BALL_SIZE := 28.6 * BALL_VISUAL_SCALE
const PRISM_CORE_SCALE := 1.50
const PRISM_CORE_GLOW_SCALE := 1.83
const PRISM_CORE_MAIN_COLOR := Color(0.78, 0.96, 1.0, 0.92)
const PRISM_CORE_CYAN_COLOR := Color(0.58, 1.0, 0.94, 0.36)
const PRISM_CORE_VIOLET_COLOR := Color(0.80, 0.72, 1.0, 0.34)
const PRISM_CORE_HIGHLIGHT_COLOR := Color(0.86, 0.99, 1.0, 0.94)

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
			var point_size: float = max(2.0 * BALL_VISUAL_SCALE, floor((2.0 + depth_factor * 3.0) * BALL_VISUAL_SCALE))
			canvas.draw_circle(pos + Vector2(x_offset, y_offset), point_size, Color(color.r, color.g, color.b, point_alpha))

	var core_color_index: int = int(fmod(prism_time * 30.0, float(PRISM_BALL_COLORS.size())))
	var core_color: Color = PRISM_BALL_COLORS[core_color_index]
	var core_radius: float = prism_center_radius * PRISM_CORE_SCALE
	var chroma_offset: Vector2 = Vector2(cos(prism_time * 2.1), sin(prism_time * 1.7)) * core_radius * 0.12
	canvas.draw_circle(pos, prism_center_radius + 5.0, Color(core_color.r, core_color.g, core_color.b, 40.0 / 255.0))
	canvas.draw_circle(pos, prism_center_radius * PRISM_CORE_GLOW_SCALE, Color(0.50, 0.80, 1.0, 0.15))
	canvas.draw_circle(pos, core_radius, PRISM_CORE_MAIN_COLOR)
	canvas.draw_circle(pos + chroma_offset, core_radius * 0.70, PRISM_CORE_CYAN_COLOR)
	canvas.draw_circle(pos - chroma_offset * 0.75, core_radius * 0.56, PRISM_CORE_VIOLET_COLOR)
	canvas.draw_circle(pos + Vector2(-4.0, -4.0) * BALL_VISUAL_SCALE, max(3.0 * BALL_VISUAL_SCALE, core_radius * 0.28), PRISM_CORE_HIGHLIGHT_COLOR)
