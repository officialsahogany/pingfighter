extends RefCounted

const MatchScoreEventController := preload("res://scripts/core/match_score_event_controller.gd")
const MatchScoreboardFlowController := preload("res://scripts/core/match_scoreboard_flow_controller.gd")
const MatchRoundRestartController := preload("res://scripts/core/match_round_restart_controller.gd")
const MatchResetController := preload("res://scripts/core/match_reset_controller.gd")

var _fallback_score_event_controller: Object = MatchScoreEventController.new()
var _fallback_scoreboard_flow_controller: Object = MatchScoreboardFlowController.new()
var _fallback_round_restart_controller: Object = MatchRoundRestartController.new()
var _fallback_reset_controller: Object = MatchResetController.new()


func handle_score_event(scoring_side: String, deps: Dictionary, callbacks: Dictionary) -> void:
	var controller: Object = _get_controller(deps, "match_score_event_controller", _fallback_score_event_controller)
	controller.handle_score_event(scoring_side, deps, callbacks)


func handle_round_restart(reason: String, deps: Dictionary, callbacks: Dictionary) -> void:
	var controller: Object = _get_controller(deps, "match_round_restart_controller", _fallback_round_restart_controller)
	controller.handle_round_restart(reason, deps, callbacks)


func update_scoreboard(delta: float, deps: Dictionary, callbacks: Dictionary, config: Dictionary) -> void:
	var controller: Object = _get_controller(deps, "match_scoreboard_flow_controller", _fallback_scoreboard_flow_controller)
	controller.update_scoreboard(delta, deps, callbacks, config)


func reset_game(deps: Dictionary, callbacks: Dictionary) -> Dictionary:
	var controller: Object = _get_controller(deps, "match_reset_controller", _fallback_reset_controller)
	return controller.reset_game(deps, callbacks)


func reset_for_stage_transition(deps: Dictionary, callbacks: Dictionary) -> Dictionary:
	var controller: Object = _get_controller(deps, "match_reset_controller", _fallback_reset_controller)
	if controller.has_method("reset_for_stage_transition"):
		return controller.reset_for_stage_transition(deps, callbacks)
	return controller.reset_game(deps, callbacks)


func _get_controller(deps: Dictionary, key: String, fallback: Object) -> Object:
	var controller: Variant = deps.get(key, null)
	if typeof(controller) == TYPE_OBJECT and controller != null:
		return controller
	return fallback
