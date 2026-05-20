extends RefCounted

const DEFAULT_DURATION_SEC := 0.22

var timer := 0.0
var duration := DEFAULT_DURATION_SEC
var side := ""
var impact_y := 0.0


func reset(default_duration_sec: float = DEFAULT_DURATION_SEC) -> void:
	timer = 0.0
	duration = default_duration_sec
	side = ""
	impact_y = 0.0


func update(delta: float) -> void:
	timer = max(0.0, timer - max(0.0, delta))


func trigger(resolved_side: String, y: float, duration_sec: float = DEFAULT_DURATION_SEC) -> void:
	timer = max(0.0, duration_sec)
	duration = timer
	side = resolved_side
	impact_y = y


func is_active() -> bool:
	return timer > 0.0


func get_snapshot() -> Dictionary:
	return {
		"timer": timer,
		"duration": duration,
		"side": side,
		"y": impact_y,
	}
