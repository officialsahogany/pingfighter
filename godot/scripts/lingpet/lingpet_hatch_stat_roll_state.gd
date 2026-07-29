extends RefCounted

const SAVE_KEY := "hatch_stat_rolls"
const LEGACY_MOBILITY_KEY := "hatch_mobility_headstart"
const LEGACY_DEFENSE_KEY := "hatch_defense_headstart"
const LEGACY_SET_KEY := "hatch_stat_roll_set"

var _rolls: Dictionary = {}


func reset_for_new_run() -> void:
	_rolls.clear()


func export_run_state() -> Dictionary:
	var rolls_copy := {}
	for raw_pet_id in _rolls.keys():
		var pet_id := _normalize_raw_pet_id(str(raw_pet_id))
		var roll: Variant = _rolls.get(raw_pet_id, {})
		if pet_id.is_empty() or not (roll is Dictionary):
			continue
		rolls_copy[pet_id] = _sanitize_roll(roll as Dictionary)
	return {SAVE_KEY: rolls_copy}


func import_run_state(data: Dictionary) -> void:
	_rolls.clear()
	var raw_rolls: Variant = data.get(SAVE_KEY, {})
	if raw_rolls is Dictionary:
		for raw_pet_id in (raw_rolls as Dictionary).keys():
			var pet_id := _normalize_raw_pet_id(str(raw_pet_id))
			var raw_roll: Variant = (raw_rolls as Dictionary).get(raw_pet_id, {})
			if not pet_id.is_empty() and raw_roll is Dictionary:
				_rolls[pet_id] = _sanitize_roll(raw_roll as Dictionary)

	# Compatibility reader for saves written while hatch individuality lived in
	# affinity_state's per-pet dictionary. New exports never write these fields.
	var legacy_pets: Variant = data.get("pets", {})
	if legacy_pets is Dictionary:
		for raw_pet_id in (legacy_pets as Dictionary).keys():
			var pet_id := _normalize_raw_pet_id(str(raw_pet_id))
			var raw_pet: Variant = (legacy_pets as Dictionary).get(raw_pet_id, {})
			if pet_id.is_empty() or _rolls.has(pet_id) or not (raw_pet is Dictionary):
				continue
			var legacy_pet := raw_pet as Dictionary
			if not bool(legacy_pet.get(LEGACY_SET_KEY, false)):
				continue
			_rolls[pet_id] = _sanitize_roll({
				"mobility": legacy_pet.get(LEGACY_MOBILITY_KEY, 0.0),
				"defense": legacy_pet.get(LEGACY_DEFENSE_KEY, 0.0),
			})


func set_hatch_stat_roll(
	pet_id: String,
	mobility_headstart: float,
	defense_headstart: float
) -> Dictionary:
	var normalized_pet_id := _normalize_raw_pet_id(pet_id)
	if normalized_pet_id.is_empty():
		return get_empty_hatch_stat_roll()
	_rolls[normalized_pet_id] = _sanitize_roll({
		"mobility": mobility_headstart,
		"defense": defense_headstart,
	})
	return get_hatch_stat_roll(normalized_pet_id)


func has_hatch_stat_roll(pet_id: String) -> bool:
	return _rolls.has(_normalize_raw_pet_id(pet_id))


func get_hatch_stat_roll(pet_id: String) -> Dictionary:
	var normalized_pet_id := _normalize_raw_pet_id(pet_id)
	if normalized_pet_id.is_empty() or not _rolls.has(normalized_pet_id):
		return get_empty_hatch_stat_roll()
	var result := _sanitize_roll(_rolls.get(normalized_pet_id, {}) as Dictionary)
	result["has_roll"] = true
	return result


static func get_empty_hatch_stat_roll() -> Dictionary:
	return {"mobility": 0.0, "defense": 0.0, "has_roll": false}


func roll_item_egg_hatch_traits(
	pet_id: String,
	loadout_state: Object,
	item_egg_profile: Object
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
	ensure_roll(pet_id, item_egg_profile, "patrol")
	return true


func ensure_roll(
	pet_id: String,
	current_profile: Object,
	patrol_motion_style: String
) -> Dictionary:
	if current_profile == null:
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
	if has_hatch_stat_roll(normalized_pet_id):
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
		motion_style = str(current_profile.get_guardian_motion_style())
	if motion_style != patrol_motion_style:
		defense_headstart = 0.0
	var result := set_hatch_stat_roll(normalized_pet_id, mobility_headstart, defense_headstart)
	result["accepted"] = true
	result["pet_id"] = normalized_pet_id
	return result


func _normalize_pet_id(pet_id: String, current_profile: Object) -> String:
	if current_profile != null and current_profile.has_method("normalize_pet_id"):
		return str(current_profile.normalize_pet_id(pet_id))
	return _normalize_raw_pet_id(pet_id)


static func _sanitize_roll(raw_roll: Dictionary) -> Dictionary:
	return {
		"mobility": clampf(float(raw_roll.get("mobility", 0.0)), 0.0, 1.0),
		"defense": clampf(float(raw_roll.get("defense", 0.0)), 0.0, 1.0),
	}


static func _normalize_raw_pet_id(pet_id: String) -> String:
	return pet_id.strip_edges().to_lower()
