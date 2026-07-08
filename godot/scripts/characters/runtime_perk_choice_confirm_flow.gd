extends RefCounted

const CALLBACK_IS_SELECTABLE := "is_selectable"
const CALLBACK_GET_CARD_RECTS := "get_card_rects"
const CALLBACK_APPLY_CHOICE := "apply_choice"
const CALLBACK_APPLY_CHOICE_FAILURE_FEEDBACK := "apply_choice_failure_feedback"
const CALLBACK_PLAY_ACTIVE_UNLOCK_FLIGHT_AUDIO := "play_active_unlock_flight_audio"
const CALLBACK_PLAY_PERK_SELECT_AUDIO := "play_perk_select_audio"
const CALLBACK_FINISH_OR_OPEN_UNLOCK_SHOWCASE := "finish_or_open_unlock_showcase"


func build_state_callbacks(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {}
	return {
		CALLBACK_IS_SELECTABLE: Callable(runtime_state, "is_selectable"),
		CALLBACK_GET_CARD_RECTS: Callable(runtime_state, "get_card_rects"),
		CALLBACK_APPLY_CHOICE: Callable(runtime_state, "apply_choice"),
		CALLBACK_APPLY_CHOICE_FAILURE_FEEDBACK: Callable(runtime_state, "_apply_choice_failure_feedback"),
		CALLBACK_PLAY_ACTIVE_UNLOCK_FLIGHT_AUDIO: Callable(runtime_state, "_play_active_unlock_flight_audio"),
		CALLBACK_PLAY_PERK_SELECT_AUDIO: Callable(runtime_state, "_play_perk_select_audio"),
		CALLBACK_FINISH_OR_OPEN_UNLOCK_SHOWCASE: Callable(runtime_state, "_finish_or_open_unlock_showcase"),
	}


func choose_selected_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	view_size: Vector2 = Vector2.ZERO,
	perf_logger: Object = null
) -> Dictionary:
	return choose_selected(
		_get_runtime_state_array(runtime_state, "current_choices"),
		_get_runtime_state_int(runtime_state, "selected_index"),
		owner,
		registry,
		view_size,
		runtime_state,
		_get_runtime_state_object(runtime_state, "_choice_selection"),
		_get_runtime_state_object(runtime_state, "_active_unlock_flight"),
		build_state_callbacks(runtime_state),
		perf_logger
	)


func choose_selected(
	current_choices: Array,
	selected_index: int,
	owner: Object,
	registry: Object,
	view_size: Vector2,
	runtime_state: Object,
	choice_selection: Object,
	active_unlock_flight: Object,
	callbacks: Dictionary,
	perf_logger: Object = null
) -> Dictionary:
	if runtime_state == null or choice_selection == null:
		return {"accepted": false, "blocked_reason": "missing_confirm_flow_deps"}
	var selection: Dictionary = choice_selection.build_selected_choice_payload(
		current_choices,
		selected_index,
		_call_bool(callbacks, CALLBACK_IS_SELECTABLE, [], false)
	)
	if not bool(selection.get("accepted", false)):
		return selection
	var choice: Dictionary = _get_dict(selection.get("choice", {}))
	var choice_id: String = str(selection.get("choice_id", choice.get("id", "")))

	var flight_result: Dictionary = start_active_unlock_flight(
		choice,
		selected_index,
		owner,
		registry,
		view_size,
		runtime_state,
		active_unlock_flight,
		callbacks
	)
	if bool(flight_result.get("started_flight", false)):
		return _with_choice_result(flight_result, choice_id)

	var applied: bool = _call_bool(
		callbacks,
		CALLBACK_APPLY_CHOICE,
		[choice, owner, registry, perf_logger],
		false
	)
	if not applied:
		_call_optional(callbacks, CALLBACK_APPLY_CHOICE_FAILURE_FEEDBACK, [])
		return {
			"accepted": false,
			"choice_id": choice_id,
			"blocked_reason": "choice_apply_failed",
		}

	_call_optional(callbacks, CALLBACK_PLAY_PERK_SELECT_AUDIO, [registry])
	_call_optional(
		callbacks,
		CALLBACK_FINISH_OR_OPEN_UNLOCK_SHOWCASE,
		[choice_id, owner, registry, perf_logger, choice]
	)
	return {
		"accepted": true,
		"choice_id": choice_id,
		"applied": true,
	}


func start_active_unlock_flight(
	choice: Dictionary,
	selected_index: int,
	owner: Object,
	registry: Object,
	view_size: Vector2,
	runtime_state: Object,
	active_unlock_flight: Object,
	callbacks: Dictionary
) -> Dictionary:
	if runtime_state == null or active_unlock_flight == null:
		return {"accepted": false, "started_flight": false}
	var effect: Dictionary = active_unlock_flight.build_effect_for_selected_card(
		choice,
		selected_index,
		_call_array(callbacks, CALLBACK_GET_CARD_RECTS, [view_size]),
		owner,
		registry,
		view_size
	)
	if effect.is_empty():
		return {"accepted": false, "started_flight": false}
	var apply_result: Dictionary = active_unlock_flight.apply_effect_state_update(runtime_state, effect)
	if not bool(apply_result.get("accepted", false)):
		apply_result["started_flight"] = false
		return apply_result
	_call_optional(callbacks, CALLBACK_PLAY_ACTIVE_UNLOCK_FLIGHT_AUDIO, [registry])
	apply_result["started_flight"] = true
	return apply_result


