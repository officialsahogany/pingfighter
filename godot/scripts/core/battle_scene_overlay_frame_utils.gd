extends RefCounted


static func get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


static func get_cached_module(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	var value: Variant = registry.get_cached_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


static func get_modal_gate(module_getter: Callable) -> Object:
	return get_module(module_getter, "battle_scene_modal_gate_controller")


static func call_modal_gate_bool(
	module_getter: Callable,
	method_name: String,
	fallback: bool = false,
	modal_gate: Object = null
) -> bool:
	if modal_gate == null:
		modal_gate = get_modal_gate(module_getter)
	if modal_gate == null or not modal_gate.has_method(method_name):
		return fallback
	return bool(modal_gate.call(method_name, module_getter))


static func queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


static func get_view_size(owner: Object) -> Vector2:
	if owner != null and owner.has_method("get_viewport_rect"):
		return owner.get_viewport_rect().size
	return Vector2.ZERO


static func perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


static func perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
