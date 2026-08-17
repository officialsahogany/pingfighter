extends SceneTree

const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var catalog := RuntimePerkCatalog.new()
	var fusion_entry := _fusion_entry_fixture()
	var acquired := CharacterInfoOverlayPerkPresenter.build_acquired_perks_from_projection(
		[fusion_entry],
		catalog,
		{},
		Color.CORNFLOWER_BLUE,
		Color.GOLD
	)
	_expect(acquired.size() == 1, "fixture should build one folded fusion entry")
	var fusion: Dictionary = acquired[0] as Dictionary if acquired.size() == 1 else {}
	var sections: Array = fusion.get("fusion_sections", []) as Array
	_expect(sections.size() == 3, "fusion tooltip should expose exactly two source cards plus one outcome card")
	if sections.size() == 3:
		_verify_source_card(
			sections[0] as Dictionary,
			"common_bulk_up",
			"무공 A",
			"철산공",
			"철산공으로 몸의 기세를 넓혀 몸집 크기가 증가합니다.",
			"몸집 크기 30% 증가"
		)
		_verify_source_card(
			sections[1] as Dictionary,
			"dash_lightweight",
			"무공 B",
			"회기보",
			"회기보로 흩어진 기운을 거두어 소모한 활주 횟수를 더 빠르게 회복합니다.",
			"활주 재충전 60% 감소"
		)
		var source_a_rows: Array = (sections[0] as Dictionary).get("rows", []) as Array
		_expect(source_a_rows.size() == 1, "the changed source card should own its one side-effect row")
		if source_a_rows.size() == 1:
			var change_text := str((source_a_rows[0] as Dictionary).get("text", ""))
			_expect(change_text.contains("효과 수치") and change_text.contains("→"), "the source-local side-effect row should retain the actual before-to-after value")
			_expect(not change_text.contains("runtime_skill_bonus"), "source card must not leak raw fusion option ids")
		_expect(((sections[1] as Dictionary).get("rows", []) as Array).is_empty(), "the untouched source must not inherit the other Mugong's side effect")
		var outcome: Dictionary = sections[2] as Dictionary
		_expect(str(outcome.get("kind", "")) == "outcome", "third card should be the dedicated side-effect/byproduct outcome card")
		var outcome_rows: Array = outcome.get("rows", []) as Array
		_expect(outcome_rows.size() == 2, "outcome card should separate one side-effect summary and one byproduct detail")
		var byproduct_row: Dictionary = outcome_rows[1] as Dictionary if outcome_rows.size() > 1 else {}
		_expect(str(byproduct_row.get("icon_id", "")) == "reverb", "byproduct detail should carry its canonical orb icon id")
		_expect(str(byproduct_row.get("text", "")).contains("잔향") and str(byproduct_row.get("text", "")).contains("3초") and str(byproduct_row.get("text", "")).contains("70%"), "byproduct card should show Reverb's current localized duration and move-speed bonus")

	var packed := CharacterInfoOverlayPerkPresenter.pack_fusion_hover_body(
		str(fusion.get("detail", "")),
		str(fusion.get("description", "")),
		sections
	)
	var payload := CharacterInfoOverlayPerkPresenter.build_fusion_hover_payload(packed)
	var payload_sections: Array = payload.get("fusion_sections", []) as Array
	_expect(payload_sections.size() == 3, "real String hover cache packing should preserve all three structured cards")
	_expect(str(payload.get("tooltip_kind", "")) == "fusion", "structured hover payload should keep the fusion renderer route")
	if payload_sections.size() == 3:
		_expect(str((payload_sections[0] as Dictionary).get("icon_id", "")) == "common_bulk_up", "hover decoding should preserve source A's icon id")
		_expect(str((payload_sections[1] as Dictionary).get("icon_id", "")) == "dash_lightweight", "hover decoding should preserve source B's icon id")

	var tooltip_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_tooltip_presenter.gd")
	var status_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	_expect(tooltip_source.contains("static func draw_fusion_tooltip("), "TAB tooltip should own a dedicated three-card fusion renderer")
	_expect(tooltip_source.contains("fusion_sections.size() == 3"), "TAB dispatch should require the exact two-source-plus-outcome contract")
	_expect(status_source.contains("CharacterInfoOverlayTooltipPresenter.draw_fusion_tooltip("), "ESC owned-Mugong tooltip should reuse the same three-card renderer")

	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("perk_fusion_source_cards_tooltip_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_source_card(
	section: Dictionary,
	expected_id: String,
	expected_eyebrow: String,
	expected_title: String,
	expected_body: String,
	expected_stats: String
) -> void:
	_expect(str(section.get("kind", "")) == "source", "%s should render as an original Mugong source card" % expected_title)
	_expect(str(section.get("source_id", "")) == expected_id, "%s source identity should remain stable" % expected_title)
	_expect(str(section.get("icon_id", "")) == expected_id, "%s card should use its original Mugong icon" % expected_title)
	_expect(str(section.get("eyebrow", "")) == expected_eyebrow, "%s card should keep its material lane label" % expected_title)
	_expect(str(section.get("title", "")) == expected_title, "%s card should use the catalog name" % expected_title)
	_expect(str(section.get("body", "")) == expected_body, "%s card should reuse the catalog detail verbatim" % expected_title)
	_expect(str(section.get("stats", "")) == expected_stats, "%s card should reuse its current-level catalog stats" % expected_title)


func _fusion_entry_fixture() -> Dictionary:
	return {
		"type": "fusion",
		"id": "fusion_cheolsan_hoegi",
		"fusion_id": "fusion_cheolsan_hoegi",
		"fusion_revision": 4,
		"sources": ["common_bulk_up", "dash_lightweight"],
		"source_names": ["철산공", "회기보"],
		"base_levels": {"common_bulk_up": 5, "dash_lightweight": 5},
		"effective_levels": {"common_bulk_up": 5, "dash_lightweight": 5},
		"live_source_options": {
			"common_bulk_up": {
				"runtime_skill_bonus": {
					"value": 0.3,
					"adjusted_value": 0.24,
				},
			},
		},
		"summary": "철산공 + 회기보 · 주화입마 합일 · 상승무공 1개",
		"slot_cost": 1,
		"record_payload": {
			"fusion_id": "fusion_cheolsan_hoegi",
			"sources": ["common_bulk_up", "dash_lightweight"],
			"outcome": "side_effect",
			"option_penalties": {
				"common_bulk_up": {
					"runtime_skill_bonus": {
						"original_value": 0.3,
						"adjusted_value": 0.24,
						"nominal_pct": 20.0,
					},
				},
			},
			"deleted_options": {},
			"byproducts": ["reverb"],
			"byproduct_payloads": {},
		},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
