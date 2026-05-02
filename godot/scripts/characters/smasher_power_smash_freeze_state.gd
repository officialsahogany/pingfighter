extends RefCounted

var active: bool = false
var timer: float = 0.0
var ball_locked: bool = false
var ball_pos: Vector2 = Vector2.ZERO


func reset() -> void:
	active = false
	timer = 0.0
	ball_locked = false
	ball_pos = Vector2.ZERO


func begin() -> void:
	active = true
	timer = 0.0
	ball_locked = false
	ball_pos = Vector2.ZERO


func lock_pose(pos: Vector2) -> void:
	ball_pos = pos
	ball_locked = true
	timer = 0.0


func update(delta: float, freeze_duration: float) -> bool:
	if not active:
		return false

	timer += delta
	if timer < freeze_duration:
		return false

	active = false
	ball_locked = false
	return true


func is_active() -> bool:
	return active


func get_timer() -> float:
	return timer


func is_ball_locked() -> bool:
	return ball_locked


func get_ball_pos() -> Vector2:
	return ball_pos
