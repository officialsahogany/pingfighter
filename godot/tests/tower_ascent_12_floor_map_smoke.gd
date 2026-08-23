extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	_verify_12_floor_rows_and_node_slots()
	_verify_standard_distribution_for_many_seeds()
	_verify_flow_exposes_only_the_next_two_candidates()
	_verify_flag_off_remains_legacy()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_12_floor_map_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_12_floor_rows_and_node_slots() -> void:
	var graph: Dictionary = TowerAscentMapGenerator.new().generate_tower(83521)
	_expect(not graph.is_empty(), "12-floor generator must produce a graph")
	_expect(graph.phases.size() == 2, "tower graph must serialize human and immortal realm phases")
	var human_phase: Dictionary = graph.phases[0]
	var immortal_phase: Dictionary = graph.phases[1]
	_expect(str(human_phase.id) == TowerAscentMapGenerator.HUMAN_REALM_PHASE_ID, "phase 1 must be the human realm")
	_expect(str(immortal_phase.id) == TowerAscentMapGenerator.IMMORTAL_REALM_PHASE_ID, "phase 2 must be the immortal realm")
	_expect(human_phase.floors.size() == 9, "human realm must serialize floors 1 through 9")
	_expect(immortal_phase.floors.size() == 3, "immortal realm must serialize floors 10 through 12")
	var all_nodes: Array = human_phase.nodes.duplicate()
	all_nodes.append_array(immortal_phase.nodes)
	var node_by_id := _node_index(all_nodes)
	var seen_kinds: Dictionary = {}
	var all_floors: Array = human_phase.floors.duplicate()
	all_floors.append_array(immortal_phase.floors)
	for floor_index in range(all_floors.size()):
		var floor_data: Dictionary = all_floors[floor_index]
		var expected_rows := (
			1
			if int(floor_data.floor) == 1
			else 2 + TowerAscentMapGenerator.FLOOR_ONE_EXPANSION_ROW_ROLES.size()
			if int(floor_data.floor) == 2
			else 2
		)
		_expect(floor_data.rows.size() == expected_rows, "floor %d must keep its temporary row allocation" % int(floor_data.floor))
		var gate_row: Dictionary = floor_data.rows[floor_data.rows.size() - 1]
		_expect(bool(gate_row.gatekeeper), "each floor must end at an unavoidable gatekeeper row")
		var floor_number := int(floor_data.floor)
		var expected_singleton_gate := floor_number in [1, 9, 11, 12]
		_expect(
			gate_row.node_ids.size() == 1 if expected_singleton_gate else gate_row.node_ids.size() in [2, 3],
			"floor %d gate width must preserve branches except at true realm/group endpoints" % floor_number
		)
		for gate_node_id_variant in gate_row.node_ids:
			var gate_node: Dictionary = node_by_id.get(str(gate_node_id_variant), {})
			_expect(bool(gate_node.floor_boundary), "floor boundary metadata must survive boss-pool normalization")
			_expect(
				str(gate_node.get("kind", "")) == "boss"
				or str(gate_node.get("boss_assignment_state", "")) == "npc_fill",
				"floor boundary lanes must be a unique boss or deterministic NPC fill"
			)
		if floor_index > 0:
			var route_row: Dictionary = floor_data.rows[0]
			var route_width: int = (route_row.get("node_ids", []) as Array).size()
			var expected_route_widths: Array = [1] if floor_number == 10 else ([2] if floor_number in [2, 12] else [3, 4])
			_expect(route_width in expected_route_widths, "floor %d route width must follow the seeded narrow/wide rhythm" % floor_number)
		for row_variant in floor_data.rows:
			for node_id_variant in (row_variant as Dictionary).node_ids:
				var node: Dictionary = node_by_id.get(str(node_id_variant), {})
				seen_kinds[str(node.get("kind", ""))] = true
				if node.has("boss_slot_id"):
					_expect(not str(node.get("label", "")).is_empty(), "registry-decorated combat nodes must expose their canonical slot label")
				else:
					_expect(str(node.get("label", "")) == _label_for_kind(str(node.get("kind", "")), int(floor_data.floor)), "generated node labels must stay paired with their node kind")
				if int(floor_data.floor) > 9:
					_expect(bool(node.get("route_locked", false)), "10-12 floor metadata must remain unreachable before the true-ending gate")
	for required_kind in ["boss", "shop", "training", "fallen_monk", "guardian_spring", "rest"]:
		_expect(seen_kinds.has(required_kind), "generated slots must include node kind: %s" % required_kind)


func _verify_standard_distribution_for_many_seeds() -> void:
	var generator := TowerAscentMapGenerator.new()
	for map_seed in [1, 2, 7, 31, 99, 83521, 700001]:
		var graph: Dictionary = generator.generate_tower(map_seed)
		var integrity: Dictionary = generator.analyze_graph_integrity(graph, true, true)
		_expect(bool(integrity.get("valid", false)), "standard distribution contract must hold for seed %d" % map_seed)
		_expect(
			float(integrity.get("boss_ratio", 1.0))
			<= TowerAscentTuning.TEMP_GENERATED_BOSS_NODE_MAX_RATIO + 0.000001,
			"generated boss density must stay at or below twenty percent for seed %d" % map_seed
		)
		_expect(
			int(integrity.get("npc_node_count", 0))
			>= int(integrity.get("combat_node_count", 0)) * TowerAscentTuning.TEMP_GENERATED_NPC_PER_BOSS_MIN,
			"generated NPC nodes must outnumber bosses by at least four to one for seed %d" % map_seed
		)


func _verify_flow_exposes_only_the_next_two_candidates() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {"run_id": "floor-flow", "map_seed": 83521}), "tower flow must start from the generated floor graph")
	var phases := flow.get_graph_phases()
	_expect(phases.size() == 2, "flow owner must retain both realm phases")
	_expect(phases[0].floors.size() == 9 and phases[1].floors.size() == 3, "flow owner must retain the 9 plus 3 floor split")
	_expect(flow.get_active_graph_phase_index() == 0, "ordinary tower start must activate only the human realm")
	for node in flow.get_graph_nodes():
		_expect(int(node.get("floor", 0)) <= 9, "phase-1 disclosure must not leak phase-2 nodes")
	_expect((flow.get_locked_phase_hints() as Array).size() == 1, "phase 1 must preserve one locked immortal-realm hint")
	var targets := flow.get_route_target_ids()
	_expect(
		targets == [
			"floor_01_expansion_route_01_lane_01",
			"floor_01_expansion_route_01_lane_02",
		],
		"only the next expanded first-floor NPC row may be targeted after the start boss"
	)


func _verify_flag_off_remains_legacy() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	_expect(not TowerAscentFlowOwner.new().begin_vertical_slice(null, Callable(), {"run_id": "off", "map_seed": 1}), "flag OFF must not enter the generated tower")


func _node_index(nodes: Array) -> Dictionary:
	var result: Dictionary = {}
	for node_variant in nodes:
		if node_variant is Dictionary:
			var node := node_variant as Dictionary
			result[str(node.get("id", ""))] = node
	return result


func _label_for_kind(node_kind: String, floor_number: int) -> String:
	match node_kind:
		"boss":
			return "%d층 수문장" % floor_number
		"combat":
			return "전투"
		"enraged":
			return "광폭화"
		"shop":
			return "상점"
		"training":
			return "수련장"
		"fallen_monk":
			return "파계승"
		"guardian_spring":
			return "샘터"
		"rest":
			return "휴식"
	return "노드"


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
