extends RefCounted

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
	return runtime._has_equipped_item_name(ITEM_REINFORCED_BOOMERANG_GAUNTLET)


func is_reinforced_boomerang_gauntlet_active(runtime: Object) -> bool:
	return is_reinforced_boomerang_gauntlet_equipped(runtime)


func get_reinforced_boomerang_gauntlet_count(runtime: Object) -> int:
	return runtime._count_equipped_item_name(ITEM_REINFORCED_BOOMERANG_GAUNTLET)


func get_boomerang_launch_speed_pct(runtime: Object) -> float:
	if not is_reinforced_boomerang_gauntlet_equipped(runtime):
		return 0.0
	return clamp(
		runtime._get_equipped_roll_sum(ITEM_REINFORCED_BOOMERANG_GAUNTLET, "boomerang_launch_speed_pct"),
		0.0,
		REINFORCED_BOOMERANG_LAUNCH_CAP_PCT
	)


func get_boomerang_homing_pct(runtime: Object) -> float:
	if not is_reinforced_boomerang_gauntlet_equipped(runtime):
		return 0.0
	return clamp(
		runtime._get_equipped_roll_sum(ITEM_REINFORCED_BOOMERANG_GAUNTLET, "boomerang_homing_pct"),
		0.0,
		REINFORCED_BOOMERANG_HOMING_CAP_PCT
	)


func get_boomerang_spawn_bonus_pct(runtime: Object) -> float:
	if not is_reinforced_boomerang_gauntlet_equipped(runtime):
		return 0.0
	return clamp(
		runtime._get_equipped_roll_sum(ITEM_REINFORCED_BOOMERANG_GAUNTLET, "boomerang_spawn_bonus_pct"),
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
	return REINFORCED_BOOMERANG_KNOCKBACK_MULTIPLIER if is_reinforced_boomerang_gauntlet_equipped(runtime) else 1.0


func get_boomerang_stun_multiplier(runtime: Object) -> float:
	return REINFORCED_BOOMERANG_STUN_MULTIPLIER if is_reinforced_boomerang_gauntlet_equipped(runtime) else 1.0


func is_commando_arm_equipped(runtime: Object) -> bool:
	return runtime._has_equipped_item_name(ITEM_COMMANDO_ARM)


func is_commando_arm_active(runtime: Object) -> bool:
	return is_commando_arm_equipped(runtime)


func get_commando_arm_count(runtime: Object) -> int:
	return min(COMMANDO_ARM_MAX_STACKS, runtime._count_equipped_item_name(ITEM_COMMANDO_ARM))


func get_commando_arm_throw_speed_pct(runtime: Object) -> float:
	if not is_commando_arm_equipped(runtime):
		return 0.0
	return clamp(runtime._get_commando_arm_roll_sum("throw_speed_pct"), 0.0, COMMANDO_ARM_THROW_SPEED_CAP_PCT)


func get_commando_arm_explosion_range_pct(runtime: Object) -> float:
	if not is_commando_arm_equipped(runtime):
		return 0.0
	return clamp(
		runtime._get_commando_arm_roll_sum("explosion_range_pct"),
		0.0,
		COMMANDO_ARM_EXPLOSION_RANGE_CAP_PCT
	)


func get_commando_arm_smoke_duration_pct(runtime: Object) -> float:
	if not is_commando_arm_equipped(runtime):
		return 0.0
	return clamp(
		runtime._get_commando_arm_roll_sum("smoke_duration_pct"),
		0.0,
		COMMANDO_ARM_SMOKE_DURATION_CAP_PCT
	)


func get_commando_arm_prep_reduction_pct(runtime: Object) -> float:
	if not is_commando_arm_equipped(runtime):
		return 0.0
	return clamp(
		runtime._get_commando_arm_roll_sum("prep_reduction_pct"),
		0.0,
		COMMANDO_ARM_PREP_REDUCTION_CAP_PCT * COMMANDO_ARM_MAX_STACKS
	)


func get_commando_arm_prep_multiplier(runtime: Object) -> float:
	if not is_commando_arm_equipped(runtime):
		return 1.0
	var multiplier := 1.0
	for reduction_value in runtime._get_commando_arm_roll_values("prep_reduction_pct"):
		var reduction_pct: float = clamp(float(reduction_value), 0.0, COMMANDO_ARM_PREP_REDUCTION_CAP_PCT)
		multiplier *= max(0.01, 1.0 - reduction_pct / 100.0)
	return max(0.01, multiplier)


func get_commando_arm_windup_msec(runtime: Object, base_msec: int) -> int:
	if not is_commando_arm_equipped(runtime):
		return max(1, int(base_msec))
	return max(1, int(floor(float(base_msec) * get_commando_arm_prep_multiplier(runtime))))


func get_commando_arm_throw_speed_multiplier(runtime: Object, use_rolled_speed: bool = false) -> float:
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
