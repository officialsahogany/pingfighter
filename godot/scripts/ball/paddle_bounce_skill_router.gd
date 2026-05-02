extends RefCounted

const PaddleBounceDriveActivationRouter := preload("res://scripts/ball/paddle_bounce_drive_activation_router.gd")

var drive_activation_router: Object = PaddleBounceDriveActivationRouter.new()


func try_activate_power_smashing(
	ball_pos: Vector2,
	ball_active: bool,
	special_gauge: float,
	context: Dictionary,
	deps: Dictionary,
	callbacks: Dictionary
) -> Dictionary:
	var controller: Object = deps.get("power_activation_controller", null)
	if controller == null:
		return {
			"activated": false,
			"special_gauge": special_gauge,
		}
	return controller.try_activate(
		{
			"ball_active": ball_active,
			"ball_pos": ball_pos,
			"special_gauge": special_gauge,
			"gauge_cost": float(context.get("power_smash_gauge_cost", 0.0)),
			"ball_size": float(context.get("ball_size", 22.0)),
			"text_duration_frames": float(context.get("power_smash_text_duration_frames", 0.0)),
			"perfect_cooldown_frames": float(context.get("drive_perfect_cooldown_frames", 0.0)),
			"global_cooldown_frames": float(context.get("drive_global_cooldown_frames", 0.0)),
			"combo_min_count": int(context.get("combo_min_count", 2)),
			"current_msec": int(context.get("current_msec", Time.get_ticks_msec())),
		},
		{
			"input_reader": deps.get("input_reader", null),
			"power_state": deps.get("power_state", null),
			"round_state": deps.get("round_state", null),
			"drive_input_state": deps.get("drive_input_state", null),
			"combo_state": deps.get("combo_state", null),
			"skill_state": deps.get("skill_state", null),
			"skill_config": deps.get("skill_config", null),
			"orb_hud_state": deps.get("orb_hud_state", null),
			"audio": deps.get("audio", null),
			"feedback": deps.get("feedback", null),
		},
		callbacks
	)


func try_activate_drive(
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
	return drive_activation_router.try_activate(
		speed,
		angle_rad,
		hit_pos,
		accel_scale,
		ball_pos,
		ball_spin_strength,
		ball_spin_direction,
		drive_speed_increase,
		drive_ball_active,
		drive_hit_boss,
		special_gauge,
		drive_text_timer_frames,
		context,
		deps
	)


func build_clear_drive_snapshot(ball_spin_state: Object, clear_spin: bool) -> Dictionary:
	if ball_spin_state != null and ball_spin_state.has_method("build_clear_drive_snapshot"):
		var snapshot: Variant = ball_spin_state.build_clear_drive_snapshot(clear_spin)
		if snapshot is Dictionary:
			return snapshot
	var fallback: Dictionary = {
		"drive_ball_active": false,
		"drive_hit_boss": false,
		"drive_speed_increase": 0.0,
	}
	if clear_spin:
		fallback["ball_spin_strength"] = 0.0
		fallback["ball_spin_direction"] = 0
	return fallback
