extends RefCounted

const CLASS_NUMERIC_PASSIVE := "numeric_passive"
const CLASS_BOOLEAN_UNIQUE := "boolean_unique"
const CLASS_MYTHIC_SYSTEM := "mythic_system"
const CLASS_UNLOCK := "unlock"
const CLASS_INSTANT := "instant"
const CLASS_SYSTEM_CHOICE := "system_choice"

const FUSION_CLASSES := [
	CLASS_NUMERIC_PASSIVE,
	CLASS_BOOLEAN_UNIQUE,
	CLASS_MYTHIC_SYSTEM,
	CLASS_UNLOCK,
	CLASS_INSTANT,
	CLASS_SYSTEM_CHOICE,
]

const CANDIDATE_CLASSES := {
	CLASS_NUMERIC_PASSIVE: true,
	CLASS_BOOLEAN_UNIQUE: true,
	CLASS_MYTHIC_SYSTEM: true,
}

const SYSTEM_CHOICE_IDS := {
	"common_expansion": true,
	"dash_amplification": true,
}

const CHARACTER_NUMERIC_TREES := {
	"smasher": true,
	"viper": true,
	"soldier": true,
	"commando": true,
	"optimus": true,
	"blacksmith": true,
}

# Explicit S4 eligibility registry. Every id here has a production consumer that
# keeps scaling above its authored max level; boolean/system/exempt perks are
# intentionally absent even if their raw table happens to contain a number.
const LIMIT_BREAK_ELIGIBLE_IDS := {
	"dash_lightweight": true,
	"dash_module_control": true,
	"dash_jump": true,
	"dash_acceleration": true,
	"dash_spirit": true,
	"item_luck": true,
	"item_cooldown_mastery": true,
	"item_gauge_mastery": true,
	"item_bag_expansion": true,
	"item_caffeine": true,
	"item_polish": true,
	"item_recycle": true,
	"common_swiftness": true,
	"common_bulk_up": true,
	"common_training": true,
	"perk_boost_charge": true,
	"perk_laurel_shield": true,
	"star_detector": true,
	"adversity_armor": true,
	"reinforced_boomerang_gauntlet": true,
	"sensor": true,
	"dowsing_pendulum": true,
	"dowsing_goggles": true,
	"chargebag": true,
	"battery": true,
	"master": true,
	"gold_digger": true,
	"lucky_coin": true,
	"shrapnel_armor": true,
	"fuel_pouch": true,
	"bluetooth_ring": true,
	"foul_whistle": true,
	"neural_helmet": true,
	"commando_arm": true,
	"rainbow_fur_glove": true,
	"knee_pads": true,
	"soul_burst": true,
	"bulletproof_hat": true,
	"spiked_helmet": true,
	"venom_mist_gauntlet": true,
}


func classify_perk(perk_id: String, runtime_catalog: Object, base_level: int = -1) -> Dictionary:
	var perk_data: Dictionary = _get_perk_data(runtime_catalog, perk_id)
	return classify_data(perk_id, perk_data, runtime_catalog, base_level)


func get_perk_classification(perk_id: String, runtime_catalog: Object, base_level: int = -1) -> Dictionary:
	return classify_perk(perk_id, runtime_catalog, base_level)


func classify_data(
	perk_id: String,
	perk_data: Dictionary,
	runtime_catalog: Object = null,
	base_level: int = -1
) -> Dictionary:
	var normalized_id: String = perk_id.strip_edges()
	if normalized_id.is_empty() or perk_data.is_empty():
		return {}

	var normalized_data: Dictionary = perk_data.duplicate(true)
	normalized_data["id"] = normalized_id
	var max_level: int = int(normalized_data.get("max_level", 0))
	var slot_probe_level: int = base_level if base_level >= 0 else max_level
	var slot_cost: int = _get_slot_cost(runtime_catalog, normalized_data, slot_probe_level)
	var fusion_class: String = _resolve_fusion_class(
		normalized_id,
		normalized_data,
		runtime_catalog,
		slot_cost
	)
	var penalty_hookable: bool = _resolve_penalty_hookable(normalized_data, fusion_class)
	var fusion_excluded := bool(normalized_data.get("exclude_from_perk_fusion", false))

	return {
		"perk_id": normalized_id,
		"fusion_class": fusion_class,
		"classification": fusion_class,
		"penalty_hookable": penalty_hookable,
		"max_level": max_level,
		"slot_cost": slot_cost,
		"is_candidate_class": bool(CANDIDATE_CLASSES.get(fusion_class, false)) and not fusion_excluded,
		"fusion_excluded": fusion_excluded,
		"limit_break_eligible": bool(perk_data.get(
			"limit_break_eligible",
			LIMIT_BREAK_ELIGIBLE_IDS.get(normalized_id, false)
		)),
	}


