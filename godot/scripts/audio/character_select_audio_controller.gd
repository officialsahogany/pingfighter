extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BgmMuteState := preload("res://scripts/audio/bgm_mute_state.gd")

const CHARACTER_SELECT_BGM_PATH := "res://assets/bgm/character select.wav"
const BGM_BUS_NAME := "BGM"
const SFX_BUS_NAME := "SFX"

var bgm_player: AudioStreamPlayer = null
var bgm_loop_enabled := false
var bgm_muted := false
var click_voice_player: AudioStreamPlayer = null
var click_voice_pending := false
var click_voice_delay_remaining := 0.0
var confirm_voice_player: AudioStreamPlayer = null
var confirm_voice_pending := false
var confirm_voice_delay_remaining := 0.0


func get_snapshot() -> Dictionary:
	return {
		"bgm_player": bgm_player,
		"bgm_loop_enabled": bgm_loop_enabled,
		"bgm_muted": bgm_muted,
		"click_voice_player": click_voice_player,
		"click_voice_pending": click_voice_pending,
		"click_voice_delay_remaining": click_voice_delay_remaining,
		"confirm_voice_player": confirm_voice_player,
		"confirm_voice_pending": confirm_voice_pending,
		"confirm_voice_delay_remaining": confirm_voice_delay_remaining,
	}


func restore_bgm_muted(tree: SceneTree) -> bool:
	bgm_muted = BgmMuteState.is_muted(tree)
	return bgm_muted


func setup(host: Node, bgm_finished_callback: Callable) -> void:
	if host == null or Engine.is_editor_hint():
		return
	teardown(bgm_finished_callback)

	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "CharacterSelectBGM"
	bgm_player.bus = BGM_BUS_NAME
	if bgm_finished_callback.is_valid() and not bgm_player.is_connected("finished", bgm_finished_callback):
		bgm_player.connect("finished", bgm_finished_callback)
	bgm_player.stream = ProjectResourceLoader.load_audio_stream(
		CHARACTER_SELECT_BGM_PATH,
		"Missing character-select BGM: %s",
		"Failed to load character-select BGM: %s"
	)
	host.add_child(bgm_player)
	if bgm_player.stream != null:
		bgm_loop_enabled = true
		if not bgm_muted:
			bgm_player.play()

	click_voice_player = _create_voice_player(host, "ClickMotionVoice")
	confirm_voice_player = _create_voice_player(host, "ConfirmIntroVoice")


func on_bgm_finished(host_inside_tree: bool) -> void:
	if not bgm_loop_enabled or bgm_muted:
		return
	if bgm_player == null or bgm_player.stream == null or not host_inside_tree:
		return
	bgm_player.play()


func toggle_bgm(tree: SceneTree) -> bool:
	bgm_muted = BgmMuteState.toggle(tree)
	if bgm_muted:
		if bgm_player != null and bgm_player.playing:
			bgm_player.stop()
		return true
	if bgm_player != null and bgm_player.stream != null and not bgm_player.playing:
		bgm_player.play()
	return false


func prepare_click_voice(character: Dictionary) -> void:
	if click_voice_player == null:
		return
	var path := str(character.get("click_motion_voice_path", ""))
	if path == "":
		path = str(character.get("confirm_intro_voice_path", ""))
	if path == "":
		return
	var stream := ProjectResourceLoader.load_audio_stream(path)
	if stream == null:
		return
	click_voice_player.stop()
	click_voice_player.stream = stream
	click_voice_player.volume_db = float(character.get(
		"click_motion_voice_volume_db",
		character.get("confirm_intro_voice_volume_db", -5.0)
	))
	click_voice_delay_remaining = max(0.0, float(character.get(
		"click_motion_voice_delay",
		character.get("confirm_intro_voice_delay", 0.0)
	)))
	click_voice_pending = true
	if click_voice_delay_remaining <= 0.0:
		update_click_voice(0.0)


func update_click_voice(delta: float) -> void:
	if not click_voice_pending:
		return
	click_voice_delay_remaining -= delta
	if click_voice_delay_remaining > 0.0:
		return
	click_voice_pending = false
	click_voice_delay_remaining = 0.0
	if click_voice_player != null and click_voice_player.stream != null:
		click_voice_player.play()


func stop_click_voice() -> void:
	click_voice_pending = false
	click_voice_delay_remaining = 0.0
	if click_voice_player != null:
		click_voice_player.stop()
		click_voice_player.stream = null


func prepare_confirm_voice(character: Dictionary) -> void:
	if confirm_voice_player == null:
		return
	var path := str(character.get("confirm_intro_voice_path", ""))
	if path == "":
		return
	var stream := ProjectResourceLoader.load_audio_stream(path)
	if stream == null:
		return
	confirm_voice_player.stop()
	confirm_voice_player.stream = stream
	confirm_voice_player.volume_db = float(character.get("confirm_intro_voice_volume_db", -6.0))
	confirm_voice_delay_remaining = max(0.0, float(character.get("confirm_intro_voice_delay", 0.0)))
	confirm_voice_pending = true
	if confirm_voice_delay_remaining <= 0.0:
		update_confirm_voice(0.0)


func update_confirm_voice(delta: float) -> void:
	if not confirm_voice_pending:
		return
	confirm_voice_delay_remaining -= delta
	if confirm_voice_delay_remaining > 0.0:
		return
	confirm_voice_pending = false
	confirm_voice_delay_remaining = 0.0
	if confirm_voice_player != null and confirm_voice_player.stream != null:
		confirm_voice_player.play()


func stop_confirm_voice() -> void:
	confirm_voice_pending = false
	confirm_voice_delay_remaining = 0.0
	if confirm_voice_player != null:
		confirm_voice_player.stop()
		confirm_voice_player.stream = null


func teardown(bgm_finished_callback: Callable = Callable()) -> void:
	bgm_loop_enabled = false
	stop_click_voice()
	stop_confirm_voice()
	_dispose_audio_player(bgm_player, bgm_finished_callback)
	_dispose_audio_player(click_voice_player)
	_dispose_audio_player(confirm_voice_player)
	bgm_player = null
	click_voice_player = null
	confirm_voice_player = null


func _create_voice_player(host: Node, player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = SFX_BUS_NAME
	host.add_child(player)
	return player


func _dispose_audio_player(player: AudioStreamPlayer, finished_callback: Callable = Callable()) -> void:
	if player == null:
		return
	if finished_callback.is_valid() and player.is_connected("finished", finished_callback):
		player.disconnect("finished", finished_callback)
	if player.playing:
		player.stop()
	player.stream = null
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	player.free()
