extends SceneTree

# expect-zero-object-leaks

const OWNER_PATH := "res://scripts/audio/lingpet_acquisition_audio.gd"
const FACADE_PATH := "res://scripts/audio/game_audio.gd"
const GameAudio := preload(FACADE_PATH)

const REQUIRED_CUE_IDS := [
	"cutin",
	"click_deep_bass",
	"click_crackle_sweep",
	"guardian_enhance_roll_loop",
	"guardian_enhance_stamp",
	"guardian_enhance_result_tail",
]
const EXPECTED_SPECS := {
	"cutin": ["LingpetAcquireCutinSfx", "res://assets/sounds/lingpet/lingpet_acquire_ominous_shadow_shimmer_02.wav", 0.0],
	"click_deep_bass": ["LingpetAcquireClickDeepBassSfx", "res://assets/sounds/lingpet/lingpet_acquire_click_deep_bass_doom.wav", -2.0],
	"click_crackle_sweep": ["LingpetAcquireClickCrackleSweepSfx", "res://assets/sounds/lingpet/lingpet_acquire_click_magic_crackle_sweep.wav", -5.0],
	"guardian_enhance_roll_loop": ["LingpetGuardianEnhanceRollLoopSfx", "res://assets/sounds/lingpet/guardian_enhance_roll_loop.wav", -8.0],
	"guardian_enhance_stamp": ["LingpetGuardianEnhanceStampSfx", "res://assets/sounds/lingpet/guardian_enhance_stamp.wav", -2.0],
	"guardian_enhance_result_tail": ["LingpetGuardianEnhanceResultTailSfx", "res://assets/sounds/lingpet/guardian_enhance_result_tail.wav", -6.0],
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
	var force_play_failure := false
	var item_get_fallbacks := 0

	func _play_with_pitch(player: AudioStreamPlayer, pitch: float) -> bool:
		played_players.append(player)
		played_pitches.append(pitch)
		return not force_play_failure and player != null and player.stream != null

	func play_item_get() -> void:
		item_get_fallbacks += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var focused_facade_ready := _verify_owner_boundary()
	if FileAccess.file_exists(OWNER_PATH):
		await _verify_catalog_setup_and_lazy_recovery()
		if focused_facade_ready:
			await _verify_production_facade()

	if _failures.is_empty():
		print("game_audio_lingpet_acquisition_audio_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> bool:
	_expect(FileAccess.file_exists(OWNER_PATH), "Guardian Spirit acquisition cues should have a focused audio owner")
	if not FileAccess.file_exists(OWNER_PATH):
		return false
	var facade_source := FileAccess.get_file_as_string(FACADE_PATH)
	var owner_source := FileAccess.get_file_as_string(OWNER_PATH)
	var focused_facade_ready := facade_source.contains("LingpetAcquisitionAudio")
	_expect(owner_source.contains("const CUE_SPECS"), "focused owner should own the complete acquisition catalog")
	# Commit 5a is intentionally valid before the conditional whole-file 5b
	# migration of game_audio.gd. The facade legs activate as soon as that owner
	# delegation exists in the checked-out tree.
	if not focused_facade_ready:
		return false
	_expect(facade_source.contains("lingpet_acquisition_audio.setup(owner_node, player_factory)"), "eager acquisition setup should delegate")
	_expect(facade_source.contains("lingpet_acquisition_audio.get_prewarm_stream_paths()"), "acquisition prewarm projection should delegate")
	_expect(facade_source.contains("lingpet_acquisition_audio.ensure_player("), "acquisition lazy recovery should delegate")
	_expect(not facade_source.contains("const LINGPET_ACQUIRE_CUTIN_SOUND_PATH"), "GameAudio should not retain acquisition path constants")
	_expect(not facade_source.contains("const LINGPET_ACQUIRE_CUTIN_GAIN_DB"), "GameAudio should not retain acquisition gain constants")
	_expect(not facade_source.contains("func _ensure_lingpet_acquire_cutin_sfx"), "GameAudio should not retain per-cue acquisition ensure methods")
	_expect(not facade_source.contains("player_factory.create(owner_node, \"LingpetAcquireCutinSfx\""), "GameAudio should not recreate acquisition players")
	return true


func _verify_catalog_setup_and_lazy_recovery() -> void:
	var owner: Object = _new_owner()
	var cue_ids: Array[String] = owner.get_cue_ids()
	_expect(cue_ids.size() == REQUIRED_CUE_IDS.size(), "focused owner should expose every declared cue exactly once")
	for required_cue_id in REQUIRED_CUE_IDS:
		_expect(cue_ids.has(required_cue_id), "%s should remain in the focused cue catalog" % required_cue_id)
	for cue_id in cue_ids:
		var expected: Array = EXPECTED_SPECS[cue_id]
		var spec: Dictionary = owner.get_spec(cue_id)
		_expect(str(spec.get("player_name", "")) == expected[0], "%s should retain its player name" % cue_id)
		_expect(str(spec.get("path", "")) == expected[1], "%s should retain its stream path" % cue_id)
		_expect(is_equal_approx(float(spec.get("gain_db", -99.0)), float(expected[2])), "%s should retain its authored gain" % cue_id)
	_expect(owner.get_spec("missing").is_empty(), "unknown acquisition cues should fail closed")
	_expect(owner.get_prewarm_stream_paths() == _expected_paths(cue_ids), "acquisition prewarm should follow the owner's declared cue order")

	var host := Node.new()
	get_root().add_child(host)
	var factory := FakePlayerFactory.new()
	owner.setup(host, factory)
	_expect(factory.calls.size() == cue_ids.size(), "setup should create exactly one player per declared cue")
	for index in cue_ids.size():
		var cue_id: String = cue_ids[index]
		var expected: Array = EXPECTED_SPECS[cue_id]
		var call: Dictionary = factory.calls[index]
		_expect(str(call.get("name", "")) == expected[0], "%s setup should retain player order" % cue_id)
		_expect(str(call.get("path", "")) == expected[1], "%s setup should retain its stream" % cue_id)
		_expect(is_equal_approx(float(call.get("volume_db", -99.0)), float(expected[2])), "%s setup should retain authored gain" % cue_id)
	_expect(owner.get_players() == _players_for_ids(owner, cue_ids), "SFX-bus enumeration should follow the owner's declared cue order")

	var stale_cutin: AudioStreamPlayer = owner.get_player("cutin")
	stale_cutin.stream = null
	var recovered_cutin: AudioStreamPlayer = owner.ensure_player("cutin")
	_expect(recovered_cutin != null and recovered_cutin != stale_cutin and recovered_cutin.stream != null, "lazy recovery should replace a missing cut-in stream")
	_expect(factory.calls.size() == cue_ids.size() + 1, "lazy recovery should create exactly one replacement")
	_expect(owner.ensure_player("missing") == null, "unknown lazy recovery should stay silent")
	_expect(factory.calls.size() == cue_ids.size() + 1, "unknown recovery should not create a player")

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
	var focused_owner: Object = spy.get("lingpet_acquisition_audio")
	focused_owner.setup(host, factory)

	spy.play_lingpet_acquire_cutin()
	_expect(spy.played_players.size() == 1 and spy.played_players[0] == focused_owner.get_player("cutin"), "cut-in facade should route the focused player")
	_expect(spy.played_pitches[0] >= 0.98 and spy.played_pitches[0] <= 1.02, "cut-in facade should preserve pitch jitter")
	spy.played_players.clear()
	spy.played_pitches.clear()
	spy.play_lingpet_acquire_click_reaction_backing()
	_expect(spy.played_players == _players_for_ids(focused_owner, ["click_deep_bass", "click_crackle_sweep"]), "click backing should preserve deep-bass then crackle order")
	_expect(spy.played_pitches == [1.0, 1.0], "click backing should preserve native pitch for both layers")

	spy.force_play_failure = true
	spy.play_lingpet_acquire_cutin()
	_expect(spy.item_get_fallbacks == 1, "failed cut-in playback should preserve item-get fallback")
	spy.force_play_failure = false
	var replacement := AudioStreamPlayer.new()
	replacement.stream = AudioStreamGenerator.new()
	host.add_child(replacement)
	spy.set("lingpet_acquire_cutin_sfx", replacement)
	_expect(spy.get("lingpet_acquire_cutin_sfx") == replacement, "legacy acquisition player property should remain writable")

	var item_prewarm: Array[String] = spy._get_audio_setup_stream_paths(3)
	var prior_index: int = item_prewarm.find("res://assets/sounds/defeat_gem_shatter.wav")
	var acquisition_paths: Array[String] = focused_owner.get_prewarm_stream_paths()
	var acquire_head_index: int = item_prewarm.find(acquisition_paths[0])
	var click_voice_index: int = item_prewarm.find("res://assets/sounds/lingpet/lunabi_click_reaction_voice_v1.mp3")
	_expect(acquire_head_index == prior_index + 1, "global item prewarm should keep acquisition cues after defeat feedback")
	_expect(
		click_voice_index == acquire_head_index + focused_owner.get_cue_ids().size(),
		"global item prewarm should derive the click-voice anchor from the focused cue count"
	)
	var sfx_players: Array = spy._get_sfx_players()
	# The three Guardian Enhancement players remain owner-only until conditional
	# commit 5b wires the facade play/stop surface and global SFX projection.
	for cue_id in ["cutin", "click_deep_bass", "click_crackle_sweep"]:
		_expect(
			sfx_players.has(focused_owner.get_player(cue_id)),
			"global SFX-bus projection should retain the wired acquisition player: %s" % cue_id
		)

	spy = null
	focused_owner = null
	factory = null
	host.free()
	await process_frame
	await process_frame
	await process_frame


func _expected_paths(cue_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for cue_id in cue_ids:
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
