extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")


func sync_owner_from_runtime_state(runtime_state: Object, owner: Object, owner_projection: Object = null) -> void:
	if runtime_state == null:
		return
	var projection: Object = owner_projection
	if projection == null:
		projection = RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_owner_projection")
	sync_owner(
		owner,
		projection,
		RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "runtime_skill_levels"),
		RuntimePerkRuntimeStateAccess.call_dict(runtime_state, "get_effective_runtime_skill_levels"),
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "pending_skill_choices"),
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "starpoint_for_skills"),
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "gold_from_perks"),
		RuntimePerkRuntimeStateAccess.call_bool(runtime_state, "is_choice_active"),
		RuntimePerkRuntimeStateAccess.get_int(runtime_state, "item_perk_level_bonus"),
		RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "viper_ignition_aura_active")
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
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_owner_effect_sync"),
		RuntimePerkRuntimeStateAccess.call_dict(runtime_state, "get_effective_runtime_skill_levels"),
		RuntimePerkRuntimeStateAccess.call_int(runtime_state, "get_accessory_slot_bonus"),
		RuntimePerkRuntimeStateAccess.call_int(runtime_state, "get_laurel_leaf_count", [registry]),
		RuntimePerkRuntimeStateAccess.call_float(runtime_state, "get_player_paddle_size_multiplier"),
		RuntimePerkRuntimeStateAccess.call_float(runtime_state, "get_player_skill_cooldown_multiplier"),
		RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_get_instance"),
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
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_owner_effect_sync"),
		RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_get_instance")
	)


func refresh_mythic_runtime_perk_consumers_from_runtime_state(
	runtime_state: Object,
	owner: Object,
	registry: Object
) -> void:
	refresh_mythic_runtime_perk_consumers(
		owner,
		registry,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_owner_effect_sync"),
		RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_get_instance")
	)


func apply_training_to_skill_configs_from_runtime_state(
	runtime_state: Object,
	registry: Object
) -> void:
	apply_training_to_skill_configs(
		registry,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_owner_effect_sync"),
		RuntimePerkRuntimeStateAccess.call_float(runtime_state, "get_player_skill_cooldown_multiplier", [], 1.0),
		RuntimePerkRuntimeStateAccess.build_callable(runtime_state, "_get_instance")
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


func _missing_instance(_registry: Object, _key: String) -> Object:
	return null
