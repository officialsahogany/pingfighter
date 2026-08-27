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
const TowerAscentMapCloudLayer := preload(
	"res://scripts/tower_ascent/tower_ascent_map_cloud_layer.gd"
)
const TowerAscentMapPathGeometry := preload(
	"res://scripts/tower_ascent/tower_ascent_map_path_geometry.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const SAMPLE_SEED_COUNT := 128
const MAP_DRAW_CALL_LIMIT := 1536
const FINAL_DOT_GAP_UPPER_BOUND := 44.378
const FLOAT_EPSILON := 0.001
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
const EXPECTED_GENERATOR_VERSION := "tower_map_v17_seeded_lane_silhouettes"


class EarlyGuaranteeDisabledGenerator:
	extends "res://scripts/tower_ascent/tower_ascent_map_generator.gd"

	func _apply_early_guardian_spring_guarantee(graph: Dictionary) -> Dictionary:
		return graph

var _failures: Array[String] = []
var _full_choice_row_count := 0
var _invalid_choice_row_count := 0
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
var _maximum_draw_base_dot_gap := 0.0
var _maximum_draw_final_dot_gap := 0.0
var _maximum_final_dot_gap := 0.0
var _minimum_fit_all_zoom := INF
var _maximum_world_height := 0.0
var _fit_all_budget_seed_count := 0
var _final_dot_gap_overflow_count := 0
var _negative_leg_count := 0
var _negative_fixture: Dictionary = {}
var _early_replacement_seed_count := 0
var _early_preexisting_seed_count := 0
var _early_disabled_zero_seed_count := 0
var _early_replaced_from_counts: Dictionary = {}
var _maximum_replacement_draw_calls := 0
var _maximum_replacement_draw_seed := 0
var _maximum_replacement_path_draw_calls := 0
var _maximum_replacement_cloud_draw_calls := 0
var _same_row_duplicate_rejected := false


func _init() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(false)
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_expect(
		MAP_DRAW_CALL_LIMIT == TowerAscentTuning.TEMP_MAP_PATH_DRAW_CALL_BUDGET,
		"GRT-043: the sweep limit must stay in lockstep with production tuning"
	)
	_verify_standard_seeds()
	_verify_audition_route_unchanged()
	_verify_negative_legs()
	TowerAuditionBuildConfig.debug_clear_enabled_override()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print(
			"tower_ascent_floor_one_expansion_contract_smoke: seeds=%d invalid_choice_rows=%d full_choice_rows=%d generated=%d boss=%d npc=%d boss_ratio=%0.4f degree1=%d degree2=%d degree2_ratio=%0.4f services=%s"
			% [
				SAMPLE_SEED_COUNT,
				_invalid_choice_row_count,
				_full_choice_row_count,
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
			"tower_ascent_floor_one_expansion_contract_smoke: fit_all_budget seeds=%d seed=%d path=%d clouds=%d total=%d limit=%d margin=%d base_dot_gap=%0.3f final_dot_gap=%0.3f max_final_dot_gap=%0.3f upper=%0.3f overflow_seeds=%d min_fit_all=%0.4f world_height=%0.1f negative_legs=%d"
			% [
				_fit_all_budget_seed_count,
				_maximum_draw_seed,
				_maximum_path_draw_calls,
				_maximum_cloud_draw_calls,
				_maximum_draw_calls,
				MAP_DRAW_CALL_LIMIT,
				MAP_DRAW_CALL_LIMIT - _maximum_draw_calls,
				_maximum_draw_base_dot_gap,
				_maximum_draw_final_dot_gap,
				_maximum_final_dot_gap,
				FINAL_DOT_GAP_UPPER_BOUND,
				_final_dot_gap_overflow_count,
				_minimum_fit_all_zoom,
				_maximum_world_height,
				_negative_leg_count,
			]
		)
		print(
			"tower_ascent_floor_one_expansion_contract_smoke: early_guardian_spring replacement_seeds=%d preexisting_seeds=%d disabled_zero_seeds=%d replaced_from=%s replacement_budget_seed=%d path=%d clouds=%d total=%d limit=%d"
			% [
				_early_replacement_seed_count,
				_early_preexisting_seed_count,
				_early_disabled_zero_seed_count,
				str(_early_replaced_from_counts),
				_maximum_replacement_draw_seed,
				_maximum_replacement_path_draw_calls,
				_maximum_replacement_cloud_draw_calls,
				_maximum_replacement_draw_calls,
				MAP_DRAW_CALL_LIMIT,
			]
		)
		print(
			"tower_ascent_floor_one_expansion_contract_smoke: same_row_duplicate_fixture=%s"
			% ("RED_REJECTED" if _same_row_duplicate_rejected else "NOT_REJECTED")
		)
		print("tower_ascent_floor_one_expansion_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_standard_seeds() -> void:
	var generator := TowerAscentMapGenerator.new()
	var disabled_generator := EarlyGuaranteeDisabledGenerator.new()
	_expect(
		"|".join(TowerAscentMapGenerator.FLOOR_ONE_EXPANSION_ROW_ROLES)
			== "npc_separator|boss_encounter",
		"floor 1 must use one NPC separator and one combined boss-choice row"
	)
	_expect(
		TowerAscentMapGenerator.GENERATOR_VERSION == EXPECTED_GENERATOR_VERSION,
		"generator version must advance to the compact first-floor contract"
	)
	for seed_offset in range(SAMPLE_SEED_COUNT):
		var map_seed := 7001 + seed_offset * 7919
		var graph := generator.generate_tower(map_seed)
		var repeated := generator.generate_tower(map_seed)
		var disabled_graph := disabled_generator.generate_tower(map_seed)
		_expect(not graph.is_empty(), "seed %d must generate an expanded tower" % map_seed)
		_expect(
			not disabled_graph.is_empty(),
			"seed %d disabled guarantee fixture must generate" % map_seed
		)
		if graph.is_empty() or disabled_graph.is_empty():
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
		var replacement_applied := _verify_early_guardian_spring_guarantee(
			map_seed,
			graph,
			disabled_graph
		)
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
		var gatekeeper_boss_count := 0
		for node_variant in human_phase.get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if bool(node.get("floor_one_expansion_added_node", false)):
				added_node_count += 1
			if bool(node.get("floor_one_boss_choice", false)):
				floor_one_choice_count += 1
			if (
				bool(node.get("gatekeeper", false))
				and str(node.get("content_state", "")) == "generated"
				and str(node.get("kind", ""))
					in TowerAscentMapGenerator.COMBAT_NODE_KINDS
			):
				gatekeeper_boss_count += 1
		_expect(
			added_node_count == 6,
			"seed %d must identify exactly six first-floor-added nodes" % map_seed
		)
		# 피드백2 8항 후속: 기존 구조는 층당 단일 레인 초크포인트 관문과
		# 1층 선택 조우 2를 보존한다. 2층 이상 추가 조우는 기존 NPC 전환이라
		# 이 기준값 위에 별도로 더해진다.
		_expect(
			gatekeeper_boss_count == TowerAuditionBuildConfig.STANDARD_CLEAR_FLOOR,
			"seed %d must keep every human-realm floor gate a chokepoint boss"
			% map_seed
		)
		_expect(
			int(integrity.get("combat_node_count", 0))
				== gatekeeper_boss_count + floor_one_choice_count
					+ _count_optional_extra_bosses(graph),
			"seed %d combat count must be gates, first-floor choices, and optional extras"
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
		_verify_fit_all_budget(map_seed, replacement_applied)
	_expect(
		_fit_all_budget_seed_count == SAMPLE_SEED_COUNT,
		"every standard seed must exercise the production fit-all budget"
	)
	# 피드백2 4항: the merged row permanently exposes both unused stage-1 slots,
	# so every seed must show the start boss plus two selectable bosses.
	_expect(
		_invalid_choice_row_count == 0,
		"full roster: no seed may omit either combined-row boss"
	)
	_expect(
		_full_choice_row_count == SAMPLE_SEED_COUNT,
		"full roster: all 128 seeds must spawn both combined-row bosses"
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
	_expect(
		_early_replacement_seed_count > 0,
		"128-seed fixture must exercise the early guardian spring replacement leg"
	)
	_expect(
		_early_preexisting_seed_count > 0,
		"128-seed fixture must exercise the preexisting no-change leg"
	)
	_expect(
		_early_replacement_seed_count + _early_preexisting_seed_count
			== SAMPLE_SEED_COUNT,
		"every seed must resolve through replacement or preexisting spring"
	)
	_expect(
		_early_disabled_zero_seed_count == _early_replacement_seed_count,
		"disabling the guarantee must expose every replacement seed as RED"
	)
	_negative_leg_count += 1


func _verify_early_guardian_spring_guarantee(
	map_seed: int,
	graph: Dictionary,
	disabled_graph: Dictionary
) -> bool:
	var before_count := _count_early_guardian_springs(disabled_graph)
	var after_count := _count_early_guardian_springs(graph)
	_expect(
		after_count >= TowerAscentMapGenerator.TEMP_EARLY_GUARDIAN_SPRING_GUARANTEE_COUNT,
		"seed %d must guarantee an early guardian spring" % map_seed
	)
	if before_count >= TowerAscentMapGenerator.TEMP_EARLY_GUARDIAN_SPRING_GUARANTEE_COUNT:
		_early_preexisting_seed_count += 1
		_expect(
			TowerAscentMapGenerator.new().encode_graph(graph)
				== TowerAscentMapGenerator.new().encode_graph(disabled_graph),
			"seed %d with an existing spring must remain byte-identical" % map_seed
		)
		return false
	_early_disabled_zero_seed_count += 1
	_early_replacement_seed_count += 1
	_expect(
		after_count == TowerAscentMapGenerator.TEMP_EARLY_GUARDIAN_SPRING_GUARANTEE_COUNT,
		"seed %d replacement must add exactly the guaranteed spring count" % map_seed
	)
	_expect(
		TowerAscentMapGenerator.new().encode_graph(
			_normalize_service_kind_and_label(graph)
		) == TowerAscentMapGenerator.new().encode_graph(
			_normalize_service_kind_and_label(disabled_graph)
		),
		"seed %d guarantee must preserve every field except service kind and label"
		% map_seed
	)
	var before_nodes := _all_node_index(disabled_graph)
	var after_nodes := _all_node_index(graph)
	var changed_node_ids: Array[String] = []
	for node_id_variant in before_nodes.keys():
		var node_id := str(node_id_variant)
		if before_nodes.get(node_id, {}) != after_nodes.get(node_id, {}):
			changed_node_ids.append(node_id)
	_expect(
		changed_node_ids.size() == 1,
		"seed %d guarantee must replace exactly one node" % map_seed
	)
	if changed_node_ids.size() != 1:
		return true
	var changed_node_id := changed_node_ids[0]
	var before_node: Dictionary = before_nodes.get(changed_node_id, {})
	var after_node: Dictionary = after_nodes.get(changed_node_id, {})
	var replaced_kind := str(before_node.get("kind", ""))
	_expect(
		replaced_kind in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS
			and replaced_kind != "guardian_spring",
		"seed %d replacement source must be a non-spring service" % map_seed
	)
	_expect(
		str(after_node.get("kind", "")) == "guardian_spring"
			and str(after_node.get("label", "")) == "샘터",
		"seed %d replacement target must be the guardian spring service" % map_seed
	)
	_expect(
		_not_boss_or_gate(before_node),
		"seed %d replacement must not touch boss or gate semantics" % map_seed
	)
	var duplicate_noncontact_available := _has_early_replacement_candidate(
		disabled_graph,
		true,
		true
	)
	var noncontact_available := _has_early_replacement_candidate(
		disabled_graph,
		false,
		true
	)
	if duplicate_noncontact_available:
		_expect(
			_count_early_kind(disabled_graph, replaced_kind) > 1
				and not _has_boss_or_gate_contact(disabled_graph, changed_node_id),
			"seed %d must prefer a duplicated service away from bosses and gates"
			% map_seed
		)
	elif noncontact_available:
		_expect(
			not _has_boss_or_gate_contact(disabled_graph, changed_node_id),
			"seed %d must prefer a service away from bosses and gates" % map_seed
		)
	_early_replaced_from_counts[replaced_kind] = int(
		_early_replaced_from_counts.get(replaced_kind, 0)
	) + 1
	return true


func _count_early_guardian_springs(graph: Dictionary) -> int:
	return _count_early_kind(graph, "guardian_spring")


func _count_early_kind(graph: Dictionary, expected_kind: String) -> int:
	var result := 0
	for node_variant in _all_node_index(graph).values():
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var segment_floor := int(node.get("segment_floor", 0))
		if (
			segment_floor >= TowerAscentMapGenerator.TEMP_EARLY_GUARDIAN_SPRING_FLOOR_MIN
			and segment_floor <= TowerAscentMapGenerator.TEMP_EARLY_GUARDIAN_SPRING_FLOOR_MAX
			and str(node.get("content_state", "")) == "generated"
			and str(node.get("kind", "")) == expected_kind
		):
			result += 1
	return result


func _not_boss_or_gate(node: Dictionary) -> bool:
	return (
		str(node.get("kind", "")) in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS
		and not bool(node.get("gatekeeper", false))
		and not bool(node.get("floor_one_boss_choice", false))
		and not bool(node.get("standin_duplicate_gate", false))
		and str(node.get("boss_assignment_state", "")) != "assigned"
	)


func _has_early_replacement_candidate(
	graph: Dictionary,
	require_duplicate_kind: bool,
	require_no_boss_or_gate_contact: bool
) -> bool:
	for node_variant in _all_node_index(graph).values():
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var node_kind := str(node.get("kind", ""))
		var segment_floor := int(node.get("segment_floor", 0))
		if (
			segment_floor < TowerAscentMapGenerator.TEMP_EARLY_GUARDIAN_SPRING_FLOOR_MIN
			or segment_floor > TowerAscentMapGenerator.TEMP_EARLY_GUARDIAN_SPRING_FLOOR_MAX
			or str(node.get("content_state", "")) != "generated"
			or node_kind not in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS
			or node_kind == "guardian_spring"
			or not _not_boss_or_gate(node)
		):
			continue
		if require_duplicate_kind and _count_early_kind(graph, node_kind) <= 1:
			continue
		if (
			require_no_boss_or_gate_contact
			and _has_boss_or_gate_contact(graph, str(node.get("id", "")))
		):
			continue
		return true
	return false


func _has_boss_or_gate_contact(graph: Dictionary, candidate_id: String) -> bool:
	var node_by_id := _all_node_index(graph)
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for edge_variant in (phase_variant as Dictionary).get("edges", []):
			if not (edge_variant is Dictionary):
				continue
			var edge := edge_variant as Dictionary
			var other_id := ""
			if str(edge.get("from", "")) == candidate_id:
				other_id = str(edge.get("to", ""))
			elif str(edge.get("to", "")) == candidate_id:
				other_id = str(edge.get("from", ""))
			if other_id.is_empty():
				continue
			var other: Dictionary = node_by_id.get(other_id, {})
			if (
				bool(other.get("gatekeeper", false))
				or str(other.get("kind", "")) in TowerAscentMapGenerator.COMBAT_NODE_KINDS
				or str(other.get("boss_assignment_state", "")) == "assigned"
			):
				return true
	return false


func _normalize_service_kind_and_label(graph: Dictionary) -> Dictionary:
	var normalized := graph.duplicate(true)
	for phase_variant in normalized.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if node_variant is Dictionary:
				(node_variant as Dictionary).erase("kind")
				(node_variant as Dictionary).erase("label")
	return normalized


func _all_node_index(graph: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if node_variant is Dictionary:
				var node := node_variant as Dictionary
				result[str(node.get("id", ""))] = node
	return result


func _count_optional_extra_bosses(graph: Dictionary) -> int:
	var result := 0
	for node_variant in _all_node_index(graph).values():
		if (
			node_variant is Dictionary
			and bool((node_variant as Dictionary).get("optional_extra_boss", false))
		):
			result += 1
	return result


func _verify_floor_one_graph(map_seed: int, phase: Dictionary) -> void:
	var rows := _ordered_rows(phase)
	var node_by_id := _node_index(phase.get("nodes", []))
	var expansion_row_count := 0
	var boss_choice_rows: Array[int] = []
	var floor_one_choice_boss_count := 0
	var floor_one_combat_rows: Array[int] = []
	var floor_one_keys: Dictionary = {}
	var floor_one_lane_signature: Array[int] = []
	var floor_one_node_count := 0
	for row_index in range(rows.size()):
		var row := rows[row_index]
		var row_ids := _string_array(row.get("node_ids", []))
		var row_is_expansion := false
		var row_is_floor_one := false
		var combat_count := 0
		var npc_count := 0
		var row_is_boss_choice := false
		for node_id in row_ids:
			var node: Dictionary = node_by_id.get(node_id, {})
			row_is_floor_one = row_is_floor_one or int(
				node.get("segment_floor", 0)
			) == 1
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
				if bool(node.get("floor_one_boss_choice", false)):
					floor_one_choice_boss_count += 1
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
		if row_is_floor_one:
			floor_one_lane_signature.append(row_ids.size())
			floor_one_node_count += row_ids.size()
		if combat_count > 0:
			floor_one_combat_rows.append(row_index)
		if row_is_boss_choice:
			boss_choice_rows.append(row_index)
			_expect(
				row_ids.size() == 3 and combat_count == 2 and npc_count == 1,
				"seed %d first-floor encounter row must be two bosses plus one NPC"
				% map_seed
			)
	_expect(
		expansion_row_count == TowerAscentMapGenerator.FLOOR_ONE_EXPANSION_ROW_ROLES.size(),
		"seed %d must retain exactly two scoped expansion rows" % map_seed
	)
	_expect(
		floor_one_lane_signature == [1, 2, 3, 3]
		and floor_one_lane_signature.size() == 4
		and floor_one_node_count == 9,
		"seed %d must keep floor 1 at 4 rows, 9 nodes, and the compact lanes"
		% map_seed
	)
	_expect(
		boss_choice_rows.size() == 1 and floor_one_choice_boss_count == 2,
		"seed %d must expose two selectable bosses in one first-floor row" % map_seed
	)
	_expect(
		floor_one_keys.size() == floor_one_choice_boss_count + 1,
		"seed %d first-floor pool consumption must equal start plus choice bosses"
		% map_seed
	)
	if boss_choice_rows.size() == 1 and floor_one_choice_boss_count == 2:
		_full_choice_row_count += 1
	else:
		_invalid_choice_row_count += 1
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


func _verify_fit_all_budget(map_seed: int, replacement_applied: bool) -> void:
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
		total_draw_calls < MAP_DRAW_CALL_LIMIT,
		"seed %d fit-all dotted paths plus clouds must keep positive margin under %d (%d)"
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
	var expected_cloud_calls := TowerAscentMapCloudLayer.estimate_draw_calls(
		model.get("overview_nodes", []),
		float(model.get("art_size", 0.0)),
		float(model.get("map_scale", 1.0))
	)
	_expect(
		cloud_calls == expected_cloud_calls,
		"seed %d merged cloud reserve must match the production estimator (%d != %d)"
		% [map_seed, cloud_calls, expected_cloud_calls]
	)
	_expect(
		cloud_calls < 156,
		"seed %d merged cloud wall must beat the retired 12 floors x 13 calls reserve"
		% map_seed
	)
	var final_dot_gap := float(cache.get("path_dot_gap", 0.0))
	_fit_all_budget_seed_count += 1
	if final_dot_gap > FINAL_DOT_GAP_UPPER_BOUND + FLOAT_EPSILON:
		_final_dot_gap_overflow_count += 1
	var base_dot_gap := (
		float(model.get("art_size", 0.0))
		* TowerAscentTuning.TEMP_MAP_PATH_DOT_GAP_ART_RATIO
	)
	# Measurement only: changing the draw-call budget or the player-visible dotted
	# path density requires a separate product decision. The terminal summary
	# reports both values for the worst draw-call seed without gating their ratio.
	if total_draw_calls > _maximum_draw_calls:
		_maximum_draw_calls = total_draw_calls
		_maximum_draw_seed = map_seed
		_maximum_path_draw_calls = int(cache.get("path_draw_call_budget", 0))
		_maximum_cloud_draw_calls = cloud_calls
		_maximum_draw_base_dot_gap = base_dot_gap
		_maximum_draw_final_dot_gap = final_dot_gap
	if replacement_applied and total_draw_calls > _maximum_replacement_draw_calls:
		_maximum_replacement_draw_calls = total_draw_calls
		_maximum_replacement_draw_seed = map_seed
		_maximum_replacement_path_draw_calls = int(
			cache.get("path_draw_call_budget", 0)
		)
		_maximum_replacement_cloud_draw_calls = cloud_calls
	_maximum_final_dot_gap = maxf(_maximum_final_dot_gap, final_dot_gap)
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
	var same_row_duplicate_fixture := _negative_fixture.duplicate(true)
	var choice_nodes := _first_floor_choice_nodes(same_row_duplicate_fixture)
	_expect(
		choice_nodes.size() == 2,
		"same-row duplicate leg needs both combined-row boss nodes"
	)
	if choice_nodes.size() == 2:
		choice_nodes[1]["boss_slot_id"] = str(choice_nodes[0].get("boss_slot_id", ""))
		choice_nodes[1]["standin"] = (
			choice_nodes[0].get("standin", {}) as Dictionary
		).duplicate(true)
		choice_nodes[1]["boss_assignment_state"] = "assigned"
		var same_row_report := TowerAscentBossRegistry.new().analyze_visible_boss_contract(
			same_row_duplicate_fixture
		)
		_same_row_duplicate_rejected = (
			not bool(same_row_report.get("valid", true))
			and _has_issue(same_row_report, "duplicate_encounter_key=")
		)
		_expect(
			not bool(same_row_report.get("valid", true)),
			"same-row duplicate first-floor bosses must be RED"
		)
		_expect(
			_has_issue(same_row_report, "duplicate_encounter_key="),
			"same-row duplicate fixture must identify the reused encounter key"
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
	var nodes := _first_floor_choice_nodes(graph)
	return nodes[0] if not nodes.is_empty() else {}


func _first_floor_choice_nodes(graph: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if node_variant is Dictionary and bool(
				(node_variant as Dictionary).get("floor_one_boss_choice", false)
			):
				result.append(node_variant as Dictionary)
	return result


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
