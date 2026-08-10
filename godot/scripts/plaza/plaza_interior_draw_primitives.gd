extends RefCounted


static func draw_text_shadow(
	canvas: CanvasItem,
	font: Font,
	position: Vector2,
	text: String,
	font_size: int,
	color: Color
) -> void:
	if canvas == null or font == null or text == "" or font_size <= 0:
		return
	canvas.draw_string(
		font,
		position + Vector2(1.0, 1.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color(0.0, 0.0, 0.0, minf(0.82, color.a))
	)
	canvas.draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


static func draw_wrapped_text(
	canvas: CanvasItem,
	font: Font,
	position: Vector2,
	text: String,
	max_width: float,
	font_size: int,
	color: Color,
	line_height: float,
	max_lines: int
) -> int:
	var lines := wrap_text(font, text, max_width, font_size, max_lines)
	for index in range(lines.size()):
		draw_text_shadow(canvas, font, position + Vector2(0.0, line_height * float(index)), lines[index], font_size, color)
	return lines.size()


static func draw_button(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	label: String,
	color: Color,
	scale: float
) -> void:
	if canvas == null:
		return
	var scaled_rect := Rect2(rect.position * scale, rect.size * scale)
	canvas.draw_rect(scaled_rect, Color(color.r * 0.08, color.g * 0.08, color.b * 0.08, 0.92), true)
	canvas.draw_rect(scaled_rect, color, false, maxf(1.0, 1.0 * scale))
	if font != null:
		draw_text_shadow(
			canvas,
			font,
			scaled_rect.position + Vector2(21.0, 22.0) * scale,
			label,
			int(13.0 * scale),
			Color(0.94, 0.98, 1.0, 0.96)
		)


static func wrap_text(font: Font, text: String, max_width: float, font_size: int, max_lines: int) -> Array[String]:
	var lines: Array[String] = []
	if font == null or text == "" or max_width <= 0.0 or font_size <= 0 or max_lines <= 0:
		return lines
	var words := text.replace("\n", " ").split(" ", false)
	var current := ""
	for word_value in words:
		var word := str(word_value)
		var candidate := word if current == "" else "%s %s" % [current, word]
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
			current = candidate
		else:
			if current != "":
				lines.append(current)
			current = word
		if lines.size() >= max_lines:
			break
	if current != "" and lines.size() < max_lines:
		lines.append(current)
	return lines
