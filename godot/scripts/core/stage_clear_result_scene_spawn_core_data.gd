extends RefCounted

const StageClearResultSceneSpawnCallbackData := preload("res://scripts/core/stage_clear_result_scene_spawn_callback_data.gd")
const StageClearResultSceneSpawnConfigData := preload("res://scripts/core/stage_clear_result_scene_spawn_config_data.gd")


static func spawn_result_scene(
	owner: Object,
	current_scene: Control,
	scene_shell_handler: Object,
	scene_config: Dictionary,
	scene_callbacks: Dictionary,
	free_result_scene: Callable
) -> Control:
	if not (owner is Node):
		return null
	if current_scene != null and is_instance_valid(current_scene):
		_call(free_result_scene)
	if scene_shell_handler == null or not scene_shell_handler.has_method("spawn_scene"):
		return null
	var scene_value: Variant = scene_shell_handler.spawn_scene(owner, scene_config, scene_callbacks)
	return scene_value if scene_value is Control else null


static func spawn_configured_result_scene(
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
	return spawn_result_scene(
		owner,
		current_scene,
		scene_shell_handler,
		StageClearResultSceneSpawnConfigData.build_result_scene_config(
			scene_config_builder,
			player_score,
			boss_score,
			current_stage,
			selected_character_type,
			reward_plan,
			stage_reward_snapshot,
			runtime_owner,
			runtime_registry
		),
		StageClearResultSceneSpawnCallbackData.build_result_scene_callbacks(
			scene_shell_handler,
			next_stage,
			exit_to_menu,
			roll_box_reward,
			grant_immediate_box_reward,
			enter_plaza
		),
		free_result_scene
	)


static func _call(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()
