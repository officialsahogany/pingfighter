extends RefCounted


func draw_labels(
	canvas: Node2D,
	bar_center_x: float,
	bar_y: float,
	bar_h: float,
	display_combo: int,
	in_grace: bool,
	safe_scale: float,
	combo_color: Color,
	glow_color: Color
) -> void:
	var num_text: String = str(max(0, display_combo))
	var num_size: int = max(14, int(22.0 * safe_scale))
	var num_center: Vector2 = Vector2(bar_center_x, bar_y - 13.0 * safe_scale)
	_draw_centered_text_with_outline(canvas, num_center, num_text, num_size, combo_color, 1.0, Color.BLACK, max(1, int(2.0 * safe_scale)))
	_draw_centered_text_with_outline(canvas, Vector2(bar_center_x, bar_y + bar_h + 10.0 * safe_scale), "COMBO", max(8, int(10.0 * safe_scale)), glow_color, 0.95, Color.BLACK, 1)
	if in_grace:
		_draw_centered_text_with_outline(canvas, Vector2(bar_center_x, bar_y + bar_h + 24.0 * safe_scale), "GRACE", max(8, int(10.0 * safe_scale)), Color(1.0, 220.0 / 255.0, 120.0 / 255.0), 0.95, Color.BLACK, 1)


func _draw_centered_text_with_outline(
	canvas: Node2D,
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
