extends SceneTree

const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const CommandoPlayerController := preload("res://scripts/characters/commando_player_controller.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")
const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")

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


class FakeFeedback:
	extends RefCounted

	var shake_calls := 0
	var last_amount := 0.0
	var last_intensity := 0.0

	func max_screen_shake(amount: float, intensity: float) -> void:
		shake_calls += 1
		last_amount = max(last_amount, amount)
		last_intensity = max(last_intensity, intensity)


class FakeMovementState:
	extends RefCounted

	var knockback_calls := 0
	var last_velocity := 0.0
	var last_frames := 0.0

	func start_knockback(velocity: float, frames: float = 18.0, _decay: float = 0.92, _replace: bool = false, _cleansable: bool = true) -> bool:
		knockback_calls += 1
		last_velocity = velocity
		last_frames = frames
		return true


func _init() -> void:
	_verify_supply_aircraft_can_be_shot_down_by_player_ball()
	_verify_ball_update_controller_routes_supply_aircraft_collision()
	_verify_crash_ground_blast_shakes_and_knocks_ball()
	_verify_crash_ground_blast_ignores_distant_ball()
	_verify_crash_ground_blast_knocks_player_paddle()
	_verify_crash_blast_knocks_approaching_player()
	_verify_live_controller_path_applies_player_knockback()

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

	var crash_result: Dictionary = supply_state.update(CommandoSupplyDropState.AIRCRAFT_CRASH_SECONDS + 0.1, deps)
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


func _crash_aircraft_to_ground(deps: Dictionary) -> Object:
	var supply_state: Object = CommandoSupplyDropState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	_activate_and_advance_aircraft(supply_state, skill_config, skill_state, deps)
	var aircraft_pos: Vector2 = supply_state.get_snapshot().get("aircraft_pos", Vector2.ZERO)
	supply_state.resolve_ball_collision({
		"previous_ball_pos": aircraft_pos + Vector2(0.0, 22.0),
		"ball_pos": aircraft_pos,
		"ball_vel": Vector2(0.0, -12.0),
	}, {"ball_size": 28.6, "last_hit_by": "player"}, deps)
	supply_state.update(CommandoSupplyDropState.AIRCRAFT_CRASH_SECONDS + 0.1, deps)
	return supply_state


func _verify_crash_ground_blast_shakes_and_knocks_ball() -> void:
	var feedback := FakeFeedback.new()
	var deps := {
		"audio": FakeAudio.new(),
		"commando_weapon_controller": CommandoWeaponController.new(),
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"current_stage": 1,
		"feedback": feedback,
	}
	var supply_state: Object = _crash_aircraft_to_ground(deps)
	_expect(bool(supply_state.get_snapshot().get("aircraft_exploded", false)), "blast setup should reach the explosion state")
	_expect(feedback.shake_calls == 1, "ground crash should trigger one screen shake")
	_expect(feedback.last_intensity >= 5.0, "ground crash screen shake should read as a big impact")

	var center: Vector2 = supply_state.get_snapshot().get("aircraft_pos", Vector2.ZERO)
	# Ball just above the blast center, well inside the knockback radius.
	var ball_start_vel := Vector2(0.0, 5.0)
	var scene := {
		"ball_pos": center + Vector2(0.0, -40.0),
		"ball_vel": ball_start_vel,
	}
	supply_state.resolve_ball_collision(scene, {"ball_size": 28.6}, deps)
	var knocked_vel: Vector2 = _as_vector2(scene.get("ball_vel", Vector2.ZERO))
	_expect(knocked_vel != ball_start_vel, "in-radius ball should be knocked by the ground blast")
	_expect(knocked_vel.length() > ball_start_vel.length(), "ground blast should speed up the in-radius ball")
	_expect(knocked_vel.y < 0.0, "ground blast should launch the ball upward, never spike it into the floor")
	_expect(knocked_vel.length() <= CommandoSupplyDropState.AIRCRAFT_CRASH_KNOCKBACK_SPEED_CEILING + 0.01, "ground blast must respect the ball speed ceiling")

	# One-shot: a second ball frame must not re-fire the impulse.
	var scene2 := {
		"ball_pos": center + Vector2(0.0, -40.0),
		"ball_vel": Vector2(0.0, 5.0),
	}
	supply_state.resolve_ball_collision(scene2, {"ball_size": 28.6}, deps)
	_expect(_as_vector2(scene2.get("ball_vel", Vector2.ZERO)) == Vector2(0.0, 5.0), "ground blast impulse must be one-shot")


