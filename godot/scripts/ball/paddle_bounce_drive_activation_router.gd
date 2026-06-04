extends RefCounted


func try_activate(
	speed: float,
	angle_rad: float,
	hit_pos: float,
	accel_scale: float,
	ball_pos: Vector2,
	ball_spin_strength: float,
	ball_spin_direction: int,
	drive_speed_increase: float,
	drive_ball_active: bool,
	drive_hit_boss: bool,
	special_gauge: float,
	drive_text_timer_frames: float,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var controller: Object = deps.get("drive_activation_controller", null)
	if controller == null:
		return {"activated": false}
	return controller.try_activate(
		speed,
		angle_rad,
		hit_pos,
		accel_scale,
		int(context.get("gameplay_frame_counter", 0)),
		_build_context(
			ball_pos,
			ball_spin_strength,
			ball_spin_direction,
			drive_speed_increase,
			drive_ball_active,
			drive_hit_boss,
			special_gauge,
			drive_text_timer_frames,
			context
		),
		_build_deps(deps)
	)


func _build_context(
	ball_pos: Vector2,
	ball_spin_strength: float,
	ball_spin_direction: int,
	drive_speed_increase: float,
	drive_ball_active: bool,
	drive_hit_boss: bool,
	special_gauge: float,
	drive_text_timer_frames: float,
	context: Dictionary
) -> Dictionary:
	return {
		"ball_active": bool(context.get("ball_active", false)),
		"ball_pos": ball_pos,
		"ball_spin_strength": ball_spin_strength,
		"ball_spin_direction": ball_spin_direction,
		"drive_speed_increase": drive_speed_increase,
		"drive_ball_active": drive_ball_active,
		"drive_hit_boss": drive_hit_boss,
		"special_gauge": special_gauge,
		"gauge_cost": float(context.get("drive_gauge_cost", 0.0)),
		"drive_text_timer_frames": drive_text_timer_frames,
		"text_duration_frames": float(context.get("drive_text_duration_frames", 0.0)),
		"perfect_cooldown_frames": float(context.get("drive_perfect_cooldown_frames", 0.0)),
		"global_cooldown_frames": float(context.get("drive_global_cooldown_frames", 0.0)),
		"combo_min_count": int(context.get("combo_min_count", 2)),
		"current_msec": int(context.get("current_msec", Time.get_ticks_msec())),
	}


func _build_deps(deps: Dictionary) -> Dictionary:
	return {
		"round_state": deps.get("round_state", null),
		"drive_input_state": deps.get("drive_input_state", null),
		"drive_bounce_state": deps.get("drive_bounce_state", null),
		"combo_state": deps.get("combo_state", null),
		"skill_state": deps.get("skill_state", null),
		"skill_config": deps.get("skill_config", null),
		"ball_physics": deps.get("ball_physics", null),
		"orb_hud_state": deps.get("orb_hud_state", null),
		"impact_effects": deps.get("impact_effects", null),
		"audio": deps.get("audio", null),
		"power_state": deps.get("power_state", null),
	}
