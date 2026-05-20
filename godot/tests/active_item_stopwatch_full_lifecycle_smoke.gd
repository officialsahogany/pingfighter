extends SceneTree

# Reproduces the user-reported bug "공이 보이는데 패들이 통과해버림" by simulating
# the full per-frame loop:
#   stopwatch update (active items) -> ball motion + collision -> snapshot apply
# across freeze + recovery + post-recovery, with the paddle parked under the
# ball x. We track every paddle bounce and the final ball velocity direction.

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectQuery := preload("res://scripts/items/active_item_effect_query.gd")
const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")

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
	_simulate_descending_ball_caught_in_recovery_window()
	_simulate_descending_ball_above_paddle()

	if _failures.is_empty():
		print("active_item_stopwatch_full_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


# Simulates: stopwatch activated when ball is descending TOWARD the paddle
# (a few px above it). During recovery's slow phase, the paddle catches the
# ball. The recovery should let the bounce land naturally.
func _simulate_descending_ball_caught_in_recovery_window() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var detector: Object = BallMotionCollisionDetector.new()
	var query: Object = ActiveItemEffectQuery.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	owner.ball_pos = Vector2(360.0, 600.0)  # well above paddle
	owner.ball_vel = Vector2(0.0, 9.0)  # descending
	_expect(controller.activate_stopwatch(owner, registry), "activation should succeed for safe descending ball")

	var max_frames := 120 + 60 + 30  # freeze + recovery + grace
	var saw_paddle_bounce := false
	var post_recovery_first_vel := Vector2.ZERO
	var _post_recovery_first_pos := Vector2.ZERO
	var ball_size := 28.6
	var width := 760.0
	var height := 750.0
	var fps_scale := 1.0
	for frame_index in range(max_frames):
		# Step 1: active items (stopwatch) update.
		controller.update(owner, 1.0 / 60.0)

		# Build the per-frame collision context using the real query helper.
		var stopwatch_ball_context: Dictionary = query.get_stopwatch_ball_context(controller)
		var collision_context := {
			"player_pos": owner.player_pos,
			"player_paddle_size": owner.player_paddle_size,
			"player_collision_cooldown": owner.player_collision_cooldown,
			"hitbox_padding": 5.0,
		}
		collision_context.merge(stopwatch_ball_context, true)

		# Step 2: simulate ball motion in the absence of the freeze.
		if bool(stopwatch_ball_context.get("stopwatch_freeze_active", false)):
			# Frozen — ball stays put.
			pass
		else:
			# Move the ball one frame's worth.
			owner.ball_pos += owner.ball_vel * fps_scale

			# Wall bounce on left / right.
			if owner.ball_pos.x - ball_size * 0.5 <= 0.0:
				owner.ball_pos.x = ball_size * 0.5
				owner.ball_vel.x = abs(owner.ball_vel.x)
			elif owner.ball_pos.x + ball_size * 0.5 >= width:
				owner.ball_pos.x = width - ball_size * 0.5
				owner.ball_vel.x = -abs(owner.ball_vel.x)

			# Paddle collision check (player only).
			var hit: Dictionary = detector.check_paddles(owner.ball_pos, owner.ball_vel, ball_size, collision_context)
			if str(hit.get("event", "")) == "player_paddle":
				saw_paddle_bounce = true
				# Simple bounce: reverse y and slow down a bit.
				owner.ball_vel.y = -abs(owner.ball_vel.y)
				owner.ball_pos.y = owner.player_pos.y - ball_size * 0.5

			# Top wall (boss area) — bounce down.
			if owner.ball_pos.y < 0.0:
				owner.ball_pos.y = 0.0
				owner.ball_vel.y = abs(owner.ball_vel.y)

			# Score blocking: the ball must not get past the bottom while
			# the score blocking flag is true, but if the flag is OFF and
			# the ball goes past the bottom, that's a score loss.
			if owner.ball_pos.y > height:
				if bool(collision_context.get("stopwatch_score_blocking", false)):
					owner.ball_pos.y = height - ball_size * 0.5
				else:
					_failures.append("BUG: ball passed paddle and scored after stopwatch lifecycle (frame %d, ball_vel=%s, recovery_active=%s)" % [
						frame_index,
						str(owner.ball_vel),
						str(stopwatch_ball_context.get("stopwatch_recovery_active", false)),
					])
					return

		# Track first post-recovery ball state.
		if not controller.stopwatch_active and post_recovery_first_vel == Vector2.ZERO and owner.ball_vel.length() > 0.01:
			post_recovery_first_vel = owner.ball_vel
			_post_recovery_first_pos = owner.ball_pos

	_expect(saw_paddle_bounce, "paddle should have bounced the ball at least once during the lifecycle")
	_expect(post_recovery_first_vel.length() > 0.01, "ball must have non-zero velocity after recovery completes")


# Simulates: stopwatch activated when ball is ABOVE paddle moving down. The
# ball should descend during recovery and land on the paddle naturally.
func _simulate_descending_ball_above_paddle() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var detector: Object = BallMotionCollisionDetector.new()
	var query: Object = ActiveItemEffectQuery.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	owner.ball_pos = Vector2(360.0, 200.0)  # high above
	owner.ball_vel = Vector2(0.0, 8.0)  # descending
	_expect(controller.activate_stopwatch(owner, registry), "activation should succeed")

	var max_frames := 400
	var saw_paddle_bounce := false
	var ball_size := 28.6
	var width := 760.0
	var height := 750.0
	var fps_scale := 1.0
	for frame_index in range(max_frames):
		controller.update(owner, 1.0 / 60.0)

		var stopwatch_ball_context: Dictionary = query.get_stopwatch_ball_context(controller)
		var collision_context := {
			"player_pos": owner.player_pos,
			"player_paddle_size": owner.player_paddle_size,
			"player_collision_cooldown": owner.player_collision_cooldown,
			"hitbox_padding": 5.0,
		}
		collision_context.merge(stopwatch_ball_context, true)

		if bool(stopwatch_ball_context.get("stopwatch_freeze_active", false)):
			pass
		else:
			owner.ball_pos += owner.ball_vel * fps_scale
			if owner.ball_pos.x - ball_size * 0.5 <= 0.0:
				owner.ball_pos.x = ball_size * 0.5
				owner.ball_vel.x = abs(owner.ball_vel.x)
			elif owner.ball_pos.x + ball_size * 0.5 >= width:
				owner.ball_pos.x = width - ball_size * 0.5
				owner.ball_vel.x = -abs(owner.ball_vel.x)

			var hit: Dictionary = detector.check_paddles(owner.ball_pos, owner.ball_vel, ball_size, collision_context)
			if str(hit.get("event", "")) == "player_paddle":
				saw_paddle_bounce = true
				owner.ball_vel.y = -abs(owner.ball_vel.y)
				owner.ball_pos.y = owner.player_pos.y - ball_size * 0.5
				break

			if owner.ball_pos.y < 0.0:
				owner.ball_pos.y = 0.0
				owner.ball_vel.y = abs(owner.ball_vel.y)
			if owner.ball_pos.y > height:
				if bool(collision_context.get("stopwatch_score_blocking", false)):
					owner.ball_pos.y = height - ball_size * 0.5
				else:
					_failures.append("BUG: above-paddle ball passed paddle without bounce after stopwatch ended (frame %d, ball_vel=%s)" % [
						frame_index,
						str(owner.ball_vel),
					])
					return

	_expect(saw_paddle_bounce, "high-ball stopwatch lifecycle: paddle should eventually catch the descending ball")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
