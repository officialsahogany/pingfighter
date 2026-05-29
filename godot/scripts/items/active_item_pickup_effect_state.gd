extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PICKUP_EFFECT_DURATION_SEC := 2.0
const PICKUP_FADE_DURATION_SEC := 1.0
const PICKUP_TARGET := Vector2(100.0, FIELD_HEIGHT * 0.5)
const BALLOON_POP_PARTICLE_COUNT := 14
const MAX_PICKUP_PARTICLES := 28


func trigger_pickup_effect(field_item: Dictionary, display_name: String, item_color: Color, particles: Array[Dictionary]) -> Dictionary:
	var item_data: Dictionary = _get_dictionary(field_item, "item_data").duplicate(true)
	var start_pos: Vector2 = _get_vector2(field_item, "position", Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5))
	_spawn_balloon_pop_particles(particles, start_pos, item_color)
	var pickup_effect: Dictionary = {
		"item_data": item_data,
		"display_name": display_name,
		"timer": PICKUP_EFFECT_DURATION_SEC,
		"alpha": 180.0 / 255.0,
		"position": start_pos,
		"start_position": start_pos,
	}
	var use_hint_text: String = str(field_item.get("pickup_use_hint_text", "")).strip_edges()
	if use_hint_text != "":
		pickup_effect["use_hint_text"] = use_hint_text
	return pickup_effect


func has_pickup_effect(pickup_effect: Dictionary) -> bool:
	return not pickup_effect.is_empty()


func update_pickup_particles(particles: Array[Dictionary], delta: float) -> void:
	if particles.is_empty():
		return
	var write_index := 0
	for read_index in range(particles.size()):
		var particle: Dictionary = particles[read_index]
		var age: float = float(particle.get("age", 0.0)) + delta
		var lifetime: float = max(0.01, float(particle.get("lifetime", 0.45)))
		if age >= lifetime:
			continue
		particle["age"] = age
		particle["position"] = _get_vector2(particle, "position", Vector2.ZERO) + _get_vector2(particle, "velocity", Vector2.ZERO) * delta
		particle["velocity"] = _get_vector2(particle, "velocity", Vector2.ZERO) * 0.94
		particles[write_index] = particle
		write_index += 1
	if write_index < particles.size():
		particles.resize(write_index)


func update_pickup_effect(pickup_effect: Dictionary, delta: float) -> void:
	if pickup_effect.is_empty():
		return
	var timer: float = float(pickup_effect.get("timer", 0.0)) - delta
	if timer <= 0.0:
		pickup_effect.clear()
		return
	pickup_effect["timer"] = timer
	var progress: float = 1.0 - (timer / PICKUP_EFFECT_DURATION_SEC)
	var ease_progress: float = 1.0 - pow(1.0 - clamp(progress, 0.0, 1.0), 2.0)
	var start_pos: Vector2 = _get_vector2(pickup_effect, "start_position", Vector2.ZERO)
	pickup_effect["position"] = start_pos.lerp(PICKUP_TARGET, ease_progress)
	if timer < PICKUP_FADE_DURATION_SEC:
		pickup_effect["alpha"] = clamp(timer / PICKUP_FADE_DURATION_SEC, 0.0, 1.0)
	else:
		pickup_effect["alpha"] = 180.0 / 255.0


func _spawn_balloon_pop_particles(particles: Array[Dictionary], center: Vector2, item_color: Color) -> void:
	var keep_count: int = max(0, MAX_PICKUP_PARTICLES - BALLOON_POP_PARTICLE_COUNT)
	while particles.size() > keep_count:
		particles.remove_at(0)
	for _i in range(BALLOON_POP_PARTICLE_COUNT):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(90.0, 250.0)
		var color := item_color.lerp(Color.WHITE, randf_range(0.15, 0.55))
		particles.append({
			"position": center,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"radius": randf_range(2.0, 4.5),
			"age": 0.0,
			"lifetime": randf_range(0.28, 0.62),
			"color": color,
		})


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
