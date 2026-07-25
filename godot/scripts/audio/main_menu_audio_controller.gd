extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BgmMuteState := preload("res://scripts/audio/bgm_mute_state.gd")
const MainMenuAudioStreamPolicy := preload("res://scripts/audio/main_menu_audio_stream_policy.gd")
const MainMenuAudioSettings := preload("res://scripts/ui/main_menu_audio_settings.gd")

const MAIN_MENU_BGM_PATH := "res://assets/bgm/joseon_dalbuk_bgm.wav"
const MAIN_MENU_START_SFX_PATH := "res://assets/sounds/stagestart_godot_short.wav"
const MAIN_MENU_BGM_GAIN := 0.82
const MAIN_MENU_START_SFX_GAIN := 0.78
const BGM_BUS_NAME := "BGM"
const SFX_BUS_NAME := "SFX"
const DEFAULT_BGM_VOLUME := 0.4
const DEFAULT_SFX_VOLUME := 0.7
const PRELOADED_BGM_PLAYER_NAME := "PreloadedMenuBgmPlayer"

var audio_settings: Object = null
var bgm_player: AudioStreamPlayer = null
var start_sfx_player: AudioStreamPlayer = null
var muted: bool = false
var bgm_handoff_persisted: bool = false


func get_snapshot() -> Dictionary:
	return {
		"bgm_player": bgm_player,
		"start_sfx_player": start_sfx_player,
		"muted": muted,
	}


func restore_muted(tree: SceneTree) -> bool:
	muted = BgmMuteState.is_muted(tree)
	return muted


func start_bgm(owner: Node, tree: SceneTree) -> AudioStreamPlayer:
	if owner == null or Engine.is_editor_hint():
		return bgm_player
	if bgm_player != null and bgm_player.playing:
		return bgm_player
	if tree != null and tree.root != null:
		var preloaded_player := get_preloaded_bgm_player(tree)
		if preloaded_player != null:
			bgm_player = preloaded_player
			if bgm_player.stream != null:
				_normalize_bgm_volume(bgm_player)
				_apply_mute_state(bgm_player)
				return bgm_player
	var player_stream := _load_looping_bgm_stream()
	if player_stream == null:
		return bgm_player
	if bgm_player == null:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.name = "MainMenuBgm"
		owner.add_child(bgm_player)
	_configure_bgm_player(bgm_player, player_stream)
	return bgm_player


func start_preloaded_bgm(tree: SceneTree) -> AudioStreamPlayer:
	if tree == null or tree.root == null or Engine.is_editor_hint():
		return bgm_player
	var preloaded_player := get_preloaded_bgm_player(tree)
	if preloaded_player != null:
		bgm_player = preloaded_player
		if bgm_player.stream != null:
			_normalize_bgm_volume(bgm_player)
			_apply_mute_state(bgm_player)
			return bgm_player
	var player_stream := _load_looping_bgm_stream()
	if player_stream == null:
		return bgm_player
	if bgm_player == null:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.name = PRELOADED_BGM_PLAYER_NAME
		tree.root.add_child(bgm_player)
	_configure_bgm_player(bgm_player, player_stream)
	return bgm_player


func get_preloaded_bgm_player(tree: SceneTree) -> AudioStreamPlayer:
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(PRELOADED_BGM_PLAYER_NAME) as AudioStreamPlayer


func play_start_sfx(owner: Node) -> AudioStreamPlayer:
	if owner == null or Engine.is_editor_hint():
		return start_sfx_player
	var stream := ProjectResourceLoader.load_audio_stream(
		MAIN_MENU_START_SFX_PATH,
		"Missing main-menu start transition sound: %s",
		"Failed to load main-menu start transition sound: %s"
	)
	if stream == null:
		return start_sfx_player
	if start_sfx_player == null:
		start_sfx_player = AudioStreamPlayer.new()
		start_sfx_player.name = "StartTransitionSfx"
		owner.add_child(start_sfx_player)
	MainMenuAudioStreamPolicy.ensure_bus(SFX_BUS_NAME, DEFAULT_SFX_VOLUME)
	start_sfx_player.bus = SFX_BUS_NAME
	start_sfx_player.stream = stream
	start_sfx_player.volume_db = MainMenuAudioStreamPolicy.volume_to_db(MAIN_MENU_START_SFX_GAIN)
	start_sfx_player.pitch_scale = 1.0
	start_sfx_player.play()
	return start_sfx_player


