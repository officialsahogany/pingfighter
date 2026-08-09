extends RefCounted

const PauseMenuMainRenderer := preload("res://scripts/hud/pause_menu_main_renderer.gd")
const PauseMenuOverlayLayout := preload("res://scripts/hud/pause_menu_overlay_layout.gd")
const PauseMenuOptionsNavigationPolicy := preload("res://scripts/hud/pause_menu_options_navigation_policy.gd")
const PremiumPanelFrame := preload("res://scripts/hud/premium_panel_frame.gd")
const RuntimePerkTraditionalChrome := preload("res://scripts/hud/runtime_perk_traditional_chrome.gd")

const SLIDER_HANDLE_RADIUS := 8.0
const OPTIONS_TAB_SOUND := PauseMenuOptionsNavigationPolicy.TAB_SOUND
const OPTIONS_TAB_DISPLAY := PauseMenuOptionsNavigationPolicy.TAB_DISPLAY
const OPTIONS_TAB_CONTROLS := PauseMenuOptionsNavigationPolicy.TAB_CONTROLS
const OPTIONS_TAB_LANGUAGE := PauseMenuOptionsNavigationPolicy.TAB_LANGUAGE
const CONTROL_DEVICE_JOYPAD := PauseMenuOptionsNavigationPolicy.DEVICE_JOYPAD
const SOUND_SLIDER_BGM := "bgm"
const SOUND_SLIDER_SFX := "sfx"

# Keep the established compatibility palette public here. The pause-menu
# facade aliases these constants for callers that still preload the facade.
const PANEL_COLOR := Color(0.070, 0.055, 0.045, 0.92)
const PANEL_BORDER := Color(0.36, 0.78, 0.98, 0.90)
const HEADER_COLOR := Color(0.090, 0.070, 0.045, 0.94)
const SECTION_COLOR := Color(0.045, 0.036, 0.030, 0.55)
const BUTTON_COLOR := Color(0.080, 0.062, 0.044, 0.90)
const BUTTON_HOVER := Color(0.10, 0.18, 0.28, 0.96)
const BUTTON_SELECTED := Color(0.14, 0.24, 0.36, 1.0)
const BUTTON_BORDER := Color(0.36, 0.78, 0.98, 0.55)
const SLIDER_BACK := Color(0.055, 0.044, 0.036, 1.0)
const TEXT_DIM := Color(0.62, 0.72, 0.84)
const ACCENT_BLUE := Color(0.36, 0.78, 0.98)
const ACCENT_GREEN := Color(0.0, 1.0, 0.47)
const ACCENT_GOLD := Color(1.0, 0.80, 0.20)
const NEON_CYAN := Color(0.36, 0.78, 0.98)
const NEON_CYAN_HOT := Color(0.66, 0.92, 1.00)
const RESONANCE_MAG := Color(0.72, 0.50, 1.00)
const NEON_GREEN := Color(0.00, 1.00, 0.47)
const WARM_GOLD := Color(1.00, 0.80, 0.20)
const TEXT_WARM := Color(0.94, 0.99, 1.00)

const INK := PauseMenuMainRenderer.INK
const INK_DIM := Color(0.55, 0.66, 0.80)
const SELECT_BLUE := PauseMenuMainRenderer.SELECT_BLUE
const SPIRIT_BLUE := PauseMenuMainRenderer.SPIRIT_BLUE
const OPT_SLIDER_BGM_FILL := SPIRIT_BLUE
const OPT_SLIDER_SFX_FILL := RuntimePerkTraditionalChrome.JADE
const OPT_PANEL := PANEL_COLOR
const OPT_HEADER := HEADER_COLOR
const OPT_CARD := Color(0.082, 0.064, 0.046, 0.95)
const OPT_CARD_HOVER := Color(0.100, 0.078, 0.054, 0.98)
const OPT_BORDER := Color(0.62, 0.52, 0.30, 0.34)
const OPT_TRACK := SLIDER_BACK
const OPT_CHECK_ON := Color(0.0, 0.82, 0.46)


