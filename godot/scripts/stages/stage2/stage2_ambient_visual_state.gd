extends RefCounted


static func update_falling_leaves(falling_leaves: Array, delta: float, layout_size: Vector2) -> void:
	var write_index := 0
	var leaf_count := falling_leaves.size()
	for index in range(leaf_count):
		var leaf: Dictionary = falling_leaves[index]
		leaf["y"] = float(leaf.get("y", 0.0)) + float(leaf.get("fall_speed", 0.45)) * delta * 60.0
		leaf["sway_offset"] = float(leaf.get("sway_offset", 0.0)) + 1.5 * delta
		leaf["rotation"] = float(leaf.get("rotation", 0.0)) + float(leaf.get("rot_speed", 0.0)) * delta * 60.0
		if float(leaf.get("y", 0.0)) > layout_size.y + 25.0:
			continue
		falling_leaves[write_index] = leaf
		write_index += 1
	if write_index < leaf_count:
		falling_leaves.resize(write_index)


static func update_fireflies(fireflies: Array, delta: float, layout_size: Vector2) -> void:
	for index in range(fireflies.size()):
		var fly: Dictionary = fireflies[index]
		var phase: float = float(fly.get("phase", 0.0)) + float(fly.get("speed", 0.4)) * delta
		fly["phase"] = phase
		fly["x"] = float(fly.get("x", 0.0)) + sin(phase) * 0.35 * delta * 60.0
		fly["y"] = float(fly.get("y", 0.0)) + cos(phase * 0.7) * 0.2 * delta * 60.0
		if float(fly.get("x", 0.0)) < -25.0:
			fly["x"] = layout_size.x + 25.0
		elif float(fly.get("x", 0.0)) > layout_size.x + 25.0:
			fly["x"] = -25.0
		if float(fly.get("y", 0.0)) < -25.0:
			fly["y"] = layout_size.y + 25.0
		elif float(fly.get("y", 0.0)) > layout_size.y + 25.0:
			fly["y"] = -25.0
		fireflies[index] = fly
