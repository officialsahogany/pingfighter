extends RefCounted

const DEFAULT_LEAF_PARTICLE_LIFE_SEC := 0.95


func build_firefly(view_size: Vector2, random_source: RandomNumberGenerator) -> Dictionary:
	return {
		"x": random_source.randf_range(0.0, max(1.0, view_size.x)),
		"y": random_source.randf_range(0.0, max(1.0, view_size.y)),
		"phase": random_source.randf_range(0.0, TAU),
		"speed": random_source.randf_range(0.3, 0.5),
		"size": random_source.randi_range(2, 3),
	}


func build_ambient_leaf(
	layout_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	random_source: RandomNumberGenerator
) -> Dictionary:
	if layout_size.x <= 0.0 or game_offset.x < 30.0:
		return {}
	var ranges: Array = []
	var left_width: float = game_offset.x
	var right_start: float = game_offset.x + game_size.x
	var right_width: float = layout_size.x - right_start
	if left_width > 30.0:
		ranges.append(Vector2(10.0, max(10.0, left_width - 10.0)))
	if right_width > 30.0:
		ranges.append(Vector2(right_start + 10.0, max(right_start + 10.0, layout_size.x - 10.0)))
	if ranges.is_empty():
		return {}
	var selected: Vector2 = ranges[random_source.randi_range(0, ranges.size() - 1)]
	return {
		"x": random_source.randf_range(selected.x, selected.y),
		"y": random_source.randf_range(-30.0, -10.0),
		"size": random_source.randi_range(8, 14),
		"rotation": random_source.randf_range(0.0, 360.0),
		"rot_speed": random_source.randf_range(-2.0, 2.0),
		"fall_speed": random_source.randf_range(0.35, 0.6),
		"sway_offset": random_source.randf_range(0.0, TAU),
		"sprite_index": random_source.randi_range(0, 5),
	}


func build_leaf_particle(
	origin: Vector2,
	side: String,
	speed_scale: float,
	random_source: RandomNumberGenerator,
	particle_life_sec: float = DEFAULT_LEAF_PARTICLE_LIFE_SEC
) -> Dictionary:
	var side_dir: Vector2 = _get_leaf_particle_direction(side)
	var spread_angle: float = random_source.randf_range(-0.82, 0.82)
	var base_speed: float = random_source.randf_range(92.0, 210.0) * speed_scale
	var vel: Vector2 = side_dir.rotated(spread_angle) * base_speed
	vel.y += random_source.randf_range(-76.0, 46.0)
	return {
		"pos": origin + Vector2(random_source.randf_range(-7.0, 7.0), random_source.randf_range(-13.0, 13.0)),
		"vel": vel,
		"life": particle_life_sec * random_source.randf_range(0.72, 1.12),
		"max_life": particle_life_sec,
		"size": random_source.randf_range(6.0, 14.0),
		"rot": random_source.randf_range(0.0, TAU),
		"spin": random_source.randf_range(-8.0, 8.0),
		"color": Color(
			random_source.randf_range(0.15, 0.34),
			random_source.randf_range(0.42, 0.72),
			random_source.randf_range(0.12, 0.30),
			1.0
		),
	}


func _get_leaf_particle_direction(side: String) -> Vector2:
	if side == "right":
		return Vector2.LEFT
	if side == "top":
		return Vector2.DOWN
	if side == "bottom":
		return Vector2.UP
	return Vector2.RIGHT