func draw_window(
	canvas: CanvasItem,
	font: Font,
	panel_rect: Rect2,
	mouse_pos: Vector2,
	snapshot: Dictionary
) -> void:
	var options_tab := str(snapshot.get("options_tab", OPTIONS_TAB_SOUND))
	var options_focus := int(snapshot.get("options_focus", 0))
	draw_options_header(canvas, panel_rect)
	draw_neon_line(
		canvas,
		panel_rect.position + Vector2(14.0, 62.0),
		Vector2(panel_rect.end.x - 14.0, panel_rect.position.y + 62.0),
		Color(SELECT_BLUE.r, SELECT_BLUE.g, SELECT_BLUE.b, 0.60),
		1.5
	)
	_draw_text(canvas, font, str(snapshot.get("settings_title", "")), panel_rect.position + Vector2(28.0, 40.0), 24, INK)
	draw_tab(canvas, font, PauseMenuOverlayLayout.get_sound_tab_rect(panel_rect), str(snapshot.get("sound_tab_label", "")), options_tab == OPTIONS_TAB_SOUND, "sound")
	draw_tab(canvas, font, PauseMenuOverlayLayout.get_display_tab_rect(panel_rect), str(snapshot.get("display_tab_label", "")), options_tab == OPTIONS_TAB_DISPLAY, "display")
	draw_tab(canvas, font, PauseMenuOverlayLayout.get_controls_tab_rect(panel_rect), str(snapshot.get("controls_tab_label", "")), options_tab == OPTIONS_TAB_CONTROLS, "controls")
	draw_tab(canvas, font, PauseMenuOverlayLayout.get_language_tab_rect(panel_rect), str(snapshot.get("language_tab_label", "")), options_tab == OPTIONS_TAB_LANGUAGE, "language")
	draw_button(canvas, font, PauseMenuOverlayLayout.get_reset_button_rect(panel_rect), str(snapshot.get("reset_label", "")), false, mouse_pos)

	var content_rect := Rect2(panel_rect.position + Vector2(28.0, 84.0), Vector2(panel_rect.size.x - 56.0, panel_rect.size.y - 166.0))
	draw_panel(canvas, content_rect, OPT_CARD, OPT_BORDER, 1.0, false, false, PremiumPanelFrame.KIND_SECTION)
	if options_tab == OPTIONS_TAB_DISPLAY:
		draw_display_tab(canvas, font, panel_rect, mouse_pos, snapshot)
	elif options_tab == OPTIONS_TAB_CONTROLS:
		draw_controls_tab(canvas, font, panel_rect, mouse_pos, snapshot)
	elif options_tab == OPTIONS_TAB_LANGUAGE:
		draw_language_tab(canvas, font, panel_rect, mouse_pos, snapshot)
	else:
		draw_volume_slider(
			canvas,
			font,
			SOUND_SLIDER_BGM,
			str(snapshot.get("bgm_label", "")),
			float(snapshot.get("bgm_volume", 0.0)),
			OPT_SLIDER_BGM_FILL,
			options_focus == 0,
			mouse_pos,
			panel_rect
		)
		draw_volume_slider(
			canvas,
			font,
			SOUND_SLIDER_SFX,
			str(snapshot.get("sfx_label", "")),
			float(snapshot.get("sfx_volume", 0.0)),
			OPT_SLIDER_SFX_FILL,
			options_focus == 1,
			mouse_pos,
			panel_rect
		)

	if options_tab == OPTIONS_TAB_SOUND:
		draw_button(
			canvas,
			font,
			PauseMenuOverlayLayout.get_back_button_rect(panel_rect),
			str(snapshot.get("back_label", "")),
			options_focus == 2,
			mouse_pos
		)


