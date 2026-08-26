extends RefCounted


func handle_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> bool:
	if _call_modal_gate_bool(
		module_getter,
		"is_grip_style_selection_active"
	):
		_handle_active_overlay(
			"grip_style_selection_overlay",
			event,
			owner,
			registry,
			module_getter,
			view_size
		)
		return true
	if _call_modal_gate_bool(
		module_getter,
		"is_skill_orb_tooltip_tutorial_active"
	):
		_handle_active_overlay(
			"skill_orb_tooltip_tutorial_hint",
			event,
			owner,
			registry,
			module_getter,
			view_size
		)
		return true
	return false


func _handle_active_overlay(
	module_key: String,
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> void:
	var overlay := _get_module(module_getter, module_key)
	if overlay == null or not overlay.has_method("handle_input"):
		return
	if bool(overlay.handle_input(event, owner, registry, view_size)):
		_queue_redraw(owner)
		_mark_handled(owner)


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


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.call("queue_redraw")


func _mark_handled(owner: Object) -> void:
	if owner == null or not owner.has_method("get_viewport"):
		return
	var viewport: Viewport = owner.call("get_viewport")
	if viewport != null:
		viewport.set_input_as_handled()
