extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ServeWaitIndicatorRenderer := preload("res://scripts/hud/serve_wait_indicator_renderer.gd")

const LOCALE_CASES := [
	{
		"locale": LanguageSettings.LANGUAGE_KOREAN,
		"dalji": "달지 차례",
		"generic": "보스 차례",
		"player": "플레이어 서브",
		"preparing": "준비중..",
		"ready": "준비 완료",
	},
	{
		"locale": LanguageSettings.LANGUAGE_ENGLISH,
		"dalji": "Dalji Serve",
		"generic": "Boss Serve",
		"player": "Player Serve",
		"preparing": "Preparing...",
		"ready": "Ready",
	},
	{
		"locale": LanguageSettings.LANGUAGE_CHINESE,
		"dalji": "达尔吉 Serve",
		"generic": "首领 Serve",
		"player": "玩家发球",
		"preparing": "Preparing...",
		"ready": "Ready",
	},
	{
		"locale": LanguageSettings.LANGUAGE_JAPANESE,
		"dalji": "ダルジ Serve",
		"generic": "ボス Serve",
		"player": "プレイヤーのサーブ",
		"preparing": "Preparing...",
		"ready": "Ready",
	},
	{
		"locale": LanguageSettings.LANGUAGE_SPANISH,
		"dalji": "Dalji Serve",
		"generic": "Jefe Serve",
		"player": "Saque del jugador",
		"preparing": "Preparing...",
		"ready": "Ready",
	},
	{
		"locale": LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL,
		"dalji": "Dalji Serve",
		"generic": "Chefe Serve",
		"player": "Saque do jogador",
		"preparing": "Preparing...",
		"ready": "Ready",
	},
	{
		"locale": LanguageSettings.LANGUAGE_RUSSIAN,
		"dalji": "Dalji Serve",
		"generic": "Босс Serve",
		"player": "Подача игрока",
		"preparing": "Preparing...",
		"ready": "Ready",
	},
]

const REMOVED_PANEL_TOKENS := [
	"BOSS_PANEL_MAX_WIDTH",
	"BOSS_PANEL_HEIGHT",
	"BOSS_PANEL_TOP",
	"BOSS_PROGRESS_HEIGHT",
	"_draw_boss_serve_panel(",
	"fill_rect.grow(6.0)",
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_all_supported_locales()
	_verify_production_renderer_contract()
	LanguageSettings.set_test_locale_override("")

	if _failures.is_empty():
		print("serve_wait_indicator_localization_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_all_supported_locales() -> void:
	var renderer := ServeWaitIndicatorRenderer.new()
	var covered_locales: Array[String] = []
	for locale_case in LOCALE_CASES:
		var locale := str(locale_case.get("locale", ""))
		covered_locales.append(locale)
		LanguageSettings.set_test_locale_override(locale)
		_expect(
			renderer._get_serve_label(false, {"current_stage": 1}) == str(locale_case.get("dalji", "")),
			"%s stage-one boss turn label should match its locale contract" % locale
		)
		_expect(
			renderer._get_serve_label(false, {"current_stage": 2}) == str(locale_case.get("generic", "")),
			"%s generic boss turn label should match its locale contract" % locale
		)
		_expect(
			renderer._get_serve_label(true, {"current_stage": 1}) == str(locale_case.get("player", "")),
			"%s player serve label should retain the Z7 localization structure" % locale
		)
		var preparing := LanguageSettings.translate("hud.serve_wait.preparing")
		var ready := LanguageSettings.translate("hud.serve_wait.ready")
		_expect(preparing == str(locale_case.get("preparing", "")), "%s preparing copy should match" % locale)
		_expect(ready == str(locale_case.get("ready", "")), "%s ready copy should match" % locale)
		if locale == LanguageSettings.LANGUAGE_KOREAN:
			_expect(preparing.ends_with("..") and preparing.find("…") < 0, "Korean preparing copy should preserve the user's two periods")
		else:
			_expect(renderer._get_serve_label(false, {"current_stage": 1}).ends_with(" Serve"), "%s boss format should retain the original English Serve suffix" % locale)
			_expect(preparing == "Preparing..." and ready == "Ready", "%s boss status should retain the original English copy" % locale)
	covered_locales.sort()
	var supported_locales := LanguageSettings.SUPPORTED_LANGUAGES.duplicate()
	supported_locales.sort()
	_expect(covered_locales == supported_locales, "locale seal should cover every supported language exactly once")


func _verify_production_renderer_contract() -> void:
	var renderer_source := FileAccess.get_file_as_string("res://scripts/hud/serve_wait_indicator_renderer.gd")
	var localization_source := FileAccess.get_file_as_string("res://scripts/core/language_settings_data.gd")
	var rejected_copy := "기를 모으는" + " 중"
	_expect(renderer_source.find(rejected_copy) < 0, "production renderer should remove the rejected charging copy")
	_expect(localization_source.find(rejected_copy) < 0, "localization data should remove the rejected charging copy")
	_expect(renderer_source.find("var center := Vector2(width * 0.5, 80.0)") >= 0, "boss wait title should return to the original y=80 anchor")
	_expect(renderer_source.find("_draw_accent_line(canvas, width, serve_rect, accent_color)") >= 0, "boss wait title should retain the original single accent line")
	_expect(renderer_source.find("INFO_FONT_SIZE := 16") >= 0, "boss wait status should restore the original font size")
	_expect(renderer_source.find("hud.serve_wait.boss_turn_format") >= 0, "boss turn title should use the seven-locale key")
	_expect(renderer_source.find("hud.serve_wait.preparing") >= 0, "preparing copy should use the seven-locale key")
	_expect(renderer_source.find("hud.serve_wait.ready") >= 0, "ready copy should use the seven-locale key")
	for token in REMOVED_PANEL_TOKENS:
		_expect(renderer_source.find(token) < 0, "rejected boss panel token should stay removed: %s" % token)
	_expect(renderer_source.find("canvas.draw_circle(") < 0, "boss wait renderer should not retain moving light motes")
	_expect(renderer_source.find("\"Preparing...\"") < 0, "production renderer should not hardcode the English preparing copy")
	_expect(renderer_source.find("\"Ready\"") < 0, "production renderer should not hardcode the English ready copy")
	_expect(renderer_source.find("%s Serve") < 0, "production renderer should not hardcode the non-Korean title format")
	_expect(renderer_source.find("—") < 0, "boss serve Korean copy should not contain an em dash")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
