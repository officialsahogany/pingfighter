extends SceneTree

const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultAudioSceneHandler := preload("res://scripts/ui/stage_clear_result_audio_scene_handler.gd")
const StageClearResultVoicePlayer := preload("res://scripts/ui/stage_clear_result_voice_player.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_voice_player_helper()
	_verify_scene_delegates_voice_player()

	if _failures.is_empty():
		print("stage_clear_result_voice_player_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_voice_player_helper() -> void:
	_expect(
		StageClearResultVoicePlayer.play_voice(null, null, null, -6.0, "MissingVoice", &"_noop") == null,
		"voice helper should ignore null streams without creating a player"
	)

	var parent := Node.new()
	get_root().add_child(parent)
	var stream := AudioStreamGenerator.new()
	var player: AudioStreamPlayer = StageClearResultVoicePlayer.play_voice(
		parent,
		null,
		stream,
		-9.0,
		"TestResultVoice",
		&"_noop"
	)
	_expect(player != null, "voice helper should create a player for valid streams")
	_expect(player.get_parent() == parent, "voice helper should attach created players to the parent")
	_expect(player.stream == stream, "voice helper should assign the requested stream")
	_expect(is_equal_approx(player.volume_db, -9.0), "voice helper should assign the requested volume")
	StageClearResultVoicePlayer.stop_voice(player)
	parent.free()


func _verify_scene_delegates_voice_player() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_audio_scene_handler.gd")
	var actor_click_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_actor_click_scene_handler.gd")
	var callback_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_callback_scene_handler.gd")
	var config_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
	var voice_player_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_voice_player.gd")
	_expect(actor_click_scene_handler_source.find("StageClearResultAudioSceneHandler.play_dalji_click_voice") >= 0, "actor click scene handler should delegate voice playback setup to the audio scene handler")
	_expect(source.find("func _play_dalji_click_voice_deferred") < 0, "result scene should not keep a deferred voice playback callback")
	_expect(callback_scene_handler_source.find("StageClearResultAudioSceneHandler.stop_dalji_click_voice") >= 0, "callback scene handler should delegate voice stopping to the audio scene handler")
	_expect(config_scene_handler_source.find("StageClearResultAudioSceneHandler.stop_dalji_click_voice") >= 0, "config scene handler should delegate voice cleanup to the audio scene handler")
	_expect(source.find("func _play_dalji_click_voice()") < 0, "result scene should not keep the direct voice playback wrapper")
	_expect(source.find("func _stop_dalji_click_voice()") < 0, "result scene should not keep the direct voice stop wrapper")
	_expect(source.find("StageClearResultVoicePlayer.") < 0, "result scene should not call the voice player directly")
	_expect(voice_player_source.find("parent.call_deferred(deferred_method)") >= 0, "voice player should keep explicit deferred-method compatibility")
	_expect(scene_handler_source.find("StageClearResultVoicePlayer.play_voice") >= 0, "audio scene handler should delegate voice playback setup")
	_expect(scene_handler_source.find("StageClearResultVoicePlayer.play_deferred") >= 0, "audio scene handler should delegate deferred voice playback")
	_expect(scene_handler_source.find("StageClearResultVoicePlayer.stop_voice") >= 0, "audio scene handler should delegate voice stopping")
	_expect(source.find("AudioStreamPlayer.new()") < 0, "result scene should not create the Dalji voice player directly")
	_expect(StageClearResultAudioSceneHandler != null, "audio scene handler preload should resolve")
	_expect(StageClearResultScene != null, "result scene preload should still resolve with voice helper")


func _noop() -> void:
	pass


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
