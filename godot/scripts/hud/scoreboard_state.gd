extends RefCounted

const UPDATE_NONE := 0
const UPDATE_START_SERVE := 1
const UPDATE_RESET_GAME := 2

const SCOREBOARD_FADE_IN_DURATION := 15.0 / 60.0
const SCOREBOARD_HOLD_DURATION := 90.0 / 60.0
const SCOREBOARD_TOTAL_DURATION := SCOREBOARD_FADE_IN_DURATION + SCOREBOARD_HOLD_DURATION
const TOP_MINI_SCORE_SPARKLE_DURATION := 1.0

var active: bool = false
var timer: float = 0.0
var animation_frame: int = 0
var player_points: int = 0
var boss_points: int = 0
var win_goal: int = 5
var pending_game_reset: bool = false
var last_scoring_side: String = ""
var top_mini_score_sparkle_timer: float = 0.0


func reset() -> void:
	active = false
	timer = 0.0
	animation_frame = 0
	player_points = 0
	boss_points = 0
	win_goal = 5
	pending_game_reset = false
	last_scoring_side = ""
	top_mini_score_sparkle_timer = 0.0


func start(
	new_player_points: int,
	new_boss_points: int,
	new_pending_game_reset: bool,
	new_last_scoring_side: String = "",
	new_win_goal: int = 5
) -> void:
	player_points = new_player_points
	boss_points = new_boss_points
	win_goal = max(1, new_win_goal)
	pending_game_reset = new_pending_game_reset
	last_scoring_side = new_last_scoring_side
	timer = 0.0
	animation_frame = 0
	active = true


func update_scoreboard(delta: float) -> int:
	if not active:
		return UPDATE_NONE

	timer += delta
	animation_frame = int(floor(timer * 60.0))
	if timer < SCOREBOARD_TOTAL_DURATION:
		return UPDATE_NONE

	var result: int = UPDATE_RESET_GAME if pending_game_reset else UPDATE_START_SERVE
	active = false
	timer = 0.0
	animation_frame = 0
	pending_game_reset = false
	return result


func trigger_top_mini_sparkle() -> void:
	top_mini_score_sparkle_timer = TOP_MINI_SCORE_SPARKLE_DURATION


func update_top_mini_sparkle(delta: float) -> void:
	top_mini_score_sparkle_timer = max(0.0, top_mini_score_sparkle_timer - delta)


func is_active() -> bool:
	return active


func get_timer() -> float:
	return timer


func get_overlay_alpha() -> float:
	return clamp(timer / max(0.001, SCOREBOARD_FADE_IN_DURATION), 0.0, 1.0)


func get_animation_frame() -> int:
	return animation_frame


func get_animation_frame_time() -> float:
	return timer * 60.0


func get_player_points() -> int:
	return player_points


func get_boss_points() -> int:
	return boss_points


func get_win_goal() -> int:
	return win_goal


func has_pending_game_reset() -> bool:
	return pending_game_reset


func get_last_scoring_side() -> String:
	return last_scoring_side


func get_top_mini_score_sparkle_timer() -> float:
	return top_mini_score_sparkle_timer
