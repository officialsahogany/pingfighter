extends RefCounted


func build_deps(registry: Object) -> Dictionary:
	return {
		"orb_hud_state": _get_instance(registry, "orb_hud_state"),
		"active_hud_state": _get_instance(registry, "active_item_hud_state"),
		"active_item_runtime": _get_instance(registry, "active_item_runtime"),
		"mythic_item_runtime": _get_instance(registry, "mythic_item_runtime"),
		"treasure_hunt_runtime": _get_instance(registry, "treasure_hunt_runtime"),
	}


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
