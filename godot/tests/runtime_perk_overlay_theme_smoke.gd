extends SceneTree

const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []


func _init() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var overlay := RuntimePerkOverlayRenderer.new()
	_verify_character_edge_theme(overlay)
	_verify_unlock_label_path(overlay)
	_verify_title_text_cache(overlay)
	_verify_card_text_measurement_cache(overlay)
	_verify_static_prewarm_populates_text_caches(overlay)
	_verify_fallback_symbol_draw_budgets()
	LanguageSettings.set_test_locale_override("")

	if _failures.is_empty():
		print("runtime_perk_overlay_theme_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_character_edge_theme(overlay: Object) -> void:
	var expected_markers := {
		"smasher": "energy",
		"viper": "poison",
		"optimus": "mecha",
		"soldier": "tactical",
		"commando": "tactical",
	}
	for restriction in expected_markers.keys():
		var theme: Dictionary = overlay._character_edge_theme(str(restriction), 1.0, 0.5)
		_expect(not theme.is_empty(), "%s should have a character-edge theme" % str(restriction))
		_expect(str(theme.get("marker", "")) == str(expected_markers[restriction]), "%s should use the expected edge marker family" % str(restriction))
		_expect(theme.has("main") and theme.has("accent") and theme.has("highlight"), "%s should expose main/accent/highlight colors" % str(restriction))

	var smasher: Dictionary = overlay._character_edge_theme("smasher")
	var viper: Dictionary = overlay._character_edge_theme("viper")
	var optimus: Dictionary = overlay._character_edge_theme("optimus")
	var soldier: Dictionary = overlay._character_edge_theme("soldier")
	_expect(_dominant_channel(smasher.get("main", Color.BLACK)) == "b", "Smasher edge should read cyan/blue")
	_expect(_dominant_channel(viper.get("accent", Color.BLACK)) == "b", "Viper edge should read violet")
	_expect(_dominant_channel(optimus.get("main", Color.BLACK)) == "r", "Optimus edge should read orange")
	_expect(_dominant_channel(soldier.get("main", Color.BLACK)) == "g", "Commando/Soldier edge should read tactical green")
	_expect(overlay._character_edge_theme("unknown").is_empty(), "Unknown restrictions should not draw a character edge")


func _verify_unlock_label_path(overlay: Object) -> void:
	var unlock_choice := {
		"id": "soldier_unlock_bazooka",
		"name": "벽력완구",
		"max_level": 1,
		"current_level": 0,
		"next_level": 1,
		"character_restriction": "soldier",
		"unlocks_skill": "bazooka",
	}
	_expect(str(overlay._level_text(unlock_choice)) == "비급", "Character skill manuals should use the Korean short manual label")
	_expect(str(overlay._long_level_text(unlock_choice)).contains("초식 비급"), "Character skill manuals should use the Korean long manual label")
	_expect(bool(overlay._shows_character_unlock_badge(unlock_choice)), "Character unlock cards should show the A badge")

	var sparse_unlock_choice := {
		"id": "optimus_arm",
		"name": "옵티머스암",
		"max_level": 1,
		"current_level": 0,
		"next_level": 1,
		"character_restriction": "optimus",
	}
	_expect(bool(overlay._shows_character_unlock_badge(sparse_unlock_choice)), "A badge should follow character_restriction + max_level even when unlocks_skill is absent")

	var common_choice := {
		"id": "common_swiftness",
		"name": "유운보",
		"max_level": 5,
		"current_level": 0,
		"next_level": 1,
	}
	_expect(not bool(overlay._shows_character_unlock_badge(common_choice)), "Common scaling perks should not show the A badge")
	_expect(str(overlay._level_text(common_choice)) == "1성", "Common scaling perks should use 1성 on their first rank")
	_expect(str(overlay._long_level_text(common_choice)).contains("미습득 → 1성"), "Common scaling perk transition should use martial-rank wording")
	var max_choice := common_choice.duplicate(true)
	max_choice["current_level"] = 4
	max_choice["next_level"] = 5
	_expect(str(overlay._level_text(max_choice)) == "극성", "Common scaling perks should use 극성 at authored max")


func _verify_title_text_cache(overlay: Object) -> void:
	_expect(str(overlay.TITLE_TEXT) == "무공 수련!", "Runtime perk overlay title should use the branded Korean text")
	var font: Font = ThemeDB.fallback_font
	_expect(font != null, "Runtime perk overlay title smoke needs a fallback font")
	if font == null:
		return
	var size_1: Vector2 = overlay._get_title_text_size(font)
	var size_2: Vector2 = overlay._get_title_text_size(font)
	_expect(size_1.x > 0.0 and size_1.y > 0.0, "Runtime perk overlay title should measure to a visible size")
	_expect(size_1 == size_2, "Runtime perk overlay title size should be cached between reads")
	var line_1: TextLine = overlay._get_title_text_line(font)
	var line_2: TextLine = overlay._get_title_text_line(font)
	_expect(line_1 != null, "Runtime perk overlay title should cache a shaped TextLine")
	_expect(line_1 == line_2, "Runtime perk overlay title should reuse its shaped TextLine")
	_expect(int(overlay.TITLE_SHADOW_DRAW_COUNT) <= 1, "Runtime perk overlay title should stay within the reduced shadow draw budget")


func _verify_card_text_measurement_cache(overlay: Object) -> void:
	var font: Font = ThemeDB.fallback_font
	_expect(font != null, "Runtime perk overlay card text cache smoke needs a fallback font")
	if font == null:
		return

	overlay._prepare_text_caches()
	var fitted_1: Dictionary = overlay._get_fitted_text(font, "Runtime Perk Label That Should Ellipsize", 18, 12, 48.0)
	var fitted_2: Dictionary = overlay._get_fitted_text(font, "Runtime Perk Label That Should Ellipsize", 18, 12, 48.0)
	_expect(fitted_1 == fitted_2, "Runtime perk card text fitting should reuse cached results")
	_expect(overlay._text_fit_cache.size() == 1, "Runtime perk card text fitting should not add duplicate cache entries")

	var size_1: Vector2 = overlay._get_text_size(font, "극성", 12)
	var size_2: Vector2 = overlay._get_text_size(font, "극성", 12)
	_expect(size_1 == size_2, "Runtime perk card text measurement should reuse cached string sizes")
	_expect(not overlay._text_size_cache.is_empty(), "Runtime perk card text measurement should populate the size cache")


func _verify_static_prewarm_populates_text_caches(overlay: Object) -> void:
	overlay._title_text_line = null
	overlay._title_text_size = Vector2.ZERO
	overlay._text_fit_cache.clear()
	overlay._text_size_cache.clear()

	overlay.prewarm_assets()

	_expect(overlay._title_text_line != null, "Runtime perk overlay prewarm should shape the title TextLine before first draw")
	_expect(overlay._title_text_size.x > 0.0 and overlay._title_text_size.y > 0.0, "Runtime perk overlay prewarm should measure the title before first draw")
	_expect(not overlay._text_size_cache.is_empty(), "Runtime perk overlay prewarm should populate common text-size cache entries")
	_expect(not overlay._text_fit_cache.is_empty(), "Runtime perk overlay prewarm should populate common fitted-text cache entries")


func _verify_fallback_symbol_draw_budgets() -> void:
	_expect(RuntimePerkOverlayRenderer.PERK_UNLOCK_SYMBOL_ARC_SEGMENTS <= 20, "Runtime perk unlock fallback symbol should keep a bounded arc budget")
	_expect(RuntimePerkOverlayRenderer.PERK_FALLBACK_SYMBOL_ARC_SEGMENTS <= 24, "Runtime perk generic fallback symbol should keep a bounded arc budget")
	var source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	_expect(source.find("PERK_UNLOCK_SYMBOL_ARC_SEGMENTS") >= 0, "Runtime perk unlock fallback symbol should use the budget constant")
	_expect(source.find("PERK_FALLBACK_SYMBOL_ARC_SEGMENTS") >= 0, "Runtime perk generic fallback symbol should use the budget constant")


func _dominant_channel(color_value: Variant) -> String:
	var color: Color = color_value
	if color.g >= color.r and color.g >= color.b:
		return "g"
	if color.b >= color.r and color.b >= color.g:
		return "b"
	return "r"


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
