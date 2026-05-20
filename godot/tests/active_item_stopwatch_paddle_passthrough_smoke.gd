extends SceneTree

# Tries to reproduce the user-reported bug:
#   "공이 보이는데 패들이 통과해버림"
# Hypothesis: when stopwatch recovery completes WHILE the ball is overlapping
# the player paddle going upward, the post-recovery frame loses
# `stopwatch_recovery_active`, so the upward-catch special case turns off and
# the paddle fails to bounce the upward-moving ball that is still physically
# inside the paddle hitbox. The ball then leaks UP through the paddle.

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
	# Variant 1: ball just above paddle, descending. Stopwatch fires.
	# After recovery, can the paddle still hit a slow upward bounce?
	_simulate_ball_just_above_paddle()
	# Variant 2: ball that bounces inside paddle during recovery.
	# After recovery, the ball is inside the paddle moving up. Does the paddle
	# catch it?
	_simulate_recovery_ends_with_ball_inside_paddle_going_up()

	if _failures.is_empty():
		print("active_item_stopwatch_paddle_passthrough_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _simulate_ball_just_above_paddle() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var detector: Object = BallMotionCollisionDetector.new()
	var query: Object = ActiveItemEffectQuery.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()

	# Ball just above paddle, descending. Activation should still pass safe
	# distance (x distance > 35 OR y distance > 35).
	owner.ball_pos = Vector2(360.0, 680.0)  # 45 px above paddle top (700), 60 px from player center (725)
	owner.ball_vel = Vector2(0.0, 9.0)
	_expect(controller.activate_stopwatch(owner, registry), "ball-just-above-paddle activation should succeed")

	var max_frames := 220
	var ball_size := 28.6
	var height := 750.0
	var fps_scale := 1.0
	var _saw_passthrough_after_recovery := false
	var first_post_recovery_frame := -1
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

		if not bool(stopwatch_ball_context.get("stopwatch_freeze_active", false)):
			# Move ball one step.
			owner.ball_pos += owner.ball_vel * fps_scale

			# Try paddle collision.
			var hit: Dictionary = detector.check_paddles(owner.ball_pos, owner.ball_vel, ball_size, collision_context)
			if str(hit.get("event", "")) == "player_paddle":
				owner.ball_vel.y = -abs(owner.ball_vel.y)
				owner.ball_pos.y = owner.player_pos.y - ball_size * 0.5

			# After recovery completes, check if ball is overlapping paddle but
			# moving up and the detector returns no hit (the bug condition).
			if not controller.stopwatch_active:
				if first_post_recovery_frame < 0:
					first_post_recovery_frame = frame_index
				var paddle_top: float = owner.player_pos.y
				var paddle_bottom: float = paddle_top + owner.player_paddle_size.y
				var ball_top: float = owner.ball_pos.y - ball_size * 0.5
				var ball_bottom: float = owner.ball_pos.y + ball_size * 0.5
				var overlapping_y: bool = ball_bottom >= paddle_top and ball_top <= paddle_bottom
				var aligned_x: bool = abs(owner.ball_pos.x - (owner.player_pos.x + owner.player_paddle_size.x * 0.5)) < owner.player_paddle_size.x * 0.5
				if overlapping_y and aligned_x and owner.ball_vel.y < 0.0 and hit.is_empty():
					_saw_passthrough_after_recovery = true
					_failures.append(
						"BUG: paddle passed through upward ball after recovery (frame %d, ball_pos=%s, ball_vel=%s)" % [
							frame_index,
							str(owner.ball_pos),
							str(owner.ball_vel),
						]
					)
					return

			# Score line.
			if owner.ball_pos.y > height:
				if bool(collision_context.get("stopwatch_score_blocking", false)):
					owner.ball_pos.y = height - ball_size * 0.5
				else:
					return  # boss scored, end this scenario


func _simulate_recovery_ends_with_ball_inside_paddle_going_up() -> void:
	# Manually craft state where recovery is about to end and the ball is
	# inside the paddle going up. Then advance one frame and check if the
	# paddle catches.
	var controller: Object = ActiveItemEffectController.new()
	var detector: Object = BallMotionCollisionDetector.new()
	var query: Object = ActiveItemEffectQuery.new()
	var owner := FakeOwner.new()

	# Ball is inside paddle hitbox, moving slowly upward. Stopwatch recovery
	# is about to expire on the next tick.
	controller.stopwatch_active = true
	controller.stopwatch_timer_frames = 0.0
	controller.stopwatch_initial_timer_frames = 120.0
	controller.stopwatch_recovery_timer_frames = 1.0
	controller.stopwatch_original_ball_vel = Vector2(0.0, 9.0)  # original was downward
	owner.ball_pos = Vector2(360.0, 720.0)  # inside paddle (y=700-750)
	owner.ball_vel = Vector2(0.0, -3.0)  # currently going up (post-bounce)

	# Advance one frame (which completes recovery).
	controller.update(owner, 1.0 / 60.0)
	_expect(not controller.stopwatch_active, "recovery should complete on this tick")

	# Now check if a hypothetical paddle check would catch the ball.
	var stopwatch_ball_context: Dictionary = query.get_stopwatch_ball_context(controller)
	var collision_context := {
		"player_pos": owner.player_pos,
		"player_paddle_size": owner.player_paddle_size,
		"player_collision_cooldown": owner.player_collision_cooldown,
		"hitbox_padding": 5.0,
	}
	collision_context.merge(stopwatch_ball_context, true)

	# Final recovery sets ball_vel to direction*orig_speed. Since current_vel
	# was (0, -3) at start of update, direction = (0, -1), orig_speed = 9, so
	# ball_vel becomes (0, -9). Ball is now moving up at full speed.
	# stopwatch_recovery_active is false (recovery completed) so the upward-
	# catch special case is OFF.
	# Ball is still at y=720, inside paddle.
	var hit: Dictionary = detector.check_paddles(owner.ball_pos, owner.ball_vel, 28.6, collision_context)
	if hit.is_empty() and owner.ball_vel.y < 0.0:
		# This is the bug: ball overlaps paddle, going up, but no paddle hit
		# because recovery_active is now false.
		_failures.append(
			"BUG REPRODUCED: ball at %s moving %s overlaps paddle but post-recovery upward-catch was rejected (collision_context=%s)" % [
				str(owner.ball_pos),
				str(owner.ball_vel),
				str(collision_context),
			]
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
