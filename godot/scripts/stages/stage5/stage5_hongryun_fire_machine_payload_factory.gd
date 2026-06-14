extends RefCounted


static func build_dragons(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(maxi(0, count)):
		result.append(build_dragon(index))
	return result


static func build_dragon(index: int) -> Dictionary:
	return {
		"cannon_angle": 0.0,
		"target_cannon_angle": 0.0,
		"cannon_emergence": 0.0,
		"cannon_current_length": 0.0,
		"is_aiming": false,
		"aim_target": Vector2.ZERO,
		"jaw_open": 0.0,
		"jaw_phase": "closed",
		"fired": false,
		"base_angle_offset": lerpf(-0.08, 0.08, float(index)),
	}


static func build_fire_stream(start: Vector2, target: Vector2, fallback_angle: float, duration: float) -> Dictionary:
	var to_target: Vector2 = target - start
	return {
		"start": start,
		"target": target,
		"angle": to_target.angle() if to_target.length() > 0.001 else fallback_angle,
		"distance": to_target.length(),
		"timer": 0.0,
		"duration": duration,
		"particles": [],
		"completed": false,
	}


static func build_stream_particle(stream_pos: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"pos": stream_pos + Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0)),
		"vel": Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(0.0, 2.0)),
		"size": rng.randf_range(6.0, 12.0),
		"life": 30.0,
		"color": _random_fire_color(rng),
	}


static func build_fire_zone(
	pos: Vector2,
	width: float,
	height: float,
	duration: float,
	initial_flame_count: int,
	rng: RandomNumberGenerator
) -> Dictionary:
	var zone := {
		"pos": pos,
		"width": width,
		"height": height,
		"duration": duration,
		"spread_timer": 0.0,
		"flames": [],
	}
	var flames: Array = zone["flames"]
	for _i in range(maxi(0, initial_flame_count)):
		flames.append(build_flame(pos, width, height, true, rng))
	return zone


static func build_flame(
	center: Vector2,
	width: float,
	height: float,
	initial: bool,
	rng: RandomNumberGenerator
) -> Dictionary:
	return {
		"pos": center + Vector2(rng.randf_range(-width * 0.5, width * 0.5), rng.randf_range(-height * 0.5, height * 0.5)),
		"size": rng.randf_range(8.0, 20.0) if initial else rng.randf_range(5.0, 15.0),
		"life": rng.randf_range(20.0, 40.0) if initial else rng.randf_range(15.0, 30.0),
		"color_phase": rng.randf(),
	}


static func build_smoke_particles(
	center: Vector2,
	width: float,
	height: float,
	count: int,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var particles: Array[Dictionary] = []
	for _i in range(maxi(0, count)):
		var life: float = rng.randf_range(80.0, 140.0)
		particles.append({
			"pos": center + Vector2(rng.randf_range(-width * 0.45, width * 0.45), rng.randf_range(-height * 0.45, height * 0.45)),
			"vel": Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-2.2, -0.6)),
			"size": rng.randf_range(8.0, 14.0),
			"max_size": rng.randf_range(28.0, 46.0),
			"life": life,
			"max_life": life,
			"alpha": 0.0,
			"warmth": rng.randf_range(0.3, 0.9),
			"wobble_phase": rng.randf_range(0.0, TAU),
			"wobble_freq": rng.randf_range(0.04, 0.09),
			"wobble_amp": rng.randf_range(0.4, 1.0),
		})
	return particles


static func _random_fire_color(rng: RandomNumberGenerator) -> Color:
	var roll := rng.randi_range(0, 2)
	if roll == 0:
		return Color(1.0, 0.38, 0.05, 0.95)
	if roll == 1:
		return Color(1.0, 0.62, 0.05, 0.95)
	return Color(1.0, 0.86, 0.18, 0.95)
