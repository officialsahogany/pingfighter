extends RefCounted

const POWER_SMASH_MIN_TURN_RATIO := 0.466307658
const POWER_SMASH_MIN_TURN_SIN := 0.422618262
const POWER_SMASH_MIN_TURN_COS := 0.906307787
# Side-smash launch angle CEILING (40 deg from vertical). The incoming ball can
# arrive nearly horizontal; without a ceiling the launch keeps (and side_mult
# amplifies) that wide angle, the per-frame arc then widens it even further, and
# the ball drifts into the side wall -- loses speed to the 0.95 wall damping and
# becomes trivial for the boss to guard. Mirrors the MIN floor below and is
# speed-preserving (sin^2 + cos^2 = 1). tan/sin/cos of 40 deg.
const POWER_SMASH_MAX_TURN_RATIO := 0.839099631
const POWER_SMASH_MAX_TURN_SIN := 0.642787610
const POWER_SMASH_MAX_TURN_COS := 0.766044443
const POWER_SMASH_EFFECT_MULT := 1.0
const POWER_SMASH_SIDE_STRAIGHT_MULT := 1.0 + ((1.065856 - 1.0) * POWER_SMASH_EFFECT_MULT)


func apply_side_direction(ball_velocity: Vector2, direction: int, base_speed: float, ball_physics: Object) -> Vector2:
	var dir_sign: float = -1.0 if direction < 0 else 1.0
	var side_mult: float = _apply_dampened_multiplier(ball_physics, ball_velocity.length(), POWER_SMASH_SIDE_STRAIGHT_MULT)
	ball_velocity.x = dir_sign * abs(ball_velocity.x) * side_mult

	var y_abs: float = max(abs(ball_velocity.y), 0.0001)
	var x_abs: float = abs(ball_velocity.x)
	if x_abs < y_abs * POWER_SMASH_MIN_TURN_RATIO:
		ball_velocity = _retarget_to_fixed_angle(ball_velocity, dir_sign, base_speed, POWER_SMASH_MIN_TURN_SIN, POWER_SMASH_MIN_TURN_COS)
	elif x_abs > y_abs * POWER_SMASH_MAX_TURN_RATIO:
		ball_velocity = _retarget_to_fixed_angle(ball_velocity, dir_sign, base_speed, POWER_SMASH_MAX_TURN_SIN, POWER_SMASH_MAX_TURN_COS)
	return ball_velocity


func _retarget_to_fixed_angle(ball_velocity: Vector2, dir_sign: float, base_speed: float, sin_value: float, cos_value: float) -> Vector2:
	# Re-point the launch to a fixed angle from vertical while preserving speed.
	var turn_speed: float = ball_velocity.length()
	if turn_speed <= 0.0:
		turn_speed = base_speed
	var y_sign: float = -1.0 if ball_velocity.y < 0.0 else 1.0
	if abs(ball_velocity.y) <= 0.0001:
		y_sign = -1.0
	ball_velocity.x = dir_sign * turn_speed * sin_value
	ball_velocity.y = y_sign * turn_speed * cos_value
	return ball_velocity


func apply_straight_direction(
	ball_velocity: Vector2,
	ball_position: Vector2,
	player_position: Vector2,
	paddle_width: float,
	base_speed: float,
	ball_physics: Object
) -> Vector2:
	var x_diff: float = ball_position.x - (player_position.x + paddle_width * 0.5)
	if abs(ball_velocity.x) < base_speed * 0.3:
		if abs(x_diff) > 3.0:
			ball_velocity.x = base_speed * 0.6 * (1.0 if x_diff > 0.0 else -1.0)
		else:
			ball_velocity.x *= 0.3
	var straight_mult: float = _apply_dampened_multiplier(ball_physics, ball_velocity.length(), POWER_SMASH_SIDE_STRAIGHT_MULT)
	ball_velocity *= straight_mult
	return ball_velocity


func _apply_dampened_multiplier(ball_physics: Object, current_speed: float, raw_multiplier: float) -> float:
	if ball_physics != null and ball_physics.has_method("apply_dampened_multiplier"):
		return float(ball_physics.apply_dampened_multiplier(current_speed, raw_multiplier))
	return raw_multiplier
