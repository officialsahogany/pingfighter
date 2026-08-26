extends RefCounted

const CommonSkillCatalog := preload(
	"res://scripts/characters/common_skill_catalog.gd"
)
const StageBossVariantCatalog := preload(
	"res://scripts/stages/common/stage_boss_variant_catalog.gd"
)
# The selected map boss slot is the sole authority for boss-specific rewards.
# Stage and stand-in boss IDs are presentation/routing compatibility fields and
# must not make a different boss's Vision appear.
const VISION_UNLOCK_BY_BOSS_SLOT := {
	"floor_01_dalji": CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID,
	"floor_01_gaksital": CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_UNLOCK_ID,
	"floor_02_cheongringwi": CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_UNLOCK_ID,
	"floor_03_yeonmyo": CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_UNLOCK_ID,
}
const BOSS_SLOT_BY_STAGE_VARIANT := {
	"1:dalji": "floor_01_dalji",
	"1:gaksi": "floor_01_gaksital",
	"1:podo": "floor_01_podo",
	"2:cheongringwi": "floor_02_cheongringwi",
	"2:molewang": "floor_02_molewang",
	"2:arachne": "floor_02_arachne",
	"3:yeonmyo": "floor_03_yeonmyo",
	"3:teddy_bear": "floor_03_teddy_bear",
	"3:alice": "floor_03_alice",
}
const CANONICAL_ENCOUNTER_KEY_BY_BOSS_SLOT := {
	"floor_01_dalji": "1:dalji",
	"floor_01_gaksital": "1:gaksi",
	"floor_01_podo": "1:podo",
	"floor_02_cheongringwi": "2:cheongringwi",
	"floor_02_molewang": "2:molewang",
	"floor_02_arachne": "2:arachne",
	"floor_03_yeonmyo": "3:yeonmyo",
	"floor_03_teddy_bear": "3:teddy_bear",
	"floor_03_alice": "3:alice",
}


static func get_vision_unlock_id(boss_slot_id: String) -> String:
	return str(VISION_UNLOCK_BY_BOSS_SLOT.get(boss_slot_id.strip_edges(), ""))


static func get_boss_slot_id_for_stage_variant(stage_id: int, variant: Variant) -> String:
	if not StageBossVariantCatalog.is_ported_variant(stage_id, variant):
		return ""
	var normalized_variant := StageBossVariantCatalog.normalize_variant(stage_id, variant)
	return str(BOSS_SLOT_BY_STAGE_VARIANT.get("%d:%s" % [stage_id, normalized_variant], ""))


static func get_canonical_encounter_key(boss_slot_id: String) -> String:
	return str(CANONICAL_ENCOUNTER_KEY_BY_BOSS_SLOT.get(boss_slot_id.strip_edges(), ""))


static func get_vision_unlock_id_for_stage_variant(stage_id: int, variant: Variant) -> String:
	return get_vision_unlock_id(get_boss_slot_id_for_stage_variant(stage_id, variant))


static func get_legacy_vision_unlock_id_for_stage_variant(stage_id: int, variant: Variant) -> String:
	if stage_id == 2:
		return CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_UNLOCK_ID
	if stage_id == 3:
		return CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_UNLOCK_ID
	return get_vision_unlock_id_for_stage_variant(stage_id, variant) if stage_id == 1 else ""


static func get_default_stage_variant(stage_id: int) -> String:
	return StageBossVariantCatalog.get_default_variant(stage_id)


static func get_vision_skill_id(boss_slot_id: String) -> String:
	var unlock_id := get_vision_unlock_id(boss_slot_id)
	return CommonSkillCatalog.get_skill_id_for_unlock(unlock_id) if not unlock_id.is_empty() else ""


static func build_vision_choice(boss_slot_id: String) -> Dictionary:
	var unlock_id := get_vision_unlock_id(boss_slot_id)
	if unlock_id.is_empty():
		return {}
	var choice := CommonSkillCatalog.get_unlock_perk_data(unlock_id)
	if choice.is_empty():
		return {}
	choice["id"] = unlock_id
	choice["boss_slot_id"] = boss_slot_id.strip_edges()
	choice["reward_pick_kind"] = "vision"
	choice["current_level"] = 0
	choice["next_level"] = 1
	return choice


static func is_owned(runtime_levels: Dictionary, boss_slot_id: String) -> bool:
	var unlock_id := get_vision_unlock_id(boss_slot_id)
	var skill_id := get_vision_skill_id(boss_slot_id)
	return (
		not unlock_id.is_empty()
		and (
			int(runtime_levels.get(unlock_id, 0)) > 0
			or (not skill_id.is_empty() and int(runtime_levels.get(skill_id, 0)) > 0)
		)
	)
