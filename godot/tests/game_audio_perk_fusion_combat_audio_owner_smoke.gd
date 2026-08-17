extends SceneTree

# expect-zero-object-leaks

const OWNER_PATH := "res://scripts/audio/perk_fusion_combat_audio.gd"
const FACADE_PATH := "res://scripts/audio/game_audio.gd"
const PARRY_GATE_PATH := "res://scripts/stages/common/boss_skill_parry_gate.gd"
const BALL_PROCESSOR_PATH := "res://scripts/ball/ball_motion_event_processor.gd"
const SOUND_PATH := "res://assets/sounds/magicdefense.wav"
const EXPECTED_PLAYER_NAME := "PerkFusionSpellbreakerGuardParrySfx"
const EXPECTED_GAIN_DB := -6.0205999

const GameAudio := preload(FACADE_PATH)
const GameAudioPlayerFactory := preload("res://scripts/audio/game_audio_player_factory.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


class RecordingFactory:
	extends RefCounted

	var calls: Array[Dictionary] = []

	func create(parent: Node, player_name: String, path: String, volume_db: float) -> AudioStreamPlayer:
		calls.append({"name": player_name, "path": path, "volume_db": volume_db})
		var player := AudioStreamPlayer.new()
		player.name = player_name
		player.volume_db = volume_db
		player.stream = AudioStreamGenerator.new()
		parent.add_child(player)
		return player


class SpyAudio:
	extends GameAudio

	var played_players: Array[AudioStreamPlayer] = []
	var played_pitches: Array[float] = []

	func _play_with_pitch(player: AudioStreamPlayer, pitch: float) -> bool:
		played_players.append(player)
		played_pitches.append(pitch)
		return player != null and player.stream != null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_owner_boundary_and_runtime_routes()
	if FileAccess.file_exists(OWNER_PATH):
		await _verify_catalog_setup_and_asset()
		await _verify_production_facade()
		await _verify_real_stream_contract()

	if _failures.is_empty():
		print("game_audio_perk_fusion_combat_audio_owner_smoke: ok")
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary_and_runtime_routes() -> void:
	_expect(FileAccess.file_exists(OWNER_PATH), "Mugong-fusion combat cues should have a focused audio owner")
	if not FileAccess.file_exists(OWNER_PATH):
		return
	var facade_source := FileAccess.get_file_as_string(FACADE_PATH)
	var owner_source := FileAccess.get_file_as_string(OWNER_PATH)
	var gate_source := FileAccess.get_file_as_string(PARRY_GATE_PATH)
	var ball_source := FileAccess.get_file_as_string(BALL_PROCESSOR_PATH)
	var activation_source := _function_source(ball_source, "_try_activate_perk_fusion_spellbreaker_guard")
	_expect(facade_source.contains("PerkFusionCombatAudio"), "GameAudio should preload the Mugong-fusion combat audio owner")
	_expect(facade_source.contains("perk_fusion_combat_audio.setup(owner_node, player_factory)"), "fusion combat player setup should delegate")
	_expect(facade_source.contains("perk_fusion_combat_audio.get_prewarm_stream_paths()"), "fusion combat prewarm should delegate")
	_expect(facade_source.contains("perk_fusion_combat_audio.get_players()"), "fusion combat SFX-bus projection should delegate")
	_expect(not facade_source.contains(SOUND_PATH), "GameAudio should not retain the original sound path literal")
	_expect(owner_source.contains(SOUND_PATH), "focused owner should own the original Magic Barrier sound path")
	_expect(not owner_source.contains("randf_range"), "focused owner should not introduce pitch jitter")
	_expect(not owner_source.contains("loop_mode"), "focused owner should not mutate a one-shot stream")
	_expect(gate_source.contains("play_spellbreaker_guard_parry"), "successful boss-skill parries should play the dedicated original cue")
	_expect(not gate_source.contains("play_thor_shield_block"), "spellbreaker parries should not reuse Thor Shield audio")
	_expect(not activation_source.contains("play_thor_shield_open"), "ward activation should remain silent like the original Magic Barrier perk")


func _verify_catalog_setup_and_asset() -> void:
	var owner: Object = _new_owner()
	_expect(owner.get_cue_ids() == ["spellbreaker_guard_parry"], "fusion combat cue catalog should expose one stable cue")
	var spec: Dictionary = owner.get_spec("spellbreaker_guard_parry")
	_expect(str(spec.get("player_name", "")) == EXPECTED_PLAYER_NAME, "parry cue should retain its dedicated player name")
	_expect(str(spec.get("path", "")) == SOUND_PATH, "parry cue should use the ported original sound")
	_expect(is_equal_approx(float(spec.get("gain_db", -99.0)), EXPECTED_GAIN_DB), "parry cue should preserve original linear volume 0.5")
	_expect(owner.get_prewarm_stream_paths() == [SOUND_PATH], "ported parry sound should be prewarmed before battle")
	_expect(owner.get_spec("missing").is_empty(), "unknown fusion combat cues should fail closed")
	_expect(FileAccess.file_exists(SOUND_PATH), "ported original Magic Barrier WAV should exist")
	_expect(ProjectResourceLoader.load_audio_stream(SOUND_PATH) != null, "ported original Magic Barrier WAV should load")

	var host := Node.new()
	get_root().add_child(host)
	var factory := RecordingFactory.new()
	owner.setup(host, factory)
	_expect(factory.calls.size() == 1, "fusion combat owner should create exactly one player")
	if factory.calls.size() == 1:
		var call: Dictionary = factory.calls[0]
		_expect(str(call.get("name", "")) == EXPECTED_PLAYER_NAME, "setup should preserve the dedicated player name")
		_expect(str(call.get("path", "")) == SOUND_PATH, "setup should preserve the ported sound path")
		_expect(is_equal_approx(float(call.get("volume_db", -99.0)), EXPECTED_GAIN_DB), "setup should preserve original volume 0.5 in dB")
	_expect(owner.get_players() == [owner.get_player("spellbreaker_guard_parry")], "SFX-bus projection should contain only the parry player")

	owner = null
	factory = null
	_clear_audio_children(host)
	host.free()
	ProjectResourceLoader.clear_caches()
	for _frame_index: int in range(4):
		await process_frame


func _verify_production_facade() -> void:
	var host := Node.new()
	get_root().add_child(host)
	var factory := RecordingFactory.new()
	var audio := SpyAudio.new()
	audio.owner_node = host
	audio.player_factory = factory
	audio._setup_stage_feedback_sfx()
	var owner: Object = audio.get("perk_fusion_combat_audio")
	var player: AudioStreamPlayer = owner.get_player("spellbreaker_guard_parry")
	var names := _call_names(factory.calls)
	var player_index := names.find(EXPECTED_PLAYER_NAME)
	_expect(player_index >= 0, "production stage-feedback setup should create the fusion parry player")
	_expect(player_index > 0 and str(names[player_index - 1]) == "TrampolineBounceSfx", "fusion cue should remain after the established shared-stage tail setup")

	var prewarm_paths: Array[String] = audio._get_audio_setup_stream_paths(5)
	_expect(prewarm_paths.count(SOUND_PATH) == 1, "global audio prewarm should include the ported parry sound exactly once")
	_expect(not prewarm_paths.is_empty() and prewarm_paths[-1] == SOUND_PATH, "fusion parry sound should stay at the end of stage-feedback prewarm")
	var sfx_players: Array = audio._get_sfx_players()
	_expect(sfx_players.count(player) == 1, "global SFX routing should include the fusion parry player exactly once")
	_expect(not sfx_players.is_empty() and sfx_players[-1] == player, "fusion parry player should stay at the end of the SFX projection")

	audio.play_spellbreaker_guard_parry()
	_expect(audio.played_players == [player], "public parry playback should route the focused player")
	_expect(audio.played_pitches == [1.0], "original parry sound should play at fixed pitch")

	var replacement := _make_player(host, "ReplacementSpellbreakerParry")
	audio.set("spellbreaker_guard_parry_sfx", replacement)
	_expect(audio.get("spellbreaker_guard_parry_sfx") == replacement, "facade parry-player property should remain writable")
	_expect(owner.get_player("spellbreaker_guard_parry") == replacement, "facade replacement should reach the focused owner")

	audio = null
	owner = null
	factory = null
	_clear_audio_children(host)
	host.free()
	for _frame_index: int in range(4):
		await process_frame


func _verify_real_stream_contract() -> void:
	var host := Node.new()
	get_root().add_child(host)
	var owner: Object = _new_owner()
	var factory := GameAudioPlayerFactory.new()
	owner.setup(host, factory)
	var player: AudioStreamPlayer = owner.get_player("spellbreaker_guard_parry")
	var cached: AudioStream = ProjectResourceLoader.load_audio_stream(SOUND_PATH)
	_expect(player != null and player.stream == cached, "parry player should use the shared cached original stream")
	_expect(player != null and is_equal_approx(player.volume_db, EXPECTED_GAIN_DB), "real player should preserve original volume 0.5")
	_expect(player != null and player.bus == "Master", "ported parry cue should enter the normal SFX bus-routing path")
	_expect(player != null and player.stream is AudioStreamWAV, "ported parry cue should retain its WAV stream")
	if player != null and player.stream is AudioStreamWAV:
		_expect((player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED, "ported parry cue should remain a non-looping one-shot")
		player.stream = null

	owner = null
	factory = null
	_clear_audio_children(host)
	host.free()
	ProjectResourceLoader.clear_caches()
	for _frame_index: int in range(4):
		await process_frame


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 1)
	if next_function < 0:
		return source.substr(start)
	return source.substr(start, next_function - start)


func _call_names(calls: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for call: Dictionary in calls:
		result.append(str(call.get("name", "")))
	return result


func _make_player(parent: Node, player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = AudioStreamGenerator.new()
	parent.add_child(player)
	return player


func _new_owner() -> Object:
	var owner_script: Script = load(OWNER_PATH)
	return owner_script.new()


func _clear_audio_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stream = null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
