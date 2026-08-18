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

const GENERATOR_VERSION := "tower_map_v6_two_realms"
const TOWER_FLOOR_COUNT := 12
const STANDARD_CLEAR_FLOOR := 9
const HUMAN_REALM_PHASE_ID := "phase_01_human_realm"
const IMMORTAL_REALM_PHASE_ID := "phase_02_immortal_realm"
const ROUTE_CANDIDATE_COUNT := 2
const COMBAT_NODE_KINDS := ["boss", "combat", "enraged"]
const NONCOMBAT_NODE_KINDS := [
	"shop",
	"training",
	"fallen_monk",
	"guardian_spring",
	"rest",
]


func generate_tower(map_seed: int, skipped_boss_ids: Array = []) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var extra_combat_floor_count := rng.randi_range(
		TowerAscentTuning.TEMP_STANDARD_EXTRA_COMBAT_ROWS_MIN,
		TowerAscentTuning.TEMP_STANDARD_EXTRA_COMBAT_ROWS_MAX
	)
	var standard_optional_floors: Array[int] = []
	for floor_number in range(2, STANDARD_CLEAR_FLOOR):
		standard_optional_floors.append(floor_number)
	_shuffle_ints(standard_optional_floors, rng)
	var combat_optional_floors := standard_optional_floors.slice(0, extra_combat_floor_count)
	var noncombat_deck := _build_noncombat_deck(rng)
	var noncombat_cursor := 0
	var total_rows := 1 + (TOWER_FLOOR_COUNT - 1) * (
		TowerAscentTuning.TEMP_OPTIONAL_ROWS_PER_FLOOR + 1
	)
	var global_row_index := 0
	var floor_specs: Array[Dictionary] = []
	for floor_number in range(1, TOWER_FLOOR_COUNT + 1):
		var rows: Array[Dictionary] = []
		if floor_number > 1:
			for optional_index in range(TowerAscentTuning.TEMP_OPTIONAL_ROWS_PER_FLOOR):
				var node_kinds: Array[String] = []
				var labels: Array[String] = []
				if floor_number <= STANDARD_CLEAR_FLOOR and combat_optional_floors.has(floor_number):
					node_kinds = ["combat", "enraged"]
					labels = ["전투", "광폭화"]
				else:
					for _lane in range(ROUTE_CANDIDATE_COUNT):
						var node_kind := noncombat_deck[noncombat_cursor % noncombat_deck.size()]
						noncombat_cursor += 1
						node_kinds.append(node_kind)
						labels.append(_label_for_kind(node_kind))
				rows.append({
					"id": "floor_%02d_route_%02d" % [floor_number, optional_index + 1],
					"candidate_count": ROUTE_CANDIDATE_COUNT,
					"node_ids": [
						"floor_%02d_route_%02d_lane_01" % [floor_number, optional_index + 1],
						"floor_%02d_route_%02d_lane_02" % [floor_number, optional_index + 1],
					],
					"kinds": node_kinds,
					"labels": labels,
					"display_y": _map_y(global_row_index, total_rows),
					"route_locked": floor_number > STANDARD_CLEAR_FLOOR,
					"content_state": "registry_only" if floor_number > STANDARD_CLEAR_FLOOR else "generated",
				})
				global_row_index += 1
		rows.append({
			"id": "floor_%02d_gatekeeper_row" % floor_number,
			"candidate_count": 1,
			"node_ids": ["floor_%02d_gatekeeper" % floor_number],
			"kinds": ["boss"],
			"labels": ["%d층 수문장" % floor_number],
			"display_y": _map_y(global_row_index, total_rows),
			"gatekeeper": true,
			"floor_boundary": true,
			"route_locked": floor_number > STANDARD_CLEAR_FLOOR,
			"content_state": "registry_only" if floor_number > STANDARD_CLEAR_FLOOR else "generated",
		})
		global_row_index += 1
		floor_specs.append({"floor": floor_number, "rows": rows})
	var generated := generate(map_seed, floor_specs)
	if generated.is_empty():
		return {}
	var phase: Dictionary = generated.phases[0]
	phase["total_floors"] = TOWER_FLOOR_COUNT
	phase["standard_clear_floor"] = STANDARD_CLEAR_FLOOR
	phase["entry_node_id"] = "floor_01_gatekeeper"
	phase["initial_route_candidate_ids"] = [
		"floor_02_route_01_lane_01",
		"floor_02_route_01_lane_02",
	]
	generated["phases"] = [phase]
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
	return _split_tower_realms(marked)


