extends SceneTree

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetAffinityStore := preload("res://scripts/lingpet/lingpet_affinity_store.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_requirement_curve_and_30_level_track()
	_verify_ring_core_cap_clamps_overflow()
	_verify_unlock_cards_and_choice_state()
	_verify_reward_deck_determinism_and_bands()
	_verify_skill_level_up_cards_require_unlocks()
	_verify_dead_draw_does_not_block_unlocks()
	_verify_bond_title_boundaries()
	_verify_round_commit_gain_and_victory_gate()
	_verify_ball_hit_stall_cap()
	_verify_same_round_caps_are_battle_global()
	_verify_defense_bonus_is_tagged_and_capped()
	_verify_click_caps_are_battle_global()
	_verify_flight_opportunity_multiplier()
	_verify_hatch_bonus_is_per_pet_once()
	_verify_headstart_preserves_previous_best()
	_verify_reset_lifecycle()
	_verify_enhancement_chip_multiplier_lifecycle()
	_verify_dirty_flag()
	_verify_scalar_getters_do_not_create_entries()
	_verify_bond_pending_ledger_and_settlement()
	_verify_run_ring_core_tier_api()

	if _failures.is_empty():
		print("lingpet_affinity_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_requirement_curve_and_30_level_track() -> void:
	_expect_eq(LingpetAffinityState.MAX_LEVEL, 30, "V3 affinity max level should be 30")
	_expect_float(LingpetAffinityState.get_requirement_for_level(0), 50.0, "Lv0 should need 50 for the first level")
	_expect_requirement_slice(0, 30, 50.0, "flat 50-point affinity requirement across every level")
	_expect_float(LingpetAffinityState.get_requirement_for_level(30), 0.0, "Lv30 should have no next requirement")
	_expect_float(_requirement_sum_to_max(), 1500.0, "flat 50 over 30 levels should sum to 1,500")

	var state := LingpetAffinityState.new()
	state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	_grant_round_commits(state, "maribo", 835)
	_expect_eq(state.get_level("maribo"), 30, "4,175 points should reach V3 max Lv30")
	_expect_float(state.get_points("maribo"), 0.0, "absolute max Lv30 should discard overflow and keep points at zero")
	_expect_eq(state.get_best_level("maribo"), 30, "best level should track V3 max")
	var rewards := state.get_cumulative_rewards("maribo")
	_expect(bool(rewards.get("active_unlocked", false)), "Lv30 should have first active unlocked")
	_expect(bool(rewards.get("passive_unlocked", false)), "Lv30 should have first passive unlocked")
	_expect(bool(rewards.get("second_active_unlocked", false)), "Lv30 should have second active unlocked")
	_expect(bool(rewards.get("second_passive_unlocked", false)), "Lv30 should have second passive unlocked")
	_expect_eq(int(rewards.get("active_skill_bonus", 0)), 4, "Lv30 should carry four first-active level-up cards")
	_expect_eq(int(rewards.get("passive_skill_bonus", 0)), 4, "Lv30 should carry four first-passive level-up cards")
	_expect_eq(int(rewards.get("second_active_skill_bonus", 0)), 2, "Lv30 placeholder track should carry two second-active level-up cards")
	_expect_eq(int(rewards.get("second_passive_skill_bonus", 0)), 2, "Lv30 placeholder track should carry two second-passive level-up cards")
	_expect(bool(rewards.get("title_unlocked", false)), "Lv30 should unlock heart resonance")
	var max_block: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect_float(float(max_block.get("granted_points", 0.0)), 0.0, "max-level grant should be blocked")
	_expect_str(str(max_block.get("blocked_reason", "")), "max_level", "max-level grant should report max_level")
	_expect_float(state.get_points("maribo"), 0.0, "max-level blocked grant should preserve zero points")


func _verify_ring_core_cap_clamps_overflow() -> void:
	# No ring-core (T0 = cap 0): the bar must read 50/50, not overshoot to 1054/50.
	# Affinity earned beyond the next-level requirement is intentionally wasted so the
	# ring-core stays the investment that makes affinity count.
	var no_core := LingpetAffinityState.new()
	no_core.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 0)
	_grant_round_commits(no_core, "maribo", 200)
	_expect_eq(no_core.get_level("maribo"), 0, "ring-core cap Lv0 should keep the pet at Lv0")
	_expect_float(no_core.get_points("maribo"), 50.0, "cap Lv0 should clamp banked points at the Lv1 requirement (50/50), never overshoot")

	var capped := LingpetAffinityState.new()
	capped.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 5)
	_grant_round_commits(capped, "maribo", 200)
	_expect_eq(capped.get_level("maribo"), 5, "ring-core cap Lv5 should stop level-ups at Lv5")
	_expect_float(capped.get_points("maribo"), 50.0, "temporary cap should clamp overflow at the next-level requirement (Lv5->Lv6 = 50), not bank it unbounded")
	var capped_data: Dictionary = capped.get_pet_data("maribo")
	_expect_eq((capped_data.get("reward_history", []) as Array).size(), 5, "temporary cap should award only up to the capped level")

	capped.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, false, 10)
	capped.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect_eq(capped.get_level("maribo"), 6, "raising the cap should release only the clamped ceiling (bounded head start), not a banked level burst")
	_expect_float(capped.get_points("maribo"), 5.0, "cap release should retain only the post-level-up remainder of the clamped ceiling")
	var released_data: Dictionary = capped.get_pet_data("maribo")
	_expect_eq((released_data.get("reward_history", []) as Array).size(), 6, "cap release should fill reward history only through the bounded head-start level")

	var maxed := LingpetAffinityState.new()
	maxed.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	_grant_round_commits(maxed, "maribo", 900)
	_expect_eq(maxed.get_level("maribo"), 30, "cap 30 fixture should reach max")
	_expect_float(maxed.get_points("maribo"), 0.0, "absolute max should discard overflow entirely")


