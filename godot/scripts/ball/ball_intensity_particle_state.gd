extends RefCounted

var intensity_particles: Array[Dictionary] = []


func clear() -> void:
	intensity_particles.clear()


func update_low_intensity(fps_scale: float) -> void:
	var low_particles: Array[Dictionary] = []
	for particle in intensity_particles:
		var p: Dictionary = particle
		var particle_pos: Vector2 = p["pos"]
		var particle_vel: Vector2 = p["vel"]
		var particle_life: float = float(p["life"]) - fps_scale
		var particle_size: float = float(p["size"]) * pow(0.95, fps_scale)
		particle_pos += particle_vel * fps_scale
		particle_vel.y += 0.1 * fps_scale
		if particle_life > 0.0 and particle_size > 0.5:
			p["pos"] = particle_pos
			p["vel"] = particle_vel
			p["life"] = particle_life
			p["size"] = particle_size
			low_particles.append(p)
	intensity_particles = low_particles


func update(
	ball_center: Vector2,
	ball_velocity: Vector2,
	fps_scale: float,
	intensity: float,
	colors: Array[Color]
) -> void:
	var particle_count: int = int(1.0 + intensity * 4.0) if intensity <= 0.5 else max(1, int(3.0 - (intensity - 0.5) * 4.0))
	var spawn_chance: float = 0.3 + intensity * 0.3 if intensity <= 0.5 else 0.45 - (intensity - 0.5) * 0.3
	for _i in range(particle_count):
		if randf() < spawn_chance:
			var angle: float = atan2(-ball_velocity.y, -ball_velocity.x) + randf_range(-0.5, 0.5)
			var speed: float = randf_range(1.0, 3.0) * (1.0 + intensity)
			intensity_particles.append({
				"pos": ball_center + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)),
				"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)),
				"size": randf_range(3.0, 8.0) * (0.5 + intensity * 0.5),
				"life": 15.0 + intensity * 25.0,
				"max_life": 15.0 + intensity * 25.0,
				"color": colors[randi() % colors.size()],
				"type": "flame" if randf() < 0.7 else "spark",
			})

	var updated_particles: Array[Dictionary] = []
	for particle in intensity_particles:
		var p: Dictionary = particle
		var particle_pos: Vector2 = p["pos"]
		var particle_vel: Vector2 = p["vel"]
		var particle_life: float = float(p["life"]) - fps_scale
		var particle_size: float = float(p["size"])
		particle_pos += particle_vel * fps_scale
		if str(p["type"]) == "flame":
			particle_vel.y -= 0.15 * fps_scale
			particle_size *= pow(0.96, fps_scale)
		else:
			particle_vel.y += 0.05 * fps_scale
			particle_size *= pow(0.93, fps_scale)
		if particle_life > 0.0 and particle_size > 0.5:
			p["pos"] = particle_pos
			p["vel"] = particle_vel
			p["life"] = particle_life
			p["size"] = particle_size
			updated_particles.append(p)
	intensity_particles = updated_particles

	var max_particles: int = int(150.0 - intensity * 90.0) if intensity > 0.5 else 150
	while intensity_particles.size() > max_particles:
		intensity_particles.pop_front()


func get_particles() -> Array[Dictionary]:
	return intensity_particles.duplicate()
