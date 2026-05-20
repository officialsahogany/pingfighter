extends SceneTree

const MatchFlowController := preload("res://scripts/core/match_flow_controller.gd")

var _failures: Array[String] = []
var _reset_ball_calls := 0


class FakeRoundState:
	extends RefCounted

	var reset_round_wait_calls := 0
	var restart_notice_calls := 0

	func reset_round_wait() -> void:
		reset_round_wait_calls += 1

	func start_round_restart_notice() -> void:
		restart_notice_calls += 1


class FakeAudio:
	extends RefCounted

	var stopped: Dictionary = {}

	func stop_dash_delay() -> void:
		stopped["dash"] = true

	func stop_boomerang_loop() -> void:
		stopped["boomerang"] = true

	func stop_spider_mine_walk_loop() -> void:
		stopped["spider_mine"] = true

	func stop_plasma_charge() -> void:
		stopped["plasma_charge"] = true

	func stop_plasma_shock() -> void:
		stopped["plasma_shock"] = true

	func stop_warp_gate_loop() -> void:
		stopped["warp"] = true

	func stop_magnum_grip() -> void:
		stopped["magnum"] = true

	func stop_viper_jetpack_loop() -> void:
		stopped["viper_jetpack"] = true

	func stop_chaos_spear_blackhole_loop() -> void:
		stopped["chaos_blackhole"] = true

	func stop_ragnarok_shock_loop() -> void:
		stopped["ragnarok_shock"] = true

	func stop_electric_shock_loop() -> void:
		stopped["electric_shock"] = true

	func stop_stage2_quake_loop() -> void:
		stopped["quake"] = true


func _init() -> void:
	var controller: Object = MatchFlowController.new()
	var round_state := FakeRoundState.new()
	var audio := FakeAudio.new()

	controller.handle_round_restart("rematch", {
		"round_state": round_state,
		"audio": audio,
	}, {
		"reset_ball": Callable(self, "_record_reset_ball"),
	})
	_expect(_reset_ball_calls == 1, "valid reset-ball callback should run")
	_expect(round_state.reset_round_wait_calls == 0, "reset callback should replace fallback round wait reset")
	_expect(round_state.restart_notice_calls == 1, "rematch should start round restart notice")
	_expect(audio.stopped.size() == 12 and bool(audio.stopped.get("boomerang", false)) and bool(audio.stopped.get("spider_mine", false)) and bool(audio.stopped.get("chaos_blackhole", false)), "round restart should stop active score/round loops")

	var fallback_round_state := FakeRoundState.new()
	var fallback_audio := FakeAudio.new()
	controller.handle_round_restart("manual", {
		"round_state": fallback_round_state,
		"audio": fallback_audio,
	}, {})
	_expect(fallback_round_state.reset_round_wait_calls == 1, "missing reset callback should reset round wait")
	_expect(fallback_round_state.restart_notice_calls == 0, "non-rematch restart should not show rematch notice")
	_expect(fallback_audio.stopped.size() == 12 and bool(fallback_audio.stopped.get("boomerang", false)) and bool(fallback_audio.stopped.get("spider_mine", false)) and bool(fallback_audio.stopped.get("chaos_blackhole", false)), "fallback restart should still stop active loops")

	if _failures.is_empty():
		print("match_round_restart_controller_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _record_reset_ball() -> void:
	_reset_ball_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