func _verify_unlock_cards_and_choice_state() -> void:
	var state := LingpetAffinityState.new()
	state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	state.set_unlock_choice_candidates("maribo", LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK, ["hydro", "bubble"])
	_grant_round_commits(state, "maribo", 10)
	_expect_eq(state.get_level("maribo"), 1, "ten round commits should reach Lv1")
	var pending := state.get_pending_unlock_choices("maribo")
	_expect(not pending.has("active"), "Lv1 active unlock should auto-resolve instead of leaving a pending picker choice")
	var resolved := state.get_resolved_unlock_choices("maribo")
	_expect(resolved.has("active"), "active unlock should move directly to the resolved choice map")
	var resolved_active: Dictionary = resolved.get("active", {}) as Dictionary
	var candidates: Array = resolved_active.get("candidates", []) as Array
	_expect_eq(candidates.size(), 2, "active auto-resolve should record both original candidates")
	_expect_str(str(candidates[0]), "hydro", "active auto-resolve should preserve candidate order")
	_expect(candidates.has(str(resolved_active.get("selected", ""))), "active auto-resolve should select one recorded candidate")
	_expect_eq((resolved_active.get("rejected", []) as Array).size(), 1, "active auto-resolve should record the one rejected candidate")
	_expect(bool(resolved_active.get("auto", false)), "active auto-resolve should mark the choice as automatic")
	_expect(bool(resolved_active.get("random", false)), "active auto-resolve should mark two-candidate choices as random")
	var wrong_type_result: Dictionary = state.choose_skill_unlock("maribo", LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, "hydro")
	_expect(not bool(wrong_type_result.get("accepted", false)), "non-unlock reward type should not resolve a choice")
	_expect_str(str(wrong_type_result.get("blocked_reason", "")), "not_unlock_type", "non-unlock reward type should report not_unlock_type")
	var invalid_result: Dictionary = state.choose_skill_unlock("maribo", LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK, "outside")
	_expect(not bool(invalid_result.get("accepted", false)), "manual selection should be rejected after auto-resolve")
	_expect_str(str(invalid_result.get("blocked_reason", "")), "missing_choice", "manual selection should report missing_choice after auto-resolve")
	var repeat_result: Dictionary = state.choose_skill_unlock("maribo", LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK, "hydro")
	_expect(not bool(repeat_result.get("accepted", false)), "resolved unlock choice should not be selectable a second time")
	_expect_str(str(repeat_result.get("blocked_reason", "")), "missing_choice", "resolved unlock choice should report missing_choice on repeat")
	var repeat_resolved := state.get_resolved_unlock_choices("maribo")
	var repeat_active: Dictionary = repeat_resolved.get("active", {}) as Dictionary
	_expect_str(str(repeat_active.get("selected", "")), str(resolved_active.get("selected", "")), "repeat selection should not overwrite the automatic selected skill")

	var same_seed := LingpetAffinityState.new()
	same_seed.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	same_seed.set_unlock_choice_candidates("maribo", LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK, ["hydro", "bubble"])
	_grant_round_commits(same_seed, "maribo", 10)
	var same_seed_active: Dictionary = same_seed.get_resolved_unlock_choices("maribo").get("active", {}) as Dictionary
	_expect_str(str(same_seed_active.get("selected", "")), str(resolved_active.get("selected", "")), "same reward seed should auto-resolve the same active candidate")

	var migration := LingpetAffinityState.new()
	migration.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	var migrate_data: Dictionary = migration.call("_get_or_create_pet_data", "maribo") as Dictionary
	migrate_data["pending_unlock_choices"] = {
		"active": {
			"type": LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK,
			"choice_key": "active",
			"candidates": ["hydro", "bubble"],
			"selected": "",
			"rejected": [],
		},
	}
	migration.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 0, false, 30)
	_expect(not migration.get_pending_unlock_choices("maribo").has("active"), "seeded legacy pending active choice should migrate to automatic resolved state")
	var migrated_active: Dictionary = migration.get_resolved_unlock_choices("maribo").get("active", {}) as Dictionary
	_expect((migrated_active.get("candidates", []) as Array).has(str(migrated_active.get("selected", ""))), "migrated automatic choice should select one of the legacy candidates")


