extends SceneTree

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetFeedController := preload("res://scripts/lingpet/lingpet_feed_controller.gd")
const LingpetRingCoreRules := preload("res://scripts/lingpet/lingpet_ring_core_rules.gd")
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


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_feed_use_counter_and_reset_boundary()
	_verify_feed_level_cap_and_clamp()
	_verify_feed_ignores_enhancement_chips()
	_verify_unbounded_feed_attempts_stop_at_run_use_cap()
	_verify_feed_controller_lifecycle_ownership()
	_verify_runtime_feed_lingpet_entrypoint()
	_verify_feed_source_contracts()
	await _cleanup_runtime_resources()

	if _failures.is_empty():
		print("lingpet_feed_affinity_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_feed_use_counter_and_reset_boundary() -> void:
	var state := LingpetAffinityState.new()
	state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	for index in range(LingpetAffinityState.MAX_FEED_USES_PER_RUN):
		var result: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_FEED)
		_expect_float(float(result.get("granted_points", 0.0)), 35.0, "feed use %d should grant the base feed amount" % [index + 1])
	_expect_eq(state.get_feed_uses_this_run(), LingpetAffinityState.MAX_FEED_USES_PER_RUN, "three successful feed uses should consume the run counter")
	var fourth: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_FEED)
	_expect_float(float(fourth.get("granted_points", 0.0)), 0.0, "fourth feed use in one run should be blocked")
	_expect_str(str(fourth.get("blocked_reason", "")), "max_feed_uses", "fourth feed use should report max_feed_uses")

	state.reset_for_new_battle()
	var after_battle: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_FEED)
	_expect_str(str(after_battle.get("blocked_reason", "")), "max_feed_uses", "new battle should not reset the per-run feed counter")

	state.reset_for_new_run()
	var after_run: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_FEED)
	_expect_float(float(after_run.get("granted_points", 0.0)), 35.0, "new run should reset the feed counter")
	_expect_eq(state.get_feed_uses_this_run(), 1, "new run should start a fresh feed counter")


func _verify_feed_level_cap_and_clamp() -> void:
	var max_state := LingpetAffinityState.new()
	max_state.set_run_ring_core_tier(LingpetRingCoreRules.MAX_RING_CORE_TIER)
	max_state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, max_state.get_run_ring_core_cap())
	_grant_round_commits(max_state, "maribo", 299)
	_expect_eq(max_state.get_level("maribo"), 29, "T6 clamp fixture should start at Lv29")
	_expect_float(max_state.get_points("maribo"), 45.0, "T6 clamp fixture should sit five points below Lv30")
	var max_clamped: Dictionary = max_state.add_points("maribo", LingpetAffinityState.SOURCE_FEED)
	_expect_float(float(max_clamped.get("granted_points", 0.0)), 5.0, "feed should clamp at the Lv30 ring-core ceiling instead of overflowing")
	_expect_eq(max_state.get_level("maribo"), LingpetAffinityState.MAX_LEVEL, "T6 clamped feed should reach exactly Lv30")
	_expect_float(max_state.get_points("maribo"), 0.0, "T6 clamped feed should leave no overflow beyond Lv30")
	var max_block: Dictionary = max_state.add_points("maribo", LingpetAffinityState.SOURCE_FEED)
	_expect_float(float(max_block.get("granted_points", 0.0)), 0.0, "feed at Lv30 should grant no points")
	_expect_str(str(max_block.get("blocked_reason", "")), "max_feed_level", "feed at Lv30 should report max_feed_level")

	var capped_state := LingpetAffinityState.new()
	capped_state.set_run_ring_core_tier(3)
	capped_state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, capped_state.get_run_ring_core_cap())
	_grant_round_commits(capped_state, "maribo", 149)
	_expect_eq(capped_state.get_level("maribo"), 14, "T3 clamp fixture should start at Lv14")
	_expect_float(capped_state.get_points("maribo"), 45.0, "T3 clamp fixture should sit five points below Lv15")
	var capped_clamped: Dictionary = capped_state.add_points("maribo", LingpetAffinityState.SOURCE_FEED)
	_expect_float(float(capped_clamped.get("granted_points", 0.0)), 5.0, "T3 feed should still clamp at its current ring-core ceiling")
	_expect_eq(capped_state.get_level("maribo"), capped_state.get_run_ring_core_cap(), "T3 clamped feed should reach exactly the current ring-core cap")
	_expect_float(capped_state.get_points("maribo"), 0.0, "T3 clamped feed should leave no overflow beyond the ring-core cap")
	var capped_block: Dictionary = capped_state.add_points("maribo", LingpetAffinityState.SOURCE_FEED)
	_expect_float(float(capped_block.get("granted_points", 0.0)), 0.0, "feed at the current ring-core cap should grant no points")
	_expect_str(str(capped_block.get("blocked_reason", "")), "max_feed_level", "feed at the current ring-core cap should report max_feed_level")


