extends SceneTree

const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmSuicideDroneBallBoostResolver := preload("res://scripts/characters/commando_firearm_suicide_drone_ball_boost_resolver.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_suicide_drone_ball_boost_resolver()
	_verify_runtime_delegates_suicide_drone_ball_boost_resolver()

	if _failures.is_empty():
		print("commando_firearm_suicide_drone_ball_boost_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_suicide_drone_ball_boost_resolver() -> void:
	var projectile := {"id": 7, "pos": Vector2(100.0, 80.0)}
	var angle: float = CommandoFirearmSuicideDroneBallBoostResolver.get_fan_angle(projectile, 25.0)
	_expect(is_equal_approx(angle, 2.95), "suicide drone fan angle should preserve the deterministic legacy formula")

	var result: Dictionary = CommandoFirearmSuicideDroneBallBoostResolver.build_boost_result(
		projectile,
		{"ball_vel": Vector2(0.0, 9.0), "ball_base_speed": 8.0},
		3.0,
		25.0
	)
	var boosted_vel: Vector2 = _get_vector2(result.get("ball_vel", Vector2.ZERO))
	_expect(bool(result.get("commando_suicide_drone_ball_boosted", false)), "boost result should flag the ball as boosted")
	_expect(bool(result.get("commando_suicide_drone_ball_boost_active", false)), "boost result should expose active boost state")
	_expect(is_equal_approx(float(result.get("commando_suicide_drone_ball_restore_speed", 0.0)), 9.0), "boost result should preserve original ball speed for restore")
	_expect(is_equal_approx(float(result.get("commando_suicide_drone_ball_boosted_speed", 0.0)), 27.0), "boost result should expose boosted speed")
	_expect(is_equal_approx(float(result.get("commando_suicide_drone_ball_boost_angle_deg", 0.0)), 2.95), "boost result should expose fan angle")
	_expect(is_equal_approx(boosted_vel.length(), 27.0), "boost velocity should use boosted speed")
	_expect(boosted_vel.y < 0.0, "boost velocity should launch the ball upward")

	var base_result: Dictionary = CommandoFirearmSuicideDroneBallBoostResolver.build_boost_result(
		projectile,
		{"ball_vel": Vector2.ZERO, "base_ball_speed": 11.0},
		3.0,
		25.0
	)
	_expect(is_equal_approx(float(base_result.get("commando_suicide_drone_ball_restore_speed", 0.0)), 11.0), "zero-speed balls should use base speed fallback")
	_expect(is_equal_approx(float(base_result.get("commando_suicide_drone_ball_boosted_speed", 0.0)), 33.0), "zero-speed fallback should still apply boost multiplier")


func _verify_runtime_delegates_suicide_drone_ball_boost_resolver() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var projectile := {"id": 7, "pos": Vector2(100.0, 80.0)}
	_expect(is_equal_approx(runtime._get_suicide_drone_ball_fan_angle(projectile), 2.95), "runtime fan-angle wrapper should delegate")
	var result: Dictionary = runtime._build_suicide_drone_ball_boost_result(
		projectile,
		{"ball_vel": Vector2(0.0, 9.0), "ball_base_speed": 8.0}
	)
	_expect(is_equal_approx(float(result.get("commando_suicide_drone_ball_restore_speed", 0.0)), 9.0), "runtime boost-result wrapper should preserve restore speed")
	_expect(is_equal_approx(float(result.get("commando_suicide_drone_ball_boosted_speed", 0.0)), 27.0), "runtime boost-result wrapper should preserve boosted speed")


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
