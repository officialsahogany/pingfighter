extends RefCounted

## Owns Stage 2 cue metadata, eager setup order, ordered prewarm projection,
## and player cache. Quake loop mutation and playback policy remain with
## GameAudio.

const CUE_IDS := [
	"hydro",
	"stonebreak",
	"rockhit",
	"rock_spawn",
	"quake",
	"boss_cry",
	"speed_defense_start",
	"speed_defense_hit",
	"speed_defense_block",
]
const CUE_SPECS := {
	"hydro": {
		"player_name": "Stage2HydroSfx",
		"path": "res://assets/sounds/hydro.wav",
		"gain_db": -5.0,
	},
	"stonebreak": {
		"player_name": "Stage2StonebreakSfx",
		"path": "res://assets/sounds/stonebreak2.wav",
		"gain_db": -5.0,
	},
	"rockhit": {
		"player_name": "Stage2RockhitSfx",
		"path": "res://assets/sounds/rockhit.wav",
		"gain_db": -5.0,
	},
	"rock_spawn": {
		"player_name": "Stage2RockSpawnSfx",
		"path": "res://assets/sounds/rock_spawn.wav",
		"gain_db": -5.0,
	},
	"quake": {
		"player_name": "Stage2QuakeSfx",
		"path": "res://assets/sounds/quake_sound.wav",
		"gain_db": -7.0,
	},
	"boss_cry": {
		"player_name": "Stage2BossCrySfx",
		"path": "res://assets/sounds/cry.wav",
		"gain_db": -6.0,
	},
	"speed_defense_start": {
		"player_name": "Stage2SpeedDefenseStartSfx",
		"path": "res://assets/sounds/speed_defense_start.wav",
		"gain_db": -4.5,
	},
	"speed_defense_hit": {
		"player_name": "Stage2SpeedDefenseHitSfx",
		"path": "res://assets/sounds/defense_hit.wav",
		"gain_db": -5.0,
	},
	"speed_defense_block": {
		"player_name": "Stage2SpeedDefenseBlockSfx",
		"path": "res://assets/sounds/blocking.wav",
		"gain_db": -5.0,
	},
}

var _players: Dictionary = {}


func setup(parent: Node, player_factory: Object) -> void:
	for cue_id: String in CUE_IDS:
		var spec: Dictionary = CUE_SPECS[cue_id]
		_players[cue_id] = player_factory.create(
			parent,
			str(spec.get("player_name", "")),
			str(spec.get("path", "")),
			float(spec.get("gain_db", 0.0))
		)


func get_cue_ids() -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in CUE_IDS:
		result.append(cue_id)
	return result


func get_spec(cue_id: String) -> Dictionary:
	var value: Variant = CUE_SPECS.get(cue_id, null)
	return value as Dictionary if value is Dictionary else {}


func get_player(cue_id: String) -> AudioStreamPlayer:
	var value: Variant = _players.get(cue_id, null)
	return value as AudioStreamPlayer if value is AudioStreamPlayer else null


func set_player(cue_id: String, player: AudioStreamPlayer) -> void:
	if not CUE_SPECS.has(cue_id):
		return
	_players[cue_id] = player


func get_players() -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for cue_id: String in CUE_IDS:
		var player: AudioStreamPlayer = get_player(cue_id)
		if player != null:
			result.append(player)
	return result


func get_prewarm_stream_paths() -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in CUE_IDS:
		result.append(str(CUE_SPECS[cue_id].get("path", "")))
	return result
