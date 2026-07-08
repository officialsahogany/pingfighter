extends RefCounted


func reset_from_runtime_state(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {"accepted": false}
	_resume_skill_cooldowns_for_choice(runtime_state)
	var result: Dictionary = apply_state_update(runtime_state, build_reset_state_update())
	_reset_starpoint_absorption(runtime_state)
	_reset_active_unlock_flight(runtime_state)
	_reset_unlock_showcase(runtime_state)
	_reset_deferred_instants(runtime_state)
	_reset_resume_safety(runtime_state)
	return result


func build_reset_state_update() -> Dictionary:
	return {
		"accepted": true,
		"clear_runtime_skill_levels": true,
		"starpoint_for_skills": 0,
		"pending_skill_choices": 0,
		"choice_active": false,
		"clear_current_choices": true,
		"selected_index": 0,
		"animation_time": 0.0,
		"clear_particles": true,
		"gold_from_perks": 0,
		"feedback_text": "",
		"feedback_timer": 0.0,
		"last_selected_id": "",
		"clear_last_selected_choice": true,
		"selected_choice_sequence": 0,
		"item_gold_gain_multiplier": 1.0,
		"item_perk_level_bonus": 0,
		"viper_ignition_aura_active": false,
		"viper_ignition_aura_owner_sync_dirty": false,
		"clear_pending_unlock_swap": true,
		"unlock_swap_selected_index": 0,
		"gamepad_choice_horizontal_latch": 0,
		"gamepad_unlock_swap_horizontal_latch": 0,
		"clear_current_choice_context": true,
		"clear_current_perk_slot_status": true,
	}


func apply_state_update(runtime_state: Object, update: Dictionary) -> Dictionary:
	if runtime_state == null or not bool(update.get("accepted", false)):
		return {"accepted": false}

	if bool(update.get("clear_runtime_skill_levels", false)):
		_clear_dictionary_field(runtime_state, "runtime_skill_levels")
	if update.has("starpoint_for_skills"):
		runtime_state.set("starpoint_for_skills", int(update.get("starpoint_for_skills", 0)))
	if update.has("pending_skill_choices"):
		runtime_state.set("pending_skill_choices", int(update.get("pending_skill_choices", 0)))
	if update.has("choice_active"):
		runtime_state.set("choice_active", bool(update.get("choice_active", false)))
	if bool(update.get("clear_current_choices", false)):
		_clear_array_field(runtime_state, "current_choices")
	if update.has("selected_index"):
		runtime_state.set("selected_index", int(update.get("selected_index", 0)))
	if update.has("animation_time"):
		runtime_state.set("animation_time", float(update.get("animation_time", 0.0)))
	if bool(update.get("clear_particles", false)):
		_clear_array_field(runtime_state, "particles")
	if update.has("gold_from_perks"):
		runtime_state.set("gold_from_perks", int(update.get("gold_from_perks", 0)))
	if update.has("feedback_text"):
		runtime_state.set("feedback_text", str(update.get("feedback_text", "")))
	if update.has("feedback_timer"):
		runtime_state.set("feedback_timer", float(update.get("feedback_timer", 0.0)))
	if update.has("last_selected_id"):
		runtime_state.set("last_selected_id", str(update.get("last_selected_id", "")))
	if bool(update.get("clear_last_selected_choice", false)):
		_clear_dictionary_field(runtime_state, "last_selected_choice")
	if update.has("selected_choice_sequence"):
		runtime_state.set("selected_choice_sequence", int(update.get("selected_choice_sequence", 0)))
	if update.has("item_gold_gain_multiplier"):
		runtime_state.set("item_gold_gain_multiplier", float(update.get("item_gold_gain_multiplier", 1.0)))
	if update.has("item_perk_level_bonus"):
		runtime_state.set("item_perk_level_bonus", int(update.get("item_perk_level_bonus", 0)))
	if update.has("viper_ignition_aura_active"):
		runtime_state.set(
			"viper_ignition_aura_active",
			bool(update.get("viper_ignition_aura_active", false))
		)
	if update.has("viper_ignition_aura_owner_sync_dirty"):
		runtime_state.set(
			"viper_ignition_aura_owner_sync_dirty",
			bool(update.get("viper_ignition_aura_owner_sync_dirty", false))
		)
	if bool(update.get("clear_pending_unlock_swap", false)):
		_clear_dictionary_field(runtime_state, "pending_unlock_swap")
	if update.has("unlock_swap_selected_index"):
		runtime_state.set("unlock_swap_selected_index", int(update.get("unlock_swap_selected_index", 0)))
	if update.has("gamepad_choice_horizontal_latch"):
		runtime_state.set(
			"gamepad_choice_horizontal_latch",
			int(update.get("gamepad_choice_horizontal_latch", 0))
		)
	if update.has("gamepad_unlock_swap_horizontal_latch"):
		runtime_state.set(
			"gamepad_unlock_swap_horizontal_latch",
			int(update.get("gamepad_unlock_swap_horizontal_latch", 0))
		)
	if bool(update.get("clear_current_choice_context", false)):
		_clear_dictionary_field(runtime_state, "current_choice_context")
	if bool(update.get("clear_current_perk_slot_status", false)):
		_clear_dictionary_field(runtime_state, "current_perk_slot_status")

	return {
		"accepted": true,
		"pending_skill_choices": int(runtime_state.get("pending_skill_choices")),
		"choice_active": bool(runtime_state.get("choice_active")),
		"feedback_timer": float(runtime_state.get("feedback_timer")),
	}


func _clear_array_field(runtime_state: Object, field_name: String) -> void:
	var field_value: Variant = runtime_state.get(field_name)
	if field_value is Array:
		(field_value as Array).clear()


func _clear_dictionary_field(runtime_state: Object, field_name: String) -> void:
	var field_value: Variant = runtime_state.get(field_name)
	if field_value is Dictionary:
		(field_value as Dictionary).clear()


func _resume_skill_cooldowns_for_choice(runtime_state: Object) -> void:
	var helper: Object = _get_state_object(runtime_state, "_skill_cooldown_pause")
	if helper != null and helper.has_method("resume_from_runtime_state"):
		helper.resume_from_runtime_state(runtime_state)
	elif helper != null and helper.has_method("resume"):
		helper.resume()


func _reset_starpoint_absorption(runtime_state: Object) -> void:
	var helper: Object = _get_state_object(runtime_state, "_starpoint_absorption")
	if helper != null and helper.has_method("reset"):
		helper.reset()


func _reset_active_unlock_flight(runtime_state: Object) -> void:
	var helper: Object = _get_state_object(runtime_state, "_active_unlock_flight")
	if helper != null and helper.has_method("reset"):
		helper.reset(_get_state_dict(runtime_state, "choice_flight_effect"))


func _reset_unlock_showcase(runtime_state: Object) -> void:
	var helper: Object = _get_state_object(runtime_state, "_unlock_showcase_controller")
	if helper != null and helper.has_method("reset"):
		helper.reset(_get_state_dict(runtime_state, "unlock_showcase"))


func _reset_deferred_instants(runtime_state: Object) -> void:
	var helper: Object = _get_state_object(runtime_state, "_deferred_instants")
	if helper != null and helper.has_method("reset"):
		helper.reset()


func _reset_resume_safety(runtime_state: Object) -> void:
	var helper: Object = _get_state_object(runtime_state, "_resume_safety")
	if helper != null and helper.has_method("reset"):
		helper.reset()


func _get_state_object(runtime_state: Object, field_name: String) -> Object:
	if runtime_state == null:
		return null
	var value: Variant = runtime_state.get(field_name)
	if value is Object:
		return value
	return null


func _get_state_dict(runtime_state: Object, field_name: String) -> Dictionary:
	if runtime_state == null:
		return {}
	var value: Variant = runtime_state.get(field_name)
	if value is Dictionary:
		return value
	return {}
