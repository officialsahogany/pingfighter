extends RefCounted

const OnlineMatchProtocol := preload("res://scripts/network/online_match_protocol.gd")
const OnlinePaddleState := preload("res://scripts/network/online_paddle_state.gd")

const SIMULATION_HZ := 60
const DEFAULT_SNAPSHOT_HZ := 30
const COUNTDOWN_SECONDS := 3.0
const CONNECT_TIMEOUT_SECONDS := 10.0
const READY_TIMEOUT_SECONDS := 30.0
const CLIENT_INPUT_HISTORY_LIMIT := 240
const CLIENT_CORRECTION_MAX_PX_PER_TICK := 6.0
const FIELD_HEIGHT := 750.0
const PADDLE_HEIGHT := 50.0

var online_match_active := false
var role := "offline"
var match_phase := "offline"
var status_message := "오프라인"
var winner_side := ""

var simulation_tick := 0
var local_input_tick := 0
var snapshot_hz := DEFAULT_SNAPSHOT_HZ
var countdown_remaining := 0.0
var rtt_msec := 0

var _transport: Object = null
var _simulation: Object = null
var _view_layout: Object = null
var _packet_sequence := 0
var _last_snapshot_tick := -1
var _last_remote_input_tick_received := -1
var _last_remote_input_tick_applied := 0
var _remote_input_clock_initialized := false
var _last_remote_dash_edge_tick := -1
var _last_remote_serve_edge_tick := -1
var _last_event_serial := 0
var _last_received_event_serial := 0
var _latest_remote_input: Dictionary = OnlineMatchProtocol.sanitize_input_frame({})
var _client_input_history: Array[Dictionary] = []
var _previous_snapshot: Dictionary = {}
var _current_snapshot: Dictionary = {}
var _snapshot_interpolation_alpha := 1.0
var _snapshot_send_budget := 0
var _client_render_x := OnlinePaddleState.FIELD_WIDTH * 0.5 - OnlinePaddleState.PADDLE_WIDTH * 0.5
var _client_render_initialized := false
var _local_ready := false
var _remote_ready := false
var _handshake_received := false
var _pending_local_events: Array[Dictionary] = []
var _ping_elapsed := 0.0
var _phase_elapsed := 0.0
var _previous_physics_ticks_per_second := 0
var _simulation_tick_lock_acquired := false


func begin(request: Dictionary, transport: Object, simulation: Object, view_layout: Object) -> int:
	stop()
	role = "host" if str(request.get("role", "host")) == "host" else "client"
	snapshot_hz = clampi(int(request.get("snapshot_hz", DEFAULT_SNAPSHOT_HZ)), 1, SIMULATION_HZ)
	_transport = transport
	_simulation = simulation
	_view_layout = view_layout
	_connect_transport_signals()
	_simulation.reset_match()
	_acquire_simulation_tick_lock()
	online_match_active = true
	match_phase = "waiting_peer" if role == "host" else "connecting"
	status_message = "상대 접속 대기 중" if role == "host" else "호스트에 연결 중"
	var port := clampi(int(request.get("port", 24777)), 1, 65535)
	var error := OK
	if role == "host":
		error = int(_transport.start_host(port, str(request.get("bind_ip", "*"))))
	else:
		error = int(_transport.start_client(str(request.get("address", "127.0.0.1")), port))
	if error != OK:
		match_phase = "error"
		status_message = _transport.get_last_error() if _transport.has_method("get_last_error") else "연결 시작 실패"
		_release_simulation_tick_lock(_view_layout)
	return error


