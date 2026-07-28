extends RefCounted

const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")

const BOSS_RESULT_FRAME_SPEED := 0.18
const BOSS_RESULT_FRAME_COUNT := 8
# 최종 승리(매치 종료) 스코어보드 구간은 보스 defeat 시트 대신 "힘을 잃는" 고속
# 진동 비트를 재생한다 — 패배 라투디는 승리 전리품 페이즈 인트로에서 0프레임부터
# 이어진다. 라운드 승리(비종료) 스코어보드는 기존 defeat 반응을 유지한다.
const BOSS_POWER_LOSS_SHAKE_AMPLITUDE_PX := 4.2
const BOSS_POWER_LOSS_SHAKE_FREQUENCY := 92.0
const BOSS_POWER_LOSS_SETTLE_START_RATIO := 0.82
const BOSS_STAGE2_VICTORY_FRAME_SPEED := 0.040
const BOSS_STAGE2_VICTORY_FRAME_COUNT := 64
const BOSS_STAGE2_DEFEAT_FRAME_SPEED := 0.025
const BOSS_STAGE2_DEFEAT_FRAME_COUNT := 64
const PLAYER_VICTORY_FRAME_SPEED := 0.020
const PLAYER_VICTORY_FRAME_COUNT := 64
const PLAYER_VICTORY_GRID_COLS := 8
const PLAYER_VICTORY_8_FRAME_SPEED := 0.09
const PLAYER_VICTORY_8_FRAME_COUNT := 8
const PLAYER_VICTORY_8_GRID_COLS := 4
const BLACKSMITH_PLAYER_VICTORY_FRAME_COUNT := 49
const BLACKSMITH_PLAYER_VICTORY_GRID_COLS := 7
# 한미량(스매셔) 승리 라투디: AutoSprite 생성 상한이 49프레임(7x7)이라
# 구 64f/8열 계약에서 49f/7열로 이관 (2026-07-23).
const SMASHER_PLAYER_VICTORY_FRAME_COUNT := 49
const SMASHER_PLAYER_VICTORY_GRID_COLS := 7
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

	var pending_game_reset: bool = (
		scoreboard_state.has_method("has_pending_game_reset")
		and bool(scoreboard_state.has_pending_game_reset())
	)
	if pending_game_reset and scoring_side == "player":
		# 최종 승리: 보스는 defeat 대신 고속 진동(파워로스)으로 버티다가, 전리품
		# 인트로에서 힘을 잃고 패배 라투디로 무너진다. 진동은 페이드인 이후
		# 시작하고 구간 말미에 잦아든다(다음 비트의 슬럼프로 자연 연결).
		var shake_elapsed: float = maxf(0.0, timer - ScoreboardState.SCOREBOARD_FADE_IN_DURATION)
		var total_ratio: float = clampf(timer / maxf(0.001, ScoreboardState.SCOREBOARD_TOTAL_DURATION), 0.0, 1.0)
		var settle: float = 1.0 - smoothstep(BOSS_POWER_LOSS_SETTLE_START_RATIO, 1.0, total_ratio)
		var shake_amp: float = BOSS_POWER_LOSS_SHAKE_AMPLITUDE_PX * settle
		var shake_offset := Vector2.ZERO
		if shake_elapsed > 0.0:
			shake_offset = Vector2(
				sin(shake_elapsed * BOSS_POWER_LOSS_SHAKE_FREQUENCY) * shake_amp,
				cos(shake_elapsed * BOSS_POWER_LOSS_SHAKE_FREQUENCY * 1.31) * shake_amp * 0.35
			)
		var power_loss_player_victory_frame: int = min(PLAYER_VICTORY_FRAME_COUNT - 1, int(floor(timer / PLAYER_VICTORY_FRAME_SPEED)))
		var power_loss_player_victory_frame_8: int = min(PLAYER_VICTORY_8_FRAME_COUNT - 1, int(floor(timer / PLAYER_VICTORY_8_FRAME_SPEED)))
		return {
			"boss_power_loss_shake_active": true,
			"boss_power_loss_shake_offset": shake_offset,
			"player_victory_active": true,
			"player_victory_frame": power_loss_player_victory_frame,
			"player_victory_frame_8": power_loss_player_victory_frame_8,
		}

	var frame: int = min(BOSS_RESULT_FRAME_COUNT - 1, int(floor(timer / BOSS_RESULT_FRAME_SPEED)))
	var stage2_victory_frame: int = int(floor(timer / BOSS_STAGE2_VICTORY_FRAME_SPEED)) % BOSS_STAGE2_VICTORY_FRAME_COUNT
	var stage2_defeat_frame: int = min(BOSS_STAGE2_DEFEAT_FRAME_COUNT - 1, int(floor(timer / BOSS_STAGE2_DEFEAT_FRAME_SPEED)))
	var player_victory_frame: int = min(PLAYER_VICTORY_FRAME_COUNT - 1, int(floor(timer / PLAYER_VICTORY_FRAME_SPEED)))
	var player_victory_frame_8: int = min(PLAYER_VICTORY_8_FRAME_COUNT - 1, int(floor(timer / PLAYER_VICTORY_8_FRAME_SPEED)))
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
		"player_victory_frame_8": player_victory_frame_8,
		"player_defeat_active": scoring_side == "boss",
		"player_defeat_frame": player_defeat_frame,
		"player_defeat_frame_64": player_defeat_frame_64,
	}


