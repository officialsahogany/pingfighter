extends "res://scripts/characters/smasher_input_reader.gd"


func get_snapshot() -> Dictionary:
	return with_supply_drop_mouse_hold(super.get_snapshot(), Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))


static func with_supply_drop_mouse_hold(snapshot: Dictionary, right_mouse_pressed: bool) -> Dictionary:
	var merged: Dictionary = snapshot.duplicate(true)
	var supply_hold_pressed: bool = bool(merged.get("down_pressed", false)) or right_mouse_pressed
	merged["supply_drop_hold_pressed"] = supply_hold_pressed
	merged["commando_supply_drop_hold_pressed"] = supply_hold_pressed
	merged["mouse_right_pressed"] = right_mouse_pressed
	return merged


func handle_weapon_switch_event(event: InputEvent, owner: Object, registry: Object) -> bool:
	if not _is_commando_owner(owner):
		return false
	if not (event is InputEventMouseButton):
		return false
	var mouse_event: InputEventMouseButton = event
	if not mouse_event.pressed:
		return false
	var direction := 0
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		direction = -1
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		direction = 1
	elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
		return _select_base_weapon(registry)
	else:
		return false
	var weapon_controller: Object = _get_instance(registry, "commando_weapon_controller")
	if weapon_controller == null or not weapon_controller.has_method("cycle_weapon"):
		return false
	weapon_controller.cycle_weapon(direction)
	return true


func _select_base_weapon(registry: Object) -> bool:
	var weapon_controller: Object = _get_instance(registry, "commando_weapon_controller")
	if weapon_controller == null:
		return false
	if weapon_controller.has_method("select_base_weapon"):
		return bool(weapon_controller.select_base_weapon())
	if weapon_controller.has_method("set_current_weapon"):
		return bool(weapon_controller.set_current_weapon("pistol"))
	return false


func _is_commando_owner(owner: Object) -> bool:
	if owner == null:
		return false
	var character_type: String = str(owner.get("selected_character_type")).strip_edges().to_lower()
	return character_type == "soldier" or character_type == "commando"


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
