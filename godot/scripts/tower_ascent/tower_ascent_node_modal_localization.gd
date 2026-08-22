extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const KEY_HEADER_TITLE := "tower_ascent.node_modal.header.title"
const KEY_BALANCE_MUHON := "tower_ascent.node_modal.balance.muhon"
const KEY_BALANCE_GOLD := "tower_ascent.node_modal.balance.gold"
const KEY_BALANCE_RECEIPT_MUHON := "tower_ascent.node_modal.balance_receipt.muhon"
const KEY_BALANCE_RECEIPT_GOLD := "tower_ascent.node_modal.balance_receipt.gold"
const KEY_HOVER_CURRENT_RESULT := "tower_ascent.node_modal.hover.current_result"
const KEY_HOVER_TARGET_COST := "tower_ascent.node_modal.hover.target_cost"
const KEY_HOVER_REJECTION := "tower_ascent.node_modal.hover.rejection"
const KEY_STATE_LISTED := "tower_ascent.node_modal.state.listed"
const KEY_STATE_OWNED := "tower_ascent.node_modal.state.owned"
const KEY_STATE_EMPTY := "tower_ascent.node_modal.state.empty"
const KEY_END_WORK := "tower_ascent.node_modal.action.end_work"
const KEY_STATUS_READY := "tower_ascent.node_modal.status.ready"
const KEY_STATUS_DISABLED := "tower_ascent.node_modal.status.disabled"
const KEY_COST_GOLD := "tower_ascent.node_modal.cost.gold"
const KEY_INSUFFICIENT_GOLD := "tower_ascent.node_modal.insufficient.gold"
const KEY_SHOP_PREMIUM_ITEM := "tower_ascent.node_modal.shop.item.premium"
const KEY_SHOP_CAPSULE := "tower_ascent.node_modal.shop.item.capsule"
const KEY_SHOP_CHANCE_GEM := "tower_ascent.node_modal.shop.item.chance_gem"
const KEY_SHOP_CAPSULE_DESCRIPTION := "tower_ascent.node_modal.shop.capsule.description"
const KEY_SHOP_CHANCE_GEM_DESCRIPTION := "tower_ascent.node_modal.shop.chance_gem.description"
const KEY_SHOP_ACTIVE_RANK := "tower_ascent.node_modal.shop.rank.active"
const KEY_SHOP_CAPSULE_RANK := "tower_ascent.node_modal.shop.rank.capsule"
const KEY_SHOP_RUN_SUPPLY_RANK := "tower_ascent.node_modal.shop.rank.run_supply"
const KEY_SHOP_SOLD_OUT := "tower_ascent.node_modal.shop.sold_out"
const KEY_SHOP_SLOT_FULL := "tower_ascent.node_modal.shop.slot_full"
const KEY_SHOP_GEM_FULL := "tower_ascent.node_modal.shop.gem_full"
const KEY_SHOP_PURCHASED := "tower_ascent.node_modal.shop.purchased"
const KEY_SHOP_INVENTORY_UNAVAILABLE := "tower_ascent.node_modal.shop.inventory_unavailable"
const KEY_COST_MUHON := "tower_ascent.node_modal.cost.muhon"
const KEY_INSUFFICIENT_MUHON := "tower_ascent.node_modal.insufficient.muhon"
const KEY_TRAINING_STAT_OPTION := "tower_ascent.node_modal.training.stat_option"
const KEY_TRAINING_MAXIMUM := "tower_ascent.node_modal.training.maximum"
const KEY_TRAINING_COMPLETED := "tower_ascent.node_modal.training.completed"
const KEY_TRAINING_BONUS_BADGE := "tower_ascent.node_modal.training.bonus_badge"
const KEY_TRAINING_STORAGE_BADGE := "tower_ascent.node_modal.training.storage_badge"
const KEY_TRAINING_BASE_RECEIPT := "tower_ascent.node_modal.training.base_receipt"
const KEY_TRAINING_LUCKY_RECEIPT := "tower_ascent.node_modal.training.lucky_receipt"
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
const KEY_SPRING_CARD_BADGE_SOUL := "tower_ascent.node_modal.guardian_spring.card_badge.soul"
const KEY_SPRING_CARD_BADGE_ENHANCE := "tower_ascent.node_modal.guardian_spring.card_badge.enhance"
const KEY_SPRING_CARD_BADGE_SWAP := "tower_ascent.node_modal.guardian_spring.card_badge.swap"
const KEY_SPRING_CARD_BADGE_ABSORB := "tower_ascent.node_modal.guardian_spring.card_badge.absorb"
const KEY_SPRING_CARD_SOUL_DESCRIPTION := "tower_ascent.node_modal.guardian_spring.card_description.soul"
const KEY_SPRING_CARD_ENHANCE_DESCRIPTION := "tower_ascent.node_modal.guardian_spring.card_description.enhance"
const KEY_SPRING_CARD_SWAP_DESCRIPTION := "tower_ascent.node_modal.guardian_spring.card_description.swap"
const KEY_SPRING_CARD_ABSORB_DESCRIPTION := "tower_ascent.node_modal.guardian_spring.card_description.absorb"
const KEY_SPRING_STATE_ACTIVE := "tower_ascent.node_modal.guardian_spring.state.active"
const KEY_SPRING_STATE_SEALED := "tower_ascent.node_modal.guardian_spring.state.sealed"
const KEY_SPRING_STATE_ENHANCED := "tower_ascent.node_modal.guardian_spring.state.enhanced"
const KEY_SPRING_STATE_ABSORBED := "tower_ascent.node_modal.guardian_spring.state.absorbed"
const KEY_REST_RESTORE_OPTION := "tower_ascent.node_modal.rest.restore_option"
const KEY_REST_ALREADY_USED := "tower_ascent.node_modal.rest.already_used"
const KEY_REST_CHANCE_GEMS_FULL := "tower_ascent.node_modal.rest.chance_gems_full"
const KEY_REST_COMPLETED := "tower_ascent.node_modal.rest.completed"
const KEY_REST_CARD_BADGE := "tower_ascent.node_modal.rest.card_badge"
const KEY_REST_CARD_COMPLETE_BADGE := "tower_ascent.node_modal.rest.card_complete_badge"
const KEY_REST_CARD_DESCRIPTION := "tower_ascent.node_modal.rest.card_description"

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
		KEY_BALANCE_RECEIPT_MUHON: "무혼 {before} → {after}, {delta}",
		KEY_BALANCE_RECEIPT_GOLD: "금화 {before} → {after}, {delta}",
		KEY_HOVER_CURRENT_RESULT: "현재 {current} → 결과 {result}",
		KEY_HOVER_TARGET_COST: "대상 {target} · 비용 {cost}",
		KEY_HOVER_REJECTION: "거부 {reason}",
		KEY_STATE_LISTED: "진열 중",
		KEY_STATE_OWNED: "획득",
		KEY_STATE_EMPTY: "빈 자리",
		KEY_END_WORK: "업무 종료",
		KEY_STATUS_READY: "할 일을 고르거나 업무를 마치세요.",
		KEY_STATUS_DISABLED: "지금은 선택할 수 없습니다.",
		KEY_COST_GOLD: "{amount} 금화",
		KEY_INSUFFICIENT_GOLD: "금화 {required} 필요, {shortfall} 부족",
		KEY_SHOP_PREMIUM_ITEM: "귀물 진열: {name}",
		KEY_SHOP_CAPSULE: "액티브 캡슐",
		KEY_SHOP_CHANCE_GEM: "기회의 보석",
		KEY_SHOP_CAPSULE_DESCRIPTION: "봉인된 액티브 아이템 하나를 획득합니다.",
		KEY_SHOP_CHANCE_GEM_DESCRIPTION: "패배 후 도전을 이어갈 때 쓰는 보석을 1개 얻습니다.",
		KEY_SHOP_ACTIVE_RANK: "{rarity} 액티브",
		KEY_SHOP_CAPSULE_RANK: "액티브 물자",
		KEY_SHOP_RUN_SUPPLY_RANK: "탑 물자",
		KEY_SHOP_SOLD_OUT: "매진",
		KEY_SHOP_SLOT_FULL: "액티브 슬롯이 가득 찼습니다.",
		KEY_SHOP_GEM_FULL: "기회의 보석이 이미 가득 찼습니다.",
		KEY_SHOP_PURCHASED: "{name} 구매 완료",
		KEY_SHOP_INVENTORY_UNAVAILABLE: "상점 재고를 준비할 수 없습니다.",
		KEY_COST_MUHON: "{amount} 무혼",
		KEY_INSUFFICIENT_MUHON: "무혼 {required} 필요, {shortfall} 부족",
		KEY_TRAINING_STAT_OPTION: "체질 수련: {name}",
		KEY_TRAINING_MAXIMUM: "효과 한계",
		KEY_TRAINING_COMPLETED: "{name} 습득 완료",
		KEY_TRAINING_BONUS_BADGE: "행운 20% · 효과 +50%",
		KEY_TRAINING_STORAGE_BADGE: "고정 +1칸",
		KEY_TRAINING_BASE_RECEIPT: "{applied} 적용",
		KEY_TRAINING_LUCKY_RECEIPT: "행운 발동! 기본 {base} -> {applied} 적용",
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
		KEY_SPRING_CARD_BADGE_SOUL: "영혼소환술",
		KEY_SPRING_CARD_BADGE_ENHANCE: "활성 · 강화",
		KEY_SPRING_CARD_BADGE_SWAP: "봉인 · 교체",
		KEY_SPRING_CARD_BADGE_ABSORB: "봉인 · 흡수",
		KEY_SPRING_CARD_SOUL_DESCRIPTION: "영혼소환술을 익혀 첫 수호령을 맞이합니다.",
		KEY_SPRING_CARD_ENHANCE_DESCRIPTION: "활성 수호령에 다음 강화 결과를 적용합니다.",
		KEY_SPRING_CARD_SWAP_DESCRIPTION: "봉인 수호령을 활성 수호령과 교체합니다.",
		KEY_SPRING_CARD_ABSORB_DESCRIPTION: "봉인 수호령의 힘을 활성 수호령에 흡수합니다.",
		KEY_SPRING_STATE_ACTIVE: "활성",
		KEY_SPRING_STATE_SEALED: "봉인",
		KEY_SPRING_STATE_ENHANCED: "강화",
		KEY_SPRING_STATE_ABSORBED: "흡수",
		KEY_REST_RESTORE_OPTION: "기회의 보석 {amount}개 회복",
		KEY_REST_ALREADY_USED: "이 휴식 노드의 회복을 이미 마쳤습니다.",
		KEY_REST_CHANCE_GEMS_FULL: "기회의 보석이 최대 {maximum}개입니다.",
		KEY_REST_COMPLETED: "기회의 보석 {amount}개 회복 완료",
		KEY_REST_CARD_BADGE: "회복",
		KEY_REST_CARD_COMPLETE_BADGE: "완료",
		KEY_REST_CARD_DESCRIPTION: "기회의 보석 {current} → {result}",
		"tower_ascent.node_modal.shop.title": "상점",
		"tower_ascent.node_modal.shop.description": "탑 안에서 쓸 물자를 골라 준비합니다.",
		"tower_ascent.node_modal.training.title": "수련장",
		"tower_ascent.node_modal.training.description": "무혼을 다듬어 몸을 수련합니다.",
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
		KEY_SPRING_CARD_BADGE_SOUL: "Soul Summoning",
		KEY_SPRING_CARD_BADGE_ENHANCE: "Active · Enhance",
		KEY_SPRING_CARD_BADGE_SWAP: "Sealed · Swap",
		KEY_SPRING_CARD_BADGE_ABSORB: "Sealed · Absorb",
		KEY_SPRING_CARD_SOUL_DESCRIPTION: "Learn Soul Summoning and welcome your first guardian.",
		KEY_SPRING_CARD_ENHANCE_DESCRIPTION: "Apply the next enhancement to the active guardian.",
		KEY_SPRING_CARD_SWAP_DESCRIPTION: "Swap this sealed guardian with the active guardian.",
		KEY_SPRING_CARD_ABSORB_DESCRIPTION: "Absorb this sealed guardian into the active guardian.",
		KEY_SPRING_STATE_ACTIVE: "Active",
		KEY_SPRING_STATE_SEALED: "Sealed",
		KEY_SPRING_STATE_ENHANCED: "Enhanced",
		KEY_SPRING_STATE_ABSORBED: "Absorbed",
		KEY_REST_CARD_BADGE: "Restore",
		KEY_REST_CARD_COMPLETE_BADGE: "Complete",
		KEY_REST_CARD_DESCRIPTION: "Chance Gems {current} → {result}",
		KEY_BALANCE_RECEIPT_MUHON: "Mugong Soul {before} → {after}, {delta}",
		KEY_BALANCE_RECEIPT_GOLD: "Gold {before} → {after}, {delta}",
		KEY_HOVER_CURRENT_RESULT: "Now {current} → Result {result}",
		KEY_HOVER_TARGET_COST: "Target {target} · Cost {cost}",
		KEY_HOVER_REJECTION: "Blocked: {reason}",
		KEY_STATE_LISTED: "Listed",
		KEY_STATE_OWNED: "Acquired",
		KEY_STATE_EMPTY: "Empty slot",
		KEY_BALANCE_GOLD: "Gold {amount}",
		KEY_COST_GOLD: "{amount} Gold",
		KEY_INSUFFICIENT_GOLD: "Requires {required} Gold, {shortfall} short",
		KEY_TRAINING_MAXIMUM: "Effect limit",
		KEY_TRAINING_BONUS_BADGE: "Luck 20% · Effect +50%",
		KEY_TRAINING_STORAGE_BADGE: "Fixed +1 slot",
		KEY_TRAINING_BASE_RECEIPT: "Applied {applied}",
		KEY_TRAINING_LUCKY_RECEIPT: "Lucky! Base {base} -> {applied} applied",
		"tower_ascent.node_modal.training.description": "Refine your body through focused training.",
	},
	LanguageSettings.LANGUAGE_CHINESE: {
		KEY_SPRING_CARD_BADGE_SOUL: "灵魂召唤术",
		KEY_SPRING_CARD_BADGE_ENHANCE: "出战 · 强化",
		KEY_SPRING_CARD_BADGE_SWAP: "封印 · 交换",
		KEY_SPRING_CARD_BADGE_ABSORB: "封印 · 吸收",
		KEY_SPRING_CARD_SOUL_DESCRIPTION: "习得灵魂召唤术，迎接首位守护灵。",
		KEY_SPRING_CARD_ENHANCE_DESCRIPTION: "为当前守护灵应用下一次强化。",
		KEY_SPRING_CARD_SWAP_DESCRIPTION: "将封印守护灵与当前守护灵交换。",
		KEY_SPRING_CARD_ABSORB_DESCRIPTION: "将封印守护灵的力量融入当前守护灵。",
		KEY_SPRING_STATE_ACTIVE: "出战",
		KEY_SPRING_STATE_SEALED: "封印",
		KEY_SPRING_STATE_ENHANCED: "强化",
		KEY_SPRING_STATE_ABSORBED: "吸收",
		KEY_REST_CARD_BADGE: "恢复",
		KEY_REST_CARD_COMPLETE_BADGE: "完成",
		KEY_REST_CARD_DESCRIPTION: "机会宝石 {current} → {result}",
		KEY_BALANCE_RECEIPT_MUHON: "武魂 {before} → {after}, {delta}",
		KEY_BALANCE_RECEIPT_GOLD: "金币 {before} → {after}, {delta}",
		KEY_HOVER_CURRENT_RESULT: "当前 {current} → 结果 {result}",
		KEY_HOVER_TARGET_COST: "目标 {target} · 花费 {cost}",
		KEY_HOVER_REJECTION: "无法执行：{reason}",
		KEY_STATE_LISTED: "陈列中",
		KEY_STATE_OWNED: "已获得",
		KEY_STATE_EMPTY: "空位",
		KEY_BALANCE_GOLD: "金币 {amount}",
		KEY_COST_GOLD: "{amount} 金币",
		KEY_INSUFFICIENT_GOLD: "需要 {required} 金币，还差 {shortfall}",
		KEY_TRAINING_MAXIMUM: "效果上限",
		KEY_TRAINING_BONUS_BADGE: "幸运 20% · 效果 +50%",
		KEY_TRAINING_STORAGE_BADGE: "固定 +1 格",
		KEY_TRAINING_BASE_RECEIPT: "已应用 {applied}",
		KEY_TRAINING_LUCKY_RECEIPT: "幸运触发！基础 {base} -> 应用 {applied}",
		"tower_ascent.node_modal.training.description": "锤炼体魄，精进根基。",
	},
	LanguageSettings.LANGUAGE_JAPANESE: {
		KEY_SPRING_CARD_BADGE_SOUL: "魂召喚術",
		KEY_SPRING_CARD_BADGE_ENHANCE: "同行 · 強化",
		KEY_SPRING_CARD_BADGE_SWAP: "封印 · 交代",
		KEY_SPRING_CARD_BADGE_ABSORB: "封印 · 吸収",
		KEY_SPRING_CARD_SOUL_DESCRIPTION: "魂召喚術を学び、最初の守護霊を迎えます。",
		KEY_SPRING_CARD_ENHANCE_DESCRIPTION: "同行中の守護霊に次の強化を適用します。",
		KEY_SPRING_CARD_SWAP_DESCRIPTION: "封印した守護霊を同行中の守護霊と交代します。",
		KEY_SPRING_CARD_ABSORB_DESCRIPTION: "封印した守護霊の力を同行中の守護霊へ吸収します。",
		KEY_SPRING_STATE_ACTIVE: "同行",
		KEY_SPRING_STATE_SEALED: "封印",
		KEY_SPRING_STATE_ENHANCED: "強化",
		KEY_SPRING_STATE_ABSORBED: "吸収",
		KEY_REST_CARD_BADGE: "回復",
		KEY_REST_CARD_COMPLETE_BADGE: "完了",
		KEY_REST_CARD_DESCRIPTION: "機会の宝石 {current} → {result}",
		KEY_BALANCE_RECEIPT_MUHON: "武魂 {before} → {after}, {delta}",
		KEY_BALANCE_RECEIPT_GOLD: "金貨 {before} → {after}, {delta}",
		KEY_HOVER_CURRENT_RESULT: "現在 {current} → 結果 {result}",
		KEY_HOVER_TARGET_COST: "対象 {target} · 費用 {cost}",
		KEY_HOVER_REJECTION: "実行不可：{reason}",
		KEY_STATE_LISTED: "陳列中",
		KEY_STATE_OWNED: "獲得",
		KEY_STATE_EMPTY: "空き枠",
		KEY_BALANCE_GOLD: "金貨 {amount}",
		KEY_COST_GOLD: "{amount} 金貨",
		KEY_INSUFFICIENT_GOLD: "金貨が{required}必要、あと{shortfall}",
		KEY_TRAINING_MAXIMUM: "効果上限",
		KEY_TRAINING_BONUS_BADGE: "幸運 20% · 効果 +50%",
		KEY_TRAINING_STORAGE_BADGE: "固定 +1枠",
		KEY_TRAINING_BASE_RECEIPT: "{applied} 適用",
		KEY_TRAINING_LUCKY_RECEIPT: "幸運発動！基本 {base} -> {applied} 適用",
		"tower_ascent.node_modal.training.description": "身体を鍛え、基礎を磨きます。",
	},
	LanguageSettings.LANGUAGE_SPANISH: {
		KEY_SPRING_CARD_BADGE_SOUL: "Invocación",
		KEY_SPRING_CARD_BADGE_ENHANCE: "Activo · Mejora",
		KEY_SPRING_CARD_BADGE_SWAP: "Sellado · Cambio",
		KEY_SPRING_CARD_BADGE_ABSORB: "Sellado · Absorción",
		KEY_SPRING_CARD_SOUL_DESCRIPTION: "Aprende Invocación y recibe a tu primer guardián.",
		KEY_SPRING_CARD_ENHANCE_DESCRIPTION: "Aplica la siguiente mejora al guardián activo.",
		KEY_SPRING_CARD_SWAP_DESCRIPTION: "Cambia este guardián sellado por el guardián activo.",
		KEY_SPRING_CARD_ABSORB_DESCRIPTION: "Absorbe este guardián sellado en el guardián activo.",
		KEY_SPRING_STATE_ACTIVE: "Activo",
		KEY_SPRING_STATE_SEALED: "Sellado",
		KEY_SPRING_STATE_ENHANCED: "Mejorado",
		KEY_SPRING_STATE_ABSORBED: "Absorbido",
		KEY_REST_CARD_BADGE: "Recuperar",
		KEY_REST_CARD_COMPLETE_BADGE: "Completo",
		KEY_REST_CARD_DESCRIPTION: "Gemas de oportunidad {current} → {result}",
		KEY_BALANCE_RECEIPT_MUHON: "Alma marcial {before} → {after}, {delta}",
		KEY_BALANCE_RECEIPT_GOLD: "Oro {before} → {after}, {delta}",
		KEY_HOVER_CURRENT_RESULT: "Ahora {current} → Resultado {result}",
		KEY_HOVER_TARGET_COST: "Objetivo {target} · Coste {cost}",
		KEY_HOVER_REJECTION: "Bloqueado: {reason}",
		KEY_STATE_LISTED: "Expuesto",
		KEY_STATE_OWNED: "Obtenido",
		KEY_STATE_EMPTY: "Hueco vacío",
		KEY_BALANCE_GOLD: "Oro {amount}",
		KEY_COST_GOLD: "{amount} de oro",
		KEY_INSUFFICIENT_GOLD: "Se necesitan {required} de oro, faltan {shortfall}",
		KEY_TRAINING_MAXIMUM: "Límite de efecto",
		KEY_TRAINING_BONUS_BADGE: "Suerte 20% · Efecto +50%",
		KEY_TRAINING_STORAGE_BADGE: "+1 espacio fijo",
		KEY_TRAINING_BASE_RECEIPT: "Se aplicó {applied}",
		KEY_TRAINING_LUCKY_RECEIPT: "¡Suerte! Base {base} -> aplicado {applied}",
		"tower_ascent.node_modal.training.description": "Fortalece el cuerpo mediante el entrenamiento.",
	},
	LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: {
		KEY_SPRING_CARD_BADGE_SOUL: "Invocação",
		KEY_SPRING_CARD_BADGE_ENHANCE: "Ativo · Reforço",
		KEY_SPRING_CARD_BADGE_SWAP: "Selado · Troca",
		KEY_SPRING_CARD_BADGE_ABSORB: "Selado · Absorção",
		KEY_SPRING_CARD_SOUL_DESCRIPTION: "Aprenda Invocação e receba seu primeiro guardião.",
		KEY_SPRING_CARD_ENHANCE_DESCRIPTION: "Aplique o próximo reforço ao guardião ativo.",
		KEY_SPRING_CARD_SWAP_DESCRIPTION: "Troque este guardião selado pelo guardião ativo.",
		KEY_SPRING_CARD_ABSORB_DESCRIPTION: "Absorva este guardião selado no guardião ativo.",
		KEY_SPRING_STATE_ACTIVE: "Ativo",
		KEY_SPRING_STATE_SEALED: "Selado",
		KEY_SPRING_STATE_ENHANCED: "Reforçado",
		KEY_SPRING_STATE_ABSORBED: "Absorvido",
		KEY_REST_CARD_BADGE: "Recuperar",
		KEY_REST_CARD_COMPLETE_BADGE: "Concluído",
		KEY_REST_CARD_DESCRIPTION: "Gemas de chance {current} → {result}",
		KEY_BALANCE_RECEIPT_MUHON: "Alma marcial {before} → {after}, {delta}",
		KEY_BALANCE_RECEIPT_GOLD: "Ouro {before} → {after}, {delta}",
		KEY_HOVER_CURRENT_RESULT: "Agora {current} → Resultado {result}",
		KEY_HOVER_TARGET_COST: "Alvo {target} · Custo {cost}",
		KEY_HOVER_REJECTION: "Bloqueado: {reason}",
		KEY_STATE_LISTED: "Em exposição",
		KEY_STATE_OWNED: "Obtido",
		KEY_STATE_EMPTY: "Espaço vazio",
		KEY_BALANCE_GOLD: "Ouro {amount}",
		KEY_COST_GOLD: "{amount} de ouro",
		KEY_INSUFFICIENT_GOLD: "Requer {required} de ouro, faltam {shortfall}",
		KEY_TRAINING_MAXIMUM: "Limite do efeito",
		KEY_TRAINING_BONUS_BADGE: "Sorte 20% · Efeito +50%",
		KEY_TRAINING_STORAGE_BADGE: "+1 espaço fixo",
		KEY_TRAINING_BASE_RECEIPT: "{applied} aplicado",
		KEY_TRAINING_LUCKY_RECEIPT: "Sorte ativada! Base {base} -> {applied} aplicado",
		"tower_ascent.node_modal.training.description": "Fortaleça o corpo por meio do treinamento.",
	},
	LanguageSettings.LANGUAGE_RUSSIAN: {
		KEY_SPRING_CARD_BADGE_SOUL: "Призыв духа",
		KEY_SPRING_CARD_BADGE_ENHANCE: "Активный · Усиление",
		KEY_SPRING_CARD_BADGE_SWAP: "Печать · Замена",
		KEY_SPRING_CARD_BADGE_ABSORB: "Печать · Поглощение",
		KEY_SPRING_CARD_SOUL_DESCRIPTION: "Изучите призыв и встретьте первого хранителя.",
		KEY_SPRING_CARD_ENHANCE_DESCRIPTION: "Примените следующее усиление к активному хранителю.",
		KEY_SPRING_CARD_SWAP_DESCRIPTION: "Замените активного хранителя этим запечатанным.",
		KEY_SPRING_CARD_ABSORB_DESCRIPTION: "Поглотите силу этого хранителя активным хранителем.",
		KEY_SPRING_STATE_ACTIVE: "Активный",
		KEY_SPRING_STATE_SEALED: "Печать",
		KEY_SPRING_STATE_ENHANCED: "Усилен",
		KEY_SPRING_STATE_ABSORBED: "Поглощён",
		KEY_REST_CARD_BADGE: "Восстановить",
		KEY_REST_CARD_COMPLETE_BADGE: "Готово",
		KEY_REST_CARD_DESCRIPTION: "Камни шанса {current} → {result}",
		KEY_BALANCE_RECEIPT_MUHON: "Душа боя {before} → {after}, {delta}",
		KEY_BALANCE_RECEIPT_GOLD: "Золото {before} → {after}, {delta}",
		KEY_HOVER_CURRENT_RESULT: "Сейчас {current} → Итог {result}",
		KEY_HOVER_TARGET_COST: "Цель {target} · Цена {cost}",
		KEY_HOVER_REJECTION: "Недоступно: {reason}",
		KEY_STATE_LISTED: "На витрине",
		KEY_STATE_OWNED: "Получено",
		KEY_STATE_EMPTY: "Пустое место",
		KEY_BALANCE_GOLD: "Золото: {amount}",
		KEY_COST_GOLD: "{amount} золота",
		KEY_INSUFFICIENT_GOLD: "Нужно {required} золота, не хватает {shortfall}",
		KEY_TRAINING_MAXIMUM: "Предел эффекта",
		KEY_TRAINING_BONUS_BADGE: "Удача 20% · Эффект +50%",
		KEY_TRAINING_STORAGE_BADGE: "Фикс. +1 ячейка",
		KEY_TRAINING_BASE_RECEIPT: "Применено: {applied}",
		KEY_TRAINING_LUCKY_RECEIPT: "Удача! База {base} -> применено {applied}",
		"tower_ascent.node_modal.training.description": "Закаляйте тело упорными тренировками.",
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