func draw_display_tab(
	canvas: CanvasItem,
	font: Font,
	panel_rect: Rect2,
	mouse_pos: Vector2,
	snapshot: Dictionary
) -> void:
	var options_focus := int(snapshot.get("options_focus", 0))
	var display_mode := str(snapshot.get("display_mode", ""))
	var pulse_alpha := float(snapshot.get("focus_pulse_alpha", 1.0))
	_draw_text(canvas, font, str(snapshot.get("display_mode_label", "")), panel_rect.position + Vector2(54.0, 137.0), 19, INK)
	draw_mode_pill(canvas, font, PauseMenuOverlayLayout.get_display_fullscreen_rect(panel_rect), str(snapshot.get("fullscreen_label", "")), display_mode == str(snapshot.get("fullscreen_mode", "fullscreen")), options_focus == 0, mouse_pos)
	draw_mode_pill(canvas, font, PauseMenuOverlayLayout.get_display_exclusive_fullscreen_rect(panel_rect), str(snapshot.get("exclusive_fullscreen_label", "")), display_mode == str(snapshot.get("exclusive_fullscreen_mode", "exclusive_fullscreen")), options_focus == 0, mouse_pos)
	draw_mode_pill(canvas, font, PauseMenuOverlayLayout.get_display_windowed_rect(panel_rect), str(snapshot.get("windowed_label", "")), display_mode == str(snapshot.get("windowed_mode", "windowed")), options_focus == 0, mouse_pos)
	_draw_text(canvas, font, str(snapshot.get("display_mode_description", "")), panel_rect.position + Vector2(280.0, 162.0), 13, INK_DIM)

	draw_setting_select_row(
		canvas,
		font,
		PauseMenuOverlayLayout.get_display_fps_cap_row_rect(panel_rect),
		PauseMenuOverlayLayout.get_display_fps_cap_value_rect(panel_rect),
		str(snapshot.get("render_fps_label", "")),
		str(snapshot.get("render_fps_value", "")),
		options_focus == 1,
		mouse_pos,
		pulse_alpha
	)
	draw_setting_select_row(
		canvas,
		font,
		PauseMenuOverlayLayout.get_display_vsync_row_rect(panel_rect),
		PauseMenuOverlayLayout.get_display_vsync_value_rect(panel_rect),
		str(snapshot.get("vsync_label", "VSync")),
		str(snapshot.get("vsync_value", "")),
		options_focus == 2,
		mouse_pos,
		pulse_alpha
	)
	draw_toggle_setting_row(
		canvas,
		font,
		PauseMenuOverlayLayout.get_display_default_row_rect(panel_rect),
		PauseMenuOverlayLayout.get_display_default_checkbox_rect(panel_rect),
		str(snapshot.get("remember_title", "")),
		str(snapshot.get("remember_subtitle", "")),
		bool(snapshot.get("remember_display_mode", false)),
		options_focus == 3,
		mouse_pos,
		false,
		pulse_alpha
	)
	draw_toggle_setting_row(
		canvas,
		font,
		PauseMenuOverlayLayout.get_display_auto_refresh_row_rect(panel_rect),
		PauseMenuOverlayLayout.get_display_auto_refresh_checkbox_rect(panel_rect),
		str(snapshot.get("auto_refresh_title", "")),
		str(snapshot.get("auto_refresh_subtitle", "")),
		bool(snapshot.get("auto_refresh_rate_60hz", false)),
		options_focus == 4,
		mouse_pos,
		true,
		pulse_alpha
	)
	draw_recommendation_block(canvas, font, PauseMenuOverlayLayout.get_display_pacing_recommendation_rect(panel_rect), str(snapshot.get("pacing_recommendation", "")))
	draw_button(canvas, font, PauseMenuOverlayLayout.get_display_recommended_button_rect(panel_rect), str(snapshot.get("recommended_label", "")), options_focus == 5, mouse_pos)
	draw_button(canvas, font, PauseMenuOverlayLayout.get_display_apply_60hz_button_rect(panel_rect), str(snapshot.get("apply_60hz_label", "")), options_focus == 6, mouse_pos)
	draw_button(canvas, font, PauseMenuOverlayLayout.get_display_save_button_rect(panel_rect), str(snapshot.get("save_label", "")), options_focus == 7, mouse_pos)
	draw_button(canvas, font, PauseMenuOverlayLayout.get_display_back_button_rect(panel_rect), str(snapshot.get("back_label", "")), options_focus == 8, mouse_pos)


func draw_controls_tab(
	canvas: CanvasItem,
	font: Font,
	panel_rect: Rect2,
	mouse_pos: Vector2,
	snapshot: Dictionary
) -> void:
	var options_focus := int(snapshot.get("options_focus", 0))
	var device_view := str(snapshot.get("controls_device_view", ""))
	var pulse_alpha := float(snapshot.get("focus_pulse_alpha", 1.0))
	_draw_text(canvas, font, str(snapshot.get("controls_device_label", "")), panel_rect.position + Vector2(54.0, 137.0), 19, INK)
	draw_mode_pill(canvas, font, PauseMenuOverlayLayout.get_controls_keyboard_mouse_rect(panel_rect), str(snapshot.get("keyboard_mouse_label", "")), device_view == str(snapshot.get("keyboard_mouse_device", "keyboard_mouse")), options_focus == 0, mouse_pos)
	draw_mode_pill(canvas, font, PauseMenuOverlayLayout.get_controls_joypad_rect(panel_rect), str(snapshot.get("joypad_label", "")), device_view == CONTROL_DEVICE_JOYPAD, options_focus == 0, mouse_pos)
	if device_view == CONTROL_DEVICE_JOYPAD:
		draw_setting_select_row(
			canvas,
			font,
			PauseMenuOverlayLayout.get_controls_vibration_row_rect(panel_rect),
			PauseMenuOverlayLayout.get_controls_vibration_value_rect(panel_rect),
			str(snapshot.get("vibration_label", "")),
			str(snapshot.get("vibration_value", "")),
			options_focus == 1,
			mouse_pos,
			pulse_alpha
		)
	var mapping_rows: Array = snapshot.get("control_mapping_rows", [])
	for index in range(mapping_rows.size()):
		var row: Dictionary = mapping_rows[index]
		draw_control_mapping_row(
			canvas,
			font,
			PauseMenuOverlayLayout.get_controls_mapping_row_rect(panel_rect, index, device_view),
			str(row.get("label", "")),
			str(row.get("value", ""))
		)
	draw_button(
		canvas,
		font,
		PauseMenuOverlayLayout.get_controls_back_button_rect(panel_rect),
		str(snapshot.get("back_label", "")),
		options_focus == int(snapshot.get("controls_back_focus_index", 0)),
		mouse_pos
	)