func _verify_reward_deck_determinism_and_bands() -> void:
	var first := LingpetAffinityState.new()
	first.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	var first_deck := first.get_reward_deck("maribo")
	var second := LingpetAffinityState.new()
	second.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	var second_deck := second.get_reward_deck("maribo")
	var different_seed := LingpetAffinityState.new()
	different_seed.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 778, true, 30)
	var different_deck := different_seed.get_reward_deck("maribo")
	_expect_str(_reward_type_sequence(first_deck), _reward_type_sequence(second_deck), "seeded reward decks should be deterministic")
	_expect(_reward_type_sequence(first_deck) != _reward_type_sequence(different_deck), "different reward seeds should change shuffled non-fixed card order")
	_expect_eq(first_deck.size(), LingpetAffinityState.MAX_LEVEL, "reward deck should cover every V3 level")
	_expect_str(str((first_deck[0] as Dictionary).get("type", "")), LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK, "Lv1 should be fixed to first active unlock")
	_expect_str(str((first_deck[1] as Dictionary).get("type", "")), LingpetAffinityState.REWARD_TYPE_PASSIVE_UNLOCK, "Lv2 should be fixed to first passive unlock")
	var second_active_level := _reward_type_first_level(first_deck, LingpetAffinityState.REWARD_TYPE_SECOND_ACTIVE_UNLOCK)
	var second_passive_level := _reward_type_first_level(first_deck, LingpetAffinityState.REWARD_TYPE_SECOND_PASSIVE_UNLOCK)
	_expect(second_active_level >= 16 and second_active_level <= 25, "second active unlock should land inside the Lv16-25 shuffled hatch band")
	_expect(second_passive_level >= 16 and second_passive_level <= 25, "second passive unlock should land inside the Lv16-25 shuffled hatch band")
	_expect_slot2_cards_after_unlock(first_deck, LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, second_active_level, "second active")
	_expect_slot2_cards_after_unlock(first_deck, LingpetAffinityState.REWARD_TYPE_PASSIVE_SKILL, second_passive_level, "second passive")
	_expect_eq(_reward_type_count(first_deck, LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK), 1, "deck should contain exactly one first active unlock")
	_expect_eq(_reward_type_count(first_deck, LingpetAffinityState.REWARD_TYPE_PASSIVE_UNLOCK), 1, "deck should contain exactly one first passive unlock")
	_expect_eq(_reward_type_count(first_deck, LingpetAffinityState.REWARD_TYPE_SECOND_ACTIVE_UNLOCK), 1, "deck should contain exactly one second active unlock")
	_expect_eq(_reward_type_count(first_deck, LingpetAffinityState.REWARD_TYPE_SECOND_PASSIVE_UNLOCK), 1, "deck should contain exactly one second passive unlock")
	for band_start in [0, 5, 10, 15, 20, 25]:
		_expect_eq(_reward_band_size(first_deck, int(band_start), int(band_start) + 5), 5, "each ring-core-aligned band should contain five cards")
	for seed in [1, 2, 777, 778, 991]:
		var patrol := LingpetAffinityState.new()
		patrol.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, int(seed), true, 30)
		_expect_reward_deck_bands(patrol.get_reward_deck("maribo"), "patrol seed %d" % int(seed), LingpetAffinityState.REWARD_TYPE_DEFENSE, LingpetAffinityState.REWARD_TYPE_GAUGE)
		var flight := LingpetAffinityState.new()
		flight.configure_reward_context("rabi", LingpetAffinityState.MOTION_STYLE_FLIGHT, 1, 1, int(seed), true, 30)
		_expect_reward_deck_bands(flight.get_reward_deck("rabi"), "flight seed %d" % int(seed), LingpetAffinityState.REWARD_TYPE_GAUGE, LingpetAffinityState.REWARD_TYPE_MOBILITY)


func _verify_skill_level_up_cards_require_unlocks() -> void:
	var first_slot := LingpetAffinityState.new()
	var first_slot_award := _award_custom_first_card(first_slot, {
		"type": LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL,
		"label": "액티브 스킬 +1",
		"skill_slot": 1,
	})
	_expect_str(str(first_slot_award.get("replaced_type", "")), LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, "first active level-up should dead-draw before active unlock")
	_expect(str(first_slot_award.get("type", "")) != LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, "first active level-up should be replaced before active unlock")
	var first_rewards := first_slot.get_cumulative_rewards("maribo")
	_expect(not bool(first_rewards.get("active_unlocked", false)), "forced first-slot skill card should not unlock the skill by itself")
	_expect_eq(int(first_rewards.get("active_skill_bonus", 0)), 0, "first active level-up should not apply before active unlock")

	var second_slot := LingpetAffinityState.new()
	var second_slot_award := _award_custom_first_card(second_slot, {
		"type": LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL,
		"label": "2번째 액티브 스킬 +1",
		"skill_slot": 2,
	})
	_expect_str(str(second_slot_award.get("replaced_type", "")), LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, "second active level-up should dead-draw before second active unlock")
	_expect(str(second_slot_award.get("type", "")) != LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, "second active level-up should be replaced before second active unlock")
	var second_rewards := second_slot.get_cumulative_rewards("maribo")
	_expect(not bool(second_rewards.get("second_active_unlocked", false)), "forced second-slot skill card should not unlock the second active slot by itself")
	_expect_eq(int(second_rewards.get("second_active_skill_bonus", 0)), 0, "second active level-up should not apply before second active unlock")


