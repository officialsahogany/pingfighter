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


static func update_leaf_particles(leaf_particles: Array, delta: float) -> void:
	var write_index := 0
	var particle_count := leaf_particles.size()
	for index in range(particle_count):
		var particle: Dictionary = leaf_particles[index]
		var life: float = float(particle.get("life", 0.0)) - delta
		if life <= 0.0:
			continue
		var pos: Vector2 = _get_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _get_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		vel.y += 86.0 * delta
		vel *= pow(0.985, delta * 60.0)
		pos += vel * delta
		particle["pos"] = pos
		particle["vel"] = vel
		particle["life"] = life
		particle["rot"] = float(particle.get("rot", 0.0)) + float(particle.get("spin", 0.0)) * delta
		leaf_particles[write_index] = particle
		write_index += 1
	if write_index < particle_count:
		leaf_particles.resize(write_index)


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
