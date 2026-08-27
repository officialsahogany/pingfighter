extends RefCounted


var _hovered_slot_index := -1


func handle_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	scene_ready: bool
) -> bool:
	if _is_mobile_runtime() or owner == null or not scene_ready:
		_set_hovered_slot(-1, owner)
		return false
	if not (event is InputEventMouseMotion or event is InputEventMouseButton):
		return false

	var active_item_slots: Array = _get_active_item_slots(owner)
	var layout: Dictionary = _build_layout(active_item_slots.size(), owner, registry, module_getter)
	var mouse_event_base: InputEventMouse = event as InputEventMouse
	var mouse_position: Vector2 = mouse_event_base.position
	var slot_index: int = resolve_hovered_slot(layout, active_item_slots.size(), mouse_position)
	_set_hovered_slot(slot_index, owner)

	if not (event is InputEventMouseButton):
		return false
	var mouse_event: InputEventMouseButton = event
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT or slot_index < 0:
		return false

	var active_item_runtime: Object = _get_module(module_getter, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("use_slot"):
		active_item_runtime.use_slot(slot_index, owner, registry)
	return true


func resolve_hovered_slot(layout: Dictionary, item_count: int, mouse_position: Vector2) -> int:
	if _is_mobile_runtime() or not bool(layout.get("visible", false)) or item_count <= 0:
		return -1
	var slot_rects_value: Variant = layout.get("slot_rects", [])
	if not (slot_rects_value is Array):
		return -1
	var slot_rects: Array = slot_rects_value
	var slot_limit: int = mini(item_count, slot_rects.size())
	for slot_index in range(slot_limit):
		var rect_value: Variant = slot_rects[slot_index]
		if rect_value is Rect2 and (rect_value as Rect2).has_point(mouse_position):
			return slot_index
	return -1


func get_hovered_slot_index() -> int:
	return _hovered_slot_index


func reset() -> void:
	_hovered_slot_index = -1


func _set_hovered_slot(slot_index: int, owner: Object) -> void:
	if slot_index == _hovered_slot_index:
		return
	_hovered_slot_index = slot_index
	_request_owner_redraw(owner)


func _build_layout(item_count: int, owner: Object, registry: Object, module_getter: Callable) -> Dictionary:
	var layout_builder: Object = _get_module(module_getter, "active_item_hud_layout")
	if layout_builder == null or not layout_builder.has_method("build_layout"):
		return {"visible": false}
	var layout_context: Dictionary = _build_layout_context(owner, module_getter)
	return layout_builder.build_layout(
		_get_view_size(owner),
		_get_vector2(layout_context, "game_offset", Vector2.ZERO),
		_get_vector2(layout_context, "game_size", Vector2(760.0, 750.0)),
		float(layout_context.get("field_width", 760.0)),
		item_count,
		_get_active_item_slot_capacity(registry, module_getter, item_count)
	)


func _build_layout_context(owner: Object, module_getter: Callable) -> Dictionary:
	var view_size: Vector2 = _get_view_size(owner)
	var width := 760.0
	var height := 750.0
	var scene_config: Object = _get_module(module_getter, "battle_scene_config")
	if scene_config != null and scene_config.has_method("build_draw_context"):
		var draw_context: Dictionary = scene_config.build_draw_context()
		width = float(draw_context.get("width", width))
		height = float(draw_context.get("height", height))
	var view_layout: Object = _get_module(module_getter, "battle_view_layout")
	if view_layout != null and view_layout.has_method("build_game_layout"):
		var layout: Dictionary = view_layout.build_game_layout(view_size, width, height)
		layout["field_width"] = width
		return layout
	return {
		"game_offset": Vector2.ZERO,
		"game_size": Vector2(width, height),
		"field_width": width,
	}


func _get_active_item_slot_capacity(registry: Object, module_getter: Callable, minimum_capacity: int) -> int:
	var capacity: int = max(3, minimum_capacity)
	var runtime_perk_state: Object = _get_module(module_getter, "runtime_perk_state")
	if runtime_perk_state == null and registry != null and registry.has_method("get_instance"):
		runtime_perk_state = registry.get_instance("runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("get_active_item_slot_capacity"):
		capacity = max(capacity, int(runtime_perk_state.get_active_item_slot_capacity(3)))
	var mythic_item_runtime: Object = _get_module(module_getter, "mythic_item_runtime")
	if mythic_item_runtime == null and registry != null and registry.has_method("get_instance"):
		mythic_item_runtime = registry.get_instance("mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_active_item_slot_capacity"):
		capacity = max(capacity, int(mythic_item_runtime.get_active_item_slot_capacity(capacity)))
	return capacity


func _get_active_item_slots(owner: Object) -> Array:
	var value: Variant = owner.get("active_item_slots")
	if value is Array:
		return value
	return []


func _get_view_size(owner: Object) -> Vector2:
	if owner != null and owner.has_method("get_viewport_rect"):
		return owner.get_viewport_rect().size
	return Vector2(760.0, 750.0)


func _request_owner_redraw(owner: Object) -> void:
	if owner == null:
		return
	if owner.has_method("request_battle_redraw"):
		owner.request_battle_redraw()
	elif owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var module: Variant = module_getter.call(key)
	if typeof(module) == TYPE_OBJECT and is_instance_valid(module):
		return module as Object
	return null


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _is_mobile_runtime() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
