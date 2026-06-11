extends SceneTree

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_requirement_curve_and_reward_track()
	_verify_bond_title_boundaries()
	_verify_round_commit_gain_and_victory_gate()
	_verify_ball_hit_stall_cap()
	_verify_same_round_caps_are_battle_global()
	_verify_defense_bonus_is_tagged_and_capped()
	_verify_click_caps_are_battle_global()
	_verify_hatch_bonus_is_per_pet_once()
	_verify_headstart_preserves_previous_best()
	_verify_reset_lifecycle()
	_verify_dirty_flag()
	_verify_scalar_getters_do_not_create_entries()
	_verify_reward_deck_determinism_and_dead_draw()
	_verify_bond_pending_ledger_and_settlement()

	if _failures.is_empty():
		print("lingpet_affinity_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_bond_title_boundaries() -> void:
	_expect_str(LingpetAffinityState.get_bond_title_for_points(0), "어색함", "bond title should treat zero points as the first title band")
	_expect_str(LingpetAffinityState.get_bond_title_for_points(5), "어색함", "bond title should keep 1-5 in the awkward band")
	_expect_str(LingpetAffinityState.get_bond_title_for_points(6), "가까워짐", "bond title should move 6-10 into the closer band")
	_expect_str(LingpetAffinityState.get_bond_title_for_points(10), "가까워짐", "bond title should keep 10 in the closer band")
	_expect_str(LingpetAffinityState.get_bond_title_for_points(11), "친함", "bond title should move 11-15 into the friendly band")
	_expect_str(LingpetAffinityState.get_bond_title_for_points(15), "친함", "bond title should keep 15 in the friendly band")
	_expect_str(LingpetAffinityState.get_bond_title_for_points(16), "단짝", "bond title should move 16-20 into the best-friend band")
	_expect_str(LingpetAffinityState.get_bond_title_for_points(20), "단짝", "bond title should keep 20 in the best-friend band")
	_expect_str(LingpetAffinityState.get_bond_title_for_points(21), "영혼의 단짝", "bond title should move 21+ into the soulmate band")
	_expect_str(LingpetAffinityState.get_bond_title_for_points(30), "영혼의 단짝", "bond title should keep values above the 25 display cap at the top title")


func _verify_requirement_curve_and_reward_track() -> void:
	var state := LingpetAffinityState.new()
	_expect_float(LingpetAffinityState.get_requirement_for_level(0), 50.0, "Lv0 should need 50 for the first level")
	_expect_float(LingpetAffinityState.get_requirement_for_level(1), 75.0, "Lv1 should need 75 for the second level")
	_expect_float(LingpetAffinityState.get_requirement_for_level(2), 100.0, "Lv2+ should need 100 per level")
	_expect_float(LingpetAffinityState.get_requirement_for_level(12), 100.0, "Lv12 should still advance in the 15-level v2 track")
	_expect_float(LingpetAffinityState.get_requirement_for_level(15), 0.0, "Lv15 should have no next requirement")
	var first_commit: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect_float(float(first_commit.get("granted_points", 0.0)), 5.0, "round commit should grant exactly five points")
	for _i in range(223):
		state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect_eq(state.get_level("maribo"), 11, "224 commits should stop at Lv11")
	_expect_float(state.get_points("maribo"), 95.0, "224 commits should leave 95 points toward Lv12")
	var hatch_result: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_HATCH)
	_expect_float(float(hatch_result.get("granted_points", 0.0)), 25.0, "hatch should still grant at Lv11")
	_expect_eq(state.get_level("maribo"), 12, "Lv11 plus hatch bonus should reach Lv12")
	_expect_float(state.get_points("maribo"), 20.0, "Lv12 should retain carried points toward Lv13 in the v2 track")
	_expect_eq(state.get_best_level("maribo"), 12, "best level should track the max reached level")
	for _i in range(56):
		state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect_eq(state.get_level("maribo"), 15, "Lv12 plus 280 points should reach v2 max Lv15")
	_expect_float(state.get_points("maribo"), 0.0, "max level should discard overflow and keep points at 0")
	_expect_eq(state.get_best_level("maribo"), 15, "best level should track the v2 max reached level")
	var rewards := state.get_cumulative_rewards("maribo")
	_expect_eq(int(rewards.get("active_skill_bonus", 0)), 4, "Lv15 should grant four active skill bonuses")
	_expect_eq(int(rewards.get("passive_skill_bonus", 0)), 4, "Lv15 should grant four passive skill bonuses")
	_expect_eq(int(rewards.get("mobility_stacks", 0)), 3, "Lv15 patrol deck should grant three mobility stacks")
	_expect_eq(int(rewards.get("defense_stacks", 0)), 2, "Lv15 patrol deck should grant two defense stacks")
	_expect_eq(int(rewards.get("gauge_stacks", 0)), 2, "Lv15 patrol deck should grant two gauge stacks")
	_expect_eq(int(rewards.get("support_stacks", 0)), 4, "support stacks should mirror defense plus gauge cards")
	_expect(bool(rewards.get("title_unlocked", false)), "Lv15 should unlock the heart resonance title reward")


