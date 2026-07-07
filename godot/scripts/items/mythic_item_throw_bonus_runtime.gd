extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_REINFORCED_BOOMERANG_GAUNTLET := "reinforced_boomerang_gauntlet"
const ITEM_COMMANDO_ARM := "commando_arm"
const REINFORCED_BOOMERANG_LAUNCH_CAP_PCT := 200.0
const REINFORCED_BOOMERANG_HOMING_CAP_PCT := 150.0
const REINFORCED_BOOMERANG_SPAWN_CAP_PCT := 2000.0
const REINFORCED_BOOMERANG_KNOCKBACK_MULTIPLIER := 1.4
const REINFORCED_BOOMERANG_STUN_MULTIPLIER := 1.6
const COMMANDO_ARM_MAX_STACKS := 2
const COMMANDO_ARM_GENERIC_THROW_SPEED_PER_STACK := 0.5
const COMMANDO_ARM_THROW_SPEED_CAP_PCT := 200.0
const COMMANDO_ARM_EXPLOSION_RANGE_CAP_PCT := 200.0
const COMMANDO_ARM_SMOKE_DURATION_CAP_PCT := 300.0
const COMMANDO_ARM_PREP_REDUCTION_CAP_PCT := 95.0


func is_reinforced_boomerang_gauntlet_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_REINFORCED_BOOMERANG_GAUNTLET)


func is_reinforced_boomerang_gauntlet_active(runtime: Object) -> bool:
	return is_reinforced_boomerang_gauntlet_equipped(runtime)


func is_reinforced_boomerang_gauntlet_effect_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime, ITEM_REINFORCED_BOOMERANG_GAUNTLET) > 0
	return is_reinforced_boomerang_gauntlet_equipped(runtime)


func get_reinforced_boomerang_gauntlet_count(runtime: Object) -> int:
	return runtime.roll_query.count_equipped_item_name(runtime, ITEM_REINFORCED_BOOMERANG_GAUNTLET)


func get_boomerang_launch_speed_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_REINFORCED_BOOMERANG_GAUNTLET, "boomerang_launch_speed_pct")
	if not is_reinforced_boomerang_gauntlet_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_REINFORCED_BOOMERANG_GAUNTLET, "boomerang_launch_speed_pct"),
		0.0,
		REINFORCED_BOOMERANG_LAUNCH_CAP_PCT
	)


func get_boomerang_homing_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_REINFORCED_BOOMERANG_GAUNTLET, "boomerang_homing_pct")
	if not is_reinforced_boomerang_gauntlet_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_REINFORCED_BOOMERANG_GAUNTLET, "boomerang_homing_pct"),
		0.0,
		REINFORCED_BOOMERANG_HOMING_CAP_PCT
	)


func get_boomerang_spawn_bonus_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_REINFORCED_BOOMERANG_GAUNTLET, "boomerang_spawn_bonus_pct")
	if not is_reinforced_boomerang_gauntlet_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_REINFORCED_BOOMERANG_GAUNTLET, "boomerang_spawn_bonus_pct"),
		0.0,
		REINFORCED_BOOMERANG_SPAWN_CAP_PCT
	)


func get_boomerang_launch_speed_multiplier(runtime: Object) -> float:
	return max(0.0, 1.0 + get_boomerang_launch_speed_pct(runtime) / 100.0)


func get_boomerang_homing_multiplier(runtime: Object) -> float:
	return max(0.0, 1.0 + get_boomerang_homing_pct(runtime) / 100.0)


func get_boomerang_item_spawn_multiplier(runtime: Object) -> float:
	return max(0.0, 1.0 + get_boomerang_spawn_bonus_pct(runtime) / 100.0)


func get_boomerang_item_spawn_chance(runtime: Object, base_chance: float) -> float:
	return max(0.0, float(base_chance) * get_boomerang_item_spawn_multiplier(runtime))


func get_boomerang_knockback_multiplier(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		var knockback_pct: float = _get_converted_perk_value(runtime, ITEM_REINFORCED_BOOMERANG_GAUNTLET, "boomerang_knockback_pct")
		return max(0.0, 1.0 + knockback_pct / 100.0) if knockback_pct > 0.0 else 1.0
	return REINFORCED_BOOMERANG_KNOCKBACK_MULTIPLIER if is_reinforced_boomerang_gauntlet_equipped(runtime) else 1.0


func get_boomerang_stun_multiplier(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		var stun_pct: float = _get_converted_perk_value(runtime, ITEM_REINFORCED_BOOMERANG_GAUNTLET, "boomerang_stun_pct")
		return max(0.0, 1.0 + stun_pct / 100.0) if stun_pct > 0.0 else 1.0
	return REINFORCED_BOOMERANG_STUN_MULTIPLIER if is_reinforced_boomerang_gauntlet_equipped(runtime) else 1.0


func is_commando_arm_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_COMMANDO_ARM)


func is_commando_arm_active(runtime: Object) -> bool:
	return is_commando_arm_equipped(runtime)


func is_commando_arm_effect_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime, ITEM_COMMANDO_ARM) > 0
	return is_commando_arm_equipped(runtime)


