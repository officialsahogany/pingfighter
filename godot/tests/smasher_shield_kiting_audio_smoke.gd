extends SceneTree

const GameplayLoopAudioCleanup := preload("res://scripts/audio/gameplay_loop_audio_cleanup.gd")
const GameAudio := preload("res://scripts/audio/game_audio.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SmasherShieldKitingState := preload("res://scripts/characters/smasher_shield_kiting_state.gd")

class FakeAudio:
	var calls: Array[String] = []
	var wind_up_playing := true

	func play_shield_kiting_wind_up() -> void:
		calls.append("wind_up")
		wind_up_playing = true

	func stop_shield_kiting_wind_up() -> void:
		calls.append("stop_wind_up")
		wind_up_playing = false

	func is_shield_kiting_wind_up_playing() -> bool:
		return wind_up_playing

	func play_shield_kiting_launch() -> void:
		calls.append("launch")

	func play_shield_kiting_hit() -> void:
		calls.append("hit")

var _failures: Array[String] = []


func _init() -> void:
	var state: Object = SmasherShieldKitingState.new()
	var audio := FakeAudio.new()
	var deps := {"audio": audio}

	state._play_wind_up_sound(deps)
	_expect(_count_calls(audio, "wind_up") == 1, "Shield Kiting wind-up should play the wind-up cue")

	state._queue_launch_sound(deps)
	_expect(bool(state.launch_sound_pending), "Launch cue should wait while wind-up is still playing")
	_expect(_count_calls(audio, "launch") == 0, "Launch cue should not overlap a busy wind-up cue")

	state._play_pending_launch_sound(deps)
	_expect(_count_calls(audio, "launch") == 0, "Pending launch should stay queued until wind-up finishes")

	audio.wind_up_playing = false
	state._play_pending_launch_sound(deps)
	_expect(not bool(state.launch_sound_pending), "Pending launch flag should clear after delayed playback")
	_expect(_count_calls(audio, "launch") == 1, "Pending launch should play exactly once after wind-up finishes")

	state._queue_launch_sound(deps)
	_expect(_count_calls(audio, "launch") == 2, "Launch cue should play immediately when wind-up is already done")

	state.launch_sound_pending = true
	audio.wind_up_playing = true
	state.reset_round(deps)
	_expect(not bool(state.launch_sound_pending), "Round reset should clear queued Shield Kiting launch audio")
	_expect(_count_calls(audio, "stop_wind_up") == 1, "Round reset should stop the active Shield Kiting wind-up cue")

	var cleanup_audio := FakeAudio.new()
	GameplayLoopAudioCleanup.stop_all(cleanup_audio)
	_expect(_count_calls(cleanup_audio, "stop_wind_up") == 1, "Global gameplay-audio cleanup should stop Shield Kiting wind-up")

	_expect(ProjectResourceLoader.load_audio_stream(GameAudio.SHIELD_KITING_WIND_UP_SOUND_PATH) != null, "Shield Kiting wind-up asset should load")
	_expect(ProjectResourceLoader.load_audio_stream(GameAudio.SHIELD_KITING_LAUNCH_SOUND_PATH) != null, "Shield Kiting launch asset should load")
	_expect(ProjectResourceLoader.load_audio_stream(GameAudio.SHIELD_KITING_HIT_SOUND_PATH) != null, "Shield Kiting hit asset should load")

	if _failures.is_empty():
		print("smasher_shield_kiting_audio_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _count_calls(audio: FakeAudio, call_name: String) -> int:
	var count := 0
	for value in audio.calls:
		if value == call_name:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
