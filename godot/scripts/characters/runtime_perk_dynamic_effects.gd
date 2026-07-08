extends RefCounted

const CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS := "sync_runtime_perk_owner_effects"
const CALLBACK_APPLY_TRAINING_TO_SKILL_CONFIGS := "apply_training_to_skill_configs"
const CALLBACK_REFRESH_ITEM_POLISH_CONSUMERS := "refresh_item_polish_consumers"


func build_state_callbacks(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {}
	return {
		CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS: Callable(runtime_state, "_sync_runtime_perk_owner_effects"),
		CALLBACK_APPLY_TRAINING_TO_SKILL_CONFIGS: Callable(runtime_state, "_apply_training_to_skill_configs"),
		CALLBACK_REFRESH_ITEM_POLISH_CONSUMERS: Callable(runtime_state, "_refresh_item_polish_consumers"),
	}


func set_viper_ignition_aura_active_from_runtime_state(
	runtime_state: Object,
	active: bool
) -> Dictionary:
	return set_viper_ignition_aura_active(
		_get_runtime_state_object(runtime_state, "_effective_levels"),
		runtime_state,
		active
	)


func is_viper_ignition_aura_active_from_runtime_state(runtime_state: Object) -> bool:
	if runtime_state == null:
		return false
	return bool(runtime_state.get("viper_ignition_aura_active"))


func set_viper_ignition_aura_active(
	effective_levels: Object,
	runtime_state: Object,
	active: bool
) -> Dictionary:
	if effective_levels == null or not effective_levels.has_method("build_viper_ignition_aura_active_update"):
		return {"accepted": false, "blocked_reason": "missing_effective_levels"}
	var update: Dictionary = effective_levels.build_viper_ignition_aura_active_update(
		bool(runtime_state.get("viper_ignition_aura_active")) if runtime_state != null else false,
		active
	)
	return _apply_viper_ignition_aura_active_update(effective_levels, runtime_state, update)


func set_item_perk_level_bonus_from_runtime_state(
	runtime_state: Object,
	bonus: int
) -> Dictionary:
	return set_item_perk_level_bonus(
		_get_runtime_state_object(runtime_state, "_effective_levels"),
		runtime_state,
		bonus
	)


func set_item_perk_level_bonus(
	effective_levels: Object,
	runtime_state: Object,
	bonus: int
) -> Dictionary:
	if effective_levels == null or not effective_levels.has_method("build_item_perk_level_bonus_update"):
		return {"accepted": false, "blocked_reason": "missing_effective_levels"}
	var update: Dictionary = effective_levels.build_item_perk_level_bonus_update(
		int(runtime_state.get("item_perk_level_bonus")) if runtime_state != null else 0,
		bonus
	)
	return _apply_item_perk_level_bonus_update(effective_levels, runtime_state, update)


func get_item_perk_level_bonus_from_runtime_state(runtime_state: Object) -> int:
	if runtime_state == null:
		return 0
	return int(runtime_state.get("item_perk_level_bonus"))


func refresh_viper_ignition_aura_dynamic_effects_from_runtime_state(
	runtime_state: Object,
	registry: Object,
	owner: Object = null
) -> Dictionary:
	return refresh_viper_ignition_aura_dynamic_effects(
		_get_runtime_state_object(runtime_state, "_effective_levels"),
		runtime_state,
		registry,
		owner,
		build_state_callbacks(runtime_state)
	)


func refresh_viper_ignition_aura_dynamic_effects(
	effective_levels: Object,
	runtime_state: Object,
	registry: Object,
	owner: Object,
	callbacks: Dictionary
) -> Dictionary:
	if effective_levels == null or not effective_levels.has_method("build_dynamic_effect_refresh_plan"):
		return {"accepted": false, "blocked_reason": "missing_effective_levels"}
	return apply_dynamic_effect_refresh_plan(
		effective_levels,
		runtime_state,
		effective_levels.build_dynamic_effect_refresh_plan(owner != null, true),
		registry,
		owner,
		callbacks
	)


func refresh_item_perk_level_bonus_dynamic_effects_from_runtime_state(
	runtime_state: Object,
	registry: Object,
	owner: Object = null
) -> Dictionary:
	return refresh_item_perk_level_bonus_dynamic_effects(
		_get_runtime_state_object(runtime_state, "_effective_levels"),
		runtime_state,
		registry,
		owner,
		build_state_callbacks(runtime_state)
	)


func refresh_item_perk_level_bonus_dynamic_effects(
	effective_levels: Object,
	runtime_state: Object,
	registry: Object,
	owner: Object,
	callbacks: Dictionary
) -> Dictionary:
	if effective_levels == null or not effective_levels.has_method("build_dynamic_effect_refresh_plan"):
		return {"accepted": false, "blocked_reason": "missing_effective_levels"}
	return apply_dynamic_effect_refresh_plan(
		effective_levels,
		runtime_state,
		effective_levels.build_dynamic_effect_refresh_plan(owner != null, false),
		registry,
		owner,
		callbacks
	)


func refresh_viper_ignition_aura_owner_sync_if_needed_from_runtime_state(
	runtime_state: Object,
	registry: Object,
	owner: Object
) -> Dictionary:
	return refresh_viper_ignition_aura_owner_sync_if_needed(
		_get_runtime_state_object(runtime_state, "_effective_levels"),
		runtime_state,
		registry,
		owner,
		build_state_callbacks(runtime_state)
	)


func refresh_viper_ignition_aura_owner_sync_if_needed(
	effective_levels: Object,
	runtime_state: Object,
	registry: Object,
	owner: Object,
	callbacks: Dictionary
) -> Dictionary:
	if effective_levels == null or not effective_levels.has_method("build_dirty_owner_sync_refresh_plan"):
		return {"accepted": false, "blocked_reason": "missing_effective_levels"}
	return apply_dynamic_effect_refresh_plan(
		effective_levels,
		runtime_state,
		effective_levels.build_dirty_owner_sync_refresh_plan(
			bool(runtime_state.get("viper_ignition_aura_owner_sync_dirty")) if runtime_state != null else false,
			owner != null
		),
		registry,
		owner,
		callbacks
	)


func apply_dynamic_effect_refresh_plan(
	effective_levels: Object,
	runtime_state: Object,
	plan: Dictionary,
	registry: Object,
	owner: Object,
	callbacks: Dictionary
) -> Dictionary:
	if effective_levels == null or not effective_levels.has_method("apply_dynamic_effect_refresh_state_update"):
		return {"accepted": false, "blocked_reason": "missing_effective_levels"}
	if bool(plan.get("sync_owner_effects", false)):
		_call_optional(callbacks, CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS, [owner, registry])
	if bool(plan.get("apply_training", false)):
		_call_optional(callbacks, CALLBACK_APPLY_TRAINING_TO_SKILL_CONFIGS, [registry])
	var state_result: Dictionary = effective_levels.apply_dynamic_effect_refresh_state_update(runtime_state, plan)
	if bool(plan.get("refresh_consumers", false)):
		_call_optional(callbacks, CALLBACK_REFRESH_ITEM_POLISH_CONSUMERS, [owner, registry])
	return {
		"accepted": bool(state_result.get("accepted", false)),
		"plan": plan.duplicate(true),
		"state_result": state_result,
	}


func _apply_viper_ignition_aura_active_update(
	effective_levels: Object,
	runtime_state: Object,
	update: Dictionary
) -> Dictionary:
	if effective_levels == null or not effective_levels.has_method("apply_viper_ignition_aura_active_update"):
		return {"accepted": false, "blocked_reason": "missing_effective_levels"}
	return effective_levels.apply_viper_ignition_aura_active_update(runtime_state, update)


func _apply_item_perk_level_bonus_update(
	effective_levels: Object,
	runtime_state: Object,
	update: Dictionary
) -> Dictionary:
	if effective_levels == null or not effective_levels.has_method("apply_item_perk_level_bonus_update"):
		return {"accepted": false, "blocked_reason": "missing_effective_levels"}
	return effective_levels.apply_item_perk_level_bonus_update(runtime_state, update)


func _call_optional(callbacks: Dictionary, key: String, args: Array) -> Dictionary:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return {"accepted": false, "blocked_reason": "missing_%s" % key}
	var result: Variant = callback.callv(args)
	if result is Dictionary:
		if result.has("accepted"):
			return result
		result["accepted"] = true
		return result
	return {"accepted": true}


func _get_callback(callbacks: Dictionary, key: String) -> Callable:
	var value: Variant = callbacks.get(key, Callable())
	if value is Callable:
		return value
	return Callable()


func _get_runtime_state_object(runtime_state: Object, key: String) -> Object:
	if runtime_state == null:
		return null
	var value: Variant = runtime_state.get(key)
	if value is Object:
		return value
	return null