func _verify_dead_draw_does_not_block_unlocks() -> void:
	var state := LingpetAffinityState.new()
	state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 5, 5, 777, true, 30)
	_grant_round_commits(state, "maribo", 50)
	_expect_eq(state.get_level("maribo"), 5, "dead-draw fixture should reach the first five-card band")
	var rewards := state.get_cumulative_rewards("maribo")
	_expect(bool(rewards.get("active_unlocked", false)), "active unlock should apply even when base active level is already capped")
	_expect(bool(rewards.get("passive_unlocked", false)), "passive unlock should apply even when base passive level is already capped")
	_expect_eq(int(rewards.get("active_skill_bonus", 0)), 0, "capped first active level-up should not overcap")
	_expect_eq(int(rewards.get("passive_skill_bonus", 0)), 0, "capped first passive level-up should not overcap")
	var history: Array = state.get_pet_data("maribo").get("reward_history", []) as Array
	_expect(_history_has_reward_type(history, LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK), "history should preserve the active unlock card")
	_expect(_history_has_replacement_for(history, LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL), "capped active level-up should dead-draw into a replacement")


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

	var max_pet_denominator := LingpetAffinityState.new()
	_grant_round_commits(max_pet_denominator, "maribo", 900)
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


func _verify_flight_opportunity_multiplier() -> void:
	# Same pet id, two states differing ONLY by configured motion style, so the doubling is
	# proven motion-style-driven (not pet-driven). Patrol = base GAIN_TABLE values.
	var patrol := LingpetAffinityState.new()
	patrol.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 555, true, 30)
	_expect_float(float(patrol.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT).get("granted_points", 0.0)), 8.0, "patrol ball-hit stays at the base 8 (no flight multiplier)")
	_expect_float(float(patrol.add_points("maribo", LingpetAffinityState.SOURCE_CLICK).get("granted_points", 0.0)), 5.0, "patrol click stays at the base 5")
	_expect_float(float(patrol.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT).get("granted_points", 0.0)), 5.0, "patrol round commit stays at the base 5")

	# Flight: the opportunity sources (ball hit, click) double; the style-agnostic floor
	# (round commit) stays flat.
	var flight := LingpetAffinityState.new()
	flight.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_FLIGHT, 1, 1, 555, true, 30)
	_expect_float(float(flight.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT).get("granted_points", 0.0)), 16.0, "flight ball-hit should double to 16")
	_expect_float(float(flight.add_points("maribo", LingpetAffinityState.SOURCE_CLICK).get("granted_points", 0.0)), 10.0, "flight click should double to 10")
	_expect_float(float(flight.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT).get("granted_points", 0.0)), 5.0, "flight round commit should stay flat (style-agnostic floor)")

	# Caps stay by COUNT, not value: after four full hits the flight pet drops to the reduced
	# tier, and that reduced value is doubled too (2 -> 4) -- the cap COUNT is unchanged.
	for _i in range(3):
		flight.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT)
	_expect_float(float(flight.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT).get("granted_points", 0.0)), 4.0, "flight 5th ball-hit should be the doubled reduced value (2*2)")

	# Flight click cap is still two per round (count-based), even at double value.
	_expect_float(float(flight.add_points("maribo", LingpetAffinityState.SOURCE_CLICK).get("granted_points", 0.0)), 10.0, "flight second click should still pay double")
	var third_click: Dictionary = flight.add_points("maribo", LingpetAffinityState.SOURCE_CLICK)
	_expect_float(float(third_click.get("granted_points", 0.0)), 0.0, "flight third click should hit the unchanged count-based round cap")
	_expect_str(str(third_click.get("blocked_reason", "")), "round_cap", "flight click cap should stay by count, not doubled")

	# The defense/guard bonus is NOT doubled. A flight pet that blocks with Linkport/ring-dash
	# (ring_dash_block fires on flight pets) doubles ONLY the base 8 and keeps the flat +5 guard
	# bonus -> 8*2 + 5 = 21. Pins the policy against both the over-pay ((8+5)*2 = 26) and the
	# under-pay (multiplier fully disabled when tagged -> 8+5 = 13) regressions.
	var flight_guard := LingpetAffinityState.new()
	flight_guard.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_FLIGHT, 1, 1, 555, true, 30)
	var flight_guard_hit: Dictionary = flight_guard.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT, {"ring_dash_block": true})
	_expect_float(float(flight_guard_hit.get("granted_points", 0.0)), 21.0, "flight ring-dash guard hit should double only the base (8*2) and keep the flat +5 guard bonus")

	# Patrol guard hit baseline: base 8 + guard bonus 5 = 13, unchanged (patrol gets no multiplier).
	var patrol_guard := LingpetAffinityState.new()
	patrol_guard.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 555, true, 30)
	var patrol_guard_hit: Dictionary = patrol_guard.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT, {"defense_intercept": true})
	_expect_float(float(patrol_guard_hit.get("granted_points", 0.0)), 13.0, "patrol guard hit stays at base 8 + guard bonus 5 = 13")


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
	_expect_eq(int(data.get("affinity_level", 0)), 4, "headstart should still clamp to the +4 maximum")
	_expect_float(float(data.get("affinity_points", 0.0)), 25.0, "headstart should not wipe existing run points")
	_expect_eq(int(data.get("best_level", 0)), 30, "headstart should clamp stored best to V3 max level")
	_expect_eq((data.get("reward_history", []) as Array).size(), 4, "headstart should deal the first four reward-history cards")
	_expect_str(str((data.get("reward_counts", {}) as Dictionary).get("signature", "")), headstart_with_points.get_reward_signature("maribo"), "headstart rewards should keep counts and signature coherent")
	headstart_with_points.clear_dirty()
	headstart_with_points.seed_best_level("maribo", 2)
	_expect_eq(headstart_with_points.get_best_level("maribo"), 30, "seed_best_level should not lower existing best")
	_expect(not headstart_with_points.is_dirty(), "seed_best_level load path should not dirty by default")

	var state := LingpetAffinityState.new()
	var headstart_data: Dictionary = state.apply_headstart_from_best("maribo", 11)
	_expect_eq(int(headstart_data.get("affinity_level", 0)), 3, "headstart should remain floor(best/3) for now")
	_expect_eq(int(headstart_data.get("best_level", 0)), 11, "headstart should preserve previous best for anti-inflation")
	_expect(state.get_pending_bond_level_ups().is_empty(), "headstart reward history should not enter the pending bond ledger")
	_grant_round_commits(state, "maribo", 10)
	_expect_eq(state.get_best_level("maribo"), 11, "run below previous best should not rewrite best level")
	_grant_round_commits(state, "maribo", 80)
	_expect_eq(state.get_best_level("maribo"), 12, "only exceeding previous best should raise best level")

	var no_core := LingpetAffinityState.new()
	no_core.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 0)
	var no_core_data: Dictionary = no_core.apply_headstart_from_best("maribo", 30)
	_expect_eq(int(no_core_data.get("affinity_level", 0)), 0, "ring-core cap Lv0 should block headstart level grants")
	_expect_eq((no_core_data.get("reward_history", []) as Array).size(), 0, "ring-core cap Lv0 should not award headstart reward cards")
	_expect_eq(int(no_core_data.get("best_level", 0)), 30, "ring-core cap should not erase the stored best-level handoff")

	var cap_two := LingpetAffinityState.new()
	cap_two.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 2)
	var cap_two_data: Dictionary = cap_two.apply_headstart_from_best("maribo", 30)
	_expect_eq(int(cap_two_data.get("affinity_level", 0)), 2, "headstart should clamp to a low ring-core cap below HEADSTART_MAX_LEVEL")
	_expect_eq((cap_two_data.get("reward_history", []) as Array).size(), 2, "low ring-core cap should award only capped headstart cards")


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


