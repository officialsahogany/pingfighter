extends RefCounted

const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")


func handle_score_event(registry: Object, scoring_side: String, reset_ball_callback: Callable) -> void:
	var controller: Object = _get_instance(registry, "match_flow_controller")
	if controller == null:
		return
	controller.handle_score_event(scoring_side, _get_match_flow_deps(registry), {
		"reset_ball": reset_ball_callback,
	})


func update_scoreboard(registry: Object, delta: float, reset_game_callback: Callable) -> void:
	var controller: Object = _get_instance(registry, "match_flow_controller")
	if controller == null:
		return
	controller.update_scoreboard(
		delta,
		_get_match_flow_deps(registry),
		{"reset_game": reset_game_callback},
		{
			"update_reset_game": ScoreboardState.UPDATE_RESET_GAME,
			"update_start_serve": ScoreboardState.UPDATE_START_SERVE,
		}
	)


func reset_game(
	owner: Object,
	registry: Object,
	reset_drive_input_callback: Callable,
	reset_ball_callback: Callable
) -> void:
	var controller: Object = _get_instance(registry, "match_flow_controller")
	if controller == null or owner == null:
		return
	var result: Dictionary = controller.reset_game(_get_match_flow_deps(registry), {
		"reset_drive_input": reset_drive_input_callback,
		"reset_ball": reset_ball_callback,
	})
	owner.set("special_gauge", float(result.get("special_gauge", _get_owner_value(owner, "special_gauge", 0.0))))
	owner.set("drive_text_timer_frames", float(result.get(
		"drive_text_timer_frames",
		_get_owner_value(owner, "drive_text_timer_frames", 0.0)
	)))


func _get_match_flow_deps(registry: Object) -> Dictionary:
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	if context_builder == null:
		return {}
	return context_builder.build_match_flow_deps(registry)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return value
