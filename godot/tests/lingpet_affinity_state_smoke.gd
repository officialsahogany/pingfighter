extends SceneTree

const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetRingCoreRules := preload("res://scripts/lingpet/lingpet_ring_core_rules.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_requirement_curve_and_30_level_track()
	_verify_ring_core_cap_clamps_overflow()
	_verify_unlock_cards_and_choice_state()
	_verify_reward_deck_determinism_and_bands()
	_verify_skill_level_up_cards_require_unlocks()
	_verify_dead_draw_does_not_block_unlocks()
	_verify_round_commit_gain_and_victory_gate()
	_verify_ball_hit_stall_cap()
	_verify_same_round_caps_are_battle_global()
	_verify_defense_bonus_is_tagged_and_capped()
	_verify_click_caps_are_battle_global()
	_verify_flight_opportunity_multiplier()
	_verify_stage_clear_award()
	_verify_hatch_bonus_is_per_pet_once()
	_verify_store_headstart_residue_is_removed()
	_verify_reset_lifecycle()
	_verify_enhancement_chip_multiplier_lifecycle()
	_verify_dirty_flag()
	_verify_scalar_getters_do_not_create_entries()
	_verify_bond_pending_ledger_and_settlement()
	_verify_run_ring_core_tier_api()
	_verify_ring_core_offer_cooldown_lifecycle()
	_verify_smart_fallback_fills_levels()
	_verify_next_reward_display_label()
	_verify_second_unlock_requires_pet_pool_depth()
	_verify_second_unlock_probability_gate()

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
	var rewards := state.get_cumulative_rewards("maribo")
	_expect(bool(rewards.get("active_unlocked", false)), "Lv30 should have first active unlocked")
	_expect(bool(rewards.get("passive_unlocked", false)), "Lv30 should have first passive unlocked")
	_expect_eq(int(rewards.get("active_skill_bonus", 0)), 4, "Lv30 should carry four first-active level-up cards")
	_expect_eq(int(rewards.get("passive_skill_bonus", 0)), 4, "Lv30 should carry four first-passive level-up cards")
	_expect(bool(rewards.get("title_unlocked", false)), "Lv30 should unlock heart resonance")
	# Second-slot unlocks are now probability-gated (see
	# _verify_second_unlock_probability_gate), so they are NOT asserted here. By Lv30
	# the prerequisite (combined skill level >= 5) is long met and the 30%/level roll
	# fires for this seed, so the deterministic outcome is both slots unlocked.
	_expect(bool(rewards.get("second_active_unlocked", false)), "Lv30 maribo (seed 777) should have rolled the second active unlock by max level")
	_expect(bool(rewards.get("second_passive_unlocked", false)), "Lv30 maribo (seed 777) should have rolled the second passive unlock by max level")
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
	_expect_eq(_reward_type_count(first_deck, LingpetAffinityState.REWARD_TYPE_ACTIVE_UNLOCK), 1, "deck should contain exactly one first active unlock")
	_expect_eq(_reward_type_count(first_deck, LingpetAffinityState.REWARD_TYPE_PASSIVE_UNLOCK), 1, "deck should contain exactly one first passive unlock")
	# Second-slot unlocks are no longer fixed deck cards -- they are granted by a
	# per-level probability roll gated on combined skill level (see
	# _verify_second_unlock_probability_gate). The deck must carry NONE of them.
	_expect_eq(_reward_type_count(first_deck, LingpetAffinityState.REWARD_TYPE_SECOND_ACTIVE_UNLOCK), 0, "deck should no longer contain a fixed second active unlock card")
	_expect_eq(_reward_type_count(first_deck, LingpetAffinityState.REWARD_TYPE_SECOND_PASSIVE_UNLOCK), 0, "deck should no longer contain a fixed second passive unlock card")
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
	_expect_float(maribo_total, 40.0, "round click cap should allow only two clicks (2x20)")
	state.reset_round_caps()
	var lunabi_total := 0.0
	for _i in range(2):
		var result: Dictionary = state.add_points("lunabi", LingpetAffinityState.SOURCE_CLICK)
		lunabi_total += float(result.get("granted_points", 0.0))
	_expect_float(lunabi_total, 40.0, "second pet should share the same battle cap but get fresh round cap (2x20)")
	state.reset_round_caps()
	for _i in range(3):
		var result: Dictionary = state.add_points("lunabi", LingpetAffinityState.SOURCE_CLICK)
		lunabi_total += float(result.get("granted_points", 0.0))
	_expect_float(lunabi_total, 60.0, "battle-global click cap should stop at five total clicks across pets (5x20 split)")
	_expect_float(state.get_points("maribo"), 40.0, "first pet click points should be unchanged (40 banked, below the 50 level requirement)")
	_expect_float(state.get_points("lunabi"), 10.0, "second pet earned 60 total but crossed the 50 requirement once, so 10 points remain banked")


func _verify_flight_opportunity_multiplier() -> void:
	# Same pet id, two states differing ONLY by configured motion style, so the doubling is
	# proven motion-style-driven (not pet-driven). Patrol = base GAIN_TABLE values.
	var patrol := LingpetAffinityState.new()
	patrol.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 555, true, 30)
	_expect_float(float(patrol.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT).get("granted_points", 0.0)), 8.0, "patrol ball-hit stays at the base 8 (no flight multiplier)")
	_expect_float(float(patrol.add_points("maribo", LingpetAffinityState.SOURCE_CLICK).get("granted_points", 0.0)), 20.0, "patrol click stays at the base 20")
	_expect_float(float(patrol.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT).get("granted_points", 0.0)), 5.0, "patrol round commit stays at the base 5")

	# Flight: the opportunity sources (ball hit, click) double; the style-agnostic floor
	# (round commit) stays flat.
	var flight := LingpetAffinityState.new()
	flight.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_FLIGHT, 1, 1, 555, true, 30)
	_expect_float(float(flight.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT).get("granted_points", 0.0)), 16.0, "flight ball-hit should double to 16")
	_expect_float(float(flight.add_points("maribo", LingpetAffinityState.SOURCE_CLICK).get("granted_points", 0.0)), 30.0, "flight click should pay the explicit flight value 30 (not the ball-hit 2x)")
	_expect_float(float(flight.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT).get("granted_points", 0.0)), 5.0, "flight round commit should stay flat (style-agnostic floor)")

	# Caps stay by COUNT, not value: after four full hits the flight pet drops to the reduced
	# tier, and that reduced value is doubled too (2 -> 4) -- the cap COUNT is unchanged.
	for _i in range(3):
		flight.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT)
	_expect_float(float(flight.add_points("maribo", LingpetAffinityState.SOURCE_BALL_HIT).get("granted_points", 0.0)), 4.0, "flight 5th ball-hit should be the doubled reduced value (2*2)")

	# Flight click cap is still two per round (count-based), even at double value.
	_expect_float(float(flight.add_points("maribo", LingpetAffinityState.SOURCE_CLICK).get("granted_points", 0.0)), 30.0, "flight second click should still pay the flight value 30")
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


