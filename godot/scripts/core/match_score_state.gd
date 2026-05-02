extends RefCounted

const WIN_GOAL := 5
const DEUCE_TRIGGER := 4
const DEUCE_GOAL_1 := 6
const DEUCE_GOAL_2 := 7
const SIDE_PLAYER := "player"
const SIDE_BOSS := "boss"

var player_score := 0
var boss_score := 0
var deuce_mode := false
var deuce_goal := DEUCE_GOAL_1


func reset() -> void:
	player_score = 0
	boss_score = 0
	deuce_mode = false
	deuce_goal = DEUCE_GOAL_1


func player_scored() -> Dictionary:
	return score_for(SIDE_PLAYER)


func boss_scored() -> Dictionary:
	return score_for(SIDE_BOSS)


func score_for(scoring_side: String) -> Dictionary:
	if scoring_side == SIDE_PLAYER:
		player_score += 1
	elif scoring_side == SIDE_BOSS:
		boss_score += 1
	var match_finished := _update_deuce_score_state() if deuce_mode else _update_normal_score_state()
	var result: Dictionary = _score_result(match_finished)
	result["next_player_serves"] = scoring_side == SIDE_BOSS
	return result


func get_snapshot() -> Dictionary:
	return {
		"player_score": player_score,
		"boss_score": boss_score,
		"deuce_mode": deuce_mode,
		"deuce_goal": deuce_goal,
		"win_goal": WIN_GOAL,
	}


func get_win_goal() -> int:
	return WIN_GOAL


func _score_result(match_finished: bool) -> Dictionary:
	return {
		"player_score": player_score,
		"boss_score": boss_score,
		"deuce_mode": deuce_mode,
		"deuce_goal": deuce_goal,
		"match_finished": match_finished,
	}


func _update_normal_score_state() -> bool:
	if player_score >= WIN_GOAL or boss_score >= WIN_GOAL:
		return true
	if player_score == DEUCE_TRIGGER and boss_score == DEUCE_TRIGGER:
		deuce_mode = true
		deuce_goal = DEUCE_GOAL_1
	return false


func _update_deuce_score_state() -> bool:
	if player_score == 5 and boss_score == 5:
		deuce_goal = DEUCE_GOAL_2
	return player_score >= deuce_goal or boss_score >= deuce_goal
