extends RefCounted


func get_runtime_skill_level_from_runtime_state(runtime_state: Object, skill_id: String) -> int:
	return get_runtime_skill_level(_get_effective_levels(runtime_state), runtime_state, skill_id)


func get_converted_perk_effect_level_from_runtime_state(runtime_state: Object, perk_id: String) -> int:
	return get_converted_perk_effect_level(_get_effective_levels(runtime_state), runtime_state, perk_id)


func get_effective_runtime_skill_levels_from_runtime_state(runtime_state: Object) -> Dictionary:
	return get_effective_runtime_skill_levels(_get_effective_levels(runtime_state), runtime_state)


func get_runtime_skill_bonus_from_runtime_state(runtime_state: Object, skill_id: String) -> float:
	return get_runtime_skill_bonus(_get_effective_levels(runtime_state), runtime_state, skill_id)


func get_perk_amplify_multiplier_from_runtime_state(runtime_state: Object, skill_id: String) -> float:
	return get_perk_amplify_multiplier(_get_effective_levels(runtime_state), runtime_state, skill_id)


func get_combo_amplifier_chip_bonus_from_runtime_state(runtime_state: Object) -> Dictionary:
	return get_combo_amplifier_chip_bonus(_get_effective_levels(runtime_state), runtime_state)


func get_dash_recharge_frames_from_runtime_state(runtime_state: Object, base_frames: float) -> float:
	return get_dash_recharge_frames(_get_effective_levels(runtime_state), runtime_state, base_frames)


func get_dash_recovery_frames_from_runtime_state(runtime_state: Object, base_frames: float) -> float:
	return get_dash_recovery_frames(_get_effective_levels(runtime_state), runtime_state, base_frames)


func get_dash_duration_frames_from_runtime_state(runtime_state: Object, base_frames: float) -> float:
	return get_dash_duration_frames(_get_effective_levels(runtime_state), runtime_state, base_frames)


func get_item_spawn_delay_msec_from_runtime_state(runtime_state: Object, base_delay_msec: int) -> int:
	return get_item_spawn_delay_msec(_get_effective_levels(runtime_state), runtime_state, base_delay_msec)


func get_active_item_cooldown_msec_from_runtime_state(runtime_state: Object, base_cooldown_msec: int) -> int:
	return get_active_item_cooldown_msec(_get_effective_levels(runtime_state), runtime_state, base_cooldown_msec)


func get_active_item_use_gauge_bonus_from_runtime_state(runtime_state: Object) -> float:
	return get_active_item_use_gauge_bonus(_get_effective_levels(runtime_state), runtime_state)


func get_active_item_slot_capacity_from_runtime_state(runtime_state: Object, base_slots: int) -> int:
	return get_active_item_slot_capacity(_get_effective_levels(runtime_state), runtime_state, base_slots)


func get_active_item_duration_bonus_from_runtime_state(runtime_state: Object) -> float:
	return get_active_item_duration_bonus(_get_effective_levels(runtime_state), runtime_state)


func get_active_item_duration_multiplier_from_runtime_state(runtime_state: Object) -> float:
	return get_active_item_duration_multiplier(_get_effective_levels(runtime_state), runtime_state)


func get_active_item_duration_frames_from_runtime_state(runtime_state: Object, base_duration_frames: float) -> float:
	return get_active_item_duration_frames(_get_effective_levels(runtime_state), runtime_state, base_duration_frames)


func get_active_item_recycle_chance_from_runtime_state(runtime_state: Object) -> float:
	return get_active_item_recycle_chance(_get_effective_levels(runtime_state), runtime_state)


func get_effective_polish_multiplier_from_runtime_state(runtime_state: Object) -> float:
	return get_effective_polish_multiplier(_get_effective_levels(runtime_state), runtime_state)


func get_base_polish_multiplier_from_runtime_state(runtime_state: Object) -> float:
	return get_base_polish_multiplier(_get_effective_levels(runtime_state), runtime_state)


