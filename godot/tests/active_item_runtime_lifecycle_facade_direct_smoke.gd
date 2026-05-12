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

	func build_starting_slots() -> Array:
		return starting_slots


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


func _verify_lifecycle_facade_forwards_starting_slots() -> void:
	var facade: Object = ActiveItemRuntimeLifecycleFacade.new()
	var runtime := FakeRuntime.new()
	var slots: Array = facade.build_starting_slots(runtime)

	_expect(slots.size() == 1, "lifecycle facade should forward starting slot count")
	_expect(str(slots[0].get("name", "")) == "starter", "lifecycle facade should forward starting slot content")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
