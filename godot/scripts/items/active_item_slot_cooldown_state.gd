extends RefCounted

const CLEAR_COOLDOWN_ANCHOR_MSEC := -1000000

var last_item_use_msec: int = CLEAR_COOLDOWN_ANCHOR_MSEC
var cooldown_pause_started_msec := -1


func reset() -> void:
	last_item_use_msec = CLEAR_COOLDOWN_ANCHOR_MSEC
	cooldown_pause_started_msec = -1


func reset_for_stage_transition(active_item_slots: Array) -> Array:
	reset()
	var result: Array = active_item_slots.duplicate(true)
	for i in range(result.size()):
		var slot: Variant = result[i]
		if not (slot is Dictionary):
			continue
		var item: Dictionary = slot
		var item_identity := _get_item_identity(item)
		if str(item.get("name", "")) == "" and item_identity != "":
			item["name"] = item_identity
		if item.has("last_use_msec"):
			item["last_use_msec"] = -1
		if item.has("last_use"):
			item["last_use"] = -1
		result[i] = item
	return result


func pause(time_now: int) -> void:
	if cooldown_pause_started_msec >= 0:
		return
	cooldown_pause_started_msec = max(0, time_now)


func resume(time_now: int, active_item_slots: Array = []) -> Array:
	if cooldown_pause_started_msec < 0:
		return active_item_slots
	var pause_duration_msec: int = max(0, time_now - cooldown_pause_started_msec)
	cooldown_pause_started_msec = -1
	if pause_duration_msec <= 0:
		return active_item_slots
	if last_item_use_msec >= 0:
		last_item_use_msec += pause_duration_msec
	var result: Array = active_item_slots.duplicate(true)
	for i in range(result.size()):
		var slot: Variant = result[i]
		if not (slot is Dictionary):
			continue
		var item: Dictionary = slot
		if item.has("last_use_msec"):
			var last_use_msec: int = int(item.get("last_use_msec", -1))
			if last_use_msec >= 0:
				item["last_use_msec"] = last_use_msec + pause_duration_msec
		if item.has("last_use"):
			var last_use: int = int(item.get("last_use", -1))
			if last_use >= 0:
				item["last_use"] = last_use + pause_duration_msec
		result[i] = item
	return result


func get_effective_time_msec(current_time_msec: int) -> int:
	return cooldown_pause_started_msec if cooldown_pause_started_msec >= 0 else current_time_msec


func get_inherited_last_use_msec() -> int:
	return last_item_use_msec


func is_item_ready(
	item_data: Dictionary,
	now_msec: int,
	effective_cooldown_msec: int,
	uses_global_cooldown: bool
) -> bool:
	if uses_global_cooldown and now_msec - last_item_use_msec < effective_cooldown_msec:
		return false
	var last_use_msec: int = int(item_data.get("last_use_msec", item_data.get("last_use", -1)))
	return last_use_msec < 0 or now_msec - last_use_msec >= effective_cooldown_msec


func start_global_cooldown(now_msec: int) -> void:
	last_item_use_msec = now_msec


func propagate_global_cooldown(active_item_slots: Array, now_msec: int) -> void:
	for i in range(active_item_slots.size()):
		var slot: Variant = active_item_slots[i]
		if not (slot is Dictionary):
			continue
		var item: Dictionary = slot
		item["last_use_msec"] = now_msec
		active_item_slots[i] = item


func _get_item_identity(item_data: Dictionary) -> String:
	for key in ["name", "effect", "item_name", "item_id"]:
		var raw_value: Variant = item_data.get(str(key), "")
		if raw_value == null:
			continue
		var value := str(raw_value)
		if value != "":
			return value
	return ""
