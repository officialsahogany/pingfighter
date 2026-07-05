extends RefCounted

const MOVE_DEADZONE := 0.42
const MENU_AXIS_THRESHOLD := 0.82
const MENU_AXIS_RELEASE_THRESHOLD := 0.38
const TRIGGER_DEADZONE := 0.45
const PRIMARY_ACTION_TRIGGER_SUPPRESS_RELEASE_THRESHOLD := 0.35

const PRIMARY_ACTION_BUTTONS := [JOY_BUTTON_A, JOY_BUTTON_X]
const CONFIRM_BUTTONS := [JOY_BUTTON_A, JOY_BUTTON_START]
const CANCEL_BUTTONS := [JOY_BUTTON_B]
const PAUSE_BUTTONS := [JOY_BUTTON_START]
const TAB_PREVIOUS_BUTTONS := [JOY_BUTTON_LEFT_SHOULDER]
const TAB_NEXT_BUTTONS := [JOY_BUTTON_RIGHT_SHOULDER]
const SUPPLY_HOLD_BUTTONS := []
const FIREARM_RESET_BUTTONS := []
const FIREARM_NEXT_BUTTONS := [JOY_BUTTON_LEFT_STICK]
const DOWN_ACTION_BUTTONS := [JOY_BUTTON_B]
const ACTIVE_ITEM_USE_BUTTONS := [JOY_BUTTON_Y]
const ACTIVE_ITEM_PREVIOUS_BUTTONS := [JOY_BUTTON_LEFT_SHOULDER]
const ACTIVE_ITEM_NEXT_BUTTONS := [JOY_BUTTON_RIGHT_SHOULDER]
const SKILL_TOOLTIP_CYCLE_BUTTONS := [JOY_BUTTON_BACK]
const RIGHT_STICK_AXES := [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]
const RIGHT_STICK_BUTTONS := [JOY_BUTTON_RIGHT_STICK]

static var _primary_action_trigger_suppressed := false


static func is_left_pressed() -> bool:
	return _is_button_pressed(JOY_BUTTON_DPAD_LEFT) or _is_axis_below(JOY_AXIS_LEFT_X, -MOVE_DEADZONE)


static func is_right_pressed() -> bool:
	return _is_button_pressed(JOY_BUTTON_DPAD_RIGHT) or _is_axis_above(JOY_AXIS_LEFT_X, MOVE_DEADZONE)


static func is_up_pressed() -> bool:
	return _is_button_pressed(JOY_BUTTON_DPAD_UP) or _is_axis_below(JOY_AXIS_LEFT_Y, -MOVE_DEADZONE)


static func is_down_pressed() -> bool:
	return (
		_is_button_pressed(JOY_BUTTON_DPAD_DOWN)
		or _is_axis_above(JOY_AXIS_LEFT_Y, MOVE_DEADZONE)
		or _is_any_button_pressed(DOWN_ACTION_BUTTONS)
	)


static func is_primary_action_pressed() -> bool:
	_refresh_primary_action_trigger_suppression()
	return (
		_is_any_button_pressed(PRIMARY_ACTION_BUTTONS)
		or (
			not _primary_action_trigger_suppressed
			and _is_axis_above(JOY_AXIS_TRIGGER_RIGHT, TRIGGER_DEADZONE)
		)
	)


static func is_supply_hold_pressed() -> bool:
	return (
		_is_any_button_pressed(SUPPLY_HOLD_BUTTONS)
		or _is_axis_above(JOY_AXIS_TRIGGER_LEFT, TRIGGER_DEADZONE)
	)


static func is_firearm_reset_pressed() -> bool:
	return _is_any_button_pressed(FIREARM_RESET_BUTTONS)


static func is_active_item_use_pressed() -> bool:
	return _is_any_button_pressed(ACTIVE_ITEM_USE_BUTTONS)


static func get_active_item_selection_direction() -> int:
	if _is_any_button_pressed(ACTIVE_ITEM_PREVIOUS_BUTTONS):
		return -1
	if _is_any_button_pressed(ACTIVE_ITEM_NEXT_BUTTONS):
		return 1
	return 0


static func is_confirm_event(event: InputEvent) -> bool:
	return (
		_is_action_event(event, "ui_accept")
		or _is_joy_button_event(event, CONFIRM_BUTTONS)
		or _is_axis_event(event, JOY_AXIS_TRIGGER_RIGHT, 1, TRIGGER_DEADZONE)
	)


static func is_cancel_event(event: InputEvent) -> bool:
	return _is_action_event(event, "ui_cancel") or _is_joy_button_event(event, CANCEL_BUTTONS)


static func is_pause_event(event: InputEvent) -> bool:
	return _is_joy_button_event(event, PAUSE_BUTTONS)


static func is_intro_skip_event(event: InputEvent) -> bool:
	return is_confirm_event(event) or is_cancel_event(event) or is_pause_event(event)


static func is_firearm_reset_event(event: InputEvent) -> bool:
	return _is_joy_button_event(event, FIREARM_RESET_BUTTONS)


static func is_active_item_use_event(event: InputEvent) -> bool:
	return _is_joy_button_event(event, ACTIVE_ITEM_USE_BUTTONS)


static func is_skill_tooltip_cycle_event(event: InputEvent) -> bool:
	return _is_joy_button_event(event, SKILL_TOOLTIP_CYCLE_BUTTONS)


