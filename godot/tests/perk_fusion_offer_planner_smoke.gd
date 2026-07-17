extends SceneTree

const PerkFusionOfferPlanner := preload("res://scripts/characters/perk_fusion_offer_planner.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_offer_source_allowlist()
	_verify_appearance_roll_boundaries()
	_verify_explicit_protection_markers()
	_verify_preconditions_skip_roll()
	_verify_replacement_payload_and_determinism()

	if _failures.is_empty():
		print("perk_fusion_offer_planner_smoke: ok")
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)


func _verify_offer_source_allowlist() -> void:
	var planner := PerkFusionOfferPlanner.new()
	var choices: Array = [_replaceable_choice("ordinary")]
	var candidates: Array = ["source_a", "source_b"]
	for allowed_source: String in [
		PerkFusionOfferPlanner.OFFER_SOURCE_BATTLE_STARPOINT,
		PerkFusionOfferPlanner.OFFER_SOURCE_RESULT_BOX_STARPOINT_CHOICE,
	]:
		var allowed_result: Dictionary = planner.plan_offer(choices, candidates, allowed_source, 0.0, 0.0)
		_expect(bool(allowed_result.get("rolled", false)), "%s should reach the appearance roll" % allowed_source)
		_expect(bool(allowed_result.get("appeared", false)), "%s should allow a fusion offer" % allowed_source)

	for denied_source: String in ["", "plaza_academy", "unknown", "mythic"]:
		var denied_result: Dictionary = planner.plan_offer(choices, candidates, denied_source, 0.0, 0.0)
		_expect(not bool(denied_result.get("rolled", true)), "%s should fail closed before rolling" % denied_source)
		_expect(_choice_ids(_result_choices(denied_result)) == ["ordinary"], "denied source should preserve choices")


func _verify_appearance_roll_boundaries() -> void:
	var planner := PerkFusionOfferPlanner.new()
	var choices: Array = [_replaceable_choice("ordinary")]
	var candidates: Array = ["source_a", "source_b"]
	var below_boundary: Dictionary = planner.plan_offer(choices, candidates, "battle_starpoint", 0.349999, 0.0)
	_expect(bool(below_boundary.get("rolled", false)), "valid prerequisites should consume an appearance roll")
	_expect(bool(below_boundary.get("appeared", false)), "rolls below 0.35 should appear")

	var exact_boundary: Dictionary = planner.plan_offer(choices, candidates, "battle_starpoint", 0.35, 0.0)
	_expect(bool(exact_boundary.get("rolled", false)), "the 0.35 boundary should still count as rolled")
	_expect(not bool(exact_boundary.get("appeared", true)), "the conventional roll < chance boundary should reject 0.35")
	_expect(_choice_ids(_result_choices(exact_boundary)) == ["ordinary"], "failed appearance roll should preserve choices")


func _verify_explicit_protection_markers() -> void:
	var planner := PerkFusionOfferPlanner.new()
	var protected_choices: Array = [
		_protected_choice("jackpot", "mythic"),
		_protected_choice("dash_amplification", "reserved"),
		_protected_choice("already_owned", "owned"),
		_protected_choice("lingpet_ring_core_upgrade", "ring"),
		_protected_choice("dowsing_bonus", "dowsing"),
		_protected_choice("convert_to_gold", "gold"),
	]
	var choices: Array = protected_choices.duplicate(true)
	choices.append(_replaceable_choice("ordinary", {"pending": false, "nested": {"value": 7}}))
	var result: Dictionary = planner.plan_offer(choices, ["source_a", "source_b"], "battle_starpoint", 0.0, 1.0)
	var planned: Array = _result_choices(result)
	_expect(planned.size() == choices.size(), "fusion offer should preserve choice count")
	for index: int in range(protected_choices.size()):
		_expect(planned[index] == protected_choices[index], "explicitly protected choice %d should remain unchanged" % index)
	_expect(str(_as_dict(planned[planned.size() - 1]).get("id", "")) == PerkFusionOfferPlanner.FUSION_CARD_ID, "only the replaceable lane should be replaced")

	var unmarked_result: Dictionary = planner.plan_offer(
		[{"id": "looks_ordinary_but_has_no_offer_metadata"}],
		["source_a", "source_b"],
		"battle_starpoint",
		0.0,
		0.0
	)
	_expect(not bool(unmarked_result.get("rolled", true)), "unmarked cards should fail closed instead of being inferred replaceable")