func stop(view_layout_override: Object = null) -> void:
	if _transport != null:
		_disconnect_transport_signals()
		if _transport.has_method("close"):
			_transport.close()
	var layout := view_layout_override if view_layout_override != null else _view_layout
	_release_simulation_tick_lock(layout)
	online_match_active = false
	role = "offline"
	match_phase = "offline"
	status_message = "오프라인"
	winner_side = ""
	simulation_tick = 0
	local_input_tick = 0
	countdown_remaining = 0.0
	rtt_msec = 0
	_transport = null
	_simulation = null
	_view_layout = null
	_packet_sequence = 0
	_last_snapshot_tick = -1
	_last_remote_input_tick_received = -1
	_last_remote_input_tick_applied = 0
	_remote_input_clock_initialized = false
	_last_remote_dash_edge_tick = -1
	_last_remote_serve_edge_tick = -1
	_last_event_serial = 0
	_last_received_event_serial = 0
	_latest_remote_input = OnlineMatchProtocol.sanitize_input_frame({})
	_client_input_history.clear()
	_previous_snapshot.clear()
	_current_snapshot.clear()
	_snapshot_interpolation_alpha = 1.0
	_snapshot_send_budget = 0
	_pending_local_events.clear()
	_local_ready = false
	_remote_ready = false
	_handshake_received = false
	_client_render_initialized = false
	_ping_elapsed = 0.0
	_phase_elapsed = 0.0


func enter_startup_error(message: String, view_layout: Object = null) -> void:
	stop(view_layout)
	_view_layout = view_layout
	online_match_active = true
	role = "offline"
	match_phase = "error"
	status_message = message if not message.strip_edges().is_empty() else "온라인 대전 시작 오류"


func poll_transport() -> void:
	if online_match_active and _transport != null and _transport.has_method("poll"):
		_transport.poll()


func advance_idle(delta: float) -> void:
	if not online_match_active:
		return
	_snapshot_interpolation_alpha = minf(
		1.0,
		_snapshot_interpolation_alpha + maxf(0.0, delta) * float(snapshot_hz)
	)
	_advance_phase_timeout(maxf(0.0, delta))
	_ping_elapsed += maxf(0.0, delta)
	if role == "client" and _ping_elapsed >= 1.0 and _has_remote_peer():
		_ping_elapsed = 0.0
		_send_packet(
			OnlineMatchProtocol.KIND_PING,
			{"stamp_msec": Time.get_ticks_msec()},
			false
		)


func mark_local_ready() -> void:
	if not online_match_active or _local_ready:
		return
	_local_ready = true
	if role == "client" and _handshake_received and _has_remote_peer():
		_send_packet(OnlineMatchProtocol.KIND_READY, {"ready": true}, true)
	elif role == "host":
		_try_start_countdown()


func next_input_tick() -> int:
	return local_input_tick + 1


func process_simulation_tick(delta: float, local_input: Dictionary) -> void:
	if not online_match_active or _simulation == null:
		return
	if match_phase == "error" or match_phase == "disconnected":
		return
	local_input_tick += 1
	var clean_local := OnlineMatchProtocol.sanitize_input_frame(local_input)
	clean_local["tick"] = local_input_tick
	if role == "host":
		_process_host_tick(delta, clean_local)
	else:
		_process_client_tick(delta, clean_local)


func drain_local_events() -> Array[Dictionary]:
	var result := _pending_local_events.duplicate(true)
	_pending_local_events.clear()
	return result


func is_active() -> bool:
	return online_match_active


func is_host() -> bool:
	return role == "host"


func get_status_message() -> String:
	return status_message


func get_rtt_msec() -> int:
	return rtt_msec


func get_simulation() -> Object:
	return _simulation


func get_render_state() -> Dictionary:
	if _simulation == null:
		return {}
	var world_state := _build_interpolated_world_state()
	return project_world_state_for_side(world_state, role)


