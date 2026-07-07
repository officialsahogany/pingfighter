extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_SAGE_RING := "sage_ring"
const ITEM_SACRED_LAUREL := "sacred_laurel"
const ITEM_TRANSCENDENT_CROWN := "transcendent_crown"
const SAGE_RING_PERK_LEVEL_BONUS := 1
const SAGE_RING_MAX_SPEED_PENALTY_PCT := 95.0
const SAGE_RING_MAX_BODY_PENALTY_PCT := 95.0


func is_sage_ring_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_SAGE_RING)


func is_sage_ring_active(runtime: Object) -> bool:
	return is_sage_ring_equipped(runtime)


func get_sage_ring_count(runtime: Object) -> int:
	return runtime.roll_query.count_equipped_item_name(runtime, ITEM_SAGE_RING)


func get_sage_ring_perk_level_bonus(runtime: Object) -> int:
	if not is_sage_ring_equipped(runtime):
		return 0
	return get_sage_ring_count(runtime) * SAGE_RING_PERK_LEVEL_BONUS


func get_sage_ring_speed_penalty_pct(runtime: Object) -> float:
	if not is_sage_ring_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_SAGE_RING, "sage_speed_penalty_pct"),
		0.0,
		SAGE_RING_MAX_SPEED_PENALTY_PCT
	)


func get_sage_ring_body_penalty_pct(runtime: Object) -> float:
	if not is_sage_ring_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_SAGE_RING, "sage_body_penalty_pct"),
		0.0,
		SAGE_RING_MAX_BODY_PENALTY_PCT
	)


func get_sage_ring_speed_multiplier(runtime: Object) -> float:
	return max(0.0, 1.0 - get_sage_ring_speed_penalty_pct(runtime) / 100.0)


func is_sacred_laurel_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_SACRED_LAUREL)


func get_sacred_laurel_leaf_bonus(runtime: Object) -> int:
	if not is_sacred_laurel_equipped(runtime):
		return 0
	return max(0, int(round(runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_SACRED_LAUREL, "leaf_count"))))


func get_sacred_laurel_context(runtime: Object) -> Dictionary:
	return runtime.context_builder.get_sacred_laurel_context(runtime)


func is_transcendent_crown_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_TRANSCENDENT_CROWN)


func is_transcendent_crown_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_crown_level(runtime) > 0
	return is_transcendent_crown_equipped(runtime)


func get_transcendent_crown_skill_bonus(runtime: Object) -> int:
	if PerkConversionFlags.is_enabled():
		if _get_converted_crown_level(runtime) <= 0:
			return 0
		return max(0, int(round(PerkConversionValues.get_mythic_value(ITEM_TRANSCENDENT_CROWN, "skill_bonus"))))
	if not is_transcendent_crown_equipped(runtime):
		return 0
	return max(0, int(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_TRANSCENDENT_CROWN, "skill_bonus")))


func get_total_item_perk_level_bonus(runtime: Object) -> int:
	return max(0, get_sage_ring_perk_level_bonus(runtime) + get_transcendent_crown_skill_bonus(runtime))


func get_transcendent_crown_context(runtime: Object) -> Dictionary:
	return runtime.context_builder.get_transcendent_crown_context(runtime)


func _get_converted_crown_level(runtime: Object) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(ITEM_TRANSCENDENT_CROWN)))
	return 0
