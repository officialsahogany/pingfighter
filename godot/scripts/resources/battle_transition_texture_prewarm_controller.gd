extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _prewarm_key: String = ""
var _step_index: int = 0
var _current: Dictionary = {}
var _path: String = ""
var _active: bool = false


func is_threaded_prewarm_in_flight() -> bool:
	return _active


func prepare_transition(prewarm_key: String) -> bool:
	if _prewarm_key == prewarm_key:
		return false
	_prewarm_key = prewarm_key
	_step_index = 0
	_clear_threaded_job()
	return true


func get_step_index() -> int:
	return _step_index


func get_current_path() -> String:
	return _path


func advance_step_and_is_complete(total_step_count: int) -> bool:
	_step_index += 1
	return _step_index >= total_step_count


func reset_transition() -> void:
	_prewarm_key = ""
	_step_index = 0
	_drain_threaded_job()


func prewarm_texture_spec_step(
	spec: Dictionary,
	is_texture_spec_loaded: Callable,
	try_store_cached_texture_spec: Callable,
	load_texture_spec: Callable,
	store_texture_spec: Callable
) -> bool:
	if bool(is_texture_spec_loaded.call(spec)):
		return true
	if bool(try_store_cached_texture_spec.call(spec)):
		return true

	var spec_path := str(spec.get("path", ""))
	if spec_path == "":
		return true
	if not ProjectResourceLoader.can_thread_load_texture(spec_path):
		load_texture_spec.call(spec)
		return true
	if _active:
		return _update_threaded_job(load_texture_spec, store_texture_spec)

	var request_error := ResourceLoader.load_threaded_request(spec_path, "Texture2D", true)
	if request_error != OK and request_error != ERR_BUSY:
		load_texture_spec.call(spec)
		return true
	_current = spec
	_path = spec_path
	_active = true
	return false


func _update_threaded_job(load_texture_spec: Callable, store_texture_spec: Callable) -> bool:
	if not _active:
		return true
	var progress_values: Array = []
	var status := ResourceLoader.load_threaded_get_status(_path, progress_values)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_finish_threaded_job(ResourceLoader.load_threaded_get(_path), store_texture_spec)
			_clear_threaded_job()
			return true
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			var failed_spec := _current.duplicate(true)
			_clear_threaded_job()
			load_texture_spec.call(failed_spec)
			return true
	return false


func _finish_threaded_job(resource: Resource, store_texture_spec: Callable) -> void:
	var texture := resource as Texture2D
	if texture == null:
		return
	ProjectResourceLoader.store_texture(_path, texture)
	store_texture_spec.call(_current, texture)


func _drain_threaded_job() -> void:
	if not _active or _path == "":
		_clear_threaded_job()
		return
	var progress_values: Array = []
	var status := ResourceLoader.load_threaded_get_status(_path, progress_values)
	if status != ResourceLoader.THREAD_LOAD_FAILED and status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_get(_path)
	_clear_threaded_job()


func _clear_threaded_job() -> void:
	_current = {}
	_path = ""
	_active = false
