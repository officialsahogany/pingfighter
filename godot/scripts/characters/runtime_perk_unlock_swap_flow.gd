extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const RuntimePerkCallbackMap := preload("res://scripts/characters/runtime_perk_callback_map.gd")

const RuntimePerkPayloadAccess := preload("res://scripts/characters/runtime_perk_payload_access.gd")

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const RuntimePerkSoulSummonArt := preload("res://scripts/characters/runtime_perk_soul_summon_art.gd")

const SWAP_CANCEL_FEEDBACK_TEXT := "교체 취소"
const SWAP_CANCEL_FEEDBACK_TIMER := 0.8
const SWAP_COMPLETE_FEEDBACK_TEMPLATE := "%s 교체 완료"
const SWAP_COMPLETE_FEEDBACK_TIMER := 1.1

const CALLBACK_APPLY_UNLOCK_SWAP_STATE_UPDATE := "apply_unlock_swap_state_update"
const CALLBACK_GET_INSTANCE := "get_instance"
const CALLBACK_GET_SKILL_CONFIG_KEY := "get_skill_config_key"
const CALLBACK_COMMIT_UNLOCK_CHOICE_LEVEL := "commit_unlock_choice_level"
const CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS := "sync_runtime_perk_owner_effects"
const CALLBACK_FINISH_OR_OPEN_UNLOCK_SHOWCASE := "finish_or_open_unlock_showcase"


func build_confirm_callbacks(runtime_state: Object, level_side_effects: Object) -> Dictionary:
	var commit_callback := Callable()
	if level_side_effects != null:
		commit_callback = Callable(level_side_effects, "commit_unlock_choice_level")
	if runtime_state == null:
		return {
			CALLBACK_COMMIT_UNLOCK_CHOICE_LEVEL: commit_callback,
		}
	return {
		CALLBACK_APPLY_UNLOCK_SWAP_STATE_UPDATE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_apply_unlock_swap_state_update"),
		CALLBACK_GET_INSTANCE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_get_instance"),
		CALLBACK_GET_SKILL_CONFIG_KEY: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_get_skill_config_key"),
		CALLBACK_COMMIT_UNLOCK_CHOICE_LEVEL: commit_callback,
		CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_sync_runtime_perk_owner_effects"),
		CALLBACK_FINISH_OR_OPEN_UNLOCK_SHOWCASE: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_finish_or_open_unlock_showcase"),
	}


func build_confirm_callbacks_from_runtime_state(runtime_state: Object) -> Dictionary:
	return build_confirm_callbacks(
		runtime_state,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_level_side_effects")
	)


func confirm_pending_swap_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	level_side_effects: Object = null
) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false, "blocked_reason": "missing_runtime_state"}
	var pending_swap: Dictionary = RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "pending_unlock_swap")
	if not has_pending_swap(pending_swap):
		return {"accepted": false, "blocked_reason": "missing_pending_swap"}
	var confirm_callbacks: Dictionary = build_confirm_callbacks(runtime_state, level_side_effects)
	if level_side_effects == null:
		confirm_callbacks = build_confirm_callbacks_from_runtime_state(runtime_state)
	return confirm_pending_swap(
		pending_swap,
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "unlock_swap_selected_index"),
		RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "runtime_skill_levels"),
		owner,
		registry,
		RuntimePerkRuntimeStateAccess.call_object(runtime_state, "_get_catalog", [registry]),
		RuntimePerkRuntimeStateAccess.call_string(runtime_state, "_get_character_type", [owner], "smasher"),
		confirm_callbacks
	)


func cancel_pending_swap_from_runtime_state(runtime_state: Object, owner: Object = null) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false, "blocked_reason": "missing_runtime_state"}
	var pending_swap: Dictionary = RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "pending_unlock_swap")
	if not has_pending_swap(pending_swap):
		return {"accepted": false, "blocked_reason": "missing_pending_swap"}
	return apply_state_update_and_sync_owner_from_runtime_state(
		runtime_state,
		build_cancel_state_update(),
		owner
	)


