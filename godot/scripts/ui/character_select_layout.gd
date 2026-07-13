extends RefCounted

const DESKTOP_BREAKPOINT := 980.0
const NARROW_MOBILE_BREAKPOINT := 640.0


static func action_bar_layout(view_size: Vector2, league_buttons: Array) -> Dictionary:
	var league_count: int = maxi(1, league_buttons.size())
	if view_size.x < DESKTOP_BREAKPOINT:
		var bottom_y := mobile_action_bar_bottom_y(view_size)
		var row_y := bottom_y + 2.0
		if view_size.x < NARROW_MOBILE_BREAKPOINT:
			var confirm_width: float = minf(170.0, view_size.x - 48.0)
			var back := Rect2(24.0, row_y, 78.0, 34.0)
			var gap := 6.0
			var available_width: float = view_size.x - 24.0 - back.size.x - 12.0 - 24.0 - gap * float(league_count - 1)
			var league_width: float = clampf(available_width / float(league_count), 44.0, 118.0)
			var confirm := Rect2(view_size.x - 24.0 - confirm_width, bottom_y - 58.0, confirm_width, 50.0)
			var layout: Dictionary = {"back": back, "confirm": confirm}
			layout.merge(build_league_button_layout(league_buttons, back.end.x + 12.0, row_y - 2.0, league_width, 38.0, gap), true)
			return layout
		var confirm_width := 170.0
		var back_width := 90.0
		var gap := 6.0
		var available_width: float = view_size.x - 24.0 - back_width - 12.0 - confirm_width - 12.0 - 24.0 - gap * float(league_count - 1)
		var league_width: float = clampf(available_width / float(league_count), 64.0, 118.0)
		var back := Rect2(24.0, row_y, back_width, 34.0)
		var confirm := Rect2(view_size.x - 24.0 - confirm_width, bottom_y - 8.0, confirm_width, 50.0)
		var layout: Dictionary = {"back": back, "confirm": confirm}
		layout.merge(build_league_button_layout(league_buttons, back.end.x + 12.0, row_y - 2.0, league_width, 38.0, gap), true)
		return layout

	var bottom_y: float = view_size.y - 98.0
	var rail := full_body_rail_rect(view_size)
	var confirm := Rect2(view_size.x - view_size.x * 0.09 - 214.0, bottom_y - 8.0, 214.0, 50.0)
	if rail.has_area():
		confirm = Rect2(rail.position.x + 14.0, rail.end.y - 64.0, rail.size.x - 28.0, 50.0)
	var back := Rect2(card_column_rect(view_size).position.x + 14.0, bottom_y + 2.0, 106.0, 34.0)
	# League tabs share the bottom band with back/confirm. A fixed 150px width
	# centered on the screen overlaps back (left) and the floating confirm
	# (right) at 980~1300px desktop widths, so size and clamp the row into the
	# free span between them instead.
	var league_left_bound: float = back.end.x + 16.0
	var league_right_bound: float = (rail.position.x - 24.0) if rail.has_area() else (confirm.position.x - 16.0)
	var league_gap := 12.0
	var league_height := 44.0
	var league_row_y: float = bottom_y - 3.0
	var available_width: float = league_right_bound - league_left_bound
	var league_width: float = clampf((available_width - league_gap * float(league_count - 1)) / float(league_count), 64.0, 150.0)
	var total_width: float = league_width * float(league_count) + league_gap * float(league_count - 1)
	var league_start: float = clampf(view_size.x * 0.5 - total_width * 0.5, league_left_bound, maxf(league_left_bound, league_right_bound - total_width))
	var layout: Dictionary = {
		"back": back,
		"confirm": confirm,
	}
	layout.merge(build_league_button_layout(league_buttons, league_start, league_row_y, league_width, league_height, league_gap), true)
	return layout


static func build_league_button_layout(
	league_buttons: Array,
	start_x: float,
	row_y: float,
	button_width: float,
	button_height: float,
	gap: float
) -> Dictionary:
	var result: Dictionary = {}
	for index in range(league_buttons.size()):
		var button_value: Variant = league_buttons[index]
		if not (button_value is Dictionary):
			continue
		var mode := str((button_value as Dictionary).get("mode", ""))
		result[mode] = Rect2(start_x + (button_width + gap) * float(index), row_y, button_width, button_height)
	return result


