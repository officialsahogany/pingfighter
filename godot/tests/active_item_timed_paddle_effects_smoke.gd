extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectStateApplier := preload("res://scripts/items/active_item_effect_state_applier.gd")
const ActiveItemTimedPaddleEffects := preload("res://scripts/items/active_item_timed_paddle_effects.gd")

var _failures: Array[String] = []


class FakeTarget:
	extends RefCounted

	var long_boost_active := false
	var long_boost_timer_frames := 0.0
	var long_boost_initial_timer_frames := 0.0
	var long_boost_scale := 1.0
	var vitamin_pill_active := false
	var vitamin_pill_timer_frames := 0.0
	var vitamin_pill_initial_timer_frames := 0.0
	var vitamin_pill_phase := 0.0
	var vitamin_pill_flash_timer_frames := 0.0
	var vitamin_pill_player_center := Vector2.ZERO
	var strange_vial_active := false
	var strange_vial_timer_frames := 0.0
	var strange_vial_initial_timer_frames := 0.0
	var strange_vial_effect_type := ""
	var strange_vial_scale := 1.0
	var strange_vial_target_scale := 1.0
	var strange_vial_speed_multiplier := 1.0
	var strange_vial_target_speed_multiplier := 1.0
	var strange_vial_phase := 0.0
	var strange_vial_flash_timer_frames := 0.0
	var strange_vial_player_center := Vector2.ZERO