func should_start_swap(skill_config: Object, unlocked_skill: String, _character_type: String) -> bool:
	if skill_config == null:
		return false
	# The common art can occupy every character's shared five-orb budget. Once it
	# is present, a later character unlock must be allowed to replace it too;
	# otherwise the common slot silently turns the final authored unlock into a
	# dead card. Config-owned candidate surfaces keep this generic gate fail-closed.
	if skill_config.has_method("is_skill_equipped") and bool(skill_config.is_skill_equipped(unlocked_skill)):
		return false
	if skill_config.has_method("is_shared_slot_full") and not bool(skill_config.is_shared_slot_full()):
		return false
	if skill_config.has_method("get_shared_slot_swap_candidates"):
		return not RuntimePerkPayloadAccess.as_array(skill_config.get_shared_slot_swap_candidates(unlocked_skill)).is_empty()
	return false


func build_pending_swap(choice: Dictionary, skill_config: Object) -> Dictionary:
	if skill_config == null:
		return {}
	var unlocked_skill: String = str(choice.get("unlocks_skill", ""))
	var candidates: Array = []
	var raw_candidates: Array = []
	if skill_config.has_method("get_shared_slot_swap_candidates"):
		raw_candidates = RuntimePerkPayloadAccess.as_array(skill_config.get_shared_slot_swap_candidates(unlocked_skill))
	for value in raw_candidates:
		var skill_id := str(value)
		var skill_data: Dictionary = skill_config.get_skill_data(skill_id) if skill_config.has_method("get_skill_data") else {}
		candidates.append({
			"skill_id": skill_id,
			"name": str(skill_data.get("korean", skill_id)),
		})
	if candidates.is_empty():
		return {}
	var new_skill_data: Dictionary = skill_config.get_skill_data(unlocked_skill) if skill_config.has_method("get_skill_data") else {}
	return {
		"choice": choice.duplicate(true),
		"choice_id": str(choice.get("id", "")),
		"unlocks_skill": unlocked_skill,
		"new_name": str(new_skill_data.get("korean", choice.get("name", unlocked_skill))),
		"candidates": candidates,
	}


func has_pending_swap(pending_swap: Dictionary) -> bool:
	return not pending_swap.is_empty()


func has_pending_swap_from_runtime_state(runtime_state: Object) -> bool:
	return has_pending_swap(RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "pending_unlock_swap"))


func get_pending_swap_snapshot(pending_swap: Dictionary) -> Dictionary:
	return pending_swap.duplicate(true)


func get_pending_swap_snapshot_from_runtime_state(runtime_state: Object) -> Dictionary:
	return get_pending_swap_snapshot(RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "pending_unlock_swap"))


func get_selected_index(selected_index: int) -> int:
	return selected_index


func get_selected_index_from_runtime_state(runtime_state: Object) -> int:
	return get_selected_index(RuntimePerkRuntimeStateAccess.get_int(runtime_state, "unlock_swap_selected_index"))


func get_candidate_count(pending_swap: Dictionary) -> int:
	return RuntimePerkPayloadAccess.as_array(pending_swap.get("candidates", [])).size()


func has_candidates(pending_swap: Dictionary) -> bool:
	return get_candidate_count(pending_swap) > 0


func build_start_state_update(swap: Dictionary) -> Dictionary:
	if swap.is_empty():
		return {"accepted": false}
	return {
		"accepted": true,
		"pending_unlock_swap": swap.duplicate(true),
		"unlock_swap_selected_index": 0,
		"gamepad_unlock_swap_horizontal_latch": 0,
		"sync_owner": true,
	}


func build_cancel_state_update() -> Dictionary:
	return {
		"accepted": true,
		"clear_pending_unlock_swap": true,
		"unlock_swap_selected_index": 0,
		"gamepad_unlock_swap_horizontal_latch": 0,
		"clear_current_choice_context": true,
		"feedback_result": build_cancel_feedback(),
		"sync_owner": true,
	}


func build_confirm_state_update(choice: Dictionary, choice_id: String = "") -> Dictionary:
	return {
		"accepted": true,
		"clear_pending_unlock_swap": true,
		"unlock_swap_selected_index": 0,
		"gamepad_unlock_swap_horizontal_latch": 0,
		"feedback_result": build_confirm_feedback(choice, choice_id),
	}


