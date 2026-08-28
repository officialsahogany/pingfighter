extends RefCounted


func process_idle(
	delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	perf_logger: Object = null
) -> bool:
	var grip_overlay := _get_module(module_getter, "grip_style_selection_overlay")
	if grip_overlay == null or not grip_overlay.has_method("update"):
		return false
	var sample_start := _perf_begin(perf_logger)
	var should_redraw := bool(grip_overlay.call(
		"update",
		delta,
		owner,
		registry,
		module_getter
	))
	_perf_end(perf_logger, "process.frame.grip_style_selection", sample_start)
	if should_redraw:
		_queue_redraw(owner)
	return (
		grip_overlay.has_method("is_active")
		and bool(grip_overlay.call("is_active"))
	)


func draw_if_active(
	canvas: CanvasItem,
	owner: Object,
	module_getter: Callable,
	view_size: Vector2,
	perf_logger: Object = null
) -> bool:
	var grip_overlay := _get_module(module_getter, "grip_style_selection_overlay")
	if (
		grip_overlay == null
		or not grip_overlay.has_method("is_active")
		or not bool(grip_overlay.call("is_active"))
	):
		return false
	var sample_start := _perf_begin(perf_logger)
	if grip_overlay.has_method("draw"):
		grip_overlay.call("draw", canvas, owner, view_size)
	_perf_end(perf_logger, "draw.frame.grip_style_selection", sample_start)
	return true


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _queue_redraw(owner: Object) -> void:
	if owner == null:
		return
	if owner.has_method("request_battle_redraw"):
		owner.call("request_battle_redraw")
	elif owner.has_method("queue_redraw"):
		owner.call("queue_redraw")


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.call("begin_sample"))
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.call("finish_sample", label, start_usec)