static func project_world_state_for_side(world_state: Dictionary, local_side: String) -> Dictionary:
	var normalized_side := "host" if local_side == "host" else "client"
	var mirror_y := normalized_side == "client"
	var host_paddle: Dictionary = world_state.get("p_host", {})
	var client_paddle: Dictionary = world_state.get("p_client", {})
	var host_pos := Vector2(float(host_paddle.get("paddle_x", 302.5)), OnlinePaddleState.HOST_Y)
	var client_pos := Vector2(float(client_paddle.get("paddle_x", 302.5)), OnlinePaddleState.CLIENT_Y)
	var ball_pos := OnlineMatchProtocol.wire_to_vector(world_state.get("ball_pos", {}), Vector2(380.0, 375.0))
	var ball_vel := OnlineMatchProtocol.wire_to_vector(world_state.get("ball_vel", {}), Vector2.ZERO)
	if mirror_y:
		host_pos.y = FIELD_HEIGHT - host_pos.y - PADDLE_HEIGHT
		client_pos.y = FIELD_HEIGHT - client_pos.y - PADDLE_HEIGHT
		ball_pos.y = FIELD_HEIGHT - ball_pos.y
		ball_vel.y = -ball_vel.y
	var local_paddle := host_paddle if normalized_side == "host" else client_paddle
	var opponent_paddle := client_paddle if normalized_side == "host" else host_paddle
	var local_pos := host_pos if normalized_side == "host" else client_pos
	var opponent_pos := client_pos if normalized_side == "host" else host_pos
	var score: Dictionary = world_state.get("score", {})
	var host_score := int(score.get("host", 0))
	var client_score := int(score.get("client", 0))
	var serve: Dictionary = world_state.get("serve", {})
	var serve_side := str(serve.get("owner_side", "host"))
	var winner := str(world_state.get("winner_side", ""))
	return {
		"tick": int(world_state.get("tick", 0)),
		"local_side": normalized_side,
		"ball_pos": ball_pos,
		"ball_vel": ball_vel,
		"ball_active": bool(world_state.get("ball_active", false)),
		"local_paddle": local_paddle,
		"opponent_paddle": opponent_paddle,
		"local_paddle_pos": local_pos,
		"opponent_paddle_pos": opponent_pos,
		"local_score": host_score if normalized_side == "host" else client_score,
		"opponent_score": client_score if normalized_side == "host" else host_score,
		"deuce_mode": bool(score.get("deuce_mode", false)),
		"deuce_goal": int(score.get("deuce_goal", 8)),
		"serve_waiting": bool(serve.get("waiting", true)),
		"local_serves": serve_side == normalized_side,
		"match_phase": str(world_state.get("match_phase", "waiting_peer")),
		"winner_local": winner != "" and winner == normalized_side,
		"winner_side": winner,
	}


func _process_host_tick(delta: float, local_input: Dictionary) -> void:
	if match_phase not in ["countdown", "serve_wait", "rally", "finished"]:
		return
	simulation_tick += 1
	var remote_input := _consume_latest_remote_input()
	if match_phase == "countdown":
		countdown_remaining = maxf(0.0, countdown_remaining - delta)
		if countdown_remaining <= 0.0:
			match_phase = "serve_wait"
			status_message = "서브 대기"
	var events: Array[Dictionary] = _simulation.step(delta, local_input, remote_input, match_phase)
	for event in events:
		_publish_local_event(event)
	if _simulation.winner_side != "":
		winner_side = _simulation.winner_side
		match_phase = "finished"
		status_message = "승리" if winner_side == "host" else "패배"
	elif match_phase == "serve_wait" and _simulation.ball_active:
		match_phase = "rally"
		status_message = "랠리"
	elif match_phase == "rally" and not _simulation.ball_active:
		match_phase = "serve_wait"
		status_message = "서브 대기"
	var should_snapshot := _advance_snapshot_schedule() or not events.is_empty()
	if should_snapshot and _has_remote_peer():
		var network_event := _select_network_event(events)
		if not network_event.is_empty():
			_last_event_serial += 1
			network_event["serial"] = _last_event_serial
		var snapshot: Dictionary = _simulation.build_snapshot(
			simulation_tick,
			match_phase,
			_last_remote_input_tick_applied,
			network_event,
			countdown_remaining
		)
		_send_packet(
			OnlineMatchProtocol.KIND_SNAPSHOT,
			snapshot,
			_noteworthy_event(network_event)
		)


func _process_client_tick(delta: float, local_input: Dictionary) -> void:
	_send_packet(
		OnlineMatchProtocol.KIND_INPUT,
		local_input,
		bool(local_input.get("dash_edge", false)) or bool(local_input.get("serve_edge", false))
	)
	_client_input_history.append(local_input.duplicate(true))
	while _client_input_history.size() > CLIENT_INPUT_HISTORY_LIMIT:
		_client_input_history.pop_front()
	var before_x: float = _simulation.client_paddle.position.x
	var result: Dictionary = _simulation.client_paddle.step(delta, local_input)
	var predicted_x: float = _simulation.client_paddle.position.x
	if not _client_render_initialized:
		_client_render_x = predicted_x
		_client_render_initialized = true
	else:
		_client_render_x += predicted_x - before_x
		_client_render_x = move_toward(
			_client_render_x,
			predicted_x,
			CLIENT_CORRECTION_MAX_PX_PER_TICK
		)
		_client_render_x = clampf(_client_render_x, 0.0, OnlinePaddleState.FIELD_WIDTH - OnlinePaddleState.PADDLE_WIDTH)
	if bool(result.get("dash_started", false)):
		_publish_local_event({
			"kind": "dash",
			"source_x": predicted_x + OnlinePaddleState.PADDLE_WIDTH * 0.5,
			"half_dash": bool(result.get("half_dash", false)),
		})


