extends RefCounted

const RuntimePerkChoiceCompletion := preload("res://scripts/characters/runtime_perk_choice_completion.gd")

const CALLBACK_GET_CHARACTER_TYPE := "get_character_type"
const CALLBACK_GET_CATALOG := "get_catalog"
const CALLBACK_GET_INSTANCE := "get_instance"
const CALLBACK_HAS_PENDING_UNLOCK_SWAP := "has_pending_unlock_swap"
const CALLBACK_OPEN_NEXT_CHOICE := "open_next_choice"
const CALLBACK_RESUME_SKILL_COOLDOWNS := "resume_skill_cooldowns"
const CALLBACK_TRY_ARM_RESUME_SAFETY := "try_arm_resume_safety"
const CALLBACK_START_STARPOINT_ABSORPTION := "start_starpoint_absorption"
const CALLBACK_SYNC_OWNER := "sync_owner"


func build_state_callbacks(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {}
	return {
		CALLBACK_GET_CHARACTER_TYPE: Callable(runtime_state, "_get_character_type"),
		CALLBACK_GET_CATALOG: Callable(runtime_state, "_get_catalog"),
		CALLBACK_GET_INSTANCE: Callable(runtime_state, "_get_instance"),
		CALLBACK_HAS_PENDING_UNLOCK_SWAP: Callable(runtime_state, "has_pending_unlock_swap"),
		CALLBACK_OPEN_NEXT_CHOICE: Callable(runtime_state, "open_next_choice"),
		CALLBACK_RESUME_SKILL_COOLDOWNS: Callable(runtime_state, "_resume_skill_cooldowns_for_choice"),
		CALLBACK_TRY_ARM_RESUME_SAFETY: Callable(runtime_state, "_try_arm_resume_safety"),
		CALLBACK_START_STARPOINT_ABSORPTION: Callable(runtime_state, "_start_starpoint_absorption_effect"),
		CALLBACK_SYNC_OWNER: Callable(runtime_state, "_sync_owner"),
	}


func finish_successful_choice_from_runtime_state(
	runtime_state: Object,
	choice_id: String,
	owner: Object,
	registry: Object,
	perf_logger: Object = null,
	choice: Dictionary = {}
) -> Dictionary:
	return finish_successful_choice(
		choice_id,
		owner,
		registry,
		runtime_state,
		_get_runtime_state_dict(runtime_state, "runtime_skill_levels"),
		choice,
		_get_runtime_state_object(runtime_state, "_choice_completion"),
		_get_runtime_state_object(runtime_state, "_choice_offer_modifiers"),
		_get_runtime_state_object(runtime_state, "_choice_feedback"),
		build_state_callbacks(runtime_state),
		perf_logger
	)


func finish_successful_choice(
	choice_id: String,
	owner: Object,
	registry: Object,
	runtime_state: Object,
	runtime_skill_levels: Dictionary,
	choice: Dictionary,
	choice_completion: Object,
	choice_offer_modifiers: Object,
	choice_feedback: Object,
	callbacks: Dictionary,
	perf_logger: Object = null
) -> Dictionary:
	if runtime_state == null or choice_completion == null:
		return {"accepted": false, "blocked_reason": "missing_finish_flow_deps"}
	var sample_start: int = _perf_begin(perf_logger)
	var next_choice_context: Dictionary = choice_completion.build_next_choice_context(
		_get_dict(runtime_state.get("current_choice_context"))
	)
	var megingjord_extra_pick: bool = _try_megingjord_extra_pick(choice_offer_modifiers, choice_id, owner, registry, callbacks)
	var megingjord_feedback: Dictionary = {}
	if megingjord_extra_pick and choice_feedback != null and choice_feedback.has_method("build_megingjord_extra_pick_feedback"):
		megingjord_feedback = choice_feedback.build_megingjord_extra_pick_feedback(float(runtime_state.get("feedback_timer")))
	var state_update: Dictionary = choice_completion.build_success_state_update_for_choice(
		choice_id,
		choice,
		runtime_skill_levels,
		int(runtime_state.get("pending_skill_choices")),
		int(runtime_state.get("selected_choice_sequence")),
		megingjord_extra_pick,
		megingjord_feedback
	)
	var state_apply_result: Dictionary = choice_completion.apply_success_state_update(runtime_state, state_update, choice_id)
	if not bool(state_apply_result.get("accepted", false)):
		_perf_end(perf_logger, "process.runtime_perk.finish_success.state", sample_start)
		return state_apply_result
	_perf_end(perf_logger, "process.runtime_perk.finish_success.state", sample_start)

	var character_type: String = _call_string(callbacks, CALLBACK_GET_CHARACTER_TYPE, [owner], "smasher")
	var catalog: Object = _call_object(callbacks, CALLBACK_GET_CATALOG, [registry])
	var post_state_plan: Dictionary = choice_completion.build_post_state_plan(
		int(runtime_state.get("pending_skill_choices")),
		catalog != null,
		_call_bool(callbacks, CALLBACK_HAS_PENDING_UNLOCK_SWAP, [], false)
	)
	var post_state_apply_result: Dictionary = choice_completion.apply_post_state_plan(runtime_state, post_state_plan)
	if not bool(post_state_apply_result.get("accepted", false)):
		return post_state_apply_result
	if bool(post_state_apply_result.get("open_next_choice", false)):
		sample_start = _perf_begin(perf_logger)
		_call_optional(
			callbacks,
			CALLBACK_OPEN_NEXT_CHOICE,
			[character_type, catalog, false, owner, registry, perf_logger, next_choice_context]
		)
		_perf_end(perf_logger, "process.runtime_perk.finish_success.open_next_choice", sample_start)
	var close_plan: Dictionary = choice_completion.build_modal_close_plan(
		bool(runtime_state.get("choice_active")),
		_call_bool(callbacks, CALLBACK_HAS_PENDING_UNLOCK_SWAP, [], false)
	)
	for close_step_value in choice_completion.build_modal_close_steps(close_plan):
		var close_step: Dictionary = _get_dict(close_step_value)
		sample_start = _perf_begin(perf_logger)
		match str(close_step.get("action", "")):
			RuntimePerkChoiceCompletion.CLOSE_ACTION_RESUME_SKILL_COOLDOWNS:
				_call_optional(callbacks, CALLBACK_RESUME_SKILL_COOLDOWNS, [])
			RuntimePerkChoiceCompletion.CLOSE_ACTION_ARM_RESUME_SAFETY:
				_call_optional(callbacks, CALLBACK_TRY_ARM_RESUME_SAFETY, [owner, registry])
			RuntimePerkChoiceCompletion.CLOSE_ACTION_START_STARPOINT_ABSORPTION:
				_call_optional(callbacks, CALLBACK_START_STARPOINT_ABSORPTION, [owner])
			RuntimePerkChoiceCompletion.CLOSE_ACTION_SYNC_OWNER:
				_call_optional(callbacks, CALLBACK_SYNC_OWNER, [owner])
		_perf_end(perf_logger, str(close_step.get("perf_label", "")), sample_start)
	return {
		"accepted": true,
		"choice_id": choice_id,
		"opened_next_choice": bool(post_state_apply_result.get("open_next_choice", false)),
	}


func _try_megingjord_extra_pick(
	choice_offer_modifiers: Object,
	choice_id: String,
	owner: Object,
	registry: Object,
	callbacks: Dictionary
) -> bool:
	if choice_offer_modifiers == null or not choice_offer_modifiers.has_method("try_megingjord_extra_pick"):
		return false
	return bool(choice_offer_modifiers.try_megingjord_extra_pick(
		choice_id,
		owner,
		registry,
		_get_callback(callbacks, CALLBACK_GET_INSTANCE)
	))


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


func _call_string(callbacks: Dictionary, key: String, args: Array, fallback: String = "") -> String:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return fallback
	return str(callback.callv(args))


func _call_object(callbacks: Dictionary, key: String, args: Array) -> Object:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return null
	var result: Variant = callback.callv(args)
	return result as Object


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


func _get_runtime_state_dict(runtime_state: Object, key: String) -> Dictionary:
	if runtime_state == null:
		return {}
	return _get_dict(runtime_state.get(key))
