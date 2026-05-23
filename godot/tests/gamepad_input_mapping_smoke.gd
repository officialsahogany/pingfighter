extends SceneTree

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

var _failures: Array[String] = []


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/core/gamepad_input.gd")
	_expect(GamepadInput.is_confirm_event(_button(JOY_BUTTON_A)), "A should confirm")
	_expect(GamepadInput.is_confirm_event(_axis(JOY_AXIS_TRIGGER_RIGHT, 0.8)), "RT should confirm / primary action")
	_expect(GamepadInput.is_cancel_event(_button(JOY_BUTTON_B)), "B should cancel")
	_expect(source.find("const DOWN_ACTION_BUTTONS := [JOY_BUTTON_B]") >= 0, "B should also act as the gameplay down / dash input")
	_expect(source.find("or _is_any_button_pressed(DOWN_ACTION_BUTTONS)") >= 0, "down polling should include the B dash button")
	_expect(GamepadInput.is_pause_event(_button(JOY_BUTTON_START)), "Menu should pause")
	_expect(GamepadInput.get_tab_direction_event(_button(JOY_BUTTON_RIGHT_SHOULDER)) == 1, "RB should switch to the next settings tab")
	_expect(GamepadInput.get_tab_direction_event(_button(JOY_BUTTON_LEFT_SHOULDER)) == -1, "LB should switch to the previous settings tab")
	_expect(GamepadInput.get_menu_horizontal_event(_axis(JOY_AXIS_LEFT_X, 0.65)) == 0, "small left-stick horizontal tilt should not navigate menus")
	_expect(GamepadInput.get_menu_horizontal_event(_axis(JOY_AXIS_LEFT_X, 0.85)) == 1, "left stick right should navigate right")
	_expect(GamepadInput.get_menu_vertical_event(_axis(JOY_AXIS_LEFT_Y, -0.65)) == 0, "small left-stick vertical tilt should not navigate menus")
	_expect(GamepadInput.get_menu_vertical_event(_axis(JOY_AXIS_LEFT_Y, -0.85)) == -1, "left stick up should navigate up")
	_expect(GamepadInput.is_active_item_use_event(_button(JOY_BUTTON_Y)), "Y should use the selected active item")
	_expect(GamepadInput.get_active_item_selection_direction_event(_button(JOY_BUTTON_RIGHT_SHOULDER)) == 1, "RB should select the next active item")
	_expect(GamepadInput.get_active_item_selection_direction_event(_button(JOY_BUTTON_LEFT_SHOULDER)) == -1, "LB should select the previous active item")
	_expect(GamepadInput.get_active_item_selection_direction_event(_axis(JOY_AXIS_RIGHT_X, -0.85)) == -1, "right stick left should select the previous active item")
	_expect(GamepadInput.get_active_item_selection_direction_event(_axis(JOY_AXIS_RIGHT_X, 0.85)) == 1, "right stick right should select the next active item")
	_expect(GamepadInput.get_weapon_cycle_direction_event(_axis(JOY_AXIS_RIGHT_Y, -0.85)) == -1, "right stick up should cycle weapons backward")
	_expect(GamepadInput.get_weapon_cycle_direction_event(_axis(JOY_AXIS_RIGHT_Y, 0.85)) == 1, "right stick down should cycle weapons forward")

	if _failures.is_empty():
		print("gamepad_input_mapping_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _button(button_index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = button_index
	return event


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
