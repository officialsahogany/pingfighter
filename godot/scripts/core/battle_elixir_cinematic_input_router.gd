extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")


func handle_input(
	event: InputEvent,
	owner: Object,
	module_getter: Callable
) -> bool:
	if not _call_modal_gate_bool(
		module_getter,
		"is_elixir_cinematic_active"
	):
		return false
	if _is_confirm_event(event):
		var active_item_runtime := _get_module(
			module_getter,
			"active_item_runtime"
		)
		if (
			active_item_runtime != null
			and active_item_runtime.has_method("handle_elixir_confirm")
			and bool(active_item_runtime.handle_elixir_confirm())
		):
			_queue_redraw(owner)
			_mark_handled(owner)
	return true


func _is_confirm_event(event: InputEvent) -> bool:
	if GamepadInput.is_confirm_event(event):
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
		return (
			key_event.keycode == KEY_SPACE
			or key_event.physical_keycode == KEY_SPACE
			or key_event.keycode == KEY_ENTER
			or key_event.physical_keycode == KEY_ENTER
		)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return (
			mouse_event.pressed
			and mouse_event.button_index == MOUSE_BUTTON_LEFT
		)
	return false


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