func _verify_crash_ground_blast_ignores_distant_ball() -> void:
	var deps := {
		"audio": FakeAudio.new(),
		"commando_weapon_controller": CommandoWeaponController.new(),
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"current_stage": 1,
		"feedback": FakeFeedback.new(),
	}
	var supply_state: Object = _crash_aircraft_to_ground(deps)
	var center: Vector2 = supply_state.get_snapshot().get("aircraft_pos", Vector2.ZERO)
	var far_vel := Vector2(3.0, -4.0)
	var scene := {
		"ball_pos": center + Vector2(0.0, -400.0),
		"ball_vel": far_vel,
	}
	supply_state.resolve_ball_collision(scene, {"ball_size": 28.6}, deps)
	_expect(_as_vector2(scene.get("ball_vel", Vector2.ZERO)) == far_vel, "ball outside the blast radius should be untouched")


func _shoot_down_and_get_crash_target(supply_state: Object, deps: Dictionary) -> Vector2:
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	_activate_and_advance_aircraft(supply_state, skill_config, skill_state, deps)
	var aircraft_pos: Vector2 = supply_state.get_snapshot().get("aircraft_pos", Vector2.ZERO)
	supply_state.resolve_ball_collision({
		"previous_ball_pos": aircraft_pos + Vector2(0.0, 22.0),
		"ball_pos": aircraft_pos,
		"ball_vel": Vector2(0.0, -12.0),
	}, {"ball_size": 28.6, "last_hit_by": "player"}, deps)
	return _as_vector2(supply_state.get_snapshot().get("aircraft_crash_target_pos", Vector2.ZERO))