func _verify_enhancement_chip_multiplier_lifecycle() -> void:
	var base_state := LingpetAffinityState.new()
	var base_gain: Dictionary = base_state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect_eq(base_state.get_enhancement_chips(), 0, "new run should start with zero enhancement chips")
	_expect_float(base_state.get_enhancement_chip_multiplier(), 1.0, "zero chips should keep the affinity multiplier at 1.0")
	_expect_float(float(base_gain.get("granted_points", 0.0)), 5.0, "zero chips should keep round commit gain at 5")

	var boosted_state := LingpetAffinityState.new()
	for _i in range(5):
		boosted_state.add_enhancement_chip()
	_expect_eq(boosted_state.get_enhancement_chips(), 5, "enhancement chips should stack up to five")
	_expect_eq(boosted_state.add_enhancement_chip(), 5, "enhancement chips should clamp above five")
	_expect_float(boosted_state.get_enhancement_chip_multiplier(), 2.0, "five chips should double affinity income")
	var boosted_gain: Dictionary = boosted_state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect_float(float(boosted_gain.get("granted_points", 0.0)), 10.0, "five chips should double round commit gain")
	_expect(not boosted_state.get_pet_data("maribo").has("enhancement_chips"), "enhancement chips should stay run-scoped, not per-pet data")

	var reset_state := LingpetAffinityState.new()
	reset_state.set_enhancement_chips(3)
	reset_state.reset_for_new_battle()
	_expect_eq(reset_state.get_enhancement_chips(), 3, "new battle should preserve run-scoped enhancement chips")
	reset_state.reset_for_new_run()
	_expect_eq(reset_state.get_enhancement_chips(), 0, "new run should clear enhancement chips")

	var max_state := LingpetAffinityState.new()
	max_state.set_enhancement_chips(5)
	max_state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	_grant_round_commits(max_state, "maribo", 900)
	var blocked_max: Dictionary = max_state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect_float(float(blocked_max.get("granted_points", 0.0)), 0.0, "max-level grants should stay blocked even with enhancement chips")


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


