extends RefCounted


func build_config(
	player_score: int,
	boss_score: int,
	current_stage: int,
	selected_character_type: String,
	reward_plan: Dictionary,
	stage_reward_snapshot: Dictionary,
	owner: Object,
	registry: Object
) -> Dictionary:
	return {
		"player_score": player_score,
		"boss_score": boss_score,
		"current_stage": current_stage,
		"selected_character_type": selected_character_type,
		"reward_plan": reward_plan.duplicate(true),
		"stage_reward_snapshot": stage_reward_snapshot.duplicate(true),
		"runtime_perk_state": _get_instance(registry, "runtime_perk_state"),
		"runtime_perk_catalog": _get_instance(registry, "runtime_perk_catalog"),
		"runtime_perk_icon_renderer": _get_instance(registry, "runtime_perk_icon_renderer"),
		"runtime_perk_owner": owner,
		"runtime_perk_registry": registry,
		"mythic_item_runtime": _get_instance(registry, "mythic_item_runtime"),
		"treasure_hunt_runtime": _get_instance(registry, "treasure_hunt_runtime"),
		"game_audio": _get_instance(registry, "game_audio"),
	}


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var instance: Variant = registry.get_instance(key)
	return instance if instance is Object else null
