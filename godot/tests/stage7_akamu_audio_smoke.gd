extends SceneTree

const GameAudio := preload("res://scripts/audio/game_audio.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const EXPECTED_SFX := {
	"Stage7AkamuShurikenShootSfx": "res://assets/sounds/stage7_akamu_shuriken_shoot.wav",
	"Stage7AkamuShurikenHitSfx": "res://assets/sounds/stage7_akamu_shuriken_hit.wav",
	"Stage7AkamuCloudSfx": "res://assets/sounds/stage7_akamu_cloud.wav",
	"Stage7AkamuAuraBlockSfx": "res://assets/sounds/stage7_akamu_aura_block.wav",
	"Stage7AkamuCloneSpawnSfx": "res://assets/sounds/stage7_akamu_clone_spawn.wav",
	"Stage7AkamuCloneOutSfx": "res://assets/sounds/stage7_akamu_clone_out.wav",
}

var _failures: Array[String] = []


class FakePlayerFactory:
	extends RefCounted

	var specs: Dictionary = {}

	func create(parent: Node, player_name: String, path: String, volume_db: float) -> AudioStreamPlayer:
		var player := AudioStreamPlayer.new()
		player.name = player_name
		player.volume_db = volume_db
		if parent != null:
			parent.add_child(player)
		specs[player_name] = {"path": path, "volume_db": volume_db}
		return player


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_stage7_akamu_shuriken_shoot() -> void:
		calls.append("shuriken_shoot")

	func play_stage7_akamu_shuriken_hit() -> void:
		calls.append("shuriken_hit")

	func play_stage7_akamu_cloud() -> void:
		calls.append("cloud")

	func play_stage7_akamu_wind_aura_block() -> void:
		calls.append("aura_block")

	func play_stage7_akamu_clone_spawn() -> void:
		calls.append("clone_spawn")

	func play_stage7_akamu_clone_out() -> void:
		calls.append("clone_out")


class FakeCleanseState:
	extends RefCounted

	func is_immune() -> bool:
		return true


class FakeBattleOwner:
	extends Node

	var current_stage := 7


