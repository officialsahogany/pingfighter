extends SceneTree

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetFeedController := preload("res://scripts/lingpet/lingpet_feed_controller.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var lingpet_slots: Array = []
	var ringpet_slots: Array = []
	var lingpet_slot_pet_ids: Array = []
	var ringpet_slot_pet_ids: Array = []
	var lingpet_active_slot_index := -1
	var ringpet_active_slot_index := -1
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var ball_active := false

	func queue_redraw() -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_affinity_feed_source_removed()
	_verify_feed_controller_duration_gates_and_pending_amount()
	_verify_runtime_feed_restores_duration_after_bowl()
	_verify_expired_feed_unlocks_resummon_without_auto_summon()
	_verify_battle_cap_resets_only_on_new_battle()
	await _cleanup_runtime_resources()

	if _failures.is_empty():
		print("lingpet_feed_affinity_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_affinity_feed_source_removed() -> void:
	var state := LingpetAffinityState.new()
	state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	var result: Dictionary = state.add_points("maribo", "feed")
	_expect_float(float(result.get("granted_points", -1.0)), 0.0, "legacy feed source should no longer grant affinity")
	_expect_str(str(result.get("blocked_reason", "")), "unknown_source", "legacy feed source should be rejected as an affinity source")
	_expect_float(state.get_points("maribo"), 0.0, "legacy feed source must leave affinity points unchanged")

	var affinity_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_state.gd")
	_expect(affinity_source.find("SOURCE_FEED") < 0, "affinity state should not keep a feed affinity source")
	_expect(affinity_source.find("MAX_FEED_USES_PER_RUN") < 0, "affinity state should not keep the old run feed cap")
	_expect(affinity_source.find("_feed_uses_this_run") < 0, "affinity state should not export/import old feed counters")
	_expect(affinity_source.find("max_feed_level") < 0, "ring-core feed affinity cap should be superseded")
	_expect(
		affinity_source.find("var enhancement_multiplier := 1.0 if source == SOURCE_RING_CORE_UPGRADE else get_enhancement_chip_multiplier()") >= 0,
		"only ring-core-upgrade should remain chip-exempt after feed stops granting affinity"
	)


func _verify_feed_controller_duration_gates_and_pending_amount() -> void:
	var controller := LingpetFeedController.new()
	var state := LingpetAffinityState.new()
	var owner := FakeOwner.new()
	var registry_token := RefCounted.new()
	state.set_satiety("maribo", 60.0)

	var missing: Dictionary = controller.request("", owner, Vector2(250.0, 700.0), "patrol", state, false, registry_token, 20.0)
	_expect_str(str(missing.get("blocked_reason", "")), "missing_lingpet", "feed controller should own the missing-pet request gate")
	var invalid: Dictionary = controller.request("maribo", owner, Vector2(250.0, 700.0), "patrol", state, false, registry_token, 0.0)
	_expect_str(str(invalid.get("blocked_reason", "")), "invalid_feed_amount", "feed controller should reject zero duration recovery")
	var busy: Dictionary = controller.request("maribo", owner, Vector2(250.0, 700.0), "patrol", state, true, registry_token, 20.0)
	_expect_str(str(busy.get("blocked_reason", "")), "companion_busy", "feed controller should own the companion-busy request gate")

	state.set_satiety("maribo", LingpetAffinityState.SATIETY_MAX)
	var full: Dictionary = controller.request("maribo", owner, Vector2(250.0, 700.0), "patrol", state, false, registry_token, 20.0)
	_expect_str(str(full.get("blocked_reason", "")), "duration_full", "feed controller should block actual feed requests when the shared pool is full")

	state.set_satiety("maribo", 20.0)
	var first: Dictionary = controller.request("maribo", owner, Vector2(250.0, 700.0), "patrol", state, false, registry_token, 20.0)
	_expect(bool(first.get("accepted", false)) and bool(first.get("pending", false)), "feed controller should arm a pending duration recovery")
	_expect_float(float(first.get("duration_recovery_seconds", 0.0)), 20.0, "feed controller should echo the requested recovery seconds")
	var duplicate: Dictionary = controller.request("maribo", owner, Vector2(250.0, 700.0), "patrol", state, false, registry_token, 20.0)
	_expect_str(str(duplicate.get("blocked_reason", "")), "feed_in_progress", "feed controller should reject a second request while its bowl is active")
	var completed := _advance_controller_until_complete(controller, Vector2(250.0, 700.0), "patrol")
	_expect_str(str(completed.get("feed_pet_id", "")), "maribo", "feed controller should preserve pending pet ownership through completion")
	_expect_float(float(completed.get("duration_recovery_seconds", 0.0)), 20.0, "feed controller should preserve pending recovery seconds through completion")
	_expect(completed.get("feed_registry", null) == registry_token, "feed controller should preserve the request registry through completion")
	_expect_eq(controller.get_feed_uses_this_battle_for_tests(), 1, "completed feed should consume one battle feed use")

	_arm_and_complete_controller(controller, state, owner, registry_token, 100.0)
	_expect_eq(controller.get_feed_uses_this_battle_for_tests(), LingpetFeedController.MAX_FEED_USES_PER_BATTLE, "second completed feed should reach the battle cap")
	state.set_satiety("maribo", 30.0)
	var capped: Dictionary = controller.request("maribo", owner, Vector2(250.0, 700.0), "patrol", state, false, registry_token, 20.0)
	_expect_str(str(capped.get("blocked_reason", "")), "max_battle_feed_uses", "third feed in one battle should be blocked by the battle cap")
	controller.reset_all()
	var still_capped: Dictionary = controller.request("maribo", owner, Vector2(250.0, 700.0), "patrol", state, false, registry_token, 20.0)
	_expect_str(str(still_capped.get("blocked_reason", "")), "max_battle_feed_uses", "visual reset/round cleanup must not reset the battle feed cap")
	controller.reset_for_new_battle()
	var after_battle_reset: Dictionary = controller.request("maribo", owner, Vector2(250.0, 700.0), "patrol", state, false, registry_token, 20.0)
	_expect(bool(after_battle_reset.get("accepted", false)), "new battle reset should reopen the feed cap")


func _verify_runtime_feed_restores_duration_after_bowl() -> void:
	var runtime := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner), "fixture should activate a lingpet companion")
	runtime.set_satiety_for_tests("maribo", 25.0)
	var affinity_before := runtime.get_affinity_points("maribo")
	var first: Dictionary = runtime.feed_lingpet(owner, registry, 40.0)
	_expect(bool(first.get("accepted", false)) and bool(first.get("pending", false)), "runtime feed_lingpet should arm a duration recovery")
	_expect_float(float(first.get("legacy_feed_amount", 0.0)), 40.0, "runtime should preserve the legacy catalog amount during the transition")
	_expect_float(float(first.get("duration_recovery_seconds", 0.0)), 20.0, "40 legacy feed points should map to 20 recovery seconds")
	_expect_float(runtime.get_duration_pool_current(), 25.0, "runtime feed should not restore duration until the bowl completes")
	_advance_feed_until_complete(runtime, owner, registry)
	var last_result: Dictionary = runtime.get_last_affinity_result_for_tests()
	_expect_str(str(last_result.get("source", "")), "duration_feed", "completed feed should report the duration-feed source")
	_expect_float(float(last_result.get("duration_recovery_seconds", 0.0)), 20.0, "completed feed should preserve the mapped recovery seconds")
	_expect_float(float(last_result.get("granted_duration_seconds", 0.0)), 20.0, "completed feed should grant 20 shared-pool seconds")
	_expect(runtime.get_duration_pool_current() > 43.0 and runtime.get_duration_pool_current() <= 45.0, "completed feed should restore duration after normal active drain during the bowl walk")
	_expect_float(runtime.get_affinity_points("maribo"), affinity_before, "completed feed must not grant affinity points")

	runtime.set_satiety_for_tests("maribo", LingpetAffinityState.SATIETY_MAX)
	var full: Dictionary = runtime.feed_lingpet(owner, registry, 40.0)
	_expect(not bool(full.get("accepted", true)), "runtime feed_lingpet should reject full-duration requests")
	_expect_str(str(full.get("blocked_reason", "")), "duration_full", "full-duration feed should report duration_full")
	_cleanup_runtime(runtime)


