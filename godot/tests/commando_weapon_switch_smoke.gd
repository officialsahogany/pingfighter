extends SceneTree

const CommandoInputReader := preload("res://scripts/characters/commando_input_reader.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	var controller: Object
	var audio: Object

	func get_instance(key: String) -> Object:
		if key == "commando_weapon_controller":
			return controller
		if key == "game_audio":
			return audio
		return null


class FakeAudio:
	extends RefCounted

	var weapon_change_calls := 0

	func play_commando_weapon_change() -> void:
		weapon_change_calls += 1


class FakeOwner:
	extends RefCounted

	var selected_character_type := "soldier"


func _init() -> void:
	_verify_wheel_switches_only_for_commando()
	_verify_gamepad_switches_and_reset_for_commando()
	_verify_gamepad_supply_hold_snapshot()

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
	var audio := FakeAudio.new()
	registry.audio = audio
	var reader: Object = CommandoInputReader.new()
	var owner := FakeOwner.new()

	var down_event := _wheel_event(MOUSE_BUTTON_WHEEL_DOWN)
	_expect(bool(reader.handle_weapon_switch_event(down_event, owner, registry)), "wheel down should be consumed for Commando")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "net_gun", "wheel down should select the next weapon")
	_expect(audio.weapon_change_calls == 1, "wheel down should play weapon.wav when the active firearm changes")

	var up_event := _wheel_event(MOUSE_BUTTON_WHEEL_UP)
	_expect(bool(reader.handle_weapon_switch_event(up_event, owner, registry)), "wheel up should be consumed for Commando")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "pistol", "wheel up should select the previous weapon")
	_expect(audio.weapon_change_calls == 2, "wheel up should play weapon.wav when the active firearm changes")

	owner.selected_character_type = "viper"
	_expect(not bool(reader.handle_weapon_switch_event(down_event, owner, registry)), "wheel input should not be consumed for non-Commando characters")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "pistol", "non-Commando wheel input should not switch weapons")
	_expect(audio.weapon_change_calls == 2, "non-Commando wheel input should not play the weapon-change cue")

	owner.selected_character_type = "commando"
	_expect(bool(reader.handle_weapon_switch_event(down_event, owner, registry)), "commando alias should also consume wheel switching")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "net_gun", "commando alias should switch weapons")
	_expect(audio.weapon_change_calls == 3, "commando alias switch should play weapon.wav")

	var middle_event := _wheel_event(MOUSE_BUTTON_MIDDLE)
	_expect(bool(reader.handle_weapon_switch_event(middle_event, owner, registry)), "middle mouse should be consumed for Commando firearm reset")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "pistol", "middle mouse should return from another firearm to the base pistol")
	_expect(audio.weapon_change_calls == 4, "middle mouse reset should play weapon.wav only when it changes the firearm")
	_expect(bool(reader.handle_weapon_switch_event(middle_event, owner, registry)), "middle mouse should still be consumed while already on the base pistol")
	_expect(audio.weapon_change_calls == 4, "middle mouse on the current base pistol should not replay weapon.wav")


func _verify_gamepad_switches_and_reset_for_commando() -> void:
	var controller: Object = CommandoWeaponController.new()
	controller.switch_debounce_msec = 0
	controller.unlock_permanent_weapon("net_gun", true)
	controller.unlock_permanent_weapon("ak47", true)
	controller.set_current_weapon("pistol")

	var registry := FakeRegistry.new()
	registry.controller = controller
	var audio := FakeAudio.new()
	registry.audio = audio
	var reader: Object = CommandoInputReader.new()
	var owner := FakeOwner.new()

	_expect(bool(reader.handle_weapon_switch_event(_button_event(JOY_BUTTON_LEFT_STICK), owner, registry)), "L3 should cycle Commando firearms forward")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "net_gun", "L3 should select the next firearm")
	_expect(audio.weapon_change_calls == 1, "L3 cycle should play weapon.wav")
	_expect(bool(reader.handle_weapon_switch_event(_button_event(JOY_BUTTON_LEFT_STICK), owner, registry)), "L3 should keep cycling Commando firearms forward")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "ak47", "second L3 press should select the next firearm")
	_expect(audio.weapon_change_calls == 2, "second L3 cycle should play weapon.wav")

	controller.set_current_weapon("ak47")
	_expect(not bool(reader.handle_weapon_switch_event(_axis_event(JOY_AXIS_RIGHT_Y, 0.85), owner, registry)), "right-stick down should be ignored for Commando firearms")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "ak47", "right-stick motion should not change firearms")
	_expect(not bool(reader.handle_weapon_switch_event(_button_event(JOY_BUTTON_RIGHT_STICK), owner, registry)), "right-stick click should be ignored for Commando firearms")
	_expect(str(controller.get_snapshot().get("current_weapon_id", "")) == "ak47", "right-stick click should not reset firearms")
	_expect(audio.weapon_change_calls == 2, "ignored right-stick input should not play weapon.wav")


func _verify_gamepad_supply_hold_snapshot() -> void:
	var snapshot: Dictionary = CommandoInputReader.with_supply_drop_hold({"down_pressed": false}, false, true)
	_expect(bool(snapshot.get("supply_drop_hold_pressed", false)), "gamepad supply hold should feed the shared supply-drop hold key")
	_expect(bool(snapshot.get("commando_supply_drop_hold_pressed", false)), "gamepad supply hold should feed the Commando alias key")
	_expect(bool(snapshot.get("gamepad_supply_hold_pressed", false)), "snapshot should expose the raw gamepad supply hold key")


func _wheel_event(button_index: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	@warning_ignore("int_as_enum_without_cast")
	event.button_index = button_index
	event.pressed = true
	return event


func _button_event(button_index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	return event


func _axis_event(axis: JoyAxis, axis_value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