func _verify_feed_ignores_enhancement_chips() -> void:
	var state := LingpetAffinityState.new()
	state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	state.set_enhancement_chips(5)
	var feed: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_FEED)
	_expect_float(float(feed.get("granted_points", 0.0)), 35.0, "five chips should not multiply feed affinity")
	var round_commit: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect_float(float(round_commit.get("granted_points", 0.0)), 10.0, "five chips should still multiply ordinary affinity income")


# Feed-only affinity is bounded by the per-run feed-use cap plus the current
# ring-core cap. (Second-slot unlocks are source-agnostic: combined skill level
# + a per-level roll, so this test only owns the feed bounds.)
func _verify_unbounded_feed_attempts_stop_at_run_use_cap() -> void:
	var state := LingpetAffinityState.new()
	state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	var last_result: Dictionary = {}
	for _i in range(100):
		last_result = state.add_points("maribo", LingpetAffinityState.SOURCE_FEED)
	_expect(state.get_level("maribo") <= state.get_feed_cap_for_pet("maribo"), "feed-only affinity should never exceed the current feed cap")
	_expect_str(str(last_result.get("blocked_reason", "")), "max_feed_uses", "unbounded feed attempts should end at the run-use cap")


func _verify_feed_controller_lifecycle_ownership() -> void:
	var controller := LingpetFeedController.new()
	var state := LingpetAffinityState.new()
	state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	var owner := FakeOwner.new()
	var registry_token := RefCounted.new()
	var missing: Dictionary = controller.request("", owner, Vector2(250.0, 700.0), "patrol", state, false, registry_token)
	_expect_str(str(missing.get("blocked_reason", "")), "missing_lingpet", "feed controller should own the missing-pet request gate")

	var busy: Dictionary = controller.request("maribo", owner, Vector2(250.0, 700.0), "patrol", state, true, registry_token)
	_expect_str(str(busy.get("blocked_reason", "")), "companion_busy", "feed controller should own the companion-busy request gate")

	var armed: Dictionary = controller.request("maribo", owner, Vector2(250.0, 700.0), "patrol", state, false, registry_token)
	_expect(bool(armed.get("accepted", false)) and bool(armed.get("pending", false)), "feed controller should arm and retain a pending feed lifecycle")
	var bowl_pos: Variant = armed.get("bowl_pos", Vector2.ZERO)
	_expect(bowl_pos is Vector2 and (bowl_pos as Vector2).x < owner.player_pos.x + owner.player_paddle_width * 0.5, "feed controller should place the bowl on the companion-facing side")
	var duplicate: Dictionary = controller.request("maribo", owner, Vector2(250.0, 700.0), "patrol", state, false, null)
	_expect_str(str(duplicate.get("blocked_reason", "")), "feed_in_progress", "feed controller should reject a second request while its bowl is active")

	var completed: Dictionary = {}
	for _i in range(260):
		var advanced: Dictionary = controller.advance(1.0 / 60.0, Vector2(250.0, 700.0), "patrol", null)
		if bool(advanced.get("completed", false)):
			completed = advanced
			break
	_expect_str(str(completed.get("feed_pet_id", "")), "maribo", "feed controller should return the pending pet only after eating completes")
	_expect(completed.get("feed_registry", null) == registry_token, "feed controller should preserve the request registry through completion")
	_expect(not controller.is_active(), "feed controller should clear the visible bowl after completion")

	controller.request("maribo", owner, Vector2(250.0, 700.0), "patrol", state, false, registry_token)
	controller.reset_all()
	_expect(not controller.is_active(), "feed controller reset should clear an active bowl")
	_expect(controller.advance(1.0, Vector2(250.0, 700.0), "patrol", null).is_empty(), "feed controller reset should clear pending completion work")

	var high_level_state := LingpetAffinityState.new()
	high_level_state.set_run_ring_core_tier(LingpetRingCoreRules.MAX_RING_CORE_TIER)
	high_level_state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, high_level_state.get_run_ring_core_cap())
	_grant_round_commits(high_level_state, "maribo", 260)
	var high_level_controller := LingpetFeedController.new()
	var high_level_request: Dictionary = high_level_controller.request("maribo", owner, Vector2(250.0, 700.0), "patrol", high_level_state, false, registry_token)
	_expect(bool(high_level_request.get("accepted", false)), "feed controller should allow Lv15+ pets when the current ring-core cap is higher")
	high_level_controller.reset_all()

	var capped_state := LingpetAffinityState.new()
	capped_state.set_run_ring_core_tier(3)
	capped_state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, capped_state.get_run_ring_core_cap())
	_grant_round_commits(capped_state, "maribo", 150)
	var capped_controller := LingpetFeedController.new()
	var capped_request: Dictionary = capped_controller.request("maribo", owner, Vector2(250.0, 700.0), "patrol", capped_state, false, registry_token)
	_expect_str(str(capped_request.get("blocked_reason", "")), "max_feed_level", "feed controller should still block at the current ring-core cap")


