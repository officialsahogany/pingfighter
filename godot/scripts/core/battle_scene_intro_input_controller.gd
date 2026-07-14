extends RefCounted


func handle_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	context: Dictionary
) -> bool:
	if _is_stage7_prebattle_pending(module_getter):
		_handle_stage7_prebattle_input(event, owner, registry, module_getter)
		return true
	if _is_stage_landing_intro_active(module_getter):
		_handle_stage_landing_intro_input(event, owner, registry, module_getter, context)
		return true
	if _is_ball_spawn_intro_active(module_getter):
		_handle_ball_spawn_intro_input(event, owner, registry, module_getter)
		return true
	return false


func _handle_stage7_prebattle_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> void:
	var presentation: Object = _get_module(module_getter, "stage7_akamu_prebattle_presentation")
	if presentation == null or not presentation.has_method("handle_input"):
		return
	if bool(presentation.handle_input(event, owner, registry)):
		_queue_redraw(owner)
		_mark_handled(owner)


func _handle_stage_landing_intro_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	context: Dictionary
) -> void:
	var landing_intro: Object = _get_module(module_getter, "stage_landing_intro")
	if landing_intro == null or not landing_intro.has_method("handle_input"):
		return
	var handled: bool = bool(landing_intro.handle_input(event, registry))
	if not handled:
		return
	if not _is_stage_landing_intro_active(module_getter):
		_call_context(context, "begin_ball_spawn_intro")
	_queue_redraw(owner)
	_mark_handled(owner)


func _handle_ball_spawn_intro_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> void:
	var ball_spawn_intro: Object = _get_module(module_getter, "stage_ball_spawn_intro")
	if ball_spawn_intro == null or not ball_spawn_intro.has_method("handle_input"):
		return
	if bool(ball_spawn_intro.handle_input(event, registry)):
		_mark_handled(owner)


func _is_stage_landing_intro_active(module_getter: Callable) -> bool:
	return _call_readiness_bool(module_getter, "is_stage_landing_intro_active")


func _is_ball_spawn_intro_active(module_getter: Callable) -> bool:
	return _call_readiness_bool(module_getter, "is_ball_spawn_intro_active")


func _is_stage7_prebattle_pending(module_getter: Callable) -> bool:
	return _call_readiness_bool(module_getter, "is_stage7_prebattle_pending")


func _get_readiness_controller(module_getter: Callable) -> Object:
	return _get_module(module_getter, "battle_scene_readiness_controller")


func _call_readiness_bool(module_getter: Callable, method_name: String, fallback: bool = false) -> bool:
	var readiness: Object = _get_readiness_controller(module_getter)
	if readiness == null or not readiness.has_method(method_name):
		return fallback
	return bool(readiness.call(method_name, module_getter))


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _call_context(context: Dictionary, key: String) -> void:
	var callback_value: Variant = context.get(key, Callable())
	if typeof(callback_value) == TYPE_CALLABLE:
		var callback: Callable = callback_value
		if callback.is_valid():
			callback.call()


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _mark_handled(owner: Object) -> void:
	if owner == null or not owner.has_method("get_viewport"):
		return
	var viewport: Viewport = owner.get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
