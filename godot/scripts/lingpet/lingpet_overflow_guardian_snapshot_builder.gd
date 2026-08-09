extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")

var _current_profile: Object = LingpetCurrentProfile.new()
var _current_cache_key := ""
var _current_cache: Dictionary = {}
var _replacement_cache_key := ""
var _replacement_cache: Dictionary = {}


func enrich_choice_snapshot(
	snapshot: Dictionary,
	pending_pet_id: String,
	collection_state: Object,
	loadout_state: Object,
	guardian_run_state: Object,
	hatch_stat_roll_state: Object
) -> Dictionary:
	snapshot["current_guardian"] = build_current(
		collection_state,
		loadout_state,
		guardian_run_state,
		hatch_stat_roll_state
	)
	var replacement_guardian := build_replacement(pending_pet_id, loadout_state)
	if not replacement_guardian.is_empty():
		snapshot["replacement_guardian"] = replacement_guardian
		snapshot["replacement_skill_name"] = str(replacement_guardian.get("active_skill_name", ""))
		snapshot["replacement_skill_description"] = str(replacement_guardian.get("active_skill_description", ""))
		snapshot["replacement_skill_cooldown"] = float(replacement_guardian.get("active_skill_cooldown", 0.0))
		snapshot["replacement_skill_icon_path"] = str(replacement_guardian.get("active_skill_icon_path", ""))
	return snapshot


func build_replacement(pet_id: String, loadout_state: Object) -> Dictionary:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	if normalized_pet_id.is_empty() or not LingpetCatalog.has_pet(normalized_pet_id):
		return {}
	var loadout: Dictionary = loadout_state.get_stored_loadout(normalized_pet_id)
	if loadout.is_empty():
		loadout = loadout_state.get_loadout(normalized_pet_id)
	var cache_key := "%s:%d" % [normalized_pet_id, hash(loadout)]
	if cache_key == _replacement_cache_key and not _replacement_cache.is_empty():
		return _replacement_cache.duplicate(true)
	var active_level := int(loadout.get("active_skill_level", LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL))
	var passive_level := int(loadout.get("passive_skill_level", LingpetCatalog.DEFAULT_PASSIVE_SKILL_LEVEL))
	var active_entries: Array[Dictionary] = []
	for skill_id in collect_loadout_skill_ids(loadout, "active_skill_ids", "active_skill_id"):
		var slot_level := int((loadout.get("active_skill_levels", {}) as Dictionary).get(skill_id, active_level))
		var slot_skill := LingpetCatalog.get_active_skill(normalized_pet_id, skill_id, slot_level)
		if slot_skill.is_empty():
			continue
		active_entries.append(build_skill_entry(slot_skill, slot_level))
	var passive_entries: Array[Dictionary] = []
	for skill_id in collect_loadout_skill_ids(loadout, "passive_skill_ids", "passive_skill_id"):
		var slot_level := int((loadout.get("passive_skill_levels", {}) as Dictionary).get(skill_id, passive_level))
		var slot_passive := LingpetCatalog.get_passive_skill(normalized_pet_id, skill_id, slot_level)
		if slot_passive.is_empty():
			continue
		passive_entries.append(build_skill_entry(slot_passive, slot_level))
	# A level-0 hatch roll is a real empty slot. Never borrow pool[0] here: the
	# comparison card must preview exactly what a confirmed replacement keeps.
	var active_skill: Dictionary = active_entries[0] if not active_entries.is_empty() else {}
	var passive_skill: Dictionary = passive_entries[0] if not passive_entries.is_empty() else {}
	_replacement_cache_key = cache_key
	_replacement_cache = _build_snapshot(
		normalized_pet_id,
		LingpetCatalog.get_display_name(normalized_pet_id),
		_build_catalog_stats(normalized_pet_id),
		active_entries,
		passive_entries,
		active_skill,
		passive_skill,
		true
	)
	return _replacement_cache.duplicate(true)


func build_current(
	collection_state: Object,
	loadout_state: Object,
	guardian_run_state: Object,
	hatch_stat_roll_state: Object
) -> Dictionary:
	var slots_value: Variant = collection_state.get_battle_slots()
	if not (slots_value is Array) or (slots_value as Array).is_empty():
		return {}
	var pet_id := str((slots_value as Array)[0]).strip_edges().to_lower()
	if pet_id.is_empty() or not LingpetCatalog.has_pet(pet_id):
		return {}
	# get_loadout() already handles missing storage. A stored empty skill slot is
	# intentional and must not be replaced with a catalog default.
	var loadout: Dictionary = loadout_state.get_loadout(pet_id)
	var rewards: Dictionary = guardian_run_state.get_cumulative_rewards(pet_id)
	var hatch_roll: Dictionary = hatch_stat_roll_state.get_hatch_stat_roll(pet_id)
	var cache_key := "%s:%d:%s:%d" % [
		pet_id,
		hash(loadout),
		str(rewards.get("signature", "")),
		hash(hatch_roll),
	]
	if cache_key == _current_cache_key and not _current_cache.is_empty():
		return _current_cache.duplicate(true)
	_current_profile.set_pet_id(pet_id)
	_current_profile.set_loadout_from_data(loadout)
	_current_profile.set_enhancement_rewards(rewards)
	_current_profile.set_hatch_stat_roll(
		float(hatch_roll.get("mobility", 0.0)),
		float(hatch_roll.get("defense", 0.0))
	)
	var active_entries: Array[Dictionary] = []
	for slot in range(_current_profile.get_active_slot_count()):
		var slot_skill: Dictionary = _current_profile.get_active_skill(slot)
		if slot_skill.is_empty():
			continue
		active_entries.append(build_skill_entry(
			slot_skill,
			int(slot_skill.get("level", _current_profile.get_active_skill_level_for_slot(slot)))
		))
	var passive_entries: Array[Dictionary] = []
	for slot in range(_current_profile.get_passive_slot_count()):
		var slot_passive: Dictionary = _current_profile.get_passive_skill(slot)
		if slot_passive.is_empty():
			continue
		passive_entries.append(build_skill_entry(
			slot_passive,
			int(slot_passive.get("level", _current_profile.get_passive_skill_level_for_slot(slot)))
		))
	var active_skill: Dictionary = active_entries[0] if not active_entries.is_empty() else {}
	var passive_skill: Dictionary = passive_entries[0] if not passive_entries.is_empty() else {}
	_current_cache_key = cache_key
	_current_cache = _build_snapshot(
		pet_id,
		_current_profile.get_display_name(),
		_build_profile_stats(_current_profile),
		active_entries,
		passive_entries,
		active_skill,
		passive_skill,
		false
	)
	return _current_cache.duplicate(true)


