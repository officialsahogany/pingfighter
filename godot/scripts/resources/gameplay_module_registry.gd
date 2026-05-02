extends RefCounted

const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const ScriptInstanceCache := preload("res://scripts/resources/script_instance_cache.gd")

var catalog: Object = GameplayModuleCatalog.new()
var cache: Object = ScriptInstanceCache.new()


func create_ref_counted(key: String):
	var spec: Dictionary = _get_spec(key)
	if spec.is_empty():
		return null
	return cache.create_ref_counted(str(spec["path"]), str(spec["label"]))


func get_instance(key: String):
	var spec: Dictionary = _get_spec(key)
	if spec.is_empty():
		return null
	return cache.get_instance(str(spec["path"]), str(spec["label"]))


func clear_instances() -> void:
	cache.clear_instances()


func clear_all() -> void:
	cache.clear_all()


func _get_spec(key: String) -> Dictionary:
	var spec: Dictionary = catalog.get_spec(key)
	if spec.is_empty():
		push_warning("Unknown gameplay module key: %s" % key)
	return spec
