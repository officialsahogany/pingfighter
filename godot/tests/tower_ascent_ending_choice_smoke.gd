extends SceneTree

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


class FakeRuntimeState:
	extends RefCounted
	var pause_calls := 0
	var resume_calls := 0
	var arm_calls := 0
	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass
	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pause_calls += 1
	func _resume_skill_cooldowns_for_choice() -> void:
		resume_calls += 1
	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		arm_calls += 1


class FakeAudio:
	extends RefCounted
	var stop_calls := 0
	func stop_all() -> void:
		stop_calls += 1


class FakeRegistry:
	extends RefCounted
	var runtime := FakeRuntimeState.new()
	var audio := FakeAudio.new()
	func get_instance(key: String) -> Object:
		if key == "runtime_perk_state":
			return runtime
		if key == "game_audio":
			return audio
		return null
	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class FakeOwner:
	extends RefCounted
	var current_stage := 9
	var chance_gems_count := 0
	var chance_gems_max := 0
	var redraws := 0
	func request_battle_redraw() -> void:
		redraws += 1


func _init() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var save_path := "user://tower_ascent_ending_choice_%d.cfg" % Time.get_ticks_usec()
	_cleanup(save_path)
	_seed_fake_ending_record(save_path)
	_verify_descend_path_and_modal_hooks(save_path)
	_verify_continue_path_and_irreversibility(save_path)
	_cleanup(save_path)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_ending_choice_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _seed_fake_ending_record(save_path: String) -> void:
	var store := TowerAscentRecordStore.new()
	store.set_save_path(save_path)
	var result := store.record_clear(9, TowerAscentRecordStore.ENDING_STANDARD, false, "seed:standard")
	_expect(bool(result.get("accepted", false)), "fixture should seed the prior fake-ending clear")


func _verify_descend_path_and_modal_hooks(save_path: String) -> void:
	_finish_calls = 0
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	var flow := _begin_flow(save_path, "choice-descend", owner, registry)
	_expect(flow != null, "descend fixture should start")
	if flow == null:
		return
	var result: Dictionary = flow.begin_floor_nine_resolution(
		"choice-descend:floor09",
		Callable(self, "_record_finish"),
		owner,
		registry
	)
	_expect(bool(result.get("accepted", false)), "reclear should open a choice")
	_expect(flow.get_phase_name() == "ENDING_CHOICE", "reclear should enter the physical-blocking choice modal")
	_expect(flow.blocks_battle_physics(), "ending choice must block battle physics")
	_expect(registry.runtime.pause_calls == 1 and registry.runtime.resume_calls == 0, "choice should inherit the existing modal pause without a resume gap")
	var snapshot: Dictionary = flow.export_persistable_snapshot()
	_expect(not snapshot.is_empty(), "unanswered choice should be a stable snapshot boundary")

	var restore_registry := FakeRegistry.new()
	var restore_owner := FakeOwner.new()
	flow = null
	var restored := TowerAscentFlowOwner.new()
	restored.set_record_store_path_for_tests(save_path)
	_expect(
		restored.restore_snapshot(
			snapshot,
			Callable(self, "_record_finish"),
			restore_owner,
			restore_registry
		),
		"choice should restore after a crash"
	)
	_expect(restored.get_phase_name() == "ENDING_CHOICE", "restored choice should remain unanswered")
	_expect(restore_registry.runtime.pause_calls == 1, "restored choice should re-establish exactly one modal pause")
	var choose: Dictionary = restored.choose_ending_route("descend")
	_expect(bool(choose.get("accepted", false)) and bool(choose.get("changed", false)), "descend should commit once")
	_expect(restored.get_phase_name() == "RUN_SETTLEMENT" and _finish_calls == 0, "descend should open the shared clear settlement before final exit")
	_expect(restore_registry.runtime.resume_calls == 0 and restore_registry.runtime.arm_calls == 0, "choice-to-settlement transition must keep the modal pause without a resume gap")
	_expect(_count_locked_true_route_nodes(restored.get_graph_phases()) > 0, "descending must not unlock floors 10 to 12")
	_expect(restored.get_active_graph_phase_index() == 0, "descending must remain on the human-realm graph")
	_expect(int(restored.get_record_snapshot().get("clear_count", -1)) == 2, "descending should persist the second standard clear")
	var confirm := InputEventKey.new()
	confirm.pressed = true
	confirm.keycode = KEY_SPACE
	_expect(restored.handle_input(confirm), "clear settlement should consume confirm")
	_expect(not restored.is_active() and _finish_calls == 1, "settlement confirm should finalize once")
	_expect(restore_registry.runtime.resume_calls == 1 and restore_registry.runtime.arm_calls == 1, "settlement close should resume cooldowns and arm safety")


func _verify_continue_path_and_irreversibility(save_path: String) -> void:
	var flow := _begin_flow(save_path, "choice-continue", null, null)
	_expect(flow != null, "continue fixture should start")
	if flow == null:
		return
	flow.begin_floor_nine_resolution("choice-continue:floor09")
	var before_count := int(flow.get_record_snapshot().get("clear_count", -1))
	var choose: Dictionary = flow.choose_ending_route("continue")
	_expect(bool(choose.get("accepted", false)) and bool(choose.get("changed", false)), "continue should commit once")
	_expect(flow.get_phase_name() == "MAP_TRANSITION", "continue should enter the irreversible floor-10 transition")
	_expect(flow.get_active_graph_phase_index() == 1, "continue must atomically switch to the immortal-realm graph")
	_expect(_count_locked_true_route_nodes(flow.get_graph_phases()) == 0, "continue alone should unlock floors 10 to 12")
	for node in flow.get_graph_nodes():
		_expect(int(node.get("floor", 0)) >= 10, "phase-2 disclosure must contain only floors 10 through 12")
	_expect(bool(flow.get_ending_state_snapshot().get("route_unlocked", false)), "snapshot state should own the route unlock")
	_expect(int(flow.get_record_snapshot().get("clear_count", -1)) == before_count, "continuing is nonterminal and must not increment clears")
	var reversal: Dictionary = flow.choose_ending_route("descend")
	_expect(not bool(reversal.get("accepted", true)) and str(reversal.get("reason", "")) == "choice_is_irreversible", "continue choice must reject a later descend reversal")


func _begin_flow(save_path: String, run_id: String, owner: Object, registry: Object) -> Object:
	var flow := TowerAscentFlowOwner.new()
	flow.set_record_store_path_for_tests(save_path)
	if not flow.begin_vertical_slice(owner, Callable(), {
		"run_id": run_id,
		"current_stage": 9,
		"map_seed": 9410,
		"registry": registry,
	}):
		return null
	return flow


func _count_locked_true_route_nodes(phases: Array) -> int:
	var count := 0
	for phase_value in phases:
		if not (phase_value is Dictionary):
			continue
		for node_value in (phase_value as Dictionary).get("nodes", []):
			if node_value is Dictionary:
				var node := node_value as Dictionary
				if int(node.get("floor", 0)) >= 10 and bool(node.get("route_locked", false)):
					count += 1
	return count


func _record_finish() -> void:
	_finish_calls += 1


func _cleanup(save_path: String) -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
