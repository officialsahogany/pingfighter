extends RefCounted


func toggle_debug_spawn_menu(runtime: Object) -> void:
	runtime.debug_spawn_menu.toggle()


func close_debug_spawn_menu(runtime: Object) -> void:
	if runtime.debug_spawn_menu.has_method("close"):
		runtime.debug_spawn_menu.close()


func is_debug_spawn_menu_open(runtime: Object) -> bool:
	return bool(runtime.debug_spawn_menu.is_open())


func handle_debug_spawn_menu_click(
	runtime: Object,
	mouse_position: Vector2,
	view_size: Vector2,
	owner: Object = null,
	registry: Object = null
) -> bool:
	var result: Dictionary = runtime.debug_spawn_menu.handle_click(mouse_position, view_size)
	return apply_debug_spawn_menu_result(runtime, result, owner, registry)


func handle_debug_spawn_menu_input(
	runtime: Object,
	event: InputEvent,
	view_size: Vector2,
	owner: Object = null,
	registry: Object = null
) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mouse_event: InputEventMouseButton = event
	if not mouse_event.pressed:
		return bool(runtime.debug_spawn_menu.is_open())
	var result: Dictionary = runtime.debug_spawn_menu.handle_mouse_button(
		mouse_event.button_index,
		mouse_event.position,
		view_size
	)
	return apply_debug_spawn_menu_result(runtime, result, owner, registry)


func apply_debug_spawn_menu_result(runtime: Object, result: Dictionary, owner: Object, registry: Object) -> bool:
	var item_name: String = str(result.get("item_name", ""))
	if str(result.get("action", "grant")) == "spawn":
		if item_name == "" or int(result.get("delta", 0)) <= 0:
			return bool(result.get("handled", false))
		if runtime != null and runtime.has_method("spawn_field_item"):
			runtime.spawn_field_item(item_name)
		return bool(result.get("handled", false))
	return runtime.debug_inventory.apply_debug_spawn_menu_result(
		result,
		owner,
		registry,
		runtime.item_catalog,
		runtime.slot_controller,
		runtime.effect_controller
	)


func debug_add_item_to_slot(runtime: Object, item_name: String, owner: Object, registry: Object) -> bool:
	return runtime.debug_inventory.debug_add_item_to_slot(
		item_name,
		owner,
		registry,
		runtime.item_catalog,
		runtime.slot_controller,
		runtime.effect_controller
	)


func debug_remove_item_from_slot(runtime: Object, item_name: String, owner: Object, registry: Object) -> bool:
	return runtime.debug_inventory.debug_remove_item_from_slot(item_name, owner, registry)


func adjust_debug_item_quantity(
	runtime: Object,
	item_name: String,
	delta: int,
	owner: Object,
	registry: Object
) -> int:
	return runtime.debug_inventory.adjust_debug_item_quantity(
		item_name,
		delta,
		owner,
		registry,
		runtime.item_catalog,
		runtime.slot_controller,
		runtime.effect_controller
	)


func get_debug_item_counts(runtime: Object, owner: Object) -> Dictionary:
	return runtime.debug_inventory.get_debug_item_counts(owner)


func grant_item_to_slot(
	runtime: Object,
	item_name: String,
	owner: Object,
	registry: Object,
	allow_overflow: bool = false
) -> bool:
	return runtime.debug_inventory.grant_item_to_slot(
		item_name,
		owner,
		registry,
		runtime.item_catalog,
		runtime.slot_controller,
		runtime.effect_controller,
		allow_overflow
	)


func fill_empty_slots_with_item(
	runtime: Object,
	item_name: String,
	owner: Object,
	registry: Object,
	fill_limit: int = 9
) -> int:
	return runtime.debug_inventory.fill_empty_slots_with_item(
		item_name,
		owner,
		registry,
		runtime.item_catalog,
		runtime.slot_controller,
		runtime.effect_controller,
		fill_limit
	)


func debug_spawn_item(runtime: Object, item_name: String, owner: Object = null, registry: Object = null) -> bool:
	return debug_add_item_to_slot(runtime, item_name, owner, registry)


func draw_debug_spawn_menu(runtime: Object, canvas: CanvasItem, view_size: Vector2, owner: Object = null) -> void:
	runtime.debug_spawn_menu.draw(canvas, view_size, get_debug_item_counts(runtime, owner))
