extends RefCounted

## Owns one-shot combat cues that belong to Mugong-fusion byproducts rather
## than a specific character or stage. Playback timing stays with the owning
## gameplay state and the public GameAudio facade.

const SPELLBREAKER_GUARD_PARRY_SOUND_PATH := "res://assets/sounds/magicdefense.wav"
# Original PingFighter `_spawn_barrier_block_effect`: volume 0.5.
# 20 * log10(0.5) = -6.0205999 dB.
const SPELLBREAKER_GUARD_PARRY_GAIN_DB := -6.0205999
const CUE_IDS := ["spellbreaker_guard_parry"]
const CUE_SPECS := {
	"spellbreaker_guard_parry": {
		"player_name": "PerkFusionSpellbreakerGuardParrySfx",
		"path": SPELLBREAKER_GUARD_PARRY_SOUND_PATH,
		"gain_db": SPELLBREAKER_GUARD_PARRY_GAIN_DB,
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
	return ["spellbreaker_guard_parry"]


func get_spec(cue_id: String) -> Dictionary:
	var value: Variant = CUE_SPECS.get(cue_id, null)
	return value as Dictionary if value is Dictionary else {}


func get_prewarm_stream_paths() -> Array[String]:
	return [SPELLBREAKER_GUARD_PARRY_SOUND_PATH]


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