func _verify_round_commit_gain_and_victory_gate() -> void:
	var eligible := LingpetAffinityState.new()
	eligible.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	eligible.add_points("lunabi", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	eligible.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	var win: Dictionary = eligible.add_points("maribo", LingpetAffinityState.SOURCE_VICTORY)
	_expect_float(float(win.get("granted_points", 0.0)), 20.0, "50 percent or higher participation should receive victory points")
	var duplicate: Dictionary = eligible.add_points("maribo", LingpetAffinityState.SOURCE_VICTORY)
	_expect_float(float(duplicate.get("granted_points", 0.0)), 0.0, "victory should self-seal after one payout")
	_expect_str(str(duplicate.get("blocked_reason", "")), "victory_already_paid", "duplicate victory should report its seal")

	var below_half := LingpetAffinityState.new()
	below_half.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	below_half.add_points("lunabi", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	below_half.add_points("lunabi", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	var lost_gate: Dictionary = below_half.add_points("maribo", LingpetAffinityState.SOURCE_VICTORY)
	_expect_float(float(lost_gate.get("granted_points", 0.0)), 0.0, "below 50 percent participation should not receive victory points")
	_expect_str(str(lost_gate.get("blocked_reason", "")), "ineligible", "below-half victory should report ineligible")

	var no_commit := LingpetAffinityState.new()
	var no_commit_win: Dictionary = no_commit.add_points("maribo", LingpetAffinityState.SOURCE_VICTORY, {"eligible": true})
	_expect_float(float(no_commit_win.get("granted_points", 0.0)), 0.0, "tag-only victory without committed rounds should fail closed")
	_expect_str(str(no_commit_win.get("blocked_reason", "")), "ineligible", "tag-only victory should report ineligible")

	var explicit_false := LingpetAffinityState.new()
	explicit_false.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	var false_tag: Dictionary = explicit_false.add_points("maribo", LingpetAffinityState.SOURCE_VICTORY, {"eligible": false})
	_expect_float(float(false_tag.get("granted_points", 0.0)), 0.0, "explicit ineligible tag should remain a blocking override")
	_expect_str(str(false_tag.get("blocked_reason", "")), "ineligible", "explicit ineligible tag should report ineligible")

	var max_pet_denominator := LingpetAffinityState.new()
	for _i in range(224):
		max_pet_denominator.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	max_pet_denominator.add_points("maribo", LingpetAffinityState.SOURCE_HATCH)
	for _i in range(56):
		max_pet_denominator.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	max_pet_denominator.reset_battle_caps()
	for _i in range(3):
		max_pet_denominator.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	for _i in range(2):
		max_pet_denominator.add_points("lunabi", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	var late_swap_win: Dictionary = max_pet_denominator.add_points("lunabi", LingpetAffinityState.SOURCE_VICTORY)
	_expect_float(float(late_swap_win.get("granted_points", 0.0)), 0.0, "max-level pet commits should still count in the victory denominator")
	_expect_str(str(late_swap_win.get("blocked_reason", "")), "ineligible", "late-swap pet should be below 50 percent when max-level commits are counted")


func _verify_ball_hit_stall_cap() -> void:
	var state := LingpetAffinityState.new()
	var total := 0.0
	for _i in range(10):
		var result: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT)
		total += float(result.get("granted_points", 0.0))
	_expect_float(total, 44.0, "ten ball hits in one round should grant 4*8 + 6*2")
	_expect_eq(state.get_level("maribo"), 0, "44 points should stay below first level")
	state.reset_round_caps()
	var next_result: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT)
	_expect_float(float(next_result.get("granted_points", 0.0)), 8.0, "new round should restore full ball-hit value")
	_expect_eq(state.get_level("maribo"), 1, "44 + 8 should cross the first 50-point level")
	_expect_float(state.get_points("maribo"), 2.0, "first level should leave two carried points")


func _verify_same_round_caps_are_battle_global() -> void:
	var click_state := LingpetAffinityState.new()
	click_state.add_points("maribo", LingpetAffinityState.SOURCE_CLICK)
	click_state.add_points("maribo", LingpetAffinityState.SOURCE_CLICK)
	var swapped_click: Dictionary = click_state.add_points("lunabi", LingpetAffinityState.SOURCE_CLICK)
	_expect_float(float(swapped_click.get("granted_points", 0.0)), 0.0, "same-round click cap should be shared across pets")
	_expect_str(str(swapped_click.get("blocked_reason", "")), "round_cap", "same-round swapped click should report round cap")

	var hit_state := LingpetAffinityState.new()
	for _i in range(4):
		hit_state.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT)
	var swapped_hit: Dictionary = hit_state.add_points("lunabi", LingpetAffinityState.SOURCE_BALL_HIT)
	_expect_float(float(swapped_hit.get("granted_points", 0.0)), 2.0, "same-round ball-hit full cap should be shared across pets")

	var defense_state := LingpetAffinityState.new()
	for _i in range(2):
		defense_state.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT, {"defense_intercept": true})
	var swapped_defense: Dictionary = defense_state.add_points("lunabi", LingpetAffinityState.SOURCE_BALL_HIT, {"ring_dash_block": true})
	_expect_float(float(swapped_defense.get("granted_points", 0.0)), 8.0, "same-round defense cap should block bonus across pets")
	_expect_float(float(swapped_defense.get("bonus_points", 0.0)), 0.0, "same-round swapped defense should not receive a third bonus")


