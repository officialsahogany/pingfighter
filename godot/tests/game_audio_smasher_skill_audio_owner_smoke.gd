extends SceneTree

# expect-zero-object-leaks

const OWNER_PATH := "res://scripts/audio/smasher_skill_audio.gd"
const FACADE_PATH := "res://scripts/audio/game_audio.gd"
const GameAudio := preload(FACADE_PATH)
const GameplayLoopAudioCleanup := preload("res://scripts/audio/gameplay_loop_audio_cleanup.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const SKILL_CUE_ORDER := [
	"drive",
	"drive_voice",
	"plasma_charge",
	"plasma_shoot",
	"plasma_shock",
	"recovery",
	"cleanse",
	"warp_gate",
	"magnum_grip",
	"smasher_wheel",
	"smasher_wheel_voice",
	"smasher_overdrive_activation",
	"smasher_overdrive_voice",
	"void_phantom_voice",
	"void_phantom_charge",
	"void_phantom_launch",
	"shield_kiting_wind_up",
	"shield_kiting_launch",
	"shield_kiting_hit",
]
const STAGE_FEEDBACK_CUE_ORDER := [
	"power_smash",
	"power_smashing_voice",
	"ghost_smashing_voice",
	"power_smash_launch",
]
const EXPECTED_SPECS := {
	"drive": ["DriveSfx", "res://assets/sounds/drive_strike.wav", -8.0],
	"drive_voice": ["MikaDriveVoiceSfx", "res://assets/sounds/voice/mika_byeokryeokta_activation_v1.mp3", -2.5],
	"plasma_charge": ["PlasmaChargeSfx", "res://assets/sounds/plazmacharge.wav", 0.0],
	"plasma_shoot": ["PlasmaShootSfx", "res://assets/sounds/plazmashoot.wav", -6.0206],
	"plasma_shock": ["PlasmaShockSfx", "res://assets/sounds/plazmashock.wav", -4.4370],
	"recovery": ["RecoverySfx", "res://assets/sounds/recovery.wav", -5.0],
	"cleanse": ["CleanseSfx", "res://assets/sounds/cleanse.wav", -5.0],
	"warp_gate": ["WarpGateSfx", "res://assets/sounds/warpgate.wav", -5.0],
	"magnum_grip": ["MagnumGripSfx", "res://assets/sounds/magnumgrip.wav", -5.0],
	"smasher_wheel": ["SmasherWheelSfx", "res://assets/sounds/smasherwheel.wav", -5.0],
	"smasher_wheel_voice": ["MikaSmasherWheelVoiceSfx", "res://assets/sounds/voice/mika_pungun_cheonseonmu_cutin_v1.mp3", -4.5],
	"smasher_overdrive_activation": ["SmasherOverdriveActivationSfx", "res://assets/sounds/thunderboltboom.wav", -4.0],
	"smasher_overdrive_voice": ["MikaSmasherOverdriveVoiceSfx", "res://assets/sounds/voice/mika_byeokryeok_yuseong_activation_v1.mp3", -2.5],
	"void_phantom_voice": ["MikaVoidPhantomVoiceSfx", "res://assets/sounds/voice/mika_void_phantom_activation_v1.mp3", -2.5],
	"void_phantom_charge": ["VoidPhantomChargeSfx", "res://assets/sounds/void_phantom_charge.wav", -5.0],
	"void_phantom_launch": ["VoidPhantomLaunchSfx", "res://assets/sounds/void_phantom_launch.wav", -5.0],
	"shield_kiting_wind_up": ["ShieldKitingWindUpSfx", "res://assets/sounds/shieldcating1.wav", -5.0],
	"shield_kiting_launch": ["ShieldKitingLaunchSfx", "res://assets/sounds/shieldcating2.wav", -5.0],
	"shield_kiting_hit": ["ShieldKitingHitSfx", "res://assets/sounds/shieldcating3.wav", -4.0],
	"power_smash": ["PowerSmashSfx", "res://assets/sounds/skill_cutin1.wav", -4.0],
	"power_smashing_voice": ["MikaPowerSmashingVoiceSfx", "res://assets/sounds/voice/mika_power_smashing_cutin_v1.mp3", -6.0],
	"ghost_smashing_voice": ["MikaGhostSmashingVoiceSfx", "res://assets/sounds/voice/mika_ghost_smashing_cutin_v1.mp3", -4.5],
	"power_smash_launch": ["PowerSmashLaunchSfx", "res://assets/sounds/power_smash_launch.wav", -4.0],
}
const POWER_VOICE_PATHS := [
	"res://assets/sounds/voice/mika_power_smashing_cutin_v1.mp3",
	"res://assets/sounds/voice/mika_power_smashing_cutin_v2.mp3",
	"res://assets/sounds/voice/mika_power_smashing_cutin_v3.mp3",
	"res://assets/sounds/voice/mika_power_smashing_cutin_v4.mp3",
]
const GHOST_VOICE_PATHS := [
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v1.mp3",
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v2.wav",
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v3.mp3",
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v4.wav",
]
const PUNGUN_VOICE_PATHS := [
	"res://assets/sounds/voice/mika_pungun_cheonseonmu_cutin_v1.mp3",
	"res://assets/sounds/voice/mika_pungun_cheonseonmu_cutin_v2.mp3",
]
const BYEOKRYEOKTA_VOICE_PATHS := [
	"res://assets/sounds/voice/mika_byeokryeokta_activation_v1.mp3",
	"res://assets/sounds/voice/mika_byeokryeokta_activation_v2.mp3",
]
const SMASHER_OVERDRIVE_VOICE_PATHS := [
	"res://assets/sounds/voice/mika_byeokryeok_yuseong_activation_v1.mp3",
	"res://assets/sounds/voice/mika_byeokryeok_yuseong_activation_v2.mp3",
]
const VOID_PHANTOM_VOICE_PATHS := [
	"res://assets/sounds/voice/mika_void_phantom_activation_v1.mp3",
	"res://assets/sounds/voice/mika_void_phantom_activation_v2.mp3",
]
const LOOP_CUE_IDS := [
	"plasma_charge",
	"plasma_shock",
	"warp_gate",
	"magnum_grip",
	"smasher_wheel",
]

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


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_owner_boundary()
	if FileAccess.file_exists(OWNER_PATH):
		await _verify_catalog_setup_and_assets()
		await _verify_production_facade_and_projections()
		await _verify_real_loop_stream_contracts()

	if _failures.is_empty():
		print("game_audio_smasher_skill_audio_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(OWNER_PATH), "Smasher cues should have a focused skill-audio owner")
	if not FileAccess.file_exists(OWNER_PATH):
		return
	var facade_source := FileAccess.get_file_as_string(FACADE_PATH)
	var owner_source := FileAccess.get_file_as_string(OWNER_PATH)
	_expect(facade_source.contains("SmasherSkillAudio"), "GameAudio should preload the Smasher skill-audio owner")
	_expect(facade_source.contains("smasher_skill_audio.setup_skill_players(owner_node, player_factory)"), "Smasher skill setup should delegate")
	_expect(facade_source.contains("smasher_skill_audio.setup_stage_feedback_players(owner_node, player_factory)"), "Smasher stage-feedback setup should delegate")
	_expect(facade_source.contains("smasher_skill_audio.get_skill_prewarm_stream_paths()"), "Smasher skill prewarm should delegate")
	_expect(facade_source.contains("smasher_skill_audio.get_stage_primary_prewarm_stream_paths()"), "Power Smash prewarm should delegate")
	_expect(facade_source.contains("smasher_skill_audio.get_voice_prewarm_stream_paths()"), "Smasher voice prewarm should delegate")
	_expect(facade_source.contains("smasher_skill_audio.get_skill_players()"), "Smasher skill SFX-bus projection should delegate")
	_expect(facade_source.contains("smasher_skill_audio.get_stage_feedback_players()"), "Smasher stage-feedback SFX-bus projection should delegate")
	_expect(facade_source.contains("func play_full_skill_cutin() -> void:"), "GameAudio should expose the semantic full-skill cut-in SFX facade")
	_expect(
		facade_source.contains("_play_random_stream_with_pitch(mika_drive_voice_sfx, mika_drive_voice_streams, 1.0)"),
		"벽력타 발동은 한미량 보이스 후보 중 하나를 무작위 재생해야 한다"
	)
	_expect(facade_source.contains("mika_void_phantom_voice_streams"), "허공환영 발동 보이스 후보는 GameAudio에 투영돼야 한다")
	_expect(facade_source.contains("mika_smasher_overdrive_voice_streams"), "벽력유성 발동 보이스 후보는 GameAudio에 투영돼야 한다")
	for cue_id in LOOP_CUE_IDS:
		_expect(facade_source.contains("_enable_loop(%s_sfx)" % cue_id), "%s loop mutation should remain in GameAudio" % cue_id)
	_expect(not facade_source.contains("const DRIVE_SOUND_PATH"), "GameAudio should not retain the Smasher cue catalog")
	_expect(not facade_source.contains('player_factory.create(owner_node, "DriveSfx"'), "GameAudio should not create Smasher players directly")
	_expect(owner_source.contains("const CUE_SPECS"), "focused owner should own the complete Smasher cue catalog")
	_expect(not owner_source.contains("loop_mode"), "focused owner should not mutate shared stream loop flags")


func _verify_catalog_setup_and_assets() -> void:
	var owner: Object = _new_owner()
	_expect(owner.get_skill_cue_ids() == SKILL_CUE_ORDER, "Smasher skill cue order should remain stable")
	_expect(owner.get_stage_feedback_cue_ids() == STAGE_FEEDBACK_CUE_ORDER, "Smasher stage-feedback cue order should remain stable")
	_expect(owner.get_skill_prewarm_stream_paths() == _paths_for_ids(SKILL_CUE_ORDER), "Smasher skill prewarm order should remain stable")
	_expect(owner.get_stage_primary_prewarm_stream_paths() == _paths_for_ids(["power_smash", "power_smash_launch"]), "Power Smash primary prewarm order should remain stable")
	_expect(owner.get_voice_prewarm_stream_paths() == POWER_VOICE_PATHS + GHOST_VOICE_PATHS + PUNGUN_VOICE_PATHS + BYEOKRYEOKTA_VOICE_PATHS + SMASHER_OVERDRIVE_VOICE_PATHS + VOID_PHANTOM_VOICE_PATHS, "Smasher voice prewarm order should remain stable")
	for cue_id in SKILL_CUE_ORDER + STAGE_FEEDBACK_CUE_ORDER:
		var expected: Array = EXPECTED_SPECS[cue_id]
		var spec: Dictionary = owner.get_spec(cue_id)
		_expect(str(spec.get("player_name", "")) == expected[0], "%s should retain its player name" % cue_id)
		_expect(str(spec.get("path", "")) == expected[1], "%s should retain its stream path" % cue_id)
		_expect(is_equal_approx(float(spec.get("gain_db", -99.0)), float(expected[2])), "%s should retain authored gain" % cue_id)
		_expect(ProjectResourceLoader.load_audio_stream(str(expected[1])) != null, "%s should load its authored stream" % cue_id)
	_expect(owner.get_spec("missing").is_empty(), "unknown Smasher cues should fail closed")

	var host := Node.new()
	get_root().add_child(host)
	var factory := RecordingFactory.new()
	owner.setup_skill_players(host, factory)
	_expect(_call_names(factory.calls) == _names_for_ids(SKILL_CUE_ORDER), "Smasher skill-player setup order should remain stable")
	_expect(owner.get_skill_players() == _players_for_ids(owner, SKILL_CUE_ORDER), "Smasher skill-player projection should preserve order")
	factory.calls.clear()
	owner.setup_stage_feedback_players(host, factory)
	_expect(_call_names(factory.calls) == _names_for_ids(STAGE_FEEDBACK_CUE_ORDER), "Smasher stage-feedback setup order should remain stable")
	_expect(owner.get_stage_feedback_players() == _players_for_ids(owner, STAGE_FEEDBACK_CUE_ORDER), "Smasher stage-feedback projection should preserve order")
	_expect(owner.get_power_smashing_voice_streams().size() == POWER_VOICE_PATHS.size(), "Power Smashing should retain four voice candidates")
	_expect(owner.get_ghost_smashing_voice_streams().size() == GHOST_VOICE_PATHS.size(), "Ghost Smashing should retain four voice candidates")
	_expect(owner.get_byeokryeokta_voice_streams().size() == BYEOKRYEOKTA_VOICE_PATHS.size(), "벽력타는 한미량 보이스 후보 2개를 로드해야 한다")
	_expect(owner.get_smasher_overdrive_voice_streams().size() == SMASHER_OVERDRIVE_VOICE_PATHS.size(), "벽력유성은 한미량 보이스 후보 2개를 로드해야 한다")
	_expect(owner.get_void_phantom_voice_streams().size() == VOID_PHANTOM_VOICE_PATHS.size(), "허공환영은 한미량 보이스 후보 2개를 로드해야 한다")

	owner = null
	factory = null
	host.free()
	await process_frame
	await process_frame


func _verify_production_facade_and_projections() -> void:
	var host := Node.new()
	get_root().add_child(host)
	var factory := RecordingFactory.new()
	var audio := GameAudio.new()
	audio.owner_node = host
	audio.player_factory = factory
	var prior_skill := _make_player(host, "PriorDashSpirit")
	audio.dash_spirit_delete_sfx = prior_skill
	audio._setup_smasher_skill_sfx()
	var focused_owner: Object = audio.get("smasher_skill_audio")
	_expect(_call_names(factory.calls).slice(0, SKILL_CUE_ORDER.size()) == _names_for_ids(SKILL_CUE_ORDER), "production skill setup should begin with the focused Smasher order")
	_expect(str(factory.calls[SKILL_CUE_ORDER.size()].get("name", "")) == "WhipSfx", "Stage 1 shared cues should remain after focused Smasher setup")

	var sfx_players: Array = audio._get_sfx_players()
	var skill_players: Array[AudioStreamPlayer] = focused_owner.get_skill_players()
	_expect(sfx_players.find(skill_players[0]) == sfx_players.find(prior_skill) + 1, "global SFX list should keep Smasher after core dash cues")
	_expect(sfx_players.find(audio.whip_sfx) == sfx_players.find(skill_players[skill_players.size() - 1]) + 1, "global SFX list should keep Stage 1 shared cues after Smasher")

	var replacement := _make_player(host, "ReplacementRecovery")
	audio.set("recovery_sfx", replacement)
	_expect(audio.get("recovery_sfx") == replacement, "legacy Smasher player properties should remain writable")
	_expect(audio._get_audio_setup_stream_paths(1).slice(0, SKILL_CUE_ORDER.size()) == focused_owner.get_skill_prewarm_stream_paths(), "global skill prewarm should begin with the focused Smasher projection")

	factory.calls.clear()
	var prior_stage := _make_player(host, "PriorBombSurprise")
	audio.bomb_surprise_self_explosion_sfx = prior_stage
	audio._setup_stage_feedback_sfx()
	_expect(_call_names(factory.calls).slice(0, STAGE_FEEDBACK_CUE_ORDER.size()) == _names_for_ids(STAGE_FEEDBACK_CUE_ORDER), "production stage setup should begin with focused Smasher feedback")
	_expect(str(factory.calls[STAGE_FEEDBACK_CUE_ORDER.size()].get("name", "")) == "RoundSetSfx", "shared stage feedback should remain after Smasher feedback")
	sfx_players = audio._get_sfx_players()
	var stage_players: Array[AudioStreamPlayer] = focused_owner.get_stage_feedback_players()
	_expect(sfx_players.find(stage_players[0]) == sfx_players.find(prior_stage) + 1, "global SFX list should keep Smasher stage feedback after item feedback")
	_expect(sfx_players.find(audio.round_set_sfx) == sfx_players.find(stage_players[stage_players.size() - 1]) + 1, "global SFX list should keep shared stage feedback after Smasher")
	_expect(sfx_players.find(audio.stage_clear_gong_sfx) == sfx_players.find(audio.round_set_sfx) + 1, "stage-clear gong should follow the ordinary round-set cue")

	var stage_paths: Array[String] = audio._get_audio_setup_stream_paths(5)
	_expect(stage_paths.slice(0, 2) == focused_owner.get_stage_primary_prewarm_stream_paths(), "global stage prewarm should begin with Power Smash primary paths")
	var voice_paths: Array[String] = focused_owner.get_voice_prewarm_stream_paths()
	var voice_start := stage_paths.find(voice_paths[0])
	_expect(voice_start >= 0 and stage_paths.slice(voice_start, voice_start + voice_paths.size()) == voice_paths, "global stage prewarm should retain consecutive Smasher voice paths")

	for cue_id in LOOP_CUE_IDS:
		var player: AudioStreamPlayer = focused_owner.get_player(cue_id)
		player.play()
	GameplayLoopAudioCleanup.stop_all(audio)
	for cue_id in LOOP_CUE_IDS:
		_expect(not focused_owner.get_player(cue_id).playing, "%s should stop through central round cleanup" % cue_id)

	audio.set("mika_power_smashing_voice_streams", [])
	audio.set("mika_ghost_smashing_voice_streams", [])
	audio.set("mika_drive_voice_streams", [])
	audio.set("mika_smasher_overdrive_voice_streams", [])
	audio.set("mika_void_phantom_voice_streams", [])
	audio = null
	focused_owner = null
	factory = null
	host.free()
	await process_frame
	await process_frame
	await process_frame


func _verify_real_loop_stream_contracts() -> void:
	var host := Node.new()
	get_root().add_child(host)
	var audio := GameAudio.new()
	audio.owner_node = host
	audio._setup_smasher_skill_sfx()
	var focused_owner: Object = audio.get("smasher_skill_audio")
	for cue_id in LOOP_CUE_IDS:
		var player: AudioStreamPlayer = focused_owner.get_player(cue_id)
		var cached: AudioStream = ProjectResourceLoader.load_audio_stream(str(EXPECTED_SPECS[cue_id][1]))
		_expect(player.stream is AudioStreamWAV, "%s loop player should carry its WAV stream" % cue_id)
		if player.stream is AudioStreamWAV:
			_expect(player.stream != cached, "%s should duplicate the path-cached stream" % cue_id)
			_expect((player.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED, "%s duplicate should be loop-enabled" % cue_id)
		if cached is AudioStreamWAV:
			_expect((cached as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s path-cached stream should stay non-looping" % cue_id)
		player.stream = null
	audio = null
	focused_owner = null
	host.free()
	await process_frame
	await process_frame
	await process_frame


func _paths_for_ids(cue_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for cue_id in cue_ids:
		result.append(str(EXPECTED_SPECS[str(cue_id)][1]))
	return result


func _names_for_ids(cue_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for cue_id in cue_ids:
		result.append(str(EXPECTED_SPECS[str(cue_id)][0]))
	return result


func _call_names(calls: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for call in calls:
		result.append(str(call.get("name", "")))
	return result


func _players_for_ids(owner: Object, cue_ids: Array) -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for cue_id in cue_ids:
		result.append(owner.get_player(str(cue_id)))
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
