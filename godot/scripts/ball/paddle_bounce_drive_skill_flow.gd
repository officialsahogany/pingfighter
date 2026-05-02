extends RefCounted


func try_activate(
	skill_router: Object,
	state: Dictionary,
	hit_pos: float,
	accel_scale: float,
	ball_pos: Vector2,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	if skill_router == null:
		return {"drive_activated": false}

	var drive_result: Dictionary = skill_router.try_activate_drive(
		float(state["speed"]),
		float(state["angle_rad"]),
		hit_pos,
		accel_scale,
		ball_pos,
		float(state["ball_spin_strength"]),
		int(state["ball_spin_direction"]),
		float(state["drive_speed_increase"]),
		bool(state["drive_ball_active"]),
		bool(state["drive_hit_boss"]),
		float(state["special_gauge"]),
		float(state["drive_text_timer_frames"]),
		context,
		deps
	)
	if not bool(drive_result.get("activated", false)):
		return {"drive_activated": false}

	drive_result["drive_activated"] = true
	drive_result.erase("activated")
	return drive_result