func _verify_defense_bonus_is_tagged_and_capped() -> void:
	_expect_one_defense_hit({"defense_intercept": true}, "defense_intercept")
	_expect_one_defense_hit({"ring_dash_block": true}, "ring_dash_block")
	_expect_one_defense_hit({"defense_intercept": true, "ring_dash_block": true}, "combined defense tags")

	var state := LingpetAffinityState.new()
	var total := 0.0
	var third_bonus := 0.0
	for index in range(3):
		var result: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT, {
			"defense_intercept": true,
			"ring_dash_block": true,
		})
		total += float(result.get("granted_points", 0.0))
		if index == 2:
			third_bonus = float(result.get("bonus_points", 0.0))
	_expect_float(total, 34.0, "three tagged hits should grant 3*8 plus two defense bonuses")
	_expect_float(third_bonus, 0.0, "third tagged hit should not receive another defense bonus")
	_expect_float(state.get_points("maribo"), 34.0, "combined defense tags should not double-pay")


func _expect_one_defense_hit(tags: Dictionary, label: String) -> void:
	var state := LingpetAffinityState.new()
	var result: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT, tags)
	_expect_float(float(result.get("granted_points", 0.0)), 13.0, "%s should grant base plus one defense bonus" % label)
	_expect_float(float(result.get("bonus_points", 0.0)), 5.0, "%s should report exactly five bonus points" % label)