func _verify_expired_feed_unlocks_resummon_without_auto_summon() -> void:
	var runtime := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "", registry), "KO fixture should activate a skill-capable lingpet")
	runtime.set_satiety_for_tests("maribo", 0.0)
	runtime.update(2.0, owner, registry)
	_expect(runtime.is_guardian_stowed(), "fixture should force-stow the guardian at shared-pool expiry")
	var feed: Dictionary = runtime.feed_lingpet(owner, registry, 40.0)
	_expect(bool(feed.get("accepted", false)), "feed should be usable while the guardian is force-stowed")
	_advance_feed_until_complete(runtime, owner, registry)
	_expect(runtime.get_duration_pool_current() > 10.0, "feed should restore above the strict resummon threshold")
	_expect(runtime.can_resummon_guardian(), "feed should clear the resummon lock after restoring above 10 seconds")
	_expect(runtime.is_guardian_stowed(), "feed recovery must not auto-resummon the guardian")
	_expect(runtime.try_toggle_guardian_stow(owner, registry), "dedicated toggle should consume the resummon request")
	_expect(not runtime.is_guardian_stowed(), "guardian should resummon only after the explicit toggle")
	_cleanup_runtime(runtime)


func _verify_battle_cap_resets_only_on_new_battle() -> void:
	var runtime := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner), "battle-cap fixture should activate a lingpet")
	runtime.set_satiety_for_tests("maribo", 0.0)
	_complete_runtime_feed(runtime, owner, registry, 40.0)
	_complete_runtime_feed(runtime, owner, registry, 40.0)
	runtime.reset_round({"owner": owner, "registry": registry})
	runtime.set_satiety_for_tests("maribo", 20.0)
	var round_blocked: Dictionary = runtime.feed_lingpet(owner, registry, 40.0)
	_expect_str(str(round_blocked.get("blocked_reason", "")), "max_battle_feed_uses", "round reset should not clear the battle feed cap")
	runtime.reset_affinity_for_new_battle()
	runtime.set_satiety_for_tests("maribo", 20.0)
	var new_battle: Dictionary = runtime.feed_lingpet(owner, registry, 40.0)
	_expect(bool(new_battle.get("accepted", false)), "new battle should reset the feed cap")
	_cleanup_runtime(runtime)


