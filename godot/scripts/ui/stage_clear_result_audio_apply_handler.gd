extends RefCounted

const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")


static func load_dalji_click_voice_stream(current_stage: int, current_stream: AudioStream) -> AudioStream:
	if current_stage != 1:
		return null
	return StageClearResultAssetLoader.load_dalji_click_voice(
		current_stream,
		StageClearResultAssetLoader.DALJI_CLICK_VOICE_PATH
	)


static func play_result_box_open_audio(game_audio: Object) -> bool:
	if game_audio != null and game_audio.has_method("play_result_box_open"):
		game_audio.play_result_box_open()
		return true
	return false
