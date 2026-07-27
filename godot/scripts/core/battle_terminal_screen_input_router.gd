extends RefCounted


func handle_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	if _handle_defeat_chance_gems_continue(event, owner, registry, module_getter):
		return true
	if _handle_defeat_settlement(event, owner, registry, module_getter):
		return true
	return _handle_stage_clear_result(event, owner, registry, module_getter)


func _handle_defeat_chance_gems_continue(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var continue_screen: Object = _get_module(module_getter, "defeat_chance_gems_continue_screen")
	if not _is_active_screen(continue_screen):
		return false
	if continue_screen.has_method("handle_input"):
		if not bool(continue_screen.handle_input(event, owner, registry, _get_view_size(owner))):
			return false
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_defeat_settlement(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var settlement_screen: Object = _get_module(module_getter, "defeat_settlement_screen")
	if not _is_active_screen(settlement_screen):
		return false
	if settlement_screen.has_method("handle_input"):
		settlement_screen.handle_input(event, owner, registry, _get_view_size(owner))
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _handle_stage_clear_result(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var result_screen: Object = _get_module(module_getter, "stage_clear_result_screen")
	if not _is_active_screen(result_screen):
		return false
	if _is_runtime_perk_choice_active(module_getter):
		var overlay_input: Object = _get_module(module_getter, "battle_scene_overlay_input_controller")
		if overlay_input != null and overlay_input.has_method("handle_input"):
			overlay_input.handle_input(event, owner, registry, module_getter, {})
		_queue_redraw(owner)
		_mark_handled(owner)
		return true
	if result_screen.has_method("handle_input"):
		result_screen.handle_input(event, owner, registry, _get_view_size(owner))
	_queue_redraw(owner)
	_mark_handled(owner)
	return true


func _is_active_screen(screen: Object) -> bool:
	return screen != null and screen.has_method("is_active") and bool(screen.is_active())


func _is_runtime_perk_choice_active(module_getter: Callable) -> bool:
	var modal_gate: Object = _get_module(module_getter, "battle_scene_modal_gate_controller")
	return (
		modal_gate != null
		and modal_gate.has_method("is_runtime_perk_choice_active")
		and bool(modal_gate.is_runtime_perk_choice_active(module_getter))
	)


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
