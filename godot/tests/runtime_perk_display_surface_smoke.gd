extends SceneTree

# Three-star Mugong S4 display seal.
# - all seven loading-tip locales and the Daeseong Spirit Pill catalog derive
#   their numeric cap from the same 37-entry runtime catalog
# - a catalog-wide in-memory cap mutation follows through to visible copy and
#   makes the current-cap contract RED
# - peak banner and Four Poisons milestone copy use shared formatters
# - the shipped character-info stats panel actually appends all ten row rects
# - obsolete static Lv.4/Lv.5 width prewarm is gone

const BattleLoadingTips := preload("res://scripts/core/battle_loading_tips.gd")
const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const CharacterInfoOverlayState := preload("res://scripts/hud/character_info_overlay_state.gd")
const CharacterInfoOverlayPrewarmTextUtils := preload("res://scripts/hud/character_info_overlay_prewarm_text_utils.gd")
const CharacterInfoOverlayTextWidthCache := preload("res://scripts/hud/character_info_overlay_text_width_cache.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemCatalogBuildRouter := preload("res://scripts/items/mythic_item_catalog_build_router.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")
const SmasherSkillOrbTooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")

const MUGONG_TIP_INDEX := 21
const SHIPPED_VIEW := Vector2(2051.0, 1246.0)

var _failures: Array[String] = []
var _row_probe: CharacterInfoRowProbe = null
var _frame_count := 0


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var special_gauge_max := 500.0
	var player_paddle_width := 155.0
	var runtime_paddle_scale := 1.0
	var active_item_slots: Array = []


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null

	func get_cached_instance(_key: String) -> Object:
		return null


class WidthMeasureSpy:
	extends RefCounted

	var measured_texts: Dictionary = {}

	func measure(_font: Font, text: String, size: int) -> Vector2:
		measured_texts[text] = int(measured_texts.get(text, 0)) + 1
		return Vector2(float(text.length() * size), float(size))


# GRT-021 proof uses the actual CharacterInfoOverlay draw entry, not a copied
# row-capacity formula. Canvas draw calls are only valid inside Node2D._draw().
class CharacterInfoRowProbe:
	extends Node2D

	var full_row_rect_count := -1
	var short_row_rect_count := -1
	var layout_stats_rect := Rect2()
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		var overlay := CharacterInfoOverlay.new()
		overlay._update_frame_layout(SHIPPED_VIEW)
		layout_stats_rect = overlay.get("_layout_stats_rect") as Rect2
		var font: Font = ThemeDB.fallback_font
		overlay._draw_stats_panel(
			self,
			FakeOwner.new(),
			FakeRegistry.new(),
			layout_stats_rect,
			font
		)
		var row_rects: Array = overlay.get("_last_lingpet_stat_row_rects")
		full_row_rect_count = row_rects.size()
		row_rects.clear()
		var short_rect := Rect2(layout_stats_rect.position, Vector2(layout_stats_rect.size.x, 84.0))
		overlay._draw_stats_panel(
			self,
			FakeOwner.new(),
			FakeRegistry.new(),
			short_rect,
			font
		)
		short_row_rect_count = row_rects.size()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_verify_catalog_derived_copy_and_negative_leg()
	_verify_peak_banner_locales()
	_verify_elixir_catalog_description()
	_verify_four_poisons_peak_milestone_copy()
	_verify_static_level_width_prewarm()
	_start_character_info_row_probe()


func _process(_delta: float) -> bool:
	if _row_probe == null:
		return false
	_frame_count += 1
	if _frame_count < 3:
		return false
	_expect(
		_row_probe.full_row_rect_count == CharacterInfoOverlayState.STAT_ROW_COUNT,
		"GRT-021: shipped character-info rect must append all %d stat rows, got %d (rect=%s)" % [
			CharacterInfoOverlayState.STAT_ROW_COUNT,
			_row_probe.full_row_rect_count,
			_row_probe.layout_stats_rect,
		]
	)
	_expect(
		_row_probe.short_row_rect_count < CharacterInfoOverlayState.STAT_ROW_COUNT,
		"GRT-021 negative: a deliberately short rect must drop rows so the positive seal is discriminating"
	)
	_finish()
	return true


func _verify_catalog_derived_copy_and_negative_leg() -> void:
	var catalog_data: Dictionary = RuntimePerkCatalog.new().get_all_perk_data()
	_expect(RuntimePerkProgression.TARGET_PERK_IDS.size() == 37, "display authority must cover exactly 37 migrated Mugong")
	var current_max := RuntimePerkProgression.get_catalog_mugong_max_level(catalog_data)
	_expect(current_max == 3, "the 37-entry catalog must currently resolve to max_level 3, got %d" % current_max)
	var current_failures := _catalog_copy_contract_failures(catalog_data, current_max)
	_expect(current_failures.is_empty(), "current catalog display copy must follow Lv.%d: %s" % [current_max, current_failures])
	BattleLoadingTips.invalidate_catalog_mugong_max_level_cache()
	_expect(
		BattleLoadingTips.get_catalog_mugong_max_level() == current_max,
		"production loading-tip cache must initialize from the current catalog"
	)
	_expect(
		BattleLoadingTips.tip_text_for_language(MUGONG_TIP_INDEX, "ko").contains(str(current_max)),
		"production loading-tip path must use the cached catalog max"
	)

	var mutated_catalog: Dictionary = catalog_data.duplicate(true)
	for perk_id_value: Variant in RuntimePerkProgression.TARGET_PERK_IDS.keys():
		var perk_id := str(perk_id_value)
		var perk: Dictionary = mutated_catalog[perk_id]
		perk["max_level"] = 7
		mutated_catalog[perk_id] = perk
	_expect(
		RuntimePerkProgression.get_catalog_mugong_max_level(mutated_catalog) == 7,
		"in-memory catalog fixture must resolve its arbitrary max_level 7"
	)
	_expect(
		_catalog_copy_contract_failures(mutated_catalog, 7).is_empty(),
		"catalog-derived copy must follow the in-memory max_level 7 fixture"
	)
	_expect(
		not _catalog_copy_contract_failures(mutated_catalog, current_max).is_empty(),
		"negative leg: the max_level 7 fixture must make the current Lv.3 display contract RED"
	)


func _catalog_copy_contract_failures(catalog_data: Dictionary, expected_max: int) -> Array[String]:
	var failures: Array[String] = []
	for language_value: Variant in LanguageSettings.SUPPORTED_LANGUAGES:
		var language := str(language_value)
		var tip := BattleLoadingTips.tip_text_for_language(MUGONG_TIP_INDEX, language, catalog_data)
		if not tip.contains(str(expected_max)):
			failures.append("loading tip %s did not contain %d: %s" % [language, expected_max, tip])
		if tip.contains(BattleLoadingTips.MUGONG_MAX_LEVEL_TOKEN):
			failures.append("loading tip %s leaked its template token" % language)
	var elixir_description := MythicItemCatalogBuildRouter.format_elixir_of_mastery_description(catalog_data)
	# The rebrand uses the 성 ladder, not Lv.N, for player-facing Mugong copy.
	if not elixir_description.contains("%d성" % expected_max):
		failures.append("Elixir description did not contain %d성: %s" % [expected_max, elixir_description])
	return failures


func _verify_peak_banner_locales() -> void:
	var expected_by_language := {
		"ko": "극성 도달!",
		"en": "Reached Lv.3!",
		"zh": "达到Lv.3！",
		"ja": "Lv.3達成！",
		"es": "¡Lv.3 alcanzado!",
		"pt-BR": "Nv.3 alcançado!",
		"ru": "Достигнут ур.3!",
	}
	for language_value: Variant in LanguageSettings.SUPPORTED_LANGUAGES:
		var language := str(language_value)
		LanguageSettings.set_test_locale_override(language)
		var banner := LanguageSettings.format_mugong_peak_reached(3)
		_expect(banner == str(expected_by_language[language]), "peak banner %s mismatch: %s" % [language, banner])
		_expect(not banner.contains("—"), "peak banner %s must not use an em dash" % language)
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_ENGLISH)
	_expect(
		LanguageSettings.format_mugong_peak_reached(7) == "Reached Lv.7!",
		"peak banner formatter must follow an arbitrary max_level"
	)
	var cinematic_source := FileAccess.get_file_as_string("res://scripts/items/elixir_of_mastery_cinematic_draw.gd")
	_expect(cinematic_source.contains("format_mugong_peak_reached"), "cinematic banner must consume the shared peak formatter")
	_expect(not cinematic_source.contains("translate_text(\"Lv.5 달성!\")"), "cinematic banner must not retain its literal Lv.5 key")
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)


