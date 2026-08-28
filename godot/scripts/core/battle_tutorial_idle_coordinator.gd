extends RefCounted


func update_all(
	delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	perf_logger: Object = null
) -> void:
	_update_junior_mika(delta, owner, registry, module_getter, perf_logger)
	_update_context_hint(
		"skill_orb_tooltip_tutorial_hint",
		"process.frame.skill_orb_tooltip_tutorial",
		delta,
		owner,
		registry,
		module_getter,
		perf_logger
	)
	_update_context_hint(
		"commando_firearm_tutorial_hint",
		"process.frame.commando_firearm_tutorial",
		delta,
		owner,
		registry,
		module_getter,
		perf_logger
	)
	_update_context_hint(
		"viper_jetpack_tutorial_hint",
		"process.frame.viper_jetpack_tutorial",
		delta,
		owner,
		registry,
		module_getter,
		perf_logger
	)
	_update_context_hint(
		"viper_practice_mode",
		"process.frame.viper_practice_mode",
		delta,
		owner,
		registry,
		module_getter,
		perf_logger
	)
	_update_context_hint(
		"active_item_use_tutorial_hint",
		"process.frame.active_item_use_tutorial",
		delta,
		owner,
		registry,
		module_getter,
		perf_logger
	)
	_update_context_hint(
		"character_info_tutorial_hint",
		"process.frame.character_info_tutorial",
		delta,
		owner,
		registry,
		module_getter,
		perf_logger
	)


func _update_junior_mika(
	delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	perf_logger: Object
) -> void:
	var hint: Object = _get_module(module_getter, "junior_mika_tutorial_hint")
	if hint == null or not hint.has_method("update"):
		return
	var sample_start: int = _perf_begin(perf_logger)
	if bool(hint.update(delta, owner, registry)):
		_queue_redraw(owner)
	_perf_end(perf_logger, "process.frame.junior_mika_hint", sample_start)


func _update_context_hint(
	module_key: String,
	perf_label: String,
	delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	perf_logger: Object
) -> void:
	var hint: Object = _get_module(module_getter, module_key)
	if hint == null or not hint.has_method("update"):
		return
	var sample_start: int = _perf_begin(perf_logger)
	if bool(hint.update(delta, owner, registry, module_getter)):
		_queue_redraw(owner)
	_perf_end(perf_logger, perf_label, sample_start)


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
		owner.request_battle_redraw()
	elif owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
