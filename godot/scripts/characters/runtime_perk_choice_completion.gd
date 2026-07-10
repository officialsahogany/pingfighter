extends RefCounted

const RuntimePerkPayloadAccess := preload("res://scripts/characters/runtime_perk_payload_access.gd")
const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const CLOSE_ACTION_RESUME_SKILL_COOLDOWNS := "resume_skill_cooldowns"
const CLOSE_ACTION_ARM_RESUME_SAFETY := "arm_resume_safety"
const CLOSE_ACTION_START_STARPOINT_ABSORPTION := "start_starpoint_absorption"
const CLOSE_ACTION_SYNC_OWNER := "sync_owner"


func build_selected_choice_snapshot(choice_id: String, choice: Dictionary, runtime_skill_levels: Dictionary) -> Dictionary:
	var snapshot: Dictionary = choice.duplicate(true)
	snapshot["id"] = choice_id
	if str(snapshot.get("name", "")) == "":
		snapshot["name"] = choice_id
	var applied_level: int = int(runtime_skill_levels.get(choice_id, 0))
	if applied_level > 0:
		snapshot["current_level"] = max(0, applied_level - 1)
		snapshot["next_level"] = applied_level
		snapshot["level_delta"] = 1
	return snapshot


func build_success_state_update_for_choice(
	choice_id: String,
	choice: Dictionary,
	runtime_skill_levels: Dictionary,
	pending_skill_choices: int,
	selected_choice_sequence: int,
	megingjord_extra_pick: bool,
	megingjord_feedback: Dictionary = {}
) -> Dictionary:
	return build_success_state_update(
		choice_id,
		build_selected_choice_snapshot(choice_id, choice, runtime_skill_levels),
		pending_skill_choices,
		selected_choice_sequence,
		megingjord_extra_pick,
		megingjord_feedback
	)


func build_success_state_update(
	choice_id: String,
	selected_choice_snapshot: Dictionary,
	pending_skill_choices: int,
	selected_choice_sequence: int,
	megingjord_extra_pick: bool,
	megingjord_feedback: Dictionary = {}
) -> Dictionary:
	var clean_id: String = choice_id.strip_edges()
	if clean_id == "":
		return {"accepted": false}
	var next_pending_choices: int = max(0, pending_skill_choices - 1)
	var feedback_result: Dictionary = {}
	if megingjord_extra_pick:
		next_pending_choices += 1
		feedback_result = megingjord_feedback.duplicate(true)
	return {
		"accepted": true,
		"last_selected_id": clean_id,
		"last_selected_choice": selected_choice_snapshot.duplicate(true),
		"selected_choice_sequence": max(0, selected_choice_sequence) + 1,
		"pending_skill_choices": next_pending_choices,
		"choice_active": false,
		"clear_current_choices": true,
		"animation_time": 0.0,
		"feedback_result": feedback_result,
	}


func build_next_choice_context(current_context: Dictionary) -> Dictionary:
	return current_context.duplicate(true)


func apply_success_state_update(runtime_state: Object, state_update: Dictionary, fallback_choice_id: String = "") -> Dictionary:
	if runtime_state == null or not bool(state_update.get("accepted", false)):
		return {"accepted": false}
	var resolved_id: String = str(state_update.get("last_selected_id", fallback_choice_id)).strip_edges()
	if resolved_id == "":
		return {"accepted": false}
	runtime_state.set("last_selected_id", resolved_id)
	runtime_state.set("last_selected_choice", RuntimePerkPayloadAccess.as_dict(state_update.get("last_selected_choice", {})).duplicate(true))
	runtime_state.set(
		"selected_choice_sequence",
		int(state_update.get(
			"selected_choice_sequence",
			RuntimePerkRuntimeStateAccess.get_int(runtime_state, "selected_choice_sequence")
		))
	)
	runtime_state.set(
		"pending_skill_choices",
		int(state_update.get(
			"pending_skill_choices",
			RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices")
		))
	)
	runtime_state.set("choice_active", bool(state_update.get("choice_active", false)))
	if bool(state_update.get("clear_current_choices", false)):
		var current_choices: Array = RuntimePerkRuntimeStateAccess.get_array(runtime_state, "current_choices")
		current_choices.clear()
	runtime_state.set(
		"animation_time",
		float(state_update.get(
			"animation_time",
			RuntimePerkRuntimeStateAccess.get_float(runtime_state, "animation_time")
		))
	)
	var feedback_result: Dictionary = RuntimePerkPayloadAccess.as_dict(state_update.get("feedback_result", {}))
	if not feedback_result.is_empty():
		runtime_state.set("feedback_text", str(feedback_result.get("feedback_text", "")))
		runtime_state.set(
			"feedback_timer",
			float(feedback_result.get(
				"feedback_timer",
				RuntimePerkRuntimeStateAccess.get_float(runtime_state, "feedback_timer")
			))
		)
	return {
		"accepted": true,
		"pending_skill_choices": RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices"),
		"choice_active": RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "choice_active"),
	}


