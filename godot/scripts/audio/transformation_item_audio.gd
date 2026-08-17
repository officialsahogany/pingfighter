extends RefCounted

## Owns Horn Strawberry and Odin's Eye cue metadata, eager setup order,
## selective Horn-only prewarm, legacy split SFX-bus order, and player cache.
## Playback, fallbacks, explicit Eat stopping, and event timing remain in
## GameAudio and the transformation runtime owners.

const HORN_STRAWBERRY_CHANGE_SOUND_PATH := "res://assets/sounds/strawberrychange.wav"
const ODINS_EYE_CHANGE_SOUND_PATH := "res://assets/sounds/odinchange.wav"
const ODINS_EYE_DEATH_SOUND_PATH := "res://assets/sounds/odindeath.wav"
const ODINS_EYE_SPIRIT_SOUND_PATH := "res://assets/sounds/odinspirit.wav"
const ODINS_EYE_ATTACK_SOUND_PATH := "res://assets/sounds/odinattack.wav"
const ODINS_EYE_SHADOW_SOUND_PATH := "res://assets/sounds/odinshadow.wav"
const HORN_STRAWBERRY_EAT_SOUND_PATH := "res://assets/sounds/strawberryeat.wav"
const HORN_STRAWBERRY_STEM_FIRE_SOUND_PATH := "res://assets/sounds/arrow.wav"
const HORN_STRAWBERRY_STEM_HIT_SOUND_PATH := "res://assets/sounds/bullethit.wav"
const HORN_STRAWBERRY_HORN_CHARGE_SOUND_PATH := "res://assets/sounds/horncharge.wav"
const HORN_STRAWBERRY_FIELD_BUILD_SOUND_PATH := "res://assets/sounds/bonemake3.wav"
const HORN_STRAWBERRY_FIELD_BREAK_SOUND_PATH := "res://assets/sounds/bonebreak.wav"
const HORN_STRAWBERRY_FIELD_BUILD_BREAK_SOUND_PATH := "res://assets/sounds/shurikenhit.wav"
const HORN_STRAWBERRY_BOMB_TRIGGER_SOUND_PATH := "res://assets/sounds/bullethit.wav"
const HORN_STRAWBERRY_CHANGE_GAIN_DB := -3.0980
const HORN_STRAWBERRY_EAT_GAIN_DB := 0.0
const HORN_STRAWBERRY_STEM_FIRE_GAIN_DB := -6.0206
const HORN_STRAWBERRY_STEM_HIT_GAIN_DB := -10.4576
const HORN_STRAWBERRY_HORN_CHARGE_GAIN_DB := -3.7417
const HORN_STRAWBERRY_FIELD_GAIN_DB := -3.0980
const HORN_STRAWBERRY_FIELD_BUILD_BREAK_GAIN_DB := -10.4576
const HORN_STRAWBERRY_BOMB_TRIGGER_GAIN_DB := -7.9588

