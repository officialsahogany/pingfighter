extends SceneTree

const FrameFlowDepsBuilder := preload("res://scripts/core/battle_frame_flow_deps_builder.gd")
const BallIntensity := preload("res://scripts/ball/ball_intensity.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var current_stage := 4
	var boss_pos := Vector2(312.0, 27.0)
	var boss_paddle_width := 116.0
	var boss_hitbox_height := 44.0
	var boss_paddle_shrink_scale := 0.75
	var lingpet_puppet_grab_active := true
	var lingpet_star_coil_freeze_boss_skill_cd := true


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


class FakeActiveItemRuntime:
	extends RefCounted

	var call_count := 0

	func get_boss_ai_context() -> Dictionary:
		call_count += 1
		return {
			"active_item_tear_gas_cooldown_pause_active": true,
			"active_item_boss_skill_cooldown_paused": true,
		}


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
	_expect(not bool(stakes.get("player_can_win", true)), "6-6 should not mark player match point before the next deuce rung")
	_expect(not bool(stakes.get("boss_can_win", true)), "6-6 should not mark boss match point before the next deuce rung")

	score_state.force_score(6, 5)
	deps = builder.build_deps(owner, registry)
	stakes = ball_intensity.get_stakes()
	_expect(bool(stakes.get("player_can_win", false)), "6-5 should mark player match point in ball intensity stakes")
	_expect(not bool(stakes.get("boss_can_win", true)), "6-5 should not mark boss match point in ball intensity stakes")

	score_state.force_score(5, 6)
	deps = builder.build_deps(owner, registry)
	stakes = ball_intensity.get_stakes()
	_expect(not bool(stakes.get("player_can_win", true)), "5-6 should not mark player match point in ball intensity stakes")
	_expect(bool(stakes.get("boss_can_win", false)), "5-6 should mark boss match point in ball intensity stakes")

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

	var stage7_state := RefCounted.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	registry.instances["stage7_akamu_state"] = stage7_state
	registry.instances["active_item_runtime"] = active_item_runtime
	owner.current_stage = 7
	deps = builder.build_deps(owner, registry)
	var freeze_context: Dictionary = deps.get("stage7_akamu_freeze_context", {})
	_expect(deps.get("stage7_akamu_state") == stage7_state, "Stage 7 deps should include the Akamu owner")
	_expect(freeze_context.get("boss_pos") == owner.boss_pos, "Stage 7 freeze context should preserve live boss position")
	_expect(
		freeze_context.get("boss_paddle_size") == Vector2(owner.boss_paddle_width, owner.boss_hitbox_height),
		"Stage 7 freeze context should preserve live boss geometry"
	)
	_expect(
		is_equal_approx(float(freeze_context.get("boss_paddle_shrink_scale", 0.0)), owner.boss_paddle_shrink_scale),
		"Stage 7 freeze context should preserve the live boss visual scale"
	)
	_expect(bool(freeze_context.get("lingpet_puppet_grab_active", false)), "Stage 7 freeze context should preserve external boss motion ownership")
	_expect(bool(freeze_context.get("lingpet_star_coil_freeze_boss_skill_cd", false)), "Stage 7 freeze context should preserve Star Coil cooldown pause")
	_expect(bool(freeze_context.get("active_item_tear_gas_cooldown_pause_active", false)), "Stage 7 freeze context should preserve the tear-gas compatibility pause key")
	_expect(bool(freeze_context.get("active_item_boss_skill_cooldown_paused", false)), "Stage 7 freeze context should preserve the canonical active-item pause key")
	_expect(active_item_runtime.call_count == 1, "Stage 7 freeze context should sample active-item pause once")

	owner.current_stage = 4
	registry.requested_keys.clear()
	deps = builder.build_deps(owner, registry)
	_expect(deps.get("stage7_akamu_state") == null, "non-Stage 7 deps should not include the Akamu owner")
	_expect(deps.get("stage7_akamu_freeze_context", {}).is_empty(), "non-Stage 7 deps should keep the Akamu freeze context empty")
	_expect(not registry.requested_keys.has("stage7_akamu_state"), "non-Stage 7 deps should not cold-request the Akamu owner")
	_expect(not registry.requested_keys.has("active_item_runtime"), "non-Stage 7 deps should not sample active-item pause for the Akamu freeze path")

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