func build_move_selection_state_update(current_index: int, delta_index: int, candidate_count: int) -> Dictionary:
	var safe_count: int = max(0, candidate_count)
	if safe_count <= 0:
		return {"accepted": false, "blocked_reason": "empty_candidates"}
	return {
		"accepted": true,
		"unlock_swap_selected_index": posmod(current_index + delta_index, safe_count),
	}


func build_move_selection_for_pending_swap(
	pending_swap: Dictionary,
	current_index: int,
	delta_index: int
) -> Dictionary:
	return build_move_selection_state_update(current_index, delta_index, get_candidate_count(pending_swap))


func move_selection_from_runtime_state(runtime_state: Object, delta_index: int) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false, "blocked_reason": "missing_runtime_state"}
	return apply_state_update_and_sync_owner_from_runtime_state(
		runtime_state,
		build_move_selection_for_pending_swap(
			RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "pending_unlock_swap"),
			RuntimePerkRuntimeStateAccess.get_int(runtime_state, "unlock_swap_selected_index"),
			delta_index
		)
	)


func build_direct_selection_state_update(index: int, candidate_count: int) -> Dictionary:
	var safe_count: int = max(0, candidate_count)
	if safe_count <= 0:
		return {"accepted": false, "blocked_reason": "empty_candidates"}
	if index < 0 or index >= safe_count:
		return {"accepted": false, "blocked_reason": "out_of_range"}
	return {
		"accepted": true,
		"unlock_swap_selected_index": index,
	}


func build_direct_selection_for_pending_swap(pending_swap: Dictionary, index: int) -> Dictionary:
	return build_direct_selection_state_update(index, get_candidate_count(pending_swap))


func select_index_from_runtime_state(runtime_state: Object, index: int) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false, "blocked_reason": "missing_runtime_state"}
	return apply_state_update_and_sync_owner_from_runtime_state(
		runtime_state,
		build_direct_selection_for_pending_swap(
			RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "pending_unlock_swap"),
			index
		)
	)


func build_clamped_selection_state_update(current_index: int, candidate_count: int) -> Dictionary:
	var safe_count: int = max(0, candidate_count)
	if safe_count <= 0:
		return {"accepted": false, "blocked_reason": "empty_candidates"}
	return {
		"accepted": true,
		"unlock_swap_selected_index": clampi(current_index, 0, safe_count - 1),
	}


func build_clamped_selection_for_pending_swap(pending_swap: Dictionary, current_index: int) -> Dictionary:
	return build_clamped_selection_state_update(current_index, get_candidate_count(pending_swap))


func build_confirm_request(
	pending_swap: Dictionary,
	current_index: int,
	fallback_character_type: String = ""
) -> Dictionary:
	var choice: Dictionary = RuntimePerkPayloadAccess.as_dict(pending_swap.get("choice", {}))
	var choice_id: String = str(pending_swap.get("choice_id", choice.get("id", "")))
	var unlocked_skill: String = str(pending_swap.get("unlocks_skill", choice.get("unlocks_skill", "")))
	if choice_id == "":
		return {"accepted": false, "blocked_reason": "missing_choice_id"}
	if unlocked_skill == "":
		return {"accepted": false, "blocked_reason": "missing_unlocked_skill"}
	var selection_update: Dictionary = build_clamped_selection_for_pending_swap(pending_swap, current_index)
	if not bool(selection_update.get("accepted", false)):
		return {
			"accepted": false,
			"blocked_reason": str(selection_update.get("blocked_reason", "invalid_selection")),
			"selection_update": selection_update,
		}
	var character_type: String = str(choice.get("character_restriction", fallback_character_type))
	return {
		"accepted": true,
		"choice": choice,
		"choice_id": choice_id,
		"unlocked_skill": unlocked_skill,
		"character_type": character_type,
		"selected_index": int(selection_update.get("unlock_swap_selected_index", current_index)),
		"selection_update": selection_update,
	}


