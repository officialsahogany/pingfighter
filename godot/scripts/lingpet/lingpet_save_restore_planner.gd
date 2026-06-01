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
	collection_state.set_owned_pet_ids(snapshot.get("owned_pet_ids", []))
	collection_state.set_battle_slots(snapshot.get("battle_slot_pet_ids", snapshot.get("lingpet_slots", [])))
	collection_state.set_active_slot_index(int(snapshot.get("active_slot_index", 0)))
	var active_pet_id := _normalize_pet_id(collection_state, str(snapshot.get("active_pet_id", "")))
	if active_pet_id != "":
		collection_state.add_pet(null, active_pet_id)
		var battle_slots: Array = collection_state.get_battle_slots()
		var active_slot_index := int(collection_state.get_active_slot_index())
		if active_slot_index >= 0 and active_slot_index < battle_slots.size() and str(battle_slots[active_slot_index]) == "":
			collection_state.set_battle_slots([active_pet_id, "", ""])
			collection_state.set_active_slot_index(0)

	var owned_pet_id := str(collection_state.find_active_slot_pet_id(owner))
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
