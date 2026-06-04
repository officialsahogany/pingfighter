extends RefCounted

var source_reader: Object = null
var stage3_boss_skill_state: Object = null
var status_effect_state: Object = null


func configure(input_reader: Object, skill_state: Object, shared_status_state: Object = null) -> Object:
	source_reader = input_reader
	stage3_boss_skill_state = skill_state
	status_effect_state = shared_status_state
	return self


func get_snapshot() -> Dictionary:
	var snapshot := _read_source_snapshot()
	if _is_player_stun_active():
		return _lock_player_stun_input(snapshot)
	if not _is_curse_reverse_active():
		return snapshot
	return _reverse_horizontal_input(snapshot)


func _read_source_snapshot() -> Dictionary:
	if source_reader == null or not source_reader.has_method("get_snapshot"):
		return {}
	var value: Variant = source_reader.get_snapshot()
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _is_curse_reverse_active() -> bool:
	if status_effect_state != null:
		if status_effect_state.has_method("is_player_reverse_active") and bool(status_effect_state.is_player_reverse_active()):
			return true
		if status_effect_state.has_method("has_status") and bool(status_effect_state.has_status("player", "reverse")):
			return true
	if stage3_boss_skill_state == null:
		return false
	if stage3_boss_skill_state.has_method("is_curse_reverse_active"):
		return bool(stage3_boss_skill_state.is_curse_reverse_active())
	if stage3_boss_skill_state.has_method("get_snapshot"):
		var snapshot: Variant = stage3_boss_skill_state.get_snapshot()
		if snapshot is Dictionary:
			return bool(snapshot.get("stage3_curse_reverse_active", false)) or float(snapshot.get("stage3_curse_reverse_ratio", 0.0)) > 0.0
	return false


func _is_player_stun_active() -> bool:
	if status_effect_state == null:
		return false
	if status_effect_state.has_method("is_player_stun_active") and bool(status_effect_state.is_player_stun_active()):
		return true
	if status_effect_state.has_method("has_status") and bool(status_effect_state.has_status("player", "stun")):
		return true
	if status_effect_state.has_method("get_player_control_context"):
		var context: Variant = status_effect_state.get_player_control_context()
		if context is Dictionary:
			return bool(context.get("player_stun_active", false)) or float(context.get("player_stun_ratio", 0.0)) > 0.0
	return false


func _lock_player_stun_input(snapshot: Dictionary) -> Dictionary:
	var locked: Dictionary = snapshot.duplicate(true)
	for key in [
		"left_pressed",
		"right_pressed",
		"up_pressed",
		"down_pressed",
		"action_pressed",
		"action_just_pressed",
		"action_just_released",
		"jetpack_pressed",
		"supply_drop_hold_pressed",
		"commando_supply_drop_hold_pressed",
		"mouse_right_pressed",
		"mouse_right_just_pressed",
		"gamepad_supply_hold_pressed",
		"mouse_middle_pressed",
		"mouse_middle_just_pressed",
		"firearm_reset_just_pressed",
	]:
		if locked.has(key):
			locked[key] = false
	locked["direction"] = 0.0
	locked["power_smash_direction"] = 0
	locked["player_stun_active"] = true
	locked["status_player_stun_active"] = true
	return locked


func _reverse_horizontal_input(snapshot: Dictionary) -> Dictionary:
	var reversed_snapshot: Dictionary = snapshot.duplicate(true)
	var left_pressed: bool = bool(snapshot.get("left_pressed", false))
	var right_pressed: bool = bool(snapshot.get("right_pressed", false))
	reversed_snapshot["left_pressed"] = right_pressed
	reversed_snapshot["right_pressed"] = left_pressed
	reversed_snapshot["direction"] = _get_horizontal_direction(right_pressed, left_pressed, float(snapshot.get("direction", 0.0)))
	if snapshot.has("power_smash_direction"):
		reversed_snapshot["power_smash_direction"] = -int(snapshot.get("power_smash_direction", 0))
	return reversed_snapshot


func _get_horizontal_direction(left_pressed: bool, right_pressed: bool, fallback_direction: float) -> float:
	var direction := 0.0
	if left_pressed:
		direction -= 1.0
	if right_pressed:
		direction += 1.0
	if direction != 0.0 or left_pressed != right_pressed:
		return direction
	return -fallback_direction
