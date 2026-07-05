extends SceneTree

const CommandoPlayerController := preload("res://scripts/characters/commando_player_controller.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var aircraft_play_calls := 0
	var aircraft_stop_calls := 0
	var explosion_calls := 0

	func play_commando_supply_radio() -> void:
		pass

	func play_commando_supply_aircraft_loop() -> void:
		aircraft_play_calls += 1

	func stop_commando_supply_aircraft_loop() -> void:
		aircraft_stop_calls += 1

	func play_grenade_explosion() -> void:
		explosion_calls += 1


class FakeInputReader:
	extends RefCounted

	var snapshot := {}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeActiveItemRuntime:
	extends RefCounted

	var brick_walls: Array[Dictionary] = []
	var notify_calls := 0

	func get_ball_collision_context() -> Dictionary:
		return {"brick_walls": brick_walls}

	func notify_brick_wall_hit(_wall_index: int, _impact_pos: Vector2) -> Dictionary:
		notify_calls += 1
		return {"destroyed": false}


func _init() -> void:
	_verify_player_paddle_collision_crashes_aircraft()
	_verify_brick_wall_collision_crashes_aircraft_without_consuming_wall()
	_verify_commando_controller_passes_paddle_collision_context()

	if _failures.is_empty():
		print("commando_supply_drop_obstacle_crash_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_player_paddle_collision_crashes_aircraft() -> void:
	var setup: Dictionary = _setup_active_supply()
	var supply_state: Object = setup.get("supply_state", null)
	var audio: FakeAudio = setup.get("audio", null)
	var weapon_controller: Object = setup.get("weapon_controller", null)
	var aircraft_pos: Vector2 = _as_vector2(supply_state.get_snapshot().get("aircraft_pos", Vector2.ZERO))

	var result: Dictionary = supply_state.resolve_obstacle_collision({
		"player_pos": aircraft_pos - Vector2(44.0, 20.0),
		"player_paddle_size": Vector2(88.0, 40.0),
	}, setup.get("deps", {}))
	_expect(bool(result.get("aircraft_collision", false)), "player paddle should crash the supply aircraft")
	_expect(str(result.get("source", "")) == "player_paddle", "player paddle collision should identify its source")
	var snapshot: Dictionary = supply_state.get_snapshot()
	_expect(str(snapshot.get("aircraft_crash_source", "")) == "player_paddle", "snapshot should keep player-paddle crash source")
	_expect(not bool(snapshot.get("active", true)), "paddle crash should cancel active supply drop")
	_expect(_get_array(snapshot.get("pending_drops", [])).is_empty(), "paddle crash should clear queued payloads")
	_expect(audio.aircraft_stop_calls == 1, "paddle crash should stop aircraft audio")
	supply_state.update(CommandoSupplyDropState.AIRCRAFT_CRASH_SECONDS + 0.1, setup.get("deps", {}))
	_expect(audio.explosion_calls == 1, "paddle crash should finish with the aircraft explosion cue")
	_expect(weapon_controller.get_weapons() == ["pistol"], "paddle-crashed aircraft should not grant rentals")


func _verify_brick_wall_collision_crashes_aircraft_without_consuming_wall() -> void:
	var setup: Dictionary = _setup_active_supply()
	var supply_state: Object = setup.get("supply_state", null)
	var deps: Dictionary = setup.get("deps", {})
	var fake_active_item_runtime: FakeActiveItemRuntime = FakeActiveItemRuntime.new()
	deps["active_item_runtime"] = fake_active_item_runtime

	var aircraft_pos: Vector2 = _as_vector2(supply_state.get_snapshot().get("aircraft_pos", Vector2.ZERO))
	fake_active_item_runtime.brick_walls = [{
		"rect": Rect2(aircraft_pos - Vector2(60.0, 22.0), Vector2(120.0, 44.0)),
		"hit_count": 0,
	}]
	var result: Dictionary = supply_state.update(0.01, deps)
	_expect(bool(result.get("aircraft_collision", false)), "brick wall should crash the supply aircraft")
	_expect(str(result.get("source", "")) == "brick_wall", "brick collision should identify its source")
	_expect(int(result.get("wall_index", -1)) == 0, "brick collision should report the wall index")
	_expect(fake_active_item_runtime.notify_calls == 0, "aircraft brick collision should not consume or damage the brick wall")
	_expect(str(supply_state.get_snapshot().get("aircraft_crash_source", "")) == "brick_wall", "snapshot should keep brick-wall crash source")


func _verify_commando_controller_passes_paddle_collision_context() -> void:
	var setup: Dictionary = _setup_active_supply()
	var supply_state: Object = setup.get("supply_state", null)
	var deps: Dictionary = setup.get("deps", {})
	deps["input_reader"] = FakeInputReader.new()
	deps["commando_weapon_controller"] = setup.get("weapon_controller", null)
	deps["commando_supply_drop_state"] = supply_state
	var aircraft_pos: Vector2 = _as_vector2(supply_state.get_snapshot().get("aircraft_pos", Vector2.ZERO))

	CommandoPlayerController.new().update(
		0.01,
		0,
		aircraft_pos - Vector2(44.0, 20.0),
		0.0,
		{
			"special_gauge": 500.0,
			"current_stage": 1,
			"paddle_width": 88.0,
			"paddle_height": 40.0,
			"play_left": 0.0,
			"play_right": 760.0,
		},
		deps
	)
	var snapshot: Dictionary = supply_state.get_snapshot()
	_expect(bool(snapshot.get("aircraft_crashing", false)), "commando controller should pass paddle context into supply update")
	_expect(str(snapshot.get("aircraft_crash_source", "")) == "player_paddle", "controller-routed crash should preserve paddle source")


func _setup_active_supply() -> Dictionary:
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	var supply_state: Object = CommandoSupplyDropState.new()
	var audio := FakeAudio.new()
	var deps := {
		"audio": audio,
		"commando_weapon_controller": weapon_controller,
		"commando_supply_drop_payload_count": 3,
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
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
	_expect(bool(activate_result.get("activated", false)), "supply drop should activate for obstacle crash setup")
	supply_state.update(0.35, deps)
	return {
		"supply_state": supply_state,
		"weapon_controller": weapon_controller,
		"audio": audio,
		"deps": deps,
	}


func _get_array(value: Variant) -> Array:
	return value if value is Array else []


func _as_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
