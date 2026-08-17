extends RefCounted

const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const PLAYFIELD_SIZE := Vector2(760.0, 750.0)
const MAP_RECT := Rect2(34.0, 24.0, 692.0, 702.0)
const MODAL_RECT := Rect2(78.0, 112.0, 604.0, 548.0)
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
func draw(canvas: CanvasItem, flow: Object) -> void:
	if canvas == null or flow == null or not flow.has_method("is_active") or not bool(flow.is_active()):
		return
	var phase_name := str(flow.get_phase_name())
	if phase_name == "ROUTE_AIM":
		_draw_route_aim(canvas, flow)
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color(0.035, 0.025, 0.02, 0.92), true)
	canvas.draw_rect(MAP_RECT, PAPER, true)
	canvas.draw_rect(MAP_RECT, INK, false, 4.0)
	canvas.draw_rect(MAP_RECT.grow(-8.0), PAPER_DEEP, false, 1.5)
	_draw_title(canvas, flow)
	_draw_route_map(canvas, flow)
	if phase_name == "NODE_MODAL":
		_draw_node_modal(canvas, flow)
	elif phase_name == "MAP_TRANSITION":
		_draw_map_transition(canvas, flow)
	elif phase_name == "FAKE_ENDING_TEASER":
		_draw_fake_ending_teaser(canvas, flow)
	elif phase_name == "ENDING_CHOICE":
		_draw_ending_choice(canvas, flow)
	elif phase_name == "RUN_SETTLEMENT":
		_draw_run_settlement(canvas, flow)
	elif phase_name == "GAUNTLET_TRANSITION":
		_draw_gauntlet_transition(canvas, flow)


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


func _draw_node_modal(canvas: CanvasItem, flow: Object) -> void:
	var model: Dictionary = (
		flow.get_node_modal_view_model()
		if flow.has_method("get_node_modal_view_model")
		else {}
	)
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color(0.06, 0.04, 0.025, 0.54), true)
	canvas.draw_rect(MODAL_RECT, Color("f7e9c8"), true)
	canvas.draw_rect(MODAL_RECT, CINNABAR_DARK, false, 5.0)
	canvas.draw_rect(MODAL_RECT.grow(-13.0), GOLD, false, 2.0)
	var font := ThemeDB.fallback_font
	canvas.draw_string(
		font,
		Vector2(126.0, 178.0),
		str(model.get("title", "행로 정비")),
		HORIZONTAL_ALIGNMENT_CENTER,
		508.0,
		30,
		INK
	)
	canvas.draw_line(Vector2(126.0, 195.0), Vector2(634.0, 195.0), GOLD, 2.0)
	canvas.draw_string(
		font,
		Vector2(126.0, 224.0),
		str(model.get("description", "")),
		HORIZONTAL_ALIGNMENT_CENTER,
		508.0,
		16,
		INK_SOFT
	)
	_draw_balance_badge(canvas, Rect2(190.0, 242.0, 176.0, 38.0), str(model.get("muhon_text", "무혼 0")))
	_draw_balance_badge(canvas, Rect2(394.0, 242.0, 176.0, 38.0), str(model.get("gold_text", "골드 0")))
	var actions: Array = model.get("actions", [])
	var selected_index := int(model.get("selected_index", 0))
	for index in range(actions.size()):
		if not (actions[index] is Dictionary):
			continue
		var row_rect := Rect2(
			126.0,
			301.0 + float(index) * 43.0,
			508.0,
			38.0
		)
		_draw_modal_action_row(
			canvas,
			row_rect,
			actions[index] as Dictionary,
			index == selected_index
		)
	canvas.draw_string(
		font,
		Vector2(126.0, 635.0),
		str(model.get("status_text", "")),
		HORIZONTAL_ALIGNMENT_CENTER,
		508.0,
		14,
		INK_SOFT
	)


func _draw_balance_badge(canvas: CanvasItem, rect: Rect2, label: String) -> void:
	canvas.draw_rect(rect, Color(PAPER_DEEP, 0.62), true)
	canvas.draw_rect(rect, GOLD, false, 1.5)
	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(rect.position.x, rect.position.y + 25.0),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		16,
		INK
	)


func _draw_modal_action_row(
	canvas: CanvasItem,
	rect: Rect2,
	action: Dictionary,
	selected: bool
) -> void:
	var enabled := bool(action.get("enabled", true))
	var fill := CINNABAR if selected and enabled else Color(PAPER_DEEP, 0.72)
	var text_color := PAPER if selected and enabled else INK
	if not enabled:
		fill = Color(SEALED, 0.32)
		text_color = Color(SEALED, 0.84)
	canvas.draw_rect(rect, fill, true)
	canvas.draw_rect(rect, CINNABAR_DARK if selected else GOLD, false, 2.0 if selected else 1.0)
	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(rect.position.x + 14.0, rect.position.y + 25.0),
		str(action.get("label", "")),
		HORIZONTAL_ALIGNMENT_LEFT,
		rect.size.x - 150.0,
		16,
		text_color
	)
	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(rect.end.x - 130.0, rect.position.y + 25.0),
		str(action.get("cost_text", "")),
		HORIZONTAL_ALIGNMENT_RIGHT,
		116.0,
		14,
		text_color
	)


