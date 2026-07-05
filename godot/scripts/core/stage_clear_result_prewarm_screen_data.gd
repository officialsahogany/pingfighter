extends RefCounted


static func prewarm_assets_from_screen(
	prewarm_flow_handler: Object,
	owner: Object,
	registry: Object,
	screen: Object
) -> Dictionary:
	if prewarm_flow_handler == null or not prewarm_flow_handler.has_method("prewarm_assets"):
		return {}
	if screen == null:
		_clear_prewarm_status(prewarm_flow_handler)
		return {}
	var callback: Callable = build_prewarm_assets_step_callback_from_screen(
		prewarm_flow_handler,
		screen,
		false
	)
	return prewarm_flow_handler.prewarm_assets(owner, registry, callback)


static func prewarm_scene_shell_from_screen(prewarm_flow_handler: Object, screen: Object) -> bool:
	if screen == null:
		_clear_prewarm_status(prewarm_flow_handler)
		return false
	if prewarm_flow_handler == null or not prewarm_flow_handler.has_method("prewarm_scene_shell"):
		return false
	return bool(prewarm_flow_handler.prewarm_scene_shell(
		_get_screen_object(screen, "_scene_spawn_flow_handler"),
		_get_screen_object(screen, "_scene_shell_handler")
	))


static func build_prewarm_assets_step_context_from_screen(screen: Object) -> Dictionary:
	if screen == null:
		return {}
	return {
		"fallback_owner": _get_screen_object(screen, "_pending_owner"),
		"fallback_stage": _get_screen_int(screen, "current_stage", 1),
		"scene_spawn_flow_handler": _get_screen_object(screen, "_scene_spawn_flow_handler"),
		"scene_shell_handler": _get_screen_object(screen, "_scene_shell_handler"),
		"runtime_context_handler": _get_screen_object(screen, "_runtime_context_handler"),
	}


static func build_prewarm_assets_step_callback_from_screen(
	prewarm_flow_handler: Object,
	screen: Object,
	use_threaded_texture_loads: bool = false
) -> Callable:
	if prewarm_flow_handler == null or not prewarm_flow_handler.has_method("prewarm_assets_step_from_screen"):
		return Callable()
	return Callable(prewarm_flow_handler, "prewarm_assets_step_from_screen").bind(
		screen,
		use_threaded_texture_loads
	)


static func _clear_prewarm_status(prewarm_flow_handler: Object) -> void:
	if prewarm_flow_handler != null and prewarm_flow_handler.has_method("clear_prewarm_status"):
		prewarm_flow_handler.clear_prewarm_status()


static func _get_screen_object(screen: Object, property_name: String) -> Object:
	if screen == null:
		return null
	var value: Variant = screen.get(property_name)
	return value if value is Object else null


static func _get_screen_int(screen: Object, property_name: String, default_value: int) -> int:
	if screen == null:
		return default_value
	var value: Variant = screen.get(property_name)
	if value == null:
		return default_value
	return int(value)