func draw_language_tab(
	canvas: CanvasItem,
	font: Font,
	panel_rect: Rect2,
	mouse_pos: Vector2,
	snapshot: Dictionary
) -> void:
	var options_focus := int(snapshot.get("options_focus", 0))
	_draw_text(canvas, font, str(snapshot.get("language_title", "")), panel_rect.position + Vector2(54.0, 137.0), 19, INK)
	var language_options: Array = snapshot.get("language_options", [])
	var language_rects: Array[Rect2] = [
		PauseMenuOverlayLayout.get_language_korean_rect(panel_rect),
		PauseMenuOverlayLayout.get_language_english_rect(panel_rect),
		PauseMenuOverlayLayout.get_language_chinese_rect(panel_rect),
		PauseMenuOverlayLayout.get_language_japanese_rect(panel_rect),
		PauseMenuOverlayLayout.get_language_spanish_rect(panel_rect),
		PauseMenuOverlayLayout.get_language_portuguese_brazil_rect(panel_rect),
		PauseMenuOverlayLayout.get_language_russian_rect(panel_rect),
	]
	for index in range(mini(language_options.size(), language_rects.size())):
		var option: Dictionary = language_options[index]
		draw_mode_pill(
			canvas,
			font,
			language_rects[index],
			str(option.get("label", "")),
			bool(option.get("selected", false)),
			options_focus == index,
			mouse_pos
		)
	_draw_text(canvas, font, str(snapshot.get("current_language_label", "")), panel_rect.position + Vector2(96.0, 260.0), 18, INK)
	draw_recommendation_block(canvas, font, PauseMenuOverlayLayout.get_language_note_rect(panel_rect), str(snapshot.get("language_subtitle", "")))
	draw_button(canvas, font, PauseMenuOverlayLayout.get_language_back_button_rect(panel_rect), str(snapshot.get("back_label", "")), options_focus == 7, mouse_pos)


func draw_options_header(canvas: CanvasItem, panel_rect: Rect2) -> void:
	var top_rect := Rect2(panel_rect.position + Vector2(12.0, 3.0), Vector2(maxf(0.0, panel_rect.size.x - 24.0), 59.0))
	var body_rect := Rect2(panel_rect.position + Vector2(3.0, 12.0), Vector2(maxf(0.0, panel_rect.size.x - 6.0), 50.0))
	canvas.draw_rect(top_rect, OPT_HEADER)
	canvas.draw_rect(body_rect, OPT_HEADER)


func draw_tab(canvas: CanvasItem, font: Font, rect: Rect2, label: String, active_tab: bool, icon_kind: String = "") -> void:
	var draw_rect := rect
	if active_tab:
		draw_rect.position.y -= 2.0
	var fill := SELECT_BLUE if active_tab else OPT_CARD
	var border := SELECT_BLUE if active_tab else OPT_BORDER
	draw_panel(canvas, draw_rect, fill, border, 1.0)
	if active_tab:
		draw_neon_line(canvas, Vector2(draw_rect.position.x + 4.0, draw_rect.end.y), Vector2(draw_rect.end.x - 4.0, draw_rect.end.y), SELECT_BLUE, 1.2)
	var label_rect := draw_rect
	if not icon_kind.is_empty():
		var icon_rect := Rect2(draw_rect.position + Vector2(10.0, (draw_rect.size.y - 18.0) * 0.5), Vector2(18.0, 18.0))
		var icon_color := Color.WHITE if active_tab else INK_DIM
		draw_tab_icon(canvas, icon_kind, icon_rect, icon_color)
		label_rect = Rect2(draw_rect.position + Vector2(29.0, 0.0), Vector2(maxf(0.0, draw_rect.size.x - 31.0), draw_rect.size.y))
	_draw_text_in_rect(canvas, font, label, label_rect, 15, Color.WHITE if active_tab else INK)


