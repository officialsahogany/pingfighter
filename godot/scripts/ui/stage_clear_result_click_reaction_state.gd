extends RefCounted


static func get_base_frame(base_timer: float, frame_interval: float, frame_count: int) -> int:
	var safe_count: int = max(1, frame_count)
	return int(floor(base_timer / max(0.001, frame_interval))) % safe_count


static func get_reaction_frame(
	reaction_timer: float,
	reaction_duration: float,
	click_frame_interval: float,
	frame_count: int
) -> int:
	var safe_count: int = max(1, frame_count)
	if reaction_timer >= reaction_duration:
		return safe_count - 1
	return clampi(
		int(floor(reaction_timer / max(0.001, click_frame_interval))),
		0,
		safe_count - 1
	)


static func get_transition_base_frame(
	reaction_timer: float,
	transition_duration: float,
	transition_base_frame: int,
	current_base_frame: int
) -> int:
	if reaction_timer <= transition_duration:
		return transition_base_frame
	return current_base_frame


static func get_reaction_alpha(
	reaction_timer: float,
	reaction_duration: float,
	transition_duration: float,
	return_hold_duration: float,
	return_fade_duration: float,
	total_duration: float
) -> float:
	if not is_reaction_active(reaction_timer, total_duration):
		return 0.0
	if reaction_timer <= transition_duration:
		return smooth01(reaction_timer / max(0.001, transition_duration))
	if reaction_timer >= reaction_duration:
		var blend_elapsed: float = reaction_timer - reaction_duration
		if blend_elapsed < return_hold_duration:
			return 1.0
		var fade_elapsed: float = blend_elapsed - return_hold_duration
		var fade_progress: float = clamp(fade_elapsed / max(0.001, return_fade_duration), 0.0, 1.0)
		return smooth01(1.0 - fade_progress)
	return 1.0


static func is_reaction_active(reaction_timer: float, total_duration: float) -> bool:
	return reaction_timer < total_duration


static func advance_reaction_timer(reaction_timer: float, total_duration: float, delta: float) -> float:
	if not is_reaction_active(reaction_timer, total_duration):
		return reaction_timer
	return min(total_duration, reaction_timer + max(0.0, delta))


static func is_return_blend_active(reaction_timer: float, reaction_duration: float, total_duration: float) -> bool:
	return reaction_timer >= reaction_duration and reaction_timer < total_duration


static func get_click_reaction_attempt(
	mouse_position: Vector2,
	click_rect: Rect2,
	reaction_timer: float,
	total_duration: float,
	base_timer: float,
	base_frame_interval: float,
	frame_count: int
) -> Dictionary:
	if not click_rect.has_point(mouse_position):
		return {
			"handled": false,
			"started": false,
			"click_rect": click_rect,
		}

	if is_reaction_active(reaction_timer, total_duration):
		return {
			"handled": true,
			"started": false,
			"click_rect": click_rect,
		}

	return {
		"handled": true,
		"started": true,
		"click_rect": click_rect,
		"transition_base_frame": get_base_frame(base_timer, base_frame_interval, frame_count),
		"reaction_timer": 0.0,
	}


static func get_reaction_state(
	base_timer: float,
	base_frame_interval: float,
	frame_count: int,
	reaction_timer: float,
	reaction_duration: float,
	click_frame_interval: float,
	transition_duration: float,
	transition_base_frame: int,
	return_hold_duration: float,
	return_fade_duration: float,
	total_duration: float
) -> Dictionary:
	var base_frame: int = get_base_frame(base_timer, base_frame_interval, frame_count)
	return {
		"base_frame": base_frame,
		"reaction_frame": get_reaction_frame(reaction_timer, reaction_duration, click_frame_interval, frame_count),
		"transition_base_frame": get_transition_base_frame(reaction_timer, transition_duration, transition_base_frame, base_frame),
		"reaction_alpha": get_reaction_alpha(
			reaction_timer,
			reaction_duration,
			transition_duration,
			return_hold_duration,
			return_fade_duration,
			total_duration
		),
		"reaction_active": is_reaction_active(reaction_timer, total_duration),
		"return_blend_active": is_return_blend_active(reaction_timer, reaction_duration, total_duration),
	}


static func smooth01(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
