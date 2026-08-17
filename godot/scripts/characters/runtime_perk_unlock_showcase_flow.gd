extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const RuntimePerkCallbackMap := preload("res://scripts/characters/runtime_perk_callback_map.gd")

const RuntimePerkPayloadAccess := preload("res://scripts/characters/runtime_perk_payload_access.gd")

const CALLBACK_FINISH_SUCCESSFUL_CHOICE := "finish_successful_choice"
const CALLBACK_SYNC_OWNER := "sync_owner"
const CALLBACK_IS_UNLOCK_SHOWCASE_ACTIVE := "is_unlock_showcase_active"


func build_state_callbacks(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {}
	return {
		CALLBACK_FINISH_SUCCESSFUL_CHOICE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_finish_successful_choice"),
		CALLBACK_SYNC_OWNER: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_sync_owner"),
		CALLBACK_IS_UNLOCK_SHOWCASE_ACTIVE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "is_unlock_showcase_active"),
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
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_unlock_showcase_controller"),
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
	var result: Dictionary = RuntimePerkCallbackMap.call_optional(
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
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_SYNC_OWNER, [owner])
	return apply_result


func update_unlock_showcase_from_runtime_state(
	runtime_state: Object,
	delta: float,
	owner: Object,
	registry: Object,
	perf_logger: Object = null
) -> Dictionary:
	return update_unlock_showcase(
		RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "unlock_showcase"),
		delta,
		owner,
		registry,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_unlock_showcase_controller"),
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
		RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "unlock_showcase"),
		owner,
		registry,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_unlock_showcase_controller"),
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
	var choice: Dictionary = RuntimePerkPayloadAccess.as_dict(showcase.get("choice", {}))
	var choice_id: String = str(showcase.get("choice_id", choice.get("id", "")))
	if choice_id == "":
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_SYNC_OWNER, [owner])
		return {
			"accepted": false,
			"dismissed": true,
			"blocked_reason": "missing_choice_id",
		}
	var result: Dictionary = RuntimePerkCallbackMap.call_optional(
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
		RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "unlock_showcase"),
		event,
		owner,
		registry,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_unlock_showcase_controller"),
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
	var callback := RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_IS_UNLOCK_SHOWCASE_ACTIVE)
	if callback.is_valid():
		return bool(callback.call())
	if unlock_showcase_controller != null and unlock_showcase_controller.has_method("is_active"):
		return bool(unlock_showcase_controller.is_active(unlock_showcase))
	return false
