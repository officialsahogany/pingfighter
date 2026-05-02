extends RefCounted


func draw(
	canvas: CanvasItem,
	draw_center: Vector2,
	combo: int,
	progress: float,
	scale: float,
	base_color: Color,
	alpha: float
) -> void:
	var font_size: int = int(36.0 * scale + float(combo) * 4.0)
	var combo_text: String = "%dCOMBO!" % combo
	var outline_width: int = 2 if combo < 5 else 3
	_draw_centered_text_with_outline(canvas, draw_center + Vector2(4.0, 5.0), combo_text, font_size, Color(0.0, 0.0, 0.0, 0.72), alpha * 0.72, Color.BLACK, 1)
	if combo >= 3:
		_draw_centered_text_with_outline(canvas, draw_center, combo_text, font_size, Color.WHITE, alpha * 0.88, Color.WHITE, outline_width)
	_draw_centered_text_with_outline(canvas, draw_center, combo_text, font_size, base_color, alpha, Color.BLACK, outline_width + 1)
	if combo >= 5 and progress < 0.34:
		_draw_centered_text_with_outline(canvas, draw_center + Vector2(-1.5, -1.5), combo_text, font_size, Color(1.0, 1.0, 1.0, 0.45), alpha * 0.42, Color(1.0, 1.0, 1.0, 0.12), 1)


func _draw_centered_text_with_outline(
	canvas: CanvasItem,
	center: Vector2,
	text: String,
	font_size: int,
	color: Color,
	alpha: float,
	outline_color: Color = Color.BLACK,
	outline_width: int = 1
) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)
	var clamped_alpha: float = clamp(alpha, 0.0, 1.0)
	for ox in range(-outline_width, outline_width + 1):
		for oy in range(-outline_width, outline_width + 1):
			if ox == 0 and oy == 0:
				continue
			if abs(ox) + abs(oy) > outline_width + 1:
				continue
			canvas.draw_string(
				font,
				baseline + Vector2(float(ox), float(oy)),
				text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size,
				Color(outline_color.r, outline_color.g, outline_color.b, outline_color.a * clamped_alpha)
			)
	canvas.draw_string(
		font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color(color.r, color.g, color.b, color.a * clamped_alpha)
	)
