extends RefCounted

var _input_reader: Object = null
var _mythic_item_runtime: Object = null


func configure(input_reader: Object, mythic_item_runtime: Object) -> Object:
	_input_reader = input_reader
	_mythic_item_runtime = mythic_item_runtime
	return self


func get_snapshot() -> Dictionary:
	if _input_reader == null or not _input_reader.has_method("get_snapshot"):
		return {}
	var value: Variant = _input_reader.get_snapshot()
	var snapshot: Dictionary = value.duplicate(true) if value is Dictionary else {}
	if not _is_player_skill_locked():
		return snapshot
	return _lock_skill_inputs(snapshot)


func _is_player_skill_locked() -> bool:
	if _mythic_item_runtime == null:
		return false
	if (
		_mythic_item_runtime.has_method("is_horn_strawberry_skills_locked")
		and bool(_mythic_item_runtime.is_horn_strawberry_skills_locked())
	):
		return true
	if (
		_mythic_item_runtime.has_method("is_horn_strawberry_control_locked")
		and bool(_mythic_item_runtime.is_horn_strawberry_control_locked())
	):
		return true
	if (
		_mythic_item_runtime.has_method("is_odins_eye_skills_locked")
		and bool(_mythic_item_runtime.is_odins_eye_skills_locked())
	):
		return true
	if (
		_mythic_item_runtime.has_method("is_odins_eye_control_locked")
		and bool(_mythic_item_runtime.is_odins_eye_control_locked())
	):
		return true
	return false


func _lock_skill_inputs(snapshot: Dictionary) -> Dictionary:
	var locked: Dictionary = snapshot.duplicate(true)
	for key in [
		"up_pressed",
		"down_pressed",
		"action_pressed",
		"action_just_pressed",
		"action_just_released",
		"jetpack_pressed",
		"supply_drop_hold_pressed",
		"commando_supply_drop_hold_pressed",
		"mouse_right_pressed",
		"gamepad_supply_hold_pressed",
		"mouse_middle_pressed",
		"mouse_middle_just_pressed",
		"firearm_reset_just_pressed",
	]:
		if locked.has(key):
			locked[key] = false
	locked["power_smash_direction"] = 0
	return locked
