extends SceneTree

const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)
const TowerAscentNodeResolutionTransaction := preload(
	"res://scripts/tower_ascent/tower_ascent_node_resolution_transaction.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	_verify_apply_once_and_committed_replay()
	_verify_crash_recovery_from_stable_snapshot()
	_verify_flow_owner_recovers_and_commits_pending_journal()
	_verify_malformed_and_cross_run_journals_fail_closed()
	if _failures.is_empty():
		print("tower_ascent_node_resolution_transaction_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_apply_once_and_committed_replay() -> void:
	var state := _new_state("apply-once", {"gold": 10, "muhon": 4, "chance_gems": 1})
	var transaction := TowerAscentNodeResolutionTransaction.new()
	var pending: Dictionary = transaction.prepare(
		"apply-once", "combat_01", "combat_victory", "fixture", {"gold": 5, "muhon": 2, "unknown": 999}
	)
	var completed: Dictionary = {}
	var first: Dictionary = transaction.apply_once(pending, state, completed)
	_expect(bool(first.get("applied", false)), "first application must grant the prepared reward")
	_expect(state.export_economy() == {"gold": 15, "muhon": 6, "chance_gems": 1}, "prepared reward must change real run balances")
	var duplicate: Dictionary = transaction.apply_once(pending, state, completed)
	_expect(not bool(duplicate.get("applied", true)), "same-process replay must not duplicate a reward")
	_expect(state.export_economy().gold == 15, "same-process replay must leave gold unchanged")
	completed[str(pending.node_resolution_id)] = true
	transaction.mark_committed(str(pending.node_resolution_id))
	var committed_replay: Dictionary = transaction.apply_once(pending, state, completed)
	_expect(str(committed_replay.get("reason", "")) == "already_committed", "committed replay must be classified without granting")
	_expect(state.export_economy().gold == 15, "committed replay must not duplicate gold")


func _verify_crash_recovery_from_stable_snapshot() -> void:
	var stable := _new_state("crash-recovery", {"gold": 20, "muhon": 3, "chance_gems": 0})
	var stable_snapshot: Dictionary = stable.export_snapshot_fields()
	var before_crash := TowerAscentNodeResolutionTransaction.new()
	var pending: Dictionary = before_crash.prepare(
		"crash-recovery", "combat_02", "combat_victory", "fixture", {"gold": 7, "muhon": 1}
	)
	before_crash.apply_once(pending, stable, {})
	_expect(stable.export_economy().gold == 27, "pre-crash process must apply the reward")
	var restored := TowerAscentRunState.new()
	_expect(restored.restore_snapshot(stable_snapshot), "last stable snapshot must restore after a crash")
	var recovered := TowerAscentNodeResolutionTransaction.new()
	var recovery_result: Dictionary = recovered.apply_once(pending, restored, {})
	_expect(bool(recovery_result.get("applied", false)), "pending journal must reapply against the pre-reward stable snapshot")
	_expect(restored.export_economy() == {"gold": 27, "muhon": 4, "chance_gems": 0}, "crash recovery must lose and duplicate zero rewards")
	var completed := {str(pending.node_resolution_id): true}
	recovered.mark_committed(str(pending.node_resolution_id))
	recovered.apply_once(pending, restored, completed)
	_expect(restored.export_economy().gold == 27, "post-commit journal replay must remain idempotent")


func _verify_malformed_and_cross_run_journals_fail_closed() -> void:
	var transaction := TowerAscentNodeResolutionTransaction.new()
	_expect(not bool(transaction.validate_pending({}).get("accepted", true)), "malformed pending record must fail closed")
	var pending: Dictionary = transaction.prepare("run-a", "node", "kind", "fixture", {})
	_expect(not bool(transaction.validate_pending(pending, "run-b").get("accepted", true)), "journal from another run_id must fail closed")


func _verify_flow_owner_recovers_and_commits_pending_journal() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var source := TowerAscentFlowOwner.new()
	_expect(
		source.begin_vertical_slice(null, Callable(), {
			"run_id": "flow-recovery",
			"run_state": {"gold": 30, "muhon": 0, "chance_gems": 0},
		}),
		"flow recovery fixture must reach a stable post-combat boundary"
	)
	var stable_snapshot: Dictionary = source.export_persistable_snapshot()
	var pending: Dictionary = TowerAscentNodeResolutionTransaction.new().prepare(
		"flow-recovery", "bonus_01", "bonus_reward", "fixture", {"gold": 9}
	)
	var journal := {"run_id": "flow-recovery", "pending_rewards": [pending]}
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(stable_snapshot), "flow owner must restore the last stable snapshot before journal recovery")
	var first: Dictionary = restored.recover_pending_reward_journal(journal)
	_expect(bool(first.get("accepted", false)) and int(first.get("applied_count", 0)) == 1, "flow owner must apply a pending journal once")
	_expect(restored.get_run_state_snapshot().gold == 39, "recovered journal must update the flow-owned run balance")
	var second: Dictionary = restored.recover_pending_reward_journal(journal)
	_expect(int(second.get("skipped_count", 0)) == 1, "committed recovery journal must be detected as already resolved")
	_expect(restored.get_run_state_snapshot().gold == 39, "replayed recovery journal must not duplicate the reward")
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()


func _new_state(run_id: String, economy: Dictionary) -> Object:
	var state := TowerAscentRunState.new()
	state.begin(run_id, economy, [{"id": "phase_01", "nodes": [], "edges": []}])
	return state


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
