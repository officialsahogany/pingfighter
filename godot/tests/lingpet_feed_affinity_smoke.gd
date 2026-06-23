extends SceneTree

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")

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
	_run()


func _run() -> void:
	_verify_feed_use_counter_and_reset_boundary()
	_verify_feed_level_cap_and_clamp()
	_verify_feed_ignores_enhancement_chips()
	_verify_feed_alone_cannot_reach_second_slot()
	_verify_runtime_feed_lingpet_entrypoint()
	_verify_feed_source_contracts()

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
	var clamp_state := LingpetAffinityState.new()
	clamp_state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	_grant_round_commits(clamp_state, "maribo", 149)
	_expect_eq(clamp_state.get_level("maribo"), 14, "clamp fixture should start at Lv14")
	_expect_float(clamp_state.get_points("maribo"), 45.0, "clamp fixture should sit five points below Lv15 (flat 50 requirement)")
	var clamped: Dictionary = clamp_state.add_points("maribo", LingpetAffinityState.SOURCE_FEED)
	_expect_float(float(clamped.get("granted_points", 0.0)), 5.0, "feed should clamp at the Lv15 ceiling instead of crossing to Lv16")
	_expect_eq(clamp_state.get_level("maribo"), LingpetAffinityState.LINGPET_FEED_MAX_LEVEL, "clamped feed should reach exactly Lv15")
	_expect_float(clamp_state.get_points("maribo"), 0.0, "clamped feed should leave no overflow beyond Lv15")

	var level_block: Dictionary = clamp_state.add_points("maribo", LingpetAffinityState.SOURCE_FEED)
	_expect_float(float(level_block.get("granted_points", 0.0)), 0.0, "feed at Lv15 should grant no points")
	_expect_str(str(level_block.get("blocked_reason", "")), "max_feed_level", "feed at Lv15 should report max_feed_level")


func _verify_feed_ignores_enhancement_chips() -> void:
	var state := LingpetAffinityState.new()
	state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	state.set_enhancement_chips(5)
	var feed: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_FEED)
	_expect_float(float(feed.get("granted_points", 0.0)), 35.0, "five chips should not multiply feed affinity")
	var round_commit: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect_float(float(round_commit.get("granted_points", 0.0)), 10.0, "five chips should still multiply ordinary affinity income")


func _verify_feed_alone_cannot_reach_second_slot() -> void:
	var state := LingpetAffinityState.new()
	state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	var last_result: Dictionary = {}
	for _i in range(100):
		last_result = state.add_points("maribo", LingpetAffinityState.SOURCE_FEED)
	_expect(state.get_level("maribo") < 22, "feed-only affinity should not reach the second active unlock at Lv22")
	_expect(state.get_level("maribo") <= LingpetAffinityState.LINGPET_FEED_MAX_LEVEL, "feed-only affinity should never exceed the Lv15 feed ceiling")
	_expect_str(str(last_result.get("blocked_reason", "")), "max_feed_uses", "unbounded feed attempts should end at the run-use cap")
	var rewards := state.get_cumulative_rewards("maribo")
	_expect(not bool(rewards.get("second_active_unlocked", false)), "feed-only affinity should not unlock the second active slot")


func _verify_runtime_feed_lingpet_entrypoint() -> void:
	var runtime := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	var missing: Dictionary = runtime.feed_lingpet(owner, null)
	_expect(not bool(missing.get("accepted", true)), "feed_lingpet should no-op when no lingpet is active")
	_expect_str(str(missing.get("blocked_reason", "")), "missing_lingpet", "missing lingpet feed should report missing_lingpet")

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


func _verify_feed_source_contracts() -> void:
	var affinity_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_state.gd")
	_expect(affinity_source.find("const SOURCE_FEED := \"feed\"") >= 0, "affinity state should define a feed source")
	_expect(affinity_source.find("SOURCE_FEED: {\"points\": 35.0}") >= 0, "feed source should use the placeholder N=35 amount")
	_expect(affinity_source.find("var enhancement_multiplier := 1.0 if source == SOURCE_FEED else get_enhancement_chip_multiplier()") >= 0, "feed should be exempt from enhancement chip multiplication at the chokepoint")
	_expect(affinity_source.find("_feed_uses_this_run") >= 0, "feed uses should be a run-scoped affinity_state counter")
	_expect(affinity_source.find("reset_for_new_battle") >= 0 and affinity_source.find("_feed_uses_this_run = 0", affinity_source.find("func reset_for_new_battle")) < 0, "new battle reset should not clear feed uses")
	_expect(affinity_source.find("LINGPET_FEED_MAX_LEVEL := 15") >= 0, "feed should carry the Lv15 ceiling")

	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	_expect(runtime_source.find("func feed_lingpet") >= 0, "lingpet runtime should expose a feed_lingpet entrypoint")
	_expect(runtime_source.find("LingpetAffinityState.SOURCE_FEED") >= 0, "feed_lingpet should route through the feed affinity source")
	_expect(runtime_source.find("LingpetFeedBowlState") >= 0, "feed_lingpet should stage the visible feed-bowl approach before granting affinity")
	_expect(runtime_source.find("\"pending\"") >= 0, "feed_lingpet should report a pending visual feed instead of immediate affinity")


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
