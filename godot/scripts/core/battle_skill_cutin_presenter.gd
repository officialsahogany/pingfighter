extends RefCounted


func draw_if_active(
	canvas: CanvasItem,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2,
	perf_logger: Object = null
) -> void:
	if registry == null or not registry.has_method("get_cached_instance"):
		return
	var cutin_state := _get_active_cutin_state(registry)
	if cutin_state == null or _has_blocking_overlay(module_getter):
		return
	var cutin_host := _get_cached_object(registry, "skill_cutin_overlay_host")
	if cutin_host == null or not cutin_host.has_method("draw"):
		return
	var start_usec := _perf_begin(perf_logger)
	cutin_host.call("draw", canvas, cutin_state, view_size)
	_perf_end(perf_logger, "draw.frame.skill_cutin", start_usec)


func _get_active_cutin_state(registry: Object) -> Object:
	var cutin_state := _get_module_cutin_state(registry, "smasher_power_smash_state")
	if cutin_state != null:
		return cutin_state
	return _get_module_cutin_state(registry, "viper_skill_runtime")


func _get_module_cutin_state(registry: Object, module_key: String) -> Object:
	var module := _get_cached_object(registry, module_key)
	if module == null or not module.has_method("is_cutin_active"):
		return null
	if not bool(module.call("is_cutin_active")):
		return null
	var value: Variant = module.get("cutin_state")
	if typeof(value) == TYPE_OBJECT and value != null and is_instance_valid(value):
		return value as Object
	return null


func _has_blocking_overlay(module_getter: Callable) -> bool:
	var overlay_frame := _get_module(module_getter, "battle_scene_overlay_frame_controller")
	return (
		overlay_frame != null
		and overlay_frame.has_method("has_blocking_activity")
		and bool(overlay_frame.call("has_blocking_activity", module_getter))
	)


func _get_cached_object(registry: Object, key: String) -> Object:
	var value: Variant = registry.call("get_cached_instance", key)
	if typeof(value) == TYPE_OBJECT and value != null and is_instance_valid(value):
		return value as Object
	return null


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and value != null and is_instance_valid(value):
		return value as Object
	return null


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.call("begin_sample"))
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.call("finish_sample", label, start_usec)
