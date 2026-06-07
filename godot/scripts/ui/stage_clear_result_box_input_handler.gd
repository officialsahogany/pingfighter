extends RefCounted

const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")

const PHASE_HIDDEN := "hidden"


static func open_next_idle_box(boxes: Array, reward_roll_callback: Callable) -> Dictionary:
	var next_idle_index: int = StageClearResultBoxData.get_next_idle_box_index(boxes)
	return open_box_at_index(boxes, next_idle_index, reward_roll_callback)


static func open_box_at_index(boxes: Array, index: int, reward_roll_callback: Callable) -> Dictionary:
	var result: Dictionary = StageClearResultBoxData.start_opening_box_with_roll(
		boxes,
		index,
		reward_roll_callback
	)
	result["opened_index"] = index
	result["consumed"] = bool(result.get("started", false))
	return result


static func get_box_click_result(
	boxes: Array,
	mouse_position: Vector2,
	scroll_phase: String,
	blocked: bool,
	draw_scale: float,
	timer: float,
	reward_roll_callback: Callable
) -> Dictionary:
	if boxes.is_empty():
		return _empty_result(boxes)
	if blocked:
		var blocked_result: Dictionary = _empty_result(boxes)
		blocked_result["consumed"] = true
		blocked_result["blocked"] = true
		return blocked_result
	if scroll_phase != PHASE_HIDDEN:
		return _empty_result(boxes)
	var clicked_index: int = StageClearResultInteractionState.get_clicked_idle_box_index(
		boxes,
		mouse_position,
		draw_scale,
		timer
	)
	return open_box_at_index(boxes, clicked_index, reward_roll_callback)


static func get_hovered_box_result(
	boxes: Array,
	mouse_position: Vector2,
	draw_scale: float,
	timer: float,
	previous_hovered_index: int
) -> Dictionary:
	if boxes.is_empty():
		return {
			"hovered_box_index": -1,
			"changed": previous_hovered_index != -1,
		}
	var hovered_index: int = StageClearResultInteractionState.get_hovered_box_index(
		boxes,
		mouse_position,
		draw_scale,
		timer
	)
	return {
		"hovered_box_index": hovered_index,
		"changed": hovered_index != previous_hovered_index,
	}


static func get_hovered_box_apply_result(
	hover_result: Dictionary,
	current_hovered_box_index: int
) -> Dictionary:
	return {
		"hovered_box_index": int(hover_result.get("hovered_box_index", current_hovered_box_index)),
		"redraw": bool(hover_result.get("changed", false)),
	}


static func get_box_open_apply_result(
	open_result: Dictionary,
	current_boxes: Array,
	current_hovered_box_index: int
) -> Dictionary:
	if not bool(open_result.get("started", false)):
		return {
			"started": false,
			"consumed": bool(open_result.get("consumed", false)),
			"boxes": current_boxes,
			"hovered_box_index": current_hovered_box_index,
			"play_open_audio": false,
			"redraw": false,
		}
	var opened_index: int = int(open_result.get("opened_index", -1))
	return {
		"started": true,
		"consumed": bool(open_result.get("consumed", true)),
		"boxes": open_result.get("boxes", current_boxes),
		"hovered_box_index": -1 if current_hovered_box_index == opened_index else current_hovered_box_index,
		"play_open_audio": true,
		"redraw": true,
	}


static func get_box_state_apply_result(
	box_state_result: Dictionary,
	current_boxes: Array,
	current_hovered_box_index: int
) -> Dictionary:
	var boxes_value: Variant = box_state_result.get("boxes", current_boxes)
	return {
		"started": bool(box_state_result.get("started", false)),
		"consumed": bool(box_state_result.get("consumed", false)),
		"boxes": boxes_value if boxes_value is Array else current_boxes,
		"hovered_box_index": int(box_state_result.get("hovered_box_index", current_hovered_box_index)),
		"play_open_audio": bool(box_state_result.get("play_open_audio", false)),
		"redraw": bool(box_state_result.get("redraw", false)),
	}


static func get_box_state_scene_apply_result(
	box_state_result: Dictionary,
	current_boxes: Array,
	current_hovered_box_index: int
) -> Dictionary:
	var apply_result: Dictionary = get_box_state_apply_result(
		box_state_result,
		current_boxes,
		current_hovered_box_index
	)
	apply_result["field_payload"] = {
		"_boxes": apply_result.get("boxes", current_boxes),
		"_hovered_box_index": int(apply_result.get("hovered_box_index", current_hovered_box_index)),
	}
	return apply_result


static func _empty_result(boxes: Array) -> Dictionary:
	return {
		"started": false,
		"consumed": false,
		"boxes": boxes,
		"opened_index": -1,
	}
