extends RefCounted

## Owns Guardian Spirit click-reaction voice catalog, eager player setup,
## normalized pet routing, and missing-stream recovery.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const PET_ORDER := [
	"lunabi",
	"volty",
	"milkring",
	"red_dragon",
	"maribo",
	"rabi",
	"lumion",
	"monkeyring",
	"onimaru",
	"orosha",
	"koyora",
]
const VOICE_SPECS := {
	"lunabi": {
		"player_name": "LingpetLunabiClickVoiceSfx",
		"path": "res://assets/sounds/lingpet/lunabi_click_reaction_voice_v1.mp3",
		"gain_db": -4.0,
	},
	"volty": {
		"player_name": "LingpetVoltyClickVoiceSfx",
		"path": "res://assets/sounds/lingpet/volty_click_reaction_voice_v1.mp3",
		"gain_db": 0.0,
	},
	"milkring": {
		"player_name": "LingpetMilkringClickVoiceSfx",
		"path": "res://assets/sounds/lingpet/milkring_click_reaction_voice_v1.mp3",
		"gain_db": 0.0,
	},
	"red_dragon": {
		"player_name": "LingpetRedDragonClickVoiceSfx",
		"path": "res://assets/sounds/lingpet/red_dragon_click_reaction_voice_v1.mp3",
		"gain_db": 0.0,
	},
	"maribo": {
		"player_name": "LingpetMariboClickVoiceSfx",
		"path": "res://assets/sounds/lingpet/maribo_click_reaction_voice_v1.mp3",
		"gain_db": 0.0,
	},
	"rabi": {
		"player_name": "LingpetRabiClickVoiceSfx",
		"path": "res://assets/sounds/lingpet/rabi_click_reaction_voice_v1.mp3",
		"gain_db": 0.0,
	},
	"lumion": {
		"player_name": "LingpetLumionClickVoiceSfx",
		"path": "res://assets/sounds/lingpet/lumion_click_reaction_voice_v1.mp3",
		"gain_db": 0.0,
	},
	"monkeyring": {
		"player_name": "LingpetMonkeyringClickVoiceSfx",
		"path": "res://assets/sounds/lingpet/monkeyring_click_reaction_voice_v1.mp3",
		"gain_db": 0.0,
	},
	"onimaru": {
		"player_name": "LingpetOnimaruClickVoiceSfx",
		"path": "res://assets/sounds/lingpet/onimaru_click_reaction_voice_v1.mp3",
		"gain_db": 0.0,
	},
	"orosha": {
		"player_name": "LingpetOroshaClickVoiceSfx",
		"path": "res://assets/sounds/lingpet/orosha_click_reaction_voice_v1.wav",
		"gain_db": 0.0,
	},
	"koyora": {
		"player_name": "LingpetKoyoraClickVoiceSfx",
		"path": "res://assets/sounds/lingpet/koyora_click_reaction_voice_v1.mp3",
		"gain_db": 0.0,
	},
}
const PREWARM_PET_IDS := ["lunabi", "volty", "milkring", "red_dragon"]

var owner_node: Node = null
var player_factory: Object = null
var _players: Dictionary = {}


func configure(parent: Node, factory: Object) -> void:
	owner_node = parent
	player_factory = factory


func setup(parent: Node, factory: Object) -> void:
	configure(parent, factory)
	for pet_id: String in PET_ORDER:
		_players[pet_id] = _create_player(VOICE_SPECS[pet_id])


func get_supported_pet_ids() -> Array[String]:
	var result: Array[String] = []
	for pet_id: String in PET_ORDER:
		result.append(pet_id)
	return result


func get_spec(pet_id: String) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	var value: Variant = VOICE_SPECS.get(normalized_pet_id, null)
	return value as Dictionary if value is Dictionary else {}


func get_prewarm_stream_paths() -> Array[String]:
	var result: Array[String] = []
	for pet_id: String in PREWARM_PET_IDS:
		result.append(str(VOICE_SPECS[pet_id].get("path", "")))
	return result


func get_player(pet_id: String) -> AudioStreamPlayer:
	var value: Variant = _players.get(_normalize_pet_id(pet_id), null)
	return value as AudioStreamPlayer if value is AudioStreamPlayer else null


func set_player(pet_id: String, player: AudioStreamPlayer) -> void:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if not VOICE_SPECS.has(normalized_pet_id):
		return
	_players[normalized_pet_id] = player


func get_players() -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for pet_id: String in PET_ORDER:
		var player := get_player(pet_id)
		if player != null:
			result.append(player)
	return result


func ensure_player_for_pet(pet_id: String) -> AudioStreamPlayer:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	var spec: Dictionary = get_spec(normalized_pet_id)
	if spec.is_empty():
		return null
	var current_player := get_player(normalized_pet_id)
	if current_player != null and current_player.stream != null:
		return current_player
	var replacement := _create_optional_player(spec)
	_players[normalized_pet_id] = replacement
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


func _normalize_pet_id(value: String) -> String:
	return value.strip_edges().to_lower()
