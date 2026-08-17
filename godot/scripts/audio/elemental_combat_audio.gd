extends RefCounted

## Owns the Ragnarok, electric-shock, Lumion lightning, and Poseidon cue
## metadata, eager setup order, mini-spark candidate cache, prewarm projection,
## loop membership, and SFX-bus projection. Public playback, fallbacks, RNG
## timing, guarded shared-stream loop mutation, and round cleanup stay in
## GameAudio and the gameplay runtime owners.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const RAGNAROK_SHOT_SOUND_PATH := "res://assets/sounds/ragnarokshot.wav"
const RAGNAROK_BOOM_SOUND_PATH := "res://assets/sounds/ragnarokboom.wav"
const RAGNAROK_SHOCK_SOUND_PATH := "res://assets/sounds/ragnarokshock.wav"
const ELECTRIC_SHOCK_SOUND_PATH := "res://assets/sounds/electricshock.wav"
const ELECTRIC_SHOCK_GAIN_DB := -6.9357
const THUNDER_ORB_SHOT_SOUND_PATH := "res://assets/sounds/thunderbolt.wav"
const THUNDER_ORB_BOOM_SOUND_PATH := "res://assets/sounds/thunderboltboom.wav"
const THUNDER_ORB_SHOT_GAIN_DB := -7.9588
const THUNDER_ORB_BOOM_GAIN_DB := -6.0206
const SOLAR_BOLT_STRIKE_SOUND_PATH := "res://assets/sounds/devinethunder.wav"
const SOLAR_BOLT_STRIKE_GAIN_DB := -6.0206
const MINI_SPARK_SOUND_PATHS := [
	"res://assets/sounds/spark1.wav",
	"res://assets/sounds/spark2.wav",
	"res://assets/sounds/spark3.wav",
]
const MINI_SPARK_GAIN_DB := -11.0
const POSEIDON_WAVE_SOUND_PATH := "res://assets/sounds/poseidon.wav"
const POSEIDON_CHARGE_SOUND_PATH := "res://assets/sounds/poseidoncharge.wav"

const SETUP_CUE_IDS := [
	"ragnarok_shot",
	"ragnarok_boom",
	"ragnarok_shock",
	"electric_shock",
	"thunder_orb_shot",
	"thunder_orb_boom",
	"solar_bolt_strike",
	"mini_spark",
	"poseidon_wave",
	"poseidon_charge",
]
const PREWARM_CUE_IDS := [
	"ragnarok_shot",
	"ragnarok_boom",
	"ragnarok_shock",
	"electric_shock",
	"thunder_orb_shot",
	"thunder_orb_boom",
	"solar_bolt_strike",
	"poseidon_wave",
	"poseidon_charge",
]
const LOOP_CUE_IDS := ["ragnarok_shock", "electric_shock"]
const CUE_SPECS := {
	"ragnarok_shot": {"player_name": "RagnarokShotSfx", "path": RAGNAROK_SHOT_SOUND_PATH, "gain_db": -4.0},
	"ragnarok_boom": {"player_name": "RagnarokBoomSfx", "path": RAGNAROK_BOOM_SOUND_PATH, "gain_db": -3.5},
	"ragnarok_shock": {"player_name": "RagnarokShockSfx", "path": RAGNAROK_SHOCK_SOUND_PATH, "gain_db": -5.5},
	"electric_shock": {"player_name": "ElectricShockSfx", "path": ELECTRIC_SHOCK_SOUND_PATH, "gain_db": ELECTRIC_SHOCK_GAIN_DB},
	"thunder_orb_shot": {"player_name": "ThunderOrbShotSfx", "path": THUNDER_ORB_SHOT_SOUND_PATH, "gain_db": THUNDER_ORB_SHOT_GAIN_DB},
	"thunder_orb_boom": {"player_name": "ThunderOrbBoomSfx", "path": THUNDER_ORB_BOOM_SOUND_PATH, "gain_db": THUNDER_ORB_BOOM_GAIN_DB},
	"solar_bolt_strike": {"player_name": "SolarBoltStrikeSfx", "path": SOLAR_BOLT_STRIKE_SOUND_PATH, "gain_db": SOLAR_BOLT_STRIKE_GAIN_DB},
	"mini_spark": {"player_name": "MiniSparkSfx", "path": MINI_SPARK_SOUND_PATHS[0], "gain_db": MINI_SPARK_GAIN_DB},
	"poseidon_wave": {"player_name": "PoseidonWaveSfx", "path": POSEIDON_WAVE_SOUND_PATH, "gain_db": -5.0},
	"poseidon_charge": {"player_name": "PoseidonChargeSfx", "path": POSEIDON_CHARGE_SOUND_PATH, "gain_db": -5.0},
}

var _players: Dictionary = {}
var _mini_spark_streams: Array[AudioStream] = []


func setup(parent: Node, player_factory: Object) -> void:
	for cue_id: String in SETUP_CUE_IDS:
		var spec: Dictionary = CUE_SPECS[cue_id]
		_players[cue_id] = player_factory.create(
			parent,
			str(spec.get("player_name", "")),
			str(spec.get("path", "")),
			float(spec.get("gain_db", 0.0))
		)
		if cue_id == "mini_spark":
			_mini_spark_streams = _load_audio_stream_candidates(MINI_SPARK_SOUND_PATHS)


func get_setup_cue_ids() -> Array[String]:
	return _copy_ids(SETUP_CUE_IDS)


func get_prewarm_cue_ids() -> Array[String]:
	return _copy_ids(PREWARM_CUE_IDS)


func get_loop_cue_ids() -> Array[String]:
	return _copy_ids(LOOP_CUE_IDS)


func get_spec(cue_id: String) -> Dictionary:
	var value: Variant = CUE_SPECS.get(cue_id, null)
	return value as Dictionary if value is Dictionary else {}


func get_player(cue_id: String) -> AudioStreamPlayer:
	var value: Variant = _players.get(cue_id, null)
	return value as AudioStreamPlayer if value is AudioStreamPlayer else null


func set_player(cue_id: String, player: AudioStreamPlayer) -> void:
	if CUE_SPECS.has(cue_id):
		_players[cue_id] = player


func get_candidate_stream_paths(cue_id: String) -> Array[String]:
	if cue_id != "mini_spark":
		return []
	return _copy_ids(MINI_SPARK_SOUND_PATHS)


func get_candidate_streams(cue_id: String) -> Array[AudioStream]:
	if cue_id == "mini_spark":
		return _mini_spark_streams
	return []


func set_candidate_streams(cue_id: String, streams: Array[AudioStream]) -> void:
	if cue_id == "mini_spark":
		_mini_spark_streams = streams


func get_sfx_bus_players() -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for cue_id: String in SETUP_CUE_IDS:
		var player := get_player(cue_id)
		if player != null:
			result.append(player)
	return result


func get_prewarm_stream_paths() -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in PREWARM_CUE_IDS:
		result.append(str(CUE_SPECS[cue_id].get("path", "")))
	return result


func _load_audio_stream_candidates(paths: Array) -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	for path_value: Variant in paths:
		var path := str(path_value)
		var stream: AudioStream = ProjectResourceLoader.load_audio_stream(
			path,
			"Missing sound at %s",
			"Failed to load sound at %s"
		)
		if stream != null:
			streams.append(stream)
	return streams


func _copy_ids(source: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in source:
		result.append(str(value))
	return result
