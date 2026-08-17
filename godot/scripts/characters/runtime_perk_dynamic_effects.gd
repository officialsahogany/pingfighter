extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

const RuntimePerkCallbackMap := preload("res://scripts/characters/runtime_perk_callback_map.gd")

const CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS := "sync_runtime_perk_owner_effects"
const CALLBACK_APPLY_TRAINING_TO_SKILL_CONFIGS := "apply_training_to_skill_configs"
const CALLBACK_REFRESH_ITEM_POLISH_CONSUMERS := "refresh_item_polish_consumers"


func build_state_callbacks(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {}
	return {
		CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_sync_runtime_perk_owner_effects"),
		CALLBACK_APPLY_TRAINING_TO_SKILL_CONFIGS: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_apply_training_to_skill_configs"),
		CALLBACK_REFRESH_ITEM_POLISH_CONSUMERS: RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_refresh_item_polish_consumers"),
	}


func set_viper_ignition_aura_active_from_runtime_state(
	runtime_state: Object,
	active: bool
) -> Dictionary:
	return set_viper_ignition_aura_active(
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_effective_levels"),
		runtime_state,
		active
	)


func is_viper_ignition_aura_active_from_runtime_state(runtime_state: Object) -> bool:
	if runtime_state == null:
		return false
	return bool(RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "viper_ignition_aura_active"))


func set_viper_ignition_aura_active(
	effective_levels: Object,
	runtime_state: Object,
	active: bool
) -> Dictionary:
	if effective_levels == null or not effective_levels.has_method("build_viper_ignition_aura_active_update"):
		return {"accepted": false, "blocked_reason": "missing_effective_levels"}
	var update: Dictionary = effective_levels.build_viper_ignition_aura_active_update(
		bool(RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "viper_ignition_aura_active")) if runtime_state != null else false,
		active
	)
	return _apply_viper_ignition_aura_active_update(effective_levels, runtime_state, update)


func set_item_perk_level_bonus_from_runtime_state(
	runtime_state: Object,
	bonus: int
) -> Dictionary:
	return set_item_perk_level_bonus(
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_effective_levels"),
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
		int(RuntimePerkRuntimeStateAccess.get_int(runtime_state, "item_perk_level_bonus")) if runtime_state != null else 0,
		bonus
	)
	return _apply_item_perk_level_bonus_update(effective_levels, runtime_state, update)


func get_item_perk_level_bonus_from_runtime_state(runtime_state: Object) -> int:
	if runtime_state == null:
		return 0
	return int(RuntimePerkRuntimeStateAccess.get_int(runtime_state, "item_perk_level_bonus"))


func refresh_viper_ignition_aura_dynamic_effects_from_runtime_state(
	runtime_state: Object,
	registry: Object,
	owner: Object = null
) -> Dictionary:
	return refresh_viper_ignition_aura_dynamic_effects(
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_effective_levels"),
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
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_effective_levels"),
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
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_effective_levels"),
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
			bool(RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "viper_ignition_aura_owner_sync_dirty")) if runtime_state != null else false,
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
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS, [owner, registry])
	if bool(plan.get("apply_training", false)):
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_APPLY_TRAINING_TO_SKILL_CONFIGS, [registry])
	var state_result: Dictionary = effective_levels.apply_dynamic_effect_refresh_state_update(runtime_state, plan)
	if bool(plan.get("refresh_consumers", false)):
		RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_REFRESH_ITEM_POLISH_CONSUMERS, [owner, registry])
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
