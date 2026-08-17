extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const RuntimePerkCallbackMap := preload("res://scripts/characters/runtime_perk_callback_map.gd")

const RuntimePerkPayloadAccess := preload("res://scripts/characters/runtime_perk_payload_access.gd")

const MythicPerkGrantHelper := preload("res://scripts/characters/mythic_perk_grant_helper.gd")
const RuntimePerkChoiceStandardPath := preload("res://scripts/characters/runtime_perk_choice_standard_path.gd")
const RuntimePerkLevelSideEffects := preload("res://scripts/characters/runtime_perk_level_side_effects.gd")

const CALLBACK_SHOULD_DEFER_FULL_GAUGE := "should_defer_full_gauge"
const CALLBACK_SHOULD_DEFER_DIMENSION_GATE := "should_defer_dimension_gate"
const CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT := "apply_choice_feedback_result"
const CALLBACK_APPLY_UNLOCK_CHOICE := "apply_unlock_choice"
const CALLBACK_APPLY_LEVEL_SIDE_EFFECT := "apply_level_side_effect"
const DEFAULT_STARPOINT_PER_SKILL_CHOICE := 1


func build_state_callbacks(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {}
	return {
		CALLBACK_SHOULD_DEFER_FULL_GAUGE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_should_defer_full_gauge_until_spawn_intro_end"),
		CALLBACK_SHOULD_DEFER_DIMENSION_GATE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_should_defer_dimension_gate_until_spawn_intro_end"),
		CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_apply_choice_feedback_result"),
		CALLBACK_APPLY_UNLOCK_CHOICE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_apply_unlock_choice"),
		CALLBACK_APPLY_LEVEL_SIDE_EFFECT: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_apply_level_side_effect"),
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
		runtime_state,
		RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "runtime_skill_levels"),
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices"),
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "starpoint_for_skills"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_dispatch"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_action_runner"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_standard_path"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_instant_rewards"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_level_side_effects"),
		DEFAULT_STARPOINT_PER_SKILL_CHOICE,
		build_state_callbacks(runtime_state),
		perf_logger
	)


