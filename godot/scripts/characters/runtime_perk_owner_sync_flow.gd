extends RefCounted


func sync_owner_from_runtime_state(runtime_state: Object, owner: Object, owner_projection: Object = null) -> void:
	if runtime_state == null:
		return
	var projection: Object = owner_projection
	if projection == null:
		projection = _get_state_object(runtime_state, "_owner_projection")
	sync_owner(
		owner,
		projection,
		_get_state_dict(runtime_state, "runtime_skill_levels"),
		_call_state_dict(runtime_state, "get_effective_runtime_skill_levels"),
		_get_state_int(runtime_state, "pending_skill_choices"),
		_get_state_int(runtime_state, "starpoint_for_skills"),
		_get_state_int(runtime_state, "gold_from_perks"),
		_call_state_bool(runtime_state, "is_choice_active"),
		_get_state_int(runtime_state, "item_perk_level_bonus"),
		_get_state_bool(runtime_state, "viper_ignition_aura_active")
	)


func sync_owner(
	owner: Object,
	owner_projection: Object,
	runtime_skill_levels: Dictionary,
	effective_runtime_skill_levels: Dictionary,
	pending_skill_choices: int,
	starpoint_for_skills: int,
	gold_from_perks: int,
	choice_active: bool,
	item_perk_level_bonus: int,
	viper_ignition_aura_active: bool
) -> void:
	if owner_projection == null:
		return
	var state: Dictionary = owner_projection.build_state(
		runtime_skill_levels,
		effective_runtime_skill_levels,
		pending_skill_choices,
		starpoint_for_skills,
		gold_from_perks,
		choice_active,
		item_perk_level_bonus,
		viper_ignition_aura_active
	)
	owner_projection.sync_owner(owner, state)


func sync_owner_effects_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	perf_logger: Object = null
) -> void:
	if runtime_state == null:
		return
	sync_owner_effects(
		owner,
		registry,
		_get_state_object(runtime_state, "_owner_effect_sync"),
		_call_state_dict(runtime_state, "get_effective_runtime_skill_levels"),
		_call_state_int(runtime_state, "get_accessory_slot_bonus"),
		_call_state_int(runtime_state, "get_laurel_leaf_count", [registry]),
		_call_state_float(runtime_state, "get_player_paddle_size_multiplier"),
		_call_state_float(runtime_state, "get_player_skill_cooldown_multiplier"),
		_build_runtime_state_get_instance(runtime_state),
		perf_logger
	)


func sync_owner_effects(
	owner: Object,
	registry: Object,
	owner_effect_sync: Object,
	effective_runtime_skill_levels: Dictionary,
	accessory_slot_bonus: int,
	laurel_leaf_count: int,
	player_paddle_size_multiplier: float,
	player_skill_cooldown_multiplier: float,
	get_instance: Callable,
	perf_logger: Object = null
) -> void:
	if owner_effect_sync == null:
		return
	var context: Dictionary = owner_effect_sync.build_sync_context(
		effective_runtime_skill_levels,
		accessory_slot_bonus,
		laurel_leaf_count,
		player_paddle_size_multiplier,
		player_skill_cooldown_multiplier
	)
	owner_effect_sync.sync_owner_effects(owner, registry, context, get_instance, perf_logger)


func refresh_item_polish_consumers(
	owner: Object,
	registry: Object,
	owner_effect_sync: Object,
	get_instance: Callable
) -> void:
	if owner_effect_sync != null:
		owner_effect_sync.refresh_item_polish_consumers(owner, registry, get_instance)


func refresh_mythic_runtime_perk_consumers(
	owner: Object,
	registry: Object,
	owner_effect_sync: Object,
	get_instance: Callable
) -> void:
	if owner_effect_sync != null:
		owner_effect_sync.refresh_mythic_runtime_perk_consumers(owner, registry, get_instance)


func refresh_item_polish_consumers_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object
) -> void:
	refresh_item_polish_consumers(
		owner,
		registry,
		_get_state_object(runtime_state, "_owner_effect_sync"),
		_build_runtime_state_get_instance(runtime_state)
	)


func refresh_mythic_runtime_perk_consumers_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object
) -> void:
	refresh_mythic_runtime_perk_consumers(
		owner,
		registry,
		_get_state_object(runtime_state, "_owner_effect_sync"),
		_build_runtime_state_get_instance(runtime_state)
	)


func apply_training_to_skill_configs_from_runtime_state(
	runtime_state: Object,
	registry: Object
) -> void:
	apply_training_to_skill_configs(
		registry,
		_get_state_object(runtime_state, "_owner_effect_sync"),
		_call_state_float(runtime_state, "get_player_skill_cooldown_multiplier", [], 1.0),
		_build_runtime_state_get_instance(runtime_state)
	)


func apply_training_to_skill_configs(
	registry: Object,
	owner_effect_sync: Object,
	player_skill_cooldown_multiplier: float,
	get_instance: Callable
) -> void:
	if owner_effect_sync != null:
		owner_effect_sync.apply_training_to_skill_configs(
			registry,
			player_skill_cooldown_multiplier,
			get_instance
		)


func _get_state_dict(runtime_state: Object, key: String) -> Dictionary:
	if runtime_state == null:
		return {}
	var value: Variant = runtime_state.get(key)
	if value is Dictionary:
		return value
	return {}


func _get_state_int(runtime_state: Object, key: String) -> int:
	if runtime_state == null:
		return 0
	return int(runtime_state.get(key))


func _get_state_bool(runtime_state: Object, key: String) -> bool:
	if runtime_state == null:
		return false
	return bool(runtime_state.get(key))


func _get_state_object(runtime_state: Object, key: String) -> Object:
	if runtime_state == null:
		return null
	var value: Variant = runtime_state.get(key)
	if value is Object:
		return value
	return null


func _build_runtime_state_get_instance(runtime_state: Object) -> Callable:
	if runtime_state != null and runtime_state.has_method("_get_instance"):
		return Callable(runtime_state, "_get_instance")
	return Callable(self, "_missing_instance")


func _missing_instance(_registry: Object, _key: String) -> Object:
	return null


func _call_state_dict(runtime_state: Object, method_name: String, args: Array = []) -> Dictionary:
	var value: Variant = _call_state_value(runtime_state, method_name, args, {})
	if value is Dictionary:
		return value
	return {}


func _call_state_int(runtime_state: Object, method_name: String, args: Array = [], fallback: int = 0) -> int:
	return int(_call_state_value(runtime_state, method_name, args, fallback))


func _call_state_float(runtime_state: Object, method_name: String, args: Array = [], fallback: float = 1.0) -> float:
	return float(_call_state_value(runtime_state, method_name, args, fallback))


func _call_state_bool(runtime_state: Object, method_name: String, args: Array = [], fallback: bool = false) -> bool:
	return bool(_call_state_value(runtime_state, method_name, args, fallback))


func _call_state_value(runtime_state: Object, method_name: String, args: Array, fallback: Variant) -> Variant:
	if runtime_state == null or not runtime_state.has_method(method_name):
		return fallback
	return runtime_state.callv(method_name, args)
