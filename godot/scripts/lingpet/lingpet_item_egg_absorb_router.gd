extends RefCounted


func route_absorbed_pet(
	owner: Object,
	pet_id: String,
	collection_state: Object,
	overflow_choice_state: Object
) -> Dictionary:
	var normalized_pet_id := pet_id.strip_edges()
	if normalized_pet_id == "":
		return _empty_result()
	if collection_state == null:
		return _empty_result()
	if collection_state.has_method("sync_from_owner"):
		collection_state.call("sync_from_owner", owner)
	if collection_state.has_method("is_full") and bool(collection_state.call("is_full", owner)):
		if overflow_choice_state != null and overflow_choice_state.has_method("begin_item_egg_overflow"):
			overflow_choice_state.call("begin_item_egg_overflow", normalized_pet_id)
		return {
			"handled": true,
			"opened_overflow": true,
			"registered_pet_id": "",
		}
	var registered_pet_id := ""
	if collection_state.has_method("add_pet_to_collection_keep_active"):
		registered_pet_id = str(collection_state.call("add_pet_to_collection_keep_active", owner, normalized_pet_id))
	return {
		"handled": registered_pet_id != "",
		"opened_overflow": false,
		"registered_pet_id": registered_pet_id,
	}


func commit_overflow_replace(
	owner: Object,
	slot_index: int,
	pet_id: String,
	companion_pet_id: String,
	collection_state: Object
) -> Dictionary:
	var normalized_pet_id := pet_id.strip_edges()
	if normalized_pet_id == "" or collection_state == null:
		return _empty_replace_result()
	if not collection_state.has_method("replace_slot"):
		return _empty_replace_result()
	var raw_replace_result: Variant = collection_state.call("replace_slot", owner, slot_index, normalized_pet_id)
	if not (raw_replace_result is Dictionary):
		return _empty_replace_result()
	var replace_result: Dictionary = raw_replace_result as Dictionary
	if replace_result.is_empty():
		return _empty_replace_result()
	var old_pet_id := str(replace_result.get("old_pet_id", ""))
	var new_pet_id := str(replace_result.get("new_pet_id", normalized_pet_id))
	var normalized_companion_pet_id := companion_pet_id.strip_edges()
	var replaced_active_companion := normalized_companion_pet_id != "" and old_pet_id == normalized_companion_pet_id
	if not replaced_active_companion and normalized_companion_pet_id != "":
		if (
			collection_state.has_method("has_owned_pet")
			and bool(collection_state.call("has_owned_pet", owner, normalized_companion_pet_id))
			and collection_state.has_method("ensure_pet_active_slot")
		):
			collection_state.call("ensure_pet_active_slot", owner, normalized_companion_pet_id)
	return {
		"handled": true,
		"old_pet_id": old_pet_id,
		"new_pet_id": new_pet_id,
		"slot_index": int(replace_result.get("slot_index", slot_index)),
		"replaced_active_companion": replaced_active_companion,
	}


func _empty_result() -> Dictionary:
	return {
		"handled": false,
		"opened_overflow": false,
		"registered_pet_id": "",
	}


func _empty_replace_result() -> Dictionary:
	return {
		"handled": false,
		"old_pet_id": "",
		"new_pet_id": "",
		"slot_index": -1,
		"replaced_active_companion": false,
	}
