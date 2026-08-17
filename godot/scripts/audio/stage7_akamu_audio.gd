extends RefCounted

## Owns Stage 7 Akamu battle-cue metadata, eager setup order, ordered prewarm
## projection, and player cache. Playback pitch remains with GameAudio.

const CUE_IDS := ["shuriken_shoot", "shuriken_hit", "cloud", "aura_block", "clone_spawn", "clone_out"]
const CUE_SPECS := {
	"shuriken_shoot": {
		"player_name": "Stage7AkamuShurikenShootSfx",
		"path": "res://assets/sounds/stage7_akamu_shuriken_shoot.wav",
		"gain_db": 0.0,
	},
	"shuriken_hit": {
		"player_name": "Stage7AkamuShurikenHitSfx",
		"path": "res://assets/sounds/stage7_akamu_shuriken_hit.wav",
		"gain_db": 0.0,
	},
	"cloud": {
		"player_name": "Stage7AkamuCloudSfx",
		"path": "res://assets/sounds/stage7_akamu_cloud.wav",
		"gain_db": 0.0,
	},
	"aura_block": {
		"player_name": "Stage7AkamuAuraBlockSfx",
		"path": "res://assets/sounds/stage7_akamu_aura_block.wav",
		"gain_db": 0.0,
	},
	"clone_spawn": {
		"player_name": "Stage7AkamuCloneSpawnSfx",
		"path": "res://assets/sounds/stage7_akamu_clone_spawn.wav",
		"gain_db": 0.0,
	},
	"clone_out": {
		"player_name": "Stage7AkamuCloneOutSfx",
		"path": "res://assets/sounds/stage7_akamu_clone_out.wav",
		"gain_db": 0.0,
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
