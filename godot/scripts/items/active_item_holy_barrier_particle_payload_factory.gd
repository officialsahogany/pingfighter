extends RefCounted

const HOLY_BARRIER_PARTICLE_COLORS := [
	Color(1.0, 1.0, 200.0 / 255.0, 1.0),
	Color(200.0 / 255.0, 220.0 / 255.0, 1.0, 1.0),
	Color(1.0, 230.0 / 255.0, 150.0 / 255.0, 1.0),
]


static func build_hit_particle(impact_pos: Vector2) -> Dictionary:
	return {
		"position": impact_pos + Vector2(randf_range(-15.0, 15.0), 0.0),
		"velocity": Vector2(randf_range(-2.0, 2.0), randf_range(-3.0, -1.0)) * 60.0,
		"radius": randf_range(3.0, 7.0),
		"alpha": 1.0,
		"color": Color(1.0, 1.0, 100.0 / 255.0, 1.0),
	}


static func build_idle_particle(field_width: float, barrier_center_y: float) -> Dictionary:
	return {
		"position": Vector2(randf_range(0.0, field_width), barrier_center_y + randf_range(-5.0, 5.0)),
		"velocity": Vector2(randf_range(-0.5, 0.5), randf_range(-1.5, -0.5)) * 60.0,
		"radius": randf_range(2.0, 5.0),
		"alpha": 1.0,
		"color": HOLY_BARRIER_PARTICLE_COLORS[randi() % HOLY_BARRIER_PARTICLE_COLORS.size()],
	}
