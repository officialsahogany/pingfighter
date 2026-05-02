extends RefCounted

const DRIVE_COUNTER_SPIN_RETAIN := 0.50
const DRIVE_COUNTER_SPEED_REDUCTION := 0.35
const DRIVE_COUNTER_MAX_SPEED := 22.0
const DRIVE_COUNTER_MAX_PLAYER_SPEED := 20.0


func apply_counter(
	ball_velocity: Vector2,
	ball_spin_strength: float,
	drive_speed_increase: float,
	drive_ball_active: bool,
	drive_hit_boss: bool
) -> Dictionary:
	if not drive_ball_active or drive_hit_boss:
		return {"applied": false}

	drive_hit_boss = true
	ball_spin_strength *= DRIVE_COUNTER_SPIN_RETAIN
	if drive_speed_increase > 0.0:
		var current_speed: float = ball_velocity.length()
		if current_speed > 0.0:
			var speed_reduction: float = drive_speed_increase * DRIVE_COUNTER_SPEED_REDUCTION
			var new_speed: float = max(1.0, current_speed - speed_reduction)
			ball_velocity *= new_speed / current_speed
			drive_speed_increase *= 1.0 - DRIVE_COUNTER_SPEED_REDUCTION

	var counter_speed: float = ball_velocity.length()
	if counter_speed > DRIVE_COUNTER_MAX_SPEED:
		ball_velocity *= DRIVE_COUNTER_MAX_SPEED / counter_speed
	if ball_velocity.y > 0.0:
		var player_direction_speed: float = ball_velocity.length()
		if player_direction_speed > DRIVE_COUNTER_MAX_PLAYER_SPEED:
			ball_velocity *= DRIVE_COUNTER_MAX_PLAYER_SPEED / player_direction_speed

	return {
		"applied": true,
		"ball_vel": ball_velocity,
		"ball_spin_strength": ball_spin_strength,
		"drive_speed_increase": drive_speed_increase,
		"drive_hit_boss": drive_hit_boss,
	}
