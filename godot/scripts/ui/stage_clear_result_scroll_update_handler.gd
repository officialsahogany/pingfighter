extends RefCounted

const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")


static func update_scroll(
	scroll_phase: String,
	scroll_timer: float,
	delta: float,
	boxes: Array,
	blocked: bool
) -> Dictionary:
	return StageClearResultScrollState.update_phase(
		scroll_phase,
		scroll_timer,
		delta,
		blocked,
		StageClearResultInteractionState.all_boxes_opened(boxes),
		StageClearResultScrollState.SCROLL_DELAY,
		StageClearResultScrollState.SCROLL_UNFURL_DURATION
	)


static func get_scroll_update_apply_result(
	update_result: Dictionary,
	current_scroll_phase: String,
	current_scroll_timer: float
) -> Dictionary:
	return {
		"scroll_phase": str(update_result.get("phase", current_scroll_phase)),
		"scroll_timer": float(update_result.get("timer", current_scroll_timer)),
	}


static func get_scroll_update_scene_apply_result(
	update_result: Dictionary,
	current_scroll_phase: String,
	current_scroll_timer: float
) -> Dictionary:
	var apply_result: Dictionary = get_scroll_update_apply_result(
		update_result,
		current_scroll_phase,
		current_scroll_timer
	)
	return {
		"_scroll_phase": str(apply_result.get("scroll_phase", current_scroll_phase)),
		"_scroll_timer": float(apply_result.get("scroll_timer", current_scroll_timer)),
	}
