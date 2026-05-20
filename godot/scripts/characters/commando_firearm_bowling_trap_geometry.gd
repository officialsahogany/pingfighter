extends RefCounted

const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func get_install_pos(
	config: Dictionary,
	field_width: float,
	field_height: float,
	trap_width: float,
	trap_height: float,
	min_field_y_ratio: float
) -> Vector2:
	var fallback_player_pos := Vector2(field_width * 0.5, field_height - 70.0)
	var player_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(config.get("player_pos", fallback_player_pos), fallback_player_pos)
	var paddle_width: float = max(1.0, float(config.get("paddle_width", 155.0)))
	var paddle_height: float = max(1.0, float(config.get("paddle_height", 50.0)))
	var trap_y: float = player_pos.y + paddle_height + 5.0
	var min_y: float = field_height * min_field_y_ratio
	return Vector2(
		clamp(player_pos.x + paddle_width * 0.5, trap_width * 0.5, field_width - trap_width * 0.5),
		clamp(max(trap_y, min_y), min_y, field_height - trap_height * 0.5)
	)


static func is_install_in_player_field(
	config: Dictionary,
	field_width: float,
	field_height: float,
	min_field_y_ratio: float
) -> bool:
	var fallback_player_pos := Vector2(field_width * 0.5, field_height - 70.0)
	var player_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(config.get("player_pos", fallback_player_pos), fallback_player_pos)
	var paddle_height: float = max(1.0, float(config.get("paddle_height", 50.0)))
	var trap_y: float = player_pos.y + paddle_height + 5.0
	return trap_y >= field_height * min_field_y_ratio


static func build_install_trap(
	trap_pos: Vector2,
	profile: Dictionary,
	weapon_id: String,
	trap_id: int,
	trap_width: float,
	trap_height: float,
	install_frames: float,
	capture_ball_offset: Vector2
) -> Dictionary:
	return {
		"id": trap_id,
		"weapon_id": weapon_id,
		"kind": "bowling_trap",
		"state": "installing",
		"pos": trap_pos,
		"width": trap_width,
		"height": trap_height,
		"timer_frames": install_frames,
		"max_timer_frames": install_frames,
		"install_progress": 0.0,
		"capture_progress": 0.0,
		"claw_angle": 1.0,
		"captured_ball_pos": trap_pos + capture_ball_offset,
		"captured_original_speed": 0.0,
		"captured_original_vel": Vector2.ZERO,
		"launch_direction": 0,
		"color": profile.get("color", Color(0.95, 0.18, 0.24)),
		"secondary": profile.get("secondary", Color(0.22, 0.10, 0.12)),
	}


static func build_install_marker_flash(trap_pos: Vector2, profile: Dictionary, weapon_id: String) -> Dictionary:
	return {
		"weapon_id": weapon_id,
		"kind": "trap_install_marker",
		"pos": trap_pos,
		"radius": 24.0,
		"timer_frames": 14.0,
		"max_timer_frames": 14.0,
		"color": profile.get("secondary", Color(0.22, 0.10, 0.12)),
		"secondary": profile.get("color", Color(0.95, 0.18, 0.24)),
	}


static func update_install_state(trap: Dictionary, fps_scale: float, install_frames: float) -> Dictionary:
	var next_trap: Dictionary = trap.duplicate(true)
	var timer: float = max(0.0, float(next_trap.get("timer_frames", install_frames)) - fps_scale)
	next_trap["timer_frames"] = timer
	next_trap["max_timer_frames"] = install_frames
	next_trap["install_progress"] = 1.0 - timer / install_frames
	if timer <= 0.0:
		next_trap["state"] = "waiting"
		next_trap["timer_frames"] = 0.0
		next_trap["max_timer_frames"] = 1.0
		next_trap["install_progress"] = 1.0
		next_trap["claw_angle"] = 0.0
	return next_trap


static func has_installing_trap(traps: Array) -> bool:
	for value in traps:
		var trap: Dictionary = CommandoFirearmValueUtils.get_dict(value)
		if str(trap.get("state", "")) == "installing":
			return true
	return false


static func get_install_progress(traps: Array) -> float:
	for value in traps:
		var trap: Dictionary = CommandoFirearmValueUtils.get_dict(value)
		if str(trap.get("state", "")) == "installing":
			return clamp(float(trap.get("install_progress", 0.0)), 0.0, 1.0)
	return 0.0


