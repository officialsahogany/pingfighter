extends RefCounted

const RuntimePerkAngelBlessingState := preload("res://scripts/characters/runtime_perk_angel_blessing_state.gd")
const RuntimePerkAngelBlessingCooldownCapability := preload("res://scripts/characters/runtime_perk_angel_blessing_cooldown_capability.gd")
const RuntimePerkAngelBlessingStageLifecycle := preload("res://scripts/characters/runtime_perk_angel_blessing_stage_lifecycle.gd")
const RuntimePerkAngelBlessingModalFlow := preload("res://scripts/characters/runtime_perk_angel_blessing_modal_flow.gd")
const RuntimePerkAngelBlessingAcquisitionLifecycle := preload("res://scripts/characters/runtime_perk_angel_blessing_acquisition_lifecycle.gd")
const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const PERK_ID := RuntimePerkAngelBlessingState.PERK_ID
const POLICY_CURRENT_STAGE := RuntimePerkAngelBlessingModalFlow.POLICY_CURRENT_STAGE

var _state: Object = RuntimePerkAngelBlessingState.new()
var _cooldown_capability: Object = RuntimePerkAngelBlessingCooldownCapability.new()
var _stage_lifecycle: Object = RuntimePerkAngelBlessingStageLifecycle.new()
var _modal_flow: Object = RuntimePerkAngelBlessingModalFlow.new()
var _acquisition_lifecycle: Object = RuntimePerkAngelBlessingAcquisitionLifecycle.new()


func get_state() -> Object:
	return _state


func get_modal_flow() -> Object:
	return _modal_flow


func roll_for_stage(
	stage: int,
	eligible_buff_ids: Array = [],
	forced_face: int = 0,
	forced_candidate_order: Array = []
) -> Dictionary:
	return _state.roll_for_stage(stage, eligible_buff_ids, forced_face, forced_candidate_order)


func get_eligible_buff_ids(character_type: String, registry: Object) -> Array[String]:
	return _cooldown_capability.get_eligible_buff_ids(_state, character_type, registry)


func get_cooldown_capability(character_type: String, registry: Object) -> Dictionary:
	return _cooldown_capability.get_capability(character_type, registry)


func get_snapshot() -> Dictionary:
	return _state.get_snapshot()


func on_ball_spawn_intro_finished(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	forced_face: int = 0,
	forced_candidate_order: Array = []
) -> Dictionary:
	return _stage_lifecycle.on_ball_spawn_intro_finished(
		runtime_state,
		owner,
		registry,
		forced_face,
		forced_candidate_order
	)


func on_accepted_choice(
	runtime_state: Object,
	choice: Dictionary,
	previous_raw_level: int,
	new_raw_level: int,
	choice_context: Dictionary,
	cinematic_started: bool,
	owner: Object,
	registry: Object
) -> Dictionary:
	return _acquisition_lifecycle.on_accepted_choice(
		runtime_state,
		choice,
		previous_raw_level,
		new_raw_level,
		choice_context,
		cinematic_started,
		owner,
		registry
	)


func on_acquisition_cinematic_finished(runtime_state: Object, perk_id: String) -> Dictionary:
	return _acquisition_lifecycle.on_acquisition_cinematic_finished(runtime_state, perk_id)


func get_acquisition_snapshot() -> Dictionary:
	var snapshot: Dictionary = _modal_flow.get_snapshot()
	snapshot["roll_state"] = get_snapshot()
	return snapshot


func has_visual_work() -> bool:
	return _modal_flow.has_visual_work()


func has_pending_acquisition() -> bool:
	return _modal_flow.has_work()


func is_modal_active() -> bool:
	return _modal_flow.is_modal_active()


func has_modal_work() -> bool:
	if _modal_flow.has_visual_work() or _modal_flow.has_pending_reveals():
		return true
	return _modal_flow.has_ready_current_stage_roll()


func handle_spawn_intro_completion_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	roll_options: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {}
	var forced_order_value: Variant = roll_options.get("forced_candidate_order", [])
	var forced_order: Array = forced_order_value if forced_order_value is Array else []
	var current_stage: int = get_owner_stage_from_runtime_state(runtime_state, owner)
	var acquisition_reservation: Dictionary = _modal_flow.take_ready_roll_for_stage(
		current_stage,
		true
	)
	var roll_result: Dictionary = on_ball_spawn_intro_finished(
		runtime_state,
		owner,
		registry,
		int(roll_options.get("forced_face", 0)),
		forced_order
	)
	if not roll_result.is_empty():
		result["angel_blessing"] = roll_result
	if bool(roll_result.get("rolled", false)):
		var reveal_reason: String = str(acquisition_reservation.get("reason", "stage_intro"))
		result["angel_blessing_reveal"] = _modal_flow.queue_reveal_from_roll_result(
			roll_result,
			reveal_reason
		)
		result["angel_blessing_modal"] = update_acquisition_from_runtime_state(
			runtime_state,
			0.0,
			owner,
			registry,
			{},
			roll_options
		)
	if not acquisition_reservation.is_empty():
		result["angel_blessing_acquisition_reservation"] = acquisition_reservation
	return result


