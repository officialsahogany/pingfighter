extends RefCounted


func draw_score_text(
	canvas: CanvasItem,
	center: Vector2,
	text: String,
	font_size: int,
	color: Color,
	shadow_color: Color,
	glow_color: Color,
	glow_strength: float
) -> void:
	if glow_strength > 0.0:
		for glow_radius in range(4, 0, -1):
			var glow_alpha: float = clamp(glow_strength, 0.0, 1.5) * (45.0 / 255.0) / float(glow_radius)
			var layer_color: Color = Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha)
			for offset in [
				Vector2(-float(glow_radius), 0.0),
				Vector2(float(glow_radius), 0.0),
				Vector2(0.0, -float(glow_radius)),
				Vector2(0.0, float(glow_radius)),
			]:
				_draw_text_centered(canvas, center + offset, text, font_size, layer_color, 1.0)
	_draw_text_centered(canvas, center + Vector2(2.0, 2.0), text, font_size, shadow_color, 1.0)
	_draw_text_centered(canvas, center, text, font_size, color, 1.0)


func _draw_text_centered(canvas: CanvasItem, center: Vector2, text: String, font_size: int, color: Color, alpha: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, _alpha_color(color, alpha))


func _alpha_color(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clamp(alpha, 0.0, 1.0))
