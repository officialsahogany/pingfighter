extends RefCounted

const PANEL_MAX_SIZE := Vector2(720.0, 690.0)
const PANEL_MARGIN := 12.0
const CONTENT_MARGIN := 22.0
const GRID_GAP := 10.0
const MIN_CARD_WIDTH := 132.0
const MAX_COLUMNS := 4
const MAX_ROWS := 3
const BUTTON_GAP := 10.0
const BUTTON_MAX_WIDTH := 200.0
const BUTTON_MAX_HEIGHT := 54.0
const HEADER_MAX_HEIGHT := 150.0
const FOOTER_MAX_HEIGHT := 140.0
const PAIR_MAX_GAP := 140.0
const PAIR_MAX_HEIGHT := 170.0


func build_layout(snapshot: Dictionary, view_size: Vector2) -> Dictionary:
	var safe_view := Vector2(maxf(1.0, view_size.x), maxf(1.0, view_size.y))
	var outer_margin: float = minf(PANEL_MARGIN, maxf(0.0, minf(safe_view.x, safe_view.y) * 0.12))
	var panel_size := Vector2(
		minf(PANEL_MAX_SIZE.x, maxf(1.0, safe_view.x - outer_margin * 2.0)),
		minf(PANEL_MAX_SIZE.y, maxf(1.0, safe_view.y - outer_margin * 2.0))
	)
	var panel_rect := Rect2((safe_view - panel_size) * 0.5, panel_size)
	var inner_margin: float = minf(CONTENT_MARGIN, panel_size.x * 0.08)
	var header_height: float = minf(HEADER_MAX_HEIGHT, panel_size.y * 0.24)
	var footer_height: float = minf(FOOTER_MAX_HEIGHT, panel_size.y * 0.22)
	var grid_rect := Rect2(
		panel_rect.position + Vector2(inner_margin, header_height),
		Vector2(
			maxf(1.0, panel_size.x - inner_margin * 2.0),
			maxf(1.0, panel_size.y - header_height - footer_height)
		)
	)

	var candidate_ids: Array = _as_array(snapshot.get("candidate_ids", []))
	var candidate_count: int = candidate_ids.size()
	var column_capacity: int = clampi(
		int(floor((grid_rect.size.x + GRID_GAP) / (MIN_CARD_WIDTH + GRID_GAP))),
		1,
		MAX_COLUMNS
	)
	var columns: int = mini(column_capacity, maxi(1, candidate_count))
	var page_size: int = maxi(1, columns * MAX_ROWS)
	var highlighted_index: int = clampi(int(snapshot.get("highlight_index", 0)), 0, maxi(0, candidate_count - 1))
	var page_index: int = floori(float(highlighted_index) / float(page_size))
	var page_start: int = page_index * page_size
	var page_end: int = mini(candidate_count, page_start + page_size)
	var visible_count: int = maxi(0, page_end - page_start)
	var rows: int = maxi(1, ceili(float(maxi(1, visible_count)) / float(columns)))
	var card_width: float = maxf(1.0, (grid_rect.size.x - GRID_GAP * float(columns - 1)) / float(columns))
	var card_height: float = maxf(1.0, (grid_rect.size.y - GRID_GAP * float(rows - 1)) / float(rows))
	var candidate_rects: Array = []
	for _candidate_index in range(candidate_count):
		candidate_rects.append(Rect2())
	var visible_candidate_indices: Array[int] = []
	for candidate_index in range(page_start, page_end):
		var local_index: int = candidate_index - page_start
		var column: int = local_index % columns
		var row: int = floori(float(local_index) / float(columns))
		candidate_rects[candidate_index] = Rect2(
			grid_rect.position + Vector2(
				float(column) * (card_width + GRID_GAP),
				float(row) * (card_height + GRID_GAP)
			),
			Vector2(card_width, card_height)
		)
		visible_candidate_indices.append(candidate_index)

	var button_height: float = minf(BUTTON_MAX_HEIGHT, maxf(1.0, footer_height - 8.0))
	var button_y: float = panel_rect.end.y - footer_height + maxf(4.0, (footer_height - button_height) * 0.5)
	var button_area_width: float = maxf(1.0, panel_size.x - inner_margin * 2.0)
	var button_width: float = minf(BUTTON_MAX_WIDTH, maxf(1.0, (button_area_width - BUTTON_GAP) * 0.5))
	var back_rect := Rect2(
		Vector2(panel_rect.position.x + inner_margin, button_y),
		Vector2(button_width, button_height)
	)
	var confirm_rect := Rect2(
		Vector2(panel_rect.end.x - inner_margin - button_width, button_y),
		Vector2(button_width, button_height)
	)

	var pair_gap: float = minf(PAIR_MAX_GAP, grid_rect.size.x * 0.21)
	var pair_width: float = minf(230.0, maxf(1.0, (grid_rect.size.x - pair_gap) * 0.5))
	var pair_height: float = minf(PAIR_MAX_HEIGHT, maxf(1.0, grid_rect.size.y * 0.43))
	var pair_total_width: float = pair_width * 2.0 + pair_gap
	var pair_start := Vector2(
		grid_rect.get_center().x - pair_total_width * 0.5,
		grid_rect.position.y + maxf(0.0, grid_rect.size.y * 0.06)
	)
	var pair_rects: Array[Rect2] = [
		Rect2(pair_start, Vector2(pair_width, pair_height)),
		Rect2(pair_start + Vector2(pair_width + pair_gap, 0.0), Vector2(pair_width, pair_height)),
	]
	var probability_y: float = pair_start.y + pair_height + minf(18.0, grid_rect.size.y * 0.05)
	var probability_rect := Rect2(
		Vector2(grid_rect.position.x, probability_y),
		Vector2(grid_rect.size.x, maxf(1.0, grid_rect.end.y - probability_y))
	)

	return {
		"panel_rect": panel_rect,
		"grid_rect": grid_rect,
		"candidate_rects": candidate_rects,
		"visible_candidate_indices": visible_candidate_indices,
		"page_index": page_index,
		"page_count": maxi(1, ceili(float(maxi(1, candidate_count)) / float(page_size))),
		"page_size": page_size,
		"pair_rects": pair_rects,
		"probability_rect": probability_rect,
		"result_rect": grid_rect,
		"back_rect": back_rect,
		"confirm_rect": confirm_rect,
	}


