extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_MEGINGJORD := "megingjord"
const MEGINGJORD_MAX_EXTRA_PICKS := 2


func on_new_perk_choice_batch(runtime: Object, owner: Object = null) -> void:
	runtime.megingjord_extra_pick_count = 0
	runtime.dowsing_runtime.reset_bonus_trigger(runtime)
	runtime._sync_owner(owner)


func should_check_extra_pick(choice_id: String) -> bool:
	return choice_id != "common_refresh"


func try_after_perk_choice(runtime: Object, choice_id: String, owner: Object, registry: Object) -> bool:
	if not should_check_extra_pick(choice_id):
		return false
	if not is_active(runtime):
		return false
	if runtime.megingjord_extra_pick_count >= MEGINGJORD_MAX_EXTRA_PICKS:
		return false
	var chance_pct: float = get_megingjord_extra_pick_chance(runtime)
	if randf() >= chance_pct / 100.0:
		runtime._sync_owner(owner, registry)
		return false
	runtime.megingjord_extra_pick_count += 1
	runtime.activation_effect_runtime.start(runtime, owner, registry)
	runtime._sync_owner(owner, registry)
	return true


func is_equipped(runtime: Object) -> bool:
	return runtime.is_equipped(ITEM_MEGINGJORD)


func is_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime) > 0
	return is_equipped(runtime)


func get_megingjord_extra_pick_chance(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_mythic_value(runtime, "extra_pick_chance")
	if not runtime.equipped_items.has(ITEM_MEGINGJORD):
		return 0.0
	var item_data: Dictionary = runtime._get_dict(runtime.equipped_items[ITEM_MEGINGJORD])
	var value: float = runtime.roll_query.get_item_roll_value(
		runtime,
		item_data,
		ITEM_MEGINGJORD,
		"extra_pick_chance"
	)
	return clamp(value, 0.0, 95.0)


func _get_converted_mythic_value(runtime: Object, key: String) -> float:
	if _get_converted_perk_level(runtime) <= 0:
		return 0.0
	return PerkConversionValues.get_mythic_value(ITEM_MEGINGJORD, key)


func _get_converted_perk_level(runtime: Object) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(ITEM_MEGINGJORD)))
	return 0
