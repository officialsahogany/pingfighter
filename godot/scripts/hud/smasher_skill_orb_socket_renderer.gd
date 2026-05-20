extends RefCounted

const READY_RING_ARC_POINTS := 14
const READY_RING_SWEEP_POINTS := 6
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


func draw_ready_ring(canvas: CanvasItem, center: Vector2, radius: float, t: float, phase_offset: float, color: Color) -> void:
	var pulse: float = 0.5 + 0.5 * sin(t * 5.4 + phase_offset)
	var ring_radius: float = radius + 4.0 + pulse * 1.5
	canvas.draw_arc(center, ring_radius, 0.0, TAU, READY_RING_ARC_POINTS, Color(color.r, color.g, color.b, 0.22 + 0.24 * pulse), 1.5)
	var sweep: float = TAU * 0.26
	var start: float = t * 2.6 + phase_offset
	canvas.draw_arc(center, ring_radius + 1.0, start, start + sweep, READY_RING_SWEEP_POINTS, Color(1.0, 1.0, 0.78, 0.72), 2.0)
	canvas.draw_arc(center, ring_radius + 1.0, start + PI, start + PI + sweep, READY_RING_SWEEP_POINTS, Color(0.36, 0.86, 1.0, 0.56), 2.0)
