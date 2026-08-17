extends RefCounted

## Owns the Stage 1 Dalji/Gaksital boss-skill cue catalog, eager setup order,
## unique prewarm projection, primary SFX-bus order, and extra fan layers.
## Playback pitch/volume, fan-pool cursor policy, and cleanup remain in GameAudio.

const SETUP_CUE_IDS := [
	"whip",
	"gaksital_fan",
	"gaksital_fan_layer2",
	"gaksital_fan_layer3",
	"whipcrack",
]
const PRIMARY_CUE_IDS := [
	"whip",
	"gaksital_fan",
	"whipcrack",
]
const PREWARM_CUE_IDS := [
	"whip",
	"gaksital_fan",
	"whipcrack",
]
const FAN_LAYER_CUE_IDS := [
	"gaksital_fan_layer2",
	"gaksital_fan_layer3",
]
const CUE_SPECS := {
	"whip": {
		"player_name": "WhipSfx",
		"path": "res://assets/sounds/whip_effect.wav",
		"gain_db": -5.0,
	},
	"gaksital_fan": {
		"player_name": "GaksitalFanSfx",
		"path": "res://assets/sounds/fan.wav",
		"gain_db": -9.11863911299449,
	},
	"gaksital_fan_layer2": {
		"player_name": "GaksitalFanSfxLayer2",
		"path": "res://assets/sounds/fan.wav",
		"gain_db": -9.11863911299449,
	},
	"gaksital_fan_layer3": {
		"player_name": "GaksitalFanSfxLayer3",
		"path": "res://assets/sounds/fan.wav",
		"gain_db": -9.11863911299449,
	},
	"whipcrack": {
		"player_name": "WhipcrackSfx",
		"path": "res://assets/sounds/whipcrack.wav",
		"gain_db": -4.43697499232713,
	},
}

var _players: Dictionary = {}


func setup(parent: Node, player_factory: Object, optional_player_factory: Callable) -> void:
	for cue_id: String in SETUP_CUE_IDS:
		var spec: Dictionary = CUE_SPECS[cue_id]
		var player: AudioStreamPlayer
		if FAN_LAYER_CUE_IDS.has(cue_id):
			var optional_value: Variant = optional_player_factory.call(
				str(spec.get("player_name", "")),
				str(spec.get("path", "")),
				float(spec.get("gain_db", 0.0))
			)
			player = optional_value as AudioStreamPlayer if optional_value is AudioStreamPlayer else null
		else:
			player = player_factory.create(
				parent,
				str(spec.get("player_name", "")),
				str(spec.get("path", "")),
				float(spec.get("gain_db", 0.0))
			)
		_players[cue_id] = player


func get_setup_cue_ids() -> Array[String]:
	return _copy_ids(SETUP_CUE_IDS)


func get_primary_cue_ids() -> Array[String]:
	return _copy_ids(PRIMARY_CUE_IDS)


func get_prewarm_cue_ids() -> Array[String]:
	return _copy_ids(PREWARM_CUE_IDS)


func get_fan_layer_cue_ids() -> Array[String]:
	return _copy_ids(FAN_LAYER_CUE_IDS)


func get_spec(cue_id: String) -> Dictionary:
	var value: Variant = CUE_SPECS.get(cue_id, null)
	return value as Dictionary if value is Dictionary else {}


func get_player(cue_id: String) -> AudioStreamPlayer:
	var value: Variant = _players.get(cue_id, null)
	return value as AudioStreamPlayer if value is AudioStreamPlayer else null


func set_player(cue_id: String, player: AudioStreamPlayer) -> void:
	if CUE_SPECS.has(cue_id):
		_players[cue_id] = player


func get_primary_players() -> Array[AudioStreamPlayer]:
	return _players_for_ids(PRIMARY_CUE_IDS)


func get_fan_layers() -> Array:
	return _players_for_ids(FAN_LAYER_CUE_IDS)


func set_fan_layers(players: Array) -> void:
	for index in range(FAN_LAYER_CUE_IDS.size()):
		var player: AudioStreamPlayer = null
		if index < players.size() and players[index] is AudioStreamPlayer:
			player = players[index] as AudioStreamPlayer
		_players[FAN_LAYER_CUE_IDS[index]] = player


func get_prewarm_stream_paths() -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in PREWARM_CUE_IDS:
		result.append(str(CUE_SPECS[cue_id].get("path", "")))
	return result


func _players_for_ids(cue_ids: Array) -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for cue_id: String in cue_ids:
		var player := get_player(cue_id)
		if player != null:
			result.append(player)
	return result


func _copy_ids(source: Array) -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in source:
		result.append(cue_id)
	return result
