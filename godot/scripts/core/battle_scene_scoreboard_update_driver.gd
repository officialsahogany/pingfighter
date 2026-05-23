extends RefCounted

var _pending_update_result := 0


func update_scoreboard_overlay(
	owner: Object,
	registry: Object,
	delta: float,
	frame_callbacks: Dictionary,
	perf_logger: Object = null
) -> void:
	if owner == null or registry == null:
		return
	var sample_start: int = _perf_begin(perf_logger)
	var scoreboard_state: Object = _get_instance(registry, "scoreboard_state")
	var is_scoreboard_active: bool = (
		scoreboard_state != null
		and scoreboard_state.has_method("is_active")
		and bool(scoreboard_state.is_active())
	)
	_perf_end(perf_logger, "process.scoreboard_overlay.active_check", sample_start)
	if not is_scoreboard_active:
		return

	if scoreboard_state.has_method("update_scoreboard"):
		sample_start = _perf_begin(perf_logger)
		var update_result: int = int(scoreboard_state.update_scoreboard(delta))
		_perf_end(perf_logger, "process.scoreboard_overlay.state_update", sample_start)
		if update_result != 0:
			sample_start = _perf_begin(perf_logger)
			_pending_update_result = update_result
			_perf_end(perf_logger, "process.scoreboard_overlay.result_defer", sample_start)
	else:
		sample_start = _perf_begin(perf_logger)
		_call_delta(frame_callbacks, "update_scoreboard", delta)
		_perf_end(perf_logger, "process.scoreboard_overlay.legacy_callback", sample_start)
	sample_start = _perf_begin(perf_logger)
	_call(frame_callbacks, "queue_redraw")
	_perf_end(perf_logger, "process.scoreboard_overlay.queue_redraw", sample_start)


func update_scoreboard_visuals(owner: Object, registry: Object, delta: float) -> void:
	if owner == null or registry == null:
		return
	var scoreboard_state: Object = _get_instance(registry, "scoreboard_state")
	if scoreboard_state == null:
		return

	var had_top_mini_sparkle := false
	if scoreboard_state.has_method("get_top_mini_score_sparkle_timer"):
		had_top_mini_sparkle = float(scoreboard_state.get_top_mini_score_sparkle_timer()) > 0.0
	if had_top_mini_sparkle and scoreboard_state.has_method("update_top_mini_sparkle"):
		scoreboard_state.update_top_mini_sparkle(delta)

	if had_top_mini_sparkle or _is_top_mini_deuce_mode(registry):
		_queue_redraw(owner)


func has_pending_scoreboard_result() -> bool:
	return _pending_update_result != 0


func dispatch_pending_scoreboard_result(frame_callbacks: Dictionary, perf_logger: Object = null) -> bool:
	if _pending_update_result == 0:
		return false
	var update_result := _pending_update_result
	_pending_update_result = 0
	var sample_start: int = _perf_begin(perf_logger)
	_call_int(frame_callbacks, "handle_scoreboard_update_result", update_result)
	_perf_end(perf_logger, "physics.scoreboard_overlay.result_callback", sample_start)
	return true


func _call(frame_callbacks: Dictionary, key: String) -> void:
	var callback: Callable = frame_callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call()


func _call_delta(frame_callbacks: Dictionary, key: String, delta: float) -> void:
	var callback: Callable = frame_callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call(delta)


func _call_int(frame_callbacks: Dictionary, key: String, value: int) -> void:
	var callback: Callable = frame_callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call(value)


func _queue_redraw(owner: Object) -> void:
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _is_top_mini_deuce_mode(registry: Object) -> bool:
	var score_state: Object = _get_instance(registry, "match_score_state")
	if score_state == null or not score_state.has_method("get_snapshot"):
		return false
	var score_snapshot: Dictionary = score_state.get_snapshot()
	return bool(score_snapshot.get("deuce_mode", false))


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
