extends RefCounted

var script_cache: Dictionary = {}
var instance_cache: Dictionary = {}
var threaded_script_requests: Dictionary = {}


func get_cached_script(path: String, label: String):
	if script_cache.has(path):
		return script_cache[path]
	if threaded_script_requests.has(path) and _try_finish_threaded_script(path, label):
		return script_cache.get(path, null)
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		var script = load(path)
		script_cache[path] = script
		return script
	push_warning("Missing %s script at %s" % [label, path])
	return null


func request_threaded_script(path: String, label: String) -> bool:
	if script_cache.has(path):
		return true
	if path == "" or (not ResourceLoader.exists(path) and not FileAccess.file_exists(path)):
		push_warning("Missing %s script at %s" % [label, path])
		return true
	if threaded_script_requests.has(path):
		return false
	var request_error := ResourceLoader.load_threaded_request(path, "Script", true)
	if request_error != OK and request_error != ERR_BUSY:
		request_error = ResourceLoader.load_threaded_request(path, "", true)
	if request_error != OK and request_error != ERR_BUSY:
		return true
	threaded_script_requests[path] = true
	return false


func is_threaded_script_ready(path: String, label: String) -> bool:
	if script_cache.has(path):
		return true
	if not threaded_script_requests.has(path):
		return true
	return _try_finish_threaded_script(path, label)


func _try_finish_threaded_script(path: String, label: String) -> bool:
	var progress_values: Array = []
	var status := ResourceLoader.load_threaded_get_status(path, progress_values)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			threaded_script_requests.erase(path)
			var resource: Resource = ResourceLoader.load_threaded_get(path)
			if resource is Script:
				script_cache[path] = resource
			else:
				push_warning("Threaded %s script load did not return a Script: %s" % [label, path])
			return true
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			threaded_script_requests.erase(path)
			push_warning("Threaded %s script load failed: %s" % [label, path])
			return true
	return false


func create_ref_counted(path: String, label: String):
	var script = get_cached_script(path, label)
	if script == null:
		return null
	return script.new()


func get_instance(path: String, label: String):
	if instance_cache.has(path):
		var cached_instance: Variant = instance_cache[path]
		if cached_instance == null:
			return null
		if typeof(cached_instance) == TYPE_OBJECT and is_instance_valid(cached_instance):
			return cached_instance
		instance_cache.erase(path)
	var instance = create_ref_counted(path, label)
	instance_cache[path] = instance
	return instance


func get_cached_instance(path: String):
	if not instance_cache.has(path):
		return null
	var cached_instance: Variant = instance_cache[path]
	if cached_instance == null:
		return null
	if typeof(cached_instance) == TYPE_OBJECT and is_instance_valid(cached_instance):
		return cached_instance
	instance_cache.erase(path)
	return null


func clear_instances() -> void:
	instance_cache.clear()


func clear_all() -> void:
	script_cache.clear()
	instance_cache.clear()
	threaded_script_requests.clear()
