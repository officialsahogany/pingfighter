extends RefCounted


static func build_fire_hit_explosion_particles(
	position: Vector2,
	explosion_count: int,
	spark_count: int,
	fire_color: Color
) -> Array[Dictionary]:
	var particles: Array[Dictionary] = []
	for _i in range(maxi(0, explosion_count)):
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(2.5, 7.2)
		var life := randf_range(18.0, 34.0)
		particles.append({
			"x": position.x,
			"y": position.y,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed - randf_range(0.8, 2.4),
			"life": life,
			"max_life": life,
			"size": randf_range(3.4, 8.4),
			"kind": "fire_explosion",
			"weather_type": "fire",
			"color": fire_color,
			"gravity": 0.08,
			"friction": 0.955,
			"size_decay": 0.972,
		})
	for _i in range(maxi(0, spark_count)):
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(6.5, 13.0)
		var life := randf_range(14.0, 26.0)
		particles.append({
			"x": position.x,
			"y": position.y,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed - randf_range(1.2, 3.0),
			"life": life,
			"max_life": life,
			"size": randf_range(2.0, 4.2),
			"length": randf_range(8.0, 18.0),
			"angle": angle,
			"spin": randf_range(-0.10, 0.10),
			"kind": "fire_spark",
			"weather_type": "fire",
			"color": Color(1.0, 0.72, 0.18, 1.0),
			"gravity": 0.05,
			"friction": 0.965,
			"size_decay": 0.986,
		})
	return particles


static func build_sand_dissolve_particle(position: Vector2, velocity: Vector2, sand_color: Color) -> Dictionary:
	return {
		"x": position.x + randf_range(-4.0, 4.0),
		"y": position.y + randf_range(-4.0, 4.0),
		"vx": velocity.x,
		"vy": velocity.y,
		"life": randf_range(20.0, 45.0),
		"max_life": 45.0,
		"size": randf_range(1.0, 3.0),
		"kind": "sand",
		"weather_type": "sand",
		"color": sand_color,
		"gravity": 0.15,
		"friction": 0.95,
	}


static func build_ice_slide_particle(position: Vector2, y: float, direction: int, ice_color: Color) -> Dictionary:
	return {
		"x": position.x + randf_range(10.0, 135.0),
		"y": y + randf_range(-4.0, 4.0),
		"vx": -float(direction) * randf_range(1.5, 4.5),
		"vy": randf_range(-2.5, 2.5),
		"life": randf_range(16.0, 34.0),
		"max_life": 34.0,
		"size": randf_range(2.0, 5.0),
		"kind": "ice",
		"weather_type": "ice",
		"color": ice_color,
	}


static func build_sand_erosion_particle(position: Vector2, velocity: Vector2, sand_color: Color) -> Dictionary:
	return {
		"x": position.x + randf_range(-6.0, 6.0),
		"y": position.y + randf_range(-6.0, 6.0),
		"vx": velocity.x,
		"vy": velocity.y,
		"life": randf_range(18.0, 35.0),
		"max_life": 35.0,
		"size": randf_range(2.0, 4.0),
		"kind": "sand",
		"weather_type": "sand",
		"color": sand_color,
		"gravity": 0.12,
		"friction": 0.95,
	}


static func build_hail_impact_particles(
	position: Vector2,
	size: float,
	dash_destroy: bool,
	hail_color: Color
) -> Array[Dictionary]:
	var particles: Array[Dictionary] = []
	var burst_life := 12.0 if dash_destroy else 16.0
	particles.append({
		"x": position.x,
		"y": position.y,
		"vx": 0.0,
		"vy": 0.0,
		"life": burst_life,
		"max_life": burst_life,
		"size": max(11.0, size * (2.05 if dash_destroy else 1.72)),
		"kind": "hail_burst",
		"weather_type": "hail",
		"color": hail_color,
		"angle": randf_range(0.0, PI * 0.5),
	})

	var shard_count: int = int(max(8.0, size * (2.5 if dash_destroy else 1.45)))
	for _i in range(shard_count):
		var shard_angle := randf_range(0.0, TAU)
		var shard_speed := randf_range(8.0, 16.0) if dash_destroy else randf_range(5.0, 11.0)
		var shard_life := randf_range(18.0, 32.0) if dash_destroy else randf_range(14.0, 26.0)
		particles.append({
			"x": position.x,
			"y": position.y,
			"vx": cos(shard_angle) * shard_speed,
			"vy": sin(shard_angle) * shard_speed - (5.0 if dash_destroy else 3.0),
			"life": shard_life,
			"max_life": shard_life,
			"size": randf_range(3.0, 7.0) if dash_destroy else randf_range(2.5, 5.5),
			"kind": "hail_shard",
			"weather_type": "hail",
			"color": hail_color,
			"angle": shard_angle,
			"spin": randf_range(-0.06, 0.06),
			"gravity": 0.22,
			"friction": 0.965,
		})

	var dust_count: int = int(max(8.0, size * (5.0 if dash_destroy else 2.6)))
	for _i in range(dust_count):
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(6.0, 12.0) if dash_destroy else randf_range(3.5, 7.5)
		var dust_life := randf_range(20.0, 40.0) if dash_destroy else randf_range(14.0, 28.0)
		particles.append({
			"x": position.x,
			"y": position.y,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed - (4.0 if dash_destroy else 2.0),
			"life": dust_life,
			"max_life": dust_life,
			"size": randf_range(3.0, 8.0) if dash_destroy else randf_range(2.2, 5.6),
			"kind": "hail_impact",
			"weather_type": "hail",
			"color": hail_color,
			"gravity": 0.3,
			"friction": 0.98,
		})
	return particles
