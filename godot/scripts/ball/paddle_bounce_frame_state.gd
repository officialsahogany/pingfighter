extends RefCounted


func build(
	context: Dictionary,
	physics: Object,
	ball_vel: Vector2,
	pre_hit_speed: float,
	launch_angle_rad: float
) -> Dictionary:
	var impact: Dictionary = _compute_dynamic_impact_boost(physics, ball_vel, pre_hit_speed, launch_angle_rad)
	var accel_scale: float = (
		_get_physics_multiplier(physics, "get_rally_speed_increase_multiplier")
		* _get_physics_multiplier(physics, "get_junior_speed_increase_multiplier")
	)
	return {
		"vertical_bounce_count": int(context.get("vertical_bounce_count", 0)),
		"ball_spin_strength": float(context.get("ball_spin_strength", 0.0)),
		"ball_spin_direction": int(context.get("ball_spin_direction", 0)),
		"drive_speed_increase": float(context.get("drive_speed_increase", 0.0)),
		"drive_ball_active": bool(context.get("drive_ball_active", false)),
		"drive_hit_boss": bool(context.get("drive_hit_boss", false)),
		"special_gauge": float(context.get("special_gauge", 0.0)),
		"drive_text_timer_frames": float(context.get("drive_text_timer_frames", 0.0)),
		"accel_scale": accel_scale,
		"ball_impact_boost": float(impact.get("boost", context.get("ball_impact_boost", 1.0))),
		"ball_boost_decay_rate": float(impact.get("decay_rate", context.get("ball_boost_decay_rate", 0.975))),
		"ball_min_boost": float(impact.get("min_boost", context.get("ball_min_boost", 0.70))),
	}


func apply_skill_result(frame: Dictionary, skill_result: Dictionary) -> void:
	frame["ball_spin_strength"] = float(skill_result.get("ball_spin_strength", frame["ball_spin_strength"]))
	frame["ball_spin_direction"] = int(skill_result.get("ball_spin_direction", frame["ball_spin_direction"]))
	frame["drive_speed_increase"] = float(skill_result.get("drive_speed_increase", frame["drive_speed_increase"]))
	frame["drive_ball_active"] = bool(skill_result.get("drive_ball_active", frame["drive_ball_active"]))
	frame["drive_hit_boss"] = bool(skill_result.get("drive_hit_boss", frame["drive_hit_boss"]))
	frame["special_gauge"] = float(skill_result.get("special_gauge", frame["special_gauge"]))
	frame["drive_text_timer_frames"] = float(skill_result.get("drive_text_timer_frames", frame["drive_text_timer_frames"]))


func apply_bounce_result(frame: Dictionary, bounce_result: Dictionary) -> void:
	frame["vertical_bounce_count"] = int(bounce_result.get("vertical_bounce_count", frame["vertical_bounce_count"]))
	frame["drive_speed_increase"] = float(bounce_result.get("drive_speed_increase", frame["drive_speed_increase"]))
	frame["ball_spin_strength"] = float(bounce_result.get("ball_spin_strength", frame["ball_spin_strength"]))


func apply_post_hit_result(frame: Dictionary, post_hit_result: Dictionary) -> void:
	frame["ball_spin_strength"] = float(post_hit_result.get("ball_spin_strength", frame["ball_spin_strength"]))
	frame["drive_speed_increase"] = float(post_hit_result.get("drive_speed_increase", frame["drive_speed_increase"]))
	frame["drive_hit_boss"] = bool(post_hit_result.get("drive_hit_boss", frame["drive_hit_boss"]))
	frame["special_gauge"] = float(post_hit_result.get("special_gauge", frame["special_gauge"]))


func build_result_snapshot(
	frame: Dictionary,
	ball_pos: Vector2,
	ball_vel: Vector2,
	player_speed: float,
	boss_vel: float
) -> Dictionary:
	return {
		"ball_pos": ball_pos,
		"ball_vel": ball_vel,
		"ball_impact_boost": float(frame["ball_impact_boost"]),
		"ball_boost_decay_rate": float(frame["ball_boost_decay_rate"]),
		"ball_min_boost": float(frame["ball_min_boost"]),
		"vertical_bounce_count": int(frame["vertical_bounce_count"]),
		"ball_spin_strength": float(frame["ball_spin_strength"]),
		"ball_spin_direction": int(frame["ball_spin_direction"]),
		"drive_speed_increase": float(frame["drive_speed_increase"]),
		"drive_ball_active": bool(frame["drive_ball_active"]),
		"drive_hit_boss": bool(frame["drive_hit_boss"]),
		"special_gauge": float(frame["special_gauge"]),
		"drive_text_timer_frames": float(frame["drive_text_timer_frames"]),
		"player_speed": player_speed,
		"boss_vel": boss_vel,
	}


func _compute_dynamic_impact_boost(
	ball_physics: Object,
	ball_vel: Vector2,
	current_speed: float,
	launch_angle_rad: float
) -> Dictionary:
	if ball_physics != null and ball_physics.has_method("compute_dynamic_impact_boost"):
		var impact: Variant = ball_physics.compute_dynamic_impact_boost(ball_vel, current_speed, launch_angle_rad)
		if impact is Dictionary:
			return impact
	return {
		"boost": 1.0,
		"decay_rate": 0.975,
		"min_boost": 0.70,
	}


func _get_physics_multiplier(physics: Object, method: String) -> float:
	if physics != null and physics.has_method(method):
		return float(physics.call(method))
	return 1.0
