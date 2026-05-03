extends RefCounted

const BASE_CHOICE_COUNT := 3

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
	"dash_amplification": {
		"name": "증폭",
		"max_level": 3,
		"descriptions": {
			1: "대쉬 토큰 +1",
			2: "대쉬 토큰 +2",
			3: "대쉬 토큰 +3",
		},
		"detail": "최대 대쉬 토큰 수가 증가합니다.",
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
			1: "부스트차징 발동확률 +7%",
			2: "부스트차징 발동확률 +14%",
			3: "부스트차징 발동확률 +21%",
			4: "부스트차징 발동확률 +28%",
			5: "부스트차징 발동확률 +35%",
		},
		"detail": "다음 대쉬의 토큰 소모를 무효화할 확률이 생깁니다.",
		"icon_color": Color(80.0 / 255.0, 160.0 / 255.0, 1.0),
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
}

const VIPER_PERKS := {
	"unlock_nerve_strike": {
		"name": "베놈킥 해금",
		"max_level": 1,
		"descriptions": {1: "베놈킥 스킬 해금"},
		"detail": "연계 중 보스 뒤를 파고드는 추격 스킬을 장착합니다.",
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
			1: "킥 발사 정밀도 +8%, 공속 +12%",
			2: "킥 발사 정밀도 +16%, 공속 +24%",
			3: "킥 발사 정밀도 +24%, 공속 +36%, 준비동작 감소",
			4: "킥 발사 정밀도 +32%, 공속 +48%, 준비동작 감소",
			5: "킥 발사 정밀도 +40%, 공속 +60%, 용광로 넉백볼",
		},
		"detail": "바이퍼 킥 계열 스킬의 타격 품질이 좋아집니다.",
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
			1: "EMP/카오스 준비 -8%, 베놈 혼란 +12%",
			2: "EMP/카오스 준비 -16%, 베놈 혼란 +24%",
			3: "EMP/카오스 준비 -25%, 듀얼 HP 증가, 슈퍼아머",
			4: "EMP/카오스 준비 -33%, 4스킬 쿨 -15%",
			5: "EMP/카오스 준비 -40%, 분신 스킬 복제",
		},
		"detail": "EMP, 베놈, 카오스, 듀얼 글리치를 묶어 강화합니다.",
		"icon_color": Color(215.0 / 255.0, 70.0 / 255.0, 1.0),
		"tree": "viper",
		"character_restriction": "viper",
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
		"detail": "현재 Godot 포트에서는 선택 피드백을 먼저 제공하며, 필드 스폰 강화는 아이템 포트 확장 때 연결됩니다.",
		"icon_color": Color(1.0, 100.0 / 255.0, 1.0),
		"tree": "instant",
		"is_instant": true,
	},
	"instant_treasure_hunt": {
		"name": "보물탐색",
		"description": "보물을 탐색하여 보상을 노립니다",
		"detail": "현재 Godot 포트에서는 선택 피드백을 먼저 제공하며, 보상 연출은 아이템 포트 확장 때 연결됩니다.",
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
	"smasher": 2,
	"viper": 2,
}


func get_choices(character_type: String, runtime_levels: Dictionary, exclude_instant: bool = false) -> Array:
	var choices: Array = []
	_append_pool_choices(choices, COMMON_PERKS, runtime_levels, "")

	var normalized: String = _normalize_character(character_type)
	if normalized == "smasher":
		_append_pool_choices(choices, SMASHER_PERKS, runtime_levels, "smasher")
	elif normalized == "viper":
		_append_pool_choices(choices, VIPER_PERKS, runtime_levels, "viper")

	choices = _filter_unlock_slot_budget(choices, normalized, runtime_levels)
	if not exclude_instant:
		_append_instant_choices(choices)

	choices.shuffle()
	var result: Array = []
	for choice in choices:
		if result.size() >= BASE_CHOICE_COUNT:
			break
		result.append(choice)

	if not exclude_instant and result.size() < BASE_CHOICE_COUNT:
		var filler: Array = []
		_append_instant_choices(filler)
		filler.shuffle()
		for instant_choice in filler:
			if result.size() >= BASE_CHOICE_COUNT:
				break
			if not _has_choice_id(result, str(instant_choice.get("id", ""))):
				result.append(instant_choice)

	result.append(GOLD_CHOICE.duplicate(true))
	return result


func get_all_perk_data() -> Dictionary:
	var data: Dictionary = {}
	data.merge(COMMON_PERKS, true)
	data.merge(SMASHER_PERKS, true)
	data.merge(VIPER_PERKS, true)
	return data


func get_perk_data(skill_id: String) -> Dictionary:
	var all_data: Dictionary = get_all_perk_data()
	if all_data.has(skill_id):
		var data: Dictionary = all_data[skill_id]
		return data.duplicate(true)
	if INSTANT_PERKS.has(skill_id):
		var instant_data: Dictionary = INSTANT_PERKS[skill_id]
		return instant_data.duplicate(true)
	if skill_id == "convert_to_gold":
		return GOLD_CHOICE.duplicate(true)
	return {}


func _append_pool_choices(output: Array, pool: Dictionary, runtime_levels: Dictionary, character_restriction: String) -> void:
	for skill_id in pool.keys():
		var skill_data: Dictionary = pool[skill_id]
		var max_level: int = int(skill_data.get("max_level", 1))
		var current_level: int = int(runtime_levels.get(skill_id, 0))
		if max_level >= 0 and current_level >= max_level:
			continue
		var next_level: int = current_level + 1
		var choice: Dictionary = _build_level_choice(skill_id, skill_data, current_level, next_level, character_restriction)
		output.append(choice)


func _append_instant_choices(output: Array) -> void:
	for skill_id in INSTANT_PERKS.keys():
		var data: Dictionary = INSTANT_PERKS[skill_id]
		var choice: Dictionary = data.duplicate(true)
		choice["id"] = skill_id
		choice["current_level"] = 0
		choice["next_level"] = 0
		choice["max_level"] = 0
		choice["character_restriction"] = ""
		output.append(choice)


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


func _has_choice_id(choices: Array, skill_id: String) -> bool:
	for choice in choices:
		if str(choice.get("id", "")) == skill_id:
			return true
	return false


func _normalize_character(character_type: String) -> String:
	var normalized: String = character_type.strip_edges().to_lower()
	if normalized == "viper":
		return "viper"
	return "smasher"
