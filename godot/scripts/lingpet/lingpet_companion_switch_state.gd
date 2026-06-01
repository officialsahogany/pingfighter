extends RefCounted

var timer := 0.0
var from_pet_id := ""
var to_pet_id := ""
var trigger_count := 0


func begin(raw_from_pet_id: String, raw_to_pet_id: String, duration: float) -> void:
	from_pet_id = _normalize_pet_id(raw_from_pet_id)
	to_pet_id = _normalize_pet_id(raw_to_pet_id)
	trigger_count += 1
	timer = maxf(0.0, duration)
	if timer <= 0.0:
		_clear_ids()


func advance(delta: float) -> void:
	if timer <= 0.0:
		return
	timer = maxf(0.0, timer - maxf(0.0, delta))
	if timer <= 0.0:
		_clear_ids()


func reset() -> void:
	timer = 0.0
	trigger_count = 0
	_clear_ids()


func get_ratio(duration: float) -> float:
	if timer <= 0.0 or duration <= 0.0:
		return 0.0
	return clampf(timer / duration, 0.0, 1.0)


func get_snapshot(duration: float) -> Dictionary:
	var ratio := get_ratio(duration)
	return {
		"companion_switch_transition": ratio,
		"companion_switch_from_pet_id": from_pet_id if ratio > 0.0 else "",
		"companion_switch_to_pet_id": to_pet_id if ratio > 0.0 else "",
	}


func _clear_ids() -> void:
	from_pet_id = ""
	to_pet_id = ""


func _normalize_pet_id(value: String) -> String:
	return value.strip_edges().to_lower()
