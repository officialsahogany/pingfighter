extends RefCounted

## Owns Stage 5 Hongryun primary and hurt cue metadata, split eager setup
## order, split prewarm projection, and player caches. Playback policy remains
## with GameAudio.

const PRIMARY_CUE_IDS := ["fireball", "charge", "shoot"]
const PRIMARY_CUE_SPECS := {
	"fireball": {
		"player_name": "Stage5HongryunFireballSfx",
		"path": "res://assets/sounds/stage5_hongryun_fireball.wav",
		"gain_db": -5.0,
	},
	"charge": {
		"player_name": "Stage5HongryunChargeSfx",
		"path": "res://assets/sounds/stage5_hongryun_charge.wav",
		"gain_db": -5.0,
	},
	"shoot": {
		"player_name": "Stage5HongryunShootSfx",
		"path": "res://assets/sounds/stage5_hongryun_shoot.wav",
		"gain_db": -5.0,
	},
}
const HURT_STREAM_PATHS := [
	"res://assets/sounds/stage5_hongryun_hurt_1.wav",
	"res://assets/sounds/stage5_hongryun_hurt_2.wav",
	"res://assets/sounds/stage5_hongryun_hurt_3.wav",
]
const HURT_GAIN_DB := -5.0

var _primary_players: Dictionary = {}
var _hurt_players: Array = []


func setup_primary_players(parent: Node, player_factory: Object) -> void:
	for cue_id: String in PRIMARY_CUE_IDS:
		var spec: Dictionary = PRIMARY_CUE_SPECS[cue_id]
		_primary_players[cue_id] = player_factory.create(
			parent,
			str(spec.get("player_name", "")),
			str(spec.get("path", "")),
			float(spec.get("gain_db", 0.0))
		)


func setup_hurt_players(parent: Node, player_factory: Object) -> void:
	_hurt_players.clear()
	for index in HURT_STREAM_PATHS.size():
		_hurt_players.append(player_factory.create(
			parent,
			"Stage5HongryunHurtSfx%d" % (index + 1),
			str(HURT_STREAM_PATHS[index]),
			HURT_GAIN_DB
		))


func get_primary_cue_ids() -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in PRIMARY_CUE_IDS:
		result.append(cue_id)
	return result


func get_primary_spec(cue_id: String) -> Dictionary:
	var value: Variant = PRIMARY_CUE_SPECS.get(cue_id, null)
	return value as Dictionary if value is Dictionary else {}


func get_primary_player(cue_id: String) -> AudioStreamPlayer:
	var value: Variant = _primary_players.get(cue_id, null)
	return value as AudioStreamPlayer if value is AudioStreamPlayer else null


func set_primary_player(cue_id: String, player: AudioStreamPlayer) -> void:
	if not PRIMARY_CUE_SPECS.has(cue_id):
		return
	_primary_players[cue_id] = player


func get_primary_players() -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for cue_id: String in PRIMARY_CUE_IDS:
		var player: AudioStreamPlayer = get_primary_player(cue_id)
		if player != null:
			result.append(player)
	return result


func get_hurt_players() -> Array:
	return _hurt_players


func set_hurt_players(players: Array) -> void:
	_hurt_players = players


func get_primary_prewarm_stream_paths() -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in PRIMARY_CUE_IDS:
		result.append(str(PRIMARY_CUE_SPECS[cue_id].get("path", "")))
	return result


func get_hurt_prewarm_stream_paths() -> Array[String]:
	var result: Array[String] = []
	for path: String in HURT_STREAM_PATHS:
		result.append(path)
	return result
