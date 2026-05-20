extends SceneTree

const ActiveItemAipillBehavior := preload("res://scripts/items/active_item_aipill_behavior.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")

var _failures: Array[String] = []


class FakeFeedback:
	extends RefCounted

	var flash_count := 0
	var shake_strength := 0.0

	func trigger_gauge_flash() -> void:
		flash_count += 1

	func max_screen_shake(_duration: float, strength: float) -> void:
		shake_strength = max(shake_strength, strength)


func _init() -> void:
	_verify_direct_player_control()
	_verify_direct_guard_drain()
	_verify_controller_delegates_aipill_behavior()

	if _failures.is_empty():
		print("active_item_aipill_behavior_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_player_control() -> void:
	var behavior: Object = ActiveItemAipillBehavior.new()
	var config := {
		"paddle_width": 100.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"ball_pos": Vector2(300.0, 250.0),
		"paddle_speed": 6.0,
		"paddle_max_speed": 6.0,
	}

	_expect(not bool(behavior.apply_player_control(false, Vector2.ZERO, config, 1.0 / 60.0).get("handled", true)), "inactive AI Pill should not handle player control")
	var result: Dictionary = behavior.apply_player_control(true, Vector2.ZERO, config, 1.0 / 60.0)
	_expect(bool(result.get("handled", false)), "active AI Pill should handle player control")
	_expect(result.get("player_pos", Vector2.ZERO) == Vector2(24.0, 0.0), "AI Pill should move toward the ball using boosted speed")
	_expect(is_equal_approx(float(result.get("player_speed", 0.0)), 24.0), "AI Pill should expose frame speed")


func _verify_direct_guard_drain() -> void:
	var behavior: Object = ActiveItemAipillBehavior.new()
	var inactive: Dictionary = behavior.build_guard_drain_result(false, 100.0, {})
	_expect(is_equal_approx(float(inactive.get("special_gauge", 0.0)), 100.0), "inactive AI Pill should keep gauge")
	_expect(not bool(inactive.get("feedback", true)), "inactive AI Pill should not request feedback")

	var smasher: Dictionary = behavior.build_guard_drain_result(true, 100.0, {"selected_character_type": "smasher"})
	_expect(is_equal_approx(float(smasher.get("special_gauge", 0.0)), 10.0), "AI Pill should drain 90 gauge for non-Optimus")
	_expect(bool(smasher.get("flash", false)) and bool(smasher.get("feedback", false)), "non-Optimus drain should request flash and feedback")
	_expect(not bool(smasher.get("clear_aipill", true)), "AI Pill should stay active while gauge remains")

	var depleted: Dictionary = behavior.build_guard_drain_result(true, 80.0, {"selected_character_type": "smasher"})
	_expect(is_equal_approx(float(depleted.get("special_gauge", -1.0)), 0.0), "AI Pill drain should clamp gauge to zero")
	_expect(bool(depleted.get("clear_aipill", false)), "AI Pill should clear when gauge is depleted")

	var optimus: Dictionary = behavior.build_guard_drain_result(true, 50.0, {"selected_character_type": "optimus"})
	_expect(is_equal_approx(float(optimus.get("special_gauge", 0.0)), 50.0), "Optimus AI Pill guard drain should preserve gauge")
	_expect(not bool(optimus.get("feedback", true)), "Optimus AI Pill guard drain should not request feedback")


func _verify_controller_delegates_aipill_behavior() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var config := {
		"paddle_width": 100.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"ball_pos": Vector2(300.0, 250.0),
		"paddle_speed": 6.0,
		"paddle_max_speed": 6.0,
	}

	_expect(not bool(controller.apply_aipill_player_control(Vector2.ZERO, 0.0, config, 1.0 / 60.0).get("handled", true)), "inactive controller AI Pill should not handle player control")
	controller.aipill_active = true
	var control_result: Dictionary = controller.apply_aipill_player_control(Vector2.ZERO, 0.0, config, 1.0 / 60.0)
	_expect(control_result.get("player_pos", Vector2.ZERO) == Vector2(24.0, 0.0), "controller should delegate AI Pill player control")

	var feedback := FakeFeedback.new()
	var gauge: float = controller.apply_aipill_guard_drain(100.0, {"selected_character_type": "smasher"}, {"feedback": feedback})
	_expect(is_equal_approx(gauge, 10.0), "controller should delegate AI Pill gauge drain")
	_expect(is_equal_approx(controller.aipill_flash_timer_frames, 12.0), "controller should keep AI Pill flash side effect")
	_expect(feedback.flash_count == 1 and feedback.shake_strength > 0.0, "controller should keep AI Pill feedback side effects")

	gauge = controller.apply_aipill_guard_drain(10.0, {"selected_character_type": "smasher"}, {})
	_expect(is_equal_approx(gauge, 0.0), "controller should drain remaining AI Pill gauge")
	_expect(not controller.aipill_active, "controller should clear AI Pill when gauge depletes")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
