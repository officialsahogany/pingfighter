extends SceneTree

const GameAudio := preload("res://scripts/audio/game_audio.gd")
const GameplayLoopAudioCleanup := preload("res://scripts/audio/gameplay_loop_audio_cleanup.gd")

class FakeAudio:
	var calls: Array[String] = []

	func stop_shield_kiting_wind_up() -> void:
		calls.append("stop_shield_kiting_wind_up")

	func stop_whip() -> void:
		calls.append("stop_whip")

	func stop_viper_blade_spin() -> void:
		calls.append("stop_viper_blade_spin")

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

	func stop_lingpet_guardian_enhance_cutin_loop() -> void:
		calls.append("stop_lingpet_guardian_enhance_cutin_loop")

var _failures: Array[String] = []


func _init() -> void:
	var audio := FakeAudio.new()
	GameplayLoopAudioCleanup.stop_all(audio)

	for method in [
		"stop_shield_kiting_wind_up",
		"stop_whip",
		"stop_viper_blade_spin",
		"stop_commando_supply_radio_loop",
		"stop_stage5_hongryun_fireball",
		"stop_stage5_hongryun_charge",
		"stop_stage5_hongryun_shoot",
		"stop_lingpet_gatling_loop",
		"stop_lingpet_guardian_enhance_cutin_loop",
	]:
		_expect(audio.calls.has(method), "gameplay loop cleanup should call %s" % method)

	var game_audio := GameAudio.new()
	_verify_cleanup_methods_exist_on_game_audio(game_audio)
	_verify_synced_loop_methods_are_registered(game_audio)
	_verify_manual_round_boundary_cues_are_registered()

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


func _verify_cleanup_methods_exist_on_game_audio(game_audio: Object) -> void:
	for stop_method in GameplayLoopAudioCleanup.STOP_METHODS:
		_expect(
			game_audio.has_method(str(stop_method)),
			"GameAudio should expose %s for central gameplay loop cleanup" % stop_method
		)
	_expect(game_audio.has_method("is_shield_kiting_wind_up_playing"), "GameAudio should expose shield wind-up playing query")


func _verify_synced_loop_methods_are_registered(game_audio: Object) -> void:
	for method_info in game_audio.get_method_list():
		if not (method_info is Dictionary):
			continue
		var method_name := str(method_info.get("name", ""))
		if not method_name.begins_with("sync_"):
			continue
		var stop_method := "stop_%s" % method_name.substr("sync_".length())
		_expect(
			GameplayLoopAudioCleanup.STOP_METHODS.has(stop_method),
			"GameplayLoopAudioCleanup should include %s for %s" % [stop_method, method_name]
		)


func _verify_manual_round_boundary_cues_are_registered() -> void:
	for stop_method in [
		"stop_whip",
		"stop_viper_blade_spin",
		"stop_chaos_spear_windup",
		"stop_chaos_spear_flying",
		"stop_chaos_spear_impact",
		"stop_lingpet_guardian_enhance_cutin_loop",
	]:
		_expect(
			GameplayLoopAudioCleanup.STOP_METHODS.has(stop_method),
			"manual long gameplay cue %s should be stopped by round-boundary cleanup" % stop_method
		)
