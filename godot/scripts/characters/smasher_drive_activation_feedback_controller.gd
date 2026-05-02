extends RefCounted


func apply_feedback(
	context: Dictionary,
	deps: Dictionary,
	drive_result: Dictionary,
	drive_input_state: Object,
	combo_state: Object
) -> void:
	if bool(drive_result.get("consume_combo", false)) and combo_state != null:
		combo_state.reset_combo()

	if drive_input_state != null:
		drive_input_state.trigger_frame_cooldowns(
			float(context.get("perfect_cooldown_frames", 0.0)),
			float(context.get("global_cooldown_frames", 0.0))
		)

	var current_msec: int = int(context.get("current_msec", Time.get_ticks_msec()))
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null:
		skill_state.trigger_configured_cooldown("drive", current_msec, deps.get("skill_config", null))

	var orb_hud_state: Object = deps.get("orb_hud_state", null)
	if orb_hud_state != null:
		orb_hud_state.trigger_gauge_spin(current_msec)

	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects != null:
		impact_effects.spawn_drive_particles(_get_particle_pos(context), int(drive_result.get("particle_count", 4)))

	var audio: Object = deps.get("audio", null)
	if audio != null:
		audio.play_drive()


func _get_particle_pos(context: Dictionary) -> Vector2:
	var context_ball_pos: Variant = context.get("ball_pos", Vector2.ZERO)
	if context_ball_pos is Vector2:
		return context_ball_pos
	return Vector2.ZERO
