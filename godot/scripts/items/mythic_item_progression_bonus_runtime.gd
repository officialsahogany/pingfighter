extends RefCounted

const ITEM_SAGE_RING := "sage_ring"
const ITEM_SACRED_LAUREL := "sacred_laurel"
const ITEM_TRANSCENDENT_CROWN := "transcendent_crown"
const SAGE_RING_PERK_LEVEL_BONUS := 1
const SAGE_RING_MAX_SPEED_PENALTY_PCT := 95.0
const SAGE_RING_MAX_BODY_PENALTY_PCT := 95.0


func is_sage_ring_equipped(runtime: Object) -> bool:
	return runtime._has_equipped_item_name(ITEM_SAGE_RING)


func is_sage_ring_active(runtime: Object) -> bool:
	return is_sage_ring_equipped(runtime)


func get_sage_ring_count(runtime: Object) -> int:
	return runtime._count_equipped_item_name(ITEM_SAGE_RING)


func get_sage_ring_perk_level_bonus(runtime: Object) -> int:
	if not is_sage_ring_equipped(runtime):
		return 0
	return get_sage_ring_count(runtime) * SAGE_RING_PERK_LEVEL_BONUS


func get_sage_ring_speed_penalty_pct(runtime: Object) -> float:
	if not is_sage_ring_equipped(runtime):
		return 0.0
	return clamp(
		runtime._get_equipped_roll_sum(ITEM_SAGE_RING, "sage_speed_penalty_pct"),
		0.0,
		SAGE_RING_MAX_SPEED_PENALTY_PCT
	)


func get_sage_ring_body_penalty_pct(runtime: Object) -> float:
	if not is_sage_ring_equipped(runtime):
		return 0.0
	return clamp(
		runtime._get_equipped_roll_sum(ITEM_SAGE_RING, "sage_body_penalty_pct"),
		0.0,
		SAGE_RING_MAX_BODY_PENALTY_PCT
	)


func get_sage_ring_speed_multiplier(runtime: Object) -> float:
	return max(0.0, 1.0 - get_sage_ring_speed_penalty_pct(runtime) / 100.0)


func is_sacred_laurel_equipped(runtime: Object) -> bool:
	return runtime._has_equipped_item_name(ITEM_SACRED_LAUREL)


func get_sacred_laurel_leaf_bonus(runtime: Object) -> int:
	if not is_sacred_laurel_equipped(runtime):
		return 0
	return max(0, int(round(runtime._get_equipped_roll_sum(ITEM_SACRED_LAUREL, "leaf_count"))))


func get_sacred_laurel_context(runtime: Object) -> Dictionary:
	return runtime.context_builder.get_sacred_laurel_context(runtime)


func is_transcendent_crown_equipped(runtime: Object) -> bool:
	return runtime._has_equipped_item_name(ITEM_TRANSCENDENT_CROWN)


func get_transcendent_crown_skill_bonus(runtime: Object) -> int:
	if not is_transcendent_crown_equipped(runtime):
		return 0
	return max(0, int(runtime._get_equipped_roll_value(ITEM_TRANSCENDENT_CROWN, "skill_bonus")))


func get_total_item_perk_level_bonus(runtime: Object) -> int:
	return max(0, get_sage_ring_perk_level_bonus(runtime) + get_transcendent_crown_skill_bonus(runtime))


func get_transcendent_crown_context(runtime: Object) -> Dictionary:
	return runtime.context_builder.get_transcendent_crown_context(runtime)
