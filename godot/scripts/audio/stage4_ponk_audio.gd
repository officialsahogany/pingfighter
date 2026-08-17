extends RefCounted

## Owns Stage 4 Ponk cue metadata, eager setup order, ordered prewarm
## projection, and player cache. Magnetic loop mutation remains with GameAudio.

const CUE_IDS := ["moon_shoot", "fragment_shoot", "temple_hit", "birdkill", "magnetic", "meditation", "meditation_after", "illusion"]
const CUE_SPECS := {
	"moon_shoot": {
		"player_name": "Stage4MoonShootSfx",
		"path": "res://assets/sounds/stage4moonshoot.wav",
		"gain_db": -4.0,
	},
	"fragment_shoot": {
		"player_name": "Stage4FragmentShootSfx",
		"path": "res://assets/sounds/stage4moonshoot2.wav",
		"gain_db": -5.0,
	},
	"temple_hit": {
		"player_name": "Stage4TempleHitSfx",
		"path": "res://assets/sounds/stage4hitting.wav",
		"gain_db": -5.0,
	},
	"birdkill": {
		"player_name": "Stage4BirdkillSfx",
		"path": "res://assets/sounds/birdkill.wav",
		"gain_db": -5.0,
	},
	"magnetic": {
		"player_name": "Stage4MagneticSfx",
		"path": "res://assets/sounds/magnetic.wav",
		"gain_db": -7.0,
	},
	"meditation": {
		"player_name": "Stage4MeditationSfx",
		"path": "res://assets/sounds/ponkmeditation.wav",
		"gain_db": -5.0,
	},
	"meditation_after": {
		"player_name": "Stage4MeditationAfterSfx",
		"path": "res://assets/sounds/meditationafter.wav",
		"gain_db": -5.0,
	},
	"illusion": {
		"player_name": "Stage4IllusionSfx",
		"path": "res://assets/sounds/ponkillusion.wav",
		"gain_db": -6.0,
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
