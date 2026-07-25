extends SceneTree

const MainMenuAudioController := preload("res://scripts/audio/main_menu_audio_controller.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var failure_count: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_scene_single_owner_contract()
	ProjectResourceLoader.clear_caches()
	get_root().set_meta("bgm_muted", false)
	get_root().set_meta("main_menu_bgm_muted", false)
	var owner := Node.new()
	get_root().add_child(owner)
	var controller := MainMenuAudioController.new()
	_expect(controller.audio_settings == null, "audio controller should lazily create the settings adapter")
	_expect(not controller.restore_muted(self), "audio controller should restore the unmuted root state")

	var bgm_player: AudioStreamPlayer = controller.start_bgm(owner, self)
	var cached_stream: AudioStream = null
	_expect(bgm_player != null, "audio controller should create the main-menu BGM player")
	if bgm_player != null:
		cached_stream = ProjectResourceLoader.get_cached_audio_stream(MainMenuAudioController.MAIN_MENU_BGM_PATH)
		_expect(cached_stream != null, "main-menu BGM should remain in the shared path cache")
		_expect(bgm_player.stream != cached_stream, "main-menu BGM player should use a private stream duplicate")
		if bgm_player.stream is AudioStreamWAV and cached_stream is AudioStreamWAV:
			_expect(
				(bgm_player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD,
				"main-menu player duplicate should loop forward"
			)
			_expect(
				(cached_stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED,
				"main-menu loop setup should not bleed into the cached stream"
			)

	_expect(controller.toggle_bgm(owner, self), "first toggle should mute the BGM")
	_expect(controller.muted, "controller should retain muted state")
	if bgm_player != null:
		_expect(not bgm_player.playing, "muting should stop the BGM player")
	_expect(not controller.toggle_bgm(owner, self), "second toggle should unmute the BGM")
	if bgm_player != null:
		_expect(bgm_player.playing, "unmuting should resume the BGM player")

	var sfx_player: AudioStreamPlayer = controller.play_start_sfx(owner)
	_expect(sfx_player != null and sfx_player.stream != null, "audio controller should create the start-transition SFX player")
	var audio_snapshot := controller.get_snapshot()
	_expect(audio_snapshot.get("bgm_player", null) == bgm_player, "snapshot should expose the owned BGM player")
	_expect(audio_snapshot.get("start_sfx_player", null) == sfx_player, "snapshot should expose the owned start SFX player")
	_expect(not bool(audio_snapshot.get("muted", true)), "snapshot should expose current mute state")
	_expect(controller.get_audio_settings() != null, "settings host should resolve the shared audio adapter on demand")
	controller.stop_start_sfx()
	_expect(controller.start_sfx_player == null, "SFX teardown should clear the controller facade")
	controller.stop_bgm(self)
	_expect(controller.bgm_player == null, "BGM teardown should clear the controller facade")
	bgm_player = null

	var boot_controller := MainMenuAudioController.new()
	boot_controller.restore_muted(self)
	var preloaded_player: AudioStreamPlayer = boot_controller.start_preloaded_bgm(self)
	await process_frame
	_expect(preloaded_player != null, "boot controller should create the root-preloaded BGM player")
	if preloaded_player != null:
		_expect(preloaded_player.name == MainMenuAudioController.PRELOADED_BGM_PLAYER_NAME, "boot preload should preserve the handoff node name")
		_expect(preloaded_player.get_parent() == get_root(), "boot preload should live at the SceneTree root")
	var menu_controller := MainMenuAudioController.new()
	menu_controller.restore_muted(self)
	var adopted_player: AudioStreamPlayer = menu_controller.start_bgm(owner, self)
	await process_frame
	_expect(adopted_player == preloaded_player, "main-menu controller should adopt the boot-preloaded player")
	menu_controller.stop_bgm(self)
	_expect(menu_controller.bgm_player == null, "adopted root player teardown should clear the menu controller facade")

	sfx_player = null
	cached_stream = null
	controller = null
	boot_controller = null
	menu_controller = null
	preloaded_player = null
	adopted_player = null
	owner.queue_free()
	owner = null
	await process_frame
	await process_frame
	await process_frame
	ProjectResourceLoader.clear_caches()
	get_root().set_meta("bgm_muted", false)
	get_root().set_meta("main_menu_bgm_muted", false)

	if failure_count > 0:
		quit(1)
		return
	print("main_menu_audio_controller_smoke: ok")
	quit(0)


func _verify_scene_single_owner_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/main_menu_scene.gd")
	for mirror_name in ["main_menu_bgm_player", "start_transition_sfx_player", "main_menu_bgm_muted"]:
		_expect(source.find("var %s" % mirror_name) == -1, "%s mirror should be removed" % mirror_name)
	_expect(source.find("func _sync_audio_facade") == -1, "main menu should not synchronize audio mirrors")
	_expect(source.find("var main_menu_audio_controller: MainMenuAudioController") >= 0, "main menu should keep one typed audio owner")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
