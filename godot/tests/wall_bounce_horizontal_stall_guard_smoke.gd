extends SceneTree

const WallBounceState := preload("res://scripts/ball/wall_bounce_state.gd")

const ANGLE_EPSILON_DEG := 0.6
const SPEED_EPSILON := 0.01

var _failures: Array[String] = []


func _init() -> void:
	_verify_third_alternating_wall_hit_gets_angle_floor()
	_verify_angle_floor_ramps_before_draw_reset()
	_verify_steep_wall_bounces_are_not_retuned()
	_verify_vertical_direction_is_preserved()
	_verify_zero_vertical_speed_gets_a_tiebreak_angle()
	_verify_draw_reset_remains_as_fallback()

	if _failures.is_empty():
		print("wall_bounce_horizontal_stall_guard_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_third_alternating_wall_hit_gets_angle_floor() -> void:
	var state: Object = WallBounceState.new()
	state.register_paddle_hit(0)

	var first: Dictionary = state.resolve(Vector2(-20.0, 0.2), 1.0, "left", 1000)
	var second: Dictionary = state.resolve(_get_ball_vel(first), 1.0, "right", 1100)
	var before_third: Vector2 = _get_ball_vel(second)
	var third: Dictionary = state.resolve(before_third, 1.0, "left", 1200)
	var third_velocity: Vector2 = _get_ball_vel(third)
	var third_angle: float = _angle_from_horizontal_deg(third_velocity)

	_expect(_angle_from_horizontal_deg(_get_ball_vel(first)) < 2.0, "first shallow wall bounce should stay shallow")
	_expect(
		abs(third_angle - 8.0) <= ANGLE_EPSILON_DEG,
		"third alternating wall bounce should floor shallow angle to about 8 deg, got %.2f" % third_angle
	)
	_expect(
		abs(third_velocity.length() - before_third.length() * 0.95) <= SPEED_EPSILON,
		"horizontal stall guard should preserve post-wall-damping speed"
	)


func _verify_angle_floor_ramps_before_draw_reset() -> void:
	var state: Object = WallBounceState.new()
	state.register_paddle_hit(0)

	var velocity := Vector2(-20.0, 0.2)
	var side := "left"
	var angles: Array[float] = []
	for index in range(6):
		var result: Dictionary = state.resolve(velocity, 1.0, side, 1000 + index * 100)
		velocity = _get_ball_vel(result)
		angles.append(_angle_from_horizontal_deg(velocity))
		side = "right" if side == "left" else "left"

	_expect(angles[2] > angles[1] + 5.0, "third wall bounce should visibly raise a shallow horizontal path")
	_expect(angles[3] > angles[2] + 3.0, "fourth wall bounce should continue the gradual angle ramp")
	_expect(angles[5] >= 20.0, "sixth quick wall bounce should be steered strongly before the timed draw reset")


func _verify_steep_wall_bounces_are_not_retuned() -> void:
	var state: Object = WallBounceState.new()
	state.register_paddle_hit(0)

	var first: Dictionary = state.resolve(Vector2(-20.0, 12.0), 1.0, "left", 1000)
	var second: Dictionary = state.resolve(_get_ball_vel(first), 1.0, "right", 1100)
	var before_third: Vector2 = _get_ball_vel(second)
	var expected_angle: float = _angle_from_horizontal_deg(before_third)
	var third: Dictionary = state.resolve(before_third, 1.0, "left", 1200)
	var actual_angle: float = _angle_from_horizontal_deg(_get_ball_vel(third))

	_expect(expected_angle > 25.0, "test setup should use an already-steep wall path")
	_expect(
		abs(actual_angle - expected_angle) <= ANGLE_EPSILON_DEG,
		"already-steep wall bounces should not be retuned, expected %.2f got %.2f" % [expected_angle, actual_angle]
	)


func _verify_vertical_direction_is_preserved() -> void:
	var state: Object = WallBounceState.new()
	state.register_paddle_hit(0)

	var first: Dictionary = state.resolve(Vector2(-20.0, -0.2), 1.0, "left", 1000)
	var second: Dictionary = state.resolve(_get_ball_vel(first), 1.0, "right", 1100)
	var third: Dictionary = state.resolve(_get_ball_vel(second), 1.0, "left", 1200)
	var third_velocity: Vector2 = _get_ball_vel(third)

	_expect(third_velocity.y < 0.0, "horizontal stall guard should preserve an upward drift direction")
	_expect(
		abs(_angle_from_horizontal_deg(third_velocity) - 8.0) <= ANGLE_EPSILON_DEG,
		"upward shallow wall path should still receive the third-bounce angle floor"
	)


func _verify_zero_vertical_speed_gets_a_tiebreak_angle() -> void:
	var state: Object = WallBounceState.new()
	state.register_paddle_hit(0)

	var first: Dictionary = state.resolve(Vector2(-20.0, 0.0), 1.0, "left", 1000)
	var second: Dictionary = state.resolve(_get_ball_vel(first), 1.0, "right", 1100)
	var third: Dictionary = state.resolve(_get_ball_vel(second), 1.0, "left", 1200)
	var third_velocity: Vector2 = _get_ball_vel(third)

	_expect(abs(third_velocity.y) > 0.1, "perfectly horizontal wall loops should receive a vertical tiebreak")
	_expect(
		abs(_angle_from_horizontal_deg(third_velocity) - 8.0) <= ANGLE_EPSILON_DEG,
		"perfectly horizontal wall loop should be retargeted to the first angle floor"
	)


func _verify_draw_reset_remains_as_fallback() -> void:
	var state: Object = WallBounceState.new()
	state.register_paddle_hit(0)

	var velocity := Vector2(-20.0, 0.2)
	var side := "left"
	var result: Dictionary = {}
	for index in range(7):
		result = state.resolve(velocity, 1.0, side, 1000 + index * 1000)
		velocity = _get_ball_vel(result)
		side = "right" if side == "left" else "left"

	_expect(bool(result.get("rematch_requested", false)), "timed alternating wall loop should still request rematch fallback")


func _get_ball_vel(result: Dictionary) -> Vector2:
	var value: Variant = result.get("ball_vel", Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _angle_from_horizontal_deg(velocity: Vector2) -> float:
	return rad_to_deg(atan2(abs(velocity.y), abs(velocity.x)))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
