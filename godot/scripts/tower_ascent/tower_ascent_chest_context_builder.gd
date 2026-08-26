extends RefCounted

const CommonSkillCatalog := preload(
	"res://scripts/characters/common_skill_catalog.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentBossRewardCatalog := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_reward_catalog.gd"
)

# These are compatibility IDs, not new player-facing names. Keep the chest
# contract loadable before the separate boss-Vision content track lands.
const DALJI_VISION_UNLOCK_ID := "unlock_dalji_vision_chain_top"
const GAKSITAL_VISION_UNLOCK_ID := "unlock_gaksital_vision_fan_throw"
const CHEONGRINGWI_VISION_UNLOCK_ID := "unlock_cheongringwi_vision_dragon_torrent"
const YEONMYO_VISION_UNLOCK_ID := "unlock_yeonmyo_vision_bonghongwe"
const _VISION_SKILL_ID_BY_UNLOCK_ID := {
	DALJI_VISION_UNLOCK_ID: "dalji_vision_chain_top",
	GAKSITAL_VISION_UNLOCK_ID: "gaksital_vision_fan_throw",
	CHEONGRINGWI_VISION_UNLOCK_ID: "cheongringwi_vision_dragon_torrent",
	YEONMYO_VISION_UNLOCK_ID: "yeonmyo_vision_bonghongwe",
}


func build(owner: Object, registry: Object, current_stage: int) -> Dictionary:
	var vision_offer_id := _get_boss_vision_offer_id(owner, current_stage)
	var vision_catalog_available := _is_boss_vision_catalog_available(vision_offer_id)
	var map_risk_context := _get_map_risk_context(registry)
	return {
		"floor": maxi(1, int(map_risk_context.get("floor", _get_owner_value(owner, "tower_floor", current_stage)))),
		"is_elite": bool(map_risk_context.get("is_elite", _get_owner_value(owner, "tower_node_is_elite", false))),
		"is_enraged": bool(map_risk_context.get("is_enraged", _get_owner_value(owner, "tower_node_is_enraged", false))),
		"is_gatekeeper": bool(map_risk_context.get("is_gatekeeper", _get_owner_value(owner, "tower_node_is_gatekeeper", false))),
		"secret_chosik_id": vision_offer_id,
		"secret_chosik_catalog_available": vision_catalog_available,
		"secret_chosik_eligible": vision_catalog_available and not _is_boss_vision_owned(registry, vision_offer_id),
		"supreme_art_available": bool(_get_owner_value(owner, "tower_supreme_art_available", true)),
	}


func build_secret_chosik_reward(vision_offer_id: String) -> Dictionary:
	var normalized_id := vision_offer_id.strip_edges()
	if not _is_boss_vision_catalog_available(normalized_id):
		return {}
	var catalog_class: Object = CommonSkillCatalog
	var manual_data_value: Variant = catalog_class.call(
		"get_unlock_perk_data",
		normalized_id
	)
	var manual_data: Dictionary = (
		(manual_data_value as Dictionary)
		if manual_data_value is Dictionary
		else {}
	)
	if manual_data.is_empty():
		return {}
	return {
		"type": "starpoint",
		"amount": 1,
		"label": str(manual_data.get("name", "보스 비전 초식 비급")),
		"reserved_perk_offer_id": normalized_id,
		"source": "boss_vision_box",
	}


func _get_boss_vision_offer_id(owner: Object, current_stage: int) -> String:
	var variant_property := "stage1_boss_variant" if current_stage == 1 else "stage_boss_variant"
	return TowerAscentBossRewardCatalog.get_legacy_vision_unlock_id_for_stage_variant(
		current_stage,
		_get_owner_value(
			owner,
			variant_property,
			TowerAscentBossRewardCatalog.get_default_stage_variant(current_stage)
		)
	)


func _is_boss_vision_catalog_available(vision_unlock_id: String) -> bool:
	if vision_unlock_id.is_empty():
		return false
	var catalog_class: Object = CommonSkillCatalog
	if not catalog_class.has_method("get_skill_id_for_unlock"):
		return false
	return not str(
		catalog_class.call("get_skill_id_for_unlock", vision_unlock_id)
	).is_empty()


func _is_boss_vision_owned(registry: Object, vision_unlock_id: String) -> bool:
	var runtime_perk_state := _get_registry_instance(registry, "runtime_perk_state")
	if runtime_perk_state == null:
		return false
	var levels_value: Variant = _get_object_value(
		runtime_perk_state,
		"runtime_skill_levels",
		{}
	)
	if not (levels_value is Dictionary):
		return false
	var levels := levels_value as Dictionary
	var vision_skill_id := str(_VISION_SKILL_ID_BY_UNLOCK_ID.get(vision_unlock_id, ""))
	return (
		int(levels.get(vision_unlock_id, 0)) > 0
		or (not vision_skill_id.is_empty() and int(levels.get(vision_skill_id, 0)) > 0)
	)


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	for method_name in ["get_instance", "get_cached_instance"]:
		if not registry.has_method(method_name):
			continue
		var value: Variant = registry.call(method_name, key)
		if value is Object and value != null:
			return value as Object
	return null


func _get_map_risk_context(registry: Object) -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return {}
	var flow_owner := _get_registry_instance(registry, "tower_ascent_flow_owner")
	if flow_owner == null or not flow_owner.has_method("get_current_node_risk_context"):
		return {}
	var context_variant: Variant = flow_owner.call("get_current_node_risk_context")
	return (context_variant as Dictionary).duplicate(true) if context_variant is Dictionary else {}


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return _get_object_value(owner, key, fallback)


func _get_object_value(target: Object, key: String, fallback: Variant) -> Variant:
	if target == null:
		return fallback
	var value: Variant = target.get(key)
	return fallback if value == null else value
