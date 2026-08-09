extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PauseMenuOptionsNavigationPolicy := preload("res://scripts/hud/pause_menu_options_navigation_policy.gd")

const MENU_CONTINUE := "continue"
const MENU_CHARACTER_INFO := "character_info"
const MENU_OPTIONS := "options"
const MENU_EXIT_TO_MAIN := "exit_to_main"


static func translate(key: String, fallback: String = "") -> String:
	return LanguageSettings.translate(key, fallback)


static func get_main_entries() -> Array:
	return [
		{"en": "RESUME", "label": translate("pause.continue"), "desc": translate("pause.desc.continue"), "action": MENU_CONTINUE},
		{"en": "STATUS", "label": translate("pause.character_info"), "desc": translate("pause.desc.character_info"), "action": MENU_CHARACTER_INFO},
		{"en": "SETTINGS", "label": translate("pause.options"), "desc": translate("pause.desc.options"), "action": MENU_OPTIONS},
		{"en": "EXIT", "label": translate("pause.exit_to_main"), "desc": translate("pause.desc.exit_to_main"), "action": MENU_EXIT_TO_MAIN},
	]


static func get_options_back_label(options_only: bool) -> String:
	return translate("settings.close") if options_only else translate("settings.back")


static func get_focused_option_description(tab: String, focus: int, controls_device: String) -> String:
	if tab == PauseMenuOptionsNavigationPolicy.TAB_SOUND:
		match focus:
			0:
				return translate("settings.desc.bgm", "배경음 음량을 조절합니다.")
			1:
				return translate("settings.desc.sfx", "효과음 음량을 조절합니다.")
			2:
				return translate("settings.desc.sound_back", "이전 화면으로 돌아갑니다.")
	elif tab == PauseMenuOptionsNavigationPolicy.TAB_DISPLAY:
		match focus:
			0:
				return translate("settings.desc.display_mode", "화면 표시 방식을 선택합니다.")
			1:
				return translate("settings.desc.render_fps", "렌더링 최대 프레임을 설정합니다.")
			2:
				return translate("settings.desc.vsync", "수직 동기화 방식을 설정합니다.")
			3:
				return translate("settings.desc.remember_display", "표시 모드를 다음 실행에도 유지합니다.")
			4:
				return translate("settings.desc.auto_refresh", "60Hz를 자동으로 적용합니다.")
			5:
				return translate("settings.desc.recommend_apply", "권장 설정을 한 번에 적용합니다.")
			6:
				return translate("settings.desc.apply_60hz", "지금 60Hz 설정을 적용합니다.")
			7:
				return translate("settings.desc.save", "현재 디스플레이 설정을 저장합니다.")
			8:
				return translate("settings.desc.display_back", "이전 화면으로 돌아갑니다.")
	elif tab == PauseMenuOptionsNavigationPolicy.TAB_CONTROLS:
		if focus == 0:
			return translate("settings.desc.controls_device", "입력 장치를 선택합니다.")
		if controls_device == PauseMenuOptionsNavigationPolicy.DEVICE_JOYPAD and focus == 1:
			return translate("settings.desc.controls_vibration", "조이패드 진동 세기를 조절합니다.")
		if focus == PauseMenuOptionsNavigationPolicy.get_controls_back_focus_index(controls_device):
			return translate("settings.desc.controls_back", "이전 화면으로 돌아갑니다.")
	elif tab == PauseMenuOptionsNavigationPolicy.TAB_LANGUAGE:
		if focus == PauseMenuOptionsNavigationPolicy.LANGUAGE_FOCUS_COUNT - 1:
			return translate("settings.desc.language_back", "이전 화면으로 돌아갑니다.")
		if focus >= 0 and focus < PauseMenuOptionsNavigationPolicy.LANGUAGE_FOCUS_COUNT - 1:
			return translate("settings.desc.language", "게임 언어를 선택합니다.")
	return ""
