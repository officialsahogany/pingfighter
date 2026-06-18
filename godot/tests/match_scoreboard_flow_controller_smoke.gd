extends SceneTree

const MatchFlowController := preload("res://scripts/core/match_flow_controller.gd")

var _failures: Array[String] = []
var _reset_game_calls := 0
var _reset_ball_calls := 0
var _resolve_defeat_calls := 0
var _resolve_defeat_result := false


class FakeScoreboardState:
	extends RefCounted

	var result := 0
	var last_delta := 0.0

	func _init(next_result: int) -> void:
		result = next_result

	func update_scoreboard(delta: float) -> int:
		last_delta = delta
		return result


class FakeRoundState:
	extends RefCounted

	var prepare_calls := 0

	func prepare_serve_after_scoreboard() -> void:
		prepare_calls += 1


func _init() -> void:
	var controller: Object = MatchFlowController.new()
	var config := {
		"update_reset_game": 2,
		"update_start_serve": 1,
	}

	var reset_scoreboard := FakeScoreboardState.new(2)
	controller.update_scoreboard(0.35, {
		"scoreboard_state": reset_scoreboard,
	}, {
		"resolve_match_defeat": Callable(self, "_record_resolve_defeat"),
		"reset_game": Callable(self, "_record_reset_game"),
		"reset_ball": Callable(self, "_record_reset_ball"),
	}, config)
	_expect(abs(reset_scoreboard.last_delta - 0.35) <= 0.001, "scoreboard should receive delta")
	_expect(_resolve_defeat_calls == 1, "reset-game result should ask the defeat resolver first")
	_expect(_reset_game_calls == 1 and _reset_ball_calls == 0, "reset-game result should only call reset game")

	_resolve_defeat_result = true
	var continue_scoreboard := FakeScoreboardState.new(2)
	controller.update_scoreboard(0.35, {
		"scoreboard_state": continue_scoreboard,
	}, {
		"resolve_match_defeat": Callable(self, "_record_resolve_defeat"),
		"reset_game": Callable(self, "_record_reset_game"),
		"reset_ball": Callable(self, "_record_reset_ball"),
	}, config)
	_expect(_resolve_defeat_calls == 2, "continue result should still run the defeat resolver")
	_expect(_reset_game_calls == 1 and _reset_ball_calls == 0, "resolved defeat should skip full reset and serve callbacks")
	_resolve_defeat_result = false

	var serve_scoreboard := FakeScoreboardState.new(1)
	var round_state := FakeRoundState.new()
	controller.update_scoreboard(0.5, {
		"scoreboard_state": serve_scoreboard,
		"round_state": round_state,
	}, {
		"reset_game": Callable(self, "_record_reset_game"),
		"reset_ball": Callable(self, "_record_reset_ball"),
	}, config)
	_expect(_reset_game_calls == 1 and _reset_ball_calls == 1, "start-serve result should reset ball")
	_expect(round_state.prepare_calls == 1, "start-serve result should prepare round serve")

	var none_scoreboard := FakeScoreboardState.new(0)
	controller.update_scoreboard(0.125, {
		"scoreboard_state": none_scoreboard,
	}, {
		"reset_game": Callable(self, "_record_reset_game"),
		"reset_ball": Callable(self, "_record_reset_ball"),
	}, config)
	_expect(_reset_game_calls == 1 and _reset_ball_calls == 1, "no-op result should not call callbacks")

	controller.update_scoreboard(1.0, {}, {
		"reset_game": Callable(self, "_record_reset_game"),
		"reset_ball": Callable(self, "_record_reset_ball"),
	}, config)
	_expect(_reset_game_calls == 1 and _reset_ball_calls == 1, "missing scoreboard should be a no-op")

	if _failures.is_empty():
		print("match_scoreboard_flow_controller_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _record_reset_game() -> void:
	_reset_game_calls += 1


func _record_reset_ball() -> void:
	_reset_ball_calls += 1


func _record_resolve_defeat() -> bool:
	_resolve_defeat_calls += 1
	return _resolve_defeat_result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
