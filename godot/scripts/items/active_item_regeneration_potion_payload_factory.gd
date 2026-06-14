extends RefCounted

const REGENERATION_POTION_PARTICLE_COLORS := [
	Color(1.0, 215.0 / 255.0, 0.0, 1.0),
	Color(1.0, 230.0 / 255.0, 80.0 / 255.0, 1.0),
	Color(1.0, 200.0 / 255.0, 50.0 / 255.0, 1.0),
	Color(1.0, 1.0, 100.0 / 255.0, 1.0),
	Color(1.0, 180.0 / 255.0, 30.0 / 255.0, 1.0),
]


static func build_ring(center: Vector2, duration: float) -> Dictionary:
	return {
		"position": center,
		"age": 0.0,
		"duration": duration,
	}


static func build_particle(center: Vector2, particle_duration: float) -> Dictionary:
	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(6.0, 48.0)
	var start_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
	return {
		"position": start_pos,
		"velocity": Vector2(randf_range(-34.0, 34.0), randf_range(-104.0, -34.0)),
		"radius": randf_range(2.4, 5.2),
		"age": 0.0,
		"lifetime": randf_range(0.42, particle_duration),
		"color": REGENERATION_POTION_PARTICLE_COLORS[randi() % REGENERATION_POTION_PARTICLE_COLORS.size()],
	}
