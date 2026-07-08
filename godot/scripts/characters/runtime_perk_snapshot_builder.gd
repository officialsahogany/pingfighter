extends RefCounted

const RuntimePerkChoiceCompletion := preload("res://scripts/characters/runtime_perk_choice_completion.gd")

var _choice_completion: Object = RuntimePerkChoiceCompletion.new()


func build(state: Object, starpoint_absorption: Object, deferred_instants: Object) -> Dictionary:
	if state == null:
		return {}
	return {
		"runtime_skill_levels": _duplicate_dict_property(state, "runtime_skill_levels"),
		"effective_runtime_skill_levels": _call_dict(state, "get_effective_runtime_skill_levels"),
		"starpoint_for_skills": int(state.get("starpoint_for_skills")),
		"pending_skill_choices": int(state.get("pending_skill_choices")),
		"choice_active": bool(state.get("choice_active")),
		"current_choices": _duplicate_array_property(state, "current_choices"),
		"selected_index": int(state.get("selected_index")),
		"animation_time": float(state.get("animation_time")),
		"particles": _get_array(state.get("particles")),
		"gold_from_perks": int(state.get("gold_from_perks")),
		"item_gold_gain_multiplier": float(state.get("item_gold_gain_multiplier")),
		"item_perk_level_bonus": int(state.get("item_perk_level_bonus")),
		"viper_ignition_aura_active": bool(state.get("viper_ignition_aura_active")),
		"viper_ignition_aura_level_bonus": _call_int(state, "get_viper_ignition_aura_level_bonus"),
		"viper_ignition_aura_gold_bonus": _call_int(state, "get_viper_ignition_aura_gold_bonus"),
		"pending_unlock_swap": _duplicate_dict_property(state, "pending_unlock_swap"),
		"unlock_swap_selected_index": int(state.get("unlock_swap_selected_index")),
		"choice_flight_effect": _duplicate_dict_property(state, "choice_flight_effect"),
		"unlock_showcase": _duplicate_dict_property(state, "unlock_showcase"),
		"starpoint_absorption_effect": _get_external_snapshot(starpoint_absorption),
		"feedback_text": _get_string_property(state, "feedback_text"),
		"feedback_timer": float(state.get("feedback_timer")),
		"last_selected_id": _get_string_property(state, "last_selected_id"),
		"last_selected_choice": _duplicate_dict_property(state, "last_selected_choice"),
		"selected_choice_sequence": int(state.get("selected_choice_sequence")),
		"current_choice_context": _duplicate_dict_property(state, "current_choice_context"),
		"perk_slot_status": _duplicate_dict_property(state, "current_perk_slot_status"),
		"pending_dimension_gate_after_spawn_intro": _call_bool(deferred_instants, "has_pending_dimension_gate"),
		"pending_dimension_gate_origin_stage": _call_int(deferred_instants, "get_dimension_gate_origin_stage"),
		"pending_full_gauge_after_spawn_intro": _call_bool(deferred_instants, "has_pending_full_gauge"),
		"pending_full_gauge_origin_stage": _call_int(deferred_instants, "get_full_gauge_origin_stage"),
	}


func build_from_runtime_state(runtime_state: Object) -> Dictionary:
	return build(
		runtime_state,
		_get_runtime_state_object(runtime_state, "_starpoint_absorption"),
		_get_runtime_state_object(runtime_state, "_deferred_instants")
	)


func build_selected_choice(choice_id: String, choice: Dictionary, runtime_skill_levels: Dictionary) -> Dictionary:
	return _choice_completion.build_selected_choice_snapshot(choice_id, choice, runtime_skill_levels)


func _duplicate_dict_property(source: Object, property: String) -> Dictionary:
	return _get_dict(source.get(property)).duplicate(true)


func _duplicate_array_property(source: Object, property: String) -> Array:
	return _get_array(source.get(property)).duplicate(true)


func _get_external_snapshot(source: Object) -> Dictionary:
	if source == null or not source.has_method("get_snapshot"):
		return {}
	var value: Variant = source.call("get_snapshot")
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _get_runtime_state_object(runtime_state: Object, key: String) -> Object:
	if runtime_state == null:
		return null
	var value: Variant = runtime_state.get(key)
	if value is Object:
		return value
	return null


func _call_dict(source: Object, method: String) -> Dictionary:
	if source == null or not source.has_method(method):
		return {}
	var value: Variant = source.call(method)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _call_int(source: Object, method: String) -> int:
	if source == null or not source.has_method(method):
		return 0
	return int(source.call(method))


func _call_bool(source: Object, method: String) -> bool:
	if source == null or not source.has_method(method):
		return false
	return bool(source.call(method))


func _get_string_property(source: Object, property: String) -> String:
	var value: Variant = source.get(property)
	if value == null:
		return ""
	return str(value)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
