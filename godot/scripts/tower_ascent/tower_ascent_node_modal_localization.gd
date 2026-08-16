extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const KEY_HEADER_TITLE := "tower_ascent.node_modal.header.title"
const KEY_BALANCE_MUHON := "tower_ascent.node_modal.balance.muhon"
const KEY_BALANCE_GOLD := "tower_ascent.node_modal.balance.gold"
const KEY_END_WORK := "tower_ascent.node_modal.action.end_work"
const KEY_STATUS_READY := "tower_ascent.node_modal.status.ready"
const KEY_STATUS_DISABLED := "tower_ascent.node_modal.status.disabled"
const KEY_COST_GOLD := "tower_ascent.node_modal.cost.gold"
const KEY_INSUFFICIENT_GOLD := "tower_ascent.node_modal.insufficient.gold"
const KEY_SHOP_PREMIUM_ITEM := "tower_ascent.node_modal.shop.item.premium"
const KEY_SHOP_CAPSULE := "tower_ascent.node_modal.shop.item.capsule"
const KEY_SHOP_CHANCE_GEM := "tower_ascent.node_modal.shop.item.chance_gem"
const KEY_SHOP_SOLD_OUT := "tower_ascent.node_modal.shop.sold_out"
const KEY_SHOP_SLOT_FULL := "tower_ascent.node_modal.shop.slot_full"
const KEY_SHOP_GEM_FULL := "tower_ascent.node_modal.shop.gem_full"
const KEY_SHOP_PURCHASED := "tower_ascent.node_modal.shop.purchased"
const KEY_SHOP_INVENTORY_UNAVAILABLE := "tower_ascent.node_modal.shop.inventory_unavailable"

const NODE_TITLE_KEYS := {
	"shop": "tower_ascent.node_modal.shop.title",
	"training": "tower_ascent.node_modal.training.title",
	"fallen_monk": "tower_ascent.node_modal.fallen_monk.title",
	"guardian_spring": "tower_ascent.node_modal.guardian_spring.title",
	"rest": "tower_ascent.node_modal.rest.title",
	"common_shell": "tower_ascent.node_modal.common_shell.title",
}
const NODE_DESCRIPTION_KEYS := {
	"shop": "tower_ascent.node_modal.shop.description",
	"training": "tower_ascent.node_modal.training.description",
	"fallen_monk": "tower_ascent.node_modal.fallen_monk.description",
	"guardian_spring": "tower_ascent.node_modal.guardian_spring.description",
	"rest": "tower_ascent.node_modal.rest.description",
	"common_shell": "tower_ascent.node_modal.common_shell.description",
}

const TEXT_BY_LOCALE := {
	LanguageSettings.LANGUAGE_KOREAN: {
		KEY_HEADER_TITLE: "승천탑 행로",
		KEY_BALANCE_MUHON: "무혼 {amount}",
		KEY_BALANCE_GOLD: "골드 {amount}",
		KEY_END_WORK: "업무 종료",
		KEY_STATUS_READY: "할 일을 고르거나 업무를 마치세요.",
		KEY_STATUS_DISABLED: "지금은 선택할 수 없습니다.",
		KEY_COST_GOLD: "{amount} 골드",
		KEY_INSUFFICIENT_GOLD: "골드 {required} 필요, {shortfall} 부족",
		KEY_SHOP_PREMIUM_ITEM: "귀물 진열: {name}",
		KEY_SHOP_CAPSULE: "액티브 캡슐",
		KEY_SHOP_CHANCE_GEM: "기회의 보석",
		KEY_SHOP_SOLD_OUT: "매진",
		KEY_SHOP_SLOT_FULL: "액티브 슬롯이 가득 찼습니다.",
		KEY_SHOP_GEM_FULL: "기회의 보석이 이미 가득 찼습니다.",
		KEY_SHOP_PURCHASED: "{name} 구매 완료",
		KEY_SHOP_INVENTORY_UNAVAILABLE: "상점 재고를 준비할 수 없습니다.",
		"tower_ascent.node_modal.shop.title": "상점",
		"tower_ascent.node_modal.shop.description": "탑 안에서 쓸 물자를 골라 준비합니다.",
		"tower_ascent.node_modal.training.title": "수련장",
		"tower_ascent.node_modal.training.description": "무혼을 다듬어 몸과 무공을 수련합니다.",
		"tower_ascent.node_modal.fallen_monk.title": "파계승",
		"tower_ascent.node_modal.fallen_monk.description": "초식을 익히고 덜어내며 자리를 바꿉니다.",
		"tower_ascent.node_modal.guardian_spring.title": "수호의 샘터",
		"tower_ascent.node_modal.guardian_spring.description": "전투가 멎은 사이, 수호령과 인연을 정비합니다.",
		"tower_ascent.node_modal.rest.title": "휴식",
		"tower_ascent.node_modal.rest.description": "잠시 숨을 고르고 다음 행로를 준비합니다.",
		"tower_ascent.node_modal.common_shell.title": "행로 정비",
		"tower_ascent.node_modal.common_shell.description": "전투가 멎은 사이, 다음 행로를 정비합니다.",
	},
}


static func text(key: String, values: Dictionary = {}) -> String:
	var locale := LanguageSettings.get_language()
	var locale_text: Dictionary = TEXT_BY_LOCALE.get(locale, {})
	var fallback_text: Dictionary = TEXT_BY_LOCALE.get(LanguageSettings.LANGUAGE_KOREAN, {})
	var value := str(locale_text.get(key, fallback_text.get(key, key)))
	return value.format(values)


static func node_title(node_kind: String) -> String:
	return text(str(NODE_TITLE_KEYS.get(node_kind, NODE_TITLE_KEYS.common_shell)))


static func node_description(node_kind: String) -> String:
	return text(str(NODE_DESCRIPTION_KEYS.get(node_kind, NODE_DESCRIPTION_KEYS.common_shell)))


static func get_registered_keys() -> Array[String]:
	var result: Array[String] = []
	var korean_text: Dictionary = TEXT_BY_LOCALE.get(LanguageSettings.LANGUAGE_KOREAN, {})
	for key_value in korean_text.keys():
		result.append(str(key_value))
	result.sort()
	return result


static func get_missing_translation_locales() -> Array[String]:
	var result: Array[String] = []
	for locale in LanguageSettings.SUPPORTED_LANGUAGES:
		if locale != LanguageSettings.LANGUAGE_KOREAN and not TEXT_BY_LOCALE.has(locale):
			result.append(locale)
	return result
