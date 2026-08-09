extends SceneTree

const PauseMenuInputCommandRouter := preload("res://scripts/hud/pause_menu_input_command_router.gd")
const PauseMenuOptionsNavigationPolicy := preload("res://scripts/hud/pause_menu_options_navigation_policy.gd")

var _failures: Array[String] = []


func _init() -> void:
	var router := PauseMenuInputCommandRouter.new()
	_verify_main_keyboard(router)
	_verify_options_keyboard(router)
	_verify_gamepad(router)
	_verify_overlay_ownership()
	if _failures.is_empty():
		print("pause_menu_input_command_router_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_main_keyboard(router: Object) -> void:
	var released := _key(KEY_ESCAPE, false)
	_expect_command(router.route_key(released, false, PauseMenuOptionsNavigationPolicy.TAB_SOUND, 0, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE), PauseMenuInputCommandRouter.COMMAND_NONE, "released key")
	_expect_command(router.route_key(_key(KEY_ESCAPE), false, PauseMenuOptionsNavigationPolicy.TAB_SOUND, 0, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE), PauseMenuInputCommandRouter.COMMAND_CLOSE_MAIN, "main escape")
	_expect_direction(router.route_key(_key(KEY_UP), false, PauseMenuOptionsNavigationPolicy.TAB_SOUND, 0, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE), PauseMenuInputCommandRouter.COMMAND_MOVE_MAIN, -1, "main up")
	_expect_direction(router.route_key(_key(KEY_DOWN), false, PauseMenuOptionsNavigationPolicy.TAB_SOUND, 0, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE), PauseMenuInputCommandRouter.COMMAND_MOVE_MAIN, 1, "main down")
	_expect_command(router.route_key(_key(KEY_ENTER), false, PauseMenuOptionsNavigationPolicy.TAB_SOUND, 0, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE), PauseMenuInputCommandRouter.COMMAND_ACTIVATE_MAIN, "main confirm")


func _verify_options_keyboard(router: Object) -> void:
	var device := PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE
	_expect_command(router.route_key(_key(KEY_ESCAPE), true, PauseMenuOptionsNavigationPolicy.TAB_SOUND, 0, device), PauseMenuInputCommandRouter.COMMAND_CLOSE_OPTIONS, "options escape")
	_expect_direction(router.route_key(_key(KEY_TAB), true, PauseMenuOptionsNavigationPolicy.TAB_SOUND, 0, device), PauseMenuInputCommandRouter.COMMAND_SWITCH_TAB, 1, "options tab")
	_expect_direction(router.route_key(_key(KEY_LEFT), true, PauseMenuOptionsNavigationPolicy.TAB_SOUND, 0, device), PauseMenuInputCommandRouter.COMMAND_ADJUST_VOLUME, -1, "sound left")
	_expect_command(router.route_key(_key(KEY_SPACE), true, PauseMenuOptionsNavigationPolicy.TAB_SOUND, 2, device), PauseMenuInputCommandRouter.COMMAND_CLOSE_OPTIONS, "sound back confirm")
	_expect_direction(router.route_key(_key(KEY_RIGHT), true, PauseMenuOptionsNavigationPolicy.TAB_DISPLAY, 1, device), PauseMenuInputCommandRouter.COMMAND_ADJUST_DISPLAY, 1, "display FPS right")
	_expect_command(router.route_key(_key(KEY_ENTER), true, PauseMenuOptionsNavigationPolicy.TAB_DISPLAY, 8, device), PauseMenuInputCommandRouter.COMMAND_ACTIVATE_DISPLAY, "display back confirm")
	var controls_move: Dictionary = router.route_key(_key(KEY_DOWN), true, PauseMenuOptionsNavigationPolicy.TAB_CONTROLS, 0, PauseMenuOptionsNavigationPolicy.DEVICE_JOYPAD)
	_expect_direction(controls_move, PauseMenuInputCommandRouter.COMMAND_MOVE_OPTIONS_FOCUS, 1, "controls down")
	_expect(int(controls_move.get("focus_count", 0)) == PauseMenuOptionsNavigationPolicy.CONTROLS_JOYPAD_FOCUS_COUNT, "controls command should carry device-specific focus count")
	_expect_direction(router.route_key(_key(KEY_LEFT), true, PauseMenuOptionsNavigationPolicy.TAB_CONTROLS, 1, PauseMenuOptionsNavigationPolicy.DEVICE_JOYPAD), PauseMenuInputCommandRouter.COMMAND_ADJUST_CONTROLS, -1, "controls vibration left")
	_expect_direction(router.route_key(_key(KEY_RIGHT), true, PauseMenuOptionsNavigationPolicy.TAB_LANGUAGE, 0, device), PauseMenuInputCommandRouter.COMMAND_CYCLE_LANGUAGE, 1, "language right")
	_expect_command(router.route_key(_key(KEY_RIGHT), true, PauseMenuOptionsNavigationPolicy.TAB_LANGUAGE, PauseMenuOptionsNavigationPolicy.LANGUAGE_FOCUS_COUNT - 1, device), PauseMenuInputCommandRouter.COMMAND_NONE, "language back horizontal")
	_expect_command(router.route_key(_key(KEY_ENTER), true, PauseMenuOptionsNavigationPolicy.TAB_LANGUAGE, 3, device), PauseMenuInputCommandRouter.COMMAND_ACTIVATE_LANGUAGE, "language confirm")


func _verify_gamepad(router: Object) -> void:
	var device := PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE
	_expect_command(router.route_gamepad(_joy(JOY_BUTTON_B), false, PauseMenuOptionsNavigationPolicy.TAB_SOUND, 0, device), PauseMenuInputCommandRouter.COMMAND_CLOSE_MAIN, "main gamepad cancel")
	_expect_direction(router.route_gamepad(_joy(JOY_BUTTON_DPAD_DOWN), false, PauseMenuOptionsNavigationPolicy.TAB_SOUND, 0, device), PauseMenuInputCommandRouter.COMMAND_MOVE_MAIN, 1, "main gamepad down")
	_expect_command(router.route_gamepad(_joy(JOY_BUTTON_A), false, PauseMenuOptionsNavigationPolicy.TAB_SOUND, 0, device), PauseMenuInputCommandRouter.COMMAND_ACTIVATE_MAIN, "main gamepad confirm")
	_expect_direction(router.route_gamepad(_joy(JOY_BUTTON_LEFT_SHOULDER), true, PauseMenuOptionsNavigationPolicy.TAB_SOUND, 0, device), PauseMenuInputCommandRouter.COMMAND_SWITCH_TAB, -1, "options previous tab")
	_expect_direction(router.route_gamepad(_joy(JOY_BUTTON_DPAD_RIGHT), true, PauseMenuOptionsNavigationPolicy.TAB_DISPLAY, 2, device), PauseMenuInputCommandRouter.COMMAND_ADJUST_DISPLAY, 1, "display gamepad right")
	_expect_command(router.route_gamepad(_joy(JOY_BUTTON_A), true, PauseMenuOptionsNavigationPolicy.TAB_CONTROLS, 0, device), PauseMenuInputCommandRouter.COMMAND_ACTIVATE_CONTROLS, "controls gamepad confirm")
	_expect_direction(router.route_gamepad(_joy(JOY_BUTTON_DPAD_LEFT), true, PauseMenuOptionsNavigationPolicy.TAB_LANGUAGE, 2, device), PauseMenuInputCommandRouter.COMMAND_CYCLE_LANGUAGE, -1, "language gamepad left")


func _verify_overlay_ownership() -> void:
	var overlay_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	var router_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_input_command_router.gd")
	_expect(overlay_source.find("PauseMenuInputCommandRouter") >= 0, "overlay should preload the input command router")
	_expect(overlay_source.find("_execute_input_command(") >= 0, "overlay should execute routed commands at its side-effect boundary")
	_expect(overlay_source.find("_input_command_router.route_key(") >= 0, "keyboard input should delegate to the command router")
	_expect(overlay_source.find("_input_command_router.route_gamepad(") >= 0, "gamepad input should delegate to the command router")
	_expect(router_source.find("GamepadInput.get_menu_vertical_event") >= 0, "router should own gamepad vertical interpretation")
	_expect(router_source.find("KEY_ESCAPE") >= 0 and router_source.find("KEY_TAB") >= 0, "router should own keyboard command interpretation")
	_expect(router_source.find("play_ui_") == -1, "pure command router must not play UI audio")
	_expect(router_source.find("battle_view_layout") == -1, "pure command router must not call display integration")


func _key(keycode: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = pressed
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _joy(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = button
	return event


func _expect_command(command: Dictionary, expected: StringName, label: String) -> void:
	_expect(StringName(command.get("command", &"")) == expected, "%s should route to %s" % [label, expected])


func _expect_direction(command: Dictionary, expected: StringName, direction: int, label: String) -> void:
	_expect_command(command, expected, label)
	_expect(int(command.get("direction", 0)) == direction, "%s should carry direction %d" % [label, direction])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
