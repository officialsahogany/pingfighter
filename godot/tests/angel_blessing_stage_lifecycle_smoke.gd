extends SceneTree

const AngelBlessingStageLifecycle := preload("res://scripts/characters/runtime_perk_angel_blessing_stage_lifecycle.gd")
const BlacksmithSkillConfig := preload("res://scripts/characters/blacksmith_skill_config.gd")
const MatchResetController := preload("res://scripts/core/match_reset_controller.gd")
const MatchRoundRestartController := preload("res://scripts/core/match_round_restart_controller.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")

const ANGEL_PERK_ID := "angel_blessing"

var _failures: Array[String] = []
var _reset_ball_calls := 0


func _init() -> void:
	_verify_owned_stage_roll_dedupes_and_survives_round_restart()
	_verify_deferred_actions_run_before_next_stage_angel_replacement()
	_verify_context_gates_and_character_capability()
	_verify_future_stage_and_full_reset_contract()

	if _failures.is_empty():
		print("angel_blessing_stage_lifecycle_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_owned_stage_roll_dedupes_and_survives_round_restart() -> void:
	var fixture: Dictionary = _build_fixture("smasher", 1, true)
	var runtime: Object = fixture["runtime"]
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var skill_config: Object = fixture["skill_config"]
	var mythic: Object = fixture["mythic"]
	var lifecycle: Object = fixture["lifecycle"]

	var first: Dictionary = lifecycle.on_ball_spawn_intro_finished(
		runtime,
		owner,
		registry,
		2,
		["paddle_size", "active_cooldown"]
	)
	_expect(bool(first.get("rolled", false)), "first owned campaign intro should roll Angel")
	_expect(int(first.get("active_stage", 0)) == 1, "first roll should bind to Stage 1")
	_expect(first.get("active_buff_ids", []) == ["paddle_size", "active_cooldown"], "forced Stage 1 roll should preserve deterministic order")
	_expect_close(runtime.get_player_paddle_size_multiplier(), 1.30, "Stage 1 paddle blessing should become live")
	_expect_close(runtime.get_player_skill_cooldown_multiplier(), 0.70, "Stage 1 skill cooldown blessing should become live")
	_expect_close(float(skill_config.get_snapshot().get("runtime_cooldown_multiplier", 1.0)), 0.70, "successful roll should immediately sync the live skill config")
	_expect_close(float(owner.get("player_paddle_width")), 201.5, "successful roll should immediately sync owner paddle width")
	_expect(mythic.refresh_calls == 1, "successful roll should refresh the single mythic gauge consumer path once")

	var revision_before_duplicate: int = int(runtime.get_angel_blessing_snapshot().get("revision", -1))
	var duplicate: Dictionary = lifecycle.on_ball_spawn_intro_finished(
		runtime,
		owner,
		registry,
		1,
		["move_speed"]
	)
	_expect(not bool(duplicate.get("rolled", true)), "duplicate same-stage intro callback must not reroll")
	_expect(str(duplicate.get("reason", "")) == "already_triggered", "duplicate callback should expose the stage-dedupe reason")
	_expect(int(runtime.get_angel_blessing_snapshot().get("revision", -2)) == revision_before_duplicate, "duplicate callback must not mutate Angel revision")
	_expect(mythic.refresh_calls == 1, "duplicate callback must not resync owner consumers")

	var round_restart := MatchRoundRestartController.new()
	round_restart.handle_round_restart("score", {}, {"reset_ball": Callable(self, "_record_reset_ball")})
	_expect(_reset_ball_calls == 1, "round restart control should still reset the ball")
	_expect(runtime.get_angel_blessing_snapshot().get("active_buff_ids", []) == ["paddle_size", "active_cooldown"], "rally restart must preserve the current stage blessing")
	_expect(int(runtime.get_angel_blessing_snapshot().get("revision", -2)) == revision_before_duplicate, "rally restart must not touch Angel revision")


func _verify_deferred_actions_run_before_next_stage_angel_replacement() -> void:
	var fixture: Dictionary = _build_fixture("smasher", 1, true)
	var runtime: Object = fixture["runtime"]
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var skill_config: Object = fixture["skill_config"]
	var mythic: Object = fixture["mythic"]
	var lifecycle: Object = fixture["lifecycle"]

	lifecycle.on_ball_spawn_intro_finished(
		runtime,
		owner,
		registry,
		2,
		["paddle_size", "active_cooldown"]
	)
	runtime.call("_queue_full_gauge_after_spawn_intro", owner, "게이지 완충 대기")
	owner.set("special_gauge", 73.0)
	owner.set("current_stage", 2)

	var combined: Dictionary = runtime.on_ball_spawn_intro_finished(
		owner,
		registry,
		{
			"forced_face": 1,
			"forced_candidate_order": ["gauge_max"],
		}
	)
	_expect(bool(combined.get("full_gauge_activated", false)), "existing deferred full-gauge result should stay top-level")
	var angel_result: Dictionary = combined.get("angel_blessing", {})
	_expect(bool(angel_result.get("rolled", false)), "Stage 2 intro should append an Angel result")
	_expect(angel_result.get("active_buff_ids", []) == ["gauge_max"], "Stage 2 roll should atomically replace the old result")
	_expect_close(mythic.last_gauge_seen_before_refresh, 500.0, "deferred full gauge must resolve before Angel gauge refresh")
	_expect_close(float(owner.get("special_gauge_max")), 650.0, "Stage 2 gauge blessing should publish the new maximum")
	_expect_close(float(owner.get("special_gauge")), 500.0, "Angel gauge replacement should preserve the deferred absolute gauge value")
	_expect_close(runtime.get_player_paddle_size_multiplier(), 1.0, "unselected old paddle lane should return to neutral")
	_expect_close(runtime.get_player_skill_cooldown_multiplier(), 1.0, "unselected old cooldown lane should return to neutral")
	_expect_close(float(skill_config.get_snapshot().get("runtime_cooldown_multiplier", 0.0)), 1.0, "Stage 2 replacement should restore the skill config multiplier")
	_expect_close(float(owner.get("player_paddle_width")), 155.0, "Stage 2 replacement should restore base paddle width")
	_expect(runtime.get_angel_blessing_snapshot().get("triggered_stages", []) == [1, 2], "stage history should retain both completed intro stages")


func _verify_context_gates_and_character_capability() -> void:
	var unowned: Dictionary = _build_fixture("smasher", 1, false)
	var unowned_result: Dictionary = unowned["runtime"].on_ball_spawn_intro_finished(unowned["owner"], unowned["registry"])
	_expect(not unowned_result.has("angel_blessing"), "unowned Angel must stay dormant at intro finish")
	_expect(int(unowned["runtime"].get_angel_blessing_snapshot().get("active_stage", -1)) == 0, "unowned intro must not mutate Angel state")

	for gate_case: Dictionary in [
		{"stage": 1, "arena": true, "label": "arena"},
		{"stage": 50, "arena": false, "label": "tutorial"},
		{"stage": 0, "arena": false, "label": "invalid stage"},
	]:
		var fixture: Dictionary = _build_fixture("smasher", int(gate_case["stage"]), true)
		fixture["owner"].set("arena_mode_enabled", bool(gate_case["arena"]))
		var result: Dictionary = fixture["runtime"].on_ball_spawn_intro_finished(fixture["owner"], fixture["registry"])
		_expect(not result.has("angel_blessing"), "%s should not run Angel lifecycle" % str(gate_case["label"]))
		_expect(int(fixture["runtime"].get_angel_blessing_snapshot().get("active_stage", -1)) == 0, "%s should leave Angel neutral" % str(gate_case["label"]))

	var optimus: Dictionary = _build_fixture("optimus", 1, true)
	var optimus_result: Dictionary = optimus["runtime"].on_ball_spawn_intro_finished(
		optimus["owner"],
		optimus["registry"],
		{
			"forced_face": 1,
			"forced_candidate_order": ["active_cooldown", "move_speed"],
		}
	)
	var optimus_angel: Dictionary = optimus_result.get("angel_blessing", {})
	_expect(optimus_angel.get("active_buff_ids", []) == ["move_speed"], "Optimus lifecycle must use normalized capability and skip dead active_cooldown")

	var blacksmith: Dictionary = _build_fixture("baltor", 1, true)
	var blacksmith_result: Dictionary = blacksmith["runtime"].on_ball_spawn_intro_finished(
		blacksmith["owner"],
		blacksmith["registry"],
		{
			"forced_face": 1,
			"forced_candidate_order": ["active_cooldown", "dash_cooldown"],
		}
	)
	var blacksmith_angel: Dictionary = blacksmith_result.get("angel_blessing", {})
	_expect(blacksmith_angel.get("active_buff_ids", []) == ["dash_cooldown"], "current Blacksmith lifecycle must skip the unported Hammer Shock cooldown")


func _verify_future_stage_and_full_reset_contract() -> void:
	var fixture: Dictionary = _build_fixture("smasher", 7, true)
	var runtime: Object = fixture["runtime"]
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var skill_config: Object = fixture["skill_config"]
	var lifecycle: Object = fixture["lifecycle"]

	var stage7: Dictionary = runtime.on_ball_spawn_intro_finished(
		owner,
		registry,
		{"forced_face": 1, "forced_candidate_order": ["move_speed"]}
	).get("angel_blessing", {})
	_expect(bool(stage7.get("rolled", false)) and int(stage7.get("active_stage", 0)) == 7, "Stage 7 should use the shared intro completion path")
	owner.set("current_stage", 9)
	var future: Dictionary = lifecycle.on_ball_spawn_intro_finished(
		runtime,
		owner,
		registry,
		1,
		["paddle_size"]
	)
	_expect(bool(future.get("rolled", false)) and int(future.get("active_stage", 0)) == 9, "future positive campaign stage ids must not be hard-capped")

	var reset_controller := MatchResetController.new()
	var reset_result: Dictionary = reset_controller.reset_game(
		{
			"runtime_perk_state": runtime,
			"skill_states": [],
			"skill_configs": [skill_config],
			"skill_runtimes": [],
			"starting_dash_tokens": 1,
		},
		{}
	)
	var reset_snapshot: Dictionary = runtime.get_angel_blessing_snapshot()
	_expect(int(reset_snapshot.get("active_stage", -1)) == 0, "full reset should clear Angel active stage")
	_expect((reset_snapshot.get("active_buff_ids", []) as Array).is_empty(), "full reset should clear active blessings")
	_expect((reset_snapshot.get("triggered_stages", []) as Array).is_empty(), "full reset should clear stage dedupe history")
	_expect(not runtime.runtime_skill_levels.has(ANGEL_PERK_ID), "full reset should clear Angel ownership level")
	_expect_close(float(skill_config.get_snapshot().get("runtime_cooldown_multiplier", 0.0)), 1.0, "full reset should restore neutral skill config multiplier")
	_expect_close(float(reset_result.get("special_gauge_max", 0.0)), 500.0, "full reset result should restore base gauge maximum")


func _build_fixture(character_type: String, stage: int, owned: bool) -> Dictionary:
	var runtime: Object = RuntimePerkState.new()
	if owned:
		runtime.runtime_skill_levels[ANGEL_PERK_ID] = 1
	var owner := FakeOwner.new({
		"selected_character_type": character_type,
		"current_stage": stage,
		"arena_mode_enabled": false,
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"player_paddle_scale": 1.0,
		"runtime_paddle_base_width": 155.0,
		"runtime_paddle_base_height": 50.0,
		"runtime_paddle_scale": 1.0,
		"special_gauge": 0.0,
		"special_gauge_max": 500.0,
	})
	var skill_config: Object = BlacksmithSkillConfig.new() if character_type in ["blacksmith", "baltor", "kohaku"] else SmasherSkillConfig.new()
	var skill_state: Object = SmasherSkillState.new()
	var mythic := FakeMythicRuntime.new()
	var instances := {
		"runtime_perk_state": runtime,
		"mythic_item_runtime": mythic,
	}
	if character_type in ["blacksmith", "baltor", "kohaku"]:
		instances["blacksmith_skill_config"] = skill_config
		instances["blacksmith_skill_state"] = skill_state
	elif character_type not in ["optimus", "io"]:
		instances["smasher_skill_config"] = skill_config
		instances["smasher_skill_state"] = skill_state
	var registry := FakeRegistry.new(instances)
	return {
		"runtime": runtime,
		"owner": owner,
		"registry": registry,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"mythic": mythic,
		"lifecycle": AngelBlessingStageLifecycle.new(),
	}


func _record_reset_ball() -> void:
	_reset_ball_calls += 1


func _expect_close(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (expected %.6f, got %.6f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeOwner:
	extends RefCounted

	var values: Dictionary

	func _init(source: Dictionary) -> void:
		values = source.duplicate(true)

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(source: Dictionary) -> void:
		instances = source

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeMythicRuntime:
	extends RefCounted

	var refresh_calls := 0
	var last_gauge_seen_before_refresh := -1.0

	func refresh_runtime_perk_scaling(owner: Object = null, registry: Object = null) -> void:
		refresh_calls += 1
		if owner == null or registry == null:
			return
		last_gauge_seen_before_refresh = float(owner.get("special_gauge"))
		var runtime: Object = registry.get_instance("runtime_perk_state")
		if runtime == null:
			return
		var next_max: float = float(runtime.get_angel_blessing_special_gauge_max(500.0))
		owner.set("special_gauge_max", next_max)
		owner.set("special_gauge", minf(float(owner.get("special_gauge")), next_max))
