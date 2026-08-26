extends RefCounted


func handle_open_menu_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> bool:
	if handle_pre_ball_speed_menu_input(
		event,
		owner,
		registry,
		module_getter,
		view_size
	):
		return true
	return handle_post_ball_speed_menu_input(
		event,
		owner,
		registry,
		module_getter,
		view_size
	)


func handle_pre_ball_speed_menu_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> bool:
	if _call_modal_gate_bool(module_getter, "is_character_debug_picker_open"):
		return _dispatch_input(
			"character_debug_picker",
			"handle_input",
			event,
			owner,
			registry,
			module_getter,
			view_size
		)
	if _call_modal_gate_bool(module_getter, "is_weather_debug_picker_open"):
		return _dispatch_input(
			"weather_debug_picker",
			"handle_input",
			event,
			owner,
			registry,
			module_getter,
			view_size
		)
	if _call_modal_gate_bool(module_getter, "is_stage_debug_picker_open"):
		return _dispatch_input(
			"stage_debug_picker",
			"handle_input",
			event,
			owner,
			registry,
			module_getter,
			view_size
		)
	if _call_modal_gate_bool(module_getter, "is_lingpet_debug_picker_open"):
		return _dispatch_input(
			"lingpet_debug_picker",
			"handle_input",
			event,
			owner,
			registry,
			module_getter,
			view_size
		)
	return false


func handle_post_ball_speed_menu_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> bool:
	if _call_modal_gate_bool(module_getter, "is_mythic_management_menu_open"):
		return _dispatch_input(
			"mythic_item_runtime",
			"handle_debug_management_menu_input",
			event,
			owner,
			registry,
			module_getter,
			view_size
		)
	if _call_modal_gate_bool(module_getter, "is_perk_debug_picker_open"):
		return _dispatch_input(
			"runtime_perk_debug_picker",
			"handle_input",
			event,
			owner,
			registry,
			module_getter,
			view_size
		)
	return false


func _dispatch_input(
	module_key: String,
	method_name: String,
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> bool:
	var module := _get_module(module_getter, module_key)
	if module != null and module.has_method(method_name):
		var handled := bool(module.call(
			method_name,
			event,
			owner,
			registry,
			view_size
		))
		if handled:
			_queue_redraw(owner)
			_mark_handled(owner)
	return true


func _call_modal_gate_bool(
	module_getter: Callable,
	method_name: String,
	fallback: bool = false
) -> bool:
	var modal_gate := _get_module(
		module_getter,
		"battle_scene_modal_gate_controller"
	)
	if modal_gate == null or not modal_gate.has_method(method_name):
		return fallback
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
