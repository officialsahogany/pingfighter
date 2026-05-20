extends RefCounted


func update_runtime_perk_resume(owner: Object, registry: Object, delta: float) -> void:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("update_resume_safety"):
		runtime_perk_state.update_resume_safety(owner, registry, delta)
	var laurel_leaf_shield_state: Object = _get_instance(registry, "laurel_leaf_shield_state")
	if laurel_leaf_shield_state != null and laurel_leaf_shield_state.has_method("update_from_runtime"):
		laurel_leaf_shield_state.update_from_runtime(owner, registry, delta)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
