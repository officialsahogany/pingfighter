extends SceneTree

const ActiveItemHudState := preload("res://scripts/hud/active_item_hud_state.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []


class FakeRegistry:
	extends RefCounted

	var hud_state: Object = null
	var active_item_runtime: Object = null

	func _init(hud: Object = null, active_runtime: Object = null) -> void:
		hud_state = hud
		active_item_runtime = active_runtime

	func get_instance(key: String) -> Object:
		if key == "active_item_hud_state":
			return hud_state
		if key == "active_item_runtime":
			return active_item_runtime
		return null


class FakeHudState:
	extends RefCounted

	var selected_index := 0

	func set_selected_index(index: int) -> void:
		selected_index = max(0, index)

	func get_selected_index() -> int:
		return selected_index


class FakePausedActiveItemRuntime:
	extends RefCounted

	var frozen_time_msec := 0

	func get_active_item_cooldown_time_msec(_current_time_msec: int) -> int:
		return frozen_time_msec


func _init() -> void:
	_verify_idle_polling_avoids_slot_deep_copy()
	_verify_many_slot_idle_polling_stays_noop()
	_verify_gamepad_selected_slot_flow()
	_verify_cooldown_pause_freezes_hud_and_shifts_anchors()

	if _failures.is_empty():
		print("active_item_slot_controller_polling_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_idle_polling_avoids_slot_deep_copy() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/items/active_item_slot_controller.gd")
	var update_body: String = _extract_function_body(source, "func update(")
	var selected_use_edge_index: int = update_body.find("if selected_use_just_pressed:")
	var pressed_edge_index: int = update_body.find("if i < key_count and pressed and not was_pressed:")
	var copy_call_index: int = update_body.find("_copy_slots_for_use(active_item_slots)")
	var keyboard_copy_call_index: int = update_body.find("_copy_slots_for_use(active_item_slots)", pressed_edge_index)

	_expect(selected_use_edge_index >= 0, "slot polling should keep edge-triggered gamepad selected-slot use")
	_expect(pressed_edge_index >= 0, "slot polling should keep edge-triggered key checks")
	_expect(copy_call_index > selected_use_edge_index, "slot polling should copy slots only after a selected-use edge")
	_expect(keyboard_copy_call_index > pressed_edge_index, "keyboard slot polling should copy slots only after a key edge")
	_expect(update_body.find("active_item_slots.duplicate(true)") < 0, "idle slot polling should not deep-copy every active slot")
	_expect(source.find("func _copy_slots_for_use(active_item_slots: Array) -> Array:") >= 0, "slot use copies should stay isolated behind a helper")
	_expect(source.find("GamepadInput.is_active_item_use_pressed()") >= 0, "slot polling should include the gamepad selected-item use button")
	_expect(source.find("GamepadInput.get_active_item_selection_direction()") >= 0, "slot polling should include gamepad slot selection")


func _verify_many_slot_idle_polling_stays_noop() -> void:
	var controller: Object = ActiveItemSlotController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	for i in range(18):
		owner.active_item_slots.append({
			"name": "test_item_%d" % i,
			"rolls": {
				"cooldown": i,
				"nested": {"value": i},
			},
		})

	var result: Dictionary = controller.update(
		owner,
		registry,
		false,
		Callable(self, "_apply_item_effect"),
		Callable(self, "_backup_pending_use")
	)

	_expect(int(result.get("used_slot", -2)) == -1, "idle polling should not use a slot")
	_expect(owner.active_item_slots.size() == 18, "idle polling should not rewrite or remove slots")
	_expect(str(owner.active_item_slots[17].get("name", "")) == "test_item_17", "idle polling should keep later slots intact")


func _verify_gamepad_selected_slot_flow() -> void:
	var controller: Object = ActiveItemSlotController.new()
	var owner := FakeOwner.new()
	var hud_state := FakeHudState.new()
	var registry := FakeRegistry.new(hud_state)
	owner.active_item_slots = [
		{"name": "first_item"},
		{"name": "second_item"},
		{"name": "third_item"},
	]

	_expect(controller.cycle_selected_slot(1, owner, registry) == 1, "gamepad slot cycle should advance selected active item")
	_expect(hud_state.selected_index == 1, "HUD state should track the cycled active-item slot")
	_expect(controller.cycle_selected_slot(1, owner, registry) == 2, "gamepad slot cycle should advance across all slots")
	_expect(controller.cycle_selected_slot(1, owner, registry) == 0, "gamepad slot cycle should wrap at the end")
	_expect(controller.cycle_selected_slot(-1, owner, registry) == 2, "gamepad slot cycle should wrap backward")

	var used: bool = controller.use_selected_slot(
		owner,
		registry,
		false,
		Callable(self, "_apply_item_effect"),
		Callable(self, "_backup_pending_use")
	)
	_expect(used, "selected active-item slot should be usable through the controller")
	_expect(owner.active_item_slots.size() == 2, "using a consumable selected slot should remove that item")
	_expect(str(owner.active_item_slots[0].get("name", "")) == "first_item", "selected use should leave earlier slots intact")
	_expect(str(owner.active_item_slots[1].get("name", "")) == "second_item", "selected use should remove the selected third slot")
	_expect(hud_state.selected_index == 1, "selected index should clamp after the selected item is consumed")


func _verify_cooldown_pause_freezes_hud_and_shifts_anchors() -> void:
	var controller: Object = ActiveItemSlotController.new()
	controller.last_item_use_msec = 1000
	controller.pause_cooldowns(3000)
	_expect(
		int(controller.get_cooldown_time_msec(12000)) == 3000,
		"active item cooldown display time should stay pinned while paused"
	)

	var paused_runtime := FakePausedActiveItemRuntime.new()
	paused_runtime.frozen_time_msec = 3000
	var hud_state: Object = ActiveItemHudState.new()
	var status: Dictionary = hud_state.get_slot_status(
		0,
		{"name": "long_boost", "cooldown_msec": 10000, "last_use_msec": 1000},
		12000,
		12000,
		FakeRegistry.new(null, paused_runtime)
	)
	_expect(
		is_equal_approx(float(status.get("cooldown_remaining_ratio", 0.0)), 0.8),
		"active item HUD cooldown ring should not drain while paused"
	)

	var resumed_slots: Array = controller.resume_cooldowns(8000, [
		{"name": "long_boost", "cooldown_msec": 10000, "last_use_msec": 1000, "last_use": 1000},
	])
	_expect(int(controller.last_item_use_msec) == 6000, "global active item cooldown anchor should shift by paused wall time")
	_expect(int(resumed_slots[0].get("last_use_msec", 0)) == 6000, "slot last_use_msec should shift by paused wall time")
	_expect(int(resumed_slots[0].get("last_use", 0)) == 6000, "legacy slot last_use should shift by paused wall time")
	_expect(int(controller.get_cooldown_time_msec(12000)) == 12000, "active item cooldown display time should resume after unpause")
	_expect(
		not bool(controller._is_item_ready(resumed_slots[0], 10000, FakeRegistry.new())),
		"resumed active item should not become ready from wall-clock time spent paused"
	)


func _extract_function_body(source: String, signature: String) -> String:
	var start: int = source.find(signature)
	if start < 0:
		return ""
	var next_func: int = source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _apply_item_effect(_item_data: Dictionary, _owner: Object, _registry: Object) -> bool:
	return true


func _backup_pending_use(_item_data: Dictionary, _slot_index: int, _owner: Object, _registry: Object) -> void:
	pass


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
