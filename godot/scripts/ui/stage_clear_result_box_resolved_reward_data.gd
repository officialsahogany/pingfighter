extends RefCounted

const BOX_KIND_NORMAL := "normal"


static func append_resolved_perk_reward(boxes: Array, index: int, perk_reward: Dictionary) -> Dictionary:
	if index < 0 or index >= boxes.size() or perk_reward.is_empty():
		return {"updated": false, "boxes": boxes}
	var box: Dictionary = boxes[index] if boxes[index] is Dictionary else {}
	var reward_value: Variant = box.get("reward", {})
	if not (reward_value is Dictionary):
		return {"updated": false, "boxes": boxes}
	var reward: Dictionary = reward_value
	if reward.is_empty() or str(reward.get("type", "")) != "starpoint":
		return {"updated": false, "boxes": boxes}
	var updated_boxes: Array = boxes.duplicate(false)
	var updated_box: Dictionary = box.duplicate(true)
	var updated_reward: Dictionary = updated_box.get("reward", {}) if updated_box.get("reward", {}) is Dictionary else {}
	var resolved_value: Variant = updated_reward.get("resolved_perk_rewards", [])
	var resolved: Array = resolved_value.duplicate(false) if resolved_value is Array else []
	var reward_copy: Dictionary = perk_reward.duplicate(true)
	reward_copy["source"] = "box_starpoint_choice"
	resolved.append(reward_copy)
	updated_reward["resolved_perk_rewards"] = resolved
	updated_reward["resolved_perk_count"] = resolved.size()
	updated_box["reward"] = updated_reward
	updated_boxes[index] = updated_box
	return {"updated": true, "boxes": updated_boxes}


static func get_append_resolved_perk_reward_apply_result(
	append_result: Dictionary,
	current_boxes: Array
) -> Dictionary:
	var updated: bool = bool(append_result.get("updated", false))
	return {
		"updated": updated,
		"boxes": append_result.get("boxes", current_boxes) if updated else current_boxes,
		"redraw": updated,
	}


static func get_append_resolved_perk_reward_scene_apply_result(
	append_result: Dictionary,
	current_boxes: Array
) -> Dictionary:
	var apply_result: Dictionary = get_append_resolved_perk_reward_apply_result(
		append_result,
		current_boxes
	)
	apply_result["field_payload"] = {
		"_boxes": apply_result.get("boxes", current_boxes),
	}
	return apply_result


static func get_resolved_rewards(boxes: Array) -> Array:
	var rewards: Array = []
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		var reward_value: Variant = box.get("reward", {})
		if not (reward_value is Dictionary):
			continue
		var reward: Dictionary = reward_value
		if reward.is_empty():
			continue
		var reward_copy: Dictionary = reward.duplicate(true)
		reward_copy["box_kind"] = str(box.get("kind", BOX_KIND_NORMAL))
		reward_copy["box_state"] = str(box.get("state", "idle"))
		rewards.append(reward_copy)
	return rewards
