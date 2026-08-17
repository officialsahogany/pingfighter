extends RefCounted

## Owns Smasher cue metadata, phase-stable player creation, prewarm/SFX-bus
## projections, player cache, and Smasher voice candidate pools.
## Playback, pitch/RNG policy, loop mutation, and cleanup remain with GameAudio.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const SKILL_CUE_IDS := [
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
const STAGE_FEEDBACK_CUE_IDS := [
	"power_smash",
	"power_smashing_voice",
	"ghost_smashing_voice",
	"power_smash_launch",
]
const STAGE_PRIMARY_PREWARM_IDS := [
	"power_smash",
	"power_smash_launch",
]
const POWER_SMASHING_VOICE_STREAM_PATHS := [
	"res://assets/sounds/voice/mika_power_smashing_cutin_v1.mp3",
	"res://assets/sounds/voice/mika_power_smashing_cutin_v2.mp3",
	"res://assets/sounds/voice/mika_power_smashing_cutin_v3.mp3",
	"res://assets/sounds/voice/mika_power_smashing_cutin_v4.mp3",
]
const GHOST_SMASHING_VOICE_STREAM_PATHS := [
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v1.mp3",
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v2.wav",
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v3.mp3",
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v4.wav",
]
# 풍운천선무(smasher_wheel) 컷인 한미량 보이스. 발동마다 1개를 무작위로 고른다.
const PUNGUN_CHEONSEONMU_VOICE_STREAM_PATHS := [
	"res://assets/sounds/voice/mika_pungun_cheonseonmu_cutin_v1.mp3",
	"res://assets/sounds/voice/mika_pungun_cheonseonmu_cutin_v2.mp3",
]
# 벽력타 발동마다 두 한미량 테이크 중 하나를 고른다. drive 호환 ID는 유지한다.
const BYEOKRYEOKTA_VOICE_STREAM_PATHS := [
	"res://assets/sounds/voice/mika_byeokryeokta_activation_v1.mp3",
	"res://assets/sounds/voice/mika_byeokryeokta_activation_v2.mp3",
]
const SMASHER_OVERDRIVE_VOICE_STREAM_PATHS := [
	"res://assets/sounds/voice/mika_byeokryeok_yuseong_activation_v1.mp3",
	"res://assets/sounds/voice/mika_byeokryeok_yuseong_activation_v2.mp3",
]
const VOID_PHANTOM_VOICE_STREAM_PATHS := [
	"res://assets/sounds/voice/mika_void_phantom_activation_v1.mp3",
	"res://assets/sounds/voice/mika_void_phantom_activation_v2.mp3",
]
const CUE_SPECS := {
	"drive": {
		"player_name": "DriveSfx",
		"path": "res://assets/sounds/drive_strike.wav",
		"gain_db": -8.0,
	},
	"drive_voice": {
		"player_name": "MikaDriveVoiceSfx",
		"path": "res://assets/sounds/voice/mika_byeokryeokta_activation_v1.mp3",
		"gain_db": -2.5,
	},
	"plasma_charge": {
		"player_name": "PlasmaChargeSfx",
		"path": "res://assets/sounds/plazmacharge.wav",
		"gain_db": 0.0,
	},
	"plasma_shoot": {
		"player_name": "PlasmaShootSfx",
		"path": "res://assets/sounds/plazmashoot.wav",
		"gain_db": -6.0206,
	},
	"plasma_shock": {
		"player_name": "PlasmaShockSfx",
		"path": "res://assets/sounds/plazmashock.wav",
		"gain_db": -4.4370,
	},
	"recovery": {
		"player_name": "RecoverySfx",
		"path": "res://assets/sounds/recovery.wav",
		"gain_db": -5.0,
	},
	"cleanse": {
		"player_name": "CleanseSfx",
		"path": "res://assets/sounds/cleanse.wav",
		"gain_db": -5.0,
	},
	"warp_gate": {
		"player_name": "WarpGateSfx",
		"path": "res://assets/sounds/warpgate.wav",
		"gain_db": -5.0,
	},
	"magnum_grip": {
		"player_name": "MagnumGripSfx",
		"path": "res://assets/sounds/magnumgrip.wav",
		"gain_db": -5.0,
	},
	"smasher_wheel": {
		"player_name": "SmasherWheelSfx",
		"path": "res://assets/sounds/smasherwheel.wav",
		"gain_db": -5.0,
	},
	"smasher_wheel_voice": {
		"player_name": "MikaSmasherWheelVoiceSfx",
		"path": "res://assets/sounds/voice/mika_pungun_cheonseonmu_cutin_v1.mp3",
		"gain_db": -4.5,
	},
	"smasher_overdrive_activation": {
		"player_name": "SmasherOverdriveActivationSfx",
		"path": "res://assets/sounds/thunderboltboom.wav",
		"gain_db": -4.0,
	},
	"smasher_overdrive_voice": {
		"player_name": "MikaSmasherOverdriveVoiceSfx",
		"path": "res://assets/sounds/voice/mika_byeokryeok_yuseong_activation_v1.mp3",
		"gain_db": -2.5,
	},
	"void_phantom_voice": {
		"player_name": "MikaVoidPhantomVoiceSfx",
		"path": "res://assets/sounds/voice/mika_void_phantom_activation_v1.mp3",
		"gain_db": -2.5,
	},
	"void_phantom_charge": {
		"player_name": "VoidPhantomChargeSfx",
		"path": "res://assets/sounds/void_phantom_charge.wav",
		"gain_db": -5.0,
	},
	"void_phantom_launch": {
		"player_name": "VoidPhantomLaunchSfx",
		"path": "res://assets/sounds/void_phantom_launch.wav",
		"gain_db": -5.0,
	},
	"shield_kiting_wind_up": {
		"player_name": "ShieldKitingWindUpSfx",
		"path": "res://assets/sounds/shieldcating1.wav",
		"gain_db": -5.0,
	},
	"shield_kiting_launch": {
		"player_name": "ShieldKitingLaunchSfx",
		"path": "res://assets/sounds/shieldcating2.wav",
		"gain_db": -5.0,
	},
	"shield_kiting_hit": {
		"player_name": "ShieldKitingHitSfx",
		"path": "res://assets/sounds/shieldcating3.wav",
		"gain_db": -4.0,
	},
	"power_smash": {
		"player_name": "PowerSmashSfx",
		"path": "res://assets/sounds/skill_cutin1.wav",
		"gain_db": -4.0,
	},
	"power_smashing_voice": {
		"player_name": "MikaPowerSmashingVoiceSfx",
		"path": "res://assets/sounds/voice/mika_power_smashing_cutin_v1.mp3",
		"gain_db": -6.0,
	},
	"ghost_smashing_voice": {
		"player_name": "MikaGhostSmashingVoiceSfx",
		"path": "res://assets/sounds/voice/mika_ghost_smashing_cutin_v1.mp3",
		"gain_db": -4.5,
	},
	"power_smash_launch": {
		"player_name": "PowerSmashLaunchSfx",
		"path": "res://assets/sounds/power_smash_launch.wav",
		"gain_db": -4.0,
	},
}

