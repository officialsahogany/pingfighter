extends RefCounted


static func build_plaza_enter_context_from_screen(screen: Object) -> Dictionary:
	if screen == null:
		return {}
	var owner: Object = _get_screen_object(screen, "_pending_owner")
	var registry: Object = _get_screen_object(screen, "_pending_registry")
	var runtime_context_handler: Object = _get_screen_object(screen, "_runtime_context_handler")
	return {
		"active": bool(screen.get("active")),
		"current_stage": _get_screen_int(screen, "current_stage", 1),
		"plaza_save_store": _get_screen_object(screen, "_plaza_save_store"),
		"owner": owner,
		"registry": registry,
		"selected_character_type": _get_selected_character_type(runtime_context_handler, owner),
		"scene": _get_screen_control(screen, "_scene_node"),
		"plaza_scene_handler": _get_screen_object(screen, "_plaza_scene_handler"),
		"starpoint_choice_handler": _get_screen_object(screen, "_starpoint_choice_handler"),
		"grant_pending_rewards": _build_grant_pending_rewards_callback(screen),
		"apply_stage_clear_progress": _build_apply_stage_clear_progress_callback(screen),
		"mark_spawn_not_pending": _build_mark_spawn_not_pending_callback(screen),
	}


static func _build_grant_pending_rewards_callback(screen: Object) -> Callable:
	var reward_grant_handler: Object = _get_screen_object(screen, "_reward_grant_handler")
	if reward_grant_handler == null or not reward_grant_handler.has_method("grant_pending_scene_rewards"):
		return Callable()
	return Callable(reward_grant_handler, "grant_pending_scene_rewards").bind(
		_get_screen_control(screen, "_scene_node"),
		_get_screen_object(screen, "_pending_owner"),
		_get_screen_object(screen, "_pending_registry")
	)


static func _build_apply_stage_clear_progress_callback(screen: Object) -> Callable:
	var plaza_progress_handler: Object = _get_screen_object(screen, "_plaza_progress_handler")
	if plaza_progress_handler == null or not plaza_progress_handler.has_method("apply_stage_clear_progress_from_callback"):
		return Callable()
	return Callable(plaza_progress_handler, "apply_stage_clear_progress_from_callback").bind(
		_get_screen_object(screen, "_pending_owner"),
		_get_screen_object(screen, "_plaza_save_store"),
		_get_screen_int(screen, "current_stage", 1)
	)


static func _build_mark_spawn_not_pending_callback(screen: Object) -> Callable:
	var screen_state_handler: Object = _get_screen_object(screen, "_screen_state_handler")
	if screen_state_handler == null or not screen_state_handler.has_method("mark_spawn_not_pending"):
		return Callable()
	return Callable(screen_state_handler, "mark_spawn_not_pending").bind(screen)


static func _get_selected_character_type(runtime_context_handler: Object, owner: Object) -> String:
	if runtime_context_handler != null and runtime_context_handler.has_method("get_selected_character_type"):
		return str(runtime_context_handler.get_selected_character_type(owner))
	return ""


static func _get_screen_control(screen: Object, property_name: String) -> Control:
	var value: Object = _get_screen_object(screen, property_name)
	if value is Control and is_instance_valid(value):
		return value as Control
	return null


static func _get_screen_object(screen: Object, property_name: String) -> Object:
	if screen == null:
		return null
	var value: Variant = screen.get(property_name)
	return value if value is Object else null


static func _get_screen_int(screen: Object, property_name: String, fallback: int) -> int:
	if screen == null:
		return fallback
	var value: Variant = screen.get(property_name)
	if value == null:
		return fallback
	return int(value)
