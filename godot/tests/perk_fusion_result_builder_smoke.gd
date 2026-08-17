extends SceneTree

const PerkFusionResultBuilder := preload("res://scripts/characters/perk_fusion_result_builder.gd")
const PerkFusionByproductCatalog := preload("res://scripts/characters/perk_fusion_byproduct_catalog.gd")

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
	_verify_byproduct_count_boundaries()
	_verify_core_stabilization()
	_verify_owned_exclusion_and_count_clamp()
	_verify_rare_slot_policy()
	_verify_rare_id_table_matches_the_catalog()
	_verify_selection_rolls_address_every_slot()
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
	_expect(_raw_outcome_at(0.199999) == "success", "production roll below 20 percent should preserve the source options")
	_expect(_raw_outcome_at(0.20) == "side_effect", "production 20-percent boundary should enter qi deviation")
	_expect(_raw_outcome_at(0.299999) == "side_effect", "production roll below 30 percent should remain qi deviation")
	_expect(_raw_outcome_at(0.30) == "byproduct", "production 30-percent boundary should grant Superior Martial Arts")
	_expect(_raw_outcome_at(1.0) == "byproduct", "production one-unit roll should clamp to byproduct")

	_expect(_raw_outcome_at(0.049999, true) == "success", "production dual roll below 5 percent should preserve the source options")
	_expect(_raw_outcome_at(0.05, true) == "side_effect", "production dual 5-percent boundary should enter qi deviation")
	_expect(_raw_outcome_at(0.149999, true) == "side_effect", "production dual roll below 15 percent should remain qi deviation")
	_expect(_raw_outcome_at(0.15, true) == "byproduct", "production dual 15-percent boundary should grant Superior Martial Arts")


