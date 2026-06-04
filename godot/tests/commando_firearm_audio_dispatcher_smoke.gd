extends SceneTree

const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []
	var generic_fire_calls: Array[String] = []
	var generic_impact_calls: Array[String] = []

	func play_specific_fire() -> void:
		calls.append("specific_fire")

	func play_first_available() -> void:
		calls.append("first_available")

	func play_commando_pistol_reload_round() -> void:
		calls.append("reload_round")

	func play_commando_pistol_reload_start() -> void:
		calls.append("reload_start")

	func stop_commando_suicide_drone_loop() -> void:
		calls.append("stop_drone")

	func play_commando_fire_support_radio() -> void:
		calls.append("support_radio")

	func play_commando_fire_support_aircraft_loop() -> void:
		calls.append("start_aircraft")

	func stop_commando_fire_support_aircraft_loop() -> void:
		calls.append("stop_aircraft")

	func play_commando_firearm_fire(weapon_id: String) -> void:
		generic_fire_calls.append(weapon_id)

	func play_commando_firearm_impact(weapon_id: String) -> void:
		generic_impact_calls.append(weapon_id)


func _init() -> void:
	_verify_specific_method_wins()
	_verify_generic_fallback_and_game_audio_key()
	_verify_first_available_method()
	_verify_reload_progress_round_count()
	_verify_suicide_drone_stop()
	_verify_support_aircraft_loop_state()
	_verify_support_call_start_dispatch()
	_verify_support_aircraft_event_dispatch()
	_verify_missing_audio_is_noop()
	_verify_removed_runtime_audio_dispatcher_bridges()

	if _failures.is_empty():
		print("commando_firearm_audio_dispatcher_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_specific_method_wins() -> void:
	var audio := FakeAudio.new()
	CommandoFirearmAudioDispatcher.play_weapon_audio_method(
		{"audio": audio},
		["missing_method", "play_specific_fire"],
		"play_commando_firearm_fire",
		"ak47"
	)
	_expect(audio.calls == ["specific_fire"], "audio dispatcher should prefer the first implemented specific method")
	_expect(audio.generic_fire_calls.is_empty(), "audio dispatcher should not use fallback after a specific method wins")


func _verify_generic_fallback_and_game_audio_key() -> void:
	var audio := FakeAudio.new()
	CommandoFirearmAudioDispatcher.play_weapon_audio_method(
		{"game_audio": audio},
		["missing_method"],
		"play_commando_firearm_impact",
		"experimental"
	)
	_expect(audio.generic_impact_calls == ["experimental"], "audio dispatcher should fall back through the game_audio dep key")


func _verify_first_available_method() -> void:
	var audio := FakeAudio.new()
	CommandoFirearmAudioDispatcher.play_first_audio_method({"audio": audio}, ["missing_method", "play_first_available"])
	_expect(audio.calls == ["first_available"], "audio dispatcher should call the first available no-arg method")


func _verify_reload_progress_round_count() -> void:
	var audio := FakeAudio.new()
	CommandoFirearmAudioDispatcher.play_reload_progress_audio(
		{
			"base_pistol": {"reload_rounds_added": 1},
			"commando_pistol": {"reload_rounds_added": 2},
		},
		{"audio": audio}
	)
	_expect(audio.calls == ["reload_round", "reload_round", "reload_round"], "reload progress should emit one cue per added pistol round")


func _verify_suicide_drone_stop() -> void:
	var audio := FakeAudio.new()
	CommandoFirearmAudioDispatcher.stop_suicide_drone_audio({"audio": audio})
	_expect(audio.calls == ["stop_drone"], "suicide drone stop should route through the stop loop method")


func _verify_support_aircraft_loop_state() -> void:
	var audio := FakeAudio.new()
	var support_call := {}
	CommandoFirearmAudioDispatcher.start_support_aircraft_audio(support_call, {"audio": audio})
	CommandoFirearmAudioDispatcher.start_support_aircraft_audio(support_call, {"audio": audio})
	_expect(bool(support_call.get("aircraft_audio_active", false)), "support aircraft start should mark the call audio active")
	_expect(audio.calls == ["start_aircraft"], "support aircraft start should not duplicate active loop cues")
	CommandoFirearmAudioDispatcher.stop_support_aircraft_audio(support_call, {"audio": audio})
	CommandoFirearmAudioDispatcher.stop_support_aircraft_audio(support_call, {"audio": audio})
	_expect(not bool(support_call.get("aircraft_audio_active", false)), "support aircraft stop should clear the active flag")
	_expect(audio.calls == ["start_aircraft", "stop_aircraft"], "support aircraft stop should not duplicate inactive loop cues")

	var calls: Array = [
		{"aircraft_audio_active": true},
		{"aircraft_audio_active": false},
	]
	CommandoFirearmAudioDispatcher.stop_all_support_aircraft_audio(calls, {"audio": audio})
	_expect(not bool(CommandoFirearmAudioDispatcher._get_dict(calls[0]).get("aircraft_audio_active", true)), "support aircraft stop-all should clear active call audio")
	_expect(audio.calls == ["start_aircraft", "stop_aircraft", "stop_aircraft"], "support aircraft stop-all should stop only active calls")


func _verify_support_call_start_dispatch() -> void:
	var audio := FakeAudio.new()
	var evicted_call := {"aircraft_audio_active": true}
	CommandoFirearmAudioDispatcher.dispatch_support_call_start_audio(
		{"evicted_calls": [evicted_call, "bad_call"]},
		{"audio": audio}
	)
	_expect(not bool(evicted_call.get("aircraft_audio_active", true)), "support call start dispatch should stop evicted aircraft loops")
	_expect(audio.calls == ["stop_aircraft", "support_radio"], "support call start dispatch should stop evicted loops before radio cue")


func _verify_support_aircraft_event_dispatch() -> void:
	var audio := FakeAudio.new()
	var start_call := {"aircraft_audio_active": false}
	var stop_call := {"aircraft_audio_active": true}
	CommandoFirearmAudioDispatcher.dispatch_support_aircraft_audio_events(
		[
			{"type": "start_aircraft", "call": start_call},
			{"type": "stop_aircraft", "call": stop_call},
			{"type": "ignored", "call": {"aircraft_audio_active": true}},
			"bad_event",
		],
		{"audio": audio}
	)
	_expect(bool(start_call.get("aircraft_audio_active", false)), "support aircraft event dispatch should mark started calls active")
	_expect(not bool(stop_call.get("aircraft_audio_active", true)), "support aircraft event dispatch should clear stopped calls")
	_expect(audio.calls == ["start_aircraft", "stop_aircraft"], "support aircraft event dispatch should route start and stop cues in order")


func _verify_missing_audio_is_noop() -> void:
	CommandoFirearmAudioDispatcher.play_weapon_audio_method({}, ["missing_method"], "missing_fallback", "ak47")
	CommandoFirearmAudioDispatcher.play_first_audio_method({}, ["missing_method"])
	CommandoFirearmAudioDispatcher.play_reload_progress_audio({"base_pistol": {"reload_rounds_added": 1}}, {})
	CommandoFirearmAudioDispatcher.stop_suicide_drone_audio({})
	CommandoFirearmAudioDispatcher.start_support_aircraft_audio({}, {})
	CommandoFirearmAudioDispatcher.stop_support_aircraft_audio({"aircraft_audio_active": true}, {})
	CommandoFirearmAudioDispatcher.stop_all_support_aircraft_audio([{"aircraft_audio_active": true}], {})
	CommandoFirearmAudioDispatcher.dispatch_support_call_start_audio({"evicted_calls": [{"aircraft_audio_active": true}]}, {})
	CommandoFirearmAudioDispatcher.dispatch_support_aircraft_audio_events([{"type": "start_aircraft", "call": {}}], {})
	_expect(true, "missing audio deps should be no-ops")


func _verify_removed_runtime_audio_dispatcher_bridges() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	var fire_spawn_source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_fire_spawn_state.gd")
	var support_source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_support_projectile_resolver.gd")
	for bridge_name in [
		"_play_weapon_audio_method",
		"_play_first_audio_method",
		"_play_reload_progress_audio",
		"_stop_suicide_drone_audio",
		"_play_fire_audio",
		"_play_impact_audio",
		"_start_support_aircraft_audio",
		"_stop_support_aircraft_audio",
		"_stop_all_support_aircraft_audio",
	]:
		_expect(source.find("func %s" % bridge_name) < 0, "runtime should not keep audio dispatcher bridge %s" % bridge_name)
	_expect(
		source.find("CommandoFirearmAudioDispatcher.dispatch_support_aircraft_audio_events") < 0,
		"runtime should not keep support aircraft audio event dispatch inline"
	)
	_expect(
		support_source.find("CommandoFirearmAudioDispatcher.dispatch_support_aircraft_audio_events") >= 0,
		"support projectile resolver should delegate support aircraft audio event dispatch to the audio dispatcher"
	)
	_expect(
		fire_spawn_source.find("CommandoFirearmAudioDispatcher.dispatch_support_call_start_audio") >= 0,
		"fire spawn state should delegate support call start audio dispatch to the audio dispatcher"
	)
	_expect(
		source.find("play_commando_fire_support_radio") < 0,
		"runtime should not keep the fire-support radio cue list inline"
	)
	_expect(
		fire_spawn_source.find("play_commando_fire_support_radio") < 0,
		"fire spawn state should not keep the fire-support radio cue list inline"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
