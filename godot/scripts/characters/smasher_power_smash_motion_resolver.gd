extends RefCounted


func apply(
	power_state: Object,
	ball_velocity: Vector2,
	fps_scale: float,
	gravity_effect: float,
	boost_duration: float
) -> Vector2:
	if power_state == null:
		return ball_velocity
	if not power_state.step_motion(fps_scale, boost_duration):
		return ball_velocity

	var elapsed: float = float(power_state.get_elapsed())
	if bool(power_state.is_initial_boost_active()) and elapsed < boost_duration:
		ball_velocity = _apply_initial_boost(power_state, ball_velocity, elapsed, boost_duration)

	var arc_strength: float = float(power_state.get_arc_strength())
	var horizontal_decay: float = max(0.8, 1.0 - elapsed * 0.05)
	var chaos_random: float = randf_range(-0.04, 0.04)
	var chaos_factor: float = sin(elapsed * 5.0) * 0.05 + chaos_random
	var horizontal_force: float = arc_strength * horizontal_decay * (0.5 + chaos_factor * 0.2)
	ball_velocity.x += horizontal_force * fps_scale

	if elapsed < 1.8:
		var base_lift: float = gravity_effect * 1.5 * (1.8 - elapsed) / 1.8
		var vertical_chaos: float = cos(elapsed * 5.0) * 0.015
		var vertical_lift: float = base_lift + vertical_chaos
		ball_velocity.y -= vertical_lift * fps_scale
	else:
		var base_pull: float = gravity_effect * 1.2 * (elapsed - 1.8)
		var descent_chaos: float = sin(elapsed * 7.0) * 0.015
		var vertical_pull: float = base_pull + descent_chaos
		ball_velocity.y += vertical_pull * fps_scale

	return ball_velocity


func _apply_initial_boost(power_state: Object, ball_velocity: Vector2, elapsed: float, boost_duration: float) -> Vector2:
	var current_speed: float = ball_velocity.length()
	var boost_progress: float = clamp(elapsed / boost_duration, 0.0, 1.0)
	var target_speed: float = float(power_state.get_target_speed())
	var boosted_speed: float = float(power_state.get_boosted_speed())
	var initial_boosted_speed: float = boosted_speed if boosted_speed > 0.0 else target_speed
	var interpolated_speed: float = initial_boosted_speed - (initial_boosted_speed - target_speed) * boost_progress
	if current_speed > 0.0:
		ball_velocity *= interpolated_speed / current_speed
		if boost_progress >= 1.0:
			power_state.stop_initial_boost()
	return ball_velocity
