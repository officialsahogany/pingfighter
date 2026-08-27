extends RefCounted

var _pending_ball_impulse := false
var _ball_impulse_center := Vector2.ZERO
var _blast_timer := 0.0
var _blast_center := Vector2.ZERO
var _player_knocked := false


func reset() -> void:
	_pending_ball_impulse = false
	_ball_impulse_center = Vector2.ZERO
	_blast_timer = 0.0
	_blast_center = Vector2.ZERO
	_player_knocked = false


func arm(center: Vector2, duration: float) -> void:
	_pending_ball_impulse = true
	_ball_impulse_center = center
	_blast_timer = max(0.0, duration)
	_blast_center = center
	_player_knocked = false


func advance(delta: float) -> void:
	if _blast_timer <= 0.0:
		return
	_blast_timer = max(0.0, _blast_timer - max(0.0, delta))


func has_active_blast() -> bool:
	return _blast_timer > 0.0


func is_player_knockback_pending() -> bool:
	return has_active_blast() and not _player_knocked


func mark_player_knocked() -> void:
	_player_knocked = true


func consume_ball_impulse() -> Dictionary:
	if not _pending_ball_impulse:
		return {}
	# The first ball frame consumes the edge even if downstream collision math
	# decides that the ball is outside the radius. This prevents delayed or
	# duplicate impulses on later frames.
	_pending_ball_impulse = false
	return {
		"pending": true,
		"center": _ball_impulse_center,
	}


func build_blast_zone(radius: float, explosion_style: String, max_duration_frames: float) -> Dictionary:
	return {
		"active": has_active_blast(),
		"position": _blast_center,
		"radius": radius,
		"explosion_style": explosion_style,
		"max_duration_frames": max_duration_frames,
		"duration_frames": _blast_timer * 60.0,
	}


func get_snapshot() -> Dictionary:
	return {
		"crash_blast_timer": _blast_timer,
		"crash_blast_center": _blast_center,
		"crash_blast_player_knocked": _player_knocked,
	}


func restore(snapshot: Dictionary) -> void:
	# The pending ball edge was never part of the save schema; recreating it
	# would let loading a save replay an already-consumed gameplay impulse.
	_pending_ball_impulse = false
	_ball_impulse_center = Vector2.ZERO
	_blast_timer = max(0.0, float(snapshot.get("crash_blast_timer", 0.0)))
	_blast_center = _get_vector2(snapshot.get("crash_blast_center", Vector2.ZERO), Vector2.ZERO)
	_player_knocked = bool(snapshot.get("crash_blast_player_knocked", false))


func get_blast_center() -> Vector2:
	return _blast_center


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
