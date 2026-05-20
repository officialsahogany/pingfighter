extends RefCounted

const DEFAULT_DURATION_SEC := 1.15
const MIN_DURATION_SEC := 0.20

var timer := 0.0
var duration := DEFAULT_DURATION_SEC
var text := ""
var kind := ""


func reset(default_duration_sec: float = DEFAULT_DURATION_SEC) -> void:
	timer = 0.0
	duration = default_duration_sec
	text = ""
	kind = ""


func update(delta: float) -> void:
	timer = max(0.0, timer - max(0.0, delta))


func trigger(warning_kind: String, warning_text: String, duration_sec: float = DEFAULT_DURATION_SEC) -> void:
	kind = warning_kind
	text = warning_text
	duration = max(MIN_DURATION_SEC, duration_sec)
	timer = duration


func is_active() -> bool:
	return timer > 0.0


func get_kind() -> String:
	return kind


func get_snapshot() -> Dictionary:
	return {
		"active": is_active(),
		"text": text,
		"kind": kind,
		"timer": timer,
		"duration": duration,
	}
