extends RefCounted


func draw_result_if_active(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2,
	perf_logger: Object = null
) -> bool:
	var screen := _get_module(module_getter, "stage_clear_result_screen")
	if not _is_active(screen):
		return false
	if screen.has_method("draw"):
		var start_usec := _perf_begin(perf_logger)
		screen.call("draw", canvas, owner, registry, view_size)
		_perf_end(perf_logger, "draw.frame.result_screen", start_usec)
	return true


func draw_defeat_if_active(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2,
	perf_logger: Object = null
) -> bool:
	var continue_screen := _get_module(
		module_getter,
		"defeat_chance_gems_continue_screen"
	)
	if _is_active(continue_screen):
		_draw_defeat_screen(
			continue_screen,
			canvas,
			owner,
			registry,
			view_size,
			perf_logger,
			"draw.frame.defeat_chance_gems_continue"
		)
		return true

	var settlement_screen := _get_module(module_getter, "defeat_settlement_screen")
	if _is_active(settlement_screen):
		_draw_defeat_screen(
			settlement_screen,
			canvas,
			owner,
			registry,
			view_size,
			perf_logger,
			"draw.frame.defeat_settlement"
		)
		return true
	return false


func _draw_defeat_screen(
	screen: Object,
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	view_size: Vector2,
	perf_logger: Object,
	perf_label: String
) -> void:
	var start_usec := _perf_begin(perf_logger)
	if screen.has_method("draw"):
		screen.call("draw", canvas, owner, registry, view_size)
	_perf_end(perf_logger, perf_label, start_usec)


func _is_active(screen: Object) -> bool:
	return (
		screen != null
		and screen.has_method("is_active")
		and bool(screen.call("is_active"))
	)


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
