extends RefCounted

const DRIVE_EFFECT_MULT: float = 0.8
const DRIVE_MAX_LAUNCH_SPEED_MULT: float = 2.30 * DRIVE_EFFECT_MULT


func apply(
	speed: float,
	bounce_vector: Vector2,
	hit_pos: float,
	accel_scale: float,
	ball_physics: Object,
	current_speed_increase: float,
	current_spin_strength: float,
	center_hit_threshold: float,
	smash_hit_threshold: float
) -> Dictionary:
	var speed_increase: float = current_speed_increase
	var original_speed: float = max(0.0, speed - speed_increase)
	var spin_strength: float = current_spin_strength
	if abs(hit_pos) < center_hit_threshold:
		var center_boost: float = _apply_dampened_multiplier(
			ball_physics,
			speed,
			1.0 + 0.0216 * DRIVE_EFFECT_MULT * accel_scale
		)
		var center_additional_speed: float = speed * (center_boost - 1.0)
		speed *= center_boost
		speed_increase += center_additional_speed
		spin_strength = min(
			0.52 * DRIVE_EFFECT_MULT,
			(0.22 * DRIVE_EFFECT_MULT) + speed * 0.012 * DRIVE_EFFECT_MULT
		)
	elif abs(hit_pos) > smash_hit_threshold:
		var drive_smash_rate: float = randf_range(
			0.0108 * DRIVE_EFFECT_MULT * accel_scale,
			0.036 * DRIVE_EFFECT_MULT * accel_scale
		)
		var drive_smash_boost: float = _apply_dampened_multiplier(ball_physics, speed, 1.0 + drive_smash_rate)
		var smash_additional_speed: float = speed * (drive_smash_boost - 1.0)
		speed *= drive_smash_boost
		speed_increase += smash_additional_speed
		spin_strength = min(
			0.52 * DRIVE_EFFECT_MULT,
			(0.22 * DRIVE_EFFECT_MULT) + speed * 0.012 * DRIVE_EFFECT_MULT
		)
		bounce_vector = bounce_vector.rotated(deg_to_rad(randf_range(-5.0, 5.0)))

	var max_drive_speed: float = max(original_speed, 0.1) * DRIVE_MAX_LAUNCH_SPEED_MULT
	if speed > max_drive_speed:
		speed = max_drive_speed
		speed_increase = max(0.0, speed - original_speed)

	return {
		"speed": speed,
		"bounce_vector": bounce_vector,
		"speed_increase": speed_increase,
		"spin_strength": spin_strength,
	}


func _apply_dampened_multiplier(ball_physics: Object, current_speed: float, raw_multiplier: float) -> float:
	if ball_physics != null and ball_physics.has_method("apply_dampened_multiplier"):
		return float(ball_physics.apply_dampened_multiplier(current_speed, raw_multiplier))
	return raw_multiplier