func apply_confirm_selection_update(
	confirm_request: Dictionary,
	owner: Object,
	apply_unlock_swap_state_update: Callable
) -> Dictionary:
	if not bool(confirm_request.get("accepted", false)):
		return {"accepted": false, "blocked_reason": "invalid_confirm_request"}
	if not apply_unlock_swap_state_update.is_valid():
		return {"accepted": false, "blocked_reason": "missing_state_update_callback"}
	var update: Dictionary = RuntimePerkPayloadAccess.as_dict(confirm_request.get("selection_update", {}))
	if not bool(update.get("accepted", false)):
		return {"accepted": false, "blocked_reason": "missing_selection_update"}
	var apply_result: Variant = apply_unlock_swap_state_update.call(update, owner)
	var state_applied := false
	if apply_result is Dictionary:
		state_applied = bool(apply_result.get("accepted", false))
	else:
		state_applied = bool(apply_result)
	if not state_applied:
		return {
			"accepted": false,
			"blocked_reason": "selection_update_rejected",
			"apply_result": apply_result,
		}
	return {
		"accepted": true,
		"state_applied": true,
		"selected_index": int(update.get("unlock_swap_selected_index", confirm_request.get("selected_index", 0))),
	}


func build_confirm_completion_plan(confirm_request: Dictionary) -> Dictionary:
	if not bool(confirm_request.get("accepted", false)):
		return {"accepted": false, "blocked_reason": "invalid_confirm_request"}
	var choice: Dictionary = RuntimePerkPayloadAccess.as_dict(confirm_request.get("choice", {}))
	var choice_id := str(confirm_request.get("choice_id", choice.get("id", "")))
	if choice_id == "":
		return {"accepted": false, "blocked_reason": "missing_choice_id"}
	return {
		"accepted": true,
		"state_update": build_confirm_state_update(choice, choice_id),
		"showcase_choice_id": choice_id,
		"showcase_choice": choice,
	}


func apply_confirm_completion_and_showcase(
	completion_plan: Dictionary,
	owner: Object,
	registry: Object,
	apply_unlock_swap_state_update: Callable,
	finish_or_open_unlock_showcase: Callable
) -> Dictionary:
	if not bool(completion_plan.get("accepted", false)):
		return {"accepted": false, "blocked_reason": "invalid_completion_plan"}
	if not apply_unlock_swap_state_update.is_valid():
		return {"accepted": false, "blocked_reason": "missing_state_update_callback"}
	if not finish_or_open_unlock_showcase.is_valid():
		return {"accepted": false, "blocked_reason": "missing_showcase_callback"}
	var apply_result: Variant = apply_unlock_swap_state_update.call(
		RuntimePerkPayloadAccess.as_dict(completion_plan.get("state_update", {})),
		owner
	)
	var state_applied := false
	if apply_result is Dictionary:
		state_applied = bool(apply_result.get("accepted", false))
	else:
		state_applied = bool(apply_result)
	if not state_applied:
		return {
			"accepted": false,
			"blocked_reason": "completion_state_update_rejected",
			"apply_result": apply_result,
		}
	var showcase_choice_id := str(completion_plan.get("showcase_choice_id", ""))
	var showcase_choice: Dictionary = RuntimePerkPayloadAccess.as_dict(completion_plan.get("showcase_choice", {}))
	finish_or_open_unlock_showcase.call(showcase_choice_id, owner, registry, null, showcase_choice)
	return {
		"accepted": true,
		"state_applied": true,
		"showcase_choice_id": showcase_choice_id,
	}