func _init() -> void:
	_verify_helper_transitions()
	_verify_helper_update_application()
	_verify_controller_delegates_timed_paddle_effects()

	if _failures.is_empty():
		print("active_item_timed_paddle_effects_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_transitions() -> void:
	var helper: Object = ActiveItemTimedPaddleEffects.new()
	var center := Vector2(320.0, 700.0)

	var long_boost: Dictionary = helper.start_long_boost()
	_expect(bool(long_boost.get("active", false)), "long boost should start active")
	long_boost = helper.update_long_boost(true, 480.0, 480.0, 0.5)
	_expect(is_equal_approx(float(long_boost.get("scale", 0.0)), 1.25), "long boost should grow across transition")
	long_boost = helper.update_long_boost(true, 1.0, 480.0, 1.0 / 60.0)
	_expect(not bool(long_boost.get("active", true)), "long boost should clear at expiry")

	var vitamin: Dictionary = helper.start_vitamin_pill(center)
	_expect(is_equal_approx(float(vitamin.get("timer_frames", 0.0)), 600.0), "vitamin pill should use reference duration")
	vitamin = helper.update_vitamin_pill(true, 600.0, 600.0, 0.0, 10.0, center, 1.0 / 60.0)
	_expect(is_equal_approx(float(vitamin.get("timer_frames", 0.0)), 599.0), "vitamin pill should tick by fps scale")
	_expect(is_equal_approx(float(vitamin.get("phase", 0.0)), 0.18), "vitamin pill should advance visual phase")
	_expect(is_equal_approx(float(vitamin.get("flash_timer_frames", 0.0)), 9.0), "vitamin pill should tick flash timer")

	var vial: Dictionary = helper.start_strange_vial(true, center)
	_expect(str(vial.get("effect_type", "")) == "enlarge", "strange vial should expose chosen effect type")
	vial = helper.update_strange_vial(true, 600.0, 600.0, "enlarge", 2.2, 0.5, 0.0, 12.0, center, 22.5 / 60.0)
	_expect(is_equal_approx(float(vial.get("scale", 0.0)), 1.6), "strange vial should ease paddle scale during grow transition")
	_expect(is_equal_approx(float(vial.get("speed_multiplier", 0.0)), 0.75), "strange vial should ease speed during grow transition")
	vial = helper.update_strange_vial(true, 1.0, 600.0, "enlarge", 2.2, 0.5, 0.0, 1.0, center, 1.0 / 60.0)
	_expect(not bool(vial.get("active", true)), "strange vial should clear at expiry")
	_expect(_get_vector2(vial, "player_center", Vector2.ZERO) == helper.get_default_player_center(), "strange vial expiry should reset the render anchor")


func _verify_helper_update_application() -> void:
	var helper: Object = ActiveItemTimedPaddleEffects.new()
	var applier: Object = ActiveItemEffectStateApplier.new()
	var target := FakeTarget.new()
	var center := Vector2(320.0, 700.0)

	target.long_boost_active = true
	target.long_boost_timer_frames = 480.0
	target.long_boost_initial_timer_frames = 480.0
	helper.apply_update_long_boost(
		target,
		target.long_boost_active,
		target.long_boost_timer_frames,
		target.long_boost_initial_timer_frames,
		0.5,
		applier
	)
	_expect(is_equal_approx(target.long_boost_scale, 1.25), "timed paddle helper should apply long boost transition")

	target.vitamin_pill_active = true
	target.vitamin_pill_timer_frames = 600.0
	target.vitamin_pill_initial_timer_frames = 600.0
	target.vitamin_pill_flash_timer_frames = 10.0
	helper.apply_update_vitamin_pill(
		target,
		target.vitamin_pill_active,
		target.vitamin_pill_timer_frames,
		target.vitamin_pill_initial_timer_frames,
		target.vitamin_pill_phase,
		target.vitamin_pill_flash_timer_frames,
		center,
		1.0 / 60.0,
		applier
	)
	_expect(is_equal_approx(target.vitamin_pill_timer_frames, 599.0), "timed paddle helper should apply vitamin timer tick")
	_expect(is_equal_approx(target.vitamin_pill_phase, 0.18), "timed paddle helper should apply vitamin phase tick")
	_expect(target.vitamin_pill_player_center == center, "timed paddle helper should apply vitamin center")

	target.strange_vial_active = true
	target.strange_vial_timer_frames = 1.0
	target.strange_vial_initial_timer_frames = 600.0
	target.strange_vial_effect_type = "enlarge"
	target.strange_vial_target_scale = 2.2
	target.strange_vial_target_speed_multiplier = 0.5
	helper.apply_update_strange_vial(
		target,
		target.strange_vial_active,
		target.strange_vial_timer_frames,
		target.strange_vial_initial_timer_frames,
		target.strange_vial_effect_type,
		target.strange_vial_target_scale,
		target.strange_vial_target_speed_multiplier,
		target.strange_vial_phase,
		target.strange_vial_flash_timer_frames,
		center,
		1.0 / 60.0,
		applier
	)
	_expect(not target.strange_vial_active, "timed paddle helper should apply strange vial expiry")
	_expect(target.strange_vial_player_center == helper.get_default_player_center(), "timed paddle helper should apply strange vial default center on expiry")


func _verify_controller_delegates_timed_paddle_effects() -> void:
	var controller: Object = ActiveItemEffectController.new()
	_expect(controller.activate_long_boost(null, null), "controller should activate delegated long boost state")
	controller.update(null, 0.5)
	_expect(is_equal_approx(controller.long_boost_scale, 1.25), "controller should apply delegated long boost transition")

	_expect(controller.activate_vitamin_pill(null, null), "controller should activate delegated vitamin pill state")
	controller.update(null, 1.0 / 60.0)
	_expect(is_equal_approx(controller.vitamin_pill_timer_frames, 599.0), "controller should apply delegated vitamin pill timer")
	_expect(is_equal_approx(controller.vitamin_pill_phase, 0.18), "controller should apply delegated vitamin pill phase")

	seed(7)
	_expect(controller.activate_strange_vial(null, null), "controller should activate delegated strange vial state")
	_expect(controller.strange_vial_effect_type in ["enlarge", "shrink"], "controller should apply delegated strange vial effect choice")
	controller.strange_vial_timer_frames = 1.0
	controller.update(null, 1.0 / 60.0)
	_expect(not controller.strange_vial_active, "controller should clear delegated strange vial expiry")
	var helper: Object = ActiveItemTimedPaddleEffects.new()
	_expect(controller.strange_vial_player_center == helper.get_default_player_center(), "controller should reset strange vial center on expiry")


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
