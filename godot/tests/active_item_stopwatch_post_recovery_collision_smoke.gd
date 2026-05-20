extends SceneTree

# Reproduces the user-reported bug:
#   "스톱워치 액티브아이템 사용 후 공이 정지되었다가 풀리고 난 뒤에 공이 타격이 안되는 버그"
# After stopwatch freeze + recovery, the ball should still be hit-able by the
# player paddle when descending. This walks through the full lifecycle and
# checks the post-recovery state, then runs collision detection at the
# expected paddle intercept position.

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const ActiveItemEffectQuery := preload("res://scripts/items/active_item_effect_query.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_pos: Vector2 = Vector2.ZERO
	var ball_vel: Vector2 = Vector2.ZERO
	var player_pos: Vector2 = Vector2(300.0, 700.0)
	var player_paddle_size: Vector2 = Vector2(155.0, 50.0)
	var player_paddle_width: float = 155.0
	var player_paddle_height: float = 50.0
	var player_collision_cooldown: float = 0.0
	var boss_collision_cooldown: float = 0.0


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}
	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_post_recovery_descending_ball_can_be_hit()
	_verify_post_recovery_no_lingering_score_blocking()
	_verify_freeze_then_recovery_collision_during_recovery()

	if _failures.is_empty():
		print("active_item_stopwatch_post_recovery_collision_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_post_recovery_descending_ball_can_be_hit() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	# Ball mid-descent toward the paddle when stopwatch is activated.
	owner.ball_pos = Vector2(360.0, 500.0)
	owner.ball_vel = Vector2(2.0, 8.0)

	_expect(controller.activate_stopwatch(owner, registry), "stopwatch should activate from a safe descent")
	_expect(controller.stopwatch_active, "stopwatch should be active after activation")
	_expect(owner.ball_vel == Vector2.ZERO, "ball should be frozen on activation")

	# Tick the freeze period (120 frames).
	for _i in range(120):
		controller.update(owner, 1.0 / 60.0)
	_expect(is_equal_approx(controller.stopwatch_timer_frames, 0.0), "freeze timer should be drained")
	_expect(is_equal_approx(controller.stopwatch_recovery_timer_frames, 60.0), "recovery timer should be armed at handoff")

	# Tick the recovery period. Simulate the ball staying in place by
	# resetting ball_pos before each tick — apply_recovery_velocity reads
	# owner.ball_vel each tick and writes the new vel.
	for _i in range(60):
		# Pretend the ball did not move (stationary scenario), so direction
		# stays original.
		controller.update(owner, 1.0 / 60.0)
	_expect(not controller.stopwatch_active, "stopwatch should be inactive after recovery completes")
	_expect(is_equal_approx(controller.stopwatch_recovery_timer_frames, 0.0), "recovery timer should be zero post-recovery")
	_expect(owner.player_collision_cooldown == 0.0, "player collision cooldown should be reset post-recovery")
	_expect(owner.boss_collision_cooldown == 0.0, "boss collision cooldown should be reset post-recovery")
	_expect(owner.ball_vel.length() > 0.01, "ball should resume motion post-recovery (non-zero velocity)")
	_expect(owner.ball_vel.y > 0.0, "ball should still be descending post-recovery, since original velocity was descending")

	# Now run the actual paddle collision detector with the realistic
	# context that ball_update_controller would build for a post-recovery
	# frame. The ball is now somewhere near the paddle and moving down.
	var detector: Object = BallMotionCollisionDetector.new()
	var ball_at_paddle: Vector2 = Vector2(360.0, 720.0)  # within paddle Y range
	var query: Object = ActiveItemEffectQuery.new()
	var stopwatch_ball_context: Dictionary = query.get_stopwatch_ball_context(controller)

	var collision_context := {
		"player_pos": owner.player_pos,
		"player_paddle_size": owner.player_paddle_size,
		"player_collision_cooldown": owner.player_collision_cooldown,
		"hitbox_padding": 5.0,
	}
	collision_context.merge(stopwatch_ball_context, true)

	var hit: Dictionary = detector.check_paddles(ball_at_paddle, owner.ball_vel, 28.6, collision_context)
	_expect(str(hit.get("event", "")) == "player_paddle", "post-recovery descending ball must hit the player paddle (got '%s')" % str(hit.get("event", "")))


func _verify_post_recovery_no_lingering_score_blocking() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	owner.ball_pos = Vector2(380.0, 400.0)
	owner.ball_vel = Vector2(0.0, 9.0)
	controller.activate_stopwatch(owner, registry)
	for _i in range(180):
		controller.update(owner, 1.0 / 60.0)

	var query: Object = ActiveItemEffectQuery.new()
	var stopwatch_ball_context: Dictionary = query.get_stopwatch_ball_context(controller)
	_expect(not bool(stopwatch_ball_context.get("stopwatch_score_blocking", true)), "stopwatch_score_blocking must be false after recovery")
	_expect(not bool(stopwatch_ball_context.get("stopwatch_freeze_active", true)), "stopwatch_freeze_active must be false after recovery")
	_expect(not bool(stopwatch_ball_context.get("stopwatch_recovery_active", true)), "stopwatch_recovery_active must be false after recovery")


func _verify_freeze_then_recovery_collision_during_recovery() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	owner.ball_pos = Vector2(360.0, 500.0)
	owner.ball_vel = Vector2(0.0, 10.0)
	controller.activate_stopwatch(owner, registry)
	for _i in range(120):
		controller.update(owner, 1.0 / 60.0)
	# One step into the recovery window.
	controller.update(owner, 1.0 / 60.0)

	_expect(controller.stopwatch_active, "stopwatch should still be active during recovery")
	_expect(controller.stopwatch_recovery_timer_frames > 0.0, "recovery timer should be positive mid-recovery")
	_expect(owner.ball_vel.y > 0.0, "ball should be moving downward during recovery (matching original direction)")

	var detector: Object = BallMotionCollisionDetector.new()
	var query: Object = ActiveItemEffectQuery.new()
	var stopwatch_ball_context: Dictionary = query.get_stopwatch_ball_context(controller)

	var collision_context := {
		"player_pos": owner.player_pos,
		"player_paddle_size": owner.player_paddle_size,
		"player_collision_cooldown": owner.player_collision_cooldown,
		"hitbox_padding": 5.0,
	}
	collision_context.merge(stopwatch_ball_context, true)

	var hit: Dictionary = detector.check_paddles(Vector2(360.0, 720.0), owner.ball_vel, 28.6, collision_context)
	_expect(str(hit.get("event", "")) == "player_paddle", "descending recovery ball must hit player paddle")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
