extends SceneTree

const ActiveItemRuntimeLifecycleFacade := preload("res://scripts/items/active_item_runtime_lifecycle_facade.gd")

var _failures: Array[String] = []


class FakeResetController:
	extends RefCounted

	var reset_calls := 0

	func reset() -> void:
		reset_calls += 1


class FakeSlotController:
	extends FakeResetController

	var starting_slots: Array = [{"name": "starter"}]
	var cooldown_reset_calls := 0

	func build_starting_slots() -> Array:
		return starting_slots

	func reset_cooldowns_for_stage_transition(active_item_slots: Array) -> Array:
		cooldown_reset_calls += 1
		var result: Array = active_item_slots.duplicate(true)
		for i in range(result.size()):
			var item_value: Variant = result[i]
			if item_value is Dictionary:
				var item_data: Dictionary = item_value
				item_data["last_use_msec"] = -1
				result[i] = item_data
		return result


class FakeOwner:
	extends RefCounted

	var active_item_slots := [
		{"name": "aipill", "last_use_msec": 12345},
		{"name": "grenade", "last_use_msec": 23456},
	]


class FakeRuntime:
	extends RefCounted

	var slot_controller := FakeSlotController.new()
	var field_spawn_controller := FakeResetController.new()
	var throw_controller := FakeResetController.new()
	var effect_controller := FakeResetController.new()
	var debug_spawn_menu := FakeResetController.new()
	var pending_throw_recovery := FakeResetController.new()


func _init() -> void:
	_verify_lifecycle_facade_resets_runtime_state()
	_verify_lifecycle_facade_resets_stage_transition_runtime_state_without_losing_slots()
	_verify_lifecycle_facade_forwards_starting_slots()

	if _failures.is_empty():
		print("active_item_runtime_lifecycle_facade_direct_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_lifecycle_facade_resets_runtime_state() -> void:
	var facade: Object = ActiveItemRuntimeLifecycleFacade.new()
	var runtime := FakeRuntime.new()

	facade.reset(runtime)

	_expect(runtime.slot_controller.reset_calls == 1, "lifecycle facade should reset slot controller")
	_expect(runtime.field_spawn_controller.reset_calls == 1, "lifecycle facade should reset field spawn controller")
	_expect(runtime.throw_controller.reset_calls == 1, "lifecycle facade should reset throw controller")
	_expect(runtime.effect_controller.reset_calls == 1, "lifecycle facade should reset effect controller")
	_expect(runtime.debug_spawn_menu.reset_calls == 1, "lifecycle facade should reset debug menu")
	_expect(runtime.pending_throw_recovery.reset_calls == 1, "lifecycle facade should reset pending throw recovery")


func _verify_lifecycle_facade_resets_stage_transition_runtime_state_without_losing_slots() -> void:
	var facade: Object = ActiveItemRuntimeLifecycleFacade.new()
	var runtime := FakeRuntime.new()
	var owner := FakeOwner.new()

	facade.reset_for_stage_transition(runtime, owner)

	_expect(runtime.field_spawn_controller.reset_calls == 1, "stage transition should reset active item field spawns")
	_expect(runtime.throw_controller.reset_calls == 1, "stage transition should reset active item throw state")
	_expect(runtime.effect_controller.reset_calls == 1, "stage transition should reset active item transient effects")
	_expect(runtime.debug_spawn_menu.reset_calls == 1, "stage transition should reset active item debug menu state")
	_expect(runtime.pending_throw_recovery.reset_calls == 1, "stage transition should reset pending throw recovery")
	_expect(runtime.slot_controller.reset_calls == 1, "stage transition should reset slot input/cooldown controller state")
	_expect(runtime.slot_controller.cooldown_reset_calls == 1, "stage transition should clear stored slot cooldowns")
	_expect(owner.active_item_slots.size() == 2, "stage transition should preserve active item inventory")
	_expect(int(owner.active_item_slots[0].get("last_use_msec", 0)) < 0, "stage transition should clear first slot cooldown")
	_expect(str(owner.active_item_slots[1].get("name", "")) == "grenade", "stage transition should keep slot item identity")


func _verify_lifecycle_facade_forwards_starting_slots() -> void:
	var facade: Object = ActiveItemRuntimeLifecycleFacade.new()
	var runtime := FakeRuntime.new()
	var slots: Array = facade.build_starting_slots(runtime)

	_expect(slots.size() == 1, "lifecycle facade should forward starting slot count")
	_expect(str(slots[0].get("name", "")) == "starter", "lifecycle facade should forward starting slot content")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
