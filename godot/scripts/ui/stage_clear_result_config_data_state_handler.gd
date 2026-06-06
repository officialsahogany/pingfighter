extends RefCounted


static func get_config_data_state(data: Dictionary, current_selected_character_type: String) -> Dictionary:
	var plan_value: Variant = data.get("reward_plan", {})
	var stage_reward_value: Variant = data.get("stage_reward_snapshot", {})
	return {
		"player_score": int(data.get("player_score", 0)),
		"boss_score": int(data.get("boss_score", 0)),
		"current_stage": int(data.get("current_stage", 1)),
		"selected_character_type": str(data.get("selected_character_type", current_selected_character_type)),
		"reward_plan": plan_value if plan_value is Dictionary else {},
		"stage_reward_snapshot": stage_reward_value if stage_reward_value is Dictionary else {},
	}


# Single source of truth: coerce each field once and emit it under the scene's
# real member name. Folds the prior dead get_config_data_apply_result two-tier
# (only its scene_apply sibling + smoke called it) into one map.
static func get_config_data_scene_apply_result(
	config_data_state: Dictionary,
	current_player_score: int,
	current_boss_score: int,
	current_stage: int,
	current_reward_plan: Dictionary,
	current_stage_reward_snapshot: Dictionary
) -> Dictionary:
	var reward_plan_value: Variant = config_data_state.get("reward_plan", current_reward_plan)
	var stage_reward_value: Variant = config_data_state.get("stage_reward_snapshot", current_stage_reward_snapshot)
	return {
		"field_payload": {
			"player_score": int(config_data_state.get("player_score", current_player_score)),
			"boss_score": int(config_data_state.get("boss_score", current_boss_score)),
			"current_stage": int(config_data_state.get("current_stage", current_stage)),
			"reward_plan": reward_plan_value if reward_plan_value is Dictionary else current_reward_plan,
			"stage_reward_snapshot": stage_reward_value if stage_reward_value is Dictionary else current_stage_reward_snapshot,
		},
	}