func invalidate_replacement() -> void:
	_replacement_cache_key = ""
	_replacement_cache.clear()


static func build_skill_entry(skill: Dictionary, level: int) -> Dictionary:
	return {
		"name": str(skill.get("name", "")),
		"description": str(skill.get("description", "")),
		"cooldown": float(skill.get("cooldown", 0.0)),
		"icon_path": str(skill.get("icon_texture_path", "")),
		"level": maxi(0, level),
	}


static func collect_loadout_skill_ids(
	loadout: Dictionary,
	list_key: String,
	primary_key: String
) -> Array[String]:
	var ids: Array[String] = []
	var raw_ids: Variant = loadout.get(list_key, [])
	if raw_ids is Array:
		for raw_id in raw_ids as Array:
			var skill_id := str(raw_id).strip_edges()
			if not skill_id.is_empty() and not ids.has(skill_id):
				ids.append(skill_id)
	if ids.is_empty():
		var primary := str(loadout.get(primary_key, "")).strip_edges()
		if not primary.is_empty():
			ids.append(primary)
	return ids


static func _build_catalog_stats(pet_id: String) -> Dictionary:
	return {
		"patrol_speed_default": LingpetCatalog.get_stat(pet_id, "patrol_speed_default", 0.0),
		"patrol_speed_min": LingpetCatalog.get_stat(pet_id, "patrol_speed_min", 0.0),
		"patrol_speed_max": LingpetCatalog.get_stat(pet_id, "patrol_speed_max", 0.0),
		"catch_width": LingpetCatalog.get_stat(pet_id, "catch_width", 0.0),
		"catch_height": LingpetCatalog.get_stat(pet_id, "catch_height", 0.0),
		"defense_rate": LingpetCatalog.get_stat(pet_id, "defense_rate", 0.0),
		"appearance_rate": LingpetCatalog.get_stat(pet_id, "appearance_rate", 0.0),
		"hit_gauge_gain": LingpetCatalog.get_stat(pet_id, "hit_gauge_gain", 0.0),
	}


static func _build_profile_stats(profile: Object) -> Dictionary:
	return {
		"patrol_speed_default": profile.get_stat("patrol_speed_default", 0.0),
		"patrol_speed_min": profile.get_stat("patrol_speed_min", 0.0),
		"patrol_speed_max": profile.get_stat("patrol_speed_max", 0.0),
		"catch_width": profile.get_stat("catch_width", 0.0),
		"catch_height": profile.get_stat("catch_height", 0.0),
		"defense_rate": profile.get_stat("defense_rate", 0.0),
		"appearance_rate": profile.get_stat("appearance_rate", 0.0),
		"hit_gauge_gain": profile.get_stat("hit_gauge_gain", 0.0),
	}


static func _build_snapshot(
	pet_id: String,
	display_name: String,
	stats: Dictionary,
	active_entries: Array[Dictionary],
	passive_entries: Array[Dictionary],
	active_skill: Dictionary,
	passive_skill: Dictionary,
	pending_roll: bool
) -> Dictionary:
	return {
		"pet_id": pet_id,
		"display_name": display_name,
		"art_path": LingpetCatalog.get_visual_path(pet_id, "cutin_art"),
		"stats": stats,
		"active_skills": active_entries,
		"passive_skills": passive_entries,
		"active_skill_name": str(active_skill.get("name", "")),
		"active_skill_description": str(active_skill.get("description", "")),
		"active_skill_cooldown": float(active_skill.get("cooldown", 0.0)),
		"active_skill_icon_path": str(active_skill.get("icon_path", "")),
		"active_skill_level": int(active_skill.get("level", 0)),
		"passive_skill_name": str(passive_skill.get("name", "")),
		"passive_skill_description": str(passive_skill.get("description", "")),
		"passive_skill_icon_path": str(passive_skill.get("icon_path", "")),
		"passive_skill_level": int(passive_skill.get("level", 0)),
		"pending_roll": pending_roll,
	}
