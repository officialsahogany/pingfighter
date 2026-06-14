extends RefCounted

const ActiveItemHolyBarrierParticlePayloadFactory := preload("res://scripts/items/active_item_holy_barrier_particle_payload_factory.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const HOLY_BARRIER_HEIGHT := 20.0
const HOLY_BARRIER_Y_OFFSET := 5.0
const HOLY_BARRIER_PARTICLE_INTERVAL_FRAMES := 5.0


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
		particles.append(ActiveItemHolyBarrierParticlePayloadFactory.build_hit_particle(impact_pos))


func spawn_idle_particles(particles: Array[Dictionary]) -> void:
	var barrier_center_y: float = FIELD_HEIGHT - HOLY_BARRIER_Y_OFFSET - HOLY_BARRIER_HEIGHT * 0.5
	for _i in range(2):
		particles.append(ActiveItemHolyBarrierParticlePayloadFactory.build_idle_particle(FIELD_WIDTH, barrier_center_y))


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
