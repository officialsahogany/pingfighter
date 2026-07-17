extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")
const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")
const RuntimePerkAngelBlessingProjection := preload("res://scripts/characters/runtime_perk_angel_blessing_projection.gd")


func get_runtime_skill_level_from_runtime_state(runtime_state: Object, skill_id: String) -> int:
	return get_runtime_skill_level(_get_effective_levels(runtime_state), runtime_state, skill_id)


func get_converted_perk_effect_level_from_runtime_state(runtime_state: Object, perk_id: String) -> int:
	return get_converted_perk_effect_level(_get_effective_levels(runtime_state), runtime_state, perk_id)


func get_effective_runtime_skill_levels_from_runtime_state(runtime_state: Object) -> Dictionary:
	return get_effective_runtime_skill_levels(_get_effective_levels(runtime_state), runtime_state)


func get_runtime_skill_bonus_from_runtime_state(runtime_state: Object, skill_id: String) -> float:
	return get_runtime_skill_bonus(_get_effective_levels(runtime_state), runtime_state, skill_id)


func get_runtime_skill_bonus_before_fusion_from_runtime_state(runtime_state: Object, skill_id: String) -> float:
	return get_runtime_skill_bonus(
		_get_effective_levels(runtime_state),
		runtime_state,
		skill_id,
		false
	)


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


func get_angel_blessing_special_gauge_max_from_runtime_state(runtime_state: Object, current_max: float) -> float:
	return RuntimePerkAngelBlessingProjection.apply_special_gauge_max(
		_get_angel_blessing_state(runtime_state),
		current_max
	)


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
	var base_level := int(effective_levels.get_runtime_skill_level(
		_get_runtime_skill_levels(runtime_state),
		_get_item_perk_level_bonus(runtime_state),
		_is_viper_ignition_aura_active(runtime_state),
		skill_id
	))
	if base_level <= 0:
		return 0
	return base_level + _get_fusion_effective_level_bonus(runtime_state, skill_id)


func get_converted_perk_effect_level(effective_levels: Object, runtime_state: Object, perk_id: String) -> int:
	if effective_levels == null or not effective_levels.has_method("get_converted_perk_effect_level"):
		return 0
	var base_level := int(effective_levels.get_converted_perk_effect_level(
		_get_runtime_skill_levels(runtime_state),
		_get_item_perk_level_bonus(runtime_state),
		_is_viper_ignition_aura_active(runtime_state),
		perk_id
	))
	if base_level <= 0:
		return 0
	return base_level + _get_fusion_effective_level_bonus(runtime_state, perk_id)


func get_effective_runtime_skill_levels(effective_levels: Object, runtime_state: Object) -> Dictionary:
	if effective_levels == null or not effective_levels.has_method("get_effective_runtime_skill_levels"):
		return {}
	var resolved_levels: Dictionary = effective_levels.get_effective_runtime_skill_levels(
		_get_runtime_skill_levels(runtime_state),
		_get_item_perk_level_bonus(runtime_state),
		_is_viper_ignition_aura_active(runtime_state)
	)
	for perk_id_value: Variant in resolved_levels.keys():
		var perk_id := str(perk_id_value)
		resolved_levels[perk_id_value] = int(resolved_levels.get(perk_id_value, 0)) + _get_fusion_effective_level_bonus(
			runtime_state,
			perk_id
		)
	return resolved_levels


func get_runtime_skill_bonus(
	effective_levels: Object,
	runtime_state: Object,
	skill_id: String,
	apply_fusion: bool = true
) -> float:
	if effective_levels == null or not effective_levels.has_method("get_runtime_skill_bonus"):
		return 0.0
	var levels: Dictionary = _get_runtime_skill_levels_with_fusion_bonus(runtime_state, skill_id)
	# The effective-level owner historically applies Polish internally from raw
	# levels. Remove it for this base read, then reapply the resolver-aware
	# Polish multiplier below so Polish limit break and fusion scars both reach
	# every production consumer.
	var unamplified_levels: Dictionary = levels
	if (
		skill_id.strip_edges() != RuntimePerkEffectiveLevels.ITEM_POLISH_ID
		and levels.has(RuntimePerkEffectiveLevels.ITEM_POLISH_ID)
	):
		# Runtime perk levels are a flat id->int map; a shallow copy avoids a
		# needless recursive duplication on the physics-tick Polish path.
		unamplified_levels = levels.duplicate()
		unamplified_levels[RuntimePerkEffectiveLevels.ITEM_POLISH_ID] = 0
	var base_bonus := float(effective_levels.get_runtime_skill_bonus(
		unamplified_levels,
		_get_item_perk_level_bonus(runtime_state),
		_is_viper_ignition_aura_active(runtime_state),
		skill_id
	))
	base_bonus *= get_perk_amplify_multiplier(effective_levels, runtime_state, skill_id)
	return _apply_fusion_skill_bonus(runtime_state, skill_id, base_bonus) if apply_fusion else base_bonus


