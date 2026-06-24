extends SceneTree

const GameAudio := preload("res://scripts/audio/game_audio.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var audio := GameAudio.new()
	var host := Node.new()
	root.add_child(host)
	await process_frame

	var move_stream: AudioStream = _verify_stream(GameAudio.UI_MOVE_SOUND_PATH, 0.040, 0.070, "UI move")
	var confirm_stream: AudioStream = _verify_stream(GameAudio.UI_CONFIRM_SOUND_PATH, 0.130, 0.180, "UI confirm")
	var back_stream: AudioStream = _verify_stream(GameAudio.UI_BACK_SOUND_PATH, 0.090, 0.130, "UI back")

	audio.ui_move_sfx = _make_player(host, "UiMoveSfx", move_stream)
	audio.ui_confirm_sfx = _make_player(host, "UiConfirmSfx", confirm_stream)
	audio.ui_back_sfx = _make_player(host, "UiBackSfx", back_stream)

	var sfx_players: Array = audio._get_sfx_players()
	_expect(sfx_players.has(audio.ui_move_sfx), "UI move player should be registered for SFX cleanup/bus routing")
	_expect(sfx_players.has(audio.ui_confirm_sfx), "UI confirm player should be registered for SFX cleanup/bus routing")
	_expect(sfx_players.has(audio.ui_back_sfx), "UI back player should be registered for SFX cleanup/bus routing")

	audio._ensure_audio_bus(GameAudio.SFX_BUS_NAME)
	audio._apply_sfx_bus_to_players()
	_expect(audio.ui_move_sfx.bus == GameAudio.SFX_BUS_NAME, "UI move should route through the central SFX bus")
	_expect(audio.ui_confirm_sfx.bus == GameAudio.SFX_BUS_NAME, "UI confirm should route through the central SFX bus")
	_expect(audio.ui_back_sfx.bus == GameAudio.SFX_BUS_NAME, "UI back should route through the central SFX bus")

	audio.play_ui_move()
	_expect(audio.ui_move_sfx.pitch_scale >= 0.96 and audio.ui_move_sfx.pitch_scale <= 1.05, "UI move should apply small pitch jitter")
	audio.play_ui_confirm()
	_expect(is_equal_approx(audio.ui_confirm_sfx.pitch_scale, 1.0), "UI confirm should play at fixed pitch")
	audio.play_ui_back()
	_expect(is_equal_approx(audio.ui_back_sfx.pitch_scale, 1.0), "UI back should play at fixed pitch")

	host.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("game_audio_ui_sfx_smoke: ok")
	quit(0)


func _verify_stream(path: String, min_length: float, max_length: float, label: String) -> AudioStream:
	_expect(FileAccess.file_exists(path), "%s sound file should exist" % label)
	var stream: AudioStream = ProjectResourceLoader.load_audio_stream(path)
	_expect(stream != null, "%s sound file should load through the resource helper" % label)
	var length := stream.get_length()
	_expect(length >= min_length and length <= max_length, "%s length should stay in the intended UI-feedback range" % label)
	return stream


func _make_player(host: Node, player_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	host.add_child(player)
	return player


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
