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
	_verify_standard_combat_budget_for_many_seeds()
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
	var phase: Dictionary = graph.phases[0]
	_expect(int(phase.total_floors) == 12, "tower graph must declare 12 floors")
	_expect(phase.floors.size() == 12, "tower graph must serialize all 12 floor bands")
	var node_by_id := _node_index(phase.nodes)
	var seen_kinds: Dictionary = {}
	for floor_index in range(phase.floors.size()):
		var floor_data: Dictionary = phase.floors[floor_index]
		var expected_rows := 1 if floor_index == 0 else 2
		_expect(floor_data.rows.size() == expected_rows, "floor %d must keep its temporary row allocation" % (floor_index + 1))
		var gate_row: Dictionary = floor_data.rows[floor_data.rows.size() - 1]
		_expect(bool(gate_row.gatekeeper), "each floor must end at an unavoidable gatekeeper row")
		_expect(gate_row.node_ids.size() == 1, "gatekeeper boundary rows must converge to one unavoidable node")
		var gate_node: Dictionary = node_by_id.get(str(gate_row.node_ids[0]), {})
		_expect(gate_node.kind == "boss" and bool(gate_node.floor_boundary), "floor boundary node must be a boss slot")
		if floor_index > 0:
			var route_row: Dictionary = floor_data.rows[0]
			_expect(route_row.node_ids.size() == 2, "non-boundary rows must retain exactly two candidates")
		for row_variant in floor_data.rows:
			for node_id_variant in (row_variant as Dictionary).node_ids:
				var node: Dictionary = node_by_id.get(str(node_id_variant), {})
				seen_kinds[str(node.get("kind", ""))] = true
				_expect(str(node.get("label", "")) == _label_for_kind(str(node.get("kind", "")), int(floor_data.floor)), "generated node labels must stay paired with their node kind")
				if int(floor_data.floor) > 9:
					_expect(bool(node.get("route_locked", false)), "10-12 floor metadata must remain unreachable before the true-ending gate")
	for required_kind in ["boss", "combat", "enraged", "shop", "training", "fallen_monk", "guardian_spring", "rest"]:
		_expect(seen_kinds.has(required_kind), "generated slots must include node kind: %s" % required_kind)


func _verify_standard_combat_budget_for_many_seeds() -> void:
	var generator := TowerAscentMapGenerator.new()
	for map_seed in [1, 2, 7, 31, 99, 83521, 700001]:
		var graph: Dictionary = generator.generate_tower(map_seed)
		var budget: Dictionary = generator.analyze_standard_combat_budget(graph)
		_expect(int(budget.minimum) >= TowerAscentTuning.TEMP_STANDARD_COMBAT_BUDGET_MIN, "minimum standard-route combat count must respect tuning for seed %d" % map_seed)
		_expect(int(budget.maximum) <= TowerAscentTuning.TEMP_STANDARD_COMBAT_BUDGET_MAX, "maximum standard-route combat count must respect tuning for seed %d" % map_seed)
		_expect(int(budget.minimum) == int(budget.maximum), "each generated optional row must keep all route choices inside one combat budget tier")


func _verify_flow_exposes_only_the_next_two_candidates() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {"run_id": "floor-flow", "map_seed": 83521}), "tower flow must start from the generated floor graph")
	var phases := flow.get_graph_phases()
	_expect(phases.size() == 1 and phases[0].floors.size() == 12, "flow owner must retain the full 12-floor phase")
	var targets := flow.get_route_target_ids()
	_expect(targets == ["floor_02_route_01_lane_01", "floor_02_route_01_lane_02"], "only the next generated row may be targeted after floor 1")


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
