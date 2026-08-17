extends RefCounted

## Owns Stage 3 Menhera/Kuromi cue metadata, eager setup order, optional-player
## routing, ordered prewarm projection, and player cache. Psychoball loop
## mutation and playback policy remain with GameAudio.

const CUE_IDS := [
	"tail",
	"psychoball",
	"dollcurse",
	"tears",
	"chest_land",
	"curse_explode",
	"kuromi_awake",
	"kuromi_stonebreak",
	"kuromi_tongue",
	"kuromi_swallow",
	"kuromi_spit",
]
const CUE_SPECS := {
	"tail": {
		"player_name": "Stage3TailSfx",
		"path": "res://assets/sounds/stage3tail.wav",
		"gain_db": -4.5,
	},
	"psychoball": {
		"player_name": "Stage3PsychoballSfx",
		"path": "res://assets/sounds/psychoball.wav",
		"gain_db": -6.0,
	},
	"dollcurse": {
		"player_name": "Stage3DollcurseSfx",
		"path": "res://assets/sounds/dollcurse.wav",
		"gain_db": -5.0,
	},
	"tears": {
		"player_name": "Stage3TearsSfx",
		"path": "res://assets/sounds/tears.wav",
		"gain_db": -7.0,
	},
	"chest_land": {
		"player_name": "Stage3ChestLandSfx",
		"path": "res://assets/sounds/bonemake.wav",
		"gain_db": -5.0,
	},
	"curse_explode": {
		"player_name": "Stage3CurseExplodeSfx",
		"path": "res://assets/sounds/weakexplosion.wav",
		"gain_db": -5.0,
	},
	"kuromi_awake": {
		"player_name": "Stage3KuromiAwakeSfx",
		"path": "res://assets/sounds/kuromiawake.wav",
		"gain_db": -3.0,
	},
	"kuromi_stonebreak": {
		"player_name": "Stage3KuromiStonebreakSfx",
		"path": "res://assets/sounds/stonebreak_large.wav",
		"gain_db": -4.0,
		"optional": true,
	},
	"kuromi_tongue": {
		"player_name": "Stage3KuromiTongueSfx",
		"path": "res://assets/sounds/kuromitongue.wav",
		"gain_db": -4.5,
	},
	"kuromi_swallow": {
		"player_name": "Stage3KuromiSwallowSfx",
		"path": "res://assets/sounds/kuromiswallow.wav",
		"gain_db": -5.0,
	},
	"kuromi_spit": {
		"player_name": "Stage3KuromiSpitSfx",
		"path": "res://assets/sounds/kuromispit.wav",
		"gain_db": -4.0,
	},
}

var _players: Dictionary = {}


func setup(parent: Node, player_factory: Object, optional_player_factory: Callable = Callable()) -> void:
	for cue_id: String in CUE_IDS:
		var spec: Dictionary = CUE_SPECS[cue_id]
		var player_name := str(spec.get("player_name", ""))
		var path := str(spec.get("path", ""))
		var gain_db := float(spec.get("gain_db", 0.0))
		if bool(spec.get("optional", false)) and optional_player_factory.is_valid():
			_players[cue_id] = optional_player_factory.call(player_name, path, gain_db)
		else:
			_players[cue_id] = player_factory.create(parent, player_name, path, gain_db)


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