var _players: Dictionary = {}
var _power_smashing_voice_streams: Array[AudioStream] = []
var _ghost_smashing_voice_streams: Array[AudioStream] = []
var _pungun_cheonseonmu_voice_streams: Array[AudioStream] = []
var _byeokryeokta_voice_streams: Array[AudioStream] = []
var _smasher_overdrive_voice_streams: Array[AudioStream] = []
var _void_phantom_voice_streams: Array[AudioStream] = []


func setup_skill_players(parent: Node, player_factory: Object) -> void:
	_create_players(SKILL_CUE_IDS, parent, player_factory)
	_byeokryeokta_voice_streams = _load_audio_stream_candidates(
		BYEOKRYEOKTA_VOICE_STREAM_PATHS
	)
	_smasher_overdrive_voice_streams = _load_audio_stream_candidates(
		SMASHER_OVERDRIVE_VOICE_STREAM_PATHS
	)
	_void_phantom_voice_streams = _load_audio_stream_candidates(
		VOID_PHANTOM_VOICE_STREAM_PATHS
	)
	# 풍운천선무 보이스는 스킬 큐라 여기서 후보를 실어둔다(스테이지 피드백 쪽의
	# 천뢰격 / 고스트와 달리 setup_stage_feedback_players 를 안 거친다).
	_pungun_cheonseonmu_voice_streams = _load_audio_stream_candidates(
		PUNGUN_CHEONSEONMU_VOICE_STREAM_PATHS
	)


func setup_stage_feedback_players(parent: Node, player_factory: Object) -> void:
	_create_players(STAGE_FEEDBACK_CUE_IDS, parent, player_factory)
	_power_smashing_voice_streams = _load_audio_stream_candidates(POWER_SMASHING_VOICE_STREAM_PATHS)
	_ghost_smashing_voice_streams = _load_audio_stream_candidates(GHOST_SMASHING_VOICE_STREAM_PATHS)


func get_skill_cue_ids() -> Array[String]:
	return _copy_ids(SKILL_CUE_IDS)


func get_stage_feedback_cue_ids() -> Array[String]:
	return _copy_ids(STAGE_FEEDBACK_CUE_IDS)


func get_spec(cue_id: String) -> Dictionary:
	var value: Variant = CUE_SPECS.get(cue_id, null)
	return value as Dictionary if value is Dictionary else {}


