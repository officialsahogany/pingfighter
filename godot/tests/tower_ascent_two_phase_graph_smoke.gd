extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)
const TowerAscentRecordStore := preload(
	"res://scripts/tower_ascent/tower_ascent_record_store.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var save_path := "user://tower_ascent_two_phase_%d.cfg" % Time.get_ticks_usec()
	_cleanup(save_path)
	_verify_true_route_switch_and_phase_two_recovery(save_path)
	_cleanup(save_path)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_two_phase_graph_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_true_route_switch_and_phase_two_recovery(save_path: String) -> void:
	var store := TowerAscentRecordStore.new()
	store.set_save_path(save_path)
	var seed: Dictionary = store.record_clear(
		9,
		TowerAscentRecordStore.ENDING_STANDARD,
		false,
		"two-phase:seed"
	)
	_expect(bool(seed.get("accepted", false)), "phase-switch fixture must seed a prior standard clear")
	var flow := TowerAscentFlowOwner.new()
	flow.set_record_store_path_for_tests(save_path)
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "two-phase-run",
		"current_stage": 9,
		"map_seed": 91821,
	}), "phase-switch fixture must begin on the human-realm graph")
	_expect(flow.get_active_graph_phase_index() == 0, "ordinary run must start in phase 1")
	var judgment: Dictionary = flow.begin_floor_nine_resolution("two-phase:floor09")
	_expect(bool(judgment.get("accepted", false)) and flow.get_phase_name() == "ENDING_CHOICE", "floor 9 reclear must preserve the existing ending judgment")
	var choice: Dictionary = flow.choose_ending_route("continue")
	_expect(bool(choice.get("accepted", false)), "true-route choice must commit")
	_expect(flow.get_active_graph_phase_index() == 1, "true-route choice must switch to phase 2 before floor 10")
	_expect(flow.get_phase_name() == "MAP_TRANSITION" and flow.is_phase_entry_transition(), "realm switch must own an explicit phase-entry map transition")
	var active_phase: Dictionary = flow.get_active_graph_phase()
	_expect(str(active_phase.get("id", "")) == TowerAscentMapGenerator.IMMORTAL_REALM_PHASE_ID, "active graph must identify the immortal realm")
	_expect((active_phase.get("floors", []) as Array).size() == 3, "phase 2 must disclose exactly floors 10 through 12")
	for node in flow.get_graph_nodes():
		_expect(int(node.get("floor", 0)) >= 10, "phase-2 renderer surface must not leak human-realm nodes")
		_expect(not bool(node.get("route_locked", true)), "true-route confirmation must unlock every phase-2 node")
	var model: Dictionary = TowerAscentFlowRenderer.new().build_fullscreen_map_model(
		flow,
		Rect2(Vector2.ZERO, Vector2(1280.0, 800.0))
	)
	_expect(str(model.get("realm_kind", "")) == "immortal_realm", "phase-2 renderer must select the cloud and cliff treatment")
	_expect((model.get("floor_bands", []) as Array).size() == 3, "phase-2 renderer must project three floor tiers")
	_expect(bool((model.get("transition_marker", {}) as Dictionary).get("phase_entry", false)), "phase-2 renderer must publish the entry marker and banner")

	var snapshot: Dictionary = flow.export_persistable_snapshot()
	_expect(not snapshot.is_empty(), "phase-entry map transition must be a stable snapshot boundary")
	_expect(int(snapshot.run_progress.active_phase_index) == 1, "snapshot must persist the active immortal-realm index")
	var restored := TowerAscentFlowOwner.new()
	restored.set_record_store_path_for_tests(save_path)
	_expect(restored.restore_snapshot(snapshot), "phase-2 full graph must recover without regeneration")
	_expect(restored.get_active_graph_phase_index() == 1, "recovery must restore the same active realm")
	_expect(restored.get_phase_name() == "MAP_TRANSITION" and restored.is_phase_entry_transition(), "recovery must preserve the pending realm-entry transition")
	_expect(var_to_bytes(restored.export_persistable_snapshot().map_graph) == var_to_bytes(snapshot.map_graph), "phase-2 graph recovery must remain byte-identical")


func _cleanup(save_path: String) -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
