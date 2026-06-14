extends RefCounted


static func build_projectile(origin: Vector2, projectile_speed: float, visual_seed: float, radius_scale: float) -> Dictionary:
	var trail: Array[Vector2] = []
	trail.append(origin)
	return {
		"pos": origin,
		"vel": Vector2(0.0, -projectile_speed),
		"trail": trail,
		"age": 0.0,
		"origin_x": origin.x,
		"phase": visual_seed * TAU,
		"visual_seed": visual_seed,
		"radius_scale": radius_scale,
	}


static func build_particle(position: Vector2, velocity: Vector2, life: float, size: float) -> Dictionary:
	return {
		"pos": position,
		"vel": velocity,
		"life": life,
		"max_life": maxf(0.01, life),
		"size": size,
	}


static func build_burst_particle(origin: Vector2, strength: float) -> Dictionary:
	var angle: float = randf_range(0.0, TAU)
	var speed: float = randf_range(70.0, 190.0) * maxf(0.1, strength)
	var position := origin + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
	var velocity := Vector2(cos(angle), sin(angle)) * speed
	return build_particle(position, velocity, randf_range(0.28, 0.62), randf_range(2.4, 5.8))


static func build_stun_status_data() -> Dictionary:
	return {
		"cleansable": true,
		"visual": "maribo_bubble_trap",
		"suppress_stun_stars": true,
	}