func get_downtown_treasure_map_field_mythic_bonus_from_runtime_state(runtime_state: Object) -> float:
	return get_downtown_treasure_map_field_mythic_bonus(_get_effective_levels(runtime_state), runtime_state)


func get_downtown_treasure_map_field_mythic_multiplier_from_runtime_state(runtime_state: Object) -> float:
	return get_downtown_treasure_map_field_mythic_multiplier(_get_effective_levels(runtime_state), runtime_state)


func get_downtown_treasure_map_passive_drop_share_bonus_from_runtime_state(runtime_state: Object) -> float:
	return get_downtown_treasure_map_passive_drop_share_bonus(_get_effective_levels(runtime_state), runtime_state)


func get_treasure_hunt_legendary_chance_bonus_from_runtime_state(runtime_state: Object) -> float:
	return get_treasure_hunt_legendary_chance_bonus(_get_effective_levels(runtime_state), runtime_state)


func get_treasure_hunt_legendary_chance_from_runtime_state(runtime_state: Object, base_chance: float) -> float:
	return get_treasure_hunt_legendary_chance(_get_effective_levels(runtime_state), runtime_state, base_chance)


func get_player_speed_multiplier_from_runtime_state(runtime_state: Object) -> float:
	return get_player_speed_multiplier(_get_effective_levels(runtime_state), runtime_state)


func get_player_paddle_size_multiplier_from_runtime_state(runtime_state: Object) -> float:
	return get_player_paddle_size_multiplier(_get_effective_levels(runtime_state), runtime_state)


func get_accessory_slot_bonus_from_runtime_state(runtime_state: Object) -> int:
	return get_accessory_slot_bonus(_get_effective_levels(runtime_state), runtime_state)


func get_player_skill_cooldown_multiplier_from_runtime_state(runtime_state: Object) -> float:
	return get_player_skill_cooldown_multiplier(_get_effective_levels(runtime_state), runtime_state)


func get_player_skill_cooldown_seconds_from_runtime_state(runtime_state: Object, base_cooldown_seconds: float) -> float:
	return get_player_skill_cooldown_seconds(_get_effective_levels(runtime_state), runtime_state, base_cooldown_seconds)


func get_boost_charge_chance_pct_from_runtime_state(runtime_state: Object) -> float:
	return get_boost_charge_chance_pct(_get_effective_levels(runtime_state), runtime_state)


func get_dash_acceleration_level_from_runtime_state(runtime_state: Object) -> int:
	return get_dash_acceleration_level(_get_effective_levels(runtime_state), runtime_state)


func get_dash_acceleration_bonus_from_runtime_state(runtime_state: Object) -> float:
	return get_dash_acceleration_bonus(_get_effective_levels(runtime_state), runtime_state)


func get_dash_acceleration_height_bonus_from_runtime_state(runtime_state: Object, base_height: float) -> float:
	return get_dash_acceleration_height_bonus(_get_effective_levels(runtime_state), runtime_state, base_height)


func get_viper_ignition_aura_level_bonus_from_runtime_state(runtime_state: Object) -> int:
	var effective_levels: Object = _get_effective_levels(runtime_state)
	if effective_levels == null or not effective_levels.has_method("get_viper_ignition_aura_level_bonus"):
		return 0
	return int(effective_levels.get_viper_ignition_aura_level_bonus(_is_viper_ignition_aura_active(runtime_state)))


func is_runtime_level_bonus_eligible_from_runtime_state(
	runtime_state: Object,
	skill_id: String,
	base_level: int
) -> bool:
	var effective_levels: Object = _get_effective_levels(runtime_state)
	if effective_levels == null or not effective_levels.has_method("is_runtime_level_bonus_eligible"):
		return false
	return bool(effective_levels.is_runtime_level_bonus_eligible(skill_id, base_level))