func _on_transport_peer_joined(_peer_id: int) -> void:
	_acquire_simulation_tick_lock()
	if role == "host":
		_reset_remote_peer_state(true)
		match_phase = "waiting_ready"
		status_message = "상대 준비 대기"
		_phase_elapsed = 0.0
		_send_packet(OnlineMatchProtocol.KIND_WELCOME, {
			"side": "client",
			"simulation_hz": SIMULATION_HZ,
			"snapshot_hz": snapshot_hz,
		}, true)
	else:
		status_message = "호스트 응답 대기"
		_phase_elapsed = 0.0
		_send_packet(OnlineMatchProtocol.KIND_HELLO, {
			"character_id": "ufo_player",
			"runtime_character_id": "smasher",
		}, true)


func _on_transport_peer_left(_peer_id: int) -> void:
	_reset_remote_peer_state(false)
	match_phase = "disconnected"
	status_message = "상대 연결이 끊어졌습니다"
	_phase_elapsed = 0.0
	_release_simulation_tick_lock(_view_layout)


func _on_transport_error(message: String) -> void:
	_enter_error(message)


func _on_transport_packet(peer_id: int, bytes: PackedByteArray) -> void:
	if _transport == null or peer_id != int(_transport.get_remote_peer_id()):
		return
	var packet := OnlineMatchProtocol.decode_packet(bytes)
	if packet.is_empty():
		return
	var kind := str(packet.get("kind", ""))
	var payload: Dictionary = packet.get("payload", {})
	match kind:
		OnlineMatchProtocol.KIND_HELLO:
			if role == "host" and str(payload.get("runtime_character_id", "")) == "smasher":
				_handshake_received = true
				_try_start_countdown()
		OnlineMatchProtocol.KIND_WELCOME:
			if role == "client" and int(payload.get("simulation_hz", 0)) == SIMULATION_HZ:
				_handshake_received = true
				snapshot_hz = clampi(int(payload.get("snapshot_hz", snapshot_hz)), 1, SIMULATION_HZ)
				match_phase = "waiting_ready"
				status_message = "전투 준비 중"
				_phase_elapsed = 0.0
				if _local_ready:
					_send_packet(OnlineMatchProtocol.KIND_READY, {"ready": true}, true)
		OnlineMatchProtocol.KIND_READY:
			if role == "host" and bool(payload.get("ready", false)):
				_remote_ready = true
				_try_start_countdown()
		OnlineMatchProtocol.KIND_INPUT:
			if role == "host":
				_receive_remote_input(payload)
		OnlineMatchProtocol.KIND_SNAPSHOT:
			if role == "client":
				_receive_snapshot(payload)
		OnlineMatchProtocol.KIND_PING:
			if role == "host":
				_send_packet(OnlineMatchProtocol.KIND_PONG, payload, false)
		OnlineMatchProtocol.KIND_PONG:
			if role == "client":
				rtt_msec = maxi(0, Time.get_ticks_msec() - int(payload.get("stamp_msec", 0)))
		OnlineMatchProtocol.KIND_DISCONNECT:
			_reset_remote_peer_state(false)
			match_phase = "disconnected"
			status_message = str(payload.get("reason", "상대가 나갔습니다"))
			_release_simulation_tick_lock(_view_layout)


