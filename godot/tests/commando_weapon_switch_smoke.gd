extends SceneTree

const CommandoInputReader := preload("res://scripts/characters/commando_input_reader.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	var controller: Object

	func get_instance(key: String) -> Object:
		if key == "commando_weapon_controller":
			return controller
		return null


class FakeOwner:
	extends RefCounted

	var selected_character_type := "soldier"


func _init() -> void:
	_verify_wheel_switches_only_for_commando()

	if _failures.is_empty():
		print("commando_weapon_switch_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_wheel_switches_only_for_commando() -> void:
	var controller: Object = CommandoWeaponController.new()
	controller.switch_debounce_msec = 0
	controller.unlock_permanent_weapon("net_gun", true)
	controller.unlock_permanent_weapon("ak47", true)
	controller.set_current_weapon("pistol")

	var registry := FakeRegistry.new()
	registry.controller = controller
	var reader: Object = CommandoInputReader.new()
	var owner := FakeOwner.new()

	var down_event := _wheel_event(MOUSE_BUTTON_WHEEL_DOWN)
	_expect(bool(reader.handle_weapon_switch_event(down_event, owner, registry)), "wheel down should be consumed for Commando")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "net_gun", "wheel down should select the next weapon")

	var up_event := _wheel_event(MOUSE_BUTTON_WHEEL_UP)
	_expect(bool(reader.handle_weapon_switch_event(up_event, owner, registry)), "wheel up should be consumed for Commando")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "pistol", "wheel up should select the previous weapon")

	owner.selected_character_type = "viper"
	_expect(not bool(reader.handle_weapon_switch_event(down_event, owner, registry)), "wheel input should not be consumed for non-Commando characters")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "pistol", "non-Commando wheel input should not switch weapons")

	owner.selected_character_type = "commando"
	_expect(bool(reader.handle_weapon_switch_event(down_event, owner, registry)), "commando alias should also consume wheel switching")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "net_gun", "commando alias should switch weapons")

	var middle_event := _wheel_event(MOUSE_BUTTON_MIDDLE)
	_expect(bool(reader.handle_weapon_switch_event(middle_event, owner, registry)), "middle mouse should be consumed for Commando firearm reset")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "pistol", "middle mouse should return from another firearm to the base pistol")


func _wheel_event(button_index: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	@warning_ignore("int_as_enum_without_cast")
	event.button_index = button_index
	event.pressed = true
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
