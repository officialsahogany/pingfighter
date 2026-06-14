extends SceneTree

const GameAudio := preload("res://scripts/audio/game_audio.gd")
const BgmMuteState := preload("res://scripts/audio/bgm_mute_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var host: Node = null
var audio: Object = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	BgmMuteState.set_muted(self, false)
	host = Node.new()
	get_root().add_child(host)
	await process_frame
	await _verify_setup_step_completes_from_cold_cache()
	_verify_setup_uses_sync_audio_prewarm()
	audio = GameAudio.new()
	audio.owner_node = host
	audio._setup_core_ball_sfx()
	audio._setup_item_command_sfx()
	audio._setup_commando_skill_sfx()
	audio._setup_bgm_players()

	_expect(is_equal_approx(float(audio.get_bgm_volume()), 0.4), "BGM volume should use the Godot runtime default")
	_expect(is_equal_approx(float(audio.get_sfx_volume()), 0.7), "SFX volume should use the Python runtime default")
	_expect(audio.lingpet_acquire_cutin_sfx != null and audio.lingpet_acquire_cutin_sfx.stream != null, "lingpet acquisition cut-in SFX player should load its WAV stream")
	_expect(audio.lingpet_lunabi_click_voice_sfx != null and audio.lingpet_lunabi_click_voice_sfx.stream != null, "Lunabi click-reaction voice player should load its MP3 stream")
	_expect(is_equal_approx(float(audio.lingpet_lunabi_click_voice_sfx.volume_db), -4.0), "Lunabi click-reaction voice should sit slightly behind the click Live2D SFX mix")
	_expect(audio.lingpet_volty_click_voice_sfx != null and audio.lingpet_volty_click_voice_sfx.stream != null, "Volty click-reaction voice player should load its MP3 stream")
	_expect(audio.lingpet_milkring_click_voice_sfx != null and audio.lingpet_milkring_click_voice_sfx.stream != null, "Milkring click-reaction voice player should load its MP3 stream")
	_expect(audio.commando_supply_radio_loop_sfx != null and audio.commando_supply_radio_loop_sfx.stream != null, "commando supply radio player should load its WAV stream")
	var supply_radio_stream: AudioStreamWAV = audio.commando_supply_radio_loop_sfx.stream as AudioStreamWAV
	_expect(supply_radio_stream != null and supply_radio_stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "supply radio sample must not loop: Python plays radio.wav once to its natural end, and the supply-drop state no longer force-stops the post-activation tail")
	audio.play_lingpet_acquire_cutin()
	_expect(audio.lingpet_acquire_cutin_sfx.playing, "lingpet acquisition cut-in SFX should enter playback when requested")
	audio.lingpet_acquire_cutin_sfx.stop()
	audio.play_lingpet_click_reaction("lunabi")
	_expect(audio.lingpet_lunabi_click_voice_sfx.playing, "Lunabi click-reaction voice should enter playback when requested")
	audio.lingpet_lunabi_click_voice_sfx.stop()
	audio.play_lingpet_click_reaction("volty")
	_expect(audio.lingpet_volty_click_voice_sfx.playing, "Volty click-reaction voice should enter playback when requested")
	audio.lingpet_volty_click_voice_sfx.stop()
	audio.play_lingpet_click_reaction("milkring")
	_expect(audio.lingpet_milkring_click_voice_sfx.playing, "Milkring click-reaction voice should enter playback when requested")
	audio.lingpet_milkring_click_voice_sfx.stop()
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
	await _cleanup_host_audio_players()
	BgmMuteState.set_muted(self, false)
	await process_frame
	host.queue_free()
	audio = null
	adopted_audio = null
	muted_audio = null
	host = null
	await process_frame
	await process_frame
	await process_frame
	print("game_audio_volume_settings_smoke: ok")
	quit(0)


func _cleanup_host_audio_players() -> void:
	if host == null:
		return
	for child in host.get_children():
		var player := child as AudioStreamPlayer
		if player == null:
			continue
		_cleanup_player(player)
		player.queue_free()
	await process_frame
	await process_frame


func _cleanup_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if player.playing:
		player.stop()
	player.stream = null


func _verify_setup_step_completes_from_cold_cache() -> void:
	ProjectResourceLoader.clear_caches()
	var boot_audio := GameAudio.new()
	var frames := 0
	var previous_progress := -0.001
	while not bool(boot_audio.setup_step(host)):
		frames += 1
		var progress := float(boot_audio.get_setup_progress())
		_expect(progress + 0.001 >= previous_progress, "GameAudio setup progress should not move backward during boot prewarm")
		previous_progress = progress
		_expect(frames <= 320, "GameAudio setup_step should not hold the loading screen at 38 percent")
		await process_frame
	_expect(is_equal_approx(float(boot_audio.get_setup_progress()), 1.0), "GameAudio setup progress should finish at 100 percent")
	_expect(boot_audio.stage1_bgm != null, "GameAudio setup_step should create the required stage BGM player")
	await _cleanup_host_audio_players()
	ProjectResourceLoader.clear_caches()


func _verify_setup_uses_sync_audio_prewarm() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	var prewarm_body := _function_body(source, "func _prewarm_audio_setup_streams_step()")
	var optional_sfx_body := _function_body(source, "func _create_optional_sfx(")
	_expect(
		prewarm_body.find("ProjectResourceLoader.load_audio_stream(path)") >= 0,
		"GameAudio boot setup should cache one audio stream per frame through the synchronous loader"
	)
	_expect(
		prewarm_body.find("prewarm_audio_stream_threaded_step") < 0,
		"GameAudio boot setup should not wait on threaded audio prewarm during the visible 38 percent loading step"
	)
	_expect(
		optional_sfx_body.find("ProjectResourceLoader.audio_resource_exists(path)") >= 0,
		"GameAudio optional SFX setup should accept packed/imported AudioStream resources"
	)
	_expect(
		optional_sfx_body.find("FileAccess.file_exists(\"%s.import\" % path)") < 0,
		"GameAudio optional SFX setup should not depend on raw .import sidecar visibility"
	)
	_expect(
		source.find("FileAccess.file_exists(\"%s.import\" % path)") < 0,
		"GameAudio setup should not depend on raw audio .import sidecar visibility"
	)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
