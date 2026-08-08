extends SceneTree

const OnlineEnetTransport := preload("res://scripts/network/online_enet_transport.gd")
const OnlineMatchProtocol := preload("res://scripts/network/online_match_protocol.gd")

const OUTPUT_PATH := "res://test_artifacts/online_match_live_visual_qa.png"
const TIMEOUT_MSEC := 90000

var _client_transport: Object = null
var _client_sequence := 0
var _client_tick := 0
var _sent_handshake := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root_window := root
	root_window.size = Vector2i(1280, 900)
	var selection_state := root_window.get_node_or_null("GameSelectionState")
	if selection_state == null:
		_fail("GameSelectionState autoload missing")
		return
	var port := 46500 + (OS.get_process_id() % 10000)
	selection_state.set_character({"id": "ufo_player", "runtime_id": "smasher", "name": "한미량"})
	selection_state.set_league_mode("champion")
	selection_state.set_stage(1)
	selection_state.request_online_match({"role": "host", "port": port, "snapshot_hz": 30})
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("battle scene failed to load")
		return
	var battle := packed.instantiate()
	root_window.add_child(battle)
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	var host_session: Object = null
	while Time.get_ticks_msec() < deadline:
		host_session = battle.gameplay_modules.get_cached_instance("online_match_session")
		if host_session != null and host_session.is_active():
			break
		await process_frame
	if host_session == null or not host_session.is_active():
		_fail("online host session did not become active")
		return

	_client_transport = OnlineEnetTransport.new()
	if int(_client_transport.start_client("127.0.0.1", port)) != OK:
		_fail("visual QA client failed to start")
		return
	while Time.get_ticks_msec() < deadline and not _client_transport.has_remote_peer():
		_client_transport.poll()
		await process_frame
	if not _client_transport.has_remote_peer():
		_fail("visual QA client failed to connect")
		return
	_send_handshake()

	var serve_pressed := false
	var serve_press_started_msec := 0
	var match_deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < match_deadline:
		_client_transport.poll()
		_client_tick += 1
		_send(OnlineMatchProtocol.KIND_INPUT, {
			"tick": _client_tick,
			"move_dir": 1 if _client_tick < 70 else 0,
			"dash_edge": _client_tick == 15,
			"serve_edge": false,
		}, _client_tick == 15)
		if host_session.match_phase == "serve_wait" and not serve_pressed:
			var simulation: Object = host_session.get_simulation()
			if simulation != null and simulation.round_flow_state.serve_timer >= 1.0:
				Input.action_press("ui_accept")
				serve_pressed = true
				serve_press_started_msec = Time.get_ticks_msec()
		elif serve_pressed and Time.get_ticks_msec() - serve_press_started_msec >= 250:
			Input.action_release("ui_accept")
		if host_session.match_phase == "rally" and host_session.get_simulation().ball_active:
			break
		await process_frame
	Input.action_release("ui_accept")
	if host_session.match_phase != "rally":
		var simulation: Object = host_session.get_simulation()
		var serve_timer := float(simulation.round_flow_state.serve_timer) if simulation != null else -1.0
		_fail("visual QA host did not reach rally (phase=%s serve_timer=%.2f)" % [host_session.match_phase, serve_timer])
		return
	for _frame in range(20):
		_client_transport.poll()
		await process_frame
	var image := root_window.get_texture().get_image()
	var absolute_output := ProjectSettings.globalize_path(OUTPUT_PATH)
	var output_dir := absolute_output.get_base_dir()
	DirAccess.make_dir_recursive_absolute(output_dir)
	var save_error := image.save_png(absolute_output)
	_client_transport.close()
	battle.queue_free()
	await process_frame
	if save_error != OK:
		_fail("visual QA capture save failed: %d" % save_error)
		return
	print("online_match_live_visual_qa: ok -> %s" % absolute_output)
	quit(0)


func _send_handshake() -> void:
	if _sent_handshake:
		return
	_sent_handshake = true
	_send(OnlineMatchProtocol.KIND_HELLO, {
		"character_id": "ufo_player",
		"runtime_character_id": "smasher",
	}, true)
	_send(OnlineMatchProtocol.KIND_READY, {"ready": true}, true)


func _send(kind: String, payload: Dictionary, reliable: bool) -> void:
	if _client_transport == null or not _client_transport.has_remote_peer():
		return
	_client_sequence += 1
	var packet := OnlineMatchProtocol.encode_packet(kind, _client_sequence, payload)
	var channel := OnlineEnetTransport.CONTROL_CHANNEL if reliable else OnlineEnetTransport.INPUT_CHANNEL
	_client_transport.send(packet, reliable, channel)


func _fail(message: String) -> void:
	Input.action_release("ui_accept")
	if _client_transport != null:
		_client_transport.close()
	push_error(message)
	quit(1)
