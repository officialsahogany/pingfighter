extends RefCounted

const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")


static func get_standalone_preview_defaults(
	player_score: int,
	boss_score: int,
	reward_plan: Dictionary,
	reward_count: int
) -> Dictionary:
	if player_score != 0 or boss_score != 0 or not reward_plan.is_empty():
		return {"apply": false}
	var defaults: Dictionary = StageClearResultBoxData.build_standalone_preview_defaults(reward_count)
	defaults["apply"] = true
	return defaults


# Single source of truth: decide apply-vs-skip once and emit the scene field
# payload directly. Folds the prior dead get_standalone_preview_apply_result
# two-tier (only its scene_apply sibling + smoke called it) into one function.
# The scene ignores the top-level "apply" flag (it just applies field_payload);
# it stays in the return for callers/tests that branch on apply-vs-skip.
static func get_standalone_preview_scene_apply_result(
	defaults: Dictionary,
	current_player_score: int,
	current_boss_score: int,
	current_stage: int,
	current_reward_plan: Dictionary
) -> Dictionary:
	if not bool(defaults.get("apply", false)):
		return {
			"apply": false,
			"field_payload": {
				"player_score": current_player_score,
				"boss_score": current_boss_score,
				"current_stage": current_stage,
				"reward_plan": current_reward_plan,
			},
		}
	var reward_plan_value: Variant = defaults.get("reward_plan", current_reward_plan)
	return {
		"apply": true,
		"field_payload": {
			"player_score": int(defaults.get("player_score", current_player_score)),
			"boss_score": int(defaults.get("boss_score", current_boss_score)),
			"current_stage": int(defaults.get("current_stage", current_stage)),
			"reward_plan": reward_plan_value if reward_plan_value is Dictionary else current_reward_plan,
		},
	}
