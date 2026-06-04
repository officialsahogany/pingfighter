extends SceneTree

const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var radio_calls := 0
	var aircraft_play_calls := 0
	var aircraft_stop_calls := 0
	var fire_support_aircraft_play_calls := 0
	var fire_support_aircraft_stop_calls := 0
	var suicide_drone_loop_play_calls := 0
	var suicide_drone_loop_stop_calls := 0
	var drop_calls := 0
	var item_get_calls := 0
	var weapon_change_calls := 0

	func play_commando_supply_radio() -> void:
		radio_calls += 1

	func play_commando_supply_aircraft_loop() -> void:
		aircraft_play_calls += 1

	func stop_commando_supply_aircraft_loop() -> void:
		aircraft_stop_calls += 1

	func play_commando_fire_support_aircraft_loop() -> void:
		fire_support_aircraft_play_calls += 1

	func stop_commando_fire_support_aircraft_loop() -> void:
		fire_support_aircraft_stop_calls += 1

	func play_commando_fire_support_radio() -> void:
		radio_calls += 1

	func play_commando_suicide_drone_launch() -> void:
		suicide_drone_loop_play_calls += 1

	func stop_commando_suicide_drone_loop() -> void:
		suicide_drone_loop_stop_calls += 1

	func play_commando_supply_drop() -> void:
		drop_calls += 1

	func play_item_get() -> void:
		item_get_calls += 1

	func play_commando_weapon_change() -> void:
		weapon_change_calls += 1


