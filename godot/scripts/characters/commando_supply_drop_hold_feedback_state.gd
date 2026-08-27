extends RefCounted

const HOLD_REQUIRED_SECONDS := 1.0
const HOLD_GAUGE_THRESHOLD_SECONDS := 0.3
const HOLD_GAUGE_WIDTH := 80.0
const HOLD_GAUGE_HEIGHT := 12.0
const HOLD_GAUGE_TOP_OFFSET := 40.0

const DEFAULT_RADIO_DURATION := 0.35
const DEFAULT_PLAYER_POS := Vector2(302.0, 654.0)
const DEFAULT_PLAYER_SIZE := Vector2(155.0, 50.0)

var _hold_time := 0.0
var _pending_hold_time := 0.0
var _radio_motion := false
var _radio_timer := 0.0
var _radio_duration := DEFAULT_RADIO_DURATION
var _radio_audio_active := false
var _gauge_player_pos := DEFAULT_PLAYER_POS
var _gauge_player_size := DEFAULT_PLAYER_SIZE


func reset() -> void:
	_hold_time = 0.0
	_pending_hold_time = 0.0
	_radio_motion = false
	_radio_timer = 0.0
	_radio_audio_active = false
	_gauge_player_pos = DEFAULT_PLAYER_POS
	_gauge_player_size = DEFAULT_PLAYER_SIZE


func cancel_transient() -> void:
	_hold_time = 0.0
	_pending_hold_time = 0.0
	_radio_motion = false
	_radio_timer = 0.0
	release_audio_gate()


func advance(delta: float, active: bool) -> void:
	if not _radio_motion:
		return
	_radio_timer = max(0.0, _radio_timer - max(0.0, delta))
	if _radio_timer > 0.0:
		return
	_radio_motion = false
	# Python parity: tail expiry only re-arms the one-playback gate. The
	# sample itself keeps playing to its natural end and is force-stopped only
	# by the round/battle owner.
	if active:
		release_audio_gate()


func accumulate_pending_hold(delta: float) -> void:
	_pending_hold_time = min(
		HOLD_REQUIRED_SECONDS,
		max(_pending_hold_time, _hold_time) + max(0.0, delta)
	)
	_hold_time = 0.0
	release_audio_gate()


func advance_hold(delta: float) -> bool:
	if _pending_hold_time > 0.0:
		_hold_time = max(_hold_time, _pending_hold_time)
		_pending_hold_time = 0.0
	_hold_time += delta
	return _hold_time >= HOLD_REQUIRED_SECONDS


func cache_gauge_anchor(deps: Dictionary) -> void:
	var context_value: Variant = deps.get("commando_supply_drop_collision_context", {})
	if not (context_value is Dictionary):
		return
	var context: Dictionary = context_value
	_gauge_player_pos = _get_vector2(context.get("player_pos", _gauge_player_pos), _gauge_player_pos)
	_gauge_player_size = _get_vector2(
		context.get(
			"player_paddle_size",
			Vector2(
				float(context.get("paddle_width", _gauge_player_size.x)),
				float(context.get("paddle_height", _gauge_player_size.y))
			)
		),
		_gauge_player_size
	)


func sync_hold_feedback(active: bool) -> bool:
	if not is_gauge_visible(active):
		return false
	_radio_motion = true
	_radio_timer = max(_radio_timer, _radio_duration)
	if _radio_audio_active:
		return false
	_radio_audio_active = true
	return true


func begin_activation() -> bool:
	_hold_time = 0.0
	_pending_hold_time = 0.0
	_radio_motion = true
	_radio_timer = _radio_duration
	return not _radio_audio_active


func build_gauge_status(active: bool) -> Dictionary:
	var progress := get_gauge_progress()
	return {
		"visible": is_gauge_visible(active),
		"progress": progress,
		"percent": int(round(progress * 100.0)),
		"rect": get_gauge_rect(),
		"player_pos": _gauge_player_pos,
		"player_size": _gauge_player_size,
	}


func get_snapshot(active: bool) -> Dictionary:
	return {
		"hold_time": _hold_time,
		"pending_hold_time": _pending_hold_time,
		"radio_motion": _radio_motion,
		"radio_timer": _radio_timer,
		"radio_duration": _radio_duration,
		"hold_gauge_visible": is_gauge_visible(active),
		"hold_progress": get_gauge_progress(),
		"hold_gauge_rect": get_gauge_rect(),
		"hold_radio_audio_active": _radio_audio_active,
	}


func restore(snapshot: Dictionary) -> void:
	_hold_time = float(snapshot.get("hold_time", 0.0))
	_pending_hold_time = float(snapshot.get("pending_hold_time", 0.0))
	_radio_motion = bool(snapshot.get("radio_motion", false))
	_radio_timer = float(snapshot.get("radio_timer", 0.0))
	_radio_duration = float(snapshot.get("radio_duration", _radio_duration))
	# A save snapshot cannot prove that an AudioStreamPlayer is still live.
	_radio_audio_active = false


func is_gauge_visible(active: bool) -> bool:
	return not active and _hold_time >= HOLD_GAUGE_THRESHOLD_SECONDS


func get_gauge_progress() -> float:
	if _hold_time < HOLD_GAUGE_THRESHOLD_SECONDS:
		return 0.0
	var denominator: float = max(0.001, HOLD_REQUIRED_SECONDS - HOLD_GAUGE_THRESHOLD_SECONDS)
	return clamp((_hold_time - HOLD_GAUGE_THRESHOLD_SECONDS) / denominator, 0.0, 1.0)


func get_gauge_rect() -> Rect2:
	var player_center_x := _gauge_player_pos.x + _gauge_player_size.x * 0.5
	var gauge_y := _gauge_player_pos.y - HOLD_GAUGE_TOP_OFFSET
	return Rect2(
		Vector2(player_center_x - HOLD_GAUGE_WIDTH * 0.5, gauge_y),
		Vector2(HOLD_GAUGE_WIDTH, HOLD_GAUGE_HEIGHT)
	)


func is_radio_motion() -> bool:
	return _radio_motion


func is_radio_audio_active() -> bool:
	return _radio_audio_active


func get_radio_duration() -> float:
	return _radio_duration


func release_audio_gate() -> void:
	_radio_audio_active = false


func force_stop_audio() -> void:
	_radio_audio_active = false


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