static func should_suppress_right_stick_event(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		var motion_event: InputEventJoypadMotion = event
		return RIGHT_STICK_AXES.has(motion_event.axis)
	if event is InputEventJoypadButton:
		var button_event: InputEventJoypadButton = event
		return RIGHT_STICK_BUTTONS.has(button_event.button_index)
	return false


static func suppress_primary_action_trigger_until_release() -> void:
	_primary_action_trigger_suppressed = true


static func update_primary_action_trigger_suppression_from_event(event: InputEvent) -> void:
	if not (event is InputEventJoypadMotion):
		return
	var motion_event: InputEventJoypadMotion = event
	if motion_event.axis != JOY_AXIS_TRIGGER_RIGHT:
		return
	if motion_event.axis_value <= PRIMARY_ACTION_TRIGGER_SUPPRESS_RELEASE_THRESHOLD:
		_primary_action_trigger_suppressed = false


static func is_primary_action_trigger_suppressed_for_tests() -> bool:
	return _primary_action_trigger_suppressed


static func clear_primary_action_trigger_suppression_for_tests() -> void:
	_primary_action_trigger_suppressed = false


static func get_active_item_selection_direction_event(event: InputEvent) -> int:
	if _is_joy_button_event(event, ACTIVE_ITEM_PREVIOUS_BUTTONS):
		return -1
	if _is_joy_button_event(event, ACTIVE_ITEM_NEXT_BUTTONS):
		return 1
	return 0


static func get_menu_horizontal_event(event: InputEvent) -> int:
	if _is_non_gamepad_action_event(event, "ui_left") or _is_joy_button_event(event, [JOY_BUTTON_DPAD_LEFT]):
		return -1
	if _is_non_gamepad_action_event(event, "ui_right") or _is_joy_button_event(event, [JOY_BUTTON_DPAD_RIGHT]):
		return 1
	if _is_axis_event(event, JOY_AXIS_LEFT_X, -1, MENU_AXIS_THRESHOLD):
		return -1
	if _is_axis_event(event, JOY_AXIS_LEFT_X, 1, MENU_AXIS_THRESHOLD):
		return 1
	return 0


static func get_menu_vertical_event(event: InputEvent) -> int:
	if _is_non_gamepad_action_event(event, "ui_up") or _is_joy_button_event(event, [JOY_BUTTON_DPAD_UP]):
		return -1
	if _is_non_gamepad_action_event(event, "ui_down") or _is_joy_button_event(event, [JOY_BUTTON_DPAD_DOWN]):
		return 1
	if _is_axis_event(event, JOY_AXIS_LEFT_Y, -1, MENU_AXIS_THRESHOLD):
		return -1
	if _is_axis_event(event, JOY_AXIS_LEFT_Y, 1, MENU_AXIS_THRESHOLD):
		return 1
	return 0


static func get_weapon_cycle_direction_event(event: InputEvent) -> int:
	if _is_joy_button_event(event, FIREARM_NEXT_BUTTONS):
		return 1
	return 0


static func get_tab_direction_event(event: InputEvent) -> int:
	if _is_joy_button_event(event, TAB_PREVIOUS_BUTTONS):
		return -1
	if _is_joy_button_event(event, TAB_NEXT_BUTTONS):
		return 1
	return 0


static func is_gamepad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


static func _is_any_button_pressed(buttons: Array) -> bool:
	for button in buttons:
		if _is_button_pressed(int(button)):
			return true
	return false


static func _is_button_pressed(button: int) -> bool:
	for device in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(int(device), button):
			return true
	return false


static func _is_axis_above(axis: int, threshold: float) -> bool:
	for device in Input.get_connected_joypads():
		if Input.get_joy_axis(int(device), axis) >= threshold:
			return true
	return false


static func _is_axis_below(axis: int, threshold: float) -> bool:
	for device in Input.get_connected_joypads():
		if Input.get_joy_axis(int(device), axis) <= threshold:
			return true
	return false


static func _refresh_primary_action_trigger_suppression() -> void:
	if not _primary_action_trigger_suppressed:
		return
	for device in Input.get_connected_joypads():
		if Input.get_joy_axis(int(device), JOY_AXIS_TRIGGER_RIGHT) > PRIMARY_ACTION_TRIGGER_SUPPRESS_RELEASE_THRESHOLD:
			return
	_primary_action_trigger_suppressed = false


static func _is_action_event(event: InputEvent, action: StringName) -> bool:
	return event != null and event.is_action_pressed(action)


static func _is_non_gamepad_action_event(event: InputEvent, action: StringName) -> bool:
	if is_gamepad_event(event):
		return false
	return _is_action_event(event, action)


static func _is_joy_button_event(event: InputEvent, buttons: Array) -> bool:
	if not (event is InputEventJoypadButton):
		return false
	var button_event: InputEventJoypadButton = event
	return button_event.pressed and buttons.has(button_event.button_index)


static func _is_axis_event(event: InputEvent, axis: int, direction: int, threshold: float) -> bool:
	if not (event is InputEventJoypadMotion):
		return false
	var motion_event: InputEventJoypadMotion = event
	if motion_event.axis != axis:
		return false
	if direction < 0:
		return motion_event.axis_value <= -threshold
	return motion_event.axis_value >= threshold
