extends Node

const SCREENSHOT_KEY := KEY_F12
const SCREENSHOT_DIR := "D:/screenshot"
const SCREENSHOT_PREFIX := "diskhearts_lingpia_"
# A capture used to stall the main thread ~450ms per shot: Image.save_png's
# single-threaded PNG encode of the full window (2026-06-11 perf logs, 55-shot
# burst). The encode now runs on a WorkerThreadPool task; only the GPU
# readback (get_image, ~0-40ms) stays on the main thread. The cooldown keeps
# a held key from queueing dozens of ~16MB pending images.
const CAPTURE_COOLDOWN_MSEC := 500

var capture_in_progress := false
var last_saved_path := ""
var _last_capture_msec: int = -CAPTURE_COOLDOWN_MSEC
var _pending_save_task_ids: Array[int] = []


func _ready() -> void:
	set_process_input(true)


func _exit_tree() -> void:
	for task_id in _pending_save_task_ids:
		WorkerThreadPool.wait_for_task_completion(task_id)
	_pending_save_task_ids.clear()


func _input(event: InputEvent) -> void:
	if not is_screenshot_key_event(event):
		return
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	request_screenshot()


func request_screenshot() -> void:
	if capture_in_progress:
		return
	var now_msec: int = Time.get_ticks_msec()
	if not should_accept_capture(now_msec):
		return
	_last_capture_msec = now_msec
	capture_in_progress = true
	call_deferred("_capture_after_frame")


func should_accept_capture(now_msec: int) -> bool:
	return now_msec - _last_capture_msec >= CAPTURE_COOLDOWN_MSEC


func is_screenshot_key_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == SCREENSHOT_KEY or key_event.physical_keycode == SCREENSHOT_KEY


func build_screenshot_path(datetime: Dictionary = {}, msec: int = -1) -> String:
	var source := datetime
	if source.is_empty():
		source = Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d_%02d%02d%02d_%03d" % [
		int(source.get("year", 0)),
		int(source.get("month", 0)),
		int(source.get("day", 0)),
		int(source.get("hour", 0)),
		int(source.get("minute", 0)),
		int(source.get("second", 0)),
		int(msec if msec >= 0 else Time.get_ticks_msec() % 1000),
	]
	return "%s/%s%s.png" % [SCREENSHOT_DIR, SCREENSHOT_PREFIX, stamp]


# Reads the frame back on the main thread, then hands the encode+write to a
# worker task. Returns the path the capture will be written to ("" on
# failure); last_saved_path updates only after the background save lands.
func capture_viewport_to_png(viewport: Viewport = null) -> String:
	var target_viewport := viewport
	if target_viewport == null:
		target_viewport = get_tree().root
	if target_viewport == null:
		_finish_failed_capture("스크린샷을 찍을 뷰포트를 찾지 못했습니다.")
		return ""

	var texture := target_viewport.get_texture()
	if texture == null:
		_finish_failed_capture("스크린샷 텍스처를 읽지 못했습니다.")
		return ""

	var image: Image = texture.get_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		_finish_failed_capture("스크린샷 이미지가 비어 있습니다.")
		return ""

	var directory_error := ensure_screenshot_directory()
	if directory_error != OK:
		_finish_failed_capture("스크린샷 폴더를 만들지 못했습니다. 오류 코드: %d" % directory_error)
		return ""

	var path := _build_unique_screenshot_path()
	var absolute_path := _globalize_output_path(path)
	var task_id: int = WorkerThreadPool.add_task(
		Callable(self, "_save_image_task").bind(image, path, absolute_path),
		false,
		"screenshot png encode"
	)
	_pending_save_task_ids.append(task_id)
	return path


func ensure_screenshot_directory() -> int:
	var absolute_dir := _globalize_output_path(SCREENSHOT_DIR)
	return DirAccess.make_dir_recursive_absolute(absolute_dir)


func _capture_after_frame() -> void:
	await RenderingServer.frame_post_draw
	capture_viewport_to_png()
	capture_in_progress = false


# Runs on a WorkerThreadPool thread. The Image is owned by this task after
# dispatch; only the deferred completion call touches node state, back on the
# main thread.
func _save_image_task(image: Image, path: String, absolute_path: String) -> void:
	var save_error := image.save_png(absolute_path)
	call_deferred("_on_save_task_finished", path, absolute_path, save_error)


func _on_save_task_finished(path: String, absolute_path: String, save_error: int) -> void:
	_reap_finished_save_tasks()
	if save_error != OK:
		_finish_failed_capture("스크린샷 저장에 실패했습니다. 오류 코드: %d" % save_error)
		return
	last_saved_path = path
	print("스크린샷 저장: %s" % absolute_path)


func _reap_finished_save_tasks() -> void:
	for index in range(_pending_save_task_ids.size() - 1, -1, -1):
		var task_id: int = _pending_save_task_ids[index]
		if WorkerThreadPool.is_task_completed(task_id):
			WorkerThreadPool.wait_for_task_completion(task_id)
			_pending_save_task_ids.remove_at(index)


func _build_unique_screenshot_path() -> String:
	var base_path := build_screenshot_path()
	var stem := base_path.substr(0, base_path.length() - 4)
	var candidate := base_path
	var index := 1
	while _path_exists(candidate):
		candidate = "%s_%02d.png" % [stem, index]
		index += 1
	return candidate


func _path_exists(path: String) -> bool:
	if FileAccess.file_exists(path):
		return true
	var absolute_path := _globalize_output_path(path)
	return absolute_path != path and FileAccess.file_exists(absolute_path)


func _globalize_output_path(path: String) -> String:
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path(path)


func _finish_failed_capture(message: String) -> void:
	push_warning(message)
