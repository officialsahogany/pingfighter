extends RefCounted

const GENERATOR_VERSION := "tower_map_v1"


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
	var label_offset := rng.randi_range(0, labels.size() - 1)
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