func _verify_elixir_catalog_description() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var item: Dictionary = MythicItemCatalog.new().build_item_by_name("elixir_of_mastery")
	var description := str(item.get("description", ""))
	_expect(description.contains("3성"), "mythic Elixir catalog description must show catalog-derived 3성: %s" % description)
	_expect(not description.contains("5성"), "mythic Elixir catalog description must not retain 5성")


func _verify_four_poisons_peak_milestone_copy() -> void:
	var renderer := SmasherSkillOrbTooltipRenderer.new()
	var milestone_level := RuntimePerkProgression.get_milestone_level("four_poisons", "clone_replication", "starts")
	var max_level := RuntimePerkProgression.get_authored_max_level("four_poisons")
	_expect(milestone_level == max_level, "Four Poisons clone milestone must start at its catalog-authored peak")
	for language_value: Variant in LanguageSettings.SUPPORTED_LANGUAGES:
		var language := str(language_value)
		LanguageSettings.set_test_locale_override(language)
		var line := renderer._format_four_poisons_dual_peak_line()
		var expected_rank := LanguageSettings.format_mugong_level(milestone_level, max_level)
		_expect(line.contains(expected_rank), "Four Poisons %s copy must contain derived rank %s: %s" % [language, expected_rank, line])
		_expect(not line.contains("Lv5"), "Four Poisons %s copy must not retain literal Lv5" % language)
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)