func analyze_standard_combat_budget(graph: Dictionary) -> Dictionary:
	var phases_variant: Variant = graph.get("phases", [])
	if not (phases_variant is Array) or (phases_variant as Array).is_empty():
		return {}
	var phase_variant: Variant = (phases_variant as Array)[0]
	if not (phase_variant is Dictionary):
		return {}
	var phase := phase_variant as Dictionary
	var node_by_id: Dictionary = {}
	for node_variant in phase.get("nodes", []):
		if node_variant is Dictionary:
			var node := node_variant as Dictionary
			node_by_id[str(node.get("id", ""))] = node
	var minimum := 0
	var maximum := 0
	for floor_variant in phase.get("floors", []):
		if not (floor_variant is Dictionary):
			continue
		var floor_data := floor_variant as Dictionary
		if int(floor_data.get("floor", 0)) > STANDARD_CLEAR_FLOOR:
			break
		for row_variant in floor_data.get("rows", []):
			if not (row_variant is Dictionary):
				continue
			var counts: Array[int] = []
			for node_id_variant in (row_variant as Dictionary).get("node_ids", []):
				var node: Dictionary = node_by_id.get(str(node_id_variant), {})
				counts.append(1 if COMBAT_NODE_KINDS.has(str(node.get("kind", ""))) else 0)
			if not counts.is_empty():
				minimum += counts.min()
				maximum += counts.max()
	return {"minimum": minimum, "maximum": maximum}


func generate(map_seed: int, floor_specs: Array) -> Dictionary:
	if floor_specs.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
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
			for from_id in previous_row_ids:
				for to_id in current_row_ids:
					edges.append({"from": from_id, "to": to_id})
			floor_rows.append({
				"id": str(row_spec.get("id", "floor_%02d_row_%02d" % [floor_number, floor_row_index + 1])),
				"node_ids": current_row_ids.duplicate(),
				"gatekeeper": bool(row_spec.get("gatekeeper", false)),
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


func encode_graph(graph: Dictionary) -> PackedByteArray:
	return var_to_bytes(graph)


func _split_tower_realms(graph: Dictionary) -> Dictionary:
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
		if floor_number <= STANDARD_CLEAR_FLOOR:
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
		if int(floor_data.get("floor", 0)) <= STANDARD_CLEAR_FLOOR:
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
	if human_floors.size() != STANDARD_CLEAR_FLOOR or immortal_floors.size() != 3:
		return {}
	var human_phase := {
		"id": HUMAN_REALM_PHASE_ID,
		"display_name": "인간계",
		"realm_kind": "human_realm",
		"floor_start": 1,
		"floor_end": STANDARD_CLEAR_FLOOR,
		"total_floors": STANDARD_CLEAR_FLOOR,
		"tower_total_floors": TOWER_FLOOR_COUNT,
		"standard_clear_floor": STANDARD_CLEAR_FLOOR,
		"entry_node_id": "floor_01_gatekeeper",
		"initial_route_candidate_ids": [
			"floor_02_route_01_lane_01",
			"floor_02_route_01_lane_02",
		],
		"locked_phase_hints": [{
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
		"floor_start": 10,
		"floor_end": 12,
		"total_floors": 3,
		"tower_total_floors": TOWER_FLOOR_COUNT,
		"standard_clear_floor": STANDARD_CLEAR_FLOOR,
		"entry_node_id": "floor_10_route_01_lane_01",
		"initial_route_candidate_ids": [
			"floor_10_route_01_lane_01",
			"floor_10_route_01_lane_02",
		],
		"floors": immortal_floors,
		"nodes": immortal_nodes,
		"edges": immortal_edges,
	}
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
		result.append({
			"id": node_id,
			"floor": floor_number,
			"row": floor_row_index + 1,
			"lane": lane,
			"kind": kinds[(kind_offset + lane) % kinds.size()],
			"label": labels[(label_offset + lane) % labels.size()],
			"position": [int(position.x), int(position.y)],
			"completed": false,
			"gatekeeper": bool(row_spec.get("gatekeeper", false)),
			"enraged": bool(row_spec.get("enraged", false)),
			"floor_boundary": bool(row_spec.get("floor_boundary", false)),
			"route_locked": bool(row_spec.get("route_locked", false)),
			"content_state": str(row_spec.get("content_state", "generated")),
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


func _build_noncombat_deck(rng: RandomNumberGenerator) -> Array[String]:
	var result: Array[String] = []
	for node_kind in NONCOMBAT_NODE_KINDS:
		var copies := maxi(1, int(TowerAscentTuning.TEMP_NODE_TYPE_WEIGHTS.get(node_kind, 1)))
		for _copy_index in range(copies):
			result.append(node_kind)
	for index in range(result.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held := result[index]
		result[index] = result[swap_index]
		result[swap_index] = held
	return result


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
