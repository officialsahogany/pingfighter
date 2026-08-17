extends SceneTree

const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentRecordStore := preload(
	"res://scripts/tower_ascent/tower_ascent_record_store.gd"
)

var _failures: Array[String] = []
var _finish_calls := 0
var _continue_calls := 0


class FakeScoreboard:
	extends RefCounted
	func get_player_points() -> int:
		return 0
	func get_boss_points() -> int:
		return MatchScoreState.WIN_GOAL
	func get_win_goal() -> int:
		return MatchScoreState.WIN_GOAL
	func get_last_scoring_side() -> String:
		return "boss"


class FakeRegistry:
	extends RefCounted
	var scoreboard := FakeScoreboard.new()
	func get_instance(key: String) -> Object:
		return scoreboard if key == "scoreboard_state" else null


class FakeOwner:
	extends RefCounted
	var current_stage := 10
	var chance_gems_count := 3
	var chance_gems_max := 3


func _init() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var medal_path := "user://tower_ascent_true_ending_medal_%d.cfg" % Time.get_ticks_usec()
	var defeated_path := "user://tower_ascent_true_ending_defeated_%d.cfg" % Time.get_ticks_usec()
	var locked_path := "user://tower_ascent_true_ending_locked_%d.cfg" % Time.get_ticks_usec()
	for path in [medal_path, defeated_path, locked_path]:
		_cleanup(path)
	_verify_locked_route_rejects(locked_path)
	_verify_undefeated_true_ending(medal_path)
	_verify_defeat_count_blocks_medal(defeated_path)
	for path in [medal_path, defeated_path, locked_path]:
		_cleanup(path)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_true_ending_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_locked_route_rejects(save_path: String) -> void:
	var flow := TowerAscentFlowOwner.new()
	flow.set_record_store_path_for_tests(save_path)
	_expect(flow.ensure_run_started(null, {"run_id": "true-ending-locked"}), "locked fixture should start")
	var result: Dictionary = flow.begin_floor_twelve_true_ending("true-ending-locked:floor12")
	_expect(not bool(result.get("accepted", true)) and str(result.get("reason", "")) == "true_route_locked", "floor twelve must reject a run that never chose to continue")


func _verify_undefeated_true_ending(save_path: String) -> void:
	_finish_calls = 0
	var flow := _build_true_route_flow(save_path, "true-ending-medal")
	_expect(flow != null, "undefeated fixture should reach the true route")
	if flow == null:
		return
	_expect(_complete_gauntlet(flow), "undefeated fixture should complete all four encounters")
	var result: Dictionary = flow.begin_floor_twelve_true_ending(
		"true-ending-medal:floor12",
		Callable(self, "_record_finish")
	)
	_expect(bool(result.get("accepted", false)) and bool(result.get("undefeated", false)), "zero defeats should open the undefeated true-ending settlement")
	_expect(flow.get_phase_name() == "RUN_SETTLEMENT", "true ending should use the shared settlement phase")
	var records: Dictionary = flow.get_record_snapshot()
	_expect(bool(records.get("true_ending_cleared", false)), "true ending should persist immediately")
	_expect(bool(records.get("undefeated_true_ending_medal", false)), "zero run defeats should award the medal")
	_expect(int(records.get("highest_floor", 0)) == 12 and int(records.get("clear_count", 0)) == 2, "true ending should update floor and clear records once")
	var model: Dictionary = flow.get_settlement_view_model()
	_expect(str(model.get("result_kind", "")) == "true_ending", "settlement should expose the true-ending variant")
	_expect(str(model.get("title", "")) == "왕의 시련 완수", "true-ending title should be distinct")
	_expect(str(model.get("body", "")).find("—") < 0 and str(model.get("body", "")).find("–") < 0, "true-ending Korean copy must not use dash punctuation")
	_expect((model.get("persistent_income_rows", []) as Array).has("무패 진엔딩 훈장"), "persistent income should list the earned medal")
	var duplicate: Dictionary = flow.begin_floor_twelve_true_ending("true-ending-medal:floor12")
	_expect(bool(duplicate.get("accepted", false)), "replayed true-ending resolution should be idempotent")
	_expect(int(flow.get_record_snapshot().get("clear_count", 0)) == 2, "replay must not increment clear count")
	var confirm := InputEventKey.new()
	confirm.pressed = true
	confirm.keycode = KEY_SPACE
	flow.handle_input(confirm)
	_expect(_finish_calls == 1, "true-ending settlement should finalize once")
	var reloaded := TowerAscentRecordStore.new()
	reloaded.set_save_path(save_path)
	_expect(bool(reloaded.get_snapshot().get("undefeated_true_ending_medal", false)), "medal should survive a store restart")


