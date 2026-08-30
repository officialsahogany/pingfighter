extends SceneTree

const MatchEventDriver := preload("res://scripts/core/battle_scene_match_event_driver.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {
		"current_stage": 11,
		"boss_max_health": 15,
		"boss_current_health": 2,
		"boss_health_damage_units": 13,
		"boss_defeated_by_health": true,
		"special_gauge": 0.0,
		"special_gauge_max": 640.0,
	}

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true


class FakeItemDriver:
	extends RefCounted

	var restore_calls := 0

	func restore_pending_throw_item_on_round_end(_owner: Object, _registry: Object) -> void:
		restore_calls += 1


class FakeBallDriver:
	extends RefCounted

	var reset_calls := 0
	var drive_reset_calls := 0

	func reset_ball(_owner: Object, _registry: Object) -> void:
		reset_calls += 1

	func reset_drive_input_frames(_registry: Object) -> void:
		drive_reset_calls += 1


class FakeBossHealthFlow:
	extends RefCounted

	var reset_calls := 0

	func reset_round_health(owner: Object) -> void:
		reset_calls += 1
		owner.set("boss_current_health", owner.get("boss_max_health"))
		owner.set("boss_health_damage_units", 0)
		owner.set("boss_defeated_by_health", false)


class FakeMatchFlowDriver:
	extends RefCounted

	var score_side := ""
	var score_stage := 0
	var restart_reason := ""
	var scoreboard_delta := 0.0
	var reset_game_calls := 0
	var saw_scoreboard_drive_reset_callback := false

	func handle_score_event(_registry: Object, scoring_side: String, reset_ball_callback: Callable, current_stage: int = 1) -> void:
		score_side = scoring_side
		score_stage = current_stage
		reset_ball_callback.call()

	func handle_round_restart(_registry: Object, reason: String, reset_ball_callback: Callable) -> void:
		restart_reason = reason
		reset_ball_callback.call()

	func update_scoreboard(
		_registry: Object,
		delta: float,
		reset_game_callback: Callable,
		reset_ball_callback: Callable,
		_owner: Object = null,
		reset_drive_input_callback: Callable = Callable()
	) -> void:
		scoreboard_delta = delta
		saw_scoreboard_drive_reset_callback = reset_drive_input_callback.is_valid()
		reset_game_callback.call()
		reset_ball_callback.call()

	func reset_game(_owner: Object, _registry: Object, reset_drive_input_callback: Callable, reset_ball_callback: Callable) -> void:
		reset_game_calls += 1
		reset_drive_input_callback.call()
		reset_ball_callback.call()


class FakeTowerFlow:
	extends RefCounted

	var match_flow: Object
	var pending := true
	var consume_invocations := 0
	var applied_calls := 0
	var saw_reset_before_consume := false

	func _init(match_flow_value: Object) -> void:
		match_flow = match_flow_value

	func consume_next_battle_full_gauge(owner: Object, _registry: Object) -> Dictionary:
		consume_invocations += 1
		saw_reset_before_consume = int(match_flow.reset_game_calls) > 1
		if not pending:
			return {"accepted": true, "applied": false, "reason": "not_pending"}
		owner.set("special_gauge", owner.get("special_gauge_max"))
		pending = false
		applied_calls += 1
		return {"accepted": true, "applied": true}


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	var owner := FakeOwner.new()
	var item := FakeItemDriver.new()
	var ball := FakeBallDriver.new()
	var boss_health := FakeBossHealthFlow.new()
	var match_flow := FakeMatchFlowDriver.new()
	var tower_flow := FakeTowerFlow.new(match_flow)
	var registry := FakeRegistry.new({
		"battle_scene_item_update_driver": item,
		"battle_scene_ball_update_driver": ball,
		"battle_scene_boss_health_flow": boss_health,
		"battle_scene_match_flow_driver": match_flow,
		"tower_ascent_flow_owner": tower_flow,
	})
	var driver: Object = MatchEventDriver.new()

	driver.handle_score_event("player", owner, registry)
	_expect(item.restore_calls == 1, "score event should restore pending throwables before match flow")
	_expect(match_flow.score_side == "player" and match_flow.score_stage == 11, "score event should forward side and current stage")
	_expect(ball.reset_calls == 1, "score event reset callback should reset ball")
	_expect(boss_health.reset_calls == 1 and int(owner.data.get("boss_current_health", 0)) == 15, "score event reset callback should reset boss health")

	owner.data["boss_current_health"] = 1
	owner.data["boss_health_damage_units"] = 14
	driver.handle_round_restart_event("rematch", owner, registry)
	_expect(item.restore_calls == 2, "round restart should restore pending throwables")
	_expect(match_flow.restart_reason == "rematch", "round restart should forward reason")
	_expect(ball.reset_calls == 2, "round restart reset callback should reset ball")
	_expect(boss_health.reset_calls == 2 and int(owner.data.get("boss_health_damage_units", -1)) == 0, "round restart should reset boss health state")

	owner.data["boss_current_health"] = 0
	owner.data["boss_defeated_by_health"] = true
	driver.update_scoreboard(0.25, owner, registry)
	_expect(abs(match_flow.scoreboard_delta - 0.25) <= 0.001, "scoreboard update should forward delta")
	_expect(match_flow.saw_scoreboard_drive_reset_callback, "scoreboard update should thread the continue reset Drive callback")
	_expect(match_flow.reset_game_calls == 1, "scoreboard reset-game callback should route through match event driver")
	_expect(ball.drive_reset_calls == 1, "reset-game callback should reset Drive input frames")
	_expect(ball.reset_calls == 4, "scoreboard reset callbacks should reset ball through reset-game and direct reset")
	_expect(boss_health.reset_calls == 4 and not bool(owner.data.get("boss_defeated_by_health", true)), "scoreboard reset callbacks should reset boss health through reset-game and direct reset")

	driver._reset_match_for_stage_transition(owner, registry)
	_expect(tower_flow.consume_invocations == 1 and tower_flow.applied_calls == 1, "real stage-transition reset must consume the pending tower full-gauge latch once")
	_expect(tower_flow.saw_reset_before_consume and is_equal_approx(float(owner.data.get("special_gauge", 0.0)), 640.0), "tower rest gauge must apply after the match reset so it starts full")
	owner.data["special_gauge"] = 17.0
	driver._reset_match_for_stage_transition(owner, registry)
	_expect(tower_flow.consume_invocations == 2 and tower_flow.applied_calls == 1 and is_equal_approx(float(owner.data.get("special_gauge", 0.0)), 17.0), "consumed tower gauge latch must not refill a second battle")

	if _failures.is_empty():
		print("tower_campfire_gauge_entry_seal: after_reset=1 full=640 once=1")
		print("match_event_driver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