func _arm_and_complete_controller(controller: Object, state: Object, owner: Object, registry_token: Object, amount: float) -> void:
	state.set_satiety("maribo", 20.0)
	var armed: Dictionary = controller.request("maribo", owner, Vector2(250.0, 700.0), "patrol", state, false, registry_token, amount)
	_expect(bool(armed.get("accepted", false)), "controller fixture should arm feed before completion")
	_advance_controller_until_complete(controller, Vector2(250.0, 700.0), "patrol")


func _advance_controller_until_complete(controller: Object, companion_pos: Vector2, motion_style: String) -> Dictionary:
	for _i in range(260):
		var advanced: Dictionary = controller.advance(1.0 / 60.0, companion_pos, motion_style, null)
		if bool(advanced.get("completed", false)):
			return advanced
	_expect(false, "feed controller should complete within the smoke time budget")
	return {}


func _complete_runtime_feed(runtime: Object, owner: Object, registry: Object, amount: float) -> void:
	var armed: Dictionary = runtime.feed_lingpet(owner, registry, amount)
	_expect(bool(armed.get("accepted", false)), "runtime fixture should arm feed before completion")
	_advance_feed_until_complete(runtime, owner, registry)


func _advance_feed_until_complete(runtime: Object, owner: Object, registry: Object) -> void:
	for _i in range(260):
		runtime.update(1.0 / 60.0, owner, registry)
		if not bool(runtime.get_snapshot().get("feed_bowl_active", false)):
			return
	_expect(false, "feed bowl should complete within the smoke time budget")


func _cleanup_runtime(runtime: Object) -> void:
	if runtime != null and runtime.has_method("reset_for_tests"):
		runtime.reset_for_tests()
	ProjectResourceLoader.clear_caches()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])


func _cleanup_runtime_resources() -> void:
	ProjectResourceLoader.clear_caches()
	for _i in range(12):
		await process_frame
