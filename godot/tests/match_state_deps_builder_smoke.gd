extends SceneTree

const MatchStateDepsBuilder := preload("res://scripts/core/battle_update_match_state_deps_builder.gd")
const BattleUpdateMatchFlowContext := preload("res://scripts/core/battle_update_match_flow_context.gd")
const BattleUpdateMatchFlowDepsGroups := preload("res://scripts/core/battle_update_match_flow_deps_groups.gd")

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init() -> void:
		for key in [
			"match_score_state",
			"round_flow_state",
			"scoreboard_state",
			"game_audio",
			"match_score_event_controller",
			"match_scoreboard_flow_controller",
			"match_round_restart_controller",
			"match_reset_controller",
		]:
			instances[key] = RefCounted.new()

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	var registry := FakeRegistry.new()
	var builder: Object = MatchStateDepsBuilder.new()

	_verify_match_state_deps(builder.build_deps(registry), registry, "direct builder")
	_verify_match_state_deps(BattleUpdateMatchFlowDepsGroups.new().build_match_state_deps(registry), registry, "deps groups facade")

	var match_flow_deps: Dictionary = BattleUpdateMatchFlowContext.new().build_deps(registry)
	_verify_match_state_deps(match_flow_deps, registry, "match flow context facade")

	var null_deps: Dictionary = builder.build_deps(null)
	for key in [
		"score_state",
		"round_state",
		"scoreboard_state",
		"audio",
		"match_score_event_controller",
		"match_scoreboard_flow_controller",
		"match_round_restart_controller",
		"match_reset_controller",
	]:
		_expect(null_deps.get(key, RefCounted.new()) == null, "null registry should produce null %s" % key)

	if _failures.is_empty():
		print("match_state_deps_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_match_state_deps(deps: Dictionary, registry: FakeRegistry, source: String) -> void:
	_expect(deps.get("score_state", null) == registry.instances["match_score_state"], "%s should include score state" % source)
	_expect(deps.get("round_state", null) == registry.instances["round_flow_state"], "%s should include round state" % source)
	_expect(deps.get("scoreboard_state", null) == registry.instances["scoreboard_state"], "%s should include scoreboard state" % source)
	_expect(deps.get("audio", null) == registry.instances["game_audio"], "%s should include game audio" % source)
	_expect(deps.get("match_score_event_controller", null) == registry.instances["match_score_event_controller"], "%s should include score event controller" % source)
	_expect(deps.get("match_scoreboard_flow_controller", null) == registry.instances["match_scoreboard_flow_controller"], "%s should include scoreboard flow controller" % source)
	_expect(deps.get("match_round_restart_controller", null) == registry.instances["match_round_restart_controller"], "%s should include round restart controller" % source)
	_expect(deps.get("match_reset_controller", null) == registry.instances["match_reset_controller"], "%s should include reset controller" % source)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
