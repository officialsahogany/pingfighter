extends RefCounted

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")


func roll_item_egg_hatch_traits(
	pet_id: String,
	loadout_state: Object,
	item_egg_profile: Object,
	affinity_state: Object
) -> bool:
	# Item-egg hatches (a coexisting egg absorbed while a companion stays active, or an overflow
	# slot-replace) must roll the SAME hatch loadout + stat headstart that regular hatches roll.
	# The loadout write intentionally stays unsynced: this helper invalidates the owner-loadout
	# sync key so the next owner sync republishes the loadouts dictionary without stealing the
	# active companion's published skill level.
	if pet_id == "" or loadout_state == null or item_egg_profile == null:
		return false
	loadout_state.roll_and_store_pet_loadout_unsynced(pet_id, null)
	if loadout_state.has_method("invalidate_owner_loadout_sync_for_runtime"):
		loadout_state.invalidate_owner_loadout_sync_for_runtime()
	item_egg_profile.set_pet_id(pet_id)
	ensure_roll(pet_id, affinity_state, item_egg_profile, LingpetAffinityState.MOTION_STYLE_PATROL)
	return true


func ensure_roll(
	pet_id: String,
	affinity_state: Object,
	current_profile: Object,
	patrol_motion_style: String
) -> Dictionary:
	if affinity_state == null or current_profile == null:
		return {
			"accepted": false,
			"blocked_reason": "missing_state",
		}
	var normalized_pet_id := _normalize_pet_id(pet_id, current_profile)
	if normalized_pet_id == "":
		return {
			"accepted": false,
			"blocked_reason": "missing_pet_id",
		}
	if affinity_state.has_method("has_hatch_stat_roll") and bool(affinity_state.has_hatch_stat_roll(normalized_pet_id)):
		return {
			"accepted": false,
			"blocked_reason": "already_set",
			"pet_id": normalized_pet_id,
		}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var mobility_headstart: float = rng.randf()
	var defense_headstart: float = rng.randf()
	var motion_style := ""
	if current_profile.has_method("get_affinity_motion_style"):
		motion_style = str(current_profile.get_affinity_motion_style())
	if motion_style != patrol_motion_style:
		defense_headstart = 0.0
	var result: Dictionary = {}
	if affinity_state.has_method("set_hatch_stat_roll"):
		result = affinity_state.set_hatch_stat_roll(normalized_pet_id, mobility_headstart, defense_headstart)
	result["accepted"] = true
	result["pet_id"] = normalized_pet_id
	return result


func _normalize_pet_id(pet_id: String, current_profile: Object) -> String:
	if current_profile != null and current_profile.has_method("normalize_pet_id"):
		return str(current_profile.normalize_pet_id(pet_id))
	return pet_id.strip_edges().to_lower()
