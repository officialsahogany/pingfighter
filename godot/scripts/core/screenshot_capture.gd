extends Node

const SCREENSHOT_KEY := KEY_F12
const SCREENSHOT_DIR := "D:/screenshot"
const SCREENSHOT_PREFIX := "diskhearts_lingpia_"

var capture_in_progress := false
var last_saved_path := ""


func _ready() -> void:
	set_process_input(true)


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
	capture_in_progress = true
	call_deferred("_capture_after_frame")


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
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		_finish_failed_capture("스크린샷 저장에 실패했습니다. 오류 코드: %d" % save_error)
		return ""

	last_saved_path = path
	print("스크린샷 저장: %s" % absolute_path)
	return path


func ensure_screenshot_directory() -> int:
	var absolute_dir := _globalize_output_path(SCREENSHOT_DIR)
	return DirAccess.make_dir_recursive_absolute(absolute_dir)


func _capture_after_frame() -> void:
	await RenderingServer.frame_post_draw
	capture_viewport_to_png()
	capture_in_progress = false


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
