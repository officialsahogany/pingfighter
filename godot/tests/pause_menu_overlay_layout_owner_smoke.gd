extends SceneTree

const PauseMenuOverlay := preload("res://scripts/hud/pause_menu_overlay.gd")
const PauseMenuOverlayLayout := preload("res://scripts/hud/pause_menu_overlay_layout.gd")

var _failures: Array[String] = []


func _init() -> void:
	var overlay := PauseMenuOverlay.new()
	_verify_geometry_parity(overlay)
	_verify_facade_delegation_contract()

	if _failures.is_empty():
		print("pause_menu_overlay_layout_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_geometry_parity(overlay: Object) -> void:
	var view_size := Vector2(1280.0, 720.0)
	var main_panel: Rect2 = overlay._get_main_panel_rect(view_size)
	var main_entry_count: int = overlay._get_main_entries().size()
	_expect_rect(
		main_panel,
		PauseMenuOverlayLayout.get_main_panel_rect(view_size),
		"main panel should delegate to the layout owner"
	)
	_expect_close(
		overlay._get_main_row_pitch(main_panel),
		PauseMenuOverlayLayout.get_main_row_pitch(main_panel),
		"main row pitch should match the layout owner"
	)
	_expect_rect(
		overlay._get_main_row_band_rect(main_panel, 2),
		PauseMenuOverlayLayout.get_main_row_band_rect(main_panel, 2, main_entry_count),
		"main row band should preserve the current entry-count contract"
	)

	var options_panel: Rect2 = overlay._get_options_panel_rect(view_size)
	_expect_rect(
		options_panel,
		PauseMenuOverlayLayout.get_options_panel_rect(view_size),
		"options panel should delegate to the layout owner"
	)
	_expect_rect(
		overlay._get_sound_tab_rect(options_panel),
		PauseMenuOverlayLayout.get_sound_tab_rect(options_panel),
		"sound tab should match the layout owner"
	)
	_expect_rect(
		overlay._get_slider_hit_rect_from_panel("bgm", options_panel),
		PauseMenuOverlayLayout.get_slider_hit_rect_from_panel("bgm", options_panel),
		"BGM slider hit geometry should match the layout owner"
	)
	_expect_rect(
		overlay._get_display_fps_cap_value_rect(options_panel),
		PauseMenuOverlayLayout.get_display_fps_cap_value_rect(options_panel),
		"display FPS value geometry should match the layout owner"
	)
	_expect_rect(
		overlay._get_display_auto_refresh_checkbox_rect(options_panel),
		PauseMenuOverlayLayout.get_display_auto_refresh_checkbox_rect(options_panel),
		"display auto-refresh checkbox should match the layout owner"
	)
	_expect_rect(
		overlay._get_language_portuguese_brazil_rect(options_panel),
		PauseMenuOverlayLayout.get_language_portuguese_brazil_rect(options_panel),
		"wide Portuguese language button should match the layout owner"
	)

	overlay.controls_device_view = "keyboard_mouse"
	_expect_rect(
		overlay._get_controls_mapping_row_rect(options_panel, 3),
		PauseMenuOverlayLayout.get_controls_mapping_row_rect(options_panel, 3, "keyboard_mouse"),
		"keyboard mapping row should match the layout owner"
	)
	overlay.controls_device_view = "joypad"
	_expect_rect(
		overlay._get_controls_mapping_row_rect(options_panel, 3),
		PauseMenuOverlayLayout.get_controls_mapping_row_rect(options_panel, 3, "joypad"),
		"joypad mapping row should match the layout owner"
	)


func _verify_facade_delegation_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	var delegations := {
		"_get_main_panel_rect": "PauseMenuOverlayLayout.get_main_panel_rect",
		"_get_main_row_pitch": "PauseMenuOverlayLayout.get_main_row_pitch",
		"_get_main_row_height": "PauseMenuOverlayLayout.get_main_row_height",
		"_get_main_row_start_y": "PauseMenuOverlayLayout.get_main_row_start_y",
		"_get_main_bar_width": "PauseMenuOverlayLayout.get_main_bar_width",
		"_get_main_row_band_rect": "PauseMenuOverlayLayout.get_main_row_band_rect",
		"_get_main_selection_bar_rect": "PauseMenuOverlayLayout.get_main_selection_bar_rect",
		"_get_main_left_margin": "PauseMenuOverlayLayout.get_main_left_margin",
		"_get_main_title_left_margin": "PauseMenuOverlayLayout.get_main_title_left_margin",
		"_get_main_list_anchor_x": "PauseMenuOverlayLayout.get_main_list_anchor_x",
		"_get_main_diamond_center_x": "PauseMenuOverlayLayout.get_main_diamond_center_x",
		"_get_main_unselected_text_x": "PauseMenuOverlayLayout.get_main_unselected_text_x",
		"_get_main_selected_en_x": "PauseMenuOverlayLayout.get_main_selected_en_x",
		"_get_main_scroll_cap_half_width": "PauseMenuOverlayLayout.get_main_scroll_cap_half_width",
		"_get_main_selected_local_x": "PauseMenuOverlayLayout.get_main_selected_local_x",
		"_get_main_subtitle_font_size": "PauseMenuOverlayLayout.get_main_subtitle_font_size",
		"_get_main_entry_selected_font_size": "PauseMenuOverlayLayout.get_main_entry_selected_font_size",
		"_get_main_entry_local_font_size": "PauseMenuOverlayLayout.get_main_entry_local_font_size",
		"_get_main_entry_idle_font_size": "PauseMenuOverlayLayout.get_main_entry_idle_font_size",
		"_get_options_panel_rect": "PauseMenuOverlayLayout.get_options_panel_rect",
		"_get_sound_tab_rect": "PauseMenuOverlayLayout.get_sound_tab_rect",
		"_get_display_tab_rect": "PauseMenuOverlayLayout.get_display_tab_rect",
		"_get_controls_tab_rect": "PauseMenuOverlayLayout.get_controls_tab_rect",
		"_get_language_tab_rect": "PauseMenuOverlayLayout.get_language_tab_rect",
		"_get_reset_button_rect": "PauseMenuOverlayLayout.get_reset_button_rect",
		"_get_button_rect": "PauseMenuOverlayLayout.get_button_rect",
		"_get_slider_rect": "PauseMenuOverlayLayout.get_slider_rect",
		"_get_slider_rect_from_panel": "PauseMenuOverlayLayout.get_slider_rect_from_panel",
		"_get_slider_hit_rect": "PauseMenuOverlayLayout.get_slider_hit_rect",
		"_get_slider_hit_rect_from_panel": "PauseMenuOverlayLayout.get_slider_hit_rect_from_panel",
		"_get_back_button_rect": "PauseMenuOverlayLayout.get_back_button_rect",
		"_get_display_fullscreen_rect": "PauseMenuOverlayLayout.get_display_fullscreen_rect",
		"_get_display_exclusive_fullscreen_rect": "PauseMenuOverlayLayout.get_display_exclusive_fullscreen_rect",
		"_get_display_windowed_rect": "PauseMenuOverlayLayout.get_display_windowed_rect",
		"_get_display_fps_cap_row_rect": "PauseMenuOverlayLayout.get_display_fps_cap_row_rect",
		"_get_display_fps_cap_value_rect": "PauseMenuOverlayLayout.get_display_fps_cap_value_rect",
		"_get_display_vsync_row_rect": "PauseMenuOverlayLayout.get_display_vsync_row_rect",
		"_get_display_vsync_value_rect": "PauseMenuOverlayLayout.get_display_vsync_value_rect",
		"_get_display_default_checkbox_rect": "PauseMenuOverlayLayout.get_display_default_checkbox_rect",
		"_get_display_default_row_rect": "PauseMenuOverlayLayout.get_display_default_row_rect",
		"_get_display_auto_refresh_checkbox_rect": "PauseMenuOverlayLayout.get_display_auto_refresh_checkbox_rect",
		"_get_display_auto_refresh_row_rect": "PauseMenuOverlayLayout.get_display_auto_refresh_row_rect",
		"_get_display_pacing_recommendation_rect": "PauseMenuOverlayLayout.get_display_pacing_recommendation_rect",
		"_get_display_recommended_button_rect": "PauseMenuOverlayLayout.get_display_recommended_button_rect",
		"_get_display_apply_60hz_button_rect": "PauseMenuOverlayLayout.get_display_apply_60hz_button_rect",
		"_get_display_save_button_rect": "PauseMenuOverlayLayout.get_display_save_button_rect",
		"_get_display_back_button_rect": "PauseMenuOverlayLayout.get_display_back_button_rect",
		"_get_controls_keyboard_mouse_rect": "PauseMenuOverlayLayout.get_controls_keyboard_mouse_rect",
		"_get_controls_joypad_rect": "PauseMenuOverlayLayout.get_controls_joypad_rect",
		"_get_controls_vibration_row_rect": "PauseMenuOverlayLayout.get_controls_vibration_row_rect",
		"_get_controls_vibration_value_rect": "PauseMenuOverlayLayout.get_controls_vibration_value_rect",
		"_get_controls_mapping_row_rect": "PauseMenuOverlayLayout.get_controls_mapping_row_rect",
		"_get_controls_back_button_rect": "PauseMenuOverlayLayout.get_controls_back_button_rect",
		"_get_language_korean_rect": "PauseMenuOverlayLayout.get_language_korean_rect",
		"_get_language_english_rect": "PauseMenuOverlayLayout.get_language_english_rect",
		"_get_language_chinese_rect": "PauseMenuOverlayLayout.get_language_chinese_rect",
		"_get_language_japanese_rect": "PauseMenuOverlayLayout.get_language_japanese_rect",
		"_get_language_spanish_rect": "PauseMenuOverlayLayout.get_language_spanish_rect",
		"_get_language_portuguese_brazil_rect": "PauseMenuOverlayLayout.get_language_portuguese_brazil_rect",
		"_get_language_russian_rect": "PauseMenuOverlayLayout.get_language_russian_rect",
		"_get_language_note_rect": "PauseMenuOverlayLayout.get_language_note_rect",
		"_get_language_back_button_rect": "PauseMenuOverlayLayout.get_language_back_button_rect",
	}
	for function_name: String in delegations:
		var body := _source_function_body(source, "func %s(" % function_name)
		_expect(
			body.contains(str(delegations[function_name])),
			"%s should delegate geometry to the layout owner" % function_name
		)


func _source_function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + signature.length())
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)


func _expect_rect(actual: Rect2, expected: Rect2, message: String) -> void:
	_expect(actual.is_equal_approx(expected), "%s (expected %s, found %s)" % [message, expected, actual])


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s (expected %.4f, found %.4f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