func _init() -> void:
	await _verify_exact_assets_and_game_audio_registration()
	_verify_stage7_stepped_boot_completes()
	_verify_shuriken_audio_boundaries()
	_verify_cloud_and_aura_audio_boundaries()
	_verify_clone_audio_boundaries()
	_verify_no_invented_smokebomb_or_loop_contract()

	if _failures.is_empty():
		print("stage7_akamu_audio_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_exact_assets_and_game_audio_registration() -> void:
	var expected_paths: Array[String] = [
		GameAudio.STAGE7_AKAMU_SHURIKEN_SHOOT_SOUND_PATH,
		GameAudio.STAGE7_AKAMU_SHURIKEN_HIT_SOUND_PATH,
		GameAudio.STAGE7_AKAMU_CLOUD_SOUND_PATH,
		GameAudio.STAGE7_AKAMU_AURA_BLOCK_SOUND_PATH,
		GameAudio.STAGE7_AKAMU_CLONE_SPAWN_SOUND_PATH,
		GameAudio.STAGE7_AKAMU_CLONE_OUT_SOUND_PATH,
	]
	_expect(expected_paths.size() == 6, "Akamu should register exactly six dedicated battle SFX")
	for path in expected_paths:
		_expect(FileAccess.file_exists(path), "%s should exist" % path)
		var stream: AudioStream = ProjectResourceLoader.load_audio_stream(path)
		_expect(stream is AudioStreamWAV, "%s should load as an exact WAV one-shot" % path)
		if stream is AudioStreamWAV:
			_expect(
				(stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED,
				"%s should remain non-looping" % path
			)

	var setup_host := Node.new()
	get_root().add_child(setup_host)
	var factory := FakePlayerFactory.new()
	var setup_audio: Object = GameAudio.new()
	setup_audio.owner_node = setup_host
	setup_audio.player_factory = factory
	setup_audio._setup_stage_feedback_sfx()
	setup_audio._apply_audio_buses_and_volumes()
	for player_name in EXPECTED_SFX:
		var spec: Dictionary = factory.specs.get(player_name, {})
		_expect(str(spec.get("path", "")) == str(EXPECTED_SFX[player_name]), "%s should use its exact promoted asset" % player_name)
		_expect(is_equal_approx(float(spec.get("volume_db", -99.0)), 0.0), "%s should preserve native 0 dB cue gain" % player_name)
	var stage7_players: Array = [
		setup_audio.stage7_akamu_shuriken_shoot_sfx,
		setup_audio.stage7_akamu_shuriken_hit_sfx,
		setup_audio.stage7_akamu_cloud_sfx,
		setup_audio.stage7_akamu_aura_block_sfx,
		setup_audio.stage7_akamu_clone_spawn_sfx,
		setup_audio.stage7_akamu_clone_out_sfx,
	]
	for player_value in stage7_players:
		_expect(player_value is AudioStreamPlayer, "all six Akamu SFX players should be created")
		if player_value is AudioStreamPlayer:
			_expect((player_value as AudioStreamPlayer).bus == GameAudio.SFX_BUS_NAME, "Akamu one-shots should route through the shared SFX bus")
	for facade_method in [
		"play_stage7_akamu_shuriken_shoot",
		"play_stage7_akamu_shuriken_hit",
		"play_stage7_akamu_cloud",
		"play_stage7_akamu_wind_aura_block",
		"play_stage7_akamu_clone_spawn",
		"play_stage7_akamu_clone_out",
	]:
		_expect(setup_audio.has_method(str(facade_method)), "GameAudio should expose %s" % facade_method)
		if setup_audio.has_method(str(facade_method)):
			setup_audio.call(str(facade_method))
	var prewarm_paths: Array = setup_audio._get_audio_setup_stream_paths(5)
	for path in expected_paths:
		_expect(prewarm_paths.has(path), "%s should be registered in the step-5 stream prewarm list" % path)
	setup_host.free()

	var real_host := Node.new()
	get_root().add_child(real_host)
	await process_frame
	var real_audio: Object = GameAudio.new()
	real_audio.owner_node = real_host
	real_audio._setup_stage_feedback_sfx()
	var real_players := {
		"shuriken_shoot": real_audio.stage7_akamu_shuriken_shoot_sfx,
		"shuriken_hit": real_audio.stage7_akamu_shuriken_hit_sfx,
		"cloud": real_audio.stage7_akamu_cloud_sfx,
		"aura_block": real_audio.stage7_akamu_aura_block_sfx,
		"clone_spawn": real_audio.stage7_akamu_clone_spawn_sfx,
		"clone_out": real_audio.stage7_akamu_clone_out_sfx,
	}
	for cue_name in real_players:
		var real_player: AudioStreamPlayer = real_players[cue_name]
		_expect(real_player != null and real_player.stream is AudioStreamWAV, "real %s player should carry its WAV stream" % cue_name)
		if real_player != null and real_player.stream is AudioStreamWAV:
			_expect(
				(real_player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED,
				"real %s player stream must stay a non-looping one-shot" % cue_name
			)
	var facade_to_player := {
		"play_stage7_akamu_shuriken_shoot": real_audio.stage7_akamu_shuriken_shoot_sfx,
		"play_stage7_akamu_shuriken_hit": real_audio.stage7_akamu_shuriken_hit_sfx,
		"play_stage7_akamu_cloud": real_audio.stage7_akamu_cloud_sfx,
		"play_stage7_akamu_wind_aura_block": real_audio.stage7_akamu_aura_block_sfx,
		"play_stage7_akamu_clone_spawn": real_audio.stage7_akamu_clone_spawn_sfx,
		"play_stage7_akamu_clone_out": real_audio.stage7_akamu_clone_out_sfx,
	}
	for method_name in facade_to_player:
		var mapped_player: AudioStreamPlayer = facade_to_player[method_name]
		real_audio.call(str(method_name))
		_expect(
			mapped_player != null and mapped_player.playing,
			"%s should drive exactly its own mapped real player" % method_name
		)
		for other_name in facade_to_player:
			if str(other_name) == str(method_name):
				continue
			var other_player: AudioStreamPlayer = facade_to_player[other_name]
			_expect(
				other_player == null or not other_player.playing,
				"%s must not cross-trigger %s's player" % [method_name, other_name]
			)
		if mapped_player != null:
			mapped_player.stop()
	OS.delay_msec(250)
	real_host.free()

	_expect(FileAccess.file_exists(GameAudio.STAGE7_BGM_PATH), "Akamu BGM Ogg should exist")
	var cached_bgm: AudioStream = ProjectResourceLoader.load_audio_stream(GameAudio.STAGE7_BGM_PATH)
	_expect(cached_bgm is AudioStreamOggVorbis, "Akamu BGM should load as Ogg Vorbis")
	if cached_bgm is AudioStreamOggVorbis:
		_expect(absf(cached_bgm.get_length() - 278.079979) <= 0.02, "Akamu BGM should preserve the 278.08s legacy duration")
		_expect(not (cached_bgm as AudioStreamOggVorbis).loop, "path-cached Akamu BGM must remain non-mutated")

	var bgm_host := Node.new()
	get_root().add_child(bgm_host)
	var bgm_audio: Object = GameAudio.new()
	bgm_audio.owner_node = bgm_host
	var stage7_player: AudioStreamPlayer = bgm_audio._ensure_bgm_player("stage7")
	_expect(stage7_player != null and stage7_player.stream is AudioStreamOggVorbis, "Stage 7 should lazily create its BGM player")
	if stage7_player != null and stage7_player.stream is AudioStreamOggVorbis:
		_expect(stage7_player.stream != cached_bgm, "loop enablement should duplicate the path-cached BGM stream")
		_expect((stage7_player.stream as AudioStreamOggVorbis).loop, "Stage 7 BGM player should loop")
		_expect(stage7_player.bus == GameAudio.BGM_BUS_NAME, "Stage 7 BGM should use the BGM bus")
	bgm_audio.bgm_muted = true
	_expect(bgm_audio.prime_stage_bgm(7), "Stage 7 BGM should prime")
	_expect(bgm_audio.get_current_bgm_name() == "stage7", "Stage 7 prime should select the Akamu track")
	_expect(bgm_audio.play_stage_bgm(7), "Stage 7 BGM should enter the normal play route")
	_expect(bgm_audio.get_current_bgm_name() == "stage7", "Stage 7 play should retain the same single track")
	if stage7_player != null:
		stage7_player.stream = null
	bgm_host.free()


func _verify_stage7_stepped_boot_completes() -> void:
	# 코덱스 P1 봉인: current_stage == 7 오너에서 단계식 BGM 셋업이 스텝 예산 안에
	# 완주해야 한다. STEP_COUNT만 늘리거나 stage7 스텝을 빠뜨리면 부트 프리웜이
	# _is_required_bgm_player_ready() 미충족으로 무한 대기한다.
	var owner := FakeBattleOwner.new()
	get_root().add_child(owner)
	var boot_audio: Object = GameAudio.new()
	boot_audio.owner_node = owner
	var completed := false
	for step_index in range(GameAudio.BGM_SETUP_STEP_COUNT + 2):
		if boot_audio._setup_bgm_players_step():
			completed = true
			break
	_expect(completed, "stage7 owner stepped BGM setup should complete within the step budget")
	_expect(boot_audio.stage7_bgm is AudioStreamPlayer and boot_audio.stage7_bgm.stream is AudioStreamOggVorbis, "stepped setup should create the stage7 BGM player")
	_expect(boot_audio._is_required_bgm_player_ready(), "stage7 stepped setup should satisfy the required-player readiness gate")
	if boot_audio.stage7_bgm != null:
		boot_audio.stage7_bgm.stream = null
	owner.free()

	# 외곽 통합 봉인: 사설 스텝 헬퍼가 아니라 부트가 실제로 도는 공개
	# setup_step() 루프가 stage7 오너에서 예산 안에 완주해야 한다(스트림
	# 프리웜은 스레드라 재호출 대기가 필요).
	var full_owner := FakeBattleOwner.new()
	get_root().add_child(full_owner)
	var full_audio: Object = GameAudio.new()
	var full_iterations := 0
	while not full_audio.setup_step(full_owner):
		full_iterations += 1
		if full_iterations > 5000:
			break
		OS.delay_msec(2)
	_expect(full_iterations <= 5000, "public setup_step should complete for a stage7 owner within the iteration budget")
	_expect(bool(full_audio._is_setup_complete()), "public setup_step completion should satisfy _is_setup_complete for a stage7 owner")
	_expect(full_audio.stage7_bgm is AudioStreamPlayer, "public setup_step should create the stage7 BGM player")
	if full_audio.stage7_bgm != null:
		full_audio.stage7_bgm.stream = null
	OS.delay_msec(250)
	full_owner.free()


func _verify_shuriken_audio_boundaries() -> void:
	var context: Dictionary = _base_context()
	var shoot_audio := FakeAudio.new()
	var shoot_state: Object = Stage7AkamuState.new()
	shoot_state.debug_set_awakened(true)
	shoot_state.debug_set_gauge(100.0)
	shoot_state.debug_set_shuriken_cooldown_remaining(0.0, 8.0)
	shoot_state.update(1.0 / 60.0, context, {"audio": shoot_audio})
	_advance(shoot_state, 0.29, context, {"audio": shoot_audio})
	_expect(_count_calls(shoot_audio, "shuriken_shoot") == 0, "shuriken shoot cue must wait for the 300ms cast commit")
	_advance(shoot_state, 0.02, context, {"audio": shoot_audio})
	_expect(_count_calls(shoot_audio, "shuriken_shoot") == 1, "primary shuriken should emit one shoot cue at release")
	_advance(shoot_state, 0.20, context, {"audio": shoot_audio})
	_expect(_count_calls(shoot_audio, "shuriken_shoot") == 2, "awakened +200ms bonus shot should emit its own shoot cue")

	var cleanse_audio := FakeAudio.new()
	var cleanse_state: Object = Stage7AkamuState.new()
	cleanse_state.debug_spawn_shuriken(Vector2(380.0, 675.0), Vector2(380.0, 740.0))
	var cleanse_result: Dictionary = cleanse_state.update(1.0 / 60.0, context, {
		"audio": cleanse_audio,
		"smasher_cleanse_state": FakeCleanseState.new(),
	})
	_expect(bool(cleanse_result.get("stage7_akamu_shuriken_cleansed", false)), "cleanse audio leg should reach a real shuriken contact")
	_expect(_count_calls(cleanse_audio, "shuriken_hit") == 1, "cleanse immunity should not suppress the physical shuriken hit cue")

	var smoke_audio := FakeAudio.new()
	var smoke_state: Object = Stage7AkamuState.new()
	var smoke_context: Dictionary = context.duplicate(true)
	smoke_context["player_in_smoke"] = true
	smoke_state.debug_spawn_shuriken(Vector2(380.0, 675.0), Vector2(380.0, 740.0))
	var smoke_result: Dictionary = smoke_state.update(1.0 / 60.0, smoke_context, {"audio": smoke_audio})
	_expect(bool(smoke_result.get("stage7_akamu_shuriken_smoke_absorbed", false)), "smoke audio leg should absorb the projectile")
	_expect(_count_calls(smoke_audio, "shuriken_hit") == 0, "smoke-absorbed shuriken should remain silent")


func _verify_cloud_and_aura_audio_boundaries() -> void:
	var context: Dictionary = _base_context()
	var cloud_audio := FakeAudio.new()
	var cloud_state: Object = Stage7AkamuState.new()
	cloud_state.debug_set_gauge(120.0)
	_expect(cloud_state.debug_start_cloud(context, {"audio": cloud_audio}), "cloud audio leg should start")
	_advance(cloud_state, 0.40, context, {"audio": cloud_audio})
	_expect(_count_calls(cloud_audio, "cloud") == 0, "cloud cue should not play during the 400ms precast")
	_advance(cloud_state, 0.30, context, {"audio": cloud_audio})
	_expect(_count_calls(cloud_audio, "cloud") == 0, "cloud cue should wait for the full 316ms descent")
	_advance(cloud_state, 0.02, context, {"audio": cloud_audio})
	_expect(_count_calls(cloud_audio, "cloud") == 1, "cloud landing should emit one exact ninjacloud cue")

	var aura_audio := FakeAudio.new()
	var aura_state: Object = Stage7AkamuState.new()
	aura_state.debug_force_complete_awakening()
	var aura_context: Dictionary = context.duplicate(true)
	aura_context["last_hit_by"] = "player"
	aura_context["active_item_boss_skill_cooldown_paused"] = true
	for hit_index in range(5):
		var result: Dictionary = aura_state.resolve_wind_aura_collision(
			Vector2(380.0, 100.0),
			Vector2(0.0, -12.0),
			aura_context,
			{"audio": aura_audio}
		)
		_expect(bool(result.get("stage7_akamu_wind_aura_hit", false)), "aura hit %d should commit" % (hit_index + 1))
		if hit_index < 4:
			aura_state.debug_clear_wind_aura_hit_cooldown()
	_expect(_count_calls(aura_audio, "aura_block") == 5, "all five valid blocks, including depletion under pause, should emit the aura cue")


func _verify_clone_audio_boundaries() -> void:
	var context: Dictionary = _base_context()
	var spawn_audio := FakeAudio.new()
	var spawn_state: Object = Stage7AkamuState.new()
	spawn_state.debug_set_gauge(100.0)
	_expect(spawn_state.debug_start_clone_cast(context), "clone audio leg should start")
	_advance(spawn_state, 0.49, context, {"audio": spawn_audio})
	_expect(_count_calls(spawn_audio, "clone_spawn") == 0, "clone spawn cue must wait for the 500ms commit")
	_advance(spawn_state, 0.02, context, {"audio": spawn_audio})
	_expect(_count_calls(spawn_audio, "clone_spawn") == 1, "two-clone cast should emit one spawn cue per cast")
	_advance(spawn_state, 10.01, context, {"audio": spawn_audio})
	_expect(_count_calls(spawn_audio, "clone_out") == 2, "two naturally expired clones should each emit one out cue")

	var hit_audio := FakeAudio.new()
	var hit_state: Object = Stage7AkamuState.new()
	hit_state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	var hit_scene := {
		"previous_ball_pos": Vector2(380.0, 310.0),
		"ball_pos": Vector2(380.0, 130.0),
		"ball_vel": Vector2(0.0, -12.0),
	}
	_expect(hit_state.resolve_ball_collision(hit_scene, context, {"audio": hit_audio}), "clone audio collision leg should hit")
	_expect(_count_calls(hit_audio, "clone_out") == 1, "clone collision should emit one out cue at dying entry")
	_advance(hit_state, 0.71, context, {"audio": hit_audio})
	_expect(_count_calls(hit_audio, "clone_out") == 1, "dying completion should not replay the clone out cue")

	var cleanup_audio := FakeAudio.new()
	var cleanup_state: Object = Stage7AkamuState.new()
	cleanup_state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	cleanup_state.clear_round_transients()
	_advance(cleanup_state, 0.10, context, {"audio": cleanup_audio})
	_expect(cleanup_audio.calls.is_empty(), "round cleanup should not invent a clone-out cue on later audio-deps ticks")


func _verify_no_invented_smokebomb_or_loop_contract() -> void:
	_expect(GameAudio.SMOKEBOMB_SOUND_PATH == "res://assets/sounds/smokebomb.wav", "shared smokebomb asset should remain unchanged")
	var state_source := FileAccess.get_file_as_string("res://scripts/stages/stage7/stage7_akamu_state.gd")
	_expect(state_source.find("play_smokebomb") < 0, "Akamu runtime must not substitute smokebomb for ninjacloud")
	var cleanup_source := FileAccess.get_file_as_string("res://scripts/audio/gameplay_loop_audio_cleanup.gd")
	_expect(cleanup_source.find("stage7_akamu") < 0, "all Akamu skill cues are one-shots and should not enter loop cleanup")


func _advance(state: Object, seconds: float, context: Dictionary, deps: Dictionary = {}) -> void:
	var remaining := maxf(0.0, seconds)
	while remaining > 0.000001:
		var step := minf(1.0 / 60.0, remaining)
		state.update(step, context, deps)
		remaining -= step


func _count_calls(audio: FakeAudio, cue: String) -> int:
	var count := 0
	for value in audio.calls:
		if value == cue:
			count += 1
	return count


func _base_context() -> Dictionary:
	return {
		"current_stage": 7,
		"selected_character_type": "smasher",
		"ball_active": true,
		"waiting_for_serve": false,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_speed": 5.0,
		"special_gauge": 100.0,
		"gauge_max": 500.0,
		"ball_size": 20.0,
		"last_hit_by": "player",
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
