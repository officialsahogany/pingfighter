extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

const FULLSCREEN_TOGGLE_KEY := KEY_F11
const BGM_TOGGLE_KEY := KEY_B
const RIGHT_STICK_MOUSE_WHEEL_SUPPRESS_MSEC := 450

var _right_stick_mouse_wheel_suppress_until_msec := 0


func handle_input(
	event: InputEvent,
	owner: Object,
	module_getter: Callable
) -> bool:
	if _handle_window_shortcut(event, owner, module_getter):
		return true
	if _handle_bgm_shortcut(event, owner, module_getter):
		return true
	return _handle_right_stick_suppression(event, owner)


func _handle_window_shortcut(
	event: InputEvent,
	owner: Object,
	module_getter: Callable
) -> bool:
	if not _is_key_pressed(event, FULLSCREEN_TOGGLE_KEY):
		return false
	var view_layout: Object = _get_module(module_getter, "battle_view_layout")
	if view_layout == null or not view_layout.has_method("toggle_fullscreen"):
		return false
	if owner == null or not owner.has_method("get_window"):
		return false
	view_layout.toggle_fullscreen(owner.get_window())
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_bgm_shortcut(
	event: InputEvent,
	owner: Object,
	module_getter: Callable
) -> bool:
	if not _is_key_pressed(event, BGM_TOGGLE_KEY):
		return false
	var audio: Object = _get_module(module_getter, "game_audio")
	if audio == null or not audio.has_method("toggle_bgm"):
		return false
	audio.toggle_bgm()
	_mark_handled(owner)
	return true


func _handle_right_stick_suppression(event: InputEvent, owner: Object) -> bool:
	# Battle-only carve-out: R3 is the guardian_toggle action. Right-stick axes
	# and the menu routers keep their existing suppression behavior.
	if _is_guardian_toggle_button_event(event):
		return false
	if GamepadInput.should_suppress_right_stick_event(event):
		_right_stick_mouse_wheel_suppress_until_msec = (
			Time.get_ticks_msec() + RIGHT_STICK_MOUSE_WHEEL_SUPPRESS_MSEC
		)
		_mark_handled(owner)
		return true
	if (
		_is_mouse_wheel_event(event)
		and Time.get_ticks_msec() <= _right_stick_mouse_wheel_suppress_until_msec
	):
		_mark_handled(owner)
		return true
	return false


func _is_guardian_toggle_button_event(event: InputEvent) -> bool:
	return (
		event is InputEventJoypadButton
		and (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_STICK
	)


func _is_key_pressed(event: InputEvent, keycode: int) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == keycode or key_event.physical_keycode == keycode


func _is_mouse_wheel_event(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mouse_event: InputEventMouseButton = event
	if not mouse_event.pressed:
		return false
	return (
		mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP
		or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		or mouse_event.button_index == MOUSE_BUTTON_WHEEL_LEFT
		or mouse_event.button_index == MOUSE_BUTTON_WHEEL_RIGHT
	)


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _mark_handled(owner: Object) -> void:
	if owner == null or not owner.has_method("get_viewport"):
		return
	var viewport: Viewport = owner.get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
