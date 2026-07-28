extends SceneTree
# Seals the lingpet save/restore round trip preserving the RUN-SCOPED affinity
# progression (per-pet affinity level/points, reward seed/deck, and run-local feed state).
#
# Regression: apply_save_snapshot() calls reset_for_tests() -> reset_for_new_run()
# which wipes _affinity_state. Before the fix, get_save_snapshot() carried no affinity
# data, so any in-run save/restore (plaza egg-buy rollback, in-run restore) reset every
# pet to Lv.0 and lost the reward deck. The fix carries the run state in
# the snapshot ("affinity_run_state") and re-imports it on restore.
#
# Built-in reverse verification: a snapshot with affinity_run_state STRIPPED must NOT
# restore the run state (proves the import is the load-bearing lever, not some other path).

const Smoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetSaveStore := preload("res://scripts/lingpet/lingpet_save_store.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failed := false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _make_owner() -> Object:
	var owner = Smoke.FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo", "lunabi"]
	owner.owned_lingpet_ids = owner.lingpet_owned_pet_ids.duplicate()
	owner.owned_ringpet_ids = owner.lingpet_owned_pet_ids.duplicate()
	owner.lingpet_slots = ["maribo", "lunabi", ""]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 0
	owner.ringpet_active_slot_index = 0
	return owner


func _seed_runtime() -> Dictionary:
	var owner := _make_owner()
	var registry = Smoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.update(0.0, owner, registry)                       # adopt maribo
	runtime.update(0.0, owner, registry)                       # project affinity to owner state
	for _i in range(12):
		runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, registry)
	var aff = runtime.get("_affinity_state")
	return {
		"runtime": runtime,
		"owner": owner,
		"registry": registry,
		"level": int(aff.get_level("maribo")),
		"points": float(aff.get_points("maribo")),
		"seed": int(aff.get_reward_seed("maribo")),
		"deck": _deck_types(aff.get_reward_deck("maribo")),
	}


func _deck_types(deck: Array) -> Array:
	var types: Array = []
	for card in deck:
		if card is Dictionary:
			types.append(str((card as Dictionary).get("type", "")))
	return types


