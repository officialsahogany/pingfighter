extends RefCounted

const WALL_DAMPING := 0.95
const WALL_SHAKE_SPEED_THRESHOLD := 16.0
const WALL_SHAKE_BASE := 0.05
const WALL_SHAKE_INTENSITY_DIVISOR := 6.0
const WALL_SHAKE_MIN_INTENSITY := 2.5
const WALL_SHAKE_MAX_INTENSITY := 5.0


func resolve(ball_velocity: Vector2, impact_boost: float, side: String) -> Dictionary:
	var impact_speed: float = ball_velocity.length() * max(1.0, impact_boost)
	if side == "left":
		ball_velocity.x = abs(ball_velocity.x) * WALL_DAMPING
	else:
		ball_velocity.x = -abs(ball_velocity.x) * WALL_DAMPING
	ball_velocity.y *= WALL_DAMPING

	var shake_amount := 0.0
	var shake_intensity := 0.0
	if impact_speed >= WALL_SHAKE_SPEED_THRESHOLD:
		shake_amount = WALL_SHAKE_BASE
		shake_intensity = clamp(
			impact_speed / WALL_SHAKE_INTENSITY_DIVISOR,
			WALL_SHAKE_MIN_INTENSITY,
			WALL_SHAKE_MAX_INTENSITY
		)

	return {
		"ball_vel": ball_velocity,
		"impact_speed": impact_speed,
		"screen_shake": shake_amount,
		"screen_shake_intensity": shake_intensity,
	}
