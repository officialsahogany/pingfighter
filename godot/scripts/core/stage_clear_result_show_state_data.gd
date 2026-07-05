extends RefCounted


static func build_show_state(
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
	var snapshot: Dictionary = _get_score_snapshot(runtime_context_handler, registry)
	var player_score: int = int(snapshot.get("player_score", 0))
	var boss_score: int = int(snapshot.get("boss_score", 0))
	if player_score <= boss_score:
		return {"shown": false}

	var current_stage: int = _get_current_stage(runtime_context_handler, owner)
	_reset_stage_for_result(runtime_context_handler, registry, current_stage)
	_reset_handler(reward_grant_handler)
	_reset_handler(plaza_progress_handler)
	if starpoint_choice_handler != null and starpoint_choice_handler.has_method("reset"):
		starpoint_choice_handler.reset(scene_node)
	return {
		"shown": true,
		"player_score": player_score,
		"boss_score": boss_score,
		"current_stage": current_stage,
		"pending_reset_callback": reset_game_callback,
		"pending_exit_callback": exit_to_menu_callback,
		"pending_owner": owner,
		"pending_registry": registry,
		"last_stage_reward_snapshot": _build_stage_reward_snapshot(
			stage_snapshot_builder,
			owner,
			registry,
			current_stage,
			stage_start_snapshot
		),
		"active": true,
		"spawn_pending": true,
	}


static func _get_score_snapshot(runtime_context_handler: Object, registry: Object) -> Dictionary:
	if runtime_context_handler == null or not runtime_context_handler.has_method("get_score_snapshot"):
		return {}
	var snapshot_value: Variant = runtime_context_handler.get_score_snapshot(registry)
	return snapshot_value if snapshot_value is Dictionary else {}


static func _get_current_stage(runtime_context_handler: Object, owner: Object) -> int:
	if runtime_context_handler == null or not runtime_context_handler.has_method("get_current_stage"):
		return 1
	return int(runtime_context_handler.get_current_stage(owner))


static func _reset_stage_for_result(runtime_context_handler: Object, registry: Object, current_stage: int) -> void:
	if runtime_context_handler != null and runtime_context_handler.has_method("reset_stage_for_result"):
		runtime_context_handler.reset_stage_for_result(registry, current_stage)


static func _build_stage_reward_snapshot(
	stage_snapshot_builder: Object,
	owner: Object,
	registry: Object,
	current_stage: int,
	stage_start_snapshot: Dictionary
) -> Dictionary:
	if stage_snapshot_builder == null or not stage_snapshot_builder.has_method("build_stage_reward_snapshot"):
		return {}
	var snapshot_value: Variant = stage_snapshot_builder.build_stage_reward_snapshot(
		owner,
		registry,
		current_stage,
		stage_start_snapshot
	)
	return snapshot_value.duplicate(true) if snapshot_value is Dictionary else {}


static func _reset_handler(handler: Object) -> void:
	if handler != null and handler.has_method("reset"):
		handler.reset()