func _init() -> void:
	# Sanity: seeding actually produced a non-trivial run state to lose.
	var seed_data := _seed_runtime()
	_expect(int(seed_data["level"]) >= 1, "fixture should level maribo to at least Lv.1")
	_expect(float(seed_data["points"]) > 0.0, "fixture should bank maribo affinity points")

	# 1) Same-instance save -> restore preserves run state.
	var runtime_a: Object = seed_data["runtime"]
	var owner_a: Object = seed_data["owner"]
	var registry_a: Object = seed_data["registry"]
	var snap_a: Dictionary = runtime_a.get_save_snapshot()
	_expect(snap_a.has("affinity_run_state"), "save snapshot should carry affinity_run_state")
	_expect(not (snap_a.get("affinity_run_state", {}) as Dictionary).is_empty(), "affinity_run_state should be populated for an active run")
	runtime_a.apply_save_snapshot(snap_a, owner_a, registry_a)
	var aff_a = runtime_a.get("_affinity_state")
	_expect(int(aff_a.get_level("maribo")) == int(seed_data["level"]), "same-instance restore should preserve per-pet affinity level")
	_expect(is_equal_approx(float(aff_a.get_points("maribo")), float(seed_data["points"])), "same-instance restore should preserve per-pet affinity points")
	# P1: the reward seed (and thus the deterministic reward deck / unlock-choice shuffle)
	# must survive restore. reset_for_tests clears the coordinator seed cache, so without the
	# coordinator adopting the restored pet seed it would re-randomize here.
	_expect(int(aff_a.get_reward_seed("maribo")) == int(seed_data["seed"]), "same-instance restore should preserve the reward seed (no re-randomization)")
	_expect(_deck_types(aff_a.get_reward_deck("maribo")) == (seed_data["deck"] as Array), "same-instance restore should preserve the reward deck order")

	# 2) Fresh-instance restore (egg_runtime recreated) preserves run state.
	var seed_b := _seed_runtime()
	var snap_b: Dictionary = (seed_b["runtime"] as Object).get_save_snapshot()
	var owner_b2 := _make_owner()
	var registry_b2 = Smoke.FakeRegistry.new()
	var runtime_b2: Object = LingpetEggRuntime.new()
	runtime_b2.apply_save_snapshot(snap_b, owner_b2, registry_b2)
	var aff_b2 = runtime_b2.get("_affinity_state")
	_expect(int(aff_b2.get_level("maribo")) == int(seed_b["level"]), "fresh-instance restore should preserve per-pet affinity level")
	_expect(int(aff_b2.get_reward_seed("maribo")) == int(seed_b["seed"]), "fresh-instance restore should preserve the reward seed (no re-randomization)")
	_expect(_deck_types(aff_b2.get_reward_deck("maribo")) == (seed_b["deck"] as Array), "fresh-instance restore should preserve the reward deck order")

	# 3) REVERSE VERIFICATION: strip affinity_run_state -> run state is NOT restored.
	#    Proves the re-import is the load-bearing lever (not some incidental path).
	var seed_c := _seed_runtime()
	var snap_c: Dictionary = (seed_c["runtime"] as Object).get_save_snapshot()
	snap_c.erase("affinity_run_state")
	var owner_c2 := _make_owner()
	var registry_c2 = Smoke.FakeRegistry.new()
	var runtime_c2: Object = LingpetEggRuntime.new()
	runtime_c2.apply_save_snapshot(snap_c, owner_c2, registry_c2)
	var aff_c2 = runtime_c2.get("_affinity_state")
	_expect(int(aff_c2.get_level("maribo")) == 0, "stripped snapshot must NOT restore affinity level (reverse check)")

	# 4) Per-run-restart invariant: a volatile (active-run) snapshot is NOT written to
	#    disk -- the store clears the file -- so a game restart still resets the run even
	#    though the snapshot now carries affinity_run_state.
	var store: Object = LingpetSaveStore.new()
	store.set_save_path("user://zz_test_lingpet_run_state.cfg")
	store.clear_snapshot("test_setup")
	var volatile_snapshot: Dictionary = (seed_data["runtime"] as Object).get_save_snapshot()
	store.save_snapshot(volatile_snapshot)
	_expect(str(store.last_save_summary) == "cleared_run_state", "an active-run snapshot (now carrying affinity_run_state) must still take the volatile-clear path, not be written to disk")
	_expect(store.load_snapshot().is_empty(), "disk snapshot must be empty after saving a volatile run snapshot (per-run restart reset preserved)")
	store.clear_snapshot("test_cleanup")

	# 5) P3 user-flow regression: the actual in-battle slot switch (a -> b -> a) must keep
	#    per-pet affinity DISTINCT and PRESERVED across both
	#    switches. This is the exact path the TAB lingpet tabs drive (switch_lingpet_slot).
	var owner_s := _make_owner()
	var registry_s = Smoke.FakeRegistry.new()
	var runtime_s: Object = LingpetEggRuntime.new()
	runtime_s.update(0.0, owner_s, registry_s)                 # adopt maribo (slot 0)
	runtime_s.update(0.0, owner_s, registry_s)
	for _i in range(12):
		runtime_s.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, registry_s)
	var aff_s = runtime_s.get("_affinity_state")
	var maribo_level: int = int(aff_s.get_level("maribo"))
	# switch to lunabi (slot 1), give it a smaller, DISTINCT affinity
	_expect(runtime_s.switch_lingpet_slot(1, owner_s, registry_s), "switch to lunabi slot should succeed")
	for _i in range(4):
		runtime_s.debug_add_affinity_points_for_tests("lunabi", LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, registry_s)
	var lunabi_points: float = float(aff_s.get_points("lunabi"))
	# switch back to maribo (slot 0)
	_expect(runtime_s.switch_lingpet_slot(0, owner_s, registry_s), "switch back to maribo slot should succeed")
	runtime_s.update(0.0, owner_s, registry_s)
	_expect(int(aff_s.get_level("maribo")) == maribo_level, "maribo affinity must be preserved after a/b/a switch")
	_expect(int(owner_s.lingpet_affinity_level) == maribo_level, "owner display must show maribo's affinity after switch back")
	_expect(is_equal_approx(float(aff_s.get_points("lunabi")), lunabi_points), "lunabi affinity must stay per-pet distinct, untouched by maribo")

	_cleanup_runtime(seed_data.get("runtime", null) as Object)
	_cleanup_runtime(seed_b.get("runtime", null) as Object)
	_cleanup_runtime(runtime_b2)
	_cleanup_runtime(seed_c.get("runtime", null) as Object)
	_cleanup_runtime(runtime_c2)
	_cleanup_runtime(runtime_s)
	ProjectResourceLoader.clear_caches()

	if _failed:
		quit(1)
		return
	print("lingpet_affinity_run_state_save_restore_smoke: ok")
	quit(0)


func _cleanup_runtime(runtime: Object) -> void:
	if runtime != null and runtime.has_method("reset_for_tests"):
		runtime.reset_for_tests()
