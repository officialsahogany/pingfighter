extends SceneTree

# expect-zero-object-leaks

const OWNER_PATH := "res://scripts/audio/stage7_akamu_audio.gd"
const FACADE_PATH := "res://scripts/audio/game_audio.gd"
const GameAudio := preload(FACADE_PATH)

const CUE_ORDER := ["shuriken_shoot", "shuriken_hit", "cloud", "aura_block", "clone_spawn", "clone_out"]
const EXPECTED_SPECS := {
	"shuriken_shoot": ["Stage7AkamuShurikenShootSfx", "res://assets/sounds/stage7_akamu_shuriken_shoot.wav", 0.0],
	"shuriken_hit": ["Stage7AkamuShurikenHitSfx", "res://assets/sounds/stage7_akamu_shuriken_hit.wav", 0.0],
	"cloud": ["Stage7AkamuCloudSfx", "res://assets/sounds/stage7_akamu_cloud.wav", 0.0],
	"aura_block": ["Stage7AkamuAuraBlockSfx", "res://assets/sounds/stage7_akamu_aura_block.wav", 0.0],
	"clone_spawn": ["Stage7AkamuCloneSpawnSfx", "res://assets/sounds/stage7_akamu_clone_spawn.wav", 0.0],
	"clone_out": ["Stage7AkamuCloneOutSfx", "res://assets/sounds/stage7_akamu_clone_out.wav", 0.0],
}

var _failures: Array[String] = []


