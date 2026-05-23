extends RefCounted

const WALL_X_MIN := 70.0
const WALL_X_MAX := 690.0
const TARGET_PICK_ATTEMPTS := 36
const MIN_GAP := 8.0


func build_crisis_rock(
	rock_id: int,
	spawn_index: int,
	_crisis_rock_count: int,
	rng: RandomNumberGenerator,
	rock_visual_factory: Object,
	y_min: float,
	y_mid: float,
	y_max: float,
	drop_height: float,
	size_scale: float,
	drop_stagger_sec: float,
	drop_time_sec: float,
	rock_life_sec: float,
	reserved_rocks: Array = []
) -> Dictionary:
	var collision_radius := rng.randf_range(25.0, 37.0) * size_scale
	var target_y := rng.randf_range(y_min, y_mid)
	if spawn_index % 2 == 1:
		target_y = rng.randf_range(y_mid, y_max)
	var target := _pick_target(target_y, collision_radius, reserved_rocks, rng)
	var start := target + Vector2(rng.randf_range(-12.0, 12.0), -drop_height - float(spawn_index) * 7.0)
	var seed_value := rng.randi()
	var rock_visual: Dictionary = {}
	if rock_visual_factory != null and rock_visual_factory.has_method("build_visual_data"):
		rock_visual = rock_visual_factory.build_visual_data(collision_radius * 2.0, false, seed_value, rng)
	var rock := {
		"id": rock_id,
		"pos": start,
		"start_pos": start,
		"target_pos": target,
		"quake_offset": Vector2.ZERO,
		"falling": true,
		"drop_delay": float(spawn_index) * drop_stagger_sec,
		"fall_timer": drop_time_sec,
		"fall_total": drop_time_sec,
		"fall_progress": 0.0,
		"radius": collision_radius,
		"visual_radius": collision_radius * 2.0,
		"hp": 1,
		"life": rock_life_sec,
		"flash": 0.0,
		"water_target_flash": 0.0,
		"phase": rng.randf_range(0.0, TAU),
		"seed": seed_value,
		"crisis_wall": true,
	}
	rock.merge(rock_visual, true)
	return rock


func _pick_target(target_y: float, radius: float, reserved_rocks: Array, rng: RandomNumberGenerator) -> Vector2:
	var min_x: float = WALL_X_MIN + radius
	var max_x: float = WALL_X_MAX - radius
	var best_target := Vector2(rng.randf_range(min_x, max_x), target_y)
	var best_clearance: float = _get_clearance(best_target, radius, reserved_rocks)
	for _attempt in range(TARGET_PICK_ATTEMPTS):
		var candidate := Vector2(rng.randf_range(min_x, max_x), target_y)
		var clearance: float = _get_clearance(candidate, radius, reserved_rocks)
		if clearance >= MIN_GAP:
			return candidate
		if clearance > best_clearance:
			best_clearance = clearance
			best_target = candidate
	return best_target


func _get_clearance(target: Vector2, radius: float, reserved_rocks: Array) -> float:
	var clearance := INF
	for rock_value in reserved_rocks:
		if not rock_value is Dictionary:
			continue
		var rock: Dictionary = rock_value
		var existing_target: Vector2 = _get_vector2(rock.get("target_pos", rock.get("pos", Vector2.ZERO)), Vector2.ZERO)
		var existing_radius: float = max(0.0, float(rock.get("radius", float(rock.get("visual_radius", 0.0)) * 0.5)))
		clearance = min(clearance, target.distance_to(existing_target) - radius - existing_radius)
	return clearance


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
