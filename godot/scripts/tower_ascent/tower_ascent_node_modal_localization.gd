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
const KEY_COST_MUHON := "tower_ascent.node_modal.cost.muhon"
const KEY_INSUFFICIENT_MUHON := "tower_ascent.node_modal.insufficient.muhon"
const KEY_TRAINING_STAT_OPTION := "tower_ascent.node_modal.training.stat_option"
const KEY_TRAINING_MUGONG_OPTION := "tower_ascent.node_modal.training.mugong_option"
const KEY_TRAINING_CHOICE_USED := "tower_ascent.node_modal.training.choice_used"
const KEY_TRAINING_VISIT_COMPLETE := "tower_ascent.node_modal.training.visit_complete"
const KEY_TRAINING_COMPLETED := "tower_ascent.node_modal.training.completed"
const KEY_TRAINING_OFFER_UNAVAILABLE := "tower_ascent.node_modal.training.offer_unavailable"
const KEY_MONK_ACQUIRE_OPTION := "tower_ascent.node_modal.fallen_monk.acquire_option"
const KEY_MONK_SWAP_OPTION := "tower_ascent.node_modal.fallen_monk.swap_option"
const KEY_MONK_REMOVE_OPTION := "tower_ascent.node_modal.fallen_monk.remove_option"
const KEY_MONK_ACQUIRE_USED := "tower_ascent.node_modal.fallen_monk.acquire_used"
const KEY_MONK_SWAP_USED := "tower_ascent.node_modal.fallen_monk.swap_used"
const KEY_MONK_REMOVE_USED := "tower_ascent.node_modal.fallen_monk.remove_used"
const KEY_MONK_ACQUIRE_COMPLETED := "tower_ascent.node_modal.fallen_monk.acquire_completed"
const KEY_MONK_SWAP_COMPLETED := "tower_ascent.node_modal.fallen_monk.swap_completed"
const KEY_MONK_REMOVE_COMPLETED := "tower_ascent.node_modal.fallen_monk.remove_completed"
const KEY_MONK_OFFER_UNAVAILABLE := "tower_ascent.node_modal.fallen_monk.offer_unavailable"
const KEY_COST_FREE := "tower_ascent.node_modal.cost.free"
const KEY_SPRING_SOUL_SUMMONING_OPTION := "tower_ascent.node_modal.guardian_spring.soul_summoning_option"
const KEY_SPRING_FIRST_VISIT_COMPLETE := "tower_ascent.node_modal.guardian_spring.first_visit_complete"
const KEY_SPRING_ENHANCE_OPTION := "tower_ascent.node_modal.guardian_spring.enhance_option"
const KEY_SPRING_SWAP_OPTION := "tower_ascent.node_modal.guardian_spring.swap_option"
const KEY_SPRING_ABSORB_OPTION := "tower_ascent.node_modal.guardian_spring.absorb_option"
const KEY_SPRING_RUNTIME_UNAVAILABLE := "tower_ascent.node_modal.guardian_spring.runtime_unavailable"
const KEY_SPRING_ENHANCE_UNAVAILABLE := "tower_ascent.node_modal.guardian_spring.enhance_unavailable"
const KEY_SPRING_ACTIVE_GUARDIAN_REQUIRED := "tower_ascent.node_modal.guardian_spring.active_guardian_required"
const KEY_SPRING_SOUL_SUMMONING_COMPLETED := "tower_ascent.node_modal.guardian_spring.soul_summoning_completed"
const KEY_SPRING_ENHANCE_COMPLETED := "tower_ascent.node_modal.guardian_spring.enhance_completed"
const KEY_SPRING_SWAP_COMPLETED := "tower_ascent.node_modal.guardian_spring.swap_completed"
const KEY_SPRING_ABSORB_COMPLETED := "tower_ascent.node_modal.guardian_spring.absorb_completed"
const KEY_SPRING_ACTION_UNAVAILABLE := "tower_ascent.node_modal.guardian_spring.action_unavailable"
const KEY_REST_RESTORE_OPTION := "tower_ascent.node_modal.rest.restore_option"
const KEY_REST_ALREADY_USED := "tower_ascent.node_modal.rest.already_used"
const KEY_REST_CHANCE_GEMS_FULL := "tower_ascent.node_modal.rest.chance_gems_full"
const KEY_REST_COMPLETED := "tower_ascent.node_modal.rest.completed"

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
		KEY_BALANCE_GOLD: "금화 {amount}",
		KEY_END_WORK: "업무 종료",
		KEY_STATUS_READY: "할 일을 고르거나 업무를 마치세요.",
		KEY_STATUS_DISABLED: "지금은 선택할 수 없습니다.",
		KEY_COST_GOLD: "{amount} 금화",
		KEY_INSUFFICIENT_GOLD: "금화 {required} 필요, {shortfall} 부족",
		KEY_SHOP_PREMIUM_ITEM: "귀물 진열: {name}",
		KEY_SHOP_CAPSULE: "액티브 캡슐",
		KEY_SHOP_CHANCE_GEM: "기회의 보석",
		KEY_SHOP_SOLD_OUT: "매진",
		KEY_SHOP_SLOT_FULL: "액티브 슬롯이 가득 찼습니다.",
		KEY_SHOP_GEM_FULL: "기회의 보석이 이미 가득 찼습니다.",
		KEY_SHOP_PURCHASED: "{name} 구매 완료",
		KEY_SHOP_INVENTORY_UNAVAILABLE: "상점 재고를 준비할 수 없습니다.",
		KEY_COST_MUHON: "{amount} 무혼",
		KEY_INSUFFICIENT_MUHON: "무혼 {required} 필요, {shortfall} 부족",
		KEY_TRAINING_STAT_OPTION: "체질 수련: {name}",
		KEY_TRAINING_MUGONG_OPTION: "무공 서가: {name}",
		KEY_TRAINING_CHOICE_USED: "선택 완료",
		KEY_TRAINING_VISIT_COMPLETE: "이번 방문의 수련을 모두 마쳤습니다.",
		KEY_TRAINING_COMPLETED: "{name} 습득 완료",
		KEY_TRAINING_OFFER_UNAVAILABLE: "수련 선택지를 준비할 수 없습니다.",
		KEY_MONK_ACQUIRE_OPTION: "초식 습득: {name}",
		KEY_MONK_SWAP_OPTION: "초식 교환: {old_name} 대신 {new_name}",
		KEY_MONK_REMOVE_OPTION: "초식 제거: {name}",
		KEY_MONK_ACQUIRE_USED: "이번 방문의 초식 습득을 마쳤습니다.",
		KEY_MONK_SWAP_USED: "이번 방문의 초식 교환을 마쳤습니다.",
		KEY_MONK_REMOVE_USED: "이번 방문의 초식 제거를 마쳤습니다.",
		KEY_MONK_ACQUIRE_COMPLETED: "{name} 습득 완료",
		KEY_MONK_SWAP_COMPLETED: "{name} 교환 완료",
		KEY_MONK_REMOVE_COMPLETED: "{name} 제거 완료",
		KEY_MONK_OFFER_UNAVAILABLE: "파계승의 초식 선택지를 준비할 수 없습니다.",
		KEY_COST_FREE: "무료",
		KEY_SPRING_SOUL_SUMMONING_OPTION: "영혼소환술 습득",
		KEY_SPRING_FIRST_VISIT_COMPLETE: "영혼소환술을 익혔습니다. 다음 샘터부터 수호령을 정비할 수 있습니다.",
		KEY_SPRING_ENHANCE_OPTION: "수호령 강화: {name}",
		KEY_SPRING_SWAP_OPTION: "봉인 해제 및 교체: {name}",
		KEY_SPRING_ABSORB_OPTION: "봉인 수호령 흡수: {name}",
		KEY_SPRING_RUNTIME_UNAVAILABLE: "수호령 기능을 준비할 수 없습니다.",
		KEY_SPRING_ENHANCE_UNAVAILABLE: "현재 수호령에 적용할 강화가 없습니다.",
		KEY_SPRING_ACTIVE_GUARDIAN_REQUIRED: "흡수할 힘을 받을 동행 수호령이 필요합니다.",
		KEY_SPRING_SOUL_SUMMONING_COMPLETED: "영혼소환술 습득 완료",
		KEY_SPRING_ENHANCE_COMPLETED: "수호령 강화 완료",
		KEY_SPRING_SWAP_COMPLETED: "{name} 교체 완료",
		KEY_SPRING_ABSORB_COMPLETED: "{name} 흡수 완료",
		KEY_SPRING_ACTION_UNAVAILABLE: "샘터에서 처리할 수호령 업무가 없습니다.",
		KEY_REST_RESTORE_OPTION: "기회의 보석 {amount}개 회복",
		KEY_REST_ALREADY_USED: "이 휴식 노드의 회복을 이미 마쳤습니다.",
		KEY_REST_CHANCE_GEMS_FULL: "기회의 보석이 최대 {maximum}개입니다.",
		KEY_REST_COMPLETED: "기회의 보석 {amount}개 회복 완료",
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
	LanguageSettings.LANGUAGE_ENGLISH: {
		KEY_BALANCE_GOLD: "Gold {amount}",
		KEY_COST_GOLD: "{amount} Gold",
		KEY_INSUFFICIENT_GOLD: "Requires {required} Gold, {shortfall} short",
	},
	LanguageSettings.LANGUAGE_CHINESE: {
		KEY_BALANCE_GOLD: "金币 {amount}",
		KEY_COST_GOLD: "{amount} 金币",
		KEY_INSUFFICIENT_GOLD: "需要 {required} 金币，还差 {shortfall}",
	},
	LanguageSettings.LANGUAGE_JAPANESE: {
		KEY_BALANCE_GOLD: "金貨 {amount}",
		KEY_COST_GOLD: "{amount} 金貨",
		KEY_INSUFFICIENT_GOLD: "金貨が{required}必要、あと{shortfall}",
	},
	LanguageSettings.LANGUAGE_SPANISH: {
		KEY_BALANCE_GOLD: "Oro {amount}",
		KEY_COST_GOLD: "{amount} de oro",
		KEY_INSUFFICIENT_GOLD: "Se necesitan {required} de oro, faltan {shortfall}",
	},
	LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: {
		KEY_BALANCE_GOLD: "Ouro {amount}",
		KEY_COST_GOLD: "{amount} de ouro",
		KEY_INSUFFICIENT_GOLD: "Requer {required} de ouro, faltam {shortfall}",
	},
	LanguageSettings.LANGUAGE_RUSSIAN: {
		KEY_BALANCE_GOLD: "Золото: {amount}",
		KEY_COST_GOLD: "{amount} золота",
		KEY_INSUFFICIENT_GOLD: "Нужно {required} золота, не хватает {shortfall}",
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
	var registered_keys := get_registered_keys()
	for locale in LanguageSettings.SUPPORTED_LANGUAGES:
		if locale == LanguageSettings.LANGUAGE_KOREAN:
			continue
		var locale_text: Dictionary = TEXT_BY_LOCALE.get(locale, {})
		for key in registered_keys:
			if not locale_text.has(key):
				result.append(locale)
				break
	return result
