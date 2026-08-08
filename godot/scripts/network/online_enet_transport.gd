extends RefCounted

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal packet_received(peer_id: int, packet: PackedByteArray)
signal transport_error(message: String)

const DEFAULT_PORT := 24777
const MAX_CLIENTS := 1
const CHANNEL_COUNT := 2
const INPUT_CHANNEL := 0
const CONTROL_CHANNEL := 1

var _peer: ENetMultiplayerPeer = null
var _role := "offline"
var _remote_peer_id := 0
var _last_error := ""


func start_host(port: int = DEFAULT_PORT, bind_ip: String = "*") -> int:
	close()
	var next_peer := ENetMultiplayerPeer.new()
	var normalized_bind := bind_ip.strip_edges()
	if normalized_bind != "" and normalized_bind != "*":
		next_peer.set_bind_ip(normalized_bind)
	var error := next_peer.create_server(clampi(port, 1, 65535), MAX_CLIENTS, CHANNEL_COUNT)
	if error != OK:
		_fail("ENet host creation failed (error %d)" % error)
		return error
	_role = "host"
	_attach_peer(next_peer)
	return OK


func start_client(address: String, port: int = DEFAULT_PORT) -> int:
	close()
	var normalized_address := address.strip_edges()
	if normalized_address == "":
		_fail("ENet client address is empty")
		return ERR_INVALID_PARAMETER
	var next_peer := ENetMultiplayerPeer.new()
	var error := next_peer.create_client(normalized_address, clampi(port, 1, 65535), CHANNEL_COUNT)
	if error != OK:
		_fail("ENet client creation failed (error %d)" % error)
		return error
	_role = "client"
	_attach_peer(next_peer)
	return OK


func poll() -> void:
	if _peer == null:
		return
	# A client peer remains allocated after a failed or completed connection,
	# but ENet rejects poll() once its connection status is disconnected.
	# The session owns the visible timeout/disconnect state; the transport must
	# not turn that stable state into one engine error per frame.
	if _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	_peer.poll()
	if _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	while _peer.get_available_packet_count() > 0:
		var sender_id := _peer.get_packet_peer()
		var packet := _peer.get_packet()
		if _peer.get_packet_error() != OK:
			_fail("ENet packet receive failed")
			continue
		packet_received.emit(sender_id, packet)


func send(packet: PackedByteArray, reliable: bool = false, channel: int = INPUT_CHANNEL) -> int:
	if _peer == null or packet.is_empty() or _remote_peer_id <= 0:
		return ERR_UNCONFIGURED
	_peer.transfer_mode = (
		MultiplayerPeer.TRANSFER_MODE_RELIABLE
		if reliable
		else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	)
	_peer.transfer_channel = clampi(channel, 0, CHANNEL_COUNT - 1)
	_peer.set_target_peer(_remote_peer_id)
	var error := _peer.put_packet(packet)
	if error != OK:
		_fail("ENet packet send failed (error %d)" % error)
	return error


func close() -> void:
	if _peer != null:
		_disconnect_peer_signals(_peer)
		_peer.close()
	_peer = null
	_role = "offline"
	_remote_peer_id = 0


func is_started() -> bool:
	return _peer != null


func has_remote_peer() -> bool:
	return _remote_peer_id > 0


func get_role() -> String:
	return _role


func get_remote_peer_id() -> int:
	return _remote_peer_id


func get_connection_status() -> int:
	if _peer == null:
		return MultiplayerPeer.CONNECTION_DISCONNECTED
	return _peer.get_connection_status()


func get_last_error() -> String:
	return _last_error


func _attach_peer(next_peer: ENetMultiplayerPeer) -> void:
	_peer = next_peer
	_last_error = ""
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)


func _disconnect_peer_signals(peer: ENetMultiplayerPeer) -> void:
	var joined := Callable(self, "_on_peer_connected")
	var left := Callable(self, "_on_peer_disconnected")
	if peer.peer_connected.is_connected(joined):
		peer.peer_connected.disconnect(joined)
	if peer.peer_disconnected.is_connected(left):
		peer.peer_disconnected.disconnect(left)


func _on_peer_connected(peer_id: int) -> void:
	if _remote_peer_id > 0 and peer_id != _remote_peer_id:
		if _role == "host" and _peer != null:
			_peer.disconnect_peer(peer_id, true)
		return
	_remote_peer_id = peer_id
	if _role == "host" and _peer != null:
		_peer.refuse_new_connections = true
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id == _remote_peer_id:
		_remote_peer_id = 0
		if _role == "host" and _peer != null:
			_peer.refuse_new_connections = false
	peer_left.emit(peer_id)


func _fail(message: String) -> void:
	_last_error = message
	transport_error.emit(message)
