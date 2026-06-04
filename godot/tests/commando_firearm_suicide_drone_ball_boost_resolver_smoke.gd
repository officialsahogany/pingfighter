extends SceneTree

const CommandoFirearmSuicideDroneBallBoostResolver := preload("res://scripts/characters/commando_firearm_suicide_drone_ball_boost_resolver.gd")
const BallFrameMotionController := preload("res://scripts/ball/ball_frame_motion_controller.gd")
const BallUpdateContext := preload("res://scripts/ball/ball_update_context.gd")

var _failures: Array[String] = []


class FakeBoostOwner:
	extends RefCounted

	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2(90.0, 0.0)
	var ball_active := true
	var player_pos := Vector2(300.0, 700.0)
	var boss_pos := Vector2(330.0, 25.0)
	var commando_suicide_drone_ball_boost_active := true
	var commando_suicide_drone_ball_restore_speed := 9.0
	var commando_suicide_drone_ball_boosted_speed := 27.0


class FakePhysics:
	extends RefCounted

	func enforce_minimum_rally_speed(velocity: Vector2) -> Vector2:
		return velocity

	func get_minimum_effective_boost(_velocity: Vector2) -> float:
		return 1.0


func _init() -> void:
	_verify_direct_suicide_drone_ball_boost_resolver()
	_verify_runtime_delegates_suicide_drone_ball_boost_resolver()
	_verify_suicide_drone_boost_disables_ball_speed_cap()

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
	_expect(bool(result.get("commando_suicide_drone_speed_limit_disabled", false)), "boost result should mark the suicide-drone speed cap override")
	_expect(bool(result.get("speed_limit_disabled", false)), "boost result should disable the shared ball speed cap")
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
	var projectile := {"id": 7, "pos": Vector2(100.0, 80.0)}
	_expect(is_equal_approx(CommandoFirearmSuicideDroneBallBoostResolver.get_fan_angle(projectile, 25.0), 2.95), "fan-angle owner should stay deterministic")
	var result: Dictionary = CommandoFirearmSuicideDroneBallBoostResolver.build_boost_result(
		projectile,
		{"ball_vel": Vector2(0.0, 9.0), "ball_base_speed": 8.0},
		3.0,
		25.0
	)
	_expect(is_equal_approx(float(result.get("commando_suicide_drone_ball_restore_speed", 0.0)), 9.0), "boost-result owner should preserve restore speed")
	_expect(is_equal_approx(float(result.get("commando_suicide_drone_ball_boosted_speed", 0.0)), 27.0), "boost-result owner should preserve boosted speed")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	var projectile_motion_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_projectile_motion_state.gd")
	var suicide_drone_state_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_suicide_drone_state.gd")
	_expect(runtime_source.find("CommandoFirearmProjectileMotionState.advance_runtime_projectiles") >= 0, "runtime projectile advancement should delegate through the projectile motion owner")
	_expect(projectile_motion_source.find("CommandoFirearmSuicideDroneState.resolve_runtime_collision_at_index") >= 0, "projectile motion owner should delegate drone collision detonation through the suicide-drone state owner")
	_expect(suicide_drone_state_source.find("detonate_runtime_projectile_at_index(") >= 0, "suicide-drone state owner should retain indexed detonation ownership")
	_expect(runtime_source.find("CommandoFirearmSuicideDroneBallBoostResolver.build_boost_result(") < 0, "runtime should not build suicide-drone ball boost results inline")
	_expect(suicide_drone_state_source.find("CommandoFirearmSuicideDroneBallBoostResolver.build_boost_result(") >= 0, "suicide-drone state owner should call the ball boost owner")
	_expect(not runtime_source.contains("func _build_suicide_drone_ball_boost_result("), "runtime should not keep suicide-drone ball boost result bridge")
	_expect(not runtime_source.contains("func _get_suicide_drone_ball_fan_angle("), "runtime should not keep suicide-drone fan-angle bridge")


func _verify_suicide_drone_boost_disables_ball_speed_cap() -> void:
	var owner := FakeBoostOwner.new()
	var active_context: Dictionary = BallUpdateContext.new().build_update_context(owner)
	_expect(bool(active_context.get("commando_suicide_drone_speed_limit_disabled", false)), "update context should expose suicide-drone speed cap override while boost is active")
	_expect(bool(active_context.get("speed_limit_disabled", false)), "update context should disable the shared speed cap while suicide-drone boost is active")

	var motion := BallFrameMotionController.new()
	var uncapped_scene := {
		"ball_vel": Vector2(90.0, 0.0),
		"ball_impact_boost": 1.0,
		"max_ball_speed": 26.0,
		"impact_boost_max_ball_speed": 26.0,
		"commando_suicide_drone_ball_boost_active": true,
		"commando_suicide_drone_ball_boosted_speed": 27.0,
	}
	motion.apply_ball_speed_limits(uncapped_scene, {"ball_physics": FakePhysics.new()})
	_expect(is_equal_approx(_get_vector2(uncapped_scene.get("ball_vel", Vector2.ZERO)).length(), 90.0), "active suicide-drone boost should bypass frame speed caps above the 3x launch speed")

	owner.commando_suicide_drone_ball_boost_active = false
	var restored_context: Dictionary = BallUpdateContext.new().build_update_context(owner)
	_expect(not bool(restored_context.get("commando_suicide_drone_speed_limit_disabled", true)), "update context should clear suicide-drone cap override when boost is consumed")
	_expect(not bool(restored_context.get("speed_limit_disabled", false)), "update context should restore the shared speed cap after suicide-drone boost is consumed")
	var capped_scene := {
		"ball_vel": Vector2(90.0, 0.0),
		"ball_impact_boost": 1.0,
		"max_ball_speed": 26.0,
		"impact_boost_max_ball_speed": 26.0,
		"commando_suicide_drone_ball_boost_active": false,
	}
	motion.apply_ball_speed_limits(capped_scene, {"ball_physics": FakePhysics.new()})
	_expect(_get_vector2(capped_scene.get("ball_vel", Vector2.ZERO)).length() <= 26.01, "normal frame speed cap should return after suicide-drone boost is consumed")


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _function_body(source: String, signature: String) -> String:
	var start: int = source.find(signature)
	if start < 0:
		return ""
	var next_func: int = source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
