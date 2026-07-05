extends RefCounted

const StageClearResultFinishFlowHandler := preload("res://scripts/core/stage_clear_result_finish_flow_handler.gd")


static func build_result_scene_callbacks(
	scene_shell_handler: Object,
	next_stage: Callable,
	exit_to_menu: Callable,
	roll_box_reward: Callable,
	grant_immediate_box_reward: Callable,
	enter_plaza: Callable
) -> Dictionary:
	if scene_shell_handler == null or not scene_shell_handler.has_method("build_callbacks"):
		return {}
	var callbacks_value: Variant = scene_shell_handler.build_callbacks(
		next_stage,
		exit_to_menu,
		roll_box_reward,
		grant_immediate_box_reward,
		enter_plaza
	)
	return callbacks_value.duplicate(true) if callbacks_value is Dictionary else {}


static func build_roll_box_reward_callback(
	screen: Object,
	pending_owner: Object,
	pending_registry: Object
) -> Callable:
	var reward_grant_handler: Object = _get_screen_object(screen, "_reward_grant_handler")
	if reward_grant_handler == null or not reward_grant_handler.has_method("roll_box_reward"):
		return Callable()
	return Callable(reward_grant_handler, "roll_box_reward").bind(pending_owner, pending_registry)


static func build_spawn_result_scene_callback(
	spawn_flow_handler: Object,
	screen: Object,
	starpoint_choice_reward_delay: float
) -> Callable:
	if spawn_flow_handler == null or not spawn_flow_handler.has_method("spawn_result_scene_from_screen"):
		return Callable()
	return Callable(spawn_flow_handler, "spawn_result_scene_from_screen").bind(
		screen,
		starpoint_choice_reward_delay
	)


static func build_immediate_reward_callback(
	screen: Object,
	pending_owner: Object,
	pending_registry: Object,
	starpoint_choice_reward_delay: float
) -> Callable:
	var immediate_reward_flow_handler: Object = _get_screen_object(screen, "_immediate_reward_flow_handler")
	if immediate_reward_flow_handler == null or not immediate_reward_flow_handler.has_method("grant_immediate_box_reward_from_screen"):
		return Callable()
	return Callable(immediate_reward_flow_handler, "grant_immediate_box_reward_from_screen").bind(
		screen,
		pending_owner,
		pending_registry,
		_get_screen_object(screen, "_reward_grant_handler"),
		_get_screen_object(screen, "_starpoint_choice_handler"),
		_get_screen_object(screen, "_mythic_acquisition_handler"),
		starpoint_choice_reward_delay
	)


static func build_finish_action_callback(screen: Object, action: String) -> Callable:
	var finish_flow_handler: Object = _get_screen_object(screen, "_finish_flow_handler")
	if finish_flow_handler == null or not finish_flow_handler.has_method("finish_action_from_screen"):
		return Callable()
	return Callable(finish_flow_handler, "finish_action_from_screen").bind(
		action,
		screen,
		build_free_result_scene_callback(screen)
	)


static func build_enter_plaza_callback(screen: Object) -> Callable:
	var plaza_enter_flow_handler: Object = _get_screen_object(screen, "_plaza_enter_flow_handler")
	if plaza_enter_flow_handler == null or not plaza_enter_flow_handler.has_method("finish_enter_plaza_from_screen"):
		return Callable()
	return Callable(plaza_enter_flow_handler, "finish_enter_plaza_from_screen").bind(
		screen,
		build_free_result_scene_callback(screen),
		build_finish_action_callback(screen, StageClearResultFinishFlowHandler.ACTION_PLAZA_CONTINUE)
	)


static func build_free_result_scene_callback(screen: Object) -> Callable:
	var scene_shell_handler: Object = _get_screen_object(screen, "_scene_shell_handler")
	if scene_shell_handler == null or not scene_shell_handler.has_method("free_screen_result_scene"):
		return Callable()
	return Callable(scene_shell_handler, "free_screen_result_scene").bind(screen)


static func _get_screen_object(screen: Object, property_name: String) -> Object:
	if screen == null:
		return null
	var value: Variant = screen.get(property_name)
	return value if value is Object else null
