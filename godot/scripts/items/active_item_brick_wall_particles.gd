extends RefCounted

const ActiveItemBrickWallParticlePayloadFactory := preload("res://scripts/items/active_item_brick_wall_particle_payload_factory.gd")

const BRICK_WALL_PARTICLE_CAP := 64
const BRICK_DESTRUCTION_FRAGMENT_MIN := 8
const BRICK_DESTRUCTION_FRAGMENT_MAX := 12
const BRICK_DESTRUCTION_DUST_COUNT := 6


func spawn_install_particles(particles: Array[Dictionary], wall_rect: Rect2) -> void:
	var center := wall_rect.position + wall_rect.size * 0.5
	for _i in range(8):
		particles.append(ActiveItemBrickWallParticlePayloadFactory.build_install_dust(center, wall_rect.size))
	enforce_cap(particles)


func spawn_install_complete_particles(particles: Array[Dictionary], wall_rect: Rect2) -> void:
	for _i in range(10):
		particles.append(ActiveItemBrickWallParticlePayloadFactory.build_install_complete_dust(wall_rect))
	enforce_cap(particles)


func spawn_hit_dust(particles: Array[Dictionary], impact_pos: Vector2, amount: int) -> void:
	for _i in range(amount):
		particles.append(ActiveItemBrickWallParticlePayloadFactory.build_hit_dust(impact_pos))
	enforce_cap(particles)


func spawn_destruction_effect(particles: Array[Dictionary], wall_rect: Rect2, impact_pos: Vector2) -> void:
	for _i in range(randi_range(BRICK_DESTRUCTION_FRAGMENT_MIN, BRICK_DESTRUCTION_FRAGMENT_MAX)):
		particles.append(ActiveItemBrickWallParticlePayloadFactory.build_brick_fragment(wall_rect, impact_pos))
	spawn_hit_dust(particles, impact_pos, BRICK_DESTRUCTION_DUST_COUNT)
	enforce_cap(particles)


func update_particles(particles: Array[Dictionary], delta: float) -> void:
	if particles.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var write_index := 0
	for read_index in range(particles.size()):
		var particle: Dictionary = particles[read_index]
		var life: float = float(particle.get("life", 0.0)) - fps_scale
		if life <= 0.0:
			continue
		var position: Vector2 = _get_vector2(particle, "position", Vector2.ZERO)
		var velocity: Vector2 = _get_vector2(particle, "velocity", Vector2.ZERO)
		position += velocity * fps_scale
		velocity.y += 0.08 * fps_scale
		velocity *= pow(0.965, fps_scale)
		particle["life"] = life
		particle["position"] = position
		particle["velocity"] = velocity
		if str(particle.get("kind", "")) == "brick":
			particle["rotation"] = float(particle.get("rotation", 0.0)) + float(particle.get("rotation_speed", 0.0)) * fps_scale
		particles[write_index] = particle
		write_index += 1
	if write_index < particles.size():
		particles.resize(write_index)


func enforce_cap(particles: Array[Dictionary]) -> void:
	while particles.size() > BRICK_WALL_PARTICLE_CAP:
		particles.pop_front()


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
