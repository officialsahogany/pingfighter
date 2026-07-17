extends SceneTree

const PerkFusionResultBuilder := preload("res://scripts/characters/perk_fusion_result_builder.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_production_outcome_boundaries()
	_verify_float_penalties_and_unique_lane_selection()
	_verify_reverse_polarity_worsens_the_value()
	_verify_reverse_lane_is_never_deleted()
	_verify_integer_quantization_and_stable_fallback()
	_verify_delete_marks_without_removing_input()
	_verify_zero_pool_distribution_and_token_consumption()
	_verify_dual_catalyst_distribution()
	_verify_core_stabilization()
	_verify_owned_exclusion_and_count_clamp()
	_verify_rare_slot_policy()
	_verify_limit_break_payload()

	if _failures.is_empty():
		print("perk_fusion_result_builder_smoke: ok")
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)


func _verify_production_outcome_boundaries() -> void:
	_expect(_raw_outcome_at(0.0) == "success", "production zero roll should resolve to success")
	_expect(_raw_outcome_at(0.549999) == "success", "production roll below 55 percent should resolve to success")
	_expect(_raw_outcome_at(0.55) == "side_effect", "production 55-percent boundary should resolve to side effect")
	_expect(_raw_outcome_at(0.799999) == "side_effect", "production roll below 80 percent should resolve to side effect")
	_expect(_raw_outcome_at(0.80) == "byproduct", "production 80-percent boundary should resolve to byproduct")
	_expect(_raw_outcome_at(1.0) == "byproduct", "production one-unit roll should clamp to byproduct")

	_expect(_raw_outcome_at(0.399999, true) == "success", "production dual roll below 40 percent should resolve to success")
	_expect(_raw_outcome_at(0.40, true) == "side_effect", "production dual 40-percent boundary should resolve to side effect")
	_expect(_raw_outcome_at(0.649999, true) == "side_effect", "production dual roll below 65 percent should resolve to side effect")
	_expect(_raw_outcome_at(0.65, true) == "byproduct", "production dual 65-percent boundary should resolve to byproduct")


func _verify_float_penalties_and_unique_lane_selection() -> void:
	var result: Dictionary = PerkFusionResultBuilder.build_result(
		_context([
			_lane("source_a", "power", 100.0, "forward", "float"),
			_lane("source_b", "speed", 50.0, "forward", "float"),
		]),
		{
			"outcome": 0.60,
			"magnitude": [0.5, 1.0],
			"lane_selection": [0.0, 0.0],
			"delete": 1.0,
		}
	)
	var penalties: Dictionary = _as_dict(result.get("option_penalties", {}))
	var snapshots: Dictionary = _as_dict(result.get("commit_value_snapshots", {}))
	var power: Dictionary = _penalty(penalties, "source_a", "power")
	var speed: Dictionary = _penalty(penalties, "source_b", "speed")
	_expect(str(result.get("outcome", "")) == "side_effect", "representable lanes should preserve side-effect outcome")
	_expect(penalties.size() == 2, "two selection rolls should select two unique lanes")
	_expect_float(float(power.get("adjusted_value", 0.0)), 80.0, "20-percent forward penalty should reduce 100 to 80")
	_expect_float(float(power.get("nominal_pct", 0.0)), 20.0, "penalty should record percentage points")
	_expect_float(float(power.get("multiplier", 0.0)), 0.8, "forward penalty should record its applied multiplier")
	_expect_float(float(speed.get("adjusted_value", 0.0)), 35.0, "30-percent forward penalty should reduce 50 to 35")
	_expect_float(float(_as_dict(_as_dict(snapshots.get("source_a", {})).get("power", {})).get("value", 0.0)), 100.0, "commit value snapshots should preserve every source lane for the immutable S4 log")
	_expect_float(float(_as_dict(_as_dict(snapshots.get("source_b", {})).get("speed", {})).get("value", 0.0)), 50.0, "commit value snapshots should preserve unchanged material context")


func _verify_reverse_polarity_worsens_the_value() -> void:
	var result: Dictionary = PerkFusionResultBuilder.build_result(
		_context([_lane("source_a", "cooldown", 10.0, "reverse", "float")]),
		{"outcome": 0.60, "magnitude": [0.5], "lane_selection": [0.0], "delete": 1.0}
	)
	var penalty: Dictionary = _penalty(
		_as_dict(result.get("option_penalties", {})),
		"source_a",
		"cooldown"
	)
	_expect_float(float(penalty.get("adjusted_value", 0.0)), 12.0, "reverse lane should worsen by becoming larger")
	_expect_float(float(penalty.get("multiplier", 0.0)), 1.2, "reverse lane should expose a greater-than-one multiplier")