func get_perk_amplify_multiplier(effective_levels: Object, runtime_state: Object, skill_id: String) -> float:
	if effective_levels == null or not effective_levels.has_method("get_perk_amplify_multiplier"):
		return 1.0
	var polish_level := get_runtime_skill_level(
		effective_levels,
		runtime_state,
		RuntimePerkEffectiveLevels.ITEM_POLISH_ID
	)
	var raw_multiplier := float(effective_levels.get_perk_amplify_multiplier(
		{RuntimePerkEffectiveLevels.ITEM_POLISH_ID: polish_level},
		skill_id
	))
	var raw_bonus := maxf(0.0, raw_multiplier - 1.0)
	var adjusted_bonus := _apply_fusion_skill_bonus(
		runtime_state,
		RuntimePerkEffectiveLevels.ITEM_POLISH_ID,
		raw_bonus
	)
	return 1.0 + maxf(0.0, adjusted_bonus)


func get_combo_amplifier_chip_bonus(effective_levels: Object, runtime_state: Object) -> Dictionary:
	if effective_levels == null or not effective_levels.has_method("get_combo_amplifier_chip_bonus"):
		return {"drive_speed": 0.0, "drive_curve": 0.0, "smash_speed": 0.0}
	return effective_levels.get_combo_amplifier_chip_bonus(
		_get_runtime_skill_levels(runtime_state),
		_get_item_perk_level_bonus(runtime_state),
		_is_viper_ignition_aura_active(runtime_state)
	)


func get_dash_recharge_frames(effective_levels: Object, runtime_state: Object, base_frames: float) -> float:
	var current_frames: float = maxf(
		RuntimePerkEffectiveLevels.MIN_DASH_RECHARGE_FRAMES,
		float(base_frames)
		* maxf(0.0, 1.0 - get_runtime_skill_bonus(effective_levels, runtime_state, "dash_lightweight"))
		* _get_mystic_dice_multiplier(runtime_state, "dash_cooldown")
	)
	return RuntimePerkAngelBlessingProjection.apply_dash_recharge_frames(
		_get_angel_blessing_state(runtime_state),
		current_frames
	)


func get_dash_recovery_frames(effective_levels: Object, runtime_state: Object, base_frames: float) -> float:
	return maxf(
		RuntimePerkEffectiveLevels.MIN_DASH_RECOVERY_FRAMES,
		float(base_frames)
		* maxf(0.0, 1.0 - get_runtime_skill_bonus(effective_levels, runtime_state, "dash_module_control"))
		* _get_mystic_dice_multiplier(runtime_state, "dash_recovery")
	)


func get_dash_duration_frames(effective_levels: Object, runtime_state: Object, base_frames: float) -> float:
	return maxf(
		1.0,
		float(base_frames) * (1.0 + get_runtime_skill_bonus(effective_levels, runtime_state, "dash_jump"))
	)


func get_item_spawn_delay_msec(effective_levels: Object, runtime_state: Object, base_delay_msec: int) -> int:
	var adjusted := float(maxi(0, base_delay_msec)) * maxf(
		0.0,
		1.0 - get_runtime_skill_bonus(effective_levels, runtime_state, "item_luck")
	)
	return maxi(RuntimePerkEffectiveLevels.MIN_ITEM_SPAWN_DELAY_MSEC, int(round(adjusted)))


func get_active_item_cooldown_msec(effective_levels: Object, runtime_state: Object, base_cooldown_msec: int) -> int:
	var adjusted := float(maxi(0, base_cooldown_msec)) * maxf(
		0.0,
		1.0 - get_runtime_skill_bonus(effective_levels, runtime_state, "item_cooldown_mastery")
	) * _get_mystic_dice_multiplier(runtime_state, "item_cooldown")
	return RuntimePerkAngelBlessingProjection.apply_active_item_cooldown_msec(
		_get_angel_blessing_state(runtime_state),
		maxi(0, int(round(adjusted)))
	)


func get_active_item_use_gauge_bonus(effective_levels: Object, runtime_state: Object) -> float:
	return maxf(0.0, get_runtime_skill_bonus(effective_levels, runtime_state, "item_gauge_mastery"))


func get_active_item_slot_capacity(effective_levels: Object, runtime_state: Object, base_slots: int) -> int:
	return maxi(
		1,
		base_slots + int(round(get_runtime_skill_bonus(effective_levels, runtime_state, "item_bag_expansion")))
	)


