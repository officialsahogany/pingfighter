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


static func is_return_blend_active(reaction_timer: float, reaction_duration: float, total_duration: float) -> bool:
	return reaction_timer >= reaction_duration and reaction_timer < total_duration


static func smooth01(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
