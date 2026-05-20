extends RefCounted


static func get_delay_frames(
	call_id: int,
	target: Vector2,
	min_frames: float,
	max_frames: float
) -> float:
	var span: int = int(max_frames - min_frames) + 1
	@warning_ignore("shadowed_global_identifier")
	var seed: int = support_call_seed(call_id, target)
	return min_frames + float(seed % max(1, span))


static func get_bomb_count(
	call_id: int,
	target: Vector2,
	min_count: int,
	max_count: int
) -> int:
	var span: int = int(max_count - min_count) + 1
	@warning_ignore("shadowed_global_identifier")
	var seed: int = support_call_seed(call_id + 17, target)
	return min_count + seed % max(1, span)


static func support_call_seed(call_id: int, target: Vector2) -> int:
	var raw: int = (
		call_id * 1103515245
		+ int(round(target.x * 13.0))
		+ int(round(target.y * 31.0))
		+ 12345
	)
	return abs(raw)


static func build_call_payload(
	call_id: int,
	origin: Vector2,
	target: Vector2,
	profile: Dictionary,
	weapon_id: String,
	delay_frames: float,
	bomb_count: int,
	call_lock_frames: float,
	aircraft_drop_arm_frames: float,
	aircraft_y: float,
	aircraft_speed: float
) -> Dictionary:
	return {
		"id": call_id,
		"weapon_id": weapon_id,
		"origin": origin,
		"target": target,
		"state": "calling",
		"call_timer_frames": call_lock_frames,
		"radio_active": true,
		"radio_timer_frames": call_lock_frames,
		"radio_sound_played": true,
		"delay_frames": delay_frames,
		"delay_total_frames": delay_frames,
		"bomb_timer_frames": 0.0,
		"bombs_remaining": bomb_count,
		"bombs_total": bomb_count,
		"bombs_spawned": 0,
		"aircraft_active": false,
		"aircraft_audio_active": false,
		"aircraft_spawn_timer": 0.0,
		"aircraft_drop_arm_frames": aircraft_drop_arm_frames,
		"aircraft_pos": Vector2(-140.0, aircraft_y),
		"aircraft_velocity": Vector2(aircraft_speed, 0.0),
		"color": profile.get("color", Color(1.0, 0.34, 0.16)),
		"secondary": profile.get("secondary", Color(1.0, 0.82, 0.25)),
	}


static func build_marker_flash(
	weapon_id: String,
	target: Vector2,
	profile: Dictionary,
	call_lock_frames: float
) -> Dictionary:
	return {
		"weapon_id": weapon_id,
		"kind": "support_marker",
		"pos": target,
		"radius": float(profile.get("impact_radius", 54.0)) * 0.74,
		"timer_frames": call_lock_frames,
		"max_timer_frames": call_lock_frames,
		"color": profile.get("secondary", Color(1.0, 0.82, 0.25)),
		"secondary": profile.get("color", Color(1.0, 0.34, 0.16)),
	}


static func get_bomb_target(target: Vector2, spawn_index: int, field_width: float, field_height: float) -> Vector2:
	var offsets := [-96.0, -48.0, 0.0, 48.0, 96.0, -24.0, 72.0]
	var offset: float = float(offsets[spawn_index % offsets.size()])
	var target_y_offset: float = float(((spawn_index * 37) % 81) - 40)
	return Vector2(
		clamp(target.x + offset, 54.0, field_width - 54.0),
		clamp(target.y + target_y_offset, 42.0, field_height - 64.0)
	)


static func advance_call(
	call_data: Dictionary,
	step: float,
	aircraft_spawn_pos: Vector2,
	aircraft_velocity: Vector2,
	bomb_interval_frames: float,
	field_width: float,
	aircraft_finish_margin: float
) -> Dictionary:
	var next_call: Dictionary = call_data.duplicate(true)
	var result := {
		"call": next_call,
		"started_aircraft": false,
		"spawn_bomb": false,
		"spawn_index": -1,
		"finished": false,
	}
	var safe_step: float = max(0.0, step)
	var call_timer: float = max(0.0, float(next_call.get("call_timer_frames", 0.0)) - safe_step)
	next_call["call_timer_frames"] = call_timer
	next_call["radio_timer_frames"] = call_timer
	next_call["radio_active"] = call_timer > 0.0
	if call_timer > 0.0:
		next_call["state"] = "calling"
		return result

	var delay: float = max(0.0, float(next_call.get("delay_frames", 0.0)) - safe_step)
	next_call["delay_frames"] = delay
	next_call["radio_timer_frames"] = 0.0
	next_call["radio_active"] = false
	if delay > 0.0:
		next_call["state"] = "inbound"
		return result

	next_call["state"] = "striking"
	if not bool(next_call.get("aircraft_active", false)):
		next_call["aircraft_active"] = true
		next_call["aircraft_pos"] = aircraft_spawn_pos
		next_call["aircraft_velocity"] = aircraft_velocity
		next_call["aircraft_spawn_timer"] = 0.0
		result["started_aircraft"] = true

	var aircraft_pos: Vector2 = _get_vector2(next_call.get("aircraft_pos", aircraft_spawn_pos), aircraft_spawn_pos)
	var current_velocity: Vector2 = _get_vector2(next_call.get("aircraft_velocity", aircraft_velocity), aircraft_velocity)
	aircraft_pos += current_velocity * safe_step
	next_call["aircraft_pos"] = aircraft_pos
	var aircraft_spawn_timer: float = max(0.0, float(next_call.get("aircraft_spawn_timer", 0.0)) + safe_step)
	next_call["aircraft_spawn_timer"] = aircraft_spawn_timer
	var can_drop: bool = aircraft_spawn_timer >= float(next_call.get("aircraft_drop_arm_frames", 0.0))

	var bombs_remaining: int = max(0, int(next_call.get("bombs_remaining", 0)))
	var bomb_timer: float = max(0.0, float(next_call.get("bomb_timer_frames", 0.0)) - safe_step)
	if can_drop and bombs_remaining > 0 and bomb_timer <= 0.0:
		var spawned: int = int(next_call.get("bombs_spawned", 0))
		result["spawn_bomb"] = true
		result["spawn_index"] = spawned
		next_call["bombs_spawned"] = spawned + 1
		next_call["bombs_remaining"] = bombs_remaining - 1
		bomb_timer = bomb_interval_frames
	next_call["bomb_timer_frames"] = bomb_timer

	var aircraft_finished: bool = aircraft_pos.x > field_width + aircraft_finish_margin
	result["finished"] = int(next_call.get("bombs_remaining", 0)) <= 0 and aircraft_finished
	return result


static func has_active_lock(support_calls: Array) -> bool:
	for value in support_calls:
		var call_data: Dictionary = _get_dict(value)
		if bool(call_data.get("radio_active", false)) or float(call_data.get("call_timer_frames", 0.0)) > 0.0:
			return true
	return false


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


static func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
