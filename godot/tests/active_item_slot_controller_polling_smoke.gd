extends SceneTree

const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


func _init() -> void:
	_verify_idle_polling_avoids_slot_deep_copy()
	_verify_many_slot_idle_polling_stays_noop()

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
	var pressed_edge_index: int = update_body.find("if i < key_count and pressed and not was_pressed:")
	var copy_call_index: int = update_body.find("_copy_slots_for_use(active_item_slots)")

	_expect(pressed_edge_index >= 0, "slot polling should keep edge-triggered key checks")
	_expect(copy_call_index > pressed_edge_index, "slot polling should copy slots only after a key edge")
	_expect(update_body.find("active_item_slots.duplicate(true)") < 0, "idle slot polling should not deep-copy every active slot")
	_expect(source.find("func _copy_slots_for_use(active_item_slots: Array) -> Array:") >= 0, "slot use copies should stay isolated behind a helper")


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
