extends RefCounted

const POWER_SMASH_EFFECT_MULT := 1.0
const POWER_SMASH_INITIAL_DECAY_FACTOR := 0.89024
# Side-smash trajectory angle ceiling (40 deg from vertical), matching the launch
# ceiling in smasher_power_smash_hit_direction_resolver.gd. tan(40 deg).
const POWER_SMASH_MAX_TURN_RATIO := 0.839099631


func apply(
	power_state: Object,
	ball_velocity: Vector2,
	fps_scale: float,
	gravity_effect: float,
	boost_duration: float,
	initial_boost_decay_reduction: float = 0.0
) -> Vector2:
	if power_state == null:
		return ball_velocity
	if not power_state.step_motion(fps_scale, boost_duration):
		return ball_velocity

	var elapsed: float = float(power_state.get_elapsed())
	if bool(power_state.is_initial_boost_active()) and elapsed < boost_duration:
		ball_velocity = _apply_initial_boost(
			power_state,
			ball_velocity,
			elapsed,
			boost_duration,
			initial_boost_decay_reduction
		)

	var arc_strength: float = float(power_state.get_arc_strength())
	var horizontal_decay: float = max(0.8, 1.0 - elapsed * 0.05)
	var chaos_random: float = randf_range(-0.04, 0.04)
	var chaos_factor: float = sin(elapsed * 5.0) * 0.05 + chaos_random
	var horizontal_force: float = arc_strength * horizontal_decay * (0.5 + chaos_factor * 0.2)
	ball_velocity.x += horizontal_force * fps_scale

	if elapsed < 1.8:
		var base_lift: float = gravity_effect * 1.5 * (1.8 - elapsed) / 1.8
		var vertical_chaos: float = cos(elapsed * 5.0) * 0.015 * POWER_SMASH_EFFECT_MULT
		var vertical_lift: float = base_lift + vertical_chaos
		ball_velocity.y -= vertical_lift * fps_scale
	else:
		var base_pull: float = gravity_effect * 1.2 * (elapsed - 1.8)
		var descent_chaos: float = sin(elapsed * 7.0) * 0.015 * POWER_SMASH_EFFECT_MULT
		var vertical_pull: float = base_pull + descent_chaos
		ball_velocity.y += vertical_pull * fps_scale

	# Hold the side-smash path within the 40 deg launch ceiling. The arc above adds
	# lateral velocity every frame; left unbounded it widens the trajectory past
	# 40 deg from vertical (the felt 50-65 deg) so the ball drifts into the side
	# wall, loses speed to the 0.95 wall damping, and is trivial to guard. Straight
	# smashes (direction 0, arc 0) accumulate no lateral, so they are skipped and
	# never forced UP toward the ceiling.
	if int(power_state.get_direction()) != 0:
		ball_velocity = _clamp_lateral_to_angle_ceiling(ball_velocity)

	return ball_velocity


func _clamp_lateral_to_angle_ceiling(ball_velocity: Vector2) -> Vector2:
	var y_abs: float = abs(ball_velocity.y)
	if y_abs <= 0.0001:
		return ball_velocity
	var lateral_limit: float = y_abs * POWER_SMASH_MAX_TURN_RATIO
	if abs(ball_velocity.x) > lateral_limit:
		ball_velocity.x = clampf(ball_velocity.x, -lateral_limit, lateral_limit)
	return ball_velocity


func _apply_initial_boost(
	power_state: Object,
	ball_velocity: Vector2,
	elapsed: float,
	boost_duration: float,
	initial_boost_decay_reduction: float = 0.0
) -> Vector2:
	var current_speed: float = ball_velocity.length()
	var boost_progress: float = clamp(elapsed / boost_duration, 0.0, 1.0)
	var target_speed: float = float(power_state.get_target_speed())
	var boosted_speed: float = float(power_state.get_boosted_speed())
	var initial_boosted_speed: float = boosted_speed if boosted_speed > 0.0 else target_speed
	# 진행표 원본 레벨이 아니라 runtime_perk_state가 개광결까지 반영한 실효값이다.
	# 방어적 상한은 비정상 증폭이 감쇄 부호를 뒤집지 못하게 할 뿐, Lv3의 50%를
	# 개광결이 넘어서는 정상 fail-open 증폭은 그대로 허용한다.
	var decay_reduction := clampf(initial_boost_decay_reduction, 0.0, 1.0)
	var decay_factor: float = POWER_SMASH_INITIAL_DECAY_FACTOR * (1.0 - decay_reduction)
	var interpolated_speed: float = initial_boosted_speed - (initial_boosted_speed - target_speed) * boost_progress * decay_factor
	if current_speed > 0.0:
		ball_velocity *= interpolated_speed / current_speed
		if boost_progress >= 1.0:
			power_state.stop_initial_boost()
	return ball_velocity
