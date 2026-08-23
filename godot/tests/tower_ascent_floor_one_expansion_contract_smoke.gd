extends SceneTree

const TowerAscentBossRegistry := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd"
)
const TowerAuditionBuildConfig := preload(
	"res://scripts/tower_ascent/tower_audition_build_config.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)
const TowerAscentMapPathGeometry := preload(
	"res://scripts/tower_ascent/tower_ascent_map_path_geometry.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const SAMPLE_SEED_COUNT := 128
const MAP_DRAW_CALL_LIMIT := 1536
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))

var _failures: Array[String] = []
var _optional_second_count := 0
var _guaranteed_only_count := 0
var _generated_node_count := 0
var _combat_node_count := 0
var _npc_node_count := 0
var _degree_one_count := 0
var _degree_two_count := 0
var _branch_eligible_count := 0
var _service_counts: Dictionary = {}
var _maximum_draw_calls := 0
var _maximum_draw_seed := 0
var _maximum_path_draw_calls := 0
var _maximum_cloud_draw_calls := 0
var _maximum_dot_gap := 0.0
var _minimum_fit_all_zoom := INF
var _maximum_world_height := 0.0
var _negative_leg_count := 0
var _negative_fixture: Dictionary = {}


func _init() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(false)
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_standard_seeds()
	_verify_audition_route_unchanged()
	_verify_negative_legs()
	TowerAuditionBuildConfig.debug_clear_enabled_override()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print(
			"tower_ascent_floor_one_expansion_contract_smoke: seeds=%d guaranteed_only=%d optional_second=%d generated=%d boss=%d npc=%d boss_ratio=%0.4f degree1=%d degree2=%d degree2_ratio=%0.4f services=%s"
			% [
				SAMPLE_SEED_COUNT,
				_guaranteed_only_count,
				_optional_second_count,
				_generated_node_count,
				_combat_node_count,
				_npc_node_count,
				_safe_ratio(_combat_node_count, _generated_node_count),
				_degree_one_count,
				_degree_two_count,
				_safe_ratio(_degree_two_count, _branch_eligible_count),
				str(_service_counts),
			]
		)
		print(
			"tower_ascent_floor_one_expansion_contract_smoke: fit_all_budget seed=%d path=%d clouds=%d total=%d limit=%d max_dot_gap=%0.3f min_fit_all=%0.4f world_height=%0.1f negative_legs=%d"
			% [
				_maximum_draw_seed,
				_maximum_path_draw_calls,
				_maximum_cloud_draw_calls,
				_maximum_draw_calls,
				MAP_DRAW_CALL_LIMIT,
				_maximum_dot_gap,
				_minimum_fit_all_zoom,
				_maximum_world_height,
				_negative_leg_count,
			]
		)
		print("tower_ascent_floor_one_expansion_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_standard_seeds() -> void:
	var generator := TowerAscentMapGenerator.new()
	for seed_offset in range(SAMPLE_SEED_COUNT):
		var map_seed := 7001 + seed_offset * 7919
		var graph := generator.generate_tower(map_seed)
		var repeated := generator.generate_tower(map_seed)
		_expect(not graph.is_empty(), "seed %d must generate an expanded tower" % map_seed)
		if graph.is_empty():
			continue
		_expect(
			generator.encode_graph(graph) == generator.encode_graph(repeated),
			"seed %d expansion must remain byte deterministic" % map_seed
		)
		_expect(
			int(graph.get("floor_one_expansion_row_count", 0))
				== TowerAscentMapGenerator.FLOOR_ONE_EXPANSION_ROW_ROLES.size(),
			"seed %d must declare every first-floor expansion row" % map_seed
		)
		var phases: Array = graph.get("phases", [])
		_expect(phases.size() == 2, "seed %d must retain both phases" % map_seed)
		if phases.is_empty() or not (phases[0] is Dictionary):
			continue
		var human_phase := phases[0] as Dictionary
		_verify_floor_one_graph(map_seed, human_phase)
		var integrity := generator.analyze_graph_integrity(graph, true, true)
		_expect(
			bool(integrity.get("valid", false)),
			"seed %d full integrity must be GREEN: %s"
			% [map_seed, str(integrity.get("issues", []))]
		)
		_expect(
			bool(integrity.get("floor_one_boss_avoidance_path", false)),
			"seed %d analyzer must seal the boss-avoidance path" % map_seed
		)
		var added_node_count := 0
		var floor_one_choice_count := 0
		for node_variant in human_phase.get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if bool(node.get("floor_one_expansion_added_node", false)):
				added_node_count += 1
			if bool(node.get("floor_one_boss_choice", false)):
				floor_one_choice_count += 1
		_expect(
			added_node_count == 10,
			"seed %d must identify exactly ten first-floor-added nodes" % map_seed
		)
		var baseline_boss_budget := floori(
			float(int(integrity.get("generated_node_count", 0)) - added_node_count)
			* TowerAscentTuning.TEMP_GENERATED_BOSS_NODE_MAX_RATIO
		)
		_expect(
			int(integrity.get("combat_node_count", 0))
				== baseline_boss_budget + floor_one_choice_count,
			"seed %d must add bosses only for actual first-floor encounter rows"
			% map_seed
		)
		_generated_node_count += int(integrity.get("generated_node_count", 0))
		_combat_node_count += int(integrity.get("combat_node_count", 0))
		_npc_node_count += int(integrity.get("npc_node_count", 0))
		_degree_one_count += int(integrity.get("degree_one_node_count", 0))
		_degree_two_count += int(integrity.get("degree_two_node_count", 0))
		_branch_eligible_count += int(integrity.get("branch_eligible_node_count", 0))
		for phase_variant in phases:
			if not (phase_variant is Dictionary):
				continue
			for node_variant in (phase_variant as Dictionary).get("nodes", []):
				if not (node_variant is Dictionary):
					continue
				var node := node_variant as Dictionary
				var node_kind := str(node.get("kind", ""))
				if (
					str(node.get("content_state", "")) == "generated"
					and node_kind in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS
				):
					_service_counts[node_kind] = int(
						_service_counts.get(node_kind, 0)
					) + 1
		if _negative_fixture.is_empty():
			_negative_fixture = graph.duplicate(true)
		_verify_fit_all_budget(map_seed)
	_expect(_guaranteed_only_count > 0, "128 seeds must exercise the one-extra-boss outcome")
	_expect(_optional_second_count > 0, "128 seeds must exercise the two-extra-boss outcome")
	var optional_ratio := _safe_ratio(_optional_second_count, SAMPLE_SEED_COUNT)
	_expect(
		optional_ratio >= 0.35 and optional_ratio <= 0.65,
		"derived optional encounter should remain near its current 1/(1+1) share"
	)
	_expect(
		_safe_ratio(_combat_node_count, _generated_node_count)
			<= TowerAscentTuning.TEMP_GENERATED_BOSS_NODE_MAX_RATIO + 0.000001,
		"128-seed boss density must stay at or below twenty percent"
	)
	_expect(
		_safe_ratio(_degree_two_count, _branch_eligible_count)
			+ 0.000001 >= TowerAscentTuning.TEMP_MAP_DEGREE_TWO_MIN_RATIO,
		"128-seed two-choice ratio must stay at or above seventy percent"
	)


func _verify_floor_one_graph(map_seed: int, phase: Dictionary) -> void:
	var rows := _ordered_rows(phase)
	var node_by_id := _node_index(phase.get("nodes", []))
	var expansion_row_count := 0
	var boss_choice_rows: Array[int] = []
	var floor_one_combat_rows: Array[int] = []
	var floor_one_keys: Dictionary = {}
	for row_index in range(rows.size()):
		var row := rows[row_index]
		var row_ids := _string_array(row.get("node_ids", []))
		var row_is_expansion := false
		var combat_count := 0
		var npc_count := 0
		var row_is_boss_choice := false
		for node_id in row_ids:
			var node: Dictionary = node_by_id.get(node_id, {})
			row_is_expansion = row_is_expansion or bool(
				node.get("floor_one_expansion_row", false)
			)
			row_is_boss_choice = row_is_boss_choice or bool(
				node.get("floor_one_boss_choice_row", false)
			)
			var kind := str(node.get("kind", ""))
			if (
				int(node.get("segment_floor", 0)) == 1
				and str(node.get("content_state", "")) == "generated"
				and kind in TowerAscentMapGenerator.COMBAT_NODE_KINDS
			):
				combat_count += 1
				var standin: Dictionary = node.get("standin", {})
				_expect(
					int(standin.get("stage", 0)) == 1,
					"seed %d first-floor combat must stay in the approved stage-1 pool"
					% map_seed
				)
				var encounter_key := TowerAscentBossRegistry.new().canonical_encounter_key(
					standin
				)
				_expect(
					not encounter_key.is_empty() and not floor_one_keys.has(encounter_key),
					"seed %d start and optional first-floor bosses must be unique"
					% map_seed
				)
				floor_one_keys[encounter_key] = true
			elif kind in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS:
				npc_count += 1
		if row_is_expansion:
			expansion_row_count += 1
		if combat_count > 0:
			floor_one_combat_rows.append(row_index)
		if row_is_boss_choice:
			boss_choice_rows.append(row_index)
			_expect(
				row_ids.size() == 2 and combat_count == 1 and npc_count == 1,
				"seed %d first-floor encounter row must be a boss-vs-NPC choice"
				% map_seed
			)
	_expect(
		expansion_row_count == TowerAscentMapGenerator.FLOOR_ONE_EXPANSION_ROW_ROLES.size(),
		"seed %d must retain exactly four scoped expansion rows" % map_seed
	)
	_expect(
		boss_choice_rows.size() in [1, 2],
		"seed %d must expose one or two selectable first-floor boss rows" % map_seed
	)
	_expect(
		floor_one_keys.size() == boss_choice_rows.size() + 1,
		"seed %d first-floor pool consumption must equal start plus encounter rows"
		% map_seed
	)
	if boss_choice_rows.size() == 2:
		_optional_second_count += 1
	else:
		_guaranteed_only_count += 1
	for combat_row_index in range(1, floor_one_combat_rows.size()):
		var previous_row := floor_one_combat_rows[combat_row_index - 1]
		var current_row := floor_one_combat_rows[combat_row_index]
		_expect(
			current_row - previous_row >= 2,
			"seed %d first-floor boss rows need a complete intervening NPC row"
			% map_seed
		)
		for separator_index in range(previous_row + 1, current_row):
			for node_id in _string_array(rows[separator_index].get("node_ids", [])):
				var separator_node: Dictionary = node_by_id.get(node_id, {})
				_expect(
					str(separator_node.get("kind", ""))
						in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS,
					"seed %d every row between first-floor bosses must be all-NPC"
					% map_seed
				)
	_expect(
		_has_boss_avoidance_path(phase),
		"seed %d must provide a path that avoids every optional first-floor boss"
		% map_seed
	)


func _verify_fit_all_budget(map_seed: int) -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(
		flow.begin_vertical_slice(null, Callable(), {
			"run_id": "floor-one-budget-%d" % map_seed,
			"map_seed": map_seed,
		}),
		"seed %d budget fixture must enter production flow" % map_seed
	)
	if not flow.is_active():
		return
	var renderer := TowerAscentFlowRenderer.new()
	var model := renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var cache := renderer.get_render_cache_debug_state()
	var total_draw_calls := int(cache.get("total_map_draw_call_budget", 0))
	_expect(not model.is_empty(), "seed %d must build the fit-all map model" % map_seed)
	_expect(
		total_draw_calls <= MAP_DRAW_CALL_LIMIT,
		"seed %d fit-all dotted paths plus clouds exceed %d (%d)"
		% [map_seed, MAP_DRAW_CALL_LIMIT, total_draw_calls]
	)
	# registry_only realm nodes are layout-only previews and intentionally hide
	# their routes; every currently rendered edge must nevertheless survive LOD.
	var source_signature := TowerAscentMapPathGeometry.connection_signature(
		flow.get_graph_edges()
	)
	var projected_signature := TowerAscentMapPathGeometry.connection_signature(
		model.get("edges", [])
	)
	source_signature.sort()
	projected_signature.sort()
	_expect(
		source_signature == projected_signature,
		"seed %d budget LOD must preserve every stable edge" % map_seed
	)
	var cloud_calls := int(cache.get("cloud_draw_call_budget", 0))
	_expect(cloud_calls == 120, "seed %d fit-all must reserve all twelve cloud floors" % map_seed)
	if total_draw_calls > _maximum_draw_calls:
		_maximum_draw_calls = total_draw_calls
		_maximum_draw_seed = map_seed
		_maximum_path_draw_calls = int(cache.get("path_draw_call_budget", 0))
		_maximum_cloud_draw_calls = cloud_calls
	_maximum_dot_gap = maxf(_maximum_dot_gap, float(cache.get("path_dot_gap", 0.0)))
	_minimum_fit_all_zoom = minf(
		_minimum_fit_all_zoom,
		float(model.get("minimum_fit_all_zoom", INF))
	)
	var fit_rect: Rect2 = model.get("fit_all_camera_world_rect", Rect2())
	_maximum_world_height = maxf(_maximum_world_height, fit_rect.size.y)


func _verify_audition_route_unchanged() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(true)
	var graph := TowerAscentMapGenerator.new().generate_tower(83521)
	_expect(not graph.is_empty(), "audition route must still generate")
	_expect(
		int(graph.get("floor_one_expansion_row_count", -1)) == 0,
		"audition route must not receive the standard first-floor expansion"
	)
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if node_variant is Dictionary:
				_expect(
					not bool((node_variant as Dictionary).get(
						"floor_one_expansion_row",
						false
					)),
					"audition nodes must remain outside the standard expansion scope"
				)
	TowerAuditionBuildConfig.debug_set_enabled(false)


func _verify_negative_legs() -> void:
	_expect(not _negative_fixture.is_empty(), "negative legs require a positive fixture")
	if _negative_fixture.is_empty():
		return
	var foreign_fixture := _negative_fixture.duplicate(true)
	var foreign_node := _first_floor_choice_node(foreign_fixture)
	_expect(not foreign_node.is_empty(), "foreign-boss leg needs an encounter node")
	if not foreign_node.is_empty():
		foreign_node["boss_slot_id"] = "floor_02_arachne"
		foreign_node["standin"] = TowerAscentBossRegistry.new().get_standin(
			"floor_02_arachne"
		)
		foreign_node["boss_assignment_state"] = "assigned"
		var foreign_report := TowerAscentBossRegistry.new().analyze_visible_boss_contract(
			foreign_fixture
		)
		_expect(not bool(foreign_report.get("valid", true)), "foreign floor-1 boss fixture must be RED")
		_expect(
			_has_issue(foreign_report, "floor_1_forbidden_encounter=")
			and _has_issue(foreign_report, "slot_floor_mismatch="),
			"foreign floor-1 boss fixture must identify pool and band mismatches"
		)
	_negative_leg_count += 1
	var duplicate_fixture := _negative_fixture.duplicate(true)
	var start_node := _first_floor_start_node(duplicate_fixture)
	var duplicate_node := _first_floor_choice_node(duplicate_fixture)
	_expect(
		not start_node.is_empty() and not duplicate_node.is_empty(),
		"duplicate leg needs start and encounter nodes"
	)
	if not start_node.is_empty() and not duplicate_node.is_empty():
		duplicate_node["boss_slot_id"] = str(start_node.get("boss_slot_id", ""))
		duplicate_node["standin"] = (start_node.get("standin", {}) as Dictionary).duplicate(true)
		duplicate_node["boss_assignment_state"] = "assigned"
		var duplicate_report := TowerAscentBossRegistry.new().analyze_visible_boss_contract(
			duplicate_fixture
		)
		_expect(not bool(duplicate_report.get("valid", true)), "duplicate first-floor boss fixture must be RED")
		_expect(
			_has_issue(duplicate_report, "duplicate_encounter_key="),
			"duplicate first-floor boss fixture must identify the reused key"
		)
	_negative_leg_count += 1


func _has_boss_avoidance_path(phase: Dictionary) -> bool:
	var blocked: Dictionary = {}
	var targets: Dictionary = {}
	for node_variant in phase.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var node_id := str(node.get("id", ""))
		if bool(node.get("floor_one_boss_choice", false)):
			blocked[node_id] = true
		if int(node.get("floor", 0)) == 2 and bool(node.get("gatekeeper", false)):
			targets[node_id] = true
	var outgoing: Dictionary = {}
	for edge_variant in phase.get("edges", []):
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		if blocked.has(from_id) or blocked.has(to_id):
			continue
		var values: Array = outgoing.get(from_id, [])
		values.append(to_id)
		outgoing[from_id] = values
	var visited := _walk(str(phase.get("entry_node_id", "")), outgoing)
	for target_id_variant in targets.keys():
		if visited.has(str(target_id_variant)):
			return true
	return false


func _first_floor_start_node(graph: Dictionary) -> Dictionary:
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if (
				int(node.get("segment_floor", 0)) == 1
				and bool(node.get("gatekeeper", false))
				and str(node.get("content_state", "")) == "generated"
			):
				return node
	return {}


func _first_floor_choice_node(graph: Dictionary) -> Dictionary:
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if node_variant is Dictionary and bool(
				(node_variant as Dictionary).get("floor_one_boss_choice", false)
			):
				return node_variant as Dictionary
	return {}


func _ordered_rows(phase: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for floor_variant in phase.get("floors", []):
		if not (floor_variant is Dictionary):
			continue
		for row_variant in (floor_variant as Dictionary).get("rows", []):
			if row_variant is Dictionary:
				result.append(row_variant as Dictionary)
	return result


func _node_index(nodes: Array) -> Dictionary:
	var result: Dictionary = {}
	for node_variant in nodes:
		if node_variant is Dictionary:
			var node := node_variant as Dictionary
			result[str(node.get("id", ""))] = node
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


func _has_issue(report: Dictionary, prefix: String) -> bool:
	for issue_variant in report.get("issues", []):
		if str(issue_variant).begins_with(prefix):
			return true
	return false


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value as Array:
			result.append(str(entry))
	return result


func _safe_ratio(numerator: int, denominator: int) -> float:
	return 0.0 if denominator <= 0 else float(numerator) / float(denominator)


func _expect(condition: bool, message: String) -> void:
	if not condition and _failures.size() < 24 and not _failures.has(message):
		_failures.append(message)
