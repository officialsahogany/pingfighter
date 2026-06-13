extends RefCounted

const MAX_ENHANCEMENT_LEVEL := 10
const ENHANCEMENT_RATES := {
	0: {"success": 80, "maintain": 19, "fail": 1},
	1: {"success": 75, "maintain": 22, "fail": 3},
	2: {"success": 70, "maintain": 25, "fail": 5},
	3: {"success": 65, "maintain": 27, "fail": 8},
	4: {"success": 60, "maintain": 27, "fail": 13},
	5: {"success": 50, "maintain": 33, "fail": 17},
	6: {"success": 42, "maintain": 36, "fail": 22},
	7: {"success": 35, "maintain": 40, "fail": 25},
	8: {"success": 30, "maintain": 40, "fail": 30},
	9: {"success": 23, "maintain": 45, "fail": 32},
}
const ENHANCEMENT_COSTS := {
	0: 100,
	1: 150,
	2: 200,
	3: 300,
	4: 400,
	5: 500,
	6: 600,
	7: 700,
	8: 800,
	9: 900,
}
const ENHANCEMENT_BONUSES := {
	0: 0,
	1: 10,
	2: 22,
	3: 36,
	4: 52,
	5: 70,
	6: 90,
	7: 115,
	8: 145,
	9: 190,
	10: 260,
}

var _rng := RandomNumberGenerator.new()
var _forced_roll_for_test := -1


func _init() -> void:
	_rng.randomize()


static func get_menu_action_labels() -> Array[String]:
	return ["마지막 아이템 강화"]


static func get_enhancement_cost(level: int) -> int:
	return maxi(1, int(ENHANCEMENT_COSTS.get(clampi(level, 0, MAX_ENHANCEMENT_LEVEL - 1), 1000)))


static func get_enhancement_bonus_pct(level: int) -> int:
	return maxi(0, int(ENHANCEMENT_BONUSES.get(clampi(level, 0, MAX_ENHANCEMENT_LEVEL), 0)))


func force_next_roll_for_test(roll_value: int) -> void:
	_forced_roll_for_test = clampi(roll_value, 1, 100)


func perform_action(
	action_index: int,
	save_store: Object,
	owner: Object,
	consume_ap: bool
) -> Dictionary:
	if action_index != 0:
		return _build_summary("", "", "", -1, 0, 0, 0, {}, false, false, "unknown_blacksmith_action")
	return _enhance_last_active_item(save_store, owner, consume_ap)


func get_target_summary(owner: Object) -> Dictionary:
	var entry := _get_last_active_item_entry(owner)
	if entry.is_empty():
		return {
			"has_target": false,
			"display_name": "",
			"item_name": "",
			"level": 0,
			"cost": 0,
			"bonus_pct": 0,
		}
	var item: Dictionary = entry.get("item", {})
	var level := clampi(int(item.get("enhancement_level", 0)), 0, MAX_ENHANCEMENT_LEVEL)
	return {
		"has_target": true,
		"display_name": _get_display_name(item),
		"item_name": _get_item_identity(item),
		"level": level,
		"cost": 0 if level >= MAX_ENHANCEMENT_LEVEL else get_enhancement_cost(level),
		"bonus_pct": get_enhancement_bonus_pct(level),
	}


func _enhance_last_active_item(save_store: Object, owner: Object, consume_ap: bool) -> Dictionary:
	if owner == null:
		return _build_summary("enhance", "", "", -1, 0, 0, 0, {}, false, false, "missing_owner")
	var entry := _get_last_active_item_entry(owner)
	if entry.is_empty():
		return _build_summary("enhance", "", "", -1, 0, 0, 0, {}, false, false, "no_active_item")
	var item: Dictionary = entry.get("item", {})
	var slot_index := int(entry.get("slot_index", -1))
	var item_name := _get_item_identity(item)
	var display_name := _get_display_name(item)
	var previous_level := clampi(int(item.get("enhancement_level", 0)), 0, MAX_ENHANCEMENT_LEVEL)
	if previous_level >= MAX_ENHANCEMENT_LEVEL:
		return _build_summary("enhance", item_name, display_name, slot_index, previous_level, previous_level, 0, _get_rates(previous_level), false, false, "max_level")
	var cost := get_enhancement_cost(previous_level)
	if not _has_plaza_gold(save_store, cost):
		return _build_summary("enhance", item_name, display_name, slot_index, previous_level, previous_level, cost, _get_rates(previous_level), false, false, "not_enough_gold")
	if _is_ap_blocked(save_store, consume_ap):
		return _build_summary("enhance", item_name, display_name, slot_index, previous_level, previous_level, cost, _get_rates(previous_level), false, false, "no_ap")
	var payment := _perform_enhancement_payment(save_store, cost, consume_ap)
	if not bool(payment.get("changed", false)):
		return _merge_wallet_summary(
			_build_summary("enhance", item_name, display_name, slot_index, previous_level, previous_level, cost, _get_rates(previous_level), false, false, str(payment.get("reason", "payment_failed"))),
			payment
		)
	var roll := _roll_once()
	var result := _get_roll_result(previous_level, roll)
	var next_level := previous_level
	var item_changed := false
	if result == "success":
		next_level = mini(MAX_ENHANCEMENT_LEVEL, previous_level + 1)
		item_changed = _write_enhanced_item(owner, slot_index, next_level)
	var summary := _build_summary(
		"enhance",
		item_name,
		display_name,
		slot_index,
		previous_level,
		next_level,
		cost,
		_get_rates(previous_level),
		true,
		item_changed,
		"ok"
	)
	summary["result"] = result
	summary["roll"] = roll
	summary["enhancement_bonus_pct"] = get_enhancement_bonus_pct(next_level)
	return _merge_wallet_summary(summary, payment)


