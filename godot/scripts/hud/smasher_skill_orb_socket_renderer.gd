extends RefCounted

const READY_GLOW_FILL_LAYER_COUNT := 3
const READY_GLOW_LIGHT_POINT_COUNT := 3
const ACTIVATION_FLASH_LAYER_COUNT := 1


func draw_socket(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	socket_overlap: float,
	bg_color: Color,
	border_color: Color
) -> void:
	var socket_radius: float = icon_radius + socket_overlap
	canvas.draw_circle(center, socket_radius, bg_color)
	canvas.draw_circle(center, socket_radius, border_color, false, 1.0)


func draw_activation_flash(
	canvas: CanvasItem,
	center: Vector2,
	icon_radius: float,
	scale_factor: float,
	progress: float,
	skill_color: Color
) -> void:
	var glow_alpha: float = 0.70 * (1.0 - progress)
	var glow_radius: float = icon_radius + 8.0 * (1.0 - progress) * scale_factor
	for layer_index in range(ACTIVATION_FLASH_LAYER_COUNT):
		var layer_offset: float = 2.0 - float(layer_index) * 2.0
		var layer_alpha: float = 0.38 - float(layer_index) * 0.16
		canvas.draw_circle(center, glow_radius + layer_offset, Color(skill_color.r, skill_color.g, skill_color.b, glow_alpha * max(0.0, layer_alpha)))


func draw_ready_glow(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	t: float,
	phase_offset: float,
	color: Color
) -> void:
	var pulse: float = 0.5 + 0.5 * sin(t * 4.2 + phase_offset)
	for layer_index in range(READY_GLOW_FILL_LAYER_COUNT):
		var layer_ratio: float = float(layer_index) / float(READY_GLOW_FILL_LAYER_COUNT - 1)
		var drift := Vector2(
			cos(t * 1.3 + phase_offset + float(layer_index) * 2.1),
			sin(t * 1.1 + phase_offset + float(layer_index) * 1.7)
		) * (2.0 + layer_ratio * 2.4)
		var layer_radius: float = radius + 8.5 - layer_ratio * 5.0 + pulse * (1.2 - layer_ratio * 0.5)
		var layer_alpha: float = 0.045 + layer_ratio * 0.035
		canvas.draw_circle(
			center + drift,
			layer_radius,
			Color(color.r, color.g, color.b, layer_alpha)
		)
	canvas.draw_circle(
		center,
		radius + 1.5,
		Color(1.0, 0.96, 0.72, 0.055 + pulse * 0.035)
	)
	for point_index in range(READY_GLOW_LIGHT_POINT_COUNT):
		var angle: float = t * (0.75 + float(point_index) * 0.13) + phase_offset + float(point_index) * 2.37
		var point_center := center + Vector2.from_angle(angle) * (radius + 5.0 + sin(t * 1.8 + float(point_index)) * 2.0)
		var point_alpha: float = 0.48 + 0.24 * sin(t * 3.7 + float(point_index) * 1.9)
		canvas.draw_circle(point_center, 2.5 + pulse * 0.7, Color(color.r, color.g, color.b, point_alpha * 0.32))
		canvas.draw_circle(point_center, 1.15 + pulse * 0.25, Color(1.0, 0.98, 0.78, point_alpha))