class FakePlayerFactory:
	extends RefCounted

	var calls: Array[Dictionary] = []

	func create(parent: Node, player_name: String, path: String, volume_db: float) -> AudioStreamPlayer:
		calls.append({"name": player_name, "path": path, "volume_db": volume_db})
		var player := AudioStreamPlayer.new()
		player.name = player_name
		player.volume_db = volume_db
		player.stream = AudioStreamGenerator.new()
		if parent != null:
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
	_verify_owner_boundary()
	if FileAccess.file_exists(OWNER_PATH):
		await _verify_catalog_and_setup()
		await _verify_production_facade()

	if _failures.is_empty():
		print("game_audio_stage7_akamu_audio_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(OWNER_PATH), "Stage 7 Akamu cues should have a focused audio owner")
	if not FileAccess.file_exists(OWNER_PATH):
		return
	var facade_source := FileAccess.get_file_as_string(FACADE_PATH)
	var owner_source := FileAccess.get_file_as_string(OWNER_PATH)
	_expect(facade_source.contains("Stage7AkamuAudio"), "GameAudio should preload the Stage 7 Akamu audio owner")
	_expect(facade_source.contains("stage7_akamu_audio.setup(owner_node, player_factory)"), "Stage 7 Akamu eager setup should delegate")
	_expect(facade_source.contains("stage7_akamu_audio.get_prewarm_stream_paths()"), "Stage 7 Akamu prewarm projection should delegate")
	_expect(facade_source.contains("stage7_akamu_audio.get_players()"), "Stage 7 Akamu SFX-bus projection should delegate")
	_expect(not facade_source.contains("const STAGE7_AKAMU_SHURIKEN_SHOOT_SOUND_PATH"), "GameAudio should not retain Stage 7 Akamu path constants")
	_expect(not facade_source.contains("player_factory.create(owner_node, \"Stage7AkamuShurikenShootSfx\""), "GameAudio should not recreate Stage 7 Akamu players")
	_expect(owner_source.contains("const CUE_SPECS"), "focused owner should own the complete Stage 7 Akamu cue catalog")


func _verify_catalog_and_setup() -> void:
	var owner: Object = _new_owner()
	_expect(owner.get_cue_ids() == CUE_ORDER, "Stage 7 Akamu cue order should remain stable")
	for cue_id in CUE_ORDER:
		var expected: Array = EXPECTED_SPECS[cue_id]
		var spec: Dictionary = owner.get_spec(cue_id)
		_expect(str(spec.get("player_name", "")) == expected[0], "%s should retain its player name" % cue_id)
		_expect(str(spec.get("path", "")) == expected[1], "%s should retain its stream path" % cue_id)
		_expect(is_equal_approx(float(spec.get("gain_db", -99.0)), float(expected[2])), "%s should retain native gain" % cue_id)
	_expect(owner.get_spec("missing").is_empty(), "unknown Stage 7 Akamu cues should fail closed")
	_expect(owner.get_prewarm_stream_paths() == _expected_paths(), "Stage 7 Akamu prewarm order should match eager setup")

	var host := Node.new()
	get_root().add_child(host)
	var factory := FakePlayerFactory.new()
	owner.setup(host, factory)
	_expect(factory.calls.size() == CUE_ORDER.size(), "setup should create exactly six Stage 7 Akamu players")
	for index in CUE_ORDER.size():
		var cue_id: String = CUE_ORDER[index]
		var expected: Array = EXPECTED_SPECS[cue_id]
		var call: Dictionary = factory.calls[index]
		_expect(str(call.get("name", "")) == expected[0], "%s setup should retain player order" % cue_id)
		_expect(str(call.get("path", "")) == expected[1], "%s setup should retain its stream" % cue_id)
		_expect(is_equal_approx(float(call.get("volume_db", -99.0)), float(expected[2])), "%s setup should retain native gain" % cue_id)
	_expect(owner.get_players() == _players_for_ids(owner, CUE_ORDER), "SFX-bus enumeration should preserve Stage 7 Akamu order")

	owner = null
	factory = null
	host.free()
	await process_frame
	await process_frame


func _verify_production_facade() -> void:
	var host := Node.new()
	get_root().add_child(host)
	var factory := FakePlayerFactory.new()
	var spy := SpyAudio.new()
	spy.owner_node = host
	spy.player_factory = factory
	var focused_owner: Object = spy.get("stage7_akamu_audio")
	focused_owner.setup(host, factory)

	var method_specs := [
		["play_stage7_akamu_shuriken_shoot", "shuriken_shoot", 0.97, 1.03],
		["play_stage7_akamu_shuriken_hit", "shuriken_hit", 0.96, 1.04],
		["play_stage7_akamu_cloud", "cloud", 1.0, 1.0],
		["play_stage7_akamu_wind_aura_block", "aura_block", 0.97, 1.03],
		["play_stage7_akamu_clone_spawn", "clone_spawn", 1.0, 1.0],
		["play_stage7_akamu_clone_out", "clone_out", 0.96, 1.04],
	]
	for method_spec in method_specs:
		spy.played_players.clear()
		spy.played_pitches.clear()
		spy.call(str(method_spec[0]))
		_expect(spy.played_players == [focused_owner.get_player(str(method_spec[1]))], "%s should route only its focused player" % method_spec[0])
		_expect(spy.played_pitches.size() == 1 and spy.played_pitches[0] >= float(method_spec[2]) and spy.played_pitches[0] <= float(method_spec[3]), "%s should preserve its pitch policy" % method_spec[0])

	var replacement := AudioStreamPlayer.new()
	replacement.stream = AudioStreamGenerator.new()
	host.add_child(replacement)
	spy.set("stage7_akamu_cloud_sfx", replacement)
	_expect(spy.get("stage7_akamu_cloud_sfx") == replacement, "legacy Stage 7 Akamu player properties should remain writable")

	var prewarm_paths: Array[String] = spy._get_audio_setup_stream_paths(5)
	var prior_index: int = prewarm_paths.find("res://assets/sounds/stage5_hongryun_shoot.wav")
	var head_index: int = prewarm_paths.find(EXPECTED_SPECS["shuriken_shoot"][1])
	var tail_index: int = prewarm_paths.find(EXPECTED_SPECS["clone_out"][1])
	var next_index: int = prewarm_paths.find("res://assets/sounds/leaf.wav")
	_expect(head_index == prior_index + 1, "global stage prewarm should keep Akamu cues after Hongryun cues")
	_expect(next_index == tail_index + 1, "global stage prewarm should keep leaf shield after Akamu cues")
	var sfx_players: Array = spy._get_sfx_players()
	for player in focused_owner.get_players():
		_expect(sfx_players.has(player), "global SFX-bus projection should include every Stage 7 Akamu player")

	spy = null
	focused_owner = null
	factory = null
	host.free()
	await process_frame
	await process_frame
	await process_frame


func _expected_paths() -> Array[String]:
	var result: Array[String] = []
	for cue_id in CUE_ORDER:
		result.append(str(EXPECTED_SPECS[cue_id][1]))
	return result


func _players_for_ids(owner: Object, cue_ids: Array) -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for cue_id in cue_ids:
		result.append(owner.get_player(str(cue_id)))
	return result


func _new_owner() -> Object:
	var owner_script: Script = load(OWNER_PATH)
	return owner_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
