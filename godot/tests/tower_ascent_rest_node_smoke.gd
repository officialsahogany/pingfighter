extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentNodeArrivalTestFixture := preload(
	"res://tests/tower_ascent_node_arrival_test_fixture.gd"
)
const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

var _failures: Array[String] = []
var _initial_route_seed := TowerAscentNodeArrivalTestFixture.find_initial_route_seed(
	"rest"
)


class FakeOwner:
	extends RefCounted

	var current_stage := 4
	var chance_gems_count := 0
	var chance_gems_max := 0
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


func _initialize() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_free_once_per_node_restore_and_snapshot()
	_verify_full_and_zero_balance_legs()
	_verify_flag_off_is_untouched()
	_verify_source_contracts()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_rest_node_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_free_once_per_node_restore_and_snapshot() -> void:
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "rest-once",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "rest",
		"run_state": {"chance_gems": 2, "gold": 0, "muhon": 0},
	}), "rest fixture must enter through the real tower flow")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "rest", owner), "rest fixture must reach rest only after route serve and map arrival")
	var action := _find_action(
		flow.get_node_modal_view_model().get("actions", []),
		"rest:restore_chance_gem"
	)
	_expect(not action.is_empty() and bool(action.get("enabled", false)), "a non-full unused rest node must expose its restore action")
	_expect(str(action.get("cost_text", "")) == "무료", "rest recovery must be free")
	var first := flow.execute_node_action(
		"rest:restore_chance_gem",
		"rest-once:restore"
	)
	_expect(bool(first.get("accepted", false)) and bool(first.get("applied", false)), "rest recovery must commit through the node transaction")
	_expect(int(flow.get_run_state_snapshot().get("chance_gems", -1)) == 3, "rest recovery must add exactly one chance gem")
	_expect(owner.chance_gems_count == 3 and owner.chance_gems_max == TowerAscentRunState.MAX_CHANCE_GEMS, "rest recovery must immediately project the run balance to the owner")
	_expect(flow.get_rest_history().size() == 1, "one rest commit must create exactly one node history record")
	var replay := flow.execute_node_action(
		"rest:restore_chance_gem",
		"rest-once:restore"
	)
	_expect(bool(replay.get("accepted", false)) and not bool(replay.get("applied", true)), "the same node_resolution_id must replay idempotently")
	_expect(flow.get_rest_history().size() == 1 and int(flow.get_run_state_snapshot().get("chance_gems", -1)) == 3, "idempotent replay must not duplicate recovery or history")
	var second_resolution := flow.execute_node_action(
		"rest:restore_chance_gem",
		"rest-once:second"
	)
	_expect(not bool(second_resolution.get("accepted", true)) and str(second_resolution.get("reason", "")) == "rest_already_used", "a different resolution id must not bypass the once-per-node limit")

	var snapshot := flow.export_persistable_snapshot()
	var restored_owner := FakeOwner.new()
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(snapshot, Callable(), restored_owner), "rest history must round-trip through the stable tower snapshot")
	var restored_action := _find_action(
		restored.get_node_modal_view_model().get("actions", []),
		"rest:restore_chance_gem"
	)
	_expect(not restored_action.is_empty() and not bool(restored_action.get("enabled", true)), "restored used node must stay disabled")
	_expect(str(restored_action.get("unavailable_reason", "")).contains("이미"), "used rest node must explain why recovery is unavailable")
	_expect(restored.get_rest_history().size() == 1, "snapshot restore must preserve the rest node history")
	_finish_flow(flow, owner)
	_finish_flow(restored, restored_owner)


func _verify_full_and_zero_balance_legs() -> void:
	var full_owner := FakeOwner.new()
	var full_flow := TowerAscentFlowOwner.new()
	_expect(full_flow.begin_vertical_slice(full_owner, Callable(), {
		"run_id": "rest-full",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "rest",
		"run_state": {"chance_gems": 3},
	}), "full rest fixture must begin")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(full_flow, "rest", full_owner), "full rest fixture must arrive at rest")
	var full_action := _find_action(full_flow.get_node_modal_view_model().get("actions", []), "rest:restore_chance_gem")
	_expect(not bool(full_action.get("enabled", true)), "a full chance-gem balance must disable free recovery")
	_expect(str(full_action.get("unavailable_reason", "")).contains("3"), "full-balance copy must show the exact maximum")
	var full_result := full_flow.execute_node_action("rest:restore_chance_gem", "rest-full:restore")
	_expect(not bool(full_result.get("accepted", true)) and full_flow.get_rest_history().is_empty(), "full balance must issue no transaction or visit record")
	_expect(int(full_flow.get_run_state_snapshot().get("chance_gems", -1)) == 3, "full balance must remain unchanged")

	var zero_owner := FakeOwner.new()
	var zero_flow := TowerAscentFlowOwner.new()
	_expect(zero_flow.begin_vertical_slice(zero_owner, Callable(), {
		"run_id": "rest-zero",
		"map_seed": _initial_route_seed,
		"node_modal_kind": "rest",
		"run_state": {"chance_gems": 0},
	}), "zero-balance rest fixture must begin")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(zero_flow, "rest", zero_owner), "zero-balance rest fixture must arrive at rest")
	var zero_result := zero_flow.execute_node_action("rest:restore_chance_gem", "rest-zero:restore")
	_expect(bool(zero_result.get("applied", false)), "zero balance must still accept the free recovery")
	_expect(int(zero_flow.get_run_state_snapshot().get("chance_gems", -1)) == 1, "rest recovery amount must stay one instead of refilling to maximum")
	_finish_flow(full_flow, full_owner)
	_finish_flow(zero_flow, zero_owner)


func _verify_flag_off_is_untouched() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var flow := TowerAscentFlowOwner.new()
	_expect(not flow.begin_vertical_slice(FakeOwner.new(), Callable(), {
		"run_id": "rest-off",
		"node_modal_kind": "rest",
	}), "flag OFF must bypass the rest node")
	_expect(flow.get_rest_history().is_empty(), "flag OFF must not create a rest transaction")
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)


func _verify_source_contracts() -> void:
	var rest_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_rest_node.gd"
	)
	_expect(TowerAscentTuning.TEMP_PHASE_C_REST_RESTORE_PER_NODE == 1, "the goal-owned temporary recovery amount must remain one")
	_expect(rest_source.find('"chance_gems": amount') >= 0, "rest recovery must reward the run-owned chance_gems field")
	_expect(rest_source.find("plaza_") < 0 and rest_source.find("add_plaza") < 0, "rest recovery must never touch plaza gem storage")
	_expect(rest_source.find("apply_once") >= 0, "rest recovery must use the idempotent node action transaction")


func _find_action(actions: Array, action_id: String) -> Dictionary:
	for raw_action in actions:
		if raw_action is Dictionary and str((raw_action as Dictionary).get("id", "")) == action_id:
			return raw_action as Dictionary
	return {}


func _finish_flow(flow: Object, owner: Object) -> void:
	if flow == null or not flow.is_active():
		return
	if flow.get_phase_name() == "NODE_MODAL":
		flow.debug_advance_to_route_aim()
	if flow.get_phase_name() == "ROUTE_AIM":
		flow.debug_launch_at_target(0)
		flow.update_selective(1.5, owner)
	if flow.get_phase_name() == "MAP_TRANSITION":
		flow.update_selective(1.0, owner)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
