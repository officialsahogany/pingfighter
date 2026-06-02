extends SceneTree

const ServeFlowController := preload("res://scripts/core/serve_flow_controller.gd")

var _failures: Array[String] = []
var _serve_calls := 0


class FakeRoundState:
	extends RefCounted

	var waiting_for_serve := true
	var player_serves := true
	var serve_banner_timer := 0.85
	var banner_updates := 0
	var wait_updates := 0

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve

	func does_player_serve() -> bool:
		return player_serves

	func is_serve_banner_active() -> bool:
		return serve_banner_timer > 0.0

	func update_serve_banner(delta: float) -> bool:
		banner_updates += 1
		serve_banner_timer = max(0.0, serve_banner_timer - max(0.0, delta))
		return serve_banner_timer > 0.0

	func is_round_restart_notice_active() -> bool:
		return false

	func update_waiting(_delta: float, _target_delay: float = 1.0) -> bool:
		wait_updates += 1
		return false


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
	_verify_scoreboard_banner_does_not_swallow_manual_player_serve()

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


func _verify_scoreboard_banner_does_not_swallow_manual_player_serve() -> void:
	var controller: Object = ServeFlowController.new()
	var round_state := FakeRoundState.new()
	_serve_calls = 0
	Input.action_release("ui_accept")
	controller.sync_current_input_state()
	Input.action_press("ui_accept")
	controller.update(
		0.016,
		{"current_stage": 1},
		{"round_state": round_state},
		{"serve_ball": Callable(self, "_record_serve")}
	)
	Input.action_release("ui_accept")

	_expect(_serve_calls == 1, "manual player serve should launch during the post-score serve banner")
	_expect(round_state.banner_updates == 1, "serve banner should still advance on the launch frame")
	_expect(round_state.wait_updates == 0, "banner launch should not fall through to auto-serve waiting")


func _record_serve() -> void:
	_serve_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
