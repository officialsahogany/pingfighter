extends RefCounted

const StageClearResultSceneShellSceneData := preload("res://scripts/core/stage_clear_result_scene_shell_scene_data.gd")
const StageClearResultSceneShellPrewarmState := preload("res://scripts/core/stage_clear_result_scene_shell_prewarm_state.gd")

const RESULT_SCENE_PATH := "res://scenes/stage_clear_result.tscn"

var _result_scene_packed: PackedScene
var _prewarm_state: Object = StageClearResultSceneShellPrewarmState.new()


func get_scene_path() -> String:
	return RESULT_SCENE_PATH


func get_prewarm_status() -> Dictionary:
	return _prewarm_state.get_prewarm_status()


func prewarm_scene_shell() -> bool:
	return bool(_prewarm_state.prewarm_scene_shell(_get_result_scene_packed() != null))


func prewarm_assets_step(
	selected_character_type: String,
	stage_id: int,
	use_threaded_texture_loads: bool = false
) -> bool:
	return bool(_prewarm_state.prewarm_assets_step(
		selected_character_type,
		stage_id,
		use_threaded_texture_loads,
		_get_result_scene_packed() != null
	))


func are_assets_ready_for_spawn(selected_character_type: String, stage_id: int) -> bool:
	return bool(_prewarm_state.are_assets_ready_for_spawn(selected_character_type, stage_id))


func get_required_scene_asset_keys(stage_id: int) -> Array[String]:
	return _prewarm_state.get_required_scene_asset_keys(stage_id)


func build_callbacks(
	next_stage: Callable,
	exit_to_menu: Callable,
	roll_box_reward: Callable,
	grant_immediate_box_reward: Callable,
	enter_plaza: Callable
) -> Dictionary:
	return StageClearResultSceneShellSceneData.build_callbacks(
		next_stage,
		exit_to_menu,
		roll_box_reward,
		grant_immediate_box_reward,
		enter_plaza
	)


func spawn_scene(owner: Object, config: Dictionary, callbacks: Dictionary) -> Control:
	return StageClearResultSceneShellSceneData.spawn_scene(
		owner,
		_get_result_scene_packed(),
		RESULT_SCENE_PATH,
		config,
		callbacks
	)


func free_scene(scene: Control) -> void:
	StageClearResultSceneShellSceneData.free_scene(scene)


func free_screen_result_scene(screen: Object) -> void:
	StageClearResultSceneShellSceneData.free_screen_result_scene(screen)


func _get_result_scene_packed() -> PackedScene:
	if _result_scene_packed != null:
		return _result_scene_packed
	_result_scene_packed = load(RESULT_SCENE_PATH) as PackedScene
	return _result_scene_packed
