extends RefCounted

var _session: Object = null
var _input_collector: Object = null
var _renderer: Object = null
var _view_layout: Object = null
var _started := false
var _startup_checked := false
var _local_ready_sent := false
var _takeover_cleanup_done := false
var _last_start_error := OK
var _startup_failed := false
var _startup_failure_message := ""


func process_idle(
	delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	callbacks: Dictionary
) -> bool:
	_ensure_started(registry, module_getter)
	if not is_active():
		return false
	if _startup_failed:
		_request_redraw(owner)
		return _is_battle_initialized(callbacks)
	_session.poll_transport()
	_session.advance_idle(delta)
	if _is_battle_initialized(callbacks):
		_ensure_online_takeover_cleanup(owner, module_getter)
	if _is_battle_initialized(callbacks) and not _local_ready_sent:
		_local_ready_sent = true
		_session.mark_local_ready()
	_request_redraw(owner)
	return _is_battle_initialized(callbacks)


func process_physics(
	delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	callbacks: Dictionary
) -> bool:
	_ensure_started(registry, module_getter)
	if not is_active() or not _is_battle_initialized(callbacks):
		return false
	if _startup_failed:
		_request_redraw(owner)
		return true
	_session.poll_transport()
	var input_frame: Dictionary = _input_collector.collect(_session.next_input_tick())
	_session.process_simulation_tick(delta, input_frame)
	_sync_battle_compatibility_projection(owner)
	_play_pending_events(registry)
	_request_redraw(owner)
	return true


func draw(canvas: CanvasItem, _registry: Object, view_size: Vector2, callbacks: Dictionary) -> bool:
	if not is_active() or not _is_battle_initialized(callbacks):
		return false
	if _startup_failed:
		_draw_startup_failure(canvas, view_size)
		return true
	if _renderer != null:
		_renderer.draw(canvas, _session, _view_layout, view_size)
	return true


func is_active() -> bool:
	return _startup_failed or (
		_session != null
		and _session.has_method("is_active")
		and bool(_session.is_active())
	)


func stop() -> void:
	if _session != null and _session.has_method("stop"):
		_session.stop(_view_layout)
	if _input_collector != null and _input_collector.has_method("reset"):
		_input_collector.reset()
	_session = null
	_input_collector = null
	_renderer = null
	_view_layout = null
	_started = false
	_startup_checked = false
	_local_ready_sent = false
	_takeover_cleanup_done = false
	_last_start_error = OK
	if _startup_failed:
		var selection_state := _get_game_selection_state()
		if selection_state != null and selection_state.has_method("cancel_online_match_request"):
			selection_state.cancel_online_match_request()
	_startup_failed = false
	_startup_failure_message = ""


func _ensure_started(_registry: Object, module_getter: Callable) -> void:
	if _started or _startup_checked:
		return
	var selection_state := _get_game_selection_state()
	if selection_state == null or not selection_state.has_method("has_pending_online_match_request"):
		return
	if not bool(selection_state.has_pending_online_match_request()):
		# Online requests are armed before the production battle scene loads. An
		# offline scene therefore needs only one read-only autoload lookup, not a
		# pair of lookups on every rendered/physics frame.
		_startup_checked = true
		return
	_startup_checked = true
	_session = _get_module(module_getter, "online_match_session")
	var transport: Object = _get_module(module_getter, "online_enet_transport")
	var simulation: Object = _get_module(module_getter, "online_match_simulation")
	_input_collector = _get_module(module_getter, "online_match_input_collector")
	_renderer = _get_module(module_getter, "online_match_renderer")
	_view_layout = _get_module(module_getter, "battle_view_layout")
	var score_state: Object = _get_module(module_getter, "match_score_state")
	var round_state: Object = _get_module(module_getter, "round_flow_state")
	var missing_modules: Array[String] = []
	for entry in [
		["online_match_session", _session],
		["online_enet_transport", transport],
		["online_match_simulation", simulation],
		["online_match_input_collector", _input_collector],
		["online_match_renderer", _renderer],
		["battle_view_layout", _view_layout],
		["match_score_state", score_state],
		["round_flow_state", round_state],
	]:
		if entry[1] == null:
			missing_modules.append(str(entry[0]))
	if not missing_modules.is_empty():
		_startup_failed = true
		_started = true
		_startup_failure_message = "온라인 필수 모듈 누락: %s" % ", ".join(PackedStringArray(missing_modules))
		if _session != null and _session.has_method("enter_startup_error"):
			_session.enter_startup_error(_startup_failure_message, _view_layout)
		return
	var request: Dictionary = selection_state.consume_online_match_request()
	simulation.configure(score_state, round_state)
	_last_start_error = int(_session.begin(request, transport, simulation, _view_layout))
	_started = true


