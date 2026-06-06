extends RefCounted

const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultImmediateRewardHelper := preload("res://scripts/ui/stage_clear_result_immediate_reward_helper.gd")


static func update_boxes(
	boxes: Array,
	delta: float,
	lid_open_counter: int,
	immediate_reward_callback: Callable,
	view_size: Vector2,
	draw_scale: float,
	timer: float
) -> Dictionary:
	var update_result: Dictionary = StageClearResultBoxData.update_box_opening_state(
		boxes,
		delta,
		lid_open_counter
	)
	var updated_boxes: Array = update_result.get("boxes", boxes)
	var opened_indices: Array = update_result.get("opened_indices", [])
	if not opened_indices.is_empty():
		var grant_result: Dictionary = StageClearResultImmediateRewardHelper.try_grant_opened_indices(
			updated_boxes,
			opened_indices,
			immediate_reward_callback,
			view_size,
			draw_scale,
			timer
		)
		updated_boxes = grant_result.get("boxes", updated_boxes)
	return {
		"boxes": updated_boxes,
		"lid_open_counter": int(update_result.get("lid_open_counter", lid_open_counter)),
		"opened_indices": opened_indices,
	}


static func get_box_update_apply_result(
	update_result: Dictionary,
	current_boxes: Array,
	current_lid_open_counter: int
) -> Dictionary:
	var boxes_value: Variant = update_result.get("boxes", current_boxes)
	return {
		"boxes": boxes_value if boxes_value is Array else current_boxes,
		"lid_open_counter": int(update_result.get("lid_open_counter", current_lid_open_counter)),
	}


static func get_box_update_scene_apply_result(
	update_result: Dictionary,
	current_boxes: Array,
	current_lid_open_counter: int
) -> Dictionary:
	var apply_result: Dictionary = get_box_update_apply_result(
		update_result,
		current_boxes,
		current_lid_open_counter
	)
	return {
		"_boxes": apply_result.get("boxes", current_boxes),
		"_lid_open_counter": int(apply_result.get("lid_open_counter", current_lid_open_counter)),
	}