const SETUP_CUE_IDS := [
	"horn_strawberry_change",
	"horn_strawberry_eat",
	"horn_strawberry_stem_fire",
	"horn_strawberry_stem_hit",
	"horn_strawberry_horn_charge",
	"horn_strawberry_field_build",
	"horn_strawberry_field_break",
	"horn_strawberry_field_build_break",
	"horn_strawberry_bomb_trigger",
	"odins_eye_change",
	"odins_eye_death",
	"odins_eye_spirit",
	"odins_eye_attack",
	"odins_eye_shadow",
]
const PREWARM_CUE_IDS := [
	"horn_strawberry_change",
	"horn_strawberry_eat",
	"horn_strawberry_stem_fire",
	"horn_strawberry_stem_hit",
	"horn_strawberry_horn_charge",
	"horn_strawberry_field_build",
	"horn_strawberry_field_break",
	"horn_strawberry_field_build_break",
	"horn_strawberry_bomb_trigger",
]
const SFX_BUS_CUE_IDS := [
	"horn_strawberry_change",
	"odins_eye_change",
	"odins_eye_death",
	"odins_eye_spirit",
	"odins_eye_attack",
	"odins_eye_shadow",
	"horn_strawberry_eat",
	"horn_strawberry_stem_fire",
	"horn_strawberry_stem_hit",
	"horn_strawberry_horn_charge",
	"horn_strawberry_field_build",
	"horn_strawberry_field_break",
	"horn_strawberry_field_build_break",
	"horn_strawberry_bomb_trigger",
]
const CUE_SPECS := {
	"horn_strawberry_change": {"player_name": "HornStrawberryChangeSfx", "path": HORN_STRAWBERRY_CHANGE_SOUND_PATH, "gain_db": HORN_STRAWBERRY_CHANGE_GAIN_DB},
	"horn_strawberry_eat": {"player_name": "HornStrawberryEatSfx", "path": HORN_STRAWBERRY_EAT_SOUND_PATH, "gain_db": HORN_STRAWBERRY_EAT_GAIN_DB},
	"horn_strawberry_stem_fire": {"player_name": "HornStrawberryStemFireSfx", "path": HORN_STRAWBERRY_STEM_FIRE_SOUND_PATH, "gain_db": HORN_STRAWBERRY_STEM_FIRE_GAIN_DB},
	"horn_strawberry_stem_hit": {"player_name": "HornStrawberryStemHitSfx", "path": HORN_STRAWBERRY_STEM_HIT_SOUND_PATH, "gain_db": HORN_STRAWBERRY_STEM_HIT_GAIN_DB},
	"horn_strawberry_horn_charge": {"player_name": "HornStrawberryHornChargeSfx", "path": HORN_STRAWBERRY_HORN_CHARGE_SOUND_PATH, "gain_db": HORN_STRAWBERRY_HORN_CHARGE_GAIN_DB},
	"horn_strawberry_field_build": {"player_name": "HornStrawberryFieldBuildSfx", "path": HORN_STRAWBERRY_FIELD_BUILD_SOUND_PATH, "gain_db": HORN_STRAWBERRY_FIELD_GAIN_DB},
	"horn_strawberry_field_break": {"player_name": "HornStrawberryFieldBreakSfx", "path": HORN_STRAWBERRY_FIELD_BREAK_SOUND_PATH, "gain_db": HORN_STRAWBERRY_FIELD_GAIN_DB},
	"horn_strawberry_field_build_break": {"player_name": "HornStrawberryFieldBuildBreakSfx", "path": HORN_STRAWBERRY_FIELD_BUILD_BREAK_SOUND_PATH, "gain_db": HORN_STRAWBERRY_FIELD_BUILD_BREAK_GAIN_DB},
	"horn_strawberry_bomb_trigger": {"player_name": "HornStrawberryBombTriggerSfx", "path": HORN_STRAWBERRY_BOMB_TRIGGER_SOUND_PATH, "gain_db": HORN_STRAWBERRY_BOMB_TRIGGER_GAIN_DB},
	"odins_eye_change": {"player_name": "OdinsEyeChangeSfx", "path": ODINS_EYE_CHANGE_SOUND_PATH, "gain_db": -4.0},
	"odins_eye_death": {"player_name": "OdinsEyeDeathSfx", "path": ODINS_EYE_DEATH_SOUND_PATH, "gain_db": -4.0},
	"odins_eye_spirit": {"player_name": "OdinsEyeSpiritSfx", "path": ODINS_EYE_SPIRIT_SOUND_PATH, "gain_db": -5.0},
	"odins_eye_attack": {"player_name": "OdinsEyeAttackSfx", "path": ODINS_EYE_ATTACK_SOUND_PATH, "gain_db": -5.0},
	"odins_eye_shadow": {"player_name": "OdinsEyeShadowSfx", "path": ODINS_EYE_SHADOW_SOUND_PATH, "gain_db": -5.0},
}

var _players: Dictionary = {}


func setup(parent: Node, player_factory: Object) -> void:
	for cue_id: String in SETUP_CUE_IDS:
		var spec: Dictionary = CUE_SPECS[cue_id]
		_players[cue_id] = player_factory.create(
			parent,
			str(spec.get("player_name", "")),
			str(spec.get("path", "")),
			float(spec.get("gain_db", 0.0))
		)


func get_setup_cue_ids() -> Array[String]:
	return _copy_ids(SETUP_CUE_IDS)


func get_prewarm_cue_ids() -> Array[String]:
	return _copy_ids(PREWARM_CUE_IDS)


func get_sfx_bus_cue_ids() -> Array[String]:
	return _copy_ids(SFX_BUS_CUE_IDS)


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
	return _players_for_ids(SFX_BUS_CUE_IDS)


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
