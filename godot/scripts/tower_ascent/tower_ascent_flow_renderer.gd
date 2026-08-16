extends RefCounted

const PLAYFIELD_SIZE := Vector2(760.0, 750.0)
const MAP_RECT := Rect2(34.0, 24.0, 692.0, 702.0)
const MODAL_RECT := Rect2(120.0, 188.0, 520.0, 350.0)
const SELECTOR_RADIUS := 11.0
const MAP_NODE_RADIUS := 6.0
const ACTIVE_NODE_RADIUS := 13.0

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


func build_render_model(flow: Object) -> Dictionary:
	if flow == null:
		return {}
	var nodes: Array = flow.get_graph_nodes() if flow.has_method("get_graph_nodes") else []
	if nodes.is_empty():
		return {}
	return {
		"floors": flow.get_graph_floors() if flow.has_method("get_graph_floors") else [],
		"nodes": nodes,
		"edges": flow.get_graph_edges() if flow.has_method("get_graph_edges") else [],
		"active_candidate_ids": flow.get_route_target_ids() if flow.has_method("get_route_target_ids") else [],
		"current_node_id": str(flow.get_current_node_id()) if flow.has_method("get_current_node_id") else "",
		"selected_target_id": str(flow.get_selected_target_id()),
	}


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
	var floors: Array = flow.get_graph_floors()
	var active_candidate_ids: Array = flow.get_route_target_ids()
	var current_node_id := str(flow.get_current_node_id())
	var selected_target_id := str(flow.get_selected_target_id())
	_draw_floor_bands(canvas, floors, nodes)
	for edge_variant in edges:
		var edge: Dictionary = edge_variant
		var from_position := _find_node_position(nodes, str(edge.get("from", "")))
		var to_position := _find_node_position(nodes, str(edge.get("to", "")))
		canvas.draw_line(from_position, to_position, Color(INK_SOFT, 0.46), 1.5)
	for node_variant in nodes:
		var node: Dictionary = node_variant
		_draw_map_node(
			canvas,
			node,
			active_candidate_ids,
			current_node_id,
			selected_target_id
		)


func _draw_floor_bands(canvas: CanvasItem, floors: Array, nodes: Array) -> void:
	var font := ThemeDB.fallback_font
	for floor_variant in floors:
		if not (floor_variant is Dictionary):
			continue
		var floor_data := floor_variant as Dictionary
		var rows: Array = floor_data.get("rows", [])
		if rows.is_empty() or not (rows[rows.size() - 1] is Dictionary):
			continue
		var gate_ids: Array = (rows[rows.size() - 1] as Dictionary).get("node_ids", [])
		if gate_ids.is_empty():
			continue
		var gate_position := _find_node_position(nodes, str(gate_ids[0]))
		canvas.draw_line(Vector2(86.0, gate_position.y), Vector2(674.0, gate_position.y), Color(GOLD, 0.18), 1.0)
		canvas.draw_string(font, Vector2(53.0, gate_position.y + 4.0), "%dF" % int(floor_data.get("floor", 0)), HORIZONTAL_ALIGNMENT_CENTER, 30.0, 11, INK_SOFT)


func _find_node_position(nodes: Array, node_id: String) -> Vector2:
	for node_variant in nodes:
		var node: Dictionary = node_variant
		if str(node.get("id", "")) == node_id:
			return _vector2(node.get("position", Vector2.ZERO))
	return Vector2.ZERO


func _draw_map_node(
	canvas: CanvasItem,
	node: Dictionary,
	active_candidate_ids: Array,
	current_node_id: String,
	selected_target_id: String
) -> void:
	var position := _vector2(node.get("position", Vector2.ZERO))
	var node_id := str(node.get("id", ""))
	var completed := bool(node.get("completed", false))
	var active := active_candidate_ids.has(node_id)
	var current := node_id == current_node_id
	var selected := node_id == selected_target_id and not selected_target_id.is_empty()
	var skipped := bool(node.get("skipped", false))
	var route_locked := bool(node.get("route_locked", false))
	var enraged := bool(node.get("enraged", false))
	var radius := ACTIVE_NODE_RADIUS if active or current or selected else MAP_NODE_RADIUS
	var fill := GOLD if completed or current else PAPER_DEEP
	if route_locked or skipped:
		fill = SEALED
	elif enraged:
		fill = CINNABAR_DARK
	elif active:
		fill = Color("e6c15c")
	if selected:
		fill = CINNABAR
	canvas.draw_circle(position, radius, fill)
	canvas.draw_circle(position, radius, CINNABAR_DARK if active or selected else INK, false, 2.0 if active or current or selected else 1.0)
	if enraged:
		canvas.draw_circle(position, radius + 3.0, CINNABAR, false, 1.5)
	if skipped:
		canvas.draw_line(position + Vector2(-5.0, -5.0), position + Vector2(5.0, 5.0), PAPER, 1.5)
		canvas.draw_line(position + Vector2(5.0, -5.0), position + Vector2(-5.0, 5.0), PAPER, 1.5)
	var label := str(node.get("label", "노드"))
	var text_color := PAPER if selected else INK
	if active or selected:
		canvas.draw_string(
			ThemeDB.fallback_font,
			position + Vector2(-70.0, -17.0),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			140.0,
			12,
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
	for target_variant in flow.get_route_aim_targets():
		var target: Dictionary = target_variant
		var target_position := _vector2(target.get("position", Vector2.ZERO))
		var target_fill := CINNABAR_DARK if bool(target.get("enraged", false)) else PAPER_DEEP
		canvas.draw_circle(target_position, 30.0, target_fill)
		canvas.draw_circle(target_position, 30.0, CINNABAR, false, 3.0)
		canvas.draw_string(font, target_position + Vector2(-82.0, -41.0), str(target.get("label", "행로")), HORIZONTAL_ALIGNMENT_CENTER, 164.0, 16, INK)
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
