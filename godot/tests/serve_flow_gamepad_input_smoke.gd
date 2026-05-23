extends SceneTree

const ServeFlowController := preload("res://scripts/core/serve_flow_controller.gd")

var _failures: Array[String] = []


func _init() -> void:
	var controller: Object = ServeFlowController.new()
	var source: String = FileAccess.get_file_as_string("res://scripts/core/serve_flow_controller.gd")
	var sync_body: String = _extract_function_body(source, "func sync_current_input_state")
	var edge_body: String = _extract_function_body(source, "func _update_serve_button_edge")
	var helper_body: String = _extract_function_body(source, "func _is_serve_action_pressed")

	_expect(controller != null, "serve flow controller should load")
	_expect(
		source.find('const GamepadInput := preload("res://scripts/core/gamepad_input.gd")') >= 0,
		"serve flow should load the shared gamepad input mapping"
	)
	_expect(
		sync_body.find("_is_serve_action_pressed()") >= 0,
		"serve input sync should track gamepad action state before serve wait opens"
	)
	_expect(
		edge_body.find("_is_serve_action_pressed()") >= 0,
		"serve edge detection should use the shared serve action helper"
	)
	_expect(
		helper_body.find("GamepadInput.is_primary_action_pressed()") >= 0,
		"serve action helper should allow A / X / RT gamepad launch input"
	)

	if _failures.is_empty():
		print("serve_flow_gamepad_input_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _extract_function_body(source: String, signature: String) -> String:
	var start: int = source.find(signature)
	if start < 0:
		return ""
	var next: int = source.find("\nfunc ", start + signature.length())
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