func _receive_remote_input(payload: Dictionary) -> void:
	var frame := OnlineMatchProtocol.sanitize_input_frame(payload)
	var input_tick := int(frame.get("tick", 0))
	if input_tick <= 0:
		return
	# input_tick belongs to the remote client's clock. Its absolute value must
	# never be compared with host simulation_tick: different battle-load times
	# create a stable, legitimate offset between those clocks. Accept the first
	# remote tick as the clock baseline. There is deliberately no lead cap: the
	# host advances each paddle only once per host tick, so a remote tick jump
	# cannot accelerate movement. A lead cap would instead create a permanent
	# input lock after a long network pause. Monotonic ordering below is enough.
	if not _remote_input_clock_initialized:
		_remote_input_clock_initialized = true
	var new_dash_edge := (
		bool(frame.get("dash_edge", false))
		and input_tick > _last_remote_dash_edge_tick
	)
	var new_serve_edge := (
		bool(frame.get("serve_edge", false))
		and input_tick > _last_remote_serve_edge_tick
	)
	if new_dash_edge:
		_last_remote_dash_edge_tick = input_tick
	if new_serve_edge:
		_last_remote_serve_edge_tick = input_tick
	if input_tick > _last_remote_input_tick_received:
		var pending_dash := bool(_latest_remote_input.get("dash_edge", false))
		var pending_serve := bool(_latest_remote_input.get("serve_edge", false))
		_last_remote_input_tick_received = input_tick
		_latest_remote_input = frame
		_latest_remote_input["dash_edge"] = pending_dash or new_dash_edge
		_latest_remote_input["serve_edge"] = pending_serve or new_serve_edge
		return
	# Reliable edge packets use the control channel and can arrive after a newer
	# unreliable movement frame. Preserve a fresh edge without rolling movement
	# or the acknowledged input tick backward.
	if new_dash_edge:
		_latest_remote_input["dash_edge"] = true
	if new_serve_edge:
		_latest_remote_input["serve_edge"] = true


func _consume_latest_remote_input() -> Dictionary:
	var frame := _latest_remote_input.duplicate(true)
	_last_remote_input_tick_applied = maxi(
		_last_remote_input_tick_applied,
		int(frame.get("tick", 0))
	)
	_latest_remote_input["dash_edge"] = false
	_latest_remote_input["serve_edge"] = false
	_latest_remote_input["skill_edge"] = false
	_latest_remote_input["item_edge"] = false
	_latest_remote_input["guardian_edge"] = false
	return frame


func _receive_snapshot(payload: Dictionary) -> void:
	var snapshot := OnlineMatchProtocol.sanitize_match_snapshot(payload)
	var snapshot_tick := int(snapshot.get("tick", 0))
	if snapshot_tick <= _last_snapshot_tick:
		_receive_snapshot_event(snapshot.get("event", {}))
		return
	_last_snapshot_tick = snapshot_tick
	simulation_tick = snapshot_tick
	_previous_snapshot = _current_snapshot.duplicate(true) if not _current_snapshot.is_empty() else snapshot.duplicate(true)
	_current_snapshot = snapshot
	_snapshot_interpolation_alpha = 0.0
	var next_phase := str(snapshot.get("match_phase", match_phase))
	if next_phase != match_phase:
		_phase_elapsed = 0.0
	match_phase = next_phase
	countdown_remaining = float(snapshot.get("countdown_remaining", countdown_remaining))
	winner_side = str(snapshot.get("winner_side", ""))
	status_message = _status_for_phase(match_phase)
	var previous_render_x := _client_render_x
	_simulation.apply_authoritative_snapshot(snapshot)
	var acknowledged_tick := int(snapshot.get("ack_input_tick", 0))
	var replay_frames: Array[Dictionary] = []
	for frame in _client_input_history:
		if int(frame.get("tick", 0)) > acknowledged_tick:
			replay_frames.append(frame)
	_client_input_history = replay_frames
	for frame in _client_input_history:
		_simulation.client_paddle.step(1.0 / float(SIMULATION_HZ), frame)
	if _client_render_initialized:
		_client_render_x = previous_render_x
	else:
		_client_render_x = _simulation.client_paddle.position.x
		_client_render_initialized = true
	_receive_snapshot_event(snapshot.get("event", {}))


func _receive_snapshot_event(event_value: Variant) -> void:
	if not event_value is Dictionary:
		return
	var event: Dictionary = event_value as Dictionary
	var event_serial := int(event.get("serial", 0))
	if event_serial > _last_received_event_serial:
		_last_received_event_serial = event_serial
		_pending_local_events.append(event)


