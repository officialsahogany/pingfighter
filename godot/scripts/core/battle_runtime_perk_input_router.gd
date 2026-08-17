extends RefCounted

const RUNTIME_PERK_DEBUG_KEY := KEY_F8


func handle_active_choice_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> bool:
	if not _call_modal_gate_bool(
		module_getter,
		"is_runtime_perk_choice_active"
	):
		return false
	var runtime_perk_state := _get_module(module_getter, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method(
		"handle_input"
	):
		if bool(runtime_perk_state.handle_input(
			event,
			owner,
			registry,
			view_size
		)):
			_queue_redraw(owner)
			_mark_handled(owner)
	return true


func handle_debug_grant_input(
	event: InputEvent,
	owner: Object,
	context: Dictionary
) -> bool:
	if not _is_key_pressed(event, RUNTIME_PERK_DEBUG_KEY):
		return false
	_call_context(context, "collect_star_point")
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _is_key_pressed(event: InputEvent, keycode: int) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	return (
		key_event.keycode == keycode
		or key_event.physical_keycode == keycode
	)


func _call_modal_gate_bool(
	module_getter: Callable,
	method_name: String
) -> bool:
	var modal_gate := _get_module(
		module_getter,
		"battle_scene_modal_gate_controller"
	)
	if modal_gate == null or not modal_gate.has_method(method_name):
		return false
	return bool(modal_gate.call(method_name, module_getter))


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _call_context(context: Dictionary, key: String) -> void:
	var callback_value: Variant = context.get(key, Callable())
	if typeof(callback_value) != TYPE_CALLABLE:
		return
	var callback: Callable = callback_value
	if callback.is_valid():
		callback.call()


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.call("queue_redraw")


func _mark_handled(owner: Object) -> void:
	if owner == null or not owner.has_method("get_viewport"):
		return
	var viewport: Viewport = owner.call("get_viewport")
	if viewport != null:
		viewport.set_input_as_handled()