func _draw_startup_failure(canvas: CanvasItem, view_size: Vector2) -> void:
	if canvas == null:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.012, 0.018, 0.035, 1.0))
	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(0.0, view_size.y * 0.5),
		_startup_failure_message,
		HORIZONTAL_ALIGNMENT_CENTER,
		view_size.x,
		24,
		Color(1.0, 0.72, 0.72)
	)


func _sync_battle_compatibility_projection(owner: Object) -> void:
	if owner == null or _session == null:
		return
	var simulation: Object = _session.get_simulation()
	if simulation == null:
		return
	# Online owners stay canonical. These fields are a read-only compatibility
	# projection for shared diagnostics and teardown; normal battle code is gated.
	owner.set("ball_pos_prev", owner.get("ball_pos"))
	owner.set("ball_pos", simulation.ball_pos)
	owner.set("ball_vel", simulation.ball_vel)
	owner.set("ball_active", simulation.ball_active)
	owner.set("player_pos", simulation.host_paddle.position if _session.is_host() else simulation.client_paddle.position)
	owner.set("player_speed", simulation.host_paddle.velocity_x if _session.is_host() else simulation.client_paddle.velocity_x)
	owner.set("player_paddle_width", 155.0)
	owner.set("player_paddle_height", 50.0)


func _play_pending_events(registry: Object) -> void:
	if _session == null:
		return
	var audio: Object = registry.get_instance("game_audio") if registry != null and registry.has_method("get_instance") else null
	for event in _session.drain_local_events():
		if audio == null:
			continue
		var kind := str(event.get("kind", ""))
		match kind:
			"dash":
				if audio.has_method("play_dash_start"):
					audio.play_dash_start(bool(event.get("half_dash", false)))
			"serve":
				if audio.has_method("play_serve"):
					audio.play_serve()
			"paddle":
				if audio.has_method("play_paddle_hit"):
					audio.play_paddle_hit(float(event.get("source_x", 380.0)))
			"wall":
				if audio.has_method("play_wall_hit"):
					audio.play_wall_hit(float(event.get("speed", 0.0)), float(event.get("source_x", 380.0)))
			"score", "round_reset":
				if audio.has_method("play_round_set"):
					audio.play_round_set()
			"match_finished":
				if _session.winner_side == _session.role and audio.has_method("play_round_victory"):
					audio.play_round_victory()
				elif audio.has_method("play_round_defeat"):
					audio.play_round_defeat()


func _ensure_online_takeover_cleanup(owner: Object, module_getter: Callable) -> void:
	if _takeover_cleanup_done:
		return
	_takeover_cleanup_done = true
	var loading_renderer: Object = _get_module(module_getter, "battle_loading_screen_renderer")
	if loading_renderer == null:
		return
	if loading_renderer.has_method("hide_loading"):
		loading_renderer.hide_loading()
	if loading_renderer.has_method("release_stained_glass_hosts"):
		loading_renderer.release_stained_glass_hosts(owner)


func _is_battle_initialized(callbacks: Dictionary) -> bool:
	var callback: Callable = callbacks.get("is_battle_initialized", Callable())
	return callback.is_valid() and bool(callback.call())


func _request_redraw(owner: Object) -> void:
	if owner == null:
		return
	if owner.has_method("request_battle_redraw"):
		owner.request_battle_redraw()


func _get_game_selection_state() -> Object:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		return null
	var root: Window = (main_loop as SceneTree).root
	return root.get_node_or_null("GameSelectionState") if root != null else null


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	return value as Object if typeof(value) == TYPE_OBJECT and is_instance_valid(value) else null
