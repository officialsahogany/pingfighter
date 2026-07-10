extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")

const PERK_ID := "angel_blessing"
const EXPECTED := {
	"en": {
		"name": "Angel's Dice",
		"summary": "Gain 1–3 different blessings each stage (30% effect).",
	},
	"zh": {
		"name": "天使骰子",
		"summary": "每关获得1～3种不同的祝福（效果30%）。",
	},
	"ja": {
		"name": "天使のダイス",
		"summary": "ステージごとに異なる祝福を1～3個獲得します（効果30%）。",
	},
	"es": {
		"name": "Dado angelical",
		"summary": "Obtén de 1 a 3 bendiciones diferentes en cada fase (efecto del 30%).",
	},
	"pt-BR": {
		"name": "Dado angelical",
		"summary": "Receba de 1 a 3 bênçãos diferentes a cada fase (efeito de 30%).",
	},
	"ru": {
		"name": "Ангельская кость",
		"summary": "На каждом этапе дает 1–3 разных благословения (эффект 30%).",
	},
}

var _failures: Array[String] = []


func _init() -> void:
	var previous_language := LanguageSettings.get_language()
	_expect(
		str(LanguageSettings.PERK_LOCALIZATION_ALIASES.get(PERK_ID, "")) == PERK_ID,
		"Angel Dice should declare its canonical perk localization key"
	)
	_expect(
		LanguageSettings._get_perk_localization_key(PERK_ID) == PERK_ID,
		"Angel Dice localization alias should resolve to angel_blessing"
	)

	for language_value: Variant in EXPECTED.keys():
		var language := str(language_value)
		_verify_language(language, EXPECTED[language] as Dictionary)

	LanguageSettings._cached_language = previous_language
	if _failures.is_empty():
		print("angel_blessing_localization_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_language(language: String, expected: Dictionary) -> void:
	var name_map: Dictionary = LanguageSettings._get_perk_name_map(language)
	var summary_map: Dictionary = LanguageSettings._get_perk_summary_map(language)
	_expect(name_map.has(PERK_ID), "PERK_NAME[%s] should contain angel_blessing" % language)
	_expect(summary_map.has(PERK_ID), "PERK_SUMMARY[%s] should contain angel_blessing" % language)
	_expect(
		str(name_map.get(PERK_ID, "")) == str(expected.get("name", "")),
		"Angel Dice name should match the locked %s terminology" % language
	)
	_expect(
		str(summary_map.get(PERK_ID, "")) == str(expected.get("summary", "")),
		"Angel Dice summary should match the locked %s copy" % language
	)

	LanguageSettings._cached_language = language
	var perk_data: Dictionary = RuntimePerkCatalog.new().get_perk_data(PERK_ID)
	var name := str(perk_data.get("name", "")).strip_edges()
	var description := str(perk_data.get("description", "")).strip_edges()
	var detail := str(perk_data.get("detail", "")).strip_edges()
	var level_summary := str((perk_data.get("descriptions", {}) as Dictionary).get(1, "")).strip_edges()
	_expect(name == str(expected.get("name", "")), "catalog name should localize in %s" % language)
	_expect(description == str(expected.get("summary", "")), "catalog description should localize in %s" % language)
	_expect(detail == description, "catalog detail should use the localized summary in %s" % language)
	_expect(level_summary == description, "catalog Lv.1 copy should use the localized summary in %s" % language)
	for value: String in [name, description, detail, level_summary]:
		_expect(value != "" and value != PERK_ID, "Angel Dice should not fall back to an empty value or ID in %s" % language)
		_expect(not _contains_hangul(value), "Angel Dice should not leave a Hangul fallback in %s: %s" % [language, value])


func _contains_hangul(value: String) -> bool:
	for index: int in range(value.length()):
		var codepoint := value.unicode_at(index)
		if (codepoint >= 0xAC00 and codepoint <= 0xD7A3) or (codepoint >= 0x3130 and codepoint <= 0x318F):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
