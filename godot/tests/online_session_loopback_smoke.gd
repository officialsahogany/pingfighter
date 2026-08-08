extends SceneTree

const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const OnlineEnetTransport := preload("res://scripts/network/online_enet_transport.gd")
const OnlineMatchProtocol := preload("res://scripts/network/online_match_protocol.gd")
const OnlineMatchSession := preload("res://scripts/network/online_match_session.gd")
const OnlineMatchSimulation := preload("res://scripts/network/online_match_simulation.gd")
const OnlinePaddleState := preload("res://scripts/network/online_paddle_state.gd")
const RoundFlowState := preload("res://scripts/core/round_flow_state.gd")

var _failures: Array[String] = []


class FakeViewLayout:
	extends RefCounted
	var locked := false
	var ticks := 0

	func set_online_simulation_tick_lock(active: bool, ticks_per_second: int = 60) -> int:
		locked = active
		ticks = ticks_per_second if active else 0
		return ticks


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host_transport := OnlineEnetTransport.new()
	var client_transport := OnlineEnetTransport.new()
	var host_simulation := OnlineMatchSimulation.new()
	var client_simulation := OnlineMatchSimulation.new()
	host_simulation.configure(MatchScoreState.new(), RoundFlowState.new())
	client_simulation.configure(MatchScoreState.new(), RoundFlowState.new())
	var host_layout := FakeViewLayout.new()
	var client_layout := FakeViewLayout.new()
	var host_session := OnlineMatchSession.new()
	var client_session := OnlineMatchSession.new()
	var port := 41000 + (OS.get_process_id() % 15000)
	_expect(int(host_session.begin({"role": "host", "port": port}, host_transport, host_simulation, host_layout)) == OK, "host session should start")
	_expect(int(client_session.begin({"role": "client", "address": "127.0.0.1", "port": port}, client_transport, client_simulation, client_layout)) == OK, "client session should start")
	_expect(host_layout.locked and host_layout.ticks == 60, "host session should acquire the 60Hz lock")
	_expect(client_layout.locked and client_layout.ticks == 60, "client session should acquire the 60Hz lock")
	# Model a client that completed battle loading three seconds before the host.
	# Its first input tick is a legal remote-clock offset, not a host-clock lead.
	client_session.local_input_tick = 180

	var connect_deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < connect_deadline and not (host_transport.has_remote_peer() and client_transport.has_remote_peer()):
		host_session.poll_transport()
		client_session.poll_transport()
		await process_frame
	_expect(host_transport.has_remote_peer() and client_transport.has_remote_peer(), "host/client sessions should establish loopback ENet")

	host_session.mark_local_ready()
	client_session.mark_local_ready()
	for _handshake_frame in range(30):
		_pump_network(host_session, client_session)
		await process_frame
	_expect(host_session.match_phase == "countdown", "host should enter countdown after both peers are ready")

	# A hostile client may bypass encode_packet and append a final-position field
	# directly to the wire array. Exact schema validation must reject the whole
	# packet before the session clock advances.
	var malicious_tick := client_session.next_input_tick()
	var malformed_wire_packet := var_to_bytes([
		OnlineMatchProtocol.PROTOCOL_VERSION,
		4,
		777,
		[malicious_tick, 1, false, false, false, false, false, {"paddle_x": 999999.0}],
	])
	client_transport.send(malformed_wire_packet, true, OnlineEnetTransport.CONTROL_CHANNEL)
	for _malicious_delivery_frame in range(10):
		_pump_network(host_session, client_session)
		await process_frame
	_expect(host_session._last_remote_input_tick_received == -1, "extra client authority fields must reject the whole wire packet")
	var legal_packet := OnlineMatchProtocol.encode_packet(
		OnlineMatchProtocol.KIND_INPUT,
		778,
		{"tick": malicious_tick, "move_dir": 1}
	)
	client_transport.send(legal_packet, true, OnlineEnetTransport.CONTROL_CHANNEL)
	for _legal_delivery_frame in range(10):
		_pump_network(host_session, client_session)
		await process_frame
	_expect(host_session._last_remote_input_tick_received == malicious_tick, "host should accept the legal initial client-clock offset")
	_expect(not host_session._latest_remote_input.has("paddle_x"), "host session should not retain client paddle position")
	_expect(not host_session._latest_remote_input.has("score"), "host session should not retain client score")

	for tick in range(260):
		var client_frame := {
			"tick": client_session.next_input_tick(),
			"move_dir": 1 if tick < 45 else 0,
			"dash_edge": tick == 6,
			"serve_edge": false,
		}
		client_session.process_simulation_tick(1.0 / 60.0, client_frame)
		client_session.poll_transport()
		host_session.poll_transport()
		var host_frame := {
			"tick": host_session.next_input_tick(),
			"move_dir": 0,
			"dash_edge": false,
			"serve_edge": tick == 250,
		}
		host_session.process_simulation_tick(1.0 / 60.0, host_frame)
		host_session.poll_transport()
		client_session.poll_transport()
		await process_frame

	_expect(host_simulation.client_paddle.position.x > (760.0 - 155.0) * 0.5, "host should simulate remote client movement from input intent")
	_expect(host_simulation.client_paddle.position.x <= 760.0 - 155.0, "malicious client position must not escape host clamp")
	_expect(host_simulation.match_score_state.player_score == 0 and host_simulation.match_score_state.boss_score == 0, "malicious client score must not mutate host score")
	_expect(host_session.match_phase == "rally" and host_simulation.ball_active, "host manual serve should start the authoritative rally")
	var client_view := client_session.get_render_state()
	_expect(str(client_view.get("local_side", "")) == "client", "client render state should retain client role")
	_expect(client_view.get("local_paddle_pos", Vector2.ZERO).y == OnlinePaddleState.HOST_Y, "client prediction should render its own paddle at the bottom")

	host_session.stop(host_layout)
	client_session.stop(client_layout)
	_expect(not host_layout.locked and not client_layout.locked, "session stop should release both tick locks")
	if _failures.is_empty():
		print("online_session_loopback_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _pump_network(host_session: Object, client_session: Object) -> void:
	client_session.poll_transport()
	host_session.poll_transport()
	host_session.poll_transport()
	client_session.poll_transport()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
