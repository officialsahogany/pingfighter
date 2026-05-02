extends RefCounted


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
	canvas.draw_circle(center, glow_radius + 2.0, Color(skill_color.r, skill_color.g, skill_color.b, glow_alpha * 0.38))
	canvas.draw_circle(center, glow_radius, Color(skill_color.r, skill_color.g, skill_color.b, glow_alpha * 0.22))


func draw_ready_ring(canvas: CanvasItem, center: Vector2, radius: float, t: float, phase_offset: float, color: Color) -> void:
	var pulse: float = 0.5 + 0.5 * sin(t * 5.4 + phase_offset)
	var ring_radius: float = radius + 4.0 + pulse * 1.5
	canvas.draw_arc(center, ring_radius, 0.0, TAU, 36, Color(color.r, color.g, color.b, 0.22 + 0.24 * pulse), 1.5)
	var sweep: float = TAU * 0.26
	var start: float = t * 2.6 + phase_offset
	canvas.draw_arc(center, ring_radius + 1.0, start, start + sweep, 18, Color(1.0, 1.0, 0.78, 0.72), 2.0)
	canvas.draw_arc(center, ring_radius + 1.0, start + PI, start + PI + sweep, 18, Color(0.36, 0.86, 1.0, 0.56), 2.0)
