extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectInteractionFacade := preload("res://scripts/items/active_item_effect_interaction_facade.gd")

var _failures: Array[String] = []


class FakeFeedback:
	extends RefCounted

	var flash_count := 0
	var shake_strength := 0.0

	func trigger_gauge_flash() -> void:
		flash_count += 1

	func max_screen_shake(_duration: float, strength: float) -> void:
		shake_strength = max(shake_strength, strength)


class FakeNeuralHelmet:
	extends RefCounted

	func should_cancel_aipill_on_direction_key() -> bool:
		return true


func _init() -> void:
	_verify_interaction_facade()
	_verify_controller_delegates_interaction_facade()

	if _failures.is_empty():
		print("active_item_effect_interaction_facade_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_interaction_facade() -> void:
	seed(222)
	var controller: Object = ActiveItemEffectController.new()
	var facade := ActiveItemEffectInteractionFacade.new()
	var context := _build_magnet_context()

	_expect(facade.apply_magnet_field_ball_pull(controller, 1.0, context).is_empty(), "inactive facade magnet pull should be empty")
	controller.magnet_field_active = true
	var pull_result: Dictionary = facade.apply_magnet_field_ball_pull(controller, 1.0, context)
	_expect(bool(pull_result.get("magnet_field_pull_applied", false)), "interaction facade should apply magnet pull")

	facade.notify_holy_barrier_hit(controller, Vector2(200.0, 720.0), controller._holy_barrier_particles)
	_expect(controller.holy_barrier_particles.is_empty(), "inactive facade holy barrier hit should not spawn particles")
	controller.holy_barrier_active = true
	facade.notify_holy_barrier_hit(controller, Vector2(200.0, 720.0), controller._holy_barrier_particles)
	_expect(controller.holy_barrier_particles.size() > 0, "interaction facade should spawn holy barrier hit particles")

	var facade_walls: Array[Dictionary] = [_build_wall()]
	controller.brick_walls = facade_walls
	var first_hit: Dictionary = facade.notify_brick_wall_hit(controller, 0, Vector2(120.0, 710.0), 2)
	_expect(not bool(first_hit.get("destroyed", true)), "interaction facade first brick hit should keep wall")
	var second_hit: Dictionary = facade.notify_brick_wall_hit(controller, 0, Vector2(120.0, 710.0), 2)
	_expect(bool(second_hit.get("destroyed", false)), "interaction facade second brick hit should destroy wall")

	controller.aipill_active = true
	var control_result: Dictionary = facade.apply_aipill_player_control(
		controller,
		Vector2.ZERO,
		0.0,
		_build_aipill_control_config(),
		1.0 / 60.0
	)
	_expect(bool(control_result.get("handled", false)), "interaction facade should delegate AI Pill control")

	var feedback := FakeFeedback.new()
	var gauge: float = facade.apply_aipill_guard_drain(
		controller,
		100.0,
		{"selected_character_type": "smasher"},
		{"feedback": feedback},
		controller._state_applier,
		controller._effect_feedback
	)
	_expect(is_equal_approx(gauge, 10.0), "interaction facade should delegate AI Pill gauge drain")
	_expect(feedback.flash_count == 1 and feedback.shake_strength > 0.0, "interaction facade should keep AI Pill feedback")

	var helmet := FakeNeuralHelmet.new()
	_expect(facade.cancel_aipill_if_neural_helmet_direction_pressed(
		controller,
		helmet,
		true,
		controller._state_applier,
		controller._aipill_runtime
	), "interaction facade should cancel AI Pill through Neural Helmet")
	_expect(not controller.aipill_active, "interaction facade should clear AI Pill state")

	controller.stopwatch_active = true
	controller.stopwatch_original_ball_vel = Vector2(2.0, 3.0)
	facade.force_stopwatch_recovery_upward(controller, 9.0, controller._stopwatch_owner_effects)
	_expect(controller.stopwatch_original_ball_vel == Vector2(2.0, -3.0), "interaction facade should force stopwatch recovery upward")


func _verify_controller_delegates_interaction_facade() -> void:
	seed(333)
	var controller: Object = ActiveItemEffectController.new()
	controller.magnet_field_active = true
	_expect(
		bool(controller.apply_magnet_field_ball_pull(1.0, _build_magnet_context()).get("magnet_field_pull_applied", false)),
		"controller should delegate magnet pull through interaction facade"
	)

	controller.holy_barrier_active = true
	controller.notify_holy_barrier_hit(Vector2(200.0, 720.0))
	_expect(controller.holy_barrier_particles.size() > 0, "controller should delegate holy barrier hit through interaction facade")

	var controller_walls: Array[Dictionary] = [_build_wall()]
	controller.brick_walls = controller_walls
	_expect(not bool(controller.notify_brick_wall_hit(0, Vector2(120.0, 710.0)).get("destroyed", true)), "controller first brick hit should delegate")
	_expect(bool(controller.notify_brick_wall_hit(0, Vector2(120.0, 710.0)).get("destroyed", false)), "controller second brick hit should delegate")

	controller.aipill_active = true
	_expect(
		bool(controller.apply_aipill_player_control(Vector2.ZERO, 0.0, _build_aipill_control_config(), 1.0 / 60.0).get("handled", false)),
		"controller should delegate AI Pill control through interaction facade"
	)
	_expect(is_equal_approx(controller.apply_aipill_guard_drain(100.0, {"selected_character_type": "smasher"}, {}), 10.0), "controller should delegate AI Pill drain through interaction facade")

	var helmet := FakeNeuralHelmet.new()
	_expect(controller.cancel_aipill_if_neural_helmet_direction_pressed(helmet, true), "controller should delegate AI Pill cancel through interaction facade")

	controller.stopwatch_active = true
	controller.stopwatch_original_ball_vel = Vector2.ZERO
	controller.force_stopwatch_recovery_upward(9.0)
	_expect(controller.stopwatch_original_ball_vel == Vector2(0.0, -9.0), "controller should delegate stopwatch forced recovery")


func _build_magnet_context() -> Dictionary:
	return {
		"last_hit_by": "boss",
		"ball_vel": Vector2(8.0, 0.0),
		"ball_pos": Vector2(100.0, 100.0),
		"player_pos": Vector2(160.0, 250.0),
		"player_paddle_size": Vector2(80.0, 40.0),
	}


func _build_aipill_control_config() -> Dictionary:
	return {
		"paddle_width": 100.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"ball_pos": Vector2(300.0, 250.0),
		"paddle_speed": 6.0,
		"paddle_max_speed": 6.0,
	}


func _build_wall() -> Dictionary:
	return {
		"rect": Rect2(Vector2(100.0, 700.0), Vector2(80.0, 20.0)),
		"hit_count": 0,
		"crack_level": 0,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
