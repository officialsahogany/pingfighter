extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ServeWaitIndicatorRenderer := preload("res://scripts/hud/serve_wait_indicator_renderer.gd")

const LOCALE_CASES := [
	{
		"locale": LanguageSettings.LANGUAGE_KOREAN,
		"dalji": "달지의 서브",
		"generic": "보스의 서브",
		"player": "플레이어 서브",
		"charging": "기를 모으는 중…",
		"ready": "준비 완료",
	},
	{
		"locale": LanguageSettings.LANGUAGE_ENGLISH,
		"dalji": "Dalji's Serve",
		"generic": "Boss's Serve",
		"player": "Player Serve",
		"charging": "Gathering strength…",
		"ready": "Ready",
	},
	{
		"locale": LanguageSettings.LANGUAGE_CHINESE,
		"dalji": "达尔吉发球",
		"generic": "首领发球",
		"player": "玩家发球",
		"charging": "正在蓄势…",
		"ready": "准备完成",
	},
	{
		"locale": LanguageSettings.LANGUAGE_JAPANESE,
		"dalji": "ダルジのサーブ",
		"generic": "ボスのサーブ",
		"player": "プレイヤーのサーブ",
		"charging": "力を溜めています…",
		"ready": "準備完了",
	},
	{
		"locale": LanguageSettings.LANGUAGE_SPANISH,
		"dalji": "Saque de Dalji",
		"generic": "Saque de Jefe",
		"player": "Saque del jugador",
		"charging": "Concentrando energía…",
		"ready": "Listo",
	},
	{
		"locale": LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL,
		"dalji": "Saque de Dalji",
		"generic": "Saque de Chefe",
		"player": "Saque do jogador",
		"charging": "Concentrando energia…",
		"ready": "Pronto",
	},
	{
		"locale": LanguageSettings.LANGUAGE_RUSSIAN,
		"dalji": "Подача: Dalji",
		"generic": "Подача: Босс",
		"player": "Подача игрока",
		"charging": "Накапливает силу…",
		"ready": "Готово",
	},
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
			"%s stage-one boss serve label should be localized" % locale
		)
		_expect(
			renderer._get_serve_label(false, {"current_stage": 2}) == str(locale_case.get("generic", "")),
			"%s generic boss serve label should be localized" % locale
		)
		_expect(
			renderer._get_serve_label(true, {"current_stage": 1}) == str(locale_case.get("player", "")),
			"%s player serve label should be localized by the same owner" % locale
		)
		_expect(
			LanguageSettings.translate_text("기를 모으는 중…") == str(locale_case.get("charging", "")),
			"%s charging status should be localized" % locale
		)
		_expect(
			LanguageSettings.translate_text("준비 완료") == str(locale_case.get("ready", "")),
			"%s ready status should be localized" % locale
		)
		if locale != LanguageSettings.LANGUAGE_ENGLISH:
			var visible_text := " ".join([
				renderer._get_serve_label(false, {"current_stage": 2}),
				LanguageSettings.translate_text("기를 모으는 중…"),
				LanguageSettings.translate_text("준비 완료"),
			])
			_expect(
				visible_text.find("Boss") < 0 and visible_text.find("Serve") < 0 and visible_text.find("Preparing") < 0,
				"%s boss wait UI should not leak the former English literals" % locale
			)
	covered_locales.sort()
	var supported_locales := LanguageSettings.SUPPORTED_LANGUAGES.duplicate()
	supported_locales.sort()
	_expect(covered_locales == supported_locales, "locale seal should cover every supported language exactly once")


func _verify_production_renderer_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/serve_wait_indicator_renderer.gd")
	_expect(source.find("\"Preparing...\"") < 0, "production renderer should not retain the hardcoded Preparing literal")
	_expect(source.find("\"Ready\"") < 0, "production renderer should not retain the hardcoded Ready literal")
	_expect(source.find("\"Player Serve\"") < 0, "production renderer should not retain the hardcoded player serve label")
	_expect(source.find("%s Serve") < 0, "production renderer should not retain the English boss label format")
	_expect(source.find("_draw_boss_serve_panel(") >= 0, "boss serve path should delegate to the traditional panel owner")
	_expect(source.find("fill_rect.grow(6.0)") >= 0, "boss serve meter should retain its wide gold glow")
	_expect(source.find("canvas.draw_circle(") >= 0, "boss serve meter should retain moving light motes")
	_expect(source.find("draw_arc(") < 0, "boss serve redesign should not introduce closed procedural rings")
	_expect(source.find("—") < 0, "boss serve Korean copy should not contain an em dash")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
