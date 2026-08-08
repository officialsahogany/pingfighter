extends RefCounted

const RuntimePerkCallbackMap := preload("res://scripts/characters/runtime_perk_callback_map.gd")
const RuntimePerkChoiceCompletion := preload("res://scripts/characters/runtime_perk_choice_completion.gd")
const RuntimePerkPayloadAccess := preload("res://scripts/characters/runtime_perk_payload_access.gd")
const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const CALLBACK_GET_CHARACTER_TYPE := "get_character_type"
const CALLBACK_GET_CATALOG := "get_catalog"
const CALLBACK_GET_INSTANCE := "get_instance"
const CALLBACK_HAS_PENDING_UNLOCK_SWAP := "has_pending_unlock_swap"
const CALLBACK_OPEN_NEXT_CHOICE := "open_next_choice"
const CALLBACK_RESUME_SKILL_COOLDOWNS := "resume_skill_cooldowns"
const CALLBACK_TRY_ARM_RESUME_SAFETY := "try_arm_resume_safety"
const CALLBACK_START_STARPOINT_ABSORPTION := "start_starpoint_absorption"
const CALLBACK_SYNC_OWNER := "sync_owner"
const CALLBACK_SHOULD_DEFER_NEXT_CHOICE := "should_defer_next_choice"
const CALLBACK_HAS_POST_CHOICE_BLOCKER := "has_post_choice_blocker"
const CALLBACK_CONTINUE_AFTER_CHOICE := "continue_after_choice"


func build_state_callbacks(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {}
	return {
		CALLBACK_GET_CHARACTER_TYPE: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_get_character_type"
		),
		CALLBACK_GET_CATALOG: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_get_catalog"
		),
		CALLBACK_GET_INSTANCE: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_get_instance"
		),
		CALLBACK_HAS_PENDING_UNLOCK_SWAP: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"has_pending_unlock_swap"
		),
		CALLBACK_OPEN_NEXT_CHOICE: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"open_next_choice"
		),
		CALLBACK_RESUME_SKILL_COOLDOWNS: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_resume_skill_cooldowns_for_choice"
		),
		CALLBACK_TRY_ARM_RESUME_SAFETY: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_try_arm_resume_safety"
		),
		CALLBACK_START_STARPOINT_ABSORPTION: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_start_starpoint_absorption_effect"
		),
		CALLBACK_SYNC_OWNER: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_sync_owner"
		),
		CALLBACK_SHOULD_DEFER_NEXT_CHOICE: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_should_defer_next_choice_for_angel_acquisition"
		),
		CALLBACK_HAS_POST_CHOICE_BLOCKER: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_has_runtime_perk_post_choice_blocker"
		),
		CALLBACK_CONTINUE_AFTER_CHOICE: RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_continue_angel_blessing_after_choice"
		),
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
		RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "runtime_skill_levels"),
		choice,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_completion"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_offer_modifiers"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_feedback"),
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
		RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "current_choice_context")
	)
	var megingjord_extra_pick: bool = _try_megingjord_extra_pick(choice_offer_modifiers, choice_id, owner, registry, callbacks)
	var megingjord_feedback: Dictionary = {}
	if megingjord_extra_pick and choice_feedback != null and choice_feedback.has_method("build_megingjord_extra_pick_feedback"):
		megingjord_feedback = choice_feedback.build_megingjord_extra_pick_feedback(
			RuntimePerkRuntimeStateAccess.get_float(runtime_state, "feedback_timer")
		)
	var state_update: Dictionary = choice_completion.build_success_state_update_for_choice(
		choice_id,
		choice,
		runtime_skill_levels,
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices"),
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "selected_choice_sequence"),
		megingjord_extra_pick,
		megingjord_feedback
	)
	var state_apply_result: Dictionary = choice_completion.apply_success_state_update(runtime_state, state_update, choice_id)
	if not bool(state_apply_result.get("accepted", false)):
		_perf_end(perf_logger, "process.runtime_perk.finish_success.state", sample_start)
		return state_apply_result
	_perf_end(perf_logger, "process.runtime_perk.finish_success.state", sample_start)

	var character_type: String = RuntimePerkCallbackMap.call_string(callbacks, CALLBACK_GET_CHARACTER_TYPE, [owner], "smasher")
	var catalog: Object = RuntimePerkCallbackMap.call_object(callbacks, CALLBACK_GET_CATALOG, [registry])
	var post_state_plan: Dictionary = choice_completion.build_post_state_plan(
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices"),
		catalog != null,
		RuntimePerkCallbackMap.call_bool(callbacks, CALLBACK_HAS_PENDING_UNLOCK_SWAP, [], false),
		RuntimePerkCallbackMap.call_bool(callbacks, CALLBACK_SHOULD_DEFER_NEXT_CHOICE, [], false)
	)
	var post_state_apply_result: Dictionary = choice_completion.apply_post_state_plan(runtime_state, post_state_plan)
	if not bool(post_state_apply_result.get("accepted", false)):
		return post_state_apply_result
	if bool(post_state_apply_result.get("open_next_choice", false)):
		sample_start = _perf_begin(perf_logger)
		RuntimePerkCallbackMap.call_optional(
			callbacks,
			CALLBACK_OPEN_NEXT_CHOICE,
			[character_type, catalog, false, owner, registry, perf_logger, next_choice_context]
		)
		_perf_end(perf_logger, "process.runtime_perk.finish_success.open_next_choice", sample_start)
	var close_plan: Dictionary = choice_completion.build_modal_close_plan(
		RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "choice_active"),
		RuntimePerkCallbackMap.call_bool(callbacks, CALLBACK_HAS_PENDING_UNLOCK_SWAP, [], false),
		RuntimePerkCallbackMap.call_bool(
			callbacks,
			CALLBACK_HAS_POST_CHOICE_BLOCKER,
			[registry],
			false
		)
	)
	for close_step_value in choice_completion.build_modal_close_steps(close_plan):
		var close_step: Dictionary = RuntimePerkPayloadAccess.as_dict(close_step_value)
		sample_start = _perf_begin(perf_logger)
		match str(close_step.get("action", "")):
			RuntimePerkChoiceCompletion.CLOSE_ACTION_RESUME_SKILL_COOLDOWNS:
				RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_RESUME_SKILL_COOLDOWNS, [])
			RuntimePerkChoiceCompletion.CLOSE_ACTION_ARM_RESUME_SAFETY:
				RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_TRY_ARM_RESUME_SAFETY, [owner, registry])
			RuntimePerkChoiceCompletion.CLOSE_ACTION_START_STARPOINT_ABSORPTION:
				RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_START_STARPOINT_ABSORPTION, [owner])
			RuntimePerkChoiceCompletion.CLOSE_ACTION_SYNC_OWNER:
				RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_SYNC_OWNER, [owner])
		_perf_end(perf_logger, str(close_step.get("perf_label", "")), sample_start)
	RuntimePerkCallbackMap.call_optional(
		callbacks,
		CALLBACK_CONTINUE_AFTER_CHOICE,
		[owner, registry]
	)
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
		RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_GET_INSTANCE)
	))


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
