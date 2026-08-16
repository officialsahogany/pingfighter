extends RefCounted

const COMBAT_NODE_KINDS := ["boss", "combat", "enraged"]


func decorate_graph(
	graph: Dictionary,
	map_seed: int,
	normal_boss_chance: float
) -> Dictionary:
	var result := graph.duplicate(true)
	var phases_variant: Variant = result.get("phases", [])
	if not (phases_variant is Array):
		return {}
	var phases := phases_variant as Array
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed ^ 0x454E52
	var chance := clampf(normal_boss_chance, 0.0, 1.0)
	for phase_index in range(phases.size()):
		if not (phases[phase_index] is Dictionary):
			continue
		var phase := phases[phase_index] as Dictionary
		var nodes: Array = phase.get("nodes", [])
		for node_index in range(nodes.size()):
			if not (nodes[node_index] is Dictionary):
				continue
			var node := nodes[node_index] as Dictionary
			var node_kind := str(node.get("kind", ""))
			if node_kind not in COMBAT_NODE_KINDS:
				continue
			if node_kind == "enraged":
				node["enraged"] = true
				node["enraged_source"] = "fixed_node"
				node["enraged_roll_count"] = 0
				continue
			var roll := rng.randf()
			node["enraged"] = roll < chance
			node["enraged_source"] = "normal_boss_roll"
			node["enraged_roll"] = roll
			node["enraged_roll_chance"] = chance
			node["enraged_roll_count"] = 1
		phase["nodes"] = nodes
		phases[phase_index] = phase
	result["phases"] = phases
	return result
