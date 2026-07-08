extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetRingCoreRules := preload("res://scripts/lingpet/lingpet_ring_core_rules.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PlazaLingpetStoreTransactions := preload("res://scripts/plaza/plaza_lingpet_store_transactions.gd")

const BASE_CHOICE_COUNT := 3
const PERK_SLOT_LIMIT := 6
const LINGPET_AFFINITY_CHIP_CHOICE_ID := "lingpet_affinity_chip"
const LINGPET_RING_CORE_UPGRADE_CHOICE_ID := "lingpet_ring_core_upgrade"
const LINGPET_RING_CORE_ICON_ID_PREFIX := "lingpet_ring_core_upgrade_tier_"
const LINGPET_AFFINITY_CHIP_MIN_RING_CORE_TIER := 1
const LINGPET_RING_CORE_EARLY_RESERVE_BY_TIER := [1, 1, 1, 0, 0, 0, 0]
const LINGPET_RING_CORE_PRIORITY_KEY := "_lingpet_ring_core_reserved"
const LINGPET_GATED_CHOICE_IDS := {
	LINGPET_AFFINITY_CHIP_CHOICE_ID: true,
	LINGPET_RING_CORE_UPGRADE_CHOICE_ID: true,
}
const LINGPET_RING_CORE_UPGRADE_PERK := {
	"name": "링코어 강화",
	"max_level": LingpetRingCoreRules.MAX_RING_CORE_TIER,
	"descriptions": {
		1: "링코어를 스탠다드로 강화합니다.",
		2: "링코어를 부스트로 강화합니다.",
		3: "링코어를 하이퍼로 강화합니다.",
		4: "링코어를 오버드라이브로 강화합니다.",
		5: "링코어를 얼티밋으로 강화합니다.",
		6: "링코어를 제니스로 강화합니다.",
	},
	"detail": "골드 없이 이번 런의 링코어를 다음 티어로 강화합니다. 친밀도 임시 상한이 5레벨씩 올라가며, 새 런에서 초기화됩니다.",
	"icon_color": Color(1.0, 210.0 / 255.0, 82.0 / 255.0),
	"tree": "lingpet",
	"is_lingpet_ring_core_upgrade": true,
}
const LINGPET_AFFINITY_CHIP_PERK := {
	"name": "강화칩",
	"max_level": LingpetAffinityState.MAX_ENHANCEMENT_CHIPS,
	"descriptions": {
		1: "이번 런의 링펫 친밀도 획득량 +20%",
		2: "이번 런의 링펫 친밀도 획득량 +40%",
		3: "이번 런의 링펫 친밀도 획득량 +60%",
		4: "이번 런의 링펫 친밀도 획득량 +80%",
		5: "이번 런의 링펫 친밀도 획득량 +100%",
	},
	"detail": "링펫과 함께 싸우는 동안 친밀도 수입을 증폭합니다. 최대 5개까지 누적되며 새 런에서 초기화됩니다.",
	"icon_color": Color(90.0 / 255.0, 220.0 / 255.0, 1.0),
	"tree": "lingpet",
	"is_lingpet_affinity_chip": true,
}

const COMMON_PERKS := {
	"dash_lightweight": {
		"name": "경량화",
		"max_level": 5,
		"descriptions": {
			1: "대쉬 쿨타임 12% 감소",
			2: "대쉬 쿨타임 24% 감소",
			3: "대쉬 쿨타임 36% 감소",
			4: "대쉬 쿨타임 48% 감소",
			5: "대쉬 쿨타임 60% 감소",
		},
		"detail": "빨간 대쉬 토큰이 더 빠르게 돌아옵니다.",
		"icon_color": Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
		"tree": "dash",
	},
	"dash_module_control": {
		"name": "모듈제어",
		"max_level": 5,
		"descriptions": {
			1: "대쉬 후딜 18% 감소",
			2: "대쉬 후딜 36% 감소",
			3: "대쉬 후딜 54% 감소",
			4: "대쉬 후딜 72% 감소",
			5: "대쉬 후딜 90% 감소",
		},
		"detail": "대쉬 후 경직을 줄여 다음 행동이 빨라집니다.",
		"icon_color": Color(150.0 / 255.0, 100.0 / 255.0, 1.0),
		"tree": "dash",
	},
	"dash_jump": {
		"name": "도약",
		"max_level": 5,
		"descriptions": {
			1: "대쉬 거리 7% 증가",
			2: "대쉬 거리 14% 증가",
			3: "대쉬 거리 21% 증가",
			4: "대쉬 거리 28% 증가",
			5: "대쉬 거리 35% 증가",
		},
		"detail": "한 번의 대쉬로 더 멀리 움직입니다.",
		"icon_color": Color(100.0 / 255.0, 1.0, 150.0 / 255.0),
		"tree": "dash",
	},
	"dash_acceleration": {
		"name": "버스트업",
		"max_level": 5,
		"descriptions": {
			1: "대쉬시 패들 크기 70% 증가",
			2: "대쉬시 패들 크기 140% 증가",
			3: "대쉬시 패들 크기 210% 증가",
			4: "대쉬시 패들 크기 280% 증가",
			5: "대쉬시 패들 크기 350% 증가",
		},
		"detail": "대쉬 순간 패들이 폭발적으로 확장되어 더 넓은 범위의 공을 받아냅니다.",
		"icon_color": Color(1.0, 100.0 / 255.0, 50.0 / 255.0),
		"tree": "dash",
	},
	"dash_amplification": {
		"name": "대쉬토큰",
		"max_level": 3,
		"descriptions": {
			1: "대쉬토큰 슬롯 +1",
			2: "대쉬토큰 슬롯 +2",
			3: "대쉬토큰 슬롯 +3",
		},
		"detail": "레벨마다 대쉬토큰 최대치를 1칸 늘리고, 같은 수만큼 퍽 슬롯을 사용합니다.",
		"icon_color": Color(1.0, 200.0 / 255.0, 50.0 / 255.0),
		"tree": "dash",
	},
	"item_luck": {
		"name": "행운",
		"max_level": 5,
		"descriptions": {
			1: "아이템 스폰 대기 12% 감소",
			2: "아이템 스폰 대기 24% 감소",
			3: "아이템 스폰 대기 36% 감소",
			4: "아이템 스폰 대기 48% 감소",
			5: "아이템 스폰 대기 60% 감소",
		},
		"detail": "필드 아이템이 더 자주 나타납니다.",
		"icon_color": Color(1.0, 215.0 / 255.0, 0.0),
		"tree": "item",
	},
	"item_cooldown_mastery": {
		"name": "숙련",
		"max_level": 5,
		"descriptions": {
			1: "액티브 아이템 쿨타임 13% 감소",
			2: "액티브 아이템 쿨타임 26% 감소",
			3: "액티브 아이템 쿨타임 39% 감소",
			4: "액티브 아이템 쿨타임 52% 감소",
			5: "액티브 아이템 쿨타임 65% 감소",
		},
		"detail": "액티브 아이템 사용 간격이 짧아집니다.",
		"icon_color": Color(100.0 / 255.0, 150.0 / 255.0, 1.0),
		"tree": "item",
	},
	"item_gauge_mastery": {
		"name": "숙달",
		"max_level": 5,
		"descriptions": {
			1: "액티브 사용시 게이지 +15",
			2: "액티브 사용시 게이지 +30",
			3: "액티브 사용시 게이지 +45",
			4: "액티브 사용시 게이지 +60",
			5: "액티브 사용시 게이지 +75",
		},
		"detail": "액티브 아이템을 쓸 때 스킬 게이지를 얻습니다.",
		"icon_color": Color(150.0 / 255.0, 1.0, 100.0 / 255.0),
		"tree": "item",
	},
	"item_caffeine": {
		"name": "카페인",
		"max_level": 5,
		"descriptions": {
			1: "타이머형 아이템 지속 30% 증가",
			2: "타이머형 아이템 지속 60% 증가",
			3: "타이머형 아이템 지속 90% 증가",
			4: "타이머형 아이템 지속 120% 증가",
			5: "타이머형 아이템 지속 150% 증가",
		},
		"detail": "카페인 부스트로 지속시간형 액티브 아이템 효과가 더 오래 지속됩니다.",
		"icon_color": Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0),
		"tree": "item",
	},
	"item_polish": {
		"name": "연마",
		"max_level": 5,
		"descriptions": {
			1: "패시브 롤옵션 효율 12% 증가",
			2: "패시브 롤옵션 효율 24% 증가",
			3: "패시브 롤옵션 효율 36% 증가",
			4: "패시브 롤옵션 효율 48% 증가",
			5: "패시브 롤옵션 효율 60% 증가",
		},
		"detail": "아이템을 연마하여 패시브 효과가 강화됩니다.",
		"icon_color": Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0),
		"tree": "item",
	},
	"item_recycle": {
		"name": "연금술",
		"max_level": 5,
		"descriptions": {
			1: "아이템 유지 확률 7%",
			2: "아이템 유지 확률 14%",
			3: "아이템 유지 확률 21%",
			4: "아이템 유지 확률 28%",
			5: "아이템 유지 확률 35%",
		},
		"detail": "연금술로 사용한 아이템이 확률적으로 유지됩니다.",
		"icon_color": Color(148.0 / 255.0, 0.0, 211.0 / 255.0),
		"tree": "item",
	},
	"downtown_treasure_map": {
		"name": "보물지도",
		"max_level": 5,
		"descriptions": {
			1: "신화 확률 +150%, 패시브 드랍 +3%, 보물탐색 신화 +3%",
			2: "신화 확률 +300%, 패시브 드랍 +6%, 보물탐색 신화 +6%",
			3: "신화 확률 +450%, 패시브 드랍 +9%, 보물탐색 신화 +9%",
			4: "신화 확률 +600%, 패시브 드랍 +12%, 보물탐색 신화 +12%",
			5: "신화 확률 +750%, 패시브 드랍 +15%, 보물탐색 신화 +15%",
		},
		"detail": "신화 아이템 획득 확률과 패시브 아이템 드랍 비율이 증가합니다. 즉시형 퍽 '보물탐색'의 신화 보상 확률도 레벨당 3% 증가합니다.",
		"icon_color": Color(1.0, 223.0 / 255.0, 0.0),
		"tree": "downtown",
	},
	"item_bag_expansion": {
		"name": "가방확장",
		"max_level": 5,
		"descriptions": {
			1: "액티브 슬롯 +1",
			2: "액티브 슬롯 +2",
			3: "액티브 슬롯 +3",
			4: "액티브 슬롯 +4",
			5: "액티브 슬롯 +5",
		},
		"detail": "더 많은 액티브 아이템을 보관할 수 있습니다.",
		"icon_color": Color(180.0 / 255.0, 120.0 / 255.0, 80.0 / 255.0),
		"tree": "item",
	},
	"common_swiftness": {
		"name": "신속",
		"max_level": 5,
		"descriptions": {
			1: "이동속도 6% 증가",
			2: "이동속도 12% 증가",
			3: "이동속도 18% 증가",
			4: "이동속도 24% 증가",
			5: "이동속도 30% 증가",
		},
		"detail": "발걸음이 가벼워져 이동 속도가 증가합니다.",
		"icon_color": Color(100.0 / 255.0, 1.0, 180.0 / 255.0),
		"tree": "common",
	},
	"common_expansion": {
		"name": "확장",
		"max_level": 2,
		"descriptions": {
			1: "장신구 슬롯 +1",
			2: "장신구 슬롯 +2",
		},
		"detail": "장신구 슬롯을 추가로 활성화합니다.",
		"icon_color": Color(200.0 / 255.0, 150.0 / 255.0, 1.0),
		"tree": "common",
	},
	"common_bulk_up": {
		"name": "벌크업",
		"max_level": 5,
		"descriptions": {
			1: "패들 크기 6% 증가",
			2: "패들 크기 12% 증가",
			3: "패들 크기 18% 증가",
			4: "패들 크기 24% 증가",
			5: "패들 크기 30% 증가",
		},
		"detail": "패들이 커져 공을 받아치기 쉬워집니다.",
		"icon_color": Color(1.0, 150.0 / 255.0, 80.0 / 255.0),
		"tree": "common",
	},
	"perk_boost_charge": {
		"name": "부스트차징",
		"max_level": 5,
		"descriptions": {
			1: "확률 +7%, 발동 시 다음 대쉬 무료 + 토큰 충전 -90%",
			2: "확률 +14%, 발동 시 다음 대쉬 무료 + 토큰 충전 -90%",
			3: "확률 +21%, 발동 시 다음 대쉬 무료 + 토큰 충전 -90%",
			4: "확률 +28%, 발동 시 다음 대쉬 무료 + 토큰 충전 -90%",
			5: "확률 +35%, 발동 시 다음 대쉬 무료 + 토큰 충전 -90%",
		},
		"detail": "발동 시 다음 대쉬의 토큰 소모를 1회 무효화하고, 충전 중인 대쉬 토큰 1개의 남은 충전 쿨타임을 90% 줄입니다.",
		"icon_color": Color(80.0 / 255.0, 160.0 / 255.0, 1.0),
		"tree": "common",
	},
	"perk_laurel_shield": {
		"name": "월계수잎",
		"max_level": 5,
		"descriptions": {
			1: "월계수 잎 1개 보호",
			2: "월계수 잎 2개 보호",
			3: "월계수 잎 3개 보호",
			4: "월계수 잎 4개 보호",
			5: "월계수 잎 5개 보호",
		},
		"detail": "공을 막아주는 신성한 월계수잎이 주변을 보호합니다.",
		"icon_color": Color(100.0 / 255.0, 200.0 / 255.0, 100.0 / 255.0),
		"tree": "common",
	},
	"common_training": {
		"name": "단련",
		"max_level": 5,
		"descriptions": {
			1: "모든 스킬 쿨타임 8% 감소",
			2: "모든 스킬 쿨타임 16% 감소",
			3: "모든 스킬 쿨타임 24% 감소",
			4: "모든 스킬 쿨타임 32% 감소",
			5: "모든 스킬 쿨타임 40% 감소",
		},
		"detail": "플레이어 스킬을 더 빠르게 다시 사용할 수 있습니다.",
		"icon_color": Color(1.0, 160.0 / 255.0, 80.0 / 255.0),
		"tree": "common",
	},
}

