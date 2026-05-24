extends RefCounted

const SETTINGS_PATH := "user://language_settings.cfg"
const SETTINGS_SCHEMA_VERSION := 1
const SETTINGS_SECTION := "language"
const SETTINGS_SCHEMA_KEY := "schema_version"
const SETTINGS_LANGUAGE_KEY := "locale"

const LANGUAGE_KOREAN := "ko"
const LANGUAGE_ENGLISH := "en"
const DEFAULT_LANGUAGE := LANGUAGE_KOREAN
const SUPPORTED_LANGUAGES: Array[String] = [
	LANGUAGE_KOREAN,
	LANGUAGE_ENGLISH,
]

const LANGUAGE_NATIVE_NAMES := {
	LANGUAGE_KOREAN: "한국어",
	LANGUAGE_ENGLISH: "English",
}

const TEXT := {
	LANGUAGE_KOREAN: {
		"app.title": "디스크하츠 - 링피아",
		"pause.title": "일시정지",
		"pause.continue": "계속",
		"pause.character_info": "캐릭터정보",
		"pause.options": "옵션",
		"settings.title": "설정",
		"settings.tab.sound": "사운드",
		"settings.tab.display": "디스플레이",
		"settings.tab.controls": "조작",
		"settings.tab.language": "언어",
		"settings.back": "뒤로가기",
		"settings.close": "닫기",
		"settings.save": "저장",
		"sound.bgm_volume": "BGM 볼륨",
		"sound.sfx_volume": "효과음 볼륨",
		"display.mode": "화면 모드",
		"display.mode.fullscreen": "전체화면",
		"display.mode.exclusive": "독점",
		"display.mode.windowed": "창모드",
		"display.desc.exclusive": "DWM 합성을 우회하는 독점 전체화면으로 표시합니다",
		"display.desc.fullscreen": "네이티브 해상도 전체화면으로 표시합니다",
		"display.desc.windowed": "필러 배경 포함 창모드로 표시합니다",
		"display.render_fps": "렌더 FPS",
		"display.fps.unlimited": "제한 없음",
		"display.fps.monitor": "모니터 %d Hz",
		"display.remember.title": "현재 화면 설정 저장",
		"display.remember.subtitle": "다음 실행부터 이 화면 모드와 주사율을 사용",
		"display.auto60.title": "60Hz 모드 자동 전환",
		"display.auto60.subtitle": "특정 모니터에서 60Hz 페이싱이 필요할 때만 사용",
		"display.recommend.apply": "권장값 적용",
		"display.apply60": "60Hz 모드",
		"display.recommendation.ready": "%dHz 모니터 감지: 현재 주사율에 렌더 FPS를 자동으로 맞춥니다.\n모니터를 바꾸면 다음 적용 시 새 주사율을 따라갑니다.",
		"display.recommendation.monitor": "%dHz 모니터 감지: 렌더 FPS는 현재 주사율을 따라갑니다.\n독점 전체화면과 VSync Auto가 가장 깔끔합니다.",
		"display.recommendation.default": "%dHz 모니터 감지: 렌더 FPS를 모니터 Hz로 두면 자동으로 맞춰집니다.\n권장값 적용을 누르면 현재 주사율 기반 설정으로 저장합니다.",
		"display.recommendation.fallback": "렌더 FPS를 모니터 Hz로 두면 현재 주사율에 자동으로 맞춰집니다.\n독점 전체화면과 VSync Auto를 권장합니다.",
		"controls.device": "입력 장치",
		"controls.keyboard_mouse": "키보드+마우스",
		"controls.joypad": "조이패드",
		"controls.vibration": "진동 감도",
		"controls.map.move": "이동",
		"controls.map.dash_skill": "대쉬 / 스킬",
		"controls.map.active_item": "액티브 아이템",
		"controls.map.supply_hold": "보급 홀드",
		"controls.map.weapon_switch": "무기 전환",
		"controls.map.confirm_cancel_pause": "확인 / 취소 / 일시정지",
		"controls.value.joypad.move": "왼스틱 / D-pad",
		"controls.value.joypad.dash_skill": "대쉬: B 또는 아래 / 스킬: A / X / RT",
		"controls.value.joypad.active_item": "LB/RB 또는 오른스틱 좌우 선택 / Y 사용",
		"controls.value.joypad.supply_hold": "LT",
		"controls.value.joypad.weapon_switch": "오른스틱 위/아래 / R3",
		"controls.value.joypad.confirm_cancel_pause": "A / B / 메뉴",
		"controls.value.keyboard.move": "A,D,W,S / 방향키",
		"controls.value.keyboard.dash_skill": "Space / X / 마우스 왼쪽",
		"controls.value.keyboard.active_item": "1 / 2 / 3",
		"controls.value.keyboard.supply_hold": "S / 마우스 오른쪽",
		"controls.value.keyboard.weapon_switch": "마우스 휠 / 가운데",
		"controls.value.keyboard.confirm_cancel_pause": "Enter / Esc",
		"vibration.1": "약함",
		"vibration.2": "낮음",
		"vibration.3": "보통",
		"vibration.4": "강함",
		"vibration.5": "최대",
		"language.title": "언어",
		"language.subtitle": "언어는 즉시 저장되고 적용됩니다.",
		"language.current": "현재 언어: %s",
		"language.ko": "한국어",
		"language.en": "English",
		"main_menu.quit_prompt": "나가시겠습니까?",
		"main_menu.yes": "예",
		"main_menu.no": "아니오",
	},
	LANGUAGE_ENGLISH: {
		"app.title": "DiskHearts - Ringpia",
		"pause.title": "Paused",
		"pause.continue": "Continue",
		"pause.character_info": "Character Info",
		"pause.options": "Options",
		"settings.title": "Settings",
		"settings.tab.sound": "Sound",
		"settings.tab.display": "Display",
		"settings.tab.controls": "Controls",
		"settings.tab.language": "Language",
		"settings.back": "Back",
		"settings.close": "Close",
		"settings.save": "Save",
		"sound.bgm_volume": "BGM Volume",
		"sound.sfx_volume": "SFX Volume",
		"display.mode": "Display Mode",
		"display.mode.fullscreen": "Fullscreen",
		"display.mode.exclusive": "Exclusive",
		"display.mode.windowed": "Windowed",
		"display.desc.exclusive": "Use exclusive fullscreen and bypass DWM composition.",
		"display.desc.fullscreen": "Use native-resolution fullscreen.",
		"display.desc.windowed": "Use windowed mode with pillar backgrounds.",
		"display.render_fps": "Render FPS",
		"display.fps.unlimited": "Unlimited",
		"display.fps.monitor": "Monitor %d Hz",
		"display.remember.title": "Save Current Display Settings",
		"display.remember.subtitle": "Use this display mode and refresh pacing next launch",
		"display.auto60.title": "Auto-Switch to 60Hz",
		"display.auto60.subtitle": "Use only when a monitor needs 60Hz pacing",
		"display.recommend.apply": "Apply Recommended",
		"display.apply60": "60Hz Mode",
		"display.recommendation.ready": "%dHz monitor detected: render FPS will follow the current refresh rate.\nIf you switch monitors, it updates on the next apply.",
		"display.recommendation.monitor": "%dHz monitor detected: render FPS follows the current refresh rate.\nExclusive fullscreen with VSync Auto is recommended.",
		"display.recommendation.default": "%dHz monitor detected: set render FPS to monitor Hz for automatic pacing.\nApply Recommended saves settings based on the current refresh rate.",
		"display.recommendation.fallback": "Set render FPS to monitor Hz for automatic refresh-rate pacing.\nExclusive fullscreen with VSync Auto is recommended.",
		"controls.device": "Input Device",
		"controls.keyboard_mouse": "Keyboard+Mouse",
		"controls.joypad": "Gamepad",
		"controls.vibration": "Vibration Sensitivity",
		"controls.map.move": "Move",
		"controls.map.dash_skill": "Dash / Skill",
		"controls.map.active_item": "Active Item",
		"controls.map.supply_hold": "Hold Supply",
		"controls.map.weapon_switch": "Switch Weapon",
		"controls.map.confirm_cancel_pause": "Confirm / Cancel / Pause",
		"controls.value.joypad.move": "Left Stick / D-pad",
		"controls.value.joypad.dash_skill": "Dash: B or Down / Skill: A / X / RT",
		"controls.value.joypad.active_item": "LB/RB or Right Stick Left/Right to select / Y to use",
		"controls.value.joypad.supply_hold": "LT",
		"controls.value.joypad.weapon_switch": "Right Stick Up/Down / R3",
		"controls.value.joypad.confirm_cancel_pause": "A / B / Menu",
		"controls.value.keyboard.move": "A,D,W,S / Arrow Keys",
		"controls.value.keyboard.dash_skill": "Space / X / Left Mouse",
		"controls.value.keyboard.active_item": "1 / 2 / 3",
		"controls.value.keyboard.supply_hold": "S / Right Mouse",
		"controls.value.keyboard.weapon_switch": "Mouse Wheel / Middle",
		"controls.value.keyboard.confirm_cancel_pause": "Enter / Esc",
		"vibration.1": "Weak",
		"vibration.2": "Low",
		"vibration.3": "Normal",
		"vibration.4": "Strong",
		"vibration.5": "Max",
		"language.title": "Language",
		"language.subtitle": "Language is saved and applied immediately.",
		"language.current": "Current Language: %s",
		"language.ko": "Korean",
		"language.en": "English",
		"main_menu.quit_prompt": "Quit the game?",
		"main_menu.yes": "Yes",
		"main_menu.no": "No",
	},
}

