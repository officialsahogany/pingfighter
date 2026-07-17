extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")
const PerkFusionOfferPlanner := preload("res://scripts/characters/perk_fusion_offer_planner.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")

var _failures: Array[String] = []


func _init() -> void:
	var required_keys: Array[String] = [
		"card_name", "card_description", "materials_title", "confirm_title",
		"prob_success", "prob_side", "prob_byproduct", "animation_title",
		"prob_core_stable", "continue", "outcome_success", "result_side", "result_byproduct",
		"level_fusion",
	]
	var native_locales: Array[String] = [
		LanguageSettings.LANGUAGE_CHINESE,
		LanguageSettings.LANGUAGE_JAPANESE,
		LanguageSettings.LANGUAGE_SPANISH,
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL,
		LanguageSettings.LANGUAGE_RUSSIAN,
	]
	for locale: String in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(locale)
		for key: String in required_keys:
			var localized := PerkFusionLocalization.text(key)
			_expect(localized != "" and localized != key, "%s should resolve fusion localization key %s" % [locale, key])
		_expect(PerkFusionLocalization.byproduct_name("reverb") != "reverb", "%s should not expose raw byproduct ids" % locale)
		var localized_record := {
			"sources": ["source_a", "source_b"],
			"outcome": "side_effect",
			"source_options": {
				"source_a": {"gauge_cost": {"value": 20.0, "adjusted_value": 16.0}},
				"source_b": {"item_cooldown_pct": {"value": 12.0, "deleted": true}},
			},
			"option_penalties": {
				"source_a": {"gauge_cost": {"original_value": 20.0, "adjusted_value": 16.0}},
			},
			"deleted_options": {"source_b": ["item_cooldown_pct"]},
			"byproducts": ["limit_break"],
			"byproduct_payloads": {"limit_break": {"eligible_sources": ["source_a"]}},
		}
		var source_labels := {"source_a": "A", "source_b": "B"}
		var localized_detail := "\n".join(PerkFusionLocalization.record_detail_lines(localized_record, source_labels))
		var localized_stats := "\n".join(PerkFusionLocalization.tooltip_stat_lines(localized_record, source_labels, {"source_a": 5, "source_b": 5}, {"source_a": 6, "source_b": 5}))
		_expect(localized_detail.contains(PerkFusionLocalization.option_label("gauge_cost")) and localized_detail.contains(PerkFusionLocalization.byproduct_name("limit_break")), "%s detailed result should use localized option and byproduct copy" % locale)
		_expect(localized_stats.contains(PerkFusionLocalization.option_label("item_cooldown_pct")) and localized_stats.contains(PerkFusionLocalization.text("deleted_badge")), "%s tooltip stats should render localized deletion copy" % locale)
		_expect(not localized_detail.contains("gauge_cost") and not localized_stats.contains("item_cooldown_pct") and not localized_stats.contains("\u0336"), "%s detailed output must not leak raw keys or combining strike glyphs" % locale)
		var offer: Dictionary = PerkFusionOfferPlanner.new().plan_offer(
			[
				{"id": "a", "offer_lane": "replaceable", "offer_protected": false},
				{"id": "b", "offer_lane": "replaceable", "offer_protected": false},
			],
			["source_a", "source_b"],
			PerkFusionOfferPlanner.OFFER_SOURCE_BATTLE_STARPOINT,
			0.0,
			0.0
		)
		var choices: Array = offer.get("choices", []) as Array
		var card: Dictionary = choices[0] if not choices.is_empty() else {}
		_expect(str(card.get("name", "")) == PerkFusionLocalization.text("card_name"), "%s fusion offer should use the active locale" % locale)
		var presented: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks_from_projection(
			[{
				"type": "fusion",
				"fusion_id": "fusion_0",
				"sources": ["a", "b"],
				"source_names": ["A", "B"],
				"summary": "A + B",
			}],
			null,
			{},
			Color.CORNFLOWER_BLUE,
			Color.GOLD
		)
		var fusion_entry: Dictionary = presented[0] if not presented.is_empty() else {}
		_expect(str(fusion_entry.get("_level_text", "")) == PerkFusionLocalization.text("level_fusion"), "%s TAB fusion badge should use the active locale" % locale)
		if locale != LanguageSettings.LANGUAGE_KOREAN:
			_expect(str(fusion_entry.get("_level_text", "")) != "융합", "%s TAB presenter must not leak Korean fusion copy" % locale)
			_expect(LanguageSettings.translate_text("고유") != "고유", "%s should localize the one-off perk tag" % locale)
			_expect(LanguageSettings.translate_text("보유 퍽 강화만") != "보유 퍽 강화만", "%s should localize the owned-only status hint" % locale)
			_expect(CharacterInfoOverlayFormatter.perk_level_text({"max_level": 1, "level": 1}) == LanguageSettings.translate_text("고유"), "%s TAB one-off tag should resolve through LanguageSettings at runtime" % locale)
		if locale in native_locales:
			var ui_table: Dictionary = PerkFusionLocalization.OVERRIDES.get(locale, {}) as Dictionary
			_expect(ui_table.size() == PerkFusionLocalization.EN.size(), "%s should own every fusion UI key instead of falling back to English" % locale)
			for key_value: Variant in PerkFusionLocalization.EN.keys():
				var full_key := str(key_value)
				_expect(ui_table.has(full_key), "%s missing native fusion UI key %s" % [locale, full_key])
				_expect(PerkFusionLocalization.text(full_key) == str(ui_table.get(full_key, "")), "%s fusion UI key %s should resolve from its native table" % [locale, full_key])
			var byproduct_names: Dictionary = PerkFusionLocalization.BYPRODUCT_LOCALIZED.get(locale, {}) as Dictionary
			var byproduct_details: Dictionary = PerkFusionLocalization.BYPRODUCT_DETAIL_LOCALIZED.get(locale, {}) as Dictionary
			_expect(byproduct_names.size() == PerkFusionLocalization.BYPRODUCT_EN.size(), "%s should own every byproduct name" % locale)
			_expect(byproduct_details.size() == PerkFusionLocalization.BYPRODUCT_DETAIL_EN.size(), "%s should own every byproduct detail" % locale)
			for byproduct_value: Variant in PerkFusionLocalization.BYPRODUCT_EN.keys():
				var byproduct_id := str(byproduct_value)
				_expect(byproduct_names.has(byproduct_id), "%s missing byproduct name %s" % [locale, byproduct_id])
				_expect(byproduct_details.has(byproduct_id), "%s missing byproduct detail %s" % [locale, byproduct_id])
				_expect(PerkFusionLocalization.byproduct_name(byproduct_id) == str(byproduct_names.get(byproduct_id, "")), "%s byproduct %s should use native copy" % [locale, byproduct_id])
				_expect(PerkFusionLocalization.byproduct_detail(byproduct_id) == str(byproduct_details.get(byproduct_id, "")), "%s byproduct detail %s should use native copy" % [locale, byproduct_id])
			var option_labels: Dictionary = PerkFusionLocalization.OPTION_LABEL_LOCALIZED.get(locale, {}) as Dictionary
			_expect(option_labels.size() == PerkFusionLocalization.OPTION_LABEL_EN.size(), "%s should own every fusion option label" % locale)
			for option_value: Variant in PerkFusionLocalization.OPTION_LABEL_EN.keys():
				var option_key := str(option_value)
				_expect(option_labels.has(option_key), "%s missing option label %s" % [locale, option_key])
				_expect(PerkFusionLocalization.option_label(option_key) == str(option_labels.get(option_key, "")), "%s option %s should use native copy" % [locale, option_key])
			var units: Dictionary = PerkFusionLocalization.OPTION_UNITS.get(locale, {}) as Dictionary
			for unit_key in ["seconds", "count", "levels", "perk_level", "pixels", "gauge", "fuel"]:
				_expect(units.has(unit_key), "%s missing localized fusion unit %s" % [locale, unit_key])
			_expect(PerkFusionLocalization.option_value_text("gauge_cost", 12).contains(str(units.get("gauge", "__missing__"))), "%s gauge option should render its locale-owned unit" % locale)
			_expect(PerkFusionLocalization.option_value_text("fuel_bonus_flat", 8).contains(str(units.get("fuel", "__missing__"))), "%s fuel option should render its locale-owned unit" % locale)
			_expect(PerkFusionLocalization.byproduct_name("reverb") != PerkFusionLocalization.BYPRODUCT_EN["reverb"], "%s byproduct copy must not silently fall back to English" % locale)
			_expect(PerkFusionLocalization.option_label("gauge_cost") != PerkFusionLocalization.OPTION_LABEL_EN["gauge_cost"], "%s option copy must not silently fall back to English" % locale)
	var renderer_source := FileAccess.get_file_as_string("res://scripts/hud/perk_fusion_overlay_renderer.gd")
	_expect(renderer_source.find("ThemeDB.fallback_font") >= 0, "fusion overlay should use the engine fallback font for all supported locale glyphs")
	var runtime_renderer_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	var formatter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_formatter.gd")
	_expect(runtime_renderer_source.contains("LanguageSettings.translate_text(\"보유 퍽 강화만\")"), "owned-only status hint should route through LanguageSettings")
	_expect(runtime_renderer_source.contains("LanguageSettings.translate_text(\"고유\")"), "choice and acquired one-off tags should route through LanguageSettings")
	_expect(formatter_source.contains("LanguageSettings.translate_text(\"고유\")"), "TAB one-off tag should route through LanguageSettings")
	var fallback_font: Font = ThemeDB.fallback_font
	# The headless fallback font intentionally has no CJK faces. Keep glyph
	# coverage focused on the Latin/Cyrillic locales it owns; CJK copy is sealed
	# by native-table coverage above and uses the platform fallback in the live UI.
	for locale in [LanguageSettings.LANGUAGE_SPANISH, LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL, LanguageSettings.LANGUAGE_RUSSIAN]:
		LanguageSettings.set_test_locale_override(locale)
		var localized_text := ""
		for key: String in PerkFusionLocalization.EN.keys():
			localized_text += PerkFusionLocalization.text(key)
		for byproduct_value: Variant in PerkFusionLocalization.BYPRODUCT_EN.keys():
			localized_text += PerkFusionLocalization.byproduct_name(str(byproduct_value))
			localized_text += PerkFusionLocalization.byproduct_detail(str(byproduct_value))
		for option_value: Variant in PerkFusionLocalization.OPTION_LABEL_EN.keys():
			localized_text += PerkFusionLocalization.option_label(str(option_value))
		for index in range(localized_text.length()):
			var codepoint := localized_text.unicode_at(index)
			if codepoint > 127 and codepoint != 0x2192:
				_expect(fallback_font != null and fallback_font.has_char(codepoint), "%s fusion copy should be covered by the selected fallback font at U+%04X" % [locale, codepoint])
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var sensor_preview := PerkFusionLocalization.option_preview("auto_dash_cooldown_sec", 15.0, "reverse")
	var shrapnel_preview := PerkFusionLocalization.option_preview("shard_count", 8, "forward")
	_expect(not sensor_preview.contains("auto_dash_cooldown_sec") and sensor_preview.contains("자동 대시") and sensor_preview.contains("초"), "Korean S2 preview should localize sensor labels and units")
	_expect(not shrapnel_preview.contains("shard_count") and shrapnel_preview.contains("파편") and shrapnel_preview.contains("개"), "Korean S2 preview should localize shrapnel labels and units")
	# 코덱스 v3 P1: 융합 스모크는 저장 동작을 검증하지 않는다 — 저장형
	# set_language()는 실제 user://language_settings.cfg를 config.save()로
	# 오염시키므로(중간 종료 시 순환 중 언어 잔존), 전 융합 스모크에서
	# 비저장 set_test_locale_override만 허용한다(자기 자신 매칭 회피용
	# 문자열 결합 패턴).
	var persistent_language_call := "LanguageSettings." + "set_language("
	var tests_dir := DirAccess.open("res://tests")
	_expect(tests_dir != null, "fusion smokes should be able to enumerate the tests directory")
	if tests_dir != null:
		for file_name: String in tests_dir.get_files():
			if not file_name.ends_with(".gd"):
				continue
			# 같은 시스템 카드 로테이션 계열(융합·신비의 주사위) focused
			# 스모크 전수 — 저장형 호출은 실 user:// 설정을 오염시킨다.
			if not file_name.begins_with("perk_fusion_") and not file_name.begins_with("mystic_dice_"):
				continue
			var smoke_source := FileAccess.get_file_as_string("res://tests/" + file_name)
			_expect(not smoke_source.contains(persistent_language_call), "%s must use the non-persistent set_test_locale_override instead of the saving set_language" % file_name)
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("perk_fusion_localization_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
