extends RefCounted

const SmasherDriveActivationFeedbackController := preload("res://scripts/characters/smasher_drive_activation_feedback_controller.gd")

var feedback_controller: Object = SmasherDriveActivationFeedbackController.new()


func try_activate(
	speed: float,
	angle_rad: float,
	hit_pos: float,
	accel_scale: float,
	gameplay_frame: int,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var result: Dictionary = {
		"activated": false,
		"speed": speed,
		"angle_rad": angle_rad,
		"ball_spin_strength": float(context.get("ball_spin_strength", 0.0)),
		"ball_spin_direction": int(context.get("ball_spin_direction", 0)),
		"drive_speed_increase": float(context.get("drive_speed_increase", 0.0)),
		"drive_ball_active": bool(context.get("drive_ball_active", false)),
		"drive_hit_boss": bool(context.get("drive_hit_boss", false)),
		"special_gauge": float(context.get("special_gauge", 0.0)),
		"drive_text_timer_frames": float(context.get("drive_text_timer_frames", 0.0)),
	}
	if not can_activate(context, deps):
		return result

	var drive_input_state: Object = deps.get("drive_input_state", null)
	var drive_direction: int = 0
	if drive_input_state != null:
		drive_direction = drive_input_state.consume_direction(gameplay_frame)
	if drive_direction == 0:
		return result

	var drive_bounce_state: Object = deps.get("drive_bounce_state", null)
	if drive_bounce_state == null:
		return result

	var combo_state: Object = deps.get("combo_state", null)
	var combo_used: int = 0
	if combo_state != null:
		combo_used = int(combo_state.get_effective_combo())

	# 콤보증폭칩: 콤보 비례 드라이브 공속/커브 항을 추가 증폭(base는 비증폭).
	var combo_amp_speed: float = 0.0
	var combo_amp_curve: float = 0.0
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("get_combo_amplifier_chip_bonus"):
		var combo_amp: Dictionary = runtime_perk_state.get_combo_amplifier_chip_bonus()
		combo_amp_speed = float(combo_amp.get("drive_speed", 0.0))
		combo_amp_curve = float(combo_amp.get("drive_curve", 0.0))

	var drive_result: Dictionary = drive_bounce_state.apply_initial_bounce(
		speed,
		hit_pos,
		drive_direction,
		combo_used,
		accel_scale,
		deps.get("ball_physics", null),
		int(context.get("combo_min_count", 2)),
		float(context.get("text_duration_frames", 0.0)),
		combo_amp_speed,
		combo_amp_curve
	)
	feedback_controller.apply_feedback(context, deps, drive_result, drive_input_state, combo_state)

	result["activated"] = true
	result["speed"] = float(drive_result.get("speed", speed))
	result["angle_rad"] = float(drive_result.get("angle_rad", angle_rad))
	result["ball_spin_strength"] = float(drive_result.get("spin_strength", result["ball_spin_strength"]))
	result["ball_spin_direction"] = int(drive_result.get("spin_direction", drive_direction))
	result["drive_speed_increase"] = float(drive_result.get("speed_increase", 0.0))
	result["drive_ball_active"] = true
	result["drive_hit_boss"] = false
	result["special_gauge"] = max(
		0.0,
		float(context.get("special_gauge", 0.0)) - float(context.get("gauge_cost", 0.0))
	)
	result["drive_text_timer_frames"] = float(
		drive_result.get("text_timer_frames", context.get("text_duration_frames", 0.0))
	)
	return result


func can_activate(context: Dictionary, deps: Dictionary) -> bool:
	var round_state: Object = deps.get("round_state", null)
	if round_state == null or round_state.is_waiting_for_serve():
		return false
	if not bool(context.get("ball_active", false)):
		return false
	if float(context.get("special_gauge", 0.0)) < float(context.get("gauge_cost", 0.0)):
		return false

	var drive_input_state: Object = deps.get("drive_input_state", null)
	if drive_input_state != null and drive_input_state.is_frame_cooldown_blocked():
		return false

	var skill_state: Object = deps.get("skill_state", null)
	if skill_state == null:
		return true
	return skill_state.get_configured_cooldown_remaining(
		"drive",
		int(context.get("current_msec", Time.get_ticks_msec())),
		deps.get("skill_config", null)
	) <= 0.0
