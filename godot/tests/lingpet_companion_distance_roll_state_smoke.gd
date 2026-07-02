extends SceneTree

const LingpetCompanionDistanceRollState := preload("res://scripts/lingpet/lingpet_companion_distance_roll_state.gd")

var _failures: Array[String] = []


class FakeProfile:
	extends RefCounted

	var values: Dictionary = {}

	func _init(initial_values: Dictionary = {}) -> void:
		values = initial_values.duplicate(true)

	func get_visual_layout_value(key: String, fallback: Variant = 0.0) -> Variant:
		return values.get(key, fallback)


func _init() -> void:
	_verify_signed_roll_distance_uses_path_and_spin_direction()
	_verify_advance_and_coast()
	_verify_draw_angle_and_config_fallbacks()
	_verify_runtime_delegates_distance_roll_state()

	if _failures.is_empty():
		print("lingpet_companion_distance_roll_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_signed_roll_distance_uses_path_and_spin_direction() -> void:
	var state := LingpetCompanionDistanceRollState.new()
	_expect_float(state.signed_roll_distance(Vector2(12.0, 4.0)), 12.0, "horizontal travel should use signed x distance")
	_expect_float(state.signed_roll_distance(Vector2(0.0, 8.0)), 8.0, "vertical travel should default to positive path distance before spin starts")
	state.angular_velocity = -2.0
	_expect_float(state.signed_roll_distance(Vector2(0.0, 8.0)), -8.0, "vertical travel should preserve negative spin direction")
	state.angular_velocity = 3.0
	_expect_float(state.signed_roll_distance(Vector2(0.0, -5.0)), 5.0, "vertical travel should preserve positive spin direction")


func _verify_advance_and_coast() -> void:
	var profile := FakeProfile.new({
		"companion_distance_roll_enabled": 1.0,
		"companion_distance_roll_radius": 10.0,
		"companion_distance_roll_stop_deceleration": 2.0,
		"companion_distance_roll_max_angular_velocity": 6.0,
	})
	var state := LingpetCompanionDistanceRollState.new()
	state.advance_for_movement(Vector2(5.0, 0.0), 0.1, profile, 100.0)
	_expect_float(state.angle, 0.5, "5px on a 10px radius should advance by 0.5 radians")
	_expect_float(state.angular_velocity, 5.0, "angular velocity should derive from angular delta over delta")
	state.advance_for_movement(Vector2.ZERO, 0.1, profile, 100.0)
	_expect(state.angle > 0.5, "coast should keep rolling briefly after movement stops")
	_expect(state.angular_velocity > 0.0 and state.angular_velocity < 5.0, "coast should decelerate positive angular velocity")
	state.reset()
	_expect_float(state.angle, 0.0, "reset should clear roll angle")
	_expect_float(state.angular_velocity, 0.0, "reset should clear angular velocity")


func _verify_draw_angle_and_config_fallbacks() -> void:
	var disabled := FakeProfile.new({})
	var state := LingpetCompanionDistanceRollState.new()
	state.angle = 0.7
	_expect(not state.is_enabled(disabled), "missing enabled flag should disable distance roll")
	_expect_float(state.get_radius(disabled, 98.0), 49.0, "missing radius should fall back to half draw size")
	_expect_float(state.get_stop_deceleration(disabled), 16.0, "missing deceleration should use historical fallback")
	_expect_float(state.get_max_angular_velocity(disabled), 6.0, "missing max angular velocity should use historical fallback")
	_expect_float(state.get_draw_angle(disabled, 98.0), 0.7, "disabled distance roll should expose the raw angle")

	var scaled := FakeProfile.new({
		"companion_distance_roll_enabled": 1.0,
		"companion_distance_roll_visual_angle_scale": 0.5,
	})
	_expect_float(state.get_draw_angle(scaled, 98.0), 0.35, "visual angle scale should apply when tilt is disabled")
	var tilted := FakeProfile.new({
		"companion_distance_roll_enabled": 1.0,
		"companion_distance_roll_visual_tilt_radians": 0.25,
	})
	_expect_float(state.get_draw_angle(tilted, 98.0), sin(0.7) * 0.25, "visual tilt should use sine wobble mode")


func _verify_runtime_delegates_distance_roll_state() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_distance_roll_state.gd")
	_expect(runtime_source.find("LingpetCompanionDistanceRollState") >= 0, "egg runtime should preload the companion distance-roll state owner")
	_expect(runtime_source.find("_companion_distance_roll_state.advance_draw_movement") >= 0, "draw animation update should delegate distance-roll advancement")
	_expect(runtime_source.find("var _companion_roll_angle") < 0, "runtime should not keep roll angle state locally")
	_expect(runtime_source.find("var _companion_roll_angular_velocity") < 0, "runtime should not keep roll velocity state locally")
	_expect(runtime_source.find("func _signed_roll_distance") < 0, "runtime should not keep the old signed distance-roll wrapper")
	_expect(runtime_source.find("func _advance_companion_distance_roll") < 0, "runtime should not keep the old distance-roll movement wrapper")
	_expect(runtime_source.find("func _advance_companion_distance_roll_coast") < 0, "runtime should not keep the old distance-roll coast wrapper")
	_expect(runtime_source.find("func _is_companion_distance_roll_enabled") < 0, "runtime should not keep the old distance-roll enabled wrapper")
	_expect(runtime_source.find("func _get_companion_distance_roll_radius") < 0, "runtime should not keep the old distance-roll radius wrapper")
	_expect(runtime_source.find("func _get_companion_distance_roll_stop_deceleration") < 0, "runtime should not keep the old distance-roll deceleration wrapper")
	_expect(runtime_source.find("func _get_companion_distance_roll_max_angular_velocity") < 0, "runtime should not keep the old distance-roll velocity-cap wrapper")
	_expect(owner_source.find("advance_draw_movement") >= 0, "distance-roll owner should own draw-position movement advancement")
	_expect(owner_source.find("signed_roll_distance") >= 0, "distance-roll owner should own signed path-distance conversion")
	_expect(owner_source.find("get_draw_angle") >= 0, "distance-roll owner should own draw-angle shaping")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_float(actual: float, expected: float, message: String, tolerance: float = 0.01) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])
