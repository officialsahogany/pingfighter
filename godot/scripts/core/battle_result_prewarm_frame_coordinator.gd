extends RefCounted

const SCOREBOARD_MIN_TIMER: float = 15.0 / 60.0


func update(owner: Object, module_getter: Callable, perf_logger: Object = null) -> void:
	if not _is_safe_result_prewarm_window(module_getter):
		return
	_update_result_texture_prewarm(module_getter, perf_logger)
	if _is_stage_clear_result_prewarm_window(module_getter):
		_update_stage_clear_result_prewarm(owner, module_getter, perf_logger)


func _is_safe_result_prewarm_window(module_getter: Callable) -> bool:
	# Result sheets can finish a threaded load with a large one-frame upload.
	# Keep that work inside the score pause and let the first scoreboard frame
	# render before fallback round-result prewarm begins.
	var scoreboard_state: Object = _get_module(module_getter, "scoreboard_state")
	return (
		scoreboard_state != null
		and scoreboard_state.has_method("is_active")
		and bool(scoreboard_state.is_active())
		and _has_visible_scoreboard_frame(scoreboard_state)
	)


func _has_visible_scoreboard_frame(scoreboard_state: Object) -> bool:
	if scoreboard_state == null or not scoreboard_state.has_method("get_timer"):
		return true
	return float(scoreboard_state.get_timer()) >= SCOREBOARD_MIN_TIMER


func _is_stage_clear_result_prewarm_window(module_getter: Callable) -> bool:
	var scoreboard_state: Object = _get_module(module_getter, "scoreboard_state")
	if (
		scoreboard_state == null
		or not scoreboard_state.has_method("is_active")
		or not bool(scoreboard_state.is_active())
	):
		return false
	if scoreboard_state.has_method("has_pending_game_reset") and not bool(scoreboard_state.has_pending_game_reset()):
		return false
	return _scoreboard_snapshot_is_player_match_win(scoreboard_state)


func _scoreboard_snapshot_is_player_match_win(scoreboard_state: Object) -> bool:
	if (
		scoreboard_state == null
		or not scoreboard_state.has_method("get_player_points")
		or not scoreboard_state.has_method("get_boss_points")
	):
		return false
	var player_points: int = int(scoreboard_state.get_player_points())
	var boss_points: int = int(scoreboard_state.get_boss_points())
	if scoreboard_state.has_method("get_win_goal"):
		var win_goal: int = max(1, int(scoreboard_state.get_win_goal()))
		return player_points >= win_goal and player_points > boss_points
	return player_points > boss_points


func _update_result_texture_prewarm(module_getter: Callable, perf_logger: Object) -> void:
	var resources: Object = _get_module(module_getter, "battle_resources")
	if resources == null or not resources.has_method("update_result_texture_prewarm"):
		return
	if resources.has_method("has_result_texture_prewarm_work") and not bool(resources.has_result_texture_prewarm_work()):
		return
	var sample_start: int = _perf_begin(perf_logger)
	resources.update_result_texture_prewarm()
	_perf_end(perf_logger, "process.frame.result_texture_prewarm", sample_start)


func _update_stage_clear_result_prewarm(owner: Object, module_getter: Callable, perf_logger: Object) -> void:
	var result_screen: Object = _get_module(module_getter, "stage_clear_result_screen")
	if _is_stage_clear_result_active(result_screen):
		return
	var prewarm_controller: Object = _get_module(module_getter, "battle_boot_resource_prewarm_controller")
	if prewarm_controller == null or not prewarm_controller.has_method("prewarm_stage_clear_result_resources_step"):
		return
	if (
		prewarm_controller.has_method("has_stage_clear_result_resource_prewarm_work")
		and not bool(prewarm_controller.has_stage_clear_result_resource_prewarm_work(owner))
	):
		return
	var sample_start: int = _perf_begin(perf_logger)
	prewarm_controller.prewarm_stage_clear_result_resources_step(module_getter, owner)
	_perf_end(perf_logger, "process.frame.stage_clear_result_prewarm", sample_start)


func _is_stage_clear_result_active(result_screen: Object) -> bool:
	return result_screen != null and result_screen.has_method("is_active") and bool(result_screen.is_active())


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
