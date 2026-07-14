extends SceneTree

const CharacterSelectAudioController := preload("res://scripts/audio/character_select_audio_controller.gd")

var failure_count := 0
var bgm_finished_calls := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_screen_single_owner_contract()
	var host := Node.new()
	root.add_child(host)
	await process_frame
	var controller := CharacterSelectAudioController.new()
	controller.restore_bgm_muted(self)
	controller.setup(host, Callable(self, "_on_bgm_finished"))

	_expect(controller.bgm_player != null, "controller should create the character-select BGM player")
	_expect(controller.bgm_player.stream != null, "controller should load the character-select BGM stream")
	_expect(CharacterSelectAudioController.BGM_BUS_NAME == "BGM", "controller should retain the shared BGM bus contract")
	_expect(controller.bgm_loop_enabled, "loaded character-select BGM should arm manual looping")
	controller.bgm_player.emit_signal("finished")
	_expect(bgm_finished_calls == 1, "controller should retain the host-provided finished callback contract")
	_expect(controller.click_voice_player != null and controller.confirm_voice_player != null, "controller should create both voice channels")
	_expect(CharacterSelectAudioController.SFX_BUS_NAME == "SFX", "controller should retain the shared SFX bus contract")
	var setup_snapshot := controller.get_snapshot()
	_expect(setup_snapshot.get("bgm_player", null) == controller.bgm_player, "snapshot should expose the owned BGM player")
	_expect(bool(setup_snapshot.get("bgm_loop_enabled", false)), "snapshot should expose loop state")
	_expect(setup_snapshot.get("click_voice_player", null) == controller.click_voice_player, "snapshot should expose the owned click voice player")

	controller.bgm_player.stop()
	controller.on_bgm_finished(true)
	_expect(controller.bgm_player.playing, "finished BGM should restart while its host is active")
	_expect(controller.toggle_bgm(self), "first BGM toggle should mute")
	_expect(controller.bgm_muted and not controller.bgm_player.playing, "mute should stop the BGM player")
	_expect(not controller.toggle_bgm(self), "second BGM toggle should unmute")
	_expect(not controller.bgm_muted and controller.bgm_player.playing, "unmute should resume the loaded BGM")

	var voice_config := {
		"confirm_intro_voice_path": "res://voice/commandoselect.mp3",
		"confirm_intro_voice_delay": 0.25,
		"confirm_intro_voice_volume_db": -5.0,
	}
	controller.prepare_click_voice(voice_config)
	_expect(controller.click_voice_pending, "click voice should inherit the confirm-voice fallback and arm its delay")
	_expect(is_equal_approx(controller.click_voice_delay_remaining, 0.25), "click voice should preserve the configured fallback delay")
	_expect(is_equal_approx(controller.click_voice_player.volume_db, -5.0), "click voice should preserve the configured fallback volume")
	controller.update_click_voice(0.24)
	_expect(controller.click_voice_pending, "click voice should remain pending before the delay expires")
	controller.update_click_voice(0.02)
	_expect(not controller.click_voice_pending and controller.click_voice_player.playing, "click voice should play once its delay expires")
	controller.stop_click_voice()
	_expect(controller.click_voice_player.stream == null, "stopping click voice should release its stream")

	controller.prepare_confirm_voice(voice_config)
	_expect(controller.confirm_voice_pending, "confirm voice should arm its own delayed playback")
	controller.update_confirm_voice(0.26)
	_expect(not controller.confirm_voice_pending and controller.confirm_voice_player.playing, "confirm voice should play once its delay expires")
	controller.stop_confirm_voice()
	_expect(controller.confirm_voice_player.stream == null, "stopping confirm voice should release its stream")

	var bgm_player := controller.bgm_player
	controller.teardown(Callable(self, "_on_bgm_finished"))
	_expect(controller.bgm_player == null and controller.click_voice_player == null and controller.confirm_voice_player == null, "teardown should clear all player references")
	_expect(not controller.bgm_loop_enabled, "teardown should disarm BGM looping")
	_expect(not is_instance_valid(bgm_player), "teardown should free detached audio players immediately")
	host.queue_free()
	bgm_player = null
	controller = null
	host = null
	await process_frame
	await process_frame
	# play()가 만든 AudioStreamPlayback은 stop() 후에도 오디오 스레드의 다음
	# mix 패스에서야 해제된다. 헤드리스 프레임은 실시간보다 빨라 즉시 quit하면
	# 해제가 프로세스 종료와 경합해 ObjectDB 누수 경고가 뜬다 — 실시간으로
	# mix 패스를 기다려 드레인한다.
	OS.delay_msec(250)
	await process_frame
	await process_frame

	if failure_count > 0:
		quit(1)
		return
	print("character_select_audio_controller_smoke: ok")
	quit(0)


func _verify_screen_single_owner_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/character_select_screen.gd")
	for mirror_name in [
		"character_select_bgm_player",
		"character_select_bgm_loop_enabled",
		"character_select_bgm_muted",
		"click_motion_voice_player",
		"click_motion_voice_pending",
		"click_motion_voice_delay_remaining",
		"confirm_intro_voice_player",
		"confirm_intro_voice_pending",
		"confirm_intro_voice_delay_remaining",
	]:
		_expect(source.find("var %s" % mirror_name) == -1, "%s mirror should be removed" % mirror_name)
	_expect(source.find("func _sync_audio_facade") == -1, "screen should not synchronize audio mirrors")
	_expect(source.find("var _audio_controller: CharacterSelectAudioController") >= 0, "screen should keep one typed audio owner")


func _on_bgm_finished() -> void:
	bgm_finished_calls += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
