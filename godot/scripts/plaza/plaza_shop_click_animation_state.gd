extends RefCounted

const DEFAULT_DURATION := 0.62

var active := false
var timer := 0.0
var duration := DEFAULT_DURATION
var object_id := ""
var object_rect := Rect2()
var _pending_spec: Dictionary = {}
var _completed_spec: Dictionary = {}


func start(next_object_id: String, next_rect: Rect2, next_duration: float = DEFAULT_DURATION) -> void:
	_pending_spec.clear()
	_completed_spec.clear()
	_start_active(next_object_id, next_rect, next_duration)


func start_with_spec(spec: Dictionary, next_duration: float = DEFAULT_DURATION) -> bool:
	var next_object_id := str(spec.get("id", ""))
	if spec.is_empty() or next_object_id == "":
		return false
	_pending_spec = spec.duplicate(true)
	_completed_spec.clear()
	var next_rect: Rect2 = spec.get("rect", Rect2())
	_start_active(next_object_id, next_rect, next_duration)
	return true


func _start_active(next_object_id: String, next_rect: Rect2, next_duration: float) -> void:
	object_id = next_object_id
	object_rect = next_rect
	duration = maxf(0.08, next_duration)
	timer = 0.0
	active = true


func reset() -> void:
	_reset_active()
	_pending_spec.clear()
	_completed_spec.clear()


func _reset_active() -> void:
	active = false
	timer = 0.0
	object_id = ""
	object_rect = Rect2()
	duration = DEFAULT_DURATION


func advance(delta: float) -> bool:
	if not active:
		return false
	timer += maxf(0.0, delta)
	if timer < duration:
		return false
	_reset_active()
	_completed_spec = _pending_spec
	_pending_spec = {}
	return true


func is_active() -> bool:
	return active


func get_pending_object_id() -> String:
	return str(_pending_spec.get("id", ""))


func get_pending_spec() -> Dictionary:
	return _pending_spec.duplicate(true)


func has_completed_spec() -> bool:
	return not _completed_spec.is_empty()


func consume_completed_spec() -> Dictionary:
	if _completed_spec.is_empty():
		return {}
	var completed: Dictionary = _completed_spec.duplicate(true)
	_completed_spec.clear()
	return completed


func get_progress() -> float:
	if not active:
		return 1.0
	return clampf(timer / maxf(0.001, duration), 0.0, 1.0)


func get_alpha() -> float:
	if not active:
		return 0.0
	var progress := get_progress()
	if progress < 0.18:
		return _smooth01(progress / 0.18)
	return _smooth01(1.0 - clampf((progress - 0.18) / 0.82, 0.0, 1.0))


func get_pulse_scale() -> float:
	var progress := get_progress()
	return 1.0 + sin(progress * PI) * 0.36


static func _smooth01(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
