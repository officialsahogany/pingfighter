extends SceneTree

const CharacterInfoOverlayPerkPresenter := preload(
	"res://scripts/hud/character_info_overlay_perk_presenter.gd"
)
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MysticDiceDisplayProjection := preload(
	"res://scripts/characters/mystic_dice_display_projection.gd"
)
const MysticDiceLocalization := preload(
	"res://scripts/characters/mystic_dice_localization.gd"
)
const ProjectResourceLoader := preload(
	"res://scripts/resources/project_resource_loader.gd"
)
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkHudStripRenderer := preload(
	"res://scripts/hud/runtime_perk_hud_strip_renderer.gd"
)
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

var _failures: Array[String] = []


func _init() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_verify_projection_visibility_and_copy_contract()
	_verify_runtime_snapshot_and_dice_only_hud()
	_verify_tab_rows_and_benefit_colors()
	_verify_localized_accumulated_header()
	_verify_early_return_and_tooltip_source_contracts()
	ProjectResourceLoader.clear_caches()
	if _failures.is_empty():
		print("mystic_dice_display_projection_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_projection_visibility_and_copy_contract() -> void:
	var projector := MysticDiceDisplayProjection.new()
	var before: Dictionary = projector.build(_dice_snapshot(0, 0, _raw_fixture()))
	_expect((before.get("entries", []) as Array).is_empty(), "uncommitted Dice must not create a display entry")
	var after: Dictionary = projector.build(_dice_snapshot(1, 1, _raw_fixture()))
	var entries: Array = after.get("entries", []) as Array
	_expect(entries.size() == 1, "first committed use should create exactly one synthetic entry")
	if entries.size() != 1:
		return
	var entry: Dictionary = entries[0] as Dictionary
	_expect(str(entry.get("type", "")) == "mystic_dice", "synthetic entry should publish its dedicated type")
	_expect(str(entry.get("perk_id", "")) == "mystic_dice", "synthetic entry should preserve the canonical perk id")
	_expect(int(entry.get("slot_cost", -1)) == 0, "Mystic Dice display entry must remain slot-free")
	_expect(int(entry.get("use_count", 0)) == 1, "synthetic entry should expose committed use count")
	(entry.get("permanent_raw", {}) as Dictionary)["player_speed"] = 30
	var rebuilt: Dictionary = projector.build(_dice_snapshot(1, 1, _raw_fixture()))
	var rebuilt_entry: Dictionary = (rebuilt.get("entries", []) as Array)[0] as Dictionary
	_expect(int((rebuilt_entry.get("permanent_raw", {}) as Dictionary).get("player_speed", 0)) == -5, "projection output must not alias raw input or later builds")
	var revision_only: Dictionary = projector.build(_dice_snapshot(1, 2, _raw_fixture()))
	_expect(after.get("cache_signature") != revision_only.get("cache_signature"), "Dice revision must invalidate the display cache")


func _verify_runtime_snapshot_and_dice_only_hud() -> void:
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	var commit: Dictionary = state.commit_mystic_dice_roll(_raw_fixture())
	_expect(bool(commit.get("accepted", false)), "valid fixture should commit through the runtime facade")
	_expect(state.runtime_skill_levels.is_empty(), "Dice acquisition must not invent a runtime perk level")
	var projection: Dictionary = state.get_perk_fusion_display_projection(catalog)
	var projection_entries: Array = projection.get("entries", []) as Array
	_expect(projection_entries.size() == 1, "composite display projection should expose Dice with no ordinary perks")
	var snapshot: Dictionary = state.get_snapshot()
	var dedicated: Dictionary = snapshot.get("mystic_dice_display_projection", {}) as Dictionary
	_expect((dedicated.get("entries", []) as Array).size() == 1, "runtime snapshot should expose the dedicated Dice projection")
	var composite: Dictionary = snapshot.get("perk_fusion_display_projection", {}) as Dictionary
	_expect((composite.get("entries", []) as Array).size() == 1, "established display channel should carry the composite Dice entry")

	var strip := RuntimePerkHudStripRenderer.new()
	_expect(strip.has_visible_entries({}, projection), "Dice-only projection should pass the HUD visibility gate")
	var strip_entries: Array = strip.build_strip_entries({}, catalog, projection)
	_expect(strip_entries.size() == 1, "Dice-only HUD should build one strip icon")
	if strip_entries.size() == 1:
		var strip_entry: Dictionary = strip_entries[0] as Dictionary
		_expect(str(strip_entry.get("id", "")) == "mystic_dice", "Dice-only HUD should retain the canonical draw id")
		_expect(str(strip_entry.get("type", "")) == "mystic_dice", "HUD strip should preserve the synthetic entry type")


func _verify_tab_rows_and_benefit_colors() -> void:
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	state.commit_mystic_dice_roll(_raw_fixture())
	var snapshot: Dictionary = state.get_snapshot()
	var acquired: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(
		{},
		catalog,
		null,
		snapshot
	)
	_expect(acquired.size() == 1, "TAB perk grid should show Dice when ordinary levels are empty")
	if acquired.size() != 1:
		return
	var dice: Dictionary = acquired[0] as Dictionary
	_expect(bool(dice.get("_slot_free_cell", false)), "TAB Dice cell must render outside the consuming slot budget")
	_expect(str(dice.get("_draw_id", "")) == "mystic_dice", "TAB Dice cell should use the canonical icon id")
	_expect(str(dice.get("detail", "")) != str(dice.get("description", "")), "TAB tooltip should keep flavor copy separate from accumulated stats")
	var rows: Array = CharacterInfoOverlayPerkPresenter.build_perk_stat_entries(
		str(dice.get("description", "")),
		str(dice.get("detail", ""))
	)
	_expect(rows.size() == 7, "TAB Dice tooltip must retain all seven accumulated stat rows")
	var by_label := _rows_by_label(rows)
	_expect(_row_has(by_label, "이동속도", "-5%", CharacterInfoOverlayPerkPresenter.MYSTIC_DICE_STAT_CURSE_COLOR), "normal raw -5 should display red as a loss")
	_expect(_row_has(by_label, "몸집 크기", "+10%", CharacterInfoOverlayPerkPresenter.MYSTIC_DICE_STAT_BENEFIT_COLOR), "normal raw +10 should display green as a benefit")
	_expect(_row_has(by_label, "최대 게이지", "0%", CharacterInfoOverlayPerkPresenter.MYSTIC_DICE_STAT_NEUTRAL_COLOR), "zero raw should display neutral gray")
	_expect(_row_has(by_label, "대쉬 후딜", "-10%", CharacterInfoOverlayPerkPresenter.MYSTIC_DICE_STAT_BENEFIT_COLOR), "LIB raw -10 must invert to green")
	_expect(_row_has(by_label, "대쉬 쿨타임", "+5%", CharacterInfoOverlayPerkPresenter.MYSTIC_DICE_STAT_CURSE_COLOR), "LIB raw +5 must invert to red")
	_expect(_row_has(by_label, "아이템 쿨타임", "-4%", CharacterInfoOverlayPerkPresenter.MYSTIC_DICE_STAT_BENEFIT_COLOR), "LIB item cooldown raw -4 must invert to green")

	var before_hash := CharacterInfoOverlayPerkPresenter.acquired_perk_cache_hash({}, catalog, null, snapshot)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
	var english_hash := CharacterInfoOverlayPerkPresenter.acquired_perk_cache_hash({}, catalog, null, snapshot)
	_expect(before_hash != english_hash, "TAB acquired-perk cache should invalidate when localized Dice labels change")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	state.commit_mystic_dice_roll(_zero_raw())
	var after_snapshot: Dictionary = state.get_snapshot()
	var after_hash := CharacterInfoOverlayPerkPresenter.acquired_perk_cache_hash({}, catalog, null, after_snapshot)
	_expect(before_hash != after_hash, "TAB acquired-perk cache should invalidate on Dice revision even when raw levels stay empty")


func _verify_localized_accumulated_header() -> void:
	for locale: String in [
		LanguageSettings.LANGUAGE_KOREAN,
		LanguageSettings.LANGUAGE_ENGLISH,
		LanguageSettings.LANGUAGE_CHINESE,
		LanguageSettings.LANGUAGE_JAPANESE,
		LanguageSettings.LANGUAGE_SPANISH,
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL,
		LanguageSettings.LANGUAGE_RUSSIAN,
	]:
		LanguageSettings.set_language(locale)
		var header := MysticDiceLocalization.text("accumulated_changes")
		_expect(not header.strip_edges().is_empty() and header != "accumulated_changes", "%s should localize the accumulated-change header" % locale)
		for stat_key: String in ["player_speed", "paddle_size", "skill_gauge", "dash_distance", "dash_recovery", "dash_cooldown", "item_cooldown"]:
			var label := MysticDiceLocalization.text(stat_key)
			_expect(not label.strip_edges().is_empty() and label != stat_key, "%s should localize Dice stat %s" % [locale, stat_key])
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_early_return_and_tooltip_source_contracts() -> void:
	var drawer_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_drawer.gd")
	var drawer_body := SourceContractFunctionBody.extract(drawer_source, "func _draw_perk_hud_strip")
	_expect(drawer_body.contains("has_visible_entries(levels, display_projection)"), "battle drawer should gate on levels OR projected entries")
	_expect(not drawer_body.contains("(levels_value as Dictionary).is_empty()"), "battle drawer must not return before building a Dice-only projection")
	var strip_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_hud_strip_renderer.gd")
	var strip_body := SourceContractFunctionBody.extract(strip_source, "func draw(")
	_expect(strip_body.contains("has_visible_entries(levels, display_projection)"), "HUD strip draw should accept a Dice-only projection")
	var tooltip_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_tooltip_presenter.gd")
	_expect(tooltip_source.contains("tooltip_kind == \"mystic_dice\""), "TAB tooltip should select the dedicated Dice layout profile")
	_expect(tooltip_source.contains("24 if is_fusion else 14"), "Dice tooltip should have enough wrapped-line budget for seven localized rows")


func _rows_by_label(rows: Array) -> Dictionary:
	var result: Dictionary = {}
	for row_value: Variant in rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value as Dictionary
		var text := str(row.get("text", ""))
		var label := text.get_slice(" ", 0)
		if text.begins_with("몸집 크기"):
			label = "몸집 크기"
		elif text.begins_with("최대 게이지"):
			label = "최대 게이지"
		elif text.begins_with("대쉬 거리"):
			label = "대쉬 거리"
		elif text.begins_with("대쉬 후딜"):
			label = "대쉬 후딜"
		elif text.begins_with("대쉬 쿨타임"):
			label = "대쉬 쿨타임"
		elif text.begins_with("아이템 쿨타임"):
			label = "아이템 쿨타임"
		result[label] = row
	return result


func _row_has(rows: Dictionary, label: String, raw_text: String, expected_color: Color) -> bool:
	var row_value: Variant = rows.get(label, {})
	if not (row_value is Dictionary):
		return false
	var row: Dictionary = row_value as Dictionary
	return str(row.get("text", "")).contains(raw_text) and row.get("color") == expected_color


func _raw_fixture() -> Dictionary:
	return {
		"player_speed": -5,
		"paddle_size": 10,
		"skill_gauge": 0,
		"dash_distance": 3,
		"dash_recovery": -10,
		"dash_cooldown": 5,
		"item_cooldown": -4,
	}


func _zero_raw() -> Dictionary:
	return {
		"player_speed": 0,
		"paddle_size": 0,
		"skill_gauge": 0,
		"dash_distance": 0,
		"dash_recovery": 0,
		"dash_cooldown": 0,
		"item_cooldown": 0,
	}


func _dice_snapshot(use_count: int, revision: int, raw: Dictionary) -> Dictionary:
	return {
		"permanent_raw": raw.duplicate(true),
		"use_count": use_count,
		"max_uses_per_run": 3,
		"remaining_uses": maxi(0, 3 - use_count),
		"revision": revision,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
