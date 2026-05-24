extends RefCounted

const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func is_supported_hit_kind(hit_kind: String) -> bool:
	return hit_kind == "headshot" or hit_kind == "legshot"


static func build_feedback(
	hit_kind: String,
	boss_rect: Rect2,
	field_size: Vector2,
	timer_frames: float,
	headshot_text: String,
	legshot_text: String
) -> Dictionary:
	if not is_supported_hit_kind(hit_kind):
		return {}
	var text_pos := Vector2(
		clamp(boss_rect.position.x - 30.0, 62.0, field_size.x - 62.0),
		clamp(boss_rect.end.y - 20.0, 42.0, field_size.y - 42.0)
	)
	var wave_pos := Vector2(
		clamp(boss_rect.position.x + boss_rect.size.x * 0.5, 60.0, field_size.x - 60.0),
		clamp(boss_rect.position.y + 6.0, 34.0, field_size.y - 34.0)
	)
	return {
		"kind": hit_kind,
		"text": headshot_text if hit_kind == "headshot" else legshot_text,
		"text_pos": text_pos,
		"wave_pos": wave_pos,
		"timer_frames": timer_frames,
		"max_timer_frames": timer_frames,
	}


static func append_feedback(
	feedbacks: Array,
	hit_kind: String,
	boss_rect: Rect2,
	field_size: Vector2,
	timer_frames: float,
	headshot_text: String,
	legshot_text: String,
	feedback_limit: int
) -> void:
	var feedback: Dictionary = build_feedback(
		hit_kind,
		boss_rect,
		field_size,
		timer_frames,
		headshot_text,
		legshot_text
	)
	if feedback.is_empty():
		return
	CommandoFirearmValueUtils.append_limited(feedbacks, feedback, feedback_limit)


static func advance_feedback(feedback: Dictionary, fps_scale: float) -> Dictionary:
	var step: float = max(0.0, fps_scale)
	var next_feedback: Dictionary = feedback.duplicate(true)
	var timer: float = max(0.0, float(next_feedback.get("timer_frames", 0.0)) - step)
	if timer <= 0.0:
		return {"active": false}
	next_feedback["timer_frames"] = timer
	return {
		"active": true,
		"feedback": next_feedback,
	}


static func advance_feedbacks(feedbacks: Array, fps_scale: float) -> Array:
	var step: float = max(0.0, fps_scale)
	if step <= 0.0:
		return feedbacks.duplicate(true)
	var next_feedbacks: Array = []
	for value in feedbacks:
		var feedback: Dictionary = CommandoFirearmValueUtils.get_dict(value)
		var update_result: Dictionary = advance_feedback(feedback, step)
		if bool(update_result.get("active", false)):
			next_feedbacks.append(CommandoFirearmValueUtils.get_dict(update_result.get("feedback", feedback)))
	return next_feedbacks
