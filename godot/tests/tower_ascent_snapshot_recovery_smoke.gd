extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)

var _failures: Array[String] = []
var _continue_calls := 0


class FakeOwner:
	extends RefCounted

	var chance_gems_count := 0
	var chance_gems_max := 0


class FakeScoreboard:
	extends RefCounted

	func get_player_points() -> int:
		return 2

	func get_boss_points() -> int:
		return 7

	func get_win_goal() -> int:
		return 7

	func get_last_scoring_side() -> String:
		return "boss"


class FakeRegistry:
	extends RefCounted

	var scoreboard := FakeScoreboard.new()

	func get_instance(key: String) -> Variant:
		return scoreboard if key == "scoreboard_state" else null


func _init() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_full_graph_round_trip()
	_verify_retry_does_not_regenerate_map()
	_verify_invalid_snapshot_contracts_fail_closed()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_snapshot_recovery_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_full_graph_round_trip() -> void:
	var source := TowerAscentFlowOwner.new()
	_expect(source.begin_vertical_slice(null, Callable(), {
		"run_id": "snapshot-full-graph",
		"map_seed": 771122,
	}), "generated run must start before snapshot export")
	_advance_to_stable_map_transition(source)
	var snapshot: Dictionary = source.export_persistable_snapshot()
	_expect(not snapshot.is_empty(), "post-selection MAP_TRANSITION must be a persistable boundary")
	_expect(snapshot.map_graph_storage == TowerAscentFlowOwner.MAP_GRAPH_STORAGE_FULL, "snapshot must declare full-graph storage")
	_expect(int(snapshot.schema_version) == TowerAscentRunState.SNAPSHOT_SCHEMA_VERSION, "snapshot schema version must advance with the map contract")
	_expect(snapshot.map_graph.phases.size() == 2, "full-graph snapshot must retain both realm phases")
	_expect(snapshot.map_graph.phases[0].has("floors") and snapshot.map_graph.phases[1].has("floors"), "full-graph snapshot must retain generated floor and row metadata for both phases")
	_expect(int(snapshot.run_progress.active_phase_index) == 0, "ordinary snapshot must identify the human realm as active")
	var source_bytes := var_to_bytes(snapshot.map_graph)
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(snapshot), "full generated graph must restore")
	var round_trip: Dictionary = restored.export_persistable_snapshot()
	_expect(var_to_bytes(round_trip.map_graph) == source_bytes, "serialize, restore, and re-export must be byte identical")
	_expect(int(round_trip.map_seed) == 771122, "map seed must survive the full-graph round trip")
	_expect(round_trip.map_generator_version == snapshot.map_generator_version, "generator version must survive recovery")


func _verify_retry_does_not_regenerate_map() -> void:
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "retry-map-invariant",
		"map_seed": 120045,
	}), "retry fixture must begin")
	var before: Dictionary = flow.export_snapshot()
	_expect(flow.resolve_defeat(
		FakeRegistry.new(),
		owner,
		Callable(self, "_on_continue"),
		Callable()
	), "tower defeat must consume one run-local retry")
	var after: Dictionary = flow.export_snapshot()
	_expect(_continue_calls == 1, "retry continuation must execute exactly once")
	_expect(int(after.run_state.chance_gems) == 2, "retry must consume exactly one run-local gem")
	_expect(var_to_bytes(after.map_graph) == var_to_bytes(before.map_graph), "gem retry must not reroll the generated map")
	_expect(int(after.map_seed) == int(before.map_seed), "gem retry must preserve the map seed")


func _verify_invalid_snapshot_contracts_fail_closed() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {"run_id": "invalid-storage", "map_seed": 4}), "invalid fixture must begin")
	_advance_to_stable_map_transition(flow)
	var snapshot: Dictionary = flow.export_snapshot()
	var wrong_storage := snapshot.duplicate(true)
	wrong_storage["map_graph_storage"] = "seed_only"
	_expect(not TowerAscentFlowOwner.new().restore_snapshot(wrong_storage), "unsupported graph storage must fail closed")
	var missing_seed := snapshot.duplicate(true)
	missing_seed.erase("map_seed")
	_expect(not TowerAscentFlowOwner.new().restore_snapshot(missing_seed), "snapshot without a map seed must fail closed")
	var stale_v6 := snapshot.duplicate(true)
	stale_v6["map_generator_version"] = "tower_map_v6_two_realms"
	_expect(not TowerAscentFlowOwner.new().restore_snapshot(stale_v6), "v6 full-graph snapshots must not be reinterpreted under v7 topology")
	var legacy_single_phase := snapshot.duplicate(true)
	legacy_single_phase["schema_version"] = TowerAscentRunState.LEGACY_SINGLE_PHASE_SCHEMA_VERSION
	legacy_single_phase["map_generator_version"] = "tower_map_v5_enraged_marking"
	legacy_single_phase["map_graph"] = {"phases": [snapshot.map_graph.phases[0]]}
	_expect(TowerAscentRunState.snapshot_restore_policy(legacy_single_phase) == TowerAscentRunState.SNAPSHOT_POLICY_RESET_LEGACY_SINGLE_PHASE, "schema-7 single-phase saves must declare the explicit new-run reset policy")
	_expect(not TowerAscentFlowOwner.new().restore_snapshot(legacy_single_phase), "legacy one-phase snapshots must never be silently reinterpreted as two-phase runs")


func _advance_to_stable_map_transition(flow: Object) -> void:
	flow.debug_launch_at_target(0)
	flow.update_selective(1.5)
	_expect(flow.get_phase_name() == "MAP_TRANSITION", "snapshot fixture must reach the stable map-transition boundary")


func _on_continue() -> void:
	_continue_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
