extends RefCounted

const StageClearResultFinishActionData := preload("res://scripts/core/stage_clear_result_finish_action_data.gd")
const StageClearResultFinishScreenContextData := preload("res://scripts/core/stage_clear_result_finish_screen_context_data.gd")

const ACTION_NEXT_STAGE := StageClearResultFinishActionData.ACTION_NEXT_STAGE
const ACTION_PLAZA_CONTINUE := StageClearResultFinishActionData.ACTION_PLAZA_CONTINUE
const ACTION_EXIT_TO_MENU := StageClearResultFinishActionData.ACTION_EXIT_TO_MENU


func build_context(
	active: bool,
	reset_callback: Callable,
	exit_callback: Callable,
	grant_pending_rewards: Callable,
	apply_stage_clear_progress: Callable,
	mark_inactive: Callable,
	free_result_scene: Callable,
	free_plaza_scene: Callable
) -> Dictionary:
	return StageClearResultFinishActionData.build_context(
		active,
		reset_callback,
		exit_callback,
		grant_pending_rewards,
		apply_stage_clear_progress,
		mark_inactive,
		free_result_scene,
		free_plaza_scene
	)


func finish_action(
	action: String,
	active: bool,
	reset_callback: Callable,
	exit_callback: Callable,
	grant_pending_rewards: Callable,
	apply_stage_clear_progress: Callable,
	mark_inactive: Callable,
	free_result_scene: Callable,
	free_plaza_scene: Callable
) -> void:
	var context: Dictionary = build_context(
		active,
		reset_callback,
		exit_callback,
		grant_pending_rewards,
		apply_stage_clear_progress,
		mark_inactive,
		free_result_scene,
		free_plaza_scene
	)
	finish_context_action(action, context)


func finish_context_action(action: String, context: Dictionary) -> void:
	StageClearResultFinishActionData.finish_context_action(action, context)


func finish_action_from_screen(action: String, screen: Object, free_result_scene: Callable) -> void:
	var context: Dictionary = StageClearResultFinishScreenContextData.build_context_from_screen(
		self,
		screen,
		free_result_scene
	)
	if context.is_empty():
		return
	finish_context_action(action, context)


func finish_next_stage(context: Dictionary) -> void:
	StageClearResultFinishActionData.finish_next_stage(context)


func finish_plaza_and_continue(context: Dictionary) -> void:
	StageClearResultFinishActionData.finish_plaza_and_continue(context)


func finish_exit_to_menu(context: Dictionary) -> void:
	StageClearResultFinishActionData.finish_exit_to_menu(context)
