extends SceneTree

const LingpetDurationState := preload(
	"res://scripts/lingpet/lingpet_duration_state.gd"
)
const LingpetAffinityState := preload(
	"res://scripts/lingpet/lingpet_affinity_state.gd"
)
const BattleSceneState := preload(
	"res://scripts/core/battle_scene_state.gd"
)

var _failures: Array[String] = []


class FakeCollectionState:
	extends RefCounted

	var auto_present := false

	func is_auto_present_league(_owner: Object) -> bool:
		return auto_present


func _init() -> void:
	_verify_first_hatch_roll_is_run_shared_and_once()
	_verify_drain_recovery_and_both_rail_snaps()
	_verify_expiry_threshold_and_stage_refill()
	_verify_league_exemption_latch()
	_verify_run_state_schema_ignores_legacy_satiety()
	_verify_runtime_wiring_covers_both_hatch_families_and_real_stage_advance()

	if _failures.is_empty():
		print("lingpet_duration_pool_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_first_hatch_roll_is_run_shared_and_once() -> void:
	var state := LingpetDurationState.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260728
	var first: Dictionary = state.ensure_initial_roll(rng, 67)
	_expect(bool(first.get("accepted", false)), "first hatch should commit the duration roll")
	_expect_float(state.get_pool_current(), 67.0, "first hatch should fill current to the rolled maximum")
	_expect_float(state.get_pool_max(), 67.0, "forced deterministic roll should stay inside the 60-80 contract")
	var second: Dictionary = state.ensure_initial_roll(rng, 80)
	_expect(not bool(second.get("accepted", true)), "later hatches must not reroll the run pool")
	_expect_str(str(second.get("blocked_reason", "")), "already_rolled", "later hatch should report the once guard")
	state.set_duration("maribo", 42.0)
	_expect_float(state.get_duration("lunabi"), 42.0, "pet ids must observe one shared battery after a slot swap")


func _verify_drain_recovery_and_both_rail_snaps() -> void:
	var state := LingpetDurationState.new()
	state.ensure_initial_roll(null, 60)
	state.advance_pool(3.0, true)
	_expect_float(state.get_pool_current(), 57.0, "summoned guardian should drain at one second per second")
	state.advance_pool(3.0, false)
	_expect_float(state.get_pool_current(), 58.0, "stowed guardian should recover at one-third speed")
	state.set_pool_for_tests(0.0002, 60.0)
	_expect_float(state.get_pool_current(), 0.0, "lower rail epsilon residue should snap to exact zero")
	state.set_pool_for_tests(59.9998, 60.0)
	_expect_float(state.get_pool_current(), 60.0, "upper rail epsilon residue should snap to exact maximum")

	var tick_delta := 1.0 / 60.0
	state.set_pool_for_tests(7.0 * tick_delta + LingpetDurationState.VALUE_SNAP_EPSILON * 0.5, 60.0)
	for _tick in range(7):
		state.advance_pool(tick_delta, true)
	_expect_float(state.get_pool_current(), 0.0, "real 60 Hz ticks should land exactly on the lower rail", 0.000001)


func _verify_expiry_threshold_and_stage_refill() -> void:
	var state := LingpetDurationState.new()
	state.ensure_initial_roll(null, 73)
	state.set_pool_for_tests(0.5, 73.0)
	var expired: Dictionary = state.advance_pool(1.0, true)
	_expect(bool(expired.get("expired", false)), "crossing zero while summoned should emit one forced-stow edge")
	_expect(state.is_resummon_locked(), "expiry should latch the resummon lock")
	state.advance_pool(30.0, false)
	_expect_float(state.get_pool_current(), 10.0, "thirty stowed seconds should recover exactly ten seconds")
	_expect(not state.can_resummon(), "the strict resummon gate should remain closed at exactly ten seconds")
	state.advance_pool(0.01, false)
	_expect(state.can_resummon(), "recovery above ten seconds should reopen summoning")
	state.set_pool_for_tests(12.0, 73.0)
	_expect(state.refill_to_max(), "real stage-advance refill should report a changed pool")
	_expect_float(state.get_pool_current(), 73.0, "stage advance should refill to the run's rolled maximum")


func _verify_league_exemption_latch() -> void:
	var state := LingpetDurationState.new()
	state.ensure_initial_roll(null, 64)
	var collection := FakeCollectionState.new()
	collection.auto_present = true
	_expect(state.latch_drain_exempt(RefCounted.new(), collection), "auto-present league should latch duration drain exemption")
	state.advance_pool(5.0, true, state.is_drain_exempt_latched())
	_expect_float(state.get_pool_current(), 64.0, "latched junior/auto-present exemption should prevent drain")
	state.clear_drain_exempt_latch()
	state.advance_pool(1.0, true, state.is_drain_exempt_latched())
	_expect_float(state.get_pool_current(), 63.0, "clearing the latch should restore one-to-one drain")


func _verify_run_state_schema_ignores_legacy_satiety() -> void:
	var state := LingpetDurationState.new()
	state.import_run_state({
		"pets": {"maribo": {"satiety": 99.0}},
		"satiety": 99.0,
	})
	_expect(not state.is_initialized(), "legacy satiety fields must not initialize the shared pool")
	state.ensure_initial_roll(null, 69)
	state.set_pool_for_tests(17.0, 69.0)
	var exported := state.export_run_state()
	_expect(exported.has("duration_pool"), "run state should export duration_pool")
	_expect(exported.has("duration_pool_max"), "run state should export duration_pool_max")
	_expect(exported.has("duration_resummon_lock_remaining"), "run state should export the expiry lock remainder")
	_expect(not exported.has("satiety"), "new run state must not export legacy satiety")


func _verify_runtime_wiring_covers_both_hatch_families_and_real_stage_advance() -> void:
	var runtime_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_egg_runtime.gd"
	)
	_expect(_function_contains(runtime_source, "_finish_regular_hatch", "_ensure_duration_pool_roll()"), "regular hatch commit should ensure the run pool roll")
	_expect(_function_contains(runtime_source, "_perform_item_egg_absorb", "_ensure_duration_pool_roll()"), "item-egg free-slot hatch should ensure the same run pool roll")
	_expect(_function_contains(runtime_source, "_commit_item_egg_overflow_replace", "_ensure_duration_pool_roll()"), "item-egg overflow hatch should ensure the same run pool roll")
	_expect(_function_contains(runtime_source, "_finish_overflow_hatch_commit", "_ensure_duration_pool_roll()"), "main-egg overflow commit should ensure the same run pool roll")

	for key in ["lingpet_duration_pool_pct", "ringpet_duration_pool_pct"]:
		_expect(BattleSceneState.DEFAULT_VALUES.has(key), "BattleSceneState should declare %s" % key)
	for old_key in ["lingpet_satiety_pct", "ringpet_satiety_pct"]:
		_expect(not BattleSceneState.DEFAULT_VALUES.has(old_key), "BattleSceneState should retire %s" % old_key)
	var match_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_match_event_driver.gd"
	)
	_expect(_function_contains(match_source, "_reset_lingpet_affinity_for_stage_transition", "refill_guardian_duration_for_stage_transition"), "real stage-transition hook should refill guardian duration")
	_expect(not _function_contains(runtime_source, "reset_round", "refill_guardian_duration_for_stage_transition"), "ordinary reset_round must not refill the run pool")


func _function_contains(source: String, function_name: String, needle: String) -> bool:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return false
	var next_function := source.find("\nfunc ", start + 1)
	var body := source.substr(start) if next_function < 0 else source.substr(start, next_function - start)
	return body.find(needle) >= 0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_float(
	actual: float,
	expected: float,
	message: String,
	tolerance: float = 0.001
) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.6f, got %.6f)" % [message, expected, actual])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
