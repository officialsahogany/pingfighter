extends RefCounted


func get_catalog(registry: Object) -> Object:
	return get_instance(registry, "runtime_perk_catalog")


func get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
