extends RefCounted

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
		bool(runtime_state.get("choice_active")),
		_is_runtime_payload_active(runtime_state, "_active_unlock_flight", "choice_flight_effect"),
		_is_runtime_payload_active(runtime_state, "_unlock_showcase_controller", "unlock_showcase"),
		_has_runtime_pending_swap(runtime_state),
		float(runtime_state.get("animation_time")),
		_get_array(runtime_state.get("current_choices")).size()
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
			int(runtime_state.get("selected_index")),
			delta_index,
			_get_array(runtime_state.get("current_choices")).size()
		)
	)


func select_index_from_runtime_state(runtime_state: Object, index: int) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false, "blocked_reason": "missing_runtime_state"}
	return apply_state_update(
		runtime_state,
		build_direct_selection_update(
			index,
			_get_array(runtime_state.get("current_choices")).size()
		)
	)


func build_selected_choice_payload(choices: Array, selected_index: int, selectable: bool) -> Dictionary:
	if not selectable:
		return {"accepted": false, "blocked_reason": "not_selectable"}
	if selected_index < 0 or selected_index >= choices.size():
		return {"accepted": false, "blocked_reason": "selected_index_out_of_range"}
	var choice: Dictionary = _get_dict(choices[selected_index])
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
	runtime_state.set("selected_index", int(update.get("selected_index", runtime_state.get("selected_index"))))
	return {
		"accepted": true,
		"selected_index": int(runtime_state.get("selected_index")),
	}


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _is_runtime_payload_active(runtime_state: Object, helper_key: String, payload_key: String) -> bool:
	if runtime_state == null:
		return false
	var payload: Dictionary = _get_dict(runtime_state.get(payload_key))
	var helper: Object = _get_runtime_state_object(runtime_state, helper_key)
	if helper != null and helper.has_method("is_active"):
		return bool(helper.is_active(payload))
	return bool(payload.get("active", false))


func _has_runtime_pending_swap(runtime_state: Object) -> bool:
	if runtime_state == null:
		return false
	var pending_swap: Dictionary = _get_dict(runtime_state.get("pending_unlock_swap"))
	var helper: Object = _get_runtime_state_object(runtime_state, "_unlock_swap_flow")
	if helper != null and helper.has_method("has_pending_swap"):
		return bool(helper.has_pending_swap(pending_swap))
	return not pending_swap.is_empty()


func _get_runtime_state_object(runtime_state: Object, key: String) -> Object:
	if runtime_state == null:
		return null
	var value: Variant = runtime_state.get(key)
	if value is Object:
		return value
	return null