func _verify_scalar_getters_do_not_create_entries() -> void:
	var state := LingpetAffinityState.new()
	_expect_eq(state.get_level("typo"), 0, "unknown pet level should read as zero")
	_expect_float(state.get_points("typo"), 0.0, "unknown pet points should read as zero")
	_expect_eq(state.get_best_level("typo"), 0, "unknown pet best should read as zero")
	_expect_float(state.get_next_requirement("typo"), 50.0, "unknown pet next requirement should read as first requirement")
	var rewards := state.get_cumulative_rewards("typo")
	_expect_eq(int(rewards.get("active_skill_bonus", 0)), 0, "unknown pet rewards should be empty")
	_expect(not bool(rewards.get("active_unlocked", false)), "unknown pet unlock flags should be empty")
	_expect(state.get_pet_data("typo").is_empty(), "unknown pet snapshot should be empty")
	_expect(state.get_tracked_pet_ids().is_empty(), "scalar getters and snapshots should not create phantom pet entries")
	_expect(state.get_reward_deck("typo").is_empty(), "unknown pet deck snapshot should not create a phantom pet entry")
	_expect(state.get_pending_unlock_choices("typo").is_empty(), "unknown pet pending choices should not create a phantom pet entry")
	_expect(state.get_tracked_pet_ids().is_empty(), "deck snapshots should not create phantom pet entries")


func _verify_bond_pending_ledger_and_settlement() -> void:
	var eligible := LingpetAffinityState.new()
	_grant_round_commits(eligible, "maribo", 10)
	var pending := eligible.get_pending_bond_level_ups()
	_expect_eq(int(pending.get("maribo", 0)), 1, "level-ups should enter the battle pending bond ledger")
	var settled: Dictionary = eligible.settle_bond_level_ups_for_victory()
	_expect_eq(int((settled.get("settled", {}) as Dictionary).get("maribo", 0)), 1, "eligible pet should settle its pending bond levels on victory")
	_expect(eligible.get_pending_bond_level_ups().is_empty(), "victory settlement should clear the pending bond ledger")

	var ineligible := LingpetAffinityState.new()
	_grant_round_commits(ineligible, "maribo", 10)
	_grant_round_commits(ineligible, "lunabi", 11)
	var gated: Dictionary = ineligible.settle_bond_level_ups_for_victory()
	_expect_eq(int((gated.get("discarded", {}) as Dictionary).get("maribo", 0)), 1, "below-50-percent pet should discard its pending bond levels")
	_expect_eq(int((gated.get("settled", {}) as Dictionary).get("lunabi", 0)), 1, "eligible swapped pet should settle its own pending bond levels")

	var defeated := LingpetAffinityState.new()
	_grant_round_commits(defeated, "maribo", 10)
	var discarded: Dictionary = defeated.discard_pending_bond_level_ups()
	_expect_eq(int((discarded.get("discarded", {}) as Dictionary).get("maribo", 0)), 1, "defeat discard should return the pending bond levels")
	_expect(defeated.get_pending_bond_level_ups().is_empty(), "defeat discard should clear the pending bond ledger")


func _grant_round_commits(state: Object, pet_id: String, count: int) -> void:
	for _i in range(count):
		state.add_points(pet_id, LingpetAffinityState.SOURCE_ROUND_COMMIT)


func _requirement_sum_to_max() -> float:
	var total := 0.0
	for level in range(LingpetAffinityState.MAX_LEVEL):
		total += LingpetAffinityState.get_requirement_for_level(level)
	return total


func _expect_requirement_slice(start_level: int, end_level: int, expected: float, label: String) -> void:
	for level in range(start_level, end_level):
		_expect_float(LingpetAffinityState.get_requirement_for_level(level), expected, "%s should keep Lv%d at %.0f points" % [label, level, expected])


func _award_custom_first_card(state: Object, card: Dictionary) -> Dictionary:
	state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	var pet_data: Dictionary = state.call("_get_or_create_pet_data", "maribo") as Dictionary
	var deck: Array[Dictionary] = []
	for _i in range(LingpetAffinityState.MAX_LEVEL):
		deck.append({
			"type": LingpetAffinityState.REWARD_TYPE_NO_REWARD,
			"label": "보상 없음",
		})
	deck[0] = card.duplicate(true) as Dictionary
	pet_data["reward_deck"] = deck
	return state.call("_award_reward_for_level", pet_data, 1) as Dictionary


