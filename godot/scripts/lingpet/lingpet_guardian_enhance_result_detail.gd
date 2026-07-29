extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")
const LingpetDurationState := preload("res://scripts/lingpet/lingpet_duration_state.gd")
const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)


static func build(
	candidate: Dictionary,
	pet_id: String,
	before_pet_data: Dictionary,
	after_pet_data: Dictionary,
	before_loadout: Dictionary,
	after_loadout: Dictionary
) -> Dictionary:
	var reward_type := str(candidate.get("type", ""))
	if reward_type in [
		LingpetEnhancementBuffStore.REWARD_TYPE_ACTIVE_SKILL,
		LingpetEnhancementBuffStore.REWARD_TYPE_PASSIVE_SKILL,
		LingpetEnhancementBuffStore.REWARD_TYPE_ACTIVE_UNLOCK,
		LingpetEnhancementBuffStore.REWARD_TYPE_PASSIVE_UNLOCK,
		LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_ACTIVE_UNLOCK,
		LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_PASSIVE_UNLOCK,
	]:
		return _build_skill_detail(
			candidate,
			pet_id,
			before_pet_data,
			after_pet_data,
			before_loadout,
			after_loadout
		)
	return _build_stat_detail(candidate)


static func build_fallback() -> Dictionary:
	return {
		"kind": "stat",
		"reward_type": "duration_fallback",
		"stat_amount": LingpetDurationState.REVALIDATION_FALLBACK_SECONDS,
		"stat_unit": "seconds",
	}


static func _build_skill_detail(
	candidate: Dictionary,
	pet_id: String,
	before_pet_data: Dictionary,
	after_pet_data: Dictionary,
	_before_loadout: Dictionary,
	after_loadout: Dictionary
) -> Dictionary:
	var reward_type := str(candidate.get("type", ""))
	var active := reward_type in [
		LingpetEnhancementBuffStore.REWARD_TYPE_ACTIVE_SKILL,
		LingpetEnhancementBuffStore.REWARD_TYPE_ACTIVE_UNLOCK,
		LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_ACTIVE_UNLOCK,
	]
	var unlock := reward_type in [
		LingpetEnhancementBuffStore.REWARD_TYPE_ACTIVE_UNLOCK,
		LingpetEnhancementBuffStore.REWARD_TYPE_PASSIVE_UNLOCK,
		LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_ACTIVE_UNLOCK,
		LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_PASSIVE_UNLOCK,
	]
	var slot := int(candidate.get("skill_slot", 0))
	if slot <= 0:
		slot = 2 if reward_type in [
			LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_ACTIVE_UNLOCK,
			LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_PASSIVE_UNLOCK,
		] else 1
	var skill_id := _skill_id_from_loadout(after_loadout, active, slot)
	if skill_id == "":
		skill_id = _skill_id_from_resolved(after_pet_data, active, slot)
	var skill_entry := (
		LingpetCatalog.get_active_skill_entry(skill_id)
		if active
		else LingpetCatalog.get_passive_skill_entry(skill_id)
	)
	var before_counts := LingpetEnhancementBuffStore.reward_counts_snapshot(before_pet_data)
	var after_counts := LingpetEnhancementBuffStore.reward_counts_snapshot(after_pet_data)
	var base_level := _base_level_from_loadout(after_loadout, skill_id, active, slot)
	if base_level <= 0:
		base_level = int(after_pet_data.get(
			"active_skill_base_level" if active else "passive_skill_base_level",
			1
		))
	var previous_level := 0 if unlock else LingpetCatalog.clamp_skill_level(
		base_level + int(before_counts.get(_bonus_key(active, slot), 0))
	)
	var new_level := LingpetCatalog.clamp_skill_level(
		base_level + int(after_counts.get(_bonus_key(active, slot), 0))
	)
	return {
		"kind": "skill_unlock" if unlock else "skill_level",
		"reward_type": reward_type,
		"skill_slot": slot,
		"skill_id": skill_id,
		"skill_display_name": str(skill_entry.get("name", skill_id)),
		"previous_level": previous_level,
		"new_level": new_level,
		"icon_texture_path": str(skill_entry.get("icon_texture_path", "")),
		"pet_id": pet_id,
	}


static func _build_stat_detail(candidate: Dictionary) -> Dictionary:
	var reward_type := str(candidate.get("type", ""))
	var amount := 0.0
	var unit := ""
	match reward_type:
		LingpetEnhancementBuffStore.REWARD_TYPE_MOBILITY:
			if str(candidate.get("remapped_stat", "")) == "appearance_rate":
				amount = LingpetCurrentProfile.ENHANCEMENT_FLIGHT_APPEARANCE_BONUS * 100.0
			else:
				amount = LingpetCurrentProfile.ENHANCEMENT_MOBILITY_SPEED_BONUS_PCT
			unit = "percent"
		LingpetEnhancementBuffStore.REWARD_TYPE_DEFENSE:
			amount = LingpetCurrentProfile.ENHANCEMENT_PATROL_DEFENSE_BONUS * 100.0
			unit = "percent"
		LingpetEnhancementBuffStore.REWARD_TYPE_GAUGE:
			amount = LingpetCurrentProfile.ENHANCEMENT_HIT_GAUGE_CARD_BONUS
			unit = "points"
		LingpetEnhancementBuffStore.REWARD_TYPE_DURATION:
			amount = LingpetDurationState.DURATION_INCREASE_SECONDS
			unit = "seconds"
	return {
		"kind": "stat",
		"reward_type": reward_type,
		"stat_amount": amount,
		"stat_unit": unit,
	}


static func _skill_id_from_loadout(loadout: Dictionary, active: bool, slot: int) -> String:
	var ids_key := "active_skill_ids" if active else "passive_skill_ids"
	var ids: Array = loadout.get(ids_key, []) as Array
	var index := maxi(0, slot - 1)
	if index < ids.size():
		return str(ids[index]).strip_edges()
	var key := (
		("second_active_skill_id" if active else "second_passive_skill_id")
		if slot == 2
		else ("active_skill_id" if active else "passive_skill_id")
	)
	return str(loadout.get(key, "")).strip_edges()


static func _skill_id_from_resolved(pet_data: Dictionary, active: bool, slot: int) -> String:
	var key := ("second_active" if active else "second_passive") if slot == 2 else ("active" if active else "passive")
	var resolved: Dictionary = pet_data.get("resolved_unlock_choices", {}) as Dictionary
	var choice: Dictionary = resolved.get(key, {}) as Dictionary
	return str(choice.get("selected", "")).strip_edges()


static func _base_level_from_loadout(
	loadout: Dictionary,
	skill_id: String,
	active: bool,
	slot: int
) -> int:
	if skill_id == "":
		return 0
	var levels_key := "active_skill_levels" if active else "passive_skill_levels"
	var levels: Dictionary = loadout.get(levels_key, {}) as Dictionary
	var fallback_key := (
		("second_active_skill_level" if active else "second_passive_skill_level")
		if slot == 2
		else ("active_skill_level" if active else "passive_skill_level")
	)
	return int(levels.get(skill_id, loadout.get(fallback_key, 1)))


static func _bonus_key(active: bool, slot: int) -> String:
	if active:
		return "second_active_skill_bonus" if slot == 2 else "active_skill_bonus"
	return "second_passive_skill_bonus" if slot == 2 else "passive_skill_bonus"
