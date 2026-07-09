extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const DEFAULT_ACTIVE_ITEM_COOLDOWN_MS := ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC
const COOLDOWN_FLASH_DURATION_MS := 400
const PICKUP_POP_DURATION_MS := 350
# "Fly into the empty slot" acquisition animation: the icon travels from the field
# pickup point into its destination slot box over this window; the slot renders as an
# empty box until the icon lands, and the pickup pop is deferred to the landing frame
# so the beloved slot pop reads as the item snapping home. Kept short (cosmetic only,
# wall-clock driven) so a modal opening mid-flight simply lands it.
const SLOT_FLIGHT_DURATION_MS := 460
const SLOT_FLIGHT_MAX_ACTIVE := 5
const DEFAULT_FLIGHT_COLOR := Color(0.42, 0.82, 1.0)

var selected_active_item_index := 0
var cooldown_complete_flash: Dictionary = {}
var pickup_pop: Dictionary = {}
var slot_flights: Array = []


func reset() -> void:
	selected_active_item_index = 0
	cooldown_complete_flash.clear()
	pickup_pop.clear()
	slot_flights.clear()


func set_selected_index(index: int) -> void:
	selected_active_item_index = max(0, index)


func get_selected_index() -> int:
	return selected_active_item_index


func get_cooldown_complete_flash() -> Dictionary:
	return cooldown_complete_flash


func get_pickup_pop() -> Dictionary:
	return pickup_pop


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
		"pickup_pop_pulse": 0.0,
		"flight_incoming": false,
	}
	status["flight_incoming"] = not item_data.is_empty() and is_slot_flight_incoming(slot_index, current_time_msec)
	_update_pickup_pop_status(status, slot_index, item_data, current_time_msec)

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


func _update_pickup_pop_status(status: Dictionary, slot_index: int, item_data: Dictionary, current_time_msec: int) -> void:
	var item_key: String = _build_pickup_item_key(item_data)
	if item_key == "":
		pickup_pop.erase(slot_index)
		return

	var entry: Dictionary = {}
	var existing: Variant = pickup_pop.get(slot_index, {})
	if existing is Dictionary:
		entry = existing
	var previous_item_key: String = str(entry.get("item_key", ""))
	if previous_item_key != item_key:
		var start_msec: int = current_time_msec
		if previous_item_key != "":
			start_msec = current_time_msec - PICKUP_POP_DURATION_MS
		else:
			# Fresh empty -> item transition. If an acquisition flight is carrying this
			# item into the slot, defer the pop start to the landing frame so the pop
			# fires as the icon snaps home instead of on an empty (mid-flight) box.
			var land_delay: int = _flight_land_delay_ms(item_key, current_time_msec)
			if land_delay > 0:
				start_msec = current_time_msec + land_delay
		entry = {
			"item_key": item_key,
			"start_msec": start_msec,
		}
		pickup_pop[slot_index] = entry
		if previous_item_key != "":
			status["pickup_pop_pulse"] = 0.0
			return

	var elapsed_msec: int = current_time_msec - int(entry.get("start_msec", current_time_msec))
	if elapsed_msec < 0:
		# Start is deliberately in the future (flight-deferred landing pop); wait quietly.
		status["pickup_pop_pulse"] = 0.0
		return
	if elapsed_msec >= PICKUP_POP_DURATION_MS:
		status["pickup_pop_pulse"] = 0.0
		return
	var progress: float = float(elapsed_msec) / float(PICKUP_POP_DURATION_MS)
	var envelope: float = progress / 0.20 if progress < 0.20 else 1.0 - ((progress - 0.20) / 0.80)
	status["pickup_pop_pulse"] = clamp(envelope, 0.0, 1.0)


func _build_pickup_item_key(item_data: Dictionary) -> String:
	var identity: String = str(item_data.get("uid", ""))
	if identity == "":
		identity = str(item_data.get("instance_id", ""))
	if identity == "":
		identity = str(item_data.get("name", ""))
	if identity == "":
		return ""
	return identity


func register_slot_flight(item_data: Dictionary, slot_index: int, source_field_pos: Vector2, now_msec: int) -> void:
	if slot_index < 0 or item_data.is_empty():
		return
	var item_key: String = _build_pickup_item_key(item_data)
	if item_key == "":
		return
	# One live flight per item identity: a re-registration (e.g. a same-frame retry)
	# replaces the prior in-flight entry instead of stacking a duplicate.
	var filtered: Array = []
	for existing in slot_flights:
		if existing is Dictionary and str((existing as Dictionary).get("item_key", "")) == item_key:
			continue
		filtered.append(existing)
	slot_flights = filtered
	slot_flights.append({
		"item_key": item_key,
		"slot_index": slot_index,
		"source_field_pos": source_field_pos,
		"start_msec": now_msec,
		"item_data": item_data.duplicate(true),
		"color": _resolve_flight_color(item_data),
	})
	while slot_flights.size() > SLOT_FLIGHT_MAX_ACTIVE:
		slot_flights.remove_at(0)


func is_slot_flight_incoming(slot_index: int, now_msec: int) -> bool:
	for entry_value in slot_flights:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if int(entry.get("slot_index", -1)) != slot_index:
			continue
		var elapsed: int = now_msec - int(entry.get("start_msec", now_msec))
		if elapsed >= 0 and elapsed < SLOT_FLIGHT_DURATION_MS:
			return true
	return false


# Returns lightweight per-flight view dicts (slot_index, source_field_pos, item_data,
# color, progress) for still-travelling flights, and prunes any that have landed. The
# renderer is the single caller so pruning happens exactly once per drawn frame.
func get_active_slot_flights(now_msec: int) -> Array:
	var active: Array = []
	var kept: Array = []
	for entry_value in slot_flights:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var elapsed: int = max(0, now_msec - int(entry.get("start_msec", now_msec)))
		if elapsed >= SLOT_FLIGHT_DURATION_MS:
			continue
		kept.append(entry)
		active.append({
			"slot_index": int(entry.get("slot_index", -1)),
			"source_field_pos": entry.get("source_field_pos", Vector2.ZERO),
			"item_data": entry.get("item_data", {}),
			"color": entry.get("color", DEFAULT_FLIGHT_COLOR),
			"progress": clamp(float(elapsed) / float(SLOT_FLIGHT_DURATION_MS), 0.0, 1.0),
		})
	slot_flights = kept
	return active


func get_slot_flights() -> Array:
	return slot_flights


func _flight_land_delay_ms(item_key: String, now_msec: int) -> int:
	for entry_value in slot_flights:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("item_key", "")) != item_key:
			continue
		var elapsed: int = now_msec - int(entry.get("start_msec", now_msec))
		if elapsed < 0 or elapsed >= SLOT_FLIGHT_DURATION_MS:
			return 0
		return max(0, SLOT_FLIGHT_DURATION_MS - elapsed)
	return 0


func _resolve_flight_color(item_data: Dictionary) -> Color:
	var color_value: Variant = item_data.get("color", null)
	if color_value is Color:
		return color_value
	return DEFAULT_FLIGHT_COLOR


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
