extends SceneTree

const StageClearResultInputRouter := preload("res://scripts/ui/stage_clear_result_input_router.gd")
const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_context_builder_contract()
	_verify_modal_gate_routes()
	_verify_keyboard_and_gamepad_routes()
	_verify_mouse_routes()
	_verify_scene_delegates_input_routing()

	if _failures.is_empty():
		print("stage_clear_result_input_router_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_context_builder_contract() -> void:
	var context: Dictionary = StageClearResultInputRouter.get_input_router_context(
		true,
		false,
		true,
		true,
		StageClearResultInteractionState.PHASE_VISIBLE
	)
	_expect(bool(context.get("mythic_acquisition_active", false)), "input context should include mythic acquisition gate")
	_expect(not bool(context.get("runtime_perk_choice_active", true)), "input context should include runtime perk choice gate")
	_expect(bool(context.get("treasure_hunt_effect_active", false)), "input context should include treasure hunt gate")
	_expect(bool(context.get("scroll_dragging", false)), "input context should include scroll drag state")
	_expect(str(context.get("scroll_phase", "")) == StageClearResultInteractionState.PHASE_VISIBLE, "input context should include scroll phase")


func _verify_modal_gate_routes() -> void:
	var click: InputEventMouseButton = _mouse_button(Vector2(10.0, 20.0), true)
	_expect_route(
		StageClearResultInputRouter.get_result_input_route(click, {"mythic_acquisition_active": true}),
		StageClearResultInputRouter.ROUTE_MYTHIC_ACQUISITION,
		true,
		"mythic acquisition should capture all result-scene input first"
	)
	_expect_route(
		StageClearResultInputRouter.get_result_input_route(click, {"runtime_perk_choice_active": true}),
		StageClearResultInputRouter.ROUTE_RUNTIME_PERK,
		true,
		"runtime perk choice should capture result-scene input"
	)
	_expect_route(
		StageClearResultInputRouter.get_result_input_route(click, {"treasure_hunt_effect_active": true}),
		StageClearResultInputRouter.ROUTE_TREASURE_HUNT,
		true,
		"treasure hunt effect should consume result-scene input"
	)


func _verify_keyboard_and_gamepad_routes() -> void:
	_expect_route(
		StageClearResultInputRouter.get_result_input_route(_key(KEY_ENTER), {}),
		StageClearResultInputRouter.ROUTE_ADVANCE,
		true,
		"Enter should advance the result scene"
	)
	_expect_route(
		StageClearResultInputRouter.get_result_input_route(_key(KEY_SPACE), {}),
		StageClearResultInputRouter.ROUTE_ADVANCE,
		true,
		"Space should advance the result scene"
	)
	_expect_route(
		StageClearResultInputRouter.get_result_input_route(_key(KEY_ESCAPE), {}),
		StageClearResultInputRouter.ROUTE_ESCAPE,
		true,
		"Escape should route to result scene cancel"
	)
	_expect_route(
		StageClearResultInputRouter.get_result_input_route(_key(KEY_A), {}),
		StageClearResultInputRouter.ROUTE_NONE,
		false,
		"unmapped key presses should not be consumed"
	)
	_expect_route(
		StageClearResultInputRouter.get_result_input_route(_joy_button(JOY_BUTTON_A), {}),
		StageClearResultInputRouter.ROUTE_ADVANCE,
		true,
		"gamepad A should advance the result scene"
	)
	_expect_route(
		StageClearResultInputRouter.get_result_input_route(_joy_button(JOY_BUTTON_B), {}),
		StageClearResultInputRouter.ROUTE_ESCAPE,
		true,
		"gamepad B should route to result scene cancel"
	)
	_expect_route(
		StageClearResultInputRouter.get_result_input_route(_joy_button(JOY_BUTTON_RIGHT_SHOULDER), {}),
		StageClearResultInputRouter.ROUTE_CONSUME,
		true,
		"unmapped gamepad result input should still be consumed"
	)


func _verify_mouse_routes() -> void:
	var drag_motion: Dictionary = StageClearResultInputRouter.get_result_input_route(
		_mouse_motion(Vector2(100.0, 120.0)),
		{"scroll_dragging": true, "scroll_phase": StageClearResultInteractionState.PHASE_VISIBLE}
	)
	_expect_route(drag_motion, StageClearResultInputRouter.ROUTE_MOUSE_DRAG_UPDATE, true, "dragging mouse motion should update scroll drag")
	_expect(drag_motion.get("mouse_position", Vector2.ZERO) == Vector2(100.0, 120.0), "drag motion route should preserve mouse position")

	_expect_route(
		StageClearResultInputRouter.get_result_input_route(
			_mouse_motion(Vector2(5.0, 6.0)),
			{"scroll_phase": StageClearResultInteractionState.PHASE_VISIBLE}
		),
		StageClearResultInputRouter.ROUTE_MOUSE_HOVER_BUTTON,
		true,
		"visible scroll mouse motion should update button hover"
	)
	_expect_route(
		StageClearResultInputRouter.get_result_input_route(_mouse_motion(Vector2(5.0, 6.0)), {"scroll_phase": "hidden"}),
		StageClearResultInputRouter.ROUTE_MOUSE_HOVER_BOX,
		true,
		"hidden scroll mouse motion should update box hover"
	)
	_expect_route(
		StageClearResultInputRouter.get_result_input_route(_mouse_button(Vector2(7.0, 8.0), false), {"scroll_dragging": true}),
		StageClearResultInputRouter.ROUTE_MOUSE_DRAG_FINISH,
		true,
		"left release while dragging should finish scroll drag"
	)
	_expect_route(
		StageClearResultInputRouter.get_result_input_route(_mouse_button(Vector2(7.0, 8.0), true), {}),
		StageClearResultInputRouter.ROUTE_MOUSE_LEFT_PRESS,
		true,
		"left press should route to result-scene click chain"
	)


func _verify_scene_delegates_input_routing() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(source.find("StageClearResultInputRouter.get_result_input_route") >= 0, "result scene should delegate top-level input route classification")
	_expect(source.find("StageClearResultInputRouter.get_input_router_context") >= 0, "result scene should delegate input-router context assembly")
	_expect(source.find("func _get_input_router_context()") >= 0, "result scene should keep a thin input-router context wrapper")
	_expect(source.find("func _handle_mouse_left_press") >= 0, "result scene should keep click side effects in a focused helper")
	_expect(source.find("GamepadInput.is_confirm_event") < 0, "result scene should not classify gamepad confirm directly")
	_expect(source.find("event is InputEventMouseMotion") < 0, "result scene should not classify mouse motion directly")
	_expect(source.find("event is InputEventMouseButton") < 0, "result scene should not classify mouse buttons directly")


func _expect_route(result: Dictionary, expected_route: String, expected_consumed: bool, message: String) -> void:
	_expect(str(result.get("route", "")) == expected_route, message + " route")
	_expect(bool(result.get("consumed", false)) == expected_consumed, message + " consumption")


func _key(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _joy_button(button_index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	return event


func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event


func _mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