func _verify_float_penalties_and_unique_lane_selection() -> void:
	var result: Dictionary = PerkFusionResultBuilder.build_result(
		_context([
			_lane("source_a", "power", 100.0, "forward", "float"),
			_lane("source_b", "speed", 50.0, "forward", "float"),
		]),
		{
			"outcome": 0.25,
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
		{"outcome": 0.25, "magnitude": [0.5], "lane_selection": [0.0], "delete": 1.0}
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
		{"outcome": 0.25, "magnitude": [0.5], "lane_selection": [0.0], "delete": 0.0}
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
		{"outcome": 0.25, "magnitude": [0.0], "lane_selection": [0.0], "delete": 1.0}
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
		{"outcome": 0.25, "magnitude": [0.0], "lane_selection": [0.0], "delete": 1.0}
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
		{"outcome": 0.25, "lane_selection": [0.0], "delete": 0.199999}
	)
	var deleted: Dictionary = _as_dict(result.get("deleted_options", {}))
	_expect(_as_array(deleted.get("source_a", [])) == ["option_a"], "delete branch should mark one option when its source retains another")
	_expect(_as_dict(result.get("option_penalties", {})).is_empty(), "delete branch should not also apply the 80-percent reduction branch")
	_expect(str(_as_dict(lanes[0]).get("key", "")) == "option_a", "builder should not remove or mutate the input option")

	var protected_last_option: Dictionary = _lane("source_a", "only_option", 10.0, "forward", "float")
	protected_last_option["remaining_option_count"] = 1
	var fallback: Dictionary = PerkFusionResultBuilder.build_result(
		_context([protected_last_option]),
		{"outcome": 0.25, "magnitude": [0.5], "lane_selection": [0.0], "delete": 0.0}
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
		{"outcome": 0.95, "magnitude": [0.0], "lane_selection": [0.0], "delete": 1.0}
	)
	var weights: Dictionary = _as_dict(result.get("weights", {}))
	var consumption: Dictionary = _as_dict(result.get("token_consumption", {}))
	_expect_float(float(weights.get("success", 0.0)), 90.0, "empty byproduct pool should move Superior Martial Art weight to preservation")
	_expect_float(float(weights.get("side_effect", 0.0)), 10.0, "empty byproduct pool should preserve qi-deviation weight")
	_expect_float(float(weights.get("byproduct", -1.0)), 0.0, "empty byproduct pool should have no byproduct bucket")
	_expect(str(result.get("raw_outcome", "")) == "side_effect", "95-percent empty-pool roll should resolve against 90/10/0")
	_expect(not bool(consumption.get("dual_catalyst", true)), "dual catalyst should wait for a byproduct-capable fusion")
	_expect(_raw_outcome_at(0.899999, false, true) == "success", "empty-pool roll below 90 percent should preserve the source options")
	_expect(_raw_outcome_at(0.90, false, true) == "side_effect", "empty-pool 90-percent boundary should resolve to qi deviation")
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
	_expect_float(float(weights.get("success", 0.0)), 5.0, "dual catalyst should transfer 15 points out of preservation")
	_expect_float(float(weights.get("side_effect", 0.0)), 10.0, "dual catalyst should preserve qi-deviation weight")
	_expect_float(float(weights.get("byproduct", 0.0)), 85.0, "dual catalyst should transfer 15 points into Superior Martial Arts")
	_expect(str(result.get("outcome", "")) == "byproduct", "70-percent dual-catalyst roll should grant a byproduct")
	_expect(bool(consumption.get("dual_catalyst", false)), "byproduct-capable fusion should consume the armed dual catalyst")


func _verify_byproduct_count_boundaries() -> void:
	_expect(_byproduct_count_at(0.0) == 1, "zero count roll should grant one Superior Martial Art")
	_expect(_byproduct_count_at(4.0 / 7.0 - 0.000001) == 1, "count roll below four-sevenths should grant one Superior Martial Art")
	_expect(_byproduct_count_at(4.0 / 7.0) == 2, "four-sevenths boundary should grant two Superior Martial Arts")
	_expect(_byproduct_count_at(6.0 / 7.0 - 0.000001) == 2, "count roll below six-sevenths should grant two Superior Martial Arts")
	_expect(_byproduct_count_at(6.0 / 7.0) == 3, "six-sevenths boundary should grant three Superior Martial Arts")
	_expect(_byproduct_count_at(1.0) == 3, "one-unit count roll should clamp to three Superior Martial Arts")


func _verify_core_stabilization() -> void:
	var context: Dictionary = _context([_lane("source_a", "power", 100.0, "forward", "float")])
	context["core_stabilize_armed"] = true
	var result: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.25, "magnitude": [0.5], "lane_selection": [0.0], "delete": 1.0}
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


# 빌더의 RARE_BYPRODUCT_IDS는 카탈로그 RARE_IDS의 손수 관리 사본이다. 카탈로그에
# 희귀를 추가하고 이 표를 잊으면 신규 희귀가 조용히 일반 슬롯에서만 나온다 —
# 오류도 경고도 없다. 두 정본이 갈라지는 순간을 잡는다.
func _verify_rare_id_table_matches_the_catalog() -> void:
	var catalog_rare: Array[String] = []
	for value: Variant in PerkFusionByproductCatalog.RARE_IDS:
		catalog_rare.append(str(value))
	catalog_rare.sort()
	var builder_rare: Array[String] = []
	for key_value: Variant in PerkFusionResultBuilder.RARE_BYPRODUCT_IDS.keys():
		if bool(PerkFusionResultBuilder.RARE_BYPRODUCT_IDS.get(key_value, false)):
			builder_rare.append(str(key_value))
	builder_rare.sort()
	_expect(
		builder_rare == catalog_rare,
		"the builder rare table must stay in lockstep with the catalog rare pool (builder=%s catalog=%s)" % [builder_rare, catalog_rare]
	)
	var catalog := PerkFusionByproductCatalog.new()
	for byproduct_id: String in builder_rare:
		_expect(
			str(catalog.get_data(byproduct_id).get("rarity", "")) == "rare",
			"builder rare id %s must carry rarity \"rare\" in the catalog" % byproduct_id
		)


