extends RefCounted

const BRICK_WALL_PARTICLE_CAP := 64
const BRICK_DESTRUCTION_FRAGMENT_MIN := 8
const BRICK_DESTRUCTION_FRAGMENT_MAX := 12
const BRICK_DESTRUCTION_DUST_COUNT := 6
const BRICK_FRAGMENT_COLORS := [
	Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0, 1.0),
	Color(160.0 / 255.0, 82.0 / 255.0, 45.0 / 255.0, 1.0),
	Color(100.0 / 255.0, 50.0 / 255.0, 25.0 / 255.0, 1.0),
	Color(180.0 / 255.0, 110.0 / 255.0, 65.0 / 255.0, 1.0),
]


func spawn_install_particles(particles: Array[Dictionary], wall_rect: Rect2) -> void:
	var center := wall_rect.position + wall_rect.size * 0.5
	for _i in range(8):
		particles.append({
			"kind": "dust",
			"position": center + Vector2(randf_range(-wall_rect.size.x * 0.45, wall_rect.size.x * 0.45), randf_range(-3.0, 4.0)),
			"velocity": Vector2(randf_range(-0.55, 0.55), randf_range(-0.85, -0.15)),
			"life": randf_range(16.0, 30.0),
			"initial_life": 30.0,
			"radius": randf_range(2.0, 4.0),
			"color": Color(120.0 / 255.0, 90.0 / 255.0, 64.0 / 255.0, 1.0),
		})
	enforce_cap(particles)


func spawn_install_complete_particles(particles: Array[Dictionary], wall_rect: Rect2) -> void:
	for _i in range(10):
		var top_pos := Vector2(
			randf_range(wall_rect.position.x, wall_rect.position.x + wall_rect.size.x),
			wall_rect.position.y + randf_range(-2.0, 4.0)
		)
		particles.append({
			"kind": "dust",
			"position": top_pos,
			"velocity": Vector2(randf_range(-0.7, 0.7), randf_range(-1.2, -0.25)),
			"life": randf_range(18.0, 34.0),
			"initial_life": 34.0,
			"radius": randf_range(2.0, 4.8),
			"color": Color(155.0 / 255.0, 110.0 / 255.0, 76.0 / 255.0, 1.0),
		})
	enforce_cap(particles)


func spawn_hit_dust(particles: Array[Dictionary], impact_pos: Vector2, amount: int) -> void:
	for _i in range(amount):
		particles.append({
			"kind": "dust",
			"position": impact_pos + Vector2(randf_range(-10.0, 10.0), randf_range(-3.0, 5.0)),
			"velocity": Vector2(randf_range(-1.1, 1.1), randf_range(-1.8, -0.25)),
			"life": randf_range(18.0, 38.0),
			"initial_life": 38.0,
			"radius": randf_range(2.0, 5.2),
			"color": Color(145.0 / 255.0, 100.0 / 255.0, 70.0 / 255.0, 1.0),
		})
	enforce_cap(particles)


func spawn_destruction_effect(particles: Array[Dictionary], wall_rect: Rect2, impact_pos: Vector2) -> void:
	for _i in range(randi_range(BRICK_DESTRUCTION_FRAGMENT_MIN, BRICK_DESTRUCTION_FRAGMENT_MAX)):
		var start_pos := Vector2(
			randf_range(wall_rect.position.x, wall_rect.position.x + wall_rect.size.x),
			randf_range(wall_rect.position.y, wall_rect.position.y + wall_rect.size.y)
		)
		var burst_dir: Vector2 = start_pos - impact_pos
		if burst_dir.length() < 1.0:
			burst_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 0.2))
		burst_dir = burst_dir.normalized()
		particles.append({
			"kind": "brick",
			"position": start_pos,
			"velocity": burst_dir * randf_range(1.3, 3.4) + Vector2(randf_range(-0.7, 0.7), randf_range(-2.4, -0.7)),
			"life": randf_range(42.0, 82.0),
			"initial_life": 82.0,
			"size": Vector2(randf_range(4.0, 9.0), randf_range(3.0, 7.0)),
			"rotation": randf_range(0.0, TAU),
			"rotation_speed": randf_range(-0.22, 0.22),
			"color": BRICK_FRAGMENT_COLORS[randi() % BRICK_FRAGMENT_COLORS.size()],
		})
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