func _expect_reward_deck_bands(deck: Array, label: String, early_support_type: String, final_support_type: String) -> void:
	_expect_eq(deck.size(), LingpetAffinityState.MAX_LEVEL, "%s deck should cover every V3 level" % label)
	if deck.size() < LingpetAffinityState.MAX_LEVEL:
		return
	_expect_str(str((deck[0] as Dictionary).get("type", "")), LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK, "%s Lv1 should stay fixed to first active unlock" % label)
	_expect_str(str((deck[1] as Dictionary).get("type", "")), LingpetAffinityState.REWARD_TYPE_PASSIVE_UNLOCK, "%s Lv2 should stay fixed to first passive unlock" % label)
	var second_active_level := _reward_type_first_level(deck, LingpetAffinityState.REWARD_TYPE_SECOND_ACTIVE_UNLOCK)
	var second_passive_level := _reward_type_first_level(deck, LingpetAffinityState.REWARD_TYPE_SECOND_PASSIVE_UNLOCK)
	_expect(second_active_level >= 16 and second_active_level <= 25, "%s second active unlock should land inside Lv16-25" % label)
	_expect(second_passive_level >= 16 and second_passive_level <= 25, "%s second passive unlock should land inside Lv16-25" % label)
	_expect_slot2_cards_after_unlock(deck, LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, second_active_level, "%s second active" % label)
	_expect_slot2_cards_after_unlock(deck, LingpetAffinityState.REWARD_TYPE_PASSIVE_SKILL, second_passive_level, "%s second passive" % label)
	_expect_reward_band_multiset(deck, 0, 5, _expected_cards([
		[LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK, 0, 1],
		[LingpetAffinityState.REWARD_TYPE_PASSIVE_UNLOCK, 0, 1],
		[early_support_type, 0, 1],
		[LingpetAffinityState.REWARD_TYPE_MOBILITY, 0, 1],
		[LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, 1, 1],
	]), "%s Lv1-5" % label)
	_expect_reward_band_multiset(deck, 5, 10, _expected_cards([
		[LingpetAffinityState.REWARD_TYPE_GAUGE, 0, 1],
		[LingpetAffinityState.REWARD_TYPE_PASSIVE_SKILL, 1, 1],
		[early_support_type, 0, 1],
		[LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, 1, 1],
		[LingpetAffinityState.REWARD_TYPE_MOBILITY, 0, 1],
	]), "%s Lv6-10" % label)
	_expect_reward_band_multiset(deck, 10, 15, _expected_cards([
		[LingpetAffinityState.REWARD_TYPE_PASSIVE_SKILL, 1, 1],
		[LingpetAffinityState.REWARD_TYPE_GAUGE, 0, 1],
		[early_support_type, 0, 1],
		[LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, 1, 1],
		[LingpetAffinityState.REWARD_TYPE_MOBILITY, 0, 1],
	]), "%s Lv11-15" % label)
	_expect_reward_band_multiset(deck, 15, 25, _expected_cards([
		[LingpetAffinityState.REWARD_TYPE_PASSIVE_SKILL, 1, 1],
		[LingpetAffinityState.REWARD_TYPE_GAUGE, 0, 1],
		[early_support_type, 0, 1],
		[LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, 1, 1],
		[LingpetAffinityState.REWARD_TYPE_MOBILITY, 0, 1],
		[LingpetAffinityState.REWARD_TYPE_PASSIVE_SKILL, 1, 1],
		[LingpetAffinityState.REWARD_TYPE_GAUGE, 0, 1],
		[LingpetAffinityState.REWARD_TYPE_MOBILITY, 0, 1],
		[LingpetAffinityState.REWARD_TYPE_SECOND_ACTIVE_UNLOCK, 0, 1],
		[LingpetAffinityState.REWARD_TYPE_SECOND_PASSIVE_UNLOCK, 0, 1],
	]), "%s Lv16-25" % label)
	_expect_reward_band_multiset(deck, 25, 30, _expected_cards([
		[LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, 2, 2],
		[LingpetAffinityState.REWARD_TYPE_PASSIVE_SKILL, 2, 2],
		[final_support_type, 0, 1],
	]), "%s Lv26-30" % label)


func _expected_cards(entries: Array) -> Dictionary:
	var expected := {}
	for raw_entry in entries:
		var entry: Array = raw_entry as Array
		if entry.size() >= 3:
			var key := _card_key(str(entry[0]), int(entry[1]))
			expected[key] = int(expected.get(key, 0)) + int(entry[2])
	return expected


func _expect_reward_band_multiset(deck: Array, start_index: int, end_index: int, expected: Dictionary, label: String) -> void:
	var actual := {}
	for index in range(start_index, mini(end_index, deck.size())):
		var key := _reward_card_key(deck[index])
		if key == "":
			continue
		actual[key] = int(actual.get(key, 0)) + 1
	for raw_expected_key in expected.keys():
		var expected_key := str(raw_expected_key)
		_expect_eq(int(actual.get(expected_key, 0)), int(expected.get(raw_expected_key, 0)), "%s should keep %s count" % [label, expected_key])
	for raw_actual_key in actual.keys():
		var actual_key := str(raw_actual_key)
		_expect(expected.has(actual_key), "%s should not contain unexpected card %s" % [label, actual_key])


func _reward_type_sequence(deck: Array) -> String:
	var parts: Array[String] = []
	for raw_card in deck:
		if raw_card is Dictionary:
			var card: Dictionary = raw_card as Dictionary
			parts.append("%s:%d" % [str(card.get("type", "")), int(card.get("skill_slot", 0))])
	return ",".join(parts)


func _card_key(reward_type: String, skill_slot: int = 0) -> String:
	return "%s:%d" % [reward_type, skill_slot]


func _reward_card_key(raw_card: Variant) -> String:
	if raw_card is Dictionary:
		var card: Dictionary = raw_card as Dictionary
		return _card_key(str(card.get("type", "")), int(card.get("skill_slot", 0)))
	return ""


func _reward_type_count(deck: Array, reward_type: String, start_index: int = 0, end_index: int = -1) -> int:
	var count := 0
	var clamped_end := deck.size() if end_index < 0 else mini(end_index, deck.size())
	for index in range(maxi(0, start_index), clamped_end):
		var raw_card: Variant = deck[index]
		if raw_card is Dictionary and str((raw_card as Dictionary).get("type", "")) == reward_type:
			count += 1
	return count


