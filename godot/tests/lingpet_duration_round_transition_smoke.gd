extends SceneTree

const BallRoundController := preload("res://scripts/ball/ball_round_controller.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const MatchFlowController := preload("res://scripts/core/match_flow_controller.gd")


class FakeScoreState:
	extends RefCounted

	func score_for(side: String) -> Dictionary:
		return {
			"player_score": 1 if side == "player" else 0,
			"boss_score": 1 if side == "boss" else 0,
			"match_finished": false,
			"next_player_serves": side == "boss",
		}

	func would_score_finish(_side: String) -> bool:
		return false


class FakeRoundState:
	extends RefCounted

	var scoreboard_wait_calls := 0
	var reset_round_wait_calls := 0

	func start_scoreboard_wait() -> void:
		scoreboard_wait_calls += 1

	func reset_round_wait() -> void:
		reset_round_wait_calls += 1

	func set_player_serves(_value: bool) -> void:
		pass


class FakeScoreboardState:
	extends RefCounted

	var start_calls := 0

	func trigger_top_mini_sparkle() -> void:
		pass

	func start(
		_player_score: int,
		_boss_score: int,
		_match_finished: bool,
		_scoring_side: String
	) -> void:
		start_calls += 1


var _failures: Array[String] = []


func _init() -> void:
	_verify_real_score_to_round_reset_preserves_overfill_and_roll()
	_verify_real_round_reset_preserves_expiry_lock()
	_verify_projection_snapshot_restore_preserves_live_run_owner()

	if _failures.is_empty():
		print("lingpet_duration_round_transition_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_real_score_to_round_reset_preserves_overfill_and_roll() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	runtime.set_duration_pool_for_tests(44.0, 45.0)
	runtime.apply_guardian_enhance_duration_fallback()
	var before: Dictionary = runtime.export_affinity_run_state()
	var round_state := FakeRoundState.new()
	var scoreboard_state := FakeScoreboardState.new()
	var flow: Object = MatchFlowController.new()

	flow.handle_score_event("boss", {
		"score_state": FakeScoreState.new(),
		"round_state": round_state,
		"scoreboard_state": scoreboard_state,
		"lingpet_egg_runtime": runtime,
	}, {})
	flow.handle_round_restart("scoreboard", {"round_state": round_state}, {
		"reset_ball": Callable(self, "_reset_actual_ball_round").bind(runtime),
	})

	var after: Dictionary = runtime.export_affinity_run_state()
	_expect(scoreboard_state.start_calls == 1, "score event must enter the real scoreboard flow")
	_expect(round_state.scoreboard_wait_calls == 1, "score event must enter the real round-wait state")
	_expect_float(float(before.get("duration_pool", -1.0)), 59.0, "fixture must carry +15s overfill")
	_expect_float(float(after.get("duration_pool", -1.0)), 59.0, "round reset must preserve overfill current")
	_expect_float(float(after.get("duration_pool_max", -1.0)), 45.0, "round reset must preserve the one-time roll max")
	_expect(int(after.get("duration_increase_count", -1)) == int(before.get("duration_increase_count", -2)), "round reset must preserve duration increase ownership")


func _verify_real_round_reset_preserves_expiry_lock() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	runtime.set_duration_pool_for_tests(0.0, 45.0)
	var before: Dictionary = runtime.export_affinity_run_state()
	_reset_actual_ball_round(runtime)
	var after: Dictionary = runtime.export_affinity_run_state()
	_expect_float(float(after.get("duration_pool", -1.0)), 0.0, "round reset must not refill an expired pool")
	_expect_float(float(after.get("duration_pool_max", -1.0)), 45.0, "expired pool must retain its max")
	_expect_float(float(after.get("duration_resummon_lock_remaining", -1.0)), float(before.get("duration_resummon_lock_remaining", -2.0)), "round reset must preserve the resummon threshold remainder")
	_expect(not runtime.can_resummon_guardian(), "round reset must preserve the expiry resummon lock")


func _verify_projection_snapshot_restore_preserves_live_run_owner() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	runtime.set_duration_pool_for_tests(17.0, 45.0)
	var projection_snapshot: Dictionary = runtime.get_save_snapshot()
	projection_snapshot.erase("affinity_run_state")
	runtime.apply_save_snapshot(projection_snapshot)
	_expect_float(runtime.get_duration_pool_current(), 17.0, "in-run projection restore must preserve current when affinity payload is absent")
	_expect_float(runtime.get_duration_pool_max(), 45.0, "in-run projection restore must preserve max when affinity payload is absent")


func _reset_actual_ball_round(runtime: Object) -> void:
	BallRoundController.new().reset_ball({}, {
		"lingpet_egg_runtime": runtime,
	}, {})


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_float(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (actual=%.4f expected=%.4f)" % [message, actual, expected])
