extends RefCounted

const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAscentBossRegistry := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd"
)
const TowerAscentRouteCandidatePolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_route_candidate_policy.gd"
)
const TowerAscentEnragedPolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_enraged_policy.gd"
)
const TowerAuditionBuildConfig := preload(
	"res://scripts/tower_ascent/tower_audition_build_config.gd"
)

const GENERATOR_VERSION := "tower_map_v12_gate_chokepoint"
const TOWER_FLOOR_COUNT := 12
const STANDARD_CLEAR_FLOOR := TowerAuditionBuildConfig.STANDARD_CLEAR_FLOOR
const HUMAN_REALM_PHASE_ID := "phase_01_human_realm"
const IMMORTAL_REALM_PHASE_ID := "phase_02_immortal_realm"
const ROUTE_CANDIDATE_COUNT := 2
const MAP_LANE_COUNT_MIN := 3
const MAP_LANE_COUNT_MAX := 4
const GENERATION_MAX_ATTEMPTS := 8
const MAX_NODE_OUTGOING_EDGES := 2
const COMBAT_NODE_KINDS := ["boss", "combat", "enraged"]
const NONCOMBAT_NODE_KINDS := [
	"shop",
	"training",
	"fallen_monk",
	"guardian_spring",
	"rest",
]
const FLOOR_ONE_EXPANSION_ROW_ROLES: Array[String] = [
	"npc_separator",
	"boss_encounter",
	"npc_separator",
	"optional_boss_encounter",
]
const FLOOR_ONE_GUARANTEED_ENCOUNTER_COUNT := 1
const FLOOR_ONE_OPTIONAL_ENCOUNTER_SEED_SALT := 0x31464C52


func generate_tower(map_seed: int, skipped_boss_ids: Array = []) -> Dictionary:
	var active_clear_floor := TowerAuditionBuildConfig.get_clear_floor()
	var audition_enabled := TowerAuditionBuildConfig.is_enabled()
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var total_rows := 1 + (TOWER_FLOOR_COUNT - 1) * (
		TowerAscentTuning.TEMP_OPTIONAL_ROWS_PER_FLOOR + 1
	)
	if audition_enabled:
		total_rows += TowerAscentTuning.TEMP_OPTIONAL_ROWS_PER_FLOOR
	else:
		# The existing floor-2 optional row is already the final full-NPC
		# separator before the 2F gate. These four rows extend segment_floor 1
		# without moving the floor gate out of the final-row boundary slot.
		total_rows += FLOOR_ONE_EXPANSION_ROW_ROLES.size()
	var floor_one_rng := RandomNumberGenerator.new()
	floor_one_rng.seed = int(
		(map_seed ^ FLOOR_ONE_OPTIONAL_ENCOUNTER_SEED_SALT) & 0x7fffffff
	)
	var floor_one_optional_encounter := (
		_floor_one_optional_encounter_enabled(floor_one_rng)
		if not audition_enabled
		else false
	)
	var global_row_index := 0
	var floor_specs: Array[Dictionary] = []
	for floor_number in range(1, TOWER_FLOOR_COUNT + 1):
		var rows: Array[Dictionary] = []
		var floor_one_audition_route := (
			floor_number == 1 and audition_enabled
		)
		if floor_one_audition_route:
			rows.append(_build_gatekeeper_row(
				floor_number,
				global_row_index,
				total_rows,
				active_clear_floor,
				1
			))
			global_row_index += 1
		if floor_number > 1 or floor_one_audition_route:
			if floor_number == 2 and not audition_enabled:
				var floor_one_encounter_index := 0
				for expansion_index in range(FLOOR_ONE_EXPANSION_ROW_ROLES.size()):
					var expansion_role := FLOOR_ONE_EXPANSION_ROW_ROLES[expansion_index]
					var creates_boss_choice := (
						expansion_role == "boss_encounter"
						or (
							expansion_role == "optional_boss_encounter"
							and floor_one_optional_encounter
						)
					)
					var lane_count := ROUTE_CANDIDATE_COUNT
					if expansion_role == "npc_separator" and expansion_index > 0:
						# A 2 -> 3 -> 2 alternation lets both boss-choice
						# lanes branch while keeping every separator a full NPC
						# row. It also avoids introducing two consecutive
						# single-choice transitions into the existing S3 graph.
						lane_count = MAP_LANE_COUNT_MIN
					var node_kinds: Array[String] = []
					var labels: Array[String] = []
					if creates_boss_choice:
						floor_one_encounter_index += 1
						var npc_kind := _draw_unique_noncombat_kinds(
							floor_one_rng,
							1
						)[0]
						node_kinds.assign(["boss", npc_kind])
						labels.assign(["1층 선택 보스", _label_for_kind(npc_kind)])
					else:
						for node_kind in _draw_unique_noncombat_kinds(
							floor_one_rng,
							lane_count
						):
							node_kinds.append(node_kind)
							labels.append(_label_for_kind(node_kind))
					var row_id := "floor_01_expansion_route_%02d" % (
						expansion_index + 1
					)
					rows.append({
						"id": row_id,
						"segment_floor": 1,
						"candidate_count": lane_count,
						"node_ids": _lane_node_ids(row_id, lane_count),
						"kinds": node_kinds,
						"labels": labels,
						"display_y": _map_y(global_row_index, total_rows),
						"route_locked": false,
						"content_state": "generated",
						"floor_one_expansion_row": true,
						"floor_one_boss_choice_row": creates_boss_choice,
						"floor_one_encounter_index": (
							floor_one_encounter_index if creates_boss_choice else 0
						),
					})
					global_row_index += 1
			for optional_index in range(TowerAscentTuning.TEMP_OPTIONAL_ROWS_PER_FLOOR):
				var segment_floor := _segment_floor_for_optional_row(
					floor_number,
					active_clear_floor
				)
				var previous_lane_count := _last_row_lane_count(floor_specs, rows)
				var lane_count := _choose_route_lane_count(
					rng,
					floor_number,
					previous_lane_count,
					active_clear_floor
				)
				if floor_number == 2 and not audition_enabled:
					# This is still segment_floor 1: three NPC lanes receive
					# both lanes of the optional boss choice, then hand off to
					# the unchanged three-lane 2F gate without a single-chain.
					lane_count = MAP_LANE_COUNT_MIN
				var node_kinds: Array[String] = []
				var labels: Array[String] = []
				# A complete NPC row separates every pair of generated boss rows.
				# Boss density is normalized later by the registry after unique
				# encounter allocation, never by retrying a combat-row lottery.
				for node_kind in _draw_unique_noncombat_kinds(rng, lane_count):
					node_kinds.append(node_kind)
					labels.append(_label_for_kind(node_kind))
				var row_id := "floor_%02d_route_%02d" % [floor_number, optional_index + 1]
				rows.append({
					"id": row_id,
					"segment_floor": segment_floor,
					"candidate_count": lane_count,
					"node_ids": _lane_node_ids(row_id, lane_count),
					"kinds": node_kinds,
					"labels": labels,
					"display_y": _map_y(global_row_index, total_rows),
					"route_locked": floor_number > active_clear_floor,
					"content_state": "registry_only" if floor_number > active_clear_floor else "generated",
					"floor_one_expansion_support_row": (
						floor_number == 2 and not audition_enabled
					),
				})
				global_row_index += 1
		if not floor_one_audition_route:
			var previous_lane_count := _last_row_lane_count(floor_specs, rows)
			var gatekeeper_lane_count := _choose_gatekeeper_lane_count(
				rng,
				floor_number,
				previous_lane_count,
				active_clear_floor
			)
			rows.append(_build_gatekeeper_row(
				floor_number,
				global_row_index,
				total_rows,
				active_clear_floor,
				gatekeeper_lane_count
			))
			global_row_index += 1
		floor_specs.append({"floor": floor_number, "rows": rows})
	var generated := generate(map_seed, floor_specs)
	if generated.is_empty():
		return {}
	var phase: Dictionary = generated.phases[0]
	phase["total_floors"] = TOWER_FLOOR_COUNT
	phase["standard_clear_floor"] = active_clear_floor
	var entry_node_id := _derive_entry_node_id(phase)
	var initial_route_candidate_ids := _derive_outgoing_target_ids(
		phase,
		entry_node_id
	)
	if entry_node_id.is_empty() or initial_route_candidate_ids.size() != ROUTE_CANDIDATE_COUNT:
		return {}
	phase["entry_node_id"] = entry_node_id
	phase["initial_route_candidate_ids"] = initial_route_candidate_ids
	generated["phases"] = [phase]
	generated["floor_one_expansion_row_count"] = (
		0 if audition_enabled else FLOOR_ONE_EXPANSION_ROW_ROLES.size()
	)
	generated["floor_one_optional_boss_encounter"] = floor_one_optional_encounter
	var boss_decorated := TowerAscentBossRegistry.new().decorate_graph(generated, map_seed)
	var decorated := TowerAscentEnragedPolicy.new().decorate_graph(
		boss_decorated,
		map_seed,
		TowerAscentTuning.NORMAL_BOSS_ENRAGED_CHANCE
	)
	var marked := TowerAscentRouteCandidatePolicy.new().apply_skipped_markers(
		decorated,
		skipped_boss_ids
	)
	var split := _split_tower_realms(marked)
	var split_integrity := analyze_graph_integrity(split, true, true)
	if not bool(split_integrity.get("valid", false)):
		return {}
	split["integrity"] = split_integrity
	return split