func update_acquisition_from_runtime_state(
	runtime_state: Object,
	delta: float,
	owner: Object,
	registry: Object,
	blockers: Dictionary = {},
	roll_options: Dictionary = {}
) -> Dictionary:
	if runtime_state == null:
		return {"blocked": true, "blocked_reason": "missing_runtime_state"}
	var update_result: Dictionary = _modal_flow.update(delta)
	_play_absorb_cues(runtime_state, registry, update_result)
	if is_modal_active():
		update_result["snapshot"] = get_acquisition_snapshot()
		return update_result
	if is_open_blocked(registry, blockers):
		update_result["blocked"] = true
		update_result["snapshot"] = get_acquisition_snapshot()
		return update_result
	if _is_choice_or_swap_active(runtime_state):
		update_result["blocked"] = true
		update_result["blocked_reason"] = "runtime_perk_choice"
		update_result["snapshot"] = get_acquisition_snapshot()
		return update_result
	if RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices") > 0:
		update_result["choice_resume"] = try_resume_deferred_choices_from_runtime_state(
			runtime_state,
			owner,
			registry
		)
		if _is_choice_or_swap_active(runtime_state):
			update_result["blocked"] = true
			update_result["blocked_reason"] = "runtime_perk_choice"
			update_result["snapshot"] = get_acquisition_snapshot()
			return update_result

	var stage: int = get_owner_stage_from_runtime_state(runtime_state, owner)
	var pending_roll: Dictionary = _modal_flow.take_ready_roll_for_stage(stage, false)
	if not pending_roll.is_empty():
		var roll_result: Dictionary = roll_current_stage_from_runtime_state(
			runtime_state,
			owner,
			registry,
			roll_options
		)
		update_result["pending_roll"] = pending_roll
		update_result["roll_result"] = roll_result
		if bool(roll_result.get("rolled", false)):
			_modal_flow.queue_reveal_from_roll_result(
				roll_result,
				str(pending_roll.get("reason", "first_acquisition"))
			)

	if _modal_flow.has_pending_reveals():
		var begin_result: Dictionary = _modal_flow.begin_next_pending_reveal(stage)
		update_result["begin_result"] = begin_result
		if bool(begin_result.get("started", false)):
			_call_runtime(runtime_state, "_pause_skill_cooldowns_for_choice", [owner, registry])
			var game_audio: Object = _get_runtime_instance(runtime_state, registry, "game_audio")
			if game_audio != null and game_audio.has_method("play_angel_blessing_roll"):
				game_audio.play_angel_blessing_roll()
	update_result["snapshot"] = get_acquisition_snapshot()
	return update_result


func handle_acquisition_input_from_runtime_state(
	runtime_state: Object,
	event: InputEvent,
	owner: Object,
	registry: Object
) -> bool:
	if not is_modal_active():
		return false
	var input_result: Dictionary = _modal_flow.handle_input(event)
	if bool(input_result.get("dismissed", false)):
		finalize_deferred_choice_chain_from_runtime_state(runtime_state, owner, registry, true)
	return bool(input_result.get("consumed", false))


func finish_acquisition_cinematic_from_runtime_state(
	runtime_state: Object,
	perk_id: String,
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	var result: Dictionary = on_acquisition_cinematic_finished(runtime_state, perk_id)
	if bool(result.get("ignored", false)) or perk_id.strip_edges() != PERK_ID:
		return result
	if int(result.get("released", result.get("released_count", 0))) <= 0:
		result["ready_work"] = has_modal_work()
		return result
	if owner == null or registry == null:
		return result
	if (
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices") > 0
		and not _is_choice_or_swap_active(runtime_state)
	):
		result["choice_resume"] = try_resume_deferred_choices_from_runtime_state(
			runtime_state,
			owner,
			registry
		)
		result["opened_next_choice"] = RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "choice_active")
		if _is_choice_or_swap_active(runtime_state):
			return result
	result["angel_update"] = update_acquisition_from_runtime_state(
		runtime_state,
		0.0,
		owner,
		registry
	)
	if not _is_choice_or_swap_active(runtime_state) and not has_modal_work():
		finalize_deferred_choice_chain_from_runtime_state(runtime_state, owner, registry)
	return result


