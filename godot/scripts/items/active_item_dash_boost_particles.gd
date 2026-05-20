extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const DASH_BOOST_PARTICLE_INTERVAL_FRAMES := 3.0
const DASH_BOOST_PARTICLE_COLORS := [
	Color(100.0 / 255.0, 200.0 / 255.0, 1.0, 1.0),
	Color(150.0 / 255.0, 1.0, 200.0 / 255.0, 1.0),
	Color(200.0 / 255.0, 150.0 / 255.0, 1.0, 1.0),
	Color(1.0, 200.0 / 255.0, 100.0 / 255.0, 1.0),
]


func advance_idle_particles(
	particles: Array[Dictionary],
	accumulator_frames: float,
	player_center: Vector2,
	fps_scale: float,
	delta: float
) -> float:
	var next_accumulator: float = accumulator_frames + fps_scale
	while next_accumulator >= DASH_BOOST_PARTICLE_INTERVAL_FRAMES:
		next_accumulator -= DASH_BOOST_PARTICLE_INTERVAL_FRAMES
		spawn_idle_particles(particles, player_center)
	update_particles(particles, fps_scale, delta)
	return next_accumulator


func spawn_idle_particles(particles: Array[Dictionary], player_center: Vector2) -> void:
	var center_x: float = player_center.x if player_center.x > 0.0 else FIELD_WIDTH * 0.5
	var center_y: float = player_center.y if player_center.y > 0.0 else FIELD_HEIGHT - 25.0
	for _i in range(2):
		particles.append({
			"position": Vector2(center_x + randf_range(-180.0, 180.0), center_y - randf_range(0.0, 30.0)),
			"velocity": Vector2(randf_range(-1.0, 1.0), randf_range(-2.0, -0.5)) * 60.0,
			"radius": float(randi_range(2, 4)),
			"alpha": 200.0 / 255.0,
			"shrink_per_frame": 0.05,
			"color": DASH_BOOST_PARTICLE_COLORS[randi() % DASH_BOOST_PARTICLE_COLORS.size()],
		})


func update_particles(particles: Array[Dictionary], fps_scale: float, delta: float) -> void:
	if particles.is_empty():
		return
	var write_index := 0
	for read_index in range(particles.size()):
		var particle: Dictionary = particles[read_index]
		var alpha: float = float(particle.get("alpha", 1.0)) - (6.0 / 255.0) * fps_scale
		if alpha <= 0.0:
			continue
		particle["alpha"] = alpha
		var radius: float = float(particle.get("radius", 1.0)) - float(particle.get("shrink_per_frame", 0.05)) * fps_scale
		particle["radius"] = max(1.0, radius)
		particle["position"] = _get_vector2(particle, "position", Vector2.ZERO) + _get_vector2(particle, "velocity", Vector2.ZERO) * delta
		particles[write_index] = particle
		write_index += 1
	if write_index < particles.size():
		particles.resize(write_index)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
