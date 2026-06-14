extends RefCounted

const FLOATING_PETAL_COLORS := [
	Color(1.0, 200.0 / 255.0, 210.0 / 255.0, 0.78),
	Color(1.0, 220.0 / 255.0, 225.0 / 255.0, 0.78),
	Color(250.0 / 255.0, 210.0 / 255.0, 220.0 / 255.0, 0.78),
]
const TREE_DROP_PETAL_COLORS := [
	Color(1.0, 246.0 / 255.0, 218.0 / 255.0, 1.0),
	Color(1.0, 232.0 / 255.0, 224.0 / 255.0, 1.0),
	Color(248.0 / 255.0, 239.0 / 255.0, 204.0 / 255.0, 1.0),
	Color(1.0, 218.0 / 255.0, 226.0 / 255.0, 1.0),
]


static func build_floating_petal(x: float) -> Dictionary:
	return {
		"x": x,
		"y": randf_range(-20.0, 0.0),
		"vx": randf_range(-0.5, 0.5),
		"vy": randf_range(0.8, 1.5),
		"rotation": randf_range(0.0, 360.0),
		"rot_speed": randf_range(-2.0, 2.0),
		"size": float(randi_range(6, 10)),
		"color": FLOATING_PETAL_COLORS[randi() % FLOATING_PETAL_COLORS.size()],
	}


static func build_tree_drop_petal(base_position: Vector2, side_dir: float, burst: float) -> Dictionary:
	var life: float = randf_range(1.35, 2.15)
	return {
		"x": base_position.x + randf_range(-16.0, 16.0),
		"y": base_position.y + randf_range(-28.0, 24.0),
		"vx": (side_dir * randf_range(16.0, 48.0) + randf_range(-18.0, 18.0)) * burst,
		"vy": randf_range(24.0, 76.0) * burst,
		"gravity": randf_range(34.0, 72.0),
		"sway": randf_range(0.0, TAU),
		"sway_speed": randf_range(4.0, 7.5),
		"rotation": randf_range(0.0, 360.0),
		"rot_speed": randf_range(-165.0, 165.0),
		"size": float(randi_range(5, 9)),
		"color": TREE_DROP_PETAL_COLORS[randi() % TREE_DROP_PETAL_COLORS.size()],
		"life": life,
		"max_life": life,
	}