func _draw_route_aim(canvas: CanvasItem, flow: Object) -> void:
	var font := ThemeDB.fallback_font
	for target_variant in flow.get_route_aim_targets():
		var target: Dictionary = target_variant
		var target_position := _vector2(target.get("position", Vector2.ZERO))
		var target_radius := float(target.get("draw_radius", TowerAscentTuning.TEMP_ROUTE_TARGET_DRAW_RADIUS))
		var target_fill := CINNABAR_DARK if bool(target.get("enraged", false)) else PAPER_DEEP
		canvas.draw_circle(target_position, target_radius, target_fill)
		canvas.draw_circle(target_position, target_radius, CINNABAR, false, 3.0)
		var label_rect := Rect2(
			target_position.x - TowerAscentTuning.TEMP_ROUTE_TARGET_LABEL_WIDTH * 0.5,
			target_position.y - target_radius - TowerAscentTuning.TEMP_ROUTE_TARGET_LABEL_GAP - TowerAscentTuning.TEMP_ROUTE_TARGET_LABEL_HEIGHT,
			TowerAscentTuning.TEMP_ROUTE_TARGET_LABEL_WIDTH,
			TowerAscentTuning.TEMP_ROUTE_TARGET_LABEL_HEIGHT
		)
		canvas.draw_rect(label_rect, Color(0.04, 0.025, 0.02, 0.86), true)
		canvas.draw_rect(label_rect, GOLD, false, 1.5)
		canvas.draw_string(font, label_rect.position + Vector2(0.0, 21.0), str(target.get("label", "행로")), HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x, 16, PAPER)
	canvas.draw_string(font, Vector2(80.0, 694.0), "서브로 다음 행로의 표적을 맞히세요", HORIZONTAL_ALIGNMENT_CENTER, 600.0, 18, PAPER)
	canvas.draw_string(font, Vector2(80.0, 716.0), "명중할 때까지 다시 서브할 수 있습니다", HORIZONTAL_ALIGNMENT_CENTER, 600.0, 15, Color(PAPER, 0.82))


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


func _draw_fake_ending_teaser(canvas: CanvasItem, flow: Object) -> void:
	var model: Dictionary = (
		flow.get_ending_view_model()
		if flow.has_method("get_ending_view_model")
		else {}
	)
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color(0.02, 0.012, 0.01, 0.84), true)
	var panel := Rect2(104.0, 214.0, 552.0, 292.0)
	canvas.draw_rect(panel, Color("201813"), true)
	canvas.draw_rect(panel, CINNABAR, false, 4.0)
	canvas.draw_rect(panel.grow(-12.0), GOLD, false, 1.5)
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(144.0, 286.0), str(model.get("title", "가짜 끝")), HORIZONTAL_ALIGNMENT_CENTER, 472.0, 30, PAPER)
	canvas.draw_line(Vector2(166.0, 310.0), Vector2(594.0, 310.0), Color(GOLD, 0.72), 2.0)
	canvas.draw_string(font, Vector2(132.0, 374.0), str(model.get("body", "")), HORIZONTAL_ALIGNMENT_CENTER, 496.0, 24, Color("f3dba8"))
	canvas.draw_string(font, Vector2(132.0, 454.0), str(model.get("prompt", "")), HORIZONTAL_ALIGNMENT_CENTER, 496.0, 15, Color(PAPER, 0.78))


func _draw_ending_choice(canvas: CanvasItem, flow: Object) -> void:
	var model: Dictionary = (
		flow.get_ending_choice_view_model()
		if flow.has_method("get_ending_choice_view_model")
		else {}
	)
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color(0.02, 0.012, 0.01, 0.84), true)
	var panel := Rect2(104.0, 156.0, 552.0, 430.0)
	canvas.draw_rect(panel, Color("f3e1b8"), true)
	canvas.draw_rect(panel, CINNABAR_DARK, false, 5.0)
	canvas.draw_rect(panel.grow(-12.0), GOLD, false, 1.5)
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(144.0, 226.0), str(model.get("title", "왕의 시련")), HORIZONTAL_ALIGNMENT_CENTER, 472.0, 30, INK)
	canvas.draw_string(font, Vector2(132.0, 286.0), str(model.get("body", "")), HORIZONTAL_ALIGNMENT_CENTER, 496.0, 17, INK_SOFT)
	var actions: Array = model.get("actions", [])
	var selected_index := int(model.get("selected_index", 0))
	for index in range(actions.size()):
		var rect := Rect2(158.0, 382.0 + float(index) * 64.0, 444.0, 50.0)
		var selected := index == selected_index
		canvas.draw_rect(rect, CINNABAR if selected else Color(PAPER_DEEP, 0.76), true)
		canvas.draw_rect(rect, CINNABAR_DARK, false, 2.0)
		canvas.draw_string(font, Vector2(rect.position.x, rect.position.y + 33.0), str((actions[index] as Dictionary).get("label", "")), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, PAPER if selected else INK)
	canvas.draw_string(font, Vector2(132.0, 548.0), str(model.get("prompt", "")), HORIZONTAL_ALIGNMENT_CENTER, 496.0, 14, CINNABAR_DARK)


