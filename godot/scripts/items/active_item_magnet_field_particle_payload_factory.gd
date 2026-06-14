extends RefCounted

const MAGNET_FIELD_PARTICLE_COLORS := [
	Color(100.0 / 255.0, 150.0 / 255.0, 1.0, 1.0),
	Color(150.0 / 255.0, 100.0 / 255.0, 1.0, 1.0),
	Color(80.0 / 255.0, 200.0 / 255.0, 1.0, 1.0),
	Color(200.0 / 255.0, 150.0 / 255.0, 1.0, 1.0),
]


static func build_particle(player_center: Vector2) -> Dictionary:
	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(40.0, 150.0)
	var start_pos := Vector2(
		player_center.x + cos(angle) * radius,
		player_center.y - randf_range(20.0, 120.0)
	)
	return {
		"position": start_pos,
		"velocity": Vector2(cos(angle) * randf_range(-0.3, 0.3), randf_range(-1.5, -0.5)),
		"radius": float(randi_range(2, 4)),
		"alpha": 200.0 / 255.0,
		"color": MAGNET_FIELD_PARTICLE_COLORS[randi() % MAGNET_FIELD_PARTICLE_COLORS.size()],
	}
