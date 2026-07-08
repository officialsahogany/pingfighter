extends RefCounted


func is_choice_active(choice_active: bool, has_pending_swap: bool) -> bool:
	return choice_active or has_pending_swap


func is_choice_active_from_runtime_state(runtime_state: Object) -> bool:
	if runtime_state == null:
		return false
	return is_choice_active(
		bool(runtime_state.get("choice_active")),
		_has_runtime_pending_swap(runtime_state)
	)


func build_unavailable_state_update(clear_current_choices: bool = false) -> Dictionary:
	return {
		"accepted": true,
		"choice_active": false,
		"clear_current_choices": clear_current_choices,
		"clear_current_choice_context": true,
		"clear_current_perk_slot_status": true,
		"resume_skill_cooldowns": true,
	}


func build_empty_choices_state_update(current_pending_skill_choices: int) -> Dictionary:
	var next_pending_choices: int = max(0, current_pending_skill_choices - 1)
	var has_next_choice := next_pending_choices > 0
	return {
		"accepted": true,
		"pending_skill_choices": next_pending_choices,
		"choice_active": has_next_choice,
		"open_next_choice": has_next_choice,
		"clear_current_choice_context": not has_next_choice,
		"clear_current_perk_slot_status": not has_next_choice,
		"resume_skill_cooldowns": not has_next_choice,
	}


func build_generated_choices_state_update(
	choice_context: Dictionary,
	choices: Array,
	perk_slot_status: Dictionary
) -> Dictionary:
	return {
		"accepted": true,
		"current_choice_context": choice_context.duplicate(true),
		"current_choices": choices.duplicate(true),
		"current_perk_slot_status": perk_slot_status.duplicate(true),
	}


func build_ready_state_update(choice_count: int) -> Dictionary:
	var safe_choice_count: int = max(0, choice_count)
	if safe_choice_count <= 0:
		return {"accepted": false, "blocked_reason": "empty_choices"}
	return {
		"accepted": true,
		"selected_index": min(1, safe_choice_count - 1),
		"gamepad_choice_horizontal_latch": 0,
		"animation_time": 0.0,
		"choice_active": true,
		"tick_lingpet_ring_core_offer_cooldown": true,
		"pause_skill_cooldowns": true,
		"build_particles": true,
	}


func build_active_tick_state_update(current_animation_time: float, delta: float, choice_active: bool) -> Dictionary:
	if not choice_active:
		return {"accepted": false, "blocked_reason": "inactive_choice"}
	return {
		"accepted": true,
		"animation_time": current_animation_time + delta,
		"update_particles": true,
	}


func apply_state_update(runtime_state: Object, update: Dictionary) -> Dictionary:
	if runtime_state == null or not bool(update.get("accepted", false)):
		return {"accepted": false}
	if update.has("pending_skill_choices"):
		runtime_state.set(
			"pending_skill_choices",
			int(update.get("pending_skill_choices", runtime_state.get("pending_skill_choices")))
		)
	if update.has("choice_active"):
		runtime_state.set("choice_active", bool(update.get("choice_active", runtime_state.get("choice_active"))))
	if update.has("selected_index"):
		runtime_state.set("selected_index", int(update.get("selected_index", runtime_state.get("selected_index"))))
	if update.has("gamepad_choice_horizontal_latch"):
		runtime_state.set(
			"gamepad_choice_horizontal_latch",
			int(update.get("gamepad_choice_horizontal_latch", runtime_state.get("gamepad_choice_horizontal_latch")))
		)
	if update.has("animation_time"):
		runtime_state.set("animation_time", float(update.get("animation_time", runtime_state.get("animation_time"))))
	if update.has("current_choice_context"):
		runtime_state.set("current_choice_context", _get_dict(update.get("current_choice_context", {})).duplicate(true))
	if update.has("current_choices"):
		runtime_state.set("current_choices", _get_array(update.get("current_choices", [])).duplicate(true))
	if update.has("current_perk_slot_status"):
		runtime_state.set("current_perk_slot_status", _get_dict(update.get("current_perk_slot_status", {})).duplicate(true))
	if bool(update.get("clear_current_choices", false)):
		var current_choices_value: Variant = runtime_state.get("current_choices")
		if current_choices_value is Array:
			(current_choices_value as Array).clear()
	if bool(update.get("clear_current_choice_context", false)):
		var current_choice_context_value: Variant = runtime_state.get("current_choice_context")
		if current_choice_context_value is Dictionary:
			(current_choice_context_value as Dictionary).clear()
	if bool(update.get("clear_current_perk_slot_status", false)):
		var current_slot_status_value: Variant = runtime_state.get("current_perk_slot_status")
		if current_slot_status_value is Dictionary:
			(current_slot_status_value as Dictionary).clear()
	return {
		"accepted": true,
		"pending_skill_choices": int(runtime_state.get("pending_skill_choices")),
		"choice_active": bool(runtime_state.get("choice_active")),
		"open_next_choice": bool(update.get("open_next_choice", false)),
		"resume_skill_cooldowns": bool(update.get("resume_skill_cooldowns", false)),
		"tick_lingpet_ring_core_offer_cooldown": bool(update.get("tick_lingpet_ring_core_offer_cooldown", false)),
		"pause_skill_cooldowns": bool(update.get("pause_skill_cooldowns", false)),
		"build_particles": bool(update.get("build_particles", false)),
		"update_particles": bool(update.get("update_particles", false)),
	}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _has_runtime_pending_swap(runtime_state: Object) -> bool:
	if runtime_state == null:
		return false
	var pending_swap: Dictionary = _get_dict(runtime_state.get("pending_unlock_swap"))
	var helper: Object = _get_runtime_state_object(runtime_state, "_unlock_swap_flow")
	if helper != null and helper.has_method("has_pending_swap"):
		return bool(helper.has_pending_swap(pending_swap))
	return not pending_swap.is_empty()


func _get_runtime_state_object(runtime_state: Object, key: String) -> Object:
	if runtime_state == null:
		return null
	var value: Variant = runtime_state.get(key)
	if value is Object:
		return value
	return null
