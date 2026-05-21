extends RefCounted


static func get_reward_color(reward_type: String) -> Color:
	match reward_type:
		"active":
			return Color(0.10, 0.52, 0.62, 1.0)
		"passive":
			return Color(0.50, 0.36, 0.10, 1.0)
		"mythic":
			return Color(0.32, 0.10, 0.50, 1.0)
		"starpoint":
			return Color(0.86, 0.52, 0.10, 1.0)
		"perk", "skill":
			return Color(0.18, 0.36, 0.58, 1.0)
	return Color(0.40, 0.32, 0.20, 1.0)


static func get_reward_badge(reward: Dictionary) -> String:
	var reward_type: String = str(reward.get("type", ""))
	match reward_type:
		"active":
			return "ACTIVE"
		"passive":
			return "PASSIVE"
		"mythic":
			return "MYTHIC"
		"starpoint":
			return "PERK"
		"perk", "skill":
			return "PERK"
	return "REWARD"


static func get_result_reward_source_label(
	source_key: String,
	stage_source: String,
	box_source: String,
	stage_label: String,
	box_label: String
) -> String:
	match source_key:
		stage_source:
			return stage_label
		box_source:
			return box_label
	return ""


static func get_result_reward_source_labels(
	stage_source: String,
	box_source: String,
	stage_label: String,
	box_label: String
) -> Dictionary:
	return {
		stage_source: stage_label,
		box_source: box_label,
	}


static func get_result_reward_source_color(source_key: String, stage_source: String, box_source: String) -> Color:
	if source_key == stage_source:
		return Color(0.04, 0.32, 0.36, 1.0)
	if source_key == box_source:
		return Color(0.46, 0.22, 0.08, 1.0)
	return Color(0.18, 0.24, 0.28, 1.0)
