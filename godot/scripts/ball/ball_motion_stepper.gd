extends RefCounted

const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")

const EVENT_NONE := "none"
const EVENT_PLAYER_SCORED := "player_scored"
const EVENT_BOSS_SCORED := "boss_scored"
const EVENT_ADVERSITY_ARMOR := "adversity_armor"

var collision_detector: Object = BallMotionCollisionDetector.new()


func step(ball_pos: Vector2, effective_move: Vector2, ball_vel: Vector2, context: Dictionary) -> Dictionary:
	var ball_size: float = float(context.get("ball_size", 28.6))
	var width: float = float(context.get("width", 760.0))
	var height: float = float(context.get("height", 750.0))
	var max_step_distance: float = float(context.get("max_step_distance", 12.0))
	var total_distance: float = effective_move.length()
	var num_steps: int = 1
	if total_distance > max_step_distance:
		num_steps = int(ceil(total_distance / max_step_distance))

	var step_move: Vector2 = effective_move / float(num_steps)
	for _step in range(num_steps):
		ball_pos += step_move
		var wall_result: Dictionary = collision_detector.check_wall(ball_pos, ball_size, width)
		if not wall_result.is_empty():
			wall_result["ball_pos"] = wall_result.get("ball_pos", ball_pos)
			return wall_result

		var paddle_result: Dictionary = collision_detector.check_paddles(ball_pos, ball_vel, ball_size, context)
		if not paddle_result.is_empty():
			paddle_result["ball_pos"] = ball_pos
			return paddle_result

		if bool(context.get("adversity_armor_invincible", false)) and ball_vel.y > 0.0:
			var barrier_y: float = clamp(float(context.get("adversity_armor_barrier_y", height - ball_size * 0.5)), 0.0, height)
			if ball_pos.y >= barrier_y:
				ball_pos.y = min(ball_pos.y, barrier_y)
				return {
					"event": EVENT_ADVERSITY_ARMOR,
					"ball_pos": ball_pos,
					"impact_pos": Vector2(ball_pos.x, barrier_y),
				}

		if ball_pos.y < 0.0:
			return {"event": EVENT_PLAYER_SCORED, "ball_pos": ball_pos}
		if ball_pos.y > height:
			return {"event": EVENT_BOSS_SCORED, "ball_pos": ball_pos}

	return {"event": EVENT_NONE, "ball_pos": ball_pos}
