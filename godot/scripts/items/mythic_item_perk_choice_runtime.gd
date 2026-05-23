extends RefCounted

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
	if not runtime.is_equipped(ITEM_MEGINGJORD):
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


func get_megingjord_extra_pick_chance(runtime: Object) -> float:
	if not runtime.equipped_items.has(ITEM_MEGINGJORD):
		return 0.0
	var item_data: Dictionary = runtime._get_dict(runtime.equipped_items[ITEM_MEGINGJORD])
	var value: float = runtime._get_item_roll_value(item_data, ITEM_MEGINGJORD, "extra_pick_chance")
	return clamp(value, 0.0, 95.0)
