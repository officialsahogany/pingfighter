extends RefCounted

const StageClearResultAudioApplyHandler := preload("res://scripts/ui/stage_clear_result_audio_apply_handler.gd")
const StageClearResultVoicePlayer := preload("res://scripts/ui/stage_clear_result_voice_player.gd")


static func load_audio(scene: Object) -> void:
	if scene == null:
		return
	var current_stream: AudioStream = _get_scene_object(scene, &"_dalji_click_voice_stream") as AudioStream
	scene.set(
		"_dalji_click_voice_stream",
		StageClearResultAudioApplyHandler.load_dalji_click_voice_stream(
			int(scene.get("current_stage")),
			current_stream
		)
	)


static func play_result_box_open_audio(scene: Object) -> bool:
	return StageClearResultAudioApplyHandler.play_result_box_open_audio(
		_get_scene_object(scene, &"_game_audio")
	)


static func play_dalji_click_voice(scene: Node) -> void:
	if scene == null:
		return
	load_audio(scene)
	var player: AudioStreamPlayer = _get_scene_object(scene, &"_dalji_click_voice_player") as AudioStreamPlayer
	var stream: AudioStream = _get_scene_object(scene, &"_dalji_click_voice_stream") as AudioStream
	scene.set(
		"_dalji_click_voice_player",
		StageClearResultVoicePlayer.play_voice(scene, player, stream)
	)


static func play_dalji_click_voice_deferred(scene: Object) -> void:
	StageClearResultVoicePlayer.play_deferred(
		_get_scene_object(scene, &"_dalji_click_voice_player") as AudioStreamPlayer
	)


static func stop_dalji_click_voice(scene: Object) -> void:
	StageClearResultVoicePlayer.stop_voice(
		_get_scene_object(scene, &"_dalji_click_voice_player") as AudioStreamPlayer
	)


static func _get_scene_object(scene: Object, field_name: StringName) -> Object:
	if scene == null:
		return null
	var value: Variant = scene.get(field_name)
	return value if value is Object else null
