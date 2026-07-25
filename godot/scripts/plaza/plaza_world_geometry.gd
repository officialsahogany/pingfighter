extends RefCounted


static func fit_game_rect(view_size: Vector2, game_size: Vector2) -> Rect2:
	if view_size.x <= 0.0 or view_size.y <= 0.0 or game_size.x <= 0.0 or game_size.y <= 0.0:
		return Rect2()
	var scale: float = min(view_size.x / game_size.x, view_size.y / game_size.y)
	var fitted_size := game_size * scale
	return Rect2((view_size - fitted_size) * 0.5, fitted_size)


static func get_game_scale(rendered_size: Vector2, game_size: Vector2) -> float:
	return rendered_size.x / game_size.x if game_size.x > 0.0 else 1.0


static func normalize_player_position(
	position: Vector2,
	map_size: Vector2,
	ground_y: float,
	player_collision_size: Vector2
) -> Vector2:
	return Vector2(
		clampf(position.x, player_collision_size.x * 0.5, map_size.x - player_collision_size.x * 0.5),
		ground_y
	)


static func get_target_camera_x(
	player_x: float,
	game_width: float,
	map_width: float,
	lead_x: float
) -> float:
	return clampf(player_x - game_width * 0.5 + lead_x, 0.0, maxf(0.0, map_width - game_width))


static func world_to_local(world_position: Vector2, camera_x: float, scale: float) -> Vector2:
	return Vector2(world_position.x - camera_x, world_position.y) * scale


static func world_rect_to_local(world_rect: Rect2, camera_x: float, scale: float) -> Rect2:
	return Rect2(world_to_local(world_rect.position, camera_x, scale), world_rect.size * scale)


static func screen_to_world(
	screen_position: Vector2,
	game_global_position: Vector2,
	camera_x: float,
	scale: float
) -> Vector2:
	if scale <= 0.0:
		return Vector2.ZERO
	var local_position := screen_position - game_global_position
	return Vector2(local_position.x / scale + camera_x, local_position.y / scale)


static func screen_to_local_game(
	screen_position: Vector2,
	game_global_position: Vector2,
	scale: float
) -> Vector2:
	if scale <= 0.0:
		return Vector2.ZERO
	return (screen_position - game_global_position) / scale


static func find_interactable_building(building_specs: Array, player_position: Vector2) -> Dictionary:
	for spec_value in building_specs:
		if not spec_value is Dictionary:
			continue
		var spec: Dictionary = spec_value
		var interaction_rect: Rect2 = spec.get("interaction_rect", Rect2())
		if interaction_rect.has_point(player_position):
			return spec
	return {}


static func find_building_at_world_position(building_specs: Array, world_position: Vector2) -> Dictionary:
	# Reverse order preserves front-most (last-drawn) picking on overlaps.
	for index in range(building_specs.size() - 1, -1, -1):
		var spec_value: Variant = building_specs[index]
		if not spec_value is Dictionary:
			continue
		var spec: Dictionary = spec_value
		var visual_rect: Rect2 = spec.get("visual_rect", Rect2())
		if visual_rect.size != Vector2.ZERO and visual_rect.has_point(world_position):
			return spec
		var interaction_rect: Rect2 = spec.get("interaction_rect", Rect2())
		if interaction_rect.has_point(world_position):
			return spec
	return {}
