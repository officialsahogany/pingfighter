extends RefCounted

var hovered_object_id := ""
var _amounts: Dictionary = {}


func ensure_specs(specs: Array[Dictionary]) -> void:
	for spec in specs:
		var object_id := str(spec.get("id", ""))
		if object_id != "" and not _amounts.has(object_id):
			_amounts[object_id] = 0.0


func set_hovered(object_id: String) -> bool:
	if hovered_object_id == object_id:
		return false
	hovered_object_id = object_id
	return true


func advance(specs: Array[Dictionary], delta: float, speed: float) -> bool:
	var step := maxf(0.0, delta) * maxf(0.0, speed)
	var changed := false
	for spec in specs:
		var object_id := str(spec.get("id", ""))
		if object_id == "":
			continue
		var current := get_amount(object_id)
		var target := 1.0 if object_id == hovered_object_id else 0.0
		var next := move_toward(current, target, step)
		if not is_equal_approx(current, next):
			_amounts[object_id] = next
			changed = true
	return changed


func get_amount(object_id: String) -> float:
	return float(_amounts.get(object_id, 0.0))


func is_visible(object_id: String, threshold: float = 0.01) -> bool:
	return get_amount(object_id) > threshold


func get_tracked_count() -> int:
	return _amounts.size()


func reset() -> void:
	hovered_object_id = ""
	_amounts.clear()