func _verify_preconditions_skip_roll() -> void:
	var planner := PerkFusionOfferPlanner.new()
	var all_protected: Array = [_protected_choice("gold", "gold"), _protected_choice("dowsing", "dowsing")]
	var no_lane_result: Dictionary = planner.plan_offer(all_protected, ["source_a", "source_b"], "battle_starpoint", 0.0, 0.0)
	_expect(not bool(no_lane_result.get("rolled", true)), "zero replaceable lanes should not consume an appearance roll")
	_expect(_result_choices(no_lane_result) == all_protected, "zero replaceable lanes should preserve all choices")

	for sources: Array in [[], ["source_a"], ["source_a", "source_a"], ["", "source_a"]]:
		var too_few_result: Dictionary = planner.plan_offer([_replaceable_choice("ordinary")], sources, "battle_starpoint", 0.0, 0.0)
		_expect(not bool(too_few_result.get("rolled", true)), "fewer than two unique candidates should not roll")


func _verify_replacement_payload_and_determinism() -> void:
	var planner := PerkFusionOfferPlanner.new()
	var first_choice: Dictionary = _replaceable_choice("first", {"nested": {"value": 1}})
	var protected_middle: Dictionary = _protected_choice("middle", "protected")
	var last_choice: Dictionary = _replaceable_choice("last", {"nested": {"value": 3}})
	var choices: Array = [first_choice, protected_middle, last_choice]
	var candidates: Array = ["source_b", "source_a", "source_b", ""]
	var first_result: Dictionary = planner.plan_offer(choices, candidates, "battle_starpoint", 0.0, 0.0)
	var last_result: Dictionary = planner.plan_offer(choices, candidates, "battle_starpoint", 0.0, 1.0)
	_expect(int(first_result.get("replacement_index", -1)) == 0, "replacement roll 0 should select the first replaceable lane")
	_expect(int(last_result.get("replacement_index", -1)) == 2, "replacement roll 1 should select the last replaceable lane")

	var planned: Array = _result_choices(last_result)
	var fusion_card: Dictionary = _as_dict(planned[2])
	_expect(_string_array(fusion_card.get("eligible_sources", [])) == ["source_a", "source_b"], "fusion card should carry sorted, de-duplicated eligible sources")
	_expect(_as_dict(fusion_card.get("replaced_choice_snapshot", {})) == last_choice, "fusion card should carry a deep replaced-choice snapshot")
	_expect(bool(fusion_card.get("offer_protected", false)), "fusion card should protect its own offer lane")
	_expect(str(fusion_card.get("offer_lane", "")) == PerkFusionOfferPlanner.OFFER_LANE_FUSION, "fusion card should identify its explicit offer lane")
	_expect(bool(fusion_card.get("is_perk_fusion", false)), "fusion card should carry the runtime type marker")
	_expect(int(fusion_card.get("icon_variant", -1)) == 4, "replacement roll 1 should deterministically select icon variant 4")
	_expect(str(fusion_card.get("icon_id", "")) == "perk_fusion_4", "fusion card should route its deterministic visual variant through an explicit icon id")
	_expect(fusion_card.has("name_key") and fusion_card.has("description_key"), "fusion card should carry localization-ready keys")
	_expect(_choice_ids(planned) == ["first", "middle", PerkFusionOfferPlanner.FUSION_CARD_ID], "replacement should preserve choice order")
	_expect(_choice_ids(choices) == ["first", "middle", "last"], "planner should not mutate the input choices")

	var snapshot: Dictionary = _as_dict(fusion_card.get("replaced_choice_snapshot", {}))
	_as_dict(snapshot.get("nested", {}))["value"] = 99
	_expect(int(_as_dict(last_choice.get("nested", {})).get("value", 0)) == 3, "replaced-choice payload should be a deep snapshot")


func _replaceable_choice(choice_id: String, extra: Dictionary = {}) -> Dictionary:
	var choice: Dictionary = extra.duplicate(true)
	choice["id"] = choice_id
	choice["offer_protected"] = false
	choice["offer_lane"] = PerkFusionOfferPlanner.OFFER_LANE_REPLACEABLE
	return choice


func _protected_choice(choice_id: String, lane: String) -> Dictionary:
	return {
		"id": choice_id,
		"offer_protected": true,
		"offer_lane": lane,
		"sentinel": "%s_preserved" % choice_id,
	}


func _result_choices(result: Dictionary) -> Array:
	var value: Variant = result.get("choices", [])
	if value is Array:
		return value as Array
	return []


func _choice_ids(choices: Array) -> Array[String]:
	var ids: Array[String] = []
	for choice_value: Variant in choices:
		ids.append(str(_as_dict(choice_value).get("id", "")))
	return ids


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			result.append(str(entry))
	return result


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
