extends RefCounted

# 2026-07-31 점수 룰 개편: 5점제 -> 7점제.
# 환격전은 랠리 템포가 원본 핑파이터보다 크게 빨라져 5점제 매치가 너무 짧게
# 끝났다. 정규 승리는 7점, 듀스는 6:6부터 발동한다.
#
# 듀스 사다리 = "동점이 될 때마다 목표 점수 +1", DEUCE_GOAL_MAX에서 정지:
#   6:6 -> 8   7:7 -> 9   8:8 -> 10   9:9 -> 서든데스(목표 10 유지)
# 즉 목표는 항상 clampi(직전 동점 + 2, BASE, MAX)이며, 구 5점제 사다리
# (4:4 -> 6, 5:5 -> 7)도 같은 공식의 특수해다. 규칙이 한 벌뿐이라는 것이
# 이 파일의 계약이고, 사다리를 다른 모듈에서 재구현하면 두 벌로 갈린다.
# (실제로 match_score_event_controller 폴백에 5/7 리터럴 사본이 있었다.)
const WIN_GOAL := 7
const DEUCE_TRIGGER := 6
const DEUCE_GOAL_STEP := 2
const DEUCE_GOAL_MAX := 10
const DEUCE_GOAL_BASE := DEUCE_TRIGGER + DEUCE_GOAL_STEP
const SIDE_PLAYER := "player"
const SIDE_BOSS := "boss"

var player_score := 0
var boss_score := 0
var deuce_mode := false
var deuce_goal := DEUCE_GOAL_BASE


static func resolve_deuce_goal(tied_score: int) -> int:
	# 사다리 정본. static인 이유는 스냅샷만 가진 폴백 경로(이벤트 컨트롤러)도
	# 사본을 만들지 않고 같은 공식을 부르게 하기 위해서다.
	return clampi(tied_score + DEUCE_GOAL_STEP, DEUCE_GOAL_BASE, DEUCE_GOAL_MAX)


func reset() -> void:
	player_score = 0
	boss_score = 0
	deuce_mode = false
	deuce_goal = DEUCE_GOAL_BASE


func force_score(new_player_score: int, new_boss_score: int) -> Dictionary:
	player_score = max(0, new_player_score)
	boss_score = max(0, new_boss_score)
	deuce_mode = player_score >= DEUCE_TRIGGER and boss_score >= DEUCE_TRIGGER
	# 강제 주입은 사다리를 밟아 오지 않으므로 이미 지나온 최고 동점
	# (= 두 점수의 min)에서 목표를 역산한다.
	deuce_goal = (
		resolve_deuce_goal(mini(player_score, boss_score))
		if deuce_mode
		else DEUCE_GOAL_BASE
	)
	return _score_result(_is_match_finished())


func player_scored() -> Dictionary:
	return score_for(SIDE_PLAYER)


func boss_scored() -> Dictionary:
	return score_for(SIDE_BOSS)


func would_score_finish(scoring_side: String) -> bool:
	var next_player_score := player_score + (1 if scoring_side == SIDE_PLAYER else 0)
	var next_boss_score := boss_score + (1 if scoring_side == SIDE_BOSS else 0)
	if deuce_mode:
		var next_deuce_goal := deuce_goal
		if next_player_score == next_boss_score:
			next_deuce_goal = maxi(deuce_goal, resolve_deuce_goal(next_player_score))
		return next_player_score >= next_deuce_goal or next_boss_score >= next_deuce_goal
	return next_player_score >= WIN_GOAL or next_boss_score >= WIN_GOAL


func score_for(scoring_side: String) -> Dictionary:
	if scoring_side == SIDE_PLAYER:
		player_score += 1
	elif scoring_side == SIDE_BOSS:
		boss_score += 1
	var match_finished := _update_deuce_score_state() if deuce_mode else _update_normal_score_state()
	var result: Dictionary = _score_result(match_finished)
	result["next_player_serves"] = scoring_side == SIDE_BOSS
	return result


func is_player_in_danger() -> bool:
	# True when the boss scoring the next point would finish the match -- i.e.
	# the player is at match point against. Drives the player danger state-glow.
	# Reuses would_score_finish so deuce / deuce-goal escalation stays in one
	# place instead of being re-derived by the renderer.
	return would_score_finish(SIDE_BOSS)


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
		"win_goal": WIN_GOAL,
		"match_finished": match_finished,
	}


func _update_normal_score_state() -> bool:
	if player_score >= WIN_GOAL or boss_score >= WIN_GOAL:
		return true
	if player_score == DEUCE_TRIGGER and boss_score == DEUCE_TRIGGER:
		deuce_mode = true
		deuce_goal = resolve_deuce_goal(DEUCE_TRIGGER)
	return false


func _update_deuce_score_state() -> bool:
	# 동점이 될 때마다 한 계단 올린다. maxi로 감싸 목표가 역행하지 않게 한다.
	if player_score == boss_score:
		deuce_goal = maxi(deuce_goal, resolve_deuce_goal(player_score))
	return player_score >= deuce_goal or boss_score >= deuce_goal


func _is_match_finished() -> bool:
	if deuce_mode:
		return player_score >= deuce_goal or boss_score >= deuce_goal
	return player_score >= WIN_GOAL or boss_score >= WIN_GOAL