func is_ignition_aura_level_bonus_eligible_from_runtime_state(
	runtime_state: Object,
	skill_id: String,
	base_level: int
) -> bool:
	var effective_levels: Object = _get_effective_levels(runtime_state)
	if effective_levels == null or not effective_levels.has_method("is_ignition_aura_level_bonus_eligible"):
		return false
	return bool(effective_levels.is_ignition_aura_level_bonus_eligible(
		_is_viper_ignition_aura_active(runtime_state),
		skill_id,
		base_level
	))


func get_runtime_skill_level(effective_levels: Object, runtime_state: Object, skill_id: String) -> int:
	if effective_levels == null or not effective_levels.has_method("get_runtime_skill_level"):
		return 0
	return int(effective_levels.get_runtime_skill_level(
		_get_runtime_skill_levels(runtime_state),
		_get_item_perk_level_bonus(runtime_state),
		_is_viper_ignition_aura_active(runtime_state),
		skill_id
	))


func get_converted_perk_effect_level(effective_levels: Object, runtime_state: Object, perk_id: String) -> int:
	if effective_levels == null or not effective_levels.has_method("get_converted_perk_effect_level"):
		return 0
	return int(effective_levels.get_converted_perk_effect_level(
		_get_runtime_skill_levels(runtime_state),
		_get_item_perk_level_bonus(runtime_state),
		_is_viper_ignition_aura_active(runtime_state),
		perk_id
	))


func get_effective_runtime_skill_levels(effective_levels: Object, runtime_state: Object) -> Dictionary:
	if effective_levels == null or not effective_levels.has_method("get_effective_runtime_skill_levels"):
		return {}
	return effective_levels.get_effective_runtime_skill_levels(
		_get_runtime_skill_levels(runtime_state),
		_get_item_perk_level_bonus(runtime_state),
		_is_viper_ignition_aura_active(runtime_state)
	)


func get_runtime_skill_bonus(effective_levels: Object, runtime_state: Object, skill_id: String) -> float:
	if effective_levels == null or not effective_levels.has_method("get_runtime_skill_bonus"):
		return 0.0
	return float(effective_levels.get_runtime_skill_bonus(
		_get_runtime_skill_levels(runtime_state),
		_get_item_perk_level_bonus(runtime_state),
		_is_viper_ignition_aura_active(runtime_state),
		skill_id
	))


func get_perk_amplify_multiplier(effective_levels: Object, runtime_state: Object, skill_id: String) -> float:
	if effective_levels == null or not effective_levels.has_method("get_perk_amplify_multiplier"):
		return 1.0
	return float(effective_levels.get_perk_amplify_multiplier(
		_get_runtime_skill_levels(runtime_state),
		skill_id
	))


func get_combo_amplifier_chip_bonus(effective_levels: Object, runtime_state: Object) -> Dictionary:
	if effective_levels == null or not effective_levels.has_method("get_combo_amplifier_chip_bonus"):
		return {"drive_speed": 0.0, "drive_curve": 0.0, "smash_speed": 0.0}
	return effective_levels.get_combo_amplifier_chip_bonus(
		_get_runtime_skill_levels(runtime_state),
		_get_item_perk_level_bonus(runtime_state),
		_is_viper_ignition_aura_active(runtime_state)
	)


func get_dash_recharge_frames(effective_levels: Object, runtime_state: Object, base_frames: float) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_dash_recharge_frames", [base_frames], float(base_frames))


func get_dash_recovery_frames(effective_levels: Object, runtime_state: Object, base_frames: float) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_dash_recovery_frames", [base_frames], float(base_frames))


func get_dash_duration_frames(effective_levels: Object, runtime_state: Object, base_frames: float) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_dash_duration_frames", [base_frames], float(base_frames))


