extends RefCounted

const PATH_BOOKKEEPING := "bookkeeping"
const PATH_UNLOCK := "unlock"
const PATH_LEVEL := "level"
const BOOKKEEPING_FEEDBACK_TIMER := 1.0


func build_path(choice: Dictionary, bookkeeping_update: Dictionary) -> Dictionary:
	if bool(bookkeeping_update.get("handled", false)):
		return {
			"path": PATH_BOOKKEEPING,
			"accepted": bool(bookkeeping_update.get("accepted", false)),
			"next_pending_skill_choices": int(bookkeeping_update.get("next_pending_skill_choices", 0)),
			"next_starpoint_for_skills": int(bookkeeping_update.get("next_starpoint_for_skills", 0)),
			"feedback_result": _get_dict(bookkeeping_update.get("feedback_result", {})).duplicate(true),
			"fallback_timer": BOOKKEEPING_FEEDBACK_TIMER,
		}
	if str(choice.get("unlocks_skill", "")) != "":
		return {
			"path": PATH_UNLOCK,
			"accepted": true,
		}
	return {
		"path": PATH_LEVEL,
		"accepted": true,
	}


func build_path_from_bookkeeping_choice(
	choice: Dictionary,
	current_pending_skill_choices: int,
	current_starpoint_for_skills: int,
	starpoint_per_choice: int,
	apply_bookkeeping_choice: Callable,
	build_bookkeeping_state_update: Callable
) -> Dictionary:
	if not apply_bookkeeping_choice.is_valid():
		return {"accepted": false, "blocked_reason": "missing_bookkeeping_choice_callback"}
	if not build_bookkeeping_state_update.is_valid():
		return {"accepted": false, "blocked_reason": "missing_bookkeeping_update_callback"}
	var bookkeeping_result_value: Variant = apply_bookkeeping_choice.call(
		choice,
		current_pending_skill_choices,
		current_starpoint_for_skills,
		starpoint_per_choice
	)
	var bookkeeping_result: Dictionary = _get_dict(bookkeeping_result_value)
	var bookkeeping_update_value: Variant = build_bookkeeping_state_update.call(
		bookkeeping_result,
		current_pending_skill_choices,
		current_starpoint_for_skills
	)
	var bookkeeping_update: Dictionary = _get_dict(bookkeeping_update_value)
	var path: Dictionary = build_path(choice, bookkeeping_update)
	path["bookkeeping_result"] = bookkeeping_result
	path["bookkeeping_update"] = bookkeeping_update
	return path


func build_level_state_update(
	level_update: Dictionary,
	choice_id: String,
	current_level: int
) -> Dictionary:
	if not bool(level_update.get("accepted", false)):
		return {"accepted": false}
	return {
		"accepted": true,
		"choice_id": choice_id.strip_edges(),
		"next_level": int(level_update.get("next_level", current_level + 1)),
		"feedback_result": level_update,
	}


func build_bookkeeping_state_application(
	standard_path: Dictionary,
	current_pending_skill_choices: int,
	current_starpoint_for_skills: int
) -> Dictionary:
	if not bool(standard_path.get("accepted", false)):
		return {"accepted": false}
	return {
		"accepted": true,
		"pending_skill_choices": int(standard_path.get("next_pending_skill_choices", current_pending_skill_choices)),
		"starpoint_for_skills": int(standard_path.get("next_starpoint_for_skills", current_starpoint_for_skills)),
		"feedback_result": _get_dict(standard_path.get("feedback_result", {})).duplicate(true),
		"fallback_timer": float(standard_path.get("fallback_timer", BOOKKEEPING_FEEDBACK_TIMER)),
	}


func build_level_state_application(level_state_update: Dictionary) -> Dictionary:
	if not bool(level_state_update.get("accepted", false)):
		return {"accepted": false}
	var choice_id: String = str(level_state_update.get("choice_id", "")).strip_edges()
	if choice_id == "":
		return {"accepted": false}
	var runtime_level_patch := {}
	runtime_level_patch[choice_id] = int(level_state_update.get("next_level", 0))
	return {
		"accepted": true,
		"runtime_skill_level_patch": runtime_level_patch,
		"feedback_result": _get_dict(level_state_update.get("feedback_result", {})).duplicate(true),
	}


func apply_bookkeeping_path(
	standard_path: Dictionary,
	runtime_skill_levels: Dictionary,
	current_pending_skill_choices: int,
	current_starpoint_for_skills: int
) -> Dictionary:
	var state_application: Dictionary = build_bookkeeping_state_application(
		standard_path,
		current_pending_skill_choices,
		current_starpoint_for_skills
	)
	return apply_state_update(
		state_application,
		runtime_skill_levels,
		current_pending_skill_choices,
		current_starpoint_for_skills
	)


func apply_bookkeeping_path_to_runtime_state(
	standard_path: Dictionary,
	runtime_state: Object,
	runtime_skill_levels: Dictionary,
	current_pending_skill_choices: int,
	current_starpoint_for_skills: int,
	choice: Dictionary,
	apply_choice_feedback_result: Callable
) -> Dictionary:
	var apply_result: Dictionary = apply_bookkeeping_path(
		standard_path,
		runtime_skill_levels,
		current_pending_skill_choices,
		current_starpoint_for_skills
	)
	if not bool(apply_result.get("accepted", false)):
		return apply_result
	var state_result: Dictionary = apply_result_to_runtime_state(runtime_state, apply_result)
	if not bool(state_result.get("accepted", false)):
		return state_result
	if not apply_choice_feedback_result.is_valid():
		return {"accepted": false, "blocked_reason": "missing_feedback_callback"}
	var feedback_accepted := bool(apply_choice_feedback_result.call(
		_get_dict(state_result.get("feedback_result", {})),
		choice,
		float(state_result.get("fallback_timer", BOOKKEEPING_FEEDBACK_TIMER))
	))
	if not feedback_accepted:
		return {
			"accepted": false,
			"blocked_reason": "feedback_rejected",
			"state_result": state_result,
		}
	return {
		"accepted": true,
		"feedback_applied": true,
		"state_result": state_result,
	}