func draw_tab_icon(canvas: CanvasItem, kind: String, icon_rect: Rect2, color: Color) -> void:
	var center := icon_rect.get_center()
	match kind:
		"sound":
			canvas.draw_colored_polygon(
				PackedVector2Array([
					icon_rect.position + Vector2(2.0, 7.0),
					icon_rect.position + Vector2(6.0, 7.0),
					icon_rect.position + Vector2(11.0, 3.0),
					icon_rect.position + Vector2(11.0, 15.0),
					icon_rect.position + Vector2(6.0, 11.0),
					icon_rect.position + Vector2(2.0, 11.0),
				]),
				color
			)
			canvas.draw_arc(center + Vector2(3.0, 0.0), 5.0, -0.8, 0.8, 12, color, 1.2)
			canvas.draw_arc(center + Vector2(3.0, 0.0), 8.0, -0.7, 0.7, 12, Color(color.r, color.g, color.b, color.a * 0.70), 1.0)
		"display":
			var screen := Rect2(icon_rect.position + Vector2(2.0, 3.0), Vector2(14.0, 10.0))
			canvas.draw_rect(screen, color, false, 1.2)
			canvas.draw_line(Vector2(center.x, screen.end.y), Vector2(center.x, screen.end.y + 3.0), color, 1.2)
			canvas.draw_line(Vector2(center.x - 5.0, screen.end.y + 3.0), Vector2(center.x + 5.0, screen.end.y + 3.0), color, 1.2)
		"controls":
			var body := Rect2(icon_rect.position + Vector2(1.5, 5.0), Vector2(15.0, 9.0))
			var radius := body.size.y * 0.5
			var left_center := body.position + Vector2(radius, radius)
			var right_center := Vector2(body.end.x - radius, body.position.y + radius)
			canvas.draw_arc(left_center, radius, PI * 0.5, PI * 1.5, 10, color, 1.2)
			canvas.draw_arc(right_center, radius, -PI * 0.5, PI * 0.5, 10, color, 1.2)
			canvas.draw_line(Vector2(left_center.x, body.position.y), Vector2(right_center.x, body.position.y), color, 1.2)
			canvas.draw_line(Vector2(left_center.x, body.end.y), Vector2(right_center.x, body.end.y), color, 1.2)
			var dpad_center := body.position + Vector2(4.5, 4.5)
			canvas.draw_line(dpad_center + Vector2(-2.5, 0.0), dpad_center + Vector2(2.5, 0.0), color, 1.1)
			canvas.draw_line(dpad_center + Vector2(0.0, -2.5), dpad_center + Vector2(0.0, 2.5), color, 1.1)
			canvas.draw_circle(body.position + Vector2(10.5, 3.2), 1.2, color)
			canvas.draw_circle(body.position + Vector2(13.0, 5.8), 1.2, color)
		"language":
			canvas.draw_arc(center, 7.0, 0.0, TAU, 24, color, 1.2)
			canvas.draw_arc(center, 3.5, -PI * 0.5, PI * 0.5, 16, color, 1.0)
			canvas.draw_arc(center, 3.5, PI * 0.5, PI * 1.5, 16, color, 1.0)
			canvas.draw_line(center + Vector2(-6.0, -2.5), center + Vector2(6.0, -2.5), Color(color.r, color.g, color.b, color.a * 0.72), 1.0)
			canvas.draw_line(center + Vector2(-6.0, 2.5), center + Vector2(6.0, 2.5), Color(color.r, color.g, color.b, color.a * 0.72), 1.0)


func draw_scanlines(canvas: CanvasItem, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var color := Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.04)
	var start_y := int(rect.position.y) + 2
	var end_y := int(rect.end.y)
	for y in range(start_y, end_y, 3):
		canvas.draw_line(Vector2(rect.position.x, float(y)), Vector2(rect.end.x, float(y)), color, 1.0)