func _verify_defeat_count_blocks_medal(save_path: String) -> void:
	var flow := _build_true_route_flow(save_path, "true-ending-defeated")
	_expect(flow != null, "defeated fixture should reach the true route")
	if flow == null:
		return
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	_expect(flow.resolve_defeat(registry, owner, Callable(self, "_record_continue"), Callable()), "a gem-backed defeat should be handled")
	_expect(flow.get_run_defeat_count() == 1, "every defeat should increment the run counter even when a gem retries it")
	_expect(owner.chance_gems_count == 2 and _continue_calls == 1, "defeat fixture should consume one gem and continue")
	var snapshot: Dictionary = flow.export_persistable_snapshot()
	_expect(int(snapshot.get("run_defeat_count", 0)) == 1, "snapshot should own total run defeats independently from gem balance")
	_expect(_complete_gauntlet(flow), "defeated fixture should still be allowed to complete the gauntlet")
	var result: Dictionary = flow.begin_floor_twelve_true_ending("true-ending-defeated:floor12")
	_expect(bool(result.get("accepted", false)) and not bool(result.get("undefeated", true)), "a recovered defeat should still block the medal")
	var records: Dictionary = flow.get_record_snapshot()
	_expect(bool(records.get("true_ending_cleared", false)), "defeated run should still record true-ending completion")
	_expect(not bool(records.get("undefeated_true_ending_medal", true)), "gem recovery must not erase a defeat for medal judgment")


func _build_true_route_flow(save_path: String, run_id: String) -> Object:
	var store := TowerAscentRecordStore.new()
	store.set_save_path(save_path)
	var seed: Dictionary = store.record_clear(9, TowerAscentRecordStore.ENDING_STANDARD, false, "%s:seed" % run_id)
	if not bool(seed.get("accepted", false)):
		return null
	var flow := TowerAscentFlowOwner.new()
	flow.set_record_store_path_for_tests(save_path)
	if not flow.prepare_vertical_slice_combat(null, {
		"run_id": run_id,
		"current_stage": 9,
		"map_seed": 91212,
	}):
		return null
	if not flow.begin_vertical_slice(null, Callable()):
		return null
	var judgment: Dictionary = flow.begin_floor_nine_resolution("%s:floor09" % run_id)
	if not bool(judgment.get("accepted", false)) or flow.get_phase_name() != "ENDING_CHOICE":
		return null
	var choice: Dictionary = flow.choose_ending_route("continue")
	if not bool(choice.get("accepted", false)):
		return null
	return flow


func _complete_gauntlet(flow: Object) -> bool:
	if not bool(flow.begin_floor_eleven_gauntlet().get("accepted", false)):
		return false
	var confirm := InputEventKey.new()
	confirm.pressed = true
	confirm.keycode = KEY_SPACE
	for index in range(4):
		var result: Dictionary = flow.resolve_gauntlet_victory(
			Callable(),
			null,
			null,
			"%s:true-route:%d:victory" % [flow.get_run_id(), index]
		)
		if not bool(result.get("accepted", false)):
			return false
		if index < 3:
			if flow.get_phase_name() != "GAUNTLET_TRANSITION" or not flow.handle_input(confirm):
				return false
	return bool(flow.get_gauntlet_state_snapshot().get("completed", false))


func _record_finish() -> void:
	_finish_calls += 1


func _record_continue() -> void:
	_continue_calls += 1


func _cleanup(save_path: String) -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
