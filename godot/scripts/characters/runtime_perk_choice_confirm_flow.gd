extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const RuntimePerkCallbackMap := preload("res://scripts/characters/runtime_perk_callback_map.gd")

const RuntimePerkPayloadAccess := preload("res://scripts/characters/runtime_perk_payload_access.gd")

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
		CALLBACK_IS_SELECTABLE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "is_selectable"),
		CALLBACK_GET_CARD_RECTS: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "get_card_rects"),
		CALLBACK_APPLY_CHOICE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "apply_choice"),
		CALLBACK_APPLY_CHOICE_FAILURE_FEEDBACK: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_apply_choice_failure_feedback"),
		CALLBACK_PLAY_ACTIVE_UNLOCK_FLIGHT_AUDIO: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_play_active_unlock_flight_audio"),
		CALLBACK_PLAY_PERK_SELECT_AUDIO: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_play_perk_select_audio"),
		CALLBACK_FINISH_OR_OPEN_UNLOCK_SHOWCASE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_finish_or_open_unlock_showcase"),
	}


func choose_selected_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	view_size: Vector2 = Vector2.ZERO,
	perf_logger: Object = null
) -> Dictionary:
	return choose_selected(
		RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices"),
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "selected_index"),
		owner,
		registry,
		view_size,
		runtime_state,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_selection"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_active_unlock_flight"),
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
		RuntimePerkCallbackMap.call_bool(callbacks, CALLBACK_IS_SELECTABLE, [], false)
	)
	if not bool(selection.get("accepted", false)):
		return selection
	var choice: Dictionary = RuntimePerkPayloadAccess.as_dict(selection.get("choice", {}))
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

	var applied: bool = RuntimePerkCallbackMap.call_bool(
		callbacks,
		CALLBACK_APPLY_CHOICE,
		[choice, owner, registry, perf_logger],
		false
	)
	if not applied:
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_APPLY_CHOICE_FAILURE_FEEDBACK, [])
		return {
			"accepted": false,
			"choice_id": choice_id,
			"blocked_reason": "choice_apply_failed",
		}

	RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_PLAY_PERK_SELECT_AUDIO, [registry])
	RuntimePerkCallbackMap.call_optional(
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
		RuntimePerkCallbackMap.call_array(callbacks, CALLBACK_GET_CARD_RECTS, [view_size]),
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
	RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_PLAY_ACTIVE_UNLOCK_FLIGHT_AUDIO, [registry])
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
		RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "choice_flight_effect"),
		delta,
		owner,
		registry,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_active_unlock_flight"),
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
	var choice: Dictionary = RuntimePerkPayloadAccess.as_dict(landing_payload.get("choice", {}))
	var choice_id: String = str(landing_payload.get("choice_id", choice.get("id", "")))
	sample_start = _perf_begin(perf_logger)
	var applied: bool = RuntimePerkCallbackMap.call_bool(
		callbacks,
		CALLBACK_APPLY_CHOICE,
		[choice, owner, registry, perf_logger],
		false
	)
	_perf_end(perf_logger, "process.runtime_perk.flight.apply_choice", sample_start)
	if not applied:
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_APPLY_CHOICE_FAILURE_FEEDBACK, [])
		return {
			"accepted": false,
			"choice_id": choice_id,
			"blocked_reason": "choice_apply_failed",
		}
	sample_start = _perf_begin(perf_logger)
	RuntimePerkCallbackMap.call_optional(
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


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
