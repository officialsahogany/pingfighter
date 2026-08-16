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

const BASE_CHOICE_COUNT := 3
# 퍽 슬롯 동적 한도(flag ON): 기본 6 + 슬롯 확장 퍽(common_expansion) RAW
# 레벨(최대 10). flag OFF에서는 고정 6이며 확장 퍽은 레거시 장신구 의미.
const BASE_PERK_SLOT_LIMIT := 6
const MAX_PERK_SLOT_LIMIT := 10
const SLOT_EXPANSION_PERK_ID := "common_expansion"
const LINGPET_GUARDIAN_ENHANCE_CHOICE_ID := LingpetGuardianEnhanceOfferEngine.PERK_ID
const GUARDIAN_ENHANCE_PRIORITY_KEY := "_guardian_enhance_reserved"
const FULL_CHOSIK_SWAP_PRIORITY_KEY := "_full_chosik_swap_reserved"
const FULL_CHOSIK_SWAP_OFFER_CHANCE := 0.15
const LINGPET_GATED_CHOICE_IDS := {
	LINGPET_GUARDIAN_ENHANCE_CHOICE_ID: true,
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
			1: "활주 거리 7% 증가",
			2: "활주 거리 14% 증가",
			3: "활주 거리 21% 증가",
			4: "활주 거리 28% 증가",
			5: "활주 거리 35% 증가",
		},
		"detail": "비천보로 한 번의 활주 거리를 늘려 더 멀리 움직입니다.",
		"icon_color": Color(100.0 / 255.0, 1.0, 150.0 / 255.0),
		"tree": "dash",
	},
	"dash_acceleration": {
		"name": "대붕전익",
		"max_level": 5,
		"descriptions": {
			1: "활주시 패들 크기 70% 증가",
			2: "활주시 패들 크기 140% 증가",
			3: "활주시 패들 크기 210% 증가",
			4: "활주시 패들 크기 280% 증가",
			5: "활주시 패들 크기 350% 증가",
		},
		"detail": "활주 순간 대붕이 날개를 펼치듯 패들이 크게 넓어져 더 넓은 범위의 공을 받아냅니다.",
		"icon_color": Color(1.0, 100.0 / 255.0, 50.0 / 255.0),
		"tree": "dash",
	},
	"dash_amplification": {
		"name": "연환보",
		"max_level": 3,
		"descriptions": {
			1: "최대 활주 횟수 +1",
			2: "최대 활주 횟수 +2",
			3: "최대 활주 횟수 +3",
		},
		"detail": "연환보로 레벨마다 최대 활주 횟수를 1회 늘리고, 같은 수만큼 무공 슬롯을 사용합니다.",
		"icon_color": Color(1.0, 200.0 / 255.0, 50.0 / 255.0),
		"tree": "dash",
	},
	"item_luck": {
		"name": "인보결",
		"max_level": 5,
		"descriptions": {
			1: "아이템 스폰 대기 12% 감소",
			2: "아이템 스폰 대기 24% 감소",
			3: "아이템 스폰 대기 36% 감소",
			4: "아이템 스폰 대기 48% 감소",
			5: "아이템 스폰 대기 60% 감소",
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
		"max_level": 5,
		"descriptions": {
			1: "액티브 사용시 기력 +15",
			2: "액티브 사용시 기력 +30",
			3: "액티브 사용시 기력 +45",
			4: "액티브 사용시 기력 +60",
			5: "액티브 사용시 기력 +75",
		},
		"detail": "기령심법으로 액티브 아이템을 쓸 때 기물의 영기를 받아 기력을 얻습니다.",
		"icon_color": Color(150.0 / 255.0, 1.0, 100.0 / 255.0),
		"tree": "item",
	},
	"item_caffeine": {
		"name": "연효결",
		"max_level": 5,
		"descriptions": {
			1: "타이머형 아이템 지속 30% 증가",
			2: "타이머형 아이템 지속 60% 증가",
			3: "타이머형 아이템 지속 90% 증가",
			4: "타이머형 아이템 지속 120% 증가",
			5: "타이머형 아이템 지속 150% 증가",
		},
		"detail": "연효결로 지속시간형 액티브 아이템의 효력을 더 오래 이어갑니다.",
		"icon_color": Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0),
		"tree": "item",
	},
	"item_polish": {
		"name": "개광결",
		"max_level": 5,
		"descriptions": {
			1: "적용 대상 무공의 수치 능력치 5% 증폭",
			2: "적용 대상 무공의 수치 능력치 10% 증폭",
			3: "적용 대상 무공의 수치 능력치 15% 증폭",
			4: "적용 대상 무공의 수치 능력치 20% 증폭",
			5: "적용 대상 무공의 수치 능력치 25% 증폭",
		},
		"detail": "개광결로 적용 대상 무공의 수치형 능력치를 독립적으로 증폭합니다. 절세무공, 캐릭터, 비급, 즉시 효과와 카운트형 효과는 제외됩니다.",
		"icon_color": Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0),
		"tree": "item",
	},
	"item_recycle": {
		"name": "환보결",
		"max_level": 5,
		"descriptions": {
			1: "아이템 유지 확률 7%",
			2: "아이템 유지 확률 14%",
			3: "아이템 유지 확률 21%",
			4: "아이템 유지 확률 28%",
			5: "아이템 유지 확률 35%",
		},
		"detail": "환보결로 사용한 아이템을 확률적으로 되돌려 보존합니다.",
		"icon_color": Color(148.0 / 255.0, 0.0, 211.0 / 255.0),
		"tree": "item",
	},
	"downtown_treasure_map": {
		"name": "천기보도",
		"max_level": 5,
		"descriptions": {
			1: "신화 확률 +150%, 패시브 드랍 +3%, 보물탐색 신화 +3%",
			2: "신화 확률 +300%, 패시브 드랍 +6%, 보물탐색 신화 +6%",
			3: "신화 확률 +450%, 패시브 드랍 +9%, 보물탐색 신화 +9%",
			4: "신화 확률 +600%, 패시브 드랍 +12%, 보물탐색 신화 +12%",
			5: "신화 확률 +750%, 패시브 드랍 +15%, 보물탐색 신화 +15%",
		},
		"detail": "천기보도가 신화 아이템 획득 확률과 패시브 아이템 드랍 비율을 높입니다. 즉시형 무공 '보물탐색'의 신화 보상 확률도 레벨당 3% 증가합니다.",
		"icon_color": Color(1.0, 223.0 / 255.0, 0.0),
		"tree": "downtown",
	},
	"item_bag_expansion": {
		"name": "건곤낭",
		"max_level": 5,
		"descriptions": {
			1: "액티브 슬롯 +1",
			2: "액티브 슬롯 +2",
			3: "액티브 슬롯 +3",
			4: "액티브 슬롯 +4",
			5: "액티브 슬롯 +5",
		},
		"detail": "건곤낭의 안쪽 공간을 넓혀 더 많은 액티브 아이템을 보관합니다.",
		"icon_color": Color(180.0 / 255.0, 120.0 / 255.0, 80.0 / 255.0),
		"tree": "item",
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
			1: "패들 크기 6% 증가",
			2: "패들 크기 12% 증가",
			3: "패들 크기 18% 증가",
			4: "패들 크기 24% 증가",
			5: "패들 크기 30% 증가",
		},
		"detail": "철산공으로 몸의 기세를 넓혀 패들 크기가 증가합니다.",
		"icon_color": Color(1.0, 150.0 / 255.0, 80.0 / 255.0),
		"tree": "common",
	},
	"perk_boost_charge": {
		"name": "축기결",
		"max_level": 5,
		"descriptions": {
			1: "확률 +7%, 발동 시 다음 활주 무료 + 재충전 -90%",
			2: "확률 +14%, 발동 시 다음 활주 무료 + 재충전 -90%",
			3: "확률 +21%, 발동 시 다음 활주 무료 + 재충전 -90%",
			4: "확률 +28%, 발동 시 다음 활주 무료 + 재충전 -90%",
			5: "확률 +35%, 발동 시 다음 활주 무료 + 재충전 -90%",
		},
		"detail": "축기결이 발동하면 다음 활주 횟수 소모를 1회 무효화하고, 재충전 중인 활주 1회의 남은 시간을 90% 줄입니다.",
		"icon_color": Color(80.0 / 255.0, 160.0 / 255.0, 1.0),
		"tree": "common",
	},
	"perk_laurel_shield": {
		"name": "오엽호신",
		"max_level": 5,
		"descriptions": {
			1: "벽사 잎 1개 보호",
			2: "벽사 잎 2개 보호",
			3: "벽사 잎 3개 보호",
			4: "벽사 잎 4개 보호",
			5: "벽사 잎 5개 보호",
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
		"max_level": 5,
		"descriptions": {
			1: "활주시 7% 확률로 레이저 잔상",
			2: "활주시 14% 확률로 레이저 잔상",
			3: "활주시 21% 확률로 레이저 잔상",
			4: "활주시 28% 확률로 레이저 잔상",
			5: "활주시 35% 확률로 레이저 잔상",
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
		"detail": "S 또는 ↓ 키를 0.5초 이상 홀드하면 건곤의 문을 열어 좌/우 경계를 넘어 반대편으로 순간이동하는 초식을 익힙니다. 문을 넘을 때 추가 기력을 소모하지 않습니다.",
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
	"extension_gear": {
		"name": "불식심법",
		"max_level": 5,
		"descriptions": {
			1: "경신보/청심결/건곤환문 지속시간 +25%",
			2: "경신보/청심결/건곤환문 지속시간 +50%",
			3: "경신보/청심결/건곤환문 지속시간 +75%",
			4: "경신보/청심결/건곤환문 지속시간 +100%",
			5: "경신보/청심결/건곤환문 지속시간 +125%",
		},
		"detail": "스매셔의 지속형 유틸리티 초식 시간이 길어집니다.",
		"icon_color": Color(120.0 / 255.0, 230.0 / 255.0, 180.0 / 255.0),
		"tree": "smasher",
		"character_restriction": "smasher",
	},
	"combo_amplifier_chip": {
		"name": "축뢰심법",
		"max_level": 5,
		"descriptions": {
			1: "콤보 효과 증폭: 벽력타 공속+90%, 커브+5%, 천뢰격 공속+45%, 초기부스트 감쇄 -10%",
			2: "콤보 효과 증폭: 벽력타 공속+180%, 커브+10%, 천뢰격 공속+90%, 초기부스트 감쇄 -20%",
			3: "콤보 효과 증폭: 벽력타 공속+270%, 커브+15%, 천뢰격 공속+135%, 초기부스트 감쇄 -30%",
			4: "콤보 효과 증폭: 벽력타 공속+360%, 커브+15%(캡), 천뢰격 공속+180%, 초기부스트 감쇄 -40%",
			5: "콤보 효과 증폭: 벽력타 공속+450%, 커브+15%(캡), 천뢰격 공속+225%, 초기부스트 감쇄 -50%(캡)",
		},
		"detail": "콤보 소모형 벽력타/천뢰격의 콤보 비례 증가율을 추가로 증폭합니다. 공속 증폭은 레벨에 따라 계속 증가하지만, 벽력타 커브 증폭은 Lv3에서 캡됩니다(밸런스 보호). 또한 천뢰격의 초기 부스트 감쇄가 완만해져 폭발력이 더 오래 유지됩니다.",
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
		"max_level": 5,
		"descriptions": {
			1: "제트팩 최대 게이지 +20%",
			2: "제트팩 최대 게이지 +40%",
			3: "제트팩 최대 게이지 +60%, 체공 중 게이지 획득 +10%",
			4: "제트팩 최대 게이지 +80%, 체공 중 게이지 획득 +20%",
			5: "제트팩 최대 게이지 +100%, 체공 중 게이지 획득 +30%",
		},
		"detail": "바이퍼의 공중 운용 여유가 커집니다.",
		"icon_color": Color(90.0 / 255.0, 220.0 / 255.0, 1.0),
		"tree": "viper",
		"character_restriction": "viper",
	},
	"kick_enhance": {
		"name": "천각심법",
		"max_level": 5,
		"descriptions": {
			1: "킥 발사 정밀도 +8%, 공속 +12%, 준비 -7%",
			2: "킥 발사 정밀도 +16%, 공속 +24%, 준비 -14%",
			3: "킥 발사 정밀도 +24%, 공속 +36%, 준비 -21%, 용광로 넉백볼 10%",
			4: "킥 발사 정밀도 +32%, 공속 +48%, 준비 -28%, 용광로 넉백볼 20%",
			5: "킥 발사 정밀도 +40%, 공속 +60%, 준비 -35%, 용광로 넉백볼 30%",
		},
		"detail": "바이퍼 킥 계열 초식의 정밀도, 공속, 준비동작을 강화합니다. Lv.3부터 킥 적중 시 확률로 공이 용광로 넉백볼이 되며, 보스가 가드하면 화재형 넉백 150%를 1회 적용합니다.",
		"icon_color": Color(1.0, 90.0 / 255.0, 130.0 / 255.0),
		"tree": "viper",
		"character_restriction": "viper",
	},
	"blade_amp": {
		"name": "검강심법",
		"max_level": 5,
		"descriptions": {
			1: "검기 사거리/가로폭 +10%, 검기 속도 +10%",
			2: "검기 사거리/가로폭 +20%, 검기 속도 +20%",
			3: "검기 사거리/가로폭 +30%, 검기 속도 +30%, 유도검기",
			4: "검기 사거리/가로폭 +40%, 검기 속도 +40%, 유도검기",
			5: "검기 사거리/가로폭 +50%, 검기 속도 +50%, 추가 유도검기",
		},
		"detail": "에어 블레이드와 혈영참의 검기를 강화합니다.",
		"icon_color": Color(180.0 / 255.0, 60.0 / 255.0, 220.0 / 255.0),
		"tree": "viper",
		"character_restriction": "viper",
	},
	"four_poisons": {
		"name": "사독귀일",
		"max_level": 5,
		"descriptions": {
			1: "천뢰진각/혼천흑창 준비 -8%, 천뢰진각 수면 +5%, 독영절맥 혼란 +12%, 쌍영분신 지속 +7%",
			2: "천뢰진각/혼천흑창 준비 -16%, 천뢰진각 수면 +10%, 독영절맥 혼란 +24%, 쌍영분신 지속 +14%",
			3: "천뢰진각/혼천흑창 준비 -25%, 천뢰진각 수면 +15%, 독영절맥 혼란 +36%, 쌍영분신 지속 +20%, 쌍영분신 HP 3, 4초식 쿨 -10%, 슈퍼아머",
			4: "천뢰진각/혼천흑창 준비 -33%, 천뢰진각 수면 +20%, 독영절맥 혼란 +48%, 쌍영분신 지속 +27%, 쌍영분신 HP 3, 4초식 쿨 -15%, 슈퍼아머",
			5: "천뢰진각/혼천흑창 준비 -40%, 천뢰진각 수면 +25%, 독영절맥 혼란 +70%, 쌍영분신 지속 +33%, 쌍영분신 HP 4, 4초식 쿨 -20%, 슈퍼아머, 분신 복제",
		},
		"detail": "천뢰진각, 독영절맥, 혼천흑창, 쌍영분신을 묶어 강화합니다.\n천뢰진각/혼천흑창 준비와 천뢰진각 수면, 독영절맥 혼란, 쌍영분신 지속시간을 올립니다.\nLv.3부터 준비동작 슈퍼아머와 4초식 쿨감이 켜지고 쌍영분신 HP가 3이 됩니다.\nLv.5부터 쌍영분신 HP 4, 분신 초식 복제가 적용됩니다. 복제는 추가 기력/쿨/골드를 만들지 않습니다.",
		"icon_color": Color(215.0 / 255.0, 70.0 / 255.0, 1.0),
		"tree": "viper",
		"character_restriction": "viper",
	},
}

const SOLDIER_PERKS := {
	"soldier_unlock_net_gun": {
		"name": "그물덫총",
		"max_level": 1,
		"descriptions": {1: "그물덫총 비급"},
		"detail": "그물덫총을 영구 습득하고 호란의 초식 구슬에 추가합니다. 탄환은 재장전 초식으로 1발씩 다시 채웁니다.",
		"icon_color": Color(100.0 / 255.0, 180.0 / 255.0, 100.0 / 255.0),
		"tree": "soldier_unlock",
		"character_restriction": "soldier",
		"is_weapon_unlock": true,
		"weapon_name": "net_gun",
		"unlocks_skill": "net_gun",
	},
	"soldier_unlock_fire_support": {
		"name": "화력지원",
		"max_level": 1,
		"descriptions": {1: "화력지원 비급"},
		"detail": "화력지원을 영구 습득하고 호란의 초식 구슬에 추가합니다. 호출권은 재장전 게이지가 끝까지 차면 보충됩니다.",
		"icon_color": Color(1.0, 100.0 / 255.0, 50.0 / 255.0),
		"tree": "soldier_unlock",
		"character_restriction": "soldier",
		"is_weapon_unlock": true,
		"weapon_name": "fire_support",
		"unlocks_skill": "fire_support",
	},
	"soldier_unlock_bowling_trap": {
		"name": "볼링트랩",
		"max_level": 1,
		"descriptions": {1: "볼링트랩 비급"},
		"detail": "볼링트랩을 영구 습득하고 호란의 초식 구슬에 추가합니다. 탄환은 재장전 초식으로 1발씩 다시 채웁니다.",
		"icon_color": Color(200.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0),
		"tree": "soldier_unlock",
		"character_restriction": "soldier",
		"is_weapon_unlock": true,
		"weapon_name": "bowling_trap",
		"unlocks_skill": "bowling_trap",
	},
	"soldier_unlock_suicide_drone": {
		"name": "자폭드론",
		"max_level": 1,
		"descriptions": {1: "자폭드론 비급"},
		"detail": "자폭드론을 영구 습득하고 호란의 초식 구슬에 추가합니다. 탄환은 재장전 초식으로 1발씩 다시 채웁니다.",
		"icon_color": Color(1.0, 100.0 / 255.0, 50.0 / 255.0),
		"tree": "soldier_unlock",
		"character_restriction": "soldier",
		"is_weapon_unlock": true,
		"weapon_name": "suicide_drone",
		"unlocks_skill": "suicide_drone",
	},
	"soldier_unlock_bazooka": {
		"name": "바주카포",
		"max_level": 1,
		"descriptions": {1: "바주카포 비급"},
		"detail": "바주카포를 영구 습득하고 호란의 초식 구슬에 추가합니다. 탄약은 재장전 초식으로 1발씩 다시 채웁니다.",
		"icon_color": Color(220.0 / 255.0, 120.0 / 255.0, 70.0 / 255.0),
		"tree": "soldier_unlock",
		"character_restriction": "soldier",
		"is_weapon_unlock": true,
		"weapon_name": "bazooka",
		"unlocks_skill": "bazooka",
	},
	"soldier_unlock_ak47": {
		"name": "AK-47",
		"max_level": 1,
		"descriptions": {1: "AK-47 비급"},
		"detail": "AK-47을 영구 습득하고 호란의 초식 구슬에 추가합니다. 탄약과 지속시간은 재장전 게이지가 끝까지 차면 보충됩니다.",
		"icon_color": Color(110.0 / 255.0, 135.0 / 255.0, 85.0 / 255.0),
		"tree": "soldier_unlock",
		"character_restriction": "soldier",
		"is_weapon_unlock": true,
		"weapon_name": "ak47",
		"unlocks_skill": "ak47",
	},
	"soldier_pistol_perk": {
		"name": "베레타",
		"max_level": 1,
		"descriptions": {1: "베레타 비급"},
		"detail": "기본 권총은 유지한 채 베레타를 별도 영구 화기류로 습득합니다. 베레타는 준비동작 없이 즉시 발사되며 권총보다 연사가 2배 빠르고 탄속 20%, 정확도 30%가 향상되고 탄약 12발은 재장전 초식으로만 보충합니다.",
		"icon_color": Color(140.0 / 255.0, 130.0 / 255.0, 120.0 / 255.0),
		"tree": "soldier_unlock",
		"character_restriction": "soldier",
		"is_weapon_unlock": true,
		"weapon_name": "commando_pistol",
		"unlocks_skill": "commando_pistol",
	},
	"pistol_enhance": {
		"name": "철포결",
		"max_level": 5,
		"descriptions": {
			1: "기본권총 정확도 ±12°, 탄속 +10%, 넉백 +30%, 탄창 5발",
			2: "기본권총 정확도 ±9°, 탄속 +20%, 넉백 +60%, 탄창 5발",
			3: "기본권총 정확도 ±6°, 탄속 +30%, 넉백 +90%, 탄창 6발",
			4: "기본권총 정확도 ±3°, 탄속 +40%, 넉백 +120%, 탄창 6발",
			5: "기본권총 정확도 ±1°, 탄속 +50%, 넉백 +150%, 탄창 7발",
		},
		"detail": "기본권총 전용 강화입니다. 베레타는 영향을 받지 않습니다.\n레벨이 오를수록 기본권총 탄퍼짐이 줄고 탄속은 10%씩, 정상타 넉백은 30%씩 증가하며, Lv.3/Lv.5에 탄창이 늘어납니다.\n효과 레벨이 Lv.6 이상이면 정확도는 ±1°, 탄속은 +50%, 넉백은 +150%에 머물고 탄창만 레벨마다 1발씩 계속 늘어납니다.",
		"icon_color": Color(210.0 / 255.0, 175.0 / 255.0, 92.0 / 255.0),
		"tree": "soldier",
		"character_restriction": "soldier",
	},
}

const CONVERTED_PERKS := {
	"star_detector": {
		"name": "낙성결",
		"max_level": 5,
		"descriptions": {
			1: "스타포인트 보너스 드랍 확률 +5%",
			2: "스타포인트 보너스 드랍 확률 +10%",
			3: "스타포인트 보너스 드랍 확률 +15%",
			4: "스타포인트 보너스 드랍 확률 +20%",
			5: "스타포인트 보너스 드랍 확률 +25%",
		},
		"detail": "스타포인트 드랍이 생길 때 추가 스타포인트 드랍을 노립니다.",
		"icon_color": Color(80.0 / 255.0, 200.0 / 255.0, 220.0 / 255.0),
		"tree": "item",
		"conversion_source": "star_detector",
	},
	"adversity_armor": {
		"name": "역천호신",
		"max_level": 5,
		"descriptions": {
			1: "실점 후 발동 20%, 보호 5초",
			2: "실점 후 발동 25%, 보호 8초",
			3: "실점 후 발동 30%, 보호 10초",
			4: "실점 후 발동 35%, 보호 13초",
			5: "실점 후 발동 40%, 보호 15초",
		},
		"detail": "실점 다음 라운드에 무적벽을 세워 사용자를 보호합니다.",
		"icon_color": Color(0.96, 0.58, 0.18),
		"tree": "common",
		"conversion_source": "adversity_armor",
	},
	"reinforced_boomerang_gauntlet": {
		"name": "회선철수",
		"max_level": 5,
		"descriptions": {
			1: "부메랑 넉백 +20%, 스턴 +20%, 발사속도 +15%, 유도 +10%, 스폰 +50%",
			2: "부메랑 넉백 +28%, 스턴 +35%, 발사속도 +24%, 유도 +20%, 스폰 +88%",
			3: "부메랑 넉백 +35%, 스턴 +50%, 발사속도 +33%, 유도 +30%, 스폰 +125%",
			4: "부메랑 넉백 +43%, 스턴 +65%, 발사속도 +41%, 유도 +40%, 스폰 +163%",
			5: "부메랑 넉백 +50%, 스턴 +80%, 발사속도 +50%, 유도 +50%, 스폰 +200%",
		},
		"detail": "부메랑을 메탈 강화하고 전투 성능과 필드 등장률을 끌어올립니다.",
		"icon_color": Color(150.0 / 255.0, 200.0 / 255.0, 1.0),
		"tree": "item",
		"conversion_source": "reinforced_boomerang_gauntlet",
	},
	"sensor": {
		"name": "감응보",
		"max_level": 5,
		"descriptions": {
			1: "자동 활주 1회, 쿨타임 30초",
			2: "자동 활주 1회, 쿨타임 26초",
			3: "자동 활주 2회, 쿨타임 23초",
			4: "자동 활주 2회, 쿨타임 19초",
			5: "자동 활주 2회, 쿨타임 15초",
		},
		"detail": "위험 상황에서 전용 횟수를 사용해 자동으로 활주합니다.",
		"icon_color": Color(150.0 / 255.0, 150.0 / 255.0, 1.0),
		"tree": "dash",
		"conversion_source": "sensor",
	},
	"gravitybelt": {
		"name": "찰나신법",
		"max_level": 1,
		"descriptions": {1: "이동 입력 즉시 최대속도, 입력 해제 시 즉시 정지"},
		"detail": "이동 가속과 감속을 즉시 반응형 조작감으로 바꿉니다.",
		"icon_color": Color(120.0 / 255.0, 90.0 / 255.0, 1.0),
		"tree": "dash",
		"conversion_source": "gravitybelt",
	},
	"dowsing_pendulum": {
		"name": "섭물공",
		"max_level": 5,
		"descriptions": {
			1: "필드 아이템·스타포인트 흡인 범위 120px",
			2: "필드 아이템·스타포인트 흡인 범위 160px",
			3: "필드 아이템·스타포인트 흡인 범위 200px",
			4: "필드 아이템·스타포인트 흡인 범위 240px",
			5: "필드 아이템·스타포인트 흡인 범위 280px",
		},
		"detail": "주변의 필드 아이템과 스타포인트를 플레이어 패들 쪽으로 끌어당깁니다.",
		"icon_color": Color(100.0 / 255.0, 150.0 / 255.0, 1.0),
		"tree": "item",
		"conversion_source": "dowsing_pendulum",
	},
	"dowsing_goggles": {
		"name": "천안결",
		"max_level": 3,
		"descriptions": {
			1: "무공 선택지 보너스 발동 확률 40%",
			2: "무공 선택지 보너스 발동 확률 70%",
			3: "무공 선택지 보너스 발동 확률 100%",
		},
		"detail": "무공 선택지가 열릴 때 확률적으로 선택지 하나를 더 보여줍니다.",
		"icon_color": Color(70.0 / 255.0, 210.0 / 255.0, 1.0),
		"tree": "item",
		"conversion_source": "dowsing_goggles",
	},
	"chargebag": {
		"name": "반탄심법",
		"max_level": 5,
		"descriptions": {
			1: "벽 반사 기력 +15%",
			2: "벽 반사 기력 +25%",
			3: "벽 반사 기력 +35%",
			4: "벽 반사 기력 +45%",
			5: "벽 반사 기력 +55%",
		},
		"detail": "공이 벽에 닿을 때마다 추가 기력을 얻습니다.",
		"icon_color": Color(100.0 / 255.0, 1.0, 100.0 / 255.0),
		"tree": "item",
		"conversion_source": "chargebag",
	},
	"battery": {
		"name": "장기심법",
		"max_level": 5,
		"descriptions": {
			1: "스테이지 전환 기력 보존 40%",
			2: "스테이지 전환 기력 보존 55%",
			3: "스테이지 전환 기력 보존 70%",
			4: "스테이지 전환 기력 보존 85%",
			5: "스테이지 전환 기력 보존 100%",
		},
		"detail": "다음 스테이지로 넘어갈 때 현재 기력 일부를 보존합니다.",
		"icon_color": Color(1.0, 1.0, 0.0),
		"tree": "item",
		"conversion_source": "battery",
	},
	"revival": {
		"name": "윤회결",
		"max_level": 1,
		"descriptions": {1: "패배 직전 런당 1회 스테이지 재시작"},
		"detail": "패배 직전 한 번 발동해 게임 오버를 막고 스테이지를 다시 시작합니다.",
		"icon_color": Color(1.0, 0.0, 1.0),
		"tree": "common",
		"conversion_source": "revival",
	},
	"master": {
		"name": "축성공",
		"max_level": 5,
		"descriptions": {
			1: "벽돌 길이 +12%, 아이템 쿨타임 3% 감소, 벽돌 스폰 +100%",
			2: "벽돌 길이 +20%, 아이템 쿨타임 5% 감소, 벽돌 스폰 +158%",
			3: "벽돌 길이 +29%, 아이템 쿨타임 8% 감소, 벽돌 스폰 +215%",
			4: "벽돌 길이 +37%, 아이템 쿨타임 10% 감소, 벽돌 스폰 +273%",
			5: "벽돌 길이 +45%, 아이템 쿨타임 12% 감소, 벽돌 스폰 +330%",
		},
		"detail": "벽돌 액티브 아이템의 방어력과 등장 빈도를 강화합니다.",
		"icon_color": Color(1.0, 215.0 / 255.0, 0.0),
		"tree": "item",
		"conversion_source": "master",
	},
	"gold_digger": {
		"name": "취금결",
		"max_level": 5,
		"descriptions": {
			1: "골드·일부 기력 획득 +15%",
			2: "골드·일부 기력 획득 +25%",
			3: "골드·일부 기력 획득 +35%",
			4: "골드·일부 기력 획득 +45%",
			5: "골드·일부 기력 획득 +55%",
		},
		"detail": "전투 중 얻는 골드와 일부 기력 획득량을 늘립니다.",
		"icon_color": Color(1.0, 200.0 / 255.0, 50.0 / 255.0),
		"tree": "item",
		"conversion_source": "gold_digger",
	},
	"lucky_coin": {
		"name": "쌍복결",
		"max_level": 5,
		"descriptions": {
			1: "아이템 더블스폰 확률 3%",
			2: "아이템 더블스폰 확률 7%",
			3: "아이템 더블스폰 확률 10%",
			4: "아이템 더블스폰 확률 14%",
			5: "아이템 더블스폰 확률 17%",
		},
		"detail": "필드 아이템이 나타날 때 보너스 아이템을 한 번 더 노립니다.",
		"icon_color": Color(1.0, 223.0 / 255.0, 0.0),
		"tree": "item",
		"conversion_source": "lucky_coin",
	},
	"shrapnel_armor": {
		"name": "산화수",
		"max_level": 5,
		"descriptions": {
			1: "발동 6%, 파편 4개, 넉백 Lv.1, 기력 50 소모",
			2: "발동 9%, 파편 5개, 넉백 Lv.2, 기력 44 소모",
			3: "발동 12%, 파편 6개, 넉백 Lv.3, 기력 38 소모",
			4: "발동 14%, 파편 7개, 넉백 Lv.3, 기력 31 소모",
			5: "발동 17%, 파편 8개, 넉백 Lv.4, 기력 25 소모",
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
		"detail": "패들로 공을 칠 때 얻는 기력을 늘립니다.",
		"icon_color": Color(100.0 / 255.0, 150.0 / 255.0, 1.0),
		"tree": "common",
		"conversion_source": "bluetooth_ring",
	},
	"foul_whistle": {
		"name": "반전결",
		"max_level": 5,
		"descriptions": {
			1: "실점 무효 확률 3%",
			2: "실점 무효 확률 5%",
			3: "실점 무효 확률 7%",
			4: "실점 무효 확률 9%",
			5: "실점 무효 확률 11%",
		},
		"detail": "라운드 패배 시 실점을 취소하고 라운드 재시작을 노립니다.",
		"icon_color": Color(1.0, 235.0 / 255.0, 120.0 / 255.0),
		"tree": "common",
		"conversion_source": "foul_whistle",
	},
	"smartphone": {
		"name": "응변결",
		"max_level": 1,
		"descriptions": {1: "회복/스톱워치/금강결계 자동 사용"},
		"detail": "위급 상황에서 특정 액티브 아이템을 자동으로 사용합니다.",
		"icon_color": Color(100.0 / 255.0, 150.0 / 255.0, 200.0 / 255.0),
		"tree": "item",
		"conversion_source": "smartphone",
	},
	"neural_helmet": {
		"name": "강신결",
		"max_level": 5,
		"descriptions": {
			1: "신령환 기력 비용 30 감소, 스폰 +100%",
			2: "신령환 기력 비용 40 감소, 스폰 +158%",
			3: "신령환 기력 비용 50 감소, 스폰 +215%",
			4: "신령환 기력 비용 60 감소, 스폰 +273%",
			5: "신령환 기력 비용 70 감소, 스폰 +330%",
		},
		"detail": "신령환 액티브의 부담을 낮추고 필드 등장률을 높입니다.",
		"icon_color": Color(140.0 / 255.0, 180.0 / 255.0, 1.0),
		"tree": "item",
		"conversion_source": "neural_helmet",
	},
	"commando_arm": {
		"name": "비병결",
		"max_level": 5,
		"descriptions": {
			1: "투척 속도 +6%, 폭발 +3%, 연막 +12%, 준비 12% 감소",
			2: "투척 속도 +11%, 폭발 +7%, 연막 +21%, 준비 21% 감소",
			3: "투척 속도 +15%, 폭발 +11%, 연막 +30%, 준비 30% 감소",
			4: "투척 속도 +20%, 폭발 +14%, 연막 +39%, 준비 39% 감소",
			5: "투척 속도 +24%, 폭발 +18%, 연막 +48%, 준비 48% 감소",
		},
		"detail": "투척형 액티브 아이템들의 속도, 폭발, 지속, 준비 시간을 강화합니다.",
		"icon_color": Color(60.0 / 255.0, 60.0 / 255.0, 70.0 / 255.0),
		"tree": "item",
		"conversion_source": "commando_arm",
	},
	"rainbow_fur_glove": {
		"name": "칠채순환",
		"max_level": 5,
		"descriptions": {
			1: "공 히트 시 발동 3%, 진행 중 초식 쿨타임 20% 감소",
			2: "공 히트 시 발동 5%, 진행 중 초식 쿨타임 29% 감소",
			3: "공 히트 시 발동 8%, 진행 중 초식 쿨타임 38% 감소",
			4: "공 히트 시 발동 10%, 진행 중 초식 쿨타임 46% 감소",
			5: "공 히트 시 발동 12%, 진행 중 초식 쿨타임 55% 감소",
		},
		"detail": "공을 받아칠 때 장착한 초식의 남은 쿨타임을 줄일 수 있습니다.",
		"icon_color": Color(1.0, 170.0 / 255.0, 220.0 / 255.0),
		"tree": "common",
		"conversion_source": "rainbow_fur_glove",
	},
	"knee_pads": {
		"name": "비각축기",
		"max_level": 5,
		"descriptions": {
			1: "짧은 활주 타격 기력 +20%",
			2: "짧은 활주 타격 기력 +33%",
			3: "짧은 활주 타격 기력 +45%",
			4: "짧은 활주 타격 기력 +58%",
			5: "짧은 활주 타격 기력 +70%",
		},
		"detail": "짧은 활주로 공을 맞출 때 추가 기력을 얻습니다.",
		"icon_color": Color(80.0 / 255.0, 80.0 / 255.0, 100.0 / 255.0),
		"tree": "dash",
		"conversion_source": "knee_pads",
	},
	"soul_burst": {
		"name": "폭혼보",
		"max_level": 5,
		"descriptions": {
			1: "활주 횟수가 없을 때 완전 활주 기력 170",
			2: "활주 횟수가 없을 때 완전 활주 기력 153",
			3: "활주 횟수가 없을 때 완전 활주 기력 135",
			4: "활주 횟수가 없을 때 완전 활주 기력 118",
			5: "활주 횟수가 없을 때 완전 활주 기력 100",
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
			1: "스턴 저항 +6%",
			2: "스턴 저항 +11%",
			3: "스턴 저항 +15%",
			4: "스턴 저항 +20%",
			5: "스턴 저항 +24%",
		},
		"detail": "플레이어에게 걸리는 스턴 시간을 줄입니다.",
		"icon_color": Color(0.38, 0.72, 1.0),
		"tree": "common",
		"conversion_source": "bulletproof_hat",
	},
	"spiked_helmet": {
		"name": "천근추",
		"max_level": 5,
		"descriptions": {
			1: "넉백 저항 +6%",
			2: "넉백 저항 +11%",
			3: "넉백 저항 +15%",
			4: "넉백 저항 +20%",
			5: "넉백 저항 +24%",
		},
		"detail": "플레이어가 받는 넉백 속도를 줄입니다.",
		"icon_color": Color(1.0, 0.62, 0.32),
		"tree": "common",
		"conversion_source": "spiked_helmet",
	},
	"venom_mist_gauntlet": {
		"name": "독운공",
		"max_level": 5,
		"descriptions": {
			1: "독안개 발동 20%, 지속 1.5초",
			2: "독안개 발동 29%, 지속 2.5초",
			3: "독안개 발동 38%, 지속 3.5초",
			4: "독안개 발동 46%, 지속 4.5초",
			5: "독안개 발동 55%, 지속 5.5초",
		},
		"detail": "화랑비천각으로 감염된 공을 보스가 막으면 독안개를 생성합니다.",
		"icon_color": Color(80.0 / 255.0, 200.0 / 255.0, 80.0 / 255.0),
		"tree": "viper",
		"character_restriction": "viper",
		"conversion_source": "venom_mist_gauntlet",
	},
	"speedgear": {
		"name": "회류보",
		"max_level": 1,
		"descriptions": {1: "좌우 방향 전환 감속 2.5배"},
		"detail": "방향 전환 시 급격한 조작을 보정하는 이동 특성을 적용합니다.",
		"icon_color": Color(1.0, 150.0 / 255.0, 0.0),
		"tree": "dash",
		"conversion_source": "speedgear",
	},
	"sage_ring": {
		"name": "현문차력",
		"max_level": 5,
		"descriptions": {
			1: "공 타격 시 5%: 모든 무공 레벨 +1 (6초)",
			2: "공 타격 시 5%: 모든 무공 레벨 +1 (7초)",
			3: "공 타격 시 5%: 모든 무공 레벨 +2 (8초)",
			4: "공 타격 시 5%: 모든 무공 레벨 +2 (9초)",
			5: "공 타격 시 5%: 모든 무공 레벨 +3 (10초)",
		},
		"detail": "공을 타격할 때 5% 확률로 발동해 일정 시간 모든 무공의 유효 레벨을 올립니다. 활성 중 다시 발동하면 효과는 중첩되지 않고 현재 투자 레벨 기준으로 지속시간이 갱신됩니다.",
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
		"descriptions": {1: "전 무공 유효레벨 +2"},
		"detail": "투자한 모든 무공의 흐름을 하나로 합쳐 유효레벨을 올립니다.",
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
		"descriptions": {1: "혼딸기 강신 60초"},
		"detail": "커맨드 입력으로 일정 시간 혼딸기 신령을 몸에 내립니다.",
		"icon_color": Color(1.0, 72.0 / 255.0, 90.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "horn_strawberry_mask",
	},
	"odins_eye": {
		"name": "윤회천안",
		"max_level": 1,
		"descriptions": {1: "실점 무효·악귀 부활 35%"},
		"detail": "실점 시 일정 확률로 그 실점을 무효화하고 악귀로 되살아납니다. 되살아난 뒤에는 이동과 활주가 둔해지고, 다시 실점하면 패배합니다.",
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
		"detail": "괘상에 따라 패들 크기·최대 기력·이동 속도 증가 또는 액티브 아이템·초식·활주 재충전 시간 감소 천운을 얻습니다.",
		"icon_color": Color(1.0, 235.0 / 255.0, 150.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "angel_blessing",
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
		"name": "차원개방",
		"description": "잠시 아이템 스폰 흐름을 강화",
		"detail": "3초 동안 중앙 차원문에서 아이템이 0.5~1초 간격으로 쏟아집니다.",
		"icon_color": Color(1.0, 100.0 / 255.0, 1.0),
		"tree": "instant",
		"is_instant": true,
	},
	"instant_treasure_hunt": {
		"name": "보물탐색",
		"description": "보물을 탐색하여 보상을 노립니다",
		"detail": "고대의 천기보도를 따라 보상을 탐색합니다. 신화 아이템 20%, 패시브 아이템 60%, 꽝 20%를 기본으로 하며, 천기보도 레벨당 신화 보상 확률이 3% 증가합니다.",
		"icon_color": Color(1.0, 215.0 / 255.0, 0.0),
		"tree": "instant",
		"is_instant": true,
		"is_unique": true,
		"rarity": "legendary",
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
# 없다 — 아이템 스폰 강화(차원개방), 기력·활주·쿨 완충(풀게이징), 빈 액티브
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
	"description": "스타포인트로 무공을 획득하는 대신 골드로 변환합니다",
	"detail": "무공을 포기하고 즉시 500골드를 인게임 골드로 획득합니다.",
	"icon_color": Color(1.0, 215.0 / 255.0, 0.0),
	"tree": "instant",
	"character_restriction": "",
	"is_instant": true,
	"is_gold_conversion": true,
	# 오퍼 lane 메타: 시스템 카드 로테이션(융합·신비의 주사위)이 골드 lane을
	# 판별/스왑하는 계약 필드 — 골드는 항상 보호 lane으로 남고, 로테이션은
	# 카탈로그 밖(오퍼 후처리)에서만 일어난다.
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

	choices = _filter_unlock_slot_budget(choices, normalized, runtime_levels)
	if PerkConversionFlags.is_enabled():
		choices = _filter_perk_slot_budget(choices, runtime_levels, _registry)
	_append_lingpet_guardian_enhance_choice(choices, owner, _registry)
	if not exclude_instant:
		_append_instant_choices(choices, owner)
	choices = _filter_tower_unlock_choices(choices, _registry)

	choices = _filter_lingpet_owned_gate(choices, owner)
	var full_chosik_swap_reservation := _extract_full_chosik_swap_reserved_choice(choices)
	var full_chosik_swap_reserved: Array = full_chosik_swap_reservation.get("reserved", []) as Array
	choices = full_chosik_swap_reservation.get("remaining", []) as Array
	var guardian_enhance_reservation := _extract_guardian_enhance_reserved_choice(choices)
	var guardian_enhance_reserved: Array = guardian_enhance_reservation.get("reserved", []) as Array
	choices = guardian_enhance_reservation.get("remaining", []) as Array
	var mythic_reserved: Array = []
	var mythic_count := 0
	if PerkConversionFlags.is_enabled() and has_open_perk_slot(runtime_levels, _registry):
		var mythic_offer_chances := _get_mythic_offer_chances(runtime_levels)
		var jackpot_chance := float(mythic_offer_chances.get("jackpot", 0.0))
		if randf() < jackpot_chance:
			mythic_count = target_choice_count
	if mythic_count > 0:
		mythic_reserved = _build_unowned_mythic_choices(runtime_levels, normalized, mythic_count)
	# 예약 체인(fill order 계약: mythic -> dash token -> owned upgrades ->
	# ring-core -> shuffled). 대쉬토큰은 전용 per-level 부스트 lane(소유 후
	# generic 예약과 이중 등장 금지), 소유 업그레이드는 만석=target-1(마지막
	# 일반 lane 1개는 교체형 오퍼(융합/주사위) 진입로로 항상 남김) /
	# 빈슬롯=partial 확률 1장. 융합 슬롯 환급이 슬롯을 열면 만석 예약은
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
	for guardian_choice in guardian_enhance_reserved:
		if result.size() >= target_choice_count:
			break
		result.append(_with_offer_metadata(guardian_choice, "guardian_enhance_reserved", true))
	for swap_choice in full_chosik_swap_reserved:
		if result.size() >= target_choice_count:
			break
		result.append(_with_offer_metadata(swap_choice, "full_chosik_swap_reserved", true))
	for mythic_choice in mythic_reserved:
		if result.size() >= target_choice_count:
			break
		result.append(_with_offer_metadata(mythic_choice, "mythic_jackpot", true))
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
	if TowerAscentUnlockFilter.is_content_unlocked(
		_registry,
		TowerAscentUnlockFilter.CONTENT_RUNTIME_PERK,
		"convert_to_gold"
	):
		var gold_choice := GOLD_CHOICE.duplicate(true)
		gold_choice["id"] = "convert_to_gold"
		result.append(LanguageSettings.localize_perk_data(gold_choice))
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
	if skill_id == CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID:
		var common_unlock := CommonSkillCatalog.get_unlock_perk_data()
		common_unlock["id"] = skill_id
		return common_unlock
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
		# 카드 정의 단일 소스는 오퍼 플래너의 build_card — 카탈로그는 조회
		# 해석만 담당하고 로테이션 로직은 갖지 않는다(get_choices 비등장).
		return load("res://scripts/characters/mystic_dice_offer_planner.gd").build_card()
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
	if _perk_display_name_index.is_empty():
		for pool_value: Variant in [
			COMMON_PERKS,
			SMASHER_PERKS,
			VIPER_PERKS,
			SOLDIER_PERKS,
			CONVERTED_PERKS,
			CONVERTED_MYTHIC_PERKS,
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
	# 신비의 주사위: 모달 전용 시스템 카드 — 퍽 슬롯을 절대 소모하지 않는다
	# (영구 스탯은 슬롯 밖 run-scope 누적).
	if perk_id == "mystic_dice" or bool(perk_data.get("is_mystic_dice", false)):
		return false
	if bool(perk_data.get("is_instant", false)) or str(perk_data.get("tree", "")) == "instant":
		return false
	if str(perk_data.get("unlocks_skill", "")).strip_edges() != "":
		return false
	# 슬롯 확장 퍽은 flag ON에서만 비소모(자신은 슬롯을 먹지 않고 최대치만
	# 올림 — 가득 상태에서도 오퍼에 등장하는 탈출 밸브). OFF에서는 레거시
	# 장신구 퍽 의미라 기존 소모 규칙을 유지한다.
	if PerkConversionFlags.is_enabled() and perk_id == SLOT_EXPANSION_PERK_ID:
		return false
	if bool(LINGPET_GATED_CHOICE_IDS.get(perk_id, false)):
		return false
	return int(perk_data.get("max_level", 0)) > 0


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


func has_open_perk_slot(runtime_levels: Dictionary, slot_context: Object = null) -> bool:
	return count_owned_slot_perks(runtime_levels, slot_context) < get_perk_slot_limit(runtime_levels)


func get_perk_slot_limit(runtime_levels: Dictionary) -> int:
	# flag OFF에서는 고정 6(UI가 flag와 무관하게 조회하므로 여기서 중앙
	# 격리). ON에서만 슬롯 확장 퍽의 RAW 레벨을 반영한다 — 유효레벨
	# 보너스(초월자의 왕관·현자의 계약·점화 등)로 최대 슬롯이 늘면 안 됨.
	if not PerkConversionFlags.is_enabled():
		return BASE_PERK_SLOT_LIMIT
	var expansion_level: int = maxi(0, int(runtime_levels.get(SLOT_EXPANSION_PERK_ID, 0)))
	return clampi(BASE_PERK_SLOT_LIMIT + expansion_level, BASE_PERK_SLOT_LIMIT, MAX_PERK_SLOT_LIMIT)


func get_perk_slot_status(runtime_levels: Dictionary, slot_context: Object = null) -> Dictionary:
	var count := count_owned_slot_perks(runtime_levels, slot_context)
	var limit := get_perk_slot_limit(runtime_levels)
	return {
		"count": count,
		"limit": limit,
		"is_full": count >= limit,
	}


func get_debug_perk_entries(_character_type: String = "") -> Array:
	var entries: Array = []
	_append_debug_pool_entries(entries, COMMON_PERKS, "common")
	var soul_summon_entry: Dictionary = CommonSkillCatalog.get_unlock_perk_data()
	soul_summon_entry["id"] = CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID
	soul_summon_entry["debug_group"] = "common"
	entries.append(soul_summon_entry)
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
	# 신비의 주사위: 디버그 피커에는 검사용으로 노출하되, 직접 부여는
	# RuntimePerkDebugGrants가 modal_only_choice로 거부한다.
	var mystic_dice_choice: Dictionary = get_perk_data("mystic_dice")
	mystic_dice_choice["debug_group"] = "instant"
	entries.append(mystic_dice_choice)
	var guardian_enhance_choice := LingpetGuardianEnhanceOfferEngine.get_perk_data()
	guardian_enhance_choice["id"] = LINGPET_GUARDIAN_ENHANCE_CHOICE_ID
	guardian_enhance_choice["debug_group"] = "lingpet"
	entries.append(guardian_enhance_choice)
	entries.sort_custom(func(a, b): return _debug_sort_key(a) < _debug_sort_key(b))
	return entries


func _append_pool_choices(output: Array, pool: Dictionary, runtime_levels: Dictionary, character_restriction: String) -> void:
	for skill_id in pool.keys():
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


func _filter_unlock_slot_budget(choices: Array, character_type: String, runtime_levels: Dictionary) -> Array:
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

	var filtered: Array = []
	var swap_candidates: Array = []
	for choice in choices:
		if str(choice.get("id", "")) == CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID:
			filtered.append(choice)
			continue
		if str(choice.get("unlocks_skill", "")) == "":
			filtered.append(choice)
		else:
			swap_candidates.append(choice)
	if not swap_candidates.is_empty() and _roll_full_chosik_swap_offer():
		swap_candidates.shuffle()
		var reserved_choice: Dictionary = (swap_candidates[0] as Dictionary).duplicate(true)
		reserved_choice[FULL_CHOSIK_SWAP_PRIORITY_KEY] = true
		filtered.append(reserved_choice)
	return filtered


func set_full_chosik_swap_offer_roll_for_tests(roll_callable: Callable) -> void:
	_full_chosik_swap_offer_roll_for_tests = roll_callable


func clear_full_chosik_swap_offer_roll_for_tests() -> void:
	_full_chosik_swap_offer_roll_for_tests = Callable()


func _roll_full_chosik_swap_offer() -> bool:
	if _full_chosik_swap_offer_roll_for_tests.is_valid():
		return float(_full_chosik_swap_offer_roll_for_tests.call()) < FULL_CHOSIK_SWAP_OFFER_CHANCE
	return randf() < FULL_CHOSIK_SWAP_OFFER_CHANCE


func _filter_perk_slot_budget(choices: Array, runtime_levels: Dictionary, slot_context: Object = null) -> Array:
	var occupied_slots := count_owned_slot_perks(runtime_levels, slot_context)
	var filtered: Array = []
	for value in choices:
		if not (value is Dictionary):
			filtered.append(value)
			continue
		var choice: Dictionary = value
		if not is_slot_consuming_perk(choice):
			filtered.append(choice)
			continue
		var choice_id: String = str(choice.get("id", ""))
		var current_level: int = int(runtime_levels.get(choice_id, choice.get("current_level", 0)))
		var next_level: int = int(choice.get("next_level", current_level + 1))
		var current_cost: int = get_slot_cost_for_level(choice, current_level)
		var next_cost: int = get_slot_cost_for_level(choice, next_level)
		var extra_slots: int = max(0, next_cost - current_cost)
		if occupied_slots + extra_slots <= get_perk_slot_limit(runtime_levels):
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
	var normalized: String = character_type.strip_edges().to_lower()
	if normalized == "soldier" or normalized == "commando":
		return "soldier"
	if normalized == "optimus" or normalized == "io":
		return "optimus"
	if normalized == "viper":
		return "viper"
	return "smasher"
