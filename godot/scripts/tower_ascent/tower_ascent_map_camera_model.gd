extends RefCounted


static func minimum_cover_zoom(view_rect: Rect2, world_rect: Rect2) -> float:
	if view_rect.size.x <= 0.0 or view_rect.size.y <= 0.0:
		return 1.0
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return 1.0
	return maxf(
		view_rect.size.x / world_rect.size.x,
		view_rect.size.y / world_rect.size.y
	)


static func build(
	content_rect: Rect2,
	world_rect: Rect2,
	focus_world_position: Vector2,
	boundary_padding: float,
	focus_y_ratio: float = 0.5,
	zoom_multiplier: float = 1.0,
	focus_x_blend: float = 0.0
) -> Dictionary:
	if content_rect.size.x <= 0.0 or content_rect.size.y <= 0.0:
		return {}
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return {}
	var safe_padding := maxf(0.0, boundary_padding)
	var safe_zoom := maxf(1.0, zoom_multiplier)
	var padded_left := (world_rect.position.x - safe_padding) * safe_zoom
	var padded_right := (world_rect.end.x + safe_padding) * safe_zoom
	var padded_top := (world_rect.position.y - safe_padding) * safe_zoom
	var padded_bottom := (world_rect.end.y + safe_padding) * safe_zoom
	var minimum_offset_x := content_rect.end.x - padded_right
	var maximum_offset_x := content_rect.position.x - padded_left
	var minimum_offset_y := content_rect.end.y - padded_bottom
	var maximum_offset_y := content_rect.position.y - padded_top
	var desired_screen_x := lerpf(
		focus_world_position.x,
		content_rect.get_center().x,
		clampf(focus_x_blend, 0.0, 1.0)
	)
	var desired_screen_y := lerpf(
		content_rect.position.y,
		content_rect.end.y,
		clampf(focus_y_ratio, 0.0, 1.0)
	)
	var desired_offset_x := desired_screen_x - focus_world_position.x * safe_zoom
	var desired_offset_y := desired_screen_y - focus_world_position.y * safe_zoom
	var horizontal_world_fits := (
		(world_rect.size.x + safe_padding * 2.0) * safe_zoom <= content_rect.size.x
	)
	var vertical_world_fits := (
		(world_rect.size.y + safe_padding * 2.0) * safe_zoom <= content_rect.size.y
	)
	var offset_x := (
		content_rect.get_center().x - world_rect.get_center().x * safe_zoom
		if horizontal_world_fits
		else clampf(desired_offset_x, minimum_offset_x, maximum_offset_x)
	)
	var offset_y := (
		content_rect.get_center().y - world_rect.get_center().y * safe_zoom
		if vertical_world_fits
		else clampf(desired_offset_y, minimum_offset_y, maximum_offset_y)
	)
	var screen_offset := Vector2(offset_x, offset_y)
	var focus_screen_position := focus_world_position * safe_zoom + screen_offset
	return {
		"offset": screen_offset,
		"zoom_multiplier": safe_zoom,
		"focus_world_position": focus_world_position,
		"focus_screen_position": focus_screen_position,
		"visible_world_rect": Rect2(
			(content_rect.position - screen_offset) / safe_zoom,
			content_rect.size / safe_zoom
		),
		"minimum_offset_x": minimum_offset_x,
		"maximum_offset_x": maximum_offset_x,
		"minimum_offset_y": minimum_offset_y,
		"maximum_offset_y": maximum_offset_y,
		"horizontal_world_fits": horizontal_world_fits,
		"vertical_world_fits": vertical_world_fits,
		"at_left_boundary": not horizontal_world_fits and is_equal_approx(offset_x, maximum_offset_x),
		"at_right_boundary": not horizontal_world_fits and is_equal_approx(offset_x, minimum_offset_x),
		"at_lower_boundary": not vertical_world_fits and is_equal_approx(offset_y, minimum_offset_y),
		"at_upper_boundary": not vertical_world_fits and is_equal_approx(offset_y, maximum_offset_y),
	}
