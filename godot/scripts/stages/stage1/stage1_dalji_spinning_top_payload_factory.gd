extends RefCounted


static func build_top(
	boss_center: Vector2,
	offset_x: float,
	index: int,
	initial_down_speed: float,
	golden_top_chance: float
) -> Dictionary:
	return {
		"x": boss_center.x + offset_x,
		"y": boss_center.y + 40.0,
		"vx": randf_range(-0.5, 0.5),
		"vy": initial_down_speed,
		"rotation": randf_range(0.0, 360.0),
		"rotation_speed": 20.0,
		"tilt": 0.0,
		"alpha": 255.0,
		"whip_phase": "preparing",
		"zigzag_timer": float(index * 10),
		"speed_boost": 0.0,
		"boost_timer": 0.0,
		"is_golden": randf() < golden_top_chance,
		"star_spawned": false,
	}
