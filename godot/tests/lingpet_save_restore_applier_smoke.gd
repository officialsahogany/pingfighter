extends SceneTree

const LingpetSaveRestoreApplier := preload("res://scripts/lingpet/lingpet_save_restore_applier.gd")

const STATE_NONE := "none"
const STATE_EGG := "egg"
const STATE_COMPANION := "companion"


class FakeEggState:
	extends RefCounted

	var hatched_hits := 0

	func set_hatched(required_hits: int) -> void:
		hatched_hits = required_hits


class FakeMotionState:
	extends RefCounted

	var pos := Vector2.ZERO


class FakeHost:
	extends RefCounted

	var _state := STATE_NONE
	var _pet_id := "maribo"
	var _companion_pos := Vector2.ZERO
	var _companion_motion_state := FakeMotionState.new()
	var _egg_state := FakeEggState.new()
	var reset_calls := 0
	var sync_calls: Array[Dictionary] = []
	var set_pet_ids: Array[String] = []
	var loadout_calls := 0
	var restore_patrol_calls := 0
	var init_patrol_calls := 0
	var marked_owned_calls := 0
	var spawn_egg_calls := 0
	var clear_field_calls := 0
	var vector2_calls := 0
	var normalize_calls := 0

	func reset_for_tests() -> void:
		reset_calls += 1
		_state = STATE_NONE

	func _sync_owner(owner: Object, registry: Object = null) -> void:
		sync_calls.append({
			"owner": owner,
			"registry": registry,
		})

	func _set_current_pet_id(pet_id: String) -> void:
		_pet_id = pet_id
		set_pet_ids.append(pet_id)

	func _normalize_lingpet_state(value: String) -> String:
		normalize_calls += 1
		return value if [STATE_NONE, STATE_EGG, STATE_COMPANION].has(value) else STATE_NONE

	func _apply_current_loadout(_owner: Object, _force: bool, _allow_reconcile: bool, _registry: Object = null) -> void:
		loadout_calls += 1

	func _get_current_required_hits() -> int:
		return 3

	func _get_vector2_from_variant(value: Variant, fallback: Vector2) -> Vector2:
		vector2_calls += 1
		return value if value is Vector2 else fallback

	func _restore_companion_patrol(_snapshot: Dictionary) -> void:
		restore_patrol_calls += 1

	func _initialize_companion_patrol(_owner: Object, _force: bool) -> void:
		init_patrol_calls += 1

	func _mark_current_pet_owned(_owner: Object) -> void:
		marked_owned_calls += 1

	func _spawn_egg(_owner: Object) -> void:
		spawn_egg_calls += 1
		_state = STATE_EGG

	func _clear_lingpet_field_state() -> void:
		clear_field_calls += 1
		_state = STATE_NONE


class FakeLoadoutState:
	extends RefCounted

	var loadouts: Dictionary = {}

	func set_loadouts(value: Variant) -> void:
		loadouts = (value as Dictionary).duplicate(true) if value is Dictionary else {}


class FakeCollectionState:
	extends RefCounted

	var owned_pet_ids: Array[String] = []
	var ensure_calls := 0
	var ensure_last_pet_id := ""

	func get_owned_pet_ids() -> Array[String]:
		return owned_pet_ids.duplicate()

	# Current ownership-republish path on companion restore: the applier calls this
	# instead of the old host._mark_current_pet_owned hook.
	func ensure_pet_active_slot(_owner: Object, pet_id: String) -> String:
		ensure_calls += 1
		ensure_last_pet_id = pet_id
		if not owned_pet_ids.has(pet_id):
			owned_pet_ids.append(pet_id)
		return pet_id


class FakePlanner:
	extends RefCounted

	var plan: Dictionary = {}
	var build_calls := 0
	var last_current_pet_id := ""
	var last_restored_state := ""

	func build_plan(_snapshot: Dictionary, _owner: Object, _collection_state: Object, current_pet_id: String, restored_state: String) -> Dictionary:
		build_calls += 1
		last_current_pet_id = current_pet_id
		last_restored_state = restored_state
		return plan.duplicate(true)


func _restore_callbacks_for_host(host: FakeHost) -> Dictionary:
	return {
		"clear_field_state": Callable(host, "_clear_lingpet_field_state"),
		"restore_companion_patrol": Callable(host, "_restore_companion_patrol"),
	}


var _failures: Array[String] = []