# 라이브 시드가 슬롯 수보다 적은 selection roll을 공급하면 남는 슬롯이 roll 0.0으로
# 폴백해 후보 목록의 첫 항목에 고정된다(+3 희귀 슬롯이 항상 같은 희귀로 굳던 실제
# 회귀). 소스 문자열이 아니라 결과로 봉인한다 — 서로 다른 roll은 서로 다른 후보를
# 고르고, 3번째 roll이 실제로 희귀 슬롯을 주소지정해야 한다.
func _verify_selection_rolls_address_every_slot() -> void:
	var context: Dictionary = _context([])
	context["available_byproducts"] = [
		"overload_circuit", "reverb", "golden_trajectory",
		"core_stabilize", "limit_break", "dual_catalyst",
	]
	context["limit_break_eligible_sources"] = ["source_a"]
	var first: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.90, "byproduct_count": 1.0, "byproduct_selection": [0.0, 0.0, 0.0]}
	)
	var last: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.90, "byproduct_count": 1.0, "byproduct_selection": [0.0, 0.0, 0.99]}
	)
	var first_ids: Array = _as_array(first.get("byproducts", []))
	var last_ids: Array = _as_array(last.get("byproducts", []))
	_expect(first_ids.size() == 3 and last_ids.size() == 3, "both three-reward fixtures should grant three arts")
	_expect(
		first_ids.size() == 3 and last_ids.size() == 3 and first_ids[2] != last_ids[2],
		"the third selection roll must actually address the rare slot instead of pinning it to the first candidate"
	)
	_expect(
		first_ids.size() == 3 and last_ids.size() == 3 and first_ids.slice(0, 2) == last_ids.slice(0, 2),
		"changing only the third selection roll must not disturb the two general slots"
	)
	var short_rolls: Dictionary = {
		"outcome": 0.90,
		"byproduct_count": 1.0,
		"byproduct_selection": [0.0, 0.0],
	}
	var short_result: Array = _as_array(
		PerkFusionResultBuilder.build_result(context, short_rolls).get("byproducts", [])
	)
	_expect(
		short_result.size() == 3 and str(short_result[2]) == str(first_ids[2] if first_ids.size() == 3 else ""),
		"a seed short one roll silently pins the last slot to the roll-0.0 candidate — the live seed must supply one roll per slot"
	)


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
		"overload_circuit", "reverb", "golden_trajectory", "static_field", "recycle_protocol", "meridian_expand", "gravitybelt", "smartphone",
		"core_stabilize", "limit_break", "dual_catalyst", "linked_arsenal", "returning_light_step", "spellbreaker_guard",
	]
	_expect(not bool(PerkFusionResultBuilder.RARE_BYPRODUCT_IDS.get("meridian_expand", false)), "meridian expansion must not enter the count-3-only rare slot")
	_expect(not bool(PerkFusionResultBuilder.RARE_BYPRODUCT_IDS.get("gravitybelt", false)), "Instant Shadow Art must enter the general pool")
	_expect(not bool(PerkFusionResultBuilder.RARE_BYPRODUCT_IDS.get("smartphone", false)), "Adaptive Art must enter the general pool")
	_expect(bool(PerkFusionResultBuilder.RARE_BYPRODUCT_IDS.get("linked_arsenal", false)), "Linked Arsenal must reserve the count-3 rare slot")
	_expect(bool(PerkFusionResultBuilder.RARE_BYPRODUCT_IDS.get("returning_light_step", false)), "Last-Light Phantom Step must reserve the count-3 rare slot")
	_expect(bool(PerkFusionResultBuilder.RARE_BYPRODUCT_IDS.get("spellbreaker_guard", false)), "Spellbreaking Guard Art must reserve the count-3 rare slot")
	context["limit_break_eligible_sources"] = ["source_a"]
	_expect(is_equal_approx(float(PerkFusionResultBuilder.RARE_SLOT_CHANCE_BY_COUNT.get(1, 0.0)), 0.15), "one-reward rolls should carry a 15% rare-slot promotion chance")
	_expect(is_equal_approx(float(PerkFusionResultBuilder.RARE_SLOT_CHANCE_BY_COUNT.get(2, 0.0)), 0.25), "two-reward rolls should carry a 25% rare-slot promotion chance")
	var one: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.90, "byproduct_count": 0.0, "byproduct_selection": [0.0], "rare_slot": 1.0}
	)
	_expect(_as_array(one.get("byproducts", [])) == ["overload_circuit"], "a failed rare promotion roll should keep one-reward rolls in the general pool")
	var one_missing_roll: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.90, "byproduct_count": 0.0, "byproduct_selection": [0.0]}
	)
	_expect(_as_array(one_missing_roll.get("byproducts", [])) == ["overload_circuit"], "a missing rare_slot roll must fail closed to the general pool")
	var one_boundary: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.90, "byproduct_count": 0.0, "byproduct_selection": [0.0], "rare_slot": 0.15}
	)
	_expect(_as_array(one_boundary.get("byproducts", [])) == ["overload_circuit"], "a rare_slot roll exactly at the 15% boundary should stay general")
	var one_rare: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.90, "byproduct_count": 0.0, "byproduct_selection": [0.0], "rare_slot": 0.0}
	)
	_expect(_as_array(one_rare.get("byproducts", [])) == ["core_stabilize"], "a winning rare promotion roll should grant a rare on a one-reward roll")
	var two_rare: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.90, "byproduct_count": 0.7, "byproduct_selection": [0.0, 0.0], "rare_slot": 0.24}
	)
	_expect(
		_as_array(two_rare.get("byproducts", [])) == ["overload_circuit", "core_stabilize"],
		"a winning rare promotion roll should convert only the final slot of a two-reward roll"
	)
	var two_general: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.90, "byproduct_count": 0.7, "byproduct_selection": [0.0, 0.0], "rare_slot": 0.25}
	)
	_expect(
		_as_array(two_general.get("byproducts", [])) == ["overload_circuit", "reverb"],
		"a failed rare promotion roll should keep two-reward rolls fully general"
	)
	var three: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{"outcome": 0.90, "byproduct_count": 1.0, "byproduct_selection": [0.0, 0.0, 0.0], "rare_slot": 1.0}
	)
	_expect(
		_as_array(three.get("byproducts", [])) == ["overload_circuit", "reverb", "core_stabilize"],
		"three-reward rolls should keep the guaranteed final rare slot regardless of the promotion roll"
	)
	var live_seed_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_fusion_runtime_state.gd")
	_expect(live_seed_source.contains("\"rare_slot\": randf()"), "the live commit seed must supply the rare-slot promotion roll")
	_expect(live_seed_source.contains("\"byproduct_selection\": [randf(), randf(), randf()]"), "the live commit seed must supply one selection roll per possible slot")
	var rare_only: Dictionary = context.duplicate(true)
	rare_only["available_byproducts"] = ["core_stabilize", "dual_catalyst"]
	var fallback: Dictionary = PerkFusionResultBuilder.build_result(
		rare_only,
		{"outcome": 0.90, "byproduct_count": 1.0, "byproduct_selection": [0.0, 0.0]}
	)
	_expect(_as_array(fallback.get("byproducts", [])).size() == 2, "an unavailable three-art roll should fold into the remaining two-reward pool")


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


func _byproduct_count_at(roll_unit: float) -> int:
	var context: Dictionary = _context([])
	context["available_byproducts"] = ["overload_circuit", "reverb", "golden_trajectory"]
	var result: Dictionary = PerkFusionResultBuilder.build_result(
		context,
		{
			"outcome": 0.90,
			"byproduct_count": roll_unit,
			"byproduct_selection": [0.0, 0.0, 0.0],
		}
	)
	return _as_array(result.get("byproducts", [])).size()


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
