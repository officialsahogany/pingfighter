extends RefCounted

const StageClearResultFinishFlowHandler := preload("res://scripts/core/stage_clear_result_finish_flow_handler.gd")
const StageClearResultSceneSpawnCallbackData := preload("res://scripts/core/stage_clear_result_scene_spawn_callback_data.gd")
const StageClearResultSceneSpawnConfigData := preload("res://scripts/core/stage_clear_result_scene_spawn_config_data.gd")
const StageClearResultSceneSpawnScreenPendingData := preload("res://scripts/core/stage_clear_result_scene_spawn_screen_pending_data.gd")


static func spawn_result_scene_from_screen(
	spawn_flow_handler: Object,
	owner: Object,
	screen: Object,
	starpoint_choice_reward_delay: float
) -> bool:
	if screen == null:
		return false
	if spawn_flow_handler == null or not spawn_flow_handler.has_method("spawn_configured_result_scene"):
		return false
	var pending_owner: Object = StageClearResultSceneSpawnConfigData.get_screen_object(screen, "_pending_owner")
	var pending_registry: Object = StageClearResultSceneSpawnConfigData.get_screen_object(screen, "_pending_registry")
	var free_result_scene: Callable = StageClearResultSceneSpawnCallbackData.build_free_result_scene_callback(screen)
	var scene: Control = spawn_flow_handler.spawn_configured_result_scene(
		owner,
		StageClearResultSceneSpawnConfigData.get_screen_control(screen, "_scene_node"),
		StageClearResultSceneSpawnConfigData.get_screen_object(screen, "_scene_shell_handler"),
		StageClearResultSceneSpawnConfigData.get_screen_object(screen, "_scene_config_builder"),
		StageClearResultSceneSpawnConfigData.get_screen_int(screen, "player_score", 0),
		StageClearResultSceneSpawnConfigData.get_screen_int(screen, "boss_score", 0),
		StageClearResultSceneSpawnConfigData.get_screen_int(screen, "current_stage", 1),
		StageClearResultSceneSpawnConfigData.get_result_victory_character_type(
			StageClearResultSceneSpawnConfigData.get_screen_object(screen, "_runtime_context_handler"),
			pending_owner
		),
		StageClearResultSceneSpawnConfigData.get_screen_reward_plan(screen),
		StageClearResultSceneSpawnConfigData.get_screen_dictionary(screen, "_last_stage_reward_snapshot"),
		pending_owner,
		pending_registry,
		StageClearResultSceneSpawnCallbackData.build_finish_action_callback(
			screen,
			StageClearResultFinishFlowHandler.ACTION_NEXT_STAGE
		),
		StageClearResultSceneSpawnCallbackData.build_finish_action_callback(
			screen,
			StageClearResultFinishFlowHandler.ACTION_EXIT_TO_MENU
		),
		StageClearResultSceneSpawnCallbackData.build_roll_box_reward_callback(
			screen,
			pending_owner,
			pending_registry
		),
		StageClearResultSceneSpawnCallbackData.build_immediate_reward_callback(
			screen,
			pending_owner,
			pending_registry,
			starpoint_choice_reward_delay
		),
		StageClearResultSceneSpawnCallbackData.build_enter_plaza_callback(screen),
		free_result_scene
	)
	screen.set("_scene_node", scene)
	return scene != null and is_instance_valid(scene)


static func start_show_scene_spawn_from_screen(
	spawn_flow_handler: Object,
	screen: Object,
	owner: Object,
	starpoint_choice_reward_delay: float,
	reset: Callable
) -> Dictionary:
	return StageClearResultSceneSpawnScreenPendingData.start_show_scene_spawn_from_screen(
		spawn_flow_handler,
		screen,
		owner,
		starpoint_choice_reward_delay,
		reset
	)


static func update_pending_scene_spawn_from_screen(
	spawn_flow_handler: Object,
	screen: Object,
	prewarm_assets_step: Callable,
	starpoint_choice_reward_delay: float,
	reset: Callable
) -> bool:
	return StageClearResultSceneSpawnScreenPendingData.update_pending_scene_spawn_from_screen(
		spawn_flow_handler,
		screen,
		prewarm_assets_step,
		starpoint_choice_reward_delay,
		reset
	)
