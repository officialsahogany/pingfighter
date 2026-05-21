extends RefCounted


static func calculate_starpoint_total(boxes: Array) -> int:
	var total: int = 0
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		var reward: Variant = box.get("reward", {})
		if not (reward is Dictionary):
			continue
		var reward_dict: Dictionary = reward
		if str(reward_dict.get("type", "")) == "starpoint":
			total += int(reward_dict.get("amount", 0))
	return total


static func build_item_summary(
	stage_reward_snapshot: Dictionary,
	boxes: Array,
	stage_source: String,
	box_source: String,
	source_labels: Dictionary
) -> Array:
	var items: Array = []
	for reward in get_stage_summary_array(stage_reward_snapshot, "passive_items"):
		if reward is Dictionary:
			items.append(with_result_reward_source(reward as Dictionary, stage_source, source_labels))
	for reward in get_stage_summary_array(stage_reward_snapshot, "active_items"):
		if reward is Dictionary:
			items.append(with_result_reward_source(reward as Dictionary, stage_source, source_labels))
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		var reward: Variant = box.get("reward", {})
		if not (reward is Dictionary):
			continue
		var reward_dict: Dictionary = reward
		var reward_type: String = str(reward_dict.get("type", ""))
		if reward_type == "active" or reward_type == "passive" or reward_type == "mythic":
			items.append(with_result_reward_source(reward_dict, box_source, source_labels))
	return items


static func build_perk_summary(
	stage_reward_snapshot: Dictionary,
	boxes: Array,
	stage_source: String,
	box_source: String,
	source_labels: Dictionary
) -> Array:
	var perks: Array = []
	for reward in get_stage_summary_array(stage_reward_snapshot, "perks"):
		if reward is Dictionary:
			perks.append(with_result_reward_source(reward as Dictionary, stage_source, source_labels))
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		var reward: Variant = box.get("reward", {})
		if not (reward is Dictionary):
			continue
		var reward_dict: Dictionary = reward
		if is_perk_reward(reward_dict):
			perks.append(with_result_reward_source(reward_dict, box_source, source_labels))
	return perks


static func build_visible_reward_summary(
	stage_reward_snapshot: Dictionary,
	boxes: Array,
	stage_source: String,
	box_source: String,
	source_labels: Dictionary
) -> Array:
	var rewards: Array = []
	for reward in get_stage_summary_array(stage_reward_snapshot, "passive_items"):
		if reward is Dictionary:
			rewards.append(with_result_reward_source(reward as Dictionary, stage_source, source_labels))
	for reward in get_stage_summary_array(stage_reward_snapshot, "active_items"):
		if reward is Dictionary:
			rewards.append(with_result_reward_source(reward as Dictionary, stage_source, source_labels))
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		var reward: Variant = box.get("reward", {})
		if not (reward is Dictionary):
			continue
		var reward_dict: Dictionary = reward
		var reward_type: String = str(reward_dict.get("type", ""))
		if reward_type == "active" or reward_type == "passive" or reward_type == "mythic" or reward_type == "starpoint":
			rewards.append(with_result_reward_source(reward_dict, box_source, source_labels))
	return rewards


static func with_result_reward_source(reward: Dictionary, result_source: String, source_labels: Dictionary) -> Dictionary:
	var copy: Dictionary = reward.duplicate(true)
	copy["_result_reward_source"] = result_source
	copy["_result_reward_source_label"] = str(source_labels.get(result_source, ""))
	return copy


static func count_result_reward_sources(rewards: Array, known_sources: Array) -> Dictionary:
	var counts: Dictionary = {}
	for source_value in known_sources:
		counts[str(source_value)] = 0
	for reward_value in rewards:
		if not (reward_value is Dictionary):
			continue
		var reward: Dictionary = reward_value
		var source_key: String = str(reward.get("_result_reward_source", ""))
		if source_key == "":
			continue
		counts[source_key] = int(counts.get(source_key, 0)) + 1
	return counts


static func get_stage_summary_array(stage_reward_snapshot: Dictionary, key: String) -> Array:
	var value: Variant = stage_reward_snapshot.get(key, [])
	if value is Array:
		return (value as Array).duplicate(true)
	return []


static func is_perk_reward(reward: Dictionary) -> bool:
	var reward_type: String = str(reward.get("type", ""))
	return reward_type == "perk" or reward_type == "skill" or get_reward_perk_id(reward) != ""


static func get_reward_perk_id(reward: Dictionary) -> String:
	for key in ["perk_id", "skill_id", "id"]:
		var value: String = str(reward.get(key, ""))
		if value != "":
			return value
	var perk_data: Variant = reward.get("perk_data", {})
	if perk_data is Dictionary:
		return str((perk_data as Dictionary).get("id", ""))
	return ""
