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
		"prob_success", "prob_side", "prob_byproduct", "prob_byproduct_count", "prob_rare_slot", "animation_title",
		"prob_core_stable", "continue", "outcome_success", "result_side", "result_byproduct",
		"level_fusion", "max_level",
	]
	var native_locales: Array[String] = [
		LanguageSettings.LANGUAGE_CHINESE,
		LanguageSettings.LANGUAGE_JAPANESE,
		LanguageSettings.LANGUAGE_SPANISH,
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL,
		LanguageSettings.LANGUAGE_RUSSIAN,
	]
	var concept_terms := {
		LanguageSettings.LANGUAGE_KOREAN: {"side": "주화입마", "byproduct": "상승무공"},
		LanguageSettings.LANGUAGE_ENGLISH: {"side": "Qi Deviation", "byproduct": "Superior Martial Art"},
		LanguageSettings.LANGUAGE_CHINESE: {"side": "走火入魔", "byproduct": "上乘武功"},
		LanguageSettings.LANGUAGE_JAPANESE: {"side": "走火入魔", "byproduct": "上乗武功"},
		LanguageSettings.LANGUAGE_SPANISH: {"side": "Desviación del qi", "byproduct": "Arte marcial superior"},
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: {"side": "Desvio de qi", "byproduct": "Arte marcial superior"},
		LanguageSettings.LANGUAGE_RUSSIAN: {"side": "Отклонение ци", "byproduct": "Высшее боевое искусство"},
	}
	for locale: String in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(locale)
		for key: String in required_keys:
			var localized := PerkFusionLocalization.text(key)
			_expect(localized != "" and localized != key, "%s should resolve fusion localization key %s" % [locale, key])
		var expected_terms: Dictionary = concept_terms.get(locale, {}) as Dictionary
		_expect(PerkFusionLocalization.text("prob_side") == str(expected_terms.get("side", "")), "%s should present side effects as the qi-deviation concept" % locale)
		_expect(PerkFusionLocalization.text("prob_byproduct") == str(expected_terms.get("byproduct", "")), "%s should present byproducts as the superior-martial-art concept" % locale)
		var count_label := PerkFusionLocalization.format("prob_byproduct_count", [2])
		_expect(count_label.contains(str(expected_terms.get("byproduct", ""))) and count_label.contains("2"), "%s should localize count-specific Superior Martial Art probabilities" % locale)
		var localized_dowsing := LanguageSettings.localize_perk_data({
			"id": "dowsing_goggles",
			"description": "무공 합일 상승무공 확률 증가",
			"detail": "무공 합일 상승무공 확률 증가",
			"descriptions": {1: "무공 합일 상승무공 확률 증가"},
		})
		_expect(str(localized_dowsing.get("detail", "")).contains(str(expected_terms.get("byproduct", ""))), "%s Dowsing Goggles tooltip should use the same superior-martial-art term" % locale)
		_expect(PerkFusionLocalization.byproduct_name("reverb") != "reverb", "%s should not expose raw byproduct ids" % locale)
		var reverb_detail := PerkFusionLocalization.byproduct_detail("reverb")
		_expect(reverb_detail.contains("70%") and not reverb_detail.contains("25%"), "%s Reverb detail should disclose the current +70%% move-speed bonus" % locale)
		_expect(PerkFusionLocalization.byproduct_name("meridian_expand") != "meridian_expand", "%s should localize meridian expansion's name" % locale)
		_expect(PerkFusionLocalization.byproduct_detail("meridian_expand") != "meridian_expand", "%s should localize meridian expansion's detail" % locale)
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
		if locale == LanguageSettings.LANGUAGE_KOREAN:
			_expect(localized_stats.contains("극성") and localized_stats.contains("극성 +1"), "Korean fusion stats should expose max and overflow as 극성 ranks")
			_expect(not localized_stats.contains("Lv."), "Korean fusion stats must not retain Lv. labels")
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
	_expect(runtime_renderer_source.contains("LanguageSettings.format_mugong_rank("), "choice and acquired one-off tags should route through the canonical LanguageSettings rank formatter")
	_expect(formatter_source.contains("LanguageSettings.format_mugong_rank("), "TAB one-off tag should route through the canonical LanguageSettings rank formatter")
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
	_expect(LanguageSettings.translate_text("퍽") == "무공", "Korean perk noun should display as 무공")
	_expect(LanguageSettings.translate_text("퍽 융합") == "무공 합일", "Korean fusion noun should display as 무공 합일")
	_expect(LanguageSettings.translate_text("신화 퍽") == "절세무공", "Korean mythic perk tier should display as 절세무공")
	_expect(LanguageSettings.translate_text("신화 퍽 선택") == "절세무공 선택", "Korean mythic perk choice should use the branded tier")
	_expect(LanguageSettings.translate_text("스킬 강화!") == "무공 수련!", "Korean perk modal title should use the martial training copy")
	_expect(LanguageSettings.translate_text("새 스킬 획득!") == "새 초식 습득!", "Korean character unlock title should use 초식")
	_expect(LanguageSettings.translate_text("초식") == "초식", "Korean character active-skill badge should use 초식")
	_expect(LanguageSettings.translate_text("액티브 스킬") == "액티브 스킬", "Lingpet active-skill terminology must remain unresolved and unchanged")
	_expect(PerkFusionLocalization.text("card_name") == "무공 합일", "Korean fusion card should use 무공 합일")
	_expect(PerkFusionLocalization.text("commit") == "합일", "Korean fusion action button should use 합일")
	_expect(PerkFusionLocalization.text("level_fusion") == "합일", "Korean fusion badge should use 합일")
	_expect(PerkFusionLocalization.text("prob_success") == "유지", "Korean preserved-outcome probability should use the requested 유지 label")
	_expect(PerkFusionLocalization.format("prob_byproduct_count", [3]) == "상승무공 +3개", "Korean probability label should expose the exact Superior Martial Art count")
	_expect(PerkFusionLocalization.text("max_level") == "극성", "Korean fusion candidate max badge should use 극성")
	_expect(LanguageSettings.format_mugong_level(1, 5) == "1성", "Korean first Mugong rank should display as 1성")
	_expect(LanguageSettings.format_mugong_level(2, 5) == "2성", "Korean second Mugong rank should display as 2성")
	_expect(LanguageSettings.format_mugong_level(5, 5) == "극성", "Korean authored max should display as 극성")
	_expect(LanguageSettings.format_mugong_level(7, 5) == "극성 +2", "Korean effective overflow should remain visible above 극성")
	_expect(PerkFusionLocalization.text("outcome_side") == "주화입마 발생", "Korean adverse outcome should use 주화입마")
	_expect(PerkFusionLocalization.text("outcome_byproduct") == "상승무공 발현", "Korean beneficial outcome should use 상승무공")
	_expect(PerkFusionLocalization.format("byproduct_with_detail", ["잔향", "초식 사용 뒤 이동 속도 증가"]).begins_with("상승무공: 잔향"), "Korean fusion tooltip should label Reverb as a 상승무공")
	_expect(CharacterInfoOverlayFormatter.perk_level_text({"max_level": 1, "level": 1, "rarity": "mythic"}) == "절세무공", "Korean mythic perk badge should use 절세무공")
	for korean_fusion_value: Variant in PerkFusionLocalization.KO.values():
		var korean_fusion_text := str(korean_fusion_value)
		_expect(not korean_fusion_text.contains("퍽") and not korean_fusion_text.contains("융합") and not korean_fusion_text.contains("부작용") and not korean_fusion_text.contains("부산물"), "Korean fusion UI should not retain old perk/fusion/industrial outcome nouns: %s" % korean_fusion_text)
	for korean_byproduct_detail: Variant in PerkFusionLocalization.BYPRODUCT_DETAIL_KO.values():
		_expect(not str(korean_byproduct_detail).contains("부작용") and not str(korean_byproduct_detail).contains("부산물"), "Korean superior-art details should not retain old outcome nouns: %s" % str(korean_byproduct_detail))
	var sensor_preview := PerkFusionLocalization.option_preview("auto_dash_cooldown_sec", 15.0, "reverse")
	var shrapnel_preview := PerkFusionLocalization.option_preview("shard_count", 8, "forward")
	_expect(not sensor_preview.contains("auto_dash_cooldown_sec") and sensor_preview.contains("자동 활주") and sensor_preview.contains("초"), "Korean S2 preview should localize sensor labels and units")
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
