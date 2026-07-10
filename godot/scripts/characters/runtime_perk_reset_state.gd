extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")
const AngelBlessingRollOverlayHost := preload("res://scripts/hud/angel_blessing_roll_overlay_host.gd")


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
	_reset_mystic_dice(runtime_state)
	_reset_mystic_dice_paddle_effect(runtime_state)
	_reset_mystic_dice_modal(runtime_state)
	_reset_perk_fusion(runtime_state)
	_reset_perk_fusion_modal(runtime_state)
	_reset_perk_fusion_byproduct_runtime(runtime_state)
	_reset_angel_blessing(runtime_state)
	_reset_angel_blessing_modal(runtime_state)
	AngelBlessingRollOverlayHost.hide_all_existing_hosts()
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
		"pending_skill_choices": RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices"),
		"choice_active": RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "choice_active"),
		"feedback_timer": RuntimePerkRuntimeStateAccess.get_float(runtime_state, "feedback_timer"),
	}


func _clear_array_field(runtime_state: Object, field_name: String) -> void:
	RuntimePerkRuntimeStateAccess.get_array(runtime_state, field_name).clear()


func _clear_dictionary_field(runtime_state: Object, field_name: String) -> void:
	RuntimePerkRuntimeStateAccess.get_dict(runtime_state, field_name).clear()


func _resume_skill_cooldowns_for_choice(runtime_state: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_skill_cooldown_pause")
	if helper != null and helper.has_method("resume_from_runtime_state"):
		helper.resume_from_runtime_state(runtime_state)
	elif helper != null and helper.has_method("resume"):
		helper.resume()


func _reset_starpoint_absorption(runtime_state: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_starpoint_absorption")
	if helper != null and helper.has_method("reset"):
		helper.reset()


func _reset_active_unlock_flight(runtime_state: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_active_unlock_flight")
	if helper != null and helper.has_method("reset"):
		helper.reset(RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "choice_flight_effect"))


func _reset_unlock_showcase(runtime_state: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_unlock_showcase_controller")
	if helper != null and helper.has_method("reset"):
		helper.reset(RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "unlock_showcase"))


func _reset_deferred_instants(runtime_state: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_deferred_instants")
	if helper != null and helper.has_method("reset"):
		helper.reset()


func _reset_resume_safety(runtime_state: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_resume_safety")
	if helper != null and helper.has_method("reset"):
		helper.reset()


func _reset_mystic_dice(runtime_state: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "mystic_dice_state")
	if helper != null and helper.has_method("reset"):
		helper.reset()


func _reset_mystic_dice_paddle_effect(runtime_state: Object) -> void:
	if runtime_state != null and runtime_state.has_method("reset_mystic_dice_round_visuals"):
		runtime_state.call("reset_mystic_dice_round_visuals")
		return
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_mystic_dice_paddle_effect")
	if helper != null and helper.has_method("reset"):
		helper.reset()


func _reset_mystic_dice_modal(runtime_state: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_mystic_dice_modal_flow")
	if helper != null and helper.has_method("reset"):
		helper.reset()
	var input_helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_mystic_dice_modal_input")
	if input_helper != null and input_helper.has_method("reset"):
		input_helper.reset()
	RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "_mystic_dice_finished_choice_ids").clear()


func _reset_perk_fusion(runtime_state: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "perk_fusion_state")
	if helper != null and helper.has_method("reset"):
		helper.reset()


func _reset_perk_fusion_modal(runtime_state: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_perk_fusion_modal_flow")
	if helper != null and helper.has_method("reset"):
		helper.reset()
	var input_helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_perk_fusion_modal_input")
	if input_helper != null and input_helper.has_method("reset"):
		input_helper.reset()
	runtime_state.set("_perk_fusion_active_catalog", null)
	runtime_state.set("_perk_fusion_display_catalog", null)
	if runtime_state.has_method("reset_perk_fusion_display_caches"):
		runtime_state.reset_perk_fusion_display_caches()
	RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "_perk_fusion_finished_choice_ids").clear()


func _reset_perk_fusion_byproduct_runtime(runtime_state: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_perk_fusion_byproduct_runtime")
	if helper != null and helper.has_method("reset"):
		helper.reset()


func _reset_angel_blessing(runtime_state: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_angel_blessing_state")
	if helper != null and helper.has_method("reset"):
		helper.reset()


func _reset_angel_blessing_modal(runtime_state: Object) -> void:
	var helper: Object = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_angel_blessing_modal_flow")
	if helper != null and helper.has_method("reset"):
		helper.reset()
