extends SceneTree

const GameAudio := preload("res://scripts/audio/game_audio.gd")
const GameplayLoopAudioCleanup := preload("res://scripts/audio/gameplay_loop_audio_cleanup.gd")

class FakeAudio:
	var calls: Array[String] = []

	func stop_shield_kiting_wind_up() -> void:
		calls.append("stop_shield_kiting_wind_up")

	func stop_commando_supply_radio_loop() -> void:
		calls.append("stop_commando_supply_radio_loop")

	func stop_stage5_hongryun_fireball() -> void:
		calls.append("stop_stage5_hongryun_fireball")

	func stop_stage5_hongryun_charge() -> void:
		calls.append("stop_stage5_hongryun_charge")

	func stop_stage5_hongryun_shoot() -> void:
		calls.append("stop_stage5_hongryun_shoot")

	func stop_lingpet_gatling_loop() -> void:
		calls.append("stop_lingpet_gatling_loop")

var _failures: Array[String] = []


func _init() -> void:
	var audio := FakeAudio.new()
	GameplayLoopAudioCleanup.stop_all(audio)

	for method in [
		"stop_shield_kiting_wind_up",
		"stop_commando_supply_radio_loop",
		"stop_stage5_hongryun_fireball",
		"stop_stage5_hongryun_charge",
		"stop_stage5_hongryun_shoot",
		"stop_lingpet_gatling_loop",
	]:
		_expect(audio.calls.has(method), "gameplay loop cleanup should call %s" % method)

	var game_audio := GameAudio.new()
	_expect(game_audio.has_method("stop_shield_kiting_wind_up"), "GameAudio should expose shield wind-up cleanup")
	_expect(game_audio.has_method("is_shield_kiting_wind_up_playing"), "GameAudio should expose shield wind-up playing query")
	_expect(game_audio.has_method("stop_lingpet_gatling_loop"), "GameAudio should expose Volty Gatling loop cleanup")

	GameplayLoopAudioCleanup.stop_all(null)

	if _failures.is_empty():
		print("gameplay_loop_audio_cleanup_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