func toggle_bgm(owner: Node, tree: SceneTree) -> bool:
	muted = BgmMuteState.toggle(tree)
	if muted:
		if bgm_player != null and bgm_player.playing:
			bgm_player.stop()
		return true
	if bgm_player == null or bgm_player.stream == null:
		start_bgm(owner, tree)
	elif not bgm_player.playing:
		bgm_player.play()
	return false


func toggle_preloaded_bgm(tree: SceneTree) -> bool:
	muted = BgmMuteState.toggle(tree)
	var player := get_preloaded_bgm_player(tree)
	if player != null:
		bgm_player = player
	if muted:
		if bgm_player != null and bgm_player.playing:
			bgm_player.stop()
		return true
	if bgm_player == null or bgm_player.stream == null:
		start_preloaded_bgm(tree)
	elif not bgm_player.playing:
		bgm_player.play()
	return false


# 시작 전환 시 BGM을 끊지 않고 /root 상주 플레이어로 승격해 캐릭터 선택 →
# 스테이지 로딩까지 같은 곡이 이어지게 한다. 해제는 전투 BGM 핸드오프
# (release_preloaded_bgm_player)가 담당. 씬 소속 플레이어는 재생 위치를
# 보존한 채 /root로 재부모화한다(트리 이탈이 재생을 멈추므로 play(pos) 재개).
func persist_bgm_for_handoff(tree: SceneTree) -> void:
	if bgm_player == null:
		return
	bgm_handoff_persisted = true
	if tree == null or tree.root == null:
		return
	if bgm_player.get_parent() == tree.root:
		bgm_player.name = PRELOADED_BGM_PLAYER_NAME
		return
	var was_playing := bgm_player.playing
	var playback_position := bgm_player.get_playback_position()
	var parent := bgm_player.get_parent()
	if parent != null:
		parent.remove_child(bgm_player)
	bgm_player.name = PRELOADED_BGM_PLAYER_NAME
	tree.root.add_child(bgm_player)
	if was_playing and not muted:
		bgm_player.play(playback_position)


func cancel_bgm_handoff() -> void:
	bgm_handoff_persisted = false


static func release_preloaded_bgm_player(tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	var player := tree.root.get_node_or_null(PRELOADED_BGM_PLAYER_NAME) as AudioStreamPlayer
	if player == null:
		return
	if player.playing:
		player.stop()
	player.stream = null
	player.queue_free()


func stop_bgm(tree: SceneTree) -> void:
	if bgm_player == null:
		return
	if bgm_handoff_persisted:
		# 핸드오프로 /root에 승격된 플레이어는 다음 씬이 입양한다 — 여기서
		# 정지하면 캐릭터 선택 진입 연속성이 끊긴다.
		bgm_player = null
		return
	if bgm_player.playing:
		bgm_player.stop()
	bgm_player.stream = null
	if tree != null and tree.root != null and bgm_player.get_parent() == tree.root:
		bgm_player.queue_free()
	bgm_player = null


func stop_start_sfx() -> void:
	if start_sfx_player == null:
		return
	if start_sfx_player.playing:
		start_sfx_player.stop()
	start_sfx_player.stream = null
	start_sfx_player.queue_free()
	start_sfx_player = null


func get_audio_settings() -> Object:
	if audio_settings == null:
		audio_settings = MainMenuAudioSettings.new()
	return audio_settings


func _load_looping_bgm_stream() -> AudioStream:
	var cached_stream := ProjectResourceLoader.load_audio_stream(
		MAIN_MENU_BGM_PATH,
		"Missing main-menu BGM: %s",
		"Failed to load main-menu BGM: %s"
	)
	return MainMenuAudioStreamPolicy.duplicate_for_looping_player(cached_stream)


func _configure_bgm_player(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if player == null or stream == null:
		return
	MainMenuAudioStreamPolicy.ensure_bus(BGM_BUS_NAME, DEFAULT_BGM_VOLUME)
	player.bus = BGM_BUS_NAME
	player.stream = stream
	player.volume_db = MainMenuAudioStreamPolicy.volume_to_db(MAIN_MENU_BGM_GAIN)
	player.pitch_scale = 1.0
	_apply_mute_state(player)


# adoption 경로는 스트림 재로드 없이 플레이어를 이어받으므로, 이전 씬의
# 덕킹 트윈(-7dB 시작 전환)이 남긴 볼륨을 표준 게인으로 되돌린다.
func _normalize_bgm_volume(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	player.volume_db = MainMenuAudioStreamPolicy.volume_to_db(MAIN_MENU_BGM_GAIN)


func _apply_mute_state(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if muted:
		if player.playing:
			player.stop()
	elif not player.playing:
		player.play()