func get_active_item_duration_bonus(effective_levels: Object, runtime_state: Object) -> float:
	return maxf(0.0, get_runtime_skill_bonus(effective_levels, runtime_state, RuntimePerkEffectiveLevels.ITEM_CAFFEINE_ID))


func get_active_item_duration_multiplier(effective_levels: Object, runtime_state: Object) -> float:
	return 1.0 + get_active_item_duration_bonus(effective_levels, runtime_state)


func get_active_item_duration_frames(effective_levels: Object, runtime_state: Object, base_duration_frames: float) -> float:
	if base_duration_frames <= 0.0:
		return 0.0
	return maxf(
		1.0,
		float(int(base_duration_frames * get_active_item_duration_multiplier(effective_levels, runtime_state)))
	)


func get_active_item_recycle_chance(effective_levels: Object, runtime_state: Object) -> float:
	return clampf(
		get_runtime_skill_bonus(effective_levels, runtime_state, RuntimePerkEffectiveLevels.ITEM_RECYCLE_ID),
		0.0,
		RuntimePerkEffectiveLevels.MAX_ITEM_RECYCLE_CHANCE
	)


func get_effective_polish_multiplier(effective_levels: Object, runtime_state: Object) -> float:
	return 1.0 + maxf(
		0.0,
		get_runtime_skill_bonus(effective_levels, runtime_state, RuntimePerkEffectiveLevels.ITEM_POLISH_ID)
	)


func get_base_polish_multiplier(effective_levels: Object, runtime_state: Object) -> float:
	var base_level := maxi(0, int(_get_runtime_skill_levels(runtime_state).get(RuntimePerkEffectiveLevels.ITEM_POLISH_ID, 0)))
	var base_bonus := float(base_level) * RuntimePerkEffectiveLevels.ITEM_POLISH_ROLL_BONUS_PER_LEVEL
	return 1.0 + maxf(0.0, _apply_fusion_skill_bonus(runtime_state, RuntimePerkEffectiveLevels.ITEM_POLISH_ID, base_bonus))


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
	return RuntimePerkAngelBlessingProjection.apply_player_speed_multiplier(
		_get_angel_blessing_state(runtime_state),
		(1.0 + maxf(0.0, get_runtime_skill_bonus(effective_levels, runtime_state, "common_swiftness")))
		* _get_mystic_dice_multiplier(runtime_state, "player_speed")
	)


func get_player_paddle_size_multiplier(effective_levels: Object, runtime_state: Object) -> float:
	return RuntimePerkAngelBlessingProjection.apply_player_paddle_size_multiplier(
		_get_angel_blessing_state(runtime_state),
		maxf(
			0.1,
			(1.0 + get_runtime_skill_bonus(effective_levels, runtime_state, "common_bulk_up"))
			* _get_mystic_dice_multiplier(runtime_state, "paddle_size")
		)
	)


func get_accessory_slot_bonus(effective_levels: Object, runtime_state: Object) -> int:
	return maxi(0, int(round(get_runtime_skill_bonus(effective_levels, runtime_state, RuntimePerkEffectiveLevels.SLOT_EXPANSION_PERK_ID))))


func get_player_skill_cooldown_multiplier(effective_levels: Object, runtime_state: Object) -> float:
	return RuntimePerkAngelBlessingProjection.apply_player_skill_cooldown_multiplier(
		_get_angel_blessing_state(runtime_state),
		maxf(0.0, 1.0 - get_runtime_skill_bonus(effective_levels, runtime_state, "common_training"))
	)


func get_player_skill_cooldown_seconds(effective_levels: Object, runtime_state: Object, base_cooldown_seconds: float) -> float:
	return maxf(
		0.0,
		base_cooldown_seconds * get_player_skill_cooldown_multiplier(effective_levels, runtime_state)
	)


func get_boost_charge_chance_pct(effective_levels: Object, runtime_state: Object) -> float:
	return maxf(0.0, get_runtime_skill_bonus(effective_levels, runtime_state, "perk_boost_charge"))


func get_dash_acceleration_level(effective_levels: Object, runtime_state: Object) -> int:
	return int(_call_effective_float(effective_levels, runtime_state, "get_dash_acceleration_level", [], 0.0))


func get_dash_acceleration_bonus(effective_levels: Object, runtime_state: Object) -> float:
	return maxf(0.0, get_runtime_skill_bonus(effective_levels, runtime_state, RuntimePerkEffectiveLevels.DASH_ACCELERATION_ID))


func get_dash_acceleration_height_bonus(effective_levels: Object, runtime_state: Object, base_height: float) -> float:
	return maxf(0.0, base_height) * get_dash_acceleration_bonus(effective_levels, runtime_state)


