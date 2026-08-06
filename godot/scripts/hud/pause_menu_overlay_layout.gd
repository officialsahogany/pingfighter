extends RefCounted

# Pure geometry owner for pause/options rendering and hit testing. The public
# pause-menu facade keeps its established `_get_*_rect()` methods so battle,
# main-menu, and smoke-test callers do not depend on this module directly.

const OPTIONS_PANEL_SIZE := Vector2(900.0, 500.0)
const BUTTON_SIZE := Vector2(250.0, 48.0)
const BUTTON_GAP := 14.0
const TITLE_HEIGHT := 82.0
const MAIN_ROW_PITCH := 96.0
const MAIN_ROW_HEIGHT := 92.0
const MAIN_ROW_START_RATIO := 0.36
const MAIN_ROW_BAR_WIDTH_RATIO := 0.62
const MAIN_LEFT_MARGIN := 92.0
const MAIN_SELECTED_BAR_HEIGHT := 88.0
const MAIN_TITLE_LEFT_MARGIN := 10.0
const MAIN_LIST_ANCHOR_RATIO := 0.25
const MAIN_SCROLL_PRIMARY_CENTER_RATIO := 0.18
const MAIN_SCROLL_PRIMARY_CENTER_MAX := 230.0
const MAIN_SCROLL_CAP_MIN_HALF_WIDTH := 4.0
const MAIN_SCROLL_CAP_MAX_HALF_WIDTH := 18.0
const MAIN_SCROLL_CAP_TEXT_GAP := 12.0
const SLIDER_HEIGHT := 10.0
const SLIDER_HIT_HEIGHT := 34.0

const SOUND_SLIDER_BGM := "bgm"
const CONTROL_DEVICE_JOYPAD := "joypad"


static func get_main_panel_rect(view_size: Vector2) -> Rect2:
	return Rect2(Vector2.ZERO, view_size)


static func get_main_row_pitch(panel_rect: Rect2) -> float:
	return clampf(panel_rect.size.y * 0.135, 64.0, MAIN_ROW_PITCH)


static func get_main_row_height(panel_rect: Rect2) -> float:
	return minf(MAIN_ROW_HEIGHT, maxf(50.0, get_main_row_pitch(panel_rect) - 4.0))


static func get_main_row_start_y(panel_rect: Rect2, entry_count: int) -> float:
	var resolved_entry_count := maxi(1, entry_count)
	var pitch := get_main_row_pitch(panel_rect)
	var height := get_main_row_height(panel_rect)
	var total_height := height + pitch * float(maxi(0, resolved_entry_count - 1))
	var minimum_start := minf(142.0, maxf(36.0, panel_rect.size.y * 0.18))
	var maximum_start := maxf(minimum_start, panel_rect.size.y - total_height - 48.0)
	var preferred_start := panel_rect.size.y * MAIN_ROW_START_RATIO
	return clampf(preferred_start, minimum_start, maximum_start)


static func get_main_bar_width(panel_rect: Rect2) -> float:
	var minimum_width := minf(260.0, panel_rect.size.x)
	var maximum_width := maxf(minimum_width, panel_rect.size.x - 24.0)
	return clampf(panel_rect.size.x * MAIN_ROW_BAR_WIDTH_RATIO, minimum_width, maximum_width)


static func get_main_row_band_rect(panel_rect: Rect2, index: int, entry_count: int) -> Rect2:
	var pitch := get_main_row_pitch(panel_rect)
	var height := get_main_row_height(panel_rect)
	var y := panel_rect.position.y + get_main_row_start_y(panel_rect, entry_count) + float(index) * pitch
	return Rect2(Vector2(panel_rect.position.x, y), Vector2(get_main_bar_width(panel_rect), height))


static func get_main_selection_bar_rect(selection_rect: Rect2) -> Rect2:
	var height := minf(MAIN_SELECTED_BAR_HEIGHT, maxf(50.0, selection_rect.size.y + 6.0))
	return Rect2(Vector2(0.0, selection_rect.get_center().y - height * 0.5), Vector2(maxf(selection_rect.size.x, 1.0), height))


static func get_main_left_margin(panel_rect: Rect2) -> float:
	return clampf(panel_rect.size.x * 0.072, 36.0, MAIN_LEFT_MARGIN)


static func get_main_title_left_margin(panel_rect: Rect2) -> float:
	return clampf(panel_rect.size.x * 0.012, 8.0, MAIN_TITLE_LEFT_MARGIN)


static func get_main_list_anchor_x(panel_rect: Rect2) -> float:
	return clampf(panel_rect.size.x * MAIN_LIST_ANCHOR_RATIO, 180.0, 270.0)


static func get_main_diamond_center_x(panel_rect: Rect2) -> float:
	return get_main_list_anchor_x(panel_rect)


static func get_main_unselected_text_x(panel_rect: Rect2) -> float:
	return get_main_diamond_center_x(panel_rect) + 18.0


static func get_main_scroll_cap_half_width(bar_rect: Rect2) -> float:
	return clampf(
		minf(bar_rect.size.y * 0.18, bar_rect.size.x * 0.026),
		MAIN_SCROLL_CAP_MIN_HALF_WIDTH,
		MAIN_SCROLL_CAP_MAX_HALF_WIDTH
	)


