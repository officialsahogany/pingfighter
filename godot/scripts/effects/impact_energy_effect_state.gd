extends RefCounted

const ENERGY_EXPLOSION_MAX_PARTICLES := 140
const ENERGY_EXPLOSION_COLORS: Array[Color] = [
	Color(150.0 / 255.0, 200.0 / 255.0, 1.0),
	Color(100.0 / 255.0, 180.0 / 255.0, 1.0),
	Color(80.0 / 255.0, 160.0 / 255.0, 1.0),
	Color(200.0 / 255.0, 230.0 / 255.0, 1.0),
	Color(120.0 / 255.0, 200.0 / 255.0, 1.0),
]
const DRIVE_PARTICLE_COLORS: Array[Color] = [
	Color(1.0, 230.0 / 255.0, 70.0 / 255.0),
	Color(120.0 / 255.0, 1.0, 160.0 / 255.0),
	Color(200.0 / 255.0, 1.0, 240.0 / 255.0),
]

var energy_explosion_particles: Array[Dictionary] = []


func clear() -> void:
	energy_explosion_particles.clear()


func create_energy_explosion(pos: Vector2, scale: float, intensity: float) -> void:
	var intensity_multiplier: float = 0.5 + intensity * 1.0 if intensity <= 0.5 else 1.0 - (intensity - 0.5) * 1.0
	var explosion_count: int = int(25.0 * scale * intensity_multiplier)
	var spark_count: int = int(15.0 * scale * intensity_multiplier)
	var speed_multiplier: float = 1.0 + intensity * 0.3

	for _i in range(explosion_count):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(4.0, 12.0) * scale * speed_multiplier
		energy_explosion_particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"size": randf_range(4.0, 10.0) * scale,
			"lifetime": 0.0,
			"max_lifetime": float(randi_range(20, 35)) * scale,
			"color": ENERGY_EXPLOSION_COLORS[randi() % ENERGY_EXPLOSION_COLORS.size()],
			"type": "explosion",
		})

	for _i in range(spark_count):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(6.0, 14.0) * scale * speed_multiplier
		energy_explosion_particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -2.0 * scale),
			"size": randf_range(2.0, 4.0) * scale,
			"lifetime": 0.0,
			"max_lifetime": float(randi_range(15, 25)) * scale,
			"color": Color(200.0 / 255.0, 230.0 / 255.0, 1.0),
			"type": "spark",
		})

	_trim_energy_particles()


func spawn_drive_particles(pos: Vector2, count: int = 4) -> void:
	for _i in range(max(0, count)):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(3.0, 8.0)
		energy_explosion_particles.append({
			"pos": pos + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)),
			"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -1.5),
			"size": randf_range(2.0, 4.0),
			"lifetime": 0.0,
			"max_lifetime": float(randi_range(14, 24)),
			"color": DRIVE_PARTICLE_COLORS[randi() % DRIVE_PARTICLE_COLORS.size()],
			"type": "spark",
		})
	_trim_energy_particles()


func update(fps_scale: float) -> void:
	var updated_explosions: Array[Dictionary] = []
	for particle in energy_explosion_particles:
		var p: Dictionary = particle
		var particle_pos: Vector2 = p["pos"]
		var particle_vel: Vector2 = p["vel"]
		var particle_size: float = float(p["size"])
		var lifetime: float = float(p["lifetime"]) + fps_scale
		var max_lifetime: float = float(p["max_lifetime"])
		particle_pos += particle_vel * fps_scale
		particle_vel *= pow(0.94, fps_scale)
		particle_size *= pow(0.95, fps_scale)
		if lifetime < max_lifetime and particle_size >= 0.3:
			p["pos"] = particle_pos
			p["vel"] = particle_vel
			p["size"] = particle_size
			p["lifetime"] = lifetime
			updated_explosions.append(p)
	energy_explosion_particles = updated_explosions


func get_energy_explosion_particles() -> Array[Dictionary]:
	return energy_explosion_particles.duplicate()


func _trim_energy_particles() -> void:
	while energy_explosion_particles.size() > ENERGY_EXPLOSION_MAX_PARTICLES:
		energy_explosion_particles.pop_front()
