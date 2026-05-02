extends RefCounted

const LIT_GLOW_LAYERS := 2


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
		var glow_alpha: float = (46.0 / 255.0) * intensity / float(glow_idx) * alpha
		canvas.draw_circle(center, glow_radius, Color(color.r, color.g, color.b, glow_alpha))
	canvas.draw_circle(center, size, _alpha_color(color, alpha))
	canvas.draw_circle(center + Vector2(-size / 3.0, -size / 3.0), max(1.0, size / 3.0), _alpha_color(_brighten_color(color, 145.0 / 255.0), alpha))


func _draw_dim_dot(canvas: Node2D, center: Vector2, color: Color, size: float, alpha: float) -> void:
	var dim_color := Color(max(10.0 / 255.0, color.r / 12.0), max(10.0 / 255.0, color.g / 12.0), max(10.0 / 255.0, color.b / 12.0))
	canvas.draw_circle(center, max(1.0, size - 1.0), _alpha_color(dim_color, alpha))


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
