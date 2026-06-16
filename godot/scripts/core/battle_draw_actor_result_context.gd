extends RefCounted

const BOSS_RESULT_FRAME_SPEED := 0.18
const BOSS_RESULT_FRAME_COUNT := 8
const BOSS_STAGE2_VICTORY_FRAME_SPEED := 0.040
const BOSS_STAGE2_VICTORY_FRAME_COUNT := 64
const BOSS_STAGE2_DEFEAT_FRAME_SPEED := 0.025
const BOSS_STAGE2_DEFEAT_FRAME_COUNT := 64
const PLAYER_VICTORY_FRAME_SPEED := 0.020
const PLAYER_VICTORY_FRAME_COUNT := 64
const PLAYER_VICTORY_GRID_COLS := 8
const BLACKSMITH_PLAYER_VICTORY_FRAME_COUNT := 49
const BLACKSMITH_PLAYER_VICTORY_GRID_COLS := 7
const BLACKSMITH_PLAYER_DEFEAT_FRAME_COUNT := 49
const BLACKSMITH_PLAYER_DEFEAT_GRID_COLS := 7
const PLAYER_DEFEAT_FRAME_SPEED := 0.09
const PLAYER_DEFEAT_FRAME_COUNT := 16
const PLAYER_DEFEAT_GRID_COLS := 4
const PLAYER_DEFEAT_64_FRAME_SPEED := 0.025
const PLAYER_DEFEAT_64_FRAME_COUNT := 64
const PLAYER_DEFEAT_64_GRID_COLS := 8


static func has_result_state(result_context: Dictionary) -> bool:
	return (
		bool(result_context.get("boss_defeat_active", false))
		or bool(result_context.get("boss_victory_active", false))
		or bool(result_context.get("player_victory_active", false))
		or bool(result_context.get("player_defeat_active", false))
	)


static func sync_cached_result_textures(
	textures: Dictionary,
	resources: Variant,
	character_type: String,
	current_stage: int,
	result_context: Dictionary
) -> Dictionary:
	if resources == null or not resources.has_method("sync_cached_result_textures"):
		return textures
	var synced: Variant = resources.sync_cached_result_textures(character_type, current_stage, result_context)
	if synced is Dictionary:
		return synced
	return textures


static func get_boss_result_context(deps: Dictionary, current_stage: int) -> Dictionary:
	var scoreboard_state = deps.get("scoreboard_state", null)
	if scoreboard_state == null:
		return {}
	if not scoreboard_state.has_method("is_active") or not scoreboard_state.is_active():
		return {}

	var scoring_side: String = ""
	if scoreboard_state.has_method("get_last_scoring_side"):
		scoring_side = str(scoreboard_state.get_last_scoring_side())

	var player_points: int = 0
	var boss_points: int = 0
	if scoreboard_state.has_method("get_player_points"):
		player_points = int(scoreboard_state.get_player_points())
	if scoreboard_state.has_method("get_boss_points"):
		boss_points = int(scoreboard_state.get_boss_points())
	if scoring_side != "player" and scoring_side != "boss":
		if player_points > boss_points:
			scoring_side = "player"
		elif boss_points > player_points:
			scoring_side = "boss"
	if scoring_side != "player" and scoring_side != "boss":
		return {}

	var timer: float = 0.0
	if scoreboard_state.has_method("get_timer"):
		timer = max(0.0, float(scoreboard_state.get_timer()))
	var frame: int = min(BOSS_RESULT_FRAME_COUNT - 1, int(floor(timer / BOSS_RESULT_FRAME_SPEED)))
	var stage2_victory_frame: int = int(floor(timer / BOSS_STAGE2_VICTORY_FRAME_SPEED)) % BOSS_STAGE2_VICTORY_FRAME_COUNT
	var stage2_defeat_frame: int = min(BOSS_STAGE2_DEFEAT_FRAME_COUNT - 1, int(floor(timer / BOSS_STAGE2_DEFEAT_FRAME_SPEED)))
	var player_victory_frame: int = min(PLAYER_VICTORY_FRAME_COUNT - 1, int(floor(timer / PLAYER_VICTORY_FRAME_SPEED)))
	var player_defeat_frame: int = min(PLAYER_DEFEAT_FRAME_COUNT - 1, int(floor(timer / PLAYER_DEFEAT_FRAME_SPEED)))
	var player_defeat_frame_64: int = min(PLAYER_DEFEAT_64_FRAME_COUNT - 1, int(floor(timer / PLAYER_DEFEAT_64_FRAME_SPEED)))
	return {
		"boss_defeat_active": scoring_side == "player",
		"boss_victory_active": scoring_side == "boss",
		"boss_result_frame": frame,
		"boss_defeat_frame": stage2_defeat_frame if current_stage == 2 else frame,
		"boss_victory_frame": stage2_victory_frame if current_stage == 2 else frame,
		"player_victory_active": scoring_side == "player",
		"player_victory_frame": player_victory_frame,
		"player_defeat_active": scoring_side == "boss",
		"player_defeat_frame": player_defeat_frame,
		"player_defeat_frame_64": player_defeat_frame_64,
	}


static func get_player_victory_frame_count(is_blacksmith: bool) -> int:
	return BLACKSMITH_PLAYER_VICTORY_FRAME_COUNT if is_blacksmith else PLAYER_VICTORY_FRAME_COUNT


static func get_player_victory_grid_cols(is_blacksmith: bool) -> int:
	return BLACKSMITH_PLAYER_VICTORY_GRID_COLS if is_blacksmith else PLAYER_VICTORY_GRID_COLS


static func get_player_defeat_frame_count(is_blacksmith: bool, is_viper: bool) -> int:
	if is_blacksmith:
		return BLACKSMITH_PLAYER_DEFEAT_FRAME_COUNT
	if is_viper:
		return PLAYER_DEFEAT_64_FRAME_COUNT
	return PLAYER_DEFEAT_FRAME_COUNT


static func get_player_defeat_grid_cols(is_blacksmith: bool, is_viper: bool) -> int:
	if is_blacksmith:
		return BLACKSMITH_PLAYER_DEFEAT_GRID_COLS
	if is_viper:
		return PLAYER_DEFEAT_64_GRID_COLS
	return PLAYER_DEFEAT_GRID_COLS


static func get_player_defeat_frame_key(is_viper: bool) -> String:
	return "player_defeat_frame_64" if is_viper else "player_defeat_frame"
