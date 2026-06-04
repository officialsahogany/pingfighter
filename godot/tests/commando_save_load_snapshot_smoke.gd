extends SceneTree

const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var loop_play_count := 0
	var loop_stop_count := 0

	func play_commando_supply_radio() -> void:
		pass

	func play_commando_supply_aircraft_loop() -> void:
		loop_play_count += 1

	func stop_commando_supply_aircraft_loop() -> void:
		loop_stop_count += 1

	func play_commando_supply_drop() -> void:
		pass

	func play_item_get() -> void:
		pass


func _init() -> void:
	_verify_skill_config_snapshot_round_trip()
	_verify_weapon_snapshot_round_trip()
	_verify_skill_cooldown_snapshot_round_trip()
	_verify_supply_drop_snapshot_round_trip()

	if _failures.is_empty():
		print("commando_save_load_snapshot_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_skill_config_snapshot_round_trip() -> void:
	var config: Object = CommandoSkillConfig.new()
	config.set_runtime_cooldown_multiplier(0.75)
	config.set_item_cooldown_multiplier(0.8)
	config.set_item_skill_slot_bonus(1)
	for skill_name in ["net_gun", "bazooka", "commando_pistol", "ak47"]:
		_expect(config.unlock_and_equip_skill(skill_name), "%s should equip before save" % skill_name)

	var snapshot: Dictionary = config.get_save_snapshot()
	var saved_equipped: Array = _get_array(snapshot.get("equipped_permanent", [])).duplicate()
	saved_equipped.append("unknown_launcher")
	saved_equipped.append("net_gun")
	snapshot["equipped_permanent"] = saved_equipped

	var restored: Object = CommandoSkillConfig.new()
	var restore_result: Dictionary = restored.apply_save_snapshot(snapshot)
	_expect(bool(restore_result.get("restored", false)), "skill config should accept a populated save snapshot")
	_expect(restored.get_equipped_skills() == ["supply_drop", "emergency_supply", "net_gun", "bazooka", "commando_pistol", "ak47"], "skill config should restore equipped shared-slot order with item slot bonus")
	_expect(int(restored.get_shared_slot_capacity()) == 4, "skill config should restore shared slot capacity bonus")
	_expect(is_equal_approx(float(restored.get_cooldown_seconds("supply_drop")), 24.0), "skill config should restore cooldown multipliers")
	_expect(_get_array(restore_result.get("dropped_ids", [])).has("unknown_launcher"), "skill config restore should drop unknown skill ids")
	_expect(_get_array(restore_result.get("dropped_ids", [])).has("net_gun"), "skill config restore should drop duplicate skill ids")

	var weapon_controller: Object = CommandoWeaponController.new()
	weapon_controller.sync_equipped_permanent(restored)
	_expect(weapon_controller.get_weapons() == ["pistol", "net_gun", "bazooka", "commando_pistol", "ak47"], "weapon controller should sync from restored Commando skill config")

	var shrunk_snapshot: Dictionary = config.get_save_snapshot()
	shrunk_snapshot["item_skill_slot_bonus"] = 0
	var shrunk: Object = CommandoSkillConfig.new()
	var shrink_result: Dictionary = shrunk.apply_save_snapshot(shrunk_snapshot)
	_expect(shrunk.get_equipped_skills() == ["supply_drop", "emergency_supply", "net_gun", "bazooka", "commando_pistol"], "skill config restore should trim overflow when saved capacity shrinks")
	_expect(_get_array(shrink_result.get("trimmed_ids", [])).has("ak47"), "skill config restore should report trimmed overflow ids")


func _verify_weapon_snapshot_round_trip() -> void:
	var controller: Object = CommandoWeaponController.new()
	_expect(controller.unlock_permanent_weapon("bazooka", true), "bazooka should unlock before save")
	_expect(controller.unlock_permanent_weapon("ak47", true), "ak47 should unlock before save")
	_expect(controller.unlock_permanent_weapon("commando_pistol", true), "commando_pistol should unlock before save")
	controller.prepare_stage_start(3)

	_expect(controller.set_current_weapon("bazooka"), "bazooka should be selectable before save")
	_spend_current_weapon_ammo(controller, 4, "bazooka should spend down before save")
	_expect(controller.set_current_weapon("ak47"), "ak47 should be selectable before save")
	_spend_current_weapon_ammo(controller, 7, "ak47 should spend bullets before save")
	controller.consume_current_weapon_duration(420.0)
	_expect(controller.set_current_weapon("commando_pistol"), "commando pistol should be selectable before save")
	_spend_current_weapon_ammo(controller, 2, "commando pistol should spend bullets before save")
	_expect(not controller.start_current_weapon_reload(), "Beretta should not start a magazine reload before save")
	_expect(controller.add_rental_weapon("net_gun", 3, 2), "rental net gun should be accepted before save")
	_expect(controller.set_current_weapon("net_gun"), "rental net gun should be selected before save")

	var snapshot: Dictionary = controller.get_save_snapshot()
	(snapshot.get("permanent_owned", {}) as Dictionary)["unknown_launcher"] = {"ammo_current": 99}
	(snapshot.get("rental_weapons", {}) as Dictionary)["pistol"] = {"ammo_current": 99}

	var restored: Object = CommandoWeaponController.new()
	var restore_result: Dictionary = restored.apply_save_snapshot(snapshot)
	_expect(bool(restore_result.get("restored", false)), "weapon controller should accept a populated save snapshot")
	_expect(_get_array(restore_result.get("dropped_ids", [])).has("unknown_launcher"), "weapon restore should drop unknown permanent ids")
	_expect(_get_array(restore_result.get("dropped_ids", [])).has("pistol"), "weapon restore should drop base pistol rentals")
	_expect(str(restored.get_snapshot().get("current_weapon_id", "")) == "net_gun", "selected rental weapon should survive save/load")

	var rental: Dictionary = restored.get_weapon_data("net_gun")
	_expect(str(rental.get("kind", "")) == "rental", "rental kind should survive save/load")
	_expect(int(rental.get("acquired_stage", 0)) == 3, "rental acquired stage should survive save/load")
	_expect(int(rental.get("ammo_current", 0)) == 2, "rental ammo should survive save/load")

	var bazooka: Dictionary = restored.get_weapon_data("bazooka")
	_expect(not bool(bazooka.get("can_fire", true)), "spent permanent bazooka should remain empty after save/load")
	var ak47: Dictionary = restored.get_weapon_data("ak47")
	_expect(int(ak47.get("ammo_current", 0)) == 83, "AK-47 ammo should survive save/load")
	_expect(is_equal_approx(float(ak47.get("duration_frames", 0.0)), 1380.0), "AK-47 duration should survive save/load")
	var pistol: Dictionary = restored.get_weapon_data("commando_pistol")
	_expect(not bool(pistol.get("reloading", false)), "Beretta should not restore a magazine reload state")
	_expect(int(pistol.get("ammo_current", 0)) == 10, "Beretta ammo should survive save/load")
	_expect(int(pistol.get("magazines_current", -1)) == 0, "Beretta spare magazines should stay disabled after save/load")
	_expect(is_equal_approx(float(pistol.get("reload_timer_frames", 0.0)), 0.0), "Beretta reload timer should stay disabled after save/load")

	var same_stage_result: Dictionary = restored.prepare_stage_start(3)
	_expect(not bool(same_stage_result.get("stage_start", true)), "restored prepared stage should prevent duplicate same-stage refill")
	_expect(not bool(restored.get_weapon_data("bazooka").get("can_fire", true)), "same-stage restore should keep spent permanent ammo")
	var next_stage_result: Dictionary = restored.prepare_stage_start(4)
	_expect(bool(next_stage_result.get("stage_start", false)), "next stage should still run after restore")
	_expect(not restored.get_weapons().has("net_gun"), "next stage should clear restored older rentals")
	_expect(not bool(restored.get_weapon_data("bazooka").get("can_fire", true)), "next stage should preserve restored spent permanent ammo")
	var next_stage_ak47: Dictionary = restored.get_weapon_data("ak47")
	_expect(int(next_stage_ak47.get("ammo_current", 0)) == 83, "next stage should preserve restored AK-47 ammo")
	_expect(is_equal_approx(float(next_stage_ak47.get("duration_frames", 0.0)), 1380.0), "next stage should preserve restored AK-47 durability")


func _verify_skill_cooldown_snapshot_round_trip() -> void:
	var skill_state: Object = CommandoSkillState.new()
	skill_state.trigger_cooldown("supply_drop", 1000, 40.0)
	skill_state.update_activation_state("supply_drop", true, 1200)
	skill_state.pause_cooldowns(5000)

	var restored: Object = CommandoSkillState.new()
	var restore_result: Dictionary = restored.apply_save_snapshot(skill_state.get_save_snapshot())
	_expect(bool(restore_result.get("restored", false)), "skill state should accept a populated save snapshot")
	_expect(is_equal_approx(float(restored.get_cooldown_remaining("supply_drop", 8000, 40.0)), 0.9), "paused cooldown remaining should survive save/load")
	_expect(bool(restored.get_was_active().get("supply_drop", false)), "skill active flag should survive save/load")
	_expect(int(restored.get_activation_msec().get("supply_drop", 0)) == 1200, "skill activation time should survive save/load")
	restored.resume_cooldowns(9000)
	_expect(is_equal_approx(float(restored.get_cooldown_remaining("supply_drop", 9000, 40.0)), 0.9), "resumed cooldown should preserve paused duration after restore")


func _verify_supply_drop_snapshot_round_trip() -> void:
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var supply_state: Object = CommandoSupplyDropState.new()
	var audio := FakeAudio.new()
	var deps := {
		"audio": audio,
		"commando_weapon_controller": weapon_controller,
		"commando_supply_drop_payload_count": 2,
		"commando_supply_drop_forced_payloads": [
			{"type": "rental_weapon", "weapon_id": "net_gun"},
			{"type": "field_item", "item_id": "ammo_box"},
		],
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"commando_supply_drop_payload_delays": [1.15, 0.28],
		"current_stage": 3,
	}

	var activate_result: Dictionary = supply_state.update_input(
		{"down_pressed": true, "action_pressed": true},
		1.0,
		500.0,
		skill_config,
		skill_state,
		deps
	)
	_expect(bool(activate_result.get("activated", false)), "supply drop should activate before save")
	_expect(audio.loop_play_count == 1, "supply activation should start aircraft loop before save")
	supply_state.update(0.35, deps)
	var snapshot: Dictionary = supply_state.get_save_snapshot()

	var restored_audio := FakeAudio.new()
	var restored: Object = CommandoSupplyDropState.new()
	var restore_result: Dictionary = restored.apply_save_snapshot(snapshot, {"audio": restored_audio})
	_expect(bool(restore_result.get("restored", false)), "supply drop should accept a populated save snapshot")
	_expect(restored_audio.loop_play_count == 1, "restoring active supply drop should restart aircraft loop")
	var restored_snapshot: Dictionary = restored.get_snapshot()
	_expect(bool(restored_snapshot.get("active", false)), "active aircraft state should survive save/load")
	_expect(_get_array(restored_snapshot.get("pending_drops", [])).size() == 2, "pending payload queue should survive save/load")
	_expect(_get_vector2(restored_snapshot.get("aircraft_pos", Vector2.ZERO), Vector2.ZERO).distance_to(_get_vector2(snapshot.get("aircraft_pos", Vector2.ZERO), Vector2.ZERO)) < 0.01, "aircraft position should survive save/load")

	deps["audio"] = restored_audio
	var first_result: Dictionary = restored.update(3.85, deps)
	_expect(bool(first_result.get("drop_resolved", false)), "restored supply drop should continue resolving payloads")
	_expect(str(first_result.get("drop", {}).get("weapon_id", "")) == "net_gun", "restored first payload should preserve its weapon id")
	_expect(_get_array(restored.get_snapshot().get("collectible_drops", [])).size() == 1, "resolved restored payload should become collectible")

	var pickup_restored: Object = CommandoSupplyDropState.new()
	pickup_restored.apply_save_snapshot(restored.get_save_snapshot(), {"audio": FakeAudio.new()})
	var pickup_result: Dictionary = _collect_first_drop(pickup_restored, deps)
	_expect(bool(pickup_result.get("pickup_resolved", false)), "restored collectible should remain pickable")
	_expect(weapon_controller.get_weapons().has("net_gun"), "restored collectible pickup should grant the rental weapon")


func _spend_current_weapon_ammo(controller: Object, amount: int, message: String) -> void:
	for _i in range(amount):
		_expect(bool(controller.consume_current_weapon_ammo()), message)


func _collect_first_drop(supply_state: Object, deps: Dictionary) -> Dictionary:
	var drops: Array = _get_array(supply_state.get_snapshot().get("collectible_drops", []))
	if drops.is_empty() or not (drops[0] is Dictionary):
		return {}
	var drop: Dictionary = drops[0]
	var pickup_pos: Vector2 = _get_vector2(drop.get("pos", drop.get("drop_position", Vector2.ZERO)), Vector2.ZERO)
	deps["commando_supply_drop_collision_context"] = {
		"player_pos": pickup_pos - Vector2(35.0, 20.0),
		"player_paddle_size": Vector2(70.0, 40.0),
		"hitbox_padding": 0.0,
	}
	var result: Dictionary = supply_state.update(0.01, deps)
	deps.erase("commando_supply_drop_collision_context")
	return result


func _get_array(value: Variant) -> Array:
	return value if value is Array else []


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
