extends RefCounted

const BOX_KIND_NORMAL := "normal"


static func build_immediate_reward_payload(box: Dictionary, cinematic_positions: Dictionary) -> Dictionary:
	var reward_value: Variant = box.get("reward", {})
	if not (reward_value is Dictionary):
		return {}
	var reward: Dictionary = (reward_value as Dictionary).duplicate(true)
	if reward.is_empty():
		return {}
	reward["box_kind"] = str(box.get("kind", BOX_KIND_NORMAL))
	reward["box_state"] = str(box.get("state", "opened"))
	reward["pickup_position"] = cinematic_positions.get("pickup_position", Vector2.ZERO)
	reward["target_player_center"] = cinematic_positions.get("target_player_center", Vector2.ZERO)
	return reward


static func mark_immediate_reward_granted(boxes: Array, index: int) -> Array:
	if index < 0 or index >= boxes.size():
		return boxes
	var box: Dictionary = boxes[index] if boxes[index] is Dictionary else {}
	var updated_boxes: Array = boxes.duplicate(false)
	var updated_box: Dictionary = box.duplicate(true)
	updated_box["reward_immediate_granted"] = true
	var reward_value: Variant = updated_box.get("reward", {})
	if reward_value is Dictionary:
		var stored_reward: Dictionary = (reward_value as Dictionary).duplicate(true)
		stored_reward["immediate_granted"] = true
		updated_box["reward"] = stored_reward
	updated_boxes[index] = updated_box
	return updated_boxes


static func try_grant_immediate_reward(
	boxes: Array,
	index: int,
	immediate_reward_callback: Callable,
	cinematic_positions: Dictionary
) -> Dictionary:
	if index < 0 or index >= boxes.size():
		return {"granted": false, "boxes": boxes, "reward": {}}
	var box: Dictionary = boxes[index] if boxes[index] is Dictionary else {}
	if bool(box.get("reward_immediate_granted", false)):
		return {"granted": false, "boxes": boxes, "reward": {}}
	if not immediate_reward_callback.is_valid():
		return {"granted": false, "boxes": boxes, "reward": {}}
	var reward: Dictionary = build_immediate_reward_payload(box, cinematic_positions)
	if reward.is_empty():
		return {"granted": false, "boxes": boxes, "reward": {}}
	if not bool(immediate_reward_callback.call(reward, index)):
		return {"granted": false, "boxes": boxes, "reward": reward}
	return {
		"granted": true,
		"boxes": mark_immediate_reward_granted(boxes, index),
		"reward": reward,
	}
