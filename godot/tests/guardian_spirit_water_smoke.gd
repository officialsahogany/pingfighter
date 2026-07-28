extends SceneTree

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const LingpetEggRuntimeSmoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")

const ITEM_NAME := "lingpet_spirit_water"

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var lazy_lookup_count := 0

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_cached_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if value is Object else null

	func get_instance(_key: String) -> Object:
		lazy_lookup_count += 1
		return null


class ReleasedSpiritWaterPortal:
	extends RefCounted

	var released := false

	func release_pending_spawn_items() -> Array[Dictionary]:
		if released:
			return []
		released = true
		return [{
			"item_data": {"name": ITEM_NAME},
			"position": Vector2(240.0, 360.0),
		}]


func _init() -> void:
	_verify_owned_gate_and_mid_stage_acquisition()
	_verify_drop_success_and_stage_latch_lifecycle()
	_verify_full_pool_gate_and_stage_refill_order()
	_verify_save_restore_keeps_consumed_latch()
	_verify_hot_paths_use_cached_runtime_only()

	if _failures.is_empty():
		print("guardian_spirit_water_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_owned_gate_and_mid_stage_acquisition() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	var owner: Object = _make_owner(false)
	runtime.set_duration_pool_for_tests(20.0, 60.0)
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var pool: Object = ActiveItemFieldSpawnPool.new()
	var item_data := {"name": ITEM_NAME}
	_expect(
		bool(pool.call("_should_skip_active_spawn_candidate", item_data, registry, owner)),
		"an owner without a guardian must not receive spirit water candidates"
	)
	_set_owned_guardian(owner)
	_expect(
		not bool(pool.call("_should_skip_active_spawn_candidate", item_data, registry, owner)),
		"first guardian ownership gained mid-stage must immediately unlock an eligible candidate"
	)
	runtime.reset_for_tests()


func _verify_drop_success_and_stage_latch_lifecycle() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	var owner: Object = _make_owner(true)
	runtime.set_duration_pool_for_tests(20.0, 60.0)
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	_expect(runtime.mark_spirit_water_drop_pending(), "eligible portal queue should mark one pending spirit water")
	var pending: Dictionary = runtime.get_spirit_water_drop_snapshot_for_tests()
	_expect(bool(pending.get("drop_pending", false)), "portal queue must be pending before field materialization")
	_expect(not bool(pending.get("drop_consumed", true)), "candidate/queue entry must not consume the stage latch")

	var controller: Object = ActiveItemFieldSpawnController.new()
	controller.spawn_portals = ReleasedSpiritWaterPortal.new()
	controller.call("_release_pending_spawn_items", registry)
	var dropped: Dictionary = runtime.get_spirit_water_drop_snapshot_for_tests()
	_expect(bool(dropped.get("drop_consumed", false)), "actual field materialization must consume the stage latch")
	_expect(not bool(dropped.get("drop_pending", true)), "successful field drop must clear pending state")
	_expect(not runtime.can_offer_spirit_water_drop(owner), "an unpicked or later-despawned field drop must not become eligible again")

	runtime.reset_round()
	_expect(not runtime.can_offer_spirit_water_drop(owner), "reset_round must never rearm a consumed spirit-water latch")
	runtime.reset_for_tests()


func _verify_full_pool_gate_and_stage_refill_order() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	var owner: Object = _make_owner(true)
	runtime.set_duration_pool_for_tests(15.0, 60.0)
	_expect(runtime.can_offer_spirit_water_drop(owner), "spent duration should satisfy the pool gate")
	runtime.mark_spirit_water_drop_pending()
	runtime.mark_spirit_water_field_drop_succeeded()
	_expect(runtime.refill_guardian_duration_for_stage_transition(), "stage transition should refill a spent pool")
	_expect(is_equal_approx(runtime.get_duration_pool_current(), 60.0), "stage transition must refill before rearming")
	var stage_snapshot: Dictionary = runtime.get_spirit_water_drop_snapshot_for_tests()
	_expect(not bool(stage_snapshot.get("drop_consumed", true)), "real stage transition must rearm the latch")
	_expect(not runtime.can_offer_spirit_water_drop(owner), "refill-complete pool must hold the rearmed latch without wasting a drop")
	runtime.set_duration_pool_for_tests(59.0, 60.0)
	_expect(runtime.can_offer_spirit_water_drop(owner), "the rearmed latch must enter candidates only after duration is spent")
	runtime.set_duration_pool_for_tests(75.0, 60.0)
	_expect(not runtime.can_offer_spirit_water_drop(owner), "overfill must also remain outside the drop candidate pool")
	runtime.reset_for_tests()


func _verify_save_restore_keeps_consumed_latch() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	var owner: Object = _make_owner(true)
	runtime.set_duration_pool_for_tests(20.0, 60.0)
	runtime.mark_spirit_water_drop_pending()
	runtime.mark_spirit_water_field_drop_succeeded()
	var save_snapshot: Dictionary = runtime.get_save_snapshot()
	var run_state: Dictionary = save_snapshot.get("affinity_run_state", {}) as Dictionary
	_expect(bool(run_state.get("spirit_water_dropped_this_stage", false)), "save snapshot must carry the consumed stage latch")
	var restored: Object = LingpetEggRuntime.new()
	restored.import_affinity_run_state(run_state)
	_expect(not restored.can_offer_spirit_water_drop(owner), "restore must not duplicate a consumed same-stage drop")
	runtime.reset_for_tests()
	restored.reset_for_tests()


func _verify_hot_paths_use_cached_runtime_only() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	var owner: Object = _make_owner(true)
	runtime.set_duration_pool_for_tests(20.0, 60.0)
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var pool: Object = ActiveItemFieldSpawnPool.new()
	pool.call("_should_skip_active_spawn_candidate", {"name": ITEM_NAME}, registry, owner)
	_expect(registry.lazy_lookup_count == 0, "spirit-water candidate gating must never lazy-create runtime owners")
	var queue_source := FileAccess.get_file_as_string("res://scripts/items/active_item_field_spawn_queue.gd")
	var controller_source := FileAccess.get_file_as_string("res://scripts/items/active_item_field_spawn_controller.gd")
	_expect(queue_source.find("_mark_spirit_water_drop_pending(item_data, registry)") >= 0, "both portal queue paths must mark the natural drop pending")
	_expect(queue_source.count("_mark_spirit_water_drop_pending(item_data, registry)") == 2, "regular and dimension queues must share the pending latch")
	_expect(controller_source.find("_notify_spirit_water_drop_succeeded(field_item, registry)") >= 0, "field release must own successful-drop latch consumption")
	runtime.reset_for_tests()


func _make_owner(owned: bool) -> Object:
	var owner := LingpetEggRuntimeSmoke.FakeOwner.new()
	if owned:
		_set_owned_guardian(owner)
	return owner


func _set_owned_guardian(owner: Object) -> void:
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.owned_lingpet_ids = ["maribo"]
	owner.owned_ringpet_ids = ["maribo"]
	owner.lingpet_slots = ["maribo", "", ""]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
