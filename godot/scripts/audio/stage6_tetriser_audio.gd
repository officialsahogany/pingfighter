extends RefCounted

## Owns Stage 6 Tetriser one-shot cue metadata, eager setup order, and player
## cache. These cues intentionally retain their established non-prewarm policy.

const CUE_IDS := ["break", "wall", "super", "big", "shield", "laser"]
const CUE_SPECS := {
	"break": {
		"player_name": "Stage6TetriserBreakSfx",
		"path": "res://assets/sounds/stage6_tetriser_break.wav",
		"gain_db": -6.0,
	},
	"wall": {
		"player_name": "Stage6TetriserWallSfx",
		"path": "res://assets/sounds/stage6_tetriser_wall.wav",
		"gain_db": -6.0,
	},
	"super": {
		"player_name": "Stage6TetriserSuperSfx",
		"path": "res://assets/sounds/stage6_tetriser_super_roar.wav",
		"gain_db": -4.0,
	},
	"big": {
		"player_name": "Stage6TetriserBigSfx",
		"path": "res://assets/sounds/stage6_tetriser_big.wav",
		"gain_db": -4.0,
	},
	"shield": {
		"player_name": "Stage6TetriserShieldSfx",
		"path": "res://assets/sounds/stage6_tetriser_shield.wav",
		"gain_db": -5.0,
	},
	"laser": {
		"player_name": "Stage6TetriserLaserSfx",
		"path": "res://assets/sounds/stage6_tetriser_laser.wav",
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