func _verify_stage_clear_award() -> void:
	# Stage clear pays a fixed +50 floor (style-agnostic, no flight multiplier), gated by the
	# same 50%+ participation as victory and self-sealing once per battle.
	var state := LingpetAffinityState.new()
	state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	var clear: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_STAGE_CLEAR)
	_expect_float(float(clear.get("granted_points", 0.0)), 50.0, "eligible stage clear should grant the +50 floor")
	var duplicate: Dictionary = state.add_points("maribo", LingpetAffinityState.SOURCE_STAGE_CLEAR)
	_expect_float(float(duplicate.get("granted_points", 0.0)), 0.0, "stage clear should self-seal after one payout per battle")
	_expect_str(str(duplicate.get("blocked_reason", "")), "stage_clear_already_paid", "duplicate stage clear should report the battle seal")

	# Flight pets get the SAME 50 floor (no opportunity multiplier on stage clear).
	var flight := LingpetAffinityState.new()
	flight.configure_reward_context("lunabi", LingpetAffinityState.MOTION_STYLE_FLIGHT, 1, 1, 555, true, 30)
	flight.add_points("lunabi", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect_float(float(flight.add_points("lunabi", LingpetAffinityState.SOURCE_STAGE_CLEAR).get("granted_points", 0.0)), 50.0, "flight stage clear stays at the style-agnostic +50 floor")

	# Below-50%-participation pet must NOT receive the stage clear bonus (mirrors victory gate).
	var gated := LingpetAffinityState.new()
	gated.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	gated.add_points("lunabi", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	gated.add_points("lunabi", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	var blocked: Dictionary = gated.add_points("maribo", LingpetAffinityState.SOURCE_STAGE_CLEAR)
	_expect_float(float(blocked.get("granted_points", 0.0)), 0.0, "a below-half-participation pet should not receive the stage clear bonus")
	_expect_str(str(blocked.get("blocked_reason", "")), "ineligible", "below-half stage clear should report ineligible")

	# New battle reload allows a fresh stage clear payout.
	state.reset_for_new_battle()
	state.add_points("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	_expect_float(float(state.add_points("maribo", LingpetAffinityState.SOURCE_STAGE_CLEAR).get("granted_points", 0.0)), 50.0, "new battle should reload the stage clear payout")


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


func _verify_store_headstart_residue_is_removed() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_affinity_state.gd")
	for residue in ["HEADSTART_MAX_LEVEL", "func seed_best_level", "func apply_headstart_from_best", "func get_best_level", "func get_best_levels", "func _update_best_level"]:
		_expect(source.find(residue) < 0, "per-run affinity state should not keep legacy store-headstart residue (%s)" % residue)
	_expect(source.find("LEGACY_PET_RUN_STATE_KEYS") >= 0 and source.find("_sanitize_pet_run_state") >= 0, "run-state export/import should centralize legacy pet-data stripping")
	var state := LingpetAffinityState.new()
	state.add_points("maribo", LingpetAffinityState.SOURCE_HATCH)
	var exported: Dictionary = state.export_run_state()
	var pets: Dictionary = exported.get("pets", {}) as Dictionary
	var maribo: Dictionary = pets.get("maribo", {}) as Dictionary
	_expect(not maribo.has("best_level"), "exported run-state pet data should not carry legacy best_level residue")

	var restored := LingpetAffinityState.new()
	restored.import_run_state({"pets": {"maribo": {"affinity_level": 2, "best_level": 30, "bond_points": 99, "bond_title": "legacy"}}})
	var restored_export: Dictionary = restored.export_run_state()
	var restored_pets: Dictionary = restored_export.get("pets", {}) as Dictionary
	var restored_maribo: Dictionary = restored_pets.get("maribo", {}) as Dictionary
	_expect_eq(restored.get_level("maribo"), 2, "run-state import should preserve real affinity level")
	_expect(not restored_maribo.has("best_level"), "run-state import should strip legacy best_level residue")
	_expect(not restored_maribo.has("bond_points"), "run-state import should strip legacy bond_points residue")
	_expect(not restored_maribo.has("bond_title"), "run-state import should strip legacy bond_title residue")


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
	_expect_float(float(reloaded_click.get("granted_points", 0.0)), 20.0, "new battle should reload click budget (20)")

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


# Regression: second-slot unlock rolls can only become real for pets whose catalog
# active/passive pool has slot depth. Granting the flag anyway produced a phantom
# unlock with an empty second-active card (lunabi / orbi / orosha are single-active
# WIP pets today). The unlock must be gated on real pool depth and recovered into
# another reward, and it must auto-enable once a second active skill is authored
# (pool size >= 2).
func _verify_second_unlock_requires_pet_pool_depth() -> void:
	var two_skill := LingpetAffinityState.new()
	two_skill.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	_grant_round_commits(two_skill, "maribo", 835)
	var two_rewards := two_skill.get_cumulative_rewards("maribo")
	_expect(bool(two_rewards.get("second_active_unlocked", false)), "two-active pet (maribo) should still unlock the second active slot")

	var one_skill := LingpetAffinityState.new()
	one_skill.configure_reward_context("orosha", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	_grant_round_commits(one_skill, "orosha", 835)
	var one_rewards := one_skill.get_cumulative_rewards("orosha")
	_expect(bool(one_rewards.get("active_unlocked", false)), "single-active pet (orosha) should still unlock its one active skill")
	_expect(not bool(one_rewards.get("second_active_unlocked", false)), "single-active pet (orosha) must not get a phantom second-active unlock")
	_expect_eq(int(one_rewards.get("second_active_skill_bonus", 0)), 0, "single-active pet should never accrue second-active level-up bonuses")


# Second-slot unlocks are gated behind combined first active + first passive
# EFFECTIVE skill level >= SECOND_UNLOCK_SKILL_LEVEL_SUM_REQUIREMENT and then
# granted by a per-level probability roll (so the appearance level is unpredictable
# and never the guaranteed next level). This verifies the prerequisite gate, the
# probabilistic-not-immediate behavior, determinism, and pet-pool gating.
func _verify_second_unlock_probability_gate() -> void:
	var state := LingpetAffinityState.new()
	state.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	var pet_data: Dictionary = state.call("_get_or_create_pet_data", "maribo") as Dictionary

	# Below the prerequisite (base 1/1 + no bonus = sum 2): NEVER roll an unlock.
	pet_data["reward_counts"] = _counts_with(0, 0)
	_expect(not bool(state.call("_second_unlock_prerequisite_met", pet_data)), "combined skill level 2 (<5) must not meet the prerequisite")
	for below_level in range(1, LingpetAffinityState.MAX_LEVEL + 1):
		var below_card: Dictionary = state.call("_maybe_roll_second_unlock_card", pet_data, below_level) as Dictionary
		_expect(below_card.is_empty(), "below the prerequisite no level may roll a second unlock [Lv%d]" % below_level)

	# Exactly at the prerequisite (active 1+2 = 3, passive 1+1 = 2, sum 5): eligible.
	pet_data["reward_counts"] = _counts_with(2, 1)
	_expect(bool(state.call("_second_unlock_prerequisite_met", pet_data)), "combined skill level exactly 5 must meet the prerequisite")
	var hits := 0
	var misses := 0
	var first_hit_level := 0
	for level in range(1, LingpetAffinityState.MAX_LEVEL + 1):
		var card: Dictionary = state.call("_maybe_roll_second_unlock_card", pet_data, level) as Dictionary
		if card.is_empty():
			misses += 1
		else:
			hits += 1
			if first_hit_level == 0:
				first_hit_level = level
	_expect(hits > 0, "with the prerequisite met the roll must grant a second unlock somewhere across 30 levels")
	_expect(misses > 0, "the roll must be probabilistic -- some eligible levels must miss, not a guaranteed Lv1 unlock")
	_expect(first_hit_level > 1, "the first unlock must NOT land on the very first eligible level (no immediate unlock)")

	# Determinism: a second identical state reproduces the same first-hit level.
	var twin := LingpetAffinityState.new()
	twin.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	var twin_data: Dictionary = twin.call("_get_or_create_pet_data", "maribo") as Dictionary
	twin_data["reward_counts"] = _counts_with(2, 1)
	var twin_first_hit := 0
	for level in range(1, LingpetAffinityState.MAX_LEVEL + 1):
		var twin_card: Dictionary = twin.call("_maybe_roll_second_unlock_card", twin_data, level) as Dictionary
		if not twin_card.is_empty() and twin_first_hit == 0:
			twin_first_hit = level
	_expect_eq(twin_first_hit, first_hit_level, "the same seed must deterministically reproduce the same first unlock level")

	# Pet-pool gating: a single-active pet never rolls a second-active unlock even
	# with the prerequisite met.
	var single := LingpetAffinityState.new()
	single.configure_reward_context("orosha", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	var single_data: Dictionary = single.call("_get_or_create_pet_data", "orosha") as Dictionary
	single_data["reward_counts"] = _counts_with(2, 1)
	var single_active_rolled := false
	for level in range(1, LingpetAffinityState.MAX_LEVEL + 1):
		var single_card: Dictionary = single.call("_maybe_roll_second_unlock_card", single_data, level) as Dictionary
		if str(single_card.get("type", "")) == LingpetAffinityState.REWARD_TYPE_SECOND_ACTIVE_UNLOCK:
			single_active_rolled = true
	_expect(not single_active_rolled, "a single-active pet (orosha) must never roll a second-active unlock")


func _counts_with(active_skill_bonus: int, passive_skill_bonus: int) -> Dictionary:
	var counts := LingpetAffinityState.get_empty_reward_counts()
	counts["active_unlocked"] = true
	counts["passive_unlocked"] = true
	counts["active_skill_bonus"] = active_skill_bonus
	counts["passive_skill_bonus"] = passive_skill_bonus
	return counts


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
	# Second-slot unlocks are roll-granted, not fixed deck cards; the deck must carry none.
	_expect_eq(_reward_type_count(deck, LingpetAffinityState.REWARD_TYPE_SECOND_ACTIVE_UNLOCK), 0, "%s deck should carry no fixed second active unlock card" % label)
	_expect_eq(_reward_type_count(deck, LingpetAffinityState.REWARD_TYPE_SECOND_PASSIVE_UNLOCK), 0, "%s deck should carry no fixed second passive unlock card" % label)
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
	# Lv16-25 is now a single 10-card shuffled band of ordinary skill/stat cards
	# (the two former pinned unlock slots became one extra active + one extra passive
	# skill card). Second-slot unlocks no longer live in the deck.
	_expect_reward_band_multiset(deck, 15, 25, _expected_cards([
		[LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, 1, 2],
		[LingpetAffinityState.REWARD_TYPE_PASSIVE_SKILL, 1, 3],
		[LingpetAffinityState.REWARD_TYPE_GAUGE, 0, 2],
		[early_support_type, 0, 1],
		[LingpetAffinityState.REWARD_TYPE_MOBILITY, 0, 2],
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


# Smart replacement: a dead-drawn card (maxed stat / locked-or-maxed skill /
# already-done unlock) recovers into the next AVAILABLE reward — stats first,
# then unused skill-bonus capacity — instead of dead-drawing into NO_REWARD.
# Pre-fix (stat-only fallback) the patrol deck dead-drew 2 levels into "보상 없음"
# and the flight deck (no defense reward) dead-drew 4, with ring core upgrades
# only exposing more empty levels.
func _verify_smart_fallback_fills_levels() -> void:
	var patrol := LingpetAffinityState.new()
	patrol.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	_grant_round_commits(patrol, "maribo", 835)
	_expect_eq(patrol.get_level("maribo"), 30, "smart-fallback patrol fixture should reach Lv30")
	_expect_eq(_history_dry_count(patrol, "maribo"), 0, "base-1/1 patrol should fill all 30 levels with a real reward (no 보상 없음)")

	var flight := LingpetAffinityState.new()
	flight.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_FLIGHT, 1, 1, 777, true, 30)
	_grant_round_commits(flight, "maribo", 835)
	_expect_eq(flight.get_level("maribo"), 30, "smart-fallback flight fixture should reach Lv30")
	_expect_eq(_history_dry_count(flight, "maribo"), 0, "base-1/1 flight (no defense reward) should also fill all 30 levels")

	# Focused: stats maxed but a slot-1 active-skill bonus still open -> a dead
	# DEFENSE card recovers into a SKILL bonus, not NO_REWARD.
	var focused := LingpetAffinityState.new()
	focused.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	var pet_data: Dictionary = focused.call("_get_or_create_pet_data", "maribo") as Dictionary
	pet_data["reward_counts"] = {
		"active_unlocked": true, "passive_unlocked": true,
		"second_active_unlocked": false, "second_passive_unlocked": false,
		"active_skill_bonus": 0, "passive_skill_bonus": 0,
		"second_active_skill_bonus": 0, "second_passive_skill_bonus": 0,
		"mobility_stacks": LingpetAffinityState.MAX_MOBILITY_STACKS,
		"defense_stacks": LingpetAffinityState.MAX_DEFENSE_STACKS,
		"gauge_stacks": LingpetAffinityState.MAX_GAUGE_STACKS,
	}
	var recovered: Dictionary = focused.call("_resolve_effective_reward_card", pet_data, {"type": LingpetAffinityState.REWARD_TYPE_DEFENSE, "label": "방어 강화"}) as Dictionary
	_expect_str(str(recovered.get("type", "")), LingpetAffinityState.REWARD_TYPE_ACTIVE_SKILL, "stats-maxed dead card should recover into a skill bonus, not 보상 없음")
	_expect_str(str(recovered.get("replaced_type", "")), LingpetAffinityState.REWARD_TYPE_DEFENSE, "recovered card should record the replaced type")

	# Genuinely exhausted (everything maxed) still resolves to NO_REWARD — the
	# fallback only recovers into REAL remaining capacity.
	var maxed_data: Dictionary = focused.call("_get_or_create_pet_data", "maribo") as Dictionary
	maxed_data["reward_counts"] = {
		"active_unlocked": true, "passive_unlocked": true,
		"second_active_unlocked": true, "second_passive_unlocked": true,
		"active_skill_bonus": 4, "passive_skill_bonus": 4,
		"second_active_skill_bonus": 4, "second_passive_skill_bonus": 4,
		"mobility_stacks": LingpetAffinityState.MAX_MOBILITY_STACKS,
		"defense_stacks": LingpetAffinityState.MAX_DEFENSE_STACKS,
		"gauge_stacks": LingpetAffinityState.MAX_GAUGE_STACKS,
	}
	var dead: Dictionary = focused.call("_resolve_effective_reward_card", maxed_data, {"type": LingpetAffinityState.REWARD_TYPE_GAUGE, "label": "게이지 강화"}) as Dictionary
	_expect_str(str(dead.get("type", "")), LingpetAffinityState.REWARD_TYPE_NO_REWARD, "a fully-maxed pet should still resolve to NO_REWARD")


# Player-facing "다음 보상" label: cap-aware + graceful terminal so the panel
# never shows a dead-end "보상 없음" / previews an unreachable locked reward.
func _verify_next_reward_display_label() -> void:
	# At the ring core cap (more rewards exist above) -> prompt a ring core upgrade.
	var capped := LingpetAffinityState.new()
	capped.set_run_ring_core_tier(3)
	capped.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, capped.get_run_ring_core_cap())
	_grant_round_commits(capped, "maribo", 400)
	_expect_eq(capped.get_level("maribo"), 15, "T3 cap should hold the pet at Lv15")
	_expect_str(capped.get_next_reward_display_label("maribo"), "링코어 강화 시 해금", "at the ring core cap the next-reward line should prompt a ring core upgrade")

	# Lv30 -> terminal title.
	var maxed := LingpetAffinityState.new()
	maxed.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	_grant_round_commits(maxed, "maribo", 835)
	_expect_eq(maxed.get_level("maribo"), 30, "uncapped pet should reach Lv30")
	_expect_str(maxed.get_next_reward_display_label("maribo"), "하트 공명", "Lv30 next-reward line should show the terminal title")

	# Sub-max, uncapped, but fully enhanced -> 최대 강화 완료 (not 보상 없음).
	var exhausted := LingpetAffinityState.new()
	exhausted.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 1, 1, 777, true, 30)
	var ex_data: Dictionary = exhausted.call("_get_or_create_pet_data", "maribo") as Dictionary
	ex_data["affinity_level"] = 20
	ex_data["reward_counts"] = {
		"active_unlocked": true, "passive_unlocked": true,
		"second_active_unlocked": true, "second_passive_unlocked": true,
		"active_skill_bonus": 4, "passive_skill_bonus": 4,
		"second_active_skill_bonus": 4, "second_passive_skill_bonus": 4,
		"mobility_stacks": LingpetAffinityState.MAX_MOBILITY_STACKS,
		"defense_stacks": LingpetAffinityState.MAX_DEFENSE_STACKS,
		"gauge_stacks": LingpetAffinityState.MAX_GAUGE_STACKS,
	}
	_expect_str(exhausted.get_next_reward_display_label("maribo"), "최대 강화 완료", "a fully-enhanced sub-max pet should read 최대 강화 완료, not 보상 없음")

	# High starting skill level (base 5/5) makes the immediate next card dry
	# (slot-1 skill bonuses have 0 capacity from the start), but real rewards —
	# the second-skill unlocks at deck levels 17-26 — still wait ahead. The label
	# must scan forward to them, not terminate early at 최대 강화 완료. Pre-fix this
	# returned 최대 강화 완료 even though the pet is only Lv15/30.
	var highbase := LingpetAffinityState.new()
	highbase.set_run_ring_core_tier(LingpetRingCoreRules.MAX_RING_CORE_TIER)  # run cap 30: nothing is core-gated
	highbase.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 5, 5, 777, true, 30)
	var hb_data: Dictionary = highbase.call("_get_or_create_pet_data", "maribo") as Dictionary
	hb_data["affinity_level"] = 15
	hb_data["reward_counts"] = {
		"active_unlocked": true, "passive_unlocked": true,
		"second_active_unlocked": false, "second_passive_unlocked": false,
		"active_skill_bonus": 0, "passive_skill_bonus": 0,
		"second_active_skill_bonus": 0, "second_passive_skill_bonus": 0,
		"mobility_stacks": LingpetAffinityState.MAX_MOBILITY_STACKS,
		"defense_stacks": LingpetAffinityState.MAX_DEFENSE_STACKS,
		"gauge_stacks": LingpetAffinityState.MAX_GAUGE_STACKS,
	}
	var hb_label := highbase.get_next_reward_display_label("maribo")
	_expect(hb_label != "최대 강화 완료", "high-base (5/5) Lv15/30 still has the 2번째 해금 rewards ahead, must not read 최대 강화 완료")
	_expect(hb_label != "링코어 강화 시 해금", "uncapped (T6) high-base pet should preview the real reward, not the ring core prompt")
	_expect(hb_label != "", "high-base next-reward label should resolve to a real reward string")

	# Same high-base pet but capped at the ring core (T3 -> cap 15, sitting at
	# Lv15): the reachable reward sits above the cap, so prompt a ring core
	# upgrade — NOT the premature 최대 강화 완료 from the finding's repro.
	var highbase_capped := LingpetAffinityState.new()
	highbase_capped.set_run_ring_core_tier(3)
	highbase_capped.configure_reward_context("maribo", LingpetAffinityState.MOTION_STYLE_PATROL, 5, 5, 777, true, highbase_capped.get_run_ring_core_cap())
	_grant_round_commits(highbase_capped, "maribo", 400)
	_expect_eq(highbase_capped.get_level("maribo"), 15, "high-base T3 cap should hold the pet at Lv15")
	_expect_str(highbase_capped.get_next_reward_display_label("maribo"), "링코어 강화 시 해금", "high-base capped pet must prompt a ring core upgrade, not 최대 강화 완료")


func _history_dry_count(state: Object, pet_id: String) -> int:
	var history: Array = state.get_pet_data(pet_id).get("reward_history", []) as Array
	var dry := 0
	for card in history:
		if card is Dictionary and str((card as Dictionary).get("type", "")) == LingpetAffinityState.REWARD_TYPE_NO_REWARD:
			dry += 1
	return dry


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
	_expect_eq(state.get_run_ring_core_cap(), LingpetRingCoreRules.get_ring_core_cap_for_tier(3), "run ring core cap should reuse the ring-core tier->cap map")

	state.set_run_ring_core_tier(-99)
	_expect_eq(state.get_run_ring_core_tier(), 0, "set_run_ring_core_tier(-99) should clamp to 0")
	state.set_run_ring_core_tier(999)
	_expect_eq(state.get_run_ring_core_tier(), LingpetRingCoreRules.MAX_RING_CORE_TIER, "set_run_ring_core_tier(999) should clamp to max tier")

	var climber := LingpetAffinityState.new()
	_expect(climber.upgrade_run_ring_core_tier(), "upgrade from tier 0 should succeed")
	_expect_eq(climber.get_run_ring_core_tier(), 1, "first upgrade should reach tier 1")
	_expect(climber.upgrade_run_ring_core_tier(), "upgrade from tier 1 should succeed")
	_expect_eq(climber.get_run_ring_core_tier(), 2, "second upgrade should reach tier 2")
	while climber.get_run_ring_core_tier() < LingpetRingCoreRules.MAX_RING_CORE_TIER:
		_expect(climber.upgrade_run_ring_core_tier(), "upgrade below max tier should succeed")
	_expect_eq(climber.get_run_ring_core_tier(), LingpetRingCoreRules.MAX_RING_CORE_TIER, "sequential upgrades should reach max tier")
	_expect(not climber.upgrade_run_ring_core_tier(), "upgrade at max tier should return false")
	_expect_eq(climber.get_run_ring_core_tier(), LingpetRingCoreRules.MAX_RING_CORE_TIER, "tier should not exceed max after a blocked upgrade")

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


func _verify_ring_core_offer_cooldown_lifecycle() -> void:
	var cooldown := LingpetAffinityState.RING_CORE_OFFER_COOLDOWN_SCREENS
	_expect(cooldown > 0, "ring-core offer cooldown should be a positive number of presented screens")

	var state := LingpetAffinityState.new()
	_expect_eq(state.get_ring_core_offer_cooldown_screens(), 0, "fresh state should start with no ring-core offer cooldown")
	state.set_run_ring_core_tier(1)
	_expect_eq(state.get_ring_core_offer_cooldown_screens(), 0, "direct tier setter should not arm the ring-core offer cooldown")
	_expect(state.upgrade_run_ring_core_tier(2), "successful ring-core tier raise should arm the offer cooldown")
	_expect_eq(state.get_ring_core_offer_cooldown_screens(), cooldown, "ring-core tier raise should set the full offer cooldown")
	state.tick_ring_core_offer_cooldown()
	_expect_eq(state.get_ring_core_offer_cooldown_screens(), cooldown - 1, "one presented screen should decrement the offer cooldown by one")
	for _i in range(cooldown + 2):
		state.tick_ring_core_offer_cooldown()
	_expect_eq(state.get_ring_core_offer_cooldown_screens(), 0, "ring-core offer cooldown should floor at zero")
	_expect(not state.upgrade_run_ring_core_tier(2), "rejected same-tier upgrade should not re-arm the offer cooldown")
	_expect_eq(state.get_ring_core_offer_cooldown_screens(), 0, "rejected ring-core upgrade should leave the drained cooldown at zero")
	_expect(state.upgrade_run_ring_core_tier(3), "second successful ring-core tier raise should re-arm the offer cooldown")
	_expect_eq(state.get_ring_core_offer_cooldown_screens(), cooldown, "second tier raise should restore the full offer cooldown")
	state.reset_all()
	_expect_eq(state.get_ring_core_offer_cooldown_screens(), 0, "reset_all should clear the ring-core offer cooldown")


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
