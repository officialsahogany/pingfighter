extends RefCounted


static func update_drop(drop: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	if drop.is_empty():
		return {}
	var runtime := _resolve_lingpet_runtime(context, deps)
	if runtime == null or not runtime.has_method("update_starlight_tracking_for_starpoint_drop"):
		return {}
	return runtime.update_starlight_tracking_for_starpoint_drop(drop, maxf(0.0, fps_scale) / 60.0, context)


static func _resolve_lingpet_runtime(context: Dictionary, deps: Dictionary) -> Object:
	var runtime_value: Variant = deps.get("lingpet_egg_runtime", deps.get("lingpet_runtime", null))
	if runtime_value is Object:
		return runtime_value as Object
	var registry_value: Variant = context.get("registry", deps.get("registry", null))
	if registry_value is Object and (registry_value as Object).has_method("get_instance"):
		var runtime_from_registry: Variant = (registry_value as Object).get_instance("lingpet_egg_runtime")
		if runtime_from_registry is Object:
			return runtime_from_registry as Object
		runtime_from_registry = (registry_value as Object).get_instance("lingpet_runtime")
		if runtime_from_registry is Object:
			return runtime_from_registry as Object
	return null
