extends RefCounted

const CALLBACK_FINISH_SUCCESSFUL_CHOICE := "finish_successful_choice"
const CALLBACK_SYNC_OWNER := "sync_owner"
const CALLBACK_IS_UNLOCK_SHOWCASE_ACTIVE := "is_unlock_showcase_active"


func build_state_callbacks(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {}
	return {
		CALLBACK_FINISH_SUCCESSFUL_CHOICE: Callable(runtime_state, "_finish_successful_choice"),
		CALLBACK_SYNC_OWNER: Callable(runtime_state, "_sync_owner"),
		CALLBACK_IS_UNLOCK_SHOWCASE_ACTIVE: Callable(runtime_state, "is_unlock_showcase_active"),
	}


func finish_or_open_unlock_showcase_from_runtime_state(
	runtime_state: Object,
	choice_id: String,
	owner: Object,
	registry: Object,
	perf_logger: Object,
	choice: Dictionary = {}
) -> Dictionary:
	return finish_or_open_unlock_showcase(
		choice_id,
		owner,
		registry,
		perf_logger,
		choice,
		runtime_state,
		_get_runtime_state_object(runtime_state, "_unlock_showcase_controller"),
		build_state_callbacks(runtime_state)
	)


func finish_or_open_unlock_showcase(
	choice_id: String,
	owner: Object,
	registry: Object,
	perf_logger: Object,
	choice: Dictionary,
	runtime_state: Object,
	unlock_showcase_controller: Object,
	callbacks: Dictionary
) -> Dictionary:
	if runtime_state == null or unlock_showcase_controller == null:
		return {"accepted": false, "blocked_reason": "missing_showcase_flow_deps"}
	if unlock_showcase_controller.should_open(choice, owner):
		return open_unlock_showcase(
			choice_id,
			owner,
			registry,
			choice,
			runtime_state,
			unlock_showcase_controller,
			callbacks
		)
	var result: Dictionary = _call_optional(
		callbacks,
		CALLBACK_FINISH_SUCCESSFUL_CHOICE,
		[choice_id, owner, registry, perf_logger, choice]
	)
	result["finished"] = bool(result.get("accepted", false))
	result["choice_id"] = choice_id
	return result


func open_unlock_showcase(
	choice_id: String,
	owner: Object,
	registry: Object,
	choice: Dictionary,
	runtime_state: Object,
	unlock_showcase_controller: Object,
	callbacks: Dictionary
) -> Dictionary:
	if runtime_state == null or unlock_showcase_controller == null:
		return {"accepted": false, "blocked_reason": "missing_showcase_flow_deps"}
	var showcase: Dictionary = unlock_showcase_controller.build(choice_id, owner, registry, choice)
	var apply_result: Dictionary = unlock_showcase_controller.apply_showcase_state_update(runtime_state, showcase)
	var accepted: bool = bool(apply_result.get("accepted", false))
	apply_result["opened_showcase"] = accepted
	if accepted:
		_call_optional(callbacks, CALLBACK_SYNC_OWNER, [owner])
	return apply_result


func update_unlock_showcase_from_runtime_state(
	runtime_state: Object,
	delta: float,
	owner: Object,
	registry: Object,
	perf_logger: Object = null
) -> Dictionary:
	return update_unlock_showcase(
		_get_runtime_state_dict(runtime_state, "unlock_showcase"),
		delta,
		owner,
		registry,
		_get_runtime_state_object(runtime_state, "_unlock_showcase_controller"),
		build_state_callbacks(runtime_state),
		perf_logger
	)


func update_unlock_showcase(
	unlock_showcase: Dictionary,
	delta: float,
	owner: Object,
	registry: Object,
	unlock_showcase_controller: Object,
	callbacks: Dictionary,
	perf_logger: Object = null
) -> Dictionary:
	if unlock_showcase_controller == null:
		return {"accepted": false, "blocked_reason": "missing_unlock_showcase_controller"}
	if unlock_showcase_controller.advance(unlock_showcase, delta):
		return dismiss_unlock_showcase(
			unlock_showcase,
			owner,
			registry,
			unlock_showcase_controller,
			callbacks,
			perf_logger
		)
	return {"accepted": true, "dismissed": false}


func dismiss_unlock_showcase_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	perf_logger: Object = null
) -> Dictionary:
	return dismiss_unlock_showcase(
		_get_runtime_state_dict(runtime_state, "unlock_showcase"),
		owner,
		registry,
		_get_runtime_state_object(runtime_state, "_unlock_showcase_controller"),
		build_state_callbacks(runtime_state),
		perf_logger
	)


