extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const DEFAULT_COOLDOWN_MSEC := ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC
const SLOT_KEY_CODES := [KEY_1, KEY_2, KEY_3]
const MAX_ACTIVE_ITEM_SLOTS := 3

var slot_key_pressed: Dictionary = {}
var last_item_use_msec: int = -1000000


func reset() -> void:
	slot_key_pressed.clear()
	last_item_use_msec = -1000000


func build_starting_slots() -> Array:
	return []


func update(owner: Object, registry: Object, input_locked: bool, apply_item_effect_callback: Callable) -> Dictionary:
	if owner == null:
		return {}

	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	if active_item_slots.is_empty() or input_locked:
		_sync_slot_key_states()
		return {
			"used_slot": -1,
		}

	var slots_copy: Array = active_item_slots.duplicate(true)
	var used_slot: int = -1
	var key_count: int = int(min(slots_copy.size(), SLOT_KEY_CODES.size()))
	for i in range(SLOT_KEY_CODES.size()):
		var pressed: bool = Input.is_key_pressed(int(SLOT_KEY_CODES[i]))
		var was_pressed: bool = bool(slot_key_pressed.get(i, false))
		slot_key_pressed[i] = pressed
		if i < key_count and pressed and not was_pressed:
			if _try_use_slot(i, slots_copy, owner, registry, apply_item_effect_callback):
				used_slot = i
				break

	if used_slot >= 0:
		owner.set("active_item_slots", slots_copy)

	return {
		"used_slot": used_slot,
	}


func store_active_item(
	field_item: Dictionary,
	active_item_slots: Array,
	registry: Object,
	can_store_item_callback: Callable
) -> bool:
	if active_item_slots.size() >= MAX_ACTIVE_ITEM_SLOTS:
		return false

	var source_item_data: Dictionary = _get_dictionary(field_item, "item_data")
	var item_name: String = str(source_item_data.get("name", ""))
	if can_store_item_callback.is_valid() and not bool(can_store_item_callback.call(item_name)):
		return false

	source_item_data["revealed"] = true
	field_item["item_data"] = source_item_data
	var item_data: Dictionary = source_item_data.duplicate(true)
	item_data["revealed"] = true
	item_data["last_use_msec"] = last_item_use_msec
	active_item_slots.append(item_data)
	_select_slot(registry, active_item_slots.size() - 1)
	return true


func append_item_data(
	owner: Object,
	item_data: Dictionary,
	registry: Object,
	allow_overflow: bool = false,
	can_store_item_callback: Callable = Callable()
) -> bool:
	if owner == null or item_data.is_empty():
		return false
	var item_name: String = str(item_data.get("name", ""))
	if can_store_item_callback.is_valid() and not bool(can_store_item_callback.call(item_name)):
		return false

	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	if active_item_slots.size() >= MAX_ACTIVE_ITEM_SLOTS and not allow_overflow:
		return false

	var next_item: Dictionary = item_data.duplicate(true)
	next_item["revealed"] = true
	next_item["last_use_msec"] = last_item_use_msec
	active_item_slots.append(next_item)
	owner.set("active_item_slots", active_item_slots)
	_select_slot(registry, active_item_slots.size() - 1)
	return true


func _try_use_slot(
	slot_index: int,
	active_item_slots: Array,
	owner: Object,
	registry: Object,
	apply_item_effect_callback: Callable
) -> bool:
	if slot_index < 0 or slot_index >= active_item_slots.size():
		return false

	var item_value: Variant = active_item_slots[slot_index]
	if not (item_value is Dictionary):
		return false

	var item_data: Dictionary = item_value
	_select_slot(registry, slot_index)

	var now_msec: int = Time.get_ticks_msec()
	if not _is_item_ready(item_data, now_msec):
		return false

	if not apply_item_effect_callback.is_valid():
		return false
	if not bool(apply_item_effect_callback.call(item_data, owner, registry)):
		return false

	item_data["last_use_msec"] = now_msec
	last_item_use_msec = now_msec
	if bool(item_data.get("consumable", true)):
		active_item_slots.remove_at(slot_index)
		_select_slot(registry, max(0, min(slot_index, active_item_slots.size() - 1)))
	else:
		active_item_slots[slot_index] = item_data
	for i in range(active_item_slots.size()):
		var other_value: Variant = active_item_slots[i]
		if other_value is Dictionary:
			var other_item: Dictionary = other_value
			other_item["last_use_msec"] = now_msec
			active_item_slots[i] = other_item
	return true


func _sync_slot_key_states() -> void:
	for i in range(SLOT_KEY_CODES.size()):
		slot_key_pressed[i] = Input.is_key_pressed(int(SLOT_KEY_CODES[i]))


func _is_item_ready(item_data: Dictionary, now_msec: int) -> bool:
	var cooldown_msec: int = max(0, int(item_data.get("cooldown_msec", DEFAULT_COOLDOWN_MSEC)))
	if now_msec - last_item_use_msec < cooldown_msec:
		return false
	var last_use_msec: int = int(item_data.get("last_use_msec", item_data.get("last_use", -1)))
	if last_use_msec < 0:
		return true
	return now_msec - last_use_msec >= cooldown_msec


func _select_slot(registry: Object, slot_index: int) -> void:
	var hud_state: Object = _get_instance(registry, "active_item_hud_state")
	if hud_state != null and hud_state.has_method("set_selected_index"):
		hud_state.set_selected_index(slot_index)


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
