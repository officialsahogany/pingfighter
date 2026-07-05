extends RefCounted


static func build_context_from_screen(
	finish_flow_handler: Object,
	screen: Object,
	free_result_scene: Callable
) -> Dictionary:
	if screen == null:
		return {}
	if finish_flow_handler == null or not finish_flow_handler.has_method("build_context"):
		return {}
	var context_value: Variant = finish_flow_handler.build_context(
		bool(screen.get("active")),
		_get_screen_callable(screen, "_pending_reset_callback"),
		_get_screen_callable(screen, "_pending_exit_callback"),
		_build_grant_pending_rewards_callback(screen),
		_build_apply_stage_clear_progress_callback(screen),
		_build_mark_finish_inactive_callback(screen),
		free_result_scene,
		_build_free_plaza_scene_callback(screen)
	)
	return context_value if context_value is Dictionary else {}


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


static func _build_mark_finish_inactive_callback(screen: Object) -> Callable:
	var screen_state_handler: Object = _get_screen_object(screen, "_screen_state_handler")
	if screen_state_handler == null or not screen_state_handler.has_method("mark_finish_inactive"):
		return Callable()
	return Callable(screen_state_handler, "mark_finish_inactive").bind(screen)


static func _build_free_plaza_scene_callback(screen: Object) -> Callable:
	var plaza_scene_handler: Object = _get_screen_object(screen, "_plaza_scene_handler")
	if plaza_scene_handler == null or not plaza_scene_handler.has_method("free_scene"):
		return Callable()
	return Callable(plaza_scene_handler, "free_scene")


static func _get_screen_callable(screen: Object, property_name: String) -> Callable:
	if screen == null:
		return Callable()
	var value: Variant = screen.get(property_name)
	return value if value is Callable else Callable()


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