func _draw_run_settlement(canvas: CanvasItem, flow: Object) -> void:
	var model: Dictionary = (
		flow.get_settlement_view_model()
		if flow.has_method("get_settlement_view_model")
		else {}
	)
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color(0.018, 0.012, 0.01, 0.9), true)
	var panel := Rect2(86.0, 76.0, 588.0, 598.0)
	canvas.draw_rect(panel, Color("f2dfb7"), true)
	canvas.draw_rect(panel, CINNABAR_DARK, false, 5.0)
	canvas.draw_rect(panel.grow(-12.0), GOLD, false, 1.5)
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(126.0, 137.0), str(model.get("title", "등정 종료")), HORIZONTAL_ALIGNMENT_CENTER, 508.0, 30, INK)
	canvas.draw_string(font, Vector2(544.0, 137.0), str(model.get("floor_text", "")), HORIZONTAL_ALIGNMENT_RIGHT, 70.0, 17, CINNABAR_DARK)
	canvas.draw_string(font, Vector2(116.0, 177.0), str(model.get("body", "")), HORIZONTAL_ALIGNMENT_CENTER, 528.0, 16, INK_SOFT)
	_draw_settlement_section(
		canvas,
		Rect2(116.0, 208.0, 528.0, 176.0),
		str(model.get("lost_build_title", "")),
		model.get("lost_build_rows", [])
	)
	_draw_settlement_section(
		canvas,
		Rect2(116.0, 402.0, 528.0, 176.0),
		str(model.get("persistent_income_title", "")),
		model.get("persistent_income_rows", [])
	)
	canvas.draw_string(font, Vector2(126.0, 632.0), str(model.get("prompt", "")), HORIZONTAL_ALIGNMENT_CENTER, 508.0, 15, CINNABAR_DARK)


func _draw_settlement_section(
	canvas: CanvasItem,
	rect: Rect2,
	title: String,
	rows_value: Variant
) -> void:
	canvas.draw_rect(rect, Color(PAPER_DEEP, 0.42), true)
	canvas.draw_rect(rect, GOLD, false, 1.5)
	canvas.draw_string(ThemeDB.fallback_font, rect.position + Vector2(18.0, 30.0), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 36.0, 18, INK)
	var rows: Array = rows_value if rows_value is Array else []
	for index in range(mini(rows.size(), 6)):
		canvas.draw_string(
			ThemeDB.fallback_font,
			rect.position + Vector2(28.0, 60.0 + float(index) * 20.0),
			"· %s" % str(rows[index]),
			HORIZONTAL_ALIGNMENT_LEFT,
			rect.size.x - 56.0,
			13,
			INK_SOFT
		)


func _draw_gauntlet_transition(canvas: CanvasItem, flow: Object) -> void:
	var model: Dictionary = (
		flow.get_gauntlet_transition_view_model()
		if flow.has_method("get_gauntlet_transition_view_model")
		else {}
	)
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color(0.018, 0.012, 0.01, 0.9), true)
	var panel := Rect2(104.0, 170.0, 552.0, 390.0)
	canvas.draw_rect(panel, Color("201813"), true)
	canvas.draw_rect(panel, CINNABAR, false, 5.0)
	canvas.draw_rect(panel.grow(-12.0), GOLD, false, 1.5)
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(144.0, 242.0), str(model.get("title", "4천왕 연전")), HORIZONTAL_ALIGNMENT_CENTER, 472.0, 30, PAPER)
	canvas.draw_line(Vector2(166.0, 268.0), Vector2(594.0, 268.0), Color(GOLD, 0.72), 2.0)
	canvas.draw_string(font, Vector2(132.0, 322.0), str(model.get("body", "")), HORIZONTAL_ALIGNMENT_CENTER, 496.0, 19, Color("f3dba8"))
	var opponent: Dictionary = model.get("opponent", {})
	canvas.draw_rect(Rect2(176.0, 352.0, 408.0, 54.0), Color(CINNABAR_DARK, 0.82), true)
	canvas.draw_string(
		font,
		Vector2(176.0, 387.0),
		str(opponent.get("display_name", "4천왕 슬롯")),
		HORIZONTAL_ALIGNMENT_CENTER,
		408.0,
		20,
		PAPER
	)
	canvas.draw_string(font, Vector2(132.0, 450.0), str(model.get("preserve", "")), HORIZONTAL_ALIGNMENT_CENTER, 496.0, 15, Color(PAPER, 0.82))
	canvas.draw_string(font, Vector2(132.0, 516.0), str(model.get("prompt", "")), HORIZONTAL_ALIGNMENT_CENTER, 496.0, 15, Color(GOLD, 0.9))


func _vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Vector2i:
		return Vector2(value as Vector2i)
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO
