extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const PauseMenuOptionsNavigationPolicy := preload("res://scripts/hud/pause_menu_options_navigation_policy.gd")

const COMMAND_NONE := &"none"
const COMMAND_CLOSE_MAIN := &"close_main"
const COMMAND_MOVE_MAIN := &"move_main"
const COMMAND_ACTIVATE_MAIN := &"activate_main"
const COMMAND_CLOSE_OPTIONS := &"close_options"
const COMMAND_SWITCH_TAB := &"switch_tab"
const COMMAND_MOVE_OPTIONS_FOCUS := &"move_options_focus"
const COMMAND_ADJUST_VOLUME := &"adjust_volume"
const COMMAND_CONFIRM := &"confirm"
const COMMAND_ADJUST_DISPLAY := &"adjust_display"
const COMMAND_ACTIVATE_DISPLAY := &"activate_display"
const COMMAND_ADJUST_CONTROLS := &"adjust_controls"
const COMMAND_ACTIVATE_CONTROLS := &"activate_controls"
const COMMAND_CYCLE_LANGUAGE := &"cycle_language"
const COMMAND_ACTIVATE_LANGUAGE := &"activate_language"


func route_key(
	key_event: InputEventKey,
	options_open: bool,
	options_tab: String,
	options_focus: int,
	controls_device: String
) -> Dictionary:
	if not key_event.pressed or key_event.echo:
		return _command(COMMAND_NONE)
	if options_open:
		return route_options_key(key_event, options_tab, options_focus, controls_device)
	return route_main_key(key_event)


func route_main_key(key_event: InputEventKey) -> Dictionary:
	if _is_key(key_event, KEY_ESCAPE):
		return _command(COMMAND_CLOSE_MAIN)
	if _is_key(key_event, KEY_UP):
		return _command(COMMAND_MOVE_MAIN, -1)
	if _is_key(key_event, KEY_DOWN):
		return _command(COMMAND_MOVE_MAIN, 1)
	if _is_confirm_key(key_event):
		return _command(COMMAND_ACTIVATE_MAIN)
	return _command(COMMAND_NONE)


func route_options_key(
	key_event: InputEventKey,
	options_tab: String,
	options_focus: int,
	controls_device: String
) -> Dictionary:
	if _is_key(key_event, KEY_ESCAPE):
		return _command(COMMAND_CLOSE_OPTIONS)
	if _is_key(key_event, KEY_TAB):
		return _command(COMMAND_SWITCH_TAB, 1)
	match options_tab:
		PauseMenuOptionsNavigationPolicy.TAB_DISPLAY:
			return route_display_key(key_event, options_focus)
		PauseMenuOptionsNavigationPolicy.TAB_CONTROLS:
			return route_controls_key(key_event, controls_device)
		PauseMenuOptionsNavigationPolicy.TAB_LANGUAGE:
			return route_language_key(key_event, options_focus)
	return route_sound_key(key_event, options_focus)


func route_sound_key(key_event: InputEventKey, options_focus: int) -> Dictionary:
	if _is_key(key_event, KEY_UP):
		return _command(COMMAND_MOVE_OPTIONS_FOCUS, -1, PauseMenuOptionsNavigationPolicy.SOUND_FOCUS_COUNT)
	if _is_key(key_event, KEY_DOWN):
		return _command(COMMAND_MOVE_OPTIONS_FOCUS, 1, PauseMenuOptionsNavigationPolicy.SOUND_FOCUS_COUNT)
	if _is_key(key_event, KEY_LEFT):
		return _command(COMMAND_ADJUST_VOLUME, -1)
	if _is_key(key_event, KEY_RIGHT):
		return _command(COMMAND_ADJUST_VOLUME, 1)
	if _is_confirm_key(key_event):
		return _command(COMMAND_CLOSE_OPTIONS if options_focus == PauseMenuOptionsNavigationPolicy.SOUND_FOCUS_COUNT - 1 else COMMAND_CONFIRM)
	return _command(COMMAND_NONE)


func route_display_key(key_event: InputEventKey, _options_focus: int) -> Dictionary:
	if _is_key(key_event, KEY_UP):
		return _command(COMMAND_MOVE_OPTIONS_FOCUS, -1, PauseMenuOptionsNavigationPolicy.DISPLAY_FOCUS_COUNT)
	if _is_key(key_event, KEY_DOWN):
		return _command(COMMAND_MOVE_OPTIONS_FOCUS, 1, PauseMenuOptionsNavigationPolicy.DISPLAY_FOCUS_COUNT)
	if _is_key(key_event, KEY_LEFT):
		return _command(COMMAND_ADJUST_DISPLAY, -1)
	if _is_key(key_event, KEY_RIGHT):
		return _command(COMMAND_ADJUST_DISPLAY, 1)
	if _is_confirm_key(key_event):
		return _command(COMMAND_ACTIVATE_DISPLAY)
	return _command(COMMAND_NONE)


func route_controls_key(key_event: InputEventKey, controls_device: String) -> Dictionary:
	var focus_count := PauseMenuOptionsNavigationPolicy.get_controls_focus_count(controls_device)
	if _is_key(key_event, KEY_UP):
		return _command(COMMAND_MOVE_OPTIONS_FOCUS, -1, focus_count)
	if _is_key(key_event, KEY_DOWN):
		return _command(COMMAND_MOVE_OPTIONS_FOCUS, 1, focus_count)
	if _is_key(key_event, KEY_LEFT):
		return _command(COMMAND_ADJUST_CONTROLS, -1)
	if _is_key(key_event, KEY_RIGHT):
		return _command(COMMAND_ADJUST_CONTROLS, 1)
	if _is_confirm_key(key_event):
		return _command(COMMAND_ACTIVATE_CONTROLS)
	return _command(COMMAND_NONE)


func route_language_key(key_event: InputEventKey, options_focus: int) -> Dictionary:
	if _is_key(key_event, KEY_UP):
		return _command(COMMAND_MOVE_OPTIONS_FOCUS, -1, PauseMenuOptionsNavigationPolicy.LANGUAGE_FOCUS_COUNT)
	if _is_key(key_event, KEY_DOWN):
		return _command(COMMAND_MOVE_OPTIONS_FOCUS, 1, PauseMenuOptionsNavigationPolicy.LANGUAGE_FOCUS_COUNT)
	if options_focus < PauseMenuOptionsNavigationPolicy.LANGUAGE_FOCUS_COUNT - 1:
		if _is_key(key_event, KEY_LEFT):
			return _command(COMMAND_CYCLE_LANGUAGE, -1)
		if _is_key(key_event, KEY_RIGHT):
			return _command(COMMAND_CYCLE_LANGUAGE, 1)
	if _is_confirm_key(key_event):
		return _command(COMMAND_ACTIVATE_LANGUAGE)
	return _command(COMMAND_NONE)


func route_gamepad(
	event: InputEvent,
	options_open: bool,
	options_tab: String,
	options_focus: int,
	controls_device: String
) -> Dictionary:
	if options_open:
		return route_options_gamepad(event, options_tab, options_focus, controls_device)
	return route_main_gamepad(event)


func route_main_gamepad(event: InputEvent) -> Dictionary:
	if GamepadInput.is_cancel_event(event) or GamepadInput.is_pause_event(event):
		return _command(COMMAND_CLOSE_MAIN)
	var vertical_direction := GamepadInput.get_menu_vertical_event(event)
	if vertical_direction != 0:
		return _command(COMMAND_MOVE_MAIN, vertical_direction)
	if GamepadInput.is_confirm_event(event):
		return _command(COMMAND_ACTIVATE_MAIN)
	return _command(COMMAND_NONE)


func route_options_gamepad(
	event: InputEvent,
	options_tab: String,
	options_focus: int,
	controls_device: String
) -> Dictionary:
	if GamepadInput.is_cancel_event(event) or GamepadInput.is_pause_event(event):
		return _command(COMMAND_CLOSE_OPTIONS)
	var tab_direction := GamepadInput.get_tab_direction_event(event)
	if tab_direction != 0:
		return _command(COMMAND_SWITCH_TAB, tab_direction)
	match options_tab:
		PauseMenuOptionsNavigationPolicy.TAB_DISPLAY:
			return route_display_gamepad(event)
		PauseMenuOptionsNavigationPolicy.TAB_CONTROLS:
			return route_controls_gamepad(event, controls_device)
		PauseMenuOptionsNavigationPolicy.TAB_LANGUAGE:
			return route_language_gamepad(event, options_focus)
	return route_sound_gamepad(event, options_focus)


