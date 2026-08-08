extends SceneTree

const OnlineEnetTransport := preload("res://scripts/network/online_enet_transport.gd")
const OnlineMatchProtocol := preload("res://scripts/network/online_match_protocol.gd")

var _failures: Array[String] = []
var _host: Object = null
var _client: Object = null
var _host_packet: PackedByteArray = PackedByteArray()
var _client_packet: PackedByteArray = PackedByteArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_host = OnlineEnetTransport.new()
	_client = OnlineEnetTransport.new()
	_host.packet_received.connect(_on_host_packet)
	_client.packet_received.connect(_on_client_packet)
	var port := 32000 + (OS.get_process_id() % 20000)
	_expect(int(_host.start_host(port, "127.0.0.1")) == OK, "loopback host should bind")
	_expect(int(_client.start_client("127.0.0.1", port)) == OK, "loopback client should start")
	await _poll_until(Callable(self, "_both_connected"), 5000)
	_expect(_both_connected(), "loopback peers should connect within 5 seconds")

	var input_packet := OnlineMatchProtocol.encode_packet(
		OnlineMatchProtocol.KIND_INPUT,
		1,
		{"tick": 1, "move_dir": -1, "dash_edge": true}
	)
	_expect(int(_client.send(input_packet, true, OnlineEnetTransport.CONTROL_CHANNEL)) == OK, "client should send input bytes")
	await _poll_until(Callable(self, "_host_has_packet"), 3000)
	var host_decoded := OnlineMatchProtocol.decode_packet(_host_packet)
	_expect(str(host_decoded.get("kind", "")) == OnlineMatchProtocol.KIND_INPUT, "host should receive the input packet")
	_expect(int(host_decoded.get("payload", {}).get("move_dir", 0)) == -1, "host should decode client input intent")

	var snapshot_packet := OnlineMatchProtocol.encode_packet(
		OnlineMatchProtocol.KIND_SNAPSHOT,
		2,
		{
			"tick": 2,
			"ball_pos": {"x": 380.0, "y": 375.0},
			"p_host": {},
			"p_client": {},
			"score": {},
			"serve": {},
		}
	)
	_expect(int(_host.send(snapshot_packet, false, OnlineEnetTransport.INPUT_CHANNEL)) == OK, "host should send snapshot bytes")
	await _poll_until(Callable(self, "_client_has_packet"), 3000)
	var client_decoded := OnlineMatchProtocol.decode_packet(_client_packet)
	_expect(str(client_decoded.get("kind", "")) == OnlineMatchProtocol.KIND_SNAPSHOT, "client should receive the snapshot packet")

	_host.close()
	_client.close()
	if _failures.is_empty():
		print("online_enet_loopback_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _poll_until(predicate: Callable, timeout_msec: int) -> void:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline and not bool(predicate.call()):
		_host.poll()
		_client.poll()
		await process_frame


func _both_connected() -> bool:
	return _host.has_remote_peer() and _client.has_remote_peer()


func _host_has_packet() -> bool:
	return not _host_packet.is_empty()


func _client_has_packet() -> bool:
	return not _client_packet.is_empty()


func _on_host_packet(_peer_id: int, packet: PackedByteArray) -> void:
	_host_packet = packet


func _on_client_packet(_peer_id: int, packet: PackedByteArray) -> void:
	_client_packet = packet


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
