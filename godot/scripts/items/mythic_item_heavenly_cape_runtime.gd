extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_HEAVENLY_CAPE := "heavenly_cape"
const MAX_SKILL_COOLDOWN_REDUCTION_PCT := 95.0
const SKILL_SLOT_BONUS := 1


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_HEAVENLY_CAPE)


func is_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime) > 0
	return is_equipped(runtime)


func get_skill_cooldown_reduction_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_mythic_value(runtime, "skill_cooldown_reduction")
	if not is_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_HEAVENLY_CAPE, "skill_cooldown_reduction"),
		0.0,
		MAX_SKILL_COOLDOWN_REDUCTION_PCT
	)


func get_skill_slot_bonus(runtime: Object) -> int:
	if not is_active(runtime):
		return 0
	if PerkConversionFlags.is_enabled():
		return max(0, int(round(PerkConversionValues.get_mythic_value(ITEM_HEAVENLY_CAPE, "skill_slot_bonus"))))
	return SKILL_SLOT_BONUS


func get_player_skill_max_slots(runtime: Object, base_slots: int) -> int:
	return max(1, int(base_slots) + get_skill_slot_bonus(runtime))


func get_player_skill_cooldown_multiplier(runtime: Object) -> float:
	var multiplier := 1.0
	var timer_reduction_pct: float = runtime.get_timer_belt_skill_cooldown_reduction_pct()
	if timer_reduction_pct > 0.0:
		multiplier *= max(0.0, 1.0 - timer_reduction_pct / 100.0)
	var cape_reduction_pct: float = get_skill_cooldown_reduction_pct(runtime)
	if cape_reduction_pct > 0.0:
		multiplier *= max(0.0, 1.0 - cape_reduction_pct / 100.0)
	return max(0.0, multiplier)


func get_player_skill_cooldown_seconds(runtime: Object, base_cooldown_seconds: float) -> float:
	return max(
		0.0,
		float(base_cooldown_seconds) * get_player_skill_cooldown_multiplier(runtime)
	)


func _get_converted_mythic_value(runtime: Object, key: String) -> float:
	if _get_converted_perk_level(runtime) <= 0:
		return 0.0
	return PerkConversionValues.get_mythic_value(ITEM_HEAVENLY_CAPE, key)


func _get_converted_perk_level(runtime: Object) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(ITEM_HEAVENLY_CAPE)))
	return 0
