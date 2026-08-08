extends RefCounted

const PROTOCOL_VERSION := 2
const MAX_PACKET_BYTES := 64 * 1024
const MAX_TICK := 2_147_483_647

const KIND_HELLO := "hello"
const KIND_WELCOME := "welcome"
const KIND_READY := "ready"
const KIND_INPUT := "input"
const KIND_SNAPSHOT := "snapshot"
const KIND_DISCONNECT := "disconnect"
const KIND_PING := "ping"
const KIND_PONG := "pong"

const VALID_KINDS := {
	KIND_HELLO: true,
	KIND_WELCOME: true,
	KIND_READY: true,
	KIND_INPUT: true,
	KIND_SNAPSHOT: true,
	KIND_DISCONNECT: true,
	KIND_PING: true,
	KIND_PONG: true,
}
const KIND_TO_CODE := {
	KIND_HELLO: 1,
	KIND_WELCOME: 2,
	KIND_READY: 3,
	KIND_INPUT: 4,
	KIND_SNAPSHOT: 5,
	KIND_DISCONNECT: 6,
	KIND_PING: 7,
	KIND_PONG: 8,
}
const CODE_TO_KIND := {
	1: KIND_HELLO,
	2: KIND_WELCOME,
	3: KIND_READY,
	4: KIND_INPUT,
	5: KIND_SNAPSHOT,
	6: KIND_DISCONNECT,
	7: KIND_PING,
	8: KIND_PONG,
}


static func encode_packet(kind: String, sequence: int, payload: Dictionary = {}) -> PackedByteArray:
	var normalized_kind := kind.strip_edges().to_lower()
	if not VALID_KINDS.has(normalized_kind):
		return PackedByteArray()
	var sanitized_payload := _sanitize_payload(normalized_kind, payload)
	# Fixed-order arrays avoid Dictionary key/type overhead. A normal snapshot is
	# comfortably below ENet's ~1.4KB MTU, so 30Hz state updates stay unfragmented.
	return var_to_bytes([
		PROTOCOL_VERSION,
		int(KIND_TO_CODE.get(normalized_kind, 0)),
		clampi(sequence, 0, MAX_TICK),
		_payload_to_wire(normalized_kind, sanitized_payload),
	])


