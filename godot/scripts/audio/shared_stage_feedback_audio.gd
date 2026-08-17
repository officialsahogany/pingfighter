extends RefCounted

## Owns shared round/intro/field feedback cue metadata, the phase-correct
## primary/tail setup and prewarm/SFX projections, and player cache. Public
## playback, pitch/fallback policy, intro stopping, event timing, and round
## lifecycle remain in GameAudio and the focused runtime owners.

const ROUND_SET_SOUND_PATH := "res://assets/sounds/roundset.wav"
const ROUND_SET_GAIN_DB := -8.0
const ROUND_DEFEAT_SOUND_PATH := "res://assets/sounds/round_defeat.wav"
const ROUND_DEFEAT_GAIN_DB := 6.0206
const STAGE_CLEAR_GONG_SOUND_PATH := "res://assets/sounds/roundgong.wav"
const STAGE_CLEAR_GONG_GAIN_DB := -6.0
const BALL_SPAWN_INTRO_SOUND_PATH := "res://assets/sounds/stagestart_godot_short.wav"
const STAGE_LANDING_ZOOM_INTRO_SOUND_PATH := "res://assets/sounds/stage_landing_zoom_doom.wav"
const BALLOON_POP_SOUND_PATH := "res://assets/sounds/balloonboom.wav"
const STAGE1_BALLOON_DOOR_SOUND_PATH := "res://assets/sounds/stage1door.wav"
const STAGE1_BALLOON_MACHINE_SOUND_PATH := "res://assets/sounds/stage1muchine.wav"
const STAR_COLLECT_SOUND_PATH := "res://assets/sounds/star.wav"
const LEAF_SHIELD_SOUND_PATH := "res://assets/sounds/leaf.wav"
const TRAMPOLINE_BOUNCE_SOUND_PATH := "res://assets/sounds/trampoline_bounce.wav"
const TRAMPOLINE_BOUNCE_GAIN_DB := -4.0

const PRIMARY_CUE_IDS := [
	"round_set",
	"round_defeat",
	"stage_clear_gong",
	"ball_spawn_intro",
	"stage_landing_zoom_intro",
	"balloon_pop",
	"stage1_balloon_door",
	"stage1_balloon_machine",
	"star_collect",
]
const TAIL_CUE_IDS := [
	"leaf_shield",
	"trampoline_bounce",
]
const CUE_SPECS := {
	"round_set": {"player_name": "RoundSetSfx", "path": ROUND_SET_SOUND_PATH, "gain_db": ROUND_SET_GAIN_DB},
	"round_defeat": {"player_name": "RoundDefeatSfx", "path": ROUND_DEFEAT_SOUND_PATH, "gain_db": ROUND_DEFEAT_GAIN_DB},
	"stage_clear_gong": {"player_name": "StageClearGongSfx", "path": STAGE_CLEAR_GONG_SOUND_PATH, "gain_db": STAGE_CLEAR_GONG_GAIN_DB},
	"ball_spawn_intro": {"player_name": "BallSpawnIntroSfx", "path": BALL_SPAWN_INTRO_SOUND_PATH, "gain_db": -4.0},
	"stage_landing_zoom_intro": {"player_name": "StageLandingZoomIntroSfx", "path": STAGE_LANDING_ZOOM_INTRO_SOUND_PATH, "gain_db": -3.0},
	"balloon_pop": {"player_name": "BalloonPopSfx", "path": BALLOON_POP_SOUND_PATH, "gain_db": -5.0},
	"stage1_balloon_door": {"player_name": "Stage1BalloonDoorSfx", "path": STAGE1_BALLOON_DOOR_SOUND_PATH, "gain_db": -6.0},
	"stage1_balloon_machine": {"player_name": "Stage1BalloonMachineSfx", "path": STAGE1_BALLOON_MACHINE_SOUND_PATH, "gain_db": -7.0},
	"star_collect": {"player_name": "StarCollectSfx", "path": STAR_COLLECT_SOUND_PATH, "gain_db": -4.0},
	"leaf_shield": {"player_name": "LeafShieldSfx", "path": LEAF_SHIELD_SOUND_PATH, "gain_db": -4.5},
	"trampoline_bounce": {"player_name": "TrampolineBounceSfx", "path": TRAMPOLINE_BOUNCE_SOUND_PATH, "gain_db": TRAMPOLINE_BOUNCE_GAIN_DB},
}

var _players: Dictionary = {}


func setup_primary(parent: Node, player_factory: Object) -> void:
	_setup_players(PRIMARY_CUE_IDS, parent, player_factory)


func setup_tail(parent: Node, player_factory: Object) -> void:
	_setup_players(TAIL_CUE_IDS, parent, player_factory)


func get_primary_cue_ids() -> Array[String]:
	return _copy_ids(PRIMARY_CUE_IDS)


func get_tail_cue_ids() -> Array[String]:
	return _copy_ids(TAIL_CUE_IDS)


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


func get_tail_players() -> Array[AudioStreamPlayer]:
	return _players_for_ids(TAIL_CUE_IDS)


func get_primary_prewarm_stream_paths() -> Array[String]:
	return _paths_for_ids(PRIMARY_CUE_IDS)


func get_tail_prewarm_stream_paths() -> Array[String]:
	return _paths_for_ids(TAIL_CUE_IDS)


func _setup_players(cue_ids: Array, parent: Node, player_factory: Object) -> void:
	for cue_id: String in cue_ids:
		var spec: Dictionary = CUE_SPECS[cue_id]
		_players[cue_id] = player_factory.create(
			parent,
			str(spec.get("player_name", "")),
			str(spec.get("path", "")),
			float(spec.get("gain_db", 0.0))
		)


func _players_for_ids(cue_ids: Array) -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for cue_id: String in cue_ids:
		var player := get_player(cue_id)
		if player != null:
			result.append(player)
	return result


func _paths_for_ids(cue_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in cue_ids:
		result.append(str(CUE_SPECS[cue_id].get("path", "")))
	return result


func _copy_ids(source: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in source:
		result.append(str(value))
	return result
