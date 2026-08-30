extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")
const LingpetGuardianEnhanceOfferEngine := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_offer_engine.gd"
)
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)
const PhysiqueTrainingCatalog := preload("res://scripts/characters/physique_training_catalog.gd")
const RuntimePerkCharacterContext := preload("res://scripts/characters/runtime_perk_character_context.gd")

const BASE_CHOICE_COUNT := 3
# 무공 슬롯 동적 한도(flag ON): 기본 6 + 합일 부산물 기맥 확장 1(최대 7).
# flag OFF에서는 고정 6이며 common_expansion은 레거시 장신구 의미.
const BASE_PERK_SLOT_LIMIT := 6
const MAX_PERK_SLOT_LIMIT := 7
const PERK_SLOT_LIMIT_BLOCKED_REASON := "perk_slot_limit"
const TOWER_UPGRADE_READ_ONLY_REASON_COUNT_TYPE := "count_type"
const SLOT_EXPANSION_PERK_ID := "common_expansion"
const FUSION_SLOT_EXPANSION_BYPRODUCT_ID := "meridian_expand"
const LINGPET_GUARDIAN_ENHANCE_CHOICE_ID := LingpetGuardianEnhanceOfferEngine.PERK_ID
const GUARDIAN_ENHANCE_PRIORITY_KEY := "_guardian_enhance_reserved"
const FULL_CHOSIK_SWAP_PRIORITY_KEY := "_full_chosik_swap_reserved"
const BOSS_VISION_PRIORITY_KEY := "_boss_vision_reserved"
# 초식 슬롯 만석 뒤에는 화면당 한 번만 굴려, 드물게 교체 기회를 연다.
const FULL_CHOSIK_SWAP_OFFER_CHANCE := 0.05
# 슬롯에 여유가 있어도 초식 후보가 무제한으로 풀에 깔리면 화면 절반 이상을
# 점령한다(2026-08-12 실측 52.8%). 라이브 만석 판정이 가능한 경로에서는 여유
# 상태도 화면당 한 번만 굴려 최대 1장으로 제한한다. 단일 튜닝 상수.
const OPEN_CHOSIK_OFFER_CHANCE := 0.35
const LINGPET_GATED_CHOICE_IDS := {
	LINGPET_GUARDIAN_ENHANCE_CHOICE_ID: true,
}
const TRAINING_MIGRATED_PERK_IDS := {
	"dash_lightweight": true,
	"dash_module_control": true,
	"dash_jump": true,
	"common_swiftness": true,
	"bulletproof_hat": true,
	"common_bulk_up": true,
	"fuel_pouch": true,
	"bluetooth_ring": true,
	"item_cooldown_mastery": true,
	"common_training": true,
}
const TRAINING_DEPENDENT_PERK_IDS := {
	"training_mastery": true,
}
const COMMON_PERKS := {
	"dash_lightweight": {
		"name": "회기보",
		"max_level": 5,
		"descriptions": {
			1: "활주 재충전 12% 감소",
			2: "활주 재충전 24% 감소",
			3: "활주 재충전 36% 감소",
			4: "활주 재충전 48% 감소",
			5: "활주 재충전 60% 감소",
		},
		"detail": "회기보로 흩어진 기운을 거두어 소모한 활주 횟수를 더 빠르게 회복합니다.",
		"icon_color": Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
		"tree": "dash",
	},
	"dash_module_control": {
		"name": "수세결",
		"max_level": 5,
		"descriptions": {
			1: "활주 후딜 18% 감소",
			2: "활주 후딜 36% 감소",
			3: "활주 후딜 54% 감소",
			4: "활주 후딜 72% 감소",
			5: "활주 후딜 90% 감소",
		},
		"detail": "수세결로 활주 뒤 흐트러진 자세를 곧바로 거두어 다음 행동이 빨라집니다.",
		"icon_color": Color(150.0 / 255.0, 100.0 / 255.0, 1.0),
		"tree": "dash",
	},
	"dash_jump": {
		"name": "비천보",
		"max_level": 5,
		"descriptions": {
			1: "활주 지속 7% 증가",
			2: "활주 지속 14% 증가",
			3: "활주 지속 21% 증가",
			4: "활주 지속 28% 증가",
			5: "활주 지속 35% 증가",
		},
		"detail": "비천보로 한 번의 활주 지속을 늘려 더 멀리 움직입니다.",
		"icon_color": Color(100.0 / 255.0, 1.0, 150.0 / 255.0),
		"tree": "dash",
	},
	"dash_acceleration": {
		"name": "대붕전익",
		"max_level": 3,
		"descriptions": {
			1: "활주시 몸집 세로 88%·가로 13% 증가",
			2: "활주시 몸집 세로 203%·가로 29% 증가",
			3: "활주시 몸집 세로 350%·가로 50% 증가",
		},
		"detail": "활주 순간 대붕이 날개를 펼치듯 몸집이 세로로 크게, 가로로 적당히 넓어져 더 넓은 범위의 공을 받아냅니다.",
		"icon_color": Color(1.0, 100.0 / 255.0, 50.0 / 255.0),
		"tree": "dash",
	},
	"dash_amplification": {
		"name": "활주구슬",
		"max_level": 3,
		# 보유 수는 내부 level로 누적되지만 각 구슬이 슬롯 한 칸을 따로 차지하는
		# 카운트형 무공이다. 성장 경지(1성~극성) 대신 고유 태그로 표시한다.
		"rank_tag": "unique",
		"descriptions": {
			1: "최대 활주 횟수 +1",
			2: "최대 활주 횟수 +2",
			3: "최대 활주 횟수 +3",
		},
		"detail": "활주구슬 하나마다 최대 활주 횟수가 1회 늘어나며, 구슬 하나당 무공 슬롯을 1칸 사용합니다.",
		"icon_color": Color(1.0, 200.0 / 255.0, 50.0 / 255.0),
		"tree": "dash",
	},
	"item_luck": {
		"name": "인보결",
		"max_level": 3,
		"descriptions": {
			1: "아이템 스폰 대기 15% 감소",
			2: "아이템 스폰 대기 35% 감소",
			3: "아이템 스폰 대기 60% 감소",
		},
		"detail": "인보결로 기물의 기운을 끌어당겨 필드 아이템이 더 자주 나타납니다.",
		"icon_color": Color(1.0, 215.0 / 255.0, 0.0),
		"tree": "item",
	},
	"item_cooldown_mastery": {
		"name": "순환결",
		"max_level": 5,
		"descriptions": {
			1: "액티브 아이템 쿨타임 13% 감소",
			2: "액티브 아이템 쿨타임 26% 감소",
			3: "액티브 아이템 쿨타임 39% 감소",
			4: "액티브 아이템 쿨타임 52% 감소",
			5: "액티브 아이템 쿨타임 65% 감소",
		},
		"detail": "순환결로 액티브 아이템의 기운을 빠르게 되돌려 사용 간격을 줄입니다. 모든 효과 적용 후 최종 쿨타임은 기본값의 5% 미만으로 내려가지 않습니다. (최대 95% 감소)",
		"icon_color": Color(100.0 / 255.0, 150.0 / 255.0, 1.0),
		"tree": "item",
	},
	"item_gauge_mastery": {
		"name": "기령심법",
		"max_level": 3,
		"descriptions": {
			1: "액티브 사용시 기력 +19",
			2: "액티브 사용시 기력 +44",
			3: "액티브 사용시 기력 +75",
		},
		"detail": "기령심법으로 액티브 아이템을 쓸 때 기물의 영기를 받아 기력을 얻습니다.",
		"icon_color": Color(150.0 / 255.0, 1.0, 100.0 / 255.0),
		"tree": "item",
	},
	"item_caffeine": {
		"name": "연효결",
		"max_level": 3,
		"descriptions": {
			1: "타이머형 아이템 지속 38% 증가",
			2: "타이머형 아이템 지속 87% 증가",
			3: "타이머형 아이템 지속 150% 증가",
		},
		"detail": "연효결로 지속시간형 액티브 아이템의 효력을 더 오래 이어갑니다.",
		"icon_color": Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0),
		"tree": "item",
	},
	"item_polish": {
		"name": "개광결",
		"max_level": 3,
		"descriptions": {
			1: "모든 일반 성장형 무공의 수치 능력치 6% 증폭",
			2: "모든 일반 성장형 무공의 수치 능력치 15% 증폭",
			3: "모든 일반 성장형 무공의 수치 능력치 25% 증폭",
		},
		"detail": "개광결로 모든 일반 성장형 무공의 증폭 가능한 수치 효과를 독립적으로 강화합니다. 횟수·슬롯·해금·활성 여부 같은 구조값은 그대로 유지됩니다.",
		"icon_color": Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0),
		"tree": "item",
	},
	"item_recycle": {
		"name": "환보결",
		"max_level": 3,
		"descriptions": {
			1: "아이템 유지 확률 9%",
			2: "아이템 유지 확률 20%",
			3: "아이템 유지 확률 35%",
		},
		"detail": "환보결로 사용한 아이템을 확률적으로 되돌려 보존합니다. 자체 회수되는 부메랑은 제외됩니다.",
		"icon_color": Color(148.0 / 255.0, 0.0, 211.0 / 255.0),
		"tree": "item",
	},
	"downtown_treasure_map": {
		"name": "천기보도",
		"max_level": 3,
		"descriptions": {
			1: "승리 보상 픽 절세무공 등장 확률 +188%, 무공 합일 무혼 비용 -1",
			2: "승리 보상 픽 절세무공 등장 확률 +435%, 무공 합일 무혼 비용 -3",
			3: "승리 보상 픽 절세무공 등장 확률 +750%, 무공 합일 무혼 비용 없음",
		},
		"detail": "천기보도가 승리 보상 픽에 절세무공 카드가 등장할 확률을 성급에 따라 최대 750% 높입니다. 무공 합일 무혼 비용은 1성에서 1, 2성에서 3 감소하고, 극성 이상에서는 기본 비용이 올라도 0으로 고정됩니다.",
		"icon_color": Color(1.0, 223.0 / 255.0, 0.0),
		"tree": "downtown",
	},
	"common_swiftness": {
		"name": "유운보",
		"max_level": 5,
		"descriptions": {
			1: "이동속도 6% 증가",
			2: "이동속도 12% 증가",
			3: "이동속도 18% 증가",
			4: "이동속도 24% 증가",
			5: "이동속도 30% 증가",
		},
		"detail": "유운보의 가벼운 보법으로 이동 속도가 증가합니다.",
		"icon_color": Color(100.0 / 255.0, 1.0, 180.0 / 255.0),
		"tree": "common",
	},
	"common_expansion": {
		"name": "광맥결",
		"max_level": 4,
		"descriptions": {
			1: "무공 최대 슬롯 +1 (총 7)",
			2: "무공 최대 슬롯 +1 (총 8)",
			3: "무공 최대 슬롯 +1 (총 9)",
			4: "무공 최대 슬롯 +1 (총 10)",
		},
		"detail": "광맥결로 기맥을 넓혀 이번 런의 무공 최대 슬롯을 1칸씩 늘립니다. 자신은 무공 슬롯을 차지하지 않으며, 직접 투자한 레벨만 적용됩니다. 초월자의 왕관·현문차력·점화 등 유효 레벨 보너스로는 슬롯이 늘지 않습니다.",
		"icon_color": Color(200.0 / 255.0, 150.0 / 255.0, 1.0),
		"tree": "common",
	},
	"common_bulk_up": {
		"name": "철산공",
		"max_level": 5,
		"descriptions": {
			1: "몸집 크기 6% 증가",
			2: "몸집 크기 12% 증가",
			3: "몸집 크기 18% 증가",
			4: "몸집 크기 24% 증가",
			5: "몸집 크기 30% 증가",
		},
		"detail": "철산공으로 몸의 기세를 넓혀 몸집 크기가 증가합니다.",
		"icon_color": Color(1.0, 150.0 / 255.0, 80.0 / 255.0),
		"tree": "common",
	},
	"training_mastery": {
		"name": "연공심법",
		"max_level": 3,
		"descriptions": {
			1: "모든 수련의 능력치 효과 25% 증폭",
			2: "모든 수련의 능력치 효과 58% 증폭",
			3: "모든 수련의 능력치 효과 100% 증폭",
		},
		"detail": "연공심법으로 모든 수련의 수치 효과를 독립적으로 강화합니다. 수납술의 액티브 아이템 슬롯 증가는 그대로 유지됩니다.",
		"icon_color": Color(0.66, 0.49, 0.20),
		"tree": "common",
	},
	"perk_boost_charge": {
		"name": "축기결",
		"max_level": 3,
		"descriptions": {
			1: "확률 +9%, 발동 시 다음 활주 무료 + 재충전 -90%",
			2: "확률 +20%, 발동 시 다음 활주 무료 + 재충전 -90%",
			3: "확률 +35%, 발동 시 다음 활주 무료 + 재충전 -90%",
		},
		"detail": "축기결이 발동하면 다음 활주 횟수 소모를 1회 무효화하고, 재충전 중인 활주 1회의 남은 시간을 90% 줄입니다.",
		"icon_color": Color(80.0 / 255.0, 160.0 / 255.0, 1.0),
		"tree": "common",
	},
	"perk_laurel_shield": {
		"name": "오엽호신",
		"max_level": 3,
		"descriptions": {
			1: "벽사 잎 1개 보호",
			2: "벽사 잎 3개 보호",
			3: "벽사 잎 5개 보호",
		},
		"detail": "공을 막아주는 다섯 벽사 잎이 주변을 돌며 몸을 보호합니다.",
		"icon_color": Color(100.0 / 255.0, 200.0 / 255.0, 100.0 / 255.0),
		"tree": "common",
	},
	"common_training": {
		"name": "조식심법",
		"max_level": 5,
		"descriptions": {
			1: "모든 초식 쿨타임 8% 감소",
			2: "모든 초식 쿨타임 16% 감소",
			3: "모든 초식 쿨타임 24% 감소",
			4: "모든 초식 쿨타임 32% 감소",
			5: "모든 초식 쿨타임 40% 감소",
		},
		"detail": "호흡과 기운을 고르게 하여 모든 초식을 더 빠르게 다시 펼칩니다. 모든 효과 적용 후 최종 쿨타임은 기본값의 5% 미만으로 내려가지 않습니다. (최대 95% 감소)",
		"icon_color": Color(1.0, 160.0 / 255.0, 80.0 / 255.0),
		"tree": "common",
	},
}