func _reward_type_first_level(deck: Array, reward_type: String) -> int:
	for index in range(deck.size()):
		var raw_card: Variant = deck[index]
		if raw_card is Dictionary and str((raw_card as Dictionary).get("type", "")) == reward_type:
			return index + 1
	return 0


func _expect_slot2_cards_after_unlock(deck: Array, reward_type: String, unlock_level: int, label: String) -> void:
	for index in range(deck.size()):
		var raw_card: Variant = deck[index]
		if not (raw_card is Dictionary):
			continue
		var card: Dictionary = raw_card as Dictionary
		if str(card.get("type", "")) == reward_type and int(card.get("skill_slot", 0)) == 2:
			_expect(index + 1 > unlock_level, "%s slot-2 level-up card should appear after its unlock" % label)


func _reward_band_size(deck: Array, start_index: int, end_index: int) -> int:
	var count := 0
	for index in range(start_index, mini(end_index, deck.size())):
		if deck[index] is Dictionary:
			count += 1
	return count


func _history_has_reward_type(history: Array, reward_type: String) -> bool:
	for raw_card in history:
		if raw_card is Dictionary and str((raw_card as Dictionary).get("type", "")) == reward_type:
			return true
	return false


func _history_has_replacement_for(history: Array, reward_type: String) -> bool:
	for raw_card in history:
		if raw_card is Dictionary and str((raw_card as Dictionary).get("replaced_type", "")) == reward_type:
			return true
	return false


func _verify_run_ring_core_tier_api() -> void:
	var state := LingpetAffinityState.new()
	_expect_eq(state.get_run_ring_core_tier(), 0, "fresh state run ring core tier should default to 0")
	_expect_eq(state.get_run_ring_core_cap(), 0, "fresh state run ring core cap should be 0 (T0 = cap 0)")

	state.set_run_ring_core_tier(3)
	_expect_eq(state.get_run_ring_core_tier(), 3, "set_run_ring_core_tier(3) should set tier 3")
	_expect_eq(state.get_run_ring_core_cap(), LingpetAffinityStore.get_ring_core_cap_for_tier(3), "run ring core cap should reuse the store tier->cap map")

	state.set_run_ring_core_tier(-99)
	_expect_eq(state.get_run_ring_core_tier(), 0, "set_run_ring_core_tier(-99) should clamp to 0")
	state.set_run_ring_core_tier(999)
	_expect_eq(state.get_run_ring_core_tier(), LingpetAffinityStore.MAX_RING_CORE_TIER, "set_run_ring_core_tier(999) should clamp to max tier")

	var climber := LingpetAffinityState.new()
	_expect(climber.upgrade_run_ring_core_tier(), "upgrade from tier 0 should succeed")
	_expect_eq(climber.get_run_ring_core_tier(), 1, "first upgrade should reach tier 1")
	_expect(climber.upgrade_run_ring_core_tier(), "upgrade from tier 1 should succeed")
	_expect_eq(climber.get_run_ring_core_tier(), 2, "second upgrade should reach tier 2")
	while climber.get_run_ring_core_tier() < LingpetAffinityStore.MAX_RING_CORE_TIER:
		_expect(climber.upgrade_run_ring_core_tier(), "upgrade below max tier should succeed")
	_expect_eq(climber.get_run_ring_core_tier(), LingpetAffinityStore.MAX_RING_CORE_TIER, "sequential upgrades should reach max tier")
	_expect(not climber.upgrade_run_ring_core_tier(), "upgrade at max tier should return false")
	_expect_eq(climber.get_run_ring_core_tier(), LingpetAffinityStore.MAX_RING_CORE_TIER, "tier should not exceed max after a blocked upgrade")

	var target_state := LingpetAffinityState.new()
	target_state.set_run_ring_core_tier(3)
	_expect(not target_state.upgrade_run_ring_core_tier(2), "upgrade to a lower target tier should fail (no downgrade)")
	_expect_eq(target_state.get_run_ring_core_tier(), 3, "a rejected lower-target upgrade should keep the tier at 3")
	_expect(not target_state.upgrade_run_ring_core_tier(3), "upgrade to the same target tier should fail (not higher)")
	_expect_eq(target_state.get_run_ring_core_tier(), 3, "a rejected same-target upgrade should keep the tier at 3")
	_expect(target_state.upgrade_run_ring_core_tier(4), "upgrade to a higher target tier should succeed")
	_expect_eq(target_state.get_run_ring_core_tier(), 4, "a higher-target upgrade should reach tier 4")

	var reset_state := LingpetAffinityState.new()
	reset_state.set_run_ring_core_tier(5)
	reset_state.reset_all()
	_expect_eq(reset_state.get_run_ring_core_tier(), 0, "reset_all should reset run ring core tier to 0")
	_expect_eq(reset_state.get_run_ring_core_cap(), 0, "reset_all should reset run ring core cap to 0")

	_expect_eq(LingpetAffinityState.new().get_run_ring_core_tier(), 0, "a new state instance should always start at run ring core tier 0")


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
