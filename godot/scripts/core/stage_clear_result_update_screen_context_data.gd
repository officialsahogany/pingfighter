extends RefCounted


static func is_screen_active(screen: Object) -> bool:
	return _get_screen_bool(screen, "active", false)


static func is_spawn_pending(screen: Object) -> bool:
	return _get_screen_bool(screen, "_spawn_pending", false)


static func get_plaza_scene_handler(screen: Object) -> Object:
	return _get_screen_object(screen, "_plaza_scene_handler")


static func has_plaza_scene(plaza_scene_handler: Object) -> bool:
	if plaza_scene_handler == null or not plaza_scene_handler.has_method("has_scene"):
		return false
	return bool(plaza_scene_handler.has_scene())


static func update_plaza_scene(plaza_scene_handler: Object, delta: float) -> void:
	if plaza_scene_handler != null and plaza_scene_handler.has_method("update"):
		plaza_scene_handler.update(delta)


static func update_pending_scene_spawn_from_screen(
	screen: Object,
	starpoint_choice_reward_delay: float
) -> bool:
	var scene_spawn_flow_handler: Object = _get_screen_object(screen, "_scene_spawn_flow_handler")
	if scene_spawn_flow_handler == null or not scene_spawn_flow_handler.has_method("update_pending_scene_spawn_from_screen"):
		return false
	return bool(scene_spawn_flow_handler.update_pending_scene_spawn_from_screen(
		screen,
		_build_prewarm_assets_step_callback_from_screen(screen),
		starpoint_choice_reward_delay,
		Callable(screen, "reset")
	))


static func screen_has_result_scene(screen: Object) -> bool:
	var scene: Control = _get_screen_control(screen, "_scene_node")
	return scene != null and is_instance_valid(scene)


static func build_result_flow_context(screen: Object) -> Dictionary:
	if screen == null:
		return {}
	var owner: Object = _get_screen_object(screen, "_pending_owner")
	var registry: Object = _get_screen_object(screen, "_pending_registry")
	var runtime_context_handler: Object = _get_screen_object(screen, "_runtime_context_handler")
	return {
		"scene": _get_screen_control(screen, "_scene_node"),
		"current_stage": _get_screen_int(screen, "current_stage", 1),
		"owner": owner,
		"registry": registry,
		"selected_character_type": _get_selected_character_type(runtime_context_handler, owner),
		"plaza_scene_handler": _get_screen_object(screen, "_plaza_scene_handler"),
		"mythic_acquisition_handler": _get_screen_object(screen, "_mythic_acquisition_handler"),
		"starpoint_choice_handler": _get_screen_object(screen, "_starpoint_choice_handler"),
	}


static func _build_prewarm_assets_step_callback_from_screen(screen: Object) -> Callable:
	var prewarm_flow_handler: Object = _get_screen_object(screen, "_prewarm_flow_handler")
	if prewarm_flow_handler == null or not prewarm_flow_handler.has_method("build_prewarm_assets_step_callback_from_screen"):
		return Callable()
	var callback_value: Variant = prewarm_flow_handler.build_prewarm_assets_step_callback_from_screen(screen)
	return callback_value if callback_value is Callable else Callable()


static func _get_selected_character_type(runtime_context_handler: Object, owner: Object) -> String:
	if runtime_context_handler == null or not runtime_context_handler.has_method("get_selected_character_type"):
		return "smasher"
	return str(runtime_context_handler.get_selected_character_type(owner))


static func _get_screen_object(screen: Object, property_name: String) -> Object:
	if screen == null:
		return null
	var value: Variant = screen.get(property_name)
	return value if value is Object else null


static func _get_screen_control(screen: Object, property_name: String) -> Control:
	if screen == null:
		return null
	var value: Variant = screen.get(property_name)
	if value is Control:
		return value as Control
	return null


static func _get_screen_int(screen: Object, property_name: String, default_value: int) -> int:
	if screen == null:
		return default_value
	var value: Variant = screen.get(property_name)
	if value == null:
		return default_value
	return int(value)


static func _get_screen_bool(screen: Object, property_name: String, default_value: bool) -> bool:
	if screen == null:
		return default_value
	var value: Variant = screen.get(property_name)
	if value == null:
		return default_value
	return bool(value)
