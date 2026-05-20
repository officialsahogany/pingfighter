extends RefCounted

var active: bool = false
var elapsed: float = 0.0
var direction: int = 0
var arc_strength: float = 0.0
var combo_consumed: int = 0


func reset() -> void:
	active = false
	elapsed = 0.0
	direction = 0
	arc_strength = 0.0
	combo_consumed = 0


func prepare(new_direction: int, new_arc_strength: float, new_combo_consumed: int) -> void:
	direction = new_direction
	arc_strength = new_arc_strength
	combo_consumed = new_combo_consumed
	active = false
	elapsed = 0.0


func start() -> void:
	active = true
	elapsed = 0.0


func finish() -> void:
	active = false
	elapsed = 0.0


func step(fps_scale: float) -> bool:
	if not active:
		return false
	elapsed += fps_scale / 60.0
	return true


func is_active() -> bool:
	return active


func get_elapsed() -> float:
	return elapsed


func get_direction() -> int:
	return direction


func get_arc_strength() -> float:
	return arc_strength


func get_combo_consumed() -> int:
	return combo_consumed
