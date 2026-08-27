extends SceneTree

const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

const AIRCRAFT_STATE_PATH := "res://scripts/characters/commando_supply_drop_aircraft_lifecycle_state.gd"
const HOST_PATH := "res://scripts/characters/commando_supply_drop_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_arrival_and_flight_edges()
	_verify_production_same_frame_remainder()
	_verify_direction_and_payload_window()
	_verify_crash_lifecycle()
	_verify_snapshot_restore()

	if _failures.is_empty():
		print("commando_supply_drop_aircraft_lifecycle_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(AIRCRAFT_STATE_PATH), "Commando Supply Drop aircraft should have a focused lifecycle owner")
	if not FileAccess.file_exists(AIRCRAFT_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var owner_source := FileAccess.get_file_as_string(AIRCRAFT_STATE_PATH)
	_expect(
		host_source.find("const CommandoSupplyDropAircraftLifecycleState := preload(\"%s\")" % AIRCRAFT_STATE_PATH) >= 0,
		"Supply Drop state should preload the focused aircraft lifecycle owner"
	)
	_expect(
		host_source.find("var _aircraft_state: Object = CommandoSupplyDropAircraftLifecycleState.new()") >= 0,
		"Supply Drop state should retain one aircraft lifecycle owner instance"
	)
	for marker in [
		"func reset(",
		"func begin(",
		"func restore(",
		"func get_snapshot(",
		"func advance_active_flight(",
		"func update_arrival(",
		"func spawn(",
		"func advance_flight(",
		"func begin_crash(",
		"func advance_crash(",
		"func get_collision_rect(",
		"func get_payload_drop_timer_delta(",
	]:
		_expect(owner_source.find(marker) >= 0, "aircraft lifecycle owner should implement %s" % marker)
	for moved_marker in [
		"var aircraft_spawned",
		"var aircraft_arrival_delay",
		"var aircraft_direction",
		"var aircraft_pos",
		"var aircraft_crashing",
		"var aircraft_crash_elapsed",
		"var aircraft_crash_timer",
		"var aircraft_crash_rotation",
		"var aircraft_crash_start_pos",
		"var aircraft_crash_target_pos",
		"var aircraft_exploded",
		"var aircraft_crash_source",
		"var flight_elapsed",
		"var flight_duration",
		"func _get_aircraft_arrival_delay(",
		"func _get_aircraft_direction(",
		"func _update_aircraft_arrival(",
		"func _get_aircraft_start_pos(",
		"func _update_aircraft_visual(",
		"func _get_aircraft_travel_duration(",
		"func _is_aircraft_offscreen(",
		"func _is_aircraft_over_payload_drop_zone(",
		"func _get_payload_drop_timer_delta(",
		"func _get_payload_drop_zone_elapsed_window(",
		"func _get_payload_drop_gate_bounds(",
		"func _update_aircraft_crash(",
	]:
		_expect(host_source.find(moved_marker) < 0, "Supply Drop host should not retain lifecycle marker %s" % moved_marker)
	_expect(
		host_source.find("_aircraft_state.advance_active_flight(safe_delta, active, deps)") >= 0,
		"frame update should delegate arrival remainder and flight motion as one lifecycle transaction"
	)
	_expect(
		host_source.find("_aircraft_state.advance_crash(safe_delta)") >= 0,
		"frame update should delegate crash motion to the focused owner"
	)


func _verify_arrival_and_flight_edges() -> void:
	var owner: Object = _new_owner()
	if owner == null:
		return
	if not owner.has_method("advance_active_flight"):
		_expect(false, "aircraft lifecycle owner should expose combined active-flight advancement")
		return
	owner.begin({
		"commando_supply_drop_aircraft_arrival_delay": 1.0,
		"commando_supply_drop_direction": "left_to_right",
	})
	var pending_transaction: Dictionary = owner.advance_active_flight(0.75, true, {})
	_expect(bool(pending_transaction.get("aircraft_pending", false)), "combined flight advancement should retain a partial arrival wait")
	_expect_close(owner.flight_elapsed, 0.0, "arrival wait must not leak time into flight motion")
	var crossing_transaction: Dictionary = owner.advance_active_flight(0.50, true, {})
	_expect(bool(crossing_transaction.get("aircraft_spawned", false)), "combined advancement should publish the arrival edge")
	_expect_close(float(crossing_transaction.get("remaining_delta_after_aircraft_spawn", -1.0)), 0.25, "combined advancement should retain the post-arrival frame remainder")
	_expect_close(float(crossing_transaction.get("flight_elapsed", -1.0)), 0.25, "post-arrival remainder should advance flight in the same frame")
	_expect_close(owner.pos.x, -330.0, "same-frame post-arrival motion should preserve 120 pixels per second")

	owner.reset()
	var begin_result: Dictionary = owner.begin({
		"commando_supply_drop_aircraft_arrival_delay": 1.0,
		"commando_supply_drop_direction": "left_to_right",
	})
	_expect_close(float(begin_result.get("aircraft_arrival_delay", -1.0)), 1.0, "configured arrival delay should be preserved")
	_expect(owner.pos == Vector2(-360.0, 56.0), "left-to-right flight should begin at the shipped off-canvas lane")
	var pending: Dictionary = owner.update_arrival(0.999, true)
	_expect(bool(pending.get("aircraft_pending", false)), "arrival should remain pending before the exact timer edge")
	_expect(not owner.spawned, "aircraft must remain hidden before arrival expires")
	var spawned: Dictionary = owner.update_arrival(0.011, true)
	_expect(bool(spawned.get("aircraft_spawned", false)), "arrival should spawn on the exact expiry crossing")
	_expect_close(float(spawned.get("remaining_delta_after_aircraft_spawn", -1.0)), 0.010, "arrival should return the unconsumed frame delta")
	_expect(owner.spawned, "spawn should publish the live aircraft state")
	var advanced: Dictionary = owner.advance_flight(0.5, {})
	_expect_close(owner.pos.x, -300.0, "aircraft should move at the shipped 120 pixels per second")
	_expect_close(float(advanced.get("previous_flight_elapsed", -1.0)), 0.0, "first flight step should report the zero origin")
	_expect_close(float(advanced.get("flight_elapsed", -1.0)), 0.5, "flight step should publish elapsed time")
	_expect(not bool(advanced.get("aircraft_offscreen", true)), "half-second flight should remain onscreen-bound")
	owner.advance_flight(owner.get_travel_duration(), {})
	_expect(owner.is_offscreen(), "travel-duration crossing should mark the aircraft offscreen")


func _verify_production_same_frame_remainder() -> void:
	var supply_state: Object = CommandoSupplyDropState.new()
	var deps := {
		"commando_weapon_controller": CommandoWeaponController.new(),
		"commando_supply_drop_direction": "left_to_right",
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_forced_payloads": [{"type": "field_item", "item_id": "gauge_charge"}],
		"commando_supply_drop_aircraft_arrival_delay": 1.0,
		"commando_supply_drop_payload_delays": [1.15],
	}
	var activated: Dictionary = supply_state.update_input(
		{"down_pressed": true, "action_pressed": true},
		1.0,
		500.0,
		CommandoSkillConfig.new(),
		CommandoSkillState.new(),
		deps
	)
	_expect(bool(activated.get("activated", false)), "production remainder setup should activate Supply Drop")
	supply_state.update(1.25, deps)
	var snapshot: Dictionary = supply_state.get_snapshot()
	_expect(bool(snapshot.get("aircraft_spawned", false)), "production update should spawn after crossing the one-second arrival edge")
	_expect_close(float(snapshot.get("flight_elapsed", -1.0)), 0.25, "production update should advance only the unconsumed post-arrival remainder")
	var aircraft_pos: Vector2 = snapshot.get("aircraft_pos", Vector2.ZERO)
	_expect_close(aircraft_pos.x, -330.0, "production aircraft position should reflect only the post-arrival remainder")


func _verify_direction_and_payload_window() -> void:
	var owner: Object = _new_owner()
	if owner == null:
		return
	owner.begin({
		"commando_supply_drop_aircraft_arrival_delay_frames": 30.0,
		"commando_supply_drop_direction": "right_to_left",
	})
	_expect_close(owner.arrival_delay, 0.5, "arrival-frame override should use the 60 FPS contract")
	_expect(owner.direction == "right_to_left", "configured reverse direction should be retained")
	_expect(owner.pos == Vector2(1120.0, 56.0), "right-to-left flight should begin on the opposite off-canvas edge")
	owner.spawn(true)
	owner.advance_flight(1.0, {})
	_expect_close(owner.pos.x, 1000.0, "reverse flight should move left at the same speed")
	var window: Vector2 = owner.get_payload_drop_zone_elapsed_window({
		"play_width": 760.0,
		"commando_supply_drop_aircraft_center_min_x": 100.0,
		"commando_supply_drop_aircraft_center_max_x": 660.0,
	})
	_expect(window.x < window.y, "payload gate should expose a positive elapsed window")
	_expect_close(
		owner.get_payload_drop_timer_delta(window.x - 0.25, window.x + 0.25, {
			"play_width": 760.0,
			"commando_supply_drop_aircraft_center_min_x": 100.0,
			"commando_supply_drop_aircraft_center_max_x": 660.0,
		}),
		0.25,
		"payload timer should count only the part of a frame inside the drop window"
	)
	_expect(owner.get_collision_rect().size == Vector2(96.0, 44.0), "aircraft collision box should preserve shipped dimensions")


func _verify_crash_lifecycle() -> void:
	var owner: Object = _new_owner()
	if owner == null:
		return
	owner.begin({
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"commando_supply_drop_direction": "left_to_right",
	})
	owner.spawn(true)
	owner.advance_flight(3.0, {})
	var crash_origin: Vector2 = owner.pos
	_expect(owner.begin_crash(true, "ball"), "live aircraft should enter crash state once")
	_expect(not owner.spawned and owner.crashing, "shoot-down should replace flying state with crash state")
	_expect(owner.crash_source == "ball", "crash source should survive for feedback and save data")
	_expect_close(owner.crash_target_pos.x, clamp(crash_origin.x + 96.0, 42.0, 718.0), "crash target should drift in the flight direction")
	_expect_close(owner.crash_target_pos.y, 660.0, "crash target should land at the shipped ground lane")
	var mid: Dictionary = owner.advance_crash(0.75)
	_expect(bool(mid.get("aircraft_crashing", false)), "half-duration crash should remain active")
	_expect(mid.get("smoke_position", Vector2.ZERO) == owner.pos, "active crash should publish the current smoke anchor")
	_expect_close(absf(owner.crash_rotation), PI * 0.575, "half-duration crash should rotate through half the full arc")
	var finished: Dictionary = owner.advance_crash(0.75)
	_expect(bool(finished.get("aircraft_exploded", false)), "exact crash-duration edge should publish explosion")
	_expect(bool(finished.get("crash_finished", false)), "exact crash-duration edge should publish the one-shot impact event")
	_expect(not owner.crashing and owner.exploded, "finished crash should transition to exploded state")
	_expect(owner.pos == owner.crash_target_pos, "finished crash should land exactly at its target")
	_expect(not owner.begin_crash(true, "brick_wall"), "exploded aircraft must reject a second crash transition")


func _verify_snapshot_restore() -> void:
	var owner: Object = _new_owner()
	if owner == null:
		return
	owner.restore({
		"aircraft_spawned": true,
		"aircraft_arrival_delay": -4.0,
		"aircraft_direction": "invalid",
		"aircraft_pos": Vector2(123.0, 45.0),
		"flight_elapsed": -2.0,
		"flight_duration": 0.1,
		"aircraft_crash_target_pos": Vector2(500.0, 660.0),
		"timer": 8.0,
	}, true)
	_expect(owner.spawned, "restore should retain explicit spawned state")
	_expect(owner.direction == "left_to_right", "restore should normalize unknown direction to the default lane")
	_expect(owner.pos == Vector2(123.0, 45.0), "restore should preserve valid aircraft position")
	_expect_close(owner.arrival_delay, 0.0, "restore should clamp negative arrival delay")
	_expect_close(owner.flight_elapsed, 0.0, "restore should clamp negative flight elapsed")
	_expect_close(owner.flight_duration, owner.get_travel_duration(), "restore should retain the runtime travel-duration floor")
	_expect_close(owner.arrival_timer, 0.0, "spawned restore should not retain the shared legacy arrival timer")
	var snapshot: Dictionary = owner.get_snapshot()
	snapshot["aircraft_pos"] = Vector2.ZERO
	_expect(owner.pos == Vector2(123.0, 45.0), "snapshot mutation must not alias the live aircraft state")


func _new_owner() -> Object:
	if not FileAccess.file_exists(AIRCRAFT_STATE_PATH):
		return null
	var owner_script: Script = load(AIRCRAFT_STATE_PATH)
	return owner_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.5f, got %.5f)" % [message, expected, actual])
