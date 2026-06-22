extends RefCounted

const STAGE1_CHAMPION_BOSS_SPEED_MULT: float = 1.5
const BOSS_ACCEL: float = 0.798 * STAGE1_CHAMPION_BOSS_SPEED_MULT
const BOSS_DECEL: float = 0.798 * STAGE1_CHAMPION_BOSS_SPEED_MULT
const BOSS_MAX_SPEED: float = 6.3175 * STAGE1_CHAMPION_BOSS_SPEED_MULT
const TURN_SLIDE_BRAKE_MULT: float = 0.48
const TURN_APPROACH_SLIDE_BRAKE_MULT: float = 0.82
const TURN_RELEASE_ACCEL_MULT: float = 0.18
const TURN_RELEASE_MIN_RATIO: float = 0.03


func update_velocity(
	future_x: float,
	boss_center: float,
	boss_vel: float,
	fps_scale: float,
	ball_approaching_boss: bool,
	reaction_multiplier: float = 1.0,
	decel_multiplier: float = 1.0,
	movement_context: Dictionary = {}
) -> float:
	var base_accel: float = max(0.0, float(movement_context.get("boss_movement_accel", BOSS_ACCEL)))
	var base_decel: float = max(0.0, float(movement_context.get("boss_movement_decel", BOSS_DECEL)))
	var base_max_speed: float = max(0.0, float(movement_context.get("boss_movement_max_speed", BOSS_MAX_SPEED)))
	var accel: float = base_accel * max(0.0, reaction_multiplier)
	var max_speed: float = base_max_speed * max(0.0, reaction_multiplier)
	var decel: float = base_decel * max(0.0, decel_multiplier)
	var target_dir: int = _get_target_direction(future_x, boss_center)
	var reversing: bool = _is_reversing(target_dir, boss_vel)
	if reversing:
		return _sanitize_velocity(
			_brake_through_reversal(target_dir, boss_vel, fps_scale, ball_approaching_boss, accel, decel),
			max_speed
		)

	if target_dir < 0:
		boss_vel = _approach_target(future_x, boss_center, boss_vel, fps_scale, accel, decel, max_speed, true)
	elif target_dir > 0:
		boss_vel = _approach_target(future_x, boss_center, boss_vel, fps_scale, accel, decel, max_speed, false)
	else:
		boss_vel = _decelerate_to_stop(boss_vel, fps_scale, decel)

	return _sanitize_velocity(boss_vel, max_speed)


# Accelerate toward the target, but start braking once the boss is within its own
# stopping distance so it SETTLES on the predicted x instead of blowing past it.
# Without this predictive brake the resolver only ever decelerates AFTER overshoot
# (via _brake_through_reversal), and the weak reversal brake (< 1.0 mult) leaves a
# sustained limit-cycle oscillation after any large displacement (banana slip /
# knockback slam to a wall). Braking distance is the standard v^2/(2*decel) stop
# distance; fps_scale cancels out of that integral so it is not a factor here.
func _approach_target(
	future_x: float,
	boss_center: float,
	boss_vel: float,
	fps_scale: float,
	accel: float,
	decel: float,
	max_speed: float,
	going_left: bool
) -> float:
	var distance_to_target: float = abs(future_x - boss_center)
	var braking_distance: float = (boss_vel * boss_vel) / (2.0 * max(0.001, decel))
	if braking_distance >= distance_to_target:
		return _decelerate_to_stop(boss_vel, fps_scale, decel)
	if going_left:
		return _accelerate_left(boss_vel, fps_scale, accel, max_speed)
	return _accelerate_right(boss_vel, fps_scale, accel, max_speed)


func _brake_through_reversal(
	target_dir: int,
	boss_vel: float,
	fps_scale: float,
	ball_approaching_boss: bool,
	accel: float,
	decel: float
) -> float:
	var slide_brake_mult: float = TURN_APPROACH_SLIDE_BRAKE_MULT if ball_approaching_boss else TURN_SLIDE_BRAKE_MULT
	var brake_step: float = decel * slide_brake_mult * fps_scale
	var current_speed: float = abs(boss_vel)
	if current_speed > brake_step:
		return move_toward(boss_vel, 0.0, brake_step)

	var remaining_brake: float = brake_step - current_speed
	var release_ratio: float = clamp(remaining_brake / max(0.001, brake_step), TURN_RELEASE_MIN_RATIO, 1.0)
	var release_speed: float = accel * TURN_RELEASE_ACCEL_MULT * release_ratio * fps_scale
	return float(target_dir) * release_speed


func _sanitize_velocity(boss_vel: float, max_speed: float) -> float:
	boss_vel = clamp(boss_vel, -max_speed, max_speed)
	if abs(boss_vel) < 0.001:
		return 0.0
	return boss_vel


func _accelerate_left(boss_vel: float, fps_scale: float, accel: float, max_speed: float) -> float:
	if boss_vel <= -max_speed:
		return boss_vel
	return max(-max_speed, boss_vel - accel * fps_scale)


func _accelerate_right(boss_vel: float, fps_scale: float, accel: float, max_speed: float) -> float:
	if boss_vel >= max_speed:
		return boss_vel
	return min(max_speed, boss_vel + accel * fps_scale)


func _decelerate_to_stop(boss_vel: float, fps_scale: float, decel: float) -> float:
	return move_toward(boss_vel, 0.0, decel * fps_scale)


func _get_target_direction(future_x: float, boss_center: float) -> int:
	if future_x < boss_center:
		return -1
	if future_x > boss_center:
		return 1
	return 0


func _is_reversing(target_dir: int, boss_vel: float) -> bool:
	return (target_dir < 0 and boss_vel > 0.0) or (target_dir > 0 and boss_vel < 0.0)
