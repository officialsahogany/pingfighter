extends RefCounted


func update_freeze(delta: float, ball_pos: Vector2, context: Dictionary, deps: Dictionary) -> Dictionary:
	var power_state = deps.get("power_state", null)
	if power_state == null:
		return {}
	if not power_state.is_freeze_active():
		return {}

	if power_state.is_freeze_ball_locked():
		ball_pos = power_state.get_freeze_ball_pos()

	var launched: bool = power_state.update_freeze(delta, float(context.get("freeze_duration", 0.0)))
	if launched:
		var audio = deps.get("audio", null)
		if audio != null:
			audio.play_power_smash_launch()

		var combo_consumed: int = int(power_state.get_combo_consumed())
		var feedback = deps.get("feedback", null)
		if feedback != null and combo_consumed >= 2:
			feedback.max_screen_shake(
				float(15 + combo_consumed * 2) / 60.0,
				10.0 + float(combo_consumed * 2)
			)

	return {
		"ball_pos": ball_pos,
	}


func apply_motion(ball_vel: Vector2, fps_scale: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	var power_state = deps.get("power_state", null)
	if power_state == null:
		return {}
	return {
		"ball_vel": power_state.apply_motion(
			ball_vel,
			fps_scale,
			float(context.get("gravity_effect", 0.0)),
			float(context.get("boost_duration", 0.0))
		),
	}
