extends RefCounted

const ActiveItemRegenerationPotionPayloadFactory := preload("res://scripts/items/active_item_regeneration_potion_payload_factory.gd")

const REGENERATION_POTION_PARTICLE_DURATION_SEC := 0.78
const REGENERATION_POTION_RING_DURATION_SEC := 0.58
const REGENERATION_POTION_PARTICLE_COUNT := 12


func spawn_effect(particles: Array[Dictionary], rings: Array[Dictionary], center: Vector2) -> void:
	rings.append(ActiveItemRegenerationPotionPayloadFactory.build_ring(center, REGENERATION_POTION_RING_DURATION_SEC))

	for _i in range(REGENERATION_POTION_PARTICLE_COUNT):
		particles.append(ActiveItemRegenerationPotionPayloadFactory.build_particle(center, REGENERATION_POTION_PARTICLE_DURATION_SEC))


func update_effect(particles: Array[Dictionary], rings: Array[Dictionary], delta: float) -> void:
	if not particles.is_empty():
		var particle_write_index := 0
		for read_index in range(particles.size()):
			var particle: Dictionary = particles[read_index]
			var age: float = float(particle.get("age", 0.0)) + delta
			var lifetime: float = max(0.001, float(particle.get("lifetime", REGENERATION_POTION_PARTICLE_DURATION_SEC)))
			if age >= lifetime:
				continue
			var pos: Vector2 = _get_vector2(particle, "position", Vector2.ZERO)
			var velocity: Vector2 = _get_vector2(particle, "velocity", Vector2.ZERO)
			pos += velocity * delta
			velocity = velocity.lerp(Vector2.ZERO, min(1.0, delta * 1.8))
			velocity.y += 18.0 * delta
			particle["age"] = age
			particle["position"] = pos
			particle["velocity"] = velocity
			particles[particle_write_index] = particle
			particle_write_index += 1
		if particle_write_index < particles.size():
			particles.resize(particle_write_index)

	if not rings.is_empty():
		var ring_write_index := 0
		for read_index in range(rings.size()):
			var ring: Dictionary = rings[read_index]
			var age: float = float(ring.get("age", 0.0)) + delta
			var duration: float = max(0.001, float(ring.get("duration", REGENERATION_POTION_RING_DURATION_SEC)))
			if age >= duration:
				continue
			ring["age"] = age
			rings[ring_write_index] = ring
			ring_write_index += 1
		if ring_write_index < rings.size():
			rings.resize(ring_write_index)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
