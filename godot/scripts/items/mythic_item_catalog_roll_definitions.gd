extends RefCounted

const MEGINGJORD_ROLL_OPTIONS := [
	{
		"key": "extra_pick_chance",
		"label": "추가 선택 확률",
		"min": 30.0,
		"max": 50.0,
		"unit": "%",
		"default": 40.0,
	},
]

const PANDORA_LEGACY_ROLL_OPTIONS := [
	{
		"key": "selection_quality",
		"label": "매직찬스",
		"min": 10.0,
		"max": 30.0,
		"unit": "%",
		"default": 20.0,
	},
	{
		"key": "trigger_chance",
		"label": "승리시 유산 발동률",
		"min": 40.0,
		"max": 70.0,
		"unit": "%",
		"default": 55.0,
	},
]

const RAGNAROK_HAMMER_ROLL_OPTIONS := [
	{
		"key": "trigger_chance",
		"label": "발동 확률",
		"min": 20.0,
		"max": 40.0,
		"step": 1.0,
		"unit": "%",
		"default": 30.0,
	},
	{
		"key": "stun_duration",
		"label": "스턴 시간",
		"min": 0.8,
		"max": 1.2,
		"step": 0.1,
		"unit": "초",
		"default": 1.0,
	},
	{
		"key": "speed_boost",
		"label": "공속 증가",
		"min": 15.0,
		"max": 35.0,
		"step": 1.0,
		"unit": "%",
		"default": 25.0,
	},
	{
		"key": "gauge_cost",
		"label": "게이지 소모",
		"min": 20.0,
		"max": 40.0,
		"step": 1.0,
		"unit": "",
		"default": 30.0,
		"reverse": true,
	},
]

const SACRED_LAUREL_ROLL_OPTIONS := [
	{
		"key": "leaf_count",
		"label": "월계수 잎",
		"min": 4.0,
		"max": 8.0,
		"step": 1.0,
		"unit": "개",
		"default": 6.0,
	},
]

const TRANSCENDENT_CROWN_ROLL_OPTIONS := [
	{
		"key": "skill_bonus",
		"label": "모든 퍽 레벨 증가",
		"min": 1.0,
		"max": 2.0,
		"step": 1.0,
		"unit": "+",
		"default": 2.0,
	},
]

const HERMES_SHOES_ROLL_OPTIONS := [
	{
		"key": "speed_bonus",
		"label": "이동속도",
		"min": 30.0,
		"max": 60.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 50.0,
	},
]

const POSEIDON_TRIDENT_ROLL_OPTIONS := [
	{
		"key": "cooldown",
		"label": "쿨타임",
		"min": 2.0,
		"max": 10.0,
		"step": 1.0,
		"unit": "초",
		"default": 6.0,
		"reverse": true,
	},
	{
		"key": "gauge_cost",
		"label": "게이지 소모",
		"min": 20.0,
		"max": 40.0,
		"step": 1.0,
		"unit": "",
		"prefix": "-",
		"default": 30.0,
		"reverse": true,
	},
	{
		"key": "vortex_size",
		"label": "소용돌이 크기",
		"min": 150.0,
		"max": 250.0,
		"step": 10.0,
		"unit": "px",
		"default": 200.0,
	},
]

const HEAVENLY_CAPE_ROLL_OPTIONS := [
	{
		"key": "skill_cooldown_reduction",
		"label": "스킬 쿨타임 감소",
		"min": 10.0,
		"max": 20.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "-",
		"default": 15.0,
	},
]

const CELESTIAL_ARMOR_ROLL_OPTIONS := [
	{
		"key": "trigger_chance_pct",
		"label": "발동 확률",
		"min": 50.0,
		"max": 80.0,
		"step": 1.0,
		"unit": "%",
		"default": 65.0,
	},
	{
		"key": "gauge_cost",
		"label": "게이지 소모",
		"min": 20.0,
		"max": 40.0,
		"step": 1.0,
		"unit": "",
		"prefix": "-",
		"default": 30.0,
		"reverse": true,
	},
]

