extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const TEXT := {
	"title": {
		"ko": "첫 길을 고르십시오",
		"en": "Choose Your First Path",
		"zh": "选择你的初始道路",
		"ja": "最初の道を選べ",
		"es": "Elige tu primer camino",
		"pt-BR": "Escolha seu primeiro caminho",
		"ru": "Выберите первый путь",
	},
	"instruction": {
		"ko": "3장 중 1장을 고르십시오",
		"en": "Choose 1 of 3 cards",
		"zh": "从3张卡中选择1张",
		"ja": "3枚から1枚を選んでください",
		"es": "Elige 1 de 3 cartas",
		"pt-BR": "Escolha 1 de 3 cartas",
		"ru": "Выберите 1 из 3 карт",
	},
	"random_autoselect_notice": {
		"ko": "선택하지 않으면 무작위 카드가 선택됩니다",
		"en": "If you do not choose, a random card will be selected",
		"zh": "若不选择，将随机选择一张卡牌",
		"ja": "選択しない場合、カードがランダムに選ばれます",
		"es": "Si no eliges, se seleccionará una carta al azar",
		"pt-BR": "Se você não escolher, uma carta será selecionada aleatoriamente",
		"ru": "Если вы не выберете, карта будет выбрана случайно",
	},
	"confirmed": {
		"ko": "선택이 운명에 새겨졌습니다",
		"en": "Your choice is etched into fate",
		"zh": "你的选择已铭刻于命运",
		"ja": "選択が運命に刻まれた",
		"es": "Tu elección quedó grabada en el destino",
		"pt-BR": "Sua escolha foi gravada no destino",
		"ru": "Ваш выбор вписан в судьбу",
	},
}


static func text(key: String) -> String:
	var entries: Dictionary = TEXT.get(key, {})
	var locale := LanguageSettings.get_language()
	return str(entries.get(locale, entries.get("en", key)))


static func get_supported_locales() -> Array[String]:
	return ["ko", "en", "zh", "ja", "es", "pt-BR", "ru"]


static func text_for_locale(key: String, locale: String) -> String:
	var entries: Dictionary = TEXT.get(key, {})
	return str(entries.get(locale, entries.get("en", key)))
