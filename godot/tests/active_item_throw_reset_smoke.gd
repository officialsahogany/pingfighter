extends SceneTree

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const ActiveItemThrowReset := preload("res://scripts/items/active_item_throw_reset.gd")

var _failures: Array[String] = []


class StopRecorder:
	extends RefCounted

	var controller: Object = null
	var call_count := 0
	var saw_placed_count := -1
	var last_registry: Variant = "unset"

	func stop_fuses(registry: Variant) -> void:
		call_count += 1
		last_registry = registry
		if controller != null:
			saw_placed_count = controller.get_placed_dynamites().size()


func _init() -> void:
	_verify_reset_helper_clears_throw_lifecycle_state()
	_verify_controller_reset_delegates_to_helper()

	if _failures.is_empty():
		print("active_item_throw_reset_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_reset_helper_clears_throw_lifecycle_state() -> void:
	var helper: Object = ActiveItemThrowReset.new()
	var controller: Object = ActiveItemThrowController.new()
	var recorder := StopRecorder.new()
	recorder.controller = controller
	_seed_throw_state(controller)

	helper.reset(controller, Callable(recorder, "stop_fuses"))

	_expect(recorder.call_count == 1, "reset helper should stop dynamite fuses once")
	_expect(recorder.last_registry == null, "reset helper should preserve legacy null registry for fuse cleanup")
	_expect(recorder.saw_placed_count == 1, "reset helper should stop fuses before clearing placed dynamites")
	_expect(_all_arrays_empty(controller), "reset helper should clear every throw array")
	_expect(_all_float_fields_zero(controller), "reset helper should clear every throw timer")


func _verify_controller_reset_delegates_to_helper() -> void:
	var controller: Object = ActiveItemThrowController.new()
	_seed_throw_state(controller)

	controller.reset()

	_expect(not controller.has_visible_effects(), "controller reset should remove visible throw effects")
	_expect(not controller.is_throw_windup_active(), "controller reset should remove pending windups")
	_expect(_all_arrays_empty(controller), "controller reset should clear every throw array through helper")
	_expect(_all_float_fields_zero(controller), "controller reset should clear every throw timer through helper")


func _seed_throw_state(controller: Object) -> void:
	for field_name in ActiveItemThrowReset.ARRAY_FIELDS:
		var value: Variant = controller.get(field_name)
		if value is Array:
			value.append({"seed": field_name})
	for field_name in ActiveItemThrowReset.FLOAT_FIELDS:
		controller.set(field_name, 7.0)


func _all_arrays_empty(controller: Object) -> bool:
	for field_name in ActiveItemThrowReset.ARRAY_FIELDS:
		var value: Variant = controller.get(field_name)
		if value is Array and not value.is_empty():
			_failures.append("array field should be empty after reset: %s" % field_name)
			return false
	return true


func _all_float_fields_zero(controller: Object) -> bool:
	for field_name in ActiveItemThrowReset.FLOAT_FIELDS:
		if not is_equal_approx(float(controller.get(field_name)), 0.0):
			_failures.append("float field should be zero after reset: %s" % field_name)
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
