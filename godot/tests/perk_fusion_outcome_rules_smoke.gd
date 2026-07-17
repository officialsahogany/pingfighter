extends SceneTree

const PerkFusionOutcomeRules := preload("res://scripts/characters/perk_fusion_outcome_rules.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_outcome_weights()
	_verify_side_effect_magnitude_and_polarity()
	_verify_integer_lane_quantization()
	_verify_limit_break_eligibility()

	if _failures.is_empty():
		print("perk_fusion_outcome_rules_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_outcome_weights() -> void:
	var base_weights: Dictionary = PerkFusionOutcomeRules.build_outcome_weights()
	_expect_float(float(base_weights.get("success", 0.0)), 55.0, "base success weight should be 55 percent")
	_expect_float(float(base_weights.get("side_effect", 0.0)), 25.0, "base side-effect weight should be 25 percent")
	_expect_float(float(base_weights.get("byproduct", 0.0)), 20.0, "base byproduct weight should be 20 percent")
	_expect_float(_sum_weights(base_weights), 100.0, "base outcome weights should sum to 100 percent")

	var catalyst_weights: Dictionary = PerkFusionOutcomeRules.build_outcome_weights(true)
	_expect_float(float(catalyst_weights.get("success", 0.0)), 40.0, "dual catalyst should subtract 15 percentage points from success")
	_expect_float(float(catalyst_weights.get("side_effect", 0.0)), 25.0, "dual catalyst should preserve side-effect weight")
	_expect_float(float(catalyst_weights.get("byproduct", 0.0)), 35.0, "dual catalyst should add 15 percentage points to byproduct")
	_expect_float(_sum_weights(catalyst_weights), 100.0, "dual-catalyst outcome weights should sum to 100 percent")

	var empty_pool_weights: Dictionary = PerkFusionOutcomeRules.build_final_outcome_weights(true, true)
	_expect_float(float(empty_pool_weights.get("success", 0.0)), 75.0, "empty pool should centralize its success redistribution")
	_expect_float(float(empty_pool_weights.get("side_effect", 0.0)), 25.0, "empty pool should preserve side-effect weight")
	_expect_float(float(empty_pool_weights.get("byproduct", -1.0)), 0.0, "empty pool should suppress the byproduct bucket even with dual catalyst")
	_expect_float(_sum_weights(empty_pool_weights), 100.0, "empty-pool final weights should sum to 100 percent")



func _verify_side_effect_magnitude_and_polarity() -> void:
	_expect_float(PerkFusionOutcomeRules.resolve_side_effect_magnitude(-1.0), 0.10, "magnitude should clamp to 10 percent at the low end")
	_expect_float(PerkFusionOutcomeRules.resolve_side_effect_magnitude(0.5), 0.20, "midpoint magnitude should be 20 percent")
	_expect_float(PerkFusionOutcomeRules.resolve_side_effect_magnitude(2.0), 0.30, "magnitude should clamp to 30 percent at the high end")
	_expect_float(PerkFusionOutcomeRules.apply_forward_penalty(100.0, 0.20), 80.0, "forward lane should become smaller")
	_expect_float(PerkFusionOutcomeRules.apply_reverse_penalty(100.0, 0.20), 120.0, "reverse lane should become larger")
	_expect_float(PerkFusionOutcomeRules.apply_forward_penalty(100.0, 0.01), 90.0, "forward magnitude should clamp to the 10-percent floor")
	_expect_float(PerkFusionOutcomeRules.apply_reverse_penalty(100.0, 0.90), 130.0, "reverse magnitude should clamp to the 30-percent ceiling")


func _verify_integer_lane_quantization() -> void:
	var forward_small: Dictionary = PerkFusionOutcomeRules.apply_forward_integer_penalty(2, 0.10)
	_expect(bool(forward_small.get("excluded", false)), "forward integer lane should be excluded when one step would exceed 30 percent")
	_expect(str(forward_small.get("excluded_reason", "")) == "unrepresentable_integer_lane", "unrepresentable forward integer lane should expose its reason")

	var reverse_small: Dictionary = PerkFusionOutcomeRules.apply_reverse_integer_penalty(2, 0.10)
	_expect(bool(reverse_small.get("excluded", false)), "reverse integer lane should be excluded when one step would exceed 30 percent")
	_expect(str(reverse_small.get("excluded_reason", "")) == "unrepresentable_integer_lane", "unrepresentable reverse integer lane should expose its reason")

	var forward_exact: Dictionary = PerkFusionOutcomeRules.apply_forward_integer_penalty(10, 0.10)
	var reverse_exact: Dictionary = PerkFusionOutcomeRules.apply_reverse_integer_penalty(10, 0.10)
	_expect(int(forward_exact.get("value", 0)) == 9, "exact forward integer boundary should not over-quantize")
	_expect(int(reverse_exact.get("value", 0)) == 11, "exact reverse integer boundary should not over-quantize")

	var boolean_zero: Dictionary = PerkFusionOutcomeRules.apply_forward_integer_penalty(0, 0.20, true)
	var boolean_one: Dictionary = PerkFusionOutcomeRules.apply_reverse_integer_penalty(1, 0.20, true)
	_expect(bool(boolean_zero.get("excluded", false)), "zero-valued boolean lane should return an exclusion signal")
	_expect(bool(boolean_one.get("excluded", false)), "one-valued boolean lane should return an exclusion signal")
	_expect(str(boolean_one.get("excluded_reason", "")) == "boolean_lane", "boolean exclusion should expose its reason")
	_expect(int(boolean_zero.get("value", -1)) == 0 and int(boolean_one.get("value", -1)) == 1, "boolean exclusion should preserve the original value")

	var numeric_one: Dictionary = PerkFusionOutcomeRules.apply_reverse_integer_penalty(1, 0.10, false)
	_expect(bool(numeric_one.get("excluded", false)), "numeric value one should be excluded when no 10-to-30-percent integer step exists")


func _verify_limit_break_eligibility() -> void:
	_expect(PerkFusionOutcomeRules.is_limit_break_eligible({"max_level": 5}), "scaling non-exempt perk should be limit-break eligible")
	_expect(not PerkFusionOutcomeRules.is_limit_break_eligible({"max_level": 1}), "single-level perk should be limit-break ineligible")
	_expect(not PerkFusionOutcomeRules.is_limit_break_eligible({"max_level": 5, "effective_level_exempt": true}), "effective-level-exempt perk should be limit-break ineligible")
	_expect(not PerkFusionOutcomeRules.is_limit_break_eligible({}), "missing perk data should be limit-break ineligible")
	var exempt_reason: Dictionary = PerkFusionOutcomeRules.get_limit_break_eligibility({
		"max_level": 5,
		"effective_level_exempt": true,
	})
	_expect(str(exempt_reason.get("reason", "")) == "effective_level_exempt", "limit-break rejection should expose the exemption reason")


func _sum_weights(weights: Dictionary) -> float:
	return (
		float(weights.get("success", 0.0))
		+ float(weights.get("side_effect", 0.0))
		+ float(weights.get("byproduct", 0.0))
	)


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s (actual=%s, expected=%s)" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
