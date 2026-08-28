extends RefCounted


func draw_all(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2,
	perf_logger: Object = null
) -> void:
	_draw_owner_hint(
		"junior_mika_tutorial_hint",
		"draw.frame.junior_mika_hint",
		canvas,
		owner,
		module_getter,
		view_size,
		perf_logger
	)
	_draw_context_hint(
		"skill_orb_tooltip_tutorial_hint",
		"draw.frame.skill_orb_tooltip_tutorial",
		canvas,
		owner,
		registry,
		module_getter,
		view_size,
		perf_logger
	)
	_draw_context_hint(
		"commando_firearm_tutorial_hint",
		"draw.frame.commando_firearm_tutorial",
		canvas,
		owner,
		registry,
		module_getter,
		view_size,
		perf_logger
	)
	_draw_context_hint(
		"viper_jetpack_tutorial_hint",
		"draw.frame.viper_jetpack_tutorial",
		canvas,
		owner,
		registry,
		module_getter,
		view_size,
		perf_logger
	)
	_draw_context_hint(
		"viper_practice_mode",
		"draw.frame.viper_practice_mode",
		canvas,
		owner,
		registry,
		module_getter,
		view_size,
		perf_logger
	)
	_draw_context_hint(
		"active_item_use_tutorial_hint",
		"draw.frame.active_item_use_tutorial",
		canvas,
		owner,
		registry,
		module_getter,
		view_size,
		perf_logger
	)
	_draw_context_hint(
		"character_info_tutorial_hint",
		"draw.frame.character_info_tutorial",
		canvas,
		owner,
		registry,
		module_getter,
		view_size,
		perf_logger
	)


func _draw_owner_hint(
	module_key: String,
	perf_label: String,
	canvas: CanvasItem,
	owner: Object,
	module_getter: Callable,
	view_size: Vector2,
	perf_logger: Object
) -> void:
	var hint := _get_module(module_getter, module_key)
	if hint == null or not hint.has_method("draw"):
		return
	var start_usec := _perf_begin(perf_logger)
	hint.call("draw", canvas, owner, view_size)
	_perf_end(perf_logger, perf_label, start_usec)


func _draw_context_hint(
	module_key: String,
	perf_label: String,
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2,
	perf_logger: Object
) -> void:
	var hint := _get_module(module_getter, module_key)
	if hint == null or not hint.has_method("draw"):
		return
	var start_usec := _perf_begin(perf_logger)
	hint.call("draw", canvas, owner, registry, view_size)
	_perf_end(perf_logger, perf_label, start_usec)


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
