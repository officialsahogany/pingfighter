extends RefCounted

const POWER_SMASH_MAX_EFFECT_PARTICLES: int = 82
const PARTICLE_VELOCITY_DECAY: float = 0.92
const PARTICLE_GRAVITY_PER_FRAME: float = 0.1
const ENERGY_BURST_COLOR: Color = Color(150.0 / 255.0, 200.0 / 255.0, 1.0)
const SPARK_COLOR: Color = Color(200.0 / 255.0, 230.0 / 255.0, 1.0)
const AMBIENT_ENERGY_COLORS: Array[Color] = [
	Color(100.0 / 255.0, 150.0 / 255.0, 1.0),
	Color(150.0 / 255.0, 200.0 / 255.0, 1.0),
	Color(200.0 / 255.0, 220.0 / 255.0, 1.0),
]

var particles: Array[Dictionary] = []


func clear() -> void:
	particles.clear()


func spawn(pos: Vector2, count: int, _combo_count: int = 0) -> void:
	for _i in range(max(0, count)):
		var angle: float = randf_range(0.0, TAU)
		if randf() < 0.45:
			_append_particle(
				pos + Vector2(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0)),
				angle,
				randf_range(5.0, 10.0),
				30.0,
				SPARK_COLOR,
				"spark",
				randf_range(2.0, 4.0)
			)
		else:
			_append_particle(
				pos + Vector2(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0)),
				angle,
				randf_range(4.0, 6.0),
				40.0,
				ENERGY_BURST_COLOR,
				"energy",
				randf_range(2.0, 4.0)
			)


func spawn_initial_burst(pos: Vector2) -> void:
	for i in range(10):
		var angle: float = (float(i) / 10.0) * TAU
		_append_particle(pos, angle, randf_range(4.0, 6.0), 40.0, ENERGY_BURST_COLOR, "energy", randf_range(2.0, 4.0))
	for _i in range(6):
		_append_particle(pos, randf_range(0.0, TAU), randf_range(5.0, 10.0), 30.0, SPARK_COLOR, "spark", randf_range(2.0, 4.0))


func spawn_ambient_energy(pos: Vector2) -> void:
	_append_particle(
		pos + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)),
		randf_range(0.0, TAU),
		randf_range(0.5, 2.0),
		25.0,
		AMBIENT_ENERGY_COLORS[randi() % AMBIENT_ENERGY_COLORS.size()],
		"energy",
		randf_range(1.8, 3.2)
	)


func spawn_ambient_spark(pos: Vector2) -> void:
	_append_particle(pos, randf_range(0.0, TAU), randf_range(2.0, 4.0), 15.0, SPARK_COLOR, "spark", randf_range(1.6, 2.8))


func update(fps_scale: float) -> void:
	if particles.is_empty():
		return
	var write_idx: int = 0
	for i in range(particles.size()):
		var p: Dictionary = particles[i]
		var particle_pos: Vector2 = p["pos"]
		var particle_vel: Vector2 = p["vel"]
		var lifetime: float = float(p["lifetime"]) + fps_scale
		var max_lifetime: float = float(p["max_lifetime"])
		particle_pos += particle_vel * fps_scale
		particle_vel *= pow(PARTICLE_VELOCITY_DECAY, fps_scale)
		particle_vel.y += PARTICLE_GRAVITY_PER_FRAME * fps_scale
		if lifetime < max_lifetime:
			p["pos"] = particle_pos
			p["vel"] = particle_vel
			p["lifetime"] = lifetime
			particles[write_idx] = p
			write_idx += 1
	particles.resize(write_idx)


func get_particles() -> Array[Dictionary]:
	return particles


func has_particles() -> bool:
	return not particles.is_empty()


func _append_particle(
	pos: Vector2,
	angle: float,
	speed: float,
	max_lifetime: float,
	color: Color,
	particle_type: String,
	size: float
) -> void:
	particles.append({
		"pos": pos,
		"vel": Vector2(cos(angle), sin(angle)) * speed,
		"size": size,
		"lifetime": 0.0,
		"max_lifetime": max_lifetime,
		"color": color,
		"type": particle_type,
	})
	while particles.size() > POWER_SMASH_MAX_EFFECT_PARTICLES:
		particles.pop_front()
