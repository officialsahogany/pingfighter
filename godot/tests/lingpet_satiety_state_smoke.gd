extends SceneTree

# Transitional compatibility seal. The production filename/API still says
# satiety until §9-4, while the behavior is the §9-3 run-shared duration pool.
const Smoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")

var _failures: Array[String] = []


class SchemaGatedOwner:
	extends RefCounted

	var scene_state: Object = BattleSceneState.new()

	func _init() -> void:
		scene_state.reset()

	func _get(property: StringName) -> Variant:
		var key := str(property)
		return scene_state.get_value(key) if scene_state.has_key(key) else null

	func _set(property: StringName, value: Variant) -> bool:
		var key := str(property)
		if not scene_state.has_key(key):
			return false
		scene_state.set_value(key, value)
		return true

	func queue_redraw() -> void:
		pass


func _init() -> void:
	_verify_runtime_shared_drain_and_stow_recovery()
	_verify_save_restore_uses_run_global_schema()
	_verify_owner_schema_and_stage_only_refill()
	_verify_expiry_gate_and_junior_exemption()
	_verify_warning_renderer_transition_contract()

	if _failures.is_empty():
		print("lingpet_satiety_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_runtime_shared_drain_and_stow_recovery() -> void:
	var owner := _make_owner()
	var runtime: Object = LingpetEggRuntime.new()
	var registry := Smoke.FakeRegistry.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry), "fixture should activate a guardian")
	runtime.set_duration_pool_for_tests(60.0, 60.0)
	runtime.update(12.0, owner, registry)
	_expect_float(runtime.get_duration_pool_current(), 48.0, "summoned guardian should drain one-to-one")
	_expect_float(runtime.get_satiety("lunabi"), 48.0, "legacy pet-id facade should read the same shared pool")
	runtime.set("_guardian_stowed", true)
	runtime.update(3.0, owner, registry)
	_expect_float(runtime.get_duration_pool_current(), 49.0, "stowed guardian should recover at one-third speed")
	_cleanup_runtime(runtime)


func _verify_save_restore_uses_run_global_schema() -> void:
	var owner := _make_owner()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.debug_grant_and_activate_pet("maribo", owner)
	runtime.set_duration_pool_for_tests(23.0, 71.0)
	var snapshot: Dictionary = runtime.get_save_snapshot()
	var run_state: Dictionary = snapshot.get("affinity_run_state", {}) as Dictionary
	_expect_float(float(run_state.get("duration_pool", -1.0)), 23.0, "save should carry duration_pool")
	_expect_float(float(run_state.get("duration_pool_max", -1.0)), 71.0, "save should carry duration_pool_max")
	var pets: Dictionary = run_state.get("pets", {}) as Dictionary
	for raw_pet in pets.values():
		if raw_pet is Dictionary:
			_expect(not (raw_pet as Dictionary).has("satiety"), "per-pet save entries must not retain satiety")

	var restored: Object = LingpetEggRuntime.new()
	restored.apply_save_snapshot(snapshot, _make_owner(), Smoke.FakeRegistry.new())
	_expect_float(restored.get_duration_pool_current(), 23.0, "restore should preserve the shared current pool")
	_expect_float(restored.get_duration_pool_max(), 71.0, "restore should preserve the run roll")
	_cleanup_runtime(runtime)
	_cleanup_runtime(restored)


func _verify_owner_schema_and_stage_only_refill() -> void:
	for key in ["lingpet_duration_pool_pct", "ringpet_duration_pool_pct"]:
		_expect(BattleSceneState.DEFAULT_VALUES.has(key), "BattleSceneState should declare %s" % key)
	var owner := _make_schema_owner()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.debug_grant_and_activate_pet("maribo", owner)
	runtime.set_duration_pool_for_tests(45.0, 60.0)
	runtime.update(0.0, owner)
	_expect_eq(int(owner.get("lingpet_duration_pool_pct")), 75, "schema-gated owner should receive the live duration percent")
	_expect_eq(int(owner.get("ringpet_duration_pool_pct")), 75, "compatibility owner pair should receive the same percent")
	runtime.reset_round({"owner": owner})
	_expect_float(runtime.get_duration_pool_current(), 45.0, "ordinary reset_round must not refill duration")
	_expect(runtime.refill_guardian_duration_for_stage_transition(), "real stage transition should report a refill")
	_expect_float(runtime.get_duration_pool_current(), 60.0, "real stage transition should refill to the rolled maximum")
	_cleanup_runtime(runtime)


func _verify_expiry_gate_and_junior_exemption() -> void:
	var owner := _make_owner()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.debug_grant_and_activate_pet("maribo", owner)
	runtime.set_duration_pool_for_tests(0.5, 60.0)
	runtime.set("_guardian_stowed", false)
	runtime.update(1.0, owner)
	_expect(runtime.is_guardian_stowed(), "zero crossing should force stow immediately")
	_expect(not runtime.can_resummon_guardian(), "expired guardian should remain locked")
	runtime.update(30.0, owner)
	_expect_float(runtime.get_duration_pool_current(), 10.0, "stow recovery should reach exactly ten after thirty seconds")
	_expect(not runtime.can_resummon_guardian(), "exactly ten seconds should remain below the strict gate")
	runtime.update(0.03, owner)
	_expect(runtime.can_resummon_guardian(), "recovery above ten seconds should reopen summon")
	_cleanup_runtime(runtime)

	var junior_owner := _make_owner()
	junior_owner.ai_mode = "junior"
	var junior: Object = LingpetEggRuntime.new()
	junior.debug_grant_and_activate_pet("maribo", junior_owner)
	junior.set_duration_pool_for_tests(60.0, 60.0)
	junior.set("_guardian_stowed", false)
	junior.update(10.0, junior_owner)
	_expect_float(junior.get_duration_pool_current(), 60.0, "junior auto-present league should be drain-exempt")
	_cleanup_runtime(junior)


func _verify_warning_renderer_transition_contract() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var dispatcher_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_audio_dispatcher.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_renderer.gd")
	_expect(runtime_source.find("DURATION_WARNING_STAGE_COUNT := 3") >= 0, "duration warning should expose three stages")
	_expect(dispatcher_source.find("play_lingpet_duration_warning") >= 0, "duration warning should expose an optional audio hook")
	_expect(renderer_source.find("_draw_satiety_exhaustion_telegraph") >= 0, "legacy renderer path should carry the warning motion until HUD restyle")


func _make_owner() -> Object:
	var owner := Smoke.FakeOwner.new()
	owner.ai_mode = "champion"
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


func _make_schema_owner() -> Object:
	var owner := SchemaGatedOwner.new()
	owner.set("ai_mode", "champion")
	owner.set("lingpet_owned_pet_ids", ["maribo", "lunabi"])
	owner.set("owned_lingpet_ids", ["maribo", "lunabi"])
	owner.set("owned_ringpet_ids", ["maribo", "lunabi"])
	owner.set("lingpet_slots", ["maribo", "lunabi", ""])
	owner.set("ringpet_slots", ["maribo", "lunabi", ""])
	owner.set("lingpet_slot_pet_ids", ["maribo", "lunabi", ""])
	owner.set("ringpet_slot_pet_ids", ["maribo", "lunabi", ""])
	owner.set("lingpet_active_slot_index", 0)
	owner.set("ringpet_active_slot_index", 0)
	return owner


func _cleanup_runtime(runtime: Object) -> void:
	if runtime != null and runtime.has_method("reset_for_tests"):
		runtime.reset_for_tests()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])
