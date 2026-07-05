extends RefCounted


func get_selected_index(hud_state) -> int:
	if hud_state == null:
		return 0
	return int(hud_state.get_selected_index())


func get_time_since_round_start(current_time_msec: int, round_start_time_msec: int) -> int:
	if round_start_time_msec > 0:
		return current_time_msec - round_start_time_msec
	return 10000


func get_item_data(active_item_slots: Array, slot_index: int, actual_item_count: int) -> Dictionary:
	if slot_index >= actual_item_count:
		return {}
	var item: Variant = active_item_slots[slot_index]
	if item is Dictionary:
		return item
	return {}


func get_slot_status(
	hud_state,
	slot_index: int,
	item_data: Dictionary,
	current_time_msec: int,
	time_since_round_start_msec: int,
	registry: Object = null,
	runtime_perk_state: Object = null
) -> Dictionary:
	if hud_state != null:
		return hud_state.get_slot_status(
			slot_index,
			item_data,
			current_time_msec,
			time_since_round_start_msec,
			registry,
			runtime_perk_state
		)
	return {
		"cooldown_remaining_ratio": 0.0,
		"cooldown_flash_pulse": 0.0,
		"throw_lock_remaining_seconds": 0,
		"alchemy_notice_ratio": 0.0,
		"pickup_pop_pulse": 0.0,
	}
