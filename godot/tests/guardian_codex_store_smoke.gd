extends SceneTree

const GuardianCodexStore := preload(
	"res://scripts/lingpet/guardian_codex_store.gd"
)
const GuardianCodexDiscoveryRecorder := preload(
	"res://scripts/lingpet/guardian_codex_discovery_recorder.gd"
)
const LingpetCollectionState := preload(
	"res://scripts/lingpet/lingpet_collection_state.gd"
)
const LingpetEggRuntime := preload(
	"res://scripts/lingpet/lingpet_egg_runtime.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	var save_path := "user://guardian_codex_store_%d.cfg" % Time.get_ticks_usec()
	var store := GuardianCodexStore.new()
	store.set_save_path(save_path)
	_expect(store.clear(), "guardian codex fixture must start empty")
	_verify_immediate_persistence_and_idempotency(store, save_path)
	_verify_run_state_is_separate(store)
	_verify_feature_flag_and_live_reveal_hook(store)
	_expect(store.clear(), "guardian codex fixture must remove its save")
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("guardian_codex_store_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_immediate_persistence_and_idempotency(store: Object, save_path: String) -> void:
	_expect(store.get_first_seen_pet_ids().is_empty(), "missing save must start with no persistent discoveries")
	var first: Dictionary = store.record_first_seen("maribo", "guardian:first_seen:maribo")
	_expect(bool(first.get("accepted", false)), "first reveal must be accepted")
	_expect(bool(first.get("changed", false)), "first reveal must add the pet to the meta codex")
	_expect(FileAccess.file_exists(save_path), "first reveal must persist before the reveal call returns")
	var restored := GuardianCodexStore.new()
	restored.set_save_path(save_path)
	_expect(restored.load(), "fresh codex owner must load the immediate commit")
	_expect(restored.get_first_seen_pet_ids() == ["maribo"], "fresh codex owner must retain the revealed identity")
	var replay: Dictionary = restored.record_first_seen("maribo", "guardian:first_seen:maribo")
	_expect(bool(replay.get("accepted", false)), "same discovery id replay must be accepted idempotently")
	_expect(not bool(replay.get("changed", true)), "same discovery id replay must not duplicate the discovery")
	var conflict: Dictionary = restored.record_first_seen("lunabi", "guardian:first_seen:maribo")
	_expect(not bool(conflict.get("accepted", true)), "one discovery id must not commit a different identity")
	_expect(str(conflict.get("reason", "")) == "discovery_id_conflict", "id conflict must fail loudly")


func _verify_run_state_is_separate(store: Object) -> void:
	var run_collection := LingpetCollectionState.new()
	run_collection.set_collected_pet_ids(["maribo"])
	run_collection.reset()
	_expect(run_collection.get_collected_pet_ids().is_empty(), "new-run reset must still clear run collected ids")
	_expect(store.get_first_seen_pet_ids() == ["maribo"], "run reset or defeat must not erase meta first-seen ids")


func _verify_feature_flag_and_live_reveal_hook(store: Object) -> void:
	var registry := FakeRegistry.new()
	registry.instances[GuardianCodexDiscoveryRecorder.STORE_KEY] = store
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var legacy: Dictionary = GuardianCodexDiscoveryRecorder.record_identity_reveal(registry, "lunabi")
	_expect(str(legacy.get("reason", "")) == "legacy_bypass", "flag OFF must preserve the legacy non-persistent reveal path")
	_expect(not store.has_first_seen("lunabi"), "flag OFF must not mutate the new meta codex")
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var missing: Dictionary = GuardianCodexDiscoveryRecorder.record_identity_reveal(
		FakeRegistry.new(),
		"lunabi"
	)
	_expect(not bool(missing.get("accepted", true)), "flag ON without the registered meta owner must fail closed")
	_expect(str(missing.get("reason", "")) == "missing_guardian_codex_store", "missing meta owner must report the exact wiring failure")
	var runtime := LingpetEggRuntime.new()
	var recorded_value: Variant = runtime.call("_record_guardian_discovery_at_reveal", "lunabi", registry)
	var recorded: Dictionary = recorded_value if recorded_value is Dictionary else {}
	_expect(bool(recorded.get("changed", false)), "the live egg runtime reveal hook must commit through the registry store")
	var restored := GuardianCodexStore.new()
	restored.set_save_path(str(store.get_summary().get("save_path", "")))
	_expect(restored.load(), "live reveal commit must be readable from a fresh store")
	_expect(restored.get_first_seen_pet_ids() == ["lunabi", "maribo"], "live reveal must persist without waiting for run settlement")
	var module_source := FileAccess.get_file_as_string(
		"res://scripts/resources/gameplay_core_module_catalog.gd"
	)
	_expect(module_source.find('"guardian_codex_store"') >= 0, "production registry must own the independent guardian codex store")
	var runtime_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_egg_runtime.gd"
	)
	_expect(
		runtime_source.find("_record_guardian_discovery_at_reveal(hatched_item_egg_pet_id, registry)") >= 0,
		"item-egg identity reveal must commit before its acquisition cut-in"
	)
	_expect(
		runtime_source.count("_record_guardian_discovery_at_reveal(_pet_id, registry)") == 2,
		"regular and overflow hatch reveals must both commit the public identity"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
