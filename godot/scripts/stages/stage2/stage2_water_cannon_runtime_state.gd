extends RefCounted

var delay := -1.0
var phase := "idle"
var timer := 0.0
var target_id := -1
var start := Vector2.ZERO
var target := Vector2.ZERO
var current := Vector2.ZERO
var progress := 0.0


func reset() -> void:
	delay = -1.0
	phase = "idle"
	timer = 0.0
	target_id = -1
	progress = 0.0


func advance_idle_delay(delta: float) -> bool:
	if phase != "idle" or delay <= 0.0:
		return false
	delay = max(0.0, delay - max(0.0, delta))
	return delay <= 0.0


func activate(
	resolved_target_id: int,
	start_position: Vector2,
	target_position: Vector2,
	charge_sec: float
) -> bool:
	if phase != "idle" or resolved_target_id < 0:
		return false
	target_id = resolved_target_id
	start = start_position
	target = target_position
	current = start
	progress = 0.0
	phase = "charging"
	timer = max(0.0, charge_sec)
	delay = -1.0
	return true


func set_geometry(start_position: Vector2, target_position: Vector2) -> void:
	start = start_position
	target = target_position
	if phase == "charging":
		current = start


func advance_active(delta: float, fire_sec: float) -> Dictionary:
	var events: Dictionary = {
		"started_firing": false,
		"emit_trail": false,
		"finished": false,
	}
	var clamped_delta: float = max(0.0, delta)
	if phase == "charging":
		current = start
		timer = max(0.0, timer - clamped_delta)
		if timer <= 0.0:
			phase = "firing"
			timer = max(0.0, fire_sec)
			progress = 0.0
			events["started_firing"] = true
		return events
	if phase != "firing":
		return events

	timer = max(0.0, timer - clamped_delta)
	progress = clamp(1.0 - timer / max(0.001, fire_sec), 0.0, 1.0)
	current = start.lerp(target, progress)
	events["emit_trail"] = true
	if timer <= 0.0:
		events["finished"] = true
	return events


func cancel() -> void:
	phase = "idle"
	timer = 0.0
	target_id = -1
	progress = 0.0
	current = start