static func layout_cards(
	view_size: Vector2,
	visible_indices: Array,
	hover_scales: Array,
	hover_lifts: Array
) -> Dictionary:
	var rects: Dictionary = {}
	var count: int = visible_indices.size()
	if count <= 0:
		return rects
	var column := card_column_rect(view_size)
	if view_size.x < DESKTOP_BREAKPOINT:
		var card_width: float = min(172.0, (column.size.x - 18.0) / float(count))
		var card_height: float = column.size.y - 26.0
		var step_x: float = (column.size.x - card_width) / float(max(1, count - 1))
		for position_index in range(count):
			var character_index := int(visible_indices[position_index])
			var scale_factor := float(hover_scales[character_index])
			var card_size := Vector2(card_width, card_height) * scale_factor
			var center := Vector2(
				column.position.x + card_width * 0.5 + float(position_index) * step_x,
				column.position.y + column.size.y * 0.54 - float(hover_lifts[character_index])
			)
			rects[character_index] = Rect2(center - card_size * 0.5, card_size)
		return rects

	var padding := 8.0
	var top_padding := 96.0
	var gap := 10.0
	var card_width: float = column.size.x - padding * 2.0
	var available_height: float = column.size.y - top_padding - 92.0 - gap * float(max(0, count - 1))
	var card_height: float = min(126.0, available_height / float(count))
	for position_index in range(count):
		var character_index := int(visible_indices[position_index])
		var scale_factor := float(hover_scales[character_index])
		var card_size := Vector2(card_width, card_height) * scale_factor
		var x := column.position.x + padding
		var y := column.position.y + top_padding + float(position_index) * (card_height + gap) - float(hover_lifts[character_index]) * 0.35
		var center := Vector2(x + card_width * 0.5, y + card_height * 0.5)
		rects[character_index] = Rect2(center - card_size * 0.5, card_size)
	return rects


static func card_column_rect(view_size: Vector2) -> Rect2:
	if view_size.x < DESKTOP_BREAKPOINT:
		return Rect2(24.0, view_size.y - 248.0, view_size.x - 48.0, 172.0)
	var top := 106.0
	var left: float = clamp(view_size.x * 0.085, 86.0, 150.0)
	var width: float = clamp(view_size.x * 0.152, 246.0, 292.0)
	return Rect2(left, top, width, view_size.y - top - 84.0)


static func language_button_rect(view_size: Vector2) -> Rect2:
	if view_size.x < DESKTOP_BREAKPOINT:
		var width: float = min(156.0, max(132.0, view_size.x - 68.0))
		return Rect2(view_size.x - width - 34.0, 34.0, width, 32.0)
	var column := card_column_rect(view_size)
	return Rect2(column.position.x + 14.0, column.end.y - 72.0, column.size.x - 28.0, 34.0)


static func mobile_action_bar_bottom_y(view_size: Vector2) -> float:
	return card_column_rect(view_size).position.y - 46.0


static func mobile_action_band_top(view_size: Vector2) -> float:
	var bottom_y := mobile_action_bar_bottom_y(view_size)
	if view_size.x < NARROW_MOBILE_BREAKPOINT:
		return bottom_y - 58.0
	return bottom_y - 8.0


static func preview_rect(view_size: Vector2) -> Rect2:
	if view_size.x < DESKTOP_BREAKPOINT:
		var top := 108.0
		var total_budget: float = mobile_action_band_top(view_size) - 12.0 - top
		var info_reserve := 0.0
		if total_budget >= 176.0:
			info_reserve = 112.0
		var height: float = clampf(view_size.y * 0.44, 64.0, maxf(64.0, total_budget - info_reserve))
		return Rect2(34.0, top, view_size.x - 68.0, height)
	var column := card_column_rect(view_size)
	var x := column.end.x + 24.0
	var rail := full_body_rail_rect(view_size)
	var right_edge: float = rail.position.x - 24.0 if rail.has_area() else view_size.x - layout_right_margin(view_size)
	var width: float = clamp(right_edge - x, 560.0, 1560.0)
	return Rect2(x, 116.0, width, max(360.0, view_size.y - 238.0))


