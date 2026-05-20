extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectContextBuilder := preload("res://scripts/items/active_item_effect_context_builder.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_contexts()
	_verify_controller_delegates_contexts()

	if _failures.is_empty():
		print("active_item_effect_context_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_contexts() -> void:
	var builder: Object = ActiveItemEffectContextBuilder.new()

	var magnet: Dictionary = builder.build_magnet_field_context(true, 120.0, 480.0, 1.25, Vector2(10.0, 20.0))
	_expect(bool(magnet.get("active", false)), "magnet context should preserve active flag")
	_expect(is_equal_approx(float(magnet.get("remaining_ratio", -1.0)), 0.25), "magnet remaining ratio should use timer / initial timer")
	_expect(magnet.get("player_center", Vector2.ZERO) == Vector2(10.0, 20.0), "magnet context should preserve player center")

	var holy_collision: Dictionary = builder.build_holy_barrier_collision_context(true)
	_expect(bool(holy_collision.get("holy_barrier_active", false)), "holy barrier collision context should preserve active flag")
	_expect(is_equal_approx(float(holy_collision.get("holy_barrier_y", 0.0)), 725.0), "holy barrier collision y should match bottom wall contract")

	var stopwatch: Dictionary = builder.build_stopwatch_ball_context(true, 0.0, 20.0, 0.0, 0.4, Vector2(0.0, -12.0))
	_expect(bool(stopwatch.get("stopwatch_recovery_active", false)), "stopwatch ball context should mark recovery while timer is empty and recovery remains")
	_expect(is_equal_approx(float(stopwatch.get("stopwatch_recovery_speed_ratio", -1.0)), 0.4), "stopwatch ball context should expose recovery speed ratio")
	_expect(not bool(stopwatch.get("stopwatch_post_recovery_grace_active", true)), "active stopwatch should not mark post-recovery grace")

	var grace: Dictionary = builder.build_stopwatch_ball_context(false, 0.0, 0.0, 8.0, 1.0, Vector2.ZERO)
	_expect(bool(grace.get("stopwatch_post_recovery_grace_active", false)), "post-recovery grace ball context should mark grace flag while frames remain")
	_expect(not bool(grace.get("stopwatch_recovery_active", true)), "post-recovery grace must not reactivate recovery flag")


func _verify_controller_delegates_contexts() -> void:
	var controller: Object = ActiveItemEffectController.new()
	controller.vitamin_pill_active = true
	controller.vitamin_pill_timer_frames = 300.0
	controller.vitamin_pill_initial_timer_frames = 600.0
	controller.vitamin_pill_phase = 2.0
	controller.vitamin_pill_flash_timer_frames = 4.0
	controller.vitamin_pill_player_center = Vector2(320.0, 700.0)

	var vitamin: Dictionary = controller.get_vitamin_pill_timer_context()
	_expect(bool(vitamin.get("active", false)), "controller should delegate vitamin active context")
	_expect(is_equal_approx(float(vitamin.get("speed_multiplier", 0.0)), 1.5), "controller should expose active vitamin speed multiplier")
	_expect(vitamin.get("player_center", Vector2.ZERO) == Vector2(320.0, 700.0), "controller should expose vitamin player center")

	controller.holy_barrier_active = true
	var holy: Dictionary = controller.get_holy_barrier_context()
	_expect(is_equal_approx(float(holy.get("barrier_y", 0.0)), 725.0), "controller should delegate holy barrier render context")
	var holy_collision: Dictionary = controller.get_holy_barrier_collision_context()
	_expect(bool(holy_collision.get("holy_barrier_active", false)), "controller should delegate holy barrier collision context")

	controller.stopwatch_active = true
	controller.stopwatch_timer_frames = 0.0
	controller.stopwatch_recovery_timer_frames = 30.0
	controller.stopwatch_original_ball_vel = Vector2(0.0, -9.0)
	var stopwatch: Dictionary = controller.get_stopwatch_ball_context()
	_expect(bool(stopwatch.get("stopwatch_score_blocking", false)), "controller should preserve stopwatch score blocking")
	_expect(bool(stopwatch.get("stopwatch_recovery_active", false)), "controller should preserve stopwatch recovery context")
	_expect(is_equal_approx(float(stopwatch.get("stopwatch_recovery_speed_ratio", 0.0)), 0.5), "controller should compute stopwatch recovery ratio before delegation")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
