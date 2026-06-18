extends RefCounted


func update_scoreboard(delta: float, deps: Dictionary, callbacks: Dictionary, config: Dictionary) -> void:
	var scoreboard_state: Object = deps.get("scoreboard_state", null)
	if scoreboard_state == null or not scoreboard_state.has_method("update_scoreboard"):
		return

	var update_result: int = scoreboard_state.update_scoreboard(delta)
	if update_result == int(config.get("update_reset_game", -1)):
		if _call_callback_bool(callbacks, "resolve_match_defeat"):
			return
		if _call_callback_bool(callbacks, "show_stage_clear_result"):
			return
		_call_callback(callbacks, "reset_game")
	elif update_result == int(config.get("update_start_serve", -1)):
		_call_callback(callbacks, "reset_ball")
		var round_state: Object = deps.get("round_state", null)
		if round_state != null and round_state.has_method("prepare_serve_after_scoreboard"):
			round_state.prepare_serve_after_scoreboard()
		_start_stage4_pending_destruction(deps)
		_start_pending_pandora_legacy_selection(deps)


func _call_callback(callbacks: Dictionary, key: String) -> void:
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call()


func _call_callback_bool(callbacks: Dictionary, key: String) -> bool:
	var callback: Callable = callbacks.get(key, Callable())
	if not callback.is_valid():
		return false
	return bool(callback.call())


func _start_pending_pandora_legacy_selection(deps: Dictionary) -> void:
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("start_pending_pandora_legacy_selection"):
		return
	mythic_item_runtime.start_pending_pandora_legacy_selection(
		deps.get("owner", null),
		deps.get("registry", null)
	)


func _start_stage4_pending_destruction(deps: Dictionary) -> void:
	if int(deps.get("current_stage", 1)) != 4:
		return
	var stage4_map_state: Object = deps.get("stage4_map_state", null)
	if stage4_map_state != null and stage4_map_state.has_method("handle_scoreboard_serve_prepare"):
		stage4_map_state.handle_scoreboard_serve_prepare(deps)
