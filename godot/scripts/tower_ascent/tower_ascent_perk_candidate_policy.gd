extends RefCounted

const RuntimePerkCharacterContext := preload(
	"res://scripts/characters/runtime_perk_character_context.gd"
)
const PerkConversionFlags := preload(
	"res://scripts/characters/perk_conversion_flags.gd"
)
const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)

const EXCLUDED_MUGONG_FLAGS := [
	"is_instant",
	"is_gold_conversion",
	"is_physique_training",
	"is_mystic_dice",
	"is_perk_fusion",
	"is_lingpet_guardian_enhance",
]
const RETIRED_FLAG_ON_MUGONG_IDS := {
	"common_expansion": true,
}

var _character_context: Object = RuntimePerkCharacterContext.new()


func is_mugong_candidate(
	data: Dictionary,
	runtime_levels: Dictionary,
	character_type: String,
	registry: Object,
	enforce_perk_slot_budget: bool = false
) -> bool:
	var perk_id := str(data.get("id", data.get("perk_id", ""))).strip_edges()
	if perk_id.is_empty() or str(data.get("rarity", "")).to_lower() == "mythic":
		return false
	if (
		PerkConversionFlags.is_enabled()
		and (
			RETIRED_FLAG_ON_MUGONG_IDS.has(perk_id)
			or RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS.has(perk_id)
		)
	):
		return false
	if not TowerAscentUnlockFilter.is_content_unlocked(
		registry,
		TowerAscentUnlockFilter.CONTENT_RUNTIME_PERK,
		perk_id
	):
		return false
	var restriction := str(data.get("character_restriction", "")).strip_edges()
	if (
		not restriction.is_empty()
		and _character_context.normalize_character_type(restriction) != character_type
	):
		return false
	for excluded_flag in EXCLUDED_MUGONG_FLAGS:
		if bool(data.get(excluded_flag, false)):
			return false
	var current_level := int(runtime_levels.get(perk_id, 0))
	var max_level := maxi(1, int(data.get("max_level", 0)))
	if current_level >= max_level:
		return false
	if not enforce_perk_slot_budget:
		return true
	var catalog: Object = null
	if registry != null and registry.has_method("get_instance"):
		catalog = registry.call("get_instance", "runtime_perk_catalog")
	if catalog == null or not catalog.has_method("get_perk_slot_apply_status"):
		return false
	var status_value: Variant = catalog.call(
		"get_perk_slot_apply_status",
		data,
		runtime_levels,
		registry,
		current_level + 1
	)
	return status_value is Dictionary and bool((status_value as Dictionary).get("accepted", false))


func is_chosik_candidate(
	data: Dictionary,
	runtime_levels: Dictionary,
	character_type: String,
	registry: Object,
	skill_config: Object
) -> bool:
	var perk_id := str(data.get("id", data.get("perk_id", ""))).strip_edges()
	var unlocked_skill := str(data.get("unlocks_skill", "")).strip_edges()
	var restriction := str(data.get("character_restriction", "")).strip_edges()
	if (
		perk_id.is_empty()
		or unlocked_skill.is_empty()
		or restriction.is_empty()
		or str(data.get("rarity", "")).to_lower() == "mythic"
	):
		return false
	if _character_context.normalize_character_type(restriction) != character_type:
		return false
	if int(runtime_levels.get(perk_id, 0)) > 0:
		return false
	if not TowerAscentUnlockFilter.is_content_unlocked(
		registry,
		TowerAscentUnlockFilter.CONTENT_RUNTIME_PERK,
		perk_id
	):
		return false
	if skill_config == null or not skill_config.has_method("get_skill_data"):
		return false
	var skill_data: Variant = skill_config.call("get_skill_data", unlocked_skill)
	return skill_data is Dictionary and not (skill_data as Dictionary).is_empty()
