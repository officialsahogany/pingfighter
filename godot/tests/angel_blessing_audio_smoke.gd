extends SceneTree

const GameAudio := preload("res://scripts/audio/game_audio.gd")
const GameplayLoopAudioCleanup := preload("res://scripts/audio/gameplay_loop_audio_cleanup.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []
var _host: Node = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectResourceLoader.clear_caches()
	_host = Node.new()
	_host.name = "AngelBlessingAudioSmokeHost"
	root.add_child(_host)
	await process_frame

	var audio := GameAudio.new()
	_verify_source_assets_and_setup_paths(audio)
	await _run_item_audio_setup_prewarm(audio)
	_verify_setup_players(audio)
	_verify_non_looping_streams(audio)
	_verify_sfx_player_registration(audio)
	_verify_roll_and_three_way_absorb_playback(audio)
	_verify_stop_cleanup(audio)

	_cleanup_audio_nodes(audio)
	audio = null
	ProjectResourceLoader.clear_caches()
	await _drain_frames(8)
	if _host != null:
		_host.free()
		_host = null
	await _drain_frames(8)

	if _failures.is_empty():
		print("angel_blessing_audio_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_source_assets_and_setup_paths(audio: Object) -> void:
	_expect(FileAccess.file_exists(GameAudio.ANGEL_BLESSING_ROLL_SOUND_PATH), "Angel Dice roll WAV should exist")
	_expect(FileAccess.file_exists(GameAudio.ANGEL_BLESSING_ABSORB_SOUND_PATH), "Angel Dice absorb WAV should exist")
	var roll_stream: AudioStream = ProjectResourceLoader.load_audio_stream(GameAudio.ANGEL_BLESSING_ROLL_SOUND_PATH)
	var absorb_stream: AudioStream = ProjectResourceLoader.load_audio_stream(GameAudio.ANGEL_BLESSING_ABSORB_SOUND_PATH)
	_expect(roll_stream is AudioStreamWAV, "Angel Dice roll source should load as AudioStreamWAV")
	_expect(absorb_stream is AudioStreamWAV, "Angel Dice absorb source should load as AudioStreamWAV")
	var item_setup_paths: Array[String] = audio._get_audio_setup_stream_paths(3)
	_expect(GameAudio.ANGEL_BLESSING_ROLL_SOUND_PATH in item_setup_paths, "audio setup step 3 should prewarm the Angel Dice roll WAV")
	_expect(GameAudio.ANGEL_BLESSING_ABSORB_SOUND_PATH in item_setup_paths, "audio setup step 3 should prewarm the Angel Dice absorb WAV")
	ProjectResourceLoader.clear_caches()


func _run_item_audio_setup_prewarm(audio: Object) -> void:
	var setup_calls := 0
	while int(audio.get("_audio_setup_step")) < 4:
		audio.setup_step(_host)
		setup_calls += 1
		_expect(setup_calls <= 240, "GameAudio setup should reach the item-command group without stalling")
		if setup_calls > 240:
			break
		await process_frame
	_expect(int(audio.get("_audio_setup_step")) >= 4, "GameAudio setup should execute the item-command SFX group")
	_expect(ProjectResourceLoader.get_cached_audio_stream(GameAudio.ANGEL_BLESSING_ROLL_SOUND_PATH) != null, "setup prewarm should cache the Angel Dice roll stream")
	_expect(ProjectResourceLoader.get_cached_audio_stream(GameAudio.ANGEL_BLESSING_ABSORB_SOUND_PATH) != null, "setup prewarm should cache the Angel Dice absorb stream")


func _verify_setup_players(audio: Object) -> void:
	_expect(audio.angel_blessing_roll_sfx is AudioStreamPlayer, "setup should create one Angel Dice roll player")
	_expect(audio.angel_blessing_absorb_sfx is AudioStreamPlayer, "setup should create the primary Angel Dice absorb player")
	_expect(audio.angel_blessing_absorb_sfx_layers.size() == GameAudio.ANGEL_BLESSING_ABSORB_POOL_SIZE - 1, "setup should create two extra absorb layers")
	_expect(_absorb_players(audio).size() == GameAudio.ANGEL_BLESSING_ABSORB_POOL_SIZE, "Angel Dice absorb pool should contain exactly three players")


func _verify_non_looping_streams(audio: Object) -> void:
	var players: Array[AudioStreamPlayer] = []
	if audio.angel_blessing_roll_sfx is AudioStreamPlayer:
		players.append(audio.angel_blessing_roll_sfx as AudioStreamPlayer)
	players.append_array(_absorb_players(audio))
	for player: AudioStreamPlayer in players:
		var stream := player.stream as AudioStreamWAV
		_expect(stream != null, "%s should retain its loaded WAV stream" % player.name)
		if stream != null:
			_expect(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s must remain a one-shot, non-looping stream" % player.name)


func _verify_sfx_player_registration(audio: Object) -> void:
	var registered: Array = audio._get_sfx_players()
	_expect(registered.has(audio.angel_blessing_roll_sfx), "roll player should participate in central SFX bus/cleanup enumeration")
	for player: AudioStreamPlayer in _absorb_players(audio):
		_expect(registered.has(player), "%s should participate in central SFX bus/cleanup enumeration" % player.name)
	_expect("stop_angel_blessing_audio" in GameplayLoopAudioCleanup.STOP_METHODS, "round-boundary audio cleanup should invoke Angel Dice forced stop")


func _verify_roll_and_three_way_absorb_playback(audio: Object) -> void:
	audio.play_angel_blessing_roll()
	_expect(audio.angel_blessing_roll_sfx.playing, "roll cue should enter playback")
	for _index: int in range(GameAudio.ANGEL_BLESSING_ABSORB_POOL_SIZE):
		audio.play_angel_blessing_absorb()
	var playing_absorb_count := 0
	for player: AudioStreamPlayer in _absorb_players(audio):
		if player.playing:
			playing_absorb_count += 1
	_expect(playing_absorb_count == GameAudio.ANGEL_BLESSING_ABSORB_POOL_SIZE, "three rapid absorb arrivals should play concurrently without stealing a voice")


func _verify_stop_cleanup(audio: Object) -> void:
	audio.stop_angel_blessing_audio()
	_expect(not audio.angel_blessing_roll_sfx.playing, "explicit Angel Dice cleanup should stop the roll cue")
	for player: AudioStreamPlayer in _absorb_players(audio):
		_expect(not player.playing, "explicit Angel Dice cleanup should stop %s" % player.name)

	# Seal the shared score/serve/reset cleanup dispatcher too, not only the
	# feature-local method in isolation.
	audio.play_angel_blessing_roll()
	audio.play_angel_blessing_absorb()
	GameplayLoopAudioCleanup.stop_all(audio)
	_expect(not audio.angel_blessing_roll_sfx.playing, "shared gameplay audio cleanup should stop the Angel Dice roll cue")
	for player: AudioStreamPlayer in _absorb_players(audio):
		_expect(not player.playing, "shared gameplay audio cleanup should stop %s" % player.name)


func _absorb_players(audio: Object) -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	if audio.angel_blessing_absorb_sfx is AudioStreamPlayer:
		result.append(audio.angel_blessing_absorb_sfx as AudioStreamPlayer)
	for value: Variant in audio.angel_blessing_absorb_sfx_layers:
		if value is AudioStreamPlayer:
			result.append(value as AudioStreamPlayer)
	return result


func _cleanup_audio_nodes(audio: Object) -> void:
	if audio != null and audio.has_method("stop_angel_blessing_audio"):
		audio.stop_angel_blessing_audio()
	if _host == null:
		return
	for child: Node in _host.get_children():
		if child is AudioStreamPlayer:
			var player := child as AudioStreamPlayer
			if player.playing:
				player.stop()
			player.stream = null
		child.free()


func _drain_frames(frame_count: int) -> void:
	for _index: int in range(frame_count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)