static var _cached_language := ""


static func apply_saved_language() -> String:
	var language := get_language()
	_apply_engine_locale(language)
	return language


static func get_language() -> String:
	if not _cached_language.is_empty():
		return _cached_language
	var config := _load_settings()
	_cached_language = normalize_language(str(config.get_value(SETTINGS_SECTION, SETTINGS_LANGUAGE_KEY, DEFAULT_LANGUAGE)))
	_apply_engine_locale(_cached_language)
	return _cached_language


static func set_language(language: String) -> String:
	var normalized := normalize_language(language)
	_cached_language = normalized
	_apply_engine_locale(normalized)
	var config := _load_settings()
	config.set_value(SETTINGS_SECTION, SETTINGS_SCHEMA_KEY, SETTINGS_SCHEMA_VERSION)
	config.set_value(SETTINGS_SECTION, SETTINGS_LANGUAGE_KEY, normalized)
	if config.save(SETTINGS_PATH) != OK:
		push_warning("Failed to save language settings: %s" % SETTINGS_PATH)
	return normalized


static func reset_cache_for_tests() -> void:
	_cached_language = ""


static func normalize_language(language: String) -> String:
	var normalized := language.strip_edges().to_lower()
	if normalized == "en_us" or normalized == "en-us":
		normalized = LANGUAGE_ENGLISH
	if normalized == "ko_kr" or normalized == "ko-kr":
		normalized = LANGUAGE_KOREAN
	if SUPPORTED_LANGUAGES.has(normalized):
		return normalized
	return DEFAULT_LANGUAGE


static func get_language_options() -> Array[String]:
	return SUPPORTED_LANGUAGES.duplicate()


static func get_native_language_name(language: String) -> String:
	var normalized := normalize_language(language)
	return str(LANGUAGE_NATIVE_NAMES.get(normalized, normalized))


static func translate(key: String, fallback: String = "") -> String:
	var language := get_language()
	var table: Dictionary = TEXT.get(language, {})
	if table.has(key):
		return str(table[key])
	var fallback_table: Dictionary = TEXT.get(DEFAULT_LANGUAGE, {})
	if fallback_table.has(key):
		return str(fallback_table[key])
	if not fallback.is_empty():
		return fallback
	return key


static func _load_settings() -> ConfigFile:
	var config := ConfigFile.new()
	if FileAccess.file_exists(SETTINGS_PATH):
		var result := config.load(SETTINGS_PATH)
		if result != OK:
			return ConfigFile.new()
	return config


static func _apply_engine_locale(language: String) -> void:
	TranslationServer.set_locale(normalize_language(language))
