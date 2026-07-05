extends RefCounted

const StageClearResultShowStateData := preload("res://scripts/core/stage_clear_result_show_state_data.gd")
const StageClearResultShowScreenData := preload("res://scripts/core/stage_clear_result_show_screen_data.gd")


func build_show_state(
	owner: Object,
	registry: Object,
	reset_game_callback: Callable,
	exit_to_menu_callback: Callable,
	stage_start_snapshot: Dictionary,
	scene_node: Control,
	runtime_context_handler: Object,
	stage_snapshot_builder: Object,
	reward_grant_handler: Object,
	plaza_progress_handler: Object,
	starpoint_choice_handler: Object
) -> Dictionary:
	return StageClearResultShowStateData.build_show_state(
		owner,
		registry,
		reset_game_callback,
		exit_to_menu_callback,
		stage_start_snapshot,
		scene_node,
		runtime_context_handler,
		stage_snapshot_builder,
		reward_grant_handler,
		plaza_progress_handler,
		starpoint_choice_handler
	)


func show_from_screen(
	screen: Object,
	owner: Object,
	registry: Object,
	reset_game_callback: Callable,
	exit_to_menu_callback: Callable,
	starpoint_choice_reward_delay: float
) -> bool:
	if screen == null:
		return false
	var show_state: Dictionary = StageClearResultShowScreenData.build_show_state_from_screen(
		self,
		screen,
		owner,
		registry,
		reset_game_callback,
		exit_to_menu_callback
	)
	if not bool(show_state.get("shown", false)):
		return false
	return StageClearResultShowScreenData.apply_show_state_and_spawn_from_screen(
		screen,
		owner,
		show_state,
		starpoint_choice_reward_delay
	)
