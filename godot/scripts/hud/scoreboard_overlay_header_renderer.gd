extends RefCounted


func draw(canvas: CanvasItem, header_rect: Rect2, alpha: float) -> void:
	canvas.draw_rect(header_rect, _rgb(10.0, 25.0, 50.0, alpha))
	canvas.draw_rect(header_rect, _rgb(80.0, 140.0, 220.0, alpha), false, 2.0)

	var p_logo := Vector2(header_rect.position.x + 50.0, header_rect.position.y + 30.0)
	var b_logo := Vector2(header_rect.position.x + header_rect.size.x - 50.0, header_rect.position.y + 30.0)
	for glow_idx in range(4, 0, -1):
		var glow_alpha: float = (50.0 / 255.0) / float(glow_idx) * alpha
		canvas.draw_circle(p_logo, 22.0 + float(glow_idx) * 4.0, _rgb(50.0, 120.0, 200.0, glow_alpha))
		canvas.draw_circle(b_logo, 22.0 + float(glow_idx) * 4.0, _rgb(200.0, 80.0, 80.0, glow_alpha))

	canvas.draw_circle(p_logo, 22.0, _rgb(30.0, 80.0, 180.0, alpha))
	canvas.draw_circle(p_logo, 18.0, _rgb(80.0, 140.0, 255.0, alpha))
	canvas.draw_circle(p_logo, 14.0, _rgb(120.0, 180.0, 255.0, alpha))
	canvas.draw_circle(b_logo, 22.0, _rgb(180.0, 50.0, 50.0, alpha))
	canvas.draw_circle(b_logo, 18.0, _rgb(255.0, 100.0, 100.0, alpha))
	canvas.draw_circle(b_logo, 14.0, _rgb(255.0, 140.0, 140.0, alpha))

	_draw_text_centered(canvas, p_logo, "P", 22, Color.WHITE, alpha)
	_draw_text_centered(canvas, b_logo, "B", 22, Color.WHITE, alpha)
	_draw_text_left(canvas, Vector2(header_rect.position.x + 85.0, header_rect.position.y + 38.0), "PLAYER", 20, _rgb(100.0, 180.0, 255.0, 1.0), alpha)
	_draw_text_right(canvas, Vector2(header_rect.position.x + header_rect.size.x - 85.0, header_rect.position.y + 38.0), "BOSS", 20, _rgb(255.0, 120.0, 120.0, 1.0), alpha)


func _draw_text_centered(canvas: CanvasItem, center: Vector2, text: String, font_size: int, color: Color, alpha: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, _alpha_color(color, alpha))


func _draw_text_left(canvas: CanvasItem, pos: Vector2, text: String, font_size: int, color: Color, alpha: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, _alpha_color(color, alpha))


func _draw_text_right(canvas: CanvasItem, right_top: Vector2, text: String, font_size: int, color: Color, alpha: float) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	canvas.draw_string(
		font,
		Vector2(right_top.x - text_size.x, right_top.y),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		_alpha_color(color, alpha)
	)


func _alpha_color(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * clamp(alpha, 0.0, 1.0))


func _rgb(r: float, g: float, b: float, alpha: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, clamp(alpha, 0.0, 1.0))