static func get_main_scroll_text_side_inset(bar_rect: Rect2) -> float:
	return get_main_scroll_cap_half_width(bar_rect) * 2.0 + MAIN_SCROLL_CAP_TEXT_GAP


static func get_main_selected_en_x(bar_rect: Rect2, text_width: float, local_left_x: float = -1.0) -> float:
	var side_inset := get_main_scroll_text_side_inset(bar_rect)
	var min_x := bar_rect.position.x + minf(side_inset, maxf(0.0, bar_rect.size.x - text_width))
	var max_x := bar_rect.end.x - text_width - side_inset
	if local_left_x >= 0.0:
		var inline_max_x := local_left_x - text_width - 20.0
		# An impossible inline helper stacks below; it must not pull the primary
		# label back underneath the compact scroll's left axis cap.
		if inline_max_x >= min_x:
			max_x = minf(max_x, inline_max_x)
	if max_x < min_x:
		return maxf(bar_rect.position.x + 8.0, max_x)
	var center_offset := clampf(
		bar_rect.size.x * MAIN_SCROLL_PRIMARY_CENTER_RATIO,
		side_inset + text_width * 0.5,
		minf(MAIN_SCROLL_PRIMARY_CENTER_MAX, bar_rect.size.x - side_inset - text_width * 0.5)
	)
	var measured_width_x := bar_rect.position.x + center_offset - text_width * 0.5
	return clampf(measured_width_x, min_x, max_x)


static func get_main_selected_local_x(bar_rect: Rect2, text_width: float) -> float:
	return bar_rect.end.x - text_width - 44.0


static func get_main_title_font_size(panel_rect: Rect2) -> int:
	return int(clampf(panel_rect.size.x * 0.060, 42.0, 66.0))


static func get_main_subtitle_font_size(panel_rect: Rect2) -> int:
	return int(clampf(panel_rect.size.x * 0.013, 13.0, 18.0))


static func get_main_entry_selected_font_size(rect: Rect2) -> int:
	return int(clampf(rect.size.y * 0.58, 38.0, 54.0))


static func get_main_entry_local_font_size(rect: Rect2) -> int:
	return int(clampf(rect.size.y * 0.24, 16.0, 22.0))


static func get_main_entry_idle_font_size(panel_rect: Rect2) -> int:
	return int(clampf(panel_rect.size.x * 0.026, 20.0, 32.0))


static func get_options_panel_rect(view_size: Vector2) -> Rect2:
	var size := Vector2(
		min(OPTIONS_PANEL_SIZE.x, max(560.0, view_size.x - 28.0)),
		min(OPTIONS_PANEL_SIZE.y, max(300.0, view_size.y - 28.0))
	)
	return Rect2((view_size - size) * 0.5, size)


static func get_sound_tab_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(92.0, 14.0), Vector2(106.0, 36.0))


static func get_display_tab_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(208.0, 14.0), Vector2(138.0, 36.0))


static func get_controls_tab_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(356.0, 14.0), Vector2(112.0, 36.0))


static func get_language_tab_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(478.0, 14.0), Vector2(122.0, 36.0))


static func get_reset_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(panel_rect.size.x - 142.0, 14.0), Vector2(124.0, 34.0))


static func get_button_rect(panel_rect: Rect2, index: int, count: int, main_entry_count: int) -> Rect2:
	if count == main_entry_count:
		return get_main_row_band_rect(panel_rect, clampi(index, 0, maxi(0, count - 1)), main_entry_count)
	var total_height: float = BUTTON_SIZE.y * float(count) + BUTTON_GAP * float(max(0, count - 1))
	var start_y: float = panel_rect.position.y + TITLE_HEIGHT + (panel_rect.size.y - TITLE_HEIGHT - total_height) * 0.5
	var button_center_x := panel_rect.get_center().x
	return Rect2(
		Vector2(button_center_x - BUTTON_SIZE.x * 0.5, start_y + float(index) * (BUTTON_SIZE.y + BUTTON_GAP)),
		BUTTON_SIZE
	)


static func get_slider_rect(slider_key: String, view_size: Vector2) -> Rect2:
	return get_slider_rect_from_panel(slider_key, get_options_panel_rect(view_size))


static func get_slider_rect_from_panel(slider_key: String, panel_rect: Rect2) -> Rect2:
	var y: float = panel_rect.position.y + (128.0 if slider_key == SOUND_SLIDER_BGM else 202.0)
	var slider_x: float = panel_rect.position.x + 250.0
	var slider_width: float = max(300.0, panel_rect.size.x - 388.0)
	return Rect2(Vector2(slider_x, y), Vector2(slider_width, SLIDER_HEIGHT))


static func get_slider_hit_rect(slider_key: String, view_size: Vector2) -> Rect2:
	return get_slider_hit_rect_from_panel(slider_key, get_options_panel_rect(view_size))


