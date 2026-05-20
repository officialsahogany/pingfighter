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