const BAAL_BOOTS_ROLL_OPTIONS := [
	{
		"key": "gauge_recovery",
		"label": "게이지 회복",
		"min": 300.0,
		"max": 500.0,
		"step": 1.0,
		"unit": "",
		"default": 400.0,
	},
]

const HORN_STRAWBERRY_MASK_ROLL_OPTIONS := [
	{
		"key": "transform_duration",
		"label": "변신 지속시간",
		"min": 50.0,
		"max": 70.0,
		"unit": "초",
		"default": 60.0,
		"step": 5.0,
	},
]

const ODINS_EYE_ROLL_OPTIONS := [
	{
		"key": "revival_chance",
		"label": "부활 확률",
		"min": 30.0,
		"max": 45.0,
		"step": 1.0,
		"unit": "%",
		"default": 35.0,
	},
]

const DOWSING_PENDULUM_ROLL_OPTIONS := [
	{
		"key": "attraction_range",
		"label": "끌어당기는 범위",
		"min": 150.0,
		"max": 250.0,
		"step": 1.0,
		"unit": "px",
		"default": 200.0,
	},
]

const DOWSING_GOGGLES_ROLL_OPTIONS := [
	{
		"key": "bonus_perk_chance",
		"label": "추가 퍽 등장 확률",
		"min": 30.0,
		"max": 60.0,
		"step": 1.0,
		"unit": "%",
		"default": 30.0,
	},
]

const SPEEDBOOTS_ROLL_OPTIONS := [
	{
		"key": "speed_bonus_pct",
		"label": "이동 속도",
		"min": 10.0,
		"max": 18.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 10.0,
	},
]

const SENSOR_ROLL_OPTIONS := [
	{
		"key": "sensor_cooldown_sec",
		"label": "자동대쉬 쿨타임",
		"min": 13.0,
		"max": 20.0,
		"step": 1.0,
		"unit": "초",
		"default": 15.0,
		"reverse": true,
	},
]

const SLOT_ADD_ROLL_OPTIONS := [
	{
		"key": "slot_add_count",
		"label": "슬롯 추가",
		"min": 1.0,
		"max": 3.0,
		"step": 1.0,
		"unit": "칸",
		"prefix": "+",
		"default": 1.0,
	},
]

const CHARGEBAG_ROLL_OPTIONS := [
	{
		"key": "chargebag_pct",
		"label": "벽 반사 게이지",
		"min": 25.0,
		"max": 50.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 25.0,
	},
]

const BATTERY_ROLL_OPTIONS := [
	{
		"key": "gauge_preserve_pct",
		"label": "게이지 보존",
		"min": 60.0,
		"max": 100.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "",
		"default": 100.0,
	},
]

const MASTER_ROLL_OPTIONS := [
	{
		"key": "wall_length_pct",
		"label": "벽돌 길이",
		"min": 20.0,
		"max": 40.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 30.0,
	},
	{
		"key": "item_cooldown_pct",
		"label": "아이템 쿨타임",
		"min": 4.0,
		"max": 10.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "-",
		"default": 10.0,
	},
	{
		"key": "wall_spawn_bonus_pct",
		"label": "벽돌 스폰율",
		"min": 150.0,
		"max": 300.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 150.0,
	},
]

const GOLD_DIGGER_ROLL_OPTIONS := [
	{
		"key": "gold_bonus_pct",
		"label": "골드 획득량",
		"min": 25.0,
		"max": 50.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 37.0,
	},
]

const LUCKY_COIN_ROLL_OPTIONS := [
	{
		"key": "double_spawn_pct",
		"label": "더블 스폰 확률",
		"min": 5.0,
		"max": 15.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "",
		"default": 10.0,
	},
]