static func get_slider_hit_rect_from_panel(slider_key: String, panel_rect: Rect2) -> Rect2:
	var slider_rect: Rect2 = get_slider_rect_from_panel(slider_key, panel_rect)
	return Rect2(
		Vector2(slider_rect.position.x, slider_rect.get_center().y - SLIDER_HIT_HEIGHT * 0.5),
		Vector2(slider_rect.size.x, SLIDER_HIT_HEIGHT)
	)


static func get_back_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x - 72.0, panel_rect.end.y - 70.0), Vector2(144.0, 45.0))


static func get_display_fullscreen_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(280.0, 104.0), Vector2(124.0, 38.0))


static func get_display_exclusive_fullscreen_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(418.0, 104.0), Vector2(124.0, 38.0))


static func get_display_windowed_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(556.0, 104.0), Vector2(124.0, 38.0))


static func get_display_fps_cap_row_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(96.0, 188.0), Vector2(panel_rect.size.x - 192.0, 42.0))


static func get_display_fps_cap_value_rect(panel_rect: Rect2) -> Rect2:
	var row_rect: Rect2 = get_display_fps_cap_row_rect(panel_rect)
	return Rect2(row_rect.end - Vector2(212.0, 37.0), Vector2(190.0, 32.0))


static func get_display_vsync_row_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(96.0, 237.0), Vector2(panel_rect.size.x - 192.0, 42.0))


static func get_display_vsync_value_rect(panel_rect: Rect2) -> Rect2:
	var row_rect: Rect2 = get_display_vsync_row_rect(panel_rect)
	return Rect2(row_rect.end - Vector2(212.0, 37.0), Vector2(190.0, 32.0))


static func get_display_default_checkbox_rect(panel_rect: Rect2) -> Rect2:
	var row_rect: Rect2 = get_display_default_row_rect(panel_rect)
	return Rect2(row_rect.position + Vector2(18.0, 9.0), Vector2(22.0, 22.0))


static func get_display_default_row_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(96.0, 286.0), Vector2(panel_rect.size.x - 192.0, 40.0))


static func get_display_auto_refresh_checkbox_rect(panel_rect: Rect2) -> Rect2:
	var row_rect: Rect2 = get_display_auto_refresh_row_rect(panel_rect)
	return Rect2(row_rect.position + Vector2(18.0, 9.0), Vector2(22.0, 22.0))


static func get_display_auto_refresh_row_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(96.0, 330.0), Vector2(panel_rect.size.x - 192.0, 40.0))


static func get_display_pacing_recommendation_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(96.0, 378.0), Vector2(panel_rect.size.x - 192.0, 40.0))


static func get_display_recommended_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x - 376.0, panel_rect.end.y - 72.0), Vector2(170.0, 48.0))


static func get_display_apply_60hz_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x - 188.0, panel_rect.end.y - 72.0), Vector2(170.0, 48.0))


static func get_display_save_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x, panel_rect.end.y - 72.0), Vector2(170.0, 48.0))


static func get_display_back_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x + 188.0, panel_rect.end.y - 72.0), Vector2(170.0, 48.0))


static func get_controls_keyboard_mouse_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(214.0, 103.0), Vector2(178.0, 42.0))


static func get_controls_joypad_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(408.0, 103.0), Vector2(138.0, 42.0))


static func get_controls_vibration_row_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(96.0, 154.0), Vector2(panel_rect.size.x - 192.0, 42.0))


static func get_controls_vibration_value_rect(panel_rect: Rect2) -> Rect2:
	var row_rect: Rect2 = get_controls_vibration_row_rect(panel_rect)
	return Rect2(row_rect.end - Vector2(212.0, 37.0), Vector2(190.0, 32.0))


static func get_controls_mapping_row_rect(panel_rect: Rect2, index: int, device: String) -> Rect2:
	if device == CONTROL_DEVICE_JOYPAD:
		return Rect2(panel_rect.position + Vector2(96.0, 209.0 + float(index) * 32.0), Vector2(panel_rect.size.x - 192.0, 28.0))
	return Rect2(panel_rect.position + Vector2(96.0, 166.0 + float(index) * 43.0), Vector2(panel_rect.size.x - 192.0, 35.0))


static func get_controls_back_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x - 85.0, panel_rect.end.y - 72.0), Vector2(170.0, 48.0))


static func get_language_korean_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(116.0, 154.0), Vector2(130.0, 44.0))


static func get_language_english_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(264.0, 154.0), Vector2(130.0, 44.0))


static func get_language_chinese_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(412.0, 154.0), Vector2(130.0, 44.0))


static func get_language_japanese_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(560.0, 154.0), Vector2(130.0, 44.0))


static func get_language_spanish_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(116.0, 208.0), Vector2(130.0, 44.0))


static func get_language_portuguese_brazil_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(264.0, 208.0), Vector2(166.0, 44.0))


static func get_language_russian_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(448.0, 208.0), Vector2(130.0, 44.0))


static func get_language_note_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(panel_rect.position + Vector2(96.0, 292.0), Vector2(panel_rect.size.x - 192.0, 40.0))


static func get_language_back_button_rect(panel_rect: Rect2) -> Rect2:
	return Rect2(Vector2(panel_rect.get_center().x - 85.0, panel_rect.end.y - 72.0), Vector2(170.0, 48.0))
