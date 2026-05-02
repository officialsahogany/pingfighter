extends RefCounted


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
	var spin_strength: float = current_spin_strength
	if abs(hit_pos) < center_hit_threshold:
		var center_boost: float = _apply_dampened_multiplier(ball_physics, speed, 1.0 + 0.03 * accel_scale)
		var center_additional_speed: float = speed * (center_boost - 1.0)
		speed *= center_boost
		speed_increase += center_additional_speed
		spin_strength = min(0.52, 0.22 + speed * 0.012)
	elif abs(hit_pos) > smash_hit_threshold:
		var drive_smash_rate: float = randf_range(0.015 * accel_scale, 0.05 * accel_scale)
		var drive_smash_boost: float = _apply_dampened_multiplier(ball_physics, speed, 1.0 + drive_smash_rate)
		var smash_additional_speed: float = speed * (drive_smash_boost - 1.0)
		speed *= drive_smash_boost
		speed_increase += smash_additional_speed
		spin_strength = min(0.52, 0.22 + speed * 0.012)
		bounce_vector = bounce_vector.rotated(deg_to_rad(randf_range(-5.0, 5.0)))

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
