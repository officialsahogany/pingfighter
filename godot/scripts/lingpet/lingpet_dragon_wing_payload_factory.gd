extends RefCounted


static func build_flying_dragon(
	origin: Vector2,
	wind_direction: float,
	field_width: float,
	offscreen_margin: float
) -> Dictionary:
	var start_x := -offscreen_margin if wind_direction > 0.0 else field_width + offscreen_margin
	var source_y := origin.y if origin != Vector2.ZERO else randf_range(420.0, 540.0)
	var dragon_y := clampf(source_y, 400.0, 550.0)
	return {
		"active": true,
		"pos": Vector2(start_x, dragon_y),
		"base_y": dragon_y,
		"direction": wind_direction,
		"wing_time": 0.0,
		"hit_cooldown": 0.0,
	}


static func build_wind_particle(
	initial: bool,
	wind_direction: float,
	field_width: float,
	opponent_y_wind_direction: float,
	opponent_y_particle_speed_min: float,
	opponent_y_particle_speed_max: float
) -> Dictionary:
	var start_x := 0.0 if wind_direction > 0.0 else field_width
	var life := randf_range(0.55, 1.05)
	var speed := randf_range(210.0, 420.0)
	var y_range_min := 150.0 if initial else 90.0
	var y_range_max := 610.0 if initial else 660.0
	var pos := Vector2(start_x + randf_range(-22.0, 22.0), randf_range(y_range_min, y_range_max))
	if initial:
		pos.x = randf_range(0.0, field_width)
	return {
		"pos": pos,
		"vel": Vector2(
			wind_direction * speed,
			opponent_y_wind_direction * randf_range(opponent_y_particle_speed_min, opponent_y_particle_speed_max)
		),
		"life": life,
		"max_life": life,
		"length": randf_range(24.0, 58.0),
		"width": randf_range(1.3, 3.4),
		"phase": randf() * TAU,
	}


static func build_ball_swirl_trail_entry(ball_pos: Vector2, elapsed: float, trail_life: float) -> Dictionary:
	return {
		"pos": ball_pos,
		"life": trail_life,
		"max_life": trail_life,
		"phase": elapsed * 8.0 + randf_range(-0.35, 0.35),
	}


static func build_dragon_trail_entry(pos: Vector2, trail_life: float) -> Dictionary:
	return {
		"pos": pos,
		"life": trail_life,
		"max_life": trail_life,
	}