const ADVERSITY_ARMOR_ROLL_OPTIONS := [
	{
		"key": "trigger_chance_pct",
		"label": "발동 확률",
		"min": 20.0,
		"max": 30.0,
		"step": 1.0,
		"unit": "%",
		"default": 25.0,
	},
	{
		"key": "invincible_duration_sec",
		"label": "보호 지속시간",
		"min": 8.0,
		"max": 15.0,
		"step": 1.0,
		"unit": "초",
		"default": 10.0,
	},
]

const SHRAPNEL_ARMOR_ROLL_OPTIONS := [
	{
		"key": "trigger_chance_pct",
		"label": "발동 확률",
		"min": 8.0,
		"max": 15.0,
		"step": 1.0,
		"unit": "%",
		"default": 12.0,
	},
	{
		"key": "shard_count",
		"label": "파편 개수",
		"min": 4.0,
		"max": 8.0,
		"step": 1.0,
		"unit": "개",
		"default": 6.0,
	},
	{
		"key": "knockback_level",
		"label": "넉백 단계",
		"min": 1.0,
		"max": 4.0,
		"step": 1.0,
		"unit": "Lv",
		"default": 2.0,
	},
	{
		"key": "gauge_cost",
		"label": "게이지 소모",
		"min": 25.0,
		"max": 50.0,
		"step": 1.0,
		"unit": "",
		"prefix": "-",
		"default": 35.0,
		"reverse": true,
	},
]

const SAGE_RING_ROLL_OPTIONS := [
	{
		"key": "sage_speed_penalty_pct",
		"label": "이동속도 감소",
		"min": 10.0,
		"max": 20.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "-",
		"default": 15.0,
		"reverse": true,
	},
	{
		"key": "sage_body_penalty_pct",
		"label": "몸집크기 감소",
		"min": 10.0,
		"max": 20.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "-",
		"default": 15.0,
		"reverse": true,
	},
]

const COOLTIME_ROLL_OPTIONS := [
	{
		"key": "active_cooldown_pct",
		"label": "아이템 쿨타임",
		"min": 10.0,
		"max": 20.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "-",
		"default": 15.0,
	},
]

const TIMER_BELT_ROLL_OPTIONS := [
	{
		"key": "skill_cooldown_pct",
		"label": "스킬 쿨타임",
		"min": 10.0,
		"max": 20.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "-",
		"default": 15.0,
	},
]

const FUEL_POUCH_ROLL_OPTIONS := [
	{
		"key": "fuel_bonus_flat",
		"label": "최대 게이지",
		"min": 60.0,
		"max": 120.0,
		"step": 1.0,
		"unit": "",
		"prefix": "+",
		"default": 100.0,
	},
]

const BLUETOOTH_RING_ROLL_OPTIONS := [
	{
		"key": "gauge_gain_pct",
		"label": "게이지 획득량",
		"min": 10.0,
		"max": 20.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 15.0,
	},
]

const STAR_DETECTOR_ROLL_OPTIONS := [
	{
		"key": "star_bonus_pct",
		"label": "스타포인트 드랍율",
		"min": 10.0,
		"max": 20.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 15.0,
	},
]

const FOUL_WHISTLE_ROLL_OPTIONS := [
	{
		"key": "negate_chance_pct",
		"label": "라운드 패배 시 무효화 확률",
		"min": 4.0,
		"max": 10.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 7.0,
	},
]

const NEURAL_HELMET_ROLL_OPTIONS := [
	{
		"key": "aipill_gauge_reduction",
		"label": "AI알약 게이지 소모",
		"min": 40.0,
		"max": 60.0,
		"step": 1.0,
		"unit": "",
		"prefix": "-",
		"default": 50.0,
	},
	{
		"key": "aipill_spawn_bonus_pct",
		"label": "AI알약 스폰율",
		"min": 150.0,
		"max": 300.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 225.0,
	},
]

const VENOM_MIST_GAUNTLET_ROLL_OPTIONS := [
	{
		"key": "mist_trigger_chance_pct",
		"label": "발동확률",
		"min": 30.0,
		"max": 50.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "",
		"default": 40.0,
	},
	{
		"key": "mist_duration_sec",
		"label": "독안개 지속시간",
		"min": 2.0,
		"max": 5.0,
		"step": 1.0,
		"unit": "초",
		"prefix": "",
		"default": 3.0,
	},
]