const SMASHER_PERKS := {
	"dash_spirit": {
		"name": "대쉬스피릿",
		"max_level": 5,
		"descriptions": {
			1: "대쉬시 7% 확률로 레이저 잔상",
			2: "대쉬시 14% 확률로 레이저 잔상",
			3: "대쉬시 21% 확률로 레이저 잔상",
			4: "대쉬시 28% 확률로 레이저 잔상",
			5: "대쉬시 35% 확률로 레이저 잔상",
		},
		"detail": "대쉬 중 레이저 잔상이 공을 막아줄 수 있습니다.",
		"icon_color": Color(0.0, 1.0, 1.0),
		"tree": "smasher",
		"character_restriction": "smasher",
	},
	"unlock_magnum_grip": {
		"name": "매그넘 그립 해금",
		"max_level": 1,
		"descriptions": {1: "매그넘 그립 스킬 해금"},
		"detail": "좌+우 동시 입력으로 자기장을 형성해 공을 끌어당기는 스킬을 해금합니다.",
		"icon_color": Color(200.0 / 255.0, 140.0 / 255.0, 1.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "magnum_grip",
	},
	"unlock_plasma": {
		"name": "플라즈마 해금",
		"max_level": 1,
		"descriptions": {1: "플라즈마 스킬 해금"},
		"detail": "W/위 방향으로 플라즈마 구체를 발사하는 스킬을 장착합니다.",
		"icon_color": Color(0.0, 200.0 / 255.0, 1.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "plasma",
	},
	"unlock_recovery_skill": {
		"name": "리커버리 해금",
		"max_level": 1,
		"descriptions": {1: "리커버리 스킬 해금"},
		"detail": "대쉬 후딜 제거와 짧은 이동 보너스를 주는 스킬을 장착합니다.",
		"icon_color": Color(50.0 / 255.0, 1.0, 150.0 / 255.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "recovery",
	},
	"unlock_cleanse": {
		"name": "클렌즈 해금",
		"max_level": 1,
		"descriptions": {1: "클렌즈 스킬 해금"},
		"detail": "상태이상을 즉시 해제하고 잠시 면역을 얻는 스킬을 장착합니다.",
		"icon_color": Color(1.0, 220.0 / 255.0, 115.0 / 255.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "cleanse",
	},
	"unlock_shield_kiting": {
		"name": "쉴드카이팅 해금",
		"max_level": 1,
		"descriptions": {1: "쉴드카이팅 스킬 해금"},
		"detail": "에너지 쉴드를 던져 공을 유도하는 스킬을 장착합니다.",
		"icon_color": Color(110.0 / 255.0, 210.0 / 255.0, 1.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "shield_kiting",
	},
	"unlock_ghost_shot": {
		"name": "고스트스매싱 해금",
		"max_level": 1,
		"descriptions": {1: "고스트스매싱 스킬 해금"},
		"detail": "게이지 420 이상에서 파워스매싱 입력으로 공을 기괴하게 난무시키고 보스 쪽으로 재발사하는 스킬을 해금합니다.",
		"icon_color": Color(120.0 / 255.0, 50.0 / 255.0, 180.0 / 255.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "ghost_shot",
	},
	"unlock_warp_gate": {
		"name": "워프게이트 해금",
		"max_level": 1,
		"descriptions": {1: "워프게이트 스킬 해금"},
		"detail": "S 또는 ↓ 키를 0.5초 이상 홀드하면 좌/우 벽을 타넘어 반대편으로 순간이동하는 차원 포털 스킬을 해금합니다. 벽 통과는 추가 게이지를 소모하지 않습니다.",
		"icon_color": Color(200.0 / 255.0, 110.0 / 255.0, 1.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "warp_gate",
	},
	"unlock_smasher_wheel": {
		"name": "스매셔휠 해금",
		"max_level": 1,
		"descriptions": {1: "스매셔휠 스킬 해금"},
		"detail": "A→W→D 또는 D→W→A 순서 입력으로 1.2초간 회전하며, 공에 닿으면 고속 커브샷으로 재발사하는 스킬을 해금합니다.",
		"icon_color": Color(1.0, 165.0 / 255.0, 60.0 / 255.0),
		"tree": "smasher_unlock",
		"character_restriction": "smasher",
		"unlocks_skill": "smasher_wheel",
	},
	"extension_gear": {
		"name": "연장기어",
		"max_level": 5,
		"descriptions": {
			1: "리커버리/클렌즈/워프게이트 지속시간 +25%",
			2: "리커버리/클렌즈/워프게이트 지속시간 +50%",
			3: "리커버리/클렌즈/워프게이트 지속시간 +75%",
			4: "리커버리/클렌즈/워프게이트 지속시간 +100%",
			5: "리커버리/클렌즈/워프게이트 지속시간 +125%",
		},
		"detail": "스매셔의 지속형 유틸리티 스킬 시간이 길어집니다.",
		"icon_color": Color(120.0 / 255.0, 230.0 / 255.0, 180.0 / 255.0),
		"tree": "smasher",
		"character_restriction": "smasher",
	},
	"combo_amplifier_chip": {
		"name": "콤보증폭칩",
		"max_level": 5,
		"descriptions": {
			1: "콤보 효과 증폭: 드라이브 공속+90%, 커브+5%, 파워스매시 공속+45%, 초기부스트 감쇄 -10%",
			2: "콤보 효과 증폭: 드라이브 공속+180%, 커브+10%, 파워스매시 공속+90%, 초기부스트 감쇄 -20%",
			3: "콤보 효과 증폭: 드라이브 공속+270%, 커브+15%, 파워스매시 공속+135%, 초기부스트 감쇄 -30%",
			4: "콤보 효과 증폭: 드라이브 공속+360%, 커브+15%(캡), 파워스매시 공속+180%, 초기부스트 감쇄 -40%",
			5: "콤보 효과 증폭: 드라이브 공속+450%, 커브+15%(캡), 파워스매시 공속+225%, 초기부스트 감쇄 -50%(캡)",
		},
		"detail": "콤보 소모형 드라이브/파워스매싱의 콤보 비례 증가율을 추가로 증폭합니다. 공속 증폭은 레벨에 따라 계속 증가하지만, 드라이브 커브 증폭은 Lv3에서 캡됩니다(밸런스 보호). 또한 파워스매싱의 초기 부스트 감쇄가 완만해져 폭발력이 더 오래 유지됩니다.",
		"icon_color": Color(1.0, 100.0 / 255.0, 200.0 / 255.0),
		"tree": "smasher",
		"character_restriction": "smasher",
	},
}

const VIPER_PERKS := {
	"unlock_nerve_strike": {
		"name": "베놈 엣지 해금",
		"max_level": 1,
		"descriptions": {1: "베놈 엣지 스킬 해금"},
		"detail": "에어 블레이드 연계기 '베놈 엣지'를 장착합니다.",
		"icon_color": Color(180.0 / 255.0, 0.0, 220.0 / 255.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "nerve_strike",
	},
	"unlock_dive_strike": {
		"name": "EMP 해금",
		"max_level": 1,
		"descriptions": {1: "EMP 스트라이크 스킬 해금"},
		"detail": "공중에서 강한 EMP 펄스를 떨어뜨리는 스킬을 장착합니다.",
		"icon_color": Color(1.0, 120.0 / 255.0, 50.0 / 255.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "dive_strike",
	},
	"unlock_chaos_spear": {
		"name": "카오스스피어 해금",
		"max_level": 1,
		"descriptions": {1: "카오스 스피어 스킬 해금"},
		"detail": "A-W-D 입력으로 블랙홀 창을 꽂는 스킬을 장착합니다.",
		"icon_color": Color(135.0 / 255.0, 70.0 / 255.0, 1.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "chaos_spear",
	},
	"unlock_dual_glitch": {
		"name": "듀얼글리치 해금",
		"max_level": 1,
		"descriptions": {1: "듀얼 글리치 스킬 해금"},
		"detail": "좌우 분신 패들을 소환하는 스킬을 장착합니다.",
		"icon_color": Color(60.0 / 255.0, 220.0 / 255.0, 150.0 / 255.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "dual_glitch",
	},
	"unlock_ignition_aura": {
		"name": "이그니션오라 해금",
		"max_level": 1,
		"descriptions": {1: "이그니션오라 스킬 해금"},
		"detail": "지상에서 홀드해 모든 투자 퍽을 잠시 강화하는 스킬을 장착합니다.",
		"icon_color": Color(1.0, 130.0 / 255.0, 40.0 / 255.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "ignition_aura",
	},
	"double_marshal_kick": {
		"name": "팬텀 킥",
		"max_level": 1,
		"descriptions": {1: "마샬 킥 적중 후 팬텀 킥 발동 가능"},
		"detail": "마샬 킥으로 공을 맞힌 뒤 S/아래 입력으로 2차 연계 팬텀 킥을 사용할 수 있습니다. 게이지 60, 쿨타임 40초.",
		"icon_color": Color(180.0 / 255.0, 0.0, 1.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "phantom_kick",
	},
	"core_flip": {
		"name": "화랑 킥",
		"max_level": 1,
		"descriptions": {
			1: "대쉬로 공을 맞춘 뒤 0.7초 이내 A+D 동시 입력으로 화랑 킥 발동",
		},
		"detail": "대쉬로 공을 맞춘 뒤 0.7초 이내에 A+D(또는 ←+→)를 동시에 누르면 화랑 킥이 발동됩니다.\n벽을 타고 반사각으로 공을 차며, 적중 시 마샬 킥(→팬텀 킥) 연계가 열립니다.\n게이지 120, 쿨타임 25초.",
		"icon_color": Color(1.0, 110.0 / 255.0, 200.0 / 255.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "core_flip",
	},
	"dark_blade": {
		"name": "다크 블레이드",
		"max_level": 1,
		"descriptions": {1: "공 타격 후 1초 내 공중 W/↑로 다크 블레이드 발동"},
		"detail": "쉐도우 백스텝, 마샬 킥, 팬텀 킥, 화랑 킥으로 공을 맞히면 1초간 다크 블레이드 연계 윈도우가 열리고 캐릭터가 붉게 빛납니다.\n그 안에 공중에서 W/↑를 누르면 검붉은 강화 검기를 발사합니다.\n검기가 공을 맞히면 마샬 킥 윈도우가 열리지만 팬텀 킥 윈도우는 직접 열지 않습니다.\n게이지 200, 쿨타임 45초.",
		"icon_color": Color(120.0 / 255.0, 0.0, 30.0 / 255.0),
		"tree": "viper_unlock",
		"character_restriction": "viper",
		"unlocks_skill": "dark_blade",
	},
	"jetpack_enhance": {
		"name": "제트팩 강화",
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
		"name": "킥 강화",
		"max_level": 5,
		"descriptions": {
			1: "킥 발사 정밀도 +8%, 공속 +12%, 준비 -7%",
			2: "킥 발사 정밀도 +16%, 공속 +24%, 준비 -14%",
			3: "킥 발사 정밀도 +24%, 공속 +36%, 준비 -21%, 용광로 넉백볼 10%",
			4: "킥 발사 정밀도 +32%, 공속 +48%, 준비 -28%, 용광로 넉백볼 20%",
			5: "킥 발사 정밀도 +40%, 공속 +60%, 준비 -35%, 용광로 넉백볼 30%",
		},
		"detail": "바이퍼 킥 계열 스킬의 정밀도, 공속, 준비동작을 강화합니다. Lv.3부터 킥 적중 시 확률로 공이 용광로 넉백볼이 되며, 보스가 가드하면 화재형 넉백 150%를 1회 적용합니다.",
		"icon_color": Color(1.0, 90.0 / 255.0, 130.0 / 255.0),
		"tree": "viper",
		"character_restriction": "viper",
	},
	"blade_amp": {
		"name": "검기증폭",
		"max_level": 5,
		"descriptions": {
			1: "검기 사거리/가로폭 +10%, 검기 속도 +10%",
			2: "검기 사거리/가로폭 +20%, 검기 속도 +20%",
			3: "검기 사거리/가로폭 +30%, 검기 속도 +30%, 유도검기",
			4: "검기 사거리/가로폭 +40%, 검기 속도 +40%, 유도검기",
			5: "검기 사거리/가로폭 +50%, 검기 속도 +50%, 추가 유도검기",
		},
		"detail": "에어 블레이드와 다크 블레이드의 검기를 강화합니다.",
		"icon_color": Color(180.0 / 255.0, 60.0 / 255.0, 220.0 / 255.0),
		"tree": "viper",
		"character_restriction": "viper",
	},
	"four_poisons": {
		"name": "사독",
		"max_level": 5,
		"descriptions": {
			1: "EMP/카오스 준비 -8%, EMP 수면 +5%, 베놈 혼란 +12%, 듀얼 지속 +7%",
			2: "EMP/카오스 준비 -16%, EMP 수면 +10%, 베놈 혼란 +24%, 듀얼 지속 +14%",
			3: "EMP/카오스 준비 -25%, EMP 수면 +15%, 베놈 혼란 +36%, 듀얼 지속 +20%, 듀얼 HP 3, 4스킬 쿨 -10%, 슈퍼아머",
			4: "EMP/카오스 준비 -33%, EMP 수면 +20%, 베놈 혼란 +48%, 듀얼 지속 +27%, 듀얼 HP 3, 4스킬 쿨 -15%, 슈퍼아머",
			5: "EMP/카오스 준비 -40%, EMP 수면 +25%, 베놈 혼란 +70%, 듀얼 지속 +20%, 듀얼 HP 4, 4스킬 쿨 -20%, 슈퍼아머, 분신 복제",
		},
		"detail": "EMP 스트라이크, 베놈 엣지, 카오스 스피어, 듀얼 글리치를 묶어 강화합니다.\nEMP/카오스 준비와 EMP 수면, 베놈 혼란, 듀얼 지속시간을 올립니다.\nLv.3부터 준비동작 슈퍼아머와 4스킬 쿨감이 켜지고 듀얼 분신 HP가 3이 됩니다.\nLv.5부터 듀얼 분신 HP 4, 분신 스킬 복제가 적용됩니다. 복제는 추가 게이지/쿨/골드를 만들지 않습니다.",
		"icon_color": Color(215.0 / 255.0, 70.0 / 255.0, 1.0),
		"tree": "viper",
		"character_restriction": "viper",
	},
}

const SOLDIER_PERKS := {
	"soldier_unlock_net_gun": {
		"name": "그물덫총",
		"max_level": 1,
		"descriptions": {1: "그물덫총 해금"},
		"detail": "그물덫총을 영구 해금하고 코만도 스킬구슬에 추가합니다. 탄환은 재장전 스킬로 1발씩 다시 채웁니다.",
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
		"descriptions": {1: "화력지원 해금"},
		"detail": "화력지원을 영구 해금하고 코만도 스킬구슬에 추가합니다. 호출권은 재장전 게이지가 끝까지 차면 보충됩니다.",
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
		"descriptions": {1: "볼링트랩 해금"},
		"detail": "볼링트랩을 영구 해금하고 코만도 스킬구슬에 추가합니다. 탄환은 재장전 스킬로 1발씩 다시 채웁니다.",
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
		"descriptions": {1: "자폭드론 해금"},
		"detail": "자폭드론을 영구 해금하고 코만도 스킬구슬에 추가합니다. 탄환은 재장전 스킬로 1발씩 다시 채웁니다.",
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
		"descriptions": {1: "바주카포 해금"},
		"detail": "바주카포를 영구 해금하고 코만도 스킬구슬에 추가합니다. 탄약은 재장전 스킬로 1발씩 다시 채웁니다.",
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
		"descriptions": {1: "AK-47 해금"},
		"detail": "AK-47을 영구 해금하고 코만도 스킬구슬에 추가합니다. 탄약과 지속시간은 재장전 게이지가 끝까지 차면 보충됩니다.",
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
		"descriptions": {1: "베레타 해금"},
		"detail": "기본 권총은 유지한 채 베레타를 별도 영구 화기류로 해금합니다. 베레타는 준비동작 없이 즉시 발사되며 권총보다 연사가 2배 빠르고 탄속 20%, 정확도 30%가 향상되고 탄약 12발은 재장전 스킬로만 보충합니다.",
		"icon_color": Color(140.0 / 255.0, 130.0 / 255.0, 120.0 / 255.0),
		"tree": "soldier_unlock",
		"character_restriction": "soldier",
		"is_weapon_unlock": true,
		"weapon_name": "commando_pistol",
		"unlocks_skill": "commando_pistol",
	},
	"pistol_enhance": {
		"name": "권총강화",
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
		"name": "별탐지기",
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
		"name": "역경의힘",
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
		"name": "부메랑장인",
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
		"name": "위험감지센서",
		"max_level": 5,
		"descriptions": {
			1: "자동대쉬 토큰 1개, 쿨타임 30초",
			2: "자동대쉬 토큰 1개, 쿨타임 26초",
			3: "자동대쉬 토큰 2개, 쿨타임 23초",
			4: "자동대쉬 토큰 2개, 쿨타임 19초",
			5: "자동대쉬 토큰 2개, 쿨타임 15초",
		},
		"detail": "위험 상황에서 자동대쉬 전용 토큰을 사용해 몸을 피합니다.",
		"icon_color": Color(150.0 / 255.0, 150.0 / 255.0, 1.0),
		"tree": "dash",
		"conversion_source": "sensor",
	},
	"gravitybelt": {
		"name": "무중력화",
		"max_level": 1,
		"descriptions": {1: "이동 입력 즉시 최대속도, 입력 해제 시 즉시 정지"},
		"detail": "이동 가속과 감속을 즉시 반응형 조작감으로 바꿉니다.",
		"icon_color": Color(120.0 / 255.0, 90.0 / 255.0, 1.0),
		"tree": "dash",
		"conversion_source": "gravitybelt",
	},
	"dowsing_pendulum": {
		"name": "다우징",
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
		"name": "통찰",
		"max_level": 3,
		"descriptions": {
			1: "퍽 선택지 보너스 발동 확률 40%",
			2: "퍽 선택지 보너스 발동 확률 70%",
			3: "퍽 선택지 보너스 발동 확률 100%",
		},
		"detail": "퍽 선택지가 열릴 때 확률적으로 선택지 하나를 더 보여줍니다.",
		"icon_color": Color(70.0 / 255.0, 210.0 / 255.0, 1.0),
		"tree": "item",
		"conversion_source": "dowsing_goggles",
	},
	"chargebag": {
		"name": "충전가방",
		"max_level": 5,
		"descriptions": {
			1: "벽 반사 게이지 +15%",
			2: "벽 반사 게이지 +25%",
			3: "벽 반사 게이지 +35%",
			4: "벽 반사 게이지 +45%",
			5: "벽 반사 게이지 +55%",
		},
		"detail": "공이 벽에 닿을 때마다 추가 게이지를 얻습니다.",
		"icon_color": Color(100.0 / 255.0, 1.0, 100.0 / 255.0),
		"tree": "item",
		"conversion_source": "chargebag",
	},
	"battery": {
		"name": "배터리팩",
		"max_level": 5,
		"descriptions": {
			1: "스테이지 전환 게이지 보존 40%",
			2: "스테이지 전환 게이지 보존 55%",
			3: "스테이지 전환 게이지 보존 70%",
			4: "스테이지 전환 게이지 보존 85%",
			5: "스테이지 전환 게이지 보존 100%",
		},
		"detail": "다음 스테이지로 넘어갈 때 현재 게이지 일부를 보존합니다.",
		"icon_color": Color(1.0, 1.0, 0.0),
		"tree": "item",
		"conversion_source": "battery",
	},
	"revival": {
		"name": "윤회",
		"max_level": 1,
		"descriptions": {1: "패배 직전 런당 1회 스테이지 재시작"},
		"detail": "패배 직전 한 번 발동해 게임 오버를 막고 스테이지를 다시 시작합니다.",
		"icon_color": Color(1.0, 0.0, 1.0),
		"tree": "common",
		"conversion_source": "revival",
	},
	"master": {
		"name": "벽돌장인",
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
		"name": "골드디거",
		"max_level": 5,
		"descriptions": {
			1: "골드 획득 +15%",
			2: "골드 획득 +25%",
			3: "골드 획득 +35%",
			4: "골드 획득 +45%",
			5: "골드 획득 +55%",
		},
		"detail": "전투 중 얻는 골드 보상을 늘립니다.",
		"icon_color": Color(1.0, 200.0 / 255.0, 50.0 / 255.0),
		"tree": "item",
		"conversion_source": "gold_digger",
	},
	"lucky_coin": {
		"name": "럭키코인",
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
		"name": "파편사출",
		"max_level": 5,
		"descriptions": {
			1: "발동 6%, 파편 4개, 넉백 Lv.1, 게이지 50 소모",
			2: "발동 9%, 파편 5개, 넉백 Lv.2, 게이지 44 소모",
			3: "발동 12%, 파편 6개, 넉백 Lv.3, 게이지 38 소모",
			4: "발동 14%, 파편 7개, 넉백 Lv.3, 게이지 31 소모",
			5: "발동 17%, 파편 8개, 넉백 Lv.4, 게이지 25 소모",
		},
		"detail": "공을 칠 때 게이지를 소모해 보스를 향한 파편을 사출합니다.",
		"icon_color": Color(1.0, 150.0 / 255.0, 80.0 / 255.0),
		"tree": "common",
		"conversion_source": "shrapnel_armor",
	},
	"fuel_pouch": {
		"name": "연료탱크",
		"max_level": 5,
		"descriptions": {
			1: "최대 게이지 +40",
			2: "최대 게이지 +65",
			3: "최대 게이지 +90",
			4: "최대 게이지 +115",
			5: "최대 게이지 +140",
		},
		"detail": "플레이어가 보유할 수 있는 최대 게이지를 늘립니다.",
		"icon_color": Color(180.0 / 255.0, 100.0 / 255.0, 40.0 / 255.0),
		"tree": "common",
		"conversion_source": "fuel_pouch",
	},
	"bluetooth_ring": {
		"name": "블루투스링",
		"max_level": 5,
		"descriptions": {
			1: "히트 게이지 +6%",
			2: "히트 게이지 +11%",
			3: "히트 게이지 +15%",
			4: "히트 게이지 +20%",
			5: "히트 게이지 +24%",
		},
		"detail": "패들로 공을 칠 때 얻는 게이지를 늘립니다.",
		"icon_color": Color(100.0 / 255.0, 150.0 / 255.0, 1.0),
		"tree": "common",
		"conversion_source": "bluetooth_ring",
	},
	"foul_whistle": {
		"name": "반칙호루라기",
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
		"name": "오토파일럿",
		"max_level": 1,
		"descriptions": {1: "회복/스톱워치/홀리베리어 자동 사용"},
		"detail": "위급 상황에서 특정 액티브 아이템을 자동으로 사용합니다.",
		"icon_color": Color(100.0 / 255.0, 150.0 / 255.0, 200.0 / 255.0),
		"tree": "item",
		"conversion_source": "smartphone",
	},
	"neural_helmet": {
		"name": "뉴럴링크",
		"max_level": 5,
		"descriptions": {
			1: "AI알약 게이지 비용 30 감소, 스폰 +100%",
			2: "AI알약 게이지 비용 40 감소, 스폰 +158%",
			3: "AI알약 게이지 비용 50 감소, 스폰 +215%",
			4: "AI알약 게이지 비용 60 감소, 스폰 +273%",
			5: "AI알약 게이지 비용 70 감소, 스폰 +330%",
		},
		"detail": "AI알약 액티브의 부담을 낮추고 필드 등장률을 높입니다.",
		"icon_color": Color(140.0 / 255.0, 180.0 / 255.0, 1.0),
		"tree": "item",
		"conversion_source": "neural_helmet",
	},
	"commando_arm": {
		"name": "투척병기",
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
		"name": "무지개장갑",
		"max_level": 5,
		"descriptions": {
			1: "공 히트 시 발동 3%, 진행 중 스킬 쿨타임 20% 감소",
			2: "공 히트 시 발동 5%, 진행 중 스킬 쿨타임 29% 감소",
			3: "공 히트 시 발동 8%, 진행 중 스킬 쿨타임 38% 감소",
			4: "공 히트 시 발동 10%, 진행 중 스킬 쿨타임 46% 감소",
			5: "공 히트 시 발동 12%, 진행 중 스킬 쿨타임 55% 감소",
		},
		"detail": "공을 받아칠 때 장착한 캐릭터 스킬의 남은 쿨타임을 줄일 수 있습니다.",
		"icon_color": Color(1.0, 170.0 / 255.0, 220.0 / 255.0),
		"tree": "common",
		"conversion_source": "rainbow_fur_glove",
	},
	"knee_pads": {
		"name": "킥차져",
		"max_level": 5,
		"descriptions": {
			1: "하프대쉬 히트 게이지 +20%",
			2: "하프대쉬 히트 게이지 +33%",
			3: "하프대쉬 히트 게이지 +45%",
			4: "하프대쉬 히트 게이지 +58%",
			5: "하프대쉬 히트 게이지 +70%",
		},
		"detail": "하프대쉬로 공을 맞출 때 추가 게이지를 얻습니다.",
		"icon_color": Color(80.0 / 255.0, 80.0 / 255.0, 100.0 / 255.0),
		"tree": "dash",
		"conversion_source": "knee_pads",
	},
	"soul_burst": {
		"name": "소울버스트",
		"max_level": 5,
		"descriptions": {
			1: "대쉬 토큰이 없을 때 풀대쉬 소모 170",
			2: "대쉬 토큰이 없을 때 풀대쉬 소모 153",
			3: "대쉬 토큰이 없을 때 풀대쉬 소모 135",
			4: "대쉬 토큰이 없을 때 풀대쉬 소모 118",
			5: "대쉬 토큰이 없을 때 풀대쉬 소모 100",
		},
		"detail": "대쉬 토큰이 없을 때 특수 게이지를 소모해 풀대쉬를 발동합니다.",
		"icon_color": Color(150.0 / 255.0, 80.0 / 255.0, 1.0),
		"tree": "dash",
		"conversion_source": "soul_burst",
	},
	"bulletproof_hat": {
		"name": "스턴저항",
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
		"name": "넉백저항",
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
		"name": "독안개",
		"max_level": 5,
		"descriptions": {
			1: "독안개 발동 20%, 지속 1.5초",
			2: "독안개 발동 29%, 지속 2.5초",
			3: "독안개 발동 38%, 지속 3.5초",
			4: "독안개 발동 46%, 지속 4.5초",
			5: "독안개 발동 55%, 지속 5.5초",
		},
		"detail": "화랑 킥으로 감염된 공을 보스가 막으면 독안개를 생성합니다.",
		"icon_color": Color(80.0 / 255.0, 200.0 / 255.0, 80.0 / 255.0),
		"tree": "viper",
		"character_restriction": "viper",
		"conversion_source": "venom_mist_gauntlet",
	},
	"speedgear": {
		"name": "보정제어",
		"max_level": 1,
		"descriptions": {1: "좌우 방향 전환 감속 2.5배"},
		"detail": "방향 전환 시 급격한 조작을 보정하는 이동 특성을 적용합니다.",
		"icon_color": Color(1.0, 150.0 / 255.0, 0.0),
		"tree": "dash",
		"conversion_source": "speedgear",
	},
	"sage_ring": {
		"name": "현자의 계약",
		"max_level": 3,
		"descriptions": {
			1: "투자한 퍽 유효 레벨 +1, 이동속도 -8%, 몸집 -6%",
			2: "투자한 퍽 유효 레벨 +2, 이동속도 -16%, 몸집 -12%",
			3: "투자한 퍽 유효 레벨 +3, 이동속도 -24%, 몸집 -18%",
		},
		"detail": "현자의 대가로 투자한 퍽들의 유효 레벨을 올리지만, 자신과 신화 퍽은 보너스를 받지 않습니다.",
		"icon_color": Color(160.0 / 255.0, 115.0 / 255.0, 1.0),
		"tree": "common",
		"effective_level_exempt": true,
		"conversion_source": "sage_ring",
	},
}

const CONVERTED_MYTHIC_PERKS := {
	"megingjord": {
		"name": "메긴교르드",
		"max_level": 1,
		"descriptions": {1: "퍽 추가선택 발동 40%"},
		"detail": "퍽 선택 시 추가 선택 기회를 얻습니다.",
		"icon_color": Color(1.0, 215.0 / 255.0, 75.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "megingjord",
	},
	"transcendent_crown": {
		"name": "초월자의 관",
		"max_level": 1,
		"descriptions": {1: "전 퍽 유효레벨 +2"},
		"detail": "투자한 퍽들의 유효레벨을 올립니다.",
		"icon_color": Color(1.0, 215.0 / 255.0, 100.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "transcendent_crown",
	},
	"ragnarok_hammer": {
		"name": "라그나로크",
		"max_level": 1,
		"descriptions": {1: "발동 30%, 스턴 1.0초, 공속 +25%, 게이지 30 소모"},
		"detail": "받아친 공에 라그나로크의 전기 스턴 힘을 실을 수 있습니다.",
		"icon_color": Color(120.0 / 255.0, 190.0 / 255.0, 1.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "ragnarok_hammer",
	},
	"hermes_shoes": {
		"name": "헤르메스의 축복",
		"max_level": 1,
		"descriptions": {1: "이동속도 +50%"},
		"detail": "신들의 전령처럼 플레이어 이동속도가 크게 증가합니다.",
		"icon_color": Color(100.0 / 255.0, 200.0 / 255.0, 1.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "hermes_shoes",
	},
	"poseidon_trident": {
		"name": "포세이돈",
		"max_level": 1,
		"descriptions": {1: "쿨타임 6초, 게이지 30, 소용돌이 200px"},
		"detail": "대쉬 회복 순간 좌우에 거대한 물회오리를 생성합니다.",
		"icon_color": Color(70.0 / 255.0, 185.0 / 255.0, 1.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "poseidon_trident",
	},
	"sacred_laurel": {
		"name": "대월계수",
		"max_level": 1,
		"descriptions": {1: "보호 월계수 잎 8개"},
		"detail": "보호 월계수 잎 여덟 장이 공을 막아 줍니다.",
		"icon_color": Color(135.0 / 255.0, 235.0 / 255.0, 150.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "sacred_laurel",
	},
	"heavenly_cape": {
		"name": "천상의 권능",
		"max_level": 1,
		"descriptions": {1: "스킬 슬롯 +1, 플레이어 스킬 쿨타임 15% 감소"},
		"detail": "스킬 구슬 슬롯을 늘리고 플레이어 스킬을 더 빠르게 돌립니다.",
		"icon_color": Color(190.0 / 255.0, 225.0 / 255.0, 1.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "heavenly_cape",
	},
	"horn_strawberry_mask": {
		"name": "뿔딸기의 계약",
		"max_level": 1,
		"descriptions": {1: "뿔딸기 변신 60초"},
		"detail": "커맨드 입력으로 일정 시간 뿔딸기로 변신합니다.",
		"icon_color": Color(1.0, 72.0 / 255.0, 90.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "horn_strawberry_mask",
	},
	"odins_eye": {
		"name": "오딘의 눈",
		"max_level": 1,
		"descriptions": {1: "실점 무효 부활 35%"},
		"detail": "실점 시 확률로 그 점수를 무효화하고 부활합니다.",
		"icon_color": Color(110.0 / 255.0, 100.0 / 255.0, 220.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "odins_eye",
	},
	"celestial_armor": {
		"name": "부동갑주",
		"max_level": 1,
		"descriptions": {1: "스턴 무시 65%, 게이지 30 소모"},
		"detail": "스턴이 들어올 때 확률로 게이지를 소모해 무시합니다.",
		"icon_color": Color(180.0 / 255.0, 200.0 / 255.0, 1.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "celestial_armor",
	},
	"baal_boots": {
		"name": "바알의 계약",
		"max_level": 1,
		"descriptions": {1: "날씨 흡수 시 게이지 400 회복"},
		"detail": "날씨 이벤트를 바알의 힘으로 흡수하고 게이지를 회복합니다.",
		"icon_color": Color(1.0, 90.0 / 255.0, 55.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "baal_boots",
	},
	"pandora_legacy": {
		"name": "판도라의 유산",
		"max_level": 1,
		"descriptions": {1: "라운드 승리 시 발동 55%"},
		"detail": "라운드 승리 보상에서 판도라의 선택 기회를 노립니다.",
		"icon_color": Color(150.0 / 255.0, 50.0 / 255.0, 200.0 / 255.0),
		"tree": "mythic",
		"rarity": "mythic",
		"effective_level_exempt": true,
		"conversion_source": "pandora_legacy",
	},
}

const INSTANT_PERKS := {
	"instant_gauge_full": {
		"name": "풀게이징",
		"description": "모든 게이지/쿨타임 즉시 완충",
		"detail": "스킬 게이지와 대쉬 토큰을 즉시 채우고 스킬 쿨타임을 초기화합니다.",
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
		"detail": "고대의 보물지도를 따라 보상을 탐색합니다. 신화 아이템 20%, 패시브 아이템 60%, 꽝 20%를 기본으로 하며, 보물지도 레벨당 신화 보상 확률이 3% 증가합니다.",
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
		"description": "퍽 선택창을 한 번 더 새로고침",
		"detail": "현재 선택지가 마음에 들지 않을 때 한 번 더 선택지를 받습니다.",
		"icon_color": Color(150.0 / 255.0, 220.0 / 255.0, 1.0),
		"tree": "instant",
		"is_instant": true,
	},
}

const GOLD_CHOICE := {
	"id": "convert_to_gold",
	"name": "골드변환",
	"description": "스타포인트로 퍽을 획득하는 대신 골드로 변환합니다",
	"detail": "퍽을 포기하고 즉시 500골드를 인게임 골드로 획득합니다.",
	"icon_color": Color(1.0, 215.0 / 255.0, 0.0),
	"tree": "instant",
	"character_restriction": "",
	"is_instant": true,
	"is_gold_conversion": true,
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

	var normalized: String = _normalize_character(character_type)
	if normalized == "smasher":
		_append_pool_choices(choices, SMASHER_PERKS, runtime_levels, "smasher")
	elif normalized == "viper":
		_append_pool_choices(choices, VIPER_PERKS, runtime_levels, "viper")
	elif normalized == "soldier":
		_append_pool_choices(choices, SOLDIER_PERKS, runtime_levels, "soldier")

	if PerkConversionFlags.is_enabled():
		_append_converted_perk_choices(choices, runtime_levels, normalized)

	choices = _filter_unlock_slot_budget(choices, normalized, runtime_levels)
	if PerkConversionFlags.is_enabled():
		choices = _filter_perk_slot_budget(choices, runtime_levels)
	_append_lingpet_affinity_chip_choice(choices, owner, _registry)
	_append_lingpet_ring_core_upgrade_choice(choices, owner, _registry)
	if not exclude_instant:
		_append_instant_choices(choices)

	choices = _filter_lingpet_owned_gate(choices, owner)
	var ring_core_reservation: Dictionary = _extract_lingpet_ring_core_reserved_choices(choices, target_choice_count)
	var reserved_choices: Array = ring_core_reservation.get("reserved", []) as Array
	choices = ring_core_reservation.get("remaining", []) as Array
	choices.shuffle()
	var result: Array = []
	for reserved_choice in reserved_choices:
		if result.size() >= target_choice_count:
			break
		result.append(reserved_choice)
	for choice in choices:
		if result.size() >= target_choice_count:
			break
		result.append(choice)

	if not exclude_instant and result.size() < target_choice_count:
		var filler: Array = []
		_append_instant_choices(filler)
		filler = _filter_lingpet_owned_gate(filler, owner)
		filler.shuffle()
		for instant_choice in filler:
			if result.size() >= target_choice_count:
				break
			if not _has_choice_id(result, str(instant_choice.get("id", ""))):
				result.append(instant_choice)

	var gold_choice := GOLD_CHOICE.duplicate(true)
	gold_choice["id"] = "convert_to_gold"
	result.append(LanguageSettings.localize_perk_data(gold_choice))
	return result


func get_all_perk_data() -> Dictionary:
	var data: Dictionary = {}
	data.merge(COMMON_PERKS, true)
	data.merge(SMASHER_PERKS, true)
	data.merge(VIPER_PERKS, true)
	data.merge(SOLDIER_PERKS, true)
	data.merge(CONVERTED_PERKS, true)
	data.merge(CONVERTED_MYTHIC_PERKS, true)
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_KOREAN:
		return data
	var localized: Dictionary = {}
	for skill_id in data.keys():
		var perk_data: Dictionary = data[skill_id].duplicate(true)
		perk_data["id"] = str(skill_id)
		localized[skill_id] = LanguageSettings.localize_perk_data(perk_data)
	return localized


func get_perk_data(skill_id: String) -> Dictionary:
	var all_data: Dictionary = get_all_perk_data()
	if all_data.has(skill_id):
		var data: Dictionary = all_data[skill_id]
		var result := data.duplicate(true)
		result["id"] = skill_id
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
	if skill_id == LINGPET_AFFINITY_CHIP_CHOICE_ID:
		var chip_choice := LINGPET_AFFINITY_CHIP_PERK.duplicate(true)
		chip_choice["id"] = LINGPET_AFFINITY_CHIP_CHOICE_ID
		return LanguageSettings.localize_perk_data(chip_choice)
	if skill_id == LINGPET_RING_CORE_UPGRADE_CHOICE_ID:
		var ring_core_choice := _build_lingpet_ring_core_upgrade_data(0, 1, LingpetRingCoreRules.MAX_RING_CORE_TIER)
		ring_core_choice["id"] = LINGPET_RING_CORE_UPGRADE_CHOICE_ID
		return LanguageSettings.localize_perk_data(ring_core_choice)
	return {}


static func is_slot_consuming_perk(perk_data: Dictionary) -> bool:
	if perk_data.is_empty():
		return false
	var perk_id: String = str(perk_data.get("id", "")).strip_edges()
	if perk_id == "convert_to_gold" or bool(perk_data.get("is_gold_conversion", false)):
		return false
	if bool(perk_data.get("is_instant", false)) or str(perk_data.get("tree", "")) == "instant":
		return false
	if str(perk_data.get("unlocks_skill", "")).strip_edges() != "":
		return false
	if bool(perk_data.get("is_lingpet_affinity_chip", false)) or bool(perk_data.get("is_lingpet_ring_core_upgrade", false)):
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


func count_owned_slot_perks(runtime_levels: Dictionary) -> int:
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
	return count


func has_open_perk_slot(runtime_levels: Dictionary) -> bool:
	return count_owned_slot_perks(runtime_levels) < PERK_SLOT_LIMIT


func get_perk_slot_limit() -> int:
	return PERK_SLOT_LIMIT


func get_perk_slot_status(runtime_levels: Dictionary) -> Dictionary:
	var count := count_owned_slot_perks(runtime_levels)
	return {
		"count": count,
		"limit": PERK_SLOT_LIMIT,
		"is_full": count >= PERK_SLOT_LIMIT,
	}


func get_debug_perk_entries(_character_type: String = "") -> Array:
	var entries: Array = []
	_append_debug_pool_entries(entries, COMMON_PERKS, "common")
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
	var ring_core_choice := _build_lingpet_ring_core_upgrade_data(0, 1, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	ring_core_choice["debug_group"] = "lingpet"
	entries.append(LanguageSettings.localize_perk_data(ring_core_choice))
	entries.sort_custom(func(a, b): return _debug_sort_key(a) < _debug_sort_key(b))
	return entries


func _append_pool_choices(output: Array, pool: Dictionary, runtime_levels: Dictionary, character_restriction: String) -> void:
	for skill_id in pool.keys():
		var skill_data: Dictionary = pool[skill_id]
		var max_level: int = int(skill_data.get("max_level", 1))
		var current_level: int = int(runtime_levels.get(skill_id, 0))
		if max_level >= 0 and current_level >= max_level:
			continue
		var next_level: int = current_level + 1
		var choice: Dictionary = _build_level_choice(skill_id, skill_data, current_level, next_level, character_restriction)
		output.append(LanguageSettings.localize_perk_data(choice))


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


func _is_perk_allowed_for_character(skill_data: Dictionary, character_type: String) -> bool:
	var restriction := str(skill_data.get("character_restriction", "")).strip_edges().to_lower()
	if restriction == "":
		return true
	return restriction == character_type


func _append_instant_choices(output: Array) -> void:
	for skill_id in INSTANT_PERKS.keys():
		var data: Dictionary = INSTANT_PERKS[skill_id]
		var choice: Dictionary = data.duplicate(true)
		choice["id"] = skill_id
		choice["current_level"] = 0
		choice["next_level"] = 0
		choice["max_level"] = 0
		choice["character_restriction"] = ""
		output.append(LanguageSettings.localize_perk_data(choice))


func _append_lingpet_affinity_chip_choice(output: Array, owner: Object, registry: Object) -> void:
	if not _has_lingpet_owned_gate(owner):
		return
	var ring_core_tier := _get_lingpet_run_ring_core_tier(registry)
	if ring_core_tier < LINGPET_AFFINITY_CHIP_MIN_RING_CORE_TIER:
		return
	var chip_count := _get_lingpet_affinity_chip_count(registry)
	var max_chips := int(LINGPET_AFFINITY_CHIP_PERK.get("max_level", LingpetAffinityState.MAX_ENHANCEMENT_CHIPS))
	if chip_count >= max_chips:
		return
	var next_level := clampi(chip_count + 1, 1, max_chips)
	var choice := _build_level_choice(
		LINGPET_AFFINITY_CHIP_CHOICE_ID,
		LINGPET_AFFINITY_CHIP_PERK,
		chip_count,
		next_level,
		""
	)
	choice["is_lingpet_affinity_chip"] = true
	choice["chip_count"] = chip_count
	output.append(LanguageSettings.localize_perk_data(choice))


func _append_lingpet_ring_core_upgrade_choice(output: Array, owner: Object, registry: Object) -> void:
	if not _has_lingpet_owned_gate(owner):
		return
	# R5 / per-run: read THIS run's ring-core tier (run-state via egg_runtime),
	# not the dropped permanent store.
	var current_tier := _get_lingpet_run_ring_core_tier(registry)
	if current_tier < 0:
		return
	var max_tier := LingpetRingCoreRules.MAX_RING_CORE_TIER
	if current_tier >= max_tier:
		return
	var next_tier := clampi(current_tier + 1, 1, max_tier)
	var choice := LanguageSettings.localize_perk_data(_build_lingpet_ring_core_upgrade_data(current_tier, next_tier, max_tier))
	if _get_lingpet_ring_core_early_reserve_count(current_tier) > 0 and _get_lingpet_ring_core_offer_cooldown(registry) <= 0:
		choice[LINGPET_RING_CORE_PRIORITY_KEY] = true
	output.append(choice)


func _build_lingpet_ring_core_upgrade_data(current_tier: int, next_tier: int, max_tier: int) -> Dictionary:
	var clamped_next := clampi(next_tier, 1, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	var clamped_max := clampi(max_tier, 1, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	var tier_name := _get_lingpet_ring_core_tier_name(clamped_next)
	var next_cap := LingpetRingCoreRules.get_ring_core_cap_for_tier(clamped_next)
	var data: Dictionary = LINGPET_RING_CORE_UPGRADE_PERK.duplicate(true)
	data["id"] = LINGPET_RING_CORE_UPGRADE_CHOICE_ID
	data["name"] = "링코어 강화: %s" % tier_name
	data["description"] = "이번 런의 링코어를 %s로 강화합니다. 친밀도 상한 Lv.%d." % [tier_name, next_cap]
	data["detail"] = "이번 선택으로 골드 지불 없이 이번 런의 링코어가 %s 티어로 올라갑니다. 골드샵 강화와 같은 런 강화이며, 새 런에서 초기화됩니다." % tier_name
	data["current_level"] = clampi(current_tier, 0, clamped_max)
	data["next_level"] = clamped_next
	data["max_level"] = clamped_max
	data["current_tier"] = clampi(current_tier, 0, clamped_max)
	data["next_tier"] = clamped_next
	data["ring_core_tier"] = clamped_next
	data["ring_core_name"] = tier_name
	data["next_cap"] = next_cap
	data["level_text"] = "Tier %d" % clamped_next
	data["long_level_text"] = "  (Tier %d -> cap Lv.%d)" % [clamped_next, next_cap]
	data["icon_id"] = "%s%d" % [LINGPET_RING_CORE_ICON_ID_PREFIX, clamped_next]
	data["is_lingpet_ring_core_upgrade"] = true
	return data


func _append_debug_pool_entries(output: Array, pool: Dictionary, debug_group: String) -> void:
	for skill_id in pool.keys():
		var data: Dictionary = pool[skill_id].duplicate(true)
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
	for choice in choices:
		if str(choice.get("unlocks_skill", "")) == "":
			filtered.append(choice)
	return filtered


func _filter_perk_slot_budget(choices: Array, runtime_levels: Dictionary) -> Array:
	var occupied_slots := count_owned_slot_perks(runtime_levels)
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
		if occupied_slots + extra_slots <= PERK_SLOT_LIMIT:
			filtered.append(choice)
	return filtered


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


func _extract_lingpet_ring_core_reserved_choices(choices: Array, target_choice_count: int) -> Dictionary:
	var reserved: Array = []
	var remaining: Array = []
	var reserve_limit: int = maxi(0, target_choice_count)
	for value in choices:
		if value is Dictionary:
			var choice: Dictionary = value as Dictionary
			var is_reserved_ring_core := str(choice.get("id", "")) == LINGPET_RING_CORE_UPGRADE_CHOICE_ID and bool(choice.get(LINGPET_RING_CORE_PRIORITY_KEY, false))
			if is_reserved_ring_core and reserved.size() < reserve_limit:
				var reserved_choice := choice.duplicate(true)
				reserved_choice.erase(LINGPET_RING_CORE_PRIORITY_KEY)
				reserved.append(reserved_choice)
				continue
			if choice.has(LINGPET_RING_CORE_PRIORITY_KEY):
				var regular_choice := choice.duplicate(true)
				regular_choice.erase(LINGPET_RING_CORE_PRIORITY_KEY)
				remaining.append(regular_choice)
				continue
		remaining.append(value)
	return {
		"reserved": reserved,
		"remaining": remaining,
	}


func _get_lingpet_ring_core_early_reserve_count(current_tier: int) -> int:
	if current_tier < 0 or current_tier >= LINGPET_RING_CORE_EARLY_RESERVE_BY_TIER.size():
		return 0
	return maxi(0, int(LINGPET_RING_CORE_EARLY_RESERVE_BY_TIER[current_tier]))


func _get_lingpet_run_ring_core_tier(registry: Object) -> int:
	var runtime: Object = _get_lingpet_runtime(registry)
	if runtime == null or not runtime.has_method("get_run_ring_core_tier"):
		return -1
	return clampi(int(runtime.get_run_ring_core_tier()), 0, LingpetRingCoreRules.MAX_RING_CORE_TIER)


func _get_lingpet_ring_core_offer_cooldown(registry: Object) -> int:
	var runtime: Object = _get_lingpet_runtime(registry)
	if runtime == null or not runtime.has_method("get_ring_core_offer_cooldown_screens"):
		return 0
	return maxi(0, int(runtime.get_ring_core_offer_cooldown_screens()))


func _get_lingpet_affinity_chip_count(registry: Object) -> int:
	var runtime: Object = _get_lingpet_runtime(registry)
	if runtime == null or not runtime.has_method("get_enhancement_chips"):
		return 0
	return clampi(int(runtime.get_enhancement_chips()), 0, LingpetAffinityState.MAX_ENHANCEMENT_CHIPS)


func _get_lingpet_runtime(registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance("lingpet_egg_runtime")


func _get_lingpet_ring_core_tier_name(tier: int) -> String:
	var clamped_tier := clampi(tier, 0, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_KOREAN:
		return PlazaLingpetStoreTransactions.get_ring_core_tier_name(clamped_tier)
	match clamped_tier:
		1:
			return "Standard"
		2:
			return "Boost"
		3:
			return "Hyper"
		4:
			return "Overdrive"
		5:
			return "Ultimate"
		6:
			return "Zenith"
	return ""


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
