extends SceneTree

const FullscreenToggleScript := preload("res://scripts/core/fullscreen_toggle.gd")


func _init() -> void:
	var toggle := FullscreenToggleScript.new()
	_expect(toggle.is_fullscreen_toggle_event(_key_event(KEY_F11, KEY_F11, true, false)), "F11 should request fullscreen toggle")
	_expect(toggle.is_fullscreen_toggle_event(_key_event(KEY_UNKNOWN, KEY_F11, true, false)), "physical F11 should request fullscreen toggle")
	_expect(not toggle.is_fullscreen_toggle_event(_key_event(KEY_F11, KEY_F11, false, false)), "released F11 should not toggle fullscreen")
	_expect(not toggle.is_fullscreen_toggle_event(_key_event(KEY_F11, KEY_F11, true, true)), "echo F11 should not toggle fullscreen repeatedly")
	_expect(not toggle.is_fullscreen_toggle_event(_key_event(KEY_F12, KEY_F12, true, false)), "F12 should remain reserved for screenshots")
	_expect(
		str(ProjectSettings.get_setting("autoload/FullscreenToggle", "")) == "*res://scripts/core/fullscreen_toggle.gd",
		"FullscreenToggle autoload should be registered for all UI scenes"
	)
	toggle.free()
	print("fullscreen_toggle_smoke: ok")
	quit(0)


func _key_event(keycode: int, physical_keycode: int, pressed: bool, echo: bool) -> InputEventKey:
	var event := InputEventKey.new()
	@warning_ignore("int_as_enum_without_cast")
	event.keycode = keycode
	@warning_ignore("int_as_enum_without_cast")
	event.physical_keycode = physical_keycode
	event.pressed = pressed
	event.echo = echo
	return event


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