func confirm_pending_swap(
	pending_swap: Dictionary,
	selected_index: int,
	runtime_skill_levels: Dictionary,
	owner: Object,
	registry: Object,
	catalog: Object,
	fallback_character_type: String,
	callbacks: Dictionary
) -> Dictionary:
	if pending_swap.is_empty():
		return {"accepted": false, "blocked_reason": "missing_pending_swap"}
	var confirm_request: Dictionary = build_confirm_request(
		pending_swap,
		selected_index,
		fallback_character_type
	)
	if not bool(confirm_request.get("accepted", false)):
		return confirm_request

	var selection_apply: Dictionary = apply_confirm_selection_update(
		confirm_request,
		owner,
		RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_APPLY_UNLOCK_SWAP_STATE_UPDATE)
	)
	if not bool(selection_apply.get("accepted", false)):
		return selection_apply

	var get_instance := RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_GET_INSTANCE)
	var skill_config_result: Dictionary = resolve_confirm_skill_config(
		confirm_request,
		registry,
		get_instance,
		RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_GET_SKILL_CONFIG_KEY)
	)
	if not bool(skill_config_result.get("accepted", false)):
		return skill_config_result
	var skill_config: Object = skill_config_result.get("skill_config", null)
	if skill_config == null:
		return {"accepted": false, "blocked_reason": "missing_skill_config"}

	var swap_result: Dictionary = apply_confirm_selected_swap_and_cleanup(
		confirm_request,
		pending_swap,
		skill_config,
		runtime_skill_levels,
		catalog
	)
	if not bool(swap_result.get("ok", false)):
		return {
			"accepted": false,
			"blocked_reason": str(swap_result.get("blocked_reason", "swap_failed")),
			"swap_result": swap_result,
		}

	var unlock_update: Dictionary = commit_confirm_choice_level(
		confirm_request,
		runtime_skill_levels,
		RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_COMMIT_UNLOCK_CHOICE_LEVEL)
	)
	if not bool(unlock_update.get("accepted", false)):
		return unlock_update
	if RuntimePerkSoulSummonArt.is_soul_summon_skill(str(confirm_request.get("unlocked_skill", ""))):
		runtime_skill_levels[CommonSkillCatalog.SOUL_SUMMON_ART_ID] = 1

	var owner_effect_sync: Dictionary = sync_confirm_owner_effects(
		confirm_request,
		owner,
		registry,
		RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS)
	)
	if not bool(owner_effect_sync.get("accepted", false)):
		return owner_effect_sync
	var soul_summon_result: Dictionary = {}
	var removed_skill: String = str(swap_result.get("removed_skill", ""))
	var unlocked_skill: String = str(confirm_request.get("unlocked_skill", ""))
	if RuntimePerkSoulSummonArt.is_soul_summon_skill(removed_skill):
		soul_summon_result["removed"] = RuntimePerkSoulSummonArt.apply_removed(owner, registry)
	if RuntimePerkSoulSummonArt.is_soul_summon_skill(unlocked_skill):
		soul_summon_result["acquired"] = RuntimePerkSoulSummonArt.apply_acquired(owner, registry)

	sync_commando_weapon_controller_for_confirm_request(
		confirm_request,
		skill_config,
		registry,
		get_instance
	)
	var completion_plan: Dictionary = build_confirm_completion_plan(confirm_request)
	if not bool(completion_plan.get("accepted", false)):
		return completion_plan
	var completion_result: Dictionary = apply_confirm_completion_and_showcase(
		completion_plan,
		owner,
		registry,
		RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_APPLY_UNLOCK_SWAP_STATE_UPDATE),
		RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_FINISH_OR_OPEN_UNLOCK_SHOWCASE)
	)
	completion_result["soul_summon_result"] = soul_summon_result
	return completion_result


func apply_confirm_selected_swap_and_cleanup(
	confirm_request: Dictionary,
	pending_unlock_swap: Dictionary,
	skill_config: Object,
	runtime_skill_levels: Dictionary,
	catalog: Object
) -> Dictionary:
	if not bool(confirm_request.get("accepted", false)):
		return {
			"ok": false,
			"accepted": false,
			"blocked_reason": "invalid_confirm_request",
		}
	var selected_index := int(confirm_request.get("selected_index", 0))
	var result: Dictionary = apply_selected_swap_and_cleanup(
		pending_unlock_swap,
		selected_index,
		skill_config,
		runtime_skill_levels,
		catalog
	)
	result["accepted"] = bool(result.get("ok", false))
	result["selected_index"] = selected_index
	return result