func _verify_reverse_lane_is_never_deleted() -> void:
	var reverse_lane: Dictionary = _lane("source_a", "cooldown", 10.0, "reverse", "float")
	reverse_lane["remaining_option_count"] = 2
	var result: Dictionary = PerkFusionResultBuilder.build_result(
		_context([reverse_lane]),
		{"outcome": 0.60, "magnitude": [0.5], "lane_selection": [0.0], "delete": 0.0}
	)
	_expect(
		_as_dict(result.get("deleted_options", {})).is_empty(),
		"delete branch must never zero a reverse cost/cooldown lane into a buff"
	)
	var penalty: Dictionary = _penalty(
		_as_dict(result.get("option_penalties", {})),
		"source_a",
		"cooldown"
	)
	_expect_float(
		float(penalty.get("adjusted_value", 0.0)),
		12.0,
		"ineligible reverse deletion should fall back to an adverse magnitude penalty"
	)


func _verify_integer_quantization_and_stable_fallback() -> void:
	var quantized: Dictionary = PerkFusionResultBuilder.build_result(
		_context([_lane("source_a", "charges", 10, "forward", "int")]),
		{"outcome": 0.60, "magnitude": [0.0], "lane_selection": [0.0], "delete": 1.0}
	)
	var quantized_penalty: Dictionary = _penalty(
		_as_dict(quantized.get("option_penalties", {})),
		"source_a",
		"charges"
	)
	_expect(int(quantized_penalty.get("adjusted_value", 0)) == 9, "integer lane should use the outcome-rule quantizer")

	var unrepresentable: Dictionary = PerkFusionResultBuilder.build_result(
		_context([
			_lane("source_a", "tiny", 2, "forward", "int"),
			_lane("source_b", "toggle", 1, "forward", "int", true),
		]),
		{"outcome": 0.60, "magnitude": [0.0], "lane_selection": [0.0], "delete": 1.0}
	)
	_expect(str(unrepresentable.get("raw_outcome", "")) == "side_effect", "unrepresentable lanes should not erase the raw roll")
	_expect(str(unrepresentable.get("outcome", "")) == "stable", "zero applicable side-effect lanes should become stable")
	_expect(_as_dict(unrepresentable.get("option_penalties", {})).is_empty(), "unrepresentable and boolean lanes should not create penalties")


func _verify_delete_marks_without_removing_input() -> void:
	var lane: Dictionary = _lane("source_a", "option_a", 10.0, "forward", "float")
	lane["remaining_option_count"] = 2
	var lanes: Array = [lane]
	var result: Dictionary = PerkFusionResultBuilder.build_result(
		_context(lanes),
		{"outcome": 0.60, "lane_selection": [0.0], "delete": 0.199999}
	)
	var deleted: Dictionary = _as_dict(result.get("deleted_options", {}))
	_expect(_as_array(deleted.get("source_a", [])) == ["option_a"], "delete branch should mark one option when its source retains another")
	_expect(_as_dict(result.get("option_penalties", {})).is_empty(), "delete branch should not also apply the 80-percent reduction branch")
	_expect(str(_as_dict(lanes[0]).get("key", "")) == "option_a", "builder should not remove or mutate the input option")

	var protected_last_option: Dictionary = _lane("source_a", "only_option", 10.0, "forward", "float")
	protected_last_option["remaining_option_count"] = 1
	var fallback: Dictionary = PerkFusionResultBuilder.build_result(
		_context([protected_last_option]),
		{"outcome": 0.60, "magnitude": [0.5], "lane_selection": [0.0], "delete": 0.0}
	)
	_expect(_as_dict(fallback.get("deleted_options", {})).is_empty(), "last remaining option should never be deleted")
	_expect(not _as_dict(fallback.get("option_penalties", {})).is_empty(), "ineligible delete should fall back to a value penalty")