static func decode_packet(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_PACKET_BYTES:
		return {}
	var decoded: Variant = bytes_to_var(bytes)
	if not decoded is Array:
		return {}
	var packet: Array = decoded
	if (
		packet.size() != 4
		or not _is_wire_int(packet[0])
		or not _is_wire_int(packet[1])
		or not _is_wire_int(packet[2])
		or int(packet[0]) != PROTOCOL_VERSION
	):
		return {}
	var kind := str(CODE_TO_KIND.get(int(packet[1]), ""))
	if not VALID_KINDS.has(kind):
		return {}
	if not _is_valid_wire_payload(kind, packet[3]):
		return {}
	var payload := _payload_from_wire(kind, packet[3])
	return {
		"version": PROTOCOL_VERSION,
		"kind": kind,
		"sequence": clampi(int(packet[2]), 0, MAX_TICK),
		"payload": _sanitize_payload(kind, payload),
	}


static func sanitize_input_frame(source: Dictionary) -> Dictionary:
	# This whitelist is the authority boundary. Client-supplied position,
	# velocity, cooldown, collision, score, and result fields never survive it.
	return {
		"tick": clampi(_safe_int(source.get("tick", 0), 0), 0, MAX_TICK),
		"move_dir": clampi(int(sign(_safe_float(source.get("move_dir", 0), 0.0))), -1, 1),
		"dash_edge": _safe_bool(source.get("dash_edge", false), false),
		"serve_edge": _safe_bool(source.get("serve_edge", false), false),
		"skill_edge": _safe_bool(source.get("skill_edge", false), false),
		"item_edge": _safe_bool(source.get("item_edge", false), false),
		"guardian_edge": _safe_bool(source.get("guardian_edge", false), false),
	}


static func sanitize_match_snapshot(source: Dictionary) -> Dictionary:
	var host_value: Variant = source.get("p_host", {})
	var client_value: Variant = source.get("p_client", {})
	var score_value: Variant = source.get("score", {})
	var serve_value: Variant = source.get("serve", {})
	var event_value: Variant = source.get("event", {})
	return {
		"tick": clampi(_safe_int(source.get("tick", 0), 0), 0, MAX_TICK),
		"ack_input_tick": clampi(_safe_int(source.get("ack_input_tick", 0), 0), 0, MAX_TICK),
		"ball_pos": sanitize_wire_vector(source.get("ball_pos", {})),
		"ball_vel": sanitize_wire_vector(source.get("ball_vel", {})),
		"ball_active": _safe_bool(source.get("ball_active", false), false),
		"p_host": _sanitize_paddle(host_value if host_value is Dictionary else {}),
		"p_client": _sanitize_paddle(client_value if client_value is Dictionary else {}),
		"score": _sanitize_score(score_value if score_value is Dictionary else {}),
		"serve": _sanitize_serve(serve_value if serve_value is Dictionary else {}),
		"match_phase": str(source.get("match_phase", "waiting_peer")).left(32),
		"countdown_remaining": clampf(_safe_float(source.get("countdown_remaining", 0.0), 0.0), 0.0, 10.0),
		"winner_side": _sanitize_side(str(source.get("winner_side", "")), true),
		"event": _sanitize_event(event_value if event_value is Dictionary else {}),
	}


static func vector_to_wire(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


static func wire_to_vector(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2:
		return value
	if not value is Dictionary:
		return fallback
	var source: Dictionary = value
	return Vector2(
		_safe_float(source.get("x", fallback.x), fallback.x),
		_safe_float(source.get("y", fallback.y), fallback.y)
	)


static func sanitize_wire_vector(value: Variant) -> Dictionary:
	var vector := wire_to_vector(value)
	return vector_to_wire(vector)


static func _sanitize_payload(kind: String, payload: Dictionary) -> Dictionary:
	match kind:
		KIND_INPUT:
			return sanitize_input_frame(payload)
		KIND_SNAPSHOT:
			return sanitize_match_snapshot(payload)
		KIND_HELLO:
			return {
				"character_id": str(payload.get("character_id", "ufo_player")).left(32),
				"runtime_character_id": str(payload.get("runtime_character_id", "smasher")).left(32),
			}
		KIND_WELCOME:
			return {
				"side": _sanitize_side(str(payload.get("side", "client"))),
				"simulation_hz": clampi(_safe_int(payload.get("simulation_hz", 60), 60), 30, 120),
				"snapshot_hz": clampi(_safe_int(payload.get("snapshot_hz", 30), 30), 1, 60),
			}
		KIND_READY:
			return {"ready": _safe_bool(payload.get("ready", true), true)}
		KIND_DISCONNECT:
			return {"reason": str(payload.get("reason", "")).left(160)}
		KIND_PING, KIND_PONG:
			return {
				"stamp_msec": maxi(0, _safe_int(payload.get("stamp_msec", 0), 0)),
			}
	return {}


static func _payload_to_wire(kind: String, payload: Dictionary) -> Array:
	match kind:
		KIND_INPUT:
			return [
				int(payload.get("tick", 0)),
				int(payload.get("move_dir", 0)),
				bool(payload.get("dash_edge", false)),
				bool(payload.get("serve_edge", false)),
				bool(payload.get("skill_edge", false)),
				bool(payload.get("item_edge", false)),
				bool(payload.get("guardian_edge", false)),
			]
		KIND_SNAPSHOT:
			var ball_pos: Dictionary = payload.get("ball_pos", {})
			var ball_vel: Dictionary = payload.get("ball_vel", {})
			return [
				int(payload.get("tick", 0)),
				int(payload.get("ack_input_tick", 0)),
				float(ball_pos.get("x", 0.0)),
				float(ball_pos.get("y", 0.0)),
				float(ball_vel.get("x", 0.0)),
				float(ball_vel.get("y", 0.0)),
				bool(payload.get("ball_active", false)),
				_paddle_to_wire(payload.get("p_host", {})),
				_paddle_to_wire(payload.get("p_client", {})),
				_score_to_wire(payload.get("score", {})),
				_serve_to_wire(payload.get("serve", {})),
				str(payload.get("match_phase", "waiting_peer")),
				str(payload.get("winner_side", "")),
				_event_to_wire(payload.get("event", {})),
				float(payload.get("countdown_remaining", 0.0)),
			]
		KIND_HELLO:
			return [str(payload.get("character_id", "ufo_player")), str(payload.get("runtime_character_id", "smasher"))]
		KIND_WELCOME:
			return [str(payload.get("side", "client")), int(payload.get("simulation_hz", 60)), int(payload.get("snapshot_hz", 30))]
		KIND_READY:
			return [bool(payload.get("ready", true))]
		KIND_DISCONNECT:
			return [str(payload.get("reason", ""))]
		KIND_PING, KIND_PONG:
			return [int(payload.get("stamp_msec", 0))]
	return []


static func _payload_from_wire(kind: String, wire: Variant) -> Dictionary:
	if not wire is Array:
		return {}
	var values: Array = wire
	match kind:
		KIND_INPUT:
			return {
				"tick": _array_get(values, 0, 0),
				"move_dir": _array_get(values, 1, 0),
				"dash_edge": _array_get(values, 2, false),
				"serve_edge": _array_get(values, 3, false),
				"skill_edge": _array_get(values, 4, false),
				"item_edge": _array_get(values, 5, false),
				"guardian_edge": _array_get(values, 6, false),
			}
		KIND_SNAPSHOT:
			return {
				"tick": _array_get(values, 0, 0),
				"ack_input_tick": _array_get(values, 1, 0),
				"ball_pos": {"x": _array_get(values, 2, 0.0), "y": _array_get(values, 3, 0.0)},
				"ball_vel": {"x": _array_get(values, 4, 0.0), "y": _array_get(values, 5, 0.0)},
				"ball_active": _array_get(values, 6, false),
				"p_host": _paddle_from_wire(_array_get(values, 7, [])),
				"p_client": _paddle_from_wire(_array_get(values, 8, [])),
				"score": _score_from_wire(_array_get(values, 9, [])),
				"serve": _serve_from_wire(_array_get(values, 10, [])),
				"match_phase": _array_get(values, 11, "waiting_peer"),
				"winner_side": _array_get(values, 12, ""),
				"event": _event_from_wire(_array_get(values, 13, [])),
				"countdown_remaining": _array_get(values, 14, 0.0),
			}
		KIND_HELLO:
			return {"character_id": _array_get(values, 0, "ufo_player"), "runtime_character_id": _array_get(values, 1, "smasher")}
		KIND_WELCOME:
			return {"side": _array_get(values, 0, "client"), "simulation_hz": _array_get(values, 1, 60), "snapshot_hz": _array_get(values, 2, 30)}
		KIND_READY:
			return {"ready": _array_get(values, 0, true)}
		KIND_DISCONNECT:
			return {"reason": _array_get(values, 0, "")}
		KIND_PING, KIND_PONG:
			return {"stamp_msec": _array_get(values, 0, 0)}
	return {}


static func _is_valid_wire_payload(kind: String, wire: Variant) -> bool:
	if not wire is Array:
		return false
	var values: Array = wire
	match kind:
		KIND_INPUT:
			return (
				values.size() == 7
				and _is_wire_int(values[0])
				and _is_wire_int(values[1])
				and _all_wire_bools(values, 2, 7)
			)
		KIND_SNAPSHOT:
			return (
				values.size() == 15
				and _is_wire_int(values[0])
				and _is_wire_int(values[1])
				and _all_wire_numbers(values, 2, 6)
				and _is_wire_bool(values[6])
				and _is_valid_paddle_wire(values[7])
				and _is_valid_paddle_wire(values[8])
				and _is_valid_score_wire(values[9])
				and _is_valid_serve_wire(values[10])
				and _is_wire_string(values[11])
				and _is_wire_string(values[12])
				and _is_valid_event_wire(values[13])
				and _is_wire_number(values[14])
			)
		KIND_HELLO:
			return values.size() == 2 and _is_wire_string(values[0]) and _is_wire_string(values[1])
		KIND_WELCOME:
			return (
				values.size() == 3
				and _is_wire_string(values[0])
				and _is_wire_int(values[1])
				and _is_wire_int(values[2])
			)
		KIND_READY:
			return values.size() == 1 and _is_wire_bool(values[0])
		KIND_DISCONNECT:
			return values.size() == 1 and _is_wire_string(values[0])
		KIND_PING, KIND_PONG:
			return values.size() == 1 and _is_wire_int(values[0])
	return false


static func _is_valid_paddle_wire(value: Variant) -> bool:
	if not value is Array:
		return false
	var values: Array = value
	return (
		values.size() == 3
		and _is_wire_number(values[0])
		and _is_wire_number(values[1])
		and _is_valid_dash_wire(values[2])
	)


static func _is_valid_dash_wire(value: Variant) -> bool:
	if not value is Array:
		return false
	var values: Array = value
	return (
		values.size() == 16
		and _is_wire_bool(values[0])
		and _is_wire_number(values[1])
		and _is_wire_number(values[2])
		and _is_wire_bool(values[3])
		and _all_wire_numbers(values, 4, 9)
		and _is_wire_int(values[9])
		and _is_wire_number(values[10])
		and _is_wire_number(values[11])
		and _is_wire_int(values[12])
		and _is_wire_bool(values[13])
		and _is_wire_bool(values[14])
		and _is_wire_int(values[15])
	)


static func _is_valid_score_wire(value: Variant) -> bool:
	if not value is Array:
		return false
	var values: Array = value
	return (
		values.size() == 5
		and _is_wire_int(values[0])
		and _is_wire_int(values[1])
		and _is_wire_bool(values[2])
		and _is_wire_int(values[3])
		and _is_wire_int(values[4])
	)


static func _is_valid_serve_wire(value: Variant) -> bool:
	if not value is Array:
		return false
	var values: Array = value
	return (
		values.size() == 5
		and _is_wire_bool(values[0])
		and _is_wire_string(values[1])
		and _all_wire_numbers(values, 2, 5)
	)


static func _is_valid_event_wire(value: Variant) -> bool:
	if not value is Array:
		return false
	var values: Array = value
	return (
		values.size() == 5
		and _is_wire_int(values[0])
		and _is_wire_string(values[1])
		and _is_wire_number(values[2])
		and _is_wire_number(values[3])
		and _is_wire_bool(values[4])
	)


static func _all_wire_numbers(values: Array, start: int, end_exclusive: int) -> bool:
	for index in range(start, end_exclusive):
		if not _is_wire_number(values[index]):
			return false
	return true


static func _all_wire_bools(values: Array, start: int, end_exclusive: int) -> bool:
	for index in range(start, end_exclusive):
		if not _is_wire_bool(values[index]):
			return false
	return true


static func _is_wire_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT


static func _is_wire_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value))


static func _is_wire_bool(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL


static func _is_wire_string(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING


static func _paddle_to_wire(value: Variant) -> Array:
	var paddle: Dictionary = value if value is Dictionary else {}
	return [float(paddle.get("paddle_x", 302.5)), float(paddle.get("paddle_vel", 0.0)), _dash_to_wire(paddle.get("dash_state", {}))]


static func _paddle_from_wire(value: Variant) -> Dictionary:
	var values: Array = value if value is Array else []
	return {
		"paddle_x": _array_get(values, 0, 302.5),
		"paddle_vel": _array_get(values, 1, 0.0),
		"dash_state": _dash_from_wire(_array_get(values, 2, [])),
	}


static func _dash_to_wire(value: Variant) -> Array:
	var dash: Dictionary = value if value is Dictionary else {}
	return [
		bool(dash.get("active", false)), float(dash.get("timer", 0.0)),
		float(dash.get("direction", 0.0)), bool(dash.get("is_half", false)),
		float(dash.get("stun_timer", 0.0)), float(dash.get("recovery_total_frames", 0.0)),
		float(dash.get("available_timer", 0.0)), float(dash.get("elapsed_frames", 0.0)),
		float(dash.get("dash_distance_multiplier", 1.0)), int(dash.get("tokens", 1)),
		float(dash.get("charge_timer", 0.0)), float(dash.get("recharge_frames", 300.0)),
		int(dash.get("consecutive_count", 0)), bool(dash.get("key_released_since_last", true)),
		bool(dash.get("recovering", false)), int(dash.get("max_tokens", 1)),
	]


static func _dash_from_wire(value: Variant) -> Dictionary:
	var values: Array = value if value is Array else []
	return {
		"active": _array_get(values, 0, false), "timer": _array_get(values, 1, 0.0),
		"direction": _array_get(values, 2, 0.0), "is_half": _array_get(values, 3, false),
		"stun_timer": _array_get(values, 4, 0.0), "recovery_total_frames": _array_get(values, 5, 0.0),
		"available_timer": _array_get(values, 6, 0.0), "elapsed_frames": _array_get(values, 7, 0.0),
		"dash_distance_multiplier": _array_get(values, 8, 1.0), "tokens": _array_get(values, 9, 1),
		"charge_timer": _array_get(values, 10, 0.0), "recharge_frames": _array_get(values, 11, 300.0),
		"consecutive_count": _array_get(values, 12, 0), "key_released_since_last": _array_get(values, 13, true),
		"recovering": _array_get(values, 14, false), "max_tokens": _array_get(values, 15, 1),
	}


static func _score_to_wire(value: Variant) -> Array:
	var score: Dictionary = value if value is Dictionary else {}
	return [int(score.get("host", 0)), int(score.get("client", 0)), bool(score.get("deuce_mode", false)), int(score.get("deuce_goal", 8)), int(score.get("win_goal", 7))]


static func _score_from_wire(value: Variant) -> Dictionary:
	var values: Array = value if value is Array else []
	return {"host": _array_get(values, 0, 0), "client": _array_get(values, 1, 0), "deuce_mode": _array_get(values, 2, false), "deuce_goal": _array_get(values, 3, 8), "win_goal": _array_get(values, 4, 7)}


static func _serve_to_wire(value: Variant) -> Array:
	var serve: Dictionary = value if value is Dictionary else {}
	return [bool(serve.get("waiting", true)), str(serve.get("owner_side", "host")), float(serve.get("serve_timer", 0.0)), float(serve.get("serve_delay", 1.0)), float(serve.get("banner_timer", 0.0))]


static func _serve_from_wire(value: Variant) -> Dictionary:
	var values: Array = value if value is Array else []
	return {"waiting": _array_get(values, 0, true), "owner_side": _array_get(values, 1, "host"), "serve_timer": _array_get(values, 2, 0.0), "serve_delay": _array_get(values, 3, 1.0), "banner_timer": _array_get(values, 4, 0.0)}


static func _event_to_wire(value: Variant) -> Array:
	var event: Dictionary = value if value is Dictionary else {}
	return [int(event.get("serial", 0)), str(event.get("kind", "")), float(event.get("source_x", 380.0)), float(event.get("speed", 0.0)), bool(event.get("half_dash", false))]


static func _event_from_wire(value: Variant) -> Dictionary:
	var values: Array = value if value is Array else []
	return {"serial": _array_get(values, 0, 0), "kind": _array_get(values, 1, ""), "source_x": _array_get(values, 2, 380.0), "speed": _array_get(values, 3, 0.0), "half_dash": _array_get(values, 4, false)}


static func _array_get(values: Array, index: int, fallback: Variant) -> Variant:
	return values[index] if index >= 0 and index < values.size() else fallback


static func _sanitize_paddle(source: Dictionary) -> Dictionary:
	var dash_value: Variant = source.get("dash_state", {})
	return {
		"paddle_x": clampf(_safe_float(source.get("paddle_x", 302.5), 302.5), -155.0, 760.0),
		"paddle_vel": clampf(_safe_float(source.get("paddle_vel", 0.0), 0.0), -100.0, 100.0),
		"dash_state": _sanitize_dash(dash_value if dash_value is Dictionary else {}),
	}


static func _sanitize_dash(source: Dictionary) -> Dictionary:
	return {
		"active": _safe_bool(source.get("active", false), false),
		"timer": clampf(_safe_float(source.get("timer", 0.0), 0.0), 0.0, 600.0),
		"direction": clampf(float(sign(_safe_float(source.get("direction", 0.0), 0.0))), -1.0, 1.0),
		"is_half": _safe_bool(source.get("is_half", false), false),
		"recovering": _safe_bool(source.get("recovering", false), false),
		"stun_timer": clampf(_safe_float(source.get("stun_timer", 0.0), 0.0), 0.0, 600.0),
		"recovery_total_frames": clampf(_safe_float(source.get("recovery_total_frames", 0.0), 0.0), 0.0, 600.0),
		"available_timer": clampf(_safe_float(source.get("available_timer", 0.0), 0.0), 0.0, 600.0),
		"elapsed_frames": clampf(_safe_float(source.get("elapsed_frames", 0.0), 0.0), 0.0, 600.0),
		"dash_distance_multiplier": clampf(_safe_float(source.get("dash_distance_multiplier", 1.0), 1.0), 0.0, 4.0),
		"tokens": clampi(_safe_int(source.get("tokens", 1), 1), 0, 1),
		"max_tokens": 1,
		"charge_timer": clampf(_safe_float(source.get("charge_timer", 0.0), 0.0), 0.0, 1200.0),
		"recharge_frames": clampf(_safe_float(source.get("recharge_frames", 300.0), 300.0), 1.0, 1200.0),
		"consecutive_count": maxi(0, _safe_int(source.get("consecutive_count", 0), 0)),
		"key_released_since_last": _safe_bool(source.get("key_released_since_last", true), true),
	}


static func _sanitize_score(source: Dictionary) -> Dictionary:
	return {
		"host": clampi(_safe_int(source.get("host", 0), 0), 0, 99),
		"client": clampi(_safe_int(source.get("client", 0), 0), 0, 99),
		"deuce_mode": _safe_bool(source.get("deuce_mode", false), false),
		"deuce_goal": clampi(_safe_int(source.get("deuce_goal", 8), 8), 1, 99),
		"win_goal": clampi(_safe_int(source.get("win_goal", 7), 7), 1, 99),
	}


static func _sanitize_serve(source: Dictionary) -> Dictionary:
	return {
		"waiting": _safe_bool(source.get("waiting", true), true),
		"owner_side": _sanitize_side(str(source.get("owner_side", "host"))),
		"serve_timer": clampf(_safe_float(source.get("serve_timer", 0.0), 0.0), 0.0, 60.0),
		"serve_delay": clampf(_safe_float(source.get("serve_delay", 1.0), 1.0), 0.0, 60.0),
		"banner_timer": clampf(_safe_float(source.get("banner_timer", 0.0), 0.0), 0.0, 60.0),
	}


static func _sanitize_event(source: Dictionary) -> Dictionary:
	return {
		"serial": clampi(_safe_int(source.get("serial", 0), 0), 0, MAX_TICK),
		"kind": str(source.get("kind", "")).left(32),
		"source_x": clampf(_safe_float(source.get("source_x", 380.0), 380.0), 0.0, 760.0),
		"speed": clampf(_safe_float(source.get("speed", 0.0), 0.0), 0.0, 100.0),
		"half_dash": _safe_bool(source.get("half_dash", false), false),
	}


static func _sanitize_side(value: String, allow_empty: bool = false) -> String:
	var normalized := value.strip_edges().to_lower()
	if allow_empty and normalized == "":
		return ""
	return "host" if normalized == "host" else "client"


static func _safe_float(value: Variant, fallback: float) -> float:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	var number := float(value)
	return number if is_finite(number) else fallback


static func _safe_int(value: Variant, fallback: int) -> int:
	if typeof(value) != TYPE_INT:
		return fallback
	return int(value)


static func _safe_bool(value: Variant, fallback: bool) -> bool:
	if typeof(value) != TYPE_BOOL:
		return fallback
	return bool(value)