func _init() -> void:
	_verify_supply_drop_audio_lifecycle()
	_verify_round_cleanup_preserves_supply_drop_payloads()
	_verify_round_cleanup_clears_fire_support_runtime()
	_verify_round_cleanup_stops_suicide_drone_loop()

	if _failures.is_empty():
		print("commando_supply_drop_audio_cleanup_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_supply_drop_audio_lifecycle() -> void:
	var supply_state: Object = CommandoSupplyDropState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var audio := FakeAudio.new()
	var deps := {
		"audio": audio,
		"commando_weapon_controller": weapon_controller,
		"commando_supply_drop_direction": "right_to_left",
		"commando_supply_drop_forced_payloads": [
			{"type": "rental_weapon", "weapon_id": "net_gun"},
		],
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_payload_delays": [1.15],
		"current_stage": 1,
	}

	var activate_result: Dictionary = supply_state.update_input(
		{"down_pressed": true, "action_pressed": true},
		1.0,
		500.0,
		skill_config,
		skill_state,
		deps
	)
	_expect(bool(activate_result.get("activated", false)), "supply drop should activate from hold input")
	_expect(audio.radio_calls == 1, "activation should play the radio call cue")
	_expect(audio.aircraft_play_calls == 0, "activation should not start the aircraft loop before the Python arrival delay expires")
	_expect(not bool(supply_state.is_aircraft_audio_active()), "pending aircraft arrival should keep aircraft audio inactive")
	var active_snapshot: Dictionary = supply_state.get_snapshot()
	_expect(str(active_snapshot.get("aircraft_direction", "")) == "right_to_left", "snapshot should preserve aircraft direction")
	_expect(not bool(active_snapshot.get("aircraft_spawned", true)), "activation should keep the aircraft hidden until the arrival timer finishes")
	var arrival_delay: float = float(active_snapshot.get("timer", 0.0))
	_expect(arrival_delay >= 1.5 and arrival_delay <= 5.0, "supply aircraft should use the Python 90-300 frame arrival delay")
	var early_result: Dictionary = supply_state.update(max(0.0, arrival_delay - 0.01), deps)
	_expect(not bool(early_result.get("aircraft_spawned", false)), "aircraft should not spawn before the arrival timer expires")
	_expect(audio.aircraft_play_calls == 0, "aircraft loop should stay silent while the plane has not appeared")
	supply_state.update(0.02, deps)
	_expect(audio.aircraft_play_calls == 1, "aircraft loop should start when the delayed aircraft appears")
	_expect(bool(supply_state.is_aircraft_audio_active()), "spawned aircraft should expose active aircraft audio")
	_expect(bool(supply_state.has_visible_effects()), "spawned supply aircraft should be visible")

	var resolve_result: Dictionary = supply_state.update(4.2, deps)
	_expect(bool(resolve_result.get("drop_resolved", false)), "supply drop should resolve after the aircraft delay")
	_expect(audio.aircraft_stop_calls == 0, "payload resolution should not stop the slower Python-speed aircraft loop")
	_expect(audio.drop_calls == 1, "resolution should play the supply drop cue")
	_expect(bool(supply_state.is_aircraft_audio_active()), "resolved payload should keep aircraft audio active until the plane exits")
	_expect(supply_state.get_snapshot().get("drop_effects", []).size() == 1, "resolution should leave a short drop visual effect")
	_expect(supply_state.get_snapshot().get("collectible_drops", []).size() == 1, "resolution should leave a collectible parachute box")

	var collectible: Dictionary = _get_first_collectible(supply_state)
	var pickup_pos: Vector2 = collectible.get("pos", collectible.get("drop_position", Vector2.ZERO))
	deps["commando_supply_drop_collision_context"] = {
		"player_pos": pickup_pos - Vector2(35.0, 20.0),
		"player_paddle_size": Vector2(70.0, 40.0),
		"hitbox_padding": 0.0,
	}
	var pickup_result: Dictionary = supply_state.update(0.01, deps)
	_expect(bool(pickup_result.get("pickup_resolved", false)), "collectible supply payload should be picked up by the player paddle")
	_expect(audio.weapon_change_calls == 1, "rental pickup should play weapon.wav for the newly acquired firearm")
	_expect(audio.item_get_calls == 1, "rental pickup should play the item-get cue")
	deps.erase("commando_supply_drop_collision_context")
	supply_state.update(0.6, deps)
	_expect(bool(supply_state.has_visible_effects()), "aircraft should remain visible after the payload resolves")
	supply_state.update(float(supply_state.get_snapshot().get("flight_duration", 7.8)), deps)
	_expect(audio.aircraft_stop_calls == 1, "aircraft loop should stop when the slower plane exits the screen")
	_expect(not bool(supply_state.is_aircraft_audio_active()), "offscreen aircraft should clear aircraft audio state")
	_expect(not bool(supply_state.has_visible_effects()), "collected payload and offscreen aircraft should leave no visible supply effects")


func _verify_round_cleanup_preserves_supply_drop_payloads() -> void:
	var supply_state: Object = CommandoSupplyDropState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var audio := FakeAudio.new()
	var deps := {
		"audio": audio,
		"commando_weapon_controller": weapon_controller,
		"commando_supply_drop_payload_count": 2,
		"commando_supply_drop_forced_payloads": [
			{"type": "rental_weapon", "weapon_id": "net_gun"},
			{"type": "rental_weapon", "weapon_id": "fire_support"},
		],
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"commando_supply_drop_payload_delays": [1.15, 0.28],
		"current_stage": 1,
	}

	supply_state.update_input(
		{"down_pressed": true, "action_pressed": true},
		1.0,
		500.0,
		skill_config,
		skill_state,
		deps
	)
	_expect(bool(supply_state.is_aircraft_audio_active()), "cleanup setup should have an active aircraft loop")
	var first_result: Dictionary = supply_state.update(4.2, deps)
	_expect(bool(first_result.get("drop_resolved", false)), "cleanup setup should resolve the first payload before round reset")
	_expect(str(first_result.get("drop", {}).get("weapon_id", "")) == "net_gun", "cleanup setup should resolve the first forced payload")

	BallRoundActorCleanup.new().reset_actor_round_state({
		"audio": audio,
		"commando_supply_drop_state": supply_state,
	})
	var snapshot: Dictionary = supply_state.get_snapshot()
	_expect(audio.aircraft_stop_calls >= 1, "round cleanup should stop the supply aircraft loop")
	_expect(not bool(supply_state.is_aircraft_audio_active()), "round cleanup should clear the supply aircraft audio state")
	_expect(bool(snapshot.get("active", false)), "round cleanup should preserve active supply drop state across the point boundary")
	_expect(not snapshot.get("pending_drop", {}).is_empty(), "round cleanup should preserve the pending supply payload")
	_expect(_get_array(snapshot.get("pending_drops", [])).size() == 1, "round cleanup should preserve pending payload queue")
	_expect(_get_array(snapshot.get("collectible_drops", [])).size() == 1, "round cleanup should preserve already dropped parachute boxes")
	_expect(bool(supply_state.has_visible_effects()), "round cleanup should preserve visible supply drop state")

	var second_result: Dictionary = supply_state.update(0.3, deps)
	_expect(bool(second_result.get("drop_resolved", false)), "preserved supply drop should keep resolving after round cleanup")
	_expect(str(second_result.get("drop", {}).get("weapon_id", "")) == "fire_support", "preserved supply drop should resolve the remaining forced payload")


func _verify_round_cleanup_clears_fire_support_runtime() -> void:
	var runtime: Object = CommandoFirearmRuntime.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var audio := FakeAudio.new()
	_expect(bool(skill_config.unlock_and_equip_skill("fire_support")), "fire support should unlock for cleanup setup")
	weapon_controller.sync_equipped_permanent(skill_config)
	_expect(bool(weapon_controller.set_current_weapon("fire_support")), "fire support should be selectable for cleanup setup")
	var deps := {
		"audio": audio,
		"commando_weapon_controller": weapon_controller,
		"skill_state": skill_state,
		"skill_config": skill_config,
	}
	runtime.update_input({"action_pressed": true}, 500.0, {
		"player_pos": Vector2(302.0, 654.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"boss_pos": Vector2(328.0, 62.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"width": 760.0,
		"height": 750.0,
	}, deps)
	for i in range(280):
		runtime.update_effects(1.0, Time.get_ticks_msec(), {}, deps)
		if bool(runtime.is_fire_support_aircraft_audio_active()):
			break
	_expect(audio.fire_support_aircraft_play_calls == 1, "cleanup setup should start the fire-support aircraft loop")

	BallRoundActorCleanup.new().reset_actor_round_state({
		"audio": audio,
		"commando_firearm_runtime": runtime,
	})
	_expect(audio.fire_support_aircraft_stop_calls == 1, "round cleanup should stop the fire-support aircraft loop")
	_expect(not bool(runtime.has_visible_effects()), "round cleanup should clear fire-support runtime visuals")


func _verify_round_cleanup_stops_suicide_drone_loop() -> void:
	var runtime: Object = CommandoFirearmRuntime.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var audio := FakeAudio.new()
	_expect(bool(skill_config.unlock_and_equip_skill("suicide_drone")), "suicide drone should unlock for cleanup setup")
	weapon_controller.sync_equipped_permanent(skill_config)
	_expect(bool(weapon_controller.set_current_weapon("suicide_drone")), "suicide drone should be selectable for cleanup setup")
	var deps := {
		"audio": audio,
		"commando_weapon_controller": weapon_controller,
		"skill_state": skill_state,
		"skill_config": skill_config,
	}
	var result: Dictionary = runtime.update_input({"action_pressed": true}, 500.0, {
		"player_pos": Vector2(302.0, 654.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"boss_pos": Vector2(328.0, 62.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"width": 760.0,
		"height": 750.0,
	}, deps)
	_expect(bool(result.get("fired", false)), "suicide drone should fire for cleanup setup")
	_expect(audio.suicide_drone_loop_play_calls == 1, "suicide drone launch should start the loop cue")

	BallRoundActorCleanup.new().reset_actor_round_state({
		"audio": audio,
		"commando_firearm_runtime": runtime,
	})
	_expect(audio.suicide_drone_loop_stop_calls == 1, "round cleanup should stop the suicide-drone loop")
	_expect(not bool(runtime.has_visible_effects()), "round cleanup should clear suicide-drone projectile visuals")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _get_first_collectible(supply_state: Object) -> Dictionary:
	var drops: Array = supply_state.get_snapshot().get("collectible_drops", [])
	if drops.is_empty() or not (drops[0] is Dictionary):
		return {}
	return drops[0]


func _get_array(value: Variant) -> Array:
	return value if value is Array else []