const REINFORCED_BOOMERANG_GAUNTLET_ROLL_OPTIONS := [
	{
		"key": "boomerang_launch_speed_pct",
		"label": "부메랑 발사속도",
		"min": 30.0,
		"max": 60.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 45.0,
	},
	{
		"key": "boomerang_homing_pct",
		"label": "부메랑 유도성능",
		"min": 20.0,
		"max": 50.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 35.0,
	},
	{
		"key": "boomerang_spawn_bonus_pct",
		"label": "부메랑 스폰율",
		"min": 150.0,
		"max": 250.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 200.0,
	},
]

const COMMANDO_ARM_ROLL_OPTIONS := [
	{
		"key": "throw_speed_pct",
		"label": "투척 속도",
		"min": 10.0,
		"max": 20.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 15.0,
	},
	{
		"key": "explosion_range_pct",
		"label": "폭발 범위",
		"min": 5.0,
		"max": 15.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 10.0,
	},
	{
		"key": "smoke_duration_pct",
		"label": "연막탄 지속시간",
		"min": 20.0,
		"max": 40.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 30.0,
	},
	{
		"key": "prep_reduction_pct",
		"label": "준비시간 단축",
		"min": 20.0,
		"max": 40.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "-",
		"default": 30.0,
	},
]

const RAINBOW_FUR_GLOVE_ROLL_OPTIONS := [
	{
		"key": "rainbow_glove_trigger_chance_pct",
		"label": "발동확률",
		"min": 5.0,
		"max": 10.0,
		"step": 1.0,
		"unit": "%",
		"default": 5.0,
	},
	{
		"key": "rainbow_glove_cooldown_reduction_pct",
		"label": "스킬 쿨타임 감소",
		"min": 30.0,
		"max": 50.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "-",
		"default": 30.0,
	},
]

const DASHGEAR_ROLL_OPTIONS := [
	{
		"key": "dash_distance_pct",
		"label": "대쉬 거리",
		"min": 6.0,
		"max": 12.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 9.0,
	},
	{
		"key": "boost_charge_pct",
		"label": "부스트차징 발동확률",
		"min": 7.0,
		"max": 13.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 7.0,
	},
]

const SOUL_BURST_ROLL_OPTIONS := [
	{
		"key": "soul_burst_gauge_cost",
		"label": "게이지 소모",
		"min": 110.0,
		"max": 160.0,
		"step": 1.0,
		"unit": "",
		"default": 160.0,
		"reverse": true,
	},
]

const KNEE_PADS_ROLL_OPTIONS := [
	{
		"key": "knee_charge_pct",
		"label": "하프대쉬 게이지",
		"min": 30.0,
		"max": 60.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 50.0,
	},
]

const BULKUP_ROLL_OPTIONS := [
	{
		"key": "body_size_pct",
		"label": "몸집크기",
		"min": 11.0,
		"max": 16.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 11.0,
	},
]

const SPIKEBOOTS_ROLL_OPTIONS := [
	{
		"key": "dash_afterdelay_pct",
		"label": "대쉬 후딜 시간",
		"min": 15.0,
		"max": 35.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "-",
		"default": 30.0,
	},
	{
		"key": "dash_cooldown_pct",
		"label": "대쉬 쿨타임",
		"min": 15.0,
		"max": 30.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "-",
		"default": 15.0,
	},
]

const BULLETPROOF_HAT_ROLL_OPTIONS := [
	{
		"key": "stun_resist_pct",
		"label": "스턴 저항력",
		"min": 10.0,
		"max": 20.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 10.0,
	},
]

const SPIKED_HELMET_ROLL_OPTIONS := [
	{
		"key": "knockback_resist_pct",
		"label": "넉백 저항력",
		"min": 10.0,
		"max": 20.0,
		"step": 1.0,
		"unit": "%",
		"prefix": "+",
		"default": 10.0,
	},
]

