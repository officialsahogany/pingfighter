extends RefCounted

const SEVERE_LOD_SCALE_THRESHOLD := 0.50
const SEVERE_LOD_MAX_PARTICLES := 18
const SEVERE_LOD_SPAWN_CHANCE_MULTIPLIER := 0.45

var intensity_particles: Array[Dictionary] = []


func clear() -> void:
	intensity_particles.clear()


func update_low_intensity(fps_scale: float) -> void:
	if intensity_particles.is_empty():
		return
	var write_idx: int = 0
	for i in range(intensity_particles.size()):
		var p: Dictionary = intensity_particles[i]
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
			intensity_particles[write_idx] = p
			write_idx += 1
	intensity_particles.resize(write_idx)


func update(
	ball_center: Vector2,
	ball_velocity: Vector2,
	fps_scale: float,
	intensity: float,
	colors: Array[Color],
	effect_lod_scale: float = 1.0
) -> void:
	var severe_lod: bool = effect_lod_scale <= SEVERE_LOD_SCALE_THRESHOLD
	var particle_count: int = int(1.0 + intensity * 2.0) if intensity <= 0.5 else max(1, int(2.0 - (intensity - 0.5) * 2.0))
	var spawn_chance: float = 0.12 + intensity * 0.16 if intensity <= 0.5 else 0.24 - (intensity - 0.5) * 0.14
	if severe_lod:
		particle_count = 1
		spawn_chance *= SEVERE_LOD_SPAWN_CHANCE_MULTIPLIER
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

	var write_idx: int = 0
	for i in range(intensity_particles.size()):
		var p: Dictionary = intensity_particles[i]
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
			intensity_particles[write_idx] = p
			write_idx += 1
	intensity_particles.resize(write_idx)

	var max_particles: int = int(42.0 - intensity * 18.0) if intensity > 0.5 else 42
	if severe_lod:
		max_particles = min(max_particles, SEVERE_LOD_MAX_PARTICLES)
	while intensity_particles.size() > max_particles:
		intensity_particles.pop_front()


func get_particles() -> Array[Dictionary]:
	return intensity_particles
