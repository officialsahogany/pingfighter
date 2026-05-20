extends RefCounted

const DEFAULT_DURATION_SEC := 0.24

var timer := 0.0
var duration := DEFAULT_DURATION_SEC


func reset(default_duration_sec: float = DEFAULT_DURATION_SEC) -> void:
	timer = 0.0
	duration = default_duration_sec


func update(delta: float) -> void:
	timer = max(0.0, timer - max(0.0, delta))


func trigger(duration_sec: float = DEFAULT_DURATION_SEC) -> void:
	duration = max(0.0, duration_sec)
	timer = duration


func get_timer() -> float:
	return timer


func get_duration() -> float:
	return duration
