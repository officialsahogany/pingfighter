extends RefCounted

const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultCinematicPositionHelper := preload("res://scripts/ui/stage_clear_result_cinematic_position_helper.gd")


static func try_grant_immediate_reward(
	boxes: Array,
	index: int,
	immediate_reward_callback: Callable,
	view_size: Vector2,
	draw_scale: float,
	timer: float
) -> Dictionary:
	if index < 0 or index >= boxes.size():
		return {"granted": false, "boxes": boxes, "reward": {}}
	var box: Dictionary = boxes[index] if boxes[index] is Dictionary else {}
	var cinematic_positions: Dictionary = StageClearResultCinematicPositionHelper.get_reward_cinematic_positions(
		box,
		view_size,
		draw_scale,
		timer
	)
	return StageClearResultBoxData.try_grant_immediate_reward(
		boxes,
		index,
		immediate_reward_callback,
		cinematic_positions
	)


static func try_grant_opened_indices(
	boxes: Array,
	opened_indices: Array,
	immediate_reward_callback: Callable,
	view_size: Vector2,
	draw_scale: float,
	timer: float
) -> Dictionary:
	var updated_boxes: Array = boxes
	for index_value in opened_indices:
		var index: int = int(index_value)
		if index < 0 or index >= updated_boxes.size() or not (updated_boxes[index] is Dictionary):
			continue
		var result: Dictionary = try_grant_immediate_reward(
			updated_boxes,
			index,
			immediate_reward_callback,
			view_size,
			draw_scale,
			timer
		)
		updated_boxes = result.get("boxes", updated_boxes)
	return {"boxes": updated_boxes}
