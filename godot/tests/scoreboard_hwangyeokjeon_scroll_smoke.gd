extends SceneTree

const ScoreboardOverlayRenderer := preload("res://scripts/hud/scoreboard_overlay_renderer.gd")
const ScoreboardOverlayHeaderRenderer := preload("res://scripts/hud/scoreboard_overlay_header_renderer.gd")
const ScoreboardOverlayScorePanelRenderer := preload("res://scripts/hud/scoreboard_overlay_score_panel_renderer.gd")
const ScoreboardOverlayFooterRenderer := preload("res://scripts/hud/scoreboard_overlay_footer_renderer.gd")
const ScoreboardOverlayVictoryRenderer := preload("res://scripts/hud/scoreboard_overlay_victory_renderer.gd")
const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const PlayerCharacterPortraitCatalog := preload("res://scripts/characters/player_character_portrait_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const SCROLL_TEXTURE_PATH := "res://assets/sprites/hud/round_result_hwangyeokjeon_scroll_imagegen_v1.png"
const CEREMONIAL_BAK_TEXTURE_PATH := "res://assets/sprites/hud/scoreboard_victory_ceremonial_bak_imagegen_v1.png"
const CEREMONIAL_BAK_RIGHT_TEXTURE_PATH := "res://assets/sprites/hud/scoreboard_victory_ceremonial_bak_right_imagegen_v1.png"
const BRUSH_FONT_PATH := "res://assets/fonts/NanumBrushScript-Regular.ttf"
const BRUSH_FONT_LICENSE_PATH := "res://assets/fonts/NanumBrushScript-OFL.txt"

var _failures: Array[String] = []


func _init() -> void:
	_verify_scroll_asset_contract()
	_verify_unfurl_timeline_contract()
	_verify_victory_timeline_contract()
	_verify_victory_celebration_contract()
	_verify_runtime_name_contract()
	_verify_ink_score_contract()
	_verify_high_resolution_brush_digit_asset()
	_verify_polish_layout_contract()
	_verify_round_result_information_contract()
	_verify_stage_clear_victory_contract()

	if _failures.is_empty():
		print("scoreboard_hwangyeokjeon_scroll_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_scroll_asset_contract() -> void:
	_expect(FileAccess.file_exists(SCROLL_TEXTURE_PATH), "round-result scroll PNG should exist")
	var texture := ResourceLoader.load(SCROLL_TEXTURE_PATH) as Texture2D
	_expect(texture != null, "round-result scroll PNG should import as Texture2D")
	if texture != null:
		var size: Vector2 = texture.get_size()
		_expect(size.x >= 1200.0 and size.y >= 640.0, "scroll source should retain enough resolution for a 680x380 overlay")
		_expect(absf(size.x / size.y - 680.0 / 380.0) < 0.08, "scroll source aspect should closely match the live scoreboard")

	var frame_source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_overlay_frame_renderer.gd")
	_expect(frame_source.contains(SCROLL_TEXTURE_PATH), "scoreboard frame renderer should own the scroll texture path")
	_expect(frame_source.contains("ProjectResourceLoader"), "scoreboard frame renderer should load the PNG through the project cache")
	_expect(FileAccess.file_exists(BRUSH_FONT_PATH), "round-result brush font should ship with the project")
	_expect(ResourceLoader.load(BRUSH_FONT_PATH) is Font, "round-result brush font should import as a Godot Font")
	_expect(FileAccess.file_exists(BRUSH_FONT_LICENSE_PATH), "round-result brush font should retain its OFL license")


func _verify_unfurl_timeline_contract() -> void:
	var renderer := ScoreboardOverlayRenderer.new()
	var open_method := "_resolve_scroll_open_progress"
	var content_method := "_resolve_scroll_content_alpha"
	_expect(renderer.has_method(open_method), "scoreboard overlay should expose deterministic scroll-open timing")
	_expect(renderer.has_method(content_method), "scoreboard overlay should expose deterministic ink-content timing")
	if not renderer.has_method(open_method) or not renderer.has_method(content_method):
		return

	var start_open: float = float(renderer.call(open_method, 0.0))
	var mid_open: float = float(renderer.call(open_method, 0.14))
	var end_open: float = float(renderer.call(open_method, 0.40))
	_expect(start_open <= 0.10, "scroll should begin almost closed")
	_expect(mid_open > start_open and mid_open < end_open, "scroll opening should advance monotonically")
	_expect(end_open >= 0.99, "scroll should be fully open before the hold phase")

	var early_content: float = float(renderer.call(content_method, 0.05))
	var late_content: float = float(renderer.call(content_method, 0.40))
	_expect(early_content <= 0.01, "text and scores should stay hidden during the first unfurl beat")
	_expect(late_content >= 0.99, "text and scores should finish inking after the scroll opens")


func _verify_victory_timeline_contract() -> void:
	var victory := ScoreboardOverlayVictoryRenderer.new()
	var before: Dictionary = victory.resolve_presentation(0.38)
	var portrait_hit: Dictionary = victory.resolve_presentation(0.40)
	var before_stamp: Dictionary = victory.resolve_presentation(0.47)
	var stamp_hit: Dictionary = victory.resolve_presentation(0.49)
	var settled: Dictionary = victory.resolve_presentation(0.70)
	_expect(float(before.get("portrait_alpha", 1.0)) <= 0.01, "victory portrait should wait until after the shared content reveal")
	_expect(float(portrait_hit.get("portrait_scale", 1.0)) >= 1.17, "victory portrait should enter with a 1.18 punch")
	_expect(float(portrait_hit.get("flash_alpha", 0.0)) >= 0.99, "portrait punch should own a short backflash")
	_expect(float(before_stamp.get("text_alpha", 1.0)) <= 0.01, "victory stamp should wait 0.08 seconds after the portrait")
	_expect(float(stamp_hit.get("text_scale", 1.0)) >= 1.25, "victory stamp should land with a strong scale punch")
	_expect(is_equal_approx(float(settled.get("portrait_scale", 0.0)), 1.0), "portrait should settle to authored scale")
	_expect(is_equal_approx(float(settled.get("text_scale", 0.0)), 1.0), "victory stamp should settle to authored scale")
	var portrait_rect := Rect2(190.0, 100.0, 120.0, 120.0)
	var plaque_rect: Rect2 = victory.resolve_plaque_rect(portrait_rect)
	var stamp_rect: Rect2 = victory.resolve_stamp_rect(
		portrait_rect,
		plaque_rect,
		Vector2(48.0, 32.0),
		1.40
	)
	_expect(stamp_rect.position.x >= portrait_rect.end.x + 3.9, "stamp overshoot must never enter the portrait face rect")
	_expect(stamp_rect.end.x <= plaque_rect.end.x - 5.9, "stamp overshoot should remain inside the plaque's paper bay")
	_expect(stamp_rect.end.y <= plaque_rect.end.y - 11.9, "stamp should clear the plaque's bottom rail")
	var board_rect := Rect2(30.0, 179.0, 700.0, 700.0 / (680.0 / 380.0))
	var centered_portrait: Rect2 = victory.call("_resolve_portrait_rect", board_rect, 1.0)
	var centered_plaque: Rect2 = victory.resolve_plaque_rect(centered_portrait)
	_expect(
		absf(centered_plaque.get_center().x - board_rect.get_center().x) <= 12.0,
		"final-victory plaque should optically continue the scroll center axis"
	)
	_expect(
		centered_plaque.end.y <= board_rect.position.y + 4.0,
		"final-victory plaque should hover just above the scroll instead of covering its header"
	)


func _verify_victory_celebration_contract() -> void:
	_expect(FileAccess.file_exists(CEREMONIAL_BAK_TEXTURE_PATH), "ceremonial bak cutout should ship with the victory overlay")
	_expect(FileAccess.file_exists(CEREMONIAL_BAK_RIGHT_TEXTURE_PATH), "mirrored ceremonial bak cutout should avoid mutating the caller draw transform")
	var texture := ResourceLoader.load(CEREMONIAL_BAK_TEXTURE_PATH) as Texture2D
	var right_texture := ResourceLoader.load(CEREMONIAL_BAK_RIGHT_TEXTURE_PATH) as Texture2D
	_expect(texture != null, "ceremonial bak cutout should import as Texture2D")
	_expect(right_texture != null, "mirrored ceremonial bak cutout should import as Texture2D")
	if texture != null:
		var texture_size: Vector2 = texture.get_size()
		_expect(texture_size.x >= 500.0 and texture_size.y >= 900.0, "ceremonial bak source should retain clean ribbon detail")

	var victory := ScoreboardOverlayVictoryRenderer.new()
	var before: Dictionary = victory.resolve_celebration_presentation(0.60)
	var opening: Dictionary = victory.resolve_celebration_presentation(0.74)
	var settled: Dictionary = victory.resolve_celebration_presentation(1.10)
	_expect(float(before.get("ornament_alpha", 1.0)) <= 0.01, "celebration bak should wait until the victory plaque lands")
	_expect(float(opening.get("open_progress", 0.0)) > 0.0, "celebration bak should begin opening after the plaque beat")
	_expect(float(settled.get("open_progress", 0.0)) >= 0.99, "celebration bak should settle fully open during the hold")
	_expect(float(settled.get("confetti_progress", 0.0)) >= 0.99, "obangsaek paper should reach its celebration hold")

	var board_rect := Rect2(30.0, 179.0, 700.0, 700.0 / (680.0 / 380.0))
	var left_rect: Rect2 = victory.resolve_celebration_bak_rect(board_rect, false)
	var right_rect: Rect2 = victory.resolve_celebration_bak_rect(board_rect, true)
	_expect(left_rect.end.x < board_rect.get_center().x - 80.0, "left ceremonial bak should stay clear of the winner plaque")
	_expect(right_rect.position.x > board_rect.get_center().x + 80.0, "right ceremonial bak should stay clear of the winner plaque")
	_expect(is_equal_approx(left_rect.size.y, right_rect.size.y), "ceremonial bak pair should share one visual scale")


func _verify_runtime_name_contract() -> void:
	var header_source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_overlay_header_renderer.gd")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_overlay_renderer.gd")
	var context_source := FileAccess.get_file_as_string("res://scripts/core/battle_draw_playfield_scene_context.gd")
	_expect(not header_source.contains("환격전 승부 방목"), "round-result scroll should omit the redundant title")
	_expect(not header_source.contains("도전자") and not header_source.contains("수문장"), "round-result scroll should omit generic side labels")
	_expect(not overlay_source.contains("장원에 오른다"), "round-result scroll should omit the decorative footer sentence")
	_expect(context_source.contains('"selected_character_name"'), "playfield draw context should project the selected character display name")

	LanguageSettings.set_test_locale_override("ko")
	var header := ScoreboardOverlayHeaderRenderer.new()
	_expect(
		header.resolve_player_name({"selected_character_name": "한미량", "selected_character_type": "smasher"}) == "한미량",
		"scoreboard should preserve the live selected character name"
	)
	_expect(
		header.resolve_player_name({"selected_character_name": "스매셔", "selected_character_type": "smasher"}) == "한미량",
		"scoreboard should replace a legacy class label with the character name"
	)
	_expect(
		header.resolve_player_name({"selected_character_name": "격령사", "selected_character_type": "smasher"}) == "한미량",
		"scoreboard must show Han Miryang instead of the Hwangyeok class name"
	)
	_expect(header.format_round_title(9) == "제 9합 종료", "scoreboard header should announce the finished bout number")
	_expect(header.format_round_title(0) == "라운드 종료", "scoreboard header should retain a safe generic result title")
	_expect(header_source.contains("_fit_font_size"), "scoreboard names should shrink to remain inside their nameplates")
	_expect(header_source.contains("_draw_title_clearance"), "round title should clear the frame line behind its text bay")
	_expect(header_source.contains("NAME_FONT_MAX := 20.0"), "player names should remain below the score hierarchy")
	_expect(header.resolve_boss_name({"current_stage": 1, "stage1_boss_variant": "dalji"}) == "달지", "Stage 1 Dalji scoreboard name should resolve")
	_expect(header.resolve_boss_name({"current_stage": 1, "stage1_boss_variant": "gaksi"}) == "각시탈", "Stage 1 Gaksital scoreboard name should resolve")
	_expect(header.resolve_boss_name({"current_stage": 1, "stage1_boss_variant": "podo"}) == "포도대장", "Stage 1 Pododaejang scoreboard name should resolve")
	_expect(header.resolve_boss_name({"current_stage": 8}) == "미노타우로스", "Stage 8 scoreboard name should resolve")
	LanguageSettings.set_test_locale_override("")


func _verify_ink_score_contract() -> void:
	var panel_source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_overlay_score_panel_renderer.gd")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_overlay_renderer.gd")
	_expect(not panel_source.contains("ScoreboardLedDigits"), "round-result scores should no longer use cyber LED dots")
	_expect(not panel_source.contains("NanumBrushScript-Regular.ttf"), "round-result scores should not fall back to a typographic brush font")
	_expect(panel_source.contains("SCOREBOARD_OVERLAY_HWANGYEOK_DIGITS_TEXTURE_PATH"), "round-result scores should use the dedicated high-resolution hand-painted 0-9 atlas path")
	_expect(panel_source.contains("ScoreboardTopMiniDigitAtlasRenderer"), "round-result scores should share the accepted optical digit metrics")
	_expect(panel_source.contains("ProjectResourceLoader.get_cached_texture"), "round-result scores should consume the existing prewarmed atlas cache")
	_expect(not panel_source.contains("const BRUSH_DIGIT_ATLAS: Texture2D = preload"), "round-result scores should not create a second owner for the high-resolution atlas resource")
	_expect(overlay_source.contains('"scoreboard_overlay_hwangyeok_digits_texture"'), "production overlay should forward the dedicated prewarmed high-resolution atlas from battle textures")
	_expect(overlay_source.contains("brush_digit_texture"), "production overlay should pass the shared brush atlas into the score panel")
	_expect(panel_source.contains("resolve_brush_digit_source_scale"), "round-result scores should map the 3x source atlas without changing optical layout metrics")
	_expect(panel_source.contains("draw_texture_rect_region"), "round-result scores should render atlas regions instead of font glyphs")
	_expect(panel_source.contains("SCORE_INK_BLEED_ALPHA") and panel_source.contains("SCORE_INK_CORE_ALPHA"), "brush digits should retain restrained hanji bleed and ink-density variation")
	_expect(panel_source.contains("SCORE_BASELINE_Y_RATIO := 0.0"), "atlas scores should use their normalized visual center instead of the old font baseline shift")
	_expect(panel_source.contains("_draw_winner_ink_wash"), "the scoring side should receive a restrained red ink wash")
	_expect(panel_source.contains("_draw_mountain_layers") and panel_source.contains("_draw_mist_bands"), "score fields should contain low-density ink scenery")
	_expect(panel_source.contains("_draw_victory_seal"), "the scoring side should receive a small score seal")
	_expect(panel_source.contains('"승" if match_finished else "득"'), "score seal should distinguish a winning point from an ordinary point")
	_expect(panel_source.contains("_draw_stamp_ink_layers"), "victory seal should include restrained ink-density variation")
	_expect(panel_source.contains("_draw_stamp_broken_border") and panel_source.contains("_draw_stamp_flecks"), "victory seal should read as an imperfect paper stamp")
	_expect(not panel_source.contains('"對"'), "round-result score panel should omit the decorative versus glyph")


