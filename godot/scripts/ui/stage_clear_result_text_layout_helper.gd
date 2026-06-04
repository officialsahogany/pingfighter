extends RefCounted


static func get_centered_baseline(font: Font, text: String, rect: Rect2, font_size: int) -> Vector2:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	return Vector2(
		rect.position.x + (rect.size.x - text_size.x) * 0.5,
		rect.position.y + rect.size.y * 0.5 + text_size.y * 0.35
	)


static func wrap_words_to_width(font: Font, text: String, font_size: int, max_width: float, max_lines: int) -> Array[String]:
	var result: Array[String] = []
	var paragraphs: PackedStringArray = text.split("\n", false)
	for paragraph in paragraphs:
		var words: PackedStringArray = str(paragraph).split(" ", false)
		var line := ""
		for word in words:
			var candidate: String = word if line == "" else "%s %s" % [line, word]
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width or line == "":
				line = candidate
			else:
				result.append(line)
				line = word
				if result.size() >= max_lines:
					return result
		if line != "":
			result.append(line)
			if result.size() >= max_lines:
				return result
	return result


static func fit_font_size(font: Font, text: String, max_width: float, preferred_size: int, min_size: int) -> int:
	var fitted_size: int = max(min_size, preferred_size)
	while fitted_size > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size).x > max_width:
		fitted_size -= 1
	return fitted_size


static func draw_text(
	canvas: CanvasItem,
	font: Font,
	text: String,
	baseline: Vector2,
	font_size: int,
	color: Color,
	shadow_alpha: float = 0.62
) -> void:
	if canvas == null or font == null or text == "":
		return
	if shadow_alpha > 0.001:
		canvas.draw_string(
			font,
			baseline + Vector2(2.0, 2.0),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			Color(0.0, 0.0, 0.0, color.a * shadow_alpha)
		)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


static func draw_centered_text(
	canvas: CanvasItem,
	font: Font,
	text: String,
	rect: Rect2,
	font_size: int,
	color: Color,
	shadow_alpha: float = 0.62
) -> void:
	draw_text(
		canvas,
		font,
		text,
		get_centered_baseline(font, text, rect, font_size),
		font_size,
		color,
		shadow_alpha
	)


static func draw_wrapped_text(
	canvas: CanvasItem,
	font: Font,
	text: String,
	baseline: Vector2,
	font_size: int,
	color: Color,
	max_width: float,
	max_lines: int,
	line_height: float,
	shadow_alpha: float = 0.62
) -> void:
	if canvas == null or font == null or text == "" or max_width <= 0.0 or max_lines <= 0:
		return
	var lines: Array[String] = wrap_words_to_width(font, text, font_size, max_width, max_lines)
	for i in range(lines.size()):
		var line: String = str(lines[i])
		var fitted_size: int = fit_font_size(font, line, max_width, font_size, max(9, int(round(font_size * 0.76))))
		draw_text(canvas, font, line, baseline + Vector2(0.0, float(i) * line_height), fitted_size, color, shadow_alpha)