func apply_level_path(
	level_update: Dictionary,
	choice_id: String,
	current_level: int,
	runtime_skill_levels: Dictionary,
	current_pending_skill_choices: int,
	current_starpoint_for_skills: int
) -> Dictionary:
	var level_state_update: Dictionary = build_level_state_update(level_update, choice_id, current_level)
	if not bool(level_state_update.get("accepted", false)):
		return {"accepted": false}
	var state_application: Dictionary = build_level_state_application(level_state_update)
	return apply_state_update(
		state_application,
		runtime_skill_levels,
		current_pending_skill_choices,
		current_starpoint_for_skills
	)


func apply_level_path_to_runtime_state(
	level_update: Dictionary,
	choice_id: String,
	current_level: int,
	runtime_state: Object,
	runtime_skill_levels: Dictionary,
	current_pending_skill_choices: int,
	current_starpoint_for_skills: int
) -> Dictionary:
	var apply_result: Dictionary = apply_level_path(
		level_update,
		choice_id,
		current_level,
		runtime_skill_levels,
		current_pending_skill_choices,
		current_starpoint_for_skills
	)
	if not bool(apply_result.get("accepted", false)):
		return apply_result
	return apply_result_to_runtime_state(runtime_state, apply_result)


func apply_level_choice_to_runtime_state(
	choice: Dictionary,
	choice_id: String,
	runtime_state: Object,
	runtime_skill_levels: Dictionary,
	current_pending_skill_choices: int,
	current_starpoint_for_skills: int,
	build_level_choice_update: Callable
) -> Dictionary:
	if not build_level_choice_update.is_valid():
		return {"accepted": false, "blocked_reason": "missing_level_update_callback"}
	var level_update_result: Variant = build_level_choice_update.call(choice, runtime_skill_levels)
	var level_update: Dictionary = level_update_result if level_update_result is Dictionary else {"accepted": false}
	return apply_level_path_to_runtime_state(
		level_update,
		choice_id,
		int(runtime_skill_levels.get(choice_id, 0)),
		runtime_state,
		runtime_skill_levels,
		current_pending_skill_choices,
		current_starpoint_for_skills
	)


func apply_level_feedback_result(
	level_state_result: Dictionary,
	choice: Dictionary,
	apply_choice_feedback_result: Callable,
	fallback_timer: float
) -> Dictionary:
	if not bool(level_state_result.get("accepted", false)):
		return {"accepted": false, "blocked_reason": "invalid_level_state_result"}
	if not apply_choice_feedback_result.is_valid():
		return {"accepted": false, "blocked_reason": "missing_feedback_callback"}
	var feedback_accepted := bool(apply_choice_feedback_result.call(
		_get_dict(level_state_result.get("feedback_result", {})),
		choice,
		float(level_state_result.get("fallback_timer", fallback_timer))
	))
	if not feedback_accepted:
		return {
			"accepted": false,
			"blocked_reason": "feedback_rejected",
		}
	return {
		"accepted": true,
		"feedback_applied": true,
	}


func apply_state_update(
	update: Dictionary,
	runtime_skill_levels: Dictionary,
	current_pending_skill_choices: int,
	current_starpoint_for_skills: int
) -> Dictionary:
	if not bool(update.get("accepted", false)):
		return {"accepted": false}
	var runtime_level_patch: Dictionary = _get_dict(update.get("runtime_skill_level_patch", {}))
	for perk_id_value in runtime_level_patch.keys():
		var perk_id := str(perk_id_value)
		if perk_id != "":
			runtime_skill_levels[perk_id] = int(runtime_level_patch[perk_id_value])
	var result := {
		"accepted": true,
		"pending_skill_choices": int(update.get("pending_skill_choices", current_pending_skill_choices)),
		"starpoint_for_skills": int(update.get("starpoint_for_skills", current_starpoint_for_skills)),
		"feedback_result": _get_dict(update.get("feedback_result", {})).duplicate(true),
	}
	if update.has("fallback_timer"):
		result["fallback_timer"] = float(update.get("fallback_timer", BOOKKEEPING_FEEDBACK_TIMER))
	return result


func apply_result_to_runtime_state(runtime_state: Object, apply_result: Dictionary) -> Dictionary:
	if runtime_state == null or not bool(apply_result.get("accepted", false)):
		return {"accepted": false}
	if apply_result.has("pending_skill_choices"):
		runtime_state.set("pending_skill_choices", int(apply_result.get("pending_skill_choices", runtime_state.get("pending_skill_choices"))))
	if apply_result.has("starpoint_for_skills"):
		runtime_state.set("starpoint_for_skills", int(apply_result.get("starpoint_for_skills", runtime_state.get("starpoint_for_skills"))))
	var result := {
		"accepted": true,
		"pending_skill_choices": int(runtime_state.get("pending_skill_choices")),
		"starpoint_for_skills": int(runtime_state.get("starpoint_for_skills")),
		"feedback_result": _get_dict(apply_result.get("feedback_result", {})).duplicate(true),
	}
	if apply_result.has("fallback_timer"):
		result["fallback_timer"] = float(apply_result.get("fallback_timer", BOOKKEEPING_FEEDBACK_TIMER))
	return result


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
