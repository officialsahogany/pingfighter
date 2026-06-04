extends SceneTree

const CommandoEmergencySupplyState := preload("res://scripts/characters/commando_emergency_supply_state.gd")
const CommandoInputReader := preload("res://scripts/characters/commando_input_reader.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

var _failures: Array[String] = []


class FakeRoundState:
	extends RefCounted

	var waiting_for_serve := false
	var player_serves := false
	var serve_timer := 0.0
	var round_start_time_msec := 0

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve

	func does_player_serve() -> bool:
		return player_serves

	func get_round_start_time_msec() -> int:
		return round_start_time_msec

	func get_snapshot() -> Dictionary:
		return {
			"waiting_for_serve": waiting_for_serve,
			"player_serves": player_serves,
			"serve_timer": serve_timer,
			"round_start_time_msec": round_start_time_msec,
		}


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_commando_supply_radio_loop() -> void:
		calls.append("play_commando_supply_radio_loop")

	func stop_commando_supply_radio_loop() -> void:
		calls.append("stop_commando_supply_radio_loop")

	func play_commando_supply_radio() -> void:
		calls.append("play_commando_supply_radio")

	func play_commando_supply_aircraft_loop() -> void:
		calls.append("play_commando_supply_aircraft_loop")


func _init() -> void:
	_verify_right_mouse_snapshot_exposes_supply_hold()
	_verify_supply_hold_alias_activates()
	_verify_supply_hold_feedback_matches_python_threshold()
	_verify_activation_stops_hold_feedback_loop()
	_verify_round_reset_stops_hold_feedback_loop()
	_verify_round_gates_match_python_reference()
	_verify_hold_buffer_survives_post_serve_gate()
	_verify_emergency_supply_suppresses_supply_hold()
	_verify_original_skill_block_flags_clear_hold()

	if _failures.is_empty():
		print("commando_supply_drop_activation_gate_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_right_mouse_snapshot_exposes_supply_hold() -> void:
	var mouse_snapshot: Dictionary = CommandoInputReader.with_supply_drop_mouse_hold(
		{"down_pressed": false, "action_pressed": false},
		true
	)
	_expect(bool(mouse_snapshot.get("supply_drop_hold_pressed", false)), "right mouse should expose Commando supply-drop hold")
	_expect(bool(mouse_snapshot.get("commando_supply_drop_hold_pressed", false)), "right mouse should expose the Commando namespaced hold key")
	_expect(not bool(mouse_snapshot.get("down_pressed", false)), "right mouse supply hold should not rewrite the shared dash down input")

	var keyboard_snapshot: Dictionary = CommandoInputReader.with_supply_drop_mouse_hold(
		{"down_pressed": true, "action_pressed": false},
		false
	)
	_expect(bool(keyboard_snapshot.get("supply_drop_hold_pressed", false)), "keyboard down should still count as supply-drop hold")


func _verify_supply_hold_alias_activates() -> void:
	var result: Dictionary = _run_supply(CommandoSupplyDropState.new(), _supply_input(), {})
	_expect(bool(result.get("activated", false)), "supply-drop hold alias should activate after the 1-second hold")


func _verify_supply_hold_feedback_matches_python_threshold() -> void:
	var supply_state: Object = CommandoSupplyDropState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var audio := FakeAudio.new()
	var deps := _feedback_deps(audio)
	supply_state.update_input(_supply_input(), 0.29, 500.0, skill_config, skill_state, deps)
	var early_status: Dictionary = supply_state.build_hold_gauge_status()
	_expect(not bool(early_status.get("visible", false)), "supply-drop hold gauge should stay hidden before the Python 0.3-second threshold")
	_expect(audio.calls.is_empty(), "supply-drop hold radio loop should not start before the threshold")

	supply_state.update_input(_supply_input(), 0.02, 500.0, skill_config, skill_state, deps)
	var status: Dictionary = supply_state.build_hold_gauge_status()
	var rect: Rect2 = status.get("rect", Rect2())
	_expect(bool(status.get("visible", false)), "supply-drop hold gauge should appear after the Python 0.3-second threshold")
	_expect(float(status.get("progress", 0.0)) > 0.0 and float(status.get("progress", 1.0)) < 1.0, "supply-drop hold gauge should expose threshold-adjusted progress")
	_expect(audio.calls == ["play_commando_supply_radio_loop"], "supply-drop hold should start the radio loop once at the threshold")
	_expect(bool(supply_state.is_hold_radio_audio_active()), "supply state should expose active hold radio audio")
	_expect(bool(supply_state.has_visible_effects()), "visible hold gauge should keep the supply renderer active")
	_expect(is_equal_approx(rect.get_center().x, 207.5), "hold gauge should be centered above the player paddle")
	_expect(is_equal_approx(rect.position.y, 610.0), "hold gauge should sit 40px above the player top like Python")

	supply_state.update_input({"supply_drop_hold_pressed": false}, 0.02, 500.0, skill_config, skill_state, deps)
	_expect(audio.calls.has("stop_commando_supply_radio_loop"), "releasing supply-drop hold should stop the radio loop")
	_expect(not bool(supply_state.is_hold_radio_audio_active()), "released hold should clear radio-loop state")
	_expect(not bool(supply_state.build_hold_gauge_status().get("visible", false)), "released hold should hide the gauge")


func _verify_activation_stops_hold_feedback_loop() -> void:
	var supply_state: Object = CommandoSupplyDropState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var audio := FakeAudio.new()
	var deps := _feedback_deps(audio)
	supply_state.update_input(_supply_input(), 0.4, 500.0, skill_config, skill_state, deps)
	var result: Dictionary = supply_state.update_input(_supply_input(), 0.6, 500.0, skill_config, skill_state, deps)
	_expect(bool(result.get("activated", false)), "supply-drop should activate after the held feedback phase reaches one second")
	_expect(audio.calls.has("stop_commando_supply_radio_loop"), "activation should stop the hold radio loop")
	_expect(audio.calls.has("play_commando_supply_radio"), "activation should play the supply radio call cue")
	_expect(not audio.calls.has("play_commando_supply_aircraft_loop"), "activation should defer the aircraft loop until the original delayed aircraft arrival")
	_expect(not bool(supply_state.is_hold_radio_audio_active()), "activation should clear hold radio-loop state")
	var snapshot: Dictionary = supply_state.get_snapshot()
	_expect(not bool(snapshot.get("aircraft_spawned", true)), "activation should wait before spawning the supply aircraft")
	_expect(["left_to_right", "right_to_left"].has(str(snapshot.get("aircraft_direction", ""))), "activation should choose one of the original random aircraft directions")
	_expect(float(snapshot.get("timer", 0.0)) >= 1.5 and float(snapshot.get("timer", 0.0)) <= 5.0, "supply aircraft arrival timer should match Python 90-300 frame delay")
	supply_state.update(float(snapshot.get("timer", 0.0)), deps)
	_expect(audio.calls.has("play_commando_supply_aircraft_loop"), "aircraft loop should start exactly when the delayed aircraft appears")


func _verify_round_reset_stops_hold_feedback_loop() -> void:
	var supply_state: Object = CommandoSupplyDropState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var audio := FakeAudio.new()
	var deps := _feedback_deps(audio)
	supply_state.update_input(_supply_input(), 0.4, 500.0, skill_config, skill_state, deps)
	_expect(bool(supply_state.is_hold_radio_audio_active()), "round-reset setup should start the hold radio loop")
	supply_state.reset_round(deps)
	_expect(audio.calls.has("stop_commando_supply_radio_loop"), "round reset should stop the hold radio loop")
	_expect(not bool(supply_state.is_hold_radio_audio_active()), "round reset should clear hold radio-loop state")


func _verify_round_gates_match_python_reference() -> void:
	var boss_wait := FakeRoundState.new()
	boss_wait.waiting_for_serve = true
	boss_wait.player_serves = false
	var boss_wait_result: Dictionary = _run_supply(
		CommandoSupplyDropState.new(),
		_supply_input(),
		{"round_state": boss_wait, "current_msec": 10000}
	)
	_expect_not_activated(boss_wait_result, "boss serve wait should block supply-drop hold")

	var early_player_wait := FakeRoundState.new()
	early_player_wait.waiting_for_serve = true
	early_player_wait.player_serves = true
	early_player_wait.serve_timer = 5.9
	var early_player_wait_result: Dictionary = _run_supply(
		CommandoSupplyDropState.new(),
		_supply_input(),
		{"round_state": early_player_wait, "current_msec": 10000}
	)
	_expect_not_activated(early_player_wait_result, "player serve wait before 6 seconds should block supply-drop hold")

	var late_player_wait := FakeRoundState.new()
	late_player_wait.waiting_for_serve = true
	late_player_wait.player_serves = true
	late_player_wait.serve_timer = 6.0
	var late_player_wait_result: Dictionary = _run_supply(
		CommandoSupplyDropState.new(),
		_supply_input(),
		{"round_state": late_player_wait, "current_msec": 10000}
	)
	_expect(bool(late_player_wait_result.get("activated", false)), "player serve wait at 6 seconds should allow supply-drop hold")

	var fresh_serve := FakeRoundState.new()
	fresh_serve.waiting_for_serve = false
	fresh_serve.round_start_time_msec = 10000
	var fresh_serve_result: Dictionary = _run_supply(
		CommandoSupplyDropState.new(),
		_supply_input(),
		{"round_state": fresh_serve, "current_msec": 12_999}
	)
	_expect_not_activated(fresh_serve_result, "post-serve 3-second lock should block supply-drop hold")

	var settled_serve := FakeRoundState.new()
	settled_serve.waiting_for_serve = false
	settled_serve.round_start_time_msec = 10000
	var settled_serve_result: Dictionary = _run_supply(
		CommandoSupplyDropState.new(),
		_supply_input(),
		{"round_state": settled_serve, "current_msec": 13_000}
	)
	_expect(bool(settled_serve_result.get("activated", false)), "post-serve lock should expire after 3 seconds")


func _verify_hold_buffer_survives_post_serve_gate() -> void:
	var supply_state: Object = CommandoSupplyDropState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var fresh_serve := FakeRoundState.new()
	fresh_serve.waiting_for_serve = false
	fresh_serve.round_start_time_msec = 10000
	var deps := {
		"round_state": fresh_serve,
		"current_msec": 12_900,
	}
	var blocked_result: Dictionary = supply_state.update_input(
		_supply_input(),
		0.7,
		500.0,
		skill_config,
		skill_state,
		deps
	)
	_expect_not_activated(blocked_result, "post-serve lock should not activate before it expires")
	_expect(
		is_equal_approx(float(supply_state.get_snapshot().get("pending_hold_time", 0.0)), 0.7),
		"held supply input during post-serve lock should be buffered"
	)
	_expect(
		not bool(supply_state.build_hold_gauge_status().get("visible", false)),
		"blocked supply hold buffer should not show the visible hold gauge"
	)

	deps["current_msec"] = 13_000
	var activated_result: Dictionary = supply_state.update_input(
		_supply_input(),
		0.3,
		500.0,
		skill_config,
		skill_state,
		deps
	)
	_expect(
		bool(activated_result.get("activated", false)),
		"held supply input should activate without a second key attempt once the post-serve lock expires"
	)


func _verify_emergency_supply_suppresses_supply_hold() -> void:
	var emergency_state: Object = CommandoEmergencySupplyState.new()
	var skill_config: Object = CommandoSkillConfig.new()
	var skill_state: Object = CommandoSkillState.new()
	var weapon_controller: Object = CommandoWeaponController.new()
	_expect(bool(weapon_controller.consume_current_weapon_ammo(1)), "test setup should leave pistol room for emergency supply")
	var emergency_deps := {
		"skill_config": skill_config,
		"skill_state": skill_state,
		"commando_weapon_controller": weapon_controller,
	}
	emergency_state.update_input(_down_input(true), 1000, 500.0, emergency_deps)
	emergency_state.update_input(_down_input(false), 1070, 500.0, emergency_deps)
	var emergency_result: Dictionary = emergency_state.update_input(_down_input(true), 1200, 500.0, emergency_deps)
	_expect(bool(emergency_result.get("activated", false)), "test setup should activate emergency supply")

	var suppressed_result: Dictionary = _run_supply(
		CommandoSupplyDropState.new(),
		_supply_input(),
		{"commando_emergency_supply_state": emergency_state, "current_msec": 1250},
		350.0
	)
	_expect_not_activated(suppressed_result, "emergency supply suppress window should block immediate supply-drop hold")

	var expired_result: Dictionary = _run_supply(
		CommandoSupplyDropState.new(),
		_supply_input(),
		{"commando_emergency_supply_state": emergency_state, "current_msec": 1500},
		350.0
	)
	_expect(bool(expired_result.get("activated", false)), "supply-drop hold should recover after emergency suppress window")

	var suppressed_state: Object = CommandoSupplyDropState.new()
	suppressed_state.update_input(
		_supply_input(),
		0.5,
		350.0,
		skill_config,
		skill_state,
		{"commando_emergency_supply_state": emergency_state, "current_msec": 1250}
	)
	var after_suppress_result: Dictionary = suppressed_state.update_input(
		_supply_input(),
		0.5,
		350.0,
		skill_config,
		skill_state,
		{"commando_emergency_supply_state": emergency_state, "current_msec": 1500}
	)
	_expect_not_activated(
		after_suppress_result,
		"emergency-supply suppress window should not buffer the same down press into supply drop"
	)


func _verify_original_skill_block_flags_clear_hold() -> void:
	var original_blocked: Dictionary = _run_supply(
		CommandoSupplyDropState.new(),
		_supply_input(),
		{"commando_original_skills_blocked": true}
	)
	_expect_not_activated(original_blocked, "original skill block should prevent supply drop")

	var transformed_blocked: Dictionary = _run_supply(
		CommandoSupplyDropState.new(),
		_supply_input(),
		{"odins_eye_transformed": true}
	)
	_expect_not_activated(transformed_blocked, "transformation block should prevent supply drop")

	var non_commando_blocked: Dictionary = _run_supply(
		CommandoSupplyDropState.new(),
		_supply_input(),
		{"selected_character_type": "viper"}
	)
	_expect_not_activated(non_commando_blocked, "non-Commando character context should not activate supply drop")


func _run_supply(
	supply_state: Object,
	input_snapshot: Dictionary,
	deps: Dictionary,
	special_gauge: float = 500.0
) -> Dictionary:
	var skill_config: Object = deps.get("skill_config", CommandoSkillConfig.new())
	var skill_state: Object = deps.get("skill_state", CommandoSkillState.new())
	return supply_state.update_input(input_snapshot, 1.0, special_gauge, skill_config, skill_state, deps)


func _supply_input() -> Dictionary:
	return {
		"supply_drop_hold_pressed": true,
		"action_pressed": false,
	}


func _feedback_deps(audio: Object) -> Dictionary:
	return {
		"audio": audio,
		"commando_supply_drop_collision_context": {
			"player_pos": Vector2(130.0, 650.0),
			"player_paddle_size": Vector2(155.0, 50.0),
		},
	}


func _down_input(down_pressed: bool) -> Dictionary:
	return {
		"down_pressed": down_pressed,
		"left_pressed": false,
		"right_pressed": false,
		"action_pressed": false,
	}


func _expect_not_activated(result: Dictionary, message: String) -> void:
	_expect(not bool(result.get("activated", false)), message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
