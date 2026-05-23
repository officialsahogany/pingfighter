extends SceneTree

const GameAudio := preload("res://scripts/audio/game_audio.gd")
const BgmMuteState := preload("res://scripts/audio/bgm_mute_state.gd")

var host: Node = null
var audio: Object = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	BgmMuteState.set_muted(self, false)
	host = Node.new()
	get_root().add_child(host)
	await process_frame
	audio = GameAudio.new()
	audio.owner_node = host
	audio._setup_core_ball_sfx()
	audio._setup_bgm_players()

	_expect(is_equal_approx(float(audio.get_bgm_volume()), 0.4), "BGM volume should use the Godot runtime default")
	_expect(is_equal_approx(float(audio.get_sfx_volume()), 0.7), "SFX volume should use the Python runtime default")
	_expect(is_equal_approx(float(audio.set_bgm_volume(0.25)), 0.25), "BGM setter should clamp and return the stored value")
	_expect(is_equal_approx(float(audio.set_sfx_volume(0.85)), 0.85), "SFX setter should clamp and return the stored value")
	_expect(AudioServer.get_bus_index("BGM") >= 0, "BGM bus should exist for option sliders")
	_expect(AudioServer.get_bus_index("SFX") >= 0, "SFX bus should exist for option sliders")
	_expect(audio.stage1_bgm != null and audio.stage1_bgm.bus == "BGM", "BGM players should route through the BGM bus")
	_expect(audio.paddle_hit_sfx != null and audio.paddle_hit_sfx.bus == "SFX", "SFX players should route through the SFX bus")
	_expect(float(audio.set_bgm_volume(4.0)) == 1.0, "BGM setter should clamp high values")
	_expect(float(audio.set_sfx_volume(-1.0)) == 0.0, "SFX setter should clamp low values")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("BGM"), linear_to_db(0.35))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(0.65))
	var adopted_audio := GameAudio.new()
	adopted_audio.owner_node = host
	adopted_audio._apply_audio_buses_and_volumes()
	_expect(is_equal_approx(float(adopted_audio.get_bgm_volume()), 0.35), "GameAudio should adopt the main-menu BGM bus setting on setup")
	_expect(is_equal_approx(float(adopted_audio.get_sfx_volume()), 0.65), "GameAudio should adopt the main-menu SFX bus setting on setup")

	BgmMuteState.set_muted(self, true)
	var muted_audio := GameAudio.new()
	muted_audio.owner_node = host
	muted_audio._setup_bgm_players()
	_expect(bool(muted_audio.is_bgm_muted()), "GameAudio should adopt the shared BGM mute state on setup")
	_expect(bool(muted_audio.play_bgm("stage1")), "muted GameAudio should still remember the requested stage BGM")
	_expect(not muted_audio.stage1_bgm.playing, "muted GameAudio should not start the stage BGM player")
	muted_audio.toggle_bgm()
	_expect(not BgmMuteState.is_muted(self), "GameAudio B toggle should clear the shared BGM mute state")
	_expect(muted_audio.stage1_bgm.playing, "GameAudio B toggle should resume the remembered stage BGM")

	audio.stop_bgm()
	muted_audio.stop_bgm()
	await process_frame
	_cleanup_player(audio.stage1_bgm)
	_cleanup_player(audio.stage2_bgm)
	_cleanup_player(audio.stage2_alt_bgm)
	_cleanup_player(audio.stage3_bgm)
	_cleanup_player(audio.stage4_bgm)
	_cleanup_player(audio.stage4_phase2_bgm)
	_cleanup_player(audio.paddle_hit_sfx)
	_cleanup_player(muted_audio.stage1_bgm)
	_cleanup_player(muted_audio.stage2_bgm)
	_cleanup_player(muted_audio.stage2_alt_bgm)
	_cleanup_player(muted_audio.stage3_bgm)
	_cleanup_player(muted_audio.stage4_bgm)
	_cleanup_player(muted_audio.stage4_phase2_bgm)
	BgmMuteState.set_muted(self, false)
	await process_frame
	host.queue_free()
	audio = null
	adopted_audio = null
	muted_audio = null
	host = null
	await process_frame
	await process_frame
	print("game_audio_volume_settings_smoke: ok")
	quit(0)


func _cleanup_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if player.playing:
		player.stop()
	player.stream = null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