func generate(map_seed: int, floor_specs: Array) -> Dictionary:
	if floor_specs.is_empty():
		return {}
	for generation_attempt in range(GENERATION_MAX_ATTEMPTS):
		var candidate := _generate_candidate(map_seed, floor_specs, generation_attempt)
		if candidate.is_empty():
			continue
		# Boss-slot shortages are content facts, not retryable topology failures.
		# The raw graph receives structural validation only; generate_tower()
		# normalizes boss placeholders to unique bosses or NPCs before applying
		# the S3 distribution contract.
		var integrity := analyze_graph_integrity(candidate, false, false)
		if (
			bool(integrity.get("valid", false))
			and _has_floor_one_boss_avoidance_path(candidate)
		):
			candidate["generation_attempt"] = generation_attempt
			candidate["integrity"] = integrity
			return candidate
	return {}


func _generate_candidate(
	map_seed: int,
	floor_specs: Array,
	generation_attempt: int
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _generation_attempt_seed(map_seed, generation_attempt)
	var nodes: Array[Dictionary] = []
	var edges: Array[Dictionary] = []
	var floors: Array[Dictionary] = []
	var previous_row_ids: Array[String] = []
	var global_row_index := 0
	for floor_variant in floor_specs:
		if not (floor_variant is Dictionary):
			return {}
		var floor_spec := floor_variant as Dictionary
		var floor_number := maxi(1, int(floor_spec.get("floor", floors.size() + 1)))
		var row_specs_variant: Variant = floor_spec.get("rows", [])
		if not (row_specs_variant is Array) or (row_specs_variant as Array).is_empty():
			return {}
		var floor_rows: Array[Dictionary] = []
		var floor_row_index := 0
		for row_variant in row_specs_variant as Array:
			if not (row_variant is Dictionary):
				return {}
			var row_spec := row_variant as Dictionary
			var row_nodes := _build_row_nodes(
				rng,
				floor_number,
				floor_row_index,
				global_row_index,
				row_spec
			)
			if row_nodes.is_empty():
				return {}
			var current_row_ids: Array[String] = []
			for node in row_nodes:
				current_row_ids.append(str(node.get("id", "")))
				nodes.append(node)
			if not previous_row_ids.is_empty():
				var row_edges := _build_partial_row_edges(
					rng,
					previous_row_ids,
					current_row_ids
				)
				if row_edges.is_empty():
					return {}
				edges.append_array(row_edges)
			floor_rows.append({
				"id": str(row_spec.get("id", "floor_%02d_row_%02d" % [floor_number, floor_row_index + 1])),
				"node_ids": current_row_ids.duplicate(),
				"gatekeeper": bool(row_spec.get("gatekeeper", false)),
				"segment_floor": int(row_spec.get("segment_floor", floor_number)),
			})
			previous_row_ids = current_row_ids
			floor_row_index += 1
			global_row_index += 1
		floors.append({"floor": floor_number, "rows": floor_rows})
	return {
		"generator_version": GENERATOR_VERSION,
		"map_seed": map_seed,
		"generation_nonce": rng.randi(),
		"phases": [{
			"id": "phase_01",
			"floors": floors,
			"nodes": nodes,
			"edges": edges,
		}],
	}


func _build_gatekeeper_row(
	floor_number: int,
	global_row_index: int,
	total_rows: int,
	active_clear_floor: int,
	candidate_count: int
) -> Dictionary:
	var row_id := "floor_%02d_gatekeeper_row" % floor_number
	var kinds: Array[String] = []
	var labels: Array[String] = []
	for _lane in range(candidate_count):
		kinds.append("boss")
		labels.append("%d층 수문장" % floor_number)
	return {
		"id": row_id,
		"segment_floor": floor_number,
		"candidate_count": candidate_count,
		"node_ids": _gatekeeper_node_ids(floor_number, candidate_count),
		"kinds": kinds,
		"labels": labels,
		"display_y": _map_y(global_row_index, total_rows),
		"gatekeeper": true,
		"floor_boundary": true,
		"route_locked": floor_number > active_clear_floor,
		"content_state": "registry_only" if floor_number > active_clear_floor else "generated",
	}


func _derive_entry_node_id(phase: Dictionary) -> String:
	var floors_variant: Variant = phase.get("floors", [])
	if not (floors_variant is Array) or (floors_variant as Array).is_empty():
		return ""
	var first_floor_variant: Variant = (floors_variant as Array)[0]
	if not (first_floor_variant is Dictionary):
		return ""
	var rows_variant: Variant = (first_floor_variant as Dictionary).get("rows", [])
	if not (rows_variant is Array) or (rows_variant as Array).is_empty():
		return ""
	var first_row_variant: Variant = (rows_variant as Array)[0]
	if not (first_row_variant is Dictionary):
		return ""
	var node_ids_variant: Variant = (first_row_variant as Dictionary).get("node_ids", [])
	if not (node_ids_variant is Array) or (node_ids_variant as Array).is_empty():
		return ""
	return str((node_ids_variant as Array)[0])


func _derive_outgoing_target_ids(phase: Dictionary, source_node_id: String) -> Array[String]:
	var targets: Array[String] = []
	for edge_variant in phase.get("edges", []):
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		if str(edge.get("from", "")) != source_node_id:
			continue
		var target_id := str(edge.get("to", ""))
		if not target_id.is_empty() and not targets.has(target_id):
			targets.append(target_id)
	return targets


func analyze_graph_integrity(
	graph: Dictionary,
	require_boss_terminal: bool = false,
	require_distribution_contract: bool = true
) -> Dictionary:
	var issues: Array[String] = []
	var total_nodes := 0
	var total_edges := 0
	var total_isolated := 0
	var total_entry_unreachable := 0
	var total_boss_unreachable := 0
	var total_dead_ends := 0
	var total_crossings := 0
	var maximum_out_degree := 0
	var total_generated_nodes := 0
	var total_combat_nodes := 0
	var total_npc_nodes := 0
	var total_boss_adjacencies := 0
	var total_boss_spacing_violations := 0
	var total_branch_eligible_nodes := 0
	var total_degree_one_nodes := 0
	var total_degree_two_nodes := 0
	var total_raw_outgoing_nodes := 0
	var total_consecutive_single_transitions := 0
	var total_singleton_rows := 0
	var phases_variant: Variant = graph.get("phases", [])
	if not (phases_variant is Array) or (phases_variant as Array).is_empty():
		return {"valid": false, "issues": ["missing_phases"]}
	for phase_index in range((phases_variant as Array).size()):
		var phase_variant: Variant = (phases_variant as Array)[phase_index]
		if not (phase_variant is Dictionary):
			issues.append("phase_%d_not_dictionary" % phase_index)
			continue
		var phase_report := _analyze_phase_integrity(
			phase_variant as Dictionary,
			require_boss_terminal,
			require_distribution_contract
		)
		for issue_variant in phase_report.get("issues", []):
			issues.append("phase_%d:%s" % [phase_index, str(issue_variant)])
		total_nodes += int(phase_report.get("node_count", 0))
		total_edges += int(phase_report.get("edge_count", 0))
		total_isolated += int(phase_report.get("isolated_count", 0))
		total_entry_unreachable += int(phase_report.get("entry_unreachable_count", 0))
		total_boss_unreachable += int(phase_report.get("boss_unreachable_count", 0))
		total_dead_ends += int(phase_report.get("dead_end_count", 0))
		total_crossings += int(phase_report.get("crossing_count", 0))
		maximum_out_degree = maxi(
			maximum_out_degree,
			int(phase_report.get("maximum_out_degree", 0))
		)
		total_generated_nodes += int(phase_report.get("generated_node_count", 0))
		total_combat_nodes += int(phase_report.get("combat_node_count", 0))
		total_npc_nodes += int(phase_report.get("npc_node_count", 0))
		total_boss_adjacencies += int(phase_report.get("boss_adjacency_count", 0))
		total_boss_spacing_violations += int(
			phase_report.get("boss_spacing_violation_count", 0)
		)
		total_branch_eligible_nodes += int(
			phase_report.get("branch_eligible_node_count", 0)
		)
		total_degree_one_nodes += int(phase_report.get("degree_one_node_count", 0))
		total_degree_two_nodes += int(phase_report.get("degree_two_node_count", 0))
		total_raw_outgoing_nodes += int(phase_report.get("raw_outgoing_node_count", 0))
		total_consecutive_single_transitions += int(
			phase_report.get("consecutive_single_transition_count", 0)
		)
		total_singleton_rows += int(phase_report.get("singleton_row_count", 0))
	var boss_ratio := _safe_ratio(total_combat_nodes, total_generated_nodes)
	var degree_two_ratio := _safe_ratio(
		total_degree_two_nodes,
		total_branch_eligible_nodes
	)
	var raw_degree_two_ratio := _safe_ratio(
		total_degree_two_nodes,
		total_raw_outgoing_nodes
	)
	var floor_one_boss_avoidance_path := _has_floor_one_boss_avoidance_path(graph)
	if not floor_one_boss_avoidance_path:
		issues.append("floor_one_boss_avoidance_path_missing")
	return {
		"valid": issues.is_empty(),
		"issues": issues,
		"node_count": total_nodes,
		"edge_count": total_edges,
		"isolated_count": total_isolated,
		"entry_unreachable_count": total_entry_unreachable,
		"boss_unreachable_count": total_boss_unreachable,
		"dead_end_count": total_dead_ends,
		"crossing_count": total_crossings,
		"maximum_out_degree": maximum_out_degree,
		"generated_node_count": total_generated_nodes,
		"combat_node_count": total_combat_nodes,
		"npc_node_count": total_npc_nodes,
		"boss_ratio": boss_ratio,
		"boss_adjacency_count": total_boss_adjacencies,
		"boss_spacing_violation_count": total_boss_spacing_violations,
		"branch_eligible_node_count": total_branch_eligible_nodes,
		"degree_one_node_count": total_degree_one_nodes,
		"degree_two_node_count": total_degree_two_nodes,
		"degree_two_ratio": degree_two_ratio,
		"eligible_degree_two_ratio": degree_two_ratio,
		"raw_outgoing_node_count": total_raw_outgoing_nodes,
		"raw_degree_two_ratio": raw_degree_two_ratio,
		"consecutive_single_transition_count": total_consecutive_single_transitions,
		"singleton_row_count": total_singleton_rows,
		"floor_one_boss_avoidance_path": floor_one_boss_avoidance_path,
	}


func _analyze_phase_integrity(
	phase: Dictionary,
	require_boss_terminal: bool,
	require_distribution_contract: bool
) -> Dictionary:
	var issues: Array[String] = []
	var nodes_variant: Variant = phase.get("nodes", [])
	var edges_variant: Variant = phase.get("edges", [])
	if not (nodes_variant is Array) or (nodes_variant as Array).is_empty():
		return {"issues": ["missing_nodes"]}
	if not (edges_variant is Array):
		return {"issues": ["missing_edges"]}
	var nodes := nodes_variant as Array
	var edges := edges_variant as Array
	var ordered_rows := _ordered_phase_row_ids(phase)
	if ordered_rows.is_empty():
		return {"issues": ["missing_rows"]}
	var node_by_id: Dictionary = {}
	var duplicate_node_count := 0
	for node_variant in nodes:
		if not (node_variant is Dictionary):
			issues.append("node_not_dictionary")
			continue
		var node := node_variant as Dictionary
		var node_id := str(node.get("id", ""))
		if node_id.is_empty() or node_by_id.has(node_id):
			duplicate_node_count += 1
			continue
		node_by_id[node_id] = node
	if duplicate_node_count > 0:
		issues.append("duplicate_or_empty_node_ids=%d" % duplicate_node_count)
	var row_index_by_node_id: Dictionary = {}
	for row_index in range(ordered_rows.size()):
		for node_id_variant in ordered_rows[row_index]:
			row_index_by_node_id[str(node_id_variant)] = row_index
	var outgoing: Dictionary = {}
	var incoming: Dictionary = {}
	for node_id_variant in node_by_id.keys():
		var node_id := str(node_id_variant)
		outgoing[node_id] = []
		incoming[node_id] = []
	var invalid_edge_count := 0
	var duplicate_edges: Dictionary = {}
	var boss_adjacency_count := 0
	for edge_variant in edges:
		if not (edge_variant is Dictionary):
			invalid_edge_count += 1
			continue
		var edge := edge_variant as Dictionary
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		var edge_key := "%s>%s" % [from_id, to_id]
		if (
			from_id.is_empty()
			or to_id.is_empty()
			or not node_by_id.has(from_id)
			or not node_by_id.has(to_id)
			or duplicate_edges.has(edge_key)
		):
			invalid_edge_count += 1
			continue
		duplicate_edges[edge_key] = true
		var from_node: Dictionary = node_by_id[from_id]
		var to_node: Dictionary = node_by_id[to_id]
		if int(to_node.get("global_row", -1)) != int(from_node.get("global_row", -2)) + 1:
			invalid_edge_count += 1
			continue
		var targets: Array = outgoing[from_id]
		targets.append(to_id)
		outgoing[from_id] = targets
		var sources: Array = incoming[to_id]
		sources.append(from_id)
		incoming[to_id] = sources
		if (
			require_distribution_contract
			and _is_generated_combat_node(from_node)
			and _is_generated_combat_node(to_node)
		):
			boss_adjacency_count += 1
	if invalid_edge_count > 0:
		issues.append("invalid_edges=%d" % invalid_edge_count)
	if boss_adjacency_count > 0:
		issues.append("boss_adjacencies=%d" % boss_adjacency_count)
	var first_row: Array = ordered_rows[0]
	var last_row: Array = ordered_rows[ordered_rows.size() - 1]
	var entry_id := str(phase.get("entry_node_id", ""))
	if entry_id.is_empty() and not first_row.is_empty():
		entry_id = str(first_row[0])
	if first_row.size() != 1 or not first_row.has(entry_id):
		issues.append("entry_row_must_be_singleton")
	if require_boss_terminal and last_row.size() != 1:
		issues.append("terminal_row_must_be_singleton")
	if require_boss_terminal:
		for terminal_id_variant in last_row:
			var terminal_node: Dictionary = node_by_id.get(str(terminal_id_variant), {})
			if str(terminal_node.get("kind", "")) != "boss":
				issues.append("terminal_not_boss=%s" % str(terminal_id_variant))
	var singleton_row_count := 0
	for row_index in range(ordered_rows.size()):
		var row_ids: Array = ordered_rows[row_index]
		if row_ids.size() != 1:
			continue
		singleton_row_count += 1
		if not require_distribution_contract:
			continue
		if not _is_allowed_singleton_row(
			phase,
			row_index,
			ordered_rows,
			node_by_id
		):
			issues.append("forbidden_singleton_row=%d" % row_index)
		# 피드백2 8항: 허용 싱글턴끼리의 인접(신선계 진입 단일로 -> 단일
		# 관문)은 의도된 회랑이다. 비허용 싱글턴이 낀 협로만 계약 위반.
		if (
			row_index > 0
			and (ordered_rows[row_index - 1] as Array).size() < 2
			and not _is_allowed_singleton_row(
				phase,
				row_index - 1,
				ordered_rows,
				node_by_id
			)
		):
			issues.append("singleton_previous_row_too_narrow=%d" % row_index)
		if (
			row_index + 1 < ordered_rows.size()
			and (ordered_rows[row_index + 1] as Array).size() < 2
			and not _is_allowed_singleton_row(
				phase,
				row_index + 1,
				ordered_rows,
				node_by_id
			)
		):
			issues.append("singleton_next_row_too_narrow=%d" % row_index)
	var reachable_from_entry := _walk_adjacency([entry_id], outgoing)
	var reaches_terminal := _walk_adjacency(last_row, incoming)
	var entry_unreachable_count := maxi(0, node_by_id.size() - reachable_from_entry.size())
	var boss_unreachable_count := maxi(0, node_by_id.size() - reaches_terminal.size())
	if entry_unreachable_count > 0:
		issues.append("entry_unreachable=%d" % entry_unreachable_count)
	if boss_unreachable_count > 0:
		issues.append("boss_unreachable=%d" % boss_unreachable_count)
	var isolated_count := 0
	var dead_end_count := 0
	var maximum_out_degree := 0
	var degree_one_node_count := 0
	var degree_two_node_count := 0
	var raw_outgoing_node_count := 0
	var branch_eligible_node_count := 0
	var consecutive_single_transition_count := 0
	for node_id_variant in node_by_id.keys():
		var node_id := str(node_id_variant)
		var out_degree: int = (outgoing.get(node_id, []) as Array).size()
		var in_degree: int = (incoming.get(node_id, []) as Array).size()
		maximum_out_degree = maxi(maximum_out_degree, out_degree)
		if out_degree > 0:
			raw_outgoing_node_count += 1
		if out_degree == 1:
			degree_one_node_count += 1
		elif out_degree == 2:
			degree_two_node_count += 1
		var row_index := int(row_index_by_node_id.get(node_id, -1))
		if (
			row_index >= 0
			and row_index + 1 < ordered_rows.size()
			and (ordered_rows[row_index + 1] as Array).size() >= 2
		):
			branch_eligible_node_count += 1
		if require_distribution_contract and out_degree == 1:
			var target_id := str((outgoing.get(node_id, []) as Array)[0])
			var target_outgoing: Array = outgoing.get(target_id, [])
			if target_outgoing.size() == 1:
				var final_target_id := str(target_outgoing[0])
				var final_target: Dictionary = node_by_id.get(final_target_id, {})
				# 피드백2 8항: 단일 선택 체인은 보스 관문으로 수렴할 때만
				# 허용된다(초크포인트 의도). 기존 최종보스 체인 면제의 일반화.
				var allowed_final_boss_chain := (
					(
						last_row.has(final_target_id)
						or bool(final_target.get("gatekeeper", false))
					)
					and str(final_target.get("kind", "")) in COMBAT_NODE_KINDS
				)
				if not allowed_final_boss_chain:
					consecutive_single_transition_count += 1
					issues.append(
						"consecutive_single_transition=%s>%s"
						% [node_id, target_id]
					)
		if in_degree == 0 and out_degree == 0:
			isolated_count += 1
		if not last_row.has(node_id) and out_degree == 0:
			dead_end_count += 1
		if not last_row.has(node_id) and out_degree not in [1, 2]:
			issues.append("out_degree_%d=%s" % [out_degree, node_id])
		if not first_row.has(node_id) and in_degree == 0:
			issues.append("missing_incoming=%s" % node_id)
	if isolated_count > 0:
		issues.append("isolated=%d" % isolated_count)
	if dead_end_count > 0:
		issues.append("dead_ends=%d" % dead_end_count)
	if maximum_out_degree > MAX_NODE_OUTGOING_EDGES:
		issues.append("maximum_out_degree=%d" % maximum_out_degree)
	var degree_two_ratio := _safe_ratio(
		degree_two_node_count,
		branch_eligible_node_count
	)
	var raw_degree_two_ratio := _safe_ratio(
		degree_two_node_count,
		raw_outgoing_node_count
	)
	if (
		require_distribution_contract
		and branch_eligible_node_count > 0
		and degree_two_ratio + 0.000001 < TowerAscentTuning.TEMP_MAP_DEGREE_TWO_MIN_RATIO
	):
		issues.append("degree_two_ratio=%0.6f" % degree_two_ratio)
	var generated_node_count := 0
	var combat_node_count := 0
	var npc_node_count := 0
	for node_variant in nodes:
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		if str(node.get("content_state", "")) != "generated":
			continue
		generated_node_count += 1
		var node_kind := str(node.get("kind", ""))
		if node_kind in COMBAT_NODE_KINDS:
			combat_node_count += 1
		elif node_kind in NONCOMBAT_NODE_KINDS:
			npc_node_count += 1
	var boss_spacing_violation_count := 0
	if require_distribution_contract:
		var boss_ratio := _safe_ratio(combat_node_count, generated_node_count)
		if (
			boss_ratio > TowerAscentTuning.TEMP_GENERATED_BOSS_NODE_MAX_RATIO + 0.000001
		):
			issues.append("boss_ratio=%0.6f" % boss_ratio)
		if npc_node_count < combat_node_count * TowerAscentTuning.TEMP_GENERATED_NPC_PER_BOSS_MIN:
			issues.append("boss_npc_ratio=%d:%d" % [combat_node_count, npc_node_count])
		boss_spacing_violation_count = _count_boss_spacing_violations(
			ordered_rows,
			node_by_id
		)
		if boss_spacing_violation_count > 0:
			issues.append("boss_spacing_violations=%d" % boss_spacing_violation_count)
	var crossing_count := _count_crossing_edges(edges, node_by_id)
	if crossing_count > 0:
		issues.append("crossings=%d" % crossing_count)
	return {
		"issues": issues,
		"node_count": node_by_id.size(),
		"edge_count": edges.size(),
		"isolated_count": isolated_count,
		"entry_unreachable_count": entry_unreachable_count,
		"boss_unreachable_count": boss_unreachable_count,
		"dead_end_count": dead_end_count,
		"crossing_count": crossing_count,
		"maximum_out_degree": maximum_out_degree,
		"generated_node_count": generated_node_count,
		"combat_node_count": combat_node_count,
		"npc_node_count": npc_node_count,
		"boss_ratio": _safe_ratio(combat_node_count, generated_node_count),
		"boss_adjacency_count": boss_adjacency_count,
		"boss_spacing_violation_count": boss_spacing_violation_count,
		"branch_eligible_node_count": branch_eligible_node_count,
		"degree_one_node_count": degree_one_node_count,
		"degree_two_node_count": degree_two_node_count,
		"degree_two_ratio": degree_two_ratio,
		"eligible_degree_two_ratio": degree_two_ratio,
		"raw_outgoing_node_count": raw_outgoing_node_count,
		"raw_degree_two_ratio": raw_degree_two_ratio,
		"consecutive_single_transition_count": consecutive_single_transition_count,
		"singleton_row_count": singleton_row_count,
	}


func _is_generated_combat_node(node: Dictionary) -> bool:
	return (
		str(node.get("content_state", "")) == "generated"
		and str(node.get("kind", "")) in COMBAT_NODE_KINDS
	)


func _is_allowed_singleton_row(
	_phase: Dictionary,
	row_index: int,
	ordered_rows: Array,
	node_by_id: Dictionary
) -> bool:
	if row_index == 0:
		return true
	var row_ids: Array = ordered_rows[row_index]
	if row_ids.size() != 1:
		return false
	var node: Dictionary = node_by_id.get(str(row_ids[0]), {})
	# 피드백2 8항: 모든 관문 행은 단일 레인 초크포인트로 허용된다. 비관문
	# 싱글턴은 여전히 금지(첫 행 제외).
	return bool(node.get("gatekeeper", false))


func _count_boss_spacing_violations(
	ordered_rows: Array,
	node_by_id: Dictionary
) -> int:
	var result := 0
	var previous_boss_row := -1
	for row_index in range(ordered_rows.size()):
		var row_ids: Array = ordered_rows[row_index]
		var has_generated_boss := false
		for node_id_variant in row_ids:
			var node: Dictionary = node_by_id.get(str(node_id_variant), {})
			if _is_generated_combat_node(node):
				has_generated_boss = true
				break
		if not has_generated_boss:
			continue
		if previous_boss_row >= 0:
			var has_full_npc_row := false
			for gap_row_index in range(previous_boss_row + 1, row_index):
				if _is_full_generated_npc_row(
					ordered_rows[gap_row_index],
					node_by_id
				):
					has_full_npc_row = true
					break
			if not has_full_npc_row:
				result += 1
		previous_boss_row = row_index
	return result


func _is_full_generated_npc_row(row_ids: Array, node_by_id: Dictionary) -> bool:
	if row_ids.is_empty():
		return false
	for node_id_variant in row_ids:
		var node: Dictionary = node_by_id.get(str(node_id_variant), {})
		if (
			str(node.get("content_state", "")) != "generated"
			or str(node.get("kind", "")) not in NONCOMBAT_NODE_KINDS
		):
			return false
	return true


func _safe_ratio(numerator: int, denominator: int) -> float:
	return 0.0 if denominator <= 0 else float(numerator) / float(denominator)


func _ordered_phase_row_ids(phase: Dictionary) -> Array:
	var result: Array = []
	for floor_variant in phase.get("floors", []):
		if not (floor_variant is Dictionary):
			continue
		for row_variant in (floor_variant as Dictionary).get("rows", []):
			if row_variant is Dictionary:
				result.append(_string_array((row_variant as Dictionary).get("node_ids", [])))
	return result


func _walk_adjacency(start_ids: Array, adjacency: Dictionary) -> Dictionary:
	var visited: Dictionary = {}
	var pending: Array[String] = []
	for start_id_variant in start_ids:
		var start_id := str(start_id_variant)
		if start_id.is_empty() or visited.has(start_id):
			continue
		visited[start_id] = true
		pending.append(start_id)
	while not pending.is_empty():
		var current_id: String = pending.pop_back()
		for target_id_variant in adjacency.get(current_id, []):
			var target_id := str(target_id_variant)
			if visited.has(target_id):
				continue
			visited[target_id] = true
			pending.append(target_id)
	return visited


func _has_floor_one_boss_avoidance_path(graph: Dictionary) -> bool:
	var phases: Array = graph.get("phases", [])
	if phases.is_empty() or not (phases[0] is Dictionary):
		return false
	var phase := phases[0] as Dictionary
	var entry_id := str(phase.get("entry_node_id", ""))
	var blocked_ids: Dictionary = {}
	var target_ids: Dictionary = {}
	var has_floor_one_choice := false
	for node_variant in phase.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var node_id := str(node.get("id", ""))
		if entry_id.is_empty() and int(node.get("global_row", -1)) == 0:
			entry_id = node_id
		if bool(node.get("floor_one_boss_choice", false)):
			has_floor_one_choice = true
			blocked_ids[node_id] = true
		if int(node.get("floor", 0)) == 2 and bool(node.get("gatekeeper", false)):
			target_ids[node_id] = true
	if not has_floor_one_choice:
		return true
	if entry_id.is_empty() or target_ids.is_empty():
		return false
	var adjacency: Dictionary = {}
	for edge_variant in phase.get("edges", []):
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		if blocked_ids.has(from_id) or blocked_ids.has(to_id):
			continue
		var targets: Array = adjacency.get(from_id, [])
		targets.append(to_id)
		adjacency[from_id] = targets
	var visited := _walk_adjacency([entry_id], adjacency)
	for target_id_variant in target_ids.keys():
		if visited.has(str(target_id_variant)):
			return true
	return false


func _count_crossing_edges(edges: Array, node_by_id: Dictionary) -> int:
	var result := 0
	for first_index in range(edges.size()):
		if not (edges[first_index] is Dictionary):
			continue
		var first := edges[first_index] as Dictionary
		var first_from: Dictionary = node_by_id.get(str(first.get("from", "")), {})
		var first_to: Dictionary = node_by_id.get(str(first.get("to", "")), {})
		for second_index in range(first_index + 1, edges.size()):
			if not (edges[second_index] is Dictionary):
				continue
			var second := edges[second_index] as Dictionary
			var second_from: Dictionary = node_by_id.get(str(second.get("from", "")), {})
			if int(first_from.get("global_row", -1)) != int(second_from.get("global_row", -2)):
				continue
			var second_to: Dictionary = node_by_id.get(str(second.get("to", "")), {})
			var from_delta := int(first_from.get("lane", 0)) - int(second_from.get("lane", 0))
			var to_delta := int(first_to.get("lane", 0)) - int(second_to.get("lane", 0))
			if from_delta * to_delta < 0:
				result += 1
	return result


func _build_partial_row_edges(
	rng: RandomNumberGenerator,
	previous_row_ids: Array[String],
	current_row_ids: Array[String]
) -> Array[Dictionary]:
	var previous_count := previous_row_ids.size()
	var current_count := current_row_ids.size()
	if previous_count <= 0 or current_count <= 0 or current_count > previous_count * 2:
		return []
	var state := {
		"best_degree_two_count": -1,
		"layouts": [],
	}
	var target_coverage: Array[int] = []
	target_coverage.resize(current_count)
	target_coverage.fill(0)
	_collect_best_non_crossing_layouts(
		0,
		0,
		previous_row_ids,
		current_row_ids,
		[],
		target_coverage,
		state
	)
	var layouts: Array = state.get("layouts", [])
	if layouts.is_empty():
		return []
	var selected_variant: Variant = layouts[rng.randi_range(0, layouts.size() - 1)]
	var result: Array[Dictionary] = []
	if selected_variant is Array:
		for edge_variant in selected_variant as Array:
			if edge_variant is Dictionary:
				result.append((edge_variant as Dictionary).duplicate(true))
	return result


func _collect_best_non_crossing_layouts(
	source_index: int,
	minimum_target_index: int,
	previous_row_ids: Array[String],
	current_row_ids: Array[String],
	edges: Array,
	target_coverage: Array[int],
	state: Dictionary
) -> void:
	if source_index >= previous_row_ids.size():
		if target_coverage.min() <= 0:
			return
		var out_degree_by_id: Dictionary = {}
		for edge_variant in edges:
			var from_id := str((edge_variant as Dictionary).get("from", ""))
			out_degree_by_id[from_id] = int(out_degree_by_id.get(from_id, 0)) + 1
		var degree_two_count := 0
		for degree_variant in out_degree_by_id.values():
			if int(degree_variant) == MAX_NODE_OUTGOING_EDGES:
				degree_two_count += 1
		var best_count := int(state.get("best_degree_two_count", -1))
		if degree_two_count < best_count:
			return
		if degree_two_count > best_count:
			state["best_degree_two_count"] = degree_two_count
			state["layouts"] = []
		var layouts: Array = state.get("layouts", [])
		layouts.append(edges.duplicate(true))
		state["layouts"] = layouts
		return
	for target_index in range(minimum_target_index, current_row_ids.size()):
		_append_layout_option(
			source_index,
			[target_index],
			previous_row_ids,
			current_row_ids,
			edges,
			target_coverage,
			state
		)
		if target_index + 1 < current_row_ids.size():
			_append_layout_option(
				source_index,
				[target_index, target_index + 1],
				previous_row_ids,
				current_row_ids,
				edges,
				target_coverage,
				state
			)


func _append_layout_option(
	source_index: int,
	target_indexes: Array,
	previous_row_ids: Array[String],
	current_row_ids: Array[String],
	edges: Array,
	target_coverage: Array[int],
	state: Dictionary
) -> void:
	var edge_count_before := edges.size()
	for target_index_variant in target_indexes:
		var target_index := int(target_index_variant)
		edges.append({
			"from": previous_row_ids[source_index],
			"to": current_row_ids[target_index],
		})
		target_coverage[target_index] += 1
	_collect_best_non_crossing_layouts(
		source_index + 1,
		int(target_indexes[-1]),
		previous_row_ids,
		current_row_ids,
		edges,
		target_coverage,
		state
	)
	for target_index_variant in target_indexes:
		target_coverage[int(target_index_variant)] -= 1
	edges.resize(edge_count_before)


func _generation_attempt_seed(map_seed: int, generation_attempt: int) -> int:
	if generation_attempt <= 0:
		return map_seed
	return map_seed ^ (0x45D9F3B * generation_attempt)


func encode_graph(graph: Dictionary) -> PackedByteArray:
	return var_to_bytes(graph)


func _split_tower_realms(graph: Dictionary) -> Dictionary:
	var active_clear_floor := TowerAuditionBuildConfig.get_clear_floor()
	var result := graph.duplicate(true)
	var phases_variant: Variant = result.get("phases", [])
	if not (phases_variant is Array) or (phases_variant as Array).size() != 1:
		return {}
	var source_variant: Variant = (phases_variant as Array)[0]
	if not (source_variant is Dictionary):
		return {}
	var source := source_variant as Dictionary
	var human_nodes: Array[Dictionary] = []
	var immortal_nodes: Array[Dictionary] = []
	var human_node_ids: Dictionary = {}
	var immortal_node_ids: Dictionary = {}
	for node_variant in source.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var node := (node_variant as Dictionary).duplicate(true)
		var floor_number := int(node.get("floor", 0))
		if floor_number <= active_clear_floor:
			human_nodes.append(node)
			human_node_ids[str(node.get("id", ""))] = true
		else:
			immortal_nodes.append(node)
			immortal_node_ids[str(node.get("id", ""))] = true
	var human_floors: Array[Dictionary] = []
	var immortal_floors: Array[Dictionary] = []
	for floor_variant in source.get("floors", []):
		if not (floor_variant is Dictionary):
			continue
		var floor_data := (floor_variant as Dictionary).duplicate(true)
		if int(floor_data.get("floor", 0)) <= active_clear_floor:
			human_floors.append(floor_data)
		else:
			immortal_floors.append(floor_data)
	var human_edges: Array[Dictionary] = []
	var immortal_edges: Array[Dictionary] = []
	for edge_variant in source.get("edges", []):
		if not (edge_variant is Dictionary):
			continue
		var edge := (edge_variant as Dictionary).duplicate(true)
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		if human_node_ids.has(from_id) and human_node_ids.has(to_id):
			human_edges.append(edge)
		elif immortal_node_ids.has(from_id) and immortal_node_ids.has(to_id):
			immortal_edges.append(edge)
	if (
		human_floors.size() != active_clear_floor
		or immortal_floors.size() != TOWER_FLOOR_COUNT - active_clear_floor
	):
		return {}
	var human_phase := {
		"id": HUMAN_REALM_PHASE_ID,
		"display_name": "인간계",
		"realm_kind": "human_realm",
		"floor_start": 1,
		"floor_end": active_clear_floor,
		"total_floors": active_clear_floor,
		"tower_total_floors": TOWER_FLOOR_COUNT,
		"standard_clear_floor": active_clear_floor,
		"entry_node_id": str(source.get("entry_node_id", "")),
		"initial_route_candidate_ids": (
			source.get("initial_route_candidate_ids", []) as Array
		).duplicate(),
		"locked_phase_hints": [] if TowerAuditionBuildConfig.is_enabled() else [{
			"phase_id": IMMORTAL_REALM_PHASE_ID,
			"display_name": "신선계",
			"floor_start": 10,
			"floor_end": 12,
			"locked": true,
		}],
		"floors": human_floors,
		"nodes": human_nodes,
		"edges": human_edges,
	}
	var immortal_phase := {
		"id": IMMORTAL_REALM_PHASE_ID,
		"display_name": "신선계",
		"realm_kind": "immortal_realm",
		"floor_start": active_clear_floor + 1,
		"floor_end": 12,
		"total_floors": TOWER_FLOOR_COUNT - active_clear_floor,
		"tower_total_floors": TOWER_FLOOR_COUNT,
		"standard_clear_floor": active_clear_floor,
		"floors": immortal_floors,
		"nodes": immortal_nodes,
		"edges": immortal_edges,
	}
	var immortal_entry_node_id := _derive_entry_node_id(immortal_phase)
	immortal_phase["entry_node_id"] = immortal_entry_node_id
	immortal_phase["initial_route_candidate_ids"] = _derive_outgoing_target_ids(
		immortal_phase,
		immortal_entry_node_id
	)
	result["phases"] = [human_phase, immortal_phase]
	return result


func _build_row_nodes(
	rng: RandomNumberGenerator,
	floor_number: int,
	floor_row_index: int,
	global_row_index: int,
	row_spec: Dictionary
) -> Array[Dictionary]:
	var node_ids := _string_array(row_spec.get("node_ids", []))
	var candidate_count := maxi(1, int(row_spec.get("candidate_count", node_ids.size())))
	if not node_ids.is_empty() and node_ids.size() != candidate_count:
		return []
	var kinds := _string_array(row_spec.get("kinds", []))
	var labels := _string_array(row_spec.get("labels", []))
	if kinds.is_empty() or labels.is_empty():
		return []
	var display_y := int(row_spec.get("display_y", 590 - global_row_index * 160))
	var result: Array[Dictionary] = []
	var kind_offset := rng.randi_range(0, kinds.size() - 1)
	var label_offset := (
		kind_offset
		if labels.size() == kinds.size()
		else rng.randi_range(0, labels.size() - 1)
	)
	for lane in range(candidate_count):
		var node_id := (
			node_ids[lane]
			if not node_ids.is_empty()
			else "floor_%02d_row_%02d_lane_%02d" % [floor_number, floor_row_index + 1, lane + 1]
		)
		var position := _lane_position(candidate_count, lane, display_y)
		var node_kind := kinds[(kind_offset + lane) % kinds.size()]
		result.append({
			"id": node_id,
			"floor": floor_number,
			"segment_floor": int(row_spec.get("segment_floor", floor_number)),
			"row": floor_row_index + 1,
			"global_row": global_row_index,
			"lane": lane,
			"kind": node_kind,
			"label": labels[(label_offset + lane) % labels.size()],
			"position": [int(position.x), int(position.y)],
			"completed": false,
			"gatekeeper": bool(row_spec.get("gatekeeper", false)),
			"enraged": bool(row_spec.get("enraged", false)),
			"floor_boundary": bool(row_spec.get("floor_boundary", false)),
			"route_locked": bool(row_spec.get("route_locked", false)),
			"content_state": str(row_spec.get("content_state", "generated")),
			"floor_one_expansion_row": bool(row_spec.get(
				"floor_one_expansion_row",
				false
			)),
			"floor_one_boss_choice_row": bool(row_spec.get(
				"floor_one_boss_choice_row",
				false
			)),
			"floor_one_boss_choice": (
				bool(row_spec.get("floor_one_boss_choice_row", false))
				and node_kind in COMBAT_NODE_KINDS
			),
			"floor_one_encounter_index": int(row_spec.get(
				"floor_one_encounter_index",
				0
			)),
			"floor_one_expansion_added_node": (
				bool(row_spec.get("floor_one_expansion_row", false))
				or (
					bool(row_spec.get("floor_one_expansion_support_row", false))
					and lane >= ROUTE_CANDIDATE_COUNT
				)
			),
			"generation_roll": rng.randi(),
		})
	return result


func _lane_position(candidate_count: int, lane: int, y_value: int) -> Vector2i:
	if candidate_count <= 1:
		return Vector2i(380, y_value)
	var left := 220
	var right := 540
	return Vector2i(
		int(round(lerpf(float(left), float(right), float(lane) / float(candidate_count - 1)))),
		y_value
	)


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value as Array:
			result.append(str(entry))
	return result


func _last_row_lane_count(
	floor_specs: Array[Dictionary],
	current_floor_rows: Array[Dictionary]
) -> int:
	if not current_floor_rows.is_empty():
		return _string_array(current_floor_rows[-1].get("node_ids", [])).size()
	for floor_index in range(floor_specs.size() - 1, -1, -1):
		var prior_rows_variant: Variant = floor_specs[floor_index].get("rows", [])
		if not (prior_rows_variant is Array) or (prior_rows_variant as Array).is_empty():
			continue
		var prior_row_variant: Variant = (prior_rows_variant as Array)[-1]
		if prior_row_variant is Dictionary:
			return _string_array((prior_row_variant as Dictionary).get("node_ids", [])).size()
	return 0


func _choose_route_lane_count(
	_rng: RandomNumberGenerator,
	floor_number: int,
	previous_lane_count: int,
	active_clear_floor: int
) -> int:
	if floor_number == active_clear_floor + 1:
		return 1
	if previous_lane_count <= 1:
		return ROUTE_CANDIDATE_COUNT
	return mini(MAP_LANE_COUNT_MAX, previous_lane_count * MAX_NODE_OUTGOING_EDGES)


func _choose_gatekeeper_lane_count(
	_rng: RandomNumberGenerator,
	_floor_number: int,
	_previous_lane_count: int,
	_active_clear_floor: int
) -> int:
	# 피드백2 8항: 모든 층 관문은 단일 레인 초크포인트다. NPC 레인으로 관문을
	# 우회해 보스 없이 층을 넘던 경로가 사라지고, 층당 최소 1회 보스 조우가
	# 구조적으로 보장된다(선택 보스는 1층 확장 행이 담당). 관문 다음 행은
	# _choose_route_lane_count의 prev<=1 규칙이 2레인으로 되살린다.
	return 1


func _segment_floor_for_optional_row(
	floor_number: int,
	active_clear_floor: int
) -> int:
	# Floor bands are half-open at the route row between adjacent gate markers:
	# that boundary belongs to the lower, already-entered segment. The first row
	# of a newly activated realm is the sole exception because the prior band is
	# not part of that phase's render surface.
	if floor_number == active_clear_floor + 1:
		return floor_number
	return maxi(1, floor_number - 1)


func _lane_node_ids(row_id: String, lane_count: int) -> Array[String]:
	var result: Array[String] = []
	for lane_index in range(lane_count):
		result.append("%s_lane_%02d" % [row_id, lane_index + 1])
	return result


func _gatekeeper_node_ids(floor_number: int, lane_count: int) -> Array[String]:
	var result: Array[String] = []
	for lane_index in range(lane_count):
		result.append(
			"floor_%02d_gatekeeper" % floor_number
			if lane_index == 0
			else "floor_%02d_gatekeeper_lane_%02d" % [floor_number, lane_index + 1]
		)
	return result


func _draw_unique_noncombat_kinds(
	rng: RandomNumberGenerator,
	lane_count: int
) -> Array[String]:
	var result: Array[String] = []
	var available: Array[String] = []
	available.assign(NONCOMBAT_NODE_KINDS)
	for _lane_index in range(mini(lane_count, available.size())):
		var total_weight := 0
		for node_kind in available:
			total_weight += maxi(
				1,
				int(TowerAscentTuning.TEMP_NODE_TYPE_WEIGHTS.get(node_kind, 1))
			)
		var roll := rng.randi_range(1, total_weight)
		var chosen_index := 0
		for available_index in range(available.size()):
			roll -= maxi(
				1,
				int(TowerAscentTuning.TEMP_NODE_TYPE_WEIGHTS.get(
					available[available_index],
					1
				))
			)
			if roll <= 0:
				chosen_index = available_index
				break
		result.append(available[chosen_index])
		available.remove_at(chosen_index)
	return result


func _floor_one_optional_encounter_enabled(
	_rng: RandomNumberGenerator
) -> bool:
	var stage_one_pool_size := TowerAscentBossRegistry.new().get_floor_slots(1).size()
	var remaining_after_required := maxi(
		0,
		stage_one_pool_size - 1 - FLOOR_ONE_GUARANTEED_ENCOUNTER_COUNT
	)
	# 피드백2 4항: the S8 derived 50% skip made whole runs where one roster
	# boss never appeared on the map. The second encounter now spawns whenever
	# a unique slot remains, so the full first-floor roster (start + both
	# choice rows) is visible on every seed. Still pool-derived: a larger
	# future pool keeps exactly one optional row here (row roles are fixed).
	return remaining_after_required > 0


func _shuffle_ints(values: Array[int], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held := values[index]
		values[index] = values[swap_index]
		values[swap_index] = held


func _map_y(global_row_index: int, total_rows: int) -> int:
	if total_rows <= 1:
		return 590
	return int(round(lerpf(620.0, 130.0, float(global_row_index) / float(total_rows - 1))))


func _label_for_kind(node_kind: String) -> String:
	match node_kind:
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