func draw_volume_slider(
	canvas: CanvasItem,
	font: Font,
	slider_key: String,
	label: String,
	value: float,
	accent: Color,
	focused: bool,
	mouse_pos: Vector2,
	panel_rect: Rect2
) -> void:
	var slider_rect := PauseMenuOverlayLayout.get_slider_rect_from_panel(slider_key, panel_rect)
	var row_center_y := slider_rect.get_center().y
	_draw_text(canvas, font, label, Vector2(panel_rect.position.x + 54.0, row_center_y + 7.0), 18, INK)
	canvas.draw_rect(slider_rect, OPT_TRACK)
	var fill_rect := Rect2(slider_rect.position, Vector2(slider_rect.size.x * clampf(value, 0.0, 1.0), slider_rect.size.y))
	canvas.draw_rect(fill_rect, accent)
	var handle_x := slider_rect.position.x + slider_rect.size.x * clampf(value, 0.0, 1.0)
	var hit_rect := PauseMenuOverlayLayout.get_slider_hit_rect_from_panel(slider_key, panel_rect)
	var handle_color := SELECT_BLUE if focused or hit_rect.has_point(mouse_pos) else Color(0.55, 0.62, 0.72)
	canvas.draw_circle(Vector2(handle_x, row_center_y), SLIDER_HANDLE_RADIUS + (2.0 if focused else 0.0), handle_color)
	var percent := "%d%%" % int(round(value * 100.0))
	_draw_text(canvas, font, percent, Vector2(slider_rect.end.x + 18.0, row_center_y + 6.0), 15, INK)


func draw_control_mapping_row(canvas: CanvasItem, font: Font, rect: Rect2, label: String, value: String) -> void:
	draw_panel(canvas, rect, OPT_CARD, OPT_BORDER, 1.0)
	var label_size: int = 16 if rect.size.y >= 34.0 else 14
	var value_size: int = 15 if rect.size.y >= 34.0 else 13
	var baseline_y := minf(27.0, rect.size.y - 8.0)
	_draw_text(canvas, font, label, rect.position + Vector2(18.0, baseline_y), label_size, INK)
	_draw_text(canvas, font, value, rect.position + Vector2(220.0, baseline_y), value_size, INK_DIM)


func draw_mode_pill(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	label: String,
	selected: bool,
	focused: bool,
	mouse_pos: Vector2
) -> void:
	var hovered := rect.has_point(mouse_pos)
	var fill := SELECT_BLUE if selected else OPT_CARD
	if hovered and not selected:
		fill = OPT_CARD_HOVER
	var border := SELECT_BLUE if selected or focused or hovered else OPT_BORDER
	draw_panel(canvas, rect, fill, border, 2.0 if selected or focused else 1.0)
	_draw_text_in_rect(canvas, font, label, rect, 17, Color.WHITE if selected else INK)


func draw_setting_select_row(
	canvas: CanvasItem,
	font: Font,
	row_rect: Rect2,
	value_rect: Rect2,
	label: String,
	value: String,
	focused: bool,
	mouse_pos: Vector2,
	pulse_alpha: float = 1.0
) -> void:
	var hovered := row_rect.has_point(mouse_pos)
	var fill := OPT_CARD_HOVER if hovered or focused else OPT_CARD
	var border := SELECT_BLUE if hovered or focused else OPT_BORDER
	draw_panel(canvas, row_rect, fill, border, 1.0)
	_draw_text(canvas, font, label, row_rect.position + Vector2(18.0, 29.0), 16, INK)
	draw_panel(canvas, value_rect, OPT_TRACK, OPT_BORDER, 1.0)
	var chevrons := get_select_chevron_rects(value_rect)
	var left_rect: Rect2 = chevrons["left"]
	var right_rect: Rect2 = chevrons["right"]
	var left_color := INK if left_rect.has_point(mouse_pos) else SELECT_BLUE
	var right_color := INK if right_rect.has_point(mouse_pos) else SELECT_BLUE
	var left_center := Vector2(value_rect.position.x + 14.0, value_rect.get_center().y)
	var right_center := Vector2(value_rect.end.x - 14.0, value_rect.get_center().y)
	canvas.draw_colored_polygon(
		PackedVector2Array([
			left_center + Vector2(4.0, -7.0),
			left_center + Vector2(-5.0, 0.0),
			left_center + Vector2(4.0, 7.0),
		]),
		left_color
	)
	canvas.draw_colored_polygon(
		PackedVector2Array([
			right_center + Vector2(-4.0, -7.0),
			right_center + Vector2(5.0, 0.0),
			right_center + Vector2(-4.0, 7.0),
		]),
		right_color
	)
	_draw_text_in_rect(canvas, font, value, value_rect, 15, INK)
	if focused:
		draw_holo_focus_frame(canvas, row_rect, pulse_alpha)


