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
const KEY_TRAINING_TIMING_BADGE := "tower_ascent.node_modal.training.timing_badge"
const KEY_TRAINING_JUDGMENT_MAX_BADGE := "tower_ascent.node_modal.training.judgment_max_badge"
const KEY_TRAINING_STORAGE_BADGE := "tower_ascent.node_modal.training.storage_badge"
const KEY_TRAINING_BASE_RECEIPT := "tower_ascent.node_modal.training.base_receipt"
const KEY_TRAINING_TIMING_PROMPT := "tower_ascent.node_modal.training.timing_prompt"
const KEY_TRAINING_TIMING_CANCELLED := "tower_ascent.node_modal.training.timing_cancelled"
const KEY_TRAINING_TIMING_CRITICAL := "tower_ascent.node_modal.training.timing_critical"
const KEY_TRAINING_TIMING_GREAT := "tower_ascent.node_modal.training.timing_great"
const KEY_TRAINING_TIMING_BASE := "tower_ascent.node_modal.training.timing_base"
const KEY_TRAINING_TIMING_RESULT := "tower_ascent.node_modal.training.timing_result"
const KEY_TRAINING_LUCKY_RECEIPT := KEY_TRAINING_TIMING_CRITICAL
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
const KEY_MONK_MUGONG_SLOT_FULL := "tower_ascent.node_modal.fallen_monk.mugong_slot_full"
const KEY_COST_FREE := "tower_ascent.node_modal.cost.free"
const KEY_SPRING_PALM_OPTION := "tower_ascent.node_modal.guardian_spring.palm_option"
const KEY_SPRING_STATUE_DIALOGUE := "tower_ascent.node_modal.guardian_spring.statue_dialogue"
const KEY_SPRING_STATUE_PROMPT := "tower_ascent.node_modal.guardian_spring.statue_prompt"
const KEY_SPRING_PRAYER_OPTION := "tower_ascent.node_modal.guardian_spring.prayer_option"
const KEY_SPRING_BROWSE_OPTION := "tower_ascent.node_modal.guardian_spring.browse_option"
const KEY_SPRING_PALM_COMPLETED := "tower_ascent.node_modal.guardian_spring.palm_completed"
const KEY_SPRING_PRAYER_COMPLETED := "tower_ascent.node_modal.guardian_spring.prayer_completed"
const KEY_SPRING_PRAYER_RESULT := "tower_ascent.node_modal.guardian_spring.prayer_result"
const KEY_SPRING_PRAYER_COUNT := "tower_ascent.node_modal.guardian_spring.prayer_count"
const KEY_SPRING_CARD_BADGE_PRAYER := "tower_ascent.node_modal.guardian_spring.card_badge.prayer"
const KEY_SPRING_CARD_PRAYER_DESCRIPTION := "tower_ascent.node_modal.guardian_spring.card_description.prayer"
const KEY_SPRING_CARD_BADGE_BROWSE := "tower_ascent.node_modal.guardian_spring.card_badge.browse"
const KEY_SPRING_CARD_BROWSE_DESCRIPTION := "tower_ascent.node_modal.guardian_spring.card_description.browse"
const KEY_SPRING_CARD_BADGE_FIRST_PICK := "tower_ascent.node_modal.guardian_spring.card_badge.first_pick"
const KEY_SPRING_FIRST_PICK_INTRO := "tower_ascent.node_modal.guardian_spring.first_pick_intro"
const KEY_SPRING_CARD_BADGE_ELITE := "tower_ascent.node_modal.guardian_spring.card_badge.elite"
const KEY_SPRING_FIRST_PICK_COMPLETED := "tower_ascent.node_modal.guardian_spring.first_pick_completed"
const KEY_SPRING_BROWSE_COMPLETED := "tower_ascent.node_modal.guardian_spring.browse_completed"
const KEY_SPRING_FIRST_PICK_REQUIRED := "tower_ascent.node_modal.guardian_spring.first_pick_required"
const KEY_SPRING_ENHANCE_OPTION := "tower_ascent.node_modal.guardian_spring.enhance_option"
const KEY_SPRING_RUNTIME_UNAVAILABLE := "tower_ascent.node_modal.guardian_spring.runtime_unavailable"
const KEY_SPRING_ENHANCE_UNAVAILABLE := "tower_ascent.node_modal.guardian_spring.enhance_unavailable"
const KEY_SPRING_ENHANCE_COMPLETED := "tower_ascent.node_modal.guardian_spring.enhance_completed"
const KEY_SPRING_ACTION_UNAVAILABLE := "tower_ascent.node_modal.guardian_spring.action_unavailable"
const KEY_SPRING_CARD_BADGE_SOUL := "tower_ascent.node_modal.guardian_spring.card_badge.soul"
const KEY_SPRING_CARD_BADGE_ENHANCE := "tower_ascent.node_modal.guardian_spring.card_badge.enhance"
const KEY_SPRING_CARD_SOUL_DESCRIPTION := "tower_ascent.node_modal.guardian_spring.card_description.soul"
const KEY_SPRING_CARD_ENHANCE_DESCRIPTION := "tower_ascent.node_modal.guardian_spring.card_description.enhance"
const KEY_SPRING_CHOSIK_SWAP_REQUIRED := "tower_ascent.node_modal.guardian_spring.chosik_swap_required"
const KEY_SPRING_CHOSIK_SWAP_OPENED := "tower_ascent.node_modal.guardian_spring.chosik_swap_opened"
const KEY_SPRING_CHOSIK_SWAP_TITLE := "tower_ascent.node_modal.guardian_spring.chosik_swap_title"
const KEY_SPRING_CHOSIK_SWAP_NEW_LABEL := "tower_ascent.node_modal.guardian_spring.chosik_swap_new_label"
const KEY_SPRING_CHOSIK_SWAP_HINT := "tower_ascent.node_modal.guardian_spring.chosik_swap_hint"
const KEY_SPRING_VISIT_ACTION_COMPLETED := "tower_ascent.node_modal.guardian_spring.visit_action_completed"
const KEY_SPRING_STATE_ACTIVE := "tower_ascent.node_modal.guardian_spring.state.active"
const KEY_SPRING_STATE_ENHANCED := "tower_ascent.node_modal.guardian_spring.state.enhanced"
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
		KEY_MONK_MUGONG_SLOT_FULL: "무공 슬롯이 가득 찼습니다.",
		KEY_TRAINING_STAT_OPTION: "체질 수련: {name}",
		KEY_TRAINING_MAXIMUM: "효과 한계",
		KEY_TRAINING_COMPLETED: "{name} 습득 완료",
		KEY_TRAINING_TIMING_BADGE: "행운 판정 폭 {width}% · 최대 효과 +{effect}%",
		KEY_TRAINING_JUDGMENT_MAX_BADGE: "판정 성공 시 최대 {effect}",
		KEY_TRAINING_STORAGE_BADGE: "고정 +1칸",
		KEY_TRAINING_BASE_RECEIPT: "{applied} 적용",
		KEY_TRAINING_TIMING_PROMPT: "움직이는 중심추를 클릭하여 멈추세요.",
		KEY_TRAINING_TIMING_CANCELLED: "수련을 취소했습니다. 무혼은 소모되지 않았습니다.",
		KEY_TRAINING_TIMING_CRITICAL: "회심의 수련!",
		KEY_TRAINING_TIMING_GREAT: "훌륭한 수련!",
		KEY_TRAINING_TIMING_BASE: "수련 성공",
		KEY_TRAINING_TIMING_RESULT: "{judgment} {name} +{applied}",
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
		KEY_SPRING_PALM_OPTION: "손바닥을 대본다",
		KEY_SPRING_STATUE_DIALOGUE: "바위에서 영험한 기운이 흘러나옵니다",
		KEY_SPRING_STATUE_PROMPT: "돌에 손을 대어 기운을 살펴보세요",
		KEY_SPRING_PRAYER_OPTION: "기도한다",
		KEY_SPRING_BROWSE_OPTION: "수호령들을 살핀다",
		KEY_SPRING_PALM_COMPLETED: "이미 샘터의 기운을 받아들였습니다.",
		KEY_SPRING_PRAYER_COMPLETED: "모든 능력치가 {bonus}%p 상승했습니다.",
		KEY_SPRING_PRAYER_RESULT: "전능력치 상승",
		KEY_SPRING_PRAYER_COUNT: "기도 {count}회",
		KEY_SPRING_CARD_BADGE_PRAYER: "샘터 기도",
		KEY_SPRING_CARD_PRAYER_DESCRIPTION: "이번 런 동안 플레이어 전능력치가 {bonus}%p 상승합니다.",
		KEY_SPRING_CARD_BADGE_BROWSE: "정예 수호령",
		KEY_SPRING_CARD_BROWSE_DESCRIPTION: "현재 층에 맞게 강화된 정예 수호령 셋을 불러봅니다.",
		KEY_SPRING_CARD_BADGE_FIRST_PICK: "첫 인연",
		KEY_SPRING_FIRST_PICK_INTRO: "수호령의 기운이 조용히 당신을 부릅니다.",
		KEY_SPRING_CARD_BADGE_ELITE: "정예 강화 {count}회",
		KEY_SPRING_FIRST_PICK_COMPLETED: "{name}과 첫 인연을 맺었습니다.",
		KEY_SPRING_BROWSE_COMPLETED: "정예 수호령 셋이 샘터에 모습을 드러냈습니다.",
		KEY_SPRING_FIRST_PICK_REQUIRED: "첫 인연을 맺을 수호령 하나를 선택해야 합니다.",
		KEY_SPRING_ENHANCE_OPTION: "수호령 강화: {name}",
		KEY_SPRING_RUNTIME_UNAVAILABLE: "수호령 기능을 준비할 수 없습니다.",
		KEY_SPRING_ENHANCE_UNAVAILABLE: "현재 수호령에 적용할 강화가 없습니다.",
		KEY_SPRING_ENHANCE_COMPLETED: "수호령 강화 완료",
		KEY_SPRING_ACTION_UNAVAILABLE: "샘터에서 처리할 수호령 업무가 없습니다.",
		KEY_SPRING_CARD_BADGE_SOUL: "영혼소환술",
		KEY_SPRING_CARD_BADGE_ENHANCE: "활성 · 강화",
		KEY_SPRING_CARD_SOUL_DESCRIPTION: "영혼소환술을 익혀 첫 수호령을 맞이합니다.",
		KEY_SPRING_CARD_ENHANCE_DESCRIPTION: "활성 수호령에 다음 강화 결과를 적용합니다.",
		KEY_SPRING_CHOSIK_SWAP_REQUIRED: "초식 교체 필요",
		KEY_SPRING_CHOSIK_SWAP_OPENED: "버릴 초식을 선택하세요.",
		KEY_SPRING_CHOSIK_SWAP_TITLE: "초식 교체",
		KEY_SPRING_CHOSIK_SWAP_NEW_LABEL: "새 초식: {name}",
		KEY_SPRING_CHOSIK_SWAP_HINT: "Enter 선택, Esc 취소",
		KEY_SPRING_VISIT_ACTION_COMPLETED: "이번 방문의 샘터 업무를 이미 마쳤습니다.",
		KEY_SPRING_STATE_ACTIVE: "활성",
		KEY_SPRING_STATE_ENHANCED: "강화",
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
		KEY_SPRING_PALM_OPTION: "Place your palm",
		KEY_SPRING_STATUE_DIALOGUE: "A sacred energy flows from the stone.",
		KEY_SPRING_STATUE_PROMPT: "Touch the stone and feel its presence.",
		KEY_SPRING_PRAYER_OPTION: "Offer a prayer",
		KEY_SPRING_BROWSE_OPTION: "View the guardians",
		KEY_SPRING_PALM_COMPLETED: "You have already received the spring's energy.",
		KEY_SPRING_PRAYER_COMPLETED: "All stats have increased by {bonus} percentage points.",
		KEY_SPRING_PRAYER_RESULT: "All stats increased",
		KEY_SPRING_PRAYER_COUNT: "Prayers {count}",
		KEY_SPRING_CARD_BADGE_PRAYER: "Spring Prayer",
		KEY_SPRING_CARD_PRAYER_DESCRIPTION: "Raises all player stats by {bonus} percentage points for this run.",
		KEY_SPRING_CARD_BADGE_BROWSE: "Elite Guardians",
		KEY_SPRING_CARD_BROWSE_DESCRIPTION: "Call three elite guardians enhanced for the current floor.",
		KEY_SPRING_CARD_BADGE_FIRST_PICK: "First Bond",
		KEY_SPRING_FIRST_PICK_INTRO: "A guardian's presence quietly calls to you.",
		KEY_SPRING_CARD_BADGE_ELITE: "Elite · {count} enhancements",
		KEY_SPRING_FIRST_PICK_COMPLETED: "You formed your first bond with {name}.",
		KEY_SPRING_BROWSE_COMPLETED: "Three elite guardians appeared at the spring.",
		KEY_SPRING_FIRST_PICK_REQUIRED: "Choose one guardian for your first bond.",
		KEY_SPRING_CARD_BADGE_SOUL: "Soul Summoning",
		KEY_SPRING_CARD_BADGE_ENHANCE: "Active · Enhance",
		KEY_SPRING_CARD_SOUL_DESCRIPTION: "Learn Soul Summoning and welcome your first guardian.",
		KEY_SPRING_CARD_ENHANCE_DESCRIPTION: "Apply the next enhancement to the active guardian.",
		KEY_SPRING_CHOSIK_SWAP_REQUIRED: "Chosik replacement required",
		KEY_SPRING_CHOSIK_SWAP_OPENED: "Choose a Chosik to discard.",
		KEY_SPRING_CHOSIK_SWAP_TITLE: "Replace Chosik",
		KEY_SPRING_CHOSIK_SWAP_NEW_LABEL: "New Chosik: {name}",
		KEY_SPRING_CHOSIK_SWAP_HINT: "Enter: Select, Esc: Cancel",
		KEY_SPRING_VISIT_ACTION_COMPLETED: "You have finished the spring ritual for this visit.",
		KEY_SPRING_STATE_ACTIVE: "Active",
		KEY_SPRING_STATE_ENHANCED: "Enhanced",
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
		KEY_TRAINING_TIMING_BADGE: "Luck window {width}% · Max effect +{effect}%",
		KEY_TRAINING_JUDGMENT_MAX_BADGE: "Up to {effect} on judgment success",
		KEY_TRAINING_STORAGE_BADGE: "Fixed +1 slot",
		KEY_TRAINING_BASE_RECEIPT: "Applied {applied}",
		KEY_TRAINING_TIMING_PROMPT: "Click to stop the moving marker.",
		KEY_TRAINING_TIMING_CANCELLED: "Training cancelled. No Mugong Soul spent.",
		KEY_TRAINING_TIMING_CRITICAL: "Perfect training!",
		KEY_TRAINING_TIMING_GREAT: "Excellent training!",
		KEY_TRAINING_TIMING_BASE: "Training success",
		KEY_TRAINING_TIMING_RESULT: "{judgment} {name} +{applied}",
		"tower_ascent.node_modal.training.description": "Refine your body through focused training.",
	},
	LanguageSettings.LANGUAGE_CHINESE: {
		KEY_SPRING_PALM_OPTION: "将手掌贴上去",
		KEY_SPRING_STATUE_DIALOGUE: "神圣的气息正从岩石中流淌而出。",
		KEY_SPRING_STATUE_PROMPT: "触碰岩石，感受其中的气息。",
		KEY_SPRING_PRAYER_OPTION: "祈祷",
		KEY_SPRING_BROWSE_OPTION: "查看守护灵",
		KEY_SPRING_PALM_COMPLETED: "你已经接受了泉水的力量。",
		KEY_SPRING_PRAYER_COMPLETED: "所有属性已提升{bonus}个百分点。",
		KEY_SPRING_PRAYER_RESULT: "全属性提升",
		KEY_SPRING_PRAYER_COUNT: "祈祷 {count} 次",
		KEY_SPRING_CARD_BADGE_PRAYER: "泉边祈祷",
		KEY_SPRING_CARD_PRAYER_DESCRIPTION: "本次挑战中玩家全属性提升 {bonus} 个百分点。",
		KEY_SPRING_CARD_BADGE_BROWSE: "精英守护灵",
		KEY_SPRING_CARD_BROWSE_DESCRIPTION: "召来三位按当前楼层强化的精英守护灵。",
		KEY_SPRING_CARD_BADGE_FIRST_PICK: "初次结缘",
		KEY_SPRING_FIRST_PICK_INTRO: "守护灵的气息正在静静呼唤你。",
		KEY_SPRING_CARD_BADGE_ELITE: "精英强化 {count} 次",
		KEY_SPRING_FIRST_PICK_COMPLETED: "你与{name}结下了最初的缘分。",
		KEY_SPRING_BROWSE_COMPLETED: "三位精英守护灵现身泉边。",
		KEY_SPRING_FIRST_PICK_REQUIRED: "请选择一位守护灵结下最初的缘分。",
		KEY_SPRING_CARD_BADGE_SOUL: "灵魂召唤术",
		KEY_SPRING_CARD_BADGE_ENHANCE: "出战 · 强化",
		KEY_SPRING_CARD_SOUL_DESCRIPTION: "习得灵魂召唤术，迎接首位守护灵。",
		KEY_SPRING_CARD_ENHANCE_DESCRIPTION: "为当前守护灵应用下一次强化。",
		KEY_SPRING_CHOSIK_SWAP_REQUIRED: "需要替换招式",
		KEY_SPRING_CHOSIK_SWAP_OPENED: "请选择要舍弃的招式。",
		KEY_SPRING_CHOSIK_SWAP_TITLE: "替换招式",
		KEY_SPRING_CHOSIK_SWAP_NEW_LABEL: "新招式：{name}",
		KEY_SPRING_CHOSIK_SWAP_HINT: "Enter 选择，Esc 取消",
		KEY_SPRING_VISIT_ACTION_COMPLETED: "本次到访的泉水仪式已经完成。",
		KEY_SPRING_STATE_ACTIVE: "出战",
		KEY_SPRING_STATE_ENHANCED: "强化",
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
		KEY_TRAINING_TIMING_BADGE: "幸运判定宽度 {width}% · 最大效果 +{effect}%",
		KEY_TRAINING_JUDGMENT_MAX_BADGE: "判定成功时最多 {effect}",
		KEY_TRAINING_STORAGE_BADGE: "固定 +1 格",
		KEY_TRAINING_BASE_RECEIPT: "已应用 {applied}",
		KEY_TRAINING_TIMING_PROMPT: "点击停止移动的指针。",
		KEY_TRAINING_TIMING_CANCELLED: "训练已取消，未消耗武魂。",
		KEY_TRAINING_TIMING_CRITICAL: "会心修炼！",
		KEY_TRAINING_TIMING_GREAT: "出色修炼！",
		KEY_TRAINING_TIMING_BASE: "修炼成功",
		KEY_TRAINING_TIMING_RESULT: "{judgment} {name} +{applied}",
		"tower_ascent.node_modal.training.description": "锤炼体魄，精进根基。",
	},
	LanguageSettings.LANGUAGE_JAPANESE: {
		KEY_SPRING_PALM_OPTION: "手のひらを当てる",
		KEY_SPRING_STATUE_DIALOGUE: "岩から霊妙な気が流れ出しています。",
		KEY_SPRING_STATUE_PROMPT: "岩に触れて、その気配を感じてください。",
		KEY_SPRING_PRAYER_OPTION: "祈る",
		KEY_SPRING_BROWSE_OPTION: "守護霊たちを見る",
		KEY_SPRING_PALM_COMPLETED: "すでに泉の力を受け入れました。",
		KEY_SPRING_PRAYER_COMPLETED: "すべての能力値が{bonus}ポイント上昇しました。",
		KEY_SPRING_PRAYER_RESULT: "全能力値上昇",
		KEY_SPRING_PRAYER_COUNT: "祈り {count}回",
		KEY_SPRING_CARD_BADGE_PRAYER: "泉の祈り",
		KEY_SPRING_CARD_PRAYER_DESCRIPTION: "この挑戦中、プレイヤーの全能力値が{bonus}ポイント上昇します。",
		KEY_SPRING_CARD_BADGE_BROWSE: "精鋭守護霊",
		KEY_SPRING_CARD_BROWSE_DESCRIPTION: "現在の階層に合わせて強化された精鋭守護霊を3体呼びます。",
		KEY_SPRING_CARD_BADGE_FIRST_PICK: "最初の縁",
		KEY_SPRING_FIRST_PICK_INTRO: "守護霊の気配が静かにあなたを呼んでいます。",
		KEY_SPRING_CARD_BADGE_ELITE: "精鋭強化 {count}回",
		KEY_SPRING_FIRST_PICK_COMPLETED: "{name}と最初の縁を結びました。",
		KEY_SPRING_BROWSE_COMPLETED: "3体の精鋭守護霊が泉に現れました。",
		KEY_SPRING_FIRST_PICK_REQUIRED: "最初の縁を結ぶ守護霊を1体選んでください。",
		KEY_SPRING_CARD_BADGE_SOUL: "魂召喚術",
		KEY_SPRING_CARD_BADGE_ENHANCE: "同行 · 強化",
		KEY_SPRING_CARD_SOUL_DESCRIPTION: "魂召喚術を学び、最初の守護霊を迎えます。",
		KEY_SPRING_CARD_ENHANCE_DESCRIPTION: "同行中の守護霊に次の強化を適用します。",
		KEY_SPRING_CHOSIK_SWAP_REQUIRED: "招式の入れ替えが必要",
		KEY_SPRING_CHOSIK_SWAP_OPENED: "捨てる招式を選んでください。",
		KEY_SPRING_CHOSIK_SWAP_TITLE: "招式の入れ替え",
		KEY_SPRING_CHOSIK_SWAP_NEW_LABEL: "新しい招式：{name}",
		KEY_SPRING_CHOSIK_SWAP_HINT: "Enter 選択、Esc キャンセル",
		KEY_SPRING_VISIT_ACTION_COMPLETED: "今回の泉の儀式はすでに完了しました。",
		KEY_SPRING_STATE_ACTIVE: "同行",
		KEY_SPRING_STATE_ENHANCED: "強化",
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
		KEY_TRAINING_TIMING_BADGE: "幸運判定幅 {width}% · 最大効果 +{effect}%",
		KEY_TRAINING_JUDGMENT_MAX_BADGE: "判定成功時は最大 {effect}",
		KEY_TRAINING_STORAGE_BADGE: "固定 +1枠",
		KEY_TRAINING_BASE_RECEIPT: "{applied} 適用",
		KEY_TRAINING_TIMING_PROMPT: "クリックして動く指針を止めてください。",
		KEY_TRAINING_TIMING_CANCELLED: "修練を中止しました。武魂は消費されません。",
		KEY_TRAINING_TIMING_CRITICAL: "会心の修練！",
		KEY_TRAINING_TIMING_GREAT: "見事な修練！",
		KEY_TRAINING_TIMING_BASE: "修練成功",
		KEY_TRAINING_TIMING_RESULT: "{judgment} {name} +{applied}",
		"tower_ascent.node_modal.training.description": "身体を鍛え、基礎を磨きます。",
	},
	LanguageSettings.LANGUAGE_SPANISH: {
		KEY_SPRING_CARD_BADGE_SOUL: "Invocación",
		KEY_SPRING_CARD_BADGE_ENHANCE: "Activo · Mejora",
		KEY_SPRING_CARD_SOUL_DESCRIPTION: "Aprende Invocación y recibe a tu primer guardián.",
		KEY_SPRING_CARD_ENHANCE_DESCRIPTION: "Aplica la siguiente mejora al guardián activo.",
		KEY_SPRING_STATE_ACTIVE: "Activo",
		KEY_SPRING_STATE_ENHANCED: "Mejorado",
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
		KEY_TRAINING_TIMING_BADGE: "Zona de suerte {width}% · Efecto máx. +{effect}%",
		KEY_TRAINING_JUDGMENT_MAX_BADGE: "Hasta {effect} al acertar el juicio",
		KEY_TRAINING_STORAGE_BADGE: "+1 espacio fijo",
		KEY_TRAINING_BASE_RECEIPT: "Se aplicó {applied}",
		KEY_TRAINING_TIMING_PROMPT: "Haz clic para detener el marcador móvil.",
		KEY_TRAINING_TIMING_CANCELLED: "Entrenamiento cancelado. No se gastó alma marcial.",
		KEY_TRAINING_TIMING_CRITICAL: "¡Entrenamiento perfecto!",
		KEY_TRAINING_TIMING_GREAT: "¡Entrenamiento excelente!",
		KEY_TRAINING_TIMING_BASE: "Entrenamiento logrado",
		KEY_TRAINING_TIMING_RESULT: "{judgment} {name} +{applied}",
		"tower_ascent.node_modal.training.description": "Fortalece el cuerpo mediante el entrenamiento.",
	},
	LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: {
		KEY_SPRING_CARD_BADGE_SOUL: "Invocação",
		KEY_SPRING_CARD_BADGE_ENHANCE: "Ativo · Reforço",
		KEY_SPRING_CARD_SOUL_DESCRIPTION: "Aprenda Invocação e receba seu primeiro guardião.",
		KEY_SPRING_CARD_ENHANCE_DESCRIPTION: "Aplique o próximo reforço ao guardião ativo.",
		KEY_SPRING_STATE_ACTIVE: "Ativo",
		KEY_SPRING_STATE_ENHANCED: "Reforçado",
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
		KEY_TRAINING_TIMING_BADGE: "Faixa de sorte {width}% · Efeito máx. +{effect}%",
		KEY_TRAINING_JUDGMENT_MAX_BADGE: "Até {effect} ao acertar o julgamento",
		KEY_TRAINING_STORAGE_BADGE: "+1 espaço fixo",
		KEY_TRAINING_BASE_RECEIPT: "{applied} aplicado",
		KEY_TRAINING_TIMING_PROMPT: "Clique para parar o marcador em movimento.",
		KEY_TRAINING_TIMING_CANCELLED: "Treino cancelado. Nenhuma alma marcial foi gasta.",
		KEY_TRAINING_TIMING_CRITICAL: "Treino perfeito!",
		KEY_TRAINING_TIMING_GREAT: "Treino excelente!",
		KEY_TRAINING_TIMING_BASE: "Treino concluído",
		KEY_TRAINING_TIMING_RESULT: "{judgment} {name} +{applied}",
		"tower_ascent.node_modal.training.description": "Fortaleça o corpo por meio do treinamento.",
	},
	LanguageSettings.LANGUAGE_RUSSIAN: {
		KEY_SPRING_CARD_BADGE_SOUL: "Призыв духа",
		KEY_SPRING_CARD_BADGE_ENHANCE: "Активный · Усиление",
		KEY_SPRING_CARD_SOUL_DESCRIPTION: "Изучите призыв и встретьте первого хранителя.",
		KEY_SPRING_CARD_ENHANCE_DESCRIPTION: "Примените следующее усиление к активному хранителю.",
		KEY_SPRING_STATE_ACTIVE: "Активный",
		KEY_SPRING_STATE_ENHANCED: "Усилен",
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
		KEY_TRAINING_TIMING_BADGE: "Ширина удачи {width}% · Макс. эффект +{effect}%",
		KEY_TRAINING_JUDGMENT_MAX_BADGE: "До {effect} при успешной оценке",
		KEY_TRAINING_STORAGE_BADGE: "Фикс. +1 ячейка",
		KEY_TRAINING_BASE_RECEIPT: "Применено: {applied}",
		KEY_TRAINING_TIMING_PROMPT: "Нажмите, чтобы остановить бегущий маркер.",
		KEY_TRAINING_TIMING_CANCELLED: "Тренировка отменена. Душа боя не потрачена.",
		KEY_TRAINING_TIMING_CRITICAL: "Идеальная тренировка!",
		KEY_TRAINING_TIMING_GREAT: "Отличная тренировка!",
		KEY_TRAINING_TIMING_BASE: "Тренировка успешна",
		KEY_TRAINING_TIMING_RESULT: "{judgment} {name} +{applied}",
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