func _try_start_countdown() -> void:
	if role != "host" or not _local_ready or not _remote_ready or not _handshake_received:
		return
	if match_phase == "countdown" or match_phase == "serve_wait" or match_phase == "rally":
		return
	match_phase = "countdown"
	countdown_remaining = COUNTDOWN_SECONDS
	status_message = "대전 시작 준비"
	_phase_elapsed = 0.0


func _build_interpolated_world_state() -> Dictionary:
	if role == "host" or _current_snapshot.is_empty():
		var event: Dictionary = {}
		return _simulation.build_snapshot(
			simulation_tick,
			match_phase,
			_last_remote_input_tick_applied,
			event,
			countdown_remaining
		)
	var state := _current_snapshot.duplicate(true)
	var alpha := clampf(_snapshot_interpolation_alpha, 0.0, 1.0)
	var previous_ball := OnlineMatchProtocol.wire_to_vector(_previous_snapshot.get("ball_pos", {}))
	var current_ball := OnlineMatchProtocol.wire_to_vector(_current_snapshot.get("ball_pos", {}))
	state["ball_pos"] = OnlineMatchProtocol.vector_to_wire(previous_ball.lerp(current_ball, alpha))
	var previous_host: Dictionary = _previous_snapshot.get("p_host", {})
	var current_host: Dictionary = _current_snapshot.get("p_host", {})
	var host_state := current_host.duplicate(true)
	host_state["paddle_x"] = lerpf(
		float(previous_host.get("paddle_x", current_host.get("paddle_x", 302.5))),
		float(current_host.get("paddle_x", 302.5)),
		alpha
	)
	state["p_host"] = host_state
	var client_state: Dictionary = state.get("p_client", {}).duplicate(true)
	client_state["paddle_x"] = _client_render_x
	client_state["paddle_vel"] = _simulation.client_paddle.velocity_x
	client_state["dash_state"] = _simulation.client_paddle.dash_state.get_snapshot()
	state["p_client"] = client_state
	return state


func _select_network_event(events: Array[Dictionary]) -> Dictionary:
	if events.is_empty():
		return {}
	var priority := {
		"match_finished": 6,
		"score": 5,
		"serve": 4,
		"paddle": 3,
		"wall": 2,
		"dash": 1,
		"round_reset": 0,
	}
	var selected: Dictionary = events[0].duplicate(true)
	var selected_priority := int(priority.get(str(selected.get("kind", "")), -1))
	for event in events:
		var event_priority := int(priority.get(str(event.get("kind", "")), -1))
		if event_priority > selected_priority:
			selected = event.duplicate(true)
			selected_priority = event_priority
	return selected


func _noteworthy_event(event: Dictionary) -> bool:
	return str(event.get("kind", "")) in ["serve", "score", "match_finished"]


func _publish_local_event(event: Dictionary) -> void:
	if event.is_empty():
		return
	_pending_local_events.append(event.duplicate(true))


func _advance_snapshot_schedule() -> bool:
	_snapshot_send_budget += clampi(snapshot_hz, 1, SIMULATION_HZ)
	if _snapshot_send_budget < SIMULATION_HZ:
		return false
	_snapshot_send_budget -= SIMULATION_HZ
	return true


func _send_packet(kind: String, payload: Dictionary, reliable: bool) -> void:
	if not _has_remote_peer():
		return
	_packet_sequence += 1
	var packet := OnlineMatchProtocol.encode_packet(kind, _packet_sequence, payload)
	if packet.is_empty():
		return
	var channel := (
		int(_transport.CONTROL_CHANNEL)
		if reliable or kind != OnlineMatchProtocol.KIND_INPUT and kind != OnlineMatchProtocol.KIND_SNAPSHOT
		else int(_transport.INPUT_CHANNEL)
	)
	_transport.send(packet, reliable, channel)


func _has_remote_peer() -> bool:
	return _transport != null and _transport.has_method("has_remote_peer") and bool(_transport.has_remote_peer())


func _connect_transport_signals() -> void:
	if _transport == null:
		return
	_transport.peer_joined.connect(_on_transport_peer_joined)
	_transport.peer_left.connect(_on_transport_peer_left)
	_transport.packet_received.connect(_on_transport_packet)
	_transport.transport_error.connect(_on_transport_error)


