extends RefCounted

const WALL_DAMPING := 0.95
const WALL_SHAKE_SPEED_THRESHOLD := 16.0
const WALL_SHAKE_BASE := 0.05
const WALL_SHAKE_INTENSITY_DIVISOR := 6.0
const WALL_SHAKE_MIN_INTENSITY := 2.5
const WALL_SHAKE_MAX_INTENSITY := 5.0
const DRAW_BOUNCE_LIMIT := 6
const DRAW_TIME_LIMIT_MSEC := 6000
const PADDLE_HIT_GRACE_MSEC := 100

var wall_bounce_count := 0
var last_wall_hit := ""
var last_paddle_hit_msec := 0


func reset_round() -> void:
	wall_bounce_count = 0
	last_wall_hit = ""
	last_paddle_hit_msec = 0


func register_paddle_hit(current_msec: int = -1) -> void:
	wall_bounce_count = 0
	last_wall_hit = ""
	last_paddle_hit_msec = _resolve_msec(current_msec)


func resolve(ball_velocity: Vector2, impact_boost: float, side: String, current_msec: int = -1) -> Dictionary:
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
		"rematch_requested": _register_wall_bounce(side, _resolve_msec(current_msec)),
	}


func _register_wall_bounce(side: String, current_msec: int) -> bool:
	if side != "left" and side != "right":
		return false
	if current_msec - last_paddle_hit_msec <= PADDLE_HIT_GRACE_MSEC:
		return false

	var opposite_side := "right" if side == "left" else "left"
	if last_wall_hit == opposite_side:
		wall_bounce_count += 1
		var time_without_paddle := current_msec - last_paddle_hit_msec
		if wall_bounce_count >= DRAW_BOUNCE_LIMIT and time_without_paddle >= DRAW_TIME_LIMIT_MSEC:
			reset_round()
			return true
	else:
		wall_bounce_count = 0
	last_wall_hit = side
	return false


func _resolve_msec(current_msec: int) -> int:
	if current_msec >= 0:
		return current_msec
	return Time.get_ticks_msec()
