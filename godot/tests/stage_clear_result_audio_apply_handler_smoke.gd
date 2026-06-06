extends SceneTree

const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const StageClearResultAudioApplyHandler := preload("res://scripts/ui/stage_clear_result_audio_apply_handler.gd")

var _failures: Array[String] = []


class FakeGameAudio:
	extends RefCounted

	var result_box_open_calls := 0

	func play_result_box_open() -> void:
		result_box_open_calls += 1


func _init() -> void:
	_verify_audio_apply_handler_contract()
	_verify_audio_apply_handler_source()
	_verify_scene_delegates_audio_apply_handler()

	if _failures.is_empty():
		print("stage_clear_result_audio_apply_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_audio_apply_handler_contract() -> void:
	_expect(StageClearResultAudioApplyHandler != null, "audio apply handler preload should resolve")
	var existing_stream := AudioStreamGenerator.new()
	_expect(
		StageClearResultAudioApplyHandler.load_dalji_click_voice_stream(2, existing_stream) == null,
		"audio apply handler should clear Dalji voice streams outside Stage 1"
	)
	_expect(
		StageClearResultAudioApplyHandler.load_dalji_click_voice_stream(1, existing_stream) == existing_stream,
		"audio apply handler should preserve already-loaded Stage 1 voice streams"
	)
	var loaded_stream: AudioStream = StageClearResultAudioApplyHandler.load_dalji_click_voice_stream(1, null)
	_expect(loaded_stream != null, "audio apply handler should load the Stage 1 Dalji click voice")

	var game_audio := FakeGameAudio.new()
	_expect(StageClearResultAudioApplyHandler.play_result_box_open_audio(game_audio), "audio apply handler should play result box open SFX")
	_expect(game_audio.result_box_open_calls == 1, "audio apply handler should call result box open SFX once")
	_expect(not StageClearResultAudioApplyHandler.play_result_box_open_audio(null), "audio apply handler should ignore missing game audio")


func _verify_audio_apply_handler_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_audio_apply_handler.gd")
	_expect(source.find("static func load_dalji_click_voice_stream") >= 0, "audio apply handler should expose Dalji voice loading")
	_expect(source.find("static func play_result_box_open_audio") >= 0, "audio apply handler should expose result box open SFX playback")
	_expect(source.find("current_stage != 1") >= 0, "audio apply handler should own the Stage 1 voice gate")
	_expect(source.find("StageClearResultAssetLoader.load_dalji_click_voice") >= 0, "audio apply handler should delegate voice resource loading")
	_expect(source.find("StageClearResultAssetLoader.DALJI_CLICK_VOICE_PATH") >= 0, "audio apply handler should use the canonical Dalji voice path")


func _verify_scene_delegates_audio_apply_handler() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(source.find("StageClearResultAudioApplyHandler.load_dalji_click_voice_stream") >= 0, "result scene should delegate Dalji voice stream loading")
	_expect(source.find("StageClearResultAudioApplyHandler.play_result_box_open_audio") >= 0, "result scene should delegate result box open SFX playback")
	_expect(source.find("StageClearResultAssetLoader.load_dalji_click_voice") < 0, "result scene should not load Dalji voice streams directly")
	_expect(source.find("play_result_box_open()") < 0, "result scene should not call result box open SFX directly")
	_expect(StageClearResultAssetLoader.DALJI_CLICK_VOICE_PATH.ends_with("voice/dalzidefeat.mp3"), "asset loader should keep the canonical Dalji voice path")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
