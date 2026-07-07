extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_MASTER := "master"
const ITEM_COOLTIME := "cooltime"
const ITEM_TIMER_BELT := "timer_belt"


func is_master_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_MASTER)


func get_master_wall_length_bonus_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_MASTER, "wall_length_pct")
	if not is_master_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_MASTER, "wall_length_pct"), 0.0, 500.0)


func get_master_item_cooldown_reduction_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_MASTER, "item_cooldown_pct")
	if not is_master_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_MASTER, "item_cooldown_pct"), 0.0, 95.0)


func get_master_wall_spawn_bonus_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_value(runtime, ITEM_MASTER, "wall_spawn_bonus_pct")
	if not is_master_equipped(runtime):
		return 0.0
	return clamp(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_MASTER, "wall_spawn_bonus_pct"), 0.0, 2000.0)


func get_brick_wall_width(runtime: Object, base_width: float) -> float:
	return max(1.0, float(base_width) * (1.0 + get_master_wall_length_bonus_pct(runtime) / 100.0))


func get_wall_item_spawn_chance(runtime: Object, base_chance: float) -> float:
	return max(0.0, float(base_chance) * (1.0 + get_master_wall_spawn_bonus_pct(runtime) / 100.0))


func is_cooltime_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_COOLTIME)


func get_cooltime_active_item_cooldown_reduction_pct(runtime: Object) -> float:
	return clamp(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_COOLTIME, "active_cooldown_pct"), 0.0, 95.0)


func get_total_active_item_cooldown_reduction_pct(runtime: Object) -> float:
	var multiplier := 1.0
	multiplier *= max(0.0, 1.0 - get_master_item_cooldown_reduction_pct(runtime) / 100.0)
	multiplier *= max(0.0, 1.0 - get_cooltime_active_item_cooldown_reduction_pct(runtime) / 100.0)
	return clamp((1.0 - multiplier) * 100.0, 0.0, 100.0)


func get_active_item_cooldown_msec(runtime: Object, base_cooldown_msec: int) -> int:
	var adjusted: float = float(max(0, base_cooldown_msec))
	var master_reduction_pct: float = get_master_item_cooldown_reduction_pct(runtime)
	if master_reduction_pct > 0.0:
		adjusted *= max(0.0, 1.0 - master_reduction_pct / 100.0)
	var cooltime_reduction_pct: float = get_cooltime_active_item_cooldown_reduction_pct(runtime)
	if cooltime_reduction_pct > 0.0:
		adjusted *= max(0.0, 1.0 - cooltime_reduction_pct / 100.0)
	return max(0, int(round(adjusted)))


func is_timer_belt_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_TIMER_BELT)


func get_timer_belt_skill_cooldown_reduction_pct(runtime: Object) -> float:
	return clamp(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_TIMER_BELT, "skill_cooldown_pct"), 0.0, 95.0)


func _get_converted_perk_value(runtime: Object, perk_id: String, key: String) -> float:
	var level := 0
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		level = max(0, int(runtime.get_converted_perk_effect_level(perk_id)))
	if level <= 0:
		return 0.0
	return PerkConversionValues.get_value(perk_id, key, level)
