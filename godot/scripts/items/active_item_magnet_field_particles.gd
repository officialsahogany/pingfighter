extends RefCounted

const MAGNET_PARTICLE_INTERVAL_FRAMES := 3.0
const MAGNET_FIELD_PARTICLE_CAP := 96
const MAGNET_FIELD_PARTICLE_COLORS := [
	Color(100.0 / 255.0, 150.0 / 255.0, 1.0, 1.0),
	Color(150.0 / 255.0, 100.0 / 255.0, 1.0, 1.0),
	Color(80.0 / 255.0, 200.0 / 255.0, 1.0, 1.0),
	Color(200.0 / 255.0, 150.0 / 255.0, 1.0, 1.0),
]


func advance_particles(
	particles: Array[Dictionary],
	player_center: Vector2,
	accumulator_frames: float,
	fps_scale: float
) -> float:
	var next_accumulator: float = accumulator_frames + fps_scale
	while next_accumulator >= MAGNET_PARTICLE_INTERVAL_FRAMES:
		next_accumulator -= MAGNET_PARTICLE_INTERVAL_FRAMES
		spawn_particle(particles, player_center)
	update_particles(particles, fps_scale)
	return next_accumulator


func spawn_particle(particles: Array[Dictionary], player_center: Vector2) -> void:
	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(40.0, 150.0)
	var start_pos := Vector2(
		player_center.x + cos(angle) * radius,
		player_center.y - randf_range(20.0, 120.0)
	)
	particles.append({
		"position": start_pos,
		"velocity": Vector2(cos(angle) * randf_range(-0.3, 0.3), randf_range(-1.5, -0.5)),
		"radius": float(randi_range(2, 4)),
		"alpha": 200.0 / 255.0,
		"color": MAGNET_FIELD_PARTICLE_COLORS[randi() % MAGNET_FIELD_PARTICLE_COLORS.size()],
	})
	enforce_cap(particles)


func update_particles(particles: Array[Dictionary], fps_scale: float) -> void:
	if particles.is_empty():
		return
	var write_index := 0
	for read_index in range(particles.size()):
		var particle: Dictionary = particles[read_index]
		var alpha: float = float(particle.get("alpha", 1.0)) - (6.0 / 255.0) * fps_scale
		if alpha <= 0.0:
			continue
		particle["alpha"] = alpha
		particle["position"] = _get_vector2(particle, "position", Vector2.ZERO) + _get_vector2(particle, "velocity", Vector2.ZERO) * fps_scale
		particles[write_index] = particle
		write_index += 1
	if write_index < particles.size():
		particles.resize(write_index)


func enforce_cap(particles: Array[Dictionary]) -> void:
	while particles.size() > MAGNET_FIELD_PARTICLE_CAP:
		particles.pop_front()


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
