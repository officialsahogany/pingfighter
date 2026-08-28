extends RefCounted


func process_idle(
	delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	perf_logger: Object = null
) -> bool:
	var match_event_driver := _get_transition_driver(module_getter)
	if not _is_active(match_event_driver):
		return false
	if match_event_driver.has_method("update_stage_transition_loading"):
		var sample_start := _perf_begin(perf_logger)
		match_event_driver.call(
			"update_stage_transition_loading",
			delta,
			owner,
			registry
		)
		_perf_end(perf_logger, "process.frame.stage_transition_loading", sample_start)
	_queue_redraw(owner)
	return true


func draw_if_active(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2,
	perf_logger: Object = null
) -> bool:
	var match_event_driver := _get_transition_driver(module_getter)
	if not _is_active(match_event_driver):
		return false
	if match_event_driver.has_method("draw_stage_transition_loading"):
		var transition_start := _perf_begin(perf_logger)
		var was_drawn := bool(match_event_driver.call(
			"draw_stage_transition_loading",
			canvas,
			owner,
			registry,
			module_getter,
			view_size
		))
		_perf_end(
			perf_logger,
			"draw.frame.stage_transition_loading",
			transition_start
		)
		if was_drawn:
			return true
	var black_start := _perf_begin(perf_logger)
	_draw_black(canvas, view_size)
	_perf_end(perf_logger, "draw.frame.black", black_start)
	return true


func _get_transition_driver(module_getter: Callable) -> Object:
	return _get_module(module_getter, "battle_scene_match_event_driver")


func _is_active(match_event_driver: Object) -> bool:
	return (
		match_event_driver != null
		and match_event_driver.has_method("is_stage_transition_loading_active")
		and bool(match_event_driver.call("is_stage_transition_loading_active"))
	)


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


func _draw_black(canvas: CanvasItem, view_size: Vector2) -> void:
	if canvas != null:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color.BLACK)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.call("begin_sample"))
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.call("finish_sample", label, start_usec)
