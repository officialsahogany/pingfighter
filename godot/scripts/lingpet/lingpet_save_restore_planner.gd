extends RefCounted

const STATE_NONE := "none"
const STATE_EGG := "egg"
const STATE_COMPANION := "companion"


func build_plan(
	snapshot: Dictionary,
	owner: Object,
	collection_state: Object,
	current_pet_id: String,
	restored_state: String
) -> Dictionary:
	if collection_state == null:
		return _make_plan(STATE_NONE, current_pet_id)
	var legacy_owned: Variant = snapshot.get("owned_pet_ids", [])
	if collection_state.has_method("set_collected_pet_ids"):
		collection_state.set_collected_pet_ids(snapshot.get("collected_pet_ids", legacy_owned))
	collection_state.set_battle_slots(snapshot.get("battle_slot_pet_ids", snapshot.get("lingpet_slots", [])))
	collection_state.set_active_slot_index(0)
	var active_pet_id := _normalize_pet_id(collection_state, str(snapshot.get("active_pet_id", "")))
	var first_slot_pet_id := ""
	var normalized_slots: Array = collection_state.get_battle_slots()
	if not normalized_slots.is_empty():
		first_slot_pet_id = _normalize_pet_id(collection_state, str(normalized_slots[0]))
	var first_legacy_owned := ""
	if legacy_owned is Array:
		for raw_id in (legacy_owned as Array):
			first_legacy_owned = _normalize_pet_id(collection_state, str(raw_id))
			if first_legacy_owned != "":
				break
	var live_pet_id := active_pet_id
	if live_pet_id == "":
		live_pet_id = first_slot_pet_id
	if live_pet_id == "":
		live_pet_id = first_legacy_owned
	collection_state.set_owned_pet_ids([live_pet_id] if live_pet_id != "" else [])
	collection_state.set_battle_slots([live_pet_id] if live_pet_id != "" else [""])
	if active_pet_id != "":
		collection_state.add_pet(null, active_pet_id)

	var owned_pet_id := live_pet_id
	var owned_pet_ids: Array = collection_state.get_owned_pet_ids()
	if restored_state == STATE_COMPANION or owned_pet_ids.has(current_pet_id) or active_pet_id != "" or owned_pet_id != "":
		var companion_pet_id := current_pet_id
		if active_pet_id != "":
			companion_pet_id = active_pet_id
		elif owned_pet_id != "":
			companion_pet_id = owned_pet_id
		return _make_plan(STATE_COMPANION, companion_pet_id)

	if restored_state == STATE_EGG:
		if owner != null and bool(collection_state.should_spawn_egg(owner)):
			return _make_plan(STATE_EGG, current_pet_id, "egg_reset_on_entry", true)
		return _make_plan(STATE_NONE, current_pet_id, "egg_reset_on_entry")

	return _make_plan(STATE_NONE, current_pet_id)


func _make_plan(
	target_state: String,
	pet_id: String,
	restore_reason: String = "ok",
	spawn_fresh_egg: bool = false
) -> Dictionary:
	return {
		"target_state": target_state,
		"pet_id": pet_id,
		"restore_reason": restore_reason,
		"spawn_fresh_egg": spawn_fresh_egg,
	}


func _normalize_pet_id(collection_state: Object, value: String) -> String:
	if collection_state == null or not collection_state.has_method("normalize_pet_id"):
		return ""
	return str(collection_state.normalize_pet_id(value))
