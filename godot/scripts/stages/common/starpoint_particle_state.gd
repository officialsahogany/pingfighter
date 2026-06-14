extends RefCounted


static func update_particles(starpoint_particles: Array, fps_scale: float) -> void:
	if starpoint_particles.is_empty():
		return
	var write_index := 0
	var particle_count := starpoint_particles.size()
	for index in range(particle_count):
		var particle_value: Variant = starpoint_particles[index]
		var particle: Dictionary = particle_value if particle_value is Dictionary else {}
		update_particle(particle, fps_scale)
		if float(particle.get("alpha", 0.0)) > 0.0 and float(particle.get("life", 0.0)) > 0.0:
			starpoint_particles[write_index] = particle
			write_index += 1
	if write_index < particle_count:
		starpoint_particles.resize(write_index)


static func update_particle(particle: Dictionary, fps_scale: float) -> void:
	var pos: Vector2 = _get_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO)
	var vel: Vector2 = _get_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
	pos += vel * fps_scale
	vel.y += 0.1 * fps_scale
	particle["pos"] = pos
	particle["vel"] = vel
	particle["alpha"] = max(0.0, float(particle.get("alpha", 1.0)) - float(particle.get("fade_speed", 0.05)) * fps_scale)
	particle["life"] = float(particle.get("life", 0.0)) - fps_scale


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
