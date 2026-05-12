extends SceneTree

const ActiveItemSmartphoneAutoUse := preload("res://scripts/items/active_item_smartphone_auto_use.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var special_gauge := 0.0


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


class FakeSlotController:
	extends RefCounted

	var selected_item := ""
	var last_priority_names: Array = []
	var last_ignore_cooldown := false
	var last_input_locked := true
	var saw_apply_callback := false
	var saw_backup_callback := false

	func use_first_matching_item(
		item_names: Array,
		_owner: Object,
		_registry: Object,
		input_locked: bool,
		apply_item_effect_callback: Callable,
		pending_use_backup_callback: Callable,
		ignore_cooldown: bool = false
	) -> String:
		last_priority_names = item_names.duplicate()
		last_input_locked = input_locked
		last_ignore_cooldown = ignore_cooldown
		saw_apply_callback = apply_item_effect_callback.is_valid()
		saw_backup_callback = pending_use_backup_callback.is_valid()
		return selected_item


class FakeEffectController:
	extends RefCounted

	var recovery_upward_calls := 0

	func force_stopwatch_recovery_upward() -> void:
		recovery_upward_calls += 1


func _init() -> void:
	_verify_recovery_priority_and_threshold()
	_verify_defense_priority_and_stopwatch_nudge()
	_verify_null_inputs_are_noop()

	if _failures.is_empty():
		print("active_item_smartphone_auto_use_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_recovery_priority_and_threshold() -> void:
	var helper: Object = ActiveItemSmartphoneAutoUse.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var slot_controller := FakeSlotController.new()
	owner.special_gauge = 100.0
	slot_controller.selected_item = "life_elixir"

	var used_item: String = helper.try_auto_recovery(
		owner,
		registry,
		120.0,
		slot_controller,
		Callable(self, "_apply_item_effect"),
		Callable(self, "_backup_pending_use")
	)
	_expect(used_item == "life_elixir", "Smartphone recovery should return the slot controller result")
	_expect(slot_controller.last_priority_names == ["life_elixir", "gauge_charge"], "Smartphone recovery should prefer Life Elixir before gauge charge")
	_expect(not slot_controller.last_input_locked, "Smartphone recovery should not lock slot input")
	_expect(slot_controller.last_ignore_cooldown, "Smartphone recovery should bypass item cooldown")
	_expect(slot_controller.saw_apply_callback and slot_controller.saw_backup_callback, "Smartphone recovery should pass callbacks through")

	owner.special_gauge = 200.0
	slot_controller.last_priority_names.clear()
	used_item = helper.try_auto_recovery(
		owner,
		registry,
		120.0,
		slot_controller,
		Callable(self, "_apply_item_effect"),
		Callable(self, "_backup_pending_use")
	)
	_expect(used_item == "", "Smartphone recovery should skip above the gauge threshold")
	_expect(slot_controller.last_priority_names.is_empty(), "Smartphone recovery should not query slots above threshold")


func _verify_defense_priority_and_stopwatch_nudge() -> void:
	var helper: Object = ActiveItemSmartphoneAutoUse.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var slot_controller := FakeSlotController.new()
	var effect_controller := FakeEffectController.new()
	slot_controller.selected_item = "stopwatch"

	var used_item: String = helper.try_auto_defense(
		owner,
		registry,
		slot_controller,
		effect_controller,
		Callable(self, "_apply_item_effect"),
		Callable(self, "_backup_pending_use")
	)
	_expect(used_item == "stopwatch", "Smartphone defense should return the slot controller result")
	_expect(slot_controller.last_priority_names == ["stopwatch", "holy_barrier"], "Smartphone defense should prefer Stopwatch before Holy Barrier")
	_expect(effect_controller.recovery_upward_calls == 1, "Smartphone defense should nudge Stopwatch recovery upward")

	slot_controller.selected_item = "holy_barrier"
	used_item = helper.try_auto_defense(
		owner,
		registry,
		slot_controller,
		effect_controller,
		Callable(self, "_apply_item_effect"),
		Callable(self, "_backup_pending_use")
	)
	_expect(used_item == "holy_barrier", "Smartphone defense should return Holy Barrier fallback")
	_expect(effect_controller.recovery_upward_calls == 1, "Smartphone defense should only nudge Stopwatch")


func _verify_null_inputs_are_noop() -> void:
	var helper: Object = ActiveItemSmartphoneAutoUse.new()
	var registry := FakeRegistry.new()
	var slot_controller := FakeSlotController.new()

	_expect(helper.try_auto_recovery(null, registry, 120.0, slot_controller, Callable(), Callable()) == "", "Smartphone recovery should ignore null owner")
	_expect(helper.try_auto_defense(null, registry, null, null, Callable(), Callable()) == "", "Smartphone defense should ignore null owner/slot controller")


func _apply_item_effect(_item_data: Dictionary, _owner: Object, _registry: Object) -> bool:
	return true


func _backup_pending_use(_item_data: Dictionary, _slot_index: int, _owner: Object, _registry: Object) -> void:
	pass


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
