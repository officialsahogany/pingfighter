extends SceneTree

const FrameFlowDepsBuilder := preload("res://scripts/core/battle_frame_flow_deps_builder.gd")
const BallIntensity := preload("res://scripts/ball/ball_intensity.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var current_stage := 4


class FakeHoverState:
	extends RefCounted

	var hover_result: Dictionary = {"skill_name": "power_smashing"}
	var call_count := 0

	func update_hover_state(_owner: Object, _registry: Object) -> Dictionary:
		call_count += 1
		return hover_result


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary
	var requested_keys: Array[String] = []

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return instances.get(key, null)


func _init() -> void:
	var builder: Object = FrameFlowDepsBuilder.new()
	var owner := FakeOwner.new()
	var scoreboard := RefCounted.new()
	var power_state := RefCounted.new()
	var round_state := RefCounted.new()
	var serve_flow := RefCounted.new()
	var hover_state := FakeHoverState.new()
	var ball_intensity := BallIntensity.new()
	var score_state := MatchScoreState.new()
	score_state.force_score(6, 6)
	var registry := FakeRegistry.new({
		"scoreboard_state": scoreboard,
		"smasher_power_smash_state": power_state,
		"round_flow_state": round_state,
		"serve_flow_controller": serve_flow,
		"skill_orb_tooltip_hover_state": hover_state,
		"ball_intensity": ball_intensity,
		"match_score_state": score_state,
	})

	owner.selected_character_type = " Smasher "
	var deps: Dictionary = builder.build_deps(owner, registry)
	_expect(deps.get("scoreboard_state") == scoreboard, "deps should include scoreboard state")
	_expect(deps.get("power_state") == power_state, "smasher deps should include power smash state after character normalization")
	_expect(deps.get("round_state") == round_state, "deps should include round flow state")
	_expect(deps.get("serve_flow_controller") == serve_flow, "deps should include serve flow controller")
	_expect(int(deps.get("serve_context", {}).get("current_stage", 0)) == 4, "serve context should include current stage")
	_expect(bool(deps.get("skill_orb_tooltip_active", false)), "tooltip hover should mark tooltip active")
	_expect(str(deps.get("skill_orb_tooltip_key", "")) == "power_smashing", "tooltip key should come from hover state")
	_expect(hover_state.call_count == 1, "hover state should update once")
	var stakes: Dictionary = ball_intensity.get_stakes()
	_expect(bool(stakes.get("deuce_mode", false)), "frame deps should sync deuce stakes into ball intensity")
	_expect(bool(stakes.get("player_can_win", false)), "6-6 should mark player match point in ball intensity stakes")
	_expect(bool(stakes.get("boss_can_win", false)), "6-6 should mark boss match point in ball intensity stakes")

	owner.selected_character_type = "viper"
	hover_state.hover_result = {}
	score_state.force_score(2, 1)
	deps = builder.build_deps(owner, registry)
	_expect(deps.get("power_state") == null, "non-smasher deps should not include power smash state")
	_expect(not bool(deps.get("skill_orb_tooltip_active", true)), "empty hover state should mark tooltip inactive")
	_expect(str(deps.get("skill_orb_tooltip_key", "x")) == "", "empty hover state should clear tooltip key")
	stakes = ball_intensity.get_stakes()
	_expect(not bool(stakes.get("deuce_mode", true)), "frame deps should clear deuce stakes when score leaves deuce")
	_expect(not bool(stakes.get("player_can_win", true)), "frame deps should clear player match point when score leaves match point")
	_expect(not bool(stakes.get("boss_can_win", true)), "frame deps should clear boss match point when score leaves match point")

	owner.selected_character_type = " IO "
	deps = builder.build_deps(owner, registry)
	_expect(deps.get("power_state") == null, "Optimus aliases should not include Smasher power smash state")

	var missing_score_intensity := BallIntensity.new()
	var missing_score_registry := FakeRegistry.new({
		"ball_intensity": missing_score_intensity,
	})
	missing_score_intensity.set_stakes(true, true, true)
	builder.build_deps(owner, missing_score_registry)
	stakes = missing_score_intensity.get_stakes()
	_expect(not bool(stakes.get("deuce_mode", true)), "missing score state should clear stale deuce stakes")
	_expect(not bool(stakes.get("player_can_win", true)), "missing score state should clear stale player stakes")
	_expect(not bool(stakes.get("boss_can_win", true)), "missing score state should clear stale boss stakes")

	if _failures.is_empty():
		print("frame_flow_deps_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
