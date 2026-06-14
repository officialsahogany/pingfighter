extends RefCounted


static func build_falling_tear(width: float, random: RandomNumberGenerator) -> Dictionary:
	var y: float = random.randf_range(-200.0, -20.0)
	return {
		"x": random.randf_range(0.0, width - 20.0),
		"y": y,
		"prev_y": y,
		"speed": random.randf_range(2.0, 5.0),
	}


static func build_curse_smoke_particle(curse_pos: Vector2, random: RandomNumberGenerator) -> Dictionary:
	var angle := random.randf_range(0.0, TAU)
	var speed := random.randf_range(0.3, 1.5)
	return {
		"x": curse_pos.x + random.randf_range(-10.0, 10.0),
		"y": curse_pos.y + random.randf_range(-10.0, 5.0),
		"vx": cos(angle) * speed,
		"vy": sin(angle) * speed - 0.3,
		"life": random.randf_range(1.0, 2.0),
		"size": random.randf_range(8.0, 18.0),
		"alpha": 1.0,
	}


static func build_curse_explosion_particles(curse_pos: Vector2, count: int, random: RandomNumberGenerator) -> Array:
	var particles: Array = []
	for _idx in range(maxi(0, count)):
		var angle := random.randf_range(0.0, TAU)
		var speed := random.randf_range(2.0, 6.0)
		particles.append({
			"x": curse_pos.x + random.randf_range(-5.0, 5.0),
			"y": curse_pos.y + random.randf_range(-5.0, 5.0),
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed - 2.0,
			"life": random.randf_range(0.34, 0.67),
			"max_life": 0.67,
			"size": random.randf_range(3.0, 8.0),
			"life_ratio": 1.0,
		})
	return particles


static func build_psychoball_neutralize_particles(center: Vector2, count: int, random: RandomNumberGenerator) -> Array:
	var particles: Array = []
	for _idx in range(maxi(0, count)):
		var angle := random.randf_range(0.0, TAU)
		var speed := random.randf_range(2.0, 8.0)
		particles.append({
			"x": center.x,
			"y": center.y,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed,
			"life_frames": 30.0,
			"color_r": random.randi_range(150, 200),
			"color_g": 0,
			"color_b": random.randi_range(150, 255),
		})
	return particles


static func build_kuromi_mouth_particle(
	center: Vector2,
	mouth_direction: float,
	directional: bool,
	random: RandomNumberGenerator
) -> Dictionary:
	var angle: float = mouth_direction if directional else random.randf_range(0.0, TAU)
	var spread: float = random.randf_range(-0.55, 0.55)
	var speed: float = random.randf_range(0.5, 3.2) if directional else random.randf_range(0.2, 1.2)
	return {
		"x": center.x + random.randf_range(-12.0, 12.0),
		"y": center.y + random.randf_range(-8.0, 14.0),
		"vx": cos(angle + spread) * speed,
		"vy": sin(angle + spread) * speed,
		"life": random.randf_range(0.35, 0.9),
		"max_life": 0.9,
		"size": random.randf_range(2.0, 5.5),
		"hue": random.randf_range(0.86, 0.98),
	}


static func build_kuromi_spit_trail_point(position: Vector2, size: float, life: float = 1.0) -> Dictionary:
	return {
		"x": position.x,
		"y": position.y,
		"life": life,
		"size": size,
	}


static func build_tail_hit_burst(pos: Vector2, redirected_vel: Vector2, life_sec: float, random: RandomNumberGenerator) -> Dictionary:
	var angle: float = redirected_vel.angle() if redirected_vel.length() > 0.001 else 0.0
	return {
		"x": pos.x,
		"y": pos.y,
		"life": life_sec,
		"max_life": life_sec,
		"angle": angle,
		"seed": random.randi(),
	}


static func build_prism_particles(
	center: Vector2,
	count: int,
	strong: bool,
	random: RandomNumberGenerator
) -> Array:
	var particles: Array = []
	for idx in range(maxi(0, count)):
		var angle := random.randf_range(0.0, TAU)
		var speed := random.randf_range(3.0, 10.0) if strong else random.randf_range(1.5, 5.5)
		var life := random.randf_range(1.0, 2.0) if strong else 1.0
		particles.append({
			"x": center.x,
			"y": center.y,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed,
			"life": life,
			"max_life": life,
			"size": random.randf_range(2.0, 5.0) if strong else random.randf_range(1.5, 3.8),
			"hue": fposmod(float(idx) / 7.0 + random.randf_range(-0.02, 0.02), 1.0) if strong else random.randf(),
			"sparkle": random.randf_range(0.0, TAU),
		})
	return particles
