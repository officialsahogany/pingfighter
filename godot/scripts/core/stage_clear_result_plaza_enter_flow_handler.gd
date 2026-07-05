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
) -> void:
	if not active:
		return
	_call(grant_pending_rewards)
	_call(apply_stage_clear_progress, [true])
	_reset_starpoint_choice(scene, starpoint_choice_handler)
	_call(mark_spawn_not_pending)
	_call(free_result_scene)
	if not _is_plaza_handler_ready(plaza_scene_handler):
		_call(finish_plaza_and_continue)
		return
	if not bool(plaza_scene_handler.ensure_assets_ready(current_stage)):
		_call(finish_plaza_and_continue)
		return
	var plaza_config: Dictionary = plaza_scene_handler.build_scene_config(
		current_stage,
		plaza_save_store,
		owner,
		registry,
		selected_character_type,
		true
	)
	if not bool(plaza_scene_handler.spawn_scene(owner, plaza_config, finish_plaza_and_continue)):
		_call(finish_plaza_and_continue)
		return
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func finish_enter_plaza_from_screen(
	screen: Object,
	free_result_scene: Callable,
	finish_plaza_and_continue: Callable
) -> void:
	if screen == null:
		return
	var context: Dictionary = StageClearResultPlazaEnterScreenData.build_plaza_enter_context_from_screen(screen)
	if context.is_empty():
		return
	finish_enter_plaza(
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


func _is_plaza_handler_ready(plaza_scene_handler: Object) -> bool:
	return (
		plaza_scene_handler != null
		and plaza_scene_handler.has_method("ensure_assets_ready")
		and plaza_scene_handler.has_method("build_scene_config")
		and plaza_scene_handler.has_method("spawn_scene")
	)


func _call(callable_value: Callable, args: Array = []) -> Variant:
	if not callable_value.is_valid():
		return null
	return callable_value.callv(args)
