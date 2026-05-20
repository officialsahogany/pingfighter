extends SceneTree

const BattleMobileTouchController := preload("res://scripts/core/battle_mobile_touch_controller.gd")

var _failures: Array[String] = []


class FakeModuleGetter:
	extends RefCounted

	var calls := 0

	func get_module(_key: String) -> Object:
		calls += 1
		return FakeMobileControls.new()


class FakeMobileControls:
	extends RefCounted

	func set_controls_enabled(_enabled: bool) -> void:
		pass

	func draw(_canvas: CanvasItem, _view_size: Vector2, _layout_context: Dictionary = {}) -> void:
		pass

	func handle_input(
		_event: InputEvent,
		_view_size: Vector2,
		_enabled: bool = true,
		_layout_context: Dictionary = {}
	) -> bool:
		return true


func _init() -> void:
	_verify_non_mobile_runtime_skips_touch_module()
	if _failures.is_empty():
		print("battle_mobile_touch_controller_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_non_mobile_runtime_skips_touch_module() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return
	var controller := BattleMobileTouchController.new()
	var module_getter := FakeModuleGetter.new()
	var mouse_event := InputEventMouseButton.new()
	var canvas := Node2D.new()

	_expect(
		not controller.handle_input(mouse_event, null, Callable(module_getter, "get_module"), true),
		"desktop input should not enter mobile touch handling"
	)
	controller.sync_controls_enabled(null, Callable(module_getter, "get_module"), true)
	controller.draw(canvas, null, Callable(module_getter, "get_module"), true)
	_expect(
		module_getter.calls == 0,
		"desktop mobile-touch sync/draw should not instantiate mobile touch modules"
	)
	canvas.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