func build_confirm_skill_config_request(confirm_request: Dictionary, get_skill_config_key: Callable) -> Dictionary:
	if not bool(confirm_request.get("accepted", false)):
		return {"accepted": false, "blocked_reason": "invalid_confirm_request"}
	if not get_skill_config_key.is_valid():
		return {"accepted": false, "blocked_reason": "missing_skill_config_key_callback"}
	var character_type := str(confirm_request.get("character_type", ""))
	return {
		"accepted": true,
		"character_type": character_type,
		"skill_config_key": str(get_skill_config_key.call(character_type)),
	}


func resolve_confirm_skill_config(
	confirm_request: Dictionary,
	registry: Object,
	get_instance: Callable,
	get_skill_config_key: Callable
) -> Dictionary:
	if not get_instance.is_valid():
		return {"accepted": false, "blocked_reason": "missing_instance_callback"}
	var request: Dictionary = build_confirm_skill_config_request(confirm_request, get_skill_config_key)
	if not bool(request.get("accepted", false)):
		return request
	var skill_config_key := str(request.get("skill_config_key", ""))
	var skill_config: Object = get_instance.call(registry, skill_config_key)
	if skill_config == null:
		return {
			"accepted": false,
			"blocked_reason": "missing_skill_config",
			"character_type": str(request.get("character_type", "")),
			"skill_config_key": skill_config_key,
		}
	request["skill_config"] = skill_config
	return request


func commit_confirm_choice_level(
	confirm_request: Dictionary,
	runtime_skill_levels: Dictionary,
	commit_unlock_choice_level: Callable
) -> Dictionary:
	if not bool(confirm_request.get("accepted", false)):
		return {"accepted": false, "blocked_reason": "invalid_confirm_request"}
	if not commit_unlock_choice_level.is_valid():
		return {"accepted": false, "blocked_reason": "missing_commit_callback"}
	var choice: Dictionary = RuntimePerkPayloadAccess.as_dict(confirm_request.get("choice", {}))
	var result: Variant = commit_unlock_choice_level.call(choice, runtime_skill_levels)
	if result is Dictionary:
		return result
	return {"accepted": bool(result)}


func sync_confirm_owner_effects(
	confirm_request: Dictionary,
	owner: Object,
	registry: Object,
	sync_owner_effects: Callable
) -> Dictionary:
	if not bool(confirm_request.get("accepted", false)):
		return {"accepted": false, "blocked_reason": "invalid_confirm_request"}
	if not sync_owner_effects.is_valid():
		return {"accepted": false, "blocked_reason": "missing_owner_effect_sync_callback"}
	sync_owner_effects.call(owner, registry)
	return {
		"accepted": true,
		"owner_effects_synced": true,
	}


func apply_state_update(
	runtime_state: Object,
	update: Dictionary,
	feedback_helper: Object = null,
	fallback_feedback_timer: float = 0.0
) -> Dictionary:
	if runtime_state == null or not bool(update.get("accepted", false)):
		return {"accepted": false}
	if update.has("pending_unlock_swap"):
		runtime_state.set("pending_unlock_swap", RuntimePerkPayloadAccess.as_dict(update.get("pending_unlock_swap", {})).duplicate(true))
	elif bool(update.get("clear_pending_unlock_swap", false)):
		_clear_dictionary_field(runtime_state, "pending_unlock_swap")
	if update.has("unlock_swap_selected_index"):
		runtime_state.set(
			"unlock_swap_selected_index",
			int(update.get("unlock_swap_selected_index", RuntimePerkRuntimeStateAccess.get_int(runtime_state, "unlock_swap_selected_index")))
		)
	if update.has("gamepad_unlock_swap_horizontal_latch"):
		runtime_state.set(
			"gamepad_unlock_swap_horizontal_latch",
			int(update.get("gamepad_unlock_swap_horizontal_latch", RuntimePerkRuntimeStateAccess.get_int(runtime_state, "gamepad_unlock_swap_horizontal_latch")))
		)
	if bool(update.get("clear_current_choice_context", false)):
		_clear_dictionary_field(runtime_state, "current_choice_context")
	var feedback_result: Dictionary = RuntimePerkPayloadAccess.as_dict(update.get("feedback_result", {}))
	if not feedback_result.is_empty() and feedback_helper != null and feedback_helper.has_method("apply_feedback_state_update"):
		feedback_helper.apply_feedback_state_update(runtime_state, feedback_result, fallback_feedback_timer)
	return {
		"accepted": true,
		"sync_owner": bool(update.get("sync_owner", false)),
		"unlock_swap_selected_index": int(RuntimePerkRuntimeStateAccess.get_int(runtime_state, "unlock_swap_selected_index")),
	}


