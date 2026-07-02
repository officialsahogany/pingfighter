extends RefCounted

var pending := false
var active := false
var pending_pet_id := ""
var suspended_companion_pet_id := ""
var from_item_egg := false


func reset() -> void:
	pending = false
	active = false
	pending_pet_id = ""
	suspended_companion_pet_id = ""
	from_item_egg = false


func has_pending_or_active() -> bool:
	return pending or active


func is_active() -> bool:
	return bool(active)


func is_active_with_pending_pet() -> bool:
	return bool(active) and str(pending_pet_id) != ""


func is_item_egg_source() -> bool:
	return bool(from_item_egg)


func get_pending_pet_id() -> String:
	return str(pending_pet_id)


func consume_commit_pet_id() -> String:
	var pet_id := str(pending_pet_id)
	reset()
	return pet_id


func consume_release_context() -> Dictionary:
	var context := {
		"pending_pet_id": str(pending_pet_id),
		"suspended_companion_pet_id": str(suspended_companion_pet_id),
		"from_item_egg": bool(from_item_egg),
	}
	reset()
	return context


func build_snapshot(collection_state: Object) -> Dictionary:
	var active_slot_index := 0
	if collection_state != null and collection_state.has_method("get_active_slot_index"):
		active_slot_index = int(collection_state.get_active_slot_index())
	var slot_entries: Array[Dictionary] = []
	if collection_state != null and collection_state.has_method("get_battle_slots"):
		var raw_slots: Variant = collection_state.get_battle_slots()
		if raw_slots is Array:
			for i in range((raw_slots as Array).size()):
				var slot_pet_id := str((raw_slots as Array)[i])
				slot_entries.append({
					"slot_index": i,
					"pet_id": slot_pet_id,
					"display_name": _get_pet_display_name(collection_state, slot_pet_id),
					"active": i == active_slot_index,
				})
	var pending_id := str(pending_pet_id)
	return {
		"active": bool(active),
		"pending_pet_id": pending_id,
		"pending_display_name": _get_pet_display_name(collection_state, pending_id),
		"slots": slot_entries,
		"active_slot_index": active_slot_index,
	}


func begin_main_egg(suspended_pet_id: String) -> void:
	reset()
	suspended_companion_pet_id = suspended_pet_id


func begin_main_overflow(pet_id: String) -> void:
	pending = true
	active = false
	pending_pet_id = pet_id
	from_item_egg = false


func begin_item_egg_overflow(pet_id: String) -> void:
	pending = true
	active = true
	pending_pet_id = pet_id
	suspended_companion_pet_id = ""
	from_item_egg = true


func activate_after_cutin() -> bool:
	if pending and pending_pet_id != "":
		active = true
		return true
	return false


func resolve_after_acquire_cutin(item_egg_lifecycle_state: Object) -> bool:
	if (
		item_egg_lifecycle_state != null
		and item_egg_lifecycle_state.has_method("mark_absorb_ready_if_awaiting")
		and bool(item_egg_lifecycle_state.call("mark_absorb_ready_if_awaiting"))
	):
		return true
	return activate_after_cutin()


func _get_pet_display_name(collection_state: Object, pet_id: String) -> String:
	if collection_state == null or not collection_state.has_method("get_pet_display_name"):
		return pet_id
	return str(collection_state.get_pet_display_name(pet_id))