static func full_body_rail_rect(view_size: Vector2) -> Rect2:
	if view_size.x < DESKTOP_BREAKPOINT:
		return Rect2()
	var column := card_column_rect(view_size)
	var x := column.end.x + 24.0
	var right_margin := layout_right_margin(view_size)
	var width: float = clamp(view_size.x * 0.155, 264.0, 300.0)
	if view_size.x - right_margin - x < 560.0 + 24.0 + width:
		return Rect2()
	return Rect2(view_size.x - right_margin - width, 116.0, width, max(360.0, view_size.y - 238.0))


static func info_panel_rect(view_size: Vector2, preview: Rect2) -> Rect2:
	if view_size.x < DESKTOP_BREAKPOINT:
		var top := preview.end.y + 16.0
		var bottom: float = mobile_action_band_top(view_size) - 12.0
		var height: float = min(250.0, bottom - top)
		if height < 1.0:
			return Rect2()
		return Rect2(34.0, top, view_size.x - 68.0, height)
	return Rect2()


static func layout_right_margin(view_size: Vector2) -> float:
	return clamp(view_size.x * 0.080, 84.0, 156.0)


static func info_panel_width(view_size: Vector2) -> float:
	return clamp(view_size.x * 0.245, 390.0, 500.0)


static func build_info_panel_layout(rect: Rect2, character: Dictionary, font: Font) -> Dictionary:
	var content_left := rect.position.x + 26.0
	var content_width: float = max(80.0, rect.size.x - 52.0)
	var content_right := content_left + content_width
	var y := rect.position.y + 22.0
	var layout := {
		"role_top_left": Vector2(content_left, y),
	}
	var role_lines := wrapped_text_lines(font, str(character.get("role", "")), content_width, 14, 2)
	layout["role_lines"] = role_lines
	y += max(18.0, float(role_lines.size()) * 18.0)

	var name_top_left := Vector2(content_left, y + 6.0)
	layout["name_top_left"] = name_top_left
	var character_name := str(character.get("character_name", character.get("name", "")))
	var class_label := str(character.get("class_name", character.get("name", "")))
	var name_size := font.get_string_size(character_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 31)
	var resolved_badge_size := badge_size(font, class_label, 14)
	var badge_top_left := Vector2(content_left + name_size.x + 18.0, name_top_left.y + 1.0)
	var name_bottom: float = name_top_left.y + 37.0
	if class_label.strip_edges() != "" and badge_top_left.x + resolved_badge_size.x > content_right:
		badge_top_left = Vector2(content_left, name_top_left.y + 40.0)
		name_bottom = max(name_bottom, badge_top_left.y + resolved_badge_size.y + 6.0)
	layout["badge_top_left"] = badge_top_left
	y = name_bottom

	var tagline_lines := wrapped_text_lines(font, str(character.get("tagline", "")), content_width, 17, 2)
	var tagline_top_left := Vector2(content_left, y)
	layout["tagline_top_left"] = tagline_top_left
	layout["tagline_lines"] = tagline_lines
	if not tagline_lines.is_empty():
		y = tagline_top_left.y + float(tagline_lines.size()) * 22.0
	else:
		y += 4.0

	var description_lines := wrapped_text_lines(font, str(character.get("description", "")), content_width, 14, 3)
	var description_top_left := Vector2(content_left, y + 5.0)
	layout["description_top_left"] = description_top_left
	layout["description_lines"] = description_lines
	if not description_lines.is_empty():
		y = description_top_left.y + float(description_lines.size()) * 20.0
	else:
		y = description_top_left.y

	var difficulty_top_left := Vector2(content_left, y + 6.0)
	layout["difficulty_top_left"] = difficulty_top_left
	y = difficulty_top_left.y + 24.0

	if bool(character.get("unlocked", false)):
		var skills_label_top_left := Vector2(content_left, y + 2.0)
		var ring_core_size := 50.0
		var ring_core_gap := 18.0
		var skill_row_width := maxf(174.0, content_width - ring_core_size - ring_core_gap)
		var skill_rect := Rect2(Vector2(content_left, skills_label_top_left.y + 26.0), Vector2(skill_row_width, 56.0))
		var ring_core_rect := Rect2(Vector2(content_right - ring_core_size, skill_rect.position.y), Vector2(ring_core_size, ring_core_size))
		layout["skills_label_top_left"] = skills_label_top_left
		layout["skill_rect"] = skill_rect
		layout["ring_core_label_top_left"] = Vector2(ring_core_rect.position.x, skills_label_top_left.y)
		layout["ring_core_rect"] = ring_core_rect
		y = skill_rect.end.y
	else:
		var locked_status_rect := Rect2(Vector2(content_left, y + 4.0), Vector2(content_width, 76.0))
		layout["locked_status_rect"] = locked_status_rect
		y = locked_status_rect.end.y

	var full_body_top: float = max(rect.position.y + 252.0, y + 22.0)
	var full_body_height: float = rect.end.y - full_body_top - 20.0
	if full_body_height < 120.0:
		layout["full_body_rect"] = Rect2()
	else:
		layout["full_body_rect"] = Rect2(
			Vector2(rect.position.x + 22.0, full_body_top),
			Vector2(max(80.0, rect.size.x - 44.0), full_body_height)
		)
	return layout


