extends SceneTree

const Overlay := preload("res://scripts/hud/pause_menu_overlay.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
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
		overlay._draw_tab(self, Overlay.FONT_BODY, Rect2(8.0, 50.0, 58.0, 28.0), "탭", true)
		overlay._draw_tab(self, Overlay.FONT_BODY, Rect2(72.0, 50.0, 58.0, 28.0), "탭", false)
		overlay._draw_button(self, Overlay.FONT_BODY, Rect2(8.0, 84.0, 96.0, 30.0), "선택", true, Vector2(-99.0, -99.0))
		overlay._draw_toggle_setting_row(
			self,
			Overlay.FONT_BODY,
			Rect2(8.0, 120.0, 156.0, 40.0),
			Rect2(138.0, 130.0, 16.0, 16.0),
			"토글",
			"네온",
			true,
			false,
			Vector2(-99.0, -99.0)
		)
		overlay._draw_toggle_setting_row(
			self,
			Overlay.FONT_BODY,
			Rect2(8.0, 164.0, 156.0, 40.0),
			Rect2(138.0, 174.0, 16.0, 16.0),
			"토글",
			"오프",
			false,
			false,
			Vector2(-99.0, -99.0)
		)
		overlay._draw_holo_focus_frame(self, Rect2(8.0, 208.0, 150.0, 26.0), 1.0)
		overlay._draw_setting_select_row(
			self,
			Overlay.FONT_BODY,
			Rect2(8.0, 240.0, 156.0, 36.0),
			Rect2(106.0, 246.0, 50.0, 24.0),
			"라벨",
			"값",
			true,
			Vector2(-99.0, -99.0)
		)
		overlay._draw_setting_select_row(
			self,
			Overlay.FONT_BODY,
			Rect2(8.0, 282.0, 156.0, 36.0),
			Rect2(106.0, 288.0, 50.0, 24.0),
			"라벨",
			"값",
			false,
			Vector2(-99.0, -99.0)
		)
		overlay._draw_hud_readout_bar(self, Overlay.FONT_BODY, Rect2(0.0, 0.0, 180.0, 340.0), "설명 텍스트")
		overlay._draw_hud_readout_bar(self, Overlay.FONT_BODY, Rect2(0.0, 0.0, 180.0, 340.0), "")
		component_draw_count += 1


func _init() -> void:
	get_root().size = Vector2i(180, 340)
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
	_expect(_color_equal(Overlay.PANEL_COLOR, Color(0.04, 0.06, 0.10, 0.92)), "settings UI panel color should stay on the Lingpia navy token")
	_expect(_color_equal(Overlay.PANEL_BORDER, Color(0.36, 0.78, 0.98, 0.90)), "settings UI panel border should stay on the Lingpia cyan token")
	_expect(_color_equal(Overlay.SECTION_COLOR, Color(0.02, 0.04, 0.08, 0.55)), "settings UI section color should keep the slice-1 readability alpha")
	_expect(_color_equal(Overlay.NEON_CYAN, Color(0.36, 0.78, 0.98)), "settings UI neon cyan token should stay stable")
	_expect(_probe != null and _probe.draw_count > 0, "settings UI neon line probe should draw through a live _draw callback")
	_expect(_probe != null and _probe.component_draw_count > 0, "settings UI neon component probe should draw through a live _draw callback")
	var pulse: float = overlay._focus_pulse_alpha()
	_expect(pulse >= 0.0 and pulse <= 1.0, "settings UI focus pulse alpha should remain normalized")
	_expect(overlay._get_focused_option_description(Overlay.OPTIONS_TAB_DISPLAY, 1) != "", "display fps focus should yield a readout description")
	_expect(overlay._get_focused_option_description(Overlay.OPTIONS_TAB_CONTROLS, 99) == "", "out-of-range controls focus should yield empty readout")
	_verify_desc_localization()
	_verify_desc_focus_mappings(overlay)


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
