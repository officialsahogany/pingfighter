extends RefCounted

var original_speed := 0.0
var initial_boost := false
var target_speed := 0.0
var boosted_speed := 0.0


func reset() -> void:
	original_speed = 0.0
	initial_boost = false
	target_speed = 0.0
	boosted_speed = 0.0


func update_initial_boost(elapsed: float, boost_duration: float) -> void:
	if initial_boost and elapsed >= boost_duration:
		initial_boost = false


func set_original_speed(value: float) -> void:
	original_speed = max(0.0, value)


func set_target_speed(value: float) -> void:
	target_speed = max(0.0, value)


func start_initial_boost(value: float) -> void:
	initial_boost = true
	boosted_speed = max(0.0, value)


func stop_initial_boost() -> void:
	initial_boost = false


func get_original_speed() -> float:
	return original_speed


func is_initial_boost_active() -> bool:
	return initial_boost


func get_target_speed() -> float:
	return target_speed


func get_boosted_speed() -> float:
	return boosted_speed
