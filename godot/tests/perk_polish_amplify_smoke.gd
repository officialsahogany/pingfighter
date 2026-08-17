extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkOverflowDescriptions := preload("res://scripts/characters/runtime_perk_overflow_descriptions.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []


func _init() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	PerkConversionFlags.debug_set_enabled(false)
	_verify_catalog_wording()
	_verify_amplifiable_set_contract()
	_verify_flag_on_common_dash_amplify()
	_verify_exclusions()
	_verify_effective_level_and_polish_stack()
	_verify_polish_delta_display_surfaces()
	_verify_zero_level_noop()
	_verify_all_converted_numeric_values_amplify()
	_verify_flag_off_legacy_roll_and_bonus_paths()
	PerkConversionFlags.debug_set_enabled(false)
	LanguageSettings.set_test_locale_override("")
	if not _failures.is_empty():
		quit(1)
		return
	print("perk_polish_amplify_smoke: ok")
	quit(0)


func _verify_catalog_wording() -> void:
	var catalog := RuntimePerkCatalog.new()
	var data: Dictionary = catalog.get_perk_data("item_polish")
	_expect(not data.is_empty(), "item_polish should stay registered")
	var descriptions: Dictionary = data.get("descriptions", {})
	_expect(str(descriptions.get(1, "")).find("5%") >= 0, "Lv.1 Polish text should describe 5% amplify")
	_expect(str(descriptions.get(5, "")).find("25%") >= 0, "Lv.5 Polish text should describe 25% amplify")
	_expect(str(data.get("detail", "")).find("모든 일반 성장형 무공") >= 0, "Polish detail should cover every scalable general growth Mugong")
	_expect(str(data.get("detail", "")).find("구조값") >= 0, "Polish detail should explain the structural-value exception")


func _verify_amplifiable_set_contract() -> void:
	var amplifiable_ids: Dictionary = RuntimePerkState.PERK_POLISH_AMPLIFIABLE_BONUS_IDS
	var expected_ids := [
		"dash_lightweight",
		"dash_module_control",
		"dash_jump",
		"dash_acceleration",
		"dash_spirit",
		"item_luck",
		"item_cooldown_mastery",
		"item_gauge_mastery",
		"item_caffeine",
		"common_swiftness",
		"common_bulk_up",
		"training_mastery",
		"common_training",
		"perk_boost_charge",
	]
	_expect(amplifiable_ids.size() == expected_ids.size(), "amplifiable set should contain every current scalable Mugong id")
	for id_value in expected_ids:
		_expect(bool(amplifiable_ids.get(str(id_value), false)), "P1 amplifiable set should include %s" % str(id_value))
	var excluded_ids := [
		"common_expansion",
		"dash_amplification",
		"perk_laurel_shield",
		"item_polish",
		"item_recycle",
	]
	for id_value in excluded_ids:
		_expect(not bool(amplifiable_ids.get(str(id_value), false)), "P1 amplifiable set should exclude %s" % str(id_value))


func _verify_flag_on_common_dash_amplify() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["item_polish"] = 3
	state.runtime_skill_levels["common_swiftness"] = 2
	state.runtime_skill_levels["dash_lightweight"] = 1
	_expect_close(state._get_perk_amplify_multiplier("common_swiftness"), 1.15, "Lv.3 Polish should expose a 1.15 common multiplier")
	_expect_close(state.get_runtime_skill_bonus("common_swiftness"), 0.12 * 1.15, "Lv.3 Polish should amplify common_swiftness")
	_expect_close(state.get_runtime_skill_bonus("dash_lightweight"), 0.12 * 1.15, "Lv.3 Polish should amplify dash_lightweight")


func _verify_exclusions() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["item_polish"] = 5
	state.runtime_skill_levels["common_expansion"] = 2
	state.runtime_skill_levels["dash_amplification"] = 3
	state.runtime_skill_levels["perk_laurel_shield"] = 4
	state.runtime_skill_levels["item_recycle"] = 2
	_expect_close(state.get_runtime_skill_bonus("item_polish"), 0.60, "Polish must not amplify itself")
	_expect_close(state.get_runtime_skill_bonus("common_expansion"), 0.0, "flag-ON Expansion should not expose the legacy accessory-slot bonus")
	_expect_close(state.get_runtime_skill_bonus("dash_amplification"), 3.0, "dash-token count should not be amplified")
	_expect_close(state.get_runtime_skill_bonus("perk_laurel_shield"), 4.0, "laurel leaf count should not be amplified")
	_expect_close(state.get_runtime_skill_bonus("item_recycle"), 0.14, "economy/preservation chance should not be amplified in P1")


func _verify_effective_level_and_polish_stack() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["item_polish"] = 5
	state.runtime_skill_levels["common_swiftness"] = 2
	_expect(state.set_item_perk_level_bonus(2), "test setup should set effective-level bonus")
	_expect(int(state.get_runtime_skill_level("common_swiftness")) == 4, "effective-level bonus should still raise the target perk level")
	_expect_close(state._get_perk_amplify_multiplier("common_swiftness"), 1.35, "Polish amplifier should keep scaling at effective Lv.7")
	_expect_close(state.get_runtime_skill_bonus("common_swiftness"), 0.24 * 1.35, "effective-level Polish should multiply the effective-level target output")


func _verify_polish_delta_display_surfaces() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var catalog := RuntimePerkCatalog.new()
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {
		"item_polish": 3,
		"common_swiftness": 2,
		"dash_acceleration": 1,
		"item_gauge_mastery": 1,
	}
	_expect_close(state.get_perk_amplify_multiplier("common_swiftness"), 1.15, "public Polish multiplier should match the gameplay multiplier")
	_expect(state.has_method("get_runtime_skill_bonus_before_fusion"), "runtime should expose the canonical pre-fusion bonus facade")
	_expect_close(state.get_runtime_skill_bonus_before_fusion("common_swiftness"), 0.12 * 1.15, "pre-fusion facade should retain the live Polish multiplier")

	var swiftness: Dictionary = catalog.get_perk_data("common_swiftness")
	var swiftness_text: String = RuntimePerkOverflowDescriptions.resolve_stats_text_with_polish(
		"common_swiftness",
		swiftness.get("descriptions", {}),
		2,
		state
	)
	_expect(swiftness_text == "이동속도 12% (+1.8%) 증가", "Polish delta should annotate the exact swiftness gain: %s" % swiftness_text)
	var swiftness_status_text: String = RuntimePerkOverflowDescriptions.append_polish_status(
		swiftness_text,
		"common_swiftness",
		state
	)
	_expect(
		swiftness_status_text == "이동속도 12% (+1.8%) 증가, 개광결 +15% 적용",
		"owned Mugong tooltip should name the live Polish multiplier: %s" % swiftness_status_text
	)

	var acceleration: Dictionary = catalog.get_perk_data("dash_acceleration")
	var acceleration_text: String = RuntimePerkOverflowDescriptions.resolve_stats_text_with_polish(
		"dash_acceleration",
		acceleration.get("descriptions", {}),
		1,
		state
	)
	_expect(
		acceleration_text == "활주시 몸집 세로 70% (+10.5%)·가로 10% (+1.5%) 증가",
		"Polish delta should annotate both dash-acceleration lanes: %s" % acceleration_text
	)

	var gauge: Dictionary = catalog.get_perk_data("item_gauge_mastery")
	var gauge_text: String = RuntimePerkOverflowDescriptions.resolve_stats_text_with_polish(
		"item_gauge_mastery",
		gauge.get("descriptions", {}),
		1,
		state
	)
	_expect(gauge_text == "액티브 사용시 기력 +15 (+2.25)", "unitless Polish delta should not invent a percent unit: %s" % gauge_text)

	var cap_state := RuntimePerkState.new()
	cap_state.runtime_skill_levels = {"item_polish": 5, "perk_boost_charge": 5}
	_expect(cap_state.set_item_perk_level_bonus(7), "test setup should raise Energy-Gathering Art to effective Lv.12")
	var boost_charge: Dictionary = catalog.get_perk_data("perk_boost_charge")
	var boost_charge_text: String = RuntimePerkOverflowDescriptions.resolve_stats_text_with_polish(
		"perk_boost_charge",
		boost_charge.get("descriptions", {}),
		12,
		cap_state
	)
	_expect(boost_charge_text.find("(+16%)") >= 0, "effective Lv.12 capped Polish delta should show only its realizable +16%%: %s" % boost_charge_text)
	_expect(boost_charge_text.find("(+50.4%)") < 0, "effective Lv.12 capped Polish delta must not expose the unclamped reconstructed gain: %s" % boost_charge_text)

	var excluded: Dictionary = catalog.get_perk_data("dash_amplification")
	var excluded_text: String = RuntimePerkOverflowDescriptions.resolve_stats_text_with_polish(
		"dash_amplification",
		excluded.get("descriptions", {}),
		1,
		state
	)
	_expect(excluded_text == "최대 활주 횟수 +1", "count perks excluded from Polish must not gain a delta suffix: %s" % excluded_text)
	var excluded_status_text: String = RuntimePerkOverflowDescriptions.append_polish_status(
		excluded_text,
		"dash_amplification",
		state
	)
	_expect(
		excluded_status_text == "최대 활주 횟수 +1, 개광결 미적용 · 대상 제외",
		"excluded count Mugong should explain why no Polish delta appears: %s" % excluded_status_text
	)

	var polish: Dictionary = catalog.get_perk_data("item_polish")
	var polish_text: String = RuntimePerkOverflowDescriptions.resolve_stats_text_with_polish(
		"item_polish",
		polish.get("descriptions", {}),
		3,
		state
	)
	var polish_status_text: String = RuntimePerkOverflowDescriptions.append_polish_status(
		polish_text,
		"item_polish",
		state
	)
	_expect(
		polish_status_text == "모든 일반 성장형 무공의 수치 능력치 15% 증폭, 현재 적용 대상 3개",
		"Polish tooltip should summarize the number of currently affected Mugong: %s" % polish_status_text
	)
	var excluded_only_state := RuntimePerkState.new()
	excluded_only_state.runtime_skill_levels = {
		"item_polish": 1,
		"dash_amplification": 2,
		"downtown_treasure_map": 1,
	}
	var no_target_status: String = RuntimePerkOverflowDescriptions.append_polish_status(
		"모든 일반 성장형 무공의 수치 능력치 5% 증폭",
		"item_polish",
		excluded_only_state
	)
	_expect(
		no_target_status == "모든 일반 성장형 무공의 수치 능력치 5% 증폭, 현재 적용 대상 없음",
		"Polish tooltip should make an excluded-only loadout explicit: %s" % no_target_status
	)

	var acquired: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(
		state.runtime_skill_levels,
		catalog,
		state,
		null,
		{},
		[],
		Color.WHITE,
		Color.WHITE
	)
	var acquired_swiftness: Dictionary = {}
	var acquired_polish: Dictionary = {}
	for perk_value: Variant in acquired:
		if not (perk_value is Dictionary):
			continue
		var acquired_id: String = str((perk_value as Dictionary).get("id", ""))
		if acquired_id == "common_swiftness":
			acquired_swiftness = perk_value as Dictionary
		elif acquired_id == "item_polish":
			acquired_polish = perk_value as Dictionary
	_expect(str(acquired_swiftness.get("description", "")) == swiftness_status_text, "TAB perk tooltip should expose both the Polish delta and application status")
	_expect(str(acquired_polish.get("description", "")) == polish_status_text, "TAB Polish tooltip should expose its current target count")
	var visible_status_entries: Array = CharacterInfoOverlayPerkPresenter.build_perk_stat_entries(
		str(acquired_swiftness.get("description", "")),
		str(acquired_swiftness.get("detail", ""))
	)
	_expect(visible_status_entries.size() == 2, "TAB tooltip should render the Polish status as its own right-panel row")
	if visible_status_entries.size() == 2:
		_expect(str((visible_status_entries[1] as Dictionary).get("text", "")) == "개광결 +15% 적용", "TAB tooltip Polish row text should stay explicit")

	var renderer := RuntimePerkOverlayRenderer.new()
	swiftness["id"] = "common_swiftness"
	swiftness["level"] = 2
	_expect(renderer._perk_stats_for_level(swiftness, state) == swiftness_status_text, "owned-perk status tooltip should expose both the Polish delta and application status")
	for perk_id_value: Variant in RuntimePerkState.PERK_POLISH_AMPLIFIABLE_BONUS_IDS.keys():
		var perk_id := str(perk_id_value)
		var perk_data: Dictionary = catalog.get_perk_data(perk_id)
		var max_level: int = int(perk_data.get("max_level", 5))
		var max_text: String = RuntimePerkOverflowDescriptions.resolve_stats_text_with_polish(
			perk_id,
			perk_data.get("descriptions", {}),
			max_level,
			state
		)
		_expect(max_text.find("(+") >= 0, "every Polish-eligible perk should expose its added value: %s -> %s" % [perk_id, max_text])
		var full_lines: Array = renderer._wrap_text_px(max_text, 16, 230.0, 99)
		_expect(full_lines.size() <= 3, "max-invested Polish text must fit the offer card's 3-line budget: %s -> %s" % [perk_id, str(full_lines)])

	var choice: Dictionary = swiftness.duplicate(true)
	choice["current_level"] = 1
	choice["next_level"] = 2
	choice["description"] = "이동속도 12% 증가"
	renderer._ensure_card_desc_cache([choice], 250.0, state)
	var first_offer_text: String = _cached_offer_accent_text(renderer)
	_expect(first_offer_text.find("(+1.8%)") >= 0, "perk offer card should show the current Polish delta: %s" % first_offer_text)
	_expect(first_offer_text.find("개광결 +") < 0, "narrow offer cards should not duplicate the owned-tooltip Polish status row: %s" % first_offer_text)
	state.runtime_skill_levels["item_polish"] = 5
	renderer._ensure_card_desc_cache([choice], 250.0, state)
	var refreshed_offer_text: String = _cached_offer_accent_text(renderer)
	_expect(refreshed_offer_text.find("(+3%)") >= 0, "perk offer cache should refresh when the Polish multiplier changes: %s" % refreshed_offer_text)


func _cached_offer_accent_text(renderer: Object) -> String:
	var cache_value: Variant = renderer.get("_card_desc_cache")
	if not (cache_value is Array) or (cache_value as Array).is_empty():
		return ""
	var first_value: Variant = (cache_value as Array)[0]
	if not (first_value is Dictionary):
		return ""
	var text := ""
	for line_value: Variant in (first_value as Dictionary).get("accent_lines", []):
		if text != "":
			text += " "
		text += str(line_value)
	return text


func _verify_zero_level_noop() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["item_polish"] = 0
	state.runtime_skill_levels["common_swiftness"] = 2
	_expect_close(state._get_perk_amplify_multiplier("common_swiftness"), 1.0, "Lv.0 Polish should not amplify")
	_expect_close(state.get_runtime_skill_bonus("common_swiftness"), 0.12, "Lv.0 Polish should leave common_swiftness unchanged")


func _verify_all_converted_numeric_values_amplify() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {
		"item_polish": 2,
		"dowsing_goggles": 1,
		"gold_digger": 1,
		"soul_burst": 1,
		"sensor": 1,
		"shrapnel_armor": 1,
	}
	_expect_close(state.get_perk_amplify_multiplier("dowsing_goggles"), 1.10, "converted Mugong should receive the shared Polish multiplier")
	_expect_close(PerkConversionValues.get_value("dowsing_goggles", "bonus_perk_chance", 1, state), 44.0, "Polish should raise Tianan Art choice chance")
	_expect_close(PerkConversionValues.get_value("dowsing_goggles", "fusion_byproduct_chance_pct", 1, state), 3.3, "Polish should raise Tianan Art fusion chance")
	_expect_close(PerkConversionValues.get_value("gold_digger", "gold_bonus_pct", 1, state), 16.5, "Polish should raise Chwigeum Art gold and vigor gain")
	_expect_close(PerkConversionValues.get_value("soul_burst", "soul_burst_gauge_cost", 1, state), 170.0 / 1.10, "Polish should improve lower-is-better cost lanes")
	_expect_close(PerkConversionValues.get_value("sensor", "auto_dash_cooldown_sec", 1, state), 30.0 / 1.10, "Polish should improve lower-is-better cooldown lanes")
	_expect_close(PerkConversionValues.get_value("sensor", "auto_dash_token_count", 1, state), 1.0, "Polish should preserve integer count structure")
	_expect_close(PerkConversionValues.get_value("shrapnel_armor", "shard_count", 1, state), 4.0, "Polish should preserve shard-count structure")
	var scalable_lane_count := 0
	for perk_id_value: Variant in PerkConversionValues.CONVERTED_PERK_VALUES.keys():
		var perk_id := str(perk_id_value)
		var option_table: Dictionary = PerkConversionValues.CONVERTED_PERK_VALUES[perk_id_value]
		for option_key_value: Variant in option_table.keys():
			var option_key := str(option_key_value)
			var base_value := PerkConversionValues.get_value(perk_id, option_key, 1)
			var polished_value := PerkConversionValues.get_value(perk_id, option_key, 1, state)
			if not PerkConversionValues.is_polish_amplifiable_option(perk_id, option_key):
				_expect_close(polished_value, base_value, "structural converted lane must stay unchanged: %s.%s" % [perk_id, option_key])
				continue
			scalable_lane_count += 1
			if PerkConversionValues.is_lower_value_better(perk_id, option_key):
				_expect(polished_value < base_value, "Polish must improve every lower-is-better lane: %s.%s" % [perk_id, option_key])
			else:
				_expect(polished_value > base_value, "Polish must improve every higher-is-better lane: %s.%s" % [perk_id, option_key])
	_expect(scalable_lane_count >= 38, "converted Polish coverage should include every current scalable lane")

	var catalog := RuntimePerkCatalog.new()
	var dowsing: Dictionary = catalog.get_perk_data("dowsing_goggles")
	var dowsing_text := RuntimePerkOverflowDescriptions.resolve_stats_text_with_polish(
		"dowsing_goggles",
		dowsing.get("descriptions", {}),
		1,
		state
	)
	_expect(
		dowsing_text == "무공 선택지 보너스 발동 확률 40 (+4)%, 무공 합일 상승무공 발현 확률 +3 (+0.3)%p",
		"converted Mugong tooltip should expose every Polish delta: %s" % dowsing_text
	)
	_expect(
		RuntimePerkOverflowDescriptions.get_polish_status_text("gold_digger", state) == "개광결 +10% 적용",
		"converted owned-Mugong tooltip should mark Polish as applied"
	)


func _verify_flag_off_legacy_roll_and_bonus_paths() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["item_polish"] = 5
	state.runtime_skill_levels["common_swiftness"] = 2
	_expect_close(state._get_perk_amplify_multiplier("common_swiftness"), 1.0, "flag-OFF should disable the new amplifier")
	_expect_close(state.get_runtime_skill_bonus("common_swiftness"), 0.12, "flag-OFF common_swiftness should stay legacy")
	_expect(state.set_item_perk_level_bonus(1), "test setup should set legacy effective Polish bonus")
	_expect(int(state.get_runtime_skill_level("item_polish")) == 6, "legacy Polish effective level should still overcap")
	_expect_close(state.get_effective_polish_multiplier(), 1.72, "flag-OFF legacy item-roll Polish multiplier should stay unchanged")
	_expect_close(state.get_base_polish_multiplier(), 1.60, "flag-OFF base item-roll Polish multiplier should ignore effective bonuses")


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	PerkConversionFlags.debug_set_enabled(false)
	_failures.append(message)
	push_error(message)
