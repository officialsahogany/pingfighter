extends RefCounted


static func build_ghost_trail_point(pos: Vector2, alpha: float, size: float) -> Dictionary:
	return {
		"pos": pos,
		"alpha": alpha,
		"size": size,
		"age": 0.0,
	}


static func build_intensity_trail_point(pos: Vector2, alpha: float, size: float, color: Color) -> Dictionary:
	return {
		"pos": pos,
		"alpha": alpha,
		"size": size,
		"color": color,
	}


static func build_intensity_particle(ball_center: Vector2, ball_velocity: Vector2, intensity: float, colors: Array[Color]) -> Dictionary:
	var angle := atan2(-ball_velocity.y, -ball_velocity.x) + randf_range(-0.5, 0.5)
	var speed := randf_range(1.0, 3.0) * (1.0 + intensity)
	var life := 15.0 + intensity * 25.0
	return {
		"pos": ball_center + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)),
		"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)),
		"size": randf_range(3.0, 8.0) * (0.5 + intensity * 0.5),
		"life": life,
		"max_life": life,
		"color": colors[randi() % colors.size()],
		"type": "flame" if randf() < 0.7 else "spark",
	}