func _verify_runtime_feed_lingpet_entrypoint() -> void:
	var runtime := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	var missing: Dictionary = runtime.feed_lingpet(owner, null)
	_expect(not bool(missing.get("accepted", true)), "feed_lingpet should no-op when no lingpet is active")
	_expect_str(str(missing.get("blocked_reason", "")), "missing_lingpet", "missing lingpet feed should report missing_lingpet")

	runtime._affinity_state.set_run_ring_core_tier(LingpetRingCoreRules.MAX_RING_CORE_TIER)
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner), "fixture should activate a lingpet companion")
	var first: Dictionary = runtime.feed_lingpet(owner, null)
	_expect(bool(first.get("accepted", false)), "feed_lingpet should arm a feed bowl through the active companion")
	_expect(bool(first.get("pending", false)), "feed_lingpet should report pending while the companion walks to the bowl")
	_expect_float(float(first.get("granted_points", 0.0)), 0.0, "runtime feed_lingpet should not grant feed affinity immediately")
	_expect(bool(runtime.get_snapshot().get("feed_bowl_active", false)), "feed_lingpet should expose an active feed bowl before completion")
	_verify_feed_bowl_eating_y_stays_bounded(runtime, owner)
	_advance_feed_until_complete(runtime, owner)
	_expect_float(runtime.get_affinity_points("maribo"), 35.0, "runtime feed_lingpet should grant the feed amount after the eating animation")
	_expect_eq(runtime.get_affinity_level("maribo"), 0, "one completed feed should stay below the first affinity level")
	for _i in range(2):
		runtime.feed_lingpet(owner, null)
		_advance_feed_until_complete(runtime, owner)
	var blocked: Dictionary = runtime.feed_lingpet(owner, null)
	_expect(not bool(blocked.get("accepted", true)), "runtime feed_lingpet should expose blocked feed results")
	_expect_str(str(blocked.get("blocked_reason", "")), "max_feed_uses", "runtime feed_lingpet should share the state run-use cap")
	runtime.reset_for_tests()
	ProjectResourceLoader.clear_caches()


