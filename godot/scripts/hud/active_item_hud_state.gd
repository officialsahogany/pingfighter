extends RefCounted

const DEFAULT_ACTIVE_ITEM_COOLDOWN_MS := 10000
const COOLDOWN_FLASH_DURATION_MS := 400

var selected_active_item_index := 0
var cooldown_complete_flash: Dictionary = {}


func reset() -> void:
	selected_active_item_index = 0
	cooldown_complete_flash.clear()


func set_selected_index(index: int) -> void:
	selected_active_item_index = max(0, index)


func get_selected_index() -> int:
	return selected_active_item_index


func get_cooldown_complete_flash() -> Dictionary:
	return cooldown_complete_flash


func get_slot_status(
	slot_index: int,
	item_data: Dictionary,
	current_time_msec: int,
	time_since_round_start_msec: int
) -> Dictionary:
	var status := {
		"cooldown_remaining_ratio": 0.0,
		"cooldown_flash_pulse": 0.0,
		"throw_lock_remaining_seconds": 0,
	}

	var last_use_msec: int = get_active_item_last_use_msec(item_data)
	if last_use_msec >= 0:
		var elapsed: int = current_time_msec - last_use_msec
		var cooldown_msec: int = get_active_item_cooldown_msec(item_data)
		if elapsed < cooldown_msec:
			var remaining_ratio: float = 1.0 - float(elapsed) / float(max(1, cooldown_msec))
			if remaining_ratio > 0.0:
				status["cooldown_remaining_ratio"] = remaining_ratio
			cooldown_complete_flash.erase(slot_index)
		else:
			if not cooldown_complete_flash.has(slot_index):
				cooldown_complete_flash[slot_index] = current_time_msec
			var flash_elapsed: int = current_time_msec - int(cooldown_complete_flash[slot_index])
			if flash_elapsed < COOLDOWN_FLASH_DURATION_MS:
				var progress: float = float(flash_elapsed) / float(COOLDOWN_FLASH_DURATION_MS)
				var pulse: float = progress / 0.2 if progress < 0.2 else 1.0 - ((progress - 0.2) / 0.8)
				status["cooldown_flash_pulse"] = max(0.0, pulse)

	var item_name: String = str(item_data.get("name", item_data.get("effect", "")))
	var throw_limit: int = get_active_item_throw_lock_msec(item_name)
	if throw_limit > 0 and time_since_round_start_msec < throw_limit:
		status["throw_lock_remaining_seconds"] = int(float(throw_limit - time_since_round_start_msec) / 1000.0) + 1

	return status


func get_active_item_last_use_msec(item_data: Dictionary) -> int:
	if item_data.has("last_use_msec"):
		return int(item_data["last_use_msec"])
	if item_data.has("last_use"):
		return int(item_data["last_use"])
	return -1


func get_active_item_cooldown_msec(item_data: Dictionary) -> int:
	if item_data.has("cooldown_msec"):
		return max(0, int(item_data["cooldown_msec"]))
	if item_data.has("cooldown_ms"):
		return max(0, int(item_data["cooldown_ms"]))
	return DEFAULT_ACTIVE_ITEM_COOLDOWN_MS


func get_active_item_throw_lock_msec(item_name: String) -> int:
	if (
		item_name == "molotov"
		or item_name == "grenade"
		or item_name == "flare"
		or item_name == "spider_mine"
		or item_name == "dynamite"
		or item_name == "boomerang"
	):
		return 3000
	if item_name == "banana" or item_name == "soap":
		return 5000
	return 0
