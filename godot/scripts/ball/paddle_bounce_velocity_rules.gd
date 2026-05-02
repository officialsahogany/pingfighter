extends RefCounted


func apply_boss_center_preserve(
	bounce_vector: Vector2,
	hit_pos: float,
	incoming_dx: float,
	is_player: bool,
	boss_center_preserve_threshold: float,
	mid_hit_threshold: float
) -> Vector2:
	if is_player or abs(hit_pos) >= boss_center_preserve_threshold:
		return bounce_vector
	if abs(incoming_dx) > 0.5:
		var preserve_ratio: float = 0.7 * (1.0 - abs(hit_pos) / boss_center_preserve_threshold)
		bounce_vector.x += sign(incoming_dx) * preserve_ratio
		return bounce_vector.normalized()
	if abs(bounce_vector.x) < mid_hit_threshold:
		var force_dir: float = -1.0 if randf() < 0.5 else 1.0
		bounce_vector.x += force_dir * 0.5
		return bounce_vector.normalized()
	return bounce_vector


func apply_normal_contact_shape(
	speed: float,
	bounce_vector: Vector2,
	hit_pos: float,
	accel_scale: float,
	ball_physics: Object,
	center_hit_threshold: float,
	mid_hit_threshold: float,
	smash_hit_threshold: float
) -> Dictionary:
	if abs(hit_pos) < center_hit_threshold:
		speed *= apply_dampened_multiplier(ball_physics, speed, 1.0 + 0.03 * accel_scale)
	elif abs(hit_pos) < mid_hit_threshold:
		bounce_vector = bounce_vector.rotated(deg_to_rad(randf_range(-35.0, 35.0)))
	elif abs(hit_pos) > smash_hit_threshold:
		speed *= apply_dampened_multiplier(
			ball_physics,
			speed,
			1.0 + randf_range(0.015 * accel_scale, 0.05 * accel_scale)
		)
		bounce_vector = bounce_vector.rotated(deg_to_rad(randf_range(-5.0, 5.0)))
	return {
		"speed": speed,
		"bounce_vector": bounce_vector,
	}


func apply_dampened_multiplier(ball_physics: Object, current_speed: float, raw_multiplier: float) -> float:
	if ball_physics != null and ball_physics.has_method("apply_dampened_multiplier"):
		return float(ball_physics.apply_dampened_multiplier(current_speed, raw_multiplier))
	return raw_multiplier


func get_scaled_random_multiplier(ball_physics: Object, raw_min: float, raw_max: float, scale: float) -> float:
	if ball_physics != null and ball_physics.has_method("get_scaled_random_multiplier"):
		return float(ball_physics.get_scaled_random_multiplier(raw_min, raw_max, scale))
	var min_excess: float = (raw_min - 1.0) * scale
	var max_excess: float = (raw_max - 1.0) * scale
	return 1.0 + randf_range(min_excess, max_excess)


func ensure_min_vertical_component(ball_physics: Object, vector: Vector2, direction_sign: float) -> Vector2:
	if ball_physics != null and ball_physics.has_method("ensure_min_vertical_component"):
		var ensured_vector: Variant = ball_physics.ensure_min_vertical_component(vector, direction_sign)
		if ensured_vector is Vector2:
			return ensured_vector
	return vector.normalized() if vector.length() > 0.0 else Vector2(0.0, direction_sign)
