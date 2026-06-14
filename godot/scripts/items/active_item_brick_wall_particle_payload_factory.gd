extends RefCounted

const BRICK_FRAGMENT_COLORS := [
	Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0, 1.0),
	Color(160.0 / 255.0, 82.0 / 255.0, 45.0 / 255.0, 1.0),
	Color(100.0 / 255.0, 50.0 / 255.0, 25.0 / 255.0, 1.0),
	Color(180.0 / 255.0, 110.0 / 255.0, 65.0 / 255.0, 1.0),
]


static func build_install_dust(center: Vector2, wall_size: Vector2) -> Dictionary:
	return {
		"kind": "dust",
		"position": center + Vector2(randf_range(-wall_size.x * 0.45, wall_size.x * 0.45), randf_range(-3.0, 4.0)),
		"velocity": Vector2(randf_range(-0.55, 0.55), randf_range(-0.85, -0.15)),
		"life": randf_range(16.0, 30.0),
		"initial_life": 30.0,
		"radius": randf_range(2.0, 4.0),
		"color": Color(120.0 / 255.0, 90.0 / 255.0, 64.0 / 255.0, 1.0),
	}


static func build_install_complete_dust(wall_rect: Rect2) -> Dictionary:
	var top_pos := Vector2(
		randf_range(wall_rect.position.x, wall_rect.position.x + wall_rect.size.x),
		wall_rect.position.y + randf_range(-2.0, 4.0)
	)
	return {
		"kind": "dust",
		"position": top_pos,
		"velocity": Vector2(randf_range(-0.7, 0.7), randf_range(-1.2, -0.25)),
		"life": randf_range(18.0, 34.0),
		"initial_life": 34.0,
		"radius": randf_range(2.0, 4.8),
		"color": Color(155.0 / 255.0, 110.0 / 255.0, 76.0 / 255.0, 1.0),
	}


static func build_hit_dust(impact_pos: Vector2) -> Dictionary:
	return {
		"kind": "dust",
		"position": impact_pos + Vector2(randf_range(-10.0, 10.0), randf_range(-3.0, 5.0)),
		"velocity": Vector2(randf_range(-1.1, 1.1), randf_range(-1.8, -0.25)),
		"life": randf_range(18.0, 38.0),
		"initial_life": 38.0,
		"radius": randf_range(2.0, 5.2),
		"color": Color(145.0 / 255.0, 100.0 / 255.0, 70.0 / 255.0, 1.0),
	}


static func build_brick_fragment(wall_rect: Rect2, impact_pos: Vector2) -> Dictionary:
	var start_pos := Vector2(
		randf_range(wall_rect.position.x, wall_rect.position.x + wall_rect.size.x),
		randf_range(wall_rect.position.y, wall_rect.position.y + wall_rect.size.y)
	)
	var burst_dir: Vector2 = start_pos - impact_pos
	if burst_dir.length() < 1.0:
		burst_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 0.2))
	burst_dir = burst_dir.normalized()
	return {
		"kind": "brick",
		"position": start_pos,
		"velocity": burst_dir * randf_range(1.3, 3.4) + Vector2(randf_range(-0.7, 0.7), randf_range(-2.4, -0.7)),
		"life": randf_range(42.0, 82.0),
		"initial_life": 82.0,
		"size": Vector2(randf_range(4.0, 9.0), randf_range(3.0, 7.0)),
		"rotation": randf_range(0.0, TAU),
		"rotation_speed": randf_range(-0.22, 0.22),
		"color": BRICK_FRAGMENT_COLORS[randi() % BRICK_FRAGMENT_COLORS.size()],
	}
