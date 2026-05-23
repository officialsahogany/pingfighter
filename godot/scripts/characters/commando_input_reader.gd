extends "res://scripts/characters/smasher_input_reader.gd"


func get_snapshot() -> Dictionary:
	return with_supply_drop_hold(
		super.get_snapshot(),
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT),
		GamepadInput.is_supply_hold_pressed()
	)


static func with_supply_drop_mouse_hold(snapshot: Dictionary, right_mouse_pressed: bool) -> Dictionary:
	return with_supply_drop_hold(snapshot, right_mouse_pressed, false)


static func with_supply_drop_hold(
	snapshot: Dictionary,
	right_mouse_pressed: bool,
	gamepad_supply_hold_pressed: bool
) -> Dictionary:
	var merged: Dictionary = snapshot.duplicate(true)
	var supply_hold_pressed: bool = (
		bool(merged.get("down_pressed", false))
		or right_mouse_pressed
		or gamepad_supply_hold_pressed
	)
	merged["supply_drop_hold_pressed"] = supply_hold_pressed
	merged["commando_supply_drop_hold_pressed"] = supply_hold_pressed
	merged["mouse_right_pressed"] = right_mouse_pressed
	merged["gamepad_supply_hold_pressed"] = gamepad_supply_hold_pressed
	return merged


func handle_weapon_switch_event(event: InputEvent, owner: Object, registry: Object) -> bool:
	if not _is_commando_owner(owner):
		return false
	if _is_horn_strawberry_skill_locked(registry):
		return false
	var direction := 0
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if not mouse_event.pressed:
			return false
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			direction = -1
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			direction = 1
		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			return _select_base_weapon(registry)
		else:
			return false
	elif GamepadInput.is_firearm_reset_event(event):
		return _select_base_weapon(registry)
	else:
		direction = GamepadInput.get_weapon_cycle_direction_event(event)
		if direction == 0:
			return false
	var weapon_controller: Object = _get_instance(registry, "commando_weapon_controller")
	if weapon_controller == null or not weapon_controller.has_method("cycle_weapon"):
		return false
	var previous_weapon_id: String = _get_current_weapon_id(weapon_controller)
	weapon_controller.cycle_weapon(direction)
	var current_weapon_id: String = _get_current_weapon_id(weapon_controller)
	if previous_weapon_id != "" and current_weapon_id != "" and current_weapon_id != previous_weapon_id:
		_play_weapon_change_audio(registry)
	return true


func _select_base_weapon(registry: Object) -> bool:
	var weapon_controller: Object = _get_instance(registry, "commando_weapon_controller")
	if weapon_controller == null:
		return false
	var previous_weapon_id: String = _get_current_weapon_id(weapon_controller)
	var selected := false
	if weapon_controller.has_method("select_base_weapon"):
		selected = bool(weapon_controller.select_base_weapon())
	elif weapon_controller.has_method("set_current_weapon"):
		selected = bool(weapon_controller.set_current_weapon("pistol"))
	if not selected:
		return false
	var current_weapon_id: String = _get_current_weapon_id(weapon_controller)
	if previous_weapon_id != "" and current_weapon_id != "" and current_weapon_id != previous_weapon_id:
		_play_weapon_change_audio(registry)
	return true


func _get_current_weapon_id(weapon_controller: Object) -> String:
	if weapon_controller == null:
		return ""
	if weapon_controller.has_method("get_current_weapon_data"):
		return str(weapon_controller.get_current_weapon_data().get("weapon_id", ""))
	if "current_weapon_id" in weapon_controller:
		return str(weapon_controller.current_weapon_id)
	return ""


func _play_weapon_change_audio(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_commando_weapon_change"):
		audio.play_commando_weapon_change()


func _is_commando_owner(owner: Object) -> bool:
	if owner == null:
		return false
	var character_type: String = str(owner.get("selected_character_type")).strip_edges().to_lower()
	return character_type == "soldier" or character_type == "commando"


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _is_horn_strawberry_skill_locked(registry: Object) -> bool:
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null:
		return false
	if (
		mythic_item_runtime.has_method("is_horn_strawberry_skills_locked")
		and bool(mythic_item_runtime.is_horn_strawberry_skills_locked())
	):
		return true
	if (
		mythic_item_runtime.has_method("is_horn_strawberry_control_locked")
		and bool(mythic_item_runtime.is_horn_strawberry_control_locked())
	):
		return true
	return false