func get_item_spawn_delay_msec(effective_levels: Object, runtime_state: Object, base_delay_msec: int) -> int:
	return int(_call_effective_float(effective_levels, runtime_state, "get_item_spawn_delay_msec", [base_delay_msec], float(max(0, base_delay_msec))))


func get_active_item_cooldown_msec(effective_levels: Object, runtime_state: Object, base_cooldown_msec: int) -> int:
	return int(_call_effective_float(effective_levels, runtime_state, "get_active_item_cooldown_msec", [base_cooldown_msec], float(max(0, base_cooldown_msec))))


func get_active_item_use_gauge_bonus(effective_levels: Object, runtime_state: Object) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_active_item_use_gauge_bonus", [], 0.0)


func get_active_item_slot_capacity(effective_levels: Object, runtime_state: Object, base_slots: int) -> int:
	return int(_call_effective_float(effective_levels, runtime_state, "get_active_item_slot_capacity", [base_slots], float(max(1, base_slots))))


func get_active_item_duration_bonus(effective_levels: Object, runtime_state: Object) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_active_item_duration_bonus", [], 0.0)


func get_active_item_duration_multiplier(effective_levels: Object, runtime_state: Object) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_active_item_duration_multiplier", [], 1.0)


func get_active_item_duration_frames(effective_levels: Object, runtime_state: Object, base_duration_frames: float) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_active_item_duration_frames", [base_duration_frames], max(0.0, float(base_duration_frames)))


func get_active_item_recycle_chance(effective_levels: Object, runtime_state: Object) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_active_item_recycle_chance", [], 0.0)


func get_effective_polish_multiplier(effective_levels: Object, runtime_state: Object) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_effective_polish_multiplier", [], 1.0)


func get_base_polish_multiplier(effective_levels: Object, runtime_state: Object) -> float:
	if effective_levels == null or not effective_levels.has_method("get_base_polish_multiplier"):
		return 1.0
	return float(effective_levels.get_base_polish_multiplier(_get_runtime_skill_levels(runtime_state)))


func get_downtown_treasure_map_field_mythic_bonus(effective_levels: Object, runtime_state: Object) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_downtown_treasure_map_field_mythic_bonus", [], 0.0)


func get_downtown_treasure_map_field_mythic_multiplier(effective_levels: Object, runtime_state: Object) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_downtown_treasure_map_field_mythic_multiplier", [], 1.0)


func get_downtown_treasure_map_passive_drop_share_bonus(effective_levels: Object, runtime_state: Object) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_downtown_treasure_map_passive_drop_share_bonus", [], 0.0)


func get_treasure_hunt_legendary_chance_bonus(effective_levels: Object, runtime_state: Object) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_treasure_hunt_legendary_chance_bonus", [], 0.0)


func get_treasure_hunt_legendary_chance(effective_levels: Object, runtime_state: Object, base_chance: float) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_treasure_hunt_legendary_chance", [base_chance], clamp(float(base_chance), 0.0, 1.0))


func get_player_speed_multiplier(effective_levels: Object, runtime_state: Object) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_player_speed_multiplier", [], 1.0)


func get_player_paddle_size_multiplier(effective_levels: Object, runtime_state: Object) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_player_paddle_size_multiplier", [], 1.0)


func get_accessory_slot_bonus(effective_levels: Object, runtime_state: Object) -> int:
	return int(_call_effective_float(effective_levels, runtime_state, "get_accessory_slot_bonus", [], 0.0))


func get_player_skill_cooldown_multiplier(effective_levels: Object, runtime_state: Object) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_player_skill_cooldown_multiplier", [], 1.0)


func get_player_skill_cooldown_seconds(effective_levels: Object, runtime_state: Object, base_cooldown_seconds: float) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_player_skill_cooldown_seconds", [base_cooldown_seconds], max(0.0, float(base_cooldown_seconds)))


func get_boost_charge_chance_pct(effective_levels: Object, runtime_state: Object) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_boost_charge_chance_pct", [], 0.0)


