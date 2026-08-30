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
const TowerAuditionBuildConfig := preload(
	"res://scripts/tower_ascent/tower_audition_build_config.gd"
)

const DENSITY_SAMPLE_SEED_COUNT := 256
const DENSITY_SAMPLE_SEED_START := 1009
const DENSITY_SAMPLE_SEED_STEP := 7919

var _failures: Array[String] = []
var _generation_attempt_histogram: Dictionary = {}


func _init() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(false)
	_verify_12_floor_rows_and_node_slots()
	_verify_upper_floor_density_for_many_seeds()
	_verify_standard_distribution_for_many_seeds()
	_verify_flow_exposes_only_the_next_two_candidates()
	_verify_flag_off_remains_legacy()
	TowerAuditionBuildConfig.debug_clear_enabled_override()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print(
			"tower_ascent_12_floor_map_smoke: density_seeds=%d failures=0 total_rows=32 total_nodes=60..67 floor_1=4x9 floors_2_8=3x6..7 lanes_2_8=[1, 2, 3|4] floor_9=1x1 attempts=%s"
			% [DENSITY_SAMPLE_SEED_COUNT, str(_generation_attempt_histogram)]
		)
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
			else TowerAscentTuning.TEMP_OPTIONAL_ROWS_PER_FLOOR + 1
			if int(floor_data.floor) <= 9
			else TowerAscentTuning.TEMP_UNCHANGED_OPTIONAL_ROWS_PER_FLOOR + 1
		)
		_expect(floor_data.rows.size() == expected_rows, "floor %d must keep its temporary row allocation" % int(floor_data.floor))
		var gate_row: Dictionary = floor_data.rows[floor_data.rows.size() - 1]
		_expect(bool(gate_row.gatekeeper), "each floor must end at an unavoidable gatekeeper row")
		var floor_number := int(floor_data.floor)
		# 피드백2 8항: 모든 관문은 단일 레인 초크포인트다 — NPC 레인으로
		# 관문을 우회하는 경로가 존재하지 않는다.
		_expect(
			gate_row.node_ids.size() == 1,
			"floor %d gate must be the single-lane chokepoint" % floor_number
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
			# 단일 관문(prev=1) 다음 경로 행은 2레인으로 되살아나고, 신선계
			# 진입(클리어+1)만 의도된 단일로다.
			var expected_route_widths: Array = [1] if floor_number == 10 else [2]
			_expect(route_width in expected_route_widths, "floor %d route width must follow the chokepoint rhythm" % floor_number)
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
	for required_kind in ["boss", "shop", "training", "fallen_monk", "guardian_spring", "rest", "taiji_elder"]:
		_expect(seen_kinds.has(required_kind), "generated slots must include node kind: %s" % required_kind)


func _verify_upper_floor_density_for_many_seeds() -> void:
	var generator := TowerAscentMapGenerator.new()
	var generation_failure_count := 0
	for seed_offset in range(DENSITY_SAMPLE_SEED_COUNT):
		var map_seed := DENSITY_SAMPLE_SEED_START + seed_offset * DENSITY_SAMPLE_SEED_STEP
		var graph: Dictionary = generator.generate_tower(map_seed)
		if graph.is_empty():
			generation_failure_count += 1
			continue
		var generation_attempt := int(graph.get("generation_attempt", -1))
		_generation_attempt_histogram[generation_attempt] = int(
			_generation_attempt_histogram.get(generation_attempt, 0)
		) + 1
		var profile := _density_profile(graph)
		_expect(
			profile.get(1, {}) == {
				"rows": 4,
				"nodes": 9,
				"lanes": [1, 2, 3, 3],
			},
			"seed %d must preserve the 4-row 9-node first-floor profile" % map_seed
		)
		for floor_number in range(2, 9):
			var floor_profile: Dictionary = profile.get(floor_number, {})
			var floor_lanes: Array = floor_profile.get("lanes", [])
			_expect(
				int(floor_profile.get("rows", 0)) == 3
				and int(floor_profile.get("nodes", 0)) in [6, 7]
				and floor_lanes in [[1, 2, 3], [1, 2, 4]],
				"seed %d floor %d must expose a 1-to-2-to-3/4 density profile"
				% [map_seed, floor_number]
			)
		_expect(
			profile.get(9, {}) == {"rows": 1, "nodes": 1, "lanes": [1]},
			"seed %d floor 9 must remain the unchanged terminal gate" % map_seed
		)
		_expect(
			profile.get(10, {}) == {"rows": 3, "nodes": 4, "lanes": [1, 1, 2]}
			and profile.get(11, {}) == {"rows": 2, "nodes": 3, "lanes": [1, 2]}
			and profile.get(12, {}) == {"rows": 1, "nodes": 1, "lanes": [1]},
			"seed %d floors 10 through 12 must remain outside the density scope"
			% map_seed
		)
		_expect(
			_count_profile_value(profile, "rows") == 32
			and _count_profile_value(profile, "nodes") >= 60
			and _count_profile_value(profile, "nodes") <= 67,
			"seed %d must produce 32 rows and 60 to 67 nodes" % map_seed
		)
		_expect(
			_count_first_floor_choice_bosses(graph) == 2,
			"seed %d must preserve both first-floor selectable bosses" % map_seed
		)
		for floor_number in range(1, 10):
			_expect(
				_count_generated_gate_bosses(graph, floor_number) >= 1,
				"seed %d floor %d must retain an unavoidable generated gate boss"
				% [map_seed, floor_number]
			)
		_expect(
			_count_gate_bypasses(graph) == 0,
			"seed %d must expose zero paths around floors 1 through 8 gate bosses"
			% map_seed
		)
		var integrity: Dictionary = generator.analyze_graph_integrity(graph, true, true)
		_expect(
			bool(integrity.get("valid", false))
			and int(integrity.get("entry_unreachable_count", -1)) == 0
			and int(integrity.get("boss_unreachable_count", -1)) == 0
			and int(integrity.get("crossing_count", -1)) == 0
			and int(integrity.get("boss_spacing_violation_count", -1)) == 0
			and int(integrity.get("consecutive_single_transition_count", -1)) == 0
			and float(integrity.get("degree_two_ratio", 0.0)) + 0.000001
				>= TowerAscentTuning.TEMP_MAP_DEGREE_TWO_MIN_RATIO,
			"seed %d must pass reachability, spacing, crossing, singleton, and degree seals: %s"
			% [map_seed, str(integrity.get("issues", []))]
		)
	_expect(
		generation_failure_count == 0,
		"all %d density seeds must generate within %d attempts"
		% [DENSITY_SAMPLE_SEED_COUNT, TowerAscentMapGenerator.GENERATION_MAX_ATTEMPTS]
	)


func _density_profile(graph: Dictionary) -> Dictionary:
	var rows_by_floor: Dictionary = {}
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			var floor_number := int(node.get("segment_floor", 0))
			var global_row := int(node.get("global_row", -1))
			var floor_rows: Dictionary = rows_by_floor.get(floor_number, {})
			floor_rows[global_row] = int(floor_rows.get(global_row, 0)) + 1
			rows_by_floor[floor_number] = floor_rows
	var result: Dictionary = {}
	for floor_variant in rows_by_floor.keys():
		var floor_number := int(floor_variant)
		var floor_rows: Dictionary = rows_by_floor.get(floor_number, {})
		var row_numbers: Array = floor_rows.keys()
		row_numbers.sort()
		var lanes: Array[int] = []
		var node_count := 0
		for row_variant in row_numbers:
			var lane_count := int(floor_rows.get(row_variant, 0))
			lanes.append(lane_count)
			node_count += lane_count
		result[floor_number] = {
			"rows": row_numbers.size(),
			"nodes": node_count,
			"lanes": lanes,
		}
	return result


func _count_profile_value(profile: Dictionary, field: String) -> int:
	var result := 0
	for floor_variant in profile.values():
		if floor_variant is Dictionary:
			result += int((floor_variant as Dictionary).get(field, 0))
	return result


func _count_first_floor_choice_bosses(graph: Dictionary) -> int:
	var result := 0
	for node_variant in _all_nodes(graph):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		if (
			bool(node.get("floor_one_boss_choice", false))
			and str(node.get("kind", "")) in TowerAscentMapGenerator.COMBAT_NODE_KINDS
		):
			result += 1
	return result


func _count_generated_gate_bosses(graph: Dictionary, floor_number: int) -> int:
	var result := 0
	for node_variant in _all_nodes(graph):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		if (
			int(node.get("segment_floor", 0)) == floor_number
			and bool(node.get("gatekeeper", false))
			and str(node.get("content_state", "")) == "generated"
			and str(node.get("kind", "")) in TowerAscentMapGenerator.COMBAT_NODE_KINDS
		):
			result += 1
	return result


func _count_gate_bypasses(graph: Dictionary) -> int:
	var phases: Array = graph.get("phases", [])
	if phases.is_empty() or not (phases[0] is Dictionary):
		return 1
	var phase := phases[0] as Dictionary
	var result := 0
	for floor_number in range(1, 9):
		var blocked: Dictionary = {}
		for node_variant in phase.get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if (
				int(node.get("segment_floor", 0)) == floor_number
				and bool(node.get("gatekeeper", false))
			):
				blocked[str(node.get("id", ""))] = true
		var outgoing: Dictionary = {}
		for edge_variant in phase.get("edges", []):
			if not (edge_variant is Dictionary):
				continue
			var edge := edge_variant as Dictionary
			var from_id := str(edge.get("from", ""))
			var to_id := str(edge.get("to", ""))
			if blocked.has(from_id) or blocked.has(to_id):
				continue
			var targets: Array = outgoing.get(from_id, [])
			targets.append(to_id)
			outgoing[from_id] = targets
		var reachable := _walk(str(phase.get("entry_node_id", "")), outgoing)
		var bypass_found := false
		for node_variant in phase.get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if (
				int(node.get("segment_floor", 0)) > floor_number
				and reachable.has(str(node.get("id", "")))
			):
				bypass_found = true
				break
		if bypass_found:
			result += 1
	return result


func _all_nodes(graph: Dictionary) -> Array:
	var result: Array = []
	for phase_variant in graph.get("phases", []):
		if phase_variant is Dictionary:
			result.append_array((phase_variant as Dictionary).get("nodes", []))
	return result


func _walk(start_id: String, adjacency: Dictionary) -> Dictionary:
	var visited: Dictionary = {}
	var pending: Array[String] = []
	if not start_id.is_empty():
		visited[start_id] = true
		pending.append(start_id)
	while not pending.is_empty():
		var current_id: String = pending.pop_back()
		for target_variant in adjacency.get(current_id, []):
			var target_id := str(target_variant)
			if visited.has(target_id):
				continue
			visited[target_id] = true
			pending.append(target_id)
	return visited


func _verify_standard_distribution_for_many_seeds() -> void:
	var generator := TowerAscentMapGenerator.new()
	for map_seed in [1, 2, 7, 31, 99, 83521, 700001]:
		var graph: Dictionary = generator.generate_tower(map_seed)
		var integrity: Dictionary = generator.analyze_graph_integrity(graph, true, true)
		_expect(bool(integrity.get("valid", false)), "standard distribution contract must hold for seed %d" % map_seed)
		_expect(
			float(integrity.get("boss_ratio", 1.0))
			<= TowerAscentTuning.TEMP_GENERATED_BOSS_NODE_MAX_RATIO + 0.000001,
			"generated boss density must stay at or below the tuned ceiling for seed %d" % map_seed
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
			return "모닥불"
		"taiji_elder":
			return "태극노인"
	return "노드"


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
