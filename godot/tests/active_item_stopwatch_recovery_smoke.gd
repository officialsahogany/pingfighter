extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemStopwatchRecovery := preload("res://scripts/items/active_item_stopwatch_recovery.gd")
const ActiveItemStopwatchOwnerEffects := preload("res://scripts/items/active_item_stopwatch_owner_effects.gd")
const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_vel: Vector2 = Vector2.ZERO
	var player_collision_cooldown := 99.0
	var boss_collision_cooldown := 99.0


func _init() -> void:
	_verify_direct_recovery_math()
	_verify_owner_effects_delegate_recovery_math()
	_verify_owner_effects_force_recovery_upward()
	_verify_controller_delegates_recovery_ratio()
	_verify_controller_delegates_force_recovery_upward()
	_verify_recovery_upward_paddle_collision()

	if _failures.is_empty():
		print("active_item_stopwatch_recovery_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_recovery_math() -> void:
	var recovery: Object = ActiveItemStopwatchRecovery.new()

	_expect(is_equal_approx(recovery.get_recovery_speed_ratio(0.0), 1.0), "empty stopwatch recovery should expose full speed")
	_expect(is_equal_approx(recovery.get_recovery_speed_ratio(60.0), 0.30), "fresh stopwatch recovery should start at minimum speed")
	_expect(is_equal_approx(recovery.get_recovery_speed_ratio(30.0), 0.5), "mid stopwatch recovery should use linear speed ramp")

	var directed: Dictionary = recovery.build_recovery_velocity_result(Vector2(0.0, -12.0), Vector2(12.0, 0.0), 0.5)
	_expect(bool(directed.get("has_velocity", false)), "recovery should build velocity when original speed exists")
	_expect(directed.get("ball_vel", Vector2.ZERO).is_equal_approx(Vector2(6.0, 0.0)), "recovery should preserve current direction and scale original speed")

	var fallback: Dictionary = recovery.build_recovery_velocity_result(Vector2(0.0, -12.0), Vector2.ZERO, 0.5)
	_expect(fallback.get("ball_vel", Vector2.ZERO).is_equal_approx(Vector2(0.0, -6.0)), "recovery should fall back to original direction when current velocity is empty")

	var no_original_speed: Dictionary = recovery.build_recovery_velocity_result(Vector2.ZERO, Vector2(8.0, 0.0), 0.5)
	_expect(not bool(no_original_speed.get("has_velocity", true)), "recovery should skip velocity writes without original speed")


func _verify_owner_effects_delegate_recovery_math() -> void:
	var owner_effects: Object = ActiveItemStopwatchOwnerEffects.new()
	var owner := FakeOwner.new()

	owner.ball_vel = Vector2(12.0, 0.0)
	owner_effects.apply_recovery_velocity(owner, Vector2(0.0, -12.0), 0.5)
	_expect(owner.ball_vel.is_equal_approx(Vector2(6.0, 0.0)), "owner effects should delegate stopwatch recovery velocity")

	owner.ball_vel = Vector2(9.0, 0.0)
	owner_effects.apply_update_actions(owner, {
		"freeze_ball": true,
	}, Vector2.ZERO)
	_expect(owner.ball_vel == Vector2.ZERO, "owner effects should apply delegated freeze-ball action")

	owner.ball_vel = Vector2.ZERO
	owner.player_collision_cooldown = 99.0
	owner.boss_collision_cooldown = 99.0
	owner_effects.apply_update_actions(owner, {
		"apply_recovery_velocity": true,
		"apply_final_recovery_velocity": true,
		"reset_collision_cooldowns": true,
		"recovery_timer_for_velocity": 0.0,
		"recovery_original_ball_vel": Vector2(0.0, -12.0),
	}, Vector2.ZERO)
	_expect(owner.ball_vel == Vector2(0.0, -12.0), "owner effects should apply delegated final recovery velocity")
	_expect(owner.player_collision_cooldown == 0.0 and owner.boss_collision_cooldown == 0.0, "owner effects should apply delegated collision cooldown reset")


func _verify_owner_effects_force_recovery_upward() -> void:
	var owner_effects: Object = ActiveItemStopwatchOwnerEffects.new()

	var inactive_vel: Vector2 = owner_effects.force_recovery_velocity_upward(false, Vector2(3.0, 5.0), 7.65)
	_expect(inactive_vel.is_equal_approx(Vector2(3.0, 5.0)), "owner effects should not force inactive stopwatch recovery velocity")

	var downward_vel: Vector2 = owner_effects.force_recovery_velocity_upward(true, Vector2(3.0, 5.0), 7.65)
	_expect(downward_vel.is_equal_approx(Vector2(3.0, -5.0)), "owner effects should force stored recovery velocity upward")

	var flat_vel: Vector2 = owner_effects.force_recovery_velocity_upward(true, Vector2(3.0, 0.001), 8.5)
	_expect(flat_vel.is_equal_approx(Vector2(3.0, -8.5)), "owner effects should use minimum upward recovery speed for flat stored velocity")


func _verify_controller_delegates_recovery_ratio() -> void:
	var controller: Object = ActiveItemEffectController.new()

	controller.stopwatch_recovery_timer_frames = 30.0
	_expect(is_equal_approx(controller.call("_get_stopwatch_recovery_speed_ratio"), 0.5), "controller should delegate stopwatch recovery ratio")


func _verify_controller_delegates_force_recovery_upward() -> void:
	var controller: Object = ActiveItemEffectController.new()

	controller.stopwatch_active = false
	controller.stopwatch_original_ball_vel = Vector2(2.0, 4.0)
	controller.force_stopwatch_recovery_upward(9.0)
	_expect(controller.stopwatch_original_ball_vel.is_equal_approx(Vector2(2.0, 4.0)), "controller should preserve inactive stopwatch recovery velocity through owner effects")

	controller.stopwatch_active = true
	controller.stopwatch_original_ball_vel = Vector2(2.0, 4.0)
	controller.force_stopwatch_recovery_upward(9.0)
	_expect(controller.stopwatch_original_ball_vel.is_equal_approx(Vector2(2.0, -4.0)), "controller should delegate upward stopwatch recovery velocity forcing")

	controller.stopwatch_original_ball_vel = Vector2(2.0, 0.0)
	controller.force_stopwatch_recovery_upward(9.0)
	_expect(controller.stopwatch_original_ball_vel.is_equal_approx(Vector2(2.0, -9.0)), "controller should delegate minimum upward stopwatch recovery velocity forcing")


func _verify_recovery_upward_paddle_collision() -> void:
	var detector: Object = BallMotionCollisionDetector.new()
	var context := {
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_collision_cooldown": 0.0,
		"hitbox_padding": 5.0,
	}

	var normal_upward_hit: Dictionary = detector.check_paddles(
		Vector2(360.0, 725.0),
		Vector2(0.0, -8.0),
		28.6,
		context
	)
	_expect(normal_upward_hit.is_empty(), "normal upward ball should still ignore the player paddle")

	var recovery_context: Dictionary = context.duplicate()
	recovery_context["stopwatch_recovery_active"] = true
	var recovery_hit: Dictionary = detector.check_paddles(
		Vector2(360.0, 725.0),
		Vector2(0.0, -8.0),
		28.6,
		recovery_context
	)
	_expect(str(recovery_hit.get("event", "")) == "player_paddle", "stopwatch recovery should let an upward ball hit the player paddle")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