func _verify_zero_pool_distribution_and_token_consumption() -> void:
	var context: Dictionary = _context([_lane("source_a", "power", 100.0, "forward", "float")])
	context["available_byproducts"] = ["owned", "limit_break", "owned"]
	context["owned_byproducts"] = ["owned"]
	context["dual_catalyst_armed"] = true
	var result: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.80, "magnitude": [0.0], "lane_selection": [0.0], "delete": 1.0}
	)
	var weights: Dictionary = _as_dict(result.get("weights", {}))
	var consumption: Dictionary = _as_dict(result.get("token_consumption", {}))
	_expect_float(float(weights.get("success", 0.0)), 75.0, "empty byproduct pool should move byproduct weight to success")
	_expect_float(float(weights.get("side_effect", 0.0)), 25.0, "empty byproduct pool should preserve side-effect weight")
	_expect_float(float(weights.get("byproduct", -1.0)), 0.0, "empty byproduct pool should have no byproduct bucket")
	_expect(str(result.get("raw_outcome", "")) == "side_effect", "80-percent empty-pool roll should resolve against 75/25/0")
	_expect(not bool(consumption.get("dual_catalyst", true)), "dual catalyst should wait for a byproduct-capable fusion")
	_expect(_raw_outcome_at(0.749999, false, true) == "success", "empty-pool roll below 75 percent should resolve to success")
	_expect(_raw_outcome_at(0.75, false, true) == "side_effect", "empty-pool 75-percent boundary should resolve to side effect")
	_expect(_raw_outcome_at(1.0, false, true) == "side_effect", "empty-pool final bucket should remain side effect")


func _verify_dual_catalyst_distribution() -> void:
	var context: Dictionary = _context([])
	context["available_byproducts"] = ["reverb"]
	context["dual_catalyst_armed"] = true
	var result: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.70, "byproduct_count": 0.0, "byproduct_selection": [0.0]}
	)
	var weights: Dictionary = _as_dict(result.get("weights", {}))
	var consumption: Dictionary = _as_dict(result.get("token_consumption", {}))
	_expect_float(float(weights.get("success", 0.0)), 40.0, "dual catalyst should transfer 15 points out of success")
	_expect_float(float(weights.get("side_effect", 0.0)), 25.0, "dual catalyst should preserve side-effect weight")
	_expect_float(float(weights.get("byproduct", 0.0)), 35.0, "dual catalyst should transfer 15 points into byproduct")
	_expect(str(result.get("outcome", "")) == "byproduct", "70-percent dual-catalyst roll should grant a byproduct")
	_expect(bool(consumption.get("dual_catalyst", false)), "byproduct-capable fusion should consume the armed dual catalyst")


func _verify_core_stabilization() -> void:
	var context: Dictionary = _context([_lane("source_a", "power", 100.0, "forward", "float")])
	context["core_stabilize_armed"] = true
	var result: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.60, "magnitude": [0.5], "lane_selection": [0.0], "delete": 1.0}
	)
	var consumption: Dictionary = _as_dict(result.get("token_consumption", {}))
	_expect(str(result.get("raw_outcome", "")) == "side_effect", "core stabilization should preserve the raw side-effect result")
	_expect(str(result.get("outcome", "")) == "stable", "core stabilization should convert side effect to stable")
	_expect(_as_dict(result.get("option_penalties", {})).is_empty(), "stabilized result should not apply option penalties")
	_expect(bool(consumption.get("core_stabilize", false)), "armed core should always be consumed by the next fusion")
	var success_result: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.10}
	)
	_expect(str(success_result.get("outcome", "")) == "success", "core stabilization should not rewrite a success")
	_expect(
		bool(_as_dict(success_result.get("token_consumption", {})).get("core_stabilize", false)),
		"core stabilization should remain one-shot when the production roll succeeds"
	)


func _verify_owned_exclusion_and_count_clamp() -> void:
	var context: Dictionary = _context([])
	context["available_byproducts"] = ["reverb", "core_stabilize", "dual_catalyst", "static_field", "reverb"]
	context["owned_byproducts"] = ["reverb"]
	var result: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{
			"outcome": 0.90,
			"byproduct_count": 1.0,
			"byproduct_selection": [0.0, 0.0, 0.0],
		}
	)
	var byproducts: Array = _as_array(result.get("byproducts", []))
	_expect(byproducts.size() == 3, "byproduct count should clamp to three available unique rewards")
	var unique_byproducts: Dictionary = {}
	for byproduct_value: Variant in byproducts:
		unique_byproducts[str(byproduct_value)] = true
	_expect(unique_byproducts.size() == byproducts.size(), "production byproduct selection must be without replacement")
	_expect(not byproducts.has("reverb"), "owned byproduct should be excluded before selection")
	_expect(byproducts.has("core_stabilize") and byproducts.has("dual_catalyst"), "new tokens should be recorded as current rewards")
	_expect(not bool(_as_dict(result.get("token_consumption", {})).get("core_stabilize", false)), "core acquired now must not affect the current fusion")
	_expect(not bool(_as_dict(result.get("token_consumption", {})).get("dual_catalyst", false)), "dual catalyst acquired now must not affect the current fusion")


