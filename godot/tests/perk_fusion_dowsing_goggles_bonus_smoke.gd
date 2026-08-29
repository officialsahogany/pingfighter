extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")
const PerkFusionOutcomeRules := preload("res://scripts/characters/perk_fusion_outcome_rules.gd")
const PerkFusionResultBuilder := preload("res://scripts/characters/perk_fusion_result_builder.gd")
const PerkFusionState := preload("res://scripts/characters/perk_fusion_state.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkDisplayProjectionState := preload(
	"res://scripts/characters/runtime_perk_display_projection_state.gd"
)
const RuntimePerkOverflowDescriptions := preload(
	"res://scripts/characters/runtime_perk_overflow_descriptions.gd"
)
const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const DOWSING_GOGGLES_ID := "dowsing_goggles"
const CHOICE_KEY := "bonus_perk_chance"
const RARE_KEY := "fusion_rare_slot_bonus_pct"
const COUNT_SHIFT_KEY := "fusion_byproduct_count_shift_pct"
const RETIRED_TOTAL_CHANCE_KEY := "fusion_byproduct_chance_pct"
const FUSION_SOURCES := [DOWSING_GOGGLES_ID, "dash_jump"]
const CHOICE_VALUES := [40.0, 70.0, 100.0]
const RARE_BONUS_VALUES := [5.0, 10.0, 15.0]
const COUNT_SHIFT_VALUES := [6.0, 12.0, 18.0]
const SIMULATION_SAMPLES := 10000

