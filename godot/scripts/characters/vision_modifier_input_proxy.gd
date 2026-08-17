extends RefCounted

var _input_reader: Object = null


func configure(input_reader: Object) -> Object:
	_input_reader = input_reader
	return self


func get_snapshot() -> Dictionary:
	if _input_reader == null or not _input_reader.has_method("get_snapshot"):
		return {}
	var value: Variant = _input_reader.get_snapshot()
	var snapshot: Dictionary = value.duplicate(true) if value is Dictionary else {}
	for key in ["left_pressed", "right_pressed", "up_pressed"]:
		if snapshot.has(key):
			snapshot[key] = false
	for key in ["power_smash_direction", "blacksmith_swing_direction"]:
		if snapshot.has(key):
			snapshot[key] = 0
	snapshot["direction"] = 0.0
	return snapshot


func suppress_primary_pointer_until_release() -> void:
	if _input_reader != null and _input_reader.has_method("suppress_primary_pointer_until_release"):
		_input_reader.suppress_primary_pointer_until_release()
