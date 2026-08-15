extends RefCounted

const StageClearResultPlazaEnterScreenData := preload("res://scripts/core/stage_clear_result_plaza_enter_screen_data.gd")


func finish_enter_plaza(
	active: bool,
	current_stage: int,
	plaza_save_store: Object,
	owner: Object,
	registry: Object,
	selected_character_type: String,
	scene: Control,
	plaza_scene_handler: Object,
	starpoint_choice_handler: Object,
	grant_pending_rewards: Callable,
	apply_stage_clear_progress: Callable,
	mark_spawn_not_pending: Callable,
	free_result_scene: Callable,
	finish_plaza_and_continue: Callable
) -> bool:
	if not active:
		return false
	var plaza_handler_ready := _is_plaza_handler_ready(plaza_scene_handler)
	if not plaza_handler_ready:
		return false
	var plaza_config: Dictionary = plaza_scene_handler.build_scene_config(
		current_stage,
		plaza_save_store,
		owner,
		registry,
		selected_character_type,
		true
	)
	var commit_callbacks := {
		"grant_pending_rewards": grant_pending_rewards,
		"apply_stage_clear_progress": apply_stage_clear_progress,
		"reset_starpoint_choice": _build_reset_starpoint_callback(scene, starpoint_choice_handler),
		"mark_spawn_not_pending": mark_spawn_not_pending,
		"free_result_scene": free_result_scene,
	}
	# First click is consumed by an immediate opaque loading transition. Rewards,
	# result teardown, R3 activation, and R1 retirement are deferred until the
	# same atomic commit boundary after CPU+GPU prewarm completes. Failure stays
	# on the explicit loading error; it never silently continues past the plaza.
	if not bool(plaza_scene_handler.begin_r3_entry_transition(
		owner,
		plaza_config,
		finish_plaza_and_continue,
		commit_callbacks
	)):
		return false
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
	return true


func finish_enter_plaza_from_screen(
	screen: Object,
	free_result_scene: Callable,
	finish_plaza_and_continue: Callable
) -> bool:
	if screen == null:
		return false
	var context: Dictionary = StageClearResultPlazaEnterScreenData.build_plaza_enter_context_from_screen(screen)
	if context.is_empty():
		return false
	return finish_enter_plaza(
		bool(context.get("active", false)),
		int(context.get("current_stage", 1)),
		context.get("plaza_save_store", null) as Object,
		context.get("owner", null) as Object,
		context.get("registry", null) as Object,
		str(context.get("selected_character_type", "")),
		context.get("scene", null) as Control,
		context.get("plaza_scene_handler", null) as Object,
		context.get("starpoint_choice_handler", null) as Object,
		context.get("grant_pending_rewards", Callable()) as Callable,
		context.get("apply_stage_clear_progress", Callable()) as Callable,
		context.get("mark_spawn_not_pending", Callable()) as Callable,
		free_result_scene,
		finish_plaza_and_continue
	)


func _reset_starpoint_choice(scene: Control, starpoint_choice_handler: Object) -> void:
	if starpoint_choice_handler != null and starpoint_choice_handler.has_method("reset"):
		starpoint_choice_handler.reset(scene)


func _build_reset_starpoint_callback(scene: Control, starpoint_choice_handler: Object) -> Callable:
	if starpoint_choice_handler == null or not starpoint_choice_handler.has_method("reset"):
		return Callable()
	return Callable(starpoint_choice_handler, "reset").bind(scene)


func _is_plaza_handler_ready(plaza_scene_handler: Object) -> bool:
	return (
		plaza_scene_handler != null
		and plaza_scene_handler.has_method("build_scene_config")
		and plaza_scene_handler.has_method("begin_r3_entry_transition")
	)


func _call(callable_value: Callable, args: Array = []) -> Variant:
	if not callable_value.is_valid():
		return null
	return callable_value.callv(args)