func _write_enhanced_item(owner: Object, slot_index: int, next_level: int) -> bool:
	var value: Variant = owner.get("active_item_slots")
	if not (value is Array):
		return false
	var slots: Array = (value as Array).duplicate(true)
	if slot_index < 0 or slot_index >= slots.size():
		return false
	if not (slots[slot_index] is Dictionary):
		return false
	var item: Dictionary = slots[slot_index]
	item["enhancement_level"] = next_level
	item["enhancement_bonus_pct"] = get_enhancement_bonus_pct(next_level)
	slots[slot_index] = item
	owner.set("active_item_slots", slots)
	return true


func _get_roll_result(level: int, roll: int) -> String:
	var rates := _get_rates(level)
	var success := int(rates.get("success", 0))
	var maintain := int(rates.get("maintain", 0))
	if roll <= success:
		return "success"
	if roll <= success + maintain:
		return "maintain"
	return "fail"


func _roll_once() -> int:
	if _forced_roll_for_test > 0:
		var forced_roll := _forced_roll_for_test
		_forced_roll_for_test = -1
		return forced_roll
	return _rng.randi_range(1, 100)


func _get_rates(level: int) -> Dictionary:
	return (ENHANCEMENT_RATES.get(clampi(level, 0, MAX_ENHANCEMENT_LEVEL - 1), {"success": 10, "maintain": 50, "fail": 40}) as Dictionary).duplicate(true)


func _get_last_active_item_entry(owner: Object) -> Dictionary:
	if owner == null:
		return {}
	var value: Variant = owner.get("active_item_slots")
	if not (value is Array):
		return {}
	var active_item_slots: Array = value
	for index in range(active_item_slots.size() - 1, -1, -1):
		var item_value: Variant = active_item_slots[index]
		if not (item_value is Dictionary):
			continue
		var item_data: Dictionary = item_value
		if _get_item_identity(item_data) != "":
			return {
				"slot_index": index,
				"item": item_data.duplicate(true),
			}
	return {}


func _get_item_identity(item_data: Dictionary) -> String:
	for key in ["name", "effect", "item_name", "item_id"]:
		var value := str(item_data.get(str(key), ""))
		if value != "":
			return value
	return ""


func _get_display_name(item_data: Dictionary) -> String:
	var display_name := str(item_data.get("display_name", ""))
	if display_name != "":
		return display_name
	var item_name := _get_item_identity(item_data)
	return item_name if item_name != "" else "아이템"


func _has_plaza_gold(save_store: Object, amount: int) -> bool:
	return save_store != null and save_store.has_method("get_plaza_gold") and int(save_store.get_plaza_gold()) >= amount


func _is_ap_blocked(save_store: Object, consume_ap: bool) -> bool:
	return consume_ap and (save_store == null or not save_store.has_method("get_ap_current") or int(save_store.get_ap_current()) <= 0)


func _perform_enhancement_payment(save_store: Object, cost: int, consume_ap: bool) -> Dictionary:
	if save_store == null or not save_store.has_method("perform_blacksmith_enhancement_payment"):
		return _build_wallet_summary(0, false, "missing_plaza_save_store")
	var result: Variant = save_store.perform_blacksmith_enhancement_payment(cost, consume_ap)
	if result is Dictionary:
		return result
	return _build_wallet_summary(0, false, "invalid_wallet_result")


func _merge_wallet_summary(summary: Dictionary, wallet_summary: Dictionary) -> Dictionary:
	summary["wallet_summary"] = wallet_summary.duplicate(true)
	summary["delta_gold"] = int(wallet_summary.get("delta_gold", summary.get("delta_gold", 0)))
	summary["ap_spent"] = int(wallet_summary.get("ap_spent", summary.get("ap_spent", 0)))
	summary["plaza_gold"] = int(wallet_summary.get("plaza_gold", summary.get("plaza_gold", 0)))
	summary["ap_current"] = int(wallet_summary.get("ap_current", summary.get("ap_current", 0)))
	summary["reason"] = str(wallet_summary.get("reason", summary.get("reason", "")))
	summary["changed"] = bool(wallet_summary.get("changed", summary.get("changed", false)))
	return summary


func _build_wallet_summary(delta_gold: int, changed: bool, reason: String) -> Dictionary:
	return {
		"action": "enhance",
		"handled": true,
		"changed": changed,
		"reason": reason,
		"delta_gold": delta_gold,
		"ap_spent": 0,
	}


func _build_summary(
	action_id: String,
	item_name: String,
	display_name: String,
	slot_index: int,
	previous_level: int,
	new_level: int,
	cost: int,
	rates: Dictionary,
	changed: bool,
	item_changed: bool,
	reason: String
) -> Dictionary:
	return {
		"action": action_id,
		"item_name": item_name,
		"display_name": display_name,
		"slot_index": slot_index,
		"previous_level": previous_level,
		"new_level": new_level,
		"cost": cost,
		"rates": rates.duplicate(true),
		"handled": action_id == "enhance",
		"changed": changed,
		"item_changed": item_changed,
		"reason": reason,
		"result": "",
		"roll": 0,
		"enhancement_bonus_pct": get_enhancement_bonus_pct(new_level),
		"delta_gold": 0,
		"ap_spent": 0,
	}
