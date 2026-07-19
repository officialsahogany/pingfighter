extends RefCounted


static func scroll_value_for_button(current_scroll: float, button_index: int, max_scroll: float, step: float = 48.0) -> float:
	if button_index == MOUSE_BUTTON_WHEEL_UP:
		return clamp(current_scroll - step, 0.0, max_scroll)
	if button_index == MOUSE_BUTTON_WHEEL_DOWN:
		return clamp(current_scroll + step, 0.0, max_scroll)
	return current_scroll


static func scrollbar_rects(grid_rect: Rect2, content_height: float, scroll: float, max_scroll: float) -> Array[Rect2]:
	if max_scroll <= 0.0:
		return [Rect2(), Rect2()]
	var track_rect := Rect2(grid_rect.end.x - 6.0, grid_rect.position.y + 4.0, 4.0, grid_rect.size.y - 8.0)
	var thumb_h: float = max(22.0, track_rect.size.y * (grid_rect.size.y / max(grid_rect.size.y, content_height)))
	var thumb_y: float = track_rect.position.y + (track_rect.size.y - thumb_h) * (scroll / max_scroll)
	var thumb_rect := Rect2(track_rect.position.x, thumb_y, track_rect.size.x, thumb_h)
	return [track_rect, thumb_rect]


static func update_scrollbar_rects(target: Object, track_property: String, thumb_property: String, grid_rect: Rect2, content_height: float, scroll: float, max_scroll: float) -> void:
	var rects: Array[Rect2] = scrollbar_rects(grid_rect, content_height, scroll, max_scroll)
	target.set(track_property, rects[0])
	target.set(thumb_property, rects[1])


static func measured_text_width(text_size_callable: Callable, font: Font, text: String, size: int) -> float:
	var measured: Variant = text_size_callable.call(font, text, size)
	return (measured as Vector2).x if measured is Vector2 else 0.0


static func tooltip_width(font: Font, title: String, subtitle: String, body: String, view_size: Vector2, text_size_callable: Callable) -> float:
	var max_width: float = min(520.0, max(240.0, view_size.x - 16.0))
	var min_width: float = min(280.0, max_width)
	var width: float = min_width
	if title != "":
		width = max(width, min(max_width, measured_text_width(text_size_callable, font, title, 15) + 28.0))
	if subtitle != "":
		width = max(width, min(max_width, measured_text_width(text_size_callable, font, subtitle, 12) + 28.0))
	for paragraph_value in body.split("\n"):
		var paragraph: String = str(paragraph_value).strip_edges()
		if paragraph == "":
			continue
		width = max(width, min(max_width, measured_text_width(text_size_callable, font, paragraph, 13) + 28.0))
	return clamp(width, min_width, max_width)


static func tooltip_anchor_rect(data: Dictionary, mouse_pos: Vector2) -> Rect2:
	var anchor_value: Variant = data.get("anchor_rect", null)
	if anchor_value is Rect2:
		return anchor_value
	return Rect2(mouse_pos.x, mouse_pos.y, 0.0, 0.0)


static func fallback_symbol_letter(id_text: String, letter_cache: Dictionary, cache_limit: int) -> String:
	if id_text == "":
		return "?"
	var cached_letter: Variant = letter_cache.get(id_text, null)
	if cached_letter is String:
		return cached_letter
	var letter := id_text.substr(0, 1).to_upper()
	if letter_cache.size() >= cache_limit:
		letter_cache.clear()
	letter_cache[id_text] = letter
	return letter


static func set_hover_data(data: Dictionary, title: String, subtitle: String, body: String, color: Color, title_color: Variant = null, anchor_rect: Variant = null, roll_options: Variant = null, right_header: String = "") -> Dictionary:
	data.clear()
	data["title"] = title
	data["subtitle"] = subtitle
	data["body"] = body
	data["color"] = color
	if title_color is Color:
		data["title_color"] = title_color
	if anchor_rect is Rect2:
		data["anchor_rect"] = anchor_rect
	if roll_options is Array:
		if not (roll_options as Array).is_empty():
			data["roll_options"] = roll_options
	if right_header != "":
		data["right_header"] = right_header
	return data


static func cached_alpha_color(target: Object, color: Color, source_color: Color, cached_color: Color, source_property: String, cache_property: String, alpha: float) -> Color:
	if color == source_color:
		return cached_color
	var result := Color(color.r, color.g, color.b, alpha)
	target.set(source_property, color)
	target.set(cache_property, result)
	return result
