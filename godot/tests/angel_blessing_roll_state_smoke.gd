extends SceneTree

const AngelBlessingState := preload("res://scripts/characters/runtime_perk_angel_blessing_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_canonical_six_buff_contract()
	_verify_forced_faces_pick_distinct_buffs()
	_verify_seeded_rolls_are_deterministic()
	_verify_stage_dedupe_and_atomic_replacement()
	_verify_character_capability_filter()
	_verify_buff_multipliers()
	_verify_snapshot_copy_and_reset()

	if _failures.is_empty():
		print("angel_blessing_roll_state_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_canonical_six_buff_contract() -> void:
	var state := AngelBlessingState.new()
	var ids: Array[String] = state.get_all_buff_ids()
	_expect(
		ids == [
			"paddle_size",
			"gauge_max",
			"item_cooldown",
			"active_cooldown",
			"dash_cooldown",
			"move_speed",
		],
		"Angel Dice should keep the live Python source's canonical six buffs"
	)
	_expect(ids.size() == 6, "Angel Dice should expose exactly six canonical buffs")
	_expect("item_spawn" not in ids, "stale item_spawn option must not enter the live Angel Dice pool")
	_expect("dash_cost" not in ids, "stale dash_cost option must not enter the live Angel Dice pool")
	_expect(is_equal_approx(state.get_buff_pct(), 30.0), "Angel Dice should default to the fixed 30% mythic strength")


func _verify_forced_faces_pick_distinct_buffs() -> void:
	var forced_order: Array[String] = [
		"move_speed",
		"dash_cooldown",
		"active_cooldown",
		"item_cooldown",
		"gauge_max",
		"paddle_size",
	]
	for face: int in range(1, 4):
		var state := AngelBlessingState.new()
		var result: Dictionary = state.roll_for_stage(1, state.get_all_buff_ids(), face, forced_order)
		var selected: Array = result.get("active_buff_ids", []) as Array
		_expect(bool(result.get("rolled", false)), "forced face %d should produce a roll" % face)
		_expect(int(result.get("roll_face", 0)) == face, "forced face %d should be preserved" % face)
		_expect(selected.size() == face, "face %d should select exactly %d blessings" % [face, face])
		_expect(not _has_duplicates(selected), "face %d should sample without replacement" % face)
		_expect(
			selected == forced_order.slice(0, face),
			"forced candidate order should deterministically own face %d picks" % face
		)


func _verify_seeded_rolls_are_deterministic() -> void:
	var first := AngelBlessingState.new()
	var second := AngelBlessingState.new()
	first.set_rng_seed(7122026)
	second.set_rng_seed(7122026)
	var first_result: Dictionary = first.roll_for_stage(1)
	var second_result: Dictionary = second.roll_for_stage(1)
	_expect(
		int(first_result.get("roll_face", 0)) == int(second_result.get("roll_face", -1)),
		"equal Angel Dice seeds should produce equal faces"
	)
	_expect(
		first_result.get("active_buff_ids", []) == second_result.get("active_buff_ids", ["mismatch"]),
		"equal Angel Dice seeds should produce equal sampled buffs"
	)


func _verify_stage_dedupe_and_atomic_replacement() -> void:
	var state := AngelBlessingState.new()
	var first_order: Array[String] = ["paddle_size", "gauge_max"]
	var first: Dictionary = state.roll_for_stage(1, state.get_all_buff_ids(), 2, first_order)
	var first_revision: int = state.get_revision()
	var duplicate: Dictionary = state.roll_for_stage(1, state.get_all_buff_ids(), 3, ["move_speed"])
	_expect(bool(first.get("rolled", false)), "first valid stage should roll")
	_expect(not bool(duplicate.get("rolled", true)), "same stage should not reroll")
	_expect(str(duplicate.get("reason", "")) == "already_triggered", "same-stage rejection should report its cause")
	_expect(state.get_active_buff_ids() == first_order, "same-stage rejection should preserve the active result")
	_expect(state.get_revision() == first_revision, "same-stage rejection should not mutate state revision")

	var second: Dictionary = state.roll_for_stage(2, state.get_all_buff_ids(), 1, ["move_speed"])
	_expect(bool(second.get("rolled", false)), "next stage should roll")
	_expect(state.get_active_stage() == 2, "next roll should own the new active stage")
	_expect(state.get_roll_face() == 1, "next roll should replace the previous face")
	_expect(state.get_active_buff_ids() == ["move_speed"], "next roll should atomically replace prior stage buffs")
	_expect(state.get_triggered_stages() == [1, 2], "stage history should retain both triggered stages")

	var invalid_revision: int = state.get_revision()
	var invalid: Dictionary = state.roll_for_stage(0)
	_expect(not bool(invalid.get("rolled", true)), "invalid stage should not roll")
	_expect(str(invalid.get("reason", "")) == "invalid_stage", "invalid stage should report its cause")
	_expect(state.get_revision() == invalid_revision, "invalid stage should not mutate state")


func _verify_character_capability_filter() -> void:
	var state := AngelBlessingState.new()
	var full: Array[String] = state.get_eligible_buff_ids(true)
	var without_skill_cooldown: Array[String] = state.get_eligible_buff_ids(false)
	_expect(full.size() == 6, "cooldown-eligible characters should keep all six blessings")
	_expect("active_cooldown" in full, "eligible characters should retain player-skill cooldown blessing")
	_expect(without_skill_cooldown.size() == 5, "cooldown-ineligible characters should use five blessings")
	_expect("active_cooldown" not in without_skill_cooldown, "cooldown-ineligible characters should exclude only the dead skill-cooldown blessing")
	for buff_id: String in without_skill_cooldown:
		_expect(buff_id in full, "capability filtering should not invent a new blessing id")


func _verify_buff_multipliers() -> void:
	var state := AngelBlessingState.new()
	state.roll_for_stage(
		1,
		state.get_all_buff_ids(),
		3,
		["paddle_size", "item_cooldown", "dash_cooldown"]
	)
	_expect_close(state.get_multiplier_for_buff("paddle_size"), 1.30, "positive blessing multiplier")
	_expect_close(state.get_multiplier_for_buff("item_cooldown"), 0.70, "item cooldown blessing multiplier")
	_expect_close(state.get_multiplier_for_buff("dash_cooldown"), 0.70, "dash cooldown blessing multiplier")
	_expect_close(state.get_multiplier_for_buff("active_cooldown"), 1.0, "inactive blessing should stay neutral")
	_expect_close(state.get_multiplier_for_buff("not_a_blessing"), 1.0, "unknown blessing should stay neutral")


func _verify_snapshot_copy_and_reset() -> void:
	var state := AngelBlessingState.new()
	state.roll_for_stage(4, state.get_all_buff_ids(), 2, ["gauge_max", "move_speed"])
	var snapshot: Dictionary = state.get_snapshot()
	var snapshot_buffs: Array = snapshot.get("active_buff_ids", []) as Array
	var snapshot_stages: Array = snapshot.get("triggered_stages", []) as Array
	snapshot_buffs.clear()
	snapshot_stages.clear()
	_expect(state.get_active_buff_ids() == ["gauge_max", "move_speed"], "snapshot buff list should not alias state")
	_expect(state.get_triggered_stages() == [4], "snapshot stage list should not alias state")

	var revision_before_reset: int = state.get_revision()
	state.reset()
	_expect(state.get_active_stage() == 0, "reset should clear active stage")
	_expect(state.get_roll_face() == 0, "reset should clear roll face")
	_expect(state.get_active_buff_ids().is_empty(), "reset should clear active buffs")
	_expect(state.get_triggered_stages().is_empty(), "reset should clear stage history")
	_expect(state.get_revision() == revision_before_reset + 1, "reset should advance revision once")
	_expect_close(state.get_multiplier_for_buff("move_speed"), 1.0, "reset should neutralize all blessing multipliers")


func _has_duplicates(values: Array) -> bool:
	var seen: Dictionary = {}
	for value: Variant in values:
		var key: String = str(value)
		if seen.has(key):
			return true
		seen[key] = true
	return false


func _expect_close(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