func get_laurel_leaf_count_from_runtime_state(runtime_state: Object, registry: Object = null) -> int:
	return get_laurel_leaf_count(
		_get_effective_levels(runtime_state),
		runtime_state,
		registry,
		RuntimePerkRuntimeStateAccess.build_callable(
			runtime_state,
			"_get_instance",
			Callable(self, "_missing_instance")
		)
	)


func get_laurel_leaf_count(
	effective_levels: Object,
	runtime_state: Object,
	registry: Object = null,
	get_instance: Callable = Callable()
) -> int:
	if effective_levels == null or not effective_levels.has_method("get_laurel_leaf_count"):
		return _get_sacred_laurel_leaf_bonus(registry, get_instance)
	return maxi(
		0,
		int(round(get_runtime_skill_bonus(effective_levels, runtime_state, RuntimePerkEffectiveLevels.PERK_LAUREL_SHIELD_ID)))
	) + _get_sacred_laurel_leaf_bonus(registry, get_instance)


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
		_get_runtime_skill_levels_with_all_fusion_bonuses(runtime_state),
		_get_item_perk_level_bonus(runtime_state),
		_is_viper_ignition_aura_active(runtime_state),
	]
	args.append_array(extra_args)
	return RuntimePerkRuntimeStateAccess.call_float(effective_levels, method_name, args, fallback)


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


func _get_effective_levels(runtime_state: Object) -> Object:
	return RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_effective_levels")


func _get_angel_blessing_state(runtime_state: Object) -> Object:
	return RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_angel_blessing_state")


func _get_mystic_dice_multiplier(runtime_state: Object, stat_key: String) -> float:
	return maxf(
		0.0,
		RuntimePerkRuntimeStateAccess.call_float(
			runtime_state,
			"get_mystic_dice_multiplier",
			[stat_key],
			1.0
		)
	)


func _missing_instance(_registry: Object, _key: String) -> Object:
	return null


func _get_runtime_skill_levels(runtime_state: Object) -> Dictionary:
	return RuntimePerkRuntimeStateAccess.get_dict(runtime_state, "runtime_skill_levels")


func _get_runtime_skill_levels_with_fusion_bonus(runtime_state: Object, perk_id: String) -> Dictionary:
	var levels: Dictionary = _get_runtime_skill_levels(runtime_state)
	var clean_perk_id := perk_id.strip_edges()
	var base_level := int(levels.get(clean_perk_id, 0))
	var fusion_bonus := _get_fusion_effective_level_bonus(runtime_state, clean_perk_id)
	if base_level <= 0 or fusion_bonus <= 0:
		return levels
	var adjusted_levels := levels.duplicate()
	adjusted_levels[clean_perk_id] = base_level + fusion_bonus
	return adjusted_levels


func _get_runtime_skill_levels_with_all_fusion_bonuses(runtime_state: Object) -> Dictionary:
	var levels: Dictionary = _get_runtime_skill_levels(runtime_state)
	var adjusted_levels: Dictionary = levels
	var copied := false
	for perk_id_value: Variant in levels.keys():
		var perk_id := str(perk_id_value)
		var base_level := int(levels.get(perk_id_value, 0))
		var fusion_bonus := _get_fusion_effective_level_bonus(runtime_state, perk_id)
		if base_level <= 0 or fusion_bonus <= 0:
			continue
		if not copied:
			adjusted_levels = levels.duplicate()
			copied = true
		adjusted_levels[perk_id_value] = base_level + fusion_bonus
	return adjusted_levels


func _apply_fusion_skill_bonus(runtime_state: Object, perk_id: String, base_value: float) -> float:
	# 융합 흉터(central bonus 오버레이)는 runtime_perk_state의 위임 래퍼를
	# 경유한다 — 융합 미보유 state는 코어가 원값을 그대로 돌려준다.
	if runtime_state == null or not runtime_state.has_method("apply_perk_fusion_option_value"):
		return base_value
	return float(runtime_state.apply_perk_fusion_option_value(perk_id, "runtime_skill_bonus", base_value))


func _get_fusion_effective_level_bonus(runtime_state: Object, perk_id: String) -> int:
	if runtime_state == null or not runtime_state.has_method("get_perk_fusion_effective_level_bonus"):
		return 0
	return int(runtime_state.get_perk_fusion_effective_level_bonus(perk_id))


func _get_item_perk_level_bonus(runtime_state: Object) -> int:
	return max(0, RuntimePerkRuntimeStateAccess.get_int(runtime_state, "item_perk_level_bonus"))


func _is_viper_ignition_aura_active(runtime_state: Object) -> bool:
	return RuntimePerkRuntimeStateAccess.get_bool(runtime_state, "viper_ignition_aura_active")