func dismiss_unlock_showcase(
	unlock_showcase: Dictionary,
	owner: Object,
	registry: Object,
	unlock_showcase_controller: Object,
	callbacks: Dictionary,
	perf_logger: Object = null
) -> Dictionary:
	if unlock_showcase_controller == null:
		return {"accepted": false, "dismissed": false, "blocked_reason": "missing_unlock_showcase_controller"}
	if not _is_unlock_showcase_active(unlock_showcase, unlock_showcase_controller, callbacks):
		return {"accepted": false, "dismissed": false}
	var showcase: Dictionary = unlock_showcase_controller.consume(unlock_showcase)
	var choice: Dictionary = _get_dict(showcase.get("choice", {}))
	var choice_id: String = str(showcase.get("choice_id", choice.get("id", "")))
	if choice_id == "":
		_call_optional(callbacks, CALLBACK_SYNC_OWNER, [owner])
		return {
			"accepted": false,
			"dismissed": true,
			"blocked_reason": "missing_choice_id",
		}
	var result: Dictionary = _call_optional(
		callbacks,
		CALLBACK_FINISH_SUCCESSFUL_CHOICE,
		[choice_id, owner, registry, perf_logger, choice]
	)
	result["dismissed"] = true
	result["choice_id"] = choice_id
	return result


func handle_unlock_showcase_input_from_runtime_state(
	runtime_state: Object,
	event: InputEvent,
	owner: Object,
	registry: Object
) -> Dictionary:
	return handle_unlock_showcase_input(
		_get_runtime_state_dict(runtime_state, "unlock_showcase"),
		event,
		owner,
		registry,
		_get_runtime_state_object(runtime_state, "_unlock_showcase_controller"),
		build_state_callbacks(runtime_state)
	)


func handle_unlock_showcase_input(
	unlock_showcase: Dictionary,
	event: InputEvent,
	owner: Object,
	registry: Object,
	unlock_showcase_controller: Object,
	callbacks: Dictionary
) -> Dictionary:
	if unlock_showcase_controller == null:
		return {"accepted": false, "handled": true, "blocked_reason": "missing_unlock_showcase_controller"}
	if unlock_showcase_controller.should_dismiss_from_input(unlock_showcase, event):
		var dismiss_result: Dictionary = dismiss_unlock_showcase(
			unlock_showcase,
			owner,
			registry,
			unlock_showcase_controller,
			callbacks
		)
		dismiss_result["handled"] = true
		return dismiss_result
	return {"accepted": true, "handled": true, "dismissed": false}


func _is_unlock_showcase_active(
	unlock_showcase: Dictionary,
	unlock_showcase_controller: Object,
	callbacks: Dictionary
) -> bool:
	var callback := _get_callback(callbacks, CALLBACK_IS_UNLOCK_SHOWCASE_ACTIVE)
	if callback.is_valid():
		return bool(callback.call())
	if unlock_showcase_controller != null and unlock_showcase_controller.has_method("is_active"):
		return bool(unlock_showcase_controller.is_active(unlock_showcase))
	return false


func _call_optional(callbacks: Dictionary, key: String, args: Array) -> Dictionary:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return {"accepted": false, "blocked_reason": "missing_%s" % key}
	var result: Variant = callback.callv(args)
	if result is Dictionary:
		if result.has("accepted"):
			return result
		result["accepted"] = true
		return result
	return {"accepted": true}


func _get_callback(callbacks: Dictionary, key: String) -> Callable:
	var value: Variant = callbacks.get(key, Callable())
	if value is Callable:
		return value
	return Callable()


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_runtime_state_object(runtime_state: Object, key: String) -> Object:
	if runtime_state == null:
		return null
	var value: Variant = runtime_state.get(key)
	if value is Object:
		return value
	return null


func _get_runtime_state_dict(runtime_state: Object, key: String) -> Dictionary:
	if runtime_state == null:
		return {}
	return _get_dict(runtime_state.get(key))