func _verify_click_caps_are_battle_global() -> void:
	var state := LingpetAffinityState.new()
	var maribo_total := 0.0
	for _i in range(3):
		var result: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_CLICK)
		maribo_total += float(result.get("granted_points", 0.0))
	_expect_float(maribo_total, 10.0, "round click cap should allow only two clicks")
	state.reset_round_caps()
	var lunabi_total := 0.0
	for _i in range(2):
		var result: Dictionary = state.add_points("lunabi", LingpetAffinityState.SOURCE_CLICK)
		lunabi_total += float(result.get("granted_points", 0.0))
	_expect_float(lunabi_total, 10.0, "second pet should share the same battle cap but get fresh round cap")
	state.reset_round_caps()
	for _i in range(3):
		var result: Dictionary = state.add_points("lunabi", LingpetAffinityState.SOURCE_CLICK)
		lunabi_total += float(result.get("granted_points", 0.0))
	_expect_float(lunabi_total, 15.0, "battle-global click cap should stop at five total clicks across pets")
	_expect_float(state.get_points("maribo"), 10.0, "first pet click points should be unchanged")
	_expect_float(state.get_points("lunabi"), 15.0, "second pet should receive only the remaining battle click budget")


func _verify_hatch_bonus_is_per_pet_once() -> void:
	var state := LingpetAffinityState.new()
	var first: Dictionary = state.add_points("Maribo ", LingpetAffinityState.SOURCE_HATCH)
	var duplicate: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_HATCH)
	var other_pet: Dictionary = state.add_points("lunabi", LingpetAffinityState.SOURCE_HATCH)
	_expect_float(float(first.get("granted_points", 0.0)), 25.0, "first hatch should grant the contract bonus")
	_expect_float(float(duplicate.get("granted_points", 0.0)), 0.0, "duplicate hatch for the same normalized pet should not regrant")
	_expect_str(str(duplicate.get("blocked_reason", "")), "hatch_bonus_granted", "duplicate hatch should report its gate")
	_expect_float(float(other_pet.get("granted_points", 0.0)), 25.0, "different pet may receive its own hatch bonus")
	_expect_eq(state.get_tracked_pet_ids().size(), 2, "normalized hatch ids should create only two pet entries")


func _verify_headstart_preserves_previous_best() -> void:
	var headstart_with_points := LingpetAffinityState.new()
	headstart_with_points.add_points("maribo", LingpetAffinityState.SOURCE_HATCH)
	var data: Dictionary = headstart_with_points.apply_headstart_from_best("maribo", 30)
	_expect_eq(int(data.get("affinity_level", 0)), 4, "headstart should clamp to the +4 maximum")
	_expect_float(float(data.get("affinity_points", 0.0)), 25.0, "headstart should not wipe existing run points")
	_expect_eq(int(data.get("best_level", 0)), 15, "headstart should clamp stored best to max level")
	_expect_eq((data.get("reward_history", []) as Array).size(), 4, "headstart should deal the first four reward-history cards")
	_expect_str(str((data.get("reward_counts", {}) as Dictionary).get("signature", "")), headstart_with_points.get_reward_signature("maribo"), "headstart rewards should keep counts and signature coherent")
	headstart_with_points.clear_dirty()
	headstart_with_points.seed_best_level("maribo", 2)
	_expect_eq(headstart_with_points.get_best_level("maribo"), 15, "seed_best_level should not lower existing best")
	_expect(not headstart_with_points.is_dirty(), "seed_best_level load path should not dirty by default")
	var best_levels := headstart_with_points.get_best_levels()
	_expect_eq(int(best_levels.get("maribo", 0)), 15, "get_best_levels should expose the persistent handoff map")

	var state := LingpetAffinityState.new()
	var headstart_data: Dictionary = state.apply_headstart_from_best("maribo", 11)
	_expect_eq(int(headstart_data.get("affinity_level", 0)), 3, "headstart should be floor(best/3)")
	_expect_eq(int(headstart_data.get("best_level", 0)), 11, "headstart should preserve previous best for anti-inflation")
	_expect(state.get_pending_bond_level_ups().is_empty(), "headstart reward history should not enter the pending bond ledger")
	for _i in range(10):
		state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect_eq(state.get_best_level("maribo"), 11, "run below previous best should not rewrite best level")
	for _i in range(180):
		state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect_eq(state.get_best_level("maribo"), 12, "only exceeding previous best should raise best level")