func route_sound_gamepad(event: InputEvent, options_focus: int) -> Dictionary:
	var vertical_direction := GamepadInput.get_menu_vertical_event(event)
	if vertical_direction != 0:
		return _command(COMMAND_MOVE_OPTIONS_FOCUS, vertical_direction, PauseMenuOptionsNavigationPolicy.SOUND_FOCUS_COUNT)
	var horizontal_direction := GamepadInput.get_menu_horizontal_event(event)
	if horizontal_direction != 0:
		return _command(COMMAND_ADJUST_VOLUME, horizontal_direction)
	if GamepadInput.is_confirm_event(event):
		return _command(COMMAND_CLOSE_OPTIONS if options_focus == PauseMenuOptionsNavigationPolicy.SOUND_FOCUS_COUNT - 1 else COMMAND_CONFIRM)
	return _command(COMMAND_NONE)


func route_display_gamepad(event: InputEvent) -> Dictionary:
	var vertical_direction := GamepadInput.get_menu_vertical_event(event)
	if vertical_direction != 0:
		return _command(COMMAND_MOVE_OPTIONS_FOCUS, vertical_direction, PauseMenuOptionsNavigationPolicy.DISPLAY_FOCUS_COUNT)
	var horizontal_direction := GamepadInput.get_menu_horizontal_event(event)
	if horizontal_direction != 0:
		return _command(COMMAND_ADJUST_DISPLAY, horizontal_direction)
	if GamepadInput.is_confirm_event(event):
		return _command(COMMAND_ACTIVATE_DISPLAY)
	return _command(COMMAND_NONE)


func route_controls_gamepad(event: InputEvent, controls_device: String) -> Dictionary:
	var vertical_direction := GamepadInput.get_menu_vertical_event(event)
	if vertical_direction != 0:
		return _command(
			COMMAND_MOVE_OPTIONS_FOCUS,
			vertical_direction,
			PauseMenuOptionsNavigationPolicy.get_controls_focus_count(controls_device)
		)
	var horizontal_direction := GamepadInput.get_menu_horizontal_event(event)
	if horizontal_direction != 0:
		return _command(COMMAND_ADJUST_CONTROLS, horizontal_direction)
	if GamepadInput.is_confirm_event(event):
		return _command(COMMAND_ACTIVATE_CONTROLS)
	return _command(COMMAND_NONE)


func route_language_gamepad(event: InputEvent, options_focus: int) -> Dictionary:
	var vertical_direction := GamepadInput.get_menu_vertical_event(event)
	if vertical_direction != 0:
		return _command(COMMAND_MOVE_OPTIONS_FOCUS, vertical_direction, PauseMenuOptionsNavigationPolicy.LANGUAGE_FOCUS_COUNT)
	var horizontal_direction := GamepadInput.get_menu_horizontal_event(event)
	if horizontal_direction != 0 and options_focus < PauseMenuOptionsNavigationPolicy.LANGUAGE_FOCUS_COUNT - 1:
		return _command(COMMAND_CYCLE_LANGUAGE, horizontal_direction)
	if GamepadInput.is_confirm_event(event):
		return _command(COMMAND_ACTIVATE_LANGUAGE)
	return _command(COMMAND_NONE)


func _is_confirm_key(key_event: InputEventKey) -> bool:
	return _is_key(key_event, KEY_ENTER) or _is_key(key_event, KEY_KP_ENTER) or _is_key(key_event, KEY_SPACE)


func _is_key(key_event: InputEventKey, keycode: int) -> bool:
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _command(command: StringName, direction: int = 0, focus_count: int = 0) -> Dictionary:
	var result := {"command": command}
	if direction != 0:
		result["direction"] = direction
	if focus_count > 0:
		result["focus_count"] = focus_count
	return result
