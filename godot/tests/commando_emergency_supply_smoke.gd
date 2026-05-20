extends SceneTree

const CommandoEmergencySupplyState := preload("res://scripts/characters/commando_emergency_supply_state.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var reload_round_calls := 0

	func play_commando_pistol_reload_round() -> void:
		reload_round_calls += 1


func _init() -> void:
	_verify_double_tap_refills_selected_permanent_weapon()
	_verify_failure_paths_do_not_spend_or_cooldown()
	_verify_moving_tap_does_not_arm_emergency_supply()

	if _failures.is_empty():
		print("commando_emergency_supply_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_double_tap_refills_selected_permanent_weapon() -> void:
	var state: Object = CommandoEmergencySupplyState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	_expect(bool(skill_config.unlock_and_equip_skill("ak47")), "ak47 should equip as a permanent Commando firearm")
	weapon_controller.sync_equipped_permanent(skill_config)
	_expect(bool(weapon_controller.set_current_weapon("ak47")), "ak47 should be selectable after sync")
	for _i in range(5):
		_expect(bool(weapon_controller.consume_current_weapon_ammo(1)), "ak47 ammo should be consumable before refill")
	_expect(bool(weapon_controller.consume_current_weapon_duration(120.0)), "ak47 durability should be consumable before refill")
	_expect(int(weapon_controller.get_current_weapon_data().get("ammo_current", 0)) == 55, "ak47 should start the refill test below max ammo")
	_expect(is_equal_approx(float(weapon_controller.get_current_weapon_data().get("duration_frames", 0.0)), 1680.0), "ak47 should start the refill test below max durability")

	var deps := _deps(skill_config, skill_state, weapon_controller)
	var first: Dictionary = state.update_input(_input(true), 1000, 500.0, deps)
	_expect(not bool(first.get("activated", false)), "first down tap should only arm emergency supply")
	state.update_input(_input(false), 1070, 500.0, deps)
	var second: Dictionary = state.update_input(_input(true), 1200, 500.0, deps)

	_expect(bool(second.get("activated", false)), "second down tap inside the window should activate emergency supply")
	_expect(is_equal_approx(float(second.get("special_gauge", -1.0)), 350.0), "emergency supply should spend 150 gauge")
	_expect(str(second.get("weapon_id", "")) == "ak47", "emergency supply should report the selected firearm")
	_expect(int(weapon_controller.get_current_weapon_data().get("ammo_current", 0)) == 60, "emergency supply should refill the selected permanent weapon to max")
	_expect(is_equal_approx(float(weapon_controller.get_current_weapon_data().get("duration_frames", 0.0)), 1800.0), "emergency supply should refill AK-47 durability to max")
	_expect(skill_state.get_configured_cooldown_remaining("emergency_supply", 1200, skill_config) > 0.0, "successful emergency supply should trigger cooldown")


func _verify_failure_paths_do_not_spend_or_cooldown() -> void:
	var skill_config: Object = CommandoSkillConfig.new()
	var weapon_controller: Object = CommandoWeaponController.new()

	var pistol_state: Object = CommandoEmergencySupplyState.new()
	var pistol_skill_state: Object = CommandoSkillState.new()
	var audio := FakeAudio.new()
	_expect(bool(weapon_controller.consume_current_weapon_ammo(1)), "base pistol ammo should be consumable before one-round reload")
	_expect(bool(weapon_controller.consume_current_weapon_ammo(1)), "base pistol should be missing two rounds before reload")
	var pistol_result: Dictionary = _double_tap(pistol_state, 2000, 500.0, _deps(skill_config, pistol_skill_state, weapon_controller, audio))
	_expect(bool(pistol_result.get("activated", false)), "base pistol should accept emergency supply now")
	_expect(str(pistol_result.get("weapon_id", "")) == "pistol", "base pistol reload should report the base weapon id")
	_expect(is_equal_approx(float(pistol_result.get("special_gauge", -1.0)), 350.0), "base pistol reload should spend 150 gauge")
	_expect(int(weapon_controller.get_current_weapon_data().get("ammo_current", -1)) == 3, "base pistol reload should restore exactly one bullet")
	_expect(audio.reload_round_calls == 1, "base pistol one-round reload should play the reload-round cue")
	_expect(pistol_skill_state.get_configured_cooldown_remaining("emergency_supply", 2200, skill_config) > 0.0, "base pistol reload should trigger cooldown")

	var rental_state: Object = CommandoEmergencySupplyState.new()
	var rental_skill_state: Object = CommandoSkillState.new()
	var rental_controller: Object = CommandoWeaponController.new()
	_expect(bool(rental_controller.add_rental_weapon("bazooka", 1)), "rental bazooka should be grantable")
	_expect(bool(rental_controller.set_current_weapon("bazooka")), "rental bazooka should be selectable")
	var rental_result: Dictionary = _double_tap(rental_state, 3000, 500.0, _deps(skill_config, rental_skill_state, rental_controller))
	_expect(not bool(rental_result.get("activated", true)), "rental weapon should reject emergency supply")
	_expect(str(rental_result.get("failure_reason", "")) == "rental_weapon", "rental failure should be explicit")
	_expect(is_equal_approx(float(rental_result.get("special_gauge", -1.0)), 500.0), "rental failure should not spend gauge")
	_expect(is_equal_approx(rental_skill_state.get_configured_cooldown_remaining("emergency_supply", 3200, skill_config), 0.0), "rental failure should not trigger cooldown")


func _verify_moving_tap_does_not_arm_emergency_supply() -> void:
	var state: Object = CommandoEmergencySupplyState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	_expect(bool(skill_config.unlock_and_equip_skill("net_gun")), "net gun should equip as a permanent firearm")
	weapon_controller.sync_equipped_permanent(skill_config)
	_expect(bool(weapon_controller.set_current_weapon("net_gun")), "net gun should be selectable")
	_expect(bool(weapon_controller.consume_current_weapon_ammo(1)), "net gun ammo should be consumable")

	var deps := _deps(skill_config, skill_state, weapon_controller)
	state.update_input(_input(true, true), 4000, 500.0, deps)
	state.update_input(_input(false), 4070, 500.0, deps)
	var result: Dictionary = state.update_input(_input(true), 4200, 500.0, deps)
	_expect(not bool(result.get("activated", true)), "a moving first tap should not arm the second tap")
	_expect(int(weapon_controller.get_current_weapon_data().get("ammo_current", -1)) == 2, "blocked moving tap should not refill ammo")
	_expect(is_equal_approx(float(result.get("special_gauge", -1.0)), 500.0), "blocked moving tap should not spend gauge")


func _double_tap(state: Object, start_msec: int, special_gauge: float, deps: Dictionary) -> Dictionary:
	state.update_input(_input(true), start_msec, special_gauge, deps)
	state.update_input(_input(false), start_msec + 70, special_gauge, deps)
	return state.update_input(_input(true), start_msec + 200, special_gauge, deps)


func _deps(skill_config: Object, skill_state: Object, weapon_controller: Object, audio: Object = null) -> Dictionary:
	var deps := {
		"skill_config": skill_config,
		"skill_state": skill_state,
		"commando_weapon_controller": weapon_controller,
	}
	if audio != null:
		deps["audio"] = audio
	return deps


func _input(down_pressed: bool, left_pressed: bool = false, right_pressed: bool = false) -> Dictionary:
	return {
		"down_pressed": down_pressed,
		"left_pressed": left_pressed,
		"right_pressed": right_pressed,
		"action_pressed": false,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
