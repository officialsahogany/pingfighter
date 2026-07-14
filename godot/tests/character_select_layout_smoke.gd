extends SceneTree

const CharacterSelectLayout := preload("res://scripts/ui/character_select_layout.gd")
const CharacterSelectScreen := preload("res://scripts/ui/character_select_screen.gd")

var failure_count := 0


func _init() -> void:
	var screen: Control = CharacterSelectScreen.new()
	screen.visible_indices = [0, 2, 3, 5]
	screen.hover_scales = [1.0, 1.0, 1.04, 1.01, 1.0, 0.98]
	screen.hover_lifts = [0.0, 0.0, 7.0, 2.0, 0.0, 4.0]

	for size_value in [
		Vector2(420.0, 600.0),
		Vector2(560.0, 900.0),
		Vector2(900.0, 1200.0),
		Vector2(1000.0, 900.0),
		Vector2(1920.0, 1080.0),
		Vector2(2560.0, 1440.0),
	]:
		var view_size: Vector2 = size_value
		var preview := CharacterSelectLayout.preview_rect(view_size)
		_expect(screen._card_column_rect(view_size) == CharacterSelectLayout.card_column_rect(view_size), "card-column facade should match its layout owner at %s" % view_size)
		_expect(screen._language_button_rect(view_size) == CharacterSelectLayout.language_button_rect(view_size), "language-button facade should match its layout owner at %s" % view_size)
		_expect(screen._preview_rect(view_size) == preview, "preview facade should match its layout owner at %s" % view_size)
		_expect(screen._full_body_rail_rect(view_size) == CharacterSelectLayout.full_body_rail_rect(view_size), "full-body rail facade should match its layout owner at %s" % view_size)
		_expect(screen._info_panel_rect(view_size, preview) == CharacterSelectLayout.info_panel_rect(view_size, preview), "info-panel facade should match its layout owner at %s" % view_size)
		_expect(is_equal_approx(screen._mobile_action_bar_bottom_y(view_size), CharacterSelectLayout.mobile_action_bar_bottom_y(view_size)), "mobile action anchor facade should match at %s" % view_size)
		_expect(is_equal_approx(screen._mobile_action_band_top(view_size), CharacterSelectLayout.mobile_action_band_top(view_size)), "mobile action band facade should match at %s" % view_size)
		_expect(is_equal_approx(screen._layout_right_margin(view_size), CharacterSelectLayout.layout_right_margin(view_size)), "right-margin facade should match at %s" % view_size)
		_expect(is_equal_approx(screen._info_panel_width(view_size), CharacterSelectLayout.info_panel_width(view_size)), "info width facade should match at %s" % view_size)
		_expect(screen._action_bar_layout(view_size) == CharacterSelectLayout.action_bar_layout(view_size, screen.LEAGUE_BUTTONS), "action-bar facade should match its layout owner at %s" % view_size)
		_expect(screen._layout_cards(view_size) == CharacterSelectLayout.layout_cards(view_size, screen.visible_indices, screen.hover_scales, screen.hover_lifts), "card layout facade should match its layout owner at %s" % view_size)

	var direct_buttons := CharacterSelectLayout.build_league_button_layout(
		screen.LEAGUE_BUTTONS,
		100.0,
		200.0,
		80.0,
		36.0,
		5.0
	)
	_expect(screen._build_league_button_layout(100.0, 200.0, 80.0, 36.0, 5.0) == direct_buttons, "league-button compatibility facade should preserve exact mode rects")
	_expect(direct_buttons.size() == screen.LEAGUE_BUTTONS.size(), "layout owner should emit one rect for every league mode")
	_expect(CharacterSelectLayout.layout_cards(Vector2(900.0, 700.0), [], [], []).is_empty(), "empty roster should produce no card rects")

	var font := ThemeDB.fallback_font
	var character := {
		"unlocked": true,
		"role": "FRONTLINE BREAKER",
		"character_name": "RENA",
		"class_name": "SMASHER",
		"tagline": "Break through every defense",
		"description": "First paragraph stays intact.\nSecond paragraph starts on a new line.",
		"lore_height": "172 cm",
		"lore_weight": "64 kg",
		"lore_affiliation": "RINGPIA",
	}
	var panel_rect := Rect2(100.0, 80.0, 520.0, 980.0)
	var owner_info := CharacterSelectLayout.build_info_panel_layout(panel_rect, character, font)
	var facade_info: Dictionary = screen._build_info_panel_layout(panel_rect, character, font)
	_expect(facade_info == owner_info, "info-panel layout facade should match its owner")
	_expect(screen._info_panel_visible_blocks(panel_rect, facade_info, true) == CharacterSelectLayout.info_panel_visible_blocks(panel_rect, owner_info, true), "info-panel block budget facade should match its owner")
	_expect(screen._layout_string_lines(owner_info, "description_lines") == CharacterSelectLayout.layout_string_lines(owner_info, "description_lines"), "layout string coercion facade should match its owner")
	_expect(screen._full_body_microstat_rows(character) == CharacterSelectLayout.full_body_microstat_rows(character), "microstat row facade should match its owner")
	_expect(CharacterSelectLayout.full_body_microstat_rows({}).is_empty(), "missing lore should emit no microstat rows")
	_expect(screen._badge_size(font, "SMASHER", 14) == CharacterSelectLayout.badge_size(font, "SMASHER", 14), "badge measurement facade should match its owner")
	var newline_lines := CharacterSelectLayout.wrapped_text_lines(font, "first sentence\nsecond sentence", 1000.0, 14, 4)
	_expect(newline_lines == ["first sentence", "second sentence"], "shared wrapping must preserve explicit newline paragraph boundaries")
	_expect(screen._get_wrapped_text_lines(font, "first sentence\nsecond sentence", 1000.0, 14, 4) == newline_lines, "wrapped-text facade should match its owner")
	var screen_source := FileAccess.get_file_as_string("res://scripts/ui/character_select_screen.gd")
	_expect(screen_source.find("return CharacterSelectLayout.action_bar_layout") >= 0, "action-bar source should delegate to the layout owner")
	_expect(screen_source.find("return CharacterSelectLayout.layout_cards") >= 0, "card-layout source should delegate to the layout owner")
	_expect(screen_source.find("return CharacterSelectLayout.build_info_panel_layout") >= 0, "info-panel source should delegate to the layout owner")
	_expect(screen_source.find("return CharacterSelectLayout.preview_rect") >= 0, "preview geometry source should delegate to the layout owner")
	_expect(screen_source.find("return CharacterSelectLayout.wrapped_text_lines") >= 0, "text-wrap source should delegate to the layout owner")

	screen.free()
	if failure_count > 0:
		quit(1)
		return
	print("character_select_layout_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
