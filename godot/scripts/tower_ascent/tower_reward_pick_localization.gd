extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const TEXT := {
	"title": {
		"ko": "승리 보상", "en": "Victory Reward", "zh": "胜利奖励", "ja": "勝利報酬",
		"es": "Recompensa de victoria", "pt-BR": "Recompensa da vitória", "ru": "Награда за победу",
	},
	"continue": {
		"ko": "계속하기", "en": "Continue", "zh": "继续", "ja": "続ける",
		"es": "Continuar", "pt-BR": "Continuar", "ru": "Продолжить",
	},
	"balance": {
		"ko": "무혼 : {amount}개", "en": "Muhon : {amount}", "zh": "武魂 : {amount}个", "ja": "武魂 : {amount}個",
		"es": "Muhon : {amount}", "pt-BR": "Muhon : {amount}", "ru": "Мухон : {amount} шт.",
	},
	"victory_margin_reward": {
		"ko": "무혼 +{amount} (점수차 보상)", "en": "Muhon +{amount} (victory margin reward)", "zh": "武魂 +{amount}（分差奖励）", "ja": "武魂 +{amount}（得点差報酬）",
		"es": "Muhon +{amount} (recompensa por diferencia de puntos)", "pt-BR": "Muhon +{amount} (recompensa por diferença de pontos)", "ru": "Мухон +{amount} (награда за разницу в счёте)",
	},
	"price": {
		"ko": "무혼 {amount}", "en": "{amount} Muhon", "zh": "武魂 {amount}", "ja": "武魂 {amount}",
		"es": "{amount} Muhon", "pt-BR": "{amount} Muhon", "ru": "{amount} мухон",
	},
	"spent": {
		"ko": "구매 완료", "en": "Purchased", "zh": "已购买", "ja": "購入済み",
		"es": "Comprado", "pt-BR": "Comprado", "ru": "Куплено",
	},
	"insufficient": {
		"ko": "무혼이 부족합니다", "en": "Not enough Muhon", "zh": "武魂不足", "ja": "武魂が足りません",
		"es": "Muhon insuficiente", "pt-BR": "Muhon insuficiente", "ru": "Недостаточно мухона",
	},
	"hint": {
		"ko": "카드를 여러 장 살 수 있습니다", "en": "You may buy multiple cards", "zh": "可以购买多张卡牌", "ja": "複数のカードを購入できます",
		"es": "Puedes comprar varias cartas", "pt-BR": "Você pode comprar várias cartas", "ru": "Можно купить несколько карт",
	},
	"vision_swap": {
		"ko": "초식 교체 필요", "en": "Form swap required", "zh": "需要替换招式", "ja": "技の入れ替えが必要",
		"es": "Requiere cambiar técnica", "pt-BR": "Requer trocar técnica", "ru": "Нужно заменить приём",
	},
}


static func text(key: String, replacements: Dictionary = {}) -> String:
	var entries: Dictionary = TEXT.get(key, {})
	var locale := LanguageSettings.get_language()
	var value := str(entries.get(locale, entries.get("en", key)))
	for replacement_key in replacements:
		value = value.replace("{%s}" % str(replacement_key), str(replacements[replacement_key]))
	return value