func _verify_static_level_width_prewarm() -> void:
	var spy := WidthMeasureSpy.new()
	CharacterInfoOverlayTextWidthCache.prewarm_static_text(
		ThemeDB.fallback_font,
		FakeOwner.new(),
		[],
		[],
		Callable(spy, "measure")
	)
	for level in range(1, 4):
		_expect(spy.measured_texts.has("Lv.%d" % level), "static width prewarm must retain Lv.%d" % level)
	_expect(not spy.measured_texts.has("Lv.4"), "static width prewarm must not retain obsolete Mugong Lv.4")
	_expect(not spy.measured_texts.has("Lv.5"), "static width prewarm must not retain obsolete Mugong Lv.5")

	var catalog_data: Dictionary = RuntimePerkCatalog.new().get_all_perk_data()
	spy.measured_texts.clear()
	CharacterInfoOverlayPrewarmTextUtils.prewarm_perk_text_entry(
		ThemeDB.fallback_font,
		catalog_data["item_luck"],
		Callable(spy, "measure"),
		Callable(self, "_trim_label_fixture"),
		Callable(self, "_prewarm_text_block_fixture")
	)
	# Korean formats the ladder as 성 / 극성, not Lv.N (LanguageSettings.format_mugong_level).
	_expect(not spy.measured_texts.has("4성"), "migrated Mugong dynamic prewarm must stop at catalog 3성")
	_expect(not spy.measured_texts.has("5성"), "migrated Mugong dynamic prewarm must stop at catalog 3성")

	spy.measured_texts.clear()
	CharacterInfoOverlayPrewarmTextUtils.prewarm_perk_text_entry(
		ThemeDB.fallback_font,
		catalog_data["dash_lightweight"],
		Callable(spy, "measure"),
		Callable(self, "_trim_label_fixture"),
		Callable(self, "_prewarm_text_block_fixture")
	)
	_expect(spy.measured_texts.has("4성"), "training dynamic prewarm must retain its separate 4성")
	_expect(spy.measured_texts.has("극성"), "training dynamic prewarm must retain its separate 극성")


func _trim_label_fixture(text: String, _max_characters: int) -> String:
	return text


func _prewarm_text_block_fixture(_font: Font, _text: String, _size: int, _width: float, _max_lines: int) -> void:
	pass


func _start_character_info_row_probe() -> void:
	_row_probe = CharacterInfoRowProbe.new()
	get_root().add_child(_row_probe)
	_row_probe.queue_redraw()


func _finish() -> void:
	LanguageSettings.set_test_locale_override("")
	if _row_probe != null:
		_row_probe.queue_free()
	if _failures.is_empty():
		print(
			"runtime_perk_display_surface_smoke: ok TARGETS=37 LOCALES=7 ROWS=%d SHORT_ROWS=%d NEGATIVE=RED" % [
				CharacterInfoOverlayState.STAT_ROW_COUNT,
				_row_probe.short_row_rect_count,
			]
		)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
