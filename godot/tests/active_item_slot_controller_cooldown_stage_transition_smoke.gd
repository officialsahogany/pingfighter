extends SceneTree

const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_stage_transition_resets_global_anchor()
	_verify_stage_transition_clears_per_item_last_use()
	_verify_stage_transition_preserves_slot_data()
	_verify_stage_transition_normalizes_item_id_alias()
	_verify_stage_transition_handles_non_dictionary_entries()

	if _failures.is_empty():
		print("active_item_slot_controller_cooldown_stage_transition_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage_transition_resets_global_anchor() -> void:
	var controller: Object = ActiveItemSlotController.new()
	controller.last_item_use_msec = 123456
	var _result: Array = controller.reset_cooldowns_for_stage_transition([])
	_expect(
		int(controller.last_item_use_msec) == -1000000,
		"stage transition cooldown reset should rewind global last_item_use_msec to -1000000"
	)


func _verify_stage_transition_clears_per_item_last_use() -> void:
	var controller: Object = ActiveItemSlotController.new()
	controller.last_item_use_msec = 999999
	var slots: Array = [
		{"name": "regen_potion", "last_use_msec": 999999},
		{"name": "brick_wall", "last_use_msec": 999000, "last_use": 999000},
		{"name": "fresh_item", "last_use_msec": -1},
	]
	var cleaned: Array = controller.reset_cooldowns_for_stage_transition(slots)
	_expect(cleaned.size() == 3, "cleaned slots should preserve slot count")
	_expect(
		int(cleaned[0].get("last_use_msec", 0)) == -1,
		"first slot per-item cooldown should be cleared"
	)
	_expect(
		int(cleaned[1].get("last_use_msec", 0)) == -1 and int(cleaned[1].get("last_use", 0)) == -1,
		"second slot should clear both last_use_msec and legacy last_use keys"
	)
	_expect(
		int(cleaned[2].get("last_use_msec", 0)) == -1,
		"already-fresh slot should stay fresh"
	)


func _verify_stage_transition_preserves_slot_data() -> void:
	var controller: Object = ActiveItemSlotController.new()
	var slots: Array = [
		{"name": "regen_potion", "cooldown_msec": 9100, "last_use_msec": 5000, "rolls": {"value": 1}},
	]
	var cleaned: Array = controller.reset_cooldowns_for_stage_transition(slots)
	_expect(
		str(cleaned[0].get("name", "")) == "regen_potion",
		"slot name should be preserved"
	)
	_expect(
		int(cleaned[0].get("cooldown_msec", 0)) == 9100,
		"slot cooldown_msec should be preserved"
	)
	var rolls_value: Variant = cleaned[0].get("rolls", null)
	_expect(
		rolls_value is Dictionary and int(rolls_value.get("value", 0)) == 1,
		"slot nested rolls payload should be preserved (deep duplicate)"
	)
	_expect(
		int(slots[0].get("last_use_msec", 0)) == 5000,
		"input array should not be mutated in place"
	)


func _verify_stage_transition_normalizes_item_id_alias() -> void:
	var controller: Object = ActiveItemSlotController.new()
	var slots: Array = [
		{"item_id": "long_boost", "last_use_msec": 5000},
	]
	var cleaned: Array = controller.reset_cooldowns_for_stage_transition(slots)
	_expect(cleaned.size() == 1, "item_id-only slot should survive stage-transition cleanup")
	_expect(
		str(cleaned[0].get("name", "")) == "long_boost",
		"item_id-only slot should be normalized to the runtime name key"
	)
	_expect(
		str(cleaned[0].get("item_id", "")) == "long_boost",
		"item_id alias should be preserved for callers that still read it"
	)
	_expect(
		int(cleaned[0].get("last_use_msec", 0)) == -1,
		"item_id-only slot cooldown should still be cleared"
	)


func _verify_stage_transition_handles_non_dictionary_entries() -> void:
	var controller: Object = ActiveItemSlotController.new()
	var slots: Array = [
		null,
		{"name": "regen_potion", "last_use_msec": 5000},
		"unexpected_string",
	]
	var cleaned: Array = controller.reset_cooldowns_for_stage_transition(slots)
	_expect(cleaned.size() == 3, "non-dictionary slots should not be dropped")
	_expect(
		cleaned[0] == null,
		"null slot entry should pass through untouched"
	)
	_expect(
		int(cleaned[1].get("last_use_msec", 0)) == -1,
		"valid slot between non-dictionary entries should still be cleaned"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