func _verify_high_resolution_brush_digit_asset() -> void:
	var path: String = BattleResources.SCOREBOARD_OVERLAY_HWANGYEOK_DIGITS_TEXTURE_PATH
	var texture := ResourceLoader.load(path) as Texture2D
	_expect(texture != null, "round-result high-resolution brush digit atlas must import as Texture2D")
	if texture != null:
		_expect(texture.get_size() == Vector2(3840.0, 768.0), "imported round-result atlas must retain its full 3x resolution")
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	_expect(not image.is_empty(), "round-result high-resolution brush digit atlas must load")
	if image.is_empty():
		return
	_expect(image.get_size() == Vector2i(3840, 768), "round-result brush atlas must remain 10x2 384px cells")
	var expected_widths := [236, 167, 231, 215, 234, 228, 226, 229, 208, 214]
	for digit in range(10):
		var min_x := 384
		var min_y := 384
		var max_x := -1
		var max_y := -1
		var visible_pixel_count := 0
		var core_inside_body := true
		var border_clean := true
		for y in range(384):
			for x in range(384):
				var body := image.get_pixel(digit * 384 + x, y)
				var core := image.get_pixel(digit * 384 + x, 384 + y)
				if body.a >= 32.0 / 255.0:
					visible_pixel_count += 1
					min_x = mini(min_x, x)
					min_y = mini(min_y, y)
					max_x = maxi(max_x, x)
					max_y = maxi(max_y, y)
				if core.a > body.a + 0.001:
					core_inside_body = false
		for edge_index in range(384):
			if (
				image.get_pixel(digit * 384, edge_index).a > 0.001
				or image.get_pixel(digit * 384 + 383, edge_index).a > 0.001
				or image.get_pixel(digit * 384 + edge_index, 0).a > 0.001
				or image.get_pixel(digit * 384 + edge_index, 383).a > 0.001
			):
				border_clean = false
		_expect(core_inside_body, "high-resolution digit %d core must remain inside its body" % digit)
		_expect(border_clean, "high-resolution digit %d must keep a clean transparent cell border" % digit)
		_expect(max_x - min_x + 1 == int(expected_widths[digit]), "high-resolution digit %d must retain its 3x optical width" % digit)
		_expect(min_y >= 48 and min_y <= 52, "high-resolution digit %d must retain the common optical cap top" % digit)
		_expect(max_y >= 324 and max_y <= 335, "high-resolution digit %d must retain the common optical cap bottom" % digit)
		var optical_box_area: int = (max_x - min_x + 1) * (max_y - min_y + 1)
		var visible_coverage: float = float(visible_pixel_count) / maxf(1.0, float(optical_box_area))
		if digit == 0:
			_expect(visible_coverage >= 0.48, "high-resolution digit 0 must not regress to a broken, over-gapped oval stroke")
		elif digit == 1:
			_expect(visible_coverage >= 0.39, "high-resolution digit 1 must keep a continuous downstroke and foot")
	var hole_probes := {
		0: [Vector2i(192, 192)],
		6: [Vector2i(192, 228)],
		8: [Vector2i(192, 144), Vector2i(192, 234)],
		9: [Vector2i(192, 144)],
	}
	for digit_value in hole_probes.keys():
		var digit: int = int(digit_value)
		for probe_value in hole_probes[digit_value]:
			var probe: Vector2i = probe_value
			_expect(
				image.get_pixel(digit * 384 + probe.x, probe.y).a <= 0.02,
				"high-resolution digit %d internal counter must stay open at %s" % [digit, str(probe)]
			)
	var resources := BattleResources.new()
	var core_specs: Array = resources._get_core_texture_specs()
	_expect(_has_texture_spec_path(core_specs, path), "battle core prewarm must include the round-result high-resolution brush atlas")


