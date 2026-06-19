extends SceneTree

const ScreenshotCapture := preload("res://scripts/core/screenshot_capture.gd")

# quit(1) inside a coroutine does not stop the script: after `await
# process_frame` the continuation still reaches the final quit(0), which
# overrides the failure. Gate the exit on an accumulated flag instead.
var _failed := false


func _init() -> void:
	_run()


func _run() -> void:
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
	_expect(path == "D:/screenshot/diskhearts_lingpia_20260508_091011_042.png", "screenshot path should be timestamped")
	_expect(capture.ensure_screenshot_directory() == OK, "screenshot directory should be creatable")

	# Cooldown: a key burst must not queue dozens of pending captures
	# (2026-06-11 perf logs: 55-shot burst at ~450ms main-thread stall each).
	_expect(capture.should_accept_capture(0), "first capture should pass the cooldown gate")
	capture._last_capture_msec = 1000
	_expect(
		not capture.should_accept_capture(1000 + capture.CAPTURE_COOLDOWN_MSEC - 1),
		"capture inside the cooldown window should be rejected"
	)
	_expect(
		capture.should_accept_capture(1000 + capture.CAPTURE_COOLDOWN_MSEC),
		"capture at the cooldown boundary should be accepted"
	)

	# The ~450ms PNG encode must run as a WorkerThreadPool task and report
	# back through the deferred completion path while the node is alive.
	var image := Image.create(4, 4, false, Image.FORMAT_RGB8)
	image.fill(Color(0.2, 0.4, 0.6))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp"))
	var target_path := "res://.tmp/screenshot_capture_smoke_%d_%d.png" % [
		OS.get_process_id(),
		Time.get_ticks_usec(),
	]
	var absolute_path: String = ProjectSettings.globalize_path(target_path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	var task_id: int = WorkerThreadPool.add_task(
		Callable(capture, "_save_image_task").bind(image, target_path, absolute_path),
		false,
		"screenshot smoke save"
	)
	WorkerThreadPool.wait_for_task_completion(task_id)
	await process_frame
	_expect(FileAccess.file_exists(absolute_path), "background save task should write the PNG")
	_expect(
		capture.last_saved_path == target_path,
		"deferred completion should record last_saved_path on the main thread"
	)
	var loaded: Image = Image.load_from_file(absolute_path)
	_expect(
		loaded != null and loaded.get_width() == 4 and loaded.get_height() == 4,
		"saved PNG should round-trip through Image.load_from_file"
	)
	DirAccess.remove_absolute(absolute_path)

	capture.free()
	if _failed:
		quit(1)
		return
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
	_failed = true
	push_error(message)
