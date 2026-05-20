extends SceneTree

const MatchFlowController := preload("res://scripts/core/match_flow_controller.gd")

var _failures: Array[String] = []


class FakeScoreEventController:
	extends RefCounted

	var calls := 0
	var side := ""

	func handle_score_event(scoring_side: String, _deps: Dictionary, _callbacks: Dictionary) -> void:
		calls += 1
		side = scoring_side


class FakeRoundRestartController:
	extends RefCounted

	var calls := 0
	var reason := ""

	func handle_round_restart(next_reason: String, _deps: Dictionary, _callbacks: Dictionary) -> void:
		calls += 1
		reason = next_reason


class FakeScoreboardFlowController:
	extends RefCounted

	var calls := 0
	var delta := 0.0

	func update_scoreboard(next_delta: float, _deps: Dictionary, _callbacks: Dictionary, _config: Dictionary) -> void:
		calls += 1
		delta = next_delta


class FakeResetController:
	extends RefCounted

	var calls := 0

	func reset_game(_deps: Dictionary, _callbacks: Dictionary) -> Dictionary:
		calls += 1
		return {"injected_reset": true}


func _init() -> void:
	var controller: Object = MatchFlowController.new()
	var score_event := FakeScoreEventController.new()
	var round_restart := FakeRoundRestartController.new()
	var scoreboard_flow := FakeScoreboardFlowController.new()
	var reset := FakeResetController.new()
	var deps := {
		"match_score_event_controller": score_event,
		"match_round_restart_controller": round_restart,
		"match_scoreboard_flow_controller": scoreboard_flow,
		"match_reset_controller": reset,
	}

	controller.handle_score_event("player", deps, {})
	controller.handle_round_restart("rematch", deps, {})
	controller.update_scoreboard(0.25, deps, {}, {})
	var result: Dictionary = controller.reset_game(deps, {})

	_expect(score_event.calls == 1 and score_event.side == "player", "score event should use injected controller")
	_expect(round_restart.calls == 1 and round_restart.reason == "rematch", "round restart should use injected controller")
	_expect(scoreboard_flow.calls == 1 and abs(scoreboard_flow.delta - 0.25) <= 0.001, "scoreboard flow should use injected controller")
	_expect(reset.calls == 1 and bool(result.get("injected_reset", false)), "reset should use injected controller")

	var fallback_result: Dictionary = controller.reset_game({}, {})
	_expect(not bool(fallback_result.get("injected_reset", false)), "missing injected controller should use fallback reset controller")

	if _failures.is_empty():
		print("match_flow_controller_deps_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