func on_round_boundary_from_runtime_state(runtime_state: Object) -> void:
	var cancel_result: Dictionary = _modal_flow.cancel_active_presentation()
	_modal_flow.reset_for_round_boundary()
	if bool(cancel_result.get("canceled", false)):
		RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "current_choice_context").clear()
		_call_runtime(runtime_state, "_resume_skill_cooldowns_for_choice")


func on_stage_transition_from_runtime_state(runtime_state: Object) -> void:
	var had_discarded_work: bool = has_current_stage_work()
	_modal_flow.reset_for_stage_boundary()
	var cooldown_pause: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_skill_cooldown_pause")
	var cooldown_pause_active: bool = (
		cooldown_pause != null
		and cooldown_pause.has_method("is_active")
		and bool(cooldown_pause.is_active())
	)
	if not _is_choice_or_swap_active(runtime_state) and (had_discarded_work or cooldown_pause_active):
		RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "current_choice_context").clear()
		_call_runtime(runtime_state, "_resume_skill_cooldowns_for_choice")


func should_defer_next_choice() -> bool:
	for pending_value: Variant in _modal_flow.get_snapshot().get("pending_rolls", []):
		if pending_value is Dictionary and bool((pending_value as Dictionary).get("waiting_for_cinematic", false)):
			return true
	return false


func has_post_choice_blocker() -> bool:
	if is_modal_active() or _modal_flow.has_pending_reveals():
		return true
	for pending_value: Variant in _modal_flow.get_snapshot().get("pending_rolls", []):
		if not (pending_value is Dictionary):
			continue
		var pending: Dictionary = pending_value
		if str(pending.get("policy", "")) == POLICY_CURRENT_STAGE or bool(pending.get("waiting_for_cinematic", false)):
			return true
	return false


func has_current_stage_work() -> bool:
	if is_modal_active() or _modal_flow.has_pending_reveals():
		return true
	for pending_value: Variant in _modal_flow.get_snapshot().get("pending_rolls", []):
		if (
			pending_value is Dictionary
			and str((pending_value as Dictionary).get("policy", "")) == POLICY_CURRENT_STAGE
		):
			return true
	return false


func continue_after_choice_from_runtime_state(runtime_state: Object, owner: Object, registry: Object) -> void:
	if (
		RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "choice_active")
		or RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices") > 0
		or should_defer_next_choice()
	):
		return
	update_acquisition_from_runtime_state(runtime_state, 0.0, owner, registry)


func try_resume_deferred_choices_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object
) -> Dictionary:
	var pending_choices: int = RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices")
	if pending_choices <= 0 or _is_choice_or_swap_active(runtime_state):
		return {"opened": false, "pending_skill_choices": pending_choices}
	var catalog: Object = RuntimePerkRuntimeStateAccess.call_object(runtime_state, "_get_catalog", [registry])
	if catalog != null and runtime_state.has_method("open_next_choice"):
		runtime_state.call(
			"open_next_choice",
			RuntimePerkRuntimeStateAccess.call_string(runtime_state, "_get_character_type", [owner]),
			catalog,
			false,
			owner,
			registry,
			null,
			RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "current_choice_context").duplicate(true)
		)
	if not _is_choice_or_swap_active(runtime_state):
		var choice_opening: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_opening")
		while RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices") > 0:
			if choice_opening == null or not choice_opening.has_method("build_empty_choices_state_update"):
				break
			if not runtime_state.has_method("_apply_choice_opening_update"):
				break
			runtime_state.call(
				"_apply_choice_opening_update",
				choice_opening.build_empty_choices_state_update(
					RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices")
				)
			)
	return {
		"opened": RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "choice_active"),
		"pending_skill_choices": RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices"),
		"catalog_available": catalog != null,
	}


func finalize_deferred_choice_chain_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	force_resume_effects: bool = false
) -> void:
	RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "current_choice_context").clear()
	var cooldown_pause: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_skill_cooldown_pause")
	var had_cooldown_pause: bool = (
		cooldown_pause != null
		and cooldown_pause.has_method("is_active")
		and bool(cooldown_pause.is_active())
	)
	if had_cooldown_pause or force_resume_effects:
		_call_runtime(runtime_state, "_resume_skill_cooldowns_for_choice")
		_call_runtime(runtime_state, "_try_arm_resume_safety", [owner, registry])
		_call_runtime(runtime_state, "_start_starpoint_absorption_effect", [owner])
	_call_runtime(runtime_state, "_sync_owner", [owner])