func apply_state_update_and_sync_owner(
	runtime_state: Object,
	update: Dictionary,
	feedback_helper: Object = null,
	fallback_feedback_timer: float = 0.0,
	owner: Object = null,
	sync_owner: Callable = Callable()
) -> Dictionary:
	var apply_result: Dictionary = apply_state_update(
		runtime_state,
		update,
		feedback_helper,
		fallback_feedback_timer
	)
	if not bool(apply_result.get("accepted", false)):
		return apply_result
	var should_sync_owner := bool(apply_result.get("sync_owner", false))
	if should_sync_owner and sync_owner.is_valid():
		sync_owner.call(owner)
		apply_result["owner_synced"] = true
	else:
		apply_result["owner_synced"] = false
	return apply_result


func apply_state_update_and_sync_owner_from_runtime_state(
	runtime_state: Object,
	update: Dictionary,
	owner: Object = null
) -> Dictionary:
	return apply_state_update_and_sync_owner(
		runtime_state,
		update,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_choice_feedback"),
		RuntimePerkRuntimeStateAccess.get_float(runtime_state, "feedback_timer"),
		owner,
		RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_sync_owner")
	)


func build_cancel_feedback() -> Dictionary:
	return {
		"feedback_text": SWAP_CANCEL_FEEDBACK_TEXT,
		"feedback_timer": SWAP_CANCEL_FEEDBACK_TIMER,
	}


func build_confirm_feedback(choice: Dictionary, choice_id: String = "") -> Dictionary:
	var resolved_id := choice_id
	if resolved_id == "":
		resolved_id = str(choice.get("id", ""))
	var display_name := str(choice.get("name", resolved_id))
	if display_name == "":
		display_name = resolved_id
	return {
		"feedback_text": SWAP_COMPLETE_FEEDBACK_TEMPLATE % display_name,
		"feedback_timer": SWAP_COMPLETE_FEEDBACK_TIMER,
	}


func apply_selected_swap(pending_unlock_swap: Dictionary, selected_index: int, skill_config: Object) -> Dictionary:
	if pending_unlock_swap.is_empty() or skill_config == null:
		return {"ok": false}
	var choice: Dictionary = RuntimePerkPayloadAccess.as_dict(pending_unlock_swap.get("choice", {}))
	var choice_id: String = str(pending_unlock_swap.get("choice_id", choice.get("id", "")))
	var unlocked_skill: String = str(pending_unlock_swap.get("unlocks_skill", choice.get("unlocks_skill", "")))
	var candidates: Array = RuntimePerkPayloadAccess.as_array(pending_unlock_swap.get("candidates", []))
	if choice_id == "" or unlocked_skill == "" or candidates.is_empty():
		return {"ok": false}
	var clamped_index: int = clampi(selected_index, 0, candidates.size() - 1)
	var removed_skill: String = str(RuntimePerkPayloadAccess.as_dict(candidates[clamped_index]).get("skill_id", ""))
	if removed_skill == "":
		return {"ok": false}
	var swapped := false
	if skill_config.has_method("swap_equipped_permanent"):
		swapped = bool(skill_config.swap_equipped_permanent(removed_skill, unlocked_skill))
	elif skill_config.has_method("unequip_skill") and skill_config.has_method("unlock_and_equip_skill"):
		swapped = bool(skill_config.unequip_skill(removed_skill)) and bool(skill_config.unlock_and_equip_skill(unlocked_skill))
	if not swapped:
		return {"ok": false}
	return {
		"ok": true,
		"choice": choice,
		"choice_id": choice_id,
		"unlocked_skill": unlocked_skill,
		"removed_skill": removed_skill,
		"selected_index": clamped_index,
	}