func update_choice_flight_effect(
	choice_flight_effect: Dictionary,
	delta: float,
	owner: Object,
	registry: Object,
	active_unlock_flight: Object,
	callbacks: Dictionary,
	perf_logger: Object = null
) -> Dictionary:
	if active_unlock_flight == null:
		return {"accepted": false, "blocked_reason": "missing_active_unlock_flight"}
	if not active_unlock_flight.advance(choice_flight_effect, delta):
		return {"accepted": true, "finished": false}
	if owner == null or registry == null:
		return {"accepted": false, "finished": true, "blocked_reason": "missing_owner_or_registry"}
	var sample_start: int = _perf_begin(perf_logger)
	var result: Dictionary = finish_choice_flight_effect(
		choice_flight_effect,
		owner,
		registry,
		active_unlock_flight,
		callbacks,
		perf_logger
	)
	_perf_end(perf_logger, "process.runtime_perk.flight.finish", sample_start)
	result["finished"] = true
	return result


func update_choice_flight_effect_from_runtime_state(
	runtime_state: Object,
	delta: float,
	owner: Object,
	registry: Object,
	perf_logger: Object = null
) -> Dictionary:
	return update_choice_flight_effect(
		_get_runtime_state_dict(runtime_state, "choice_flight_effect"),
		delta,
		owner,
		registry,
		_get_runtime_state_object(runtime_state, "_active_unlock_flight"),
		build_state_callbacks(runtime_state),
		perf_logger
	)


func finish_choice_flight_effect(
	choice_flight_effect: Dictionary,
	owner: Object,
	registry: Object,
	active_unlock_flight: Object,
	callbacks: Dictionary,
	perf_logger: Object = null
) -> Dictionary:
	if active_unlock_flight == null:
		return {"accepted": false, "blocked_reason": "missing_active_unlock_flight"}
	var sample_start: int = _perf_begin(perf_logger)
	var effect: Dictionary = active_unlock_flight.consume_effect(choice_flight_effect)
	_perf_end(perf_logger, "process.runtime_perk.flight.capture", sample_start)
	var landing_payload: Dictionary = active_unlock_flight.build_landing_payload(effect)
	if not bool(landing_payload.get("accepted", false)):
		return landing_payload
	var choice: Dictionary = _get_dict(landing_payload.get("choice", {}))
	var choice_id: String = str(landing_payload.get("choice_id", choice.get("id", "")))
	sample_start = _perf_begin(perf_logger)
	var applied: bool = _call_bool(
		callbacks,
		CALLBACK_APPLY_CHOICE,
		[choice, owner, registry, perf_logger],
		false
	)
	_perf_end(perf_logger, "process.runtime_perk.flight.apply_choice", sample_start)
	if not applied:
		_call_optional(callbacks, CALLBACK_APPLY_CHOICE_FAILURE_FEEDBACK, [])
		return {
			"accepted": false,
			"choice_id": choice_id,
			"blocked_reason": "choice_apply_failed",
		}
	sample_start = _perf_begin(perf_logger)
	_call_optional(
		callbacks,
		CALLBACK_FINISH_OR_OPEN_UNLOCK_SHOWCASE,
		[choice_id, owner, registry, perf_logger, choice]
	)
	_perf_end(perf_logger, "process.runtime_perk.flight.finish_success", sample_start)
	return {
		"accepted": true,
		"choice_id": choice_id,
		"applied": true,
	}


func _with_choice_result(result: Dictionary, choice_id: String) -> Dictionary:
	var copy: Dictionary = result.duplicate(true)
	if not copy.has("choice_id"):
		copy["choice_id"] = choice_id
	return copy


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


func _call_bool(callbacks: Dictionary, key: String, args: Array, fallback: bool = false) -> bool:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return fallback
	return bool(callback.callv(args))


func _call_array(callbacks: Dictionary, key: String, args: Array) -> Array:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return []
	var result: Variant = callback.callv(args)
	if result is Array:
		return result
	return []


func _get_callback(callbacks: Dictionary, key: String) -> Callable:
	var value: Variant = callbacks.get(key, Callable())
	if value is Callable:
		return value
	return Callable()


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


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


func _get_runtime_state_array(runtime_state: Object, key: String) -> Array:
	if runtime_state == null:
		return []
	var value: Variant = runtime_state.get(key)
	if value is Array:
		return value
	return []


func _get_runtime_state_dict(runtime_state: Object, key: String) -> Dictionary:
	if runtime_state == null:
		return {}
	return _get_dict(runtime_state.get(key))


func _get_runtime_state_int(runtime_state: Object, key: String) -> int:
	if runtime_state == null:
		return 0
	return int(runtime_state.get(key))
