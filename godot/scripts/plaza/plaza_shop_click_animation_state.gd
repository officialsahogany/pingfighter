extends RefCounted

const DEFAULT_DURATION := 0.62

var active := false
var timer := 0.0
var duration := DEFAULT_DURATION
var object_id := ""
var object_rect := Rect2()


func start(next_object_id: String, next_rect: Rect2, next_duration: float = DEFAULT_DURATION) -> void:
	object_id = next_object_id
	object_rect = next_rect
	duration = maxf(0.08, next_duration)
	timer = 0.0
	active = true


func reset() -> void:
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
	reset()
	return true


func is_active() -> bool:
	return active


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
