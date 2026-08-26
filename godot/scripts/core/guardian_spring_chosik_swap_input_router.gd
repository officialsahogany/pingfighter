extends RefCounted

const HOST_KEY := "guardian_spring_chosik_swap_overlay_host"


func is_active(module_getter: Callable) -> bool:
	var modal_gate := _get_module(module_getter, "battle_scene_modal_gate_controller")
	return (
		modal_gate != null
		and (
			(
				modal_gate.has_method("is_guardian_spring_confirmation_active")
				and bool(modal_gate.call(
					"is_guardian_spring_confirmation_active",
					module_getter
				))
			)
			or (
				modal_gate.has_method("is_guardian_spring_chosik_swap_active")
				and bool(modal_gate.call(
					"is_guardian_spring_chosik_swap_active",
					module_getter
				))
			)
		)
	)


func handle_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2
) -> bool:
	var flow_owner := _get_module(module_getter, "tower_ascent_flow_owner")
	if (
		flow_owner != null
		and flow_owner.has_method("has_pending_guardian_spring_confirmation")
		and bool(flow_owner.call("has_pending_guardian_spring_confirmation"))
	):
		var confirmation_handled := bool(flow_owner.call(
			"handle_guardian_spring_confirmation_input",
			event,
			view_size
		))
		if confirmation_handled:
			_queue_redraw(owner)
			_mark_handled(owner)
		return confirmation_handled
	var runtime_perk_state := _get_module(module_getter, "runtime_perk_state")
	var overlay_host := _get_registry_instance(registry, HOST_KEY)
	if overlay_host == null or not overlay_host.has_method("handle_input"):
		return false
	var handled := bool(overlay_host.call(
		"handle_input",
		event,
		flow_owner,
		runtime_perk_state,
		owner,
		registry,
		view_size
	))
	if handled:
		_queue_redraw(owner)
		_mark_handled(owner)
	return handled


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
		value = registry.call("get_cached_instance", key)
	if (typeof(value) != TYPE_OBJECT or value == null) and registry.has_method("get_instance"):
		value = registry.call("get_instance", key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _queue_redraw(owner: Object) -> void:
	if owner == null:
		return
	if owner.has_method("request_battle_redraw"):
		owner.call("request_battle_redraw")
	elif owner.has_method("queue_redraw"):
		owner.call("queue_redraw")


func _mark_handled(owner: Object) -> void:
	if owner == null or not owner.has_method("get_viewport"):
		return
	var viewport: Viewport = owner.call("get_viewport")
	if viewport != null:
		viewport.set_input_as_handled()
