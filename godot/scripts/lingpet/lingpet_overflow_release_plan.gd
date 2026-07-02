extends RefCounted

const ACTION_SYNC_OWNER := "sync_owner"
const ACTION_RESTORE_COMPANION := "restore_companion"
const ACTION_CLEAR_PENDING := "clear_pending"


func consume(owner: Object, overflow_choice_state: Object, collection_state: Object) -> Dictionary:
	if overflow_choice_state == null or not overflow_choice_state.has_pending_or_active():
		return _empty_plan()
	var release_context: Dictionary = overflow_choice_state.consume_release_context()
	var released_pet_id := str(release_context.get("pending_pet_id", ""))
	if bool(release_context.get("from_item_egg", false)):
		return {
			"handled": true,
			"released_pet_id": released_pet_id,
			"restore_pet_id": "",
			"action": ACTION_SYNC_OWNER,
			"from_item_egg": true,
		}
	var restore_pet_id := str(release_context.get("suspended_companion_pet_id", ""))
	var can_restore := (
		restore_pet_id != ""
		and collection_state != null
		and collection_state.has_method("has_owned_pet")
		and bool(collection_state.has_owned_pet(owner, restore_pet_id))
	)
	return {
		"handled": true,
		"released_pet_id": released_pet_id,
		"restore_pet_id": restore_pet_id if can_restore else "",
		"action": ACTION_RESTORE_COMPANION if can_restore else ACTION_CLEAR_PENDING,
		"from_item_egg": false,
	}


func _empty_plan() -> Dictionary:
	return {
		"handled": false,
		"released_pet_id": "",
		"restore_pet_id": "",
		"action": "",
		"from_item_egg": false,
	}
