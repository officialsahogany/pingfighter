extends RefCounted

const MOBILE_ACTIVE_ITEM_SLOT_HIT_GRACE_MIN := 10.0
const MOBILE_ACTIVE_ITEM_SLOT_HIT_GRACE_RATIO := 0.28


func handle_input(
	event: InputEvent,
	owner: Object,
	module_getter: Callable,
	scene_ready: bool
) -> bool:
	if not _is_mobile_runtime():
		return false
	if _handle_mobile_active_item_touch(event, owner, module_getter, scene_ready):
		return true
	return _handle_mobile_touch_controls(event, owner, module_getter, scene_ready)


func sync_controls_enabled(owner: Object, module_getter: Callable, scene_ready: bool) -> void:
	if not _is_mobile_runtime():
		return
	var touch_controls: Object = _get_module(module_getter, "mobile_touch_controls")
	if touch_controls != null and touch_controls.has_method("set_controls_enabled"):
		touch_controls.set_controls_enabled(_are_controls_active(owner, module_getter, scene_ready))


func draw(canvas: CanvasItem, owner: Object, module_getter: Callable, scene_ready: bool) -> void:
	if not _is_mobile_runtime():
		return
	if not _are_controls_active(owner, module_getter, scene_ready):
		return
	var touch_controls: Object = _get_module(module_getter, "mobile_touch_controls")
	if touch_controls != null and touch_controls.has_method("draw"):
		touch_controls.draw(canvas, _get_view_size(owner), _build_layout_context(owner, module_getter))


func _handle_mobile_active_item_touch(
	event: InputEvent,
	owner: Object,
	module_getter: Callable,
	scene_ready: bool
) -> bool:
	if not _is_mobile_runtime() or not _are_controls_active(owner, module_getter, scene_ready):
		return false
	if not (event is InputEventScreenTouch):
		return false
	var touch_event: InputEventScreenTouch = event
	if not touch_event.pressed:
		return false

	var slot_index: int = _get_mobile_active_item_slot_at(touch_event.position, owner, module_getter)
	if slot_index < 0:
		return false

	var active_item_runtime: Object = _get_module(module_getter, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("use_slot"):
		active_item_runtime.use_slot(slot_index, owner, _get_registry(owner))
	_mark_handled(owner)
	return true


func _handle_mobile_touch_controls(
	event: InputEvent,
	owner: Object,
	module_getter: Callable,
	scene_ready: bool
) -> bool:
	var touch_controls: Object = _get_module(module_getter, "mobile_touch_controls")
	if touch_controls == null or not touch_controls.has_method("handle_input"):
		return false
	var handled: bool = bool(touch_controls.handle_input(
		event,
		_get_view_size(owner),
		_are_controls_active(owner, module_getter, scene_ready),
		_build_layout_context(owner, module_getter)
	))
	if handled:
		_mark_handled(owner)
	return handled


func _get_mobile_active_item_slot_at(screen_position: Vector2, owner: Object, module_getter: Callable) -> int:
	var active_item_slots: Array = _get_active_item_slots(owner)
	if active_item_slots.is_empty():
		return -1
	var layout: Dictionary = _build_mobile_active_item_layout(active_item_slots.size(), owner, module_getter)
	if not bool(layout.get("visible", false)):
		return -1

	var slot_rects_value: Variant = layout.get("slot_rects", [])
	if not (slot_rects_value is Array):
		return -1
	var slot_rects: Array = slot_rects_value
	var slot_limit: int = min(active_item_slots.size(), slot_rects.size())
	for i in range(slot_limit):
		var rect_value: Variant = slot_rects[i]
		if not (rect_value is Rect2):
			continue
		var slot_rect: Rect2 = rect_value
		var hit_grace: float = max(
			MOBILE_ACTIVE_ITEM_SLOT_HIT_GRACE_MIN,
			slot_rect.size.x * MOBILE_ACTIVE_ITEM_SLOT_HIT_GRACE_RATIO
		)
		if slot_rect.grow(hit_grace).has_point(screen_position):
			return i
	return -1


func _build_mobile_active_item_layout(item_count: int, owner: Object, module_getter: Callable) -> Dictionary:
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
		_get_active_item_slot_capacity(owner, module_getter, item_count)
	)


func _build_layout_context(owner: Object, module_getter: Callable) -> Dictionary:
	var view_size: Vector2 = _get_view_size(owner)
	var width: float = 760.0
	var height: float = 750.0
	var scene_config: Object = _get_module(module_getter, "battle_scene_config")
	if scene_config != null and scene_config.has_method("build_draw_context"):
		var draw_context: Dictionary = scene_config.build_draw_context()
		width = float(draw_context.get("width", width))
		height = float(draw_context.get("height", height))
	var view_layout: Object = _get_module(module_getter, "battle_view_layout")
	if view_layout != null and view_layout.has_method("build_game_layout"):
		var layout: Dictionary = view_layout.build_game_layout(view_size, width, height)
		layout["field_width"] = width
		layout["field_height"] = height
		layout["mobile_pillar_hud_lifted"] = _is_mobile_runtime()
		return layout
	return {
		"view_size": view_size,
		"game_offset": Vector2.ZERO,
		"game_size": Vector2(width, height),
		"render_scale": 1.0,
		"field_width": width,
		"field_height": height,
		"mobile_pillar_hud_lifted": _is_mobile_runtime(),
	}


func _are_controls_active(_owner: Object, module_getter: Callable, scene_ready: bool) -> bool:
	if not _is_mobile_runtime():
		return false
	if not scene_ready:
		return false
	var modal_gate: Object = _get_module(module_getter, "battle_scene_modal_gate_controller")
	if modal_gate != null and modal_gate.has_method("should_block_mobile_controls") and bool(modal_gate.should_block_mobile_controls(module_getter)):
		return false
	return true


func _get_active_item_slots(owner: Object) -> Array:
	if owner == null:
		return []
	var value: Variant = owner.get("active_item_slots")
	if value is Array:
		return value
	return []


func _get_active_item_slot_capacity(owner: Object, module_getter: Callable, minimum_capacity: int = 0) -> int:
	var capacity: int = max(3, minimum_capacity)
	var runtime_perk_state: Object = _get_module(module_getter, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("get_active_item_slot_capacity"):
		capacity = max(capacity, int(runtime_perk_state.get_active_item_slot_capacity(3)))
	var registry: Object = _get_registry(owner)
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


func _get_registry(owner: Object) -> Object:
	if owner == null:
		return null
	var value: Variant = owner.get("gameplay_modules")
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _get_view_size(owner: Object) -> Vector2:
	if owner != null and owner.has_method("get_viewport_rect"):
		return owner.get_viewport_rect().size
	return Vector2(760.0, 750.0)


func _mark_handled(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
	if owner != null and owner.has_method("get_viewport"):
		owner.get_viewport().set_input_as_handled()


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
