extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")


class FakeThrowController:
	extends RefCounted

	var clear_calls := 0

	func clear_round_boss_status_effects() -> void:
		clear_calls += 1


var _failures: Array[String] = []


func _init() -> void:
	_verify_reset_round_clears_throw_status_effects()

	if _failures.is_empty():
		print("active_item_runtime_reset_round_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_reset_round_clears_throw_status_effects() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var throw_controller := FakeThrowController.new()
	runtime.throw_controller = throw_controller

	runtime.reset_round()
	_expect(throw_controller.clear_calls == 1, "active item reset_round should clear round boss status effects")

	runtime.throw_controller = RefCounted.new()
	runtime.reset_round()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