func get_commando_arm_count(runtime: Object) -> int:
	return min(COMMANDO_ARM_MAX_STACKS, runtime.roll_query.count_equipped_item_name(runtime, ITEM_COMMANDO_ARM))


func get_commando_arm_throw_speed_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_COMMANDO_ARM, "throw_speed_pct")
	if not is_commando_arm_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_commando_arm_roll_sum(runtime, "throw_speed_pct"), 0.0, COMMANDO_ARM_THROW_SPEED_CAP_PCT)


func get_commando_arm_explosion_range_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_COMMANDO_ARM, "explosion_range_pct")
	if not is_commando_arm_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_commando_arm_roll_sum(runtime, "explosion_range_pct"),
		0.0,
		COMMANDO_ARM_EXPLOSION_RANGE_CAP_PCT
	)


func get_commando_arm_smoke_duration_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_COMMANDO_ARM, "smoke_duration_pct")
	if not is_commando_arm_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_commando_arm_roll_sum(runtime, "smoke_duration_pct"),
		0.0,
		COMMANDO_ARM_SMOKE_DURATION_CAP_PCT
	)


func get_commando_arm_prep_reduction_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_COMMANDO_ARM, "prep_reduction_pct")
	if not is_commando_arm_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_commando_arm_roll_sum(runtime, "prep_reduction_pct"),
		0.0,
		COMMANDO_ARM_PREP_REDUCTION_CAP_PCT * COMMANDO_ARM_MAX_STACKS
	)


func get_commando_arm_prep_multiplier(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		var reduction_pct: float = get_commando_arm_prep_reduction_pct(runtime)
		return max(0.01, 1.0 - reduction_pct / 100.0) if reduction_pct > 0.0 else 1.0
	if not is_commando_arm_equipped(runtime):
		return 1.0
	var multiplier := 1.0
	for reduction_value in runtime.roll_query.get_commando_arm_roll_values(runtime, "prep_reduction_pct"):
		var reduction_pct: float = clamp(float(reduction_value), 0.0, COMMANDO_ARM_PREP_REDUCTION_CAP_PCT)
		multiplier *= max(0.01, 1.0 - reduction_pct / 100.0)
	return max(0.01, multiplier)


func get_commando_arm_windup_msec(runtime: Object, base_msec: int) -> int:
	return max(1, int(floor(float(base_msec) * get_commando_arm_prep_multiplier(runtime))))


func get_commando_arm_throw_speed_multiplier(runtime: Object, use_rolled_speed: bool = false) -> float:
	if PerkConversionFlags.is_enabled():
		var speed_pct: float = get_commando_arm_throw_speed_pct(runtime)
		return max(0.0, 1.0 + speed_pct / 100.0) if speed_pct > 0.0 else 1.0
	if not is_commando_arm_equipped(runtime):
		return 1.0
	if use_rolled_speed:
		return max(0.0, 1.0 + get_commando_arm_throw_speed_pct(runtime) / 100.0)
	return max(0.0, 1.0 + COMMANDO_ARM_GENERIC_THROW_SPEED_PER_STACK * float(get_commando_arm_count(runtime)))


func get_commando_arm_range_multiplier(runtime: Object) -> float:
	return max(0.0, 1.0 + get_commando_arm_explosion_range_pct(runtime) / 100.0)


func get_commando_arm_range_value(runtime: Object, base_value: float) -> float:
	return max(0.0, float(base_value) * get_commando_arm_range_multiplier(runtime))


func get_commando_arm_smoke_duration_multiplier(runtime: Object) -> float:
	return max(0.0, 1.0 + get_commando_arm_smoke_duration_pct(runtime) / 100.0)


func get_commando_arm_duration_frames(runtime: Object, base_frames: float) -> float:
	return max(0.0, float(base_frames) * get_commando_arm_smoke_duration_multiplier(runtime))


func get_commando_arm_context(runtime: Object) -> Dictionary:
	return runtime.context_builder.get_commando_arm_context(runtime)


func _get_converted_perk_value(runtime: Object, perk_id: String, key: String) -> float:
	var level := _get_converted_perk_level(runtime, perk_id)
	if level <= 0:
		return 0.0
	return PerkConversionValues.get_value(perk_id, key, level)


func _get_converted_perk_level(runtime: Object, perk_id: String) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(perk_id)))
	return 0
