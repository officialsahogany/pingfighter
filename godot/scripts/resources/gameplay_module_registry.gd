extends RefCounted

const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const ScriptInstanceCache := preload("res://scripts/resources/script_instance_cache.gd")

var catalog: Object = GameplayModuleCatalog.new()
var cache: Object = ScriptInstanceCache.new()
var spec_cache: Dictionary = {}
var unknown_key_warnings: Dictionary = {}


func create_ref_counted(key: String):
	var spec: Dictionary = _get_spec(key)
	if spec.is_empty():
		return null
	return cache.create_ref_counted(str(spec["path"]), str(spec["label"]))


func request_threaded_script(key: String) -> bool:
	var spec: Dictionary = _get_spec(key)
	if spec.is_empty():
		return true
	return cache.request_threaded_script(str(spec["path"]), str(spec["label"]))


func is_threaded_script_ready(key: String) -> bool:
	var spec: Dictionary = _get_spec(key)
	if spec.is_empty():
		return true
	return cache.is_threaded_script_ready(str(spec["path"]), str(spec["label"]))


func get_instance(key: String):
	var spec: Dictionary = _get_spec(key)
	if spec.is_empty():
		return null
	return cache.get_instance(str(spec["path"]), str(spec["label"]))


func get_cached_instance(key: String):
	var spec: Dictionary = _get_spec(key)
	if spec.is_empty():
		return null
	return cache.get_cached_instance(str(spec["path"]))


func clear_instances() -> void:
	cache.clear_instances()


func clear_all() -> void:
	cache.clear_all()
	spec_cache.clear()
	unknown_key_warnings.clear()


func _get_spec(key: String) -> Dictionary:
	if spec_cache.has(key):
		return spec_cache[key]
	var spec: Dictionary = catalog.get_spec(key)
	spec_cache[key] = spec
	if spec.is_empty() and not unknown_key_warnings.has(key):
		unknown_key_warnings[key] = true
		push_warning("Unknown gameplay module key: %s" % key)
	return spec
