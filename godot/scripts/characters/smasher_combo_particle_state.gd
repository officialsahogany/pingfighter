extends RefCounted

const SMASHER_COMBO_MAX_PARTICLES := 54

var particles: Array[Dictionary] = []


func reset() -> void:
	particles.clear()


func update(fps_scale: float) -> void:
	var write_idx: int = 0
	var particle_count: int = particles.size()
	for particle_idx in range(particle_count):
		var p: Dictionary = particles[particle_idx]
		var particle_pos: Vector2 = p["pos"]
		var particle_vel: Vector2 = p["vel"]
		var particle_life: float = float(p["life"]) - fps_scale
		particle_pos += particle_vel * fps_scale
		particle_vel.y += 0.10 * fps_scale
		particle_vel *= pow(0.985, fps_scale)
		if particle_life <= 0.0:
			continue
		p["pos"] = particle_pos
		p["vel"] = particle_vel
		p["life"] = particle_life
		particles[write_idx] = p
		write_idx += 1
	if write_idx < particle_count:
		particles.resize(write_idx)


func spawn_effect_particles(pos: Vector2, combo_count: int, combo_color: Color) -> void:
	var particle_count: int = min(combo_count * 4, 22)
	for particle_idx in range(particle_count):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(2.0, 5.0 + float(combo_count))
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": float(randi_range(16, 32 + combo_count * 4)),
			"max_life": float(50 + combo_count * 3),
			"color": combo_color,
			"size": randf_range(3.0, 6.0 + float(combo_count) * 0.5),
			"shape": 1 if combo_count >= 4 and particle_idx % 3 == 0 else 0,
		})
	while particles.size() > SMASHER_COMBO_MAX_PARTICLES:
		particles.pop_front()


func get_particles() -> Array[Dictionary]:
	return particles


func has_particles() -> bool:
	return not particles.is_empty()
