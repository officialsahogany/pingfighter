extends RefCounted

const StageClearResultSceneSpawnCallbackData := preload("res://scripts/core/stage_clear_result_scene_spawn_callback_data.gd")
const StageClearResultSceneSpawnConfigData := preload("res://scripts/core/stage_clear_result_scene_spawn_config_data.gd")


static func start_show_scene_spawn_from_screen(
	spawn_flow_handler: Object,
	screen: Object,
	owner: Object,
	starpoint_choice_reward_delay: float,
	reset: Callable
) -> Dictionary:
	if screen == null:
		return {
			"shown": false,
			"spawn_pending": false,
		}
	if spawn_flow_handler == null or not spawn_flow_handler.has_method("start_show_scene_spawn"):
		return {
			"shown": false,
			"spawn_pending": false,
		}
	var pending_owner: Object = StageClearResultSceneSpawnConfigData.get_screen_object(screen, "_pending_owner")
	var runtime_context_handler: Object = StageClearResultSceneSpawnConfigData.get_screen_object(screen, "_runtime_context_handler")
	return spawn_flow_handler.start_show_scene_spawn(
		owner,
		StageClearResultSceneSpawnConfigData.get_screen_object(screen, "_scene_shell_handler"),
		StageClearResultSceneSpawnConfigData.get_result_victory_character_type(
			runtime_context_handler,
			pending_owner
		),
		StageClearResultSceneSpawnConfigData.get_screen_int(screen, "current_stage", 1),
		StageClearResultSceneSpawnCallbackData.build_spawn_result_scene_callback(
			spawn_flow_handler,
			screen,
			starpoint_choice_reward_delay
		),
		reset
	)


static func update_pending_scene_spawn_from_screen(
	spawn_flow_handler: Object,
	screen: Object,
	prewarm_assets_step: Callable,
	starpoint_choice_reward_delay: float,
	reset: Callable
) -> bool:
	if screen == null:
		return false
	if spawn_flow_handler == null or not spawn_flow_handler.has_method("update_pending_scene_spawn"):
		return false
	return bool(spawn_flow_handler.update_pending_scene_spawn(
		bool(screen.get("_spawn_pending")),
		StageClearResultSceneSpawnConfigData.get_screen_object(screen, "_pending_owner"),
		StageClearResultSceneSpawnConfigData.get_screen_object(screen, "_pending_registry"),
		prewarm_assets_step,
		StageClearResultSceneSpawnCallbackData.build_spawn_result_scene_callback(
			spawn_flow_handler,
			screen,
			starpoint_choice_reward_delay
		),
		reset
	))
