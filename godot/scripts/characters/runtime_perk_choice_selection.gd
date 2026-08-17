extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const RuntimePerkPayloadAccess := preload("res://scripts/characters/runtime_perk_payload_access.gd")

const MIN_SELECTABLE_ANIMATION_TIME := 0.24


func is_selectable(
	choice_active: bool,
	choice_flight_active: bool,
	unlock_showcase_active: bool,
	has_pending_swap: bool,
	animation_time: float,
	choice_count: int
) -> bool:
	return (
		choice_active
		and not choice_flight_active
		and not unlock_showcase_active
		and not has_pending_swap
		and animation_time >= MIN_SELECTABLE_ANIMATION_TIME
		and choice_count > 0
	)


func is_selectable_from_runtime_state(runtime_state: Object) -> bool:
	if runtime_state == null:
		return false
	return is_selectable(
		bool(RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "choice_active")),
		RuntimePerkRuntimeStateAccess.is_payload_active(runtime_state, "choice_flight_effect", "_active_unlock_flight"),
		RuntimePerkRuntimeStateAccess.is_payload_active(runtime_state, "unlock_showcase", "_unlock_showcase_controller"),
		RuntimePerkRuntimeStateAccess.call_bool(runtime_state, "has_pending_unlock_swap"),
		float(RuntimePerkRuntimeStateAccess.get_float(runtime_state, "animation_time")),
		RuntimePerkPayloadAccess.as_array(RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices")).size()
	)


func build_move_selection_update(current_index: int, delta_index: int, choice_count: int) -> Dictionary:
	var safe_choice_count: int = max(0, choice_count)
	if safe_choice_count <= 0:
		return {"accepted": false, "blocked_reason": "empty_choices"}
	return {
		"accepted": true,
		"selected_index": posmod(current_index + delta_index, safe_choice_count),
	}


func build_direct_selection_update(index: int, choice_count: int) -> Dictionary:
	var safe_choice_count: int = max(0, choice_count)
	if safe_choice_count <= 0:
		return {"accepted": false, "blocked_reason": "empty_choices"}
	if index < 0 or index >= safe_choice_count:
		return {"accepted": false, "blocked_reason": "out_of_range"}
	return {
		"accepted": true,
		"selected_index": index,
	}


func move_selection_from_runtime_state(runtime_state: Object, delta_index: int) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false, "blocked_reason": "missing_runtime_state"}
	return apply_state_update(
		runtime_state,
		build_move_selection_update(
			int(RuntimePerkRuntimeStateAccess.get_int(runtime_state, "selected_index")),
			delta_index,
			RuntimePerkPayloadAccess.as_array(RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices")).size()
		)
	)


func select_index_from_runtime_state(runtime_state: Object, index: int) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false, "blocked_reason": "missing_runtime_state"}
	return apply_state_update(
		runtime_state,
		build_direct_selection_update(
			index,
			RuntimePerkPayloadAccess.as_array(RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices")).size()
		)
	)


func build_selected_choice_payload(choices: Array, selected_index: int, selectable: bool) -> Dictionary:
	if not selectable:
		return {"accepted": false, "blocked_reason": "not_selectable"}
	if selected_index < 0 or selected_index >= choices.size():
		return {"accepted": false, "blocked_reason": "selected_index_out_of_range"}
	var choice: Dictionary = RuntimePerkPayloadAccess.as_dict(choices[selected_index])
	var choice_id: String = str(choice.get("id", ""))
	if choice_id == "":
		return {"accepted": false, "blocked_reason": "missing_choice_id"}
	return {
		"accepted": true,
		"choice": choice.duplicate(true),
		"choice_id": choice_id,
	}


func apply_state_update(runtime_state: Object, update: Dictionary) -> Dictionary:
	if runtime_state == null or not bool(update.get("accepted", false)):
		return {"accepted": false}
	runtime_state.set("selected_index", int(update.get("selected_index", RuntimePerkRuntimeStateAccess.get_int(runtime_state, "selected_index"))))
	return {
		"accepted": true,
		"selected_index": int(RuntimePerkRuntimeStateAccess.get_int(runtime_state, "selected_index")),
	}