func apply_choice(
	choice: Dictionary,
	owner: Object,
	registry: Object,
	runtime_state: Object,
	runtime_skill_levels: Dictionary,
	pending_skill_choices: int,
	starpoint_for_skills: int,
	choice_dispatch: Object,
	choice_action_runner: Object,
	choice_standard_path: Object,
	instant_rewards: Object,
	level_side_effects: Object,
	starpoint_per_skill_choice: int,
	callbacks: Dictionary,
	perf_logger: Object = null
) -> Dictionary:
	if runtime_state == null or choice_dispatch == null or choice_action_runner == null or choice_standard_path == null:
		return {"accepted": false, "blocked_reason": "missing_apply_flow_deps"}
	var dispatch: Dictionary = choice_dispatch.build_dispatch(
		choice,
		RuntimePerkCallbackMap.call_bool(callbacks, CALLBACK_SHOULD_DEFER_FULL_GAUGE, [], false),
		RuntimePerkCallbackMap.call_bool(callbacks, CALLBACK_SHOULD_DEFER_DIMENSION_GATE, [], false)
	)
	if not bool(dispatch.get("accepted", false)):
		return dispatch
	var choice_id: String = str(dispatch.get("choice_id", choice.get("id", "")))
	var action_result: Dictionary = choice_action_runner.run_dispatch(
		dispatch,
		choice,
		owner,
		registry,
		choice_action_runner.build_state_action_callbacks(runtime_state)
	)
	var handled_action_result: Dictionary = choice_action_runner.apply_handled_result(
		action_result,
		choice,
		RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT)
	)
	if bool(handled_action_result.get("handled", false)):
		return _with_mythic_acquisition_cinematic({
			"accepted": bool(handled_action_result.get("accepted", false)),
			"handled": true,
			"choice_id": choice_id,
		}, choice, choice_id, owner, registry)

	var standard_path: Dictionary = choice_standard_path.build_path_from_bookkeeping_choice(
		choice,
		pending_skill_choices,
		starpoint_for_skills,
		starpoint_per_skill_choice,
		Callable(instant_rewards, "apply_bookkeeping_choice") if instant_rewards != null else Callable(),
		Callable(instant_rewards, "build_bookkeeping_state_update") if instant_rewards != null else Callable()
	)
	if not bool(standard_path.get("accepted", false)):
		return standard_path
	var path: String = str(standard_path.get("path", RuntimePerkChoiceStandardPath.PATH_LEVEL))
	if path == RuntimePerkChoiceStandardPath.PATH_BOOKKEEPING:
		var bookkeeping_result: Dictionary = choice_standard_path.apply_bookkeeping_path_to_runtime_state(
			standard_path,
			runtime_state,
			runtime_skill_levels,
			pending_skill_choices,
			starpoint_for_skills,
			choice,
			RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT)
		)
		return _with_choice_id(bookkeeping_result, choice_id)

	if path == RuntimePerkChoiceStandardPath.PATH_UNLOCK:
		var unlock_start: int = _perf_begin(perf_logger)
		var unlock_applied: bool = RuntimePerkCallbackMap.call_bool(
			callbacks,
			CALLBACK_APPLY_UNLOCK_CHOICE,
			[choice, owner, registry, perf_logger],
			false
		)
		_perf_end(perf_logger, "process.runtime_perk.apply.unlock", unlock_start)
		return _with_mythic_acquisition_cinematic({
			"accepted": unlock_applied,
			"choice_id": choice_id,
			"path": path,
		}, choice, choice_id, owner, registry)

	var level_state_result: Dictionary = choice_standard_path.apply_level_choice_to_runtime_state(
		choice,
		choice_id,
		runtime_state,
		runtime_skill_levels,
		pending_skill_choices,
		starpoint_for_skills,
		Callable(level_side_effects, "build_level_choice_update") if level_side_effects != null else Callable()
	)
	if not bool(level_state_result.get("accepted", false)):
		return _with_choice_id(level_state_result, choice_id)
	var level_start: int = _perf_begin(perf_logger)
	RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_APPLY_LEVEL_SIDE_EFFECT, [choice, owner, registry, perf_logger])
	_perf_end(perf_logger, "process.runtime_perk.apply.level_side_effect", level_start)
	var level_feedback_result: Dictionary = choice_standard_path.apply_level_feedback_result(
		level_state_result,
		choice,
		RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT),
		RuntimePerkLevelSideEffects.LEVEL_FEEDBACK_TIMER
	)
	return _with_mythic_acquisition_cinematic(
		_with_choice_id(level_feedback_result, choice_id),
		choice,
		choice_id,
		owner,
		registry
	)


func _with_choice_id(result: Dictionary, choice_id: String) -> Dictionary:
	var copy: Dictionary = result.duplicate(true)
	if not copy.has("choice_id"):
		copy["choice_id"] = choice_id
	return copy


func _with_mythic_acquisition_cinematic(
	result: Dictionary,
	choice: Dictionary,
	choice_id: String,
	owner: Object,
	registry: Object
) -> Dictionary:
	var copy: Dictionary = _with_choice_id(result, choice_id)
	if (
		bool(copy.get("accepted", false))
		and _is_mythic_choice(choice)
		and choice_id.strip_edges() != ""
	):
		copy["mythic_acquisition_cinematic_started"] = MythicPerkGrantHelper.try_start_acquisition_cinematic(
			choice_id,
			owner,
			registry,
			RuntimePerkPayloadAccess.as_vector2(choice.get("pickup_position", Vector2(380.0, 375.0)), Vector2(380.0, 375.0)),
			RuntimePerkPayloadAccess.as_vector2(choice.get("target_player_center", Vector2.INF), Vector2.INF),
			choice
		)
	return copy


func _is_mythic_choice(choice: Dictionary) -> bool:
	return str(choice.get("rarity", "")).to_lower() == "mythic"


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
