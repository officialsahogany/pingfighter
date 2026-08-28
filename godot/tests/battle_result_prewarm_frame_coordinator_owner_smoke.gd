extends SceneTree

const BattleResultPrewarmFrameCoordinator := preload(
	"res://scripts/core/battle_result_prewarm_frame_coordinator.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted


class FakeScoreboardState:
	extends RefCounted

	var active := false
	var timer := 0.0
	var player_points := 0
	var boss_points := 0
	var win_goal := 7
	var pending_game_reset := false

	func is_active() -> bool:
		return active

	func get_timer() -> float:
		return timer

	func get_player_points() -> int:
		return player_points

	func get_boss_points() -> int:
		return boss_points

	func get_win_goal() -> int:
		return win_goal

	func has_pending_game_reset() -> bool:
		return pending_game_reset


class FakeBattleResources:
	extends RefCounted

	var has_work := true
	var update_calls := 0

	func has_result_texture_prewarm_work() -> bool:
		return has_work

	func update_result_texture_prewarm() -> bool:
		update_calls += 1
		return true


class FakeStageClearResultScreen:
	extends RefCounted

	var active := false

	func is_active() -> bool:
		return active


class FakeStageClearPrewarm:
	extends RefCounted

	var has_work := true
	var calls := 0
	var last_owner: Object = null

	func has_stage_clear_result_resource_prewarm_work(_owner: Object) -> bool:
		return has_work

	func prewarm_stage_clear_result_resources_step(_module_getter: Callable, owner: Object) -> bool:
		calls += 1
		last_owner = owner
		return true


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return 1

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


class FakeModuleHost:
	extends RefCounted

	var scoreboard := FakeScoreboardState.new()
	var resources := FakeBattleResources.new()
	var result_screen := FakeStageClearResultScreen.new()
	var stage_clear_prewarm := FakeStageClearPrewarm.new()

	func get_module(key: String) -> Object:
		match key:
			"scoreboard_state":
				return scoreboard
			"battle_resources":
				return resources
			"stage_clear_result_screen":
				return result_screen
			"battle_boot_resource_prewarm_controller":
				return stage_clear_prewarm
		return null


func _init() -> void:
	_verify_safe_window_and_stage_clear_policy()
	_verify_work_gates()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_result_prewarm_frame_coordinator_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_safe_window_and_stage_clear_policy() -> void:
	var coordinator: Object = BattleResultPrewarmFrameCoordinator.new()
	var owner := FakeOwner.new()
	var host := FakeModuleHost.new()
	var perf_logger := FakePerfLogger.new()
	var getter := Callable(host, "get_module")

	coordinator.update(owner, getter, perf_logger)
	_expect(host.resources.update_calls == 0, "live battle idle must not advance result texture prewarm")

	host.scoreboard.active = true
	host.scoreboard.timer = BattleResultPrewarmFrameCoordinator.SCOREBOARD_MIN_TIMER - 0.001
	coordinator.update(owner, getter, perf_logger)
	_expect(host.resources.update_calls == 0, "the first scoreboard frame must render before result prewarm")

	host.scoreboard.timer = BattleResultPrewarmFrameCoordinator.SCOREBOARD_MIN_TIMER
	coordinator.update(owner, getter, perf_logger)
	_expect(host.resources.update_calls == 1, "a visible scoreboard must advance queued result textures")
	_expect(host.stage_clear_prewarm.calls == 0, "a normal scoreboard must not run stage-clear prewarm")

	host.scoreboard.pending_game_reset = true
	host.scoreboard.player_points = 6
	coordinator.update(owner, getter, perf_logger)
	_expect(host.stage_clear_prewarm.calls == 0, "stage-clear prewarm must honor the custom win goal")

	host.scoreboard.player_points = 7
	coordinator.update(owner, getter, perf_logger)
	_expect(host.stage_clear_prewarm.calls == 1, "a player match-win scoreboard must run stage-clear prewarm")
	_expect(host.stage_clear_prewarm.last_owner == owner, "stage-clear prewarm must receive the battle owner")
	_expect(perf_logger.labels.has("process.frame.result_texture_prewarm"), "texture work must keep its BattlePerf label")
	_expect(perf_logger.labels.has("process.frame.stage_clear_result_prewarm"), "stage-clear work must keep its BattlePerf label")

	host.result_screen.active = true
	coordinator.update(owner, getter, perf_logger)
	_expect(host.stage_clear_prewarm.calls == 1, "an active result screen must stop background stage-clear prewarm")


func _verify_work_gates() -> void:
	var coordinator: Object = BattleResultPrewarmFrameCoordinator.new()
	var owner := FakeOwner.new()
	var host := FakeModuleHost.new()
	host.scoreboard.active = true
	host.scoreboard.timer = BattleResultPrewarmFrameCoordinator.SCOREBOARD_MIN_TIMER
	host.resources.has_work = false
	host.scoreboard.pending_game_reset = true
	host.scoreboard.player_points = 7
	host.stage_clear_prewarm.has_work = false
	coordinator.update(owner, Callable(host, "get_module"), FakePerfLogger.new())
	_expect(host.resources.update_calls == 0, "completed result texture work must not be polled")
	_expect(host.stage_clear_prewarm.calls == 0, "completed stage-clear work must not be polled")


func _verify_source_ownership() -> void:
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/core/battle_result_prewarm_frame_coordinator.gd")
	var frame_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	_expect(coordinator_source.contains("func _is_safe_result_prewarm_window"), "coordinator must own the safe scoreboard window")
	_expect(coordinator_source.contains("func _scoreboard_snapshot_is_player_match_win"), "coordinator must own the match-win policy")
	_expect(frame_source.contains("BattleResultPrewarmFrameCoordinator.new()"), "frame controller must compose the result prewarm coordinator")
	_expect(not frame_source.contains("func _is_safe_result_prewarm_window"), "frame controller must not retain the safe-window policy")
	_expect(not frame_source.contains("func _scoreboard_snapshot_is_player_match_win"), "frame controller must not retain match-win policy")
	_expect(not frame_source.contains("func _update_stage_clear_result_prewarm"), "frame controller must not retain result prewarm execution policy")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