func get_dash_acceleration_level(effective_levels: Object, runtime_state: Object) -> int:
	return int(_call_effective_float(effective_levels, runtime_state, "get_dash_acceleration_level", [], 0.0))


func get_dash_acceleration_bonus(effective_levels: Object, runtime_state: Object) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_dash_acceleration_bonus", [], 0.0)


func get_dash_acceleration_height_bonus(effective_levels: Object, runtime_state: Object, base_height: float) -> float:
	return _call_effective_float(effective_levels, runtime_state, "get_dash_acceleration_height_bonus", [base_height], 0.0)


func get_laurel_leaf_count_from_runtime_state(runtime_state: Object, registry: Object = null) -> int:
	return get_laurel_leaf_count(
		_get_effective_levels(runtime_state),
		runtime_state,
		registry,
		_build_runtime_state_get_instance(runtime_state)
	)


func get_laurel_leaf_count(
	effective_levels: Object,
	runtime_state: Object,
	registry: Object = null,
	get_instance: Callable = Callable()
) -> int:
	if effective_levels == null or not effective_levels.has_method("get_laurel_leaf_count"):
		return _get_sacred_laurel_leaf_bonus(registry, get_instance)
	return int(effective_levels.get_laurel_leaf_count(
		_get_runtime_skill_levels(runtime_state),
		_get_item_perk_level_bonus(runtime_state),
		_is_viper_ignition_aura_active(runtime_state),
		_get_sacred_laurel_leaf_bonus(registry, get_instance)
	))


func _call_effective_float(
	effective_levels: Object,
	runtime_state: Object,
	method_name: String,
	extra_args: Array,
	fallback: float
) -> float:
	if effective_levels == null or not effective_levels.has_method(method_name):
		return fallback
	var args := [
		_get_runtime_skill_levels(runtime_state),
		_get_item_perk_level_bonus(runtime_state),
		_is_viper_ignition_aura_active(runtime_state),
	]
	args.append_array(extra_args)
	return float(effective_levels.callv(method_name, args))


func _get_sacred_laurel_leaf_bonus(registry: Object, get_instance: Callable) -> int:
	var runtime_value: Variant = null
	if get_instance.is_valid():
		runtime_value = get_instance.call(registry, "mythic_item_runtime")
	elif registry != null and registry.has_method("get_instance"):
		runtime_value = registry.get_instance("mythic_item_runtime")
	if not (runtime_value is Object):
		return 0
	var mythic_item_runtime: Object = runtime_value
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_sacred_laurel_leaf_bonus"):
		return max(0, int(mythic_item_runtime.get_sacred_laurel_leaf_bonus()))
	return 0


func _get_state_object(runtime_state: Object, key: String) -> Object:
	if runtime_state == null:
		return null
	var value: Variant = runtime_state.get(key)
	if value is Object:
		return value
	return null


func _get_effective_levels(runtime_state: Object) -> Object:
	return _get_state_object(runtime_state, "_effective_levels")


func _build_runtime_state_get_instance(runtime_state: Object) -> Callable:
	if runtime_state != null and runtime_state.has_method("_get_instance"):
		return Callable(runtime_state, "_get_instance")
	return Callable(self, "_missing_instance")


func _missing_instance(_registry: Object, _key: String) -> Object:
	return null


func _get_runtime_skill_levels(runtime_state: Object) -> Dictionary:
	if runtime_state == null:
		return {}
	var value: Variant = runtime_state.get("runtime_skill_levels")
	if value is Dictionary:
		return value
	return {}


func _get_item_perk_level_bonus(runtime_state: Object) -> int:
	if runtime_state == null:
		return 0
	return max(0, int(runtime_state.get("item_perk_level_bonus")))


func _is_viper_ignition_aura_active(runtime_state: Object) -> bool:
	if runtime_state == null:
		return false
	return bool(runtime_state.get("viper_ignition_aura_active"))
