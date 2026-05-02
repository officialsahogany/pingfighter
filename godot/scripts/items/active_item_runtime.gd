extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const DEFAULT_COOLDOWN_MSEC := 10000
const GAUGE_MAX := 500.0
const GAUGE_CHARGE_AMOUNT := 220.0
const GAUGE_CHARGE_ICON_PATH := "res://assets/sprites/items/gauge_200.png"
const SLOT_KEY_CODES := [KEY_1, KEY_2, KEY_3]

var slot_key_pressed: Dictionary = {}


func reset() -> void:
	slot_key_pressed.clear()


func build_starting_slots() -> Array:
	return [_build_gauge_charge()]


func update(owner: Object, registry: Object, _delta: float) -> Dictionary:
	if owner == null:
		return {}

	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	if active_item_slots.is_empty():
		return {}

	var slots_copy: Array = active_item_slots.duplicate(true)
	var used_slot: int = -1
	var key_count: int = int(min(slots_copy.size(), SLOT_KEY_CODES.size()))
	for i in range(key_count):
		var pressed: bool = Input.is_key_pressed(int(SLOT_KEY_CODES[i]))
		var was_pressed: bool = bool(slot_key_pressed.get(i, false))
		slot_key_pressed[i] = pressed
		if pressed and not was_pressed:
			if _try_use_slot(i, slots_copy, owner, registry):
				used_slot = i
				break

	if used_slot >= 0:
		owner.set("active_item_slots", slots_copy)

	return {
		"used_slot": used_slot,
	}


func _try_use_slot(slot_index: int, active_item_slots: Array, owner: Object, registry: Object) -> bool:
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

	if not _apply_item_effect(item_data, owner, registry):
		return false

	item_data["last_use_msec"] = now_msec
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


func _apply_item_effect(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	var item_name: String = str(item_data.get("name", ""))
	var effect_name: String = str(item_data.get("effect", item_name))
	if item_name == "gauge_charge" or effect_name == "gauge_charge":
		return _apply_gauge_charge(item_data, owner, registry)
	return false


func _apply_gauge_charge(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	var gauge_gain: float = float(item_data.get("gauge_gain", GAUGE_CHARGE_AMOUNT))
	var gauge_max: float = _get_effective_gauge_max(owner, item_data)
	var current_gauge: float = float(BattleSceneOwnerReader.get_value(owner, "special_gauge", 0.0))
	var next_gauge: float = min(gauge_max, current_gauge + gauge_gain)
	owner.set("special_gauge", next_gauge)

	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback != null:
		if feedback.has_method("trigger_gauge_flash"):
			feedback.trigger_gauge_flash()
		if feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(0.06, 1.6)

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_drink"):
		audio.play_drink()

	return true


func _get_effective_gauge_max(owner: Object, item_data: Dictionary) -> float:
	var fallback_max: float = max(1.0, float(item_data.get("gauge_max", GAUGE_MAX)))
	return max(1.0, float(BattleSceneOwnerReader.get_value(owner, "special_gauge_max", fallback_max)))


func _is_item_ready(item_data: Dictionary, now_msec: int) -> bool:
	var last_use_msec: int = int(item_data.get("last_use_msec", item_data.get("last_use", -1)))
	if last_use_msec < 0:
		return true
	var cooldown_msec: int = max(0, int(item_data.get("cooldown_msec", DEFAULT_COOLDOWN_MSEC)))
	return now_msec - last_use_msec >= cooldown_msec


func _select_slot(registry: Object, slot_index: int) -> void:
	var hud_state: Object = _get_instance(registry, "active_item_hud_state")
	if hud_state != null and hud_state.has_method("set_selected_index"):
		hud_state.set_selected_index(slot_index)


func _build_gauge_charge() -> Dictionary:
	return {
		"name": "gauge_charge",
		"display_name": "Energy Drink",
		"type": "active",
		"effect": "gauge_charge",
		"chance": 0.042,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"gauge_gain": GAUGE_CHARGE_AMOUNT,
		"gauge_max": GAUGE_MAX,
		"icon_path": GAUGE_CHARGE_ICON_PATH,
		"color": Color(1.0, 100.0 / 255.0, 1.0),
		"consumable": true,
	}


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
