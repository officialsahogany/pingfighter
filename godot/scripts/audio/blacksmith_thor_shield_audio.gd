extends RefCounted

## Owns Thor Shield cue metadata, eager player-creation order, player cache,
## and SFX-bus projection. Playback pitch and runtime event timing stay in
## GameAudio and blacksmith_thor_shield_state respectively.

const CUE_IDS := [
	"open",
	"close",
	"swing",
	"block",
]
const CUE_SPECS := {
	"open": {
		"player_name": "ThorShieldOpenSfx",
		"path": "res://assets/sounds/umbopen.wav",
		"gain_db": -4.4,
	},
	"close": {
		"player_name": "ThorShieldCloseSfx",
		"path": "res://assets/sounds/umbclose.wav",
		"gain_db": -4.4,
	},
	"swing": {
		"player_name": "ThorShieldSwingSfx",
		"path": "res://assets/sounds/swing.wav",
		"gain_db": -5.0,
	},
	"block": {
		"player_name": "ThorShieldBlockSfx",
		"path": "res://assets/sounds/blocking.wav",
		"gain_db": -4.0,
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
	return _copy_ids(CUE_IDS)


func get_spec(cue_id: String) -> Dictionary:
	var value: Variant = CUE_SPECS.get(cue_id, null)
	return value as Dictionary if value is Dictionary else {}


func get_player(cue_id: String) -> AudioStreamPlayer:
	var value: Variant = _players.get(cue_id, null)
	return value as AudioStreamPlayer if value is AudioStreamPlayer else null


func set_player(cue_id: String, player: AudioStreamPlayer) -> void:
	if CUE_SPECS.has(cue_id):
		_players[cue_id] = player


func get_players() -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for cue_id: String in CUE_IDS:
		var player := get_player(cue_id)
		if player != null:
			result.append(player)
	return result


func _copy_ids(source: Array) -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in source:
		result.append(cue_id)
	return result
