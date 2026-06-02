extends SceneTree

const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_round_scoreboard_uses_short_hold()
	_verify_match_scoreboard_keeps_result_hold()

	if _failures.is_empty():
		print("scoreboard_state_timing_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_round_scoreboard_uses_short_hold() -> void:
	var scoreboard: Object = ScoreboardState.new()
	_expect(
		ScoreboardState.SCOREBOARD_ROUND_TOTAL_DURATION < 1.0,
		"normal round scoreboard should stay below one second"
	)
	scoreboard.start(1, 0, false, "player", 5)
	var almost_done := ScoreboardState.SCOREBOARD_ROUND_TOTAL_DURATION - 0.01
	_expect(
		int(scoreboard.update_scoreboard(almost_done)) == ScoreboardState.UPDATE_NONE,
		"normal round scoreboard should not complete before its short hold"
	)
	_expect(scoreboard.is_active(), "normal round scoreboard should remain active before short hold finishes")
	_expect(
		int(scoreboard.update_scoreboard(0.02)) == ScoreboardState.UPDATE_START_SERVE,
		"normal round scoreboard should hand off to serve as soon as the short hold finishes"
	)
	_expect(not scoreboard.is_active(), "normal round scoreboard should clear after serve handoff")


func _verify_match_scoreboard_keeps_result_hold() -> void:
	var scoreboard: Object = ScoreboardState.new()
	scoreboard.start(5, 0, true, "player", 5)
	var after_short_round_hold := ScoreboardState.SCOREBOARD_ROUND_TOTAL_DURATION + 0.05
	_expect(
		int(scoreboard.update_scoreboard(after_short_round_hold)) == ScoreboardState.UPDATE_NONE,
		"match-finished scoreboard should not use the short normal-round hold"
	)
	_expect(scoreboard.is_active(), "match-finished scoreboard should keep holding for the result handoff")
	_expect(
		int(scoreboard.update_scoreboard(ScoreboardState.SCOREBOARD_TOTAL_DURATION)) == ScoreboardState.UPDATE_RESET_GAME,
		"match-finished scoreboard should keep the full result hold before reset handoff"
	)
	_expect(not scoreboard.is_active(), "match-finished scoreboard should clear after reset handoff")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
