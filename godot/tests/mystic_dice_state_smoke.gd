extends SceneTree

const MysticDiceRoller := preload("res://scripts/characters/mystic_dice_roller.gd")
const MysticDiceState := preload("res://scripts/characters/mystic_dice_state.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const MatchResetController := preload("res://scripts/core/match_reset_controller.gd")
const MatchRoundRestartController := preload("res://scripts/core/match_round_restart_controller.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_benefit_space_polarity_contract()
	_verify_all_integer_buckets_and_roll_shape()
	_verify_atomic_accumulation_cap_and_reset()
	_verify_three_worst_benefit_rolls()
	_verify_runtime_state_reset_and_snapshot_wiring()

	if _failures.is_empty():
		print("mystic_dice_state_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_benefit_space_polarity_contract() -> void:
	var roller := MysticDiceRoller.new()
	var minimum: Dictionary = roller.roll(_repeated_units(0.0))
	var maximum: Dictionary = roller.roll(_repeated_units(1.0))
	var minimum_benefits: Dictionary = minimum.get("benefits", {}) as Dictionary
	var maximum_benefits: Dictionary = maximum.get("benefits", {}) as Dictionary
	var minimum_raw: Dictionary = minimum.get("raw", {}) as Dictionary
	var maximum_raw: Dictionary = maximum.get("raw", {}) as Dictionary

	for stat_key: String in MysticDiceRoller.STAT_KEYS:
		_expect(int(minimum_benefits.get(stat_key, 99)) == -3, "%s minimum benefit should be -3" % stat_key)
		_expect(int(maximum_benefits.get(stat_key, -99)) == 3, "%s maximum benefit should be +3" % stat_key)
		if stat_key in MysticDiceRoller.LOWER_IS_BETTER_STAT_KEYS:
			_expect(int(minimum_raw.get(stat_key, 99)) == 3, "%s should mirror -3 benefit to +3 raw" % stat_key)
			_expect(int(maximum_raw.get(stat_key, 99)) == -3, "%s should mirror +3 benefit to -3 raw" % stat_key)
		else:
			_expect(int(minimum_raw.get(stat_key, 99)) == -3, "%s should preserve -3 benefit raw" % stat_key)
			_expect(int(maximum_raw.get(stat_key, 99)) == 3, "%s should preserve +3 benefit raw" % stat_key)


func _verify_all_integer_buckets_and_roll_shape() -> void:
	var roller := MysticDiceRoller.new()
	for bucket: int in range(MysticDiceRoller.BENEFIT_BUCKET_COUNT):
		var roll_unit := (float(bucket) + 0.25) / float(MysticDiceRoller.BENEFIT_BUCKET_COUNT)
		var expected_benefit := MysticDiceRoller.BENEFIT_MIN + bucket
		_expect(
			roller.benefit_from_unit(roll_unit) == expected_benefit,
			"roll bucket %d should map to benefit %d" % [bucket, expected_benefit]
		)
	_expect(not bool(roller.roll([0.5]).get("accepted", true)), "roller should reject fewer than seven units")
	var invalid_units: Array = _repeated_units(0.5)
	invalid_units[3] = "bad"
	_expect(not bool(roller.roll(invalid_units).get("accepted", true)), "roller should reject non-numeric units")


func _verify_atomic_accumulation_cap_and_reset() -> void:
	var roller := MysticDiceRoller.new()
	var state := MysticDiceState.new()
	var best_raw: Dictionary = roller.roll(_repeated_units(1.0)).get("raw", {}) as Dictionary
	for expected_use_count: int in range(1, 4):
		var result: Dictionary = state.commit_roll(best_raw)
		_expect(bool(result.get("accepted", false)), "valid roll %d should commit" % expected_use_count)
		_expect(state.get_use_count() == expected_use_count, "commit should increment use count once")
	_expect(state.get_raw("player_speed") == 9, "three best normal rolls should accumulate to the +9 natural cap")
	_expect(state.get_raw("dash_cooldown") == -9, "three best LIB rolls should accumulate to -9 raw")
	_expect_close(state.get_multiplier("player_speed"), 1.09, "normal multiplier should expose accumulated raw")
	_expect_close(state.get_multiplier("dash_cooldown"), 0.91, "LIB multiplier should expose mirrored accumulated raw")

	var revision_at_cap := state.get_revision()
	_expect(bool(state.commit_roll(best_raw).get("accepted", false)), "a fourth dropped item should remain usable")
	_expect(state.get_revision() == revision_at_cap + 1, "repeatable item use should advance revision")
	_expect(state.get_raw("player_speed") == 9, "repeat use should respect the cumulative +9 stat cap")

	var invalid_state := MysticDiceState.new()
	var incomplete_raw := best_raw.duplicate(true)
	incomplete_raw.erase("item_cooldown")
	_expect(not bool(invalid_state.commit_roll(incomplete_raw).get("accepted", true)), "partial seven-stat roll should be rejected atomically")
	_expect(invalid_state.get_use_count() == 0, "rejected partial roll must not consume a use")
	_expect(invalid_state.get_raw("player_speed") == 0, "rejected partial roll must not mutate any stat")

	var revision_before_reset := state.get_revision()
	state.reset()
	_expect(state.get_use_count() == 0, "new-run reset should clear use count")
	_expect(state.get_remaining_uses() == -1, "active-item uses should have no run-count limit")
	_expect(state.get_raw("player_speed") == 0 and state.get_raw("dash_cooldown") == 0, "new-run reset should clear accumulated raw")
	_expect(state.get_revision() == revision_before_reset + 1, "reset should invalidate revision-dependent projections")


func _verify_three_worst_benefit_rolls() -> void:
	var roller := MysticDiceRoller.new()
	var state := MysticDiceState.new()
	var worst_raw: Dictionary = roller.roll(_repeated_units(0.0)).get("raw", {}) as Dictionary
	for expected_use_count: int in range(1, 5):
		var result: Dictionary = state.commit_roll(worst_raw)
		_expect(bool(result.get("accepted", false)), "worst benefit roll %d should commit" % expected_use_count)

	for stat_key: String in MysticDiceRoller.STAT_KEYS:
		var expected_raw := 9 if stat_key in MysticDiceRoller.LOWER_IS_BETTER_STAT_KEYS else -9
		_expect(
			state.get_raw(stat_key) == expected_raw,
			"repeated worst %s rolls should remain at %+d raw" % [stat_key, expected_raw]
		)
	_expect(state.get_remaining_uses() == -1, "repeatable item uses should never exhaust a run allowance")
	_expect_close(state.get_multiplier("player_speed"), 0.91, "three worst normal rolls should expose -9%")
	_expect_close(state.get_multiplier("dash_cooldown"), 1.09, "three worst LIB rolls should expose +9% raw")


func _verify_runtime_state_reset_and_snapshot_wiring() -> void:
	var roller := MysticDiceRoller.new()
	var runtime := RuntimePerkState.new()
	var commit: Dictionary = runtime.commit_mystic_dice_roll(
		roller.roll(_repeated_units(1.0)).get("raw", {}) as Dictionary
	)
	_expect(bool(commit.get("accepted", false)), "runtime facade should commit a valid Mystic Dice roll")
	var snapshot: Dictionary = runtime.get_snapshot()
	var dice_snapshot: Dictionary = snapshot.get("mystic_dice", {}) as Dictionary
	_expect(int(dice_snapshot.get("use_count", 0)) == 1, "runtime snapshot should expose Mystic Dice use count")
	_expect(bool(dice_snapshot.get("uses_unlimited", false)), "runtime snapshot should identify unlimited item uses explicitly")
	_expect(int(dice_snapshot.get("remaining_uses", 0)) == -1, "runtime snapshot should expose unlimited item uses")
	_expect(
		int(dice_snapshot.get("max_uses_per_run", -1)) == MysticDiceState.UNLIMITED_USES,
		"runtime snapshot should expose the unlimited-use sentinel"
	)
	_expect(int((dice_snapshot.get("permanent_raw", {}) as Dictionary).get("dash_cooldown", 0)) == -3, "runtime snapshot should expose mirrored LIB raw")
	_expect(int(snapshot.get("mystic_dice_revision", -1)) == runtime.get_mystic_dice_revision(), "runtime snapshot should expose canonical Mystic Dice revision")
	(dice_snapshot.get("permanent_raw", {}) as Dictionary)["player_speed"] = 99
	_expect(runtime.get_mystic_dice_raw("player_speed") == 3, "runtime snapshot must not alias Mystic Dice state")

	var revision_before_boundaries := runtime.get_mystic_dice_revision()
	MatchRoundRestartController.new().handle_round_restart(
		"rematch",
		{"runtime_perk_state": runtime},
		{}
	)
	_expect(runtime.get_mystic_dice_raw("player_speed") == 3, "round restart should preserve Mystic Dice raw")
	_expect(int(runtime.get_mystic_dice_snapshot().get("use_count", -1)) == 1, "round restart should preserve Mystic Dice uses")
	_expect(runtime.get_mystic_dice_revision() == revision_before_boundaries, "round restart should not revise Mystic Dice state")

	MatchResetController.new().reset_for_stage_transition(
		{"runtime_perk_state": runtime},
		{}
	)
	_expect(runtime.get_mystic_dice_raw("player_speed") == 3, "stage transition should preserve Mystic Dice raw")
	_expect(int(runtime.get_mystic_dice_snapshot().get("use_count", -1)) == 1, "stage transition should preserve Mystic Dice uses")
	_expect(runtime.get_mystic_dice_revision() == revision_before_boundaries, "stage transition should not revise Mystic Dice state")

	var revision_before_reset := runtime.get_mystic_dice_revision()
	runtime.reset()
	_expect(runtime.get_mystic_dice_raw("player_speed") == 0, "runtime new-run reset should clear Mystic Dice raw")
	_expect(int(runtime.get_mystic_dice_snapshot().get("use_count", -1)) == 0, "runtime new-run reset should clear Mystic Dice uses")
	_expect(int(runtime.get_mystic_dice_snapshot().get("remaining_uses", 0)) == MysticDiceState.UNLIMITED_USES, "runtime new-run reset should preserve the unlimited-use sentinel")
	_expect(runtime.get_mystic_dice_revision() == revision_before_reset + 1, "runtime new-run reset should advance Mystic Dice revision")

	var reset_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_reset_state.gd")
	var snapshot_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_snapshot_builder.gd")
	_expect(reset_source.find("_reset_mystic_dice(runtime_state)") >= 0, "reset facade should route Mystic Dice reset")
	_expect(snapshot_source.find("get_mystic_dice_snapshot") >= 0, "snapshot builder should route Mystic Dice state")


func _repeated_units(value: float) -> Array:
	var units: Array = []
	for _index: int in range(MysticDiceRoller.STAT_KEYS.size()):
		units.append(value)
	return units


func _expect_close(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
