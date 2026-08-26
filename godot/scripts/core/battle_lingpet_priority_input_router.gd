extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

const OVERFLOW_HOST_KEY := "lingpet_overflow_choice_overlay_host"


func handle_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2,
	pre_overflow_modal_router: Object = null
) -> bool:
	if _call_modal_gate_bool(module_getter, "is_lingpet_acquire_cutin_active"):
		_handle_acquire_cutin_input(event, owner, registry, module_getter)
		return true
	# Stable X1 insertion seam: acquisition -> pre-overflow modal -> overflow.
	# The adapter owns the modal swallow rule so a locally ignored event cannot
	# leak into the Tower modal underneath an active inserted router.
	if _handle_pre_overflow_modal_input(
		pre_overflow_modal_router,
		event,
		owner,
		registry,
		module_getter,
		view_size
	):
		return true
	if _call_modal_gate_bool(module_getter, "is_lingpet_overflow_choice_active"):
		_handle_overflow_choice_input(
			event,
			owner,
			registry,
			module_getter,
			view_size
		)
		return true
	if _call_modal_gate_bool(module_getter, "is_lingpet_guardian_enhance_cutin_active"):
		_handle_guardian_enhance_cutin_input(event, owner, registry, module_getter)
		return true
	return false


func _handle_pre_overflow_modal_input(
	modal_router: Object,
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> bool:
	if (
		modal_router == null
		or not modal_router.has_method("is_active")
		or not bool(modal_router.call("is_active", module_getter))
	):
		return false
	if modal_router.has_method("handle_input"):
		modal_router.call(
			"handle_input",
			event,
			owner,
			registry,
			module_getter,
			view_size
		)
	return true


func _handle_guardian_enhance_cutin_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> void:
	var runtime := _get_module(module_getter, "lingpet_egg_runtime")
	if runtime == null:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE):
			if runtime.has_method("cancel_guardian_enhance_cutin"):
				runtime.cancel_guardian_enhance_cutin(registry)
			_queue_redraw(owner)
			_mark_handled(owner)
			return
	if _is_confirm_event(event) and runtime.has_method("cancel_guardian_enhance_cutin"):
		runtime.cancel_guardian_enhance_cutin(registry)
		_queue_redraw(owner)
		_mark_handled(owner)


func _handle_acquire_cutin_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> void:
	var lingpet_runtime := _get_module(module_getter, "lingpet_egg_runtime")
	if (
		lingpet_runtime == null
		or not lingpet_runtime.has_method("is_acquire_cutin_awaiting_dismiss")
		or not bool(lingpet_runtime.is_acquire_cutin_awaiting_dismiss())
		or not _is_confirm_event(event)
		or not lingpet_runtime.has_method("begin_acquire_cutin_dismiss")
	):
		return
	if bool(lingpet_runtime.begin_acquire_cutin_dismiss(registry)):
		_queue_redraw(owner)
		_mark_handled(owner)


func _handle_overflow_choice_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> void:
	var lingpet_runtime := _get_module(module_getter, "lingpet_egg_runtime")
	var overflow_host := _get_registry_instance(registry, OVERFLOW_HOST_KEY)
	if overflow_host == null or not overflow_host.has_method("handle_input"):
		return
	var handled := bool(overflow_host.handle_input(
		event,
		lingpet_runtime,
		owner,
		registry,
		view_size
	))
	if handled:
		_queue_redraw(owner)
		_mark_handled(owner)


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
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	return false


func _call_modal_gate_bool(module_getter: Callable, method_name: String) -> bool:
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


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	var value: Variant = null
	if registry.has_method("get_cached_instance"):
		value = registry.get_cached_instance(key)
	if (typeof(value) != TYPE_OBJECT or value == null) and registry.has_method("get_instance"):
		value = registry.get_instance(key)
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
