extends RefCounted


static func update_drop(
	rock: Dictionary,
	delta: float,
	target_pos: Vector2,
	land_flash_sec: float,
	default_drop_time_sec: float
) -> Dictionary:
	if rock.has("fall_y") or rock.has("spawn_delay_frames"):
		return update_original_drop(rock, delta, target_pos, land_flash_sec)
	return update_timed_drop(rock, delta, target_pos, land_flash_sec, default_drop_time_sec)


static func update_original_drop(rock: Dictionary, delta: float, target_pos: Vector2, land_flash_sec: float) -> Dictionary:
	var landed: bool = false
	var frame_step_total: float = max(0.0, delta) * 60.0
	var whole_steps: int = int(min(floor(frame_step_total), 240.0))
	var remainder: float = frame_step_total - float(whole_steps)
	for _step in range(whole_steps):
		var step_result: Dictionary = step_original_drop(rock, target_pos, 1.0, land_flash_sec)
		landed = landed or bool(step_result.get("landed", false))
		if not bool(step_result.get("continue", false)):
			break
	if remainder > 0.001:
		var remainder_result: Dictionary = step_original_drop(rock, target_pos, remainder, land_flash_sec)
		landed = landed or bool(remainder_result.get("landed", false))
	return {
		"landed": landed,
		"land_position": target_pos,
	}


static func update_timed_drop(
	rock: Dictionary,
	delta: float,
	target_pos: Vector2,
	land_flash_sec: float,
	default_drop_time_sec: float
) -> Dictionary:
	var drop_delay: float = max(0.0, float(rock.get("drop_delay", 0.0)) - delta)
	rock["drop_delay"] = drop_delay
	if drop_delay > 0.0 or not bool(rock.get("falling", false)):
		return {"landed": false, "land_position": target_pos}
	var fall_total: float = max(0.001, float(rock.get("fall_total", default_drop_time_sec)))
	var fall_timer: float = max(0.0, float(rock.get("fall_timer", fall_total)) - delta)
	var progress: float = clampf(1.0 - fall_timer / fall_total, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - progress, 3.0)
	var start_pos: Vector2 = _get_vector2(rock.get("start_pos", rock.get("pos", Vector2.ZERO)), Vector2.ZERO)
	rock["pos"] = start_pos.lerp(target_pos, eased)
	rock["fall_timer"] = fall_timer
	rock["fall_progress"] = progress
	if fall_timer > 0.0:
		return {"landed": false, "land_position": target_pos}
	rock["falling"] = false
	rock["pos"] = target_pos
	rock["flash"] = max(float(rock.get("flash", 0.0)), land_flash_sec)
	return {"landed": true, "land_position": target_pos}


static func step_original_drop(rock: Dictionary, target_pos: Vector2, frame_step: float, land_flash_sec: float) -> Dictionary:
	var spawn_delay: float = float(rock.get("spawn_delay_frames", 0.0))
	var delay_timer: float = float(rock.get("delay_timer_frames", 0.0))
	if delay_timer < spawn_delay:
		rock["delay_timer_frames"] = min(spawn_delay, delay_timer + frame_step)
		rock["pos"] = Vector2(target_pos.x, float(rock.get("fall_y", target_pos.y)))
		return {"continue": true, "landed": false}
	if not bool(rock.get("falling", false)):
		rock["pos"] = target_pos
		return {"continue": false, "landed": false}

	var gravity: float = float(rock.get("gravity", 0.8))
	var fall_speed: float = float(rock.get("fall_speed", 0.0)) + gravity * frame_step
	var fall_y: float = float(rock.get("fall_y", target_pos.y)) + fall_speed * frame_step
	var start_y := -300.0
	var height_denominator: float = max(1.0, target_pos.y - start_y)
	var height_ratio: float = clampf((fall_y - start_y) / height_denominator, 0.0, 1.0)
	rock["shadow_scale"] = 0.2 + 0.8 * height_ratio
	var landed: bool = false
	if fall_y >= target_pos.y:
		fall_y = target_pos.y
		var bounce_count: int = int(rock.get("bounce_count", 0)) + 1
		rock["bounce_count"] = bounce_count
		if bounce_count <= int(rock.get("max_bounces", 1)):
			fall_speed = -fall_speed * 0.6
		else:
			rock["falling"] = false
			fall_speed = 0.0
			rock["shadow_scale"] = 1.0
			rock["flash"] = max(float(rock.get("flash", 0.0)), land_flash_sec)
			landed = true

	rock["fall_y"] = fall_y
	rock["fall_speed"] = fall_speed
	rock["fall_progress"] = height_ratio
	rock["pos"] = Vector2(target_pos.x, fall_y)
	return {"continue": true, "landed": landed}


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
