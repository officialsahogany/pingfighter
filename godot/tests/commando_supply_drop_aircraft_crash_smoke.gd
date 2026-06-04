extends SceneTree

const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
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
	var drop_calls := 0
	var explosion_calls := 0

	func play_commando_supply_radio() -> void:
		radio_calls += 1

	func play_commando_supply_aircraft_loop() -> void:
		aircraft_play_calls += 1

	func stop_commando_supply_aircraft_loop() -> void:
		aircraft_stop_calls += 1

	func play_commando_supply_drop() -> void:
		drop_calls += 1

	func play_grenade_explosion() -> void:
		explosion_calls += 1


func _init() -> void:
	_verify_supply_aircraft_can_be_shot_down_by_player_ball()
	_verify_ball_update_controller_routes_supply_aircraft_collision()

	if _failures.is_empty():
		print("commando_supply_drop_aircraft_crash_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_supply_aircraft_can_be_shot_down_by_player_ball() -> void:
	var supply_state: Object = CommandoSupplyDropState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var audio := FakeAudio.new()
	var deps := {
		"audio": audio,
		"commando_weapon_controller": weapon_controller,
		"commando_supply_drop_payload_count": 3,
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"current_stage": 1,
	}
	_activate_and_advance_aircraft(supply_state, skill_config, skill_state, deps)

	var aircraft_pos: Vector2 = supply_state.get_snapshot().get("aircraft_pos", Vector2.ZERO)
	var boss_scene := {
		"previous_ball_pos": aircraft_pos + Vector2(0.0, 22.0),
		"ball_pos": aircraft_pos,
		"ball_vel": Vector2(0.0, -12.0),
	}
	var boss_hit: bool = bool(supply_state.resolve_ball_collision(boss_scene, {
		"ball_size": 28.6,
		"last_hit_by": "boss",
	}, deps))
	_expect(not boss_hit, "boss-owned ball should not shoot down the supply aircraft")
	_expect(bool(supply_state.get_snapshot().get("active", false)), "boss pass-through should keep supply drop active")

	var scene := {
		"previous_ball_pos": aircraft_pos + Vector2(0.0, 22.0),
		"ball_pos": aircraft_pos,
		"ball_vel": Vector2(0.0, -12.0),
	}
	var hit: bool = bool(supply_state.resolve_ball_collision(scene, {
		"ball_size": 28.6,
		"last_hit_by": "player",
	}, deps))
	_expect(hit, "player-owned ball should shoot down the supply aircraft")
	_expect(_as_vector2(scene.get("ball_vel", Vector2.ZERO)).y > 0.0, "aircraft hit should damp and reflect the ball downward")
	_expect(bool(scene.get("commando_supply_aircraft_hit", false)), "collision should mark the scene with the aircraft hit flag")
	var snapshot: Dictionary = supply_state.get_snapshot()
	_expect(not bool(snapshot.get("active", true)), "shootdown should cancel the active supply payload queue")
	_expect(bool(snapshot.get("aircraft_crashing", false)), "shootdown should enter the aircraft crash state")
	_expect(_get_array(snapshot.get("pending_drops", [])).is_empty(), "shootdown should clear pending payloads")
	_expect(audio.aircraft_stop_calls == 1, "shootdown should stop the aircraft loop immediately")
	var sprite_status: Dictionary = supply_state.build_aircraft_sprite_status()
	_expect(bool(sprite_status.get("crash_active_loaded", false)), "shootdown should load the burning aircraft crash sheet")
	_expect(int(sprite_status.get("crash_frame_count", 0)) == 16, "burning aircraft crash sheet should expose 16 frames")

	var crash_result: Dictionary = supply_state.update(0.9, deps)
	_expect(bool(crash_result.get("aircraft_exploded", false)), "crash update should finish in an explosion")
	snapshot = supply_state.get_snapshot()
	_expect(bool(snapshot.get("aircraft_exploded", false)), "snapshot should expose the explosion state")
	_expect(not bool(snapshot.get("aircraft_crashing", true)), "explosion should clear the crash state")
	_expect(audio.explosion_calls == 1, "final aircraft explosion should play the explosion cue")
	_expect(weapon_controller.get_weapons() == ["pistol"], "shot-down aircraft should not grant queued rental weapons")
	_expect(bool(supply_state.has_visible_effects()), "explosion particles should keep the supply visual alive briefly")

	supply_state.update(1.2, deps)
	_expect(not bool(supply_state.has_visible_effects()), "crash explosion visuals should expire cleanly")


func _verify_ball_update_controller_routes_supply_aircraft_collision() -> void:
	var supply_state: Object = CommandoSupplyDropState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var audio := FakeAudio.new()
	var deps := {
		"audio": audio,
		"commando_weapon_controller": weapon_controller,
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"current_stage": 1,
	}
	_activate_and_advance_aircraft(supply_state, skill_config, skill_state, deps)
	var aircraft_pos: Vector2 = supply_state.get_snapshot().get("aircraft_pos", Vector2.ZERO)
	var scene := {
		"previous_ball_pos": aircraft_pos + Vector2(0.0, 22.0),
		"ball_pos": aircraft_pos,
		"ball_vel": Vector2(0.0, -10.0),
	}
	BallUpdateController.new()._process_commando_supply_drop_collision(scene, {
		"ball_size": 28.6,
		"last_hit_by": "player",
	}, {
		"audio": audio,
		"commando_supply_drop_state": supply_state,
	})
	_expect(bool(scene.get("commando_supply_aircraft_hit", false)), "ball update controller should route supply aircraft collision")
	_expect(bool(supply_state.get_snapshot().get("aircraft_crashing", false)), "routed collision should enter crash state")


func _activate_and_advance_aircraft(
	supply_state: Object,
	skill_config: Object,
	skill_state: Object,
	deps: Dictionary
) -> void:
	var activate_result: Dictionary = supply_state.update_input(
		{"down_pressed": true, "action_pressed": true},
		1.0,
		500.0,
		skill_config,
		skill_state,
		deps
	)
	_expect(bool(activate_result.get("activated", false)), "supply drop should activate for aircraft crash setup")
	supply_state.update(0.35, deps)


func _get_array(value: Variant) -> Array:
	return value if value is Array else []


func _as_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
