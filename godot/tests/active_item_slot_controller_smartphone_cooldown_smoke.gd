extends SceneTree

# Regression seal for the "lone active item stops working when you have the
# Smartphone passive" bug. The Smartphone auto-uses recovery / defense items via
# use_first_matching_item(..., ignore_cooldown = true). Each auto-use ran through
# _try_use_slot, which bumped BOTH the shared global cooldown anchor
# (last_item_use_msec) AND the per-item last_use_msec of every remaining slot. So
# the instant the Smartphone auto-consumed an item, the player's remaining (often
# lone) item was blocked for the full checked-item cooldown — it read as "the
# first item does nothing". Confirmed in live godot.log:
#   USED slot=1 item=gauge_charge        (Smartphone auto-use)
#   BLOCKED global-cooldown item=dash_boost now=569798 anchor=569781 ...  (lone)
#
# Fix: an ignore_cooldown use (Smartphone) must be cooldown-NEUTRAL toward the
# player's manual slots — it must not bump the global anchor nor the other slots'
# per-item cooldown. Manual uses keep imposing the shared global cooldown.

const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var special_gauge := 0.0
	var active_item_slots: Array = []


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


func _init() -> void:
	_verify_smartphone_auto_use_does_not_poison_lone_item()
	_verify_smartphone_scan_does_not_consume_manual_key_edge()
	_verify_manual_use_still_imposes_global_cooldown()

	if _failures.is_empty():
		print("active_item_slot_controller_smartphone_cooldown_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


# The bug case: a Smartphone auto-use (ignore_cooldown = true) consumes one item
# and must leave the remaining lone item immediately usable.
func _verify_smartphone_auto_use_does_not_poison_lone_item() -> void:
	var controller: Object = ActiveItemSlotController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	# Constructor default global anchor is -1000000 (fully clear).
	var slots: Array = [
		{"name": "dash_boost", "cooldown_msec": 7000, "last_use_msec": -1},
		{"name": "gauge_charge", "cooldown_msec": 7000, "last_use_msec": -1},
	]

	# Smartphone auto-uses gauge_charge (slot 1) bypassing cooldown.
	var used: bool = controller._try_use_slot(
		1,
		slots,
		owner,
		registry,
		Callable(self, "_apply_item_effect"),
		Callable(self, "_backup_pending_use"),
		true
	)
	_expect(used, "smartphone auto-use should apply the effect")
	_expect(slots.size() == 1, "consumable auto-used item should be removed, leaving the lone item")

	_expect(
		int(controller.last_item_use_msec) == -1000000,
		"smartphone auto-use must NOT bump the shared global cooldown anchor"
	)

	var lone: Dictionary = slots[0]
	_expect(str(lone.get("name", "")) == "dash_boost", "remaining lone item should be dash_boost")
	_expect(
		int(lone.get("last_use_msec", 0)) == -1,
		"smartphone auto-use must NOT poison the remaining item's per-item cooldown"
	)
	_expect(
		controller._is_item_ready(lone, Time.get_ticks_msec(), registry),
		"lone item must stay usable immediately after a smartphone auto-use"
	)


func _verify_smartphone_scan_does_not_consume_manual_key_edge() -> void:
	var controller: Object = ActiveItemSlotController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	owner.active_item_slots = [
		{"name": "dash_boost", "cooldown_msec": 0, "last_use_msec": -1},
	]
	controller.slot_key_pressed[0] = true

	var scanned_item: String = str(controller.use_first_matching_item(
		["life_elixir", "gauge_charge"],
		owner,
		registry,
		false,
		Callable(self, "_apply_item_effect"),
		Callable(self, "_backup_pending_use"),
		true
	))

	_expect(scanned_item == "", "smartphone recovery scan should not auto-use unrelated active items")
	_expect(
		bool(controller.slot_key_pressed.get(0, false)),
		"smartphone no-match scan must not rewrite the player's active-item key edge state"
	)
	_expect(owner.active_item_slots.size() == 1, "smartphone no-match scan should leave unrelated active slots intact")


# The intended manual behavior must be preserved: a player MANUAL use still puts
# the other slots (and the global anchor) on the shared cooldown.
func _verify_manual_use_still_imposes_global_cooldown() -> void:
	var controller: Object = ActiveItemSlotController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var slots: Array = [
		{"name": "banana", "cooldown_msec": 3000, "last_use_msec": -1},
		{"name": "dash_boost", "cooldown_msec": 7000, "last_use_msec": -1},
	]

	# Player manually uses banana (slot 0); ignore_cooldown = false.
	var used: bool = controller._try_use_slot(
		0,
		slots,
		owner,
		registry,
		Callable(self, "_apply_item_effect"),
		Callable(self, "_backup_pending_use"),
		false
	)
	_expect(used, "manual use should apply the effect")
	_expect(slots.size() == 1, "consumable manual item should be removed")

	_expect(
		int(controller.last_item_use_msec) != -1000000,
		"manual use must still bump the shared global cooldown anchor"
	)
	var remaining: Dictionary = slots[0]
	_expect(
		int(remaining.get("last_use_msec", -1)) > 0,
		"manual use must still put the remaining item on the shared cooldown"
	)
	_expect(
		not controller._is_item_ready(remaining, Time.get_ticks_msec(), registry),
		"remaining item must be blocked immediately after a MANUAL use (intended global cooldown)"
	)


func _apply_item_effect(_item_data: Dictionary, _owner: Object, _registry: Object) -> bool:
	return true


func _backup_pending_use(_item_data: Dictionary, _slot_index: int, _owner: Object, _registry: Object) -> void:
	pass


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