func _verify_limit_break_payload() -> void:
	var context: Dictionary = _context([])
	context["available_byproducts"] = ["limit_break"]
	context["limit_break_eligible_sources"] = ["source_b", "outside", "source_a", "source_b"]
	var result: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.90, "byproduct_count": 0.0, "byproduct_selection": [0.0]}
	)
	var payloads: Dictionary = _as_dict(result.get("byproduct_payloads", {}))
	var payload: Dictionary = _as_dict(payloads.get("limit_break", {}))
	_expect(_as_array(result.get("byproducts", [])) == ["limit_break"], "eligible limit break should remain in the pool")
	_expect(_as_array(payload.get("eligible_sources", [])) == ["source_a", "source_b"], "limit-break payload should contain only sorted eligible fusion sources")


func _verify_rare_slot_policy() -> void:
	var context: Dictionary = _context([])
	context["available_byproducts"] = [
		"overload_circuit", "reverb", "golden_trajectory", "static_field", "recycle_protocol",
		"core_stabilize", "limit_break", "dual_catalyst",
	]
	context["limit_break_eligible_sources"] = ["source_a"]
	var one: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.90, "byproduct_count": 0.0, "byproduct_selection": [0.0]}
	)
	_expect(_as_array(one.get("byproducts", [])) == ["overload_circuit"], "one-reward rolls should stay in the general pool while it has entries")
	var three: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.90, "byproduct_count": 1.0, "byproduct_selection": [0.0, 0.0, 0.0]}
	)
	_expect(
		_as_array(three.get("byproducts", [])) == ["overload_circuit", "reverb", "core_stabilize"],
		"three-reward rolls should reserve the final slot for one rare byproduct"
	)
	var rare_only: Dictionary = context.duplicate(true)
	rare_only["available_byproducts"] = ["core_stabilize", "dual_catalyst"]
	var fallback: Dictionary = PerkFusionResultBuilder.build_result(
		rare_only,
		{"outcome": 0.90, "byproduct_count": 0.4, "byproduct_selection": [0.0, 0.0]}
	)
	_expect(_as_array(fallback.get("byproducts", [])).size() == 2, "an empty general pool should fill ordinary slots from the remaining rare pool")


func _raw_outcome_at(
	roll_unit: float,
	dual_catalyst_armed: bool = false,
	byproduct_pool_is_empty: bool = false
) -> String:
	var context: Dictionary = _context([
		_lane("source_a", "power", 100.0, "forward", "float"),
	])
	context["dual_catalyst_armed"] = dual_catalyst_armed
	if byproduct_pool_is_empty:
		context["available_byproducts"] = []
	var result: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{
			"outcome": roll_unit,
			"magnitude": [0.5],
			"lane_selection": [0.0],
			"delete": 1.0,
			"byproduct_count": 0.0,
			"byproduct_selection": [0.0],
		}
	)
	return str(result.get("raw_outcome", ""))


func _context(penalty_lanes: Array) -> Dictionary:
	return {
		"source_ids": ["source_a", "source_b"],
		"penalty_lanes": penalty_lanes.duplicate(true),
		"available_byproducts": ["reverb"],
		"owned_byproducts": [],
		"limit_break_eligible_sources": [],
		"core_stabilize_armed": false,
		"dual_catalyst_armed": false,
	}


func _lane(
	perk_id: String,
	option_key: String,
	value: Variant,
	polarity: String,
	value_kind: String,
	is_boolean: bool = false
) -> Dictionary:
	return {
		"perk_id": perk_id,
		"key": option_key,
		"value": value,
		"polarity": polarity,
		"value_kind": value_kind,
		"is_boolean": is_boolean,
		"remaining_option_count": 1,
	}


func _penalty(option_penalties: Dictionary, perk_id: String, option_key: String) -> Dictionary:
	return _as_dict(_as_dict(option_penalties.get(perk_id, {})).get(option_key, {}))


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value as Array
	return []


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s (actual=%s, expected=%s)" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
