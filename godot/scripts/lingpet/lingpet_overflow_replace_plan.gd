extends RefCounted

const ACTION_ITEM_EGG_REPLACE := "item_egg_replace"
const ACTION_FINISH_MAIN_COMMIT := "finish_main_commit"


func consume(
	owner: Object,
	slot_index: int,
	overflow_choice_state: Object,
	collection_state: Object
) -> Dictionary:
	if overflow_choice_state == null or not overflow_choice_state.is_active_with_pending_pet():
		return _empty_plan()
	if overflow_choice_state.has_method("is_absorb_only") and bool(overflow_choice_state.is_absorb_only()):
		return _empty_plan()
	var pending_pet_id := str(overflow_choice_state.get_pending_pet_id())
	if pending_pet_id == "":
		return _empty_plan()
	if bool(overflow_choice_state.is_item_egg_source()):
		return {
			"handled": true,
			"action": ACTION_ITEM_EGG_REPLACE,
			"pending_pet_id": pending_pet_id,
			"old_pet_id": "",
		}
	if collection_state == null or not collection_state.has_method("replace_slot"):
		return _empty_plan()
	var raw_replace_result: Variant = collection_state.replace_slot(owner, slot_index, pending_pet_id)
	if not (raw_replace_result is Dictionary):
		return _empty_plan()
	var replace_result: Dictionary = raw_replace_result as Dictionary
	if replace_result.is_empty():
		return _empty_plan()
	return {
		"handled": true,
		"action": ACTION_FINISH_MAIN_COMMIT,
		"pending_pet_id": pending_pet_id,
		"old_pet_id": str(replace_result.get("old_pet_id", "")),
	}


func _empty_plan() -> Dictionary:
	return {
		"handled": false,
		"action": "",
		"pending_pet_id": "",
		"old_pet_id": "",
	}
