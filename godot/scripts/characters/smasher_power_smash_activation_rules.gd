extends RefCounted


func can_activate(
	waiting_for_serve: bool,
	ball_active: bool,
	gauge: float,
	gauge_cost: float,
	freeze_active: bool,
	parabola_active: bool,
	frame_cooldown_blocked: bool,
	skill_cooldown_remaining: float
) -> bool:
	if waiting_for_serve or not ball_active:
		return false
	if gauge < gauge_cost:
		return false
	if freeze_active or parabola_active:
		return false
	if frame_cooldown_blocked:
		return false
	return skill_cooldown_remaining <= 0.0
