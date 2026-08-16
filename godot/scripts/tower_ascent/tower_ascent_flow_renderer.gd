extends RefCounted

const PLAYFIELD_SIZE := Vector2(760.0, 750.0)
const MAP_RECT := Rect2(34.0, 24.0, 692.0, 702.0)
const MODAL_RECT := Rect2(120.0, 188.0, 520.0, 350.0)
const SELECTOR_RADIUS := 11.0

const INK := Color("30271f")
const INK_SOFT := Color("665343")
const PAPER := Color("f1dfb8")
const PAPER_DEEP := Color("d7bd88")
const CINNABAR := Color("9e352d")
const CINNABAR_DARK := Color("63241f")
const GOLD := Color("bd8c35")
const SEALED := Color("5e5145")
const BALL_COLOR := Color("f8efcc")


func draw(canvas: CanvasItem, flow: Object) -> void:
	if canvas == null or flow == null or not flow.has_method("is_active") or not bool(flow.is_active()):
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color(0.035, 0.025, 0.02, 0.92), true)
	canvas.draw_rect(MAP_RECT, PAPER, true)
	canvas.draw_rect(MAP_RECT, INK, false, 4.0)
	canvas.draw_rect(MAP_RECT.grow(-8.0), PAPER_DEEP, false, 1.5)
	_draw_title(canvas, flow)
	_draw_route_map(canvas, flow)
	var phase_name := str(flow.get_phase_name())
	if phase_name == "NODE_MODAL":
		_draw_node_modal(canvas)
	elif phase_name == "ROUTE_AIM":
		_draw_route_aim(canvas, flow)
	elif phase_name == "MAP_TRANSITION":
		_draw_map_transition(canvas, flow)


func _draw_title(canvas: CanvasItem, flow: Object) -> void:
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(62.0, 70.0), "승천탑 행로", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, INK)
	canvas.draw_string(
		font,
		Vector2(62.0, 98.0),
		flow.get_header_subtitle(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		15,
		INK_SOFT
	)
	canvas.draw_circle(Vector2(683.0, 71.0), 24.0, CINNABAR)
	canvas.draw_circle(Vector2(683.0, 71.0), 18.0, PAPER, false, 2.0)
	canvas.draw_string(font, Vector2(670.0, 79.0), "塔", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, PAPER)


func _draw_route_map(canvas: CanvasItem, flow: Object) -> void:
	var nodes: Array = flow.get_graph_nodes()
	var edges: Array = flow.get_graph_edges()
	if nodes.is_empty():
		return
	for edge_variant in edges:
		var edge: Dictionary = edge_variant
		var from_position := _find_node_position(nodes, str(edge.get("from", "")))
		var to_position := _find_node_position(nodes, str(edge.get("to", "")))
		canvas.draw_line(from_position, to_position, INK_SOFT, 4.0)
	for node_variant in nodes:
		var node: Dictionary = node_variant
		_draw_map_node(canvas, node, str(flow.get_selected_target_id()))


func _find_node_position(nodes: Array, node_id: String) -> Vector2:
	for node_variant in nodes:
		var node: Dictionary = node_variant
		if str(node.get("id", "")) == node_id:
			return _vector2(node.get("position", Vector2.ZERO))
	return Vector2.ZERO


func _draw_map_node(canvas: CanvasItem, node: Dictionary, selected_target_id: String) -> void:
	var position := _vector2(node.get("position", Vector2.ZERO))
	var node_id := str(node.get("id", ""))
	var completed := bool(node.get("completed", false))
	var selected := node_id == selected_target_id and not selected_target_id.is_empty()
	var fill := GOLD if completed else PAPER_DEEP
	if selected:
		fill = CINNABAR
	canvas.draw_circle(position, 38.0, fill)
	canvas.draw_circle(position, 38.0, CINNABAR_DARK if selected else INK, false, 3.0)
	var label := str(node.get("label", "노드"))
	var text_color := PAPER if selected else INK
	canvas.draw_string(
		ThemeDB.fallback_font,
		position + Vector2(-62.0, 6.0),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		124.0,
		17,
		text_color
	)


func _draw_node_modal(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color(0.06, 0.04, 0.025, 0.54), true)
	canvas.draw_rect(MODAL_RECT, Color("f7e9c8"), true)
	canvas.draw_rect(MODAL_RECT, CINNABAR_DARK, false, 5.0)
	canvas.draw_rect(MODAL_RECT.grow(-13.0), GOLD, false, 2.0)
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(205.0, 252.0), "수호의 샘터", HORIZONTAL_ALIGNMENT_CENTER, 350.0, 31, INK)
	canvas.draw_line(Vector2(216.0, 274.0), Vector2(544.0, 274.0), GOLD, 2.0)
	canvas.draw_string(font, Vector2(180.0, 333.0), "전투가 멎은 사이, 다음 행로를 정비합니다.", HORIZONTAL_ALIGNMENT_CENTER, 400.0, 19, INK_SOFT)
	canvas.draw_string(font, Vector2(180.0, 375.0), "이번 검증판은 효과 없이 노드만 안전하게 해소합니다.", HORIZONTAL_ALIGNMENT_CENTER, 400.0, 16, SEALED)
	canvas.draw_rect(Rect2(260.0, 434.0, 240.0, 55.0), CINNABAR, true)
	canvas.draw_rect(Rect2(260.0, 434.0, 240.0, 55.0), CINNABAR_DARK, false, 2.0)
	canvas.draw_string(font, Vector2(260.0, 469.0), "행로 조준으로", HORIZONTAL_ALIGNMENT_CENTER, 240.0, 20, PAPER)


func _draw_route_aim(canvas: CanvasItem, flow: Object) -> void:
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(80.0, 694.0), "좌우로 조준하고 확인하여 선택구를 발사하세요", HORIZONTAL_ALIGNMENT_CENTER, 600.0, 18, INK)
	canvas.draw_string(font, Vector2(80.0, 716.0), "발사 횟수 제한 없음 · 선택은 표적 명중 시 확정", HORIZONTAL_ALIGNMENT_CENTER, 600.0, 15, INK_SOFT)
	var origin: Vector2 = flow.get_selector_origin()
	if not bool(flow.is_selector_launched()):
		var aim_point: Vector2 = flow.get_aim_preview_point()
		canvas.draw_dashed_line(origin, aim_point, CINNABAR, 2.0, 9.0)
	canvas.draw_circle(flow.get_selector_position(), SELECTOR_RADIUS, BALL_COLOR)
	canvas.draw_circle(flow.get_selector_position(), SELECTOR_RADIUS, CINNABAR_DARK, false, 2.0)


func _draw_map_transition(canvas: CanvasItem, flow: Object) -> void:
	var progress: float = clampf(float(flow.get_map_transition_progress()), 0.0, 1.0)
	var current: Vector2 = flow.get_rest_node_position()
	var target: Vector2 = flow.get_selected_target_position()
	var marker := current.lerp(target, progress)
	canvas.draw_circle(marker, 12.0 + 3.0 * sin(progress * PI), CINNABAR)
	canvas.draw_circle(marker, 18.0, GOLD, false, 3.0)
	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(80.0, 704.0),
		"선택한 행로로 이동 중",
		HORIZONTAL_ALIGNMENT_CENTER,
		600.0,
		20,
		INK
	)


func _vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Vector2i:
		return Vector2(value as Vector2i)
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO
