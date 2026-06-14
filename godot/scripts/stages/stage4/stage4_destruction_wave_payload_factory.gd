extends RefCounted


static func build_wave(start: Vector2, target: Vector2, speed_px_per_sec: float, max_lifetime_sec: float) -> Dictionary:
	var direction: Vector2 = target - start
	var distance: float = maxf(1.0, direction.length())
	var velocity: Vector2 = direction / distance * speed_px_per_sec
	return {
		"start_x": start.x,
		"start_y": start.y,
		"current_x": start.x,
		"current_y": start.y,
		"target_x": target.x,
		"target_y": target.y,
		"vx": velocity.x,
		"vy": velocity.y,
		"speed": speed_px_per_sec / 60.0,
		"radius": 25.0,
		"max_radius": 120.0,
		"lifetime": 0.0,
		"max_lifetime": max_lifetime_sec,
		"trail": [],
		"beam_particles": [],
		"energy_rings": [],
		"core_rotation": 0.0,
	}


static func build_trail_particles(center: Vector2, count: int, random: RandomNumberGenerator) -> Array:
	var particles: Array = []
	for _idx in range(maxi(0, count)):
		particles.append({
			"x": center.x + random.randf_range(-20.0, 20.0),
			"y": center.y + random.randf_range(-20.0, 20.0),
			"life": 30.0,
			"size": random.randf_range(5.0, 15.0),
			"color_phase": random.randf(),
		})
	return particles


static func build_beam_particles(center: Vector2, angle: float, count: int, random: RandomNumberGenerator) -> Array:
	var particles: Array = []
	for _idx in range(maxi(0, count)):
		particles.append({
			"x": center.x + random.randf_range(-5.0, 5.0),
			"y": center.y + random.randf_range(-5.0, 5.0),
			"life": 40.0,
			"length": random.randf_range(20.0, 40.0),
			"width": random.randf_range(2.0, 4.0),
			"angle": angle,
		})
	return particles


static func build_energy_ring(center: Vector2, radius: float) -> Dictionary:
	return {
		"x": center.x,
		"y": center.y,
		"radius": 10.0,
		"max_radius": radius * 2.0,
		"life": 20.0,
		"opacity": 1.0,
	}
