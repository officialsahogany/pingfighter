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


static func cursor_anchored_offset(
	cursor_screen_position: Vector2,
	old_offset: Vector2,
	old_zoom: float,
	new_zoom: float
) -> Vector2:
	var safe_old_zoom := maxf(0.001, old_zoom)
	var safe_new_zoom := maxf(0.001, new_zoom)
	# The world point below the cursor is invariant:
	# offset' = cursor - (cursor - offset) * (z' / z).
	return (
		cursor_screen_position
		- (cursor_screen_position - old_offset) * (safe_new_zoom / safe_old_zoom)
	)


static func build_cursor_zoom_override(
	camera_model: Dictionary,
	cursor_screen_position: Vector2,
	requested_zoom: float,
	minimum_zoom: float,
	maximum_zoom: float
) -> Dictionary:
	if camera_model.is_empty():
		return {}
	var view_rect: Rect2 = camera_model.get("view_rect", Rect2())
	var world_rect: Rect2 = camera_model.get("world_rect", Rect2())
	if view_rect.size.x <= 0.0 or view_rect.size.y <= 0.0:
		return {}
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return {}
	var safe_minimum := maxf(minimum_cover_zoom(view_rect, world_rect), minimum_zoom)
	var safe_maximum := maxf(safe_minimum, maximum_zoom)
	var old_zoom := maxf(
		0.001,
		float(camera_model.get(
			"render_zoom_multiplier",
			camera_model.get("zoom_multiplier", 1.0)
		))
	)
	var new_zoom := clampf(requested_zoom, safe_minimum, safe_maximum)
	var old_offset: Vector2 = camera_model.get("offset", Vector2.ZERO)
	var requested_offset := cursor_anchored_offset(
		cursor_screen_position,
		old_offset,
		old_zoom,
		new_zoom
	)
	var rebuilt := build(
		view_rect,
		world_rect,
		camera_model.get("focus_world_position", world_rect.get_center()),
		0.0,
		0.5,
		new_zoom,
		0.0
	)
	apply_offset_override(rebuilt, requested_offset)
	rebuilt["minimum_cover_zoom"] = safe_minimum
	rebuilt["maximum_zoom"] = safe_maximum
	rebuilt["render_zoom_multiplier"] = new_zoom
	rebuilt["zoom_multiplier"] = new_zoom
	return rebuilt


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
		"view_rect": content_rect,
		"world_rect": world_rect,
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


static func apply_offset_override(
	camera_model: Dictionary,
	requested_offset: Vector2
) -> void:
	if camera_model.is_empty():
		return
	var minimum_offset_x := float(camera_model.get("minimum_offset_x", 0.0))
	var maximum_offset_x := float(camera_model.get("maximum_offset_x", 0.0))
	var minimum_offset_y := float(camera_model.get("minimum_offset_y", 0.0))
	var maximum_offset_y := float(camera_model.get("maximum_offset_y", 0.0))
	var offset := Vector2(
		clampf(requested_offset.x, minimum_offset_x, maximum_offset_x),
		clampf(requested_offset.y, minimum_offset_y, maximum_offset_y)
	)
	var zoom := float(camera_model.get("zoom_multiplier", 1.0))
	var view_rect: Rect2 = camera_model.get("view_rect", Rect2())
	var focus_world_position: Vector2 = camera_model.get(
		"focus_world_position",
		Vector2.ZERO
	)
	var horizontal_world_fits := bool(camera_model.get("horizontal_world_fits", false))
	var vertical_world_fits := bool(camera_model.get("vertical_world_fits", false))
	camera_model["offset"] = offset
	camera_model["focus_screen_position"] = focus_world_position * zoom + offset
	camera_model["visible_world_rect"] = Rect2(
		(view_rect.position - offset) / zoom,
		view_rect.size / zoom
	)
	camera_model["at_left_boundary"] = (
		not horizontal_world_fits
		and is_equal_approx(offset.x, maximum_offset_x)
	)
	camera_model["at_right_boundary"] = (
		not horizontal_world_fits
		and is_equal_approx(offset.x, minimum_offset_x)
	)
	camera_model["at_lower_boundary"] = (
		not vertical_world_fits
		and is_equal_approx(offset.y, minimum_offset_y)
	)
	camera_model["at_upper_boundary"] = (
		not vertical_world_fits
		and is_equal_approx(offset.y, maximum_offset_y)
	)
