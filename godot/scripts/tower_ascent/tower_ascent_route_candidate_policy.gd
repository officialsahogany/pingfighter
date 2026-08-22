extends RefCounted

const COMBAT_NODE_KINDS := ["boss", "combat", "enraged"]


func filter_available(
	nodes: Array,
	candidate_ids: Array,
	skipped_boss_ids: Array
) -> Array[String]:
	var result: Array[String] = []
	for candidate_variant in candidate_ids:
		var candidate_id := str(candidate_variant)
		var node := _find_node(nodes, candidate_id)
		if node.is_empty():
			continue
		if is_node_blocked_by_skipped_boss(node, skipped_boss_ids):
			continue
		result.append(candidate_id)
	return result


func filter_available_indexed(
	node_by_id: Dictionary,
	candidate_ids: Array,
	skipped_boss_ids: Array
) -> Array[String]:
	var result: Array[String] = []
	for candidate_variant in candidate_ids:
		var candidate_id := str(candidate_variant)
		var node_variant: Variant = node_by_id.get(candidate_id, {})
		if not (node_variant is Dictionary):
			continue
		if is_node_blocked_by_skipped_boss(node_variant as Dictionary, skipped_boss_ids):
			continue
		result.append(candidate_id)
	return result


func is_node_blocked_by_skipped_boss(node: Dictionary, skipped_boss_ids: Array) -> bool:
	if str(node.get("kind", "")) not in COMBAT_NODE_KINDS:
		return false
	var boss_slot_id := str(node.get("boss_slot_id", ""))
	return not boss_slot_id.is_empty() and skipped_boss_ids.has(boss_slot_id)


func apply_skipped_markers(graph: Dictionary, skipped_boss_ids: Array) -> Dictionary:
	var result := graph.duplicate(true)
	var phases_variant: Variant = result.get("phases", [])
	if not (phases_variant is Array):
		return {}
	var phases := phases_variant as Array
	for phase_index in range(phases.size()):
		if not (phases[phase_index] is Dictionary):
			continue
		var phase := phases[phase_index] as Dictionary
		var nodes: Array = phase.get("nodes", [])
		for node_index in range(nodes.size()):
			if not (nodes[node_index] is Dictionary):
				continue
			var node := nodes[node_index] as Dictionary
			if is_node_blocked_by_skipped_boss(node, skipped_boss_ids):
				node["route_disabled"] = true
				node["skipped"] = true
		phase["nodes"] = nodes
		phases[phase_index] = phase
	result["phases"] = phases
	return result


func _find_node(nodes: Array, node_id: String) -> Dictionary:
	for node_variant in nodes:
		if node_variant is Dictionary and str((node_variant as Dictionary).get("id", "")) == node_id:
			return node_variant as Dictionary
	return {}
