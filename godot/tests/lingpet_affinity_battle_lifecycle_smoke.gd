extends SceneTree

const LingpetAffinityBattleLifecycle := preload("res://scripts/lingpet/lingpet_affinity_battle_lifecycle.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")


class FakeAffinityState:
	extends RefCounted

	var settle_calls := 0
	var discard_calls := 0
	var reset_calls := 0
	var victory_settlement := {
		"settled": {"maribo": 1},
		"discarded": {},
		"total_settled": 1,
		"total_discarded": 0,
	}
	var defeat_settlement := {
		"discarded": {"maribo": 1},
		"total_discarded": 1,
	}

	func settle_bond_level_ups_for_victory() -> Dictionary:
		settle_calls += 1
		return victory_settlement.duplicate(true)

	func discard_pending_bond_level_ups() -> Dictionary:
		discard_calls += 1
		return defeat_settlement.duplicate(true)

	func reset_for_new_battle() -> void:
		reset_calls += 1


class FakeIncomeTracker:
	extends RefCounted

	var flush_reasons: Array[String] = []

	func flush_battle_log(reason: String = "battle_reset") -> void:
		flush_reasons.append(reason)


class GrantRecorder:
	extends RefCounted

	var calls: Array[Dictionary] = []

	func grant(pet_id: String, source: String, tags: Dictionary, registry: Object = null) -> Dictionary:
		calls.append({
			"pet_id": pet_id,
			"source": source,
			"tags": tags.duplicate(true),
			"registry": registry,
		})
		return {"granted_points": 0.0}


var _failures: Array[String] = []


func _init() -> void:
	_verify_score_event_grant_and_settlement_policy()
	_verify_battle_reset_flushes_and_clears_settlement()
	_verify_runtime_delegates_score_lifecycle()

	if _failures.is_empty():
		print("lingpet_affinity_battle_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_score_event_grant_and_settlement_policy() -> void:
	var lifecycle := LingpetAffinityBattleLifecycle.new()
	var state := FakeAffinityState.new()
	var grants := GrantRecorder.new()
	var registry := RefCounted.new()

	lifecycle.handle_score_event("player", {"match_finished": true}, registry, "", state, Callable(grants, "grant"))
	_expect_eq(grants.calls.size(), 0, "match finish with no active pet should not create affinity grants")
	_expect_eq(state.settle_calls, 1, "player match finish should still settle any pre-existing pending bond ledger")

	lifecycle.reset_all()
	grants.calls.clear()
	lifecycle.handle_score_event("boss", {"match_finished": false}, registry, "maribo", state, Callable(grants, "grant"))
	_expect_eq(grants.calls.size(), 0, "boss-scored non-finish point must not grant round affinity")
	_expect_eq(state.discard_calls, 0, "boss non-finish point should not discard pending bond levels")

	lifecycle.handle_score_event("player", {"match_finished": false}, registry, "maribo", state, Callable(grants, "grant"))
	_expect_eq(grants.calls.size(), 1, "player-scored point should grant one round commit")
	_expect_str(str(grants.calls[0].get("pet_id", "")), "maribo", "round commit should normalize the pet id")
	_expect_str(str(grants.calls[0].get("source", "")), LingpetAffinityState.SOURCE_ROUND_COMMIT, "player point should grant the round-commit source")

	grants.calls.clear()
	var settle_before := state.settle_calls
	lifecycle.handle_score_event("player", {"match_finished": true}, registry, "Maribo", state, Callable(grants, "grant"))
	_expect_eq(grants.calls.size(), 3, "player match finish should grant round commit, victory and stage clear")
	_expect_str(str(grants.calls[0].get("source", "")), LingpetAffinityState.SOURCE_ROUND_COMMIT, "player match finish should grant round commit first")
	_expect_str(str(grants.calls[1].get("source", "")), LingpetAffinityState.SOURCE_VICTORY, "player match finish should grant victory second")
	_expect_str(str(grants.calls[2].get("source", "")), LingpetAffinityState.SOURCE_STAGE_CLEAR, "player match finish should grant stage clear third")
	_expect_eq(state.settle_calls, settle_before + 1, "player match finish should settle pending bond levels")
	var victory_settlement: Dictionary = lifecycle.get_last_bond_settlement()
	_expect_eq(int((victory_settlement.get("settled", {}) as Dictionary).get("maribo", 0)), 1, "victory settlement should be exposed through the lifecycle")

	grants.calls.clear()
	lifecycle.handle_score_event("boss", {"match_finished": true}, registry, "maribo", state, Callable(grants, "grant"))
	_expect_eq(grants.calls.size(), 0, "boss match finish should not grant round or victory affinity")
	_expect_eq(state.discard_calls, 1, "boss match finish should discard pending bond levels")
	var defeat_settlement: Dictionary = lifecycle.get_last_bond_settlement()
	_expect_eq(int((defeat_settlement.get("discarded", {}) as Dictionary).get("maribo", 0)), 1, "defeat settlement should expose discarded pending levels")


func _verify_battle_reset_flushes_and_clears_settlement() -> void:
	var lifecycle := LingpetAffinityBattleLifecycle.new()
	var state := FakeAffinityState.new()
	var income := FakeIncomeTracker.new()
	lifecycle.handle_score_event("player", {"match_finished": true}, null, "maribo", state, Callable(GrantRecorder.new(), "grant"))
	_expect(not lifecycle.get_last_bond_settlement().is_empty(), "reset fixture should start with a visible settlement")
	lifecycle.reset_for_new_battle(income, state)
	_expect_eq(income.flush_reasons.size(), 1, "battle reset should flush the affinity income tracker")
	_expect_str(income.flush_reasons[0], "battle_reset", "battle reset should use the canonical income flush reason")
	_expect_eq(state.reset_calls, 1, "battle reset should reset the affinity battle caps")
	_expect(lifecycle.get_last_bond_settlement().is_empty(), "battle reset should clear the last bond settlement")


func _verify_runtime_delegates_score_lifecycle() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var lifecycle_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_battle_lifecycle.gd")
	_expect(runtime_source.find("LingpetAffinityBattleLifecycle") >= 0, "egg runtime should preload the focused affinity battle lifecycle")
	_expect(runtime_source.find("_affinity_battle_lifecycle.handle_score_event") >= 0, "egg runtime score-event API should delegate to the lifecycle owner")
	_expect(runtime_source.find("var _last_affinity_bond_settlement") < 0, "egg runtime should not keep the bond settlement cache locally")
	_expect(runtime_source.find("settle_bond_level_ups_for_victory") < 0, "egg runtime should not settle bond levels inline")
	_expect(runtime_source.find("discard_pending_bond_level_ups") < 0, "egg runtime should not discard bond levels inline")
	_expect(lifecycle_source.find("settle_bond_level_ups_for_victory") >= 0, "lifecycle owner should settle victory bond levels")
	_expect(lifecycle_source.find("discard_pending_bond_level_ups") >= 0, "lifecycle owner should discard defeat bond levels")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected '%s', got '%s')" % [message, expected, actual])