const SMASHER_PERKS := {
	"dash_spirit": {
		"name": "잔영호법",
		"max_level": 3,
		"descriptions": {
			1: "활주시 9% 확률로 레이저 잔상",
			2: "활주시 20% 확률로 레이저 잔상",
			3: "활주시 35% 확률로 레이저 잔상",
		},
		"detail": "활주 중 레이저 잔상이 공을 막아줄 수 있습니다.",
		"icon_color": Color(0.0, 1.0, 1.0),
		"tree": "smasher",
		"character_restriction": "smasher",
	},
	"unlock_magnum_grip": {
		"name": "흡인장 비급",
		"max_level": 1,
		"descriptions": {1: "흡인장 초식 비급"},
		"detail": "좌+우 동시 입력으로 자기장을 형성해 공을 끌어당기는 초식을 익힙니다.",
		"icon_color": Color(200.0 / 255.0, 140.0 / 255.0, 1.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "magnum_grip",
	},
	"unlock_plasma": {
		"name": "한령탄 비급",
		"max_level": 1,
		"descriptions": {1: "한령탄 초식 비급"},
		"detail": "W/위 방향으로 한령탄을 발사해 적을 둔화하는 초식을 장착합니다.",
		"icon_color": Color(0.0, 200.0 / 255.0, 1.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "plasma",
	},
	"unlock_recovery_skill": {
		"name": "경신보 비급",
		"max_level": 1,
		"descriptions": {1: "경신보 초식 비급"},
		"detail": "활주 후딜 제거와 짧은 이동 보너스를 주는 초식을 장착합니다.",
		"icon_color": Color(50.0 / 255.0, 1.0, 150.0 / 255.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "recovery",
	},
	"unlock_cleanse": {
		"name": "청심결 비급",
		"max_level": 1,
		"descriptions": {1: "청심결 초식 비급"},
		"detail": "상태이상을 즉시 해제하고 잠시 면역을 얻는 초식을 장착합니다.",
		"icon_color": Color(1.0, 220.0 / 255.0, 115.0 / 255.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "cleanse",
	},
	"unlock_shield_kiting": {
		"name": "회천비륜 비급",
		"max_level": 1,
		"descriptions": {1: "회천비륜 초식 비급"},
		"detail": "귀면 방패를 회전 투척해 공을 요격하고 다시 회수하는 초식을 장착합니다.",
		"icon_color": Color(110.0 / 255.0, 210.0 / 255.0, 1.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "shield_kiting",
	},
	"unlock_ghost_shot": {
		"name": "빙혼비격 비급",
		"max_level": 1,
		"descriptions": {1: "빙혼비격 초식 비급"},
		"detail": "기력 420 이상에서 천뢰격 입력 시 한미량이 공에 빙의해 기괴한 궤적으로 보스에게 비격을 날리는 초식을 익힙니다.",
		"icon_color": Color(120.0 / 255.0, 50.0 / 255.0, 180.0 / 255.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "ghost_shot",
	},
	"unlock_warp_gate": {
		"name": "건곤환문 비급",
		"max_level": 1,
		"descriptions": {1: "건곤환문 초식 비급"},
		"detail": "S 또는 ↓ 키를 0.5초 이상 홀드하면 건곤의 문을 열어 좌/우 경계를 넘어 반대편으로 순간이동하는 초식을 익힙니다. 문을 넘을 때 추가 기력을 소모하지 않으며, 통과 후 2초간 이동 경로에 남은 환문잔영이 공을 한 번 받아치고 연기로 흩어집니다.",
		"icon_color": Color(200.0 / 255.0, 110.0 / 255.0, 1.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "warp_gate",
	},
	"unlock_smasher_wheel": {
		"name": "풍운천선무 비급",
		"max_level": 1,
		"descriptions": {1: "풍운천선무 초식 비급"},
		"detail": "A→W→D 또는 D→W→A 순서 입력으로 구름을 휘감아 회전하고, 공에 닿으면 구름을 흩뜨리며 고속 곡선으로 반격하는 초식을 익힙니다.",
		"icon_color": Color(0.64, 0.84, 1.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "smasher_wheel",
	},
	"unlock_smasher_overdrive": {
		"name": "벽력유성 비급",
		"max_level": 1,
		"descriptions": {1: "벽력유성 초식 비급"},
		"detail": "우클릭을 유지한 채 받아친 공이 반대쪽으로 활강하다 보스 코앞에서 급전하는 초식을 익힙니다. ←/→로 최종 낙하 지점을 지정합니다.",
		"icon_color": Color(80.0 / 255.0, 225.0 / 255.0, 1.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "smasher_overdrive",
	},
	"unlock_void_phantom": {
		"name": "허공환영 비급",
		"max_level": 1,
		"descriptions": {1: "허공환영 초식 비급"},
		"detail": "↓/S와 좌클릭을 유지한 채 공을 받아치면 허공을 갈라 반투명 환영공 2개를 좌우로 넓게 띄워 보내, 보스가 어느 것이 진짜인지 착각하게 만드는 초식을 익힙니다.",
		"icon_color": Color(0.35, 0.90, 1.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "void_phantom",
	},
	"extension_gear": {
		"name": "불식심법",
		"max_level": 3,
		"descriptions": {
			1: "경신보/청심결/건곤환문 지속시간 +31%",
			2: "경신보/청심결/건곤환문 지속시간 +73%",
			3: "경신보/청심결/건곤환문 지속시간 +125%",
		},
		"detail": "스매셔의 지속형 유틸리티 초식 시간이 길어집니다.",
		"icon_color": Color(120.0 / 255.0, 230.0 / 255.0, 180.0 / 255.0),
		"tree": "smasher",
		"character_restriction": "smasher",
	},
	"combo_amplifier_chip": {
		"name": "축뢰심법",
		"max_level": 3,
		"descriptions": {
			1: "콤보 효과 증폭: 벽력타 공속+113%, 커브+4%, 천뢰격 공속+56%, 초기부스트 감쇄 -13%",
			2: "콤보 효과 증폭: 벽력타 공속+261%, 커브+9%, 천뢰격 공속+131%, 초기부스트 감쇄 -29%",
			3: "콤보 효과 증폭: 벽력타 공속+450%, 커브+15%, 천뢰격 공속+225%, 초기부스트 감쇄 -50%(캡)",
		},
		"detail": "콤보 소모형 벽력타/천뢰격의 콤보 비례 증가율을 추가로 증폭합니다. 공속 증폭은 경지에 따라 계속 증가하지만, 벽력타 커브 증폭은 3성에서 상한에 도달합니다. 또한 천뢰격의 초기 부스트 감쇄가 완만해져 폭발력이 더 오래 유지됩니다.",
		"icon_color": Color(1.0, 100.0 / 255.0, 200.0 / 255.0),
		"tree": "smasher",
		"character_restriction": "smasher",
	},
}

const VIPER_PERKS := {
	"unlock_wall_leap_raid": {
		"name": "월담야습 비급",
		"max_level": 1,
		"descriptions": {1: "월담야습 초식 비급"},
		"detail": "우클릭으로 적진에 잠입한 뒤 참격 또는 폭발을 선택하고 진입 위치로 귀환하는 월담야습을 익힙니다.",
		"icon_color": Color(0.30, 0.82, 0.92),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "wall_leap_raid",
	},
	"unlock_nerve_strike": {
		"name": "독영절맥 비급",
		"max_level": 1,
		"descriptions": {1: "독영절맥 초식 비급"},
		"detail": "검기 계열에서 이어져 상대의 등 뒤를 베고 혼란시키는 독영절맥을 장착합니다.",
		"icon_color": Color(180.0 / 255.0, 0.0, 220.0 / 255.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "nerve_strike",
	},
	"unlock_dive_strike": {
		"name": "천뢰진각 비급",
		"max_level": 1,
		"descriptions": {1: "천뢰진각 초식 비급"},
		"detail": "공중에서 내려꽂혀 원형 뇌전 파동을 퍼뜨리는 천뢰진각을 장착합니다.",
		"icon_color": Color(1.0, 120.0 / 255.0, 50.0 / 255.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "dive_strike",
	},
	"unlock_chaos_spear": {
		"name": "혼천흑창 비급",
		"max_level": 1,
		"descriptions": {1: "혼천흑창 초식 비급"},
		"detail": "A-W-D 입력으로 중앙에 흡인하는 흑창을 꽂는 혼천흑창을 장착합니다.",
		"icon_color": Color(135.0 / 255.0, 70.0 / 255.0, 1.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "chaos_spear",
	},
	"unlock_dual_glitch": {
		"name": "쌍영분신 비급",
		"max_level": 1,
		"descriptions": {1: "쌍영분신 초식 비급"},
		"detail": "좌우에 움직임을 비추는 두 분신을 소환하는 쌍영분신을 장착합니다.",
		"icon_color": Color(60.0 / 255.0, 220.0 / 255.0, 150.0 / 255.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "dual_glitch",
	},
	"unlock_ignition_aura": {
		"name": "염화개맥 비급",
		"max_level": 1,
		"descriptions": {1: "염화개맥 초식 비급"},
		"detail": "지상에서 기를 모아 모든 투자 무공을 잠시 강화하는 염화개맥을 장착합니다.",
		"icon_color": Color(1.0, 130.0 / 255.0, 40.0 / 255.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "ignition_aura",
	},
	"double_marshal_kick": {
		"name": "환영연각 비급",
		"max_level": 1,
		"descriptions": {1: "마샬 킥 적중 후 환영연각 발동 가능"},
		"detail": "마샬 킥으로 공을 맞힌 뒤 S/아래 입력으로 2차 연계 환영연각을 사용할 수 있습니다. 기력 60, 쿨타임 40초.",
		"icon_color": Color(180.0 / 255.0, 0.0, 1.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "phantom_kick",
	},
	"core_flip": {
		"name": "화랑비천각 비급",
		"max_level": 1,
		"descriptions": {
			1: "활주로 공을 맞춘 뒤 0.7초 이내 A+D 동시 입력으로 화랑비천각 발동",
		},
		"detail": "활주로 공을 맞춘 뒤 0.7초 이내에 A+D(또는 ←+→)를 동시에 누르면 화랑비천각이 발동됩니다.\n벽을 타고 반사각으로 공을 차며, 적중 시 마샬 킥(→환영연각) 연계가 열립니다.\n기력 120, 쿨타임 25초.",
		"icon_color": Color(1.0, 110.0 / 255.0, 200.0 / 255.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "core_flip",
	},
	"dark_blade": {
		"name": "혈영참 비급",
		"max_level": 1,
		"descriptions": {1: "공 타격 후 1초 내 공중 W/↑로 혈영참 발동"},
		"detail": "쉐도우 백스텝, 마샬 킥, 환영연각, 화랑비천각으로 공을 맞히면 1초간 혈영참 연계 창이 열리고 캐릭터가 붉게 빛납니다.\n그 안에 공중에서 W/↑를 누르면 검붉은 강화 검기를 발사합니다.\n검기가 공을 맞히면 마샬 킥 창이 열리지만 환영연각 창은 직접 열지 않습니다.\n기력 200, 쿨타임 45초.",
		"icon_color": Color(120.0 / 255.0, 0.0, 30.0 / 255.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "dark_blade",
	},
	"jetpack_enhance": {
		"name": "승운신법",
		"max_level": 3,
		"descriptions": {
			1: "제트팩 최대 게이지 +25%",
			2: "제트팩 최대 게이지 +58%, 체공 중 게이지 획득 +17%",
			3: "제트팩 최대 게이지 +100%, 체공 중 게이지 획득 +30%",
		},
		"detail": "바이퍼의 공중 운용 여유가 커집니다.",
		"icon_color": Color(90.0 / 255.0, 220.0 / 255.0, 1.0),
		"tree": "viper",
		"character_restriction": "viper",
	},
	"kick_enhance": {
		"name": "천각심법",
		"max_level": 3,
		"descriptions": {
			1: "킥 발사 정밀도 +10%, 공속 +15%, 준비 -9%",
			2: "킥 발사 정밀도 +23%, 공속 +35%, 준비 -20%, 용광로 넉백볼 17%",
			3: "킥 발사 정밀도 +40%, 공속 +60%, 준비 -35%, 용광로 넉백볼 30%",
		},
		"detail": "바이퍼 킥 계열 초식의 정밀도, 공속, 준비동작을 강화합니다. 2성부터 킥 적중 시 확률로 공이 용광로 넉백볼이 되며, 보스가 가드하면 화재형 넉백 150%를 1회 적용합니다.",
		"icon_color": Color(1.0, 90.0 / 255.0, 130.0 / 255.0),
		"tree": "viper",
		"character_restriction": "viper",
	},
	"blade_amp": {
		"name": "검강심법",
		"max_level": 3,
		"descriptions": {
			1: "참격 사거리/가로폭 +13%, 참격 속도 +13%",
			2: "참격 사거리/가로폭 +29%, 참격 속도 +29%, 유도검기",
			3: "참격 사거리/가로폭 +50%, 참격 속도 +50%, 추가 유도검기",
		},
		"detail": "에어 블레이드와 혈영참의 검기를 강화합니다.",
		"icon_color": Color(180.0 / 255.0, 60.0 / 255.0, 220.0 / 255.0),
		"tree": "viper",
		"character_restriction": "viper",
	},
	"four_poisons": {
		"name": "사독귀일",
		"max_level": 3,
		"descriptions": {
			1: "천뢰진각/혼천흑창 준비 -10%, 천뢰진각 수면 +6%, 독영절맥 혼란 +18%, 쌍영분신 지속 +8%",
			2: "천뢰진각/혼천흑창 준비 -23%, 천뢰진각 수면 +15%, 독영절맥 혼란 +41%, 쌍영분신 지속 +19%, 쌍영분신 HP 3, 4초식 쿨 -12%, 슈퍼아머",
			3: "천뢰진각/혼천흑창 준비 -40%, 천뢰진각 수면 +25%, 독영절맥 혼란 +70%, 쌍영분신 지속 +33%, 쌍영분신 HP 4, 4초식 쿨 -20%, 슈퍼아머, 분신 복제",
		},
		"detail": "천뢰진각, 독영절맥, 혼천흑창, 쌍영분신을 묶어 강화합니다.\n천뢰진각/혼천흑창 준비와 천뢰진각 수면, 독영절맥 혼란, 쌍영분신 지속시간을 올립니다.\n2성부터 준비동작 슈퍼아머와 4초식 쿨감이 켜지고 쌍영분신 HP가 3이 됩니다.\n극성부터 쌍영분신 HP 4, 분신 초식 복제가 적용됩니다. 복제는 추가 기력/쿨/골드를 만들지 않습니다.",
		"icon_color": Color(215.0 / 255.0, 70.0 / 255.0, 1.0),
		"tree": "viper",
		"character_restriction": "viper",
	},
}

const SOLDIER_PERKS := {
	"soldier_unlock_net_gun": {
		"name": "투망총통",
		"max_level": 1,
		"descriptions": {1: "투망총통 밀조도"},
		"detail": "투망총통을 영구 습득하고 호란의 화기 구슬에 추가합니다. 총통에 오랏줄을 물려 고친 물건이라 산채에선 오랏총이라 부릅니다. 탄환은 재장약으로 1발씩 다시 채웁니다.",
		"icon_color": Color(100.0 / 255.0, 180.0 / 255.0, 100.0 / 255.0),
		"tree": "soldier_unlock",
		"character_restriction": "soldier",
		"is_weapon_unlock": true,
		"weapon_name": "net_gun",
		"unlocks_skill": "net_gun",
	},
	"soldier_unlock_fire_support": {
		"name": "신기화전",
		"max_level": 1,
		"descriptions": {1: "신기화전 밀조도"},
		"detail": "신기화전을 영구 습득하고 호란의 화기 구슬에 추가합니다. 관군 화차째 통째로 털어온 물건이라 산채에선 불벼락이라 부릅니다. 호출권은 재장약 게이지가 끝까지 차면 보충됩니다.",
		"icon_color": Color(1.0, 100.0 / 255.0, 50.0 / 255.0),
		"tree": "soldier_unlock",
		"character_restriction": "soldier",
		"is_weapon_unlock": true,
		"weapon_name": "fire_support",
		"unlocks_skill": "fire_support",
	},
	"soldier_unlock_bowling_trap": {
		"name": "질려포통",
		"max_level": 1,
		"descriptions": {1: "질려포통 밀조도"},
		"detail": "질려포통을 영구 습득하고 호란의 화기 구슬에 추가합니다. 굴려서 마름쇠를 뿌리는 통이라 산채에선 밤송이라 부릅니다. 탄환은 재장약으로 1발씩 다시 채웁니다.",
		"icon_color": Color(200.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0),
		"tree": "soldier_unlock",
		"character_restriction": "soldier",
		"is_weapon_unlock": true,
		"weapon_name": "bowling_trap",
		"unlocks_skill": "bowling_trap",
	},
	"soldier_unlock_suicide_drone": {
		"name": "화조뢰",
		"max_level": 1,
		"descriptions": {1: "화조뢰 밀조도"},
		"detail": "화조뢰를 영구 습득하고 호란의 화기 구슬에 추가합니다. 비격진천뢰에 날개를 달아 고친 물건이라 산채에선 불까마귀라 부릅니다. 탄환은 재장약으로 1발씩 다시 채웁니다.",
		"icon_color": Color(1.0, 100.0 / 255.0, 50.0 / 255.0),
		"tree": "soldier_unlock",
		"character_restriction": "soldier",
		"is_weapon_unlock": true,
		"weapon_name": "suicide_drone",
		"unlocks_skill": "suicide_drone",
	},
	"soldier_unlock_bazooka": {
		"name": "벽력완구",
		"max_level": 1,
		"descriptions": {1: "벽력완구 밀조도"},
		"detail": "벽력완구를 영구 습득하고 호란의 화기 구슬에 추가합니다. 대완구를 어깨에 메도록 잘라낸 개조품이라 산채에선 떡메라 부릅니다. 탄약은 재장약으로 1발씩 다시 채웁니다.",
		"icon_color": Color(220.0 / 255.0, 120.0 / 255.0, 70.0 / 255.0),
		"tree": "soldier_unlock",
		"character_restriction": "soldier",
		"is_weapon_unlock": true,
		"weapon_name": "bazooka",
		"unlocks_skill": "bazooka",
	},
	"soldier_unlock_ak47": {
		"name": "연주총통",
		"max_level": 1,
		"descriptions": {1: "연주총통 밀조도"},
		"detail": "연주총통을 영구 습득하고 호란의 화기 구슬에 추가합니다. 쉬지 않고 쏘면 총열이 콩 볶듯 달아올라 산채에선 콩볶이라 부릅니다. 탄약과 지속시간은 재장약 게이지가 끝까지 차면 보충됩니다.",
		"icon_color": Color(110.0 / 255.0, 135.0 / 255.0, 85.0 / 255.0),
		"tree": "soldier_unlock",
		"character_restriction": "soldier",
		"is_weapon_unlock": true,
		"weapon_name": "ak47",
		"unlocks_skill": "ak47",
	},
	"soldier_pistol_perk": {
		"name": "삼안속총",
		"max_level": 1,
		"descriptions": {1: "삼안속총 밀조도"},
		"detail": "기본 단총통은 유지한 채 삼안속총을 별도 영구 화기로 습득합니다. 세 총열을 잇달아 격발하도록 손봐서 산채에선 세눈이라 부릅니다. 준비동작 없이 즉시 격발되며 단총통보다 연사가 2배 빠르고 탄속 20%, 정확도 30%가 향상되고 탄약 12발은 재장약으로만 보충합니다.",
		"icon_color": Color(140.0 / 255.0, 130.0 / 255.0, 120.0 / 255.0),
		"tree": "soldier_unlock",
		"character_restriction": "soldier",
		"is_weapon_unlock": true,
		"weapon_name": "commando_pistol",
		"unlocks_skill": "commando_pistol",
	},
	"pistol_enhance": {
		"name": "철포결",
		"max_level": 3,
		"descriptions": {
			1: "단총통 정확도 ±11°, 탄속 +13%, 넉백 +38%, 장전 5발",
			2: "단총통 정확도 ±7°, 탄속 +29%, 넉백 +87%, 장전 6발",
			3: "단총통 정확도 ±1°, 탄속 +50%, 넉백 +150%, 장전 7발",
		},
		"detail": "기본 화기인 단총통 전용 강화입니다. 삼안속총은 영향을 받지 않습니다.\n경지가 오를수록 단총통 탄퍼짐이 줄고 탄속과 정상타 넉백이 증가하며, 2성/극성에 장전 수가 늘어납니다.\n유효 경지가 극성 +1 이상이면 정확도는 ±1°, 탄속은 +50%, 넉백은 +150%에 머물고 장전 수만 경지마다 1발씩 계속 늘어납니다.",
		"icon_color": Color(210.0 / 255.0, 175.0 / 255.0, 92.0 / 255.0),
		"tree": "soldier",
		"character_restriction": "soldier",
	},
}

const CONVERTED_PERKS := {
	"star_detector": {
		"name": "낙성결",
		"max_level": 3,
		"descriptions": {
			1: "무혼 보너스 출현 확률 +6%",
			2: "무혼 보너스 출현 확률 +15%",
			3: "무혼 보너스 출현 확률 +25%",
		},
		"detail": "무혼이 나타날 때 추가 무혼이 나타날 확률을 얻습니다.",
		"icon_color": Color(80.0 / 255.0, 200.0 / 255.0, 220.0 / 255.0),
		"tree": "item",
		"conversion_source": "star_detector",
	},
	"adversity_armor": {
		"name": "역천호신",
		"max_level": 3,
		"descriptions": {
			1: "실점 후 발동 10%, 보호 3.75초",
			2: "실점 후 발동 23%, 보호 8.7초",
			3: "실점 후 발동 40%, 보호 15초",
		},
		"detail": "실점 다음 라운드에 무적벽을 세워 사용자를 보호합니다.",
		"icon_color": Color(0.96, 0.58, 0.18),
		"tree": "common",
		"conversion_source": "adversity_armor",
	},
	"reinforced_boomerang_gauntlet": {
		"name": "회선철수",
		"max_level": 3,
		"descriptions": {
			1: "부메랑 넉백 +13%, 스턴 +20%, 발사속도 +13%, 유도 +13%, 스폰 +50%",
			2: "부메랑 넉백 +29%, 스턴 +46%, 발사속도 +29%, 유도 +29%, 스폰 +116%",
			3: "부메랑 넉백 +50%, 스턴 +80%, 발사속도 +50%, 유도 +50%, 스폰 +200%",
		},
		"detail": "부메랑을 메탈 강화하고 전투 성능과 필드 등장률을 끌어올립니다.",
		"icon_color": Color(150.0 / 255.0, 200.0 / 255.0, 1.0),
		"tree": "item",
		"conversion_source": "reinforced_boomerang_gauntlet",
	},
	"sensor": {
		"name": "감응보",
		"max_level": 3,
		"descriptions": {
			1: "자동 활주 1회, 쿨타임 29초",
			2: "자동 활주 1회, 쿨타임 23초",
			3: "자동 활주 2회, 쿨타임 15초",
		},
		"detail": "위험 상황에서 전용 횟수를 사용해 자동으로 활주합니다.",
		"icon_color": Color(150.0 / 255.0, 150.0 / 255.0, 1.0),
		"tree": "dash",
		"conversion_source": "sensor",
	},
	"dowsing_pendulum": {
		"name": "섭물공",
		"max_level": 3,
		"descriptions": {
			1: "필드 아이템·무혼 흡인 범위 70px",
			2: "필드 아이템·무혼 흡인 범위 162px",
			3: "필드 아이템·무혼 흡인 범위 280px",
		},
		"detail": "주변의 필드 아이템과 무혼을 플레이어 쪽으로 끌어당깁니다.",
		"icon_color": Color(100.0 / 255.0, 150.0 / 255.0, 1.0),
		"tree": "item",
		"conversion_source": "dowsing_pendulum",
	},
	"dowsing_goggles": {
		"name": "천안결",
		"max_level": 3,
		"descriptions": {
			1: "무공 선택지 보너스 발동 확률 40%, 합일 희귀 슬롯 확률 +5%p, 상승무공 1개 비중 6%p를 2개와 3개로 이동",
			2: "무공 선택지 보너스 발동 확률 70%, 합일 희귀 슬롯 확률 +10%p, 상승무공 1개 비중 12%p를 2개와 3개로 이동",
			3: "무공 선택지 보너스 발동 확률 100%, 합일 희귀 슬롯 확률 +15%p, 상승무공 1개 비중 18%p를 2개와 3개로 이동",
		},
		"detail": "무공 선택지가 열릴 때 확률적으로 선택지 하나를 더 보여줍니다. 합일의 상승무공 총 발현 확률은 유지하고, 희귀 슬롯 확률을 높이며 상승무공 1개 비중을 2개와 3개로 옮깁니다. 희귀 슬롯 확률은 최대 60%, 1개 비중은 최소 20%입니다.",
		"icon_color": Color(70.0 / 255.0, 210.0 / 255.0, 1.0),
		"tree": "item",
		"conversion_source": "dowsing_goggles",
	},
	"chargebag": {
		"name": "반탄심법",
		"max_level": 3,
		"descriptions": {
			1: "벽 반사 기력 +14%",
			2: "벽 반사 기력 +32%",
			3: "벽 반사 기력 +55%",
		},
		"detail": "공이 벽에 닿을 때마다 추가 기력을 얻습니다.",
		"icon_color": Color(100.0 / 255.0, 1.0, 100.0 / 255.0),
		"tree": "item",
		"conversion_source": "chargebag",
	},
	"battery": {
		"name": "장기심법",
		"max_level": 3,
		"descriptions": {
			1: "스테이지 전환 기력 보존 25%",
			2: "스테이지 전환 기력 보존 58%",
			3: "스테이지 전환 기력 보존 100%",
		},
		"detail": "다음 스테이지로 넘어갈 때 현재 기력 일부를 보존합니다.",
		"icon_color": Color(1.0, 1.0, 0.0),
		"tree": "item",
		"conversion_source": "battery",
	},
	"master": {
		"name": "축성공",
		"max_level": 3,
		"descriptions": {
			1: "토벽·널뛰기 폭 +11%, 아이템 쿨타임 3% 감소, 토벽패 등장 +83%",
			2: "토벽·널뛰기 폭 +26%, 아이템 쿨타임 7% 감소, 토벽패 등장 +191%",
			3: "토벽·널뛰기 폭 +45%, 아이템 쿨타임 12% 감소, 토벽패 등장 +330%",
		},
		"detail": "토벽과 널뛰기의 폭을 늘리고, 액티브 아이템 쿨타임을 줄이며 토벽패 등장 빈도를 높입니다.",
		"icon_color": Color(1.0, 215.0 / 255.0, 0.0),
		"tree": "item",
		"conversion_source": "master",
	},
	"gold_digger": {
		"name": "취금결",
		"max_level": 3,
		"descriptions": {
			1: "골드 획득량 +14%",
			2: "골드 획득량 +32%",
			3: "골드 획득량 +55%",
		},
		"detail": "전투 중 얻는 골드 획득량을 늘립니다.",
		"icon_color": Color(1.0, 200.0 / 255.0, 50.0 / 255.0),
		"tree": "item",
		"conversion_source": "gold_digger",
	},
	"lucky_coin": {
		"name": "쌍복결",
		"max_level": 3,
		"descriptions": {
			1: "아이템 더블스폰 확률 4%",
			2: "아이템 더블스폰 확률 10%",
			3: "아이템 더블스폰 확률 17%",
		},
		"detail": "필드 아이템이 나타날 때 보너스 아이템을 한 번 더 노립니다.",
		"icon_color": Color(1.0, 223.0 / 255.0, 0.0),
		"tree": "item",
		"conversion_source": "lucky_coin",
	},
	"shrapnel_armor": {
		"name": "산화수",
		"max_level": 3,
		"descriptions": {
			1: "발동 4%, 파편 2개, 넉백 Lv.1, 기력 48 소모",
			2: "발동 10%, 파편 5개, 넉백 Lv.2, 기력 38 소모",
			3: "발동 17%, 파편 8개, 넉백 Lv.4, 기력 25 소모",
		},
		"detail": "공을 칠 때 기력을 소모해 보스를 향한 파편을 사출합니다.",
		"icon_color": Color(1.0, 150.0 / 255.0, 80.0 / 255.0),
		"tree": "common",
		"conversion_source": "shrapnel_armor",
	},
	"fuel_pouch": {
		"name": "태허심법",
		"max_level": 5,
		"descriptions": {
			1: "최대 기력 +40",
			2: "최대 기력 +65",
			3: "최대 기력 +90",
			4: "최대 기력 +115",
			5: "최대 기력 +140",
		},
		"detail": "플레이어가 보유할 수 있는 최대 기력을 늘립니다.",
		"icon_color": Color(180.0 / 255.0, 100.0 / 255.0, 40.0 / 255.0),
		"tree": "common",
		"conversion_source": "fuel_pouch",
	},
	"bluetooth_ring": {
		"name": "격기심법",
		"max_level": 5,
		"descriptions": {
			1: "타격 기력 +6%",
			2: "타격 기력 +11%",
			3: "타격 기력 +15%",
			4: "타격 기력 +20%",
			5: "타격 기력 +24%",
		},
		"detail": "공을 받아칠 때 얻는 기력을 늘립니다.",
		"icon_color": Color(100.0 / 255.0, 150.0 / 255.0, 1.0),
		"tree": "common",
		"conversion_source": "bluetooth_ring",
	},
	"foul_whistle": {
		"name": "반전결",
		"max_level": 3,
		"descriptions": {
			1: "실점 무효 확률 3%",
			2: "실점 무효 확률 6%",
			3: "실점 무효 확률 11%",
		},
		"detail": "라운드 패배 시 실점을 취소하고 라운드 재시작을 노립니다.",
		"icon_color": Color(1.0, 235.0 / 255.0, 120.0 / 255.0),
		"tree": "common",
		"conversion_source": "foul_whistle",
	},
	"neural_helmet": {
		"name": "강신결",
		"max_level": 3,
		"descriptions": {
			1: "신령환 가드 기력 비용 8 감소, 패들 반사 공속 추가 +3%, 스폰 +83%",
			2: "신령환 가드 기력 비용 17 감소, 패들 반사 공속 추가 +6%, 스폰 +191%",
			3: "신령환 가드 기력 비용 30 감소, 패들 반사 공속 추가 +10%, 스폰 +330%",
		},
		"detail": "신령환의 가드 1회 기력 비용을 낮추고, 패들 반사 시 기존 공속 증가에 성급별 추가 보너스를 더하며 필드 등장률을 높입니다. 발동 중 아래 방향키(S/↓)를 1초간 누르면 해제할 수 있습니다.",
		"icon_color": Color(140.0 / 255.0, 180.0 / 255.0, 1.0),
		"tree": "item",
		"conversion_source": "neural_helmet",
	},
	"commando_arm": {
		"name": "비병결",
		"max_level": 3,
		"descriptions": {
			1: "투척 속도 +6%, 폭발 +5%, 연막 +12%, 준비 12% 감소",
			2: "투척 속도 +14%, 폭발 +10%, 연막 +28%, 준비 28% 감소",
			3: "투척 속도 +24%, 폭발 +18%, 연막 +48%, 준비 48% 감소",
		},
		"detail": "투척형 액티브 아이템들의 속도, 폭발, 지속, 준비 시간을 강화합니다.",
		"icon_color": Color(60.0 / 255.0, 60.0 / 255.0, 70.0 / 255.0),
		"tree": "item",
		"conversion_source": "commando_arm",
	},
	"rainbow_fur_glove": {
		"name": "칠채순환",
		"max_level": 3,
		"descriptions": {
			1: "공 히트 시 발동 2%, 진행 중 초식의 전체 쿨타임 5% 감소",
			2: "공 히트 시 발동 4%, 진행 중 초식의 전체 쿨타임 12% 감소",
			3: "공 히트 시 발동 7%, 진행 중 초식의 전체 쿨타임 20% 감소",
		},
		"detail": "공을 받아칠 때 장착한 초식의 전체 쿨타임을 기준으로 진행 중 쿨타임을 줄입니다.",
		"icon_color": Color(1.0, 170.0 / 255.0, 220.0 / 255.0),
		"tree": "common",
		"conversion_source": "rainbow_fur_glove",
	},
	"knee_pads": {
		"name": "비각축기",
		"max_level": 3,
		"descriptions": {
			1: "짧은 활주 타격 기력 +18%",
			2: "짧은 활주 타격 기력 +41%",
			3: "짧은 활주 타격 기력 +70%",
		},
		"detail": "짧은 활주로 공을 맞출 때 추가 기력을 얻습니다.",
		"icon_color": Color(80.0 / 255.0, 80.0 / 255.0, 100.0 / 255.0),
		"tree": "dash",
		"conversion_source": "knee_pads",
	},
	"soul_burst": {
		"name": "폭혼보",
		"max_level": 3,
		"descriptions": {
			1: "활주 횟수가 없을 때 완전 활주 기력 166",
			2: "활주 횟수가 없을 때 완전 활주 기력 137",
			3: "활주 횟수가 없을 때 완전 활주 기력 100",
		},
		"detail": "활주 횟수가 없을 때 기력을 소모해 완전 활주를 발동합니다.",
		"icon_color": Color(150.0 / 255.0, 80.0 / 255.0, 1.0),
		"tree": "dash",
		"conversion_source": "soul_burst",
	},
	"bulletproof_hat": {
		"name": "철심공",
		"max_level": 5,
		"descriptions": {
			1: "자세보정 +6%",
			2: "자세보정 +11%",
			3: "자세보정 +15%",
			4: "자세보정 +20%",
			5: "자세보정 +24%",
		},
		"detail": "자세보정으로 스턴 지속시간과 넉백 이동거리·지속시간을 함께 줄입니다.",
		"icon_color": Color(0.38, 0.72, 1.0),
		"tree": "common",
		"conversion_source": "bulletproof_hat",
	},
	"venom_mist_gauntlet": {
		"name": "독운공",
		"max_level": 3,
		"descriptions": {
			1: "독안개 발동 14%, 지속 1.38초",
			2: "독안개 발동 32%, 지속 3.19초",
			3: "독안개 발동 55%, 지속 5.5초",
		},
		"detail": "화랑비천각으로 감염된 공을 보스가 막으면 독안개를 생성합니다.",
		"icon_color": Color(80.0 / 255.0, 200.0 / 255.0, 80.0 / 255.0),
		"tree": "viper",
		"character_restriction": "viper",
		"conversion_source": "venom_mist_gauntlet",
	},
	"sage_ring": {
		"name": "현문차력",
		"max_level": 3,
		"descriptions": {
			1: "공 타격 시 5%: 모든 무공 유효 경지 +1 (2.5초)",
			2: "공 타격 시 5%: 모든 무공 유효 경지 +2 (5.8초)",
			3: "공 타격 시 5%: 모든 무공 유효 경지 +3 (10초)",
		},
		"detail": "공을 타격할 때 5% 확률로 발동해 일정 시간 모든 무공의 유효 경지를 올립니다. 활성 중 다시 발동하면 효과는 중첩되지 않고 현재 투자 경지 기준으로 지속시간이 갱신됩니다.",
		"icon_color": Color(160.0 / 255.0, 115.0 / 255.0, 1.0),
		"tree": "common",
		"effective_level_exempt": true,
		"conversion_source": "sage_ring",
	},
}

const CONVERTED_MYTHIC_PERKS := {
	"megingjord": {
		"name": "삼재개문",
		"max_level": 1,
		"descriptions": {1: "무공 추가선택 발동 40%"},
		"detail": "무공 선택 시 삼재의 문을 열어 추가 선택 기회를 얻습니다.",
		"icon_color": Color(1.0, 215.0 / 255.0, 75.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "megingjord",
	},
	"transcendent_crown": {
		"name": "만법귀일",
		"max_level": 1,
		"descriptions": {1: "전 무공 유효 경지 +2"},
		"detail": "투자한 모든 무공의 흐름을 하나로 합쳐 유효 경지를 올립니다.",
		"icon_color": Color(1.0, 215.0 / 255.0, 100.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "transcendent_crown",
	},
	"ragnarok_hammer": {
		"name": "천뢰진경",
		"max_level": 1,
		"descriptions": {1: "발동 30%, 스턴 1.0초, 공속 +25%, 기력 30 소모"},
		"detail": "받아친 공에 천뢰의 기운을 실어 보스를 감전·기절시킵니다.",
		"icon_color": Color(120.0 / 255.0, 190.0 / 255.0, 1.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "ragnarok_hammer",
	},
	"hermes_shoes": {
		"name": "축지신행",
		"max_level": 1,
		"descriptions": {1: "이동속도 +50%"},
		"detail": "땅을 접어 건너는 축지 보법으로 이동속도가 크게 증가합니다.",
		"icon_color": Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "hermes_shoes",
	},
	"poseidon_trident": {
		"name": "쌍룡회류",
		"max_level": 1,
		"descriptions": {1: "쿨타임 6초, 기력 30, 소용돌이 200px"},
		"detail": "활주 회복 순간 좌우에 쌍룡의 거대한 물회오리를 생성합니다.",
		"icon_color": Color(70.0 / 255.0, 185.0 / 255.0, 1.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "poseidon_trident",
	},
	"sacred_laurel": {
		"name": "팔엽금강",
		"max_level": 1,
		"descriptions": {1: "호신엽 8장"},
		"detail": "여덟 장의 호신엽이 금강진을 이루어 공을 막아 줍니다.",
		"icon_color": Color(135.0 / 255.0, 235.0 / 255.0, 150.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "sacred_laurel",
	},
	"heavenly_cape": {
		"name": "천문개결",
		"max_level": 1,
		"descriptions": {1: "초식 슬롯 +1, 초식 쿨타임 15% 감소"},
		"detail": "천문을 열어 초식 구슬 슬롯을 늘리고 초식을 더 빠르게 펼칩니다.",
		"icon_color": Color(190.0 / 255.0, 225.0 / 255.0, 1.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "heavenly_cape",
	},
	"horn_strawberry_mask": {
		"name": "혼딸기강신",
		"max_level": 1,
		"descriptions": {1: "혼딸기 강신 60초, 기력 500, 초식 커맨드 A→D→A→D→A→D"},
		"detail": "기력 500을 소모해 2초 안에 초식 커맨드 A→D→A→D→A→D를 입력하면 스테이지당 1회, 60초간 혼딸기 신령을 몸에 내립니다.",
		"icon_color": Color(1.0, 72.0 / 255.0, 90.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "horn_strawberry_mask",
	},
	"odins_eye": {
		"name": "윤회천안",
		"max_level": 1,
		"descriptions": {1: "실점 무효·악귀 부활 35%, 활주 거리 +50%"},
		"detail": "실점 시 일정 확률로 그 실점을 무효화하고 악귀로 되살아납니다. 악귀 상태에서는 이동속도 -50%, 활주 1회, 재충전 시간 +100%가 적용되지만 활주 거리는 50% 늘어나며, 다시 실점하면 패배합니다.",
		"icon_color": Color(110.0 / 255.0, 100.0 / 255.0, 220.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "odins_eye",
	},
	"celestial_armor": {
		"name": "부동금강체",
		"max_level": 1,
		"descriptions": {1: "스턴·넉백 무시 65%, 기력 30 소모"},
		"detail": "스턴·넉백이 들어올 때 확률로 기력을 소모해 무시합니다.",
		"icon_color": Color(180.0 / 255.0, 200.0 / 255.0, 1.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "celestial_armor",
	},
	"baal_boots": {
		"name": "풍우식기결",
		"max_level": 1,
		"descriptions": {1: "날씨 흡수 시 기력 400 회복"},
		"detail": "날씨의 기운을 삼켜 기력을 회복하고 그 힘을 이번 라운드에 되돌립니다.",
		"icon_color": Color(1.0, 90.0 / 255.0, 55.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "baal_boots",
	},
	"pandora_legacy": {
		"name": "금기개함",
		"max_level": 1,
		"descriptions": {1: "라운드 승리 시 발동 55%"},
		"detail": "라운드 승리 보상에서 금기의 함을 열 선택 기회를 노립니다.",
		"icon_color": Color(150.0 / 255.0, 50.0 / 255.0, 200.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "pandora_legacy",
	},
	"angel_blessing": {
		"name": "천운삼괘",
		"max_level": 1,
		"descriptions": {1: "스테이지마다 서로 다른 천운 1~3개 획득 (효과 30%)"},
		"detail": "괘상에 따라 몸집 크기·최대 기력·이동 속도 증가 또는 액티브 아이템·초식·활주 재충전 시간 감소 천운을 얻습니다.",
		"icon_color": Color(1.0, 235.0 / 255.0, 150.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "angel_blessing",
	},
	"yangui_hoechun": {
		"name": "양의회천",
		"max_level": 1,
		"descriptions": {1: "초식 발동 시 50%, 기력 30 소모"},
		"detail": "초식 발동 시 기력이 30 이상이면 50% 확률로 기력 30을 소모해 좌우로 황금빛 기파를 펼칩니다. 기파에 닿은 하강 공은 위로 반사됩니다.",
		"icon_color": Color(1.0, 225.0 / 255.0, 72.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "yangui_hoechun",
	},
}

# Exact-grant catalog for perks that must never enter any general offer surface.
# Keep this dictionary out of get_all_perk_data(), converted mythic candidates,
# debug pools, shops, field rewards, and fusion enumeration. The campfire banana
# cooking transaction resolves banana_master only through get_perk_data().
const ACQUISITION_ONLY_PERKS := {
	"banana_master": {
		"name": "바나나의달인",
		"max_level": 1,
		"descriptions": {1: "바나나를 던질때 바나나가 2개 발사됩니다"},
		"detail": "바나나를 던질때 바나나가 2개 발사됩니다",
		"icon_color": Color(1.0, 220.0 / 255.0, 60.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"acquisition_only": true,
		"acquisition_source": "tower_campfire_banana_cooking",
	},
}

const INSTANT_PERKS := {
	"instant_gauge_full": {
		"name": "풀게이징",
		"description": "기력·활주·쿨타임 즉시 완충",
		"detail": "기력과 활주 횟수를 즉시 채우고 초식 쿨타임을 초기화합니다.",
		"icon_color": Color(100.0 / 255.0, 1.0, 200.0 / 255.0),
		"tree": "instant",
		"is_instant": true,
	},
	"instant_dimension_gate": {
		"name": "백보초래",
		"description": "도깨비 보따리의 귀문을 즉시 개방",
		"detail": "3초 동안 중앙 귀문에서 액티브 아이템이 0.5~1초 간격으로 쏟아집니다.",
		"icon_color": Color(0.66, 0.34, 0.72),
		"tree": "instant",
		"is_instant": true,
	},
	"instant_monkey_blessing": {
		"name": "원숭이은혜",
		"description": "빈 액티브 슬롯을 보급품으로 채움",
		"detail": "현재 Godot 포트에서는 선택 피드백을 먼저 제공하며, 바나나 아이템 포트 뒤 슬롯 보급을 연결합니다.",
		"icon_color": Color(1.0, 220.0 / 255.0, 50.0 / 255.0),
		"tree": "instant",
		"is_instant": true,
	},
	"common_refresh": {
		"name": "새로고침",
		"description": "무공 선택창을 한 번 더 새로고침",
		"detail": "현재 선택지가 마음에 들지 않을 때 한 번 더 선택지를 받습니다.",
		"icon_color": Color(150.0 / 255.0, 220.0 / 255.0, 1.0),
		"tree": "instant",
		"is_instant": true,
	},
}

# 승리 전리품 페이즈(보스 격파 후 상자 드랍) 오퍼에서 빼는 즉시형 보상 퍽.
# 이 시점에는 매치가 이미 끝나 공/랠리가 없으므로 인게임 즉발 효과를 쓸 곳이
# 없다 — 아이템 스폰 강화(백보초래), 기력·활주·쿨 완충(풀게이징), 빈 액티브
# 슬롯 보급(원숭이은혜)이 전부 사장된 카드로 상자 보상 한 장을 소모한다.
# `common_refresh`(새로고침)는 선택지 재굴림 유틸이라 상자 오퍼에서도 유효하므로
# 의도적으로 남긴다 — INSTANT_PERKS 전체 제외(`exclude_instant`)와는 다른 계약.
const VICTORY_LOOT_EXCLUDED_INSTANT_IDS := {
	"instant_gauge_full": true,
	"instant_dimension_gate": true,
	"instant_monkey_blessing": true,
}

const GOLD_CHOICE := {
	"id": "convert_to_gold",
	"name": "골드변환",
	"description": "무혼으로 무공을 획득하는 대신 골드로 변환합니다",
	"detail": "무공을 포기하고 즉시 500골드를 인게임 골드로 획득합니다.",
	"icon_color": Color(1.0, 215.0 / 255.0, 0.0),
	"tree": "instant",
	"character_restriction": "",
	"is_instant": true,
	"is_gold_conversion": true,
	# 일반 오퍼에서는 은퇴했지만 레거시 저장·디버그 주입·표시 경로가 이
	# payload를 계속 해석한다. lane 메타도 그 호환 범위에서만 보존한다.
	"offer_lane": "gold",
	"offer_protected": true,
	"gold_amount": 500,
	"current_level": 0,
	"next_level": 0,
	"max_level": 0,
}

const UNLOCK_SLOT_BUDGET := {
	"smasher": 3,
	"viper": 2,
	"soldier": 3,
}


var mythic_jackpot_offer_chance := 0.05
# 오퍼 예약 seam(스모크가 결정론 주입): 대쉬토큰 per-level 부스트 확률
# [Lv0, Lv1, Lv2] — 페이싱 부스트 튜닝 값(docs/perk_offer_pacing_boost_handoff.md),
# 소유 업그레이드 partial 예약 확률.
var dash_token_boost_chances: Array = [0.25, 0.10, 0.05]
var owned_upgrade_partial_chance := 0.5
var _full_chosik_swap_offer_roll_for_tests: Callable = Callable()
var _open_chosik_offer_roll_for_tests: Callable = Callable()
var _reserved_boss_vision_offer_id := ""
var _character_context: Object = RuntimePerkCharacterContext.new()


func _try_build_mythic_jackpot_offer(
	regular_pool: Array,
	runtime_levels: Dictionary,
	character_type: String,
	exclude_instant: bool,
	target_choice_count: int,
	owner: Object,
	registry: Object
) -> Array:
	if not PerkConversionFlags.is_enabled() or target_choice_count <= 0:
		return []
	if not has_open_perk_slot(runtime_levels, registry):
		return []
	var mythic_offer_chances := _get_mythic_offer_chances(runtime_levels)
	var jackpot_chance := float(mythic_offer_chances.get("jackpot", 0.0))
	if randf() >= jackpot_chance:
		return []

	var mythic_reserved := _build_unowned_mythic_choices(
		runtime_levels,
		character_type,
		target_choice_count
	)
	if mythic_reserved.is_empty():
		return []

	var result: Array = []
	for mythic_choice in mythic_reserved:
		if result.size() >= target_choice_count:
			break
		result.append(_with_offer_metadata(mythic_choice, "mythic_jackpot", true))
	if result.size() >= target_choice_count:
		return result

	# A jackpot is a dedicated screen. Only ordinary Mugong may fill a genuine
	# mythic-candidate shortage; Chosik and other protected reservations are not
	# evaluated or consumed on this path.
	var regular_fill: Array = []
	for value in regular_pool:
		if not (value is Dictionary):
			continue
		var choice: Dictionary = value as Dictionary
		if bool(choice.get(BOSS_VISION_PRIORITY_KEY, false)):
			continue
		if str(choice.get("unlocks_skill", "")).strip_edges() != "":
			continue
		regular_fill.append(choice)
	regular_fill = _filter_perk_slot_budget(regular_fill, runtime_levels, registry)
	regular_fill = _filter_lingpet_owned_gate(regular_fill, owner)
	regular_fill.shuffle()
	for regular_choice in regular_fill:
		if result.size() >= target_choice_count:
			break
		var regular_id := str((regular_choice as Dictionary).get("id", ""))
		if not _has_choice_id(result, regular_id):
			result.append(_with_offer_metadata(regular_choice, "replaceable", false))

	if not exclude_instant and result.size() < target_choice_count:
		var instant_fill: Array = []
		_append_instant_choices(instant_fill, owner)
		instant_fill = _filter_lingpet_owned_gate(instant_fill, owner)
		instant_fill.shuffle()
		for instant_choice in instant_fill:
			if result.size() >= target_choice_count:
				break
			if not _has_choice_id(result, str(instant_choice.get("id", ""))):
				result.append(instant_choice)
	return result


func get_choices(
	character_type: String,
	runtime_levels: Dictionary,
	exclude_instant: bool = false,
	base_choice_count: int = BASE_CHOICE_COUNT,
	owner: Object = null,
	_registry: Object = null
) -> Array:
	var target_choice_count: int = max(0, int(base_choice_count))
	var choices: Array = []
	_append_pool_choices(choices, COMMON_PERKS, runtime_levels, "")
	_append_soul_summon_choice(choices, runtime_levels)
	_append_reserved_boss_vision_choice(choices, runtime_levels)

	var normalized: String = _normalize_character(character_type)
	if normalized == "smasher":
		_append_pool_choices(choices, SMASHER_PERKS, runtime_levels, "smasher")
	elif normalized == "viper":
		_append_pool_choices(choices, VIPER_PERKS, runtime_levels, "viper")
	elif normalized == "soldier":
		_append_pool_choices(choices, SOLDIER_PERKS, runtime_levels, "soldier")
	choices = _filter_tower_unlock_choices(choices, _registry)

	if PerkConversionFlags.is_enabled():
		_append_converted_perk_choices(choices, runtime_levels, normalized)

	choices = _filter_unlock_slot_budget(choices, normalized, runtime_levels, _registry)
	if PerkConversionFlags.is_enabled():
		choices = _filter_perk_slot_budget(choices, runtime_levels, _registry)
	_append_lingpet_guardian_enhance_choice(choices, owner, _registry)
	if not exclude_instant:
		_append_instant_choices(choices, owner)
	choices = _filter_tower_unlock_choices(choices, _registry)

	choices = _filter_lingpet_owned_gate(choices, owner)
	var boss_vision_reservation := _extract_boss_vision_reserved_choice(choices)
	var boss_vision_reserved: Array = boss_vision_reservation.get("reserved", []) as Array
	choices = boss_vision_reservation.get("remaining", []) as Array
	var full_chosik_swap_reservation := _extract_full_chosik_swap_reserved_choice(choices)
	var full_chosik_swap_reserved: Array = full_chosik_swap_reservation.get("reserved", []) as Array
	choices = full_chosik_swap_reservation.get("remaining", []) as Array
	var guardian_enhance_reservation := _extract_guardian_enhance_reserved_choice(choices)
	var guardian_enhance_reserved: Array = guardian_enhance_reservation.get("reserved", []) as Array
	choices = guardian_enhance_reservation.get("remaining", []) as Array
	# 절세무공 당첨은 위 전용 분기에서 즉시 반환한다. 일반 예약 체인은
	# boss vision -> guardian enhance -> full Chosik swap -> dash token ->
	# owned upgrades -> shuffled 순서다. 대쉬토큰은
	# 전용 per-level 부스트 lane(소유 후
	# generic 예약과 이중 등장 금지), 소유 업그레이드는 만석=target-1(마지막
	# 일반 lane 1개는 교체형 오퍼(합일/수련) 진입로로 항상 남김) /
	# 빈슬롯=partial 확률 1장.
	# 융합 슬롯 환급이 슬롯을 열면 만석 예약은
	# 자연 비활성화된다(has_open_perk_slot 공유 판정).
	var dash_token_reserved: Array = []
	if PerkConversionFlags.is_enabled():
		var dash_level: int = int(runtime_levels.get("dash_amplification", 0))
		if dash_level >= 0 and dash_level < dash_token_boost_chances.size():
			var dash_chance := clampf(float(dash_token_boost_chances[dash_level]), 0.0, 1.0)
			if randf() < dash_chance:
				dash_token_reserved = _extract_choice_by_id(choices, "dash_amplification")
	var owned_upgrade_reserved: Array = []
	if PerkConversionFlags.is_enabled():
		var owned_reserve_limit := 0
		if not has_open_perk_slot(runtime_levels, _registry):
			owned_reserve_limit = maxi(0, target_choice_count - 1)
		elif randf() < clampf(float(owned_upgrade_partial_chance), 0.0, 1.0):
			owned_reserve_limit = 1
		if owned_reserve_limit > 0:
			var owned_upgrade_reservation: Dictionary = _extract_owned_slot_upgrade_reserved_choices(
				choices,
				runtime_levels,
				owned_reserve_limit
			)
			owned_upgrade_reserved = owned_upgrade_reservation.get("reserved", []) as Array
			choices = owned_upgrade_reservation.get("remaining", []) as Array
	choices.shuffle()
	var result: Array = []
	for vision_choice in boss_vision_reserved:
		if result.size() >= target_choice_count:
			break
		result.append(_with_offer_metadata(vision_choice, "boss_vision_reserved", true))
	for guardian_choice in guardian_enhance_reserved:
		if result.size() >= target_choice_count:
			break
		result.append(_with_offer_metadata(guardian_choice, "guardian_enhance_reserved", true))
	for swap_choice in full_chosik_swap_reserved:
		if result.size() >= target_choice_count:
			break
		result.append(_with_offer_metadata(swap_choice, "full_chosik_swap_reserved", true))
	for dash_token_choice in dash_token_reserved:
		if result.size() >= target_choice_count:
			break
		result.append(dash_token_choice)
	for owned_upgrade_choice in owned_upgrade_reserved:
		if result.size() >= target_choice_count:
			break
		result.append(_with_offer_metadata(
			owned_upgrade_choice,
			"owned_upgrade_reserved",
			true
		))
	for choice in choices:
		if result.size() >= target_choice_count:
			break
		# 일반 lane 명시 스탬프: 교체형 오퍼는 명시된 replaceable lane만
		# 교체할 수 있다(미표기=보호, fail-closed).
		result.append(_with_offer_metadata(choice, "replaceable", false))

	if not exclude_instant and result.size() < target_choice_count:
		var filler: Array = []
		_append_instant_choices(filler, owner)
		filler = _filter_tower_unlock_choices(filler, _registry)
		filler = _filter_lingpet_owned_gate(filler, owner)
		filler.shuffle()
		for instant_choice in filler:
			if result.size() >= target_choice_count:
				break
			if not _has_choice_id(result, str(instant_choice.get("id", ""))):
				result.append(instant_choice)

	result = _filter_tower_unlock_choices(result, _registry)
	return result


func _filter_tower_unlock_choices(choices: Array, registry: Object) -> Array:
	var filtered: Array = []
	for choice_value in choices:
		if not (choice_value is Dictionary):
			continue
		var choice := choice_value as Dictionary
		if TowerAscentUnlockFilter.is_content_unlocked(
			registry,
			TowerAscentUnlockFilter.CONTENT_RUNTIME_PERK,
			str(choice.get("id", ""))
		):
			filtered.append(choice)
	return filtered


func get_all_perk_data() -> Dictionary:
	var data: Dictionary = {}
	data.merge(COMMON_PERKS, true)
	data[CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID] = CommonSkillCatalog.get_unlock_perk_data()
	data[CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID] = CommonSkillCatalog.get_unlock_perk_data(
		CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID
	)
	data[CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_UNLOCK_ID] = CommonSkillCatalog.get_unlock_perk_data(
		CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_UNLOCK_ID
	)
	data[CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_UNLOCK_ID] = CommonSkillCatalog.get_unlock_perk_data(
		CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_UNLOCK_ID
	)
	data[CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_UNLOCK_ID] = CommonSkillCatalog.get_unlock_perk_data(
		CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_UNLOCK_ID
	)
	data[LINGPET_GUARDIAN_ENHANCE_CHOICE_ID] = LingpetGuardianEnhanceOfferEngine.get_perk_data()
	data.merge(SMASHER_PERKS, true)
	data.merge(VIPER_PERKS, true)
	data.merge(SOLDIER_PERKS, true)
	data.merge(CONVERTED_PERKS, true)
	data.merge(CONVERTED_MYTHIC_PERKS, true)
	# bulk 소비자(디버그 목록 등)도 조회/오퍼와 같은 flag-OFF 레거시
	# 정의를 봐야 한다 — pool 원본을 그대로 합치면 여기서 다시 갈라진다.
	if data.has(SLOT_EXPANSION_PERK_ID):
		data[SLOT_EXPANSION_PERK_ID] = _resolve_expansion_definition(SLOT_EXPANSION_PERK_ID, data[SLOT_EXPANSION_PERK_ID])
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_KOREAN:
		return data
	var localized: Dictionary = {}
	for skill_id in data.keys():
		var perk_data: Dictionary = data[skill_id].duplicate(true)
		perk_data["id"] = str(skill_id)
		localized[skill_id] = LanguageSettings.localize_perk_data(perk_data)
	return localized


func get_perk_data(skill_id: String) -> Dictionary:
	if CommonSkillCatalog.is_common_unlock(skill_id):
		var common_unlock := CommonSkillCatalog.get_unlock_perk_data(skill_id)
		common_unlock["id"] = skill_id
		return common_unlock
	if ACQUISITION_ONLY_PERKS.has(skill_id):
		var acquisition_only: Dictionary = ACQUISITION_ONLY_PERKS[skill_id]
		var acquisition_result := acquisition_only.duplicate(true)
		acquisition_result["id"] = skill_id
		return LanguageSettings.localize_perk_data(acquisition_result)
	var all_data: Dictionary = get_all_perk_data()
	if all_data.has(skill_id):
		var data: Dictionary = all_data[skill_id]
		var result := data.duplicate(true)
		result["id"] = skill_id
		result = _resolve_expansion_definition(skill_id, result)
		return LanguageSettings.localize_perk_data(result)
	if INSTANT_PERKS.has(skill_id):
		var instant_data: Dictionary = INSTANT_PERKS[skill_id]
		var instant_result := instant_data.duplicate(true)
		instant_result["id"] = skill_id
		return LanguageSettings.localize_perk_data(instant_result)
	if skill_id == "convert_to_gold":
		var gold_choice := GOLD_CHOICE.duplicate(true)
		gold_choice["id"] = "convert_to_gold"
		return LanguageSettings.localize_perk_data(gold_choice)
	if skill_id == "mystic_dice":
		# Legacy save/test compatibility only. Production offers and the debug perk
		# list no longer expose this card; acquisition belongs to the active item.
		return load("res://scripts/characters/mystic_dice_offer_planner.gd").build_card()
	if skill_id.begins_with("physique_"):
		return PhysiqueTrainingCatalog.new().build_card(skill_id, 0)
	if skill_id == LINGPET_GUARDIAN_ENHANCE_CHOICE_ID:
		var guardian_choice := LingpetGuardianEnhanceOfferEngine.get_perk_data()
		guardian_choice["id"] = LINGPET_GUARDIAN_ENHANCE_CHOICE_ID
		return guardian_choice
	return {}


# 표시명 전용 O(1) 인덱스 (능력치 툴팁 증감 내역 등). get_perk_data의
# deep-copy + 전체 로컬라이즈 비용을 피하고, pool 상수만 참조해 이 함수
# 단독으로도 파싱/동작한다 (다른 헬퍼 인덱스와의 통합은 후속 정리 후보).
static var _perk_display_name_index: Dictionary = {}


static func get_perk_display_name(skill_id: String) -> String:
	if skill_id.begins_with("physique_"):
		var training_value: Variant = PhysiqueTrainingCatalog.DATA.get(skill_id, {})
		if training_value is Dictionary:
			return LanguageSettings.localize_perk_name(skill_id, str((training_value as Dictionary).get("name", "")))
		return ""
	if _perk_display_name_index.is_empty():
		for pool_value: Variant in [
			COMMON_PERKS,
			SMASHER_PERKS,
			VIPER_PERKS,
			SOLDIER_PERKS,
			CONVERTED_PERKS,
			CONVERTED_MYTHIC_PERKS,
			ACQUISITION_ONLY_PERKS,
		]:
			if not pool_value is Dictionary:
				continue
			var pool := pool_value as Dictionary
			for perk_id_value: Variant in pool.keys():
				var entry_value: Variant = pool.get(perk_id_value)
				if entry_value is Dictionary:
					_perk_display_name_index[str(perk_id_value)] = str((entry_value as Dictionary).get("name", ""))
	var korean_name: String = str(_perk_display_name_index.get(skill_id, ""))
	if korean_name == "":
		return ""
	return LanguageSettings.localize_perk_name(skill_id, korean_name)


# flag OFF에서 슬롯 확장 퍽은 레거시 장신구 의미로 노출한다 — 새 정의
# (max_level 4·퍽 슬롯 문구)를 그대로 내보내면 OFF 실효(장신구 2칸)와
# 모순되는 무효 레벨 3~4가 노출된다. get_perk_data(조회)와 오퍼 후보 생성
# (_append_pool_choices)이 같은 헬퍼를 지나야 한다 — 조회만 고치면 실제
# 오퍼가 pool 원본(새 정의)을 직접 읽어 계약을 우회한다.
static func _resolve_expansion_definition(skill_id: String, skill_data: Dictionary) -> Dictionary:
	if skill_id != SLOT_EXPANSION_PERK_ID or PerkConversionFlags.is_enabled():
		return skill_data
	var legacy: Dictionary = skill_data.duplicate(true)
	legacy["name"] = "확장"
	legacy["max_level"] = 2
	legacy["descriptions"] = {1: "장신구 슬롯 +1", 2: "장신구 슬롯 +2"}
	legacy["detail"] = "장신구 슬롯을 추가로 활성화합니다."
	return legacy


static func is_slot_consuming_perk(perk_data: Dictionary) -> bool:
	if perk_data.is_empty():
		return false
	var perk_id: String = str(perk_data.get("id", "")).strip_edges()
	if perk_id == "convert_to_gold" or bool(perk_data.get("is_gold_conversion", false)):
		return false
	# Retired Mystic Dice card IDs can survive in old snapshots. Treat them as
	# slot-free compatibility data; new runs acquire the active item instead.
	if perk_id == "mystic_dice" or bool(perk_data.get("is_mystic_dice", false)):
		return false
	if bool(perk_data.get("is_physique_training", false)):
		return false
	if bool(perk_data.get("is_instant", false)) or str(perk_data.get("tree", "")) == "instant":
		return false
	if str(perk_data.get("unlocks_skill", "")).strip_edges() != "":
		return false
	if bool(LINGPET_GATED_CHOICE_IDS.get(perk_id, false)):
		return false
	return int(perk_data.get("max_level", 0)) > 0


static func get_tower_upgrade_read_only_reason(perk_data: Dictionary) -> String:
	if perk_data.is_empty():
		return ""
	var rank_tag := str(perk_data.get("rank_tag", "")).strip_edges().to_lower()
	if (
		rank_tag == "unique"
		or bool(perk_data.get("count_type", false))
		or bool(perk_data.get("is_count_type", false))
	):
		return TOWER_UPGRADE_READ_ONLY_REASON_COUNT_TYPE
	return ""


static func get_slot_cost_for_level(perk_data: Dictionary, level: int) -> int:
	if not is_slot_consuming_perk(perk_data):
		return 0
	var normalized_level: int = max(0, int(level))
	if str(perk_data.get("id", "")) == "dash_amplification":
		var max_level: int = int(perk_data.get("max_level", normalized_level))
		if max_level > 0:
			normalized_level = mini(normalized_level, max_level)
		return normalized_level
	return 1 if normalized_level > 0 else 0


func count_owned_slot_perks(runtime_levels: Dictionary, slot_context: Object = null) -> int:
	var count := 0
	for skill_id_value in runtime_levels.keys():
		var skill_id: String = str(skill_id_value)
		var level: int = int(runtime_levels.get(skill_id_value, 0))
		if level <= 0:
			continue
		var data: Dictionary = get_perk_data(skill_id)
		if data.is_empty():
			continue
		data["id"] = skill_id
		count += get_slot_cost_for_level(data, level)
	# 퍽 융합 슬롯 환급: record 1건=슬롯 1 환급 — 오퍼 필터/신화 지급/양쪽
	# UI가 전부 이 함수를 통해 같은 환급값을 봐야 한다(소비자별 자체 계산
	# 금지). slot_context는 registry(get_instance) 또는 runtime_perk_state
	# 자체를 받는다.
	count = maxi(0, count - _resolve_perk_fusion_slot_reduction(slot_context))
	return count


# slot_context에서 융합 슬롯 환급을 해석한다: registry면 runtime_perk_state
# 인스턴스를 꺼내고, state 자체면 그대로 위임 조회.
func _resolve_perk_fusion_slot_reduction(slot_context: Object) -> int:
	if slot_context == null:
		return 0
	var runtime_state: Object = slot_context
	if slot_context.has_method("get_instance"):
		runtime_state = slot_context.get_instance("runtime_perk_state")
	if runtime_state == null or not runtime_state.has_method("get_perk_fusion_slot_reduction"):
		return 0
	return maxi(0, int(runtime_state.get_perk_fusion_slot_reduction()))


func _resolve_perk_fusion_slot_limit_bonus(slot_context: Object) -> int:
	if slot_context == null:
		return 0
	var runtime_state: Object = slot_context
	if slot_context.has_method("get_instance"):
		runtime_state = slot_context.get_instance("runtime_perk_state")
	if runtime_state == null or not runtime_state.has_method("get_perk_fusion_owned_byproduct_ids"):
		return 0
	var owned_value: Variant = runtime_state.get_perk_fusion_owned_byproduct_ids()
	if not owned_value is Array:
		return 0
	for byproduct_id_value: Variant in owned_value as Array:
		if str(byproduct_id_value) == FUSION_SLOT_EXPANSION_BYPRODUCT_ID:
			return 1
	return 0


func has_open_perk_slot(runtime_levels: Dictionary, slot_context: Object = null) -> bool:
	return count_owned_slot_perks(runtime_levels, slot_context) < get_perk_slot_limit(runtime_levels, slot_context)


func get_perk_slot_limit(_runtime_levels: Dictionary, slot_context: Object = null) -> int:
	# flag OFF에서는 고정 6(UI가 flag와 무관하게 조회하므로 여기서 중앙
	# 격리). ON에서는 합일 부산물 보유 상태만 한도에 반영한다.
	if not PerkConversionFlags.is_enabled():
		return BASE_PERK_SLOT_LIMIT
	var bonus: int = _resolve_perk_fusion_slot_limit_bonus(slot_context)
	return clampi(BASE_PERK_SLOT_LIMIT + bonus, BASE_PERK_SLOT_LIMIT, MAX_PERK_SLOT_LIMIT)


func get_perk_slot_status(runtime_levels: Dictionary, slot_context: Object = null) -> Dictionary:
	var count := count_owned_slot_perks(runtime_levels, slot_context)
	var limit := get_perk_slot_limit(runtime_levels, slot_context)
	return {
		"count": count,
		"limit": limit,
		"is_full": count >= limit,
	}


func get_perk_slot_apply_status(
	perk_data: Dictionary,
	runtime_levels: Dictionary,
	slot_context: Object = null,
	target_level: int = -1
) -> Dictionary:
	var resolved_data := _resolve_slot_perk_data(perk_data)
	var perk_id := str(resolved_data.get("id", "")).strip_edges()
	var current_level := int(runtime_levels.get(perk_id, 0))
	var next_level := target_level
	if next_level < 0:
		next_level = current_level + 1
		var max_level := int(resolved_data.get("max_level", -1))
		if max_level > 0:
			next_level = mini(next_level, max_level)
	var current_cost := get_slot_cost_for_level(resolved_data, current_level)
	var next_cost := get_slot_cost_for_level(resolved_data, next_level)
	var extra_slots := maxi(0, next_cost - current_cost)
	var occupied_slots := count_owned_slot_perks(runtime_levels, slot_context)
	var slot_limit := get_perk_slot_limit(runtime_levels, slot_context)
	var accepted := extra_slots == 0 or occupied_slots + extra_slots <= slot_limit
	return {
		"accepted": accepted,
		"blocked_reason": "" if accepted else PERK_SLOT_LIMIT_BLOCKED_REASON,
		"perk_id": perk_id,
		"current_level": current_level,
		"next_level": next_level,
		"current_cost": current_cost,
		"next_cost": next_cost,
		"extra_slots": extra_slots,
		"occupied_slots": occupied_slots,
		"slot_limit": slot_limit,
		"remaining_slots": maxi(0, slot_limit - occupied_slots),
	}


func _resolve_slot_perk_data(perk_data: Dictionary) -> Dictionary:
	var resolved := perk_data.duplicate(true)
	var perk_id := str(resolved.get("id", resolved.get("perk_id", ""))).strip_edges()
	if perk_id.is_empty():
		return resolved
	var canonical := get_perk_data(perk_id)
	if not canonical.is_empty():
		# Slot classification and costs are an apply-side authority boundary.
		# Never let caller-authored display/offer metadata weaken canonical flags
		# or max levels (for example, forged max_level=0 / is_instant=true).
		resolved = canonical.duplicate(true)
	resolved["id"] = perk_id
	return resolved


func get_debug_perk_entries(_character_type: String = "") -> Array:
	var entries: Array = []
	_append_debug_pool_entries(entries, COMMON_PERKS, "common")
	var soul_summon_entry: Dictionary = CommonSkillCatalog.get_unlock_perk_data()
	soul_summon_entry["id"] = CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID
	soul_summon_entry["debug_group"] = "common"
	entries.append(soul_summon_entry)
	var dalji_vision_entry: Dictionary = CommonSkillCatalog.get_unlock_perk_data(
		CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID
	)
	dalji_vision_entry["id"] = CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_UNLOCK_ID
	dalji_vision_entry["debug_group"] = "vision"
	entries.append(dalji_vision_entry)
	var gaksital_vision_entry: Dictionary = CommonSkillCatalog.get_unlock_perk_data(
		CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_UNLOCK_ID
	)
	gaksital_vision_entry["id"] = CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_UNLOCK_ID
	gaksital_vision_entry["debug_group"] = "vision"
	entries.append(gaksital_vision_entry)
	var cheongringwi_vision_entry: Dictionary = CommonSkillCatalog.get_unlock_perk_data(
		CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_UNLOCK_ID
	)
	cheongringwi_vision_entry["id"] = CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_UNLOCK_ID
	cheongringwi_vision_entry["debug_group"] = "vision"
	entries.append(cheongringwi_vision_entry)
	var yeonmyo_vision_entry: Dictionary = CommonSkillCatalog.get_unlock_perk_data(
		CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_UNLOCK_ID
	)
	yeonmyo_vision_entry["id"] = CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_UNLOCK_ID
	yeonmyo_vision_entry["debug_group"] = "vision"
	entries.append(yeonmyo_vision_entry)
	_append_debug_pool_entries(entries, SMASHER_PERKS, "smasher")
	_append_debug_pool_entries(entries, VIPER_PERKS, "viper")
	_append_debug_pool_entries(entries, SOLDIER_PERKS, "soldier")
	_append_debug_pool_entries(entries, CONVERTED_PERKS, "converted")
	_append_debug_pool_entries(entries, CONVERTED_MYTHIC_PERKS, "converted_mythic")
	_append_debug_pool_entries(entries, INSTANT_PERKS, "instant")
	var gold_choice: Dictionary = GOLD_CHOICE.duplicate(true)
	gold_choice["id"] = "convert_to_gold"
	gold_choice["debug_group"] = "instant"
	entries.append(LanguageSettings.localize_perk_data(gold_choice))
	# 신비의 주사위는 퍽 목록에서 은퇴했으며 F2 액티브 아이템 메뉴로 검증한다.
	if PerkConversionFlags.is_enabled():
		var training_catalog := PhysiqueTrainingCatalog.new()
		for training_id: String in PhysiqueTrainingCatalog.TRAINING_IDS:
			var training_choice: Dictionary = training_catalog.build_card(training_id, 0)
			training_choice["debug_group"] = "training"
			entries.append(training_choice)
	var guardian_enhance_choice := LingpetGuardianEnhanceOfferEngine.get_perk_data()
	guardian_enhance_choice["id"] = LINGPET_GUARDIAN_ENHANCE_CHOICE_ID
	guardian_enhance_choice["debug_group"] = "lingpet"
	entries.append(guardian_enhance_choice)
	entries.sort_custom(func(a, b): return _debug_sort_key(a) < _debug_sort_key(b))
	return entries


func get_legacy_training_compat_debug_entries() -> Array:
	var entries: Array = []
	for perk_id_value: Variant in TRAINING_MIGRATED_PERK_IDS.keys():
		var perk_id := str(perk_id_value)
		var data := get_perk_data(perk_id)
		if data.is_empty():
			continue
		data["debug_group"] = "legacy_training_compat"
		data["legacy_injection_only"] = true
		entries.append(data)
	entries.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return entries


func _append_pool_choices(output: Array, pool: Dictionary, runtime_levels: Dictionary, character_restriction: String) -> void:
	for skill_id in pool.keys():
		if not PerkConversionFlags.is_enabled() and TRAINING_DEPENDENT_PERK_IDS.has(str(skill_id)):
			continue
		if PerkConversionFlags.is_enabled() and str(skill_id) == SLOT_EXPANSION_PERK_ID:
			continue
		if PerkConversionFlags.is_enabled() and TRAINING_MIGRATED_PERK_IDS.has(str(skill_id)):
			continue
		var skill_data: Dictionary = _resolve_expansion_definition(str(skill_id), pool[skill_id])
		var max_level: int = int(skill_data.get("max_level", 1))
		var current_level: int = int(runtime_levels.get(skill_id, 0))
		if max_level >= 0 and current_level >= max_level:
			continue
		var next_level: int = current_level + 1
		var choice: Dictionary = _build_level_choice(skill_id, skill_data, current_level, next_level, character_restriction)
		output.append(LanguageSettings.localize_perk_data(choice))


func _append_soul_summon_choice(
	output: Array,
	runtime_levels: Dictionary
) -> void:
	if int(runtime_levels.get(CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID, 0)) > 0:
		return
	if int(runtime_levels.get(CommonSkillCatalog.SOUL_SUMMON_ART_ID, 0)) > 0:
		return
	var choice: Dictionary = _build_level_choice(
		CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID,
		CommonSkillCatalog.get_unlock_perk_data(),
		0,
		1,
		""
	)
	output.append(choice)


func reserve_boss_vision_offer(perk_id: String) -> bool:
	if not CommonSkillCatalog.is_vision_unlock_id(perk_id):
		return false
	_reserved_boss_vision_offer_id = perk_id
	return true


func has_reserved_boss_vision_offer() -> bool:
	return _reserved_boss_vision_offer_id != ""


func _append_reserved_boss_vision_choice(output: Array, runtime_levels: Dictionary) -> void:
	var perk_id := _reserved_boss_vision_offer_id
	if perk_id == "":
		return
	var skill_id := CommonSkillCatalog.get_skill_id_for_unlock(perk_id)
	if skill_id == "":
		_reserved_boss_vision_offer_id = ""
		return
	if int(runtime_levels.get(perk_id, 0)) > 0 or int(runtime_levels.get(skill_id, 0)) > 0:
		_reserved_boss_vision_offer_id = ""
		return
	var choice := _build_level_choice(
		perk_id,
		CommonSkillCatalog.get_unlock_perk_data(perk_id),
		0,
		1,
		""
	)
	choice[BOSS_VISION_PRIORITY_KEY] = true
	output.append(choice)


func _extract_boss_vision_reserved_choice(choices: Array) -> Dictionary:
	var reserved: Array = []
	var remaining: Array = []
	for value in choices:
		if value is Dictionary:
			var choice: Dictionary = value as Dictionary
			if bool(choice.get(BOSS_VISION_PRIORITY_KEY, false)):
				var reserved_choice := choice.duplicate(true)
				reserved_choice.erase(BOSS_VISION_PRIORITY_KEY)
				reserved.append(reserved_choice)
				continue
		remaining.append(value)
	if not reserved.is_empty():
		_reserved_boss_vision_offer_id = ""
	return {"reserved": reserved, "remaining": remaining}


func _extract_guardian_enhance_reserved_choice(choices: Array) -> Dictionary:
	var reserved: Array = []
	var remaining: Array = []
	for value in choices:
		if value is Dictionary:
			var choice := value as Dictionary
			if bool(choice.get(GUARDIAN_ENHANCE_PRIORITY_KEY, false)):
				var reserved_choice := choice.duplicate(true)
				reserved_choice.erase(GUARDIAN_ENHANCE_PRIORITY_KEY)
				reserved.append(reserved_choice)
				continue
			if choice.has(GUARDIAN_ENHANCE_PRIORITY_KEY):
				var regular_choice := choice.duplicate(true)
				regular_choice.erase(GUARDIAN_ENHANCE_PRIORITY_KEY)
				remaining.append(regular_choice)
				continue
		remaining.append(value)
	return {
		"reserved": reserved,
		"remaining": remaining,
	}


func _extract_full_chosik_swap_reserved_choice(choices: Array) -> Dictionary:
	var reserved: Array = []
	var remaining: Array = []
	for value in choices:
		if value is Dictionary:
			var choice: Dictionary = value as Dictionary
			if bool(choice.get(FULL_CHOSIK_SWAP_PRIORITY_KEY, false)):
				var reserved_choice := choice.duplicate(true)
				reserved_choice.erase(FULL_CHOSIK_SWAP_PRIORITY_KEY)
				reserved.append(reserved_choice)
				continue
		remaining.append(value)
	return {
		"reserved": reserved,
		"remaining": remaining,
	}


func _append_converted_perk_choices(output: Array, runtime_levels: Dictionary, character_type: String) -> void:
	for skill_id in CONVERTED_PERKS.keys():
		if TRAINING_MIGRATED_PERK_IDS.has(str(skill_id)):
			continue
		var skill_data: Dictionary = CONVERTED_PERKS[skill_id]
		if not _is_perk_allowed_for_character(skill_data, character_type):
			continue
		var max_level: int = int(skill_data.get("max_level", 1))
		var current_level: int = int(runtime_levels.get(skill_id, 0))
		if max_level >= 0 and current_level >= max_level:
			continue
		var next_level: int = current_level + 1
		var restriction := str(skill_data.get("character_restriction", ""))
		var choice: Dictionary = _build_level_choice(skill_id, skill_data, current_level, next_level, restriction)
		output.append(LanguageSettings.localize_perk_data(choice))


func _with_offer_metadata(choice_value: Variant, lane: String, is_protected: bool) -> Dictionary:
	if not choice_value is Dictionary:
		return {}
	var choice: Dictionary = (choice_value as Dictionary).duplicate(true)
	choice["offer_lane"] = lane
	choice["offer_protected"] = is_protected
	return choice


func _get_mythic_offer_chances(_runtime_levels: Dictionary) -> Dictionary:
	return {
		"jackpot": clampf(float(mythic_jackpot_offer_chance), 0.0, 1.0),
	}


func _get_unowned_mythic_perk_ids(runtime_levels: Dictionary, character_type: String) -> Array[String]:
	var candidates: Array[String] = []
	for mid_value in CONVERTED_MYTHIC_PERKS.keys():
		var mid := str(mid_value)
		var mythic_data: Dictionary = CONVERTED_MYTHIC_PERKS[mid]
		if int(runtime_levels.get(mid, 0)) > 0:
			continue
		if not _is_perk_allowed_for_character(mythic_data, character_type):
			continue
		candidates.append(mid)
	return candidates


func _build_unowned_mythic_choices(runtime_levels: Dictionary, character_type: String, count: int) -> Array:
	var candidates: Array[String] = _get_unowned_mythic_perk_ids(runtime_levels, character_type)
	if candidates.is_empty():
		return []
	candidates.shuffle()
	var choices: Array = []
	for index in range(mini(maxi(0, count), candidates.size())):
		var mythic_id: String = candidates[index]
		var mythic_data: Dictionary = CONVERTED_MYTHIC_PERKS[mythic_id]
		var mythic_choice := _build_level_choice(
			mythic_id,
			mythic_data,
			0,
			1,
			str(mythic_data.get("character_restriction", ""))
		)
		choices.append(LanguageSettings.localize_perk_data(mythic_choice))
	return choices


func _is_perk_allowed_for_character(skill_data: Dictionary, character_type: String) -> bool:
	var restriction := str(skill_data.get("character_restriction", "")).strip_edges().to_lower()
	if restriction == "":
		return true
	return restriction == character_type


func _append_instant_choices(output: Array, owner: Object = null) -> void:
	# 상자 오퍼 게이트는 조립 지점 한 곳에서 닫는다 — 본 append와 부족분 filler
	# 양쪽이 같은 헬퍼를 타므로 새로고침 재굴림/자기치유 재오픈까지 동일 계약이다.
	var victory_loot_phase: bool = _is_victory_loot_phase(owner)
	for skill_id in INSTANT_PERKS.keys():
		if victory_loot_phase and VICTORY_LOOT_EXCLUDED_INSTANT_IDS.has(skill_id):
			continue
		var data: Dictionary = INSTANT_PERKS[skill_id]
		var choice: Dictionary = data.duplicate(true)
		choice["id"] = skill_id
		choice["current_level"] = 0
		choice["next_level"] = 0
		choice["max_level"] = 0
		choice["character_restriction"] = ""
		output.append(LanguageSettings.localize_perk_data(choice))


func _append_lingpet_guardian_enhance_choice(
	output: Array,
	owner: Object,
	registry: Object
) -> void:
	if not _has_lingpet_owned_gate(owner):
		return
	var runtime := _get_lingpet_runtime(registry)
	if runtime == null or not runtime.has_method("build_guardian_enhance_offer"):
		return
	var offer_value: Variant = runtime.build_guardian_enhance_offer(owner)
	if not (offer_value is Dictionary):
		return
	var offer := offer_value as Dictionary
	if not bool(offer.get("offer_allowed", false)):
		return
	var choice := LingpetGuardianEnhanceOfferEngine.get_perk_data()
	choice["id"] = LINGPET_GUARDIAN_ENHANCE_CHOICE_ID
	choice["current_level"] = 0
	choice["next_level"] = 1
	choice["guardian_enhance_candidates"] = (offer.get("candidates", []) as Array).duplicate(true)
	choice["guardian_enhance_pet_id"] = str(offer.get("pet_id", ""))
	if bool(offer.get("reserve", false)):
		choice[GUARDIAN_ENHANCE_PRIORITY_KEY] = true
	output.append(choice)


func _append_debug_pool_entries(output: Array, pool: Dictionary, debug_group: String) -> void:
	for skill_id in pool.keys():
		if not PerkConversionFlags.is_enabled() and TRAINING_DEPENDENT_PERK_IDS.has(str(skill_id)):
			continue
		# The live flag-ON picker must not grant the retired slot perk into a
		# state where it consumes a slot but has no effect. Flag OFF still needs
		# the same entry to exercise the preserved accessory-expansion path.
		if PerkConversionFlags.is_enabled() and str(skill_id) == SLOT_EXPANSION_PERK_ID:
			continue
		if PerkConversionFlags.is_enabled() and TRAINING_MIGRATED_PERK_IDS.has(str(skill_id)):
			continue
		# 디버그 목록도 조회/오퍼/bulk와 같은 flag-OFF 레거시 정의를 봐야
		# 한다 — 원본을 그대로 복사하면 OFF 디버그 피커가 max 4를 보여주고
		# 적용 단계(get_perk_data=max 2)와 어긋난다.
		var data: Dictionary = _resolve_expansion_definition(str(skill_id), pool[skill_id]).duplicate(true)
		data["id"] = skill_id
		data["debug_group"] = debug_group
		output.append(LanguageSettings.localize_perk_data(data))


func _debug_sort_key(entry: Dictionary) -> String:
	var group: String = str(entry.get("debug_group", ""))
	var group_order := {
		"common": "0",
		"smasher": "1",
		"viper": "2",
		"soldier": "3",
		"converted": "4",
		"converted_mythic": "5",
		"instant": "6",
		"training": "7",
	}
	return "%s:%s" % [str(group_order.get(group, "9")), str(entry.get("id", ""))]


func _build_level_choice(
	skill_id: String,
	skill_data: Dictionary,
	current_level: int,
	next_level: int,
	character_restriction: String
) -> Dictionary:
	var descriptions: Dictionary = skill_data.get("descriptions", {})
	var description: String = str(descriptions.get(next_level, descriptions.get(int(skill_data.get("max_level", 1)), "")))
	var choice: Dictionary = skill_data.duplicate(true)
	choice["id"] = skill_id
	choice["description"] = description
	choice["current_level"] = current_level
	choice["next_level"] = next_level
	choice["max_level"] = int(skill_data.get("max_level", 1))
	if not choice.has("character_restriction"):
		choice["character_restriction"] = character_restriction
	return choice


func _filter_unlock_slot_budget(
	choices: Array,
	character_type: String,
	runtime_levels: Dictionary,
	registry: Object = null
) -> Array:
	var live_slots_full: Variant = _get_live_chosik_slots_full(character_type, registry)
	if live_slots_full == null:
		# Direct catalog/debug callers may not own a live registry. Keep the
		# legacy character-manual count as a compatibility fallback, but never
		# prefer it over the production skill config: common/Vision Chosik also
		# occupy one of the same five combat orbs. The fallback also preserves
		# the legacy open-budget pass-through; only the live path below applies
		# the open-slot rarity gate.
		if character_type == "soldier":
			return choices
		var budget: int = int(UNLOCK_SLOT_BUDGET.get(character_type, 99))
		if budget >= 99:
			return choices
		var chosen_unlocks: int = 0
		for skill_id in runtime_levels.keys():
			var data: Dictionary = get_perk_data(str(skill_id))
			if str(data.get("character_restriction", "")) == character_type and str(data.get("unlocks_skill", "")) != "":
				chosen_unlocks += 1
		if chosen_unlocks < budget:
			return choices
		return _reserve_rare_chosik_offer(choices, true)
	# 라이브 경로: 만석/여유 모두 화면당 한 번 굴려 초식을 최대 1장으로
	# 제한한다(만석=FULL 5%, 여유=OPEN 상수).
	return _reserve_rare_chosik_offer(choices, bool(live_slots_full))


func _reserve_rare_chosik_offer(choices: Array, slots_full: bool) -> Array:
	var filtered: Array = []
	var manual_candidates: Array = []
	for choice in choices:
		if bool(choice.get(BOSS_VISION_PRIORITY_KEY, false)):
			filtered.append(choice)
			continue
		if str(choice.get("unlocks_skill", "")) == "":
			filtered.append(choice)
		else:
			manual_candidates.append(choice)
	if manual_candidates.is_empty():
		return filtered
	var offer_allowed := _roll_full_chosik_swap_offer() if slots_full else _roll_open_chosik_offer()
	if offer_allowed:
		manual_candidates.shuffle()
		var reserved_choice: Dictionary = (manual_candidates[0] as Dictionary).duplicate(true)
		# 여유 상태의 희귀 등장도 같은 예약 레인을 쓴다: 일반 셔플에 섞이면
		# 후보 수십 장에 희석되어 상수가 화면 노출률을 의미하지 못한다. 선택
		# 시 동작은 적용 시점의 실제 만석 여부(_should_start_unlock_swap)가
		# 가른다.
		reserved_choice[FULL_CHOSIK_SWAP_PRIORITY_KEY] = true
		filtered.append(reserved_choice)
	return filtered


func _get_live_chosik_slots_full(character_type: String, registry: Object) -> Variant:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var config_key := str(_character_context.get_skill_config_key(character_type))
	var skill_config: Object = registry.get_instance(config_key)
	if skill_config == null or not skill_config.has_method("is_shared_slot_full"):
		return null
	return bool(skill_config.is_shared_slot_full())


func set_full_chosik_swap_offer_roll_for_tests(roll_callable: Callable) -> void:
	_full_chosik_swap_offer_roll_for_tests = roll_callable


func clear_full_chosik_swap_offer_roll_for_tests() -> void:
	_full_chosik_swap_offer_roll_for_tests = Callable()


func set_open_chosik_offer_roll_for_tests(roll_callable: Callable) -> void:
	_open_chosik_offer_roll_for_tests = roll_callable


func clear_open_chosik_offer_roll_for_tests() -> void:
	_open_chosik_offer_roll_for_tests = Callable()


func _roll_full_chosik_swap_offer() -> bool:
	if _full_chosik_swap_offer_roll_for_tests.is_valid():
		return float(_full_chosik_swap_offer_roll_for_tests.call()) < FULL_CHOSIK_SWAP_OFFER_CHANCE
	return randf() < FULL_CHOSIK_SWAP_OFFER_CHANCE


func _roll_open_chosik_offer() -> bool:
	if _open_chosik_offer_roll_for_tests.is_valid():
		return float(_open_chosik_offer_roll_for_tests.call()) < OPEN_CHOSIK_OFFER_CHANCE
	return randf() < OPEN_CHOSIK_OFFER_CHANCE


func _filter_perk_slot_budget(choices: Array, runtime_levels: Dictionary, slot_context: Object = null) -> Array:
	var filtered: Array = []
	for value in choices:
		if not (value is Dictionary):
			filtered.append(value)
			continue
		var choice: Dictionary = value
		if bool(choice.get(BOSS_VISION_PRIORITY_KEY, false)):
			filtered.append(choice)
			continue
		if not is_slot_consuming_perk(choice):
			filtered.append(choice)
			continue
		var choice_id: String = str(choice.get("id", ""))
		var current_level: int = int(runtime_levels.get(choice_id, choice.get("current_level", 0)))
		var next_level: int = int(choice.get("next_level", current_level + 1))
		var slot_status := get_perk_slot_apply_status(
			choice,
			runtime_levels,
			slot_context,
			next_level
		)
		if bool(slot_status.get("accepted", false)):
			filtered.append(choice)
	return filtered


# 소유 슬롯퍽 업그레이드 예약: choices 풀에서 이미 보유(Lv>0)한 슬롯 소모
# 퍽의 업그레이드 카드를 셔플해 reserve_limit장 추출한다. 대쉬토큰은 전용
# per-level 부스트 lane을 따로 가지므로 여기서 제외(이중 등장 금지 —
# docs/dash_token_single_boost_double_draw_bug.md).
func _extract_owned_slot_upgrade_reserved_choices(choices: Array, runtime_levels: Dictionary, reserve_limit: int) -> Dictionary:
	var upgrades: Array = []
	var remaining: Array = []
	for value in choices:
		if value is Dictionary:
			var choice: Dictionary = value as Dictionary
			var choice_id: String = str(choice.get("id", "")).strip_edges()
			var current_level: int = int(runtime_levels.get(choice_id, choice.get("current_level", 0)))
			if choice_id == "dash_amplification":
				remaining.append(value)
				continue
			if is_slot_consuming_perk(choice) and current_level > 0:
				upgrades.append(choice)
				continue
		remaining.append(value)
	upgrades.shuffle()
	var limit := maxi(0, reserve_limit)
	var reserved: Array = []
	for index in range(upgrades.size()):
		var upgrade: Dictionary = upgrades[index] as Dictionary
		if index < limit:
			reserved.append(upgrade)
		else:
			remaining.append(upgrade)
	return {
		"reserved": reserved,
		"remaining": remaining,
	}


# 풀에서 id 일치 카드 1장을 승격 추출한다(새 카드를 만들지 않고 기존 카드를
# 그대로 옮겨 current/next_level 메타데이터를 보존).
func _extract_choice_by_id(choices: Array, choice_id: String) -> Array:
	var normalized_id := choice_id.strip_edges()
	if normalized_id == "":
		return []
	for index in range(choices.size()):
		var value = choices[index]
		if value is Dictionary and str((value as Dictionary).get("id", "")).strip_edges() == normalized_id:
			choices.remove_at(index)
			return [value]
	return []


func _filter_lingpet_owned_gate(choices: Array, owner: Object) -> Array:
	if _has_lingpet_owned_gate(owner):
		return choices
	var filtered: Array = []
	for value in choices:
		if not (value is Dictionary):
			filtered.append(value)
			continue
		var choice: Dictionary = value
		if bool(LINGPET_GATED_CHOICE_IDS.get(str(choice.get("id", "")), false)):
			continue
		filtered.append(choice)
	return filtered


func _has_lingpet_owned_gate(owner: Object) -> bool:
	return not LingpetCollectionState.new().get_owned_pet_ids_from_owner(owner).is_empty()


func _is_victory_loot_phase(owner: Object) -> bool:
	# victory_loot_phase_state가 상자 페이즈 동안 owner에 써 두는 스키마 선언 키.
	# (BattleSceneState.DEFAULT_VALUES 등재 — 미선언이면 set이 조용히 no-op다.)
	if owner == null:
		return false
	var value: Variant = owner.get("victory_loot_phase_active")
	if value == null:
		return false
	return bool(value)


func _get_lingpet_runtime(registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance("lingpet_egg_runtime")


func _has_choice_id(choices: Array, skill_id: String) -> bool:
	for choice in choices:
		if str(choice.get("id", "")) == skill_id:
			return true
	return false


func _normalize_character(character_type: String) -> String:
	return str(_character_context.normalize_character_type(character_type))
