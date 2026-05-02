extends RefCounted


func apply(ball_velocity: Vector2, bounce_vector: Vector2, speed: float, vertical_bounce_count: int) -> Dictionary:
	if abs(ball_velocity.x) < 0.5:
		vertical_bounce_count += 1
		bounce_vector = bounce_vector.rotated(deg_to_rad(-3.0 if randf() < 0.5 else 3.0)).normalized()
		ball_velocity = bounce_vector * speed
	else:
		vertical_bounce_count = 0

	if vertical_bounce_count >= 2:
		bounce_vector = bounce_vector.rotated(deg_to_rad(-15.0 if randf() < 0.5 else 15.0)).normalized()
		ball_velocity = bounce_vector * speed
		vertical_bounce_count = 0

	return {
		"ball_vel": ball_velocity,
		"vertical_bounce_count": vertical_bounce_count,
	}