static func build_round_carryover(traps: Array, capture_ball_offset: Vector2) -> Array:
	var carried: Array = []
	for value in traps:
		var trap: Dictionary = CommandoFirearmValueUtils.get_dict(value)
		var state: String = str(trap.get("state", "waiting"))
		if state == "inactive" or state == "launching":
			continue
		var normalized: Dictionary = trap.duplicate(true)
		normalized["state"] = "waiting"
		normalized["timer_frames"] = 0.0
		normalized["max_timer_frames"] = 1.0
		normalized["install_progress"] = 1.0
		normalized["capture_progress"] = 0.0
		normalized["claw_angle"] = 0.0
		normalized["captured_original_speed"] = 0.0
		normalized["captured_original_vel"] = Vector2.ZERO
		var trap_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(normalized.get("pos", Vector2.ZERO), Vector2.ZERO)
		normalized["captured_ball_pos"] = trap_pos + capture_ball_offset
		carried.append(normalized)
	return carried


static func build_capture_state(
	trap: Dictionary,
	context: Dictionary,
	capture_frames: float,
	capture_ball_offset: Vector2
) -> Dictionary:
	var next_trap: Dictionary = trap.duplicate(true)
	var ball_vel: Vector2 = CommandoFirearmValueUtils.get_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var trap_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(next_trap.get("pos", Vector2.ZERO), Vector2.ZERO)
	var original_speed: float = max(1.0, ball_vel.length())
	next_trap["state"] = "capturing"
	next_trap["timer_frames"] = capture_frames
	next_trap["max_timer_frames"] = capture_frames
	next_trap["capture_progress"] = 0.0
	next_trap["claw_angle"] = 1.0
	next_trap["captured_ball_pos"] = trap_pos + capture_ball_offset
	next_trap["captured_original_speed"] = original_speed
	next_trap["captured_original_vel"] = ball_vel
	next_trap["launch_direction"] = get_launch_direction(int(next_trap.get("id", 0)))
	return next_trap


static func update_capture_state(trap: Dictionary, fps_scale: float, capture_frames: float) -> Dictionary:
	var next_trap: Dictionary = trap.duplicate(true)
	var timer: float = max(0.0, float(next_trap.get("timer_frames", capture_frames)) - fps_scale)
	var progress: float = 1.0 - timer / capture_frames
	next_trap["timer_frames"] = timer
	next_trap["max_timer_frames"] = capture_frames
	next_trap["capture_progress"] = progress
	if progress < 0.2:
		next_trap["claw_angle"] = 1.0 - progress / 0.2
	elif progress < 0.5:
		next_trap["claw_angle"] = 0.0
	else:
		next_trap["claw_angle"] = -0.3 * ((progress - 0.5) / 0.5)
	return next_trap


static func is_capture_complete(trap: Dictionary) -> bool:
	return float(trap.get("timer_frames", 0.0)) <= 0.0


static func build_capture_result(trap: Dictionary) -> Dictionary:
	var captured_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(
		trap.get("captured_ball_pos", Vector2.ZERO),
		Vector2.ZERO
	)
	return {
		"ball_pos": captured_pos,
		"ball_vel": Vector2.ZERO,
		"skip_ball_motion_step": true,
		"commando_bowling_trap_captured": true,
		"commando_bowling_trap_capture_progress": float(trap.get("capture_progress", 0.0)),
	}


static func build_release_motion(
	trap: Dictionary,
	capture_ball_offset: Vector2,
	launch_speed_multiplier: float,
	launch_angle_step: float
) -> Dictionary:
	var trap_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(trap.get("pos", Vector2.ZERO), Vector2.ZERO)
	var captured_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(
		trap.get("captured_ball_pos", trap_pos + capture_ball_offset),
		trap_pos + capture_ball_offset
	)
	var original_speed: float = max(1.0, float(trap.get("captured_original_speed", 0.0)))
	var launch_speed: float = original_speed * launch_speed_multiplier
	var launch_direction: int = int(trap.get("launch_direction", 0))
	var launch_angle: float = -PI * 0.5 + float(launch_direction) * launch_angle_step
	var launch_vel: Vector2 = Vector2(cos(launch_angle), sin(launch_angle)) * launch_speed
	return {
		"trap_pos": trap_pos,
		"captured_pos": captured_pos,
		"original_speed": original_speed,
		"launch_speed": launch_speed,
		"launch_direction": launch_direction,
		"launch_angle": launch_angle,
		"launch_vel": launch_vel,
	}


