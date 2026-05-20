extends SceneTree

const ScreenshotCapture := preload("res://scripts/core/screenshot_capture.gd")


func _init() -> void:
	var capture := ScreenshotCapture.new()
	_expect(capture.is_screenshot_key_event(_key_event(KEY_F12, KEY_F12, true, false)), "F12 should request a screenshot")
	_expect(capture.is_screenshot_key_event(_key_event(KEY_UNKNOWN, KEY_F12, true, false)), "physical F12 should request a screenshot")
	_expect(not capture.is_screenshot_key_event(_key_event(KEY_F12, KEY_F12, false, false)), "released F12 should not request a screenshot")
	_expect(not capture.is_screenshot_key_event(_key_event(KEY_F12, KEY_F12, true, true)), "echo F12 should not request another screenshot")
	_expect(not capture.is_screenshot_key_event(_key_event(KEY_F11, KEY_F11, true, false)), "F11 should stay reserved for fullscreen")

	var path := capture.build_screenshot_path({
		"year": 2026,
		"month": 5,
		"day": 8,
		"hour": 9,
		"minute": 10,
		"second": 11,
	}, 42)
	_expect(path == "D:/screenshot/diskhearts_ringpia_20260508_091011_042.png", "screenshot path should be timestamped")
	_expect(capture.ensure_screenshot_directory() == OK, "screenshot directory should be creatable")

	capture.free()
	print("screenshot_capture_smoke: ok")
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
