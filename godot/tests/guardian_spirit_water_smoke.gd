extends SceneTree

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemEffectRouter := preload("res://scripts/items/active_item_effect_router.gd")
const ActiveItemEffectActionFacade := preload("res://scripts/items/active_item_effect_action_facade.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
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


class FakeFeedback:
	extends RefCounted

	var audio_calls := 0
	var feedback_calls := 0

	func play_first_audio(_registry: Object, _methods: Array) -> void:
		audio_calls += 1

	func trigger_registry_feedback(
		_registry: Object,
		_flash: bool,
		_hitstop: bool,
		_shake_strength: float,
		_shake_duration: float
	) -> void:
		feedback_calls += 1


class FakeSpiritWaterEffectController:
	extends RefCounted

	var calls := 0

	func apply_lingpet_spirit_water(_item_data: Dictionary, _owner: Object, _registry: Object) -> bool:
		calls += 1
		return true


func _init() -> void:
	_verify_owned_gate_and_mid_stage_acquisition()
	_verify_drop_success_and_stage_latch_lifecycle()
	_verify_full_pool_gate_and_stage_refill_order()
	_verify_save_restore_keeps_consumed_latch()
	_verify_hot_paths_use_cached_runtime_only()
	_verify_catalog_placeholder_and_localization()
	_verify_use_routing_and_full_recovery()
	_verify_overfill_is_preserved_on_use()

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
	var run_state: Dictionary = save_snapshot.get("guardian_run_state", {}) as Dictionary
	_expect(bool(run_state.get("spirit_water_dropped_this_stage", false)), "save snapshot must carry the consumed stage latch")
	var restored: Object = LingpetEggRuntime.new()
	restored.import_guardian_run_state(run_state)
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


func _verify_catalog_placeholder_and_localization() -> void:
	var catalog: Object = ActiveItemCatalog.new()
	var item_data: Dictionary = catalog.call("_build_lingpet_spirit_water")
	_expect(str(item_data.get("name", "")) == ITEM_NAME, "catalog must own the exact spirit-water id")
	_expect(str(item_data.get("display_name", "")) == "심령수", "catalog must expose the Korean player-facing name")
	_expect(str(item_data.get("effect", "")) == ITEM_NAME, "catalog and effect router must share one item identity")
	_expect(bool(item_data.get("consumable", false)), "spirit water must be a slot-stored consumable")
	_expect(ActiveItemCatalog.FIELD_SPAWN_ORDER.has(ITEM_NAME), "spirit water must enter the normal field candidate order")
	var icon_path := str(item_data.get("icon_path", ""))
	_expect(icon_path == "res://assets/sprites/items/lingpet_special_feed_icon.png", "only the approved special-feed placeholder may be wired")
	_expect(FileAccess.file_exists(icon_path), "the placeholder path must exist before runtime wiring")
	var localized_names := [
		LanguageSettingsData.ITEM_DISPLAY_EN.get(ITEM_NAME, ""),
		LanguageSettingsData.ITEM_DISPLAY_ZH.get(ITEM_NAME, ""),
		LanguageSettingsData.ITEM_DISPLAY_JA.get(ITEM_NAME, ""),
		LanguageSettingsData.ITEM_DISPLAY_ES.get(ITEM_NAME, ""),
		LanguageSettingsData.ITEM_DISPLAY_PT_BR.get(ITEM_NAME, ""),
		LanguageSettingsData.ITEM_DISPLAY_RU.get(ITEM_NAME, ""),
	]
	_expect(localized_names.all(func(value: Variant) -> bool: return str(value).strip_edges() != ""), "all six translated names plus Korean must be materialized")
	_expect(str(LanguageSettingsData.ACTIVE_ITEM_DESCRIPTION_EN.get(ITEM_NAME, "")).find("overfill") >= 0, "English item copy must disclose overfill preservation")
	var debug_source := FileAccess.get_file_as_string("res://scripts/items/active_item_debug_spawn_menu.gd")
	_expect(debug_source.find("\"lingpet_spirit_water\"") >= 0, "debug spawn inventory must expose the new item")


func _verify_use_routing_and_full_recovery() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	var owner: Object = _make_owner(true)
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var catalog: Object = ActiveItemCatalog.new()
	var item_data: Dictionary = catalog.call("_build_lingpet_spirit_water")
	var router: Object = ActiveItemEffectRouter.new()
	var fake_controller := FakeSpiritWaterEffectController.new()
	_expect(router.apply_item_effect(item_data, owner, registry, fake_controller, null), "effect router must dispatch spirit water")
	_expect(fake_controller.calls == 1, "effect router must invoke the dedicated controller method exactly once")

	var facade: Object = ActiveItemEffectActionFacade.new()
	var feedback := FakeFeedback.new()
	var no_guardian_owner: Object = _make_owner(false)
	runtime.set_duration_pool_for_tests(0.0, 60.0)
	_expect(not facade.apply_lingpet_spirit_water(null, item_data, no_guardian_owner, registry, feedback), "missing guardian must reject use without consuming the slot")
	_expect(is_equal_approx(runtime.get_duration_pool_current(), 0.0), "rejected use must not mutate duration")
	_expect(facade.apply_lingpet_spirit_water(null, item_data, owner, registry, feedback), "empty pool use must be accepted")
	_expect(is_equal_approx(runtime.get_duration_pool_current(), 60.0), "empty pool use must restore the pool to maximum")
	_expect(feedback.audio_calls == 1 and feedback.feedback_calls == 1, "accepted use must emit one standard active-item feedback cue")
	_expect(facade.apply_lingpet_spirit_water(null, item_data, owner, registry, feedback), "full-pool no-op must still count as a consumed use")
	_expect(is_equal_approx(runtime.get_duration_pool_current(), 60.0), "full-pool no-op must remain at maximum")
	_expect(registry.lazy_lookup_count == 0, "spirit-water use must consume the prewarmed runtime owner without lazy construction")
	runtime.reset_for_tests()


func _verify_overfill_is_preserved_on_use() -> void:
	var runtime: Object = LingpetEggRuntime.new()
	var owner: Object = _make_owner(true)
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	runtime.set_duration_pool_for_tests(60.0, 60.0)
	var fallback: Dictionary = runtime.apply_guardian_enhance_duration_fallback(owner, registry)
	_expect(bool(fallback.get("accepted", false)), "counterexample fixture must create the +15-second overfill")
	_expect(is_equal_approx(runtime.get_duration_pool_current(), 75.0), "overfill fixture must exceed pool maximum by 15 seconds")
	var before: float = float(runtime.get_duration_pool_current())
	var result: Dictionary = runtime.use_spirit_water(owner, registry)
	_expect(bool(result.get("accepted", false)), "overfill use remains consumable")
	_expect(is_equal_approx(runtime.get_duration_pool_current(), before), "max(current, pool_max) must preserve overfill exactly")
	_expect(bool(result.get("overfill_preserved", false)), "recovery result must explicitly report the preserved overfill leg")
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