func _verify_polish_layout_contract() -> void:
	var board_rect := Rect2(30.0, 179.0, 700.0, 700.0 / (680.0 / 380.0))
	var header := ScoreboardOverlayHeaderRenderer.new()
	var title_center: Vector2 = header.resolve_round_title_center(board_rect)
	_expect(is_equal_approx(title_center.x, board_rect.get_center().x), "round title should remain centered on the scroll")
	_expect(title_center.y > board_rect.position.y + board_rect.size.y * 0.14, "round title should keep breathing room below the top ornament")

	var panel := ScoreboardOverlayScorePanelRenderer.new()
	var override_texture := PlaceholderTexture2D.new()
	override_texture.size = Vector2(1280.0, 256.0)
	_expect(panel.resolve_brush_digit_texture(override_texture) == override_texture, "capture and test paths should be able to provide the shared atlas explicitly")
	var high_resolution_texture := PlaceholderTexture2D.new()
	high_resolution_texture.size = Vector2(3840.0, 768.0)
	_expect(is_equal_approx(panel.resolve_brush_digit_source_scale(high_resolution_texture), 3.0), "round-result renderer should map each high-resolution atlas cell at exactly 3x source scale")
	var score_panel_rect := Rect2(0.0, 0.0, 212.0, 164.0)
	_expect(is_equal_approx(panel.SCORE_PANEL_CONTENT_SCALE, 0.87), "round-result scores should use a centered 87 percent content area")
	for digit in range(10):
		var digit_layout: Dictionary = panel.build_score_number_layout(score_panel_rect, digit)
		var digit_content_rects: Array = digit_layout.get("content_rects", [])
		_expect(digit_content_rects.size() == 1, "single score digit should produce exactly one atlas region")
		var cap_ratio: float = float(digit_layout.get("cap_height", 0.0)) / score_panel_rect.size.y
		_expect(cap_ratio >= 0.79 and cap_ratio <= 0.81, "single score digit should retain the final restrained panel breathing room")
		if digit_content_rects.size() == 1:
			var content_rect: Rect2 = digit_content_rects[0]
			_expect(score_panel_rect.grow(-7.0).encloses(content_rect), "score digit optical body should retain visible space from the panel frame")
	var one_layout: Dictionary = panel.build_score_number_layout(score_panel_rect, 1)
	var one_content_rects: Array = one_layout.get("content_rects", [])
	_expect(one_content_rects.size() == 1 and (one_content_rects[0] as Rect2).size.x >= score_panel_rect.size.x * 0.33, "narrow digit 1 should remain visually dominant after the final scale adjustment")
	var ten_layout: Dictionary = panel.build_score_number_layout(score_panel_rect, 10)
	_expect(float(ten_layout.get("total_width", 999.0)) <= float(ten_layout.get("max_width", 0.0)) + 0.01, "two-digit score should fit inside the shared panel width cap")
	var ten_cap_ratio: float = float(ten_layout.get("cap_height", 0.0)) / score_panel_rect.size.y
	_expect(ten_cap_ratio >= 0.71 and ten_cap_ratio <= 0.73, "two-digit score should retain hierarchy at the final restrained scale")
	var six_offset: Vector2 = panel.resolve_score_optical_offset(6, 150.0)
	_expect(six_offset.y > 0.0, "brush digit 6 should retain a small optical vertical correction")
	_expect(panel.resolve_score_optical_offset(6, 150.0) == six_offset, "score optical correction should be side-independent")

	var footer_source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_overlay_footer_renderer.gd")
	_expect(footer_source.contains("1.0 - FOOTER_COLUMN_X_RATIO"), "footer columns should mirror around the central seal")
	_expect(footer_source.contains("FOOTER_TEXT_WIDTH_RATIO := 0.215"), "footer copy should keep a clear gap around the central seal")
	_expect(not footer_source.contains("draw_circle(\n\t\tcenter,"), "central result seal should not retain the stray center dot")


