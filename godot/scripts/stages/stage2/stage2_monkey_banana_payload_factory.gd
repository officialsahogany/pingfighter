extends RefCounted


static func build_monkey(
	side: String,
	trunk_points: Array,
	throw_delay_min_sec: float,
	throw_delay_max_sec: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	var sit_min: int = max(1, int(floor(float(trunk_points.size()) / 3.0)))
	var sit_max: int = max(sit_min, int(floor(float(trunk_points.size()) * 0.7)))
	var start_pos: Vector2 = _as_vector2(trunk_points[0], Vector2.ZERO)
	return {
		"side": side,
		"trunk_points": trunk_points,
		"state": "climbing",
		"position": start_pos,
		"target_point_idx": 0,
		"sit_point_idx": rng.randi_range(sit_min, sit_max),
		"climb_progress": 0.0,
		"throw_timer": 0.0,
		"throw_delay": rng.randf_range(throw_delay_min_sec, throw_delay_max_sec),
		"has_thrown": false,
		"anim_timer": 0.0,
		"facing_right": side == "left",
	}


static func build_flying_banana(start: Vector2, target: Vector2, target_player: bool) -> Dictionary:
	return {
		"state": "flying",
		"position": start,
		"start": start,
		"target": target,
		"target_player": target_player,
		"flight_progress": 0.0,
		"rotation_degrees": 0.0,
		"land_timer": 0.0,
		"slip_triggered": false,
		"boss_slip_triggered": false,
		"burst_timer": 0.0,
		"particles": [],
	}


static func build_landed_banana(position: Vector2, target_player: bool) -> Dictionary:
	var banana: Dictionary = build_flying_banana(position, position, target_player)
	banana["state"] = "landed"
	banana["flight_progress"] = 1.0
	return banana


static func build_burst_particles(
	origin: Vector2,
	count: int,
	colors: Array,
	rng: RandomNumberGenerator
) -> Array:
	var particles: Array = []
	for _i in range(maxi(0, count)):
		var angle: float = rng.randf_range(0.0, TAU)
		var speed: float = rng.randf_range(80.0, 200.0)
		particles.append({
			"pos": origin,
			"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -100.0),
			"size": rng.randf_range(3.0, 8.0),
			"color": colors[rng.randi_range(0, colors.size() - 1)] if not colors.is_empty() else Color(1.0, 0.88, 0.20, 1.0),
			"life": rng.randf_range(0.2, 0.4),
			"max_life": 0.4,
			"rotation_degrees": rng.randf_range(0.0, 360.0),
			"rot_speed": rng.randf_range(-500.0, 500.0),
		})
	return particles


static func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
