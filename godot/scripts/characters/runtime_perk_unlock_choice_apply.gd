extends RefCounted

const CALLBACK_GET_INSTANCE := "get_instance"
const CALLBACK_APPLY_UNLOCK_SWAP_STATE_UPDATE := "apply_unlock_swap_state_update"
const CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS := "sync_runtime_perk_owner_effects"
const CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT := "apply_choice_feedback_result"


func build_state_callbacks(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {}
	return {
		CALLBACK_GET_INSTANCE: Callable(runtime_state, "_get_instance"),
		CALLBACK_APPLY_UNLOCK_SWAP_STATE_UPDATE: Callable(runtime_state, "_apply_unlock_swap_state_update"),
		CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS: Callable(runtime_state, "_sync_runtime_perk_owner_effects"),
		CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT: Callable(runtime_state, "_apply_choice_feedback_result"),
	}


func apply_choice_from_runtime_state(
	runtime_state: Object,
	choice: Dictionary,
	owner: Object,
	registry: Object,
	perf_logger: Object = null
) -> Dictionary:
	return apply_choice(
		choice,
		owner,
		registry,
		_get_runtime_state_dict(runtime_state, "runtime_skill_levels"),
		_get_runtime_state_object(runtime_state, "_character_context"),
		_get_runtime_state_object(runtime_state, "_unlock_swap_flow"),
		_get_runtime_state_object(runtime_state, "_level_side_effects"),
		build_state_callbacks(runtime_state),
		perf_logger
	)


func apply_choice(
	choice: Dictionary,
	owner: Object,
	registry: Object,
	runtime_skill_levels: Dictionary,
	character_context: Object,
	unlock_swap_flow: Object,
	level_side_effects: Object,
	callbacks: Dictionary,
	perf_logger: Object = null
) -> Dictionary:
	var choice_id: String = str(choice.get("id", ""))
	var unlocked_skill: String = str(choice.get("unlocks_skill", ""))
	if choice_id == "" or unlocked_skill == "":
		return {"accepted": false, "blocked_reason": "missing_unlock_choice", "choice_id": choice_id}
	var character_type: String = str(choice.get("character_restriction", _get_owner_character_type(character_context, owner)))
	var skill_config: Object = _call_object(
		callbacks,
		CALLBACK_GET_INSTANCE,
		[registry, _get_skill_config_key(character_context, character_type)]
	)
	if skill_config == null or not skill_config.has_method("unlock_and_equip_skill"):
		return {"accepted": false, "blocked_reason": "missing_skill_config", "choice_id": choice_id}
	if _should_start_unlock_swap(unlock_swap_flow, skill_config, unlocked_skill, character_type):
		return _start_pending_unlock_swap(choice, skill_config, owner, unlock_swap_flow, callbacks)

	var sample_start: int = _perf_begin(perf_logger)
	if not bool(skill_config.unlock_and_equip_skill(unlocked_skill)):
		_perf_end(perf_logger, "process.runtime_perk.unlock.equip", sample_start)
		return {"accepted": false, "blocked_reason": "unlock_equip_failed", "choice_id": choice_id}
	_perf_end(perf_logger, "process.runtime_perk.unlock.equip", sample_start)

	var unlock_update: Dictionary = _commit_unlock_choice_level(level_side_effects, choice, runtime_skill_levels)
	if not bool(unlock_update.get("accepted", false)):
		return unlock_update

	sample_start = _perf_begin(perf_logger)
	var owner_sync_result: Dictionary = _call_optional(
		callbacks,
		CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS,
		[owner, registry, perf_logger]
	)
	_perf_end(perf_logger, "process.runtime_perk.unlock.sync_owner_effects", sample_start)
	if not bool(owner_sync_result.get("accepted", false)):
		return owner_sync_result

	sample_start = _perf_begin(perf_logger)
	if unlock_swap_flow != null and unlock_swap_flow.has_method("sync_commando_weapon_controller"):
		unlock_swap_flow.sync_commando_weapon_controller(
			unlocked_skill,
			skill_config,
			registry,
			character_type,
			_get_callback(callbacks, CALLBACK_GET_INSTANCE)
		)
	_perf_end(perf_logger, "process.runtime_perk.unlock.commando_sync", sample_start)

	var feedback_result: Dictionary = _call_bool(
		callbacks,
		CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT,
		[unlock_update, choice, _get_level_feedback_timer(level_side_effects)]
	)
	if not bool(feedback_result.get("accepted", false)):
		return feedback_result
	return {
		"accepted": true,
		"choice_id": choice_id,
		"unlocked_skill": unlocked_skill,
	}


func _should_start_unlock_swap(
	unlock_swap_flow: Object,
	skill_config: Object,
	unlocked_skill: String,
	character_type: String
) -> bool:
	if unlock_swap_flow == null or not unlock_swap_flow.has_method("should_start_swap"):
		return false
	return bool(unlock_swap_flow.should_start_swap(skill_config, unlocked_skill, character_type))


func _start_pending_unlock_swap(
	choice: Dictionary,
	skill_config: Object,
	owner: Object,
	unlock_swap_flow: Object,
	callbacks: Dictionary
) -> Dictionary:
	if unlock_swap_flow == null:
		return {"accepted": false, "blocked_reason": "missing_unlock_swap_flow"}
	var swap: Dictionary = unlock_swap_flow.build_pending_swap(choice, skill_config) if unlock_swap_flow.has_method("build_pending_swap") else {}
	if swap.is_empty():
		return {"accepted": false, "blocked_reason": "empty_pending_swap"}
	var update: Dictionary = unlock_swap_flow.build_start_state_update(swap) if unlock_swap_flow.has_method("build_start_state_update") else {"accepted": false}
	var apply_result: Dictionary = _call_bool(callbacks, CALLBACK_APPLY_UNLOCK_SWAP_STATE_UPDATE, [update, owner])
	if not bool(apply_result.get("accepted", false)):
		return apply_result
	return {
		"accepted": false,
		"pending_swap_started": true,
	}


func _commit_unlock_choice_level(level_side_effects: Object, choice: Dictionary, runtime_skill_levels: Dictionary) -> Dictionary:
	if level_side_effects == null or not level_side_effects.has_method("commit_unlock_choice_level"):
		return {"accepted": false, "blocked_reason": "missing_level_side_effects"}
	var result: Variant = level_side_effects.commit_unlock_choice_level(choice, runtime_skill_levels)
	if result is Dictionary:
		return result
	return {"accepted": bool(result)}


func _get_owner_character_type(character_context: Object, owner: Object) -> String:
	if character_context != null and character_context.has_method("get_owner_character_type"):
		return str(character_context.get_owner_character_type(owner))
	return "smasher"


func _get_skill_config_key(character_context: Object, character_type: String) -> String:
	if character_context != null and character_context.has_method("get_skill_config_key"):
		return str(character_context.get_skill_config_key(character_type))
	return "smasher_skill_config"


func _get_level_feedback_timer(level_side_effects: Object) -> float:
	if level_side_effects == null:
		return 1.1
	var value: Variant = level_side_effects.get("LEVEL_FEEDBACK_TIMER")
	if value == null:
		return 1.1
	return float(value)


func _call_bool(callbacks: Dictionary, key: String, args: Array) -> Dictionary:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return {"accepted": false, "blocked_reason": "missing_%s" % key}
	var result: Variant = callback.callv(args)
	if result is Dictionary:
		if result.has("accepted"):
			return result
		result["accepted"] = true
		return result
	return {"accepted": bool(result)}


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
	var value: Variant = runtime_state.get(key)
	if value is Dictionary:
		return value
	return {}
