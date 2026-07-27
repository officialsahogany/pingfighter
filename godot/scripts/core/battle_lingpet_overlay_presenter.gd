extends RefCounted

const RUNTIME_KEY := "lingpet_egg_runtime"


func draw_if_active(
	canvas: CanvasItem,
	registry: Object,
	view_size: Vector2,
	active_method: String,
	host_key: String,
	perf_label: String,
	perf_logger: Object = null
) -> void:
	var runtime := _resolve_registry_object(registry, RUNTIME_KEY)
	if runtime == null or not runtime.has_method(active_method):
		return
	if not bool(runtime.call(active_method)):
		return
	var host := _resolve_registry_object(registry, host_key)
	if host == null or not host.has_method("draw"):
		return
	var start_usec := _perf_begin(perf_logger)
	host.call("draw", canvas, runtime, view_size)
	_perf_end(perf_logger, perf_label, start_usec)


func _resolve_registry_object(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	var value: Variant = null
	if registry.has_method("get_cached_instance"):
		value = registry.call("get_cached_instance", key)
	if not _is_valid_object(value) and registry.has_method("get_instance"):
		value = registry.call("get_instance", key)
	if _is_valid_object(value):
		return value as Object
	return null


func _is_valid_object(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and value != null and is_instance_valid(value)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.call("begin_sample"))
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.call("finish_sample", label, start_usec)
