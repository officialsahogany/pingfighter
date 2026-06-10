extends SceneTree

const CommandoEmergencySupplyState := preload("res://scripts/characters/commando_emergency_supply_state.gd")
const CommandoReloadDeliveryState := preload("res://scripts/characters/commando_reload_delivery_state.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var reload_calls := 0
	var reload_round_calls := 0
	var supply_radio_calls := 0

	func play_commando_reload() -> void:
		reload_calls += 1

	func play_commando_pistol_reload_round() -> void:
		reload_round_calls += 1

	func play_commando_supply_radio() -> void:
		supply_radio_calls += 1


class FakeOwner:
	extends RefCounted

	var player_pos: Vector2 = Vector2(380.0, 670.0)
	var player_paddle_width: float = 155.0
	var player_paddle_height: float = 50.0


func _init() -> void:
	_verify_double_tap_starts_delivery_for_permanent_weapon()
	_verify_double_tap_starts_delivery_for_beretta()
	_verify_failure_paths_do_not_spend_or_cooldown()
	_verify_moving_tap_does_not_arm_emergency_supply()
	_verify_round_reset_settles_pending_refill()

	if _failures.is_empty():
		print("commando_emergency_supply_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_double_tap_starts_delivery_for_permanent_weapon() -> void:
	var state: Object = CommandoEmergencySupplyState.new()
	var delivery_state: Object = CommandoReloadDeliveryState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var audio := FakeAudio.new()
	var owner := FakeOwner.new()
	_expect(bool(skill_config.unlock_and_equip_skill("ak47")), "ak47 should equip as a permanent Commando firearm")
	weapon_controller.sync_equipped_permanent(skill_config)
	_expect(bool(weapon_controller.set_current_weapon("ak47")), "ak47 should be selectable after sync")
	for _i in range(5):
		_expect(bool(weapon_controller.consume_current_weapon_ammo(1)), "ak47 ammo should be consumable before refill")
	_expect(bool(weapon_controller.consume_current_weapon_duration(120.0)), "ak47 durability should be consumable before refill")
	_expect(int(weapon_controller.get_current_weapon_data().get("ammo_current", 0)) == 85, "ak47 should start the refill test below max ammo")
	_expect(is_equal_approx(float(weapon_controller.get_current_weapon_data().get("duration_frames", 0.0)), 1680.0), "ak47 should start the refill test below max durability")

	var deps := _deps(skill_config, skill_state, weapon_controller, audio, delivery_state, owner)
	var first: Dictionary = state.update_input(_input(true), 1000, 500.0, deps)
	_expect(not bool(first.get("activated", false)), "first down tap should only arm emergency supply")
	state.update_input(_input(false), 1070, 500.0, deps)
	var second: Dictionary = state.update_input(_input(true), 1200, 500.0, deps)

	_expect(bool(second.get("activated", false)), "second down tap inside the window should activate emergency supply")
	_expect(is_equal_approx(float(second.get("special_gauge", -1.0)), 350.0), "emergency supply should spend 150 gauge")
	_expect(str(second.get("weapon_id", "")) == "ak47", "emergency supply should report the selected firearm")
	_expect(audio.supply_radio_calls == 1, "activation should play the supply radio cue")
	_expect(audio.reload_calls == 0, "reload cue should NOT play until the soldier reaches the player")
	_expect(int(weapon_controller.get_current_weapon_data().get("ammo_current", 0)) == 85, "ammo must stay drained until the soldier delivers the supply")
	_expect(bool(delivery_state.is_active()), "delivery state should be active after activation")
	_expect(skill_state.get_configured_cooldown_remaining("emergency_supply", 1200, skill_config) > 0.0, "successful emergency supply should trigger cooldown immediately")

	_drive_delivery_until_complete(delivery_state, deps)

	_expect(int(weapon_controller.get_current_weapon_data().get("ammo_current", 0)) == 90, "delivery handover should refill the selected permanent weapon to max")
	_expect(is_equal_approx(float(weapon_controller.get_current_weapon_data().get("duration_frames", 0.0)), 1800.0), "delivery handover should refill AK-47 durability to max")
	_expect(audio.reload_calls == 1, "reload cue should play exactly once at handover")


func _verify_double_tap_starts_delivery_for_beretta() -> void:
	var state: Object = CommandoEmergencySupplyState.new()
	var delivery_state: Object = CommandoReloadDeliveryState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var audio := FakeAudio.new()
	var owner := FakeOwner.new()
	_expect(bool(skill_config.unlock_and_equip_skill("commando_pistol")), "Beretta should equip as a permanent Commando firearm")
	weapon_controller.sync_equipped_permanent(skill_config)
	_expect(bool(weapon_controller.set_current_weapon("commando_pistol")), "Beretta should be selectable after sync")
	for _i in range(3):
		_expect(bool(weapon_controller.consume_current_weapon_ammo(1)), "Beretta ammo should be consumable before reload skill")
	_expect(int(weapon_controller.get_current_weapon_data().get("ammo_current", 0)) == 9, "Beretta should start the reload-skill test below max ammo")
	_expect(not bool(weapon_controller.start_current_weapon_reload()), "Beretta should not support fire-input/manual magazine reload")

	var deps := _deps(skill_config, skill_state, weapon_controller, audio, delivery_state, owner)
	var result: Dictionary = _double_tap(state, 1600, 500.0, deps)
	_expect(bool(result.get("activated", false)), "Beretta should accept emergency supply as its reload path")
	_expect(str(result.get("weapon_id", "")) == "commando_pistol", "Beretta reload skill should report the selected firearm")
	_expect(int(weapon_controller.get_current_weapon_data().get("ammo_current", -1)) == 9, "Beretta ammo must stay drained until the soldier delivers the supply")
	_expect(audio.supply_radio_calls == 1, "Beretta reload skill should play the supply radio cue at activation")
	_expect(audio.reload_calls == 0, "Beretta reload cue should NOT play until the soldier reaches the player")
	_expect(skill_state.get_configured_cooldown_remaining("emergency_supply", 1800, skill_config) > 0.0, "Beretta reload skill should trigger cooldown immediately")

	_drive_delivery_until_complete(delivery_state, deps)

	var weapon: Dictionary = weapon_controller.get_current_weapon_data()
	_expect(int(weapon.get("ammo_current", 0)) == 12, "Beretta delivery handover should refill the 12-round magazine")
	_expect(int(weapon.get("magazines_current", -1)) == 0, "Beretta should not gain spare magazines from reload skill")
	_expect(not bool(weapon.get("reloading", false)), "Beretta reload skill should refill immediately at handover without a magazine timer")
	_expect(str(weapon.get("ammo_text", "")) == "탄약 12/12", "Beretta ammo text should stay ammo-only after handover")
	_expect(audio.reload_calls == 1, "Beretta delivery handover should play the shared reload cue once")
	_expect(audio.reload_round_calls == 0, "Beretta delivery handover should not fall back to the pistol per-round cue when shared reload exists")


func _verify_failure_paths_do_not_spend_or_cooldown() -> void:
	var skill_config: Object = CommandoSkillConfig.new()
	var weapon_controller: Object = CommandoWeaponController.new()

	var pistol_state: Object = CommandoEmergencySupplyState.new()
	var pistol_delivery: Object = CommandoReloadDeliveryState.new()
	var pistol_skill_state: Object = CommandoSkillState.new()
	var audio := FakeAudio.new()
	var owner := FakeOwner.new()
	_expect(bool(weapon_controller.consume_current_weapon_ammo(1)), "base pistol ammo should be consumable before full reload")
	_expect(bool(weapon_controller.consume_current_weapon_ammo(1)), "base pistol should be missing two rounds before reload")
	var pistol_deps := _deps(skill_config, pistol_skill_state, weapon_controller, audio, pistol_delivery, owner)
	var pistol_result: Dictionary = _double_tap(pistol_state, 2000, 500.0, pistol_deps)
	_expect(bool(pistol_result.get("activated", false)), "base pistol should accept emergency supply now")
	_expect(str(pistol_result.get("weapon_id", "")) == "pistol", "base pistol reload should report the base weapon id")
	_expect(is_equal_approx(float(pistol_result.get("special_gauge", -1.0)), 350.0), "base pistol reload should spend 150 gauge")
	_expect(int(weapon_controller.get_current_weapon_data().get("ammo_current", -1)) == 3, "base pistol must stay drained until the soldier delivers the supply")
	_expect(audio.supply_radio_calls == 1, "base pistol reload should play the supply radio cue at activation")
	_expect(audio.reload_calls == 0, "base pistol reload cue should NOT play until the soldier reaches the player")
	_expect(pistol_skill_state.get_configured_cooldown_remaining("emergency_supply", 2200, skill_config) > 0.0, "base pistol reload should trigger cooldown immediately")

	_drive_delivery_until_complete(pistol_delivery, pistol_deps)
	_expect(int(weapon_controller.get_current_weapon_data().get("ammo_current", -1)) == 5, "base pistol delivery handover should refill to max ammo")
	_expect(audio.reload_calls == 1, "base pistol delivery handover should play the shared reload cue")

	var rental_state: Object = CommandoEmergencySupplyState.new()
	var rental_delivery: Object = CommandoReloadDeliveryState.new()
	var rental_skill_state: Object = CommandoSkillState.new()
	var rental_controller: Object = CommandoWeaponController.new()
	_expect(bool(rental_controller.add_rental_weapon("bazooka", 1)), "rental bazooka should be grantable")
	_expect(bool(rental_controller.set_current_weapon("bazooka")), "rental bazooka should be selectable")
	var rental_deps := _deps(skill_config, rental_skill_state, rental_controller, null, rental_delivery, owner)
	var rental_result: Dictionary = _double_tap(rental_state, 3000, 500.0, rental_deps)
	_expect(not bool(rental_result.get("activated", true)), "rental weapon should reject emergency supply")
	_expect(str(rental_result.get("failure_reason", "")) == "rental_weapon", "rental failure should be explicit")
	_expect(is_equal_approx(float(rental_result.get("special_gauge", -1.0)), 500.0), "rental failure should not spend gauge")
	_expect(is_equal_approx(rental_skill_state.get_configured_cooldown_remaining("emergency_supply", 3200, skill_config), 0.0), "rental failure should not trigger cooldown")
	_expect(not bool(rental_delivery.is_active()), "rental rejection should not start the delivery")


func _verify_moving_tap_does_not_arm_emergency_supply() -> void:
	var state: Object = CommandoEmergencySupplyState.new()
	var delivery_state: Object = CommandoReloadDeliveryState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var owner := FakeOwner.new()
	_expect(bool(skill_config.unlock_and_equip_skill("net_gun")), "net gun should equip as a permanent firearm")
	weapon_controller.sync_equipped_permanent(skill_config)
	_expect(bool(weapon_controller.set_current_weapon("net_gun")), "net gun should be selectable")
	_expect(bool(weapon_controller.consume_current_weapon_ammo(1)), "net gun ammo should be consumable")

	var deps := _deps(skill_config, skill_state, weapon_controller, null, delivery_state, owner)
	state.update_input(_input(true, true), 4000, 500.0, deps)
	state.update_input(_input(false), 4070, 500.0, deps)
	var result: Dictionary = state.update_input(_input(true), 4200, 500.0, deps)
	_expect(not bool(result.get("activated", true)), "a moving first tap should not arm the second tap")
	_expect(int(weapon_controller.get_current_weapon_data().get("ammo_current", -1)) == 3, "blocked moving tap should not refill ammo")
	_expect(is_equal_approx(float(result.get("special_gauge", -1.0)), 500.0), "blocked moving tap should not spend gauge")
	_expect(not bool(delivery_state.is_active()), "blocked moving tap should not start the delivery")


func _verify_round_reset_settles_pending_refill() -> void:
	# If the round resets mid-delivery, the player has already paid gauge + cooldown,
	# so the pending refill must be honored on cleanup to protect the resource spend.
	var state: Object = CommandoEmergencySupplyState.new()
	var delivery_state: Object = CommandoReloadDeliveryState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var audio := FakeAudio.new()
	var owner := FakeOwner.new()
	_expect(bool(skill_config.unlock_and_equip_skill("bazooka")), "bazooka should equip as a permanent firearm")
	weapon_controller.sync_equipped_permanent(skill_config)
	_expect(bool(weapon_controller.set_current_weapon("bazooka")), "bazooka should be selectable")
	_expect(bool(weapon_controller.consume_current_weapon_ammo(1)), "bazooka ammo should be consumable before delivery test")
	var deps := _deps(skill_config, skill_state, weapon_controller, audio, delivery_state, owner)
	var result: Dictionary = _double_tap(state, 5000, 500.0, deps)
	_expect(bool(result.get("activated", false)), "bazooka reload should activate")
	_expect(bool(delivery_state.is_active()), "delivery should be active before round reset")

	delivery_state.reset()
	_expect(not bool(delivery_state.is_active()), "delivery should be inactive after reset")
	var weapon: Dictionary = weapon_controller.get_current_weapon_data()
	var ammo_max: int = int(weapon.get("ammo_max", 0))
	_expect(int(weapon.get("ammo_current", 0)) == ammo_max, "interrupted delivery should still refund the refill the player paid for")


func _drive_delivery_until_complete(delivery_state: Object, deps: Dictionary) -> void:
	var context: Dictionary = {
		"player_pos": Vector2(380.0, 670.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}
	var iterations: int = 0
	while delivery_state.is_active() and iterations < 600:
		delivery_state.update_effects(0.05, context, deps)
		iterations += 1
	_expect(not delivery_state.is_active(), "delivery should complete within the iteration budget")


func _double_tap(state: Object, start_msec: int, special_gauge: float, deps: Dictionary) -> Dictionary:
	state.update_input(_input(true), start_msec, special_gauge, deps)
	state.update_input(_input(false), start_msec + 70, special_gauge, deps)
	return state.update_input(_input(true), start_msec + 200, special_gauge, deps)


func _deps(
	skill_config: Object,
	skill_state: Object,
	weapon_controller: Object,
	audio: Object = null,
	delivery_state: Object = null,
	owner: Object = null
) -> Dictionary:
	var deps := {
		"skill_config": skill_config,
		"skill_state": skill_state,
		"commando_weapon_controller": weapon_controller,
	}
	if audio != null:
		deps["audio"] = audio
	if delivery_state != null:
		deps["commando_reload_delivery_state"] = delivery_state
	if owner != null:
		deps["owner"] = owner
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
