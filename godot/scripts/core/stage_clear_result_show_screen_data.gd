extends RefCounted


static func build_show_state_from_screen(
	show_flow_handler: Object,
	screen: Object,
	owner: Object,
	registry: Object,
	reset_game_callback: Callable,
	exit_to_menu_callback: Callable
) -> Dictionary:
	if screen == null:
		return {}
	if show_flow_handler == null or not show_flow_handler.has_method("build_show_state"):
		return {}
	var show_state_value: Variant = show_flow_handler.build_show_state(
		owner,
		registry,
		reset_game_callback,
		exit_to_menu_callback,
		_get_screen_dictionary(screen, "_stage_start_snapshot"),
		_get_screen_control(screen, "_scene_node"),
		_get_screen_object(screen, "_runtime_context_handler"),
		_get_screen_object(screen, "_stage_snapshot_builder"),
		_get_screen_object(screen, "_reward_grant_handler"),
		_get_screen_object(screen, "_plaza_progress_handler"),
		_get_screen_object(screen, "_starpoint_choice_handler")
	)
	return show_state_value if show_state_value is Dictionary else {}


static func apply_show_state_and_spawn_from_screen(
	screen: Object,
	owner: Object,
	show_state: Dictionary,
	starpoint_choice_reward_delay: float
) -> bool:
	var screen_state_handler: Object = _get_screen_object(screen, "_screen_state_handler")
	if screen_state_handler == null or not screen_state_handler.has_method("apply_show_state"):
		return false
	screen_state_handler.apply_show_state(screen, show_state)
	var scene_spawn_flow_handler: Object = _get_screen_object(screen, "_scene_spawn_flow_handler")
	if scene_spawn_flow_handler == null or not scene_spawn_flow_handler.has_method("start_show_scene_spawn_from_screen"):
		return false
	var spawn_state: Dictionary = scene_spawn_flow_handler.start_show_scene_spawn_from_screen(
		screen,
		owner,
		starpoint_choice_reward_delay,
		Callable(screen, "reset")
	)
	if screen_state_handler.has_method("apply_spawn_state"):
		return bool(screen_state_handler.apply_spawn_state(screen, spawn_state))
	return bool(spawn_state.get("shown", false))


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


static func _get_screen_dictionary(screen: Object, property_name: String) -> Dictionary:
	if screen == null:
		return {}
	var value: Variant = screen.get(property_name)
	return value.duplicate(true) if value is Dictionary else {}