func _verify_feed_source_contracts() -> void:
	var affinity_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_state.gd")
	_expect(affinity_source.find("const SOURCE_FEED := \"feed\"") >= 0, "affinity state should define a feed source")
	_expect(affinity_source.find("SOURCE_FEED: {\"points\": 35.0}") >= 0, "feed source should use the placeholder N=35 amount")
	_expect(affinity_source.find("var enhancement_multiplier := 1.0 if source == SOURCE_FEED or source == SOURCE_RING_CORE_UPGRADE else get_enhancement_chip_multiplier()") >= 0, "feed should be exempt from enhancement chip multiplication at the chokepoint")
	_expect(affinity_source.find("_feed_uses_this_run") >= 0, "feed uses should be a run-scoped affinity_state counter")
	_expect(affinity_source.find("reset_for_new_battle") >= 0 and affinity_source.find("_feed_uses_this_run = 0", affinity_source.find("func reset_for_new_battle")) < 0, "new battle reset should not clear feed uses")
	_expect(affinity_source.find("func get_feed_cap_for_pet") >= 0, "feed cap should be exposed through a ring-core-aware getter")
	_expect(affinity_source.find("var feed_cap := _get_feed_level_cap(pet_data)") >= 0, "feed gain should clamp against the pet's current ring-core cap")
	_expect(affinity_source.find("LINGPET_FEED_MAX_LEVEL") < 0, "feed should no longer carry a hardcoded Lv15 ceiling")

	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var controller_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_feed_controller.gd")
	_expect(runtime_source.find("func feed_lingpet") >= 0, "lingpet runtime should expose a feed_lingpet entrypoint")
	_expect(runtime_source.find("LingpetAffinityState.SOURCE_FEED") >= 0, "feed_lingpet should route through the feed affinity source")
	_expect(runtime_source.find("LingpetFeedController") >= 0, "lingpet runtime should delegate the feed lifecycle to its focused owner")
	_expect(runtime_source.find("_pending_feed_pet_id") < 0 and runtime_source.find("_pending_feed_registry") < 0, "lingpet runtime should not retain feed pending-context ownership")
	_expect(controller_source.find("LingpetFeedBowlState") >= 0, "feed controller should stage the visible feed-bowl approach before granting affinity")
	_expect(controller_source.find("\"pending\"") >= 0, "feed controller should report a pending visual feed instead of immediate affinity")
	_expect(controller_source.find("get_feed_cap_for_pet") >= 0, "feed controller should preflight against the ring-core-aware feed cap")


func _grant_round_commits(state: Object, pet_id: String, count: int) -> void:
	for _i in range(count):
		state.add_points(pet_id, LingpetAffinityState.SOURCE_ROUND_COMMIT)


func _advance_feed_until_complete(runtime: Object, owner: Object) -> void:
	for _i in range(260):
		runtime.update(1.0 / 60.0, owner, null)
		if not bool(runtime.get_snapshot().get("feed_bowl_active", false)):
			return
	_expect(false, "feed bowl should complete within the smoke time budget")


func _verify_feed_bowl_eating_y_stays_bounded(runtime: Object, owner: Object) -> void:
	var eating_snapshot := _advance_feed_until_eating(runtime, owner)
	var initial_pos: Variant = eating_snapshot.get("feed_bowl_companion_pos", Vector2.ZERO)
	if not (initial_pos is Vector2):
		_expect(false, "feed bowl eating snapshot should expose a companion position")
		return
	var base_y := (initial_pos as Vector2).y
	var min_y := base_y
	var max_y := base_y
	for _i in range(45):
		runtime.update(1.0 / 60.0, owner, null)
		var snapshot: Dictionary = runtime.get_snapshot()
		if str(snapshot.get("feed_bowl_phase", "")) != "eating":
			break
		var pos: Variant = snapshot.get("feed_bowl_companion_pos", Vector2.ZERO)
		if pos is Vector2:
			min_y = minf(min_y, (pos as Vector2).y)
			max_y = maxf(max_y, (pos as Vector2).y)
	_expect(max_y - min_y <= 8.0, "ground feed eating bob should stay bounded instead of accumulating vertical drift")


func _advance_feed_until_eating(runtime: Object, owner: Object) -> Dictionary:
	for _i in range(180):
		runtime.update(1.0 / 60.0, owner, null)
		var snapshot: Dictionary = runtime.get_snapshot()
		if str(snapshot.get("feed_bowl_phase", "")) == "eating":
			return snapshot
	_expect(false, "feed bowl should reach the eating phase within the smoke time budget")
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) > 0.001:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])


func _cleanup_runtime_resources() -> void:
	ProjectResourceLoader.clear_caches()
	for _i in range(12):
		await process_frame