func get_player(cue_id: String) -> AudioStreamPlayer:
	var value: Variant = _players.get(cue_id, null)
	return value as AudioStreamPlayer if value is AudioStreamPlayer else null


func set_player(cue_id: String, player: AudioStreamPlayer) -> void:
	if CUE_SPECS.has(cue_id):
		_players[cue_id] = player


func get_skill_players() -> Array[AudioStreamPlayer]:
	return _players_for_ids(SKILL_CUE_IDS)


func get_stage_feedback_players() -> Array[AudioStreamPlayer]:
	return _players_for_ids(STAGE_FEEDBACK_CUE_IDS)


func get_skill_prewarm_stream_paths() -> Array[String]:
	return _paths_for_ids(SKILL_CUE_IDS)


func get_stage_primary_prewarm_stream_paths() -> Array[String]:
	return _paths_for_ids(STAGE_PRIMARY_PREWARM_IDS)


func get_voice_prewarm_stream_paths() -> Array[String]:
	var result := _copy_paths(POWER_SMASHING_VOICE_STREAM_PATHS)
	result.append_array(_copy_paths(GHOST_SMASHING_VOICE_STREAM_PATHS))
	# 무작위 보이스 풀의 2번 후보는 어떤 큐의 primary path 도 아니라서 여기 없으면 영영 안 데워지고,
	# 무작위로 뽑힌 첫 재생에서 콜드 로드 히치가 난다.
	result.append_array(_copy_paths(PUNGUN_CHEONSEONMU_VOICE_STREAM_PATHS))
	result.append_array(_copy_paths(BYEOKRYEOKTA_VOICE_STREAM_PATHS))
	result.append_array(_copy_paths(SMASHER_OVERDRIVE_VOICE_STREAM_PATHS))
	result.append_array(_copy_paths(VOID_PHANTOM_VOICE_STREAM_PATHS))
	return result


func get_power_smashing_voice_streams() -> Array[AudioStream]:
	return _power_smashing_voice_streams


func set_power_smashing_voice_streams(streams: Array[AudioStream]) -> void:
	_power_smashing_voice_streams = streams


func get_ghost_smashing_voice_streams() -> Array[AudioStream]:
	return _ghost_smashing_voice_streams


func set_ghost_smashing_voice_streams(streams: Array[AudioStream]) -> void:
	_ghost_smashing_voice_streams = streams


func get_pungun_cheonseonmu_voice_streams() -> Array[AudioStream]:
	return _pungun_cheonseonmu_voice_streams


func set_pungun_cheonseonmu_voice_streams(streams: Array[AudioStream]) -> void:
	_pungun_cheonseonmu_voice_streams = streams


func get_byeokryeokta_voice_streams() -> Array[AudioStream]:
	return _byeokryeokta_voice_streams


func set_byeokryeokta_voice_streams(streams: Array[AudioStream]) -> void:
	_byeokryeokta_voice_streams = streams


func get_smasher_overdrive_voice_streams() -> Array[AudioStream]:
	return _smasher_overdrive_voice_streams


func set_smasher_overdrive_voice_streams(streams: Array[AudioStream]) -> void:
	_smasher_overdrive_voice_streams = streams


func get_void_phantom_voice_streams() -> Array[AudioStream]:
	return _void_phantom_voice_streams


func set_void_phantom_voice_streams(streams: Array[AudioStream]) -> void:
	_void_phantom_voice_streams = streams


func _create_players(cue_ids: Array, parent: Node, player_factory: Object) -> void:
	for cue_id: String in cue_ids:
		var spec: Dictionary = CUE_SPECS[cue_id]
		_players[cue_id] = player_factory.create(
			parent,
			str(spec.get("player_name", "")),
			str(spec.get("path", "")),
			float(spec.get("gain_db", 0.0))
		)


func _players_for_ids(cue_ids: Array) -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for cue_id: String in cue_ids:
		var player: AudioStreamPlayer = get_player(cue_id)
		if player != null:
			result.append(player)
	return result


func _paths_for_ids(cue_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in cue_ids:
		result.append(str(CUE_SPECS[cue_id].get("path", "")))
	return result


func _load_audio_stream_candidates(paths: Array) -> Array[AudioStream]:
	var result: Array[AudioStream] = []
	for path_value in paths:
		var path := str(path_value)
		var stream: AudioStream = ProjectResourceLoader.load_audio_stream(
			path,
			"Missing sound at %s",
			"Failed to load sound at %s"
		)
		if stream != null:
			result.append(stream)
	return result


func _copy_ids(source: Array) -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in source:
		result.append(cue_id)
	return result


func _copy_paths(source: Array) -> Array[String]:
	var result: Array[String] = []
	for path: String in source:
		result.append(path)
	return result
