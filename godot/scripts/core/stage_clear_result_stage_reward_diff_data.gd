extends RefCounted

const StageClearResultStageItemRewardData := preload("res://scripts/core/stage_clear_result_stage_item_reward_data.gd")
const StageClearResultStagePerkRewardData := preload("res://scripts/core/stage_clear_result_stage_perk_reward_data.gd")


static func build_stage_reward_snapshot(
	stage_id: int,
	stage_start_snapshot: Dictionary,
	active_item_slots: Array,
	passive_item_inventory: Array,
	current_perk_levels: Dictionary,
	active_item_catalog: Object,
	mythic_item_catalog: Object,
	perk_catalog: Object
) -> Dictionary:
	var baseline: Dictionary = _get_dictionary(stage_start_snapshot)
	if int(baseline.get("stage", 0)) != stage_id:
		baseline = {
			"stage": stage_id,
			"active_item_slots": [],
			"passive_item_inventory": [],
			"runtime_perk_levels": {},
		}
	return {
		"stage": stage_id,
		"active_items": StageClearResultStageItemRewardData.build_active_item_rewards(
			active_item_slots,
			active_item_catalog,
			mythic_item_catalog
		),
		"passive_items": StageClearResultStageItemRewardData.build_new_passive_item_rewards(
			passive_item_inventory,
			_get_array(baseline.get("passive_item_inventory", [])),
			active_item_catalog,
			mythic_item_catalog
		),
		"perks": StageClearResultStagePerkRewardData.build_perk_rewards(
			current_perk_levels,
			_get_dictionary(baseline.get("runtime_perk_levels", {})),
			perk_catalog
		),
	}


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


static func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