func draw_toggle_setting_row(
	canvas: CanvasItem,
	font: Font,
	row_rect: Rect2,
	checkbox_rect: Rect2,
	title: String,
	subtitle: String,
	enabled: bool,
	focused: bool,
	mouse_pos: Vector2,
	muted: bool = false,
	pulse_alpha: float = 1.0
) -> void:
	var hovered := row_rect.has_point(mouse_pos)
	var fill := OPT_CARD_HOVER if hovered or focused else OPT_CARD
	var border := SELECT_BLUE if hovered or focused else OPT_BORDER
	draw_panel(canvas, row_rect, fill, border, 1.0)
	var checkbox_fill := OPT_CHECK_ON if enabled else Color(0.12, 0.16, 0.22)
	var checkbox_border := OPT_CHECK_ON if enabled else OPT_BORDER
	draw_panel(canvas, checkbox_rect, checkbox_fill, checkbox_border, 1.0)
	if enabled:
		var center := checkbox_rect.get_center()
		canvas.draw_line(center + Vector2(-5.0, 0.0), center + Vector2(-1.5, 4.0), Color.WHITE, 2.5)
		canvas.draw_line(center + Vector2(-1.5, 4.0), center + Vector2(6.0, -5.0), Color.WHITE, 2.5)
	var title_color := INK_DIM if muted and not enabled else INK
	_draw_text(canvas, font, title, row_rect.position + Vector2(58.0, 24.0), 15, title_color)
	draw_toggle_leader(canvas, font, row_rect, checkbox_rect, title)
	_draw_text(canvas, font, subtitle, row_rect.position + Vector2(58.0, 42.0), 11, INK_DIM)
	if focused:
		draw_holo_focus_frame(canvas, row_rect, pulse_alpha)


func draw_button(canvas: CanvasItem, font: Font, rect: Rect2, text: String, selected: bool, mouse_pos: Vector2) -> void:
	var hovered := rect.has_point(mouse_pos)
	var fill := SELECT_BLUE if selected else OPT_CARD
	if hovered and not selected:
		fill = OPT_CARD_HOVER
	var border := SELECT_BLUE if selected or hovered else OPT_BORDER
	draw_panel(canvas, rect, fill, border, 1.0)
	if selected:
		canvas.draw_rect(Rect2(rect.position + Vector2(8.0, 10.0), Vector2(4.0, rect.size.y - 20.0)), Color(1.0, 1.0, 1.0, 0.70))
	_draw_text_in_rect(canvas, font, text, rect, 18, Color.WHITE if selected else INK)


func draw_recommendation_block(canvas: CanvasItem, font: Font, rect: Rect2, text: String) -> void:
	draw_panel(canvas, rect, Color(0.16, 0.13, 0.05, 0.92), Color(0.78, 0.60, 0.20, 0.55), 1.0)
	var lines := text.split("\n", false)
	for index in range(min(lines.size(), 2)):
		_draw_text(canvas, font, str(lines[index]), rect.position + Vector2(14.0, 19.0 + float(index) * 18.0), 12, INK)


func draw_hud_readout_bar(canvas: CanvasItem, font: Font, panel_rect: Rect2, text: String) -> void:
	if text.is_empty():
		return
	var draw_font := _get_text_draw_font(font, text)
	var bar := Rect2(panel_rect.position + Vector2(28.0, panel_rect.size.y - 22.0), Vector2(panel_rect.size.x - 56.0, 16.0))
	var marker_center := Vector2(bar.position.x, bar.get_center().y)
	canvas.draw_colored_polygon(
		PackedVector2Array([
			marker_center + Vector2(0.0, -3.0),
			marker_center + Vector2(6.0, 0.0),
			marker_center + Vector2(0.0, 3.0),
		]),
		SELECT_BLUE
	)
	canvas.draw_string(draw_font, Vector2(bar.position.x + 13.0, bar.get_center().y + 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, bar.size.x - 13.0), 12, INK_DIM)


static func get_select_chevron_rects(value_rect: Rect2) -> Dictionary:
	var half_width := value_rect.size.x * 0.5
	return {
		"left": Rect2(value_rect.position, Vector2(half_width, value_rect.size.y)),
		"right": Rect2(value_rect.position + Vector2(half_width, 0.0), Vector2(value_rect.size.x - half_width, value_rect.size.y)),
	}


