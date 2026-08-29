extends RefCounted

const REFERENCE_VIEW_SIZE := Vector2(1400.0, 1050.0)
const DEFAULT_CARD_SIZE := Vector2(184.0, 116.0)
const DEFAULT_CARD_GAP := 14.0
const MIN_CARD_WIDTH := 142.0
const MAX_COLUMNS := 5
const PANEL_HORIZONTAL_MARGIN := 72.0
const PANEL_TOP_CONTENT := 116.0
const PANEL_BOTTOM_CONTENT := 82.0


func build_layout(candidate_count_value: int, view_size: Vector2) -> Dictionary:
	var safe_view := Vector2(maxf(1.0, view_size.x), maxf(1.0, view_size.y))
	var scale: float = clampf(
		minf(safe_view.x / REFERENCE_VIEW_SIZE.x, safe_view.y / REFERENCE_VIEW_SIZE.y),
		0.58,
		1.24
	)
	var candidate_count: int = max(1, candidate_count_value)
	var max_width: float = minf(1120.0 * scale, safe_view.x - PANEL_HORIZONTAL_MARGIN * scale)
	var gap: float = maxf(8.0, DEFAULT_CARD_GAP * scale)
	var desired_card_width: float = DEFAULT_CARD_SIZE.x * scale
	var min_card_width: float = maxf(98.0, MIN_CARD_WIDTH * scale)
	var width_columns: int = maxi(1, int(floor(
		(max_width + gap) / (min_card_width + gap)
	)))
	var columns: int = mini(candidate_count, mini(MAX_COLUMNS, width_columns))
	var card_width: float = minf(
		desired_card_width,
		(max_width - gap * float(max(0, columns - 1))) / float(columns)
	)
	var card_height: float = card_width * DEFAULT_CARD_SIZE.y / DEFAULT_CARD_SIZE.x
	var rows: int = ceili(float(candidate_count) / float(columns))
	var grid_height: float = card_height * float(rows) + gap * float(max(0, rows - 1))
	var panel_height: float = PANEL_TOP_CONTENT * scale + grid_height + PANEL_BOTTOM_CONTENT * scale
	var max_panel_height: float = safe_view.y - 48.0 * scale
	if panel_height > max_panel_height:
		var fixed_height: float = (PANEL_TOP_CONTENT + PANEL_BOTTOM_CONTENT) * scale
		var available_grid_height: float = maxf(80.0, max_panel_height - fixed_height)
		card_height = (
			available_grid_height - gap * float(max(0, rows - 1))
		) / float(rows)
		card_width = minf(card_width, card_height * DEFAULT_CARD_SIZE.x / DEFAULT_CARD_SIZE.y)
		grid_height = card_height * float(rows) + gap * float(max(0, rows - 1))
		panel_height = fixed_height + grid_height
	var widest_row_count: int = mini(columns, candidate_count)
	var grid_width: float = card_width * float(widest_row_count) + gap * float(max(0, widest_row_count - 1))
	var panel_width: float = minf(max_width + 72.0 * scale, grid_width + 96.0 * scale)
	var panel_pos := Vector2(
		floor((safe_view.x - panel_width) * 0.5),
		floor((safe_view.y - panel_height) * 0.5)
	)
	var panel_rect := Rect2(panel_pos, Vector2(panel_width, panel_height))
	var cards_top: float = panel_rect.position.y + PANEL_TOP_CONTENT * scale
	var option_rects: Array[Rect2] = []
	for index in range(candidate_count):
		var row: int = index / columns
		var column: int = index % columns
		var remaining: int = candidate_count - row * columns
		var row_columns: int = mini(columns, remaining)
		var row_width: float = card_width * float(row_columns) + gap * float(max(0, row_columns - 1))
		var row_left: float = panel_rect.get_center().x - row_width * 0.5
		option_rects.append(Rect2(
			Vector2(
				row_left + float(column) * (card_width + gap),
				cards_top + float(row) * (card_height + gap)
			),
			Vector2(card_width, card_height)
		))
	var cancel_size := Vector2(190.0, 42.0) * scale
	var cancel_rect := Rect2(
		Vector2(
			panel_rect.get_center().x - cancel_size.x * 0.5,
			panel_rect.end.y - cancel_size.y - 16.0 * scale
		),
		cancel_size
	)
	return {
		"scale": scale,
		"panel_rect": panel_rect,
		"title_pos": panel_rect.position + Vector2(panel_width * 0.5, 38.0 * scale),
		"new_skill_pos": panel_rect.position + Vector2(panel_width * 0.5, 72.0 * scale),
		"option_rects": option_rects,
		"card_size": Vector2(card_width, card_height),
		"card_gap": gap,
		"columns": columns,
		"rows": rows,
		"hint_pos": Vector2(panel_rect.get_center().x, cancel_rect.position.y - 13.0 * scale),
		"cancel_rect": cancel_rect,
	}


func get_option_index_at(layout: Dictionary, position: Vector2) -> int:
	var rects: Array = layout.get("option_rects", []) as Array
	for index in range(rects.size()):
		var rect_value: Variant = rects[index]
		if rect_value is Rect2 and (rect_value as Rect2).has_point(position):
			return index
	return -1


func is_cancel_at(layout: Dictionary, position: Vector2) -> bool:
	var rect_value: Variant = layout.get("cancel_rect", Rect2())
	return rect_value is Rect2 and (rect_value as Rect2).has_point(position)