func roll_current_stage_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	roll_options: Dictionary = {}
) -> Dictionary:
	var forced_order_value: Variant = roll_options.get("forced_candidate_order", [])
	var forced_order: Array = forced_order_value if forced_order_value is Array else []
	return on_ball_spawn_intro_finished(
		runtime_state,
		owner,
		registry,
		int(roll_options.get("forced_face", 0)),
		forced_order
	)


func get_owner_stage_from_runtime_state(runtime_state: Object, owner: Object) -> int:
	if owner == null:
		return 0
	var character_context: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_character_context")
	if character_context != null and character_context.has_method("get_current_stage"):
		return max(0, int(character_context.get_current_stage(owner)))
	var stage_value: Variant = owner.get("current_stage")
	return max(0, int(stage_value)) if stage_value != null else 0


func is_open_blocked(registry: Object, blockers: Dictionary) -> bool:
	for blocker_key in [
		"blocked",
		"higher_priority_modal_active",
		"stage_clear_result_active",
		"stage_clear_result_screen_active",
		"mythic_acquisition_active",
		"mythic_acquisition_cinematic_active",
		"scoreboard_active",
		"runtime_perk_choice_active",
	]:
		if bool(blockers.get(blocker_key, false)):
			return true
	var cached_module_getter := Callable()
	if registry != null and registry.has_method("get_cached_instance"):
		cached_module_getter = Callable(registry, "get_cached_instance")
	elif registry != null and registry.has_method("_get_cached_module"):
		cached_module_getter = Callable(registry, "_get_cached_module")
	elif registry != null and registry.has_method("get_instance"):
		cached_module_getter = Callable(registry, "get_instance")
	var shared_modal_gate: Object = _get_cached_blocker_module(registry, "battle_scene_modal_gate_controller")
	if (
		shared_modal_gate != null
		and shared_modal_gate.has_method("should_block_battle_physics")
		and cached_module_getter.is_valid()
		and bool(shared_modal_gate.should_block_battle_physics(cached_module_getter))
	):
		return true
	var result_screen: Object = _get_cached_blocker_module(registry, "stage_clear_result_screen")
	if result_screen != null and result_screen.has_method("is_active") and bool(result_screen.is_active()):
		return true
	var scoreboard_state: Object = _get_cached_blocker_module(registry, "scoreboard_state")
	if scoreboard_state != null and scoreboard_state.has_method("is_active") and bool(scoreboard_state.is_active()):
		return true
	var mythic_runtime: Object = _get_cached_blocker_module(registry, "mythic_item_runtime")
	if mythic_runtime == null:
		return false
	for method_name in [
		"is_acquisition_cinematic_active",
		"is_pandora_legacy_selection_active",
		"is_debug_management_menu_open",
	]:
		if mythic_runtime.has_method(method_name) and bool(mythic_runtime.call(method_name)):
			return true
	return false


func _is_choice_or_swap_active(runtime_state: Object) -> bool:
	return (
		RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "choice_active")
		or RuntimePerkRuntimeStateAccess.call_bool(runtime_state, "has_pending_unlock_swap")
	)


func _play_absorb_cues(runtime_state: Object, registry: Object, update_result: Dictionary) -> void:
	var absorption_value: Variant = update_result.get("absorption", {})
	if not (absorption_value is Dictionary):
		return
	var cues_value: Variant = (absorption_value as Dictionary).get("arrival_cues", [])
	if not (cues_value is Array) or (cues_value as Array).is_empty():
		return
	var game_audio: Object = _get_runtime_instance(runtime_state, registry, "game_audio")
	if game_audio == null or not game_audio.has_method("play_angel_blessing_absorb"):
		return
	for _cue: Variant in cues_value:
		game_audio.play_angel_blessing_absorb()


func _get_runtime_instance(runtime_state: Object, registry: Object, key: String) -> Object:
	return RuntimePerkRuntimeStateAccess.call_object(runtime_state, "_get_instance", [registry, key])


func _get_cached_blocker_module(registry: Object, key: String) -> Object:
	if registry == null or key == "":
		return null
	var value: Variant = null
	if registry.has_method("get_cached_instance"):
		value = registry.call("get_cached_instance", key)
	elif registry.has_method("_get_cached_module"):
		value = registry.call("_get_cached_module", key)
	elif registry.has_method("get_instance"):
		value = registry.call("get_instance", key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _call_runtime(runtime_state: Object, method: String, args: Array = []) -> Variant:
	if runtime_state == null or not runtime_state.has_method(method):
		return null
	return runtime_state.callv(method, args)


func reset_state() -> void:
	_state.reset()