func draw_panel(
	canvas: CanvasItem,
	rect: Rect2,
	fill: Color,
	border: Color,
	border_width: float,
	double_line: bool = false,
	glow: bool = false,
	frame_kind: int = PremiumPanelFrame.KIND_SLOT
) -> void:
	var kind := PremiumPanelFrame.KIND_MAIN if glow else frame_kind
	PremiumPanelFrame.draw_panel(canvas, rect, kind, fill, border, border_width)
	if border_width > 0.0 and double_line and rect.size.x > 6.0 and rect.size.y > 6.0:
		PremiumPanelFrame.draw_panel(
			canvas,
			rect.grow(-3.0),
			PremiumPanelFrame.KIND_SLOT,
			Color.TRANSPARENT,
			Color(border.r, border.g, border.b, border.a * 0.45),
			1.0
		)


func draw_neon_line(canvas: CanvasItem, start: Vector2, finish: Vector2, color: Color, core_width: float = 1.0) -> void:
	var halo := Color(color.r, color.g, color.b, color.a * 0.18)
	var mid := Color(color.r, color.g, color.b, color.a * 0.35)
	canvas.draw_line(start, finish, halo, core_width * 3.0)
	canvas.draw_line(start, finish, mid, core_width * 2.0)
	canvas.draw_line(start, finish, color, core_width)


func draw_holo_focus_frame(canvas: CanvasItem, rect: Rect2, pulse_alpha: float = 1.0) -> void:
	if rect.size.x <= 8.0 or rect.size.y <= 8.0:
		return
	var inner_rect := rect.grow(-3.0)
	PremiumPanelFrame.draw_panel(canvas, inner_rect, PremiumPanelFrame.KIND_SLOT, Color.TRANSPARENT, Color(SELECT_BLUE.r, SELECT_BLUE.g, SELECT_BLUE.b, 0.55), 1.0)
	var alpha := clampf(pulse_alpha, 0.0, 1.0)
	var accent := Color(SELECT_BLUE.r, SELECT_BLUE.g, SELECT_BLUE.b, alpha)
	var frame_rect := rect.grow(-1.0)
	PremiumPanelFrame.draw_corner_brackets(canvas, frame_rect, accent, 1.0, 0.45, 14.0)


func draw_toggle_leader(canvas: CanvasItem, font: Font, row_rect: Rect2, checkbox_rect: Rect2, title: String) -> void:
	var title_start_x := row_rect.position.x + 58.0
	var title_font := _get_text_draw_font(font, title)
	var title_width := title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15).x
	var title_end_x := title_start_x + title_width
	var leader_y := row_rect.position.y + 20.0
	var leader_x0 := title_end_x + 10.0
	var leader_x1 := checkbox_rect.position.x - 10.0
	if checkbox_rect.position.x <= title_end_x:
		leader_x1 = row_rect.end.x - 18.0
	if leader_x1 > leader_x0 + 6.0:
		canvas.draw_dashed_line(
			Vector2(leader_x0, leader_y),
			Vector2(leader_x1, leader_y),
			Color(INK.r, INK.g, INK.b, 0.22),
			1.0,
			4.0
		)


func _draw_text(canvas: CanvasItem, font: Font, text: String, pos: Vector2, size: int, color: Color) -> void:
	canvas.draw_string(_get_text_draw_font(font, text), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _draw_text_in_rect(canvas: CanvasItem, font: Font, text: String, rect: Rect2, size: int, color: Color) -> void:
	var draw_font := _get_text_draw_font(font, text)
	var text_size := draw_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	var ascent := draw_font.get_ascent(size)
	var pos := Vector2(
		rect.position.x + (rect.size.x - text_size.x) * 0.5,
		rect.position.y + (rect.size.y - text_size.y) * 0.5 + ascent
	)
	canvas.draw_string(draw_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _get_text_draw_font(font: Font, text: String) -> Font:
	if font != null and not _needs_cjk_fallback_font(text):
		return font
	return ThemeDB.fallback_font if ThemeDB.fallback_font != null else font


func _needs_cjk_fallback_font(text: String) -> bool:
	for index in range(text.length()):
		var codepoint := text.unicode_at(index)
		if (
			(codepoint >= 0x1100 and codepoint <= 0x11FF)
			or (codepoint >= 0x2E80 and codepoint <= 0x9FFF)
			or (codepoint >= 0xAC00 and codepoint <= 0xD7AF)
			or (codepoint >= 0xF900 and codepoint <= 0xFAFF)
		):
			return true
	return false