static func get_player_victory_frame_count(is_blacksmith: bool, is_commando: bool, is_smasher: bool = false) -> int:
	if is_blacksmith:
		return BLACKSMITH_PLAYER_VICTORY_FRAME_COUNT
	if is_commando:
		return PLAYER_VICTORY_8_FRAME_COUNT
	if is_smasher:
		return SMASHER_PLAYER_VICTORY_FRAME_COUNT
	return PLAYER_VICTORY_FRAME_COUNT


static func get_player_victory_grid_cols(is_blacksmith: bool, is_commando: bool, is_smasher: bool = false) -> int:
	if is_blacksmith:
		return BLACKSMITH_PLAYER_VICTORY_GRID_COLS
	if is_commando:
		return PLAYER_VICTORY_8_GRID_COLS
	if is_smasher:
		return SMASHER_PLAYER_VICTORY_GRID_COLS
	return PLAYER_VICTORY_GRID_COLS


static func get_player_victory_frame_key(is_commando: bool) -> String:
	return "player_victory_frame_8" if is_commando else "player_victory_frame"


static func get_player_victory_frame_speed(is_commando: bool) -> float:
	return PLAYER_VICTORY_8_FRAME_SPEED if is_commando else PLAYER_VICTORY_FRAME_SPEED


static func get_player_defeat_frame_count(is_blacksmith: bool, is_viper: bool, is_commando: bool) -> int:
	if is_blacksmith:
		return BLACKSMITH_PLAYER_DEFEAT_FRAME_COUNT
	if is_viper:
		return PLAYER_DEFEAT_64_FRAME_COUNT
	if is_commando:
		return PLAYER_VICTORY_8_FRAME_COUNT
	return PLAYER_DEFEAT_FRAME_COUNT


static func get_player_defeat_grid_cols(is_blacksmith: bool, is_viper: bool, is_commando: bool) -> int:
	if is_blacksmith:
		return BLACKSMITH_PLAYER_DEFEAT_GRID_COLS
	if is_viper:
		return PLAYER_DEFEAT_64_GRID_COLS
	if is_commando:
		return PLAYER_VICTORY_8_GRID_COLS
	return PLAYER_DEFEAT_GRID_COLS


static func get_player_defeat_frame_key(is_viper: bool) -> String:
	return "player_defeat_frame_64" if is_viper else "player_defeat_frame"
