extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const PerkFusionOutcomeRules := preload("res://scripts/characters/perk_fusion_outcome_rules.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkDisplayProjectionState := preload(
	"res://scripts/characters/runtime_perk_display_projection_state.gd"
)
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const DOWSING_GOGGLES_ID := "dowsing_goggles"
const BONUS_KEY := "fusion_byproduct_chance_pct"
const FUSION_SOURCES := [DOWSING_GOGGLES_ID, "dash_jump"]

var _failures: Array[String] = []


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_value_ladder_and_overflow()
	_verify_runtime_result_and_preview_share_bonus()
	_verify_dual_catalyst_stack_and_probability_cap()
	_verify_empty_pool_suppresses_bonus()
	_verify_localized_summary_covers_new_lane()
	LanguageSettings.set_test_locale_override("")
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("perk_fusion_dowsing_goggles_bonus_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_value_ladder_and_overflow() -> void:
	for level in range(1, 4):
		_expect_float(
			PerkConversionValues.get_value(DOWSING_GOGGLES_ID, BONUS_KEY, level),
			3.0 * float(level),
			"Heavenly Eye Art should add 3 percentage points of byproduct chance per level"
		)
	_expect_float(
		PerkConversionValues.get_value(DOWSING_GOGGLES_ID, BONUS_KEY, 5),
		15.0,
		"effective-level overflow should keep the +3 percentage-point ladder"
	)


func _verify_runtime_result_and_preview_share_bonus() -> void:
	var runtime := RuntimePerkState.new()
	runtime.runtime_skill_levels = {
		DOWSING_GOGGLES_ID: 3,
		"dash_jump": 5,
	}
	var catalog := RuntimePerkCatalog.new()
	_expect_float(
		runtime.get_perk_fusion_byproduct_chance_bonus_percent(),
		9.0,
		"runtime should expose the effective Heavenly Eye Art fusion bonus"
	)

	var side_effect_result: Dictionary = runtime._build_perk_fusion_commit_result(
		FUSION_SOURCES,
		catalog,
		_rolls(0.20999)
	)
	var byproduct_result: Dictionary = runtime._build_perk_fusion_commit_result(
		FUSION_SOURCES,
		catalog,
		_rolls(0.21)
	)
	var weights: Dictionary = byproduct_result.get("weights", {}) as Dictionary
	_expect_float(float(weights.get("success", 0.0)), 11.0, "Lv.3 should move 9 points out of preservation")
	_expect_float(float(weights.get("side_effect", 0.0)), 10.0, "Heavenly Eye Art should preserve qi-deviation chance")
	_expect_float(float(weights.get("byproduct", 0.0)), 79.0, "Lv.3 should raise Superior Martial Art chance from 70 to 79 percent")
	_expect_float(
		_sum_byproduct_count_weights(weights),
		79.0,
		"count-specific preview weights should track the boosted Superior Martial Art bucket"
	)
	_expect(str(side_effect_result.get("raw_outcome", "")) == "side_effect", "a roll just below the new boundary should remain a side effect")
	_expect(str(byproduct_result.get("raw_outcome", "")) == "byproduct", "the 21-percent boundary should enter the enlarged Superior Martial Art bucket")

	var projection_state := RuntimePerkDisplayProjectionState.new()
	var preview_snapshot: Dictionary = projection_state.merge_perk_fusion_modal_preview(
		runtime,
		{"selected_source_ids": FUSION_SOURCES.duplicate(), "phase": "confirm"},
		catalog
	)
	var preview: Dictionary = preview_snapshot.get("outcome_preview", {}) as Dictionary
	_expect_float(
		float(preview.get("byproduct_chance_bonus_percent", 0.0)),
		9.0,
		"modal preview should expose the same Heavenly Eye Art bonus"
	)
	_expect(
		preview.get("weights", {}) == weights,
		"modal preview and committed result should publish identical boosted weights"
	)
	var dowsing_option_keys: Array[String] = []
	for source_value: Variant in preview_snapshot.get("source_previews", []):
		if not source_value is Dictionary or str((source_value as Dictionary).get("perk_id", "")) != DOWSING_GOGGLES_ID:
			continue
		for option_value: Variant in (source_value as Dictionary).get("options", []):
			if option_value is Dictionary:
				dowsing_option_keys.append(str((option_value as Dictionary).get("option_key", "")))
	_expect(
		dowsing_option_keys.has(BONUS_KEY),
		"selecting Heavenly Eye Art as a fusion material should preview its new byproduct option"
	)


func _verify_dual_catalyst_stack_and_probability_cap() -> void:
	var stacked: Dictionary = PerkFusionOutcomeRules.build_final_outcome_weights(false, true, 9.0)
	_expect_float(float(stacked.get("success", -1.0)), 0.0, "Dual Catalyst and Lv.3 should exhaust the 20-point preservation bucket")
	_expect_float(float(stacked.get("side_effect", 0.0)), 10.0, "stacking should preserve qi-deviation chance")
	_expect_float(float(stacked.get("byproduct", 0.0)), 90.0, "stacking should fill the non-qi-deviation remainder with Superior Martial Arts")

	var capped: Dictionary = PerkFusionOutcomeRules.build_final_outcome_weights(false, true, 999.0)
	_expect_float(float(capped.get("success", -1.0)), 0.0, "combined bonuses should never make success negative")
	_expect_float(float(capped.get("side_effect", 0.0)), 10.0, "the cap should preserve qi-deviation chance")
	_expect_float(float(capped.get("byproduct", 0.0)), 90.0, "the Superior Martial Art bucket should cap at the non-qi-deviation remainder")


func _verify_empty_pool_suppresses_bonus() -> void:
	var weights: Dictionary = PerkFusionOutcomeRules.build_final_outcome_weights(true, true, 999.0)
	_expect_float(float(weights.get("success", 0.0)), 90.0, "empty pool should return all non-qi-deviation weight to preservation")
	_expect_float(float(weights.get("side_effect", 0.0)), 10.0, "empty pool should preserve qi-deviation chance")
	_expect_float(float(weights.get("byproduct", -1.0)), 0.0, "empty pool should suppress every byproduct bonus")


func _verify_localized_summary_covers_new_lane() -> void:
	var catalog := RuntimePerkCatalog.new()
	for locale: String in ["en", "zh", "ja", "es", "pt-BR", "ru"]:
		LanguageSettings.set_test_locale_override(locale)
		var perk_data: Dictionary = catalog.get_perk_data(DOWSING_GOGGLES_ID)
		var detail := str(perk_data.get("detail", ""))
		_expect(not _contains_hangul(detail), "Heavenly Eye Art localized detail should not leak Korean in %s" % locale)
		_expect(detail.contains("3"), "Heavenly Eye Art localized detail should mention the 3-point per-level lane in %s" % locale)


func _rolls(outcome_roll: float) -> Dictionary:
	return {
		"outcome": outcome_roll,
		"magnitude": [0.5],
		"lane_selection": [0.0],
		"delete": 1.0,
		"byproduct_count": 0.0,
		"byproduct_selection": [0.0],
	}


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s (actual=%s, expected=%s)" % [message, actual, expected])


func _sum_byproduct_count_weights(weights: Dictionary) -> float:
	return (
		float(weights.get("byproduct_count_1", 0.0))
		+ float(weights.get("byproduct_count_2", 0.0))
		+ float(weights.get("byproduct_count_3", 0.0))
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
