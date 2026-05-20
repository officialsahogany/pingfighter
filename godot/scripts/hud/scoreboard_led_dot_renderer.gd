extends RefCounted

const LIT_GLOW_LAYERS := 1


func draw_premium_led(
	canvas: Node2D,
	center: Vector2,
	color: Color,
	size: float,
	intensity: float,
	is_on: bool,
	alpha: float
) -> void:
	if is_on:
		_draw_lit_dot(canvas, center, color, size, intensity, alpha)
	else:
		_draw_dim_dot(canvas, center, color, size, alpha)


func _draw_lit_dot(canvas: Node2D, center: Vector2, color: Color, size: float, intensity: float, alpha: float) -> void:
	for glow_idx in range(LIT_GLOW_LAYERS, 0, -1):
		var glow_radius: float = size + float(glow_idx) * 3.0
		var glow_alpha: float = (34.0 / 255.0) * intensity / float(glow_idx) * alpha
		canvas.draw_circle(center, glow_radius, Color(color.r, color.g, color.b, glow_alpha))
	canvas.draw_circle(center, size, _alpha_color(color, alpha))


func _draw_dim_dot(_canvas: Node2D, _center: Vector2, _color: Color, _size: float, _alpha: float) -> void:
	return


func _alpha_color(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clamp(alpha, 0.0, 1.0))


func _rgb(r: float, g: float, b: float, alpha: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, clamp(alpha, 0.0, 1.0))


func _brighten_color(color: Color, amount: float) -> Color:
	return Color(
		min(1.0, color.r + amount),
		min(1.0, color.g + amount),
		min(1.0, color.b + amount),
		color.a
	)
