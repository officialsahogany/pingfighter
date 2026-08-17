extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MysticDiceOfferPlanner := preload("res://scripts/characters/mystic_dice_offer_planner.gd")
const MysticDiceRoller := preload("res://scripts/characters/mystic_dice_roller.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkDebugGrants := preload("res://scripts/characters/runtime_perk_debug_grants.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class InjectedRollMysticDicePlanner:
	extends RefCounted

	var injected_roll_unit := 0.0
	var plan_calls := 0
	var _delegate: Object = MysticDiceOfferPlanner.new()

	func _init(next_roll_unit: float) -> void:
		injected_roll_unit = next_roll_unit

	func can_roll(choices: Array, offer_source: String, remaining_uses: int) -> bool:
		return bool(_delegate.can_roll(choices, offer_source, remaining_uses))

	func plan_offer(
		choices: Array,
		offer_source: String,
		remaining_uses: int,
		_runtime_roll_unit: float
	) -> Dictionary:
		plan_calls += 1
		return _delegate.plan_offer(
			choices,
			offer_source,
			remaining_uses,
			injected_roll_unit
		)


func _init() -> void:
	var original_language := LanguageSettings.get_language()
	_verify_retired_to_active_item_contract()
	LanguageSettings.set_test_locale_override(original_language)

	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("mystic_dice_offer_rotation_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_retired_to_active_item_contract() -> void:
	_expect(
		not MysticDiceOfferPlanner.OFFER_ROTATION_ENABLED,
		"the former perk rotation must be disabled by an explicit gate"
	)
	var legacy_plan: Dictionary = MysticDiceOfferPlanner.new().plan_offer(
		[_protected_choice("ordinary", "replaceable")],
		MysticDiceOfferPlanner.OFFER_SOURCE_BATTLE_STARPOINT,
		3,
		0.0
	)
	_expect(
		not bool(legacy_plan.get("rolled", true)) and not bool(legacy_plan.get("appeared", true)),
		"positive legacy use counts must not resurrect the retired perk offer"
	)
	var state := RuntimePerkState.new()
	state.current_choices = [_protected_choice("ordinary", "replaceable")]
	var before: Array = state.current_choices.duplicate(true)
	var result: Dictionary = state._try_inject_mystic_dice_offer(0.0)
	_expect(not bool(result.get("rolled", true)), "retired Mystic Dice perk seam must never roll")
	_expect(bool(result.get("retired_to_active_item", false)), "retired seam should identify the active-item migration")
	_expect(state.current_choices == before, "retired perk seam must preserve the offer")
	var debug_ids := _choice_ids(RuntimePerkCatalog.new().get_debug_perk_entries())
	_expect("mystic_dice" not in debug_ids, "perk debug picker must no longer expose Mystic Dice")
	var open_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_open_flow.gd")
	_expect(not open_flow_source.contains("CALLBACK_INJECT_MYSTIC_DICE_OFFER"), "production offer opening must not own a Mystic Dice callback")


func _verify_offer_source_allowlist_and_chance_boundaries() -> void:
	var planner := MysticDiceOfferPlanner.new()
	var choices: Array = [_protected_choice("normal", "replaceable"), _gold_choice()]
	for allowed_source: String in [
		MysticDiceOfferPlanner.OFFER_SOURCE_BATTLE_STARPOINT,
		MysticDiceOfferPlanner.OFFER_SOURCE_RESULT_BOX_STARPOINT_CHOICE,
	]:
		var allowed: Dictionary = planner.plan_offer(choices, allowed_source, 3, 0.0)
		_expect(bool(allowed.get("rolled", false)), "%s should consume one appearance roll" % allowed_source)
		_expect(bool(allowed.get("appeared", false)), "%s should permit Mystic Dice" % allowed_source)

	for denied_source: String in ["", "plaza_academy", "unknown", "mythic", "fixed", "tutorial", "debug"]:
		var denied: Dictionary = planner.plan_offer(choices, denied_source, 3, 0.0)
		_expect(not bool(denied.get("rolled", true)), "%s should fail closed before rolling" % denied_source)
		_expect(_choice_ids(_result_choices(denied)) == ["normal", "convert_to_gold"], "denied source should preserve the offer")

	var below_boundary := planner.plan_offer(choices, "battle_starpoint", 3, 0.249999)
	var exact_boundary := planner.plan_offer(choices, "battle_starpoint", 3, 0.25)
	_expect(bool(below_boundary.get("appeared", false)), "appearance rolls below 0.25 should append Mystic Dice")
	_expect(bool(exact_boundary.get("rolled", false)), "the exact chance boundary should count as one roll")
	_expect(not bool(exact_boundary.get("appeared", true)), "the conventional roll < chance check should reject 0.25")


func _verify_append_lane_and_input_immutability() -> void:
	var planner := MysticDiceOfferPlanner.new()
	var choices: Array = [
		_protected_choice("ordinary", "replaceable", {"nested": {"value": 1}}),
		_protected_choice("perk_fusion", "fusion"),
		_protected_choice("dowsing_bonus", "dowsing"),
		_gold_choice({"nested": {"value": 7}}),
	]
	var original: Array = choices.duplicate(true)
	var result: Dictionary = planner.plan_offer(choices, "battle_starpoint", 3, 0.0)
	var planned: Array = _result_choices(result)
	_expect(planned.size() == choices.size() + 1, "rotation should append one auxiliary card")
	_expect(int(result.get("append_index", -1)) == 4, "rotation should append after every existing lane")
	_expect(_choice_ids(planned) == ["ordinary", "perk_fusion", "dowsing_bonus", "convert_to_gold", "mystic_dice"], "all existing lanes should remain untouched")
	_expect(choices == original, "planner must not mutate the input offer")
	var card: Dictionary = planned[4] as Dictionary
	_expect(bool(card.get("is_mystic_dice", false)), "appended card should carry the Mystic Dice type marker")
	_expect(bool(card.get("offer_protected", false)), "appended card should remain protected")
	_expect(str(card.get("offer_lane", "")) == "mystic_dice", "appended card should own a dedicated offer lane")
	_expect(not card.has("is_gold_conversion") and not card.has("gold_amount"), "fresh card data must not retain gold-only fields")
	_expect(not card.has("replaced_choice_snapshot"), "append-only cards should not retain a replacement snapshot")

	var no_gold := planner.plan_offer([_protected_choice("ordinary", "replaceable")], "battle_starpoint", 3, 0.0)
	_expect(bool(no_gold.get("appeared", false)), "Mystic Dice should not depend on a gold lane")
	var exhausted := planner.plan_offer(choices, "battle_starpoint", 0, 0.0)
	_expect(not bool(exhausted.get("rolled", true)), "exhausted run cap should skip the appearance roll")
	_expect(_choice_ids(_result_choices(exhausted)) == _choice_ids(choices), "exhausted cap should preserve every base card")


func _verify_runtime_postprocessor_and_use_cap() -> void:
	var state := RuntimePerkState.new()
	state.choice_active = true
	state.current_choice_context = {"source": "battle_starpoint"}
	state.current_choices = [
		_protected_choice("perk_fusion", "fusion"),
		_gold_choice(),
	]
	var result: Dictionary = state._try_inject_mystic_dice_offer(0.0)
	_expect(bool(result.get("appeared", false)), "runtime postprocessor should inject a forced Mystic Dice offer")
	_expect(_choice_ids(state.current_choices) == ["perk_fusion", "convert_to_gold", "mystic_dice"], "runtime postprocessor should append after fusion and gold")
	var repeated: Dictionary = state._try_inject_mystic_dice_offer(0.0)
	_expect(not bool(repeated.get("rolled", true)), "same offer should not reroll after its Dice lane was appended")

	var academy_state := RuntimePerkState.new()
	academy_state.choice_active = true
	academy_state.current_choice_context = {"source": "plaza_academy"}
	academy_state.current_choices = [_gold_choice()]
	var academy_result: Dictionary = academy_state._try_inject_mystic_dice_offer(0.0)
	_expect(not bool(academy_result.get("rolled", true)), "academy offer should fail closed before rolling")
	_expect(_choice_ids(academy_state.current_choices) == ["convert_to_gold"], "academy should always retain gold conversion")

	var capped_state := RuntimePerkState.new()
	var best_raw: Dictionary = MysticDiceRoller.new().roll(_repeated_units(1.0)).get("raw", {}) as Dictionary
	for _use_index: int in range(3):
		capped_state.commit_mystic_dice_roll(best_raw)
	capped_state.choice_active = true
	capped_state.current_choice_context = {"source": "result_box_starpoint_choice"}
	capped_state.current_choices = [_gold_choice()]
	var capped_result: Dictionary = capped_state._try_inject_mystic_dice_offer(0.0)
	_expect(not bool(capped_result.get("rolled", true)), "three committed uses should suppress future appearance rolls")
	_expect(_choice_ids(capped_state.current_choices) == ["convert_to_gold"], "run-cap exhaustion should preserve result-box gold")


# 부적격 오퍼 RNG 무소비 씰: rolled=false 경로가 전역 난수열을 한 번도
# 전진시키지 않아야 이후 보상 난수 결과가 교란되지 않는다(seed 재현으로
# 다음 randf()가 정확히 일치함을 단언).
func _verify_ineligible_offers_consume_no_rng() -> void:
	var probes: Array = []
	var academy_state := RuntimePerkState.new()
	academy_state.choice_active = true
	academy_state.current_choice_context = {"source": "plaza_academy"}
	academy_state.current_choices = [_gold_choice()]
	probes.append({"state": academy_state, "label": "denied source"})
	var empty_offer_state := RuntimePerkState.new()
	empty_offer_state.choice_active = true
	empty_offer_state.current_choice_context = {"source": "battle_starpoint"}
	empty_offer_state.current_choices = []
	probes.append({"state": empty_offer_state, "label": "empty base offer"})
	var capped_state := RuntimePerkState.new()
	var best_raw: Dictionary = MysticDiceRoller.new().roll(_repeated_units(1.0)).get("raw", {}) as Dictionary
	for _use_index: int in range(3):
		capped_state.commit_mystic_dice_roll(best_raw)
	capped_state.choice_active = true
	capped_state.current_choice_context = {"source": "battle_starpoint"}
	capped_state.current_choices = [_gold_choice()]
	probes.append({"state": capped_state, "label": "exhausted cap"})
	for probe_value: Variant in probes:
		var probe: Dictionary = probe_value
		var probe_state: Object = probe.get("state")
		seed(20260718)
		var expected_next := randf()
		seed(20260718)
		var denied: Dictionary = probe_state._try_inject_mystic_dice_offer()
		_expect(not bool(denied.get("rolled", true)), "%s should fail closed before rolling" % str(probe.get("label")))
		_expect(is_equal_approx(randf(), expected_next), "%s must not consume global RNG" % str(probe.get("label")))
	# 융합 인젝트도 동형 계약: 교체 가능 lane이 없는 all-protected 오퍼는
	# 재료 2종이 있어도 난수를 한 번도 소비하지 않는다(플래너 can_roll이
	# rolled=false 전 조건의 단일 소스).
	var fusion_state := RuntimePerkState.new()
	fusion_state.runtime_skill_levels = {"common_swiftness": 3, "common_bulk_up": 3}
	fusion_state.choice_active = true
	fusion_state.current_choice_context = {"source": "battle_starpoint"}
	fusion_state.current_choices = [
		_protected_choice("perk_fusion", "fusion"),
		_gold_choice(),
	]
	seed(20260719)
	var fusion_expected_next := randf()
	seed(20260719)
	var fusion_denied: Dictionary = fusion_state._try_inject_perk_fusion_offer(RuntimePerkCatalog.new())
	_expect(not bool(fusion_denied.get("rolled", true)), "all-protected fusion offer should fail closed before rolling")
	_expect(is_equal_approx(randf(), fusion_expected_next), "all-protected fusion offer must not consume global RNG")


func _verify_open_next_choice_producer_path() -> void:
	var state := RuntimePerkState.new()
	var planner := InjectedRollMysticDicePlanner.new(0.0)
	state._mystic_dice_offer_planner = planner
	state.pending_skill_choices = 1
	state.open_next_choice(
		"smasher",
		RuntimePerkCatalog.new(),
		true,
		null,
		null,
		null,
		{"source": MysticDiceOfferPlanner.OFFER_SOURCE_BATTLE_STARPOINT}
	)
	var opened_ids: Array[String] = _choice_ids(state.current_choices)
	_expect(state.choice_active, "open_next_choice producer should open the generated offer")
	_expect(planner.plan_calls == 1, "open_next_choice producer should invoke the Mystic Dice postprocessor exactly once")
	_expect("mystic_dice" in opened_ids, "open_next_choice producer should surface Mystic Dice for an allowlisted forced roll")
	_expect("convert_to_gold" not in opened_ids, "open_next_choice producer should not append the retired gold lane")
	_expect(str(state.current_choice_context.get("source", "")) == MysticDiceOfferPlanner.OFFER_SOURCE_BATTLE_STARPOINT, "open_next_choice producer should preserve the allowlisted source context")


func _verify_catalog_slot_debug_and_localization_contract() -> void:
	var catalog := RuntimePerkCatalog.new()
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var data: Dictionary = catalog.get_perk_data("mystic_dice")
	_expect(str(data.get("name", "")) == "팔자윷", "catalog resolver should expose the Korean base card")
	_expect(not RuntimePerkCatalog.is_slot_consuming_perk(data), "Mystic Dice must never consume a perk slot")
	_expect(not bool(data.get("is_gold_conversion", false)), "catalog resolver must not alias gold conversion metadata")

	var direct_choices: Array = catalog.get_choices("smasher", {}, false, 3)
	_expect(not "mystic_dice" in _choice_ids(direct_choices), "catalog get_choices must remain free of rotation logic")
	_expect(not "convert_to_gold" in _choice_ids(direct_choices), "catalog should not emit the retired gold-conversion lane")

	var debug_ids := _choice_ids(catalog.get_debug_perk_entries())
	_expect("mystic_dice" in debug_ids, "debug picker catalog should display Mystic Dice for inspection")
	var debug_path: Dictionary = RuntimePerkDebugGrants.new().build_path("mystic_dice", data)
	_expect(not bool(debug_path.get("accepted", true)), "direct debug grant must reject the modal-only choice")
	_expect(str(debug_path.get("blocked_reason", "")) == "modal_only_choice", "debug rejection should explain the modal-only contract")

	var expected_names := {
		LanguageSettings.LANGUAGE_KOREAN: "팔자윷",
		LanguageSettings.LANGUAGE_ENGLISH: "Fate Yut",
		LanguageSettings.LANGUAGE_CHINESE: "八字柶",
		LanguageSettings.LANGUAGE_JAPANESE: "八字ユッ",
		LanguageSettings.LANGUAGE_SPANISH: "Yut del Destino",
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: "Yut do Destino",
		LanguageSettings.LANGUAGE_RUSSIAN: "Ют судьбы",
	}
	for locale: String in expected_names.keys():
		LanguageSettings.set_test_locale_override(locale)
		var localized: Dictionary = catalog.get_perk_data("mystic_dice")
		_expect(str(localized.get("name", "")) == str(expected_names[locale]), "%s should localize the card name" % locale)
		_expect(not str(localized.get("description", "")).strip_edges().is_empty(), "%s should localize the card summary" % locale)


func _verify_production_source_and_postprocessor_order() -> void:
	var battle_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_starpoint_collection_flow.gd")
	var result_source := FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_starpoint_choice_open_data.gd")
	var academy_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_academy_transactions.gd")
	var open_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_open_flow.gd")
	_expect(battle_source.contains("{\"source\": \"battle_starpoint\"}"), "battle opener should stamp its allowlisted source")
	_expect(result_source.contains("\"source\": \"result_box_starpoint_choice\""), "result-box opener should stamp its allowlisted source")
	_expect(academy_source.contains("\"source\": \"plaza_academy\""), "academy opener should stamp its denied source")
	var fusion_index := open_flow_source.find("CALLBACK_INJECT_PERK_FUSION_OFFER")
	var dowsing_index := open_flow_source.find("build_dowsing_bonus_state_update", fusion_index)
	var dice_index := open_flow_source.find("CALLBACK_INJECT_MYSTIC_DICE_OFFER", dowsing_index)
	var training_index := open_flow_source.find("CALLBACK_INJECT_PHYSIQUE_TRAINING_OFFER", dice_index)
	var ready_index := open_flow_source.find("build_ready_state_update", training_index)
	_expect(fusion_index >= 0 and dowsing_index > fusion_index and dice_index > dowsing_index and training_index > dice_index and ready_index > training_index, "auxiliary lanes should finish in fusion/Dowsing/Dice/training order before ready")


func _gold_choice(extra: Dictionary = {}) -> Dictionary:
	var choice: Dictionary = extra.duplicate(true)
	choice["id"] = "convert_to_gold"
	choice["offer_lane"] = "gold"
	choice["offer_protected"] = true
	choice["is_gold_conversion"] = true
	choice["gold_amount"] = 500
	return choice


func _protected_choice(choice_id: String, lane: String, extra: Dictionary = {}) -> Dictionary:
	var choice: Dictionary = extra.duplicate(true)
	choice["id"] = choice_id
	choice["offer_lane"] = lane
	choice["offer_protected"] = true
	return choice


func _result_choices(result: Dictionary) -> Array:
	var value: Variant = result.get("choices", [])
	return value as Array if value is Array else []


func _choice_ids(choices: Array) -> Array[String]:
	var ids: Array[String] = []
	for choice_value: Variant in choices:
		if choice_value is Dictionary:
			ids.append(str((choice_value as Dictionary).get("id", "")))
	return ids


func _repeated_units(value: float) -> Array:
	var units: Array = []
	for _index: int in range(MysticDiceRoller.STAT_KEYS.size()):
		units.append(value)
	return units


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