func apply_selected_swap_and_cleanup(
	pending_unlock_swap: Dictionary,
	selected_index: int,
	skill_config: Object,
	runtime_skill_levels: Dictionary,
	catalog: Object
) -> Dictionary:
	var swap_result: Dictionary = apply_selected_swap(pending_unlock_swap, selected_index, skill_config)
	if not bool(swap_result.get("ok", false)):
		return swap_result
	var removed_skill := str(swap_result.get("removed_skill", ""))
	swap_result["removed_perk_id"] = remove_runtime_unlock_for_skill(
		runtime_skill_levels,
		removed_skill,
		catalog
	)
	if RuntimePerkSoulSummonArt.is_soul_summon_skill(removed_skill):
		runtime_skill_levels.erase(CommonSkillCatalog.SOUL_SUMMON_ART_ID)
	return swap_result


func remove_runtime_unlock_for_skill(runtime_skill_levels: Dictionary, skill_id: String, catalog: Object) -> String:
	var removed_perk_id := ""
	for perk_id_value in runtime_skill_levels.keys():
		var perk_id := str(perk_id_value)
		var data: Dictionary = catalog.get_perk_data(perk_id) if catalog != null and catalog.has_method("get_perk_data") else {}
		if str(data.get("unlocks_skill", "")) == skill_id:
			removed_perk_id = perk_id
			break
	if removed_perk_id == "":
		var fallback_id := _get_commando_unlock_perk_id_for_skill(skill_id)
		if runtime_skill_levels.has(fallback_id):
			removed_perk_id = fallback_id
	if removed_perk_id != "":
		runtime_skill_levels.erase(removed_perk_id)
	return removed_perk_id


func sync_commando_weapon_controller(
	unlocked_skill: String,
	skill_config: Object,
	registry: Object,
	character_type: String,
	get_instance: Callable
) -> bool:
	if _normalize_character_type(character_type) != "soldier":
		return false
	var weapon_controller: Object = get_instance.call(registry, "commando_weapon_controller")
	if weapon_controller == null:
		return false
	if weapon_controller.has_method("sync_equipped_permanent"):
		weapon_controller.sync_equipped_permanent(skill_config)
	elif weapon_controller.has_method("unlock_permanent_weapon"):
		weapon_controller.unlock_permanent_weapon(unlocked_skill)
	if unlocked_skill != "" and weapon_controller.has_method("trigger_hud_highlight"):
		weapon_controller.trigger_hud_highlight(unlocked_skill)
	if unlocked_skill != "":
		_play_commando_weapon_change_audio(registry, get_instance)
	return true


func sync_commando_weapon_controller_for_confirm_request(
	confirm_request: Dictionary,
	skill_config: Object,
	registry: Object,
	get_instance: Callable
) -> bool:
	if not bool(confirm_request.get("accepted", false)):
		return false
	return sync_commando_weapon_controller(
		str(confirm_request.get("unlocked_skill", "")),
		skill_config,
		registry,
		str(confirm_request.get("character_type", "")),
		get_instance
	)


func _play_commando_weapon_change_audio(registry: Object, get_instance: Callable) -> void:
	var game_audio: Object = get_instance.call(registry, "game_audio")
	if game_audio != null and game_audio.has_method("play_commando_weapon_change"):
		game_audio.play_commando_weapon_change()


func _get_commando_unlock_perk_id_for_skill(skill_id: String) -> String:
	if skill_id == "commando_pistol":
		return "soldier_pistol_perk"
	return "soldier_unlock_%s" % skill_id


func _normalize_character_type(character_type: String) -> String:
	var normalized: String = str(character_type).strip_edges().to_lower()
	if normalized == "soldier" or normalized == "commando":
		return "soldier"
	return normalized


func _clear_dictionary_field(runtime_state: Object, field_name: String) -> void:
	var field_value: Variant = RuntimePerkRuntimeStateAccess.get_dict(runtime_state, field_name)
	if field_value is Dictionary:
		(field_value as Dictionary).clear()