func _init() -> void:
	_verify_empty_snapshot_syncs_after_reset()
	_verify_companion_restore_applies_plan_and_runtime_hooks()
	_verify_egg_and_none_branches_delegate_to_runtime_hooks()
	_verify_runtime_delegates_apply_choreography()

	if _failures.is_empty():
		print("lingpet_save_restore_applier_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_empty_snapshot_syncs_after_reset() -> void:
	var host := FakeHost.new()
	var owner := RefCounted.new()
	var registry := RefCounted.new()
	var result: Dictionary = LingpetSaveRestoreApplier.new().apply(
		{},
		owner,
		registry,
		host,
		FakeCollectionState.new(),
		FakeLoadoutState.new(),
		FakePlanner.new(),
		"maribo",
		STATE_NONE,
		STATE_EGG,
		STATE_COMPANION,
		_restore_callbacks_for_host(host)
	)
	_expect(not bool(result.get("restored", true)), "empty snapshot should report restored=false")
	_expect_str(str(result.get("reason", "")), "empty_snapshot", "empty snapshot should report the stable reason")
	_expect_eq(host.reset_calls, 1, "empty snapshot should still reset runtime first")
	_expect_eq(host.sync_calls.size(), 1, "empty snapshot should sync the owner once")
	_expect(host.sync_calls[0].get("registry", null) == registry, "empty snapshot sync should preserve the registry argument")


func _verify_companion_restore_applies_plan_and_runtime_hooks() -> void:
	var host := FakeHost.new()
	var collection := FakeCollectionState.new()
	collection.owned_pet_ids = ["lunabi"]
	var loadout := FakeLoadoutState.new()
	var planner := FakePlanner.new()
	planner.plan = {
		"target_state": STATE_COMPANION,
		"pet_id": "lunabi",
		"restore_reason": "ok",
	}
	var owner := RefCounted.new()
	var registry := RefCounted.new()
	var result: Dictionary = LingpetSaveRestoreApplier.new().apply(
		{
			"pet_id": "maribo",
			"state": "hatched",
			"companion_pos": Vector2(123.0, 456.0),
			"lingpet_loadouts": {"lunabi": {"active_skill_id": "rabi_ghost_summon"}},
		},
		owner,
		registry,
		host,
		collection,
		loadout,
		planner,
		"maribo",
		STATE_NONE,
		STATE_EGG,
		STATE_COMPANION,
		_restore_callbacks_for_host(host)
	)
	_expect(bool(result.get("restored", false)), "companion restore should report restored=true")
	_expect_str(str(result.get("state", "")), STATE_COMPANION, "companion restore should return the final state")
	_expect_eq(planner.build_calls, 1, "restore applier should ask the planner exactly once")
	_expect_str(planner.last_current_pet_id, "maribo", "planner should receive the snapshot pet after initial normalization")
	_expect_str(planner.last_restored_state, STATE_COMPANION, "planner should normalize companion aliases before planning")
	_expect_eq(host.normalize_calls, 0, "save-restore applier should own state alias normalization instead of calling the runtime private hook")
	_expect_str(host._pet_id, "lunabi", "companion restore should apply the planner pet id")
	_expect_eq(host.loadout_calls, 1, "companion restore should apply the current loadout once")
	_expect_eq(host._egg_state.hatched_hits, 3, "companion restore should mark the egg hatched with current required hits")
	_expect_eq(host._companion_pos, Vector2(123.0, 456.0), "companion restore should restore companion position")
	_expect_eq(host._companion_motion_state.pos, Vector2(123.0, 456.0), "companion restore should sync motion-state position")
	_expect_eq(host.vector2_calls, 0, "save-restore applier should use the vector resolver instead of the runtime private vector hook")
	_expect_eq(host.restore_patrol_calls, 1, "companion restore should restore patrol snapshot")
	_expect_eq(host.init_patrol_calls, 1, "companion restore should initialize patrol when owner exists")
	_expect_eq(collection.ensure_calls, 1, "companion restore should republish current pet ownership via ensure_pet_active_slot")
	_expect_str(collection.ensure_last_pet_id, "lunabi", "ownership republish should target the restored companion pet")
	_expect_eq(host.sync_calls.size(), 1, "companion restore should sync owner once after applying state")
	_expect(host.sync_calls[0].get("registry", null) == null, "final restore sync should preserve the old no-registry call shape")
	_expect(loadout.loadouts.has("lunabi"), "restore applier should load persisted lingpet loadouts before planning completes")
	_expect((result.get("owned_pet_ids", []) as Array).has("lunabi"), "restore result should expose collection-owned pet ids")


func _verify_egg_and_none_branches_delegate_to_runtime_hooks() -> void:
	var egg_host := FakeHost.new()
	var egg_planner := FakePlanner.new()
	egg_planner.plan = {
		"target_state": STATE_EGG,
		"pet_id": "maribo",
		"restore_reason": "egg_reset_on_entry",
		"spawn_fresh_egg": true,
	}
	var egg_result: Dictionary = LingpetSaveRestoreApplier.new().apply(
		{"state": "hatching"},
		RefCounted.new(),
		null,
		egg_host,
		FakeCollectionState.new(),
		FakeLoadoutState.new(),
		egg_planner,
		"maribo",
		STATE_NONE,
		STATE_EGG,
		STATE_COMPANION,
		_restore_callbacks_for_host(egg_host)
	)
	_expect_str(str(egg_result.get("state", "")), STATE_EGG, "fresh-egg plan should return egg state")
	_expect_str(egg_planner.last_restored_state, STATE_EGG, "restore applier should normalize egg aliases before planning")
	_expect_eq(egg_host.spawn_egg_calls, 1, "fresh-egg plan should call the runtime egg spawner")

	var none_host := FakeHost.new()
	var none_planner := FakePlanner.new()
	none_planner.plan = {
		"target_state": STATE_NONE,
		"pet_id": "maribo",
	}
	var none_result: Dictionary = LingpetSaveRestoreApplier.new().apply(
		{"state": STATE_COMPANION},
		RefCounted.new(),
		null,
		none_host,
		FakeCollectionState.new(),
		FakeLoadoutState.new(),
		none_planner,
		"maribo",
		STATE_NONE,
		STATE_EGG,
		STATE_COMPANION,
		_restore_callbacks_for_host(none_host)
	)
	_expect_str(str(none_result.get("state", "")), STATE_NONE, "none plan should return none state")
	_expect_eq(none_host.clear_field_calls, 1, "none plan should call the runtime field clearer")


func _verify_runtime_delegates_apply_choreography() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var applier_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_save_restore_applier.gd")
	_expect(runtime_source.find("LingpetSaveRestoreApplier") >= 0, "egg runtime should preload the save-restore applier")
	_expect(runtime_source.find("_save_restore_applier.apply") >= 0, "egg runtime apply_save_snapshot should delegate to the applier")
	_expect(runtime_source.find("restore_plan: Dictionary") < 0, "egg runtime should not keep restore-plan application choreography inline")
	_expect(runtime_source.find("func _get_vector2_from_variant") < 0, "egg runtime should not keep the old private Vector2 coercion wrapper")
	_expect(runtime_source.find("func _normalize_lingpet_state") < 0, "egg runtime should not keep the old private state-normalization wrapper")
	_expect(applier_source.find("LingpetRuntimeVectorResolver") >= 0, "applier should own companion-position Vector2 coercion through the shared resolver")
	_expect(applier_source.find("host.has_method(\"_get_vector2_from_variant\")") < 0, "applier should not call the runtime private Vector2 hook")
	_expect(applier_source.find("host.has_method(\"_normalize_lingpet_state\")") < 0, "applier should not call the runtime private state-normalization hook")
	_expect(applier_source.find("host.has_method(\"_clear_lingpet_field_state\")") < 0, "applier should use explicit callbacks instead of dynamically probing the field-clear hook")
	_expect(applier_source.find("host.has_method(\"_restore_companion_patrol\")") < 0, "applier should use explicit callbacks instead of dynamically probing the patrol-restore hook")
	_expect(runtime_source.find("Callable(self, \"_clear_lingpet_field_state\")") >= 0, "egg runtime should explicitly pass the field-clear restore callback")
	_expect(runtime_source.find("Callable(self, \"_restore_companion_patrol\")") >= 0, "egg runtime should explicitly pass the patrol-restore callback")
	_expect(applier_source.find("\"hatching\"") >= 0 and applier_source.find("\"hatched\"") >= 0, "applier should preserve legacy save-state aliases")
	_expect(applier_source.find("spawn_fresh_egg") >= 0, "applier should own the fresh-egg restore branch")
	_expect(applier_source.find("_apply_companion_restore") >= 0, "applier should own companion restore choreography")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected '%s', got '%s')" % [message, expected, actual])