func build_post_state_plan(
	pending_skill_choices: int,
	has_catalog: bool,
	has_pending_unlock_swap: bool,
	defer_next_choice: bool = false
) -> Dictionary:
	var should_defer_next := defer_next_choice and pending_skill_choices > 0
	var should_open_next := pending_skill_choices > 0 and has_catalog and not should_defer_next
	return {
		"open_next_choice": should_open_next,
		"clear_choice_context": not should_open_next and not has_pending_unlock_swap and not should_defer_next,
		"deferred_next_choice": should_defer_next,
	}


func apply_post_state_plan(runtime_state: Object, post_state_plan: Dictionary) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false}
	var should_clear_context := bool(post_state_plan.get("clear_choice_context", false))
	if should_clear_context:
		var current_context: Dictionary = RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "current_choice_context")
		current_context.clear()
	return {
		"accepted": true,
		"open_next_choice": bool(post_state_plan.get("open_next_choice", false)),
		"clear_choice_context": should_clear_context,
		"deferred_next_choice": bool(post_state_plan.get("deferred_next_choice", false)),
	}


func build_modal_close_plan(
	choice_active: bool,
	has_pending_unlock_swap: bool,
	has_post_choice_blocker: bool = false
) -> Dictionary:
	var fully_closed := not choice_active and not has_pending_unlock_swap and not has_post_choice_blocker
	return {
		CLOSE_ACTION_RESUME_SKILL_COOLDOWNS: fully_closed,
		CLOSE_ACTION_ARM_RESUME_SAFETY: fully_closed,
		CLOSE_ACTION_START_STARPOINT_ABSORPTION: fully_closed,
		CLOSE_ACTION_SYNC_OWNER: true,
	}


func build_modal_close_steps(close_plan: Dictionary) -> Array:
	var steps: Array = []
	if bool(close_plan.get(CLOSE_ACTION_RESUME_SKILL_COOLDOWNS, false)):
		steps.append(_close_step(CLOSE_ACTION_RESUME_SKILL_COOLDOWNS, "process.runtime_perk.finish_success.resume_skill_cooldowns"))
	if bool(close_plan.get(CLOSE_ACTION_ARM_RESUME_SAFETY, false)):
		steps.append(_close_step(CLOSE_ACTION_ARM_RESUME_SAFETY, "process.runtime_perk.finish_success.resume_safety"))
	if bool(close_plan.get(CLOSE_ACTION_START_STARPOINT_ABSORPTION, false)):
		steps.append(_close_step(CLOSE_ACTION_START_STARPOINT_ABSORPTION, "process.runtime_perk.finish_success.starpoint_absorption"))
	if bool(close_plan.get(CLOSE_ACTION_SYNC_OWNER, true)):
		steps.append(_close_step(CLOSE_ACTION_SYNC_OWNER, "process.runtime_perk.finish_success.sync_owner"))
	return steps


func _close_step(action: String, perf_label: String) -> Dictionary:
	return {
		"action": action,
		"perf_label": perf_label,
	}
