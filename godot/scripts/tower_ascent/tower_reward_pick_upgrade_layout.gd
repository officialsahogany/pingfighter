extends RefCounted

const REFERENCE_SIZE := Vector2(1400.0, 1050.0)
const REFERENCE_PANEL_RECT := Rect2(149.0, 79.0, 1123.0, 916.0)
const REFERENCE_BACK_ARROW_RECT := Rect2(180.0, 108.0, 82.0, 82.0)
const REFERENCE_CARD_BAND_RECT := Rect2(205.0, 247.0, 1035.0, 550.0)
const REFERENCE_CHECKBOX_RECT := Rect2(550.0, 806.0, 320.0, 60.0)
const REFERENCE_BACK_BUTTON_RECT := Rect2(340.0, 876.0, 330.0, 88.0)
const REFERENCE_CONFIRM_BUTTON_RECT := Rect2(713.0, 876.0, 360.0, 88.0)

const COMPARE_CARD_WIDTH := 438.0
const COMPARE_CARD_GAP := 72.0
const ALL_LEVEL_CARD_GAP := 18.0
const ALL_LEVEL_MIN_CARD_WIDTH := 180.0


func build_layout(
	view_size: Vector2,
	card_count_value: int,
	show_all_levels: bool,
	has_next_level: bool = true
) -> Dictionary:
	var safe_view := Vector2(maxf(1.0, view_size.x), maxf(1.0, view_size.y))
	var scale: float = minf(
		safe_view.x / REFERENCE_SIZE.x,
		safe_view.y / REFERENCE_SIZE.y
	)
	var origin: Vector2 = (safe_view - REFERENCE_SIZE * scale) * 0.5
	var panel_rect := _transform_rect(REFERENCE_PANEL_RECT, origin, scale)
	var card_band_rect := _transform_rect(REFERENCE_CARD_BAND_RECT, origin, scale)
	var card_count: int = max(1, card_count_value)
	var card_rects: Array[Rect2] = []
	var columns := 1
	var rows := 1
	if show_all_levels:
		var gap: float = ALL_LEVEL_CARD_GAP * scale
		var min_card_width: float = maxf(92.0, ALL_LEVEL_MIN_CARD_WIDTH * scale)
		columns = clampi(
			int(floor((card_band_rect.size.x + gap) / (min_card_width + gap))),
			1,
			card_count
		)
		rows = ceili(float(card_count) / float(columns))
		var card_width: float = (
			card_band_rect.size.x - gap * float(max(0, columns - 1))
		) / float(columns)
		var row_gap: float = gap
		var card_height: float = (
			card_band_rect.size.y - row_gap * float(max(0, rows - 1))
		) / float(rows)
		for index in range(card_count):
			var row: int = index / columns
			var column: int = index % columns
			var remaining: int = card_count - row * columns
			var row_columns: int = mini(columns, remaining)
			var row_width: float = card_width * float(row_columns) + gap * float(max(0, row_columns - 1))
			var row_left: float = card_band_rect.get_center().x - row_width * 0.5
			card_rects.append(Rect2(
				Vector2(
					row_left + float(column) * (card_width + gap),
					card_band_rect.position.y + float(row) * (card_height + row_gap)
				),
				Vector2(card_width, card_height)
			))
	else:
		var visible_count: int = 2 if has_next_level and card_count > 1 else 1
		columns = visible_count
		var gap: float = COMPARE_CARD_GAP * scale if visible_count > 1 else 0.0
		var card_width: float = minf(
			COMPARE_CARD_WIDTH * scale,
			(card_band_rect.size.x - gap * float(max(0, visible_count - 1))) / float(visible_count)
		)
		var total_width: float = card_width * float(visible_count) + gap * float(max(0, visible_count - 1))
		var left: float = card_band_rect.get_center().x - total_width * 0.5
		for index in range(visible_count):
			card_rects.append(Rect2(
				Vector2(left + float(index) * (card_width + gap), card_band_rect.position.y),
				Vector2(card_width, card_band_rect.size.y)
			))
	var arrow_rect := Rect2()
	if not show_all_levels and card_rects.size() == 2:
		var left_rect: Rect2 = card_rects[0]
		var right_rect: Rect2 = card_rects[1]
		var arrow_size := Vector2.ONE * minf(72.0 * scale, right_rect.position.x - left_rect.end.x)
		arrow_rect = Rect2(
			Vector2(
				(left_rect.end.x + right_rect.position.x - arrow_size.x) * 0.5,
				card_band_rect.get_center().y - arrow_size.y * 0.5
			),
			arrow_size
		)
	return {
		"reference_scale": scale,
		"reference_origin": origin,
		"panel_rect": panel_rect,
		"back_arrow_rect": _transform_rect(REFERENCE_BACK_ARROW_RECT, origin, scale),
		"card_band_rect": card_band_rect,
		"card_rects": card_rects,
		"columns": columns,
		"rows": rows,
		"arrow_rect": arrow_rect,
		"checkbox_rect": _transform_rect(REFERENCE_CHECKBOX_RECT, origin, scale),
		"back_button_rect": _transform_rect(REFERENCE_BACK_BUTTON_RECT, origin, scale),
		"confirm_button_rect": _transform_rect(REFERENCE_CONFIRM_BUTTON_RECT, origin, scale),
	}


func get_card_index_at(layout: Dictionary, position: Vector2) -> int:
	var rects: Array = layout.get("card_rects", []) as Array
	for index in range(rects.size()):
		var rect_value: Variant = rects[index]
		if rect_value is Rect2 and (rect_value as Rect2).has_point(position):
			return index
	return -1


func action_at(layout: Dictionary, position: Vector2) -> String:
	var rect_keys := {
		"back_arrow": "back_arrow_rect",
		"checkbox": "checkbox_rect",
		"back": "back_button_rect",
		"confirm": "confirm_button_rect",
	}
	for action_name: String in rect_keys:
		var rect_key: String = str(rect_keys[action_name])
		var rect_value: Variant = layout.get(rect_key, Rect2())
		if rect_value is Rect2 and (rect_value as Rect2).has_point(position):
			return action_name
	return ""


func _transform_rect(rect: Rect2, origin: Vector2, scale: float) -> Rect2:
	return Rect2(origin + rect.position * scale, rect.size * scale)
