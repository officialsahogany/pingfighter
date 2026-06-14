extends RefCounted

const ActiveItemDashBoostParticlePayloadFactory := preload("res://scripts/items/active_item_dash_boost_particle_payload_factory.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const DASH_BOOST_PARTICLE_INTERVAL_FRAMES := 3.0


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
	var center := Vector2(center_x, center_y)
	for _i in range(2):
		particles.append(ActiveItemDashBoostParticlePayloadFactory.build_idle_particle(center))


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
