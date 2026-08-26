extends RefCounted


func handle_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> bool:
	var active_item_runtime := _get_module(module_getter, "active_item_runtime")
	if active_item_runtime == null:
		return false

	if active_item_runtime.has_method("handle_debug_spawn_menu_input"):
		var handled_input := bool(active_item_runtime.handle_debug_spawn_menu_input(
			event,
			view_size,
			owner,
			registry
		))
		if handled_input:
			_queue_redraw(owner)
			_mark_handled(owner)
		return handled_input

	if not (event is InputEventMouseButton):
		return false
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if not active_item_runtime.has_method("handle_debug_spawn_menu_click"):
		return false
	var handled_click := bool(active_item_runtime.handle_debug_spawn_menu_click(
		mouse_event.position,
		view_size,
		owner,
		registry
	))
	if handled_click:
		_queue_redraw(owner)
		_mark_handled(owner)
	return handled_click


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
