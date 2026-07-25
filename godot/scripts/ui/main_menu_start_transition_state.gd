extends RefCounted

# Owns the deterministic clock and completion edge for the main-menu start
# transition. Scene nodes, tweens, audio, and navigation remain scene-owned.

var duration_sec: float = 1.0
var elapsed_sec: float = 0.0
var active: bool = false


func _init(duration: float = 1.0) -> void:
	duration_sec = maxf(duration, 0.001)


func begin() -> void:
	elapsed_sec = 0.0
	active = true


func cancel() -> void:
	active = false
	elapsed_sec = 0.0


func advance(delta: float) -> bool:
	if not active:
		return false
	elapsed_sec = minf(elapsed_sec + maxf(delta, 0.0), duration_sec)
	if elapsed_sec < duration_sec:
		return false
	active = false
	return true


func get_progress() -> float:
	return clampf(elapsed_sec / duration_sec, 0.0, 1.0)
