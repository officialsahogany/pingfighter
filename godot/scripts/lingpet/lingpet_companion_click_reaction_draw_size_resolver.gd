extends RefCounted

const CLICK_REACTION_DRAW_SIZE_KEY := "click_reaction_draw_size"
const COMPANION_WALK_DRAW_SIZE_KEY := "companion_walk_draw_size"


func resolve(profile: Object, fallback_size: float) -> Vector2:
	if profile == null or not profile.has_method("get_visual_layout_value"):
		return Vector2(fallback_size, fallback_size)
	var click_draw_size: float = float(profile.get_visual_layout_value(CLICK_REACTION_DRAW_SIZE_KEY, 0.0))
	if click_draw_size > 0.0:
		return Vector2(click_draw_size, click_draw_size)
	var draw_size: float = float(profile.get_visual_layout_value(COMPANION_WALK_DRAW_SIZE_KEY, fallback_size))
	if draw_size <= 0.0:
		draw_size = fallback_size
	return Vector2(draw_size, draw_size)
