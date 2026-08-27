extends SceneTree

const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropAudioState := preload("res://scripts/characters/commando_supply_drop_audio_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")

const AUDIO_STATE_PATH := "res://scripts/characters/commando_supply_drop_audio_state.gd"
const HOST_PATH := "res://scripts/characters/commando_supply_drop_state.gd"

var _failures: Array[String] = []


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

	func stop_commando_supply_aircraft_loop() -> void:
		calls.append("stop_commando_supply_aircraft_loop")

	func play_commando_supply_drop() -> void:
		calls.append("play_commando_supply_drop")

	func play_grenade_explosion() -> void:
		calls.append("play_grenade_explosion")


class FallbackAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_commando_supply_radio() -> void:
		calls.append("play_commando_supply_radio")

	func play_commando_supply_drop() -> void:
		calls.append("play_commando_supply_drop")


func _init() -> void:
	_verify_owner_boundary()
	_verify_direct_audio_contract()
	_verify_alias_fallbacks()
	_verify_restore_contract()
	_verify_production_host_facade()
	if _failures.is_empty():
		print("commando_supply_drop_audio_state_refactor_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_owner_boundary() -> void:
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var owner_source := FileAccess.get_file_as_string(AUDIO_STATE_PATH)
	_expect(
		host_source.find("const CommandoSupplyDropAudioState := preload(\"%s\")" % AUDIO_STATE_PATH) >= 0,
		"Supply Drop host should preload the focused audio state"
	)
	_expect(
		host_source.find("var _audio_state: Object = CommandoSupplyDropAudioState.new()") >= 0,
		"Supply Drop host should retain one audio state instance"
	)
	for moved_marker in [
		"var aircraft_audio_active",
		"func _stop_aircraft_audio(",
		"func _play_audio_method(",
		"func _play_first_audio_method(",
	]:
		_expect(host_source.find(moved_marker) < 0, "Supply Drop host should not retain audio marker %s" % moved_marker)
	for delegation in [
		"_audio_state.play_hold_radio(deps)",
		"_audio_state.play_activation_radio(deps)",
		"_audio_state.stop_hold_radio(deps)",
		"_audio_state.start_aircraft_loop(deps)",
		"_audio_state.stop_aircraft_loop(deps)",
		"_audio_state.play_drop(deps)",
		"_audio_state.play_crash(deps)",
		"_audio_state.restore(normalized, deps)",
	]:
		_expect(host_source.find(delegation) >= 0, "Supply Drop host should delegate %s" % delegation)
	for owner_marker in [
		"func reset(",
		"func restore(",
		"func start_aircraft_loop(",
		"func stop_aircraft_loop(",
		"func play_hold_radio(",
		"func stop_hold_radio(",
		"func play_activation_radio(",
		"func play_drop(",
		"func play_crash(",
	]:
		_expect(owner_source.find(owner_marker) >= 0, "audio state should implement %s" % owner_marker)


func _verify_direct_audio_contract() -> void:
	var state: Object = CommandoSupplyDropAudioState.new()
	var audio := FakeAudio.new()
	var deps := {"audio": audio}
	state.play_hold_radio(deps)
	state.play_activation_radio(deps)
	state.play_drop(deps)
	state.play_crash(deps)
	_expect(audio.calls == [
		"play_commando_supply_radio_loop",
		"play_commando_supply_radio",
		"play_commando_supply_drop",
		"play_grenade_explosion",
	], "audio state should preserve hold/activation/drop/crash cue order and preferred aliases")
	state.start_aircraft_loop(deps)
	state.start_aircraft_loop(deps)
	_expect(audio.calls.count("play_commando_supply_aircraft_loop") == 1, "aircraft loop start should be edge-triggered")
	_expect(state.is_aircraft_loop_active(), "aircraft loop state should become active after start")
	_expect(bool(state.get_snapshot().get("aircraft_audio_active", false)), "audio snapshot should expose the active loop gate")
	state.stop_aircraft_loop(deps)
	state.stop_aircraft_loop(deps)
	_expect(audio.calls.count("stop_commando_supply_aircraft_loop") == 1, "aircraft loop stop should be edge-triggered")
	_expect(not state.is_aircraft_loop_active(), "aircraft loop state should clear after stop")
	state.stop_hold_radio(deps)
	_expect(audio.calls.back() == "stop_commando_supply_radio_loop", "forced hold cleanup should call the radio stop method")


func _verify_alias_fallbacks() -> void:
	var state: Object = CommandoSupplyDropAudioState.new()
	var fallback := FallbackAudio.new()
	var deps := {"game_audio": fallback}
	state.play_hold_radio(deps)
	state.play_crash(deps)
	_expect(fallback.calls == ["play_commando_supply_radio", "play_commando_supply_drop"], "audio state should use game_audio and fallback aliases")
	state.start_aircraft_loop({})
	_expect(state.is_aircraft_loop_active(), "missing audio dependency should not corrupt the intended aircraft-loop gate")
	state.stop_aircraft_loop({})
	_expect(not state.is_aircraft_loop_active(), "missing audio dependency should still clear the aircraft-loop gate")


func _verify_restore_contract() -> void:
	var state: Object = CommandoSupplyDropAudioState.new()
	var audio := FakeAudio.new()
	state.restore({"aircraft_audio_active": true}, {"audio": audio})
	_expect(state.is_aircraft_loop_active(), "restore should recover an eligible aircraft loop gate")
	_expect(audio.calls == ["play_commando_supply_aircraft_loop"], "restore should restart an eligible aircraft loop once")
	state.restore({"aircraft_audio_active": false}, {"audio": audio})
	_expect(not state.is_aircraft_loop_active(), "inactive restore should clear the loop gate")
	_expect(audio.calls.count("play_commando_supply_aircraft_loop") == 1, "inactive restore should not replay the aircraft loop")


func _verify_production_host_facade() -> void:
	var state: Object = CommandoSupplyDropState.new()
	var audio := FakeAudio.new()
	var deps := {
		"audio": audio,
		"commando_weapon_controller": CommandoWeaponController.new(),
		"commando_supply_drop_direction": "left_to_right",
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_forced_payloads": [{"type": "field_item", "item_id": "gauge_charge"}],
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"commando_supply_drop_payload_delays": [1.15],
	}
	var activation: Dictionary = state.update_input(
		{"down_pressed": true, "action_pressed": true},
		1.0,
		500.0,
		CommandoSkillConfig.new(),
		CommandoSkillState.new(),
		deps
	)
	_expect(bool(activation.get("activated", false)), "production host should activate for audio-state integration")
	_expect(audio.calls == ["play_commando_supply_radio", "play_commando_supply_aircraft_loop"], "production activation should route radio then immediate aircraft loop")
	_expect(state.is_aircraft_audio_active(), "production host facade should expose the audio-state loop gate")
	_expect(bool(state.get_snapshot().get("aircraft_audio_active", false)), "production snapshot should compose the audio-state gate")
	_expect(state.shoot_down_aircraft(deps, "audio_state_smoke"), "production aircraft should enter crash state")
	_expect(audio.calls.count("stop_commando_supply_aircraft_loop") == 1, "production shoot-down should stop the delegated aircraft loop")
	_expect(not state.is_aircraft_audio_active(), "production facade should clear after shoot-down")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
