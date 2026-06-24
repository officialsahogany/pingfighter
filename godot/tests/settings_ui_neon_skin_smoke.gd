extends SceneTree

const Overlay := preload("res://scripts/hud/pause_menu_overlay.gd")
const GamepadVibrationSettings := preload("res://scripts/core/gamepad_vibration_settings.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const PremiumPanelFrame := preload("res://scripts/hud/premium_panel_frame.gd")
const READOUT_MAX_WIDTH := 491.0
const DESC_LANGUAGES := [
	LanguageSettingsData.LANGUAGE_KOREAN,
	LanguageSettingsData.LANGUAGE_ENGLISH,
	LanguageSettingsData.LANGUAGE_CHINESE,
	LanguageSettingsData.LANGUAGE_JAPANESE,
	LanguageSettingsData.LANGUAGE_SPANISH,
	LanguageSettingsData.LANGUAGE_PORTUGUESE_BRAZIL,
	LanguageSettingsData.LANGUAGE_RUSSIAN,
]
const DESC_KEYS := [
	"settings.desc.bgm",
	"settings.desc.sfx",
	"settings.desc.sound_back",
	"settings.desc.display_mode",
	"settings.desc.render_fps",
	"settings.desc.vsync",
	"settings.desc.remember_display",
	"settings.desc.auto_refresh",
	"settings.desc.recommend_apply",
	"settings.desc.apply_60hz",
	"settings.desc.save",
	"settings.desc.display_back",
	"settings.desc.controls_device",
	"settings.desc.controls_vibration",
	"settings.desc.controls_back",
	"settings.desc.language",
	"settings.desc.language_back",
]
const DESC_KO := {
	"settings.desc.bgm": "배경음 음량을 조절합니다.",
	"settings.desc.sfx": "효과음 음량을 조절합니다.",
	"settings.desc.sound_back": "이전 화면으로 돌아갑니다.",
	"settings.desc.display_mode": "화면 표시 방식을 선택합니다.",
	"settings.desc.render_fps": "렌더링 최대 프레임을 설정합니다.",
	"settings.desc.vsync": "수직 동기화 방식을 설정합니다.",
	"settings.desc.remember_display": "표시 모드를 다음 실행에도 유지합니다.",
	"settings.desc.auto_refresh": "60Hz를 자동으로 적용합니다.",
	"settings.desc.recommend_apply": "권장 설정을 한 번에 적용합니다.",
	"settings.desc.apply_60hz": "지금 60Hz 설정을 적용합니다.",
	"settings.desc.save": "현재 디스플레이 설정을 저장합니다.",
	"settings.desc.display_back": "이전 화면으로 돌아갑니다.",
	"settings.desc.controls_device": "입력 장치를 선택합니다.",
	"settings.desc.controls_vibration": "조이패드 진동 세기를 조절합니다.",
	"settings.desc.controls_back": "이전 화면으로 돌아갑니다.",
	"settings.desc.language": "게임 언어를 선택합니다.",
	"settings.desc.language_back": "이전 화면으로 돌아갑니다.",
}
const RESET_LABELS := {
	LanguageSettingsData.LANGUAGE_KOREAN: "초기화",
	LanguageSettingsData.LANGUAGE_ENGLISH: "Reset",
	LanguageSettingsData.LANGUAGE_CHINESE: "重置",
	LanguageSettingsData.LANGUAGE_JAPANESE: "リセット",
	LanguageSettingsData.LANGUAGE_SPANISH: "Restablecer",
	LanguageSettingsData.LANGUAGE_PORTUGUESE_BRAZIL: "Redefinir",
	LanguageSettingsData.LANGUAGE_RUSSIAN: "Сброс",
}

var _failures: Array[String] = []
var _probe: NeonSkinProbe = null
var _frame_count := 0


class NeonSkinProbe:
	extends Node2D

	var overlay: Object = Overlay.new()
	var draw_count := 0
	var component_draw_count := 0

	func _draw() -> void:
		draw_count += 1
		overlay._draw_neon_line(self, Vector2(8.0, 8.0), Vector2(160.0, 8.0), Overlay.NEON_CYAN, 1.5)
		overlay._draw_panel(self, Rect2(8.0, 18.0, 56.0, 24.0), Overlay.PANEL_COLOR, Overlay.PANEL_BORDER, 2.0)
		overlay._draw_panel(self, Rect2(72.0, 18.0, 56.0, 24.0), Overlay.PANEL_COLOR, Overlay.PANEL_BORDER, 2.0, true, true)
		overlay._draw_tab(self, Overlay.FONT_BODY, Rect2(8.0, 50.0, 78.0, 28.0), "탭", true, "sound")
		overlay._draw_tab(self, Overlay.FONT_BODY, Rect2(92.0, 50.0, 78.0, 28.0), "탭", false, "display")
		overlay._draw_tab(self, Overlay.FONT_BODY, Rect2(8.0, 84.0, 78.0, 28.0), "탭", false, "controls")
		overlay._draw_tab(self, Overlay.FONT_BODY, Rect2(92.0, 84.0, 78.0, 28.0), "탭", false, "language")
		overlay._draw_tab(self, Overlay.FONT_BODY, Rect2(8.0, 118.0, 78.0, 28.0), "탭", false)
		overlay._draw_scanlines(self, Rect2(92.0, 118.0, 78.0, 28.0))
		overlay._draw_button(self, Overlay.FONT_BODY, Rect2(8.0, 84.0, 96.0, 30.0), "선택", true, Vector2(-99.0, -99.0))
		overlay._draw_toggle_setting_row(
			self,
			Overlay.FONT_BODY,
			Rect2(8.0, 154.0, 156.0, 40.0),
			Rect2(138.0, 164.0, 16.0, 16.0),
			"토글",
			"네온",
			true,
			false,
			Vector2(-99.0, -99.0)
		)
		overlay._draw_toggle_setting_row(
			self,
			Overlay.FONT_BODY,
			Rect2(8.0, 198.0, 156.0, 40.0),
			Rect2(138.0, 208.0, 16.0, 16.0),
			"토글",
			"오프",
			false,
			false,
			Vector2(-99.0, -99.0)
		)
		overlay._draw_holo_focus_frame(self, Rect2(8.0, 242.0, 150.0, 26.0), 1.0)
		overlay._draw_setting_select_row(
			self,
			Overlay.FONT_BODY,
			Rect2(8.0, 274.0, 156.0, 36.0),
			Rect2(106.0, 280.0, 50.0, 24.0),
			"라벨",
			"값",
			true,
			Vector2(-99.0, -99.0)
		)
		overlay._draw_setting_select_row(
			self,
			Overlay.FONT_BODY,
			Rect2(8.0, 316.0, 156.0, 36.0),
			Rect2(106.0, 322.0, 50.0, 24.0),
			"라벨",
			"값",
			false,
			Vector2(-99.0, -99.0)
		)
		overlay._draw_hud_readout_bar(self, Overlay.FONT_BODY, Rect2(0.0, 0.0, 180.0, 374.0), "설명 텍스트")
		overlay._draw_hud_readout_bar(self, Overlay.FONT_BODY, Rect2(0.0, 0.0, 180.0, 374.0), "")
		component_draw_count += 1


class FakeAudio:
	extends RefCounted

	var bgm_volume := 0.0
	var sfx_volume := 0.0

	func get_bgm_volume() -> float:
		return bgm_volume

	func set_bgm_volume(value: float) -> float:
		bgm_volume = clampf(value, 0.0, 1.0)
		return bgm_volume

	func get_sfx_volume() -> float:
		return sfx_volume

	func set_sfx_volume(value: float) -> float:
		sfx_volume = clampf(value, 0.0, 1.0)
		return sfx_volume


class FakeRegistry:
	extends RefCounted

	var audio := FakeAudio.new()

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		return null


func _init() -> void:
	get_root().size = Vector2i(180, 374)
	_probe = NeonSkinProbe.new()
	_probe.name = "SettingsUiNeonSkinProbe"
	get_root().add_child(_probe)
	_probe.queue_redraw()


func _process(_delta: float) -> bool:
	_frame_count += 1
	if _frame_count < 3:
		return false
	_verify_contract()

	if _failures.is_empty():
		print("settings_ui_neon_skin_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	return true


func _verify_contract() -> void:
	var overlay: Object = Overlay.new()
	_expect(Overlay.FONT_BODY != null, "settings UI body font should preload")
	_expect(Overlay.FONT_TECH != null, "settings UI tech font should preload")
	_expect(overlay._get_ui_font() == Overlay.FONT_BODY, "default settings UI font should be NanumSquareB")
	_expect(overlay._get_ui_font(true) == Overlay.FONT_TECH, "tech settings UI font should be NeoDunggeunmoPro")
	_expect(overlay._get_text_draw_font(Overlay.FONT_BODY, "한국어") == Overlay.FONT_BODY, "Korean settings text should keep the Nanum body font")
	_expect(overlay._get_text_draw_font(Overlay.FONT_BODY, "日本語") == ThemeDB.fallback_font, "Japanese settings text should use the engine fallback font")
	_expect(overlay._get_text_draw_font(Overlay.FONT_BODY, "简体中文") == ThemeDB.fallback_font, "Chinese settings text should use the engine fallback font")
	_expect(_color_equal(Overlay.PANEL_COLOR, Color(0.04, 0.06, 0.10, 0.92)), "settings UI panel color should stay on the Lingpia navy token")
	_expect(_color_equal(Overlay.PANEL_BORDER, Color(0.36, 0.78, 0.98, 0.90)), "settings UI panel border should stay on the Lingpia cyan token")
	_expect(_color_equal(Overlay.SECTION_COLOR, Color(0.02, 0.04, 0.08, 0.55)), "settings UI section color should keep the slice-1 readability alpha")
	_expect(_color_equal(Overlay.NEON_CYAN, Color(0.36, 0.78, 0.98)), "settings UI neon cyan token should stay stable")
	_expect(_probe != null and _probe.draw_count > 0, "settings UI neon line probe should draw through a live _draw callback")
	_expect(_probe != null and _probe.component_draw_count > 0, "settings UI neon component probe should draw through a live _draw callback")
	var pause_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	_expect(PremiumPanelFrame.configure_box_for_tests(PremiumPanelFrame.KIND_MAIN, Overlay.PANEL_COLOR, Overlay.PANEL_BORDER) != null, "settings UI should preload the shared premium panel frame")
	_expect(pause_source.find("PremiumPanelFrame.draw_panel") >= 0, "settings UI panel wrapper should delegate to the shared premium panel frame")
	_expect(pause_source.find("PremiumPanelFrame.KIND_MAIN") >= 0, "settings UI should route the pause shell through the main frame kind")
	_expect(pause_source.find("PremiumPanelFrame.KIND_SECTION") >= 0, "settings UI should route the options content through the section frame kind")
	_expect(pause_source.find("PremiumPanelFrame.draw_corner_brackets") >= 0, "settings UI focus brackets should use the shared corner helper")
	var pulse: float = overlay._focus_pulse_alpha()
	_expect(pulse >= 0.0 and pulse <= 1.0, "settings UI focus pulse alpha should remain normalized")
	_expect(overlay._get_focused_option_description(Overlay.OPTIONS_TAB_DISPLAY, 1) != "", "display fps focus should yield a readout description")
	_expect(overlay._get_focused_option_description(Overlay.OPTIONS_TAB_CONTROLS, 99) == "", "out-of-range controls focus should yield empty readout")
	_verify_desc_localization()
	_verify_desc_focus_mappings(overlay)
	_verify_chevron_click_contract()
	_verify_reset_contract()
	_verify_tab_icon_contract()


func _verify_desc_localization() -> void:
	var ko_table: Dictionary = LanguageSettingsData.TEXT.get(LanguageSettingsData.LANGUAGE_KOREAN, {})
	for key in DESC_KO.keys():
		_expect(str(ko_table.get(key, "")) == str(DESC_KO[key]), "%s Korean fallback should match the data table" % key)
	for language in DESC_LANGUAGES:
		var table: Dictionary = LanguageSettingsData.TEXT.get(language, {})
		for key in DESC_KEYS:
			_expect(table.has(key), "%s should include %s" % [language, key])
			if table.has(key):
				var value := str(table[key])
				_expect(not value.is_empty(), "%s %s should not be empty" % [language, key])
				var width := Overlay.FONT_BODY.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x
				_expect(width <= READOUT_MAX_WIDTH, "%s %s should fit inside the one-line readout width" % [language, key])


func _verify_desc_focus_mappings(overlay: Object) -> void:
	var previous_language: String = LanguageSettings._cached_language
	for language in DESC_LANGUAGES:
		LanguageSettings._cached_language = language
		for focus in range(Overlay.SOUND_FOCUS_COUNT):
			_expect(overlay._get_focused_option_description(Overlay.OPTIONS_TAB_SOUND, focus) != "", "%s sound focus %d should yield a readout" % [language, focus])
		for focus in range(Overlay.DISPLAY_FOCUS_COUNT):
			_expect(overlay._get_focused_option_description(Overlay.OPTIONS_TAB_DISPLAY, focus) != "", "%s display focus %d should yield a readout" % [language, focus])
		for focus in range(Overlay.LANGUAGE_FOCUS_COUNT):
			_expect(overlay._get_focused_option_description(Overlay.OPTIONS_TAB_LANGUAGE, focus) != "", "%s language focus %d should yield a readout" % [language, focus])
		overlay.controls_device_view = Overlay.CONTROL_DEVICE_KEYBOARD_MOUSE
		for focus in range(Overlay.CONTROLS_BASE_FOCUS_COUNT):
			_expect(overlay._get_focused_option_description(Overlay.OPTIONS_TAB_CONTROLS, focus) != "", "%s keyboard controls focus %d should yield a readout" % [language, focus])
		overlay.controls_device_view = Overlay.CONTROL_DEVICE_JOYPAD
		for focus in range(Overlay.CONTROLS_JOYPAD_FOCUS_COUNT):
			_expect(overlay._get_focused_option_description(Overlay.OPTIONS_TAB_CONTROLS, focus) != "", "%s joypad controls focus %d should yield a readout" % [language, focus])
		_expect(overlay._get_focused_option_description(Overlay.OPTIONS_TAB_CONTROLS, 99) == "", "%s out-of-range controls focus should stay empty" % language)
	LanguageSettings._cached_language = previous_language


func _verify_chevron_click_contract() -> void:
	var overlay: Object = Overlay.new()
	var view_size := Vector2(900.0, 600.0)
	var panel: Rect2 = overlay._get_options_panel_rect(view_size)
	_verify_display_chevron_clicks(overlay, panel)
	_verify_controls_chevron_clicks(overlay, panel)
	_verify_chevron_regression_guards(overlay, panel, view_size)


func _verify_display_chevron_clicks(overlay: Object, panel: Rect2) -> void:
	var fps_value_rect: Rect2 = overlay._get_display_fps_cap_value_rect(panel)
	var fps_chevrons: Dictionary = overlay._get_select_chevron_rects(fps_value_rect)
	var fps_left: Rect2 = fps_chevrons["left"]
	var fps_right: Rect2 = fps_chevrons["right"]
	_expect(_rect_inside(overlay._get_display_fps_cap_row_rect(panel), fps_left), "render FPS left chevron hit rect should stay inside the row")
	_expect(_rect_inside(fps_value_rect, fps_left), "render FPS left chevron hit rect should stay inside the value rect")
	_expect(_rect_inside(fps_value_rect, fps_right), "render FPS right chevron hit rect should stay inside the value rect")

	overlay.render_fps_cap = Overlay.RENDER_FPS_CAP_SMOOTH
	overlay._handle_display_click(fps_left.get_center(), null, null, panel)
	var fps_left_result: int = overlay.render_fps_cap
	_expect(fps_left_result == Overlay.RENDER_FPS_CAP_STABILITY, "render FPS left chevron should select the previous option")
	overlay.render_fps_cap = Overlay.RENDER_FPS_CAP_SMOOTH
	overlay._handle_display_click(fps_right.get_center(), null, null, panel)
	var fps_right_result: int = overlay.render_fps_cap
	_expect(fps_right_result == Overlay.RENDER_FPS_CAP_BALANCED, "render FPS right chevron should select the next option")
	_expect(fps_left_result != fps_right_result, "render FPS left and right chevrons should split directions")

	var fps_label_pos: Vector2 = overlay._get_display_fps_cap_row_rect(panel).position + Vector2(28.0, 20.0)
	overlay.render_fps_cap = Overlay.RENDER_FPS_CAP_SMOOTH
	overlay.options_focus = 0
	overlay._handle_display_click(fps_label_pos, null, null, panel)
	_expect(overlay.render_fps_cap == Overlay.RENDER_FPS_CAP_SMOOTH, "render FPS label-area click should not cycle")
	_expect(overlay.options_focus == 1, "render FPS label-area click should only focus the row")

	var vsync_value_rect: Rect2 = overlay._get_display_vsync_value_rect(panel)
	var vsync_chevrons: Dictionary = overlay._get_select_chevron_rects(vsync_value_rect)
	var vsync_left: Rect2 = vsync_chevrons["left"]
	var vsync_right: Rect2 = vsync_chevrons["right"]
	_expect(_rect_inside(overlay._get_display_vsync_row_rect(panel), vsync_left), "VSync left chevron hit rect should stay inside the row")
	_expect(_rect_inside(vsync_value_rect, vsync_left), "VSync left chevron hit rect should stay inside the value rect")
	_expect(_rect_inside(vsync_value_rect, vsync_right), "VSync right chevron hit rect should stay inside the value rect")

	overlay.vsync_mode = Overlay.VSYNC_MODE_ENABLED
	overlay._handle_display_click(vsync_left.get_center(), null, null, panel)
	var vsync_left_result: int = overlay.vsync_mode
	_expect(vsync_left_result == Overlay.VSYNC_MODE_AUTO, "VSync left chevron should select the previous option")
	overlay.vsync_mode = Overlay.VSYNC_MODE_ENABLED
	overlay._handle_display_click(vsync_right.get_center(), null, null, panel)
	var vsync_right_result: int = overlay.vsync_mode
	_expect(vsync_right_result == Overlay.VSYNC_MODE_MAILBOX, "VSync right chevron should select the next option")
	_expect(vsync_left_result != vsync_right_result, "VSync left and right chevrons should split directions")


func _verify_controls_chevron_clicks(overlay: Object, panel: Rect2) -> void:
	var saved_vibration_level: int = GamepadVibrationSettings.get_vibration_level()
	overlay.controls_device_view = Overlay.CONTROL_DEVICE_JOYPAD
	var vibration_value_rect: Rect2 = overlay._get_controls_vibration_value_rect(panel)
	var vibration_chevrons: Dictionary = overlay._get_select_chevron_rects(vibration_value_rect)
	var vibration_left: Rect2 = vibration_chevrons["left"]
	var vibration_right: Rect2 = vibration_chevrons["right"]
	_expect(_rect_inside(overlay._get_controls_vibration_row_rect(panel), vibration_left), "vibration left chevron hit rect should stay inside the row")
	_expect(_rect_inside(vibration_value_rect, vibration_left), "vibration left chevron hit rect should stay inside the value rect")
	_expect(_rect_inside(vibration_value_rect, vibration_right), "vibration right chevron hit rect should stay inside the value rect")

	overlay.gamepad_vibration_level = 3
	overlay._handle_controls_click(vibration_left.get_center(), panel)
	var vibration_left_result: int = overlay.gamepad_vibration_level
	_expect(vibration_left_result == 2, "vibration left chevron should decrease sensitivity")
	overlay.gamepad_vibration_level = 3
	overlay._handle_controls_click(vibration_right.get_center(), panel)
	var vibration_right_result: int = overlay.gamepad_vibration_level
	_expect(vibration_right_result == 4, "vibration right chevron should increase sensitivity")
	_expect(vibration_left_result != vibration_right_result, "vibration left and right chevrons should split directions")
	GamepadVibrationSettings.set_vibration_level(saved_vibration_level)


func _verify_chevron_regression_guards(overlay: Object, panel: Rect2, view_size: Vector2) -> void:
	overlay.render_fps_cap = Overlay.RENDER_FPS_CAP_SMOOTH
	overlay.remember_display_mode = false
	overlay._handle_display_click(overlay._get_display_default_checkbox_rect(panel).get_center(), null, null, panel)
	_expect(overlay.remember_display_mode, "toggle checkbox click should still toggle display preference")
	_expect(overlay.render_fps_cap == Overlay.RENDER_FPS_CAP_SMOOTH, "toggle checkbox click should not cycle render FPS")

	overlay.render_fps_cap = Overlay.RENDER_FPS_CAP_SMOOTH
	overlay.options_focus = 0
	overlay._handle_display_click(overlay._get_display_save_button_rect(panel).get_center(), null, null, panel)
	_expect(overlay.options_focus == 7, "display save button click should still route to the button")
	_expect(overlay.render_fps_cap == Overlay.RENDER_FPS_CAP_SMOOTH, "display save button click should not cycle render FPS")

	overlay.options_tab = Overlay.OPTIONS_TAB_SOUND
	overlay.render_fps_cap = Overlay.RENDER_FPS_CAP_SMOOTH
	overlay._handle_options_click(overlay._get_slider_hit_rect_from_panel(Overlay.SOUND_SLIDER_BGM, panel).get_center(), null, null, view_size)
	_expect(overlay.options_focus == 0, "sound slider click should still focus the BGM slider")
	_expect(overlay.dragging_slider == Overlay.SOUND_SLIDER_BGM, "sound slider click should still start slider drag")
	_expect(overlay.render_fps_cap == Overlay.RENDER_FPS_CAP_SMOOTH, "sound slider click should not cycle render FPS")

	overlay.options_tab = Overlay.OPTIONS_TAB_DISPLAY
	overlay.render_fps_cap = Overlay.RENDER_FPS_CAP_SMOOTH
	overlay._handle_options_click(overlay._get_sound_tab_rect(panel).get_center(), null, null, view_size)
	_expect(overlay.options_tab == Overlay.OPTIONS_TAB_SOUND, "tab click should still switch tabs before content handlers")
	_expect(overlay.render_fps_cap == Overlay.RENDER_FPS_CAP_SMOOTH, "tab click should not cycle render FPS")


func _verify_reset_contract() -> void:
	_expect(Overlay.SOUND_FOCUS_COUNT == 3, "reset should not join the sound focus cycle")
	_expect(Overlay.DISPLAY_FOCUS_COUNT == 9, "reset should not join the display focus cycle")
	_expect(Overlay.CONTROLS_BASE_FOCUS_COUNT == 2, "reset should not join the keyboard controls focus cycle")
	_expect(Overlay.CONTROLS_JOYPAD_FOCUS_COUNT == 3, "reset should not join the joypad controls focus cycle")
	_expect(Overlay.LANGUAGE_FOCUS_COUNT == 8, "reset should not join the language focus cycle")
	for language in RESET_LABELS.keys():
		var table: Dictionary = LanguageSettingsData.TEXT.get(language, {})
		_expect(str(table.get("settings.reset", "")) == str(RESET_LABELS[language]), "%s should localize settings.reset" % language)
	var overlay: Object = Overlay.new()
	var view_size := Vector2(900.0, 600.0)
	var panel: Rect2 = overlay._get_options_panel_rect(view_size)
	var reset_rect: Rect2 = overlay._get_reset_button_rect(panel)
	_expect(not _rects_overlap(reset_rect, overlay._get_sound_tab_rect(panel)), "reset button should not overlap the sound tab")
	_expect(not _rects_overlap(reset_rect, overlay._get_display_tab_rect(panel)), "reset button should not overlap the display tab")
	_expect(not _rects_overlap(reset_rect, overlay._get_controls_tab_rect(panel)), "reset button should not overlap the controls tab")
	_expect(not _rects_overlap(reset_rect, overlay._get_language_tab_rect(panel)), "reset button should not overlap the language tab")
	_expect(not _rects_overlap(reset_rect, overlay._get_display_save_button_rect(panel)), "reset button should not overlap the display save button")
	_expect(not _rects_overlap(reset_rect, overlay._get_display_back_button_rect(panel)), "reset button should not overlap the display back button")
	_expect(not _rects_overlap(reset_rect, overlay._get_back_button_rect(panel)), "reset button should not overlap the sound back button")
	_verify_reset_sound(overlay)
	_verify_reset_display(overlay)
	_verify_reset_controls(overlay)
	_verify_reset_language(overlay)
	_verify_reset_click_routing(panel, view_size)


func _verify_tab_icon_contract() -> void:
	var overlay: Object = Overlay.new()
	var panel: Rect2 = overlay._get_options_panel_rect(Vector2(900.0, 600.0))
	var sound_tab: Rect2 = overlay._get_sound_tab_rect(panel)
	var display_tab: Rect2 = overlay._get_display_tab_rect(panel)
	var controls_tab: Rect2 = overlay._get_controls_tab_rect(panel)
	var language_tab: Rect2 = overlay._get_language_tab_rect(panel)
	var reset_rect: Rect2 = overlay._get_reset_button_rect(panel)
	_expect(not _rects_overlap(sound_tab, display_tab), "sound and display tabs should not overlap after icon layout")
	_expect(not _rects_overlap(sound_tab, controls_tab), "sound and controls tabs should not overlap after icon layout")
	_expect(not _rects_overlap(sound_tab, language_tab), "sound and language tabs should not overlap after icon layout")
	_expect(not _rects_overlap(display_tab, controls_tab), "display and controls tabs should not overlap after icon layout")
	_expect(not _rects_overlap(display_tab, language_tab), "display and language tabs should not overlap after icon layout")
	_expect(not _rects_overlap(controls_tab, language_tab), "controls and language tabs should not overlap after icon layout")
	_expect(not _rects_overlap(language_tab, reset_rect), "language tab should not overlap the reset button after icon layout")


func _verify_reset_sound(overlay: Object) -> void:
	var registry := FakeRegistry.new()
	registry.audio.bgm_volume = 0.91
	registry.audio.sfx_volume = 0.12
	overlay.options_tab = Overlay.OPTIONS_TAB_SOUND
	overlay._reset_current_tab_to_defaults(null, registry)
	_expect(is_equal_approx(registry.audio.bgm_volume, Overlay.DEFAULT_BGM_VOLUME), "sound reset should restore the default BGM volume through the audio setter")
	_expect(is_equal_approx(registry.audio.sfx_volume, Overlay.DEFAULT_SFX_VOLUME), "sound reset should restore the default SFX volume through the audio setter")


func _verify_reset_display(overlay: Object) -> void:
	overlay.options_tab = Overlay.OPTIONS_TAB_DISPLAY
	overlay.options_focus = 2
	overlay.display_mode = Overlay.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
	overlay.render_fps_cap = Overlay.RENDER_FPS_CAP_SMOOTH
	overlay.vsync_mode = Overlay.VSYNC_MODE_ENABLED
	overlay.remember_display_mode = true
	overlay.auto_refresh_rate_60hz = true
	overlay._reset_current_tab_to_defaults(null, null)
	_expect(overlay.options_focus == 2, "display reset should not change focus")
	_expect(overlay.display_mode == Overlay.DISPLAY_MODE_WINDOWED, "display reset should restore the factory display mode")
	_expect(overlay.render_fps_cap == Overlay.RENDER_FPS_CAP_DEFAULT, "display reset should restore the default render FPS cap")
	_expect(overlay.vsync_mode == Overlay.VSYNC_MODE_AUTO, "display reset should restore the default VSync mode")
	_expect(not overlay.remember_display_mode, "display reset should clear remember display mode")
	_expect(not overlay.auto_refresh_rate_60hz, "display reset should clear auto 60Hz mode")
	_expect(not overlay._display_preference_dirty, "display reset should finish through the existing save path")


func _verify_reset_controls(overlay: Object) -> void:
	var saved_vibration_level: int = GamepadVibrationSettings.get_vibration_level()
	overlay.options_tab = Overlay.OPTIONS_TAB_CONTROLS
	overlay.controls_device_view = Overlay.CONTROL_DEVICE_JOYPAD
	overlay.options_focus = 2
	overlay.gamepad_vibration_level = GamepadVibrationSettings.VIBRATION_LEVEL_MAX
	GamepadVibrationSettings.set_vibration_level(GamepadVibrationSettings.VIBRATION_LEVEL_MAX)
	overlay._reset_current_tab_to_defaults(null, null)
	_expect(overlay.controls_device_view == Overlay.CONTROL_DEVICE_KEYBOARD_MOUSE, "controls reset should return to keyboard and mouse view")
	_expect(overlay.gamepad_vibration_level == GamepadVibrationSettings.VIBRATION_LEVEL_DEFAULT, "controls reset should restore default vibration level")
	_expect(GamepadVibrationSettings.get_vibration_level() == GamepadVibrationSettings.VIBRATION_LEVEL_DEFAULT, "controls reset should persist default vibration level")
	_expect(overlay.options_focus == 1, "controls reset should clamp focus to the keyboard controls range")
	GamepadVibrationSettings.set_vibration_level(saved_vibration_level)


func _verify_reset_language(overlay: Object) -> void:
	var previous_language: String = LanguageSettings.get_language()
	overlay.options_tab = Overlay.OPTIONS_TAB_LANGUAGE
	overlay.options_focus = 4
	overlay.language_code = LanguageSettings.LANGUAGE_SPANISH
	overlay._reset_current_tab_to_defaults(null, null)
	_expect(overlay.options_focus == 4, "language reset should not change focus")
	_expect(overlay.language_code == LanguageSettings.DEFAULT_LANGUAGE, "language reset should restore the default language")
	_expect(LanguageSettings.get_language() == LanguageSettings.DEFAULT_LANGUAGE, "language reset should persist the default language")
	LanguageSettings.set_language(previous_language)


func _verify_reset_click_routing(panel: Rect2, view_size: Vector2) -> void:
	var overlay: Object = Overlay.new()
	overlay.options_tab = Overlay.OPTIONS_TAB_DISPLAY
	overlay.options_focus = 1
	overlay.display_mode = Overlay.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
	overlay.render_fps_cap = Overlay.RENDER_FPS_CAP_SMOOTH
	overlay.vsync_mode = Overlay.VSYNC_MODE_ENABLED
	overlay.remember_display_mode = true
	overlay.auto_refresh_rate_60hz = true
	overlay._handle_options_click(overlay._get_reset_button_rect(panel).get_center(), null, null, view_size)
	_expect(overlay.options_focus == 1, "reset click should not join or move focus")
	_expect(overlay.display_mode == Overlay.DISPLAY_MODE_WINDOWED, "reset button click should reset the current tab")
	_expect(overlay.render_fps_cap == Overlay.RENDER_FPS_CAP_DEFAULT, "reset button click should reset render FPS")
	overlay.display_mode = Overlay.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN
	overlay.render_fps_cap = Overlay.RENDER_FPS_CAP_SMOOTH
	overlay._handle_options_click(panel.position + Vector2(panel.size.x - 20.0, 76.0), null, null, view_size)
	_expect(overlay.display_mode == Overlay.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN, "empty header/content click should not reset display mode")
	_expect(overlay.render_fps_cap == Overlay.RENDER_FPS_CAP_SMOOTH, "empty header/content click should not reset render FPS")


func _rect_inside(container: Rect2, inner: Rect2) -> bool:
	return (
		container.has_point(inner.position)
		and container.has_point(inner.position + Vector2(inner.size.x - 0.01, inner.size.y - 0.01))
	)


func _rects_overlap(first: Rect2, second: Rect2) -> bool:
	return (
		first.position.x < second.end.x
		and first.end.x > second.position.x
		and first.position.y < second.end.y
		and first.end.y > second.position.y
	)


func _color_equal(actual: Color, expected: Color) -> bool:
	return (
		is_equal_approx(actual.r, expected.r)
		and is_equal_approx(actual.g, expected.g)
		and is_equal_approx(actual.b, expected.b)
		and is_equal_approx(actual.a, expected.a)
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