func _verify_round_result_information_contract() -> void:
	var footer := ScoreboardOverlayFooterRenderer.new()
	var regular: Dictionary = footer.resolve_rule_copy(false, 10)
	_expect(str(regular.get("left", "")) == "정규전", "regular footer should identify the match phase")
	_expect(str(regular.get("right", "")) == "7점 승리", "regular footer goal should stay fixed at seven")
	for overtime_goal in [8, 9, 10, 11]:
		var overtime: Dictionary = footer.resolve_rule_copy(true, overtime_goal)
		var expected_goal: int = mini(overtime_goal, 10)
		_expect(str(overtime.get("left", "")) == "연장전", "overtime footer should stay latched after entry")
		_expect(str(overtime.get("right", "")) == "%d점 승리" % expected_goal, "overtime footer should show the canonical capped goal")

	var footer_source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_overlay_footer_renderer.gd")
	_expect(not footer_source.contains("득점"), "footer should not duplicate the scoring player name")
	_expect(not footer_source.contains("다음 합 준비"), "footer should not restore the old transition copy")

	var overlay := ScoreboardOverlayRenderer.new()
	var state := ScoreboardState.new()
	state.start(6, 5, false, "player", 7, false, 8)
	_expect(not overlay.resolve_overtime_mode(state, 6, 5), "6:5 should remain regular time")
	_expect(overlay.resolve_victory_goal(state, 6, 5, 7) == 7, "regular match goal should remain seven")
	for case_value in [
		[6, 6, 8],
		[7, 6, 8],
		[7, 7, 9],
		[8, 7, 9],
		[8, 8, 10],
		[9, 8, 10],
		[9, 9, 10],
	]:
		var score_case: Array = case_value
		var player_score: int = int(score_case[0])
		var boss_score: int = int(score_case[1])
		var target_goal: int = int(score_case[2])
		state.start(player_score, boss_score, false, "player", 7, true, target_goal)
		_expect(overlay.resolve_overtime_mode(state, player_score, boss_score), "overtime state should remain latched after 6:6")
		_expect(overlay.resolve_victory_goal(state, player_score, boss_score, 7) == target_goal, "scoreboard should consume the stored overtime goal")

	_expect(overlay.resolve_emphasis_side("player", 4, 5) == "player", "trailing player score should still highlight the player column")
	_expect(overlay.resolve_emphasis_side("boss", 5, 4) == "boss", "trailing boss score should still highlight the boss column")
	_expect(overlay.resolve_emphasis_side("player", 6, 6) == "player", "tying score should preserve the actual scorer highlight")
	_expect(is_equal_approx(overlay.resolve_score_column_alpha_scale(0.82, "player", "player"), 1.0), "recent scorer should stay fully opaque while trailing")
	_expect(is_equal_approx(overlay.resolve_score_column_alpha_scale(0.82, "boss", "player"), 0.82), "non-scoring column should preserve its normal hierarchy alpha")

	var entry_early: Dictionary = footer.resolve_overtime_entry_presentation(0.30, true)
	var entry_mid: Dictionary = footer.resolve_overtime_entry_presentation(0.48, true)
	var entry_settled: Dictionary = footer.resolve_overtime_entry_presentation(0.80, true)
	_expect(float(entry_early.get("goal_alpha", 1.0)) <= 0.01, "overtime goal should wait for the entry beat")
	_expect(float(entry_mid.get("goal_alpha", 0.0)) > 0.0, "overtime goal should fade in during the entry beat")
	_expect(is_equal_approx(float(entry_settled.get("state_scale", 0.0)), 1.0), "overtime label should settle without continuous animation")


