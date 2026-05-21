extends RefCounted


func get_by_id(rocks: Array, rock_id: int) -> Dictionary:
	var index: int = get_index_by_id(rocks, rock_id)
	if index < 0:
		return {}
	return rocks[index]


func get_index_by_id(rocks: Array, rock_id: int) -> int:
	for idx in range(rocks.size()):
		var rock: Dictionary = rocks[idx]
		if int(rock.get("id", -1)) == rock_id:
			return idx
	return -1


func select_random_id(rocks: Array, rng: RandomNumberGenerator) -> int:
	if rocks.is_empty():
		return -1
	var selected: Dictionary = rocks[rng.randi_range(0, rocks.size() - 1)]
	return int(selected.get("id", -1))


func needs_runtime_update(rock: Dictionary, quake_active: bool) -> bool:
	if bool(rock.get("chaos_absorbing", false)):
		return true
	if bool(rock.get("falling", false)):
		return true
	if float(rock.get("drop_delay", 0.0)) > 0.0:
		return true
	if rock.has("spawn_delay_frames") and float(rock.get("delay_timer_frames", 0.0)) < float(rock.get("spawn_delay_frames", 0.0)):
		return true
	if float(rock.get("flash", 0.0)) > 0.0:
		return true
	if float(rock.get("water_target_flash", 0.0)) > 0.0:
		return true
	if quake_active:
		return true
	var quake_offset: Vector2 = _get_vector2(rock.get("quake_offset", Vector2.ZERO), Vector2.ZERO)
	return quake_offset.length_squared() > 0.03


func set_center(rock: Dictionary, center: Vector2) -> void:
	rock["pos"] = center
	rock["target_pos"] = center
	if rock.has("fall_y"):
		rock["fall_y"] = center.y
	rock["falling"] = false
	rock["drop_delay"] = 0.0
	rock["quake_offset"] = Vector2.ZERO


func is_landed(rock: Dictionary) -> bool:
	if rock.has("spawn_delay_frames") and float(rock.get("delay_timer_frames", 0.0)) < float(rock.get("spawn_delay_frames", 0.0)):
		return false
	return not bool(rock.get("falling", false)) and float(rock.get("drop_delay", 0.0)) <= 0.0


func has_landed_rocks(rocks: Array) -> bool:
	for rock_entry in rocks:
		var rock: Dictionary = rock_entry
		if is_landed(rock):
			return true
	return false


func get_target_pos(rock: Dictionary) -> Vector2:
	var fallback: Vector2 = _get_vector2(rock.get("pos", Vector2.ZERO), Vector2.ZERO)
	return _get_vector2(rock.get("target_pos", fallback), fallback)


func get_center(rock: Dictionary) -> Vector2:
	if rock.has("fall_y"):
		var target_pos: Vector2 = get_target_pos(rock)
		var y: float = float(rock.get("fall_y", target_pos.y)) if bool(rock.get("falling", false)) else target_pos.y
		return Vector2(target_pos.x, y) + _get_vector2(rock.get("quake_offset", Vector2.ZERO), Vector2.ZERO)
	var pos: Vector2 = _get_vector2(rock.get("pos", Vector2.ZERO), Vector2.ZERO)
	return pos + _get_vector2(rock.get("quake_offset", Vector2.ZERO), Vector2.ZERO)


func is_target_too_close(rocks: Array, target: Vector2, min_x: float, min_y: float) -> bool:
	for rock_entry in rocks:
		var rock: Dictionary = rock_entry
		var existing: Vector2 = get_target_pos(rock)
		if abs(target.x - existing.x) < min_x and abs(target.y - existing.y) < min_y:
			return true
	return false


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
