extends RefCounted

## Owns stage BGM metadata, ordered boot/prewarm projection, stage-selection
## pools, and player cache. GameAudio retains setup progress, owner-stage
## filtering, playback/prime/stop/mute state, selection RNG, loop-safe stream
## duplication, bus routing, and volume policy.

const STAGE1_BGM_PATH := "res://assets/bgm/stage1_shamanic_bell_rite_bgm.wav"
const STAGE2_BGM_PATH := "res://assets/bgm/stage2bgm.ogg"
const STAGE2_ALT_BGM_PATH := "res://assets/bgm/stage2bgm2.mp3"
const STAGE3_BGM_PATH := "res://assets/bgm/stage3bgm.ogg"
const STAGE4_BGM_PATH := "res://assets/bgm/stage4bgm.ogg"
const STAGE4_PHASE2_BGM_PATH := "res://assets/bgm/stage4bgm-phase2.mp3"
const STAGE5_BGM_PATH := "res://assets/bgm/stage5_hongryun_bgm.ogg"
const STAGE6_BGM_PATH := "res://assets/bgm/stage6_tetriser_bgm.ogg"
const STAGE7_BGM_PATH := "res://assets/bgm/stage7_akamu_bgm.ogg"

const STAGE1_BGM_GAIN := 0.9
const STAGE2_BGM_GAIN := 1.0
const STAGE3_BGM_GAIN := 0.9
const STAGE4_BGM_GAIN := 0.9
const STAGE5_BGM_GAIN := 0.9
const STAGE6_BGM_GAIN := 0.9
const STAGE7_BGM_GAIN := 0.9

const STAGE1_BGM_NAMES := ["stage1"]
const STAGE2_BGM_NAMES := ["stage2", "stage2_alt"]
const BGM_IDS := [
	"stage1",
	"stage2",
	"stage2_alt",
	"stage3",
	"stage4",
	"stage4_phase2",
	"stage5",
	"stage6",
	"stage7",
]
const SETUP_STEP_COUNT := 10
const BGM_SPECS := {
	"stage1": {"player_name": "Stage1Bgm", "path": STAGE1_BGM_PATH, "gain": STAGE1_BGM_GAIN},
	"stage2": {"player_name": "Stage2Bgm", "path": STAGE2_BGM_PATH, "gain": STAGE2_BGM_GAIN},
	"stage2_alt": {"player_name": "Stage2AltBgm", "path": STAGE2_ALT_BGM_PATH, "gain": STAGE2_BGM_GAIN},
	"stage3": {"player_name": "Stage3Bgm", "path": STAGE3_BGM_PATH, "gain": STAGE3_BGM_GAIN},
	"stage4": {"player_name": "Stage4Bgm", "path": STAGE4_BGM_PATH, "gain": STAGE4_BGM_GAIN},
	"stage4_phase2": {"player_name": "Stage4Phase2Bgm", "path": STAGE4_PHASE2_BGM_PATH, "gain": STAGE4_BGM_GAIN},
	"stage5": {"player_name": "Stage5Bgm", "path": STAGE5_BGM_PATH, "gain": STAGE5_BGM_GAIN},
	"stage6": {"player_name": "Stage6Bgm", "path": STAGE6_BGM_PATH, "gain": STAGE6_BGM_GAIN},
	"stage7": {"player_name": "Stage7Bgm", "path": STAGE7_BGM_PATH, "gain": STAGE7_BGM_GAIN},
}

var _players: Dictionary = {}


func get_bgm_ids() -> Array[String]:
	return _copy_ids(BGM_IDS)


func get_stage_pool(stage: int) -> Array[String]:
	if stage == 1:
		return _copy_ids(STAGE1_BGM_NAMES)
	if stage == 2:
		return _copy_ids(STAGE2_BGM_NAMES)
	return []


func get_spec(bgm_id: String) -> Dictionary:
	var value: Variant = BGM_SPECS.get(bgm_id, null)
	return value as Dictionary if value is Dictionary else {}


func get_stream_path(bgm_id: String) -> String:
	return str(get_spec(bgm_id).get("path", ""))


func get_required_stream_paths(should_include: Callable) -> Array[String]:
	var paths: Array[String] = []
	for bgm_id: String in BGM_IDS:
		if should_include.is_valid() and not bool(should_include.call(bgm_id)):
			continue
		paths.append(get_stream_path(bgm_id))
	return paths


func create_and_cache_player(bgm_id: String, create_player: Callable) -> AudioStreamPlayer:
	var spec := get_spec(bgm_id)
	if spec.is_empty() or not create_player.is_valid():
		return null
	var value: Variant = create_player.call(
		str(spec.get("player_name", "")),
		str(spec.get("path", "")),
		float(spec.get("gain", 1.0))
	)
	if value is AudioStreamPlayer:
		_players[bgm_id] = value
		return value as AudioStreamPlayer
	return null


func get_player(bgm_id: String) -> AudioStreamPlayer:
	var value: Variant = _players.get(bgm_id, null)
	return value as AudioStreamPlayer if value is AudioStreamPlayer else null


func set_player(bgm_id: String, player: AudioStreamPlayer) -> void:
	if BGM_SPECS.has(bgm_id):
		_players[bgm_id] = player


func get_players() -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for bgm_id: String in BGM_IDS:
		var player := get_player(bgm_id)
		if player != null:
			result.append(player)
	return result


func _copy_ids(source: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in source:
		result.append(str(value))
	return result
