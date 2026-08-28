extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _jobs: Array = []
var _current: Dictionary = {}
var _path: String = ""
var _active: bool = false
var _pending_specs: Array = []
var _pending_delay_frames: int = 0
var _pending_active: bool = false


func is_threaded_prewarm_in_flight() -> bool:
	return _active


func begin_result_texture_prewarm(
	specs: Array,
	is_texture_spec_loaded: Callable,
	try_store_cached_texture_spec: Callable
) -> void:
	_pending_specs.clear()
	_pending_delay_frames = 0
	_pending_active = false
	_begin_result_texture_prewarm_now(
		specs,
		is_texture_spec_loaded,
		try_store_cached_texture_spec
	)


func queue_result_texture_prewarm(specs: Array, delay_frames: int = 1) -> void:
	_drain_result_texture_prewarm_thread()
	_jobs.clear()
	_clear_threaded_job()
	_pending_specs = specs.duplicate(true)
	_pending_delay_frames = max(0, delay_frames)
	_pending_active = true


func update_result_texture_prewarm(
	is_texture_spec_loaded: Callable,
	try_store_cached_texture_spec: Callable,
	store_texture_spec: Callable
) -> bool:
	if _pending_active:
		if _pending_delay_frames > 0:
			_pending_delay_frames -= 1
			return false
		var specs := _pending_specs.duplicate(true)
		_pending_specs.clear()
		_pending_active = false
		_begin_result_texture_prewarm_now(
			specs,
			is_texture_spec_loaded,
			try_store_cached_texture_spec
		)
	if not _active:
		return _jobs.is_empty() and not _pending_active

	var progress_values: Array = []
	var status := ResourceLoader.load_threaded_get_status(_path, progress_values)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_finish_result_texture_threaded_job(
				ResourceLoader.load_threaded_get(_path),
				store_texture_spec
			)
			_request_next_result_texture_prewarm_job(
				is_texture_spec_loaded,
				try_store_cached_texture_spec
			)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_request_next_result_texture_prewarm_job(
				is_texture_spec_loaded,
				try_store_cached_texture_spec
			)
	return not _active and _jobs.is_empty()


func has_result_texture_prewarm_work() -> bool:
	return _active or not _jobs.is_empty() or _pending_active


func _begin_result_texture_prewarm_now(
	specs: Array,
	is_texture_spec_loaded: Callable,
	try_store_cached_texture_spec: Callable
) -> void:
	_drain_result_texture_prewarm_thread()
	_jobs.clear()
	_clear_threaded_job()

	var queued_paths: Dictionary = {}
	for spec_value in specs:
		if not (spec_value is Dictionary):
			continue
		var spec: Dictionary = spec_value
		if bool(is_texture_spec_loaded.call(spec)):
			continue
		if bool(try_store_cached_texture_spec.call(spec)):
			continue
		var spec_path := str(spec.get("path", ""))
		if spec_path == "" or queued_paths.has(spec_path) or not _is_thread_loadable_texture_path(spec_path):
			continue
		queued_paths[spec_path] = true
		_jobs.append(spec)
	_request_next_result_texture_prewarm_job(
		is_texture_spec_loaded,
		try_store_cached_texture_spec
	)


func _request_next_result_texture_prewarm_job(
	is_texture_spec_loaded: Callable,
	try_store_cached_texture_spec: Callable
) -> void:
	_clear_threaded_job()
	while not _jobs.is_empty():
		var spec_value: Variant = _jobs.pop_front()
		if not (spec_value is Dictionary):
			continue
		var spec: Dictionary = spec_value
		if bool(is_texture_spec_loaded.call(spec)):
			continue
		if bool(try_store_cached_texture_spec.call(spec)):
			continue
		var spec_path := str(spec.get("path", ""))
		if spec_path == "" or not _is_thread_loadable_texture_path(spec_path):
			continue
		var request_error := ResourceLoader.load_threaded_request(spec_path, "Texture2D", true)
		if request_error == OK or request_error == ERR_BUSY:
			_current = spec
			_path = spec_path
			_active = true
			return


func _finish_result_texture_threaded_job(resource: Resource, store_texture_spec: Callable) -> void:
	var texture := resource as Texture2D
	if texture == null:
		return
	ProjectResourceLoader.store_texture(_path, texture)
	store_texture_spec.call(_current, texture)


func _drain_result_texture_prewarm_thread() -> void:
	if not _active or _path == "":
		_clear_threaded_job()
		return
	var progress_values: Array = []
	var status := ResourceLoader.load_threaded_get_status(_path, progress_values)
	if status != ResourceLoader.THREAD_LOAD_FAILED and status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_get(_path)
	_clear_threaded_job()


func _clear_threaded_job() -> void:
	_active = false
	_current = {}
	_path = ""


func _is_thread_loadable_texture_path(path: String) -> bool:
	return ProjectResourceLoader.can_thread_load_texture(path)
