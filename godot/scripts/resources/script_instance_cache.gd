extends RefCounted

var script_cache: Dictionary = {}
var instance_cache: Dictionary = {}


func get_cached_script(path: String, label: String):
	if script_cache.has(path):
		return script_cache[path]
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		var script = load(path)
		script_cache[path] = script
		return script
	push_warning("Missing %s script at %s" % [label, path])
	return null


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
