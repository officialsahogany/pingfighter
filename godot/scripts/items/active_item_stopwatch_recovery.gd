extends RefCounted

const STOPWATCH_RECOVERY_FRAMES := 60.0
const STOPWATCH_MIN_RECOVERY_SPEED_RATIO := 0.30


func get_recovery_speed_ratio(recovery_timer_frames: float) -> float:
	if recovery_timer_frames <= 0.0:
		return 1.0
	var recovery_ratio: float = 1.0 - (recovery_timer_frames / max(1.0, STOPWATCH_RECOVERY_FRAMES))
	return max(STOPWATCH_MIN_RECOVERY_SPEED_RATIO, recovery_ratio)


func build_recovery_velocity_result(original_ball_vel: Vector2, current_vel: Vector2, speed_ratio: float) -> Dictionary:
	var original_speed: float = original_ball_vel.length()
	if original_speed <= 0.01:
		return {"has_velocity": false, "ball_vel": Vector2.ZERO}
	var direction: Vector2
	if current_vel.length() > 0.01:
		direction = current_vel.normalized()
	elif original_ball_vel.length() > 0.01:
		direction = original_ball_vel.normalized()
	else:
		direction = Vector2(0.0, -1.0)
	return {
		"has_velocity": true,
		"ball_vel": direction * original_speed * clamp(speed_ratio, 0.0, 1.0),
	}