func _verify_reset_lifecycle() -> void:
	var click_state := LingpetAffinityState.new()
	for _i in range(5):
		click_state.reset_round_caps()
		click_state.add_points("maribo", LingpetAffinityState.SOURCE_CLICK)
	click_state.reset_round_caps()
	var capped_click: Dictionary = click_state.add_points("maribo", LingpetAffinityState.SOURCE_CLICK)
	_expect_float(float(capped_click.get("granted_points", 0.0)), 0.0, "battle click budget should cap at five")
	_expect_str(str(capped_click.get("blocked_reason", "")), "battle_cap", "battle click cap should report battle_cap")
	click_state.reset_battle_caps()
	var reloaded_click: Dictionary = click_state.add_points("maribo", LingpetAffinityState.SOURCE_CLICK)
	_expect_float(float(reloaded_click.get("granted_points", 0.0)), 5.0, "new battle should reload click budget")

	var hatch_state := LingpetAffinityState.new()
	hatch_state.add_points("maribo", LingpetAffinityState.SOURCE_HATCH)
	hatch_state.clear_dirty()
	hatch_state.reset_battle_caps()
	var blocked_hatch: Dictionary = hatch_state.add_points("maribo", LingpetAffinityState.SOURCE_HATCH)
	_expect_float(float(blocked_hatch.get("granted_points", 0.0)), 0.0, "battle reset should not reload hatch bonus")
	_expect(not hatch_state.is_dirty(), "blocked hatch after battle reset should not dirty state")
	hatch_state.reset_all()
	_expect(not hatch_state.is_dirty(), "reset_all should leave a clean run state")
	var fresh_hatch: Dictionary = hatch_state.add_points("maribo", LingpetAffinityState.SOURCE_HATCH)
	_expect_float(float(fresh_hatch.get("granted_points", 0.0)), 25.0, "run reset should allow fresh hatch bonus")


func _verify_dirty_flag() -> void:
	var state := LingpetAffinityState.new()
	_expect(not state.is_dirty(), "new affinity state should start clean")
	state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect(state.is_dirty(), "point grant should mark state dirty")
	state.clear_dirty()
	_expect(not state.is_dirty(), "clear_dirty should clear the dirty flag")
	state.add_points("maribo", "unknown")
	_expect(not state.is_dirty(), "blocked unknown source should not dirty runtime state")

	var cap_state := LingpetAffinityState.new()
	cap_state.add_points("maribo", LingpetAffinityState.SOURCE_CLICK)
	cap_state.add_points("maribo", LingpetAffinityState.SOURCE_CLICK)
	cap_state.clear_dirty()
	var blocked_click: Dictionary = cap_state.add_points("maribo", LingpetAffinityState.SOURCE_CLICK)
	_expect_float(float(blocked_click.get("granted_points", 0.0)), 0.0, "blocked click cap should grant no points")
	_expect(not cap_state.is_dirty(), "blocked click cap should not dirty state")

	var hatch_state := LingpetAffinityState.new()
	hatch_state.add_points("maribo", LingpetAffinityState.SOURCE_HATCH)
	hatch_state.clear_dirty()
	hatch_state.add_points("maribo", LingpetAffinityState.SOURCE_HATCH)
	_expect(not hatch_state.is_dirty(), "duplicate hatch should not dirty state")

	var max_state := LingpetAffinityState.new()
	for _i in range(224):
		max_state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	max_state.add_points("maribo", LingpetAffinityState.SOURCE_HATCH)
	for _i in range(56):
		max_state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	max_state.clear_dirty()
	var max_block: Dictionary = max_state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect_float(float(max_block.get("granted_points", 0.0)), 0.0, "max-level grant should be blocked")
	_expect_str(str(max_block.get("blocked_reason", "")), "max_level", "max-level grant should report max_level")
	_expect(not max_state.is_dirty(), "max-level blocked grant should not dirty state")
	_expect_float(max_state.get_points("maribo"), 0.0, "max-level blocked grant should preserve zero points")