var _failures: Array[String] = []


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_value_tables_and_polish_contract()
	_verify_exact_distribution_table()
	_verify_runtime_preview_commit_and_polish_consumer()
	_verify_rare_slot_roll_boundaries()
	_verify_total_chance_dual_catalyst_and_pool_folding()
	_verify_overflow_caps_and_monotonicity()
	_verify_retired_saved_option_is_pruned()
	_verify_catalog_overflow_and_seven_locales()
	_run_deterministic_10000_roll_report()
	LanguageSettings.set_test_locale_override("")
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("perk_fusion_dowsing_goggles_bonus_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_value_tables_and_polish_contract() -> void:
	_expect(
		RuntimePerkProgression.PROGRESSIONS.has(DOWSING_GOGGLES_ID)
		and RuntimePerkProgression.is_converted_perk(DOWSING_GOGGLES_ID),
		"Dowsing numeric lanes must be registered in the canonical progression owner"
	)
	_expect(
		not RuntimePerkProgression.has_perk(DOWSING_GOGGLES_ID),
		"Dowsing must remain outside the migration and Elixir roster"
	)
	_expect(
		RuntimePerkProgression.TARGET_PERK_IDS.size() == 37,
		"the Dowsing redesign must not widen the 37-Mugong target roster"
	)
	var option_table: Dictionary = PerkConversionValues.CONVERTED_PERK_VALUES.get(
		DOWSING_GOGGLES_ID,
		{}
	)
	_expect(option_table.size() == 3, "Dowsing must expose exactly three converted option lanes")
	_expect(option_table.has(CHOICE_KEY), "Dowsing must retain the choice lane")
	_expect(option_table.has(RARE_KEY), "Dowsing must expose the rare-slot lane")
	_expect(option_table.has(COUNT_SHIFT_KEY), "Dowsing must expose the count-shift lane")
	_expect(not option_table.has(RETIRED_TOTAL_CHANCE_KEY), "retired total-chance lane must be absent")
	for index: int in range(3):
		var level := index + 1
		_expect_float(
			PerkConversionValues.get_value(DOWSING_GOGGLES_ID, CHOICE_KEY, level),
			CHOICE_VALUES[index],
			"the 40/70/100 extra-choice lane must remain unchanged at Lv.%d" % level
		)
		_expect_float(
			PerkConversionValues.get_value(DOWSING_GOGGLES_ID, RARE_KEY, level),
			RARE_BONUS_VALUES[index],
			"rare-slot bonus table mismatch at Lv.%d" % level
		)
		_expect_float(
			PerkConversionValues.get_value(DOWSING_GOGGLES_ID, COUNT_SHIFT_KEY, level),
			COUNT_SHIFT_VALUES[index],
			"count-share shift table mismatch at Lv.%d" % level
		)
	_expect_float(
		PerkConversionValues.get_value(DOWSING_GOGGLES_ID, RETIRED_TOTAL_CHANCE_KEY, 3),
		0.0,
		"the retired total Superior Martial Art chance lane must be absent"
	)

	_expect_float(
		PerkConversionValues.get_value(DOWSING_GOGGLES_ID, CHOICE_KEY, 4),
		100.0,
		"Lv.4 choice chance must stay capped"
	)
	_expect_float(
		PerkConversionValues.get_value(DOWSING_GOGGLES_ID, RARE_KEY, 4),
		20.0,
		"Lv.4 rare-slot bonus must keep its +5-point overflow step"
	)
	_expect_float(
		PerkConversionValues.get_value(DOWSING_GOGGLES_ID, COUNT_SHIFT_KEY, 4),
		24.0,
		"Lv.4 count shift must keep its +6-point overflow step"
	)
	_expect_float(
		PerkConversionValues.get_value(DOWSING_GOGGLES_ID, RARE_KEY, 20),
		45.0,
		"rare-slot modifier must cap at 45 points"
	)
	_expect_float(
		PerkConversionValues.get_value(DOWSING_GOGGLES_ID, COUNT_SHIFT_KEY, 20),
		(4.0 / 7.0 - 0.20) * 100.0,
		"count shift must cap at the 20-percent one-result floor"
	)

	var polished := RuntimePerkState.new()
	polished.runtime_skill_levels = {DOWSING_GOGGLES_ID: 3, "item_polish": 3}
	_expect_float(
		polished.get_perk_amplify_multiplier(DOWSING_GOGGLES_ID),
		1.25,
		"the production Polish fixture must resolve its canonical 1.25 multiplier"
	)
	_expect_float(
		PerkConversionValues.get_value(DOWSING_GOGGLES_ID, CHOICE_KEY, 3, polished),
		100.0,
		"Polish must preserve the choice-lane cap"
	)
	_expect_float(
		PerkConversionValues.get_value(DOWSING_GOGGLES_ID, RARE_KEY, 3, polished),
		18.75,
		"Polish must amplify the new rare-slot lane"
	)
	_expect_float(
		PerkConversionValues.get_value(DOWSING_GOGGLES_ID, COUNT_SHIFT_KEY, 3, polished),
		22.5,
		"Polish must amplify the new count-share lane"
	)
	var level_two_polish := RuntimePerkState.new()
	level_two_polish.runtime_skill_levels = {DOWSING_GOGGLES_ID: 1, "item_polish": 2}
	_expect_float(
		level_two_polish.get_perk_amplify_multiplier(DOWSING_GOGGLES_ID),
		1.145,
		"Lv.2 Polish must use the canonical registered progression multiplier"
	)
	_expect_float(
		PerkConversionValues.get_value(DOWSING_GOGGLES_ID, CHOICE_KEY, 1, level_two_polish),
		45.8,
		"Lv.2 Polish must amplify the preserved choice lane"
	)
	_expect_float(
		PerkConversionValues.get_value(DOWSING_GOGGLES_ID, RARE_KEY, 1, level_two_polish),
		5.725,
		"Lv.2 Polish must amplify the rare-slot lane"
	)
	_expect_float(
		PerkConversionValues.get_value(DOWSING_GOGGLES_ID, COUNT_SHIFT_KEY, 1, level_two_polish),
		6.87,
		"Lv.2 Polish must amplify the count-share lane"
	)
	var level_two_polish_catalog := RuntimePerkCatalog.new().get_perk_data(DOWSING_GOGGLES_ID)
	var level_two_polish_text := RuntimePerkOverflowDescriptions.resolve_stats_text_with_polish(
		DOWSING_GOGGLES_ID,
		level_two_polish_catalog.get("descriptions", {}),
		1,
		level_two_polish
	)
	_expect(
		level_two_polish_text
		== "무공 선택지 보너스 발동 확률 40 (+5.8)%, 합일 희귀 슬롯 확률 +5 (+0.72)%p, 상승무공 1개 비중 6 (+0.87)%p를 2개와 3개로 이동",
		"Lv.2 Polish tooltip must expose all three realized Dowsing deltas: %s"
		% level_two_polish_text
	)


func _verify_exact_distribution_table() -> void:
	var expected_absolute := [
		[40.0, 20.0, 10.0],
		[35.8, 22.8, 11.4],
		[31.6, 25.6, 12.8],
		[27.4, 28.4, 14.2],
	]
	var expected_rare := [
		[15.0, 25.0, 100.0],
		[20.0, 30.0, 100.0],
		[25.0, 35.0, 100.0],
		[30.0, 40.0, 100.0],
	]
	for level: int in range(4):
		var shift: float = 0.0 if level == 0 else float(COUNT_SHIFT_VALUES[level - 1])
		var rare_bonus: float = 0.0 if level == 0 else float(RARE_BONUS_VALUES[level - 1])
		var weights := PerkFusionResultBuilder.build_weight_table(8, false, shift)
		_expect_float(float(weights.get("success", -1.0)), 20.0, "success must stay 20 at Lv.%d" % level)
		_expect_float(float(weights.get("side_effect", -1.0)), 10.0, "side effect must stay 10 at Lv.%d" % level)
		_expect_float(float(weights.get("byproduct", -1.0)), 70.0, "byproduct total must stay 70 at Lv.%d" % level)
		for count_index: int in range(3):
			var count := count_index + 1
			_expect_float(
				float(weights.get("byproduct_count_%d" % count, -1.0)),
				float(expected_absolute[level][count_index]),
				"absolute count-%d weight mismatch at Lv.%d" % [count, level]
			)
			_expect_float(
				PerkFusionResultBuilder.resolve_rare_slot_chance(count, rare_bonus) * 100.0,
				float(expected_rare[level][count_index]),
				"rare-slot chance mismatch for count %d at Lv.%d" % [count, level]
			)
		var count_1_end := float(weights["byproduct_count_1"]) / 70.0
		var count_2_end := (
			float(weights["byproduct_count_1"])
			+ float(weights["byproduct_count_2"])
		) / 70.0
		_expect(
			PerkFusionOutcomeRules.resolve_byproduct_count(0.0, weights) == 1,
			"injected low roll must resolve one result at Lv.%d" % level
		)
		_expect(
			PerkFusionOutcomeRules.resolve_byproduct_count(count_1_end + 0.00001, weights) == 2,
			"injected middle roll must resolve two results at Lv.%d" % level
		)
		_expect(
			PerkFusionOutcomeRules.resolve_byproduct_count(count_2_end + 0.00001, weights) == 3,
			"injected high roll must resolve three results at Lv.%d" % level
		)


func _verify_runtime_preview_commit_and_polish_consumer() -> void:
	var catalog := RuntimePerkCatalog.new()
	var base_runtime := RuntimePerkState.new()
	base_runtime.runtime_skill_levels = {DOWSING_GOGGLES_ID: 1, "dash_jump": 5}
	var polished_runtime := RuntimePerkState.new()
	polished_runtime.runtime_skill_levels = {
		DOWSING_GOGGLES_ID: 3,
		"dash_jump": 5,
		"item_polish": 3,
	}
	_expect(
		not base_runtime.has_method("get_perk_fusion_byproduct_chance_bonus_percent"),
		"the retired total-chance runtime facade must be removed"
	)
	_expect_float(
		base_runtime.get_perk_fusion_rare_slot_bonus_percent(),
		5.0,
		"runtime must read the raw rare-slot lane"
	)
	_expect_float(
		base_runtime.get_perk_fusion_byproduct_count_shift_percent(),
		6.0,
		"runtime must read the raw count-share lane"
	)
	_expect_float(
		polished_runtime.get_perk_fusion_rare_slot_bonus_percent(),
		18.75,
		"runtime must read the Polish-amplified rare-slot lane"
	)
	_expect_float(
		polished_runtime.get_perk_fusion_byproduct_count_shift_percent(),
		22.5,
		"runtime must read the Polish-amplified count-share lane"
	)

	var base_result: Dictionary = base_runtime._build_perk_fusion_commit_result(
		FUSION_SOURCES,
		catalog,
		_rolls(0.99, 0.0, 1.0)
	)
	var polished_result: Dictionary = polished_runtime._build_perk_fusion_commit_result(
		FUSION_SOURCES,
		catalog,
		_rolls(0.99, 0.0, 1.0)
	)
	var runtime_rare_result: Dictionary = base_runtime._build_perk_fusion_commit_result(
		FUSION_SOURCES,
		catalog,
		_rolls(0.99, 0.0, 0.1999)
	)
	var runtime_general_result: Dictionary = base_runtime._build_perk_fusion_commit_result(
		FUSION_SOURCES,
		catalog,
		_rolls(0.99, 0.0, 0.2001)
	)
	_expect(
		_last_result_is_rare(runtime_rare_result),
		"real runtime commit must route the Lv.1 Dowsing rare bonus below 20%"
	)
	_expect(
		not _last_result_is_rare(runtime_general_result),
		"real runtime commit must reject the rare slot above the Lv.1 20% boundary"
	)
	var base_weights := _as_dict(base_result.get("weights", {}))
	var polished_weights := _as_dict(polished_result.get("weights", {}))
	_expect_float(
		float(base_weights.get("byproduct_count_1", 0.0)),
		35.8,
		"base commit must consume the 6-point count shift"
	)
	_expect_float(
		float(polished_weights.get("byproduct_count_1", 0.0)),
		24.25,
		"commit must consume the amplified 22.5-point count shift"
	)
	var commit_snapshots := _as_dict(polished_result.get("commit_value_snapshots", {}))
	var dowsing_commit_options := _as_dict(commit_snapshots.get(DOWSING_GOGGLES_ID, {}))
	_expect(dowsing_commit_options.has(CHOICE_KEY), "commit snapshot must retain the choice lane")
	_expect(dowsing_commit_options.has(RARE_KEY), "commit snapshot must retain the rare-slot lane")
	_expect(dowsing_commit_options.has(COUNT_SHIFT_KEY), "commit snapshot must retain the count-shift lane")
	_expect(
		not dowsing_commit_options.has(RETIRED_TOTAL_CHANCE_KEY),
		"commit snapshot must not retain the retired total-chance lane"
	)

	var projection_state := RuntimePerkDisplayProjectionState.new()
	var snapshot: Dictionary = projection_state.merge_perk_fusion_modal_preview(
		polished_runtime,
		{"selected_source_ids": FUSION_SOURCES.duplicate(), "phase": "confirm"},
		catalog
	)
	var preview := _as_dict(snapshot.get("outcome_preview", {}))
	_expect(
		preview.get("weights", {}) == polished_weights,
		"preview and commit must publish identical shifted weights"
	)
	_expect(
		not preview.has("byproduct_chance_bonus_percent"),
		"preview must not expose the retired total-chance bonus"
	)
	_expect_float(
		float(preview.get("rare_slot_chance_bonus_percent", 0.0)),
		18.75,
		"preview must expose amplified rare-slot bonus"
	)
	_expect_float(
		float(preview.get("byproduct_count_shift_percent", 0.0)),
		22.5,
		"preview must expose amplified count shift"
	)
	var rare_preview := _as_dict(preview.get("rare_slot_chance_percent_by_count", {}))
	_expect_float(float(rare_preview.get(1, 0.0)), 33.75, "preview count-1 rare chance must include Polish")
	_expect_float(float(rare_preview.get(2, 0.0)), 43.75, "preview count-2 rare chance must include Polish")
	_expect_float(float(rare_preview.get(3, 0.0)), 100.0, "preview count-3 rare slot must remain guaranteed")

	var option_keys: Array[String] = []
	for source_value: Variant in snapshot.get("source_previews", []):
		if (
			not source_value is Dictionary
			or str((source_value as Dictionary).get("perk_id", "")) != DOWSING_GOGGLES_ID
		):
			continue
		for option_value: Variant in (source_value as Dictionary).get("options", []):
			if option_value is Dictionary:
				option_keys.append(str((option_value as Dictionary).get("option_key", "")))
	_expect(option_keys.has(CHOICE_KEY), "fusion material preview must retain the choice lane")
	_expect(option_keys.has(RARE_KEY), "fusion material preview must show the rare-slot lane")
	_expect(option_keys.has(COUNT_SHIFT_KEY), "fusion material preview must show the count-share lane")
	_expect(
		not option_keys.has(RETIRED_TOTAL_CHANCE_KEY),
		"fusion material preview must not ghost the retired total-chance lane"
	)

	var preview_builds_before := int(
		projection_state.get_cache_stats().get("modal_preview_builds", 0)
	)
	polished_runtime.runtime_skill_levels[DOWSING_GOGGLES_ID] = 1
	polished_runtime.runtime_skill_levels["item_polish"] = 2
	var refreshed_snapshot: Dictionary = projection_state.merge_perk_fusion_modal_preview(
		polished_runtime,
		{"selected_source_ids": FUSION_SOURCES.duplicate(), "phase": "confirm"},
		catalog
	)
	var refreshed_preview := _as_dict(refreshed_snapshot.get("outcome_preview", {}))
	_expect(
		int(projection_state.get_cache_stats().get("modal_preview_builds", 0))
		== preview_builds_before + 1,
		"modal preview cache must rebuild when Dowsing or Polish levels change"
	)
	_expect_float(
		float(refreshed_preview.get("rare_slot_chance_bonus_percent", 0.0)),
		5.725,
		"refreshed preview must consume the current Polish-amplified rare bonus"
	)
	_expect_float(
		float(refreshed_preview.get("byproduct_count_shift_percent", 0.0)),
		6.87,
		"refreshed preview must consume the current Polish-amplified count shift"
	)
	var refreshed_commit: Dictionary = polished_runtime._build_perk_fusion_commit_result(
		FUSION_SOURCES,
		catalog,
		_rolls(0.99, 0.0, 1.0)
	)
	_expect(
		refreshed_preview.get("weights", {}) == refreshed_commit.get("weights", {}),
		"refreshed preview and real commit must stay weight-identical"
	)

	var scarred_runtime := RuntimePerkState.new()
	scarred_runtime.runtime_skill_levels = {DOWSING_GOGGLES_ID: 3, "dash_jump": 5}
	var scarred_record: Dictionary = scarred_runtime.commit_perk_fusion(
		FUSION_SOURCES,
		{
			"outcome": "side_effect",
			"option_penalties": {DOWSING_GOGGLES_ID: {
				RARE_KEY: {
					"original_value": 15.0,
					"adjusted_value": 12.0,
					"multiplier": 0.8,
					"polarity": "forward",
					"value_kind": "float",
				},
				COUNT_SHIFT_KEY: {
					"original_value": 18.0,
					"adjusted_value": 9.0,
					"multiplier": 0.5,
					"polarity": "forward",
					"value_kind": "float",
				},
			}},
		},
		catalog
	)
	_expect(not scarred_record.is_empty(), "Dowsing fusion-scar fixture must commit")
	_expect_float(
		scarred_runtime.get_perk_fusion_rare_slot_bonus_percent(),
		12.0,
		"runtime rare-slot getter must consume the live fusion scar"
	)
	_expect_float(
		scarred_runtime.get_perk_fusion_byproduct_count_shift_percent(),
		9.0,
		"runtime count-shift getter must consume the live fusion scar"
	)
	var scarred_projection_state := RuntimePerkDisplayProjectionState.new()
	var scarred_snapshot: Dictionary = scarred_projection_state.merge_perk_fusion_modal_preview(
		scarred_runtime,
		{"selected_source_ids": FUSION_SOURCES.duplicate(), "phase": "confirm"},
		catalog
	)
	var scarred_preview := _as_dict(scarred_snapshot.get("outcome_preview", {}))
	var scarred_commit: Dictionary = scarred_runtime._build_perk_fusion_commit_result(
		FUSION_SOURCES,
		catalog,
		_rolls(0.99, 0.0, 1.0)
	)
	_expect_float(
		float(scarred_preview.get("rare_slot_chance_bonus_percent", 0.0)),
		12.0,
		"preview must consume the scarred rare-slot value"
	)
	_expect_float(
		float(scarred_preview.get("byproduct_count_shift_percent", 0.0)),
		9.0,
		"preview must consume the scarred count-shift value"
	)
	_expect(
		scarred_preview.get("weights", {}) == scarred_commit.get("weights", {}),
		"scarred preview and real commit must stay weight-identical"
	)


func _verify_rare_slot_roll_boundaries() -> void:
	for level: int in range(4):
		var shift: float = 0.0 if level == 0 else float(COUNT_SHIFT_VALUES[level - 1])
		var rare_bonus: float = 0.0 if level == 0 else float(RARE_BONUS_VALUES[level - 1])
		var weights := PerkFusionResultBuilder.build_weight_table(8, false, shift)
		var count_2_roll := (
			float(weights.get("byproduct_count_1", 0.0))
			+ float(weights.get("byproduct_count_2", 0.0)) * 0.5
		) / 70.0
		var count_1_threshold := PerkFusionResultBuilder.resolve_rare_slot_chance(1, rare_bonus)
		var count_2_threshold := PerkFusionResultBuilder.resolve_rare_slot_chance(2, rare_bonus)
		var count_1_rare := _direct_result(shift, rare_bonus, 0.0, count_1_threshold - 0.0001)
		var count_1_general := _direct_result(shift, rare_bonus, 0.0, count_1_threshold + 0.0001)
		_expect(_last_result_is_rare(count_1_rare), "Lv.%d count-1 roll below threshold must promote" % level)
		_expect(not _last_result_is_rare(count_1_general), "Lv.%d count-1 roll above threshold must stay general" % level)
		var count_2_rare := _direct_result(
			shift,
			rare_bonus,
			count_2_roll,
			count_2_threshold - 0.0001
		)
		var count_2_general := _direct_result(
			shift,
			rare_bonus,
			count_2_roll,
			count_2_threshold + 0.0001
		)
		_expect(_last_result_is_rare(count_2_rare), "Lv.%d count-2 roll below threshold must promote" % level)
		_expect(not _last_result_is_rare(count_2_general), "Lv.%d count-2 roll above threshold must stay general" % level)
		var count_3 := _direct_result(shift, rare_bonus, 0.9999, 1.0)
		_expect(
			_as_array(count_3.get("byproducts", [])).size() == 3,
			"Lv.%d high count roll must produce three byproducts" % level
		)
		_expect(_last_result_is_rare(count_3), "Lv.%d count-3 final slot must stay guaranteed rare" % level)


func _verify_total_chance_dual_catalyst_and_pool_folding() -> void:
	var base := PerkFusionResultBuilder.build_weight_table(8, false, 18.0)
	var catalyst := PerkFusionResultBuilder.build_weight_table(8, true, 18.0)
	_expect_float(float(base.get("byproduct", 0.0)), 70.0, "Lv.3 Dowsing must not change total byproduct chance")
	_expect_float(float(catalyst.get("success", 0.0)), 5.0, "Dual Catalyst must still move 15 points out of preservation")
	_expect_float(float(catalyst.get("side_effect", 0.0)), 10.0, "Dual Catalyst must preserve side-effect chance")
	_expect_float(float(catalyst.get("byproduct", 0.0)), 85.0, "Dual Catalyst must still add 15 points to byproduct chance")
	_expect_float(_sum_count_weights(catalyst), 85.0, "shifted count weights must sum to the catalyst total")

	_expect_float(
		float(base.get("success", 0.0)),
		20.0,
		"Dowsing shift must leave the base preservation weight unchanged"
	)
	var pool_1 := PerkFusionResultBuilder.build_weight_table(1, false, 18.0)
	var pool_2 := PerkFusionResultBuilder.build_weight_table(2, false, 18.0)
	_expect_float(float(pool_1.get("byproduct_count_1", 0.0)), 70.0, "one-item pool must fold all shifted weight into count 1")
	_expect_float(float(pool_1.get("byproduct_count_2", 0.0)), 0.0, "one-item pool cannot offer count 2")
	_expect_float(float(pool_2.get("byproduct_count_1", 0.0)), 27.4, "two-item pool must preserve shifted count-1 weight")
	_expect_float(float(pool_2.get("byproduct_count_2", 0.0)), 42.6, "two-item pool must fold count-3 weight into count 2")
	_expect_float(float(pool_2.get("byproduct_count_3", 0.0)), 0.0, "two-item pool cannot offer count 3")

	var empty := PerkFusionResultBuilder.build_weight_table(0, true, 999.0)
	_expect_float(float(empty.get("success", 0.0)), 90.0, "empty pool must return weight to preservation")
	_expect_float(float(empty.get("side_effect", 0.0)), 10.0, "empty pool must preserve side-effect chance")
	_expect_float(float(empty.get("byproduct", -1.0)), 0.0, "empty pool must suppress byproducts")
	_expect_float(_sum_count_weights(empty), 0.0, "empty pool must suppress all count weights")


func _verify_overflow_caps_and_monotonicity() -> void:
	var previous_rare_bonus := 0.0
	var previous_count_shift := 0.0
	var previous_count_2 := 0.0
	var previous_count_3 := 0.0
	for level: int in range(1, 21):
		var rare_bonus := PerkConversionValues.get_value(DOWSING_GOGGLES_ID, RARE_KEY, level)
		var count_shift := PerkConversionValues.get_value(DOWSING_GOGGLES_ID, COUNT_SHIFT_KEY, level)
		var weights := PerkFusionResultBuilder.build_weight_table(8, false, count_shift)
		var count_1_share := float(weights.get("byproduct_count_1", 0.0)) / 70.0
		var count_2 := float(weights.get("byproduct_count_2", 0.0))
		var count_3 := float(weights.get("byproduct_count_3", 0.0))
		_expect(rare_bonus + 0.0001 >= previous_rare_bonus, "rare bonus must be monotonic through Lv.%d" % level)
		_expect(count_shift + 0.0001 >= previous_count_shift, "count shift must be monotonic through Lv.%d" % level)
		_expect(count_2 + 0.0001 >= previous_count_2, "two-result weight must be monotonic through Lv.%d" % level)
		_expect(count_3 + 0.0001 >= previous_count_3, "three-result weight must be monotonic through Lv.%d" % level)
		_expect(
			PerkFusionResultBuilder.resolve_rare_slot_chance(1, rare_bonus) <= 0.6001,
			"count-1 rare chance must cap at 60%"
		)
		_expect(
			PerkFusionResultBuilder.resolve_rare_slot_chance(2, rare_bonus) <= 0.6001,
			"count-2 rare chance must cap at 60%"
		)
		_expect(count_1_share + 0.0001 >= 0.20, "one-result conditional share must stay at 20% or above")
		previous_rare_bonus = rare_bonus
		previous_count_shift = count_shift
		previous_count_2 = count_2
		previous_count_3 = count_3

	var capped_polish := RuntimePerkState.new()
	capped_polish.runtime_skill_levels = {DOWSING_GOGGLES_ID: 20, "item_polish": 20}
	_expect(
		capped_polish.get_perk_fusion_rare_slot_bonus_percent() <= 45.0001,
		"Polish-amplified rare bonus must respect its final-chance cap"
	)
	_expect(
		capped_polish.get_perk_fusion_byproduct_count_shift_percent()
		<= (4.0 / 7.0 - 0.20) * 100.0 + 0.0001,
		"Polish-amplified shift must preserve the 20% one-result floor"
	)


func _verify_retired_saved_option_is_pruned() -> void:
	var state := PerkFusionState.new()
	var old_entry := {"original_value": 9.0, "adjusted_value": 7.2, "multiplier": 0.8}
	var result: Dictionary = state.restore_snapshot(
		{
			"records": [{
				"fusion_id": "fusion_0",
				"sources": FUSION_SOURCES.duplicate(),
				"outcome": "side_effect",
				"option_penalties": {DOWSING_GOGGLES_ID: {
					RETIRED_TOTAL_CHANCE_KEY: old_entry,
					RARE_KEY: old_entry,
				}},
				"commit_value_snapshots": {DOWSING_GOGGLES_ID: {
					RETIRED_TOTAL_CHANCE_KEY: {"value": 9.0},
					RARE_KEY: {"value": 15.0},
				}},
				"deleted_options": {DOWSING_GOGGLES_ID: [
					RETIRED_TOTAL_CHANCE_KEY,
					COUNT_SHIFT_KEY,
				]},
			}],
			"next_fusion_index": 1,
			"fusion_revision": 1,
		},
		RuntimePerkCatalog.new(),
		{DOWSING_GOGGLES_ID: 3, "dash_jump": 5}
	)
	_expect(int(result.get("kept", 0)) == 1, "valid historical record must survive option pruning")
	var record := _as_dict(state.get_all_records()[0])
	var penalties := _as_dict(
		_as_dict(record.get("option_penalties", {})).get(DOWSING_GOGGLES_ID, {})
	)
	var snapshots := _as_dict(
		_as_dict(record.get("commit_value_snapshots", {})).get(DOWSING_GOGGLES_ID, {})
	)
	var deleted := _as_array(
		_as_dict(record.get("deleted_options", {})).get(DOWSING_GOGGLES_ID, [])
	)
	_expect(
		not penalties.has(RETIRED_TOTAL_CHANCE_KEY) and penalties.has(RARE_KEY),
		"restore must prune only the retired penalty key"
	)
	_expect(
		not snapshots.has(RETIRED_TOTAL_CHANCE_KEY) and snapshots.has(RARE_KEY),
		"restore must prune only the retired snapshot key"
	)
	_expect(
		not deleted.has(RETIRED_TOTAL_CHANCE_KEY) and deleted.has(COUNT_SHIFT_KEY),
		"restore must prune only the retired deleted-option key"
	)


func _verify_catalog_overflow_and_seven_locales() -> void:
	LanguageSettings.set_test_locale_override("")
	var catalog := RuntimePerkCatalog.new()
	var korean: Dictionary = catalog.get_perk_data(DOWSING_GOGGLES_ID)
	var descriptions := _as_dict(korean.get("descriptions", {}))
	for level: int in range(1, 4):
		var text := str(descriptions.get(level, ""))
		_expect(
			text.contains("%d%%" % int(CHOICE_VALUES[level - 1])),
			"Korean Lv.%d copy must retain the choice chance" % level
		)
		_expect(
			text.contains("+%d%%p" % int(RARE_BONUS_VALUES[level - 1])),
			"Korean Lv.%d copy must expose rare-slot bonus" % level
		)
		_expect(
			text.contains("%d%%p" % int(COUNT_SHIFT_VALUES[level - 1])),
			"Korean Lv.%d copy must expose count shift" % level
		)
		_expect(
			not text.contains("발현 확률"),
			"Korean Lv.%d copy must remove retired total-chance wording" % level
		)
	var detail := str(korean.get("detail", ""))
	_expect(
		detail.contains("최대 60%") and detail.contains("최소 20%"),
		"Korean detail must disclose both overflow caps"
	)
	_expect(not detail.contains("—"), "Korean detail must not use an em dash")
	var overflow := RuntimePerkOverflowDescriptions.resolve_stats_text(
		DOWSING_GOGGLES_ID,
		descriptions,
		4
	)
	_expect(
		overflow.contains("100%") and overflow.contains("+20%p") and overflow.contains("24%p"),
		"overflow copy must expose all three Lv.4 values"
	)
	_expect(
		not overflow.contains(RETIRED_TOTAL_CHANCE_KEY) and not overflow.contains("발현 확률"),
		"overflow copy must not expose the retired lane"
	)

	for locale: String in ["en", "zh", "ja", "es", "pt-BR", "ru"]:
		LanguageSettings.set_test_locale_override(locale)
		var localized := RuntimePerkCatalog.new().get_perk_data(DOWSING_GOGGLES_ID)
		var localized_detail := str(localized.get("detail", ""))
		_expect(not localized_detail.is_empty(), "localized detail must exist in %s" % locale)
		_expect(not _contains_hangul(localized_detail), "localized detail must not leak Korean in %s" % locale)
		for ladder: String in ["40/70/100", "5/10/15", "6/12/18"]:
			_expect(
				localized_detail.contains(ladder),
				"localized detail must contain %s in %s" % [ladder, locale]
			)
		_expect(
			localized_detail.contains("60") and localized_detail.contains("20"),
			"localized detail must disclose the 60-percent and 20-percent caps in %s" % locale
			)
		_expect(
			localized_detail.contains("60") and localized_detail.contains("20"),
			"localized detail must disclose both caps in %s" % locale
		)
		_expect(not localized_detail.contains("—"), "localized detail must not use an em dash in %s" % locale)
		for option_key: String in [RARE_KEY, COUNT_SHIFT_KEY]:
			var label := PerkFusionLocalization.option_label(option_key)
			_expect(
				label != option_key and not label.is_empty(),
				"fusion option label must be localized for %s in %s" % [option_key, locale]
			)
			_expect(
				not _contains_hangul(label),
				"fusion option label must not leak Korean for %s in %s" % [option_key, locale]
			)
			_expect(
				PerkFusionLocalization.option_value_text(option_key, 5.0) == "+5%p",
				"fusion percentage-point value must keep its plus sign and pp unit for %s in %s"
				% [option_key, locale]
			)
		var rare_probability_label := PerkFusionLocalization.format("prob_rare_slot", [30])
		_expect(
			rare_probability_label.contains("30%") and not _contains_hangul(rare_probability_label),
			"rare-slot probability label must be localized in %s" % locale
		)


func _run_deterministic_10000_roll_report() -> void:
	var expected_count_hits := [
		[5714, 2857, 1429],
		[5114, 3257, 1629],
		[4514, 3657, 1829],
		[3914, 4057, 2029],
	]
	var expected_rare_hits := [
		[1500, 2500, 10000],
		[2000, 3000, 10000],
		[2500, 3500, 10000],
		[3000, 4000, 10000],
	]
	for level: int in range(4):
		var shift: float = 0.0 if level == 0 else float(COUNT_SHIFT_VALUES[level - 1])
		var rare_bonus: float = 0.0 if level == 0 else float(RARE_BONUS_VALUES[level - 1])
		var weights := PerkFusionResultBuilder.build_weight_table(8, false, shift)
		var count_hits := [0, 0, 0]
		var rare_1_hits := 0
		var rare_2_hits := 0
		for sample: int in range(SIMULATION_SAMPLES):
			var midpoint_roll := (float(sample) + 0.5) / float(SIMULATION_SAMPLES)
			var resolved_count := PerkFusionOutcomeRules.resolve_byproduct_count(midpoint_roll, weights)
			count_hits[resolved_count - 1] = int(count_hits[resolved_count - 1]) + 1
			if midpoint_roll < PerkFusionResultBuilder.resolve_rare_slot_chance(1, rare_bonus):
				rare_1_hits += 1
			if midpoint_roll < PerkFusionResultBuilder.resolve_rare_slot_chance(2, rare_bonus):
				rare_2_hits += 1
		var rare_hits := [rare_1_hits, rare_2_hits, SIMULATION_SAMPLES]
		_expect(count_hits == expected_count_hits[level], "10k midpoint count table mismatch at Lv.%d" % level)
		_expect(rare_hits == expected_rare_hits[level], "10k midpoint rare table mismatch at Lv.%d" % level)
		print(
			"DOWSING_GRID_10000 Lv%d count=%d/%d/%d rare=%d/%d/%d"
			% [level, count_hits[0], count_hits[1], count_hits[2], rare_hits[0], rare_hits[1], rare_hits[2]]
		)


func _direct_result(
	count_shift_percent: float,
	rare_bonus_percent: float,
	count_roll: float,
	rare_roll: float
) -> Dictionary:
	return PerkFusionResultBuilder.build_result(
		{
			"source_ids": FUSION_SOURCES.duplicate(),
			"limit_break_eligible_sources": ["dash_jump"],
			"available_byproducts": [
				"wall_bounce_gold",
				"dash_paddle_speed",
				"vigor_recycle",
				"linked_arsenal",
				"spellbreaker_guard",
			],
			"owned_byproducts": [],
			"byproduct_count_shift_percent": count_shift_percent,
			"rare_slot_chance_bonus_percent": rare_bonus_percent,
		},
		_rolls(0.99, count_roll, rare_roll)
	)


func _last_result_is_rare(result: Dictionary) -> bool:
	var byproducts := _as_array(result.get("byproducts", []))
	if byproducts.is_empty():
		return false
	return bool(PerkFusionResultBuilder.RARE_BYPRODUCT_IDS.get(str(byproducts.back()), false))


func _rolls(outcome_roll: float, count_roll: float, rare_roll: float) -> Dictionary:
	return {
		"outcome": outcome_roll,
		"magnitude": [0.5],
		"lane_selection": [0.0],
		"delete": 1.0,
		"byproduct_count": count_roll,
		"byproduct_selection": [0.0, 0.0, 0.0],
		"rare_slot": rare_roll,
	}


func _sum_count_weights(weights: Dictionary) -> float:
	return (
		float(weights.get("byproduct_count_1", 0.0))
		+ float(weights.get("byproduct_count_2", 0.0))
		+ float(weights.get("byproduct_count_3", 0.0))
	)


func _as_dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _as_array(value: Variant) -> Array:
	return value as Array if value is Array else []


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(
		absf(actual - expected) <= 0.0001,
		"%s (actual=%.6f, expected=%.6f)" % [message, actual, expected]
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _contains_hangul(value: String) -> bool:
	for index: int in range(value.length()):
		var codepoint := value.unicode_at(index)
		if codepoint >= 0xAC00 and codepoint <= 0xD7A3:
			return true
	return false
