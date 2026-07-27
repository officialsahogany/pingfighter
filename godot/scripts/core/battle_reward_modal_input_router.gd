extends RefCounted


func handle_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	if _handle_mythic_acquisition(event, owner, registry, module_getter):
		return true
	if _handle_pandora_legacy_selection(event, owner, registry, module_getter):
		return true
	return _handle_angel_blessing(event, owner, registry, module_getter)


func _handle_mythic_acquisition(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var mythic_item_runtime: Object = _get_module(module_getter, "mythic_item_runtime")
	if (
		mythic_item_runtime == null
		or not mythic_item_runtime.has_method("is_acquisition_cinematic_active")
		or not bool(mythic_item_runtime.is_acquisition_cinematic_active())
	):
		return false
	if mythic_item_runtime.has_method("handle_acquisition_cinematic_input"):
		mythic_item_runtime.handle_acquisition_cinematic_input(event, registry)
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_pandora_legacy_selection(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var mythic_item_runtime: Object = _get_module(module_getter, "mythic_item_runtime")
	if (
		mythic_item_runtime == null
		or not mythic_item_runtime.has_method("is_pandora_legacy_selection_active")
		or not bool(mythic_item_runtime.is_pandora_legacy_selection_active())
	):
		return false
	if mythic_item_runtime.has_method("handle_pandora_legacy_selection_input"):
		mythic_item_runtime.handle_pandora_legacy_selection_input(
			event,
			owner,
			registry,
			_get_view_size(owner)
		)
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_angel_blessing(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var runtime_perk_state: Object = _get_module(module_getter, "runtime_perk_state")
	if (
		runtime_perk_state == null
		or not runtime_perk_state.has_method("is_angel_blessing_modal_active")
		or not bool(runtime_perk_state.is_angel_blessing_modal_active())
	):
		return false
	if runtime_perk_state.has_method("handle_angel_blessing_input"):
		runtime_perk_state.handle_angel_blessing_input(
			event,
			owner,
			registry,
			_get_view_size(owner)
		)
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _get_view_size(owner: Object) -> Vector2:
	if owner != null and owner.has_method("get_viewport_rect"):
		return owner.get_viewport_rect().size
	if owner != null and owner.has_method("get_viewport"):
		var viewport: Viewport = owner.get_viewport()
		if viewport != null:
			return viewport.get_visible_rect().size
	return Vector2(760.0, 750.0)


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _mark_handled(owner: Object) -> void:
	if owner == null or not owner.has_method("get_viewport"):
		return
	var viewport: Viewport = owner.get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
