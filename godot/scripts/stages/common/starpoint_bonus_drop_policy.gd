extends RefCounted


static func get_mythic_item_runtime(deps: Dictionary, context: Dictionary = {}) -> Object:
	var runtime: Object = deps.get("mythic_item_runtime", null)
	if runtime != null:
		return runtime
	var registry: Object = context.get("registry", deps.get("registry", null))
	if registry != null and registry.has_method("get_instance"):
		return registry.get_instance("mythic_item_runtime")
	return null


static func roll_star_detector_bonus_drop_count(deps: Dictionary, context: Dictionary = {}) -> int:
	var mythic_item_runtime: Object = get_mythic_item_runtime(deps, context)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("roll_star_detector_bonus_drop_count"):
		return 0
	return max(0, int(mythic_item_runtime.roll_star_detector_bonus_drop_count()))
