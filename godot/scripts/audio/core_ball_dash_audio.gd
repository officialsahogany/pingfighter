extends RefCounted

## Owns core ball/dash cue metadata, eager player-creation order, prewarm
## projection, player cache, and SFX-bus order. Playback, panning, cooldowns,
## fallback policy, and Dash Delay loop mutation/cleanup remain in GameAudio.

const CUE_IDS := [
	"paddle_hit",
	"serve",
	"pingpong_serve",
	"wall_hit",
	"dash",
	"half_dash",
	"dash_delay",
	"dash_charge",
	"bust_up_dash",
	"boost_charging",
	"soul_burst_dash",
	"dash_spirit_delete",
]
const CUE_SPECS := {
	"paddle_hit": {"player_name": "PaddleHitSfx", "path": "res://assets/sounds/paddle_hit.wav", "gain_db": -5.0},
	"serve": {"player_name": "ServeSfx", "path": "res://assets/sounds/serve.wav", "gain_db": -5.0},
	"pingpong_serve": {"player_name": "PingpongServeSfx", "path": "res://assets/sounds/pong_paddle.wav", "gain_db": -5.0},
	"wall_hit": {"player_name": "WallHitSfx", "path": "res://assets/sounds/wall_hit.wav", "gain_db": -7.0},
	"dash": {"player_name": "DashSfx", "path": "res://assets/sounds/dash.wav", "gain_db": -6.0},
	"half_dash": {"player_name": "HalfDashSfx", "path": "res://assets/sounds/halfdash.wav", "gain_db": -6.0},
	"dash_delay": {"player_name": "DashDelaySfx", "path": "res://assets/sounds/dashdelay.wav", "gain_db": 0.0},
	"dash_charge": {"player_name": "DashChargeSfx", "path": "res://assets/sounds/dashcharge.wav", "gain_db": -5.0},
	"bust_up_dash": {"player_name": "BustUpDashSfx", "path": "res://assets/sounds/bustup.wav", "gain_db": -5.0},
	"boost_charging": {"player_name": "BoostChargingSfx", "path": "res://assets/sounds/boostcharging.wav", "gain_db": -5.0},
	"soul_burst_dash": {"player_name": "SoulBurstDashSfx", "path": "res://assets/sounds/soulbust.wav", "gain_db": -5.0},
	"dash_spirit_delete": {"player_name": "DashSpiritDeleteSfx", "path": "res://assets/sounds/dashspiritdelete.wav", "gain_db": -5.0},
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


func get_prewarm_stream_paths() -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in CUE_IDS:
		result.append(str(CUE_SPECS[cue_id].get("path", "")))
	return result


func _copy_ids(source: Array) -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in source:
		result.append(cue_id)
	return result
