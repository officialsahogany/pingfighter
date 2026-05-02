extends RefCounted


func apply(
	skill_flow: Object,
	frame_state: Object,
	speed: float,
	angle_rad: float,
	hit_pos: float,
	accel_scale: float,
	ball_pos: Vector2,
	frame: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	callbacks: Dictionary
) -> Dictionary:
	if skill_flow == null:
		return _build_result(false, false, speed, angle_rad)

	var skill_result: Dictionary = skill_flow.resolve_player_skills(
		speed,
		angle_rad,
		hit_pos,
		accel_scale,
		ball_pos,
		float(frame["ball_spin_strength"]),
		int(frame["ball_spin_direction"]),
		float(frame["drive_speed_increase"]),
		bool(frame["drive_ball_active"]),
		bool(frame["drive_hit_boss"]),
		float(frame["special_gauge"]),
		float(frame["drive_text_timer_frames"]),
		context,
		deps,
		callbacks
	)
	if frame_state != null:
		frame_state.apply_skill_result(frame, skill_result)

	return _build_result(
		bool(skill_result.get("power_activated", false)),
		bool(skill_result.get("drive_activated", false)),
		float(skill_result.get("speed", speed)),
		float(skill_result.get("angle_rad", angle_rad))
	)


func _build_result(power_activated: bool, drive_activated: bool, speed: float, angle_rad: float) -> Dictionary:
	return {
		"power_activated": power_activated,
		"drive_activated": drive_activated,
		"speed": speed,
		"angle_rad": angle_rad,
	}
