extends RefCounted

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")


static func has_egg_access(owner: Object, registry: Object) -> bool:
	if owner == null:
		return false
	if LingpetCollectionState.new().is_auto_present_league(owner):
		return true
	var tower_flow: Object = _get_cached_instance(registry, "tower_ascent_flow_owner")
	if (
		tower_flow != null
		and tower_flow.has_method("has_soul_summoning")
		and bool(tower_flow.call("has_soul_summoning"))
	):
		return true
	var runtime_perk_state: Object = _get_cached_instance(registry, "runtime_perk_state")
	if runtime_perk_state == null:
		return false
	if runtime_perk_state.has_method("get_runtime_skill_level"):
		return (
			int(runtime_perk_state.get_runtime_skill_level(CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID)) > 0
			or int(runtime_perk_state.get_runtime_skill_level(CommonSkillCatalog.SOUL_SUMMON_ART_ID)) > 0
		)
	var levels_value: Variant = runtime_perk_state.get("runtime_skill_levels")
	if levels_value is Dictionary:
		var levels: Dictionary = levels_value as Dictionary
		return (
			int(levels.get(CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID, 0)) > 0
			or int(levels.get(CommonSkillCatalog.SOUL_SUMMON_ART_ID, 0)) > 0
		)
	return false


static func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	return registry.get_cached_instance(key)