func _build_player_context(center_offset_x: float, target: Vector2) -> Dictionary:
	return {
		"player_pos": Vector2(target.x + center_offset_x - 77.5, 654.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}


func _verify_crash_ground_blast_knocks_player_paddle() -> void:
	var movement := FakeMovementState.new()
	var deps := {
		"audio": FakeAudio.new(),
		"commando_weapon_controller": CommandoWeaponController.new(),
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"current_stage": 1,
		"feedback": FakeFeedback.new(),
		"movement_state": movement,
	}
	var supply_state: Object = CommandoSupplyDropState.new()
	var target: Vector2 = _shoot_down_and_get_crash_target(supply_state, deps)
	# Paddle center 120px LEFT of the blast center: inside the radius.
	deps["commando_supply_drop_collision_context"] = _build_player_context(-120.0, target)
	supply_state.update(CommandoSupplyDropState.AIRCRAFT_CRASH_SECONDS + 0.05, deps)
	var snapshot: Dictionary = supply_state.get_snapshot()
	_expect(bool(snapshot.get("aircraft_exploded", false)), "player blast setup should reach the explosion state")
	_expect(float(snapshot.get("crash_blast_timer", 0.0)) > 0.0, "ground explosion should open the grenade-class blast window")
	_expect(movement.knockback_calls == 1, "paddle inside the blast radius should be knocked at the explosion instant")
	_expect(movement.last_velocity < 0.0, "paddle left of the blast should be shoved further left (away from center)")
	# 2x live-QA tuning (2026-07-03): total travel ~207px needs >=30 px/frame.
	_expect(absf(movement.last_velocity) >= 30.0, "player blast knockback should keep the doubled 2x strength")
	supply_state.update(0.05, deps)
	_expect(movement.knockback_calls == 1, "player blast knockback must be one-shot per blast")


func _verify_crash_blast_knocks_approaching_player() -> void:
	var movement := FakeMovementState.new()
	var deps := {
		"audio": FakeAudio.new(),
		"commando_weapon_controller": CommandoWeaponController.new(),
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"current_stage": 1,
		"feedback": FakeFeedback.new(),
		"movement_state": movement,
	}
	var supply_state: Object = CommandoSupplyDropState.new()
	var target: Vector2 = _shoot_down_and_get_crash_target(supply_state, deps)
	# Paddle far away at the explosion instant -> no shove.
	deps["commando_supply_drop_collision_context"] = _build_player_context(-500.0, target)
	supply_state.update(CommandoSupplyDropState.AIRCRAFT_CRASH_SECONDS + 0.05, deps)
	_expect(movement.knockback_calls == 0, "paddle far from the blast should not be knocked at the explosion instant")
	# Walk INTO the erupting blast while the window is still open -> shoved.
	deps["commando_supply_drop_collision_context"] = _build_player_context(80.0, target)
	supply_state.update(0.1, deps)
	_expect(movement.knockback_calls == 1, "paddle walking into the erupting blast should be shoved")
	_expect(movement.last_velocity > 0.0, "paddle right of the blast should be shoved further right (away from center)")
	# Window closes cleanly.
	supply_state.update(CommandoSupplyDropState.AIRCRAFT_CRASH_BLAST_SECONDS, deps)
	_expect(float(supply_state.get_snapshot().get("crash_blast_timer", 1.0)) <= 0.0, "blast window should expire after its duration")


class FakeInputReader:
	extends RefCounted

	var down := false

	func get_snapshot() -> Dictionary:
		return {
			"down_pressed": down,
			"left_pressed": false,
			"right_pressed": false,
			"action_pressed": false,
			"direction": 0.0,
		}


func _verify_live_controller_path_applies_player_knockback() -> void:
	# Full live-path repro: real CommandoPlayerController + real
	# PlayerMovementState, NO injected collision context — the controller must
	# build it itself exactly like the battle scene does.
	var controller := CommandoPlayerController.new()
	var movement_state := PlayerMovementState.new()
	var supply_state: Object = CommandoSupplyDropState.new()
	var input_reader := FakeInputReader.new()
	var deps := {
		"audio": FakeAudio.new(),
		"feedback": FakeFeedback.new(),
		"input_reader": input_reader,
		"movement_state": movement_state,
		"commando_supply_drop_state": supply_state,
		"commando_weapon_controller": CommandoWeaponController.new(),
		"skill_state": CommandoSkillState.new(),
		"skill_config": CommandoSkillConfig.new(),
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"current_stage": 1,
	}
	var config := {
		"selected_character_type": "commando",
		"special_gauge": 500.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"play_left": 0.0,
		"play_right": 760.0,
	}
	var player_pos := Vector2(300.0, 654.0)
	var frame := 0
	var delta := 1.0 / 60.0
	# Hold the supply key through the real controller until activation.
	input_reader.down = true
	var activated := false
	for i in range(90):
		var result: Dictionary = controller.update(delta, frame, player_pos, 0.0, config, deps)
		frame += 1
		if float(result.get("special_gauge", 500.0)) < 500.0:
			activated = true
			break
	_expect(activated, "live-path repro should activate the supply drop from a held key")
	input_reader.down = false
	# Fly past the invulnerability window on the real controller tick.
	for i in range(30):
		controller.update(delta, frame, player_pos, 0.0, config, deps)
		frame += 1
	# Shoot the plane down from the ball path.
	var aircraft_pos: Vector2 = _as_vector2(supply_state.get_snapshot().get("aircraft_pos", Vector2.ZERO))
	var hit: bool = bool(supply_state.resolve_ball_collision({
		"previous_ball_pos": aircraft_pos + Vector2(0.0, 22.0),
		"ball_pos": aircraft_pos,
		"ball_vel": Vector2(0.0, -12.0),
	}, {"ball_size": 28.6, "last_hit_by": "player"}, deps))
	_expect(hit, "live-path repro should shoot down the aircraft")
	# Park the paddle center 60px left of the crash target, inside the radius,
	# and drive the real controller through the whole descent.
	var target: Vector2 = _as_vector2(supply_state.get_snapshot().get("aircraft_crash_target_pos", Vector2.ZERO))
	player_pos = Vector2(clamp(target.x - 137.5, 0.0, 605.0), 654.0)
	var knocked := false
	for i in range(120):
		var result: Dictionary = controller.update(delta, frame, player_pos, 0.0, config, deps)
		frame += 1
		var moved: Variant = result.get("player_pos", player_pos)
		if moved is Vector2:
			player_pos = moved
		if bool(movement_state.get_status_snapshot().get("knockback_motion_active", false)):
			knocked = true
			break
	_expect(knocked, "live controller path should knock the parked paddle at the ground explosion")


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
