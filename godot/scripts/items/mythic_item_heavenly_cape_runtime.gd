extends RefCounted

const ITEM_HEAVENLY_CAPE := "heavenly_cape"
const MAX_SKILL_COOLDOWN_REDUCTION_PCT := 95.0
const SKILL_SLOT_BONUS := 1


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_HEAVENLY_CAPE)


func get_skill_cooldown_reduction_pct(runtime: Object) -> float:
	return clamp(
		runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_HEAVENLY_CAPE, "skill_cooldown_reduction"),
		0.0,
		MAX_SKILL_COOLDOWN_REDUCTION_PCT
	)


func get_skill_slot_bonus(runtime: Object) -> int:
	if not is_equipped(runtime):
		return 0
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
