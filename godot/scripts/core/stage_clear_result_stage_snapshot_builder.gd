extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const StageClearResultStageRewardDiffData := preload("res://scripts/core/stage_clear_result_stage_reward_diff_data.gd")

var _active_item_catalog: Object = ActiveItemCatalog.new()
var _mythic_item_catalog: Object = MythicItemCatalog.new()
var _perk_catalog: Object = RuntimePerkCatalog.new()


func build_progress_snapshot(owner: Object, registry: Object, stage_id: int) -> Dictionary:
	return {
		"stage": max(1, stage_id),
		"active_item_slots": _get_active_item_slots(owner),
		"passive_item_inventory": _get_passive_item_inventory(owner, registry),
		"runtime_perk_levels": _get_runtime_perk_levels(owner, registry),
	}


func build_stage_reward_snapshot(
	owner: Object,
	registry: Object,
	stage_id: int,
	stage_start_snapshot: Dictionary
) -> Dictionary:
	return StageClearResultStageRewardDiffData.build_stage_reward_snapshot(
		stage_id,
		stage_start_snapshot,
		_get_active_item_slots(owner),
		_get_passive_item_inventory(owner, registry),
		_get_runtime_perk_levels(owner, registry),
		_active_item_catalog,
		_mythic_item_catalog,
		_perk_catalog
	)


func _get_active_item_slots(owner: Object) -> Array:
	if owner == null:
		return []
	var value: Variant = owner.get("active_item_slots")
	if value is Array:
		return (value as Array).duplicate(true)
	return []


func _get_passive_item_inventory(owner: Object, registry: Object) -> Array:
	var mythic_item_runtime: Object = _get_cached_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_snapshot"):
		var snapshot_value: Variant = mythic_item_runtime.get_snapshot()
		if snapshot_value is Dictionary:
			var inventory_value: Variant = (snapshot_value as Dictionary).get("inventory_items", [])
			if inventory_value is Array:
				return (inventory_value as Array).duplicate(true)
	if owner != null:
		var owner_value: Variant = owner.get("passive_item_inventory")
		if owner_value is Array:
			return (owner_value as Array).duplicate(true)
	return []


func _get_runtime_perk_levels(owner: Object, registry: Object) -> Dictionary:
	var runtime_perk_state: Object = _get_cached_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("get_snapshot"):
		var snapshot_value: Variant = runtime_perk_state.get_snapshot()
		if snapshot_value is Dictionary:
			var levels_value: Variant = (snapshot_value as Dictionary).get("runtime_skill_levels", {})
			if levels_value is Dictionary:
				return (levels_value as Dictionary).duplicate(true)
	if owner != null:
		var owner_value: Variant = owner.get("runtime_perk_levels")
		if owner_value is Dictionary:
			return (owner_value as Dictionary).duplicate(true)
	return {}


func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "":
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
		return null
	if registry.has_method("get_instance"):
		return registry.get_instance(key)
	return null
