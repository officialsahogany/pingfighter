extends RefCounted


func apply_show_state(screen: Object, show_state: Dictionary) -> void:
	if screen == null:
		return
	screen.set("player_score", int(show_state.get("player_score", 0)))
	screen.set("boss_score", int(show_state.get("boss_score", 0)))
	screen.set("current_stage", int(show_state.get("current_stage", 1)))
	var reset_callback_value: Variant = show_state.get("pending_reset_callback", Callable())
	var exit_callback_value: Variant = show_state.get("pending_exit_callback", Callable())
	screen.set("_pending_reset_callback", reset_callback_value if reset_callback_value is Callable else Callable())
	screen.set("_pending_exit_callback", exit_callback_value if exit_callback_value is Callable else Callable())
	var owner_value: Variant = show_state.get("pending_owner", null)
	var registry_value: Variant = show_state.get("pending_registry", null)
	screen.set("_pending_owner", owner_value if owner_value is Object else null)
	screen.set("_pending_registry", registry_value if registry_value is Object else null)
	var reward_snapshot_value: Variant = show_state.get("last_stage_reward_snapshot", {})
	screen.set("_last_stage_reward_snapshot", reward_snapshot_value.duplicate(true) if reward_snapshot_value is Dictionary else {})
	screen.set("active", bool(show_state.get("active", false)))
	screen.set("_spawn_pending", bool(show_state.get("spawn_pending", false)))


func apply_spawn_state(screen: Object, spawn_state: Dictionary) -> bool:
	if screen != null:
		screen.set("_spawn_pending", bool(spawn_state.get("spawn_pending", bool(screen.get("_spawn_pending")))))
	return bool(spawn_state.get("shown", true))


func reset_screen_state(
	screen: Object,
	reward_grant_handler: Object,
	plaza_progress_handler: Object,
	starpoint_choice_handler: Object,
	scene_node: Control,
	free_result_scene: Callable,
	plaza_scene_handler: Object
) -> void:
	if screen == null:
		return
	screen.set("active", false)
	screen.set("player_score", 0)
	screen.set("boss_score", 0)
	screen.set("current_stage", 1)
	screen.set("_pending_reset_callback", Callable())
	screen.set("_pending_exit_callback", Callable())
	screen.set("_pending_owner", null)
	screen.set("_pending_registry", null)
	screen.set("_spawn_pending", false)
	_reset_handler(reward_grant_handler)
	screen.set("_last_stage_reward_snapshot", {})
	_reset_handler(plaza_progress_handler)
	if starpoint_choice_handler != null and starpoint_choice_handler.has_method("reset"):
		starpoint_choice_handler.reset(scene_node)
	_call(free_result_scene)
	_reset_handler(plaza_scene_handler)


func mark_finish_inactive(screen: Object) -> void:
	if screen == null:
		return
	screen.set("active", false)
	screen.set("_pending_reset_callback", Callable())
	screen.set("_pending_exit_callback", Callable())
	screen.set("_pending_owner", null)
	screen.set("_pending_registry", null)
	screen.set("_spawn_pending", false)


func mark_spawn_not_pending(screen: Object) -> void:
	if screen != null:
		screen.set("_spawn_pending", false)


func _reset_handler(handler: Object) -> void:
	if handler != null and handler.has_method("reset"):
		handler.reset()


func _call(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()