func _verify_scalar_getters_do_not_create_entries() -> void:
	var state := LingpetAffinityState.new()
	_expect_eq(state.get_level("typo"), 0, "unknown pet level should read as zero")
	_expect_float(state.get_points("typo"), 0.0, "unknown pet points should read as zero")
	_expect_eq(state.get_best_level("typo"), 0, "unknown pet best should read as zero")
	_expect_float(state.get_next_requirement("typo"), 50.0, "unknown pet next requirement should read as first requirement")
	var rewards := state.get_cumulative_rewards("typo")
	_expect_eq(int(rewards.get("active_skill_bonus", 0)), 0, "unknown pet rewards should be empty")
	_expect(state.get_pet_data("typo").is_empty(), "unknown pet snapshot should be empty")
	_expect(state.get_tracked_pet_ids().is_empty(), "scalar getters and snapshots should not create phantom pet entries")
	_expect(state.get_reward_deck("typo").is_empty(), "unknown pet deck snapshot should not create a phantom pet entry")
	_expect(state.get_tracked_pet_ids().is_empty(), "deck snapshots should not create phantom pet entries")


func _verify_reward_deck_determinism_and_dead_draw() -> void:
	var first := LingpetAffinityState.new()
	first.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true)
	var first_deck := first.get_reward_deck("maribo")
	var first_data: Dictionary = first.get_pet_data("maribo")
	_expect_eq(int(first_data.get("reward_seed", 0)), 777, "seed injection should be stored in run state")
	var second := LingpetAffinityState.new()
	second.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true)
	var second_deck := second.get_reward_deck("maribo")
	var different_seed := LingpetAffinityState.new()
	different_seed.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 778, true)
	var different_deck := different_seed.get_reward_deck("maribo")
	var default_seed := LingpetAffinityState.new()
	default_seed.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1)
	var default_deck := default_seed.get_reward_deck("maribo")
	_expect_str(_reward_type_sequence(first_deck), _reward_type_sequence(second_deck), "seeded reward decks should be deterministic")
	_expect(_reward_type_sequence(first_deck) != _reward_type_sequence(different_deck), "different reward seeds should change the shuffled deck order")
	_expect(_reward_type_sequence(first_deck) != _reward_type_sequence(default_deck), "explicit test seeds should be consumed instead of falling back to the pet hash")
	_expect_eq(first_deck.size(), LingpetAffinityState.MAX_LEVEL, "reward deck should cover every v2 level")
	_expect_str(str(first_deck[0].get("type", "")), LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, "Lv1 reward should remain fixed to active skill")
	_expect_eq(_reward_type_count(first_deck, LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, 0, 10), 4, "all active skill cards should appear by Lv10")
	_expect_eq(_reward_type_count(first_deck, LingpetAffinityState.REWARD_TYPE_PASSIVE_SKILL, 0, 10), 4, "all passive skill cards should appear by Lv10")
	for seed in [1, 2, 777, 778, 991]:
		var patrol := LingpetAffinityState.new()
		patrol.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, int(seed), true)
		_expect_reward_bands(patrol.get_reward_deck("maribo"), false, "patrol seed %d" % int(seed))
		var seeded_flight := LingpetAffinityState.new()
		seeded_flight.configure_reward_context("rabi", LingpetAffinityState.MOTION_STYLE_FLIGHT, 1, 1, int(seed), true)
		_expect_reward_bands(seeded_flight.get_reward_deck("rabi"), true, "flight seed %d" % int(seed))

	var flight := LingpetAffinityState.new()
	flight.configure_reward_context("rabi", LingpetAffinityState.MOTION_STYLE_FLIGHT, 1, 1, 777, true)
	var flight_deck := flight.get_reward_deck("rabi")
	_expect_eq(_reward_type_count(flight_deck, LingpetAffinityState.REWARD_TYPE_DEFENSE), 0, "flight decks should not contain dead defense cards")
	_expect_eq(_reward_type_count(flight_deck, LingpetAffinityState.REWARD_TYPE_GAUGE), 4, "flight decks should spend the late support band on gauge cards")

	var capped_skills := LingpetAffinityState.new()
	capped_skills.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 5, 5, 777, true)
	var advertised := capped_skills.get_next_reward("maribo")
	_expect_str(str(advertised.get("replaced_type", "")), LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, "next reward should advertise the effective replacement for a capped skill card")
	_expect(str(advertised.get("type", "")) != LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, "next reward should not advertise a skill card that will dead-draw")
	var level_result: Dictionary = {}
	for _i in range(10):
		level_result = capped_skills.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	var awarded: Array = level_result.get("rewards", []) as Array
	_expect_eq(capped_skills.get_level("maribo"), 1, "ten round commits should reach Lv1 for dead-draw replacement")
	_expect_eq(awarded.size(), 1, "Lv1 grant should report exactly one awarded card")
	if awarded.size() > 0 and awarded[0] is Dictionary:
		var card: Dictionary = awarded[0] as Dictionary
		_expect_str(str(card.get("replaced_type", "")), LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, "capped active card should record its dead-draw replacement")
		_expect(str(card.get("type", "")) != LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, "dead active card should be replaced with a valid stat card")
	var rewards := capped_skills.get_cumulative_rewards("maribo")
	_expect_eq(int(rewards.get("active_skill_bonus", 0)), 0, "dead-draw replacement should not overcap active skill rewards")
	_expect_eq(int(rewards.get("passive_skill_bonus", 0)), 0, "dead-draw replacement should not overcap passive skill rewards")
	_expect_eq(int(rewards.get("mobility_stacks", 0)) + int(rewards.get("defense_stacks", 0)) + int(rewards.get("gauge_stacks", 0)), 1, "dead-draw replacement should grant one stat card")

	var exhausted_flight := LingpetAffinityState.new()
	exhausted_flight.configure_reward_context("rabi", LingpetAffinityState.MOTION_STYLE_FLIGHT, 5, 5, 777, true)
	for _i in range(285):
		exhausted_flight.add_points("rabi", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	var exhausted_rewards := exhausted_flight.get_cumulative_rewards("rabi")
	_expect_eq(int(exhausted_rewards.get("active_skill_bonus", 0)), 0, "exhausted dead-draws should not overcap active skills")
	_expect_eq(int(exhausted_rewards.get("passive_skill_bonus", 0)), 0, "exhausted dead-draws should not overcap passive skills")
	_expect_eq(int(exhausted_rewards.get("gauge_stacks", 0)), LingpetAffinityState.MAX_GAUGE_STACKS, "exhausted flight deck should clamp gauge cards at the v2 cap")
	_expect_eq(int(exhausted_rewards.get("mobility_stacks", 0)), LingpetAffinityState.MAX_MOBILITY_STACKS, "exhausted flight deck should clamp mobility replacements at the v2 cap")
	var exhausted_history: Array = exhausted_flight.get_pet_data("rabi").get("reward_history", []) as Array
	_expect_eq(exhausted_history.size(), LingpetAffinityState.MAX_LEVEL, "no-reward markers should preserve one history entry per level")
	_expect(_history_has_no_reward_marker(exhausted_history), "exhausted replacement pool should record a non-counting no-reward marker")


func _verify_bond_pending_ledger_and_settlement() -> void:
	var eligible := LingpetAffinityState.new()
	for _i in range(10):
		eligible.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	var pending := eligible.get_pending_bond_level_ups()
	_expect_eq(int(pending.get("maribo", 0)), 1, "level-ups should enter the battle pending bond ledger")
	var settled: Dictionary = eligible.settle_bond_level_ups_for_victory()
	_expect_eq(int((settled.get("settled", {}) as Dictionary).get("maribo", 0)), 1, "eligible pet should settle its pending bond levels on victory")
	_expect(eligible.get_pending_bond_level_ups().is_empty(), "victory settlement should clear the pending bond ledger")

	var ineligible := LingpetAffinityState.new()
	for _i in range(10):
		ineligible.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	for _i in range(11):
		ineligible.add_points("lunabi", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	var gated: Dictionary = ineligible.settle_bond_level_ups_for_victory()
	_expect_eq(int((gated.get("discarded", {}) as Dictionary).get("maribo", 0)), 1, "below-50-percent pet should discard its pending bond levels")
	_expect_eq(int((gated.get("settled", {}) as Dictionary).get("lunabi", 0)), 1, "eligible swapped pet should settle its own pending bond levels")

	var defeated := LingpetAffinityState.new()
	for _i in range(10):
		defeated.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	var discarded: Dictionary = defeated.discard_pending_bond_level_ups()
	_expect_eq(int((discarded.get("discarded", {}) as Dictionary).get("maribo", 0)), 1, "defeat discard should return the pending bond levels")
	_expect(defeated.get_pending_bond_level_ups().is_empty(), "defeat discard should clear the pending bond ledger")

	var reset := LingpetAffinityState.new()
	for _i in range(10):
		reset.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	reset.reset_battle_caps()
	_expect(reset.get_pending_bond_level_ups().is_empty(), "battle reset should discard pending bond levels")


func _reward_type_sequence(deck: Array) -> String:
	var parts: Array[String] = []
	for raw_card in deck:
		if raw_card is Dictionary:
			parts.append(str((raw_card as Dictionary).get("type", "")))
	return ",".join(parts)


func _reward_type_count(deck: Array, reward_type: String, start_index: int = 0, end_index: int = -1) -> int:
	var count := 0
	var clamped_end := deck.size() if end_index < 0 else mini(end_index, deck.size())
	for index in range(maxi(0, start_index), clamped_end):
		var raw_card: Variant = deck[index]
		if raw_card is Dictionary and str((raw_card as Dictionary).get("type", "")) == reward_type:
			count += 1
	return count


func _expect_reward_bands(deck: Array, flight_style: bool, label: String) -> void:
	_expect_eq(deck.size(), LingpetAffinityState.MAX_LEVEL, "%s deck should cover all levels" % label)
	if deck.size() < LingpetAffinityState.MAX_LEVEL:
		return
	_expect_str(str((deck[0] as Dictionary).get("type", "")), LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, "%s Lv1 should be fixed active" % label)
	_expect_eq(_reward_type_count(deck, LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, 0, 5), 2, "%s Lv1-5 should contain two active cards" % label)
	_expect_eq(_reward_type_count(deck, LingpetAffinityState.REWARD_TYPE_PASSIVE_SKILL, 0, 5), 2, "%s Lv1-5 should contain two passive cards" % label)
	_expect_eq(_reward_type_count(deck, LingpetAffinityState.REWARD_TYPE_MOBILITY, 0, 5), 1, "%s Lv1-5 should contain one mobility card" % label)
	_expect_eq(_reward_type_count(deck, LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, 5, 10), 2, "%s Lv6-10 should contain two active cards" % label)
	_expect_eq(_reward_type_count(deck, LingpetAffinityState.REWARD_TYPE_PASSIVE_SKILL, 5, 10), 2, "%s Lv6-10 should contain two passive cards" % label)
	_expect_eq(_reward_type_count(deck, LingpetAffinityState.REWARD_TYPE_MOBILITY, 5, 10), 1, "%s Lv6-10 should contain one mobility card" % label)
	_expect_eq(_reward_type_count(deck, LingpetAffinityState.REWARD_TYPE_MOBILITY, 10, 15), 1, "%s Lv11-15 should contain one mobility card" % label)
	if flight_style:
		_expect_eq(_reward_type_count(deck, LingpetAffinityState.REWARD_TYPE_DEFENSE, 10, 15), 0, "%s flight late band should contain zero defense cards" % label)
		_expect_eq(_reward_type_count(deck, LingpetAffinityState.REWARD_TYPE_GAUGE, 10, 15), 4, "%s flight late band should contain four gauge cards" % label)
	else:
		_expect_eq(_reward_type_count(deck, LingpetAffinityState.REWARD_TYPE_DEFENSE, 10, 15), 2, "%s patrol late band should contain two defense cards" % label)
		_expect_eq(_reward_type_count(deck, LingpetAffinityState.REWARD_TYPE_GAUGE, 10, 15), 2, "%s patrol late band should contain two gauge cards" % label)


func _history_has_no_reward_marker(history: Array) -> bool:
	for raw_card in history:
		if raw_card is Dictionary and str((raw_card as Dictionary).get("type", "")) == LingpetAffinityState.REWARD_TYPE_NO_REWARD:
			return true
	return false


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
