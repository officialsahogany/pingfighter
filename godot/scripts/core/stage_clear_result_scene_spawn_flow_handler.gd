extends RefCounted

const StageClearResultSceneSpawnCoreData := preload("res://scripts/core/stage_clear_result_scene_spawn_core_data.gd")
const StageClearResultSceneSpawnPendingData := preload("res://scripts/core/stage_clear_result_scene_spawn_pending_data.gd")
const StageClearResultSceneSpawnScreenData := preload("res://scripts/core/stage_clear_result_scene_spawn_screen_data.gd")
const StageClearResultSceneSpawnShellData := preload("res://scripts/core/stage_clear_result_scene_spawn_shell_data.gd")


func prewarm_scene_shell(scene_shell_handler: Object) -> Dictionary:
	return StageClearResultSceneSpawnShellData.prewarm_scene_shell(scene_shell_handler)


func prewarm_assets_step(
	scene_shell_handler: Object,
	selected_character_type: String,
	stage_id: int,
	use_threaded_texture_loads: bool
) -> Dictionary:
	return StageClearResultSceneSpawnShellData.prewarm_assets_step(
		scene_shell_handler,
		selected_character_type,
		stage_id,
		use_threaded_texture_loads
	)


func spawn_result_scene(
	owner: Object,
	current_scene: Control,
	scene_shell_handler: Object,
	scene_config: Dictionary,
	scene_callbacks: Dictionary,
	free_result_scene: Callable
) -> Control:
	return StageClearResultSceneSpawnCoreData.spawn_result_scene(
		owner,
		current_scene,
		scene_shell_handler,
		scene_config,
		scene_callbacks,
		free_result_scene
	)


func spawn_configured_result_scene(
	owner: Object,
	current_scene: Control,
	scene_shell_handler: Object,
	scene_config_builder: Object,
	player_score: int,
	boss_score: int,
	current_stage: int,
	selected_character_type: String,
	reward_plan: Dictionary,
	stage_reward_snapshot: Dictionary,
	runtime_owner: Object,
	runtime_registry: Object,
	next_stage: Callable,
	exit_to_menu: Callable,
	roll_box_reward: Callable,
	grant_immediate_box_reward: Callable,
	enter_plaza: Callable,
	free_result_scene: Callable
) -> Control:
	return StageClearResultSceneSpawnCoreData.spawn_configured_result_scene(
		owner,
		current_scene,
		scene_shell_handler,
		scene_config_builder,
		player_score,
		boss_score,
		current_stage,
		selected_character_type,
		reward_plan,
		stage_reward_snapshot,
		runtime_owner,
		runtime_registry,
		next_stage,
		exit_to_menu,
		roll_box_reward,
		grant_immediate_box_reward,
		enter_plaza,
		free_result_scene
	)


func spawn_result_scene_from_screen(
	owner: Object,
	screen: Object,
	starpoint_choice_reward_delay: float
) -> bool:
	return StageClearResultSceneSpawnScreenData.spawn_result_scene_from_screen(
		self,
		owner,
		screen,
		starpoint_choice_reward_delay
	)


func start_show_scene_spawn_from_screen(
	screen: Object,
	owner: Object,
	starpoint_choice_reward_delay: float,
	reset: Callable
) -> Dictionary:
	return StageClearResultSceneSpawnScreenData.start_show_scene_spawn_from_screen(
		self,
		screen,
		owner,
		starpoint_choice_reward_delay,
		reset
	)


func update_pending_scene_spawn_from_screen(
	screen: Object,
	prewarm_assets_step: Callable,
	starpoint_choice_reward_delay: float,
	reset: Callable
) -> bool:
	return StageClearResultSceneSpawnScreenData.update_pending_scene_spawn_from_screen(
		self,
		screen,
		prewarm_assets_step,
		starpoint_choice_reward_delay,
		reset
	)


func update_pending_scene_spawn(
	spawn_pending: bool,
	owner: Object,
	registry: Object,
	prewarm_assets_step: Callable,
	spawn_result_scene: Callable,
	reset: Callable
) -> bool:
	return StageClearResultSceneSpawnPendingData.update_pending_scene_spawn(
		spawn_pending,
		owner,
		registry,
		prewarm_assets_step,
		spawn_result_scene,
		reset
	)


func start_show_scene_spawn(
	owner: Object,
	scene_shell_handler: Object,
	selected_character_type: String,
	stage_id: int,
	spawn_result_scene: Callable,
	reset: Callable
) -> Dictionary:
	return StageClearResultSceneSpawnPendingData.start_show_scene_spawn(
		owner,
		scene_shell_handler,
		selected_character_type,
		stage_id,
		spawn_result_scene,
		reset
	)


func are_assets_ready_for_spawn(
	scene_shell_handler: Object,
	selected_character_type: String,
	stage_id: int
) -> bool:
	return StageClearResultSceneSpawnShellData.are_assets_ready_for_spawn(
		scene_shell_handler,
		selected_character_type,
		stage_id
	)


func get_required_scene_asset_keys(scene_shell_handler: Object, stage_id: int) -> Array[String]:
	return StageClearResultSceneSpawnShellData.get_required_scene_asset_keys(
		scene_shell_handler,
		stage_id
	)


func get_prewarm_status(scene_shell_handler: Object) -> Dictionary:
	return StageClearResultSceneSpawnShellData.get_prewarm_status(scene_shell_handler)
