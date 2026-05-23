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
	_verify_missing_audio_is_noop()

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


func _verify_missing_audio_is_noop() -> void:
	CommandoFirearmAudioDispatcher.play_weapon_audio_method({}, ["missing_method"], "missing_fallback", "ak47")
	CommandoFirearmAudioDispatcher.play_first_audio_method({}, ["missing_method"])
	CommandoFirearmAudioDispatcher.play_reload_progress_audio({"base_pistol": {"reload_rounds_added": 1}}, {})
	CommandoFirearmAudioDispatcher.stop_suicide_drone_audio({})
	_expect(true, "missing audio deps should be no-ops")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