func _verify_stage_clear_victory_contract() -> void:
	var overlay := ScoreboardOverlayRenderer.new()
	var state := ScoreboardState.new()
	state.start(7, 4, true, "player", 7)
	_expect(overlay.is_player_stage_clear(state), "player match victory should enable the stage-clear portrait")
	_expect(is_equal_approx(overlay.resolve_boss_alpha_scale(state), 0.65), "final loser name and score should dim by 35 percent")
	state.start(3, 1, false, "player", 7)
	_expect(not overlay.is_player_stage_clear(state), "ordinary player points must not enable the stage-clear portrait")
	_expect(is_equal_approx(overlay.resolve_boss_alpha_scale(state), 0.82), "ordinary rounds should gently recede the trailing score column")
	state.start(4, 7, true, "boss", 7)
	_expect(not overlay.is_player_stage_clear(state), "boss match victory must not show the player victory portrait")
	_expect(is_equal_approx(overlay.resolve_player_alpha_scale(state), 0.65), "boss match victory should dim the losing player column by 35 percent")

	var victory := ScoreboardOverlayVictoryRenderer.new()
	_expect(victory.format_victory_text("한미량") == "승리", "stage-clear stamp should avoid repeating the header name")
	_expect(victory.format_seal_text("한미량") == "한", "small red seal should use the winner name's first character")
	_expect(victory.format_seal_text("") == "印", "small red seal should retain a non-repeating fallback mark")
	var battle_resources := BattleResources.new()
	for character_type in ["smasher", "soldier", "blacksmith", "optimus", "viper"]:
		var portrait_spec: Dictionary = PlayerCharacterPortraitCatalog.get_portrait_spec(character_type)
		var portrait_path := str(portrait_spec.get("path", ""))
		_expect(FileAccess.file_exists(portrait_path), "%s scoreboard portrait source should exist" % character_type)
		var specs: Array = battle_resources._get_player_texture_specs(character_type, false)
		_expect(_has_texture_spec_path(specs, portrait_path), "%s battle prewarm should include its scoreboard portrait" % character_type)

	var victory_source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_overlay_victory_renderer.gd")
	_expect(not victory_source.contains("ProjectResourceLoader"), "victory portrait draw must consume prewarmed battle textures")
	_expect(victory_source.contains("PLAYER_COLUMN_CENTER_X_RATIO := 0.468"), "final-victory plaque should use the scroll-centered optical correction")
	_expect(victory_source.contains("_draw_plaque_hangers"), "victory portrait should read as a hanging plaque rather than a generic avatar box")
	_expect(victory_source.contains("_draw_plaque_crown"), "victory plaque should share the scroll's restrained traditional ornament rhythm")
	_expect(victory_source.contains("_draw_hanji_bay_texture"), "victory plaque should carry a subtle hanji surface treatment")
	_expect(victory_source.contains("_draw_winner_name_slip"), "victory plaque should retain a clear full-name auxiliary label")
	_expect(victory_source.contains("CEREMONIAL_BAK_TEXTURE"), "final victory should preload the ceremonial bak ornament outside the hot draw path")
	_expect(victory_source.contains("_draw_obangsaek_confetti"), "final victory should own a restrained obangsaek paper fall")
	_expect(not victory_source.contains("draw_set_transform"), "victory celebration must preserve the battle canvas game-offset transform")
	_expect(victory_source.contains("BACKFLASH_RING_COUNT := 12"), "MIX backflash should use enough bands to hide circle stepping")
	_expect(victory_source.contains("BACKFLASH_MAX_ALPHA := 0.76"), "MIX backflash should reach light rather than low-luminance gray")
	_expect(victory_source.contains("plaque_rect.position.y - HANGER_RISE"), "plaque hangers should extend into visible space above the plaque body")
	_expect(victory_source.contains("var apex := Vector2"), "plaque hanger lines should converge on one apex")
	_expect(victory_source.contains("_draw_vertical_calligraphy"), "right plaque bay should contain vertical victory calligraphy from the portrait beat")
	_expect(victory_source.contains("_draw_backflash(canvas, plaque_rect.get_center(), plaque_rect.size.y, flash_alpha)"), "backflash should center on the plaque but size from its height")
	_expect(victory_source.contains("BAY_PAPER_LIGHT"), "calligraphy bay should separate from the portrait with a slightly lighter paper tone")
	_expect(victory_source.contains("plaque_rect.end.y - 8.0"), "plaque tassels should clear the scoreboard name band")
	_expect(victory_source.contains("Color(PAPER_LIGHT.r, PAPER_LIGHT.g, PAPER_LIGHT.b"), "victory seal should use light lettering on a red stamp")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_overlay_renderer.gd")
	_expect(overlay_source.contains("\t\t\talpha,\n\t\t\tdraw_context,\n\t\t\tplayer_name,\n\t\t\tscoreboard_timer"), "victory timing should be independent and the seal should receive the resolved winner name")
	_expect(
		overlay_source.find("victory_renderer.draw_backflash") < overlay_source.find("header_renderer.draw"),
		"backflash should render below header names so the winner remains readable"
	)
	_expect(
		overlay_source.find("victory_renderer.draw_celebration_back") < overlay_source.find("frame_renderer.draw"),
		"ceremonial ribbons and paper should stay behind the readable result scroll"
	)
	var panel_source := FileAccess.get_file_as_string("res://scripts/hud/scoreboard_overlay_score_panel_renderer.gd")
	_expect(panel_source.contains("FINAL_SCORE_SEAL_ALPHA_SCALE := 0.74"), "final score seal should remain a supporting victory mark")
	_expect(panel_source.contains("FINAL_SCORE_SEAL_SIZE_SCALE := 0.90"), "final score seal should remain below the plaque hierarchy")


func _has_texture_spec_path(specs: Array, expected_path: String) -> bool:
	for spec_value in specs:
		if spec_value is Dictionary and str((spec_value as Dictionary).get("path", "")) == expected_path:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