func get_fusion_class(perk_id: String, runtime_catalog: Object, base_level: int = -1) -> String:
	return str(classify_perk(perk_id, runtime_catalog, base_level).get("fusion_class", ""))


func is_candidate(
	perk_id: String,
	base_level: int,
	runtime_catalog: Object,
	fused_sources: Variant = {}
) -> bool:
	if base_level <= 0 or _is_source_fused(perk_id, fused_sources):
		return false
	var classification: Dictionary = classify_perk(perk_id, runtime_catalog, base_level)
	if classification.is_empty():
		return false
	if not bool(classification.get("is_candidate_class", false)):
		return false
	if base_level != int(classification.get("max_level", 0)):
		return false
	return int(classification.get("slot_cost", 0)) == 1


func is_fusion_candidate(
	perk_id: String,
	base_level: int,
	runtime_catalog: Object,
	fused_sources: Variant = {}
) -> bool:
	return is_candidate(perk_id, base_level, runtime_catalog, fused_sources)


func get_candidate_ids(
	runtime_levels: Dictionary,
	runtime_catalog: Object,
	fused_sources: Variant = {}
) -> Array[String]:
	var candidates: Array[String] = []
	for perk_id_value: Variant in runtime_levels.keys():
		var perk_id: String = str(perk_id_value).strip_edges()
		var base_level: int = int(runtime_levels.get(perk_id_value, 0))
		if is_candidate(perk_id, base_level, runtime_catalog, fused_sources):
			candidates.append(perk_id)
	candidates.sort()
	return candidates


func _resolve_fusion_class(
	perk_id: String,
	perk_data: Dictionary,
	runtime_catalog: Object,
	slot_cost: int
) -> String:
	var explicit_class: String = str(perk_data.get("fusion_class", "")).strip_edges()
	var tree: String = str(perk_data.get("tree", "")).strip_edges()

	# Keep this priority synchronized with the design contract. In particular,
	# unlock and instant entries must never fall through to max-level rules.
	if explicit_class == CLASS_UNLOCK or str(perk_data.get("unlocks_skill", "")).strip_edges() != "":
		return CLASS_UNLOCK
	if (
		explicit_class == CLASS_INSTANT
		or bool(perk_data.get("is_instant", false))
		or tree == "instant"
	):
		return CLASS_INSTANT
	if (
		explicit_class == CLASS_SYSTEM_CHOICE
		or bool(SYSTEM_CHOICE_IDS.get(perk_id, false))
		or tree == "lingpet"
		or _has_non_unit_slot_cost(runtime_catalog, slot_cost)
	):
		return CLASS_SYSTEM_CHOICE
	if (
		explicit_class == CLASS_MYTHIC_SYSTEM
		or bool(perk_data.get("effective_level_exempt", false))
		or bool(perk_data.get("is_mythic", false))
		or str(perk_data.get("rarity", "")) == "mythic"
	):
		return CLASS_MYTHIC_SYSTEM
	if explicit_class == CLASS_BOOLEAN_UNIQUE or int(perk_data.get("max_level", 0)) == 1:
		return CLASS_BOOLEAN_UNIQUE
	return CLASS_NUMERIC_PASSIVE


func _resolve_penalty_hookable(perk_data: Dictionary, fusion_class: String) -> bool:
	if perk_data.has("penalty_hookable"):
		return fusion_class == CLASS_NUMERIC_PASSIVE and bool(perk_data.get("penalty_hookable", false))
	if fusion_class != CLASS_NUMERIC_PASSIVE:
		return false
	if str(perk_data.get("character_restriction", "")).strip_edges() != "":
		return false
	var tree: String = str(perk_data.get("tree", "")).strip_edges()
	return not bool(CHARACTER_NUMERIC_TREES.get(tree, false))


func _get_perk_data(runtime_catalog: Object, perk_id: String) -> Dictionary:
	if runtime_catalog == null or not runtime_catalog.has_method("get_perk_data"):
		return {}
	var value: Variant = runtime_catalog.call("get_perk_data", perk_id)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _get_slot_cost(runtime_catalog: Object, perk_data: Dictionary, level: int) -> int:
	if runtime_catalog == null or not runtime_catalog.has_method("get_slot_cost_for_level"):
		return -1
	return int(runtime_catalog.call("get_slot_cost_for_level", perk_data, level))


func _has_non_unit_slot_cost(runtime_catalog: Object, slot_cost: int) -> bool:
	return runtime_catalog != null and slot_cost != 1


func _is_source_fused(perk_id: String, fused_sources: Variant) -> bool:
	if fused_sources is Dictionary:
		return (fused_sources as Dictionary).has(perk_id)
	if fused_sources is Array:
		return perk_id in (fused_sources as Array)
	if fused_sources is Object:
		var state: Object = fused_sources as Object
		if state != null and state.has_method("is_source_fused"):
			return bool(state.call("is_source_fused", perk_id))
	return false