func get_candidate_index_at(snapshot: Dictionary, position: Vector2, view_size: Vector2) -> int:
	# Candidate cells only exist as interactive targets during material
	# selection. Later phases deliberately reuse grid_rect for the confirmation
	# and result card, so hit-testing stale candidate rects there can consume a
	# one-shot commit/finish request without the state owner seeing its result.
	if str(snapshot.get("phase", "")) != "materials":
		return -1
	var layout: Dictionary = build_layout(snapshot, view_size)
	var candidate_rects: Array = _as_array(layout.get("candidate_rects", []))
	for candidate_index in range(candidate_rects.size()):
		var candidate_rect: Rect2 = _as_rect2(candidate_rects[candidate_index])
		if candidate_rect.size.x > 0.0 and candidate_rect.size.y > 0.0 and candidate_rect.has_point(position):
			return candidate_index
	return -1


func hit_test_candidate(snapshot: Dictionary, position: Vector2, view_size: Vector2) -> int:
	return get_candidate_index_at(snapshot, position, view_size)


func get_action_at(snapshot: Dictionary, position: Vector2, view_size: Vector2) -> String:
	var layout: Dictionary = build_layout(snapshot, view_size)
	if _as_rect2(layout.get("back_rect", Rect2())).has_point(position):
		return "back"
	if _as_rect2(layout.get("confirm_rect", Rect2())).has_point(position):
		return "confirm"
	return ""


func _as_array(value: Variant) -> Array:
	return value if value is Array else []


func _as_rect2(value: Variant) -> Rect2:
	return value if value is Rect2 else Rect2()