const ITEM_ROLL_OPTIONS := {
	"megingjord": MEGINGJORD_ROLL_OPTIONS,
	"pandora_legacy": PANDORA_LEGACY_ROLL_OPTIONS,
	"ragnarok_hammer": RAGNAROK_HAMMER_ROLL_OPTIONS,
	"sacred_laurel": SACRED_LAUREL_ROLL_OPTIONS,
	"transcendent_crown": TRANSCENDENT_CROWN_ROLL_OPTIONS,
	"hermes_shoes": HERMES_SHOES_ROLL_OPTIONS,
	"poseidon_trident": POSEIDON_TRIDENT_ROLL_OPTIONS,
	"heavenly_cape": HEAVENLY_CAPE_ROLL_OPTIONS,
	"celestial_armor": CELESTIAL_ARMOR_ROLL_OPTIONS,
	"baal_boots": BAAL_BOOTS_ROLL_OPTIONS,
	"horn_strawberry_mask": HORN_STRAWBERRY_MASK_ROLL_OPTIONS,
	"odins_eye": ODINS_EYE_ROLL_OPTIONS,
	"dowsing_pendulum": DOWSING_PENDULUM_ROLL_OPTIONS,
	"dowsing_goggles": DOWSING_GOGGLES_ROLL_OPTIONS,
	"speedboots": SPEEDBOOTS_ROLL_OPTIONS,
	"sensor": SENSOR_ROLL_OPTIONS,
	"slot_add": SLOT_ADD_ROLL_OPTIONS,
	"chargebag": CHARGEBAG_ROLL_OPTIONS,
	"battery": BATTERY_ROLL_OPTIONS,
	"master": MASTER_ROLL_OPTIONS,
	"gold_digger": GOLD_DIGGER_ROLL_OPTIONS,
	"lucky_coin": LUCKY_COIN_ROLL_OPTIONS,
	"adversity_armor": ADVERSITY_ARMOR_ROLL_OPTIONS,
	"shrapnel_armor": SHRAPNEL_ARMOR_ROLL_OPTIONS,
	"sage_ring": SAGE_RING_ROLL_OPTIONS,
	"cooltime": COOLTIME_ROLL_OPTIONS,
	"timer_belt": TIMER_BELT_ROLL_OPTIONS,
	"fuel_pouch": FUEL_POUCH_ROLL_OPTIONS,
	"bluetooth_ring": BLUETOOTH_RING_ROLL_OPTIONS,
	"star_detector": STAR_DETECTOR_ROLL_OPTIONS,
	"foul_whistle": FOUL_WHISTLE_ROLL_OPTIONS,
	"neural_helmet": NEURAL_HELMET_ROLL_OPTIONS,
	"venom_mist_gauntlet": VENOM_MIST_GAUNTLET_ROLL_OPTIONS,
	"reinforced_boomerang_gauntlet": REINFORCED_BOOMERANG_GAUNTLET_ROLL_OPTIONS,
	"commando_arm": COMMANDO_ARM_ROLL_OPTIONS,
	"rainbow_fur_glove": RAINBOW_FUR_GLOVE_ROLL_OPTIONS,
	"dashgear": DASHGEAR_ROLL_OPTIONS,
	"soul_burst": SOUL_BURST_ROLL_OPTIONS,
	"knee_pads": KNEE_PADS_ROLL_OPTIONS,
	"bulkup": BULKUP_ROLL_OPTIONS,
	"spikeboots": SPIKEBOOTS_ROLL_OPTIONS,
	"bulletproof_hat": BULLETPROOF_HAT_ROLL_OPTIONS,
	"spiked_helmet": SPIKED_HELMET_ROLL_OPTIONS,
}


static func get_roll_options(item_name: String) -> Array:
	if not ITEM_ROLL_OPTIONS.has(item_name):
		return []
	var options: Array = ITEM_ROLL_OPTIONS[item_name]
	return options.duplicate(true)