static func info_panel_visible_blocks(rect: Rect2, layout: Dictionary, unlocked: bool) -> Dictionary:
	var content_bottom: float = rect.end.y - 10.0
	var blocks := {}
	var name_top: Vector2 = layout.get("name_top_left", rect.position)
	blocks["name"] = name_top.y + 37.0 <= content_bottom
	var tagline_top: Vector2 = layout.get("tagline_top_left", rect.position)
	var tagline_count := layout_string_lines(layout, "tagline_lines").size()
	blocks["tagline"] = tagline_count > 0 and tagline_top.y + float(tagline_count) * 22.0 <= content_bottom
	var description_top: Vector2 = layout.get("description_top_left", rect.position)
	var description_count := layout_string_lines(layout, "description_lines").size()
	blocks["description"] = description_count > 0 and description_top.y + float(description_count) * 20.0 <= content_bottom
	var difficulty_top: Vector2 = layout.get("difficulty_top_left", rect.position)
	blocks["difficulty"] = difficulty_top.y + 20.0 <= content_bottom
	if unlocked:
		var skill_rect: Rect2 = layout.get("skill_rect", Rect2())
		blocks["skills"] = skill_rect.has_area() and skill_rect.end.y <= content_bottom
	else:
		var locked_rect: Rect2 = layout.get("locked_status_rect", Rect2())
		blocks["locked"] = locked_rect.has_area() and locked_rect.end.y <= content_bottom
	return blocks


static func layout_string_lines(layout: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	var lines_value: Variant = layout.get(key, [])
	if lines_value is Array:
		for line_value in lines_value:
			result.append(str(line_value))
	return result


static func wrapped_text_lines(font: Font, source_text: String, max_width: float, font_size: int, max_lines: int) -> Array[String]:
	var result: Array[String] = []
	if source_text.strip_edges() == "" or max_lines <= 0:
		return result
	var paragraphs := source_text.split("\n", false)
	for paragraph_value in paragraphs:
		var paragraph := str(paragraph_value).strip_edges()
		if paragraph == "":
			continue
		var words := paragraph.split(" ", false)
		var current_line := ""
		for word_value in words:
			var word := str(word_value)
			var candidate := word if current_line == "" else "%s %s" % [current_line, word]
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width or current_line == "":
				current_line = candidate
			else:
				result.append(current_line)
				if result.size() >= max_lines:
					return result
				current_line = word
		if current_line != "":
			result.append(current_line)
			if result.size() >= max_lines:
				return result
	return result


static func badge_size(font: Font, label: String, font_size: int) -> Vector2:
	if label.strip_edges() == "":
		return Vector2.ZERO
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	return Vector2(text_size.x + 22.0, 25.0)


static func full_body_microstat_rows(character: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry_value in [
		{"label": "HEIGHT", "key": "lore_height"},
		{"label": "WEIGHT", "key": "lore_weight"},
		{"label": "AFFILIATION", "key": "lore_affiliation"},
	]:
		var entry: Dictionary = entry_value
		var value := str(character.get(str(entry.get("key", "")), "")).strip_edges()
		if value != "":
			rows.append({"label": str(entry.get("label", "")), "value": value})
	return rows
