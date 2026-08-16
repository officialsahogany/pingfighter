extends SceneTree

const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	_verify_new_run_and_sanitization()
	_verify_snapshot_round_trip()
	_verify_rejected_snapshots_do_not_restore()
	if _failures.is_empty():
		print("tower_ascent_run_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_new_run_and_sanitization() -> void:
	var state := TowerAscentRunState.new()
	_expect(not state.begin("   "), "blank run_id must be rejected")
	_expect(state.begin("run-state-smoke", {"gold": -5, "muhon": 7, "chance_gems": 2}), "valid run must start")
	_expect(state.get_run_id() == "run-state-smoke", "run state must own run_id")
	_expect(
		state.export_economy() == {"gold": 0, "muhon": 7, "chance_gems": 2},
		"run economy must clamp negative inputs without inventing another currency"
	)
	_expect(
		state.set_phases([{"id": "phase_01", "nodes": [], "edges": []}]),
		"one-phase fixture must use the phases array contract"
	)


func _verify_snapshot_round_trip() -> void:
	var source := TowerAscentRunState.new()
	source.begin("round-trip", {"gold": 11, "muhon": 13, "chance_gems": 1})
	source.mark_boss_skipped("floor_02_molewang")
	source.set_phases([{"id": "phase_01", "nodes": [{"id": "node_01"}], "edges": []}])
	var snapshot: Dictionary = source.export_snapshot_fields()
	_expect(int(snapshot.schema_version) == TowerAscentRunState.SNAPSHOT_SCHEMA_VERSION, "snapshot schema version must be explicit")
	_expect(snapshot.map_graph.phases.size() == 1, "snapshot map graph must serialize phases as an array")
	var restored := TowerAscentRunState.new()
	_expect(restored.restore_snapshot(snapshot), "valid run-state snapshot must restore")
	_expect(restored.get_run_id() == "round-trip", "restore must preserve run_id")
	_expect(restored.export_economy() == source.export_economy(), "restore must preserve run-local economy")
	_expect(restored.get_phases() == source.get_phases(), "restore must preserve phase graph data")
	_expect(restored.get_skipped_boss_ids() == ["floor_02_molewang"], "restore must preserve run-owned avoided boss slots")


func _verify_rejected_snapshots_do_not_restore() -> void:
	var valid := {
		"schema_version": TowerAscentRunState.SNAPSHOT_SCHEMA_VERSION,
		"run_id": "reject-fixture",
		"run_state": {"gold": 0, "muhon": 0, "chance_gems": 0},
		"run_progress": {"skipped_boss_ids": []},
		"map_graph": {"phases": [{"id": "phase_01", "nodes": [], "edges": []}]},
	}
	var wrong_schema := valid.duplicate(true)
	wrong_schema["schema_version"] = TowerAscentRunState.SNAPSHOT_SCHEMA_VERSION + 1
	_expect(not TowerAscentRunState.new().restore_snapshot(wrong_schema), "unknown schema version must fail closed")
	var flat_graph := valid.duplicate(true)
	flat_graph["map_graph"] = {"nodes": [], "edges": []}
	_expect(not TowerAscentRunState.new().restore_snapshot(flat_graph), "legacy flat graph must not erase the phases contract")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
