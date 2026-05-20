extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const HOLY_BARRIER_HEIGHT := 20.0
const HOLY_BARRIER_Y_OFFSET := 5.0
const HOLY_BARRIER_PARTICLE_INTERVAL_FRAMES := 5.0
const HOLY_BARRIER_PARTICLE_COLORS := [
	Color(1.0, 1.0, 200.0 / 255.0, 1.0),
	Color(200.0 / 255.0, 220.0 / 255.0, 1.0, 1.0),
	Color(1.0, 230.0 / 255.0, 150.0 / 255.0, 1.0),
]


func advance_idle_particles(
	particles: Array[Dictionary],
	accumulator_frames: float,
	fps_scale: float,
	delta: float
) -> float:
	var next_accumulator: float = accumulator_frames + fps_scale
	while next_accumulator >= HOLY_BARRIER_PARTICLE_INTERVAL_FRAMES:
		next_accumulator -= HOLY_BARRIER_PARTICLE_INTERVAL_FRAMES
		spawn_idle_particles(particles)
	update_particles(particles, fps_scale, delta)
	return next_accumulator


func spawn_hit_particles(particles: Array[Dictionary], impact_pos: Vector2) -> void:
	for _i in range(10):
		particles.append({
			"position": impact_pos + Vector2(randf_range(-15.0, 15.0), 0.0),
			"velocity": Vector2(randf_range(-2.0, 2.0), randf_range(-3.0, -1.0)) * 60.0,
			"radius": randf_range(3.0, 7.0),
			"alpha": 1.0,
			"color": Color(1.0, 1.0, 100.0 / 255.0, 1.0),
		})


func spawn_idle_particles(particles: Array[Dictionary]) -> void:
	var barrier_center_y: float = FIELD_HEIGHT - HOLY_BARRIER_Y_OFFSET - HOLY_BARRIER_HEIGHT * 0.5
	for _i in range(2):
		particles.append({
			"position": Vector2(randf_range(0.0, FIELD_WIDTH), barrier_center_y + randf_range(-5.0, 5.0)),
			"velocity": Vector2(randf_range(-0.5, 0.5), randf_range(-1.5, -0.5)) * 60.0,
			"radius": randf_range(2.0, 5.0),
			"alpha": 1.0,
			"color": HOLY_BARRIER_PARTICLE_COLORS[randi() % HOLY_BARRIER_PARTICLE_COLORS.size()],
		})


func update_particles(particles: Array[Dictionary], fps_scale: float, delta: float) -> void:
	if particles.is_empty():
		return
	var particle_write_index := 0
	for read_index in range(particles.size()):
		var particle: Dictionary = particles[read_index]
		var alpha: float = float(particle.get("alpha", 1.0)) - (8.0 / 255.0) * fps_scale
		if alpha <= 0.0:
			continue
		particle["alpha"] = alpha
		particle["position"] = _get_vector2(particle, "position", Vector2.ZERO) + _get_vector2(particle, "velocity", Vector2.ZERO) * delta
		particles[particle_write_index] = particle
		particle_write_index += 1
	if particle_write_index < particles.size():
		particles.resize(particle_write_index)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
