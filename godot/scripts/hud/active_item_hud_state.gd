extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const DEFAULT_ACTIVE_ITEM_COOLDOWN_MS := ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC
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
	_time_since_round_start_msec: int,
	registry: Object = null,
	runtime_perk_state: Object = null
) -> Dictionary:
	var status := {
		"cooldown_remaining_ratio": 0.0,
		"cooldown_flash_pulse": 0.0,
		"throw_lock_remaining_seconds": 0,
		"alchemy_notice_ratio": 0.0,
	}

	var last_use_msec: int = get_active_item_last_use_msec(item_data)
	var cooldown_time_msec: int = _get_active_item_cooldown_time_msec(current_time_msec, registry)
	if last_use_msec >= 0:
		var elapsed: int = max(0, cooldown_time_msec - last_use_msec)
		var cooldown_msec: int = get_active_item_cooldown_msec(item_data, registry, runtime_perk_state)
		if elapsed < cooldown_msec:
			var remaining_ratio: float = 1.0 - float(elapsed) / float(max(1, cooldown_msec))
			if remaining_ratio > 0.0:
				status["cooldown_remaining_ratio"] = remaining_ratio
			cooldown_complete_flash.erase(slot_index)
		else:
			if not cooldown_complete_flash.has(slot_index):
				cooldown_complete_flash[slot_index] = cooldown_time_msec
			var flash_elapsed: int = cooldown_time_msec - int(cooldown_complete_flash[slot_index])
			if flash_elapsed < COOLDOWN_FLASH_DURATION_MS:
				var progress: float = float(flash_elapsed) / float(COOLDOWN_FLASH_DURATION_MS)
				var pulse: float = progress / 0.2 if progress < 0.2 else 1.0 - ((progress - 0.2) / 0.8)
				status["cooldown_flash_pulse"] = max(0.0, pulse)

	var alchemy_until_msec: int = int(item_data.get("alchemy_notice_until_msec", -1))
	if alchemy_until_msec > current_time_msec:
		var alchemy_started_msec: int = int(item_data.get("alchemy_notice_started_msec", current_time_msec))
		var duration_msec: int = max(1, alchemy_until_msec - alchemy_started_msec)
		status["alchemy_notice_ratio"] = clamp(float(alchemy_until_msec - current_time_msec) / float(duration_msec), 0.0, 1.0)

	return status


func get_active_item_last_use_msec(item_data: Dictionary) -> int:
	if item_data.has("last_use_msec"):
		return int(item_data["last_use_msec"])
	if item_data.has("last_use"):
		return int(item_data["last_use"])
	return -1


func get_active_item_cooldown_msec(item_data: Dictionary, registry: Object = null, runtime_perk_state: Object = null) -> int:
	var base_cooldown_msec: int = DEFAULT_ACTIVE_ITEM_COOLDOWN_MS
	if item_data.has("cooldown_msec"):
		base_cooldown_msec = max(0, int(item_data["cooldown_msec"]))
	elif item_data.has("cooldown_ms"):
		base_cooldown_msec = max(0, int(item_data["cooldown_ms"]))
	if runtime_perk_state == null:
		runtime_perk_state = _get_instance(registry, "runtime_perk_state")
	var cooldown_msec: int = base_cooldown_msec
	if runtime_perk_state != null and runtime_perk_state.has_method("get_active_item_cooldown_msec"):
		cooldown_msec = int(runtime_perk_state.get_active_item_cooldown_msec(cooldown_msec))
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_active_item_cooldown_msec"):
		cooldown_msec = int(mythic_item_runtime.get_active_item_cooldown_msec(cooldown_msec))
	return max(0, cooldown_msec)


func _get_active_item_cooldown_time_msec(current_time_msec: int, registry: Object = null) -> int:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("get_active_item_cooldown_time_msec"):
		return int(active_item_runtime.get_active_item_cooldown_time_msec(current_time_msec))
	return current_time_msec


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
