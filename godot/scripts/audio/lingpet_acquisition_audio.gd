extends RefCounted

## Owns Guardian Spirit acquisition-cinematic cue metadata, eager setup,
## ordered prewarm projection, player cache, and missing-stream recovery.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const CUE_IDS := ["cutin", "click_deep_bass", "click_crackle_sweep"]
const CUE_SPECS := {
	"cutin": {
		"player_name": "LingpetAcquireCutinSfx",
		"path": "res://assets/sounds/lingpet/lingpet_acquire_ominous_shadow_shimmer_02.wav",
		"gain_db": 0.0,
	},
	"click_deep_bass": {
		"player_name": "LingpetAcquireClickDeepBassSfx",
		"path": "res://assets/sounds/lingpet/lingpet_acquire_click_deep_bass_doom.wav",
		"gain_db": -2.0,
	},
	"click_crackle_sweep": {
		"player_name": "LingpetAcquireClickCrackleSweepSfx",
		"path": "res://assets/sounds/lingpet/lingpet_acquire_click_magic_crackle_sweep.wav",
		"gain_db": -5.0,
	},
}

var owner_node: Node = null
var player_factory: Object = null
var _players: Dictionary = {}


func configure(parent: Node, factory: Object) -> void:
	owner_node = parent
	player_factory = factory


func setup(parent: Node, factory: Object) -> void:
	configure(parent, factory)
	for cue_id: String in CUE_IDS:
		_players[cue_id] = _create_player(CUE_SPECS[cue_id])


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


func ensure_player(cue_id: String) -> AudioStreamPlayer:
	var spec: Dictionary = get_spec(cue_id)
	if spec.is_empty():
		return null
	var current_player: AudioStreamPlayer = get_player(cue_id)
	if current_player != null and current_player.stream != null:
		return current_player
	var replacement: AudioStreamPlayer = _create_optional_player(spec)
	_players[cue_id] = replacement
	return replacement


func _create_player(spec: Dictionary) -> AudioStreamPlayer:
	if player_factory == null:
		return null
	return player_factory.create(
		owner_node,
		str(spec.get("player_name", "")),
		str(spec.get("path", "")),
		float(spec.get("gain_db", 0.0))
	) as AudioStreamPlayer


func _create_optional_player(spec: Dictionary) -> AudioStreamPlayer:
	var path := str(spec.get("path", ""))
	if FileAccess.file_exists(path) or ProjectResourceLoader.audio_resource_exists(path):
		return _create_player(spec)
	var player := AudioStreamPlayer.new()
	player.name = str(spec.get("player_name", ""))
	player.bus = "Master"
	player.volume_db = float(spec.get("gain_db", 0.0))
	if owner_node != null:
		owner_node.add_child(player)
	return player