static func build_release_pseudo_projectile(trap: Dictionary, motion: Dictionary, profile: Dictionary) -> Dictionary:
	return {
		"id": int(trap.get("id", 0)),
		"weapon_id": "bowling_trap",
		"kind": "trap",
		"pos": CommandoFirearmValueUtils.get_vector2(motion.get("trap_pos", Vector2.ZERO), Vector2.ZERO),
		"velocity": CommandoFirearmValueUtils.get_vector2(motion.get("launch_vel", Vector2.ZERO), Vector2.ZERO),
		"impact_radius": float(profile.get("impact_radius", 30.0)) * 1.5,
		"color": profile.get("color", Color(0.95, 0.18, 0.24)),
		"secondary": profile.get("secondary", Color(0.22, 0.10, 0.12)),
	}


static func build_release_result(
	motion: Dictionary,
	guard_source: String,
	guard_knockback_power: float,
	guard_stun_frames: float,
	guard_speed_reduction: float
) -> Dictionary:
	var captured_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(
		motion.get("captured_pos", Vector2.ZERO),
		Vector2.ZERO
	)
	var launch_vel: Vector2 = CommandoFirearmValueUtils.get_vector2(
		motion.get("launch_vel", Vector2.ZERO),
		Vector2.ZERO
	)
	var original_speed: float = max(1.0, float(motion.get("original_speed", 0.0)))
	return {
		"ball_pos": captured_pos,
		"ball_vel": launch_vel,
		"skip_ball_motion_step": false,
		"commando_bowling_trap_released": true,
		"commando_bowling_trap_guard_armed": true,
		"commando_bowling_trap_guard_source": guard_source,
		"commando_bowling_trap_launch_speed": float(motion.get("launch_speed", 0.0)),
		"commando_bowling_trap_guard_knockback_power": guard_knockback_power,
		"commando_bowling_trap_guard_stun_frames": guard_stun_frames,
		"commando_bowling_trap_guard_restore_speed": original_speed * guard_speed_reduction,
	}


static func build_guard_state(trap: Dictionary, original_speed: float, guard_speed_reduction: float) -> Dictionary:
	var safe_original_speed: float = max(1.0, original_speed)
	return {
		"armed": true,
		"original_speed": safe_original_speed,
		"restore_speed": safe_original_speed * guard_speed_reduction,
		"source": "commando_bowling_trap_guard_%d" % int(trap.get("id", 0)),
	}


static func build_cleared_guard_state() -> Dictionary:
	return {
		"armed": false,
		"original_speed": 0.0,
		"restore_speed": 0.0,
		"source": "",
	}


static func soften_guard_ball(ball_vel: Vector2, restore_speed: float) -> Vector2:
	var speed: float = max(1.0, restore_speed)
	if ball_vel.length() <= 0.001:
		return Vector2(0.0, speed)
	return ball_vel.normalized() * speed


static func get_guard_knockback_velocity(
	boss_center: Vector2,
	context: Dictionary,
	field_width: float,
	knockback_power: float
) -> float:
	var field_center_x: float = float(context.get("width", field_width)) * 0.5
	var direction: float = 1.0 if boss_center.x < field_center_x else -1.0
	if is_equal_approx(boss_center.x, field_center_x):
		direction = sign(float(context.get("boss_vel", 0.0)))
		if is_zero_approx(direction):
			direction = 1.0
	return direction * knockback_power


static func get_launch_direction(shot_id: int) -> int:
	var roll: int = shot_id % 5
	if roll == 0:
		return -1
	if roll == 4:
		return 1
	return 0


static func hits_ball(
	trap: Dictionary,
	context: Dictionary,
	trap_height: float,
	capture_height: float,
	default_trap_width: float
) -> bool:
	var ball_vel: Vector2 = CommandoFirearmValueUtils.get_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	if ball_vel.y <= 0.0:
		return false
	var ball_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_size: float = max(1.0, float(context.get("ball_size", 28.6)))
	var trap_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(trap.get("pos", Vector2.ZERO), Vector2.ZERO)
	var trap_width: float = max(1.0, float(trap.get("width", default_trap_width)))
	var trap_rect := Rect2(
		trap_pos - Vector2(trap_width * 0.5, trap_height * 0.5),
		Vector2(trap_width, capture_height)
	)
	var ball_rect := Rect2(
		ball_pos - Vector2(ball_size, ball_size) * 0.5,
		Vector2(ball_size, ball_size)
	)
	return trap_rect.intersects(ball_rect)