func _disconnect_transport_signals() -> void:
	if _transport == null:
		return
	var bindings := [
		["peer_joined", Callable(self, "_on_transport_peer_joined")],
		["peer_left", Callable(self, "_on_transport_peer_left")],
		["packet_received", Callable(self, "_on_transport_packet")],
		["transport_error", Callable(self, "_on_transport_error")],
	]
	for binding in bindings:
		var signal_value: Signal = _transport.get(binding[0])
		var callback: Callable = binding[1]
		if signal_value.is_connected(callback):
			signal_value.disconnect(callback)


func _advance_phase_timeout(delta: float) -> void:
	var timeout_seconds := 0.0
	if role == "client" and match_phase == "connecting":
		timeout_seconds = CONNECT_TIMEOUT_SECONDS
	# Do not spend the opponent-ready budget while this machine is still in its
	# own battle loading/prewarm path. Cold or asymmetric loading can exceed the
	# network-ready timeout without either peer being unhealthy.
	elif match_phase == "waiting_ready" and _local_ready:
		timeout_seconds = READY_TIMEOUT_SECONDS
	else:
		_phase_elapsed = 0.0
		return
	_phase_elapsed += delta
	if _phase_elapsed < timeout_seconds:
		return
	var timeout_message := (
		"호스트 연결 시간이 초과되었습니다"
		if match_phase == "connecting"
		else "상대 준비 시간이 초과되었습니다"
	)
	_enter_error(timeout_message)


func _enter_error(message: String) -> void:
	match_phase = "error"
	status_message = message if not message.strip_edges().is_empty() else "온라인 연결 오류"
	_phase_elapsed = 0.0
	if _transport != null and _transport.has_method("close"):
		_transport.close()
	_release_simulation_tick_lock(_view_layout)


func _reset_remote_peer_state(reset_match: bool) -> void:
	_remote_ready = false
	_handshake_received = false
	_last_remote_input_tick_received = -1
	_last_remote_input_tick_applied = 0
	_remote_input_clock_initialized = false
	_last_remote_dash_edge_tick = -1
	_last_remote_serve_edge_tick = -1
	_latest_remote_input = OnlineMatchProtocol.sanitize_input_frame({})
	_last_event_serial = 0
	_last_received_event_serial = 0
	_pending_local_events.clear()
	countdown_remaining = 0.0
	winner_side = ""
	if not reset_match:
		return
	simulation_tick = 0
	local_input_tick = 0
	_snapshot_send_budget = 0
	_previous_snapshot.clear()
	_current_snapshot.clear()
	_client_input_history.clear()
	if _simulation != null and _simulation.has_method("reset_match"):
		_simulation.reset_match()


func _acquire_simulation_tick_lock() -> void:
	if _simulation_tick_lock_acquired:
		return
	_previous_physics_ticks_per_second = Engine.physics_ticks_per_second
	_simulation_tick_lock_acquired = true
	if _view_layout != null and _view_layout.has_method("set_online_simulation_tick_lock"):
		_view_layout.set_online_simulation_tick_lock(true, SIMULATION_HZ)
	else:
		Engine.physics_ticks_per_second = SIMULATION_HZ


func _release_simulation_tick_lock(layout: Object) -> void:
	if not _simulation_tick_lock_acquired:
		return
	if layout != null and layout.has_method("set_online_simulation_tick_lock"):
		layout.set_online_simulation_tick_lock(false, SIMULATION_HZ)
	elif _previous_physics_ticks_per_second > 0:
		Engine.physics_ticks_per_second = _previous_physics_ticks_per_second
	_simulation_tick_lock_acquired = false
	_previous_physics_ticks_per_second = 0


func _status_for_phase(phase: String) -> String:
	match phase:
		"connecting":
			return "호스트에 연결 중"
		"waiting_peer":
			return "상대 접속 대기 중"
		"waiting_ready":
			return "상대 준비 대기"
		"countdown":
			return "대전 시작 준비"
		"serve_wait":
			return "서브 대기"
		"rally":
			return "랠리"
		"finished":
			return "승리" if winner_side == role else "패배"
		"disconnected":
			return "상대 연결이 끊어졌습니다"
		"error":
			return status_message
	return phase
