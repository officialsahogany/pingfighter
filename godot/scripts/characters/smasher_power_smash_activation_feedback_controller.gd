extends RefCounted


func apply_pre_activation_feedback(
	context: Dictionary,
	deps: Dictionary,
	callbacks: Dictionary,
	current_msec: int
) -> void:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null:
		skill_state.trigger_configured_cooldown("power_smashing", current_msec, deps.get("skill_config", null))

	var orb_hud_state: Object = deps.get("orb_hud_state", null)
	if orb_hud_state != null:
		orb_hud_state.trigger_gauge_spin(current_msec)

	var reset_drive_input_callback: Callable = callbacks.get("reset_drive_input", Callable())
	if reset_drive_input_callback.is_valid():
		reset_drive_input_callback.call()

	var clear_drive_ball_callback: Callable = callbacks.get("clear_drive_ball", Callable())
	if clear_drive_ball_callback.is_valid():
		clear_drive_ball_callback.call(true)

	var drive_input_state: Object = deps.get("drive_input_state", null)
	if drive_input_state != null:
		drive_input_state.trigger_frame_cooldowns(
			float(context.get("perfect_cooldown_frames", 0.0)),
			float(context.get("global_cooldown_frames", 0.0))
		)


func apply_post_activation_feedback(
	_context: Dictionary,
	deps: Dictionary,
	_power_state: Object,
	_combo_bonus_count: int
) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null:
		audio.play_power_smash()
