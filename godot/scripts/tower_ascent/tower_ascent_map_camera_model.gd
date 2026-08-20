extends RefCounted


static func build(
	content_rect: Rect2,
	world_rect: Rect2,
	focus_world_position: Vector2,
	boundary_padding: float,
	focus_y_ratio: float = 0.5
) -> Dictionary:
	if content_rect.size.x <= 0.0 or content_rect.size.y <= 0.0:
		return {}
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return {}
	var safe_padding := maxf(0.0, boundary_padding)
	var padded_top := world_rect.position.y - safe_padding
	var padded_bottom := world_rect.end.y + safe_padding
	var minimum_offset := content_rect.end.y - padded_bottom
	var maximum_offset := content_rect.position.y - padded_top
	var desired_screen_y := lerpf(
		content_rect.position.y,
		content_rect.end.y,
		clampf(focus_y_ratio, 0.0, 1.0)
	)
	var desired_offset := desired_screen_y - focus_world_position.y
	var offset_y := clampf(desired_offset, minimum_offset, maximum_offset)
	var screen_offset := Vector2(0.0, offset_y)
	return {
		"offset": screen_offset,
		"focus_world_position": focus_world_position,
		"focus_screen_position": focus_world_position + screen_offset,
		"visible_world_rect": Rect2(
			content_rect.position - screen_offset,
			content_rect.size
		),
		"minimum_offset_y": minimum_offset,
		"maximum_offset_y": maximum_offset,
		"at_lower_boundary": is_equal_approx(offset_y, minimum_offset),
		"at_upper_boundary": is_equal_approx(offset_y, maximum_offset),
	}
