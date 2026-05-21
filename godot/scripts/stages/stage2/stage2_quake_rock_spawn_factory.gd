extends RefCounted


func build_spawn_batch(
	existing_rocks: Array,
	requested_count: int,
	max_rocks: int,
	starting_rock_id: int,
	rng: RandomNumberGenerator,
	rock_visual_factory: Object,
	quake_rock_payload_factory: Object,
	size_scale: float,
	rock_life_sec: float
) -> Dictionary:
	var spawned_rocks: Array = []
	var targets: Array[Vector2] = []
	var next_id := starting_rock_id
	for index in range(clampi(requested_count, 1, max_rocks)):
		var target: Vector2 = _pick_target(existing_rocks, spawned_rocks, rng)
		var size := float(rng.randi_range(25, 90)) * size_scale
		var fall_y := -100.0 - float(rng.randi_range(0, 200))
		var seed_value := rng.randi()
		var is_golden := rng.randf() < 0.20
		var rock_visual: Dictionary = {}
		if rock_visual_factory != null and rock_visual_factory.has_method("build_visual_data"):
			rock_visual = rock_visual_factory.build_visual_data(size, is_golden, seed_value, rng)
		var rock: Dictionary = quake_rock_payload_factory.build_quake_rock(
			next_id,
			index,
			target,
			fall_y,
			size,
			0.8 + rng.randf_range(-0.2, 0.2),
			rng.randi_range(1, 2),
			seed_value,
			is_golden,
			rock_life_sec,
			rock_visual
		)
		spawned_rocks.append(rock)
		targets.append(target)
		next_id += 1
	return {
		"rocks": spawned_rocks,
		"targets": targets,
		"next_id": next_id,
	}


func _pick_target(existing_rocks: Array, spawned_rocks: Array, rng: RandomNumberGenerator) -> Vector2:
	var map_x_min := 50
	var map_x_max := 550
	var map_y_min := 50
	var map_y_max := 700
	var target := Vector2(
		float(rng.randi_range(map_x_min, map_x_max)),
		float(rng.randi_range(map_y_min, map_y_max))
	)
	var attempts := 0
	while attempts < 10 and _is_target_too_close(existing_rocks, spawned_rocks, target):
		target = Vector2(
			float(rng.randi_range(map_x_min, map_x_max)),
			float(rng.randi_range(map_y_min, map_y_max))
		)
		attempts += 1
	return target


func _is_target_too_close(existing_rocks: Array, spawned_rocks: Array, target: Vector2) -> bool:
	return _is_target_too_close_to_rocks(existing_rocks, target) or _is_target_too_close_to_rocks(spawned_rocks, target)


func _is_target_too_close_to_rocks(rock_values: Array, target: Vector2) -> bool:
	for rock_value in rock_values:
		if not rock_value is Dictionary:
			continue
		var rock: Dictionary = rock_value
		var rock_target: Vector2 = _get_vector2(rock.get("target_pos", rock.get("pos", Vector2.ZERO)), Vector2.ZERO)
		if abs(rock_target.x - target.x) < 70.0 and abs(rock_target.y - target.y) < 70.0:
			return true
	return false


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
