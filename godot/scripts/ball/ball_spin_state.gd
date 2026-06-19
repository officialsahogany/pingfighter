extends RefCounted

const DRIVE_SPIN_FORCE := 3.5
const DRIVE_ACTIVE_SPIN_FORCE_MULT := 1.25
const DEFAULT_SPIN_DECAY := 0.98


func apply_spin(
	ball_velocity: Vector2,
	spin_strength: float,
	spin_direction: int,
	fps_scale: float,
	drive_ball_active: bool
) -> Dictionary:
	var result: Dictionary = {}
	if spin_strength > 0.01:
		var spin_force_mult: float = DRIVE_ACTIVE_SPIN_FORCE_MULT if drive_ball_active else 1.0
		ball_velocity.x += spin_strength * float(spin_direction) * DRIVE_SPIN_FORCE * spin_force_mult * fps_scale
		spin_strength *= pow(DEFAULT_SPIN_DECAY, fps_scale)
	else:
		spin_strength = 0.0
		spin_direction = 0
		if drive_ball_active:
			result.merge(build_clear_drive_snapshot(), true)

	result.merge({
		"ball_vel": ball_velocity,
		"ball_spin_strength": spin_strength,
		"ball_spin_direction": spin_direction,
	}, true)
	return result


func activate_drive(
	ball_velocity: Vector2,
	direction: int,
	spin_strength: float,
	speed_multiplier: float,
	speed_bypass_bonus: float,
	ball_physics: Object
) -> Dictionary:
	var normalized_dir: int = -1 if direction < 0 else 1
	spin_strength = max(0.0, spin_strength)
	var current_speed: float = max(0.001, ball_velocity.length())
	var dampened_speed_multiplier: float = _apply_dampened_multiplier(ball_physics, current_speed, speed_multiplier)
	ball_velocity *= dampened_speed_multiplier
	if speed_bypass_bonus > 0.0:
		ball_velocity *= 1.0 + speed_bypass_bonus

	return {
		"ball_vel": ball_velocity,
		"ball_spin_direction": normalized_dir,
		"ball_spin_strength": spin_strength,
		"drive_ball_active": spin_strength > 0.0,
		"drive_hit_boss": false,
		"drive_speed_increase": ball_velocity.length() - current_speed,
	}


func build_clear_drive_snapshot(clear_spin: bool = false) -> Dictionary:
	var snapshot: Dictionary = {
		"drive_ball_active": false,
		"drive_hit_boss": false,
		"drive_speed_increase": 0.0,
	}
	if clear_spin:
		snapshot["ball_spin_strength"] = 0.0
		snapshot["ball_spin_direction"] = 0
	return snapshot


func _apply_dampened_multiplier(ball_physics: Object, current_speed: float, raw_multiplier: float) -> float:
	if ball_physics != null and ball_physics.has_method("apply_dampened_multiplier"):
		return float(ball_physics.apply_dampened_multiplier(current_speed, raw_multiplier))
	return raw_multiplier
