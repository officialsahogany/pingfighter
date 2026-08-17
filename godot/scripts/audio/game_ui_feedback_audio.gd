extends RefCounted

## Owns in-game UI move/confirm/back/perk-select/character-info cue metadata, eager setup,
## step-0 prewarm and SFX-bus projections, and player cache. Public playback,
## pitch/fallback policy, bus volume, and modal event timing remain in
## GameAudio and the focused UI owners.

const UI_MOVE_SOUND_PATH := "res://assets/sounds/ui_move.wav"
const UI_CONFIRM_SOUND_PATH := "res://assets/sounds/ui_confirm.wav"
const UI_BACK_SOUND_PATH := "res://assets/sounds/ui_back.wav"
const UI_PERK_SELECT_SOUND_PATH := "res://assets/sounds/ui_perk_select.wav"
const CHARACTER_INFO_TOGGLE_SOUND_PATH := "res://assets/sounds/ui_character_info_toggle.wav"
const UI_MOVE_GAIN_DB := -9.0
const UI_CONFIRM_GAIN_DB := -7.0
const UI_BACK_GAIN_DB := -8.0
const UI_PERK_SELECT_GAIN_DB := 0.0
const CHARACTER_INFO_TOGGLE_GAIN_DB := 0.0

const CUE_IDS := ["ui_move", "ui_confirm", "ui_back", "ui_perk_select", "character_info_toggle"]
const CUE_SPECS := {
	"ui_move": {"player_name": "UiMoveSfx", "path": UI_MOVE_SOUND_PATH, "gain_db": UI_MOVE_GAIN_DB},
	"ui_confirm": {"player_name": "UiConfirmSfx", "path": UI_CONFIRM_SOUND_PATH, "gain_db": UI_CONFIRM_GAIN_DB},
	"ui_back": {"player_name": "UiBackSfx", "path": UI_BACK_SOUND_PATH, "gain_db": UI_BACK_GAIN_DB},
	"ui_perk_select": {"player_name": "UiPerkSelectSfx", "path": UI_PERK_SELECT_SOUND_PATH, "gain_db": UI_PERK_SELECT_GAIN_DB},
	"character_info_toggle": {"player_name": "CharacterInfoToggleSfx", "path": CHARACTER_INFO_TOGGLE_SOUND_PATH, "gain_db": CHARACTER_INFO_TOGGLE_GAIN_DB},
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


func get_sfx_bus_players() -> Array[AudioStreamPlayer]:
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
	for value: Variant in source:
		result.append(str(value))
	return result
