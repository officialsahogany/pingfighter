extends RefCounted

const DASH_BOOST_PARTICLE_COLORS := [
	Color(100.0 / 255.0, 200.0 / 255.0, 1.0, 1.0),
	Color(150.0 / 255.0, 1.0, 200.0 / 255.0, 1.0),
	Color(200.0 / 255.0, 150.0 / 255.0, 1.0, 1.0),
	Color(1.0, 200.0 / 255.0, 100.0 / 255.0, 1.0),
]


static func build_idle_particle(player_center: Vector2) -> Dictionary:
	return {
		"position": Vector2(player_center.x + randf_range(-180.0, 180.0), player_center.y - randf_range(0.0, 30.0)),
		"velocity": Vector2(randf_range(-1.0, 1.0), randf_range(-2.0, -0.5)) * 60.0,
		"radius": float(randi_range(2, 4)),
		"alpha": 200.0 / 255.0,
		"shrink_per_frame": 0.05,
		"color": DASH_BOOST_PARTICLE_COLORS[randi() % DASH_BOOST_PARTICLE_COLORS.size()],
	}
