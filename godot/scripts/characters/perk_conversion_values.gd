extends RefCounted

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")

const CONVERSION_SOURCE_TO_PERK := {
	"star_detector": "star_detector",
	"adversity_armor": "adversity_armor",
	"reinforced_boomerang_gauntlet": "reinforced_boomerang_gauntlet",
	"sensor": "sensor",
	"gravitybelt": "gravitybelt",
	"dowsing_pendulum": "dowsing_pendulum",
	"chargebag": "chargebag",
	"battery": "battery",
	"revival": "revival",
	"master": "master",
	"gold_digger": "gold_digger",
	"lucky_coin": "lucky_coin",
	"shrapnel_armor": "shrapnel_armor",
	"fuel_pouch": "fuel_pouch",
	"bluetooth_ring": "bluetooth_ring",
	"foul_whistle": "foul_whistle",
	"smartphone": "smartphone",
	"neural_helmet": "neural_helmet",
	"commando_arm": "commando_arm",
	"rainbow_fur_glove": "rainbow_fur_glove",
	"knee_pads": "knee_pads",
	"soul_burst": "soul_burst",
	"bulletproof_hat": "bulletproof_hat",
	"spiked_helmet": "spiked_helmet",
	"venom_mist_gauntlet": "venom_mist_gauntlet",
	"speedgear": "speedgear",
	"sage_ring": "sage_ring",
	"sacred_laurel": "sacred_laurel",
	"dowsing_goggles": "dowsing_goggles",
	"megingjord": "megingjord",
	"transcendent_crown": "transcendent_crown",
	"ragnarok_hammer": "ragnarok_hammer",
	"hermes_shoes": "hermes_shoes",
	"poseidon_trident": "poseidon_trident",
	"heavenly_cape": "heavenly_cape",
	"horn_strawberry_mask": "horn_strawberry_mask",
	"odins_eye": "odins_eye",
	"celestial_armor": "celestial_armor",
	"baal_boots": "baal_boots",
	"pandora_legacy": "pandora_legacy",
	"angel_blessing": "angel_blessing",
}

const DELETED_ITEM_COMPENSATION := {
	"dashholder": ["dash_amplification"],
	"speedboots": ["common_swiftness"],
	"bulkup": ["common_bulk_up"],
	"spikeboots": ["dash_module_control", "dash_lightweight"],
	"dashgear": ["dash_jump", "perk_boost_charge"],
	"cooltime": ["item_cooldown_mastery"],
	"timer_belt": ["common_training"],
	"slot_add": ["item_bag_expansion"],
}

# R1 redesign group: gold_bar is intentionally absent from conversion and
# deleted-item compensation maps. The other redesign ids are wired as perks.
const CONVERTED_PERK_VALUES := {
	"star_detector": {
		"star_bonus_pct": [5.0, 10.0, 15.0, 20.0, 25.0],
	},
	"adversity_armor": {
		"trigger_chance_pct": [20.0, 25.0, 30.0, 35.0, 40.0],
		"invincible_duration_sec": [5.0, 8.0, 10.0, 13.0, 15.0],
	},
	"reinforced_boomerang_gauntlet": {
		"boomerang_knockback_pct": [20.0, 28.0, 35.0, 43.0, 50.0],
		"boomerang_stun_pct": [20.0, 35.0, 50.0, 65.0, 80.0],
		"boomerang_launch_speed_pct": [15.0, 24.0, 33.0, 41.0, 50.0],
		"boomerang_homing_pct": [10.0, 20.0, 30.0, 40.0, 50.0],
		"boomerang_spawn_bonus_pct": [50.0, 88.0, 125.0, 163.0, 200.0],
	},
	"sensor": {
		"auto_dash_token_count": [1.0, 1.0, 2.0, 2.0, 2.0],
		"auto_dash_cooldown_sec": [30.0, 26.0, 23.0, 19.0, 15.0],
	},
	"gravitybelt": {
		"gravitybelt_instant_movement": [1.0],
	},
	"dowsing_pendulum": {
		"attraction_range": [120.0, 160.0, 200.0, 240.0, 280.0],
	},
	"dowsing_goggles": {
		"bonus_perk_chance": [40.0, 70.0, 100.0],
	},
	"chargebag": {
		"chargebag_pct": [15.0, 25.0, 35.0, 45.0, 55.0],
	},
	"battery": {
		"gauge_preserve_pct": [40.0, 55.0, 70.0, 85.0, 100.0],
	},
	"revival": {
		"revival_count": [1.0],
	},
	"master": {
		"wall_length_pct": [12.0, 20.0, 29.0, 37.0, 45.0],
		"item_cooldown_pct": [3.0, 5.0, 8.0, 10.0, 12.0],
		"wall_spawn_bonus_pct": [100.0, 158.0, 215.0, 273.0, 330.0],
	},
	"gold_digger": {
		"gold_bonus_pct": [15.0, 25.0, 35.0, 45.0, 55.0],
	},
	"lucky_coin": {
		"double_spawn_pct": [3.0, 7.0, 10.0, 14.0, 17.0],
	},
	"shrapnel_armor": {
		"trigger_chance_pct": [6.0, 9.0, 12.0, 14.0, 17.0],
		"shard_count": [4.0, 5.0, 6.0, 7.0, 8.0],
		"knockback_level": [1.0, 2.0, 3.0, 3.0, 4.0],
		"gauge_cost": [50.0, 44.0, 38.0, 31.0, 25.0],
	},
	"fuel_pouch": {
		"fuel_bonus_flat": [40.0, 65.0, 90.0, 115.0, 140.0],
	},
	"bluetooth_ring": {
		"gauge_gain_pct": [6.0, 11.0, 15.0, 20.0, 24.0],
	},
	"foul_whistle": {
		"negate_chance_pct": [3.0, 5.0, 7.0, 9.0, 11.0],
	},
	"smartphone": {
		"smartphone_auto_use_enabled": [1.0],
	},
	"neural_helmet": {
		"aipill_gauge_reduction": [30.0, 40.0, 50.0, 60.0, 70.0],
		"aipill_spawn_bonus_pct": [100.0, 158.0, 215.0, 273.0, 330.0],
	},
	"commando_arm": {
		"throw_speed_pct": [6.0, 11.0, 15.0, 20.0, 24.0],
		"explosion_range_pct": [3.0, 7.0, 11.0, 14.0, 18.0],
		"smoke_duration_pct": [12.0, 21.0, 30.0, 39.0, 48.0],
		"prep_reduction_pct": [12.0, 21.0, 30.0, 39.0, 48.0],
	},
	"rainbow_fur_glove": {
		"rainbow_glove_trigger_chance_pct": [3.0, 5.0, 8.0, 10.0, 12.0],
		"rainbow_glove_cooldown_reduction_pct": [20.0, 29.0, 38.0, 46.0, 55.0],
	},
	"knee_pads": {
		"knee_charge_pct": [20.0, 33.0, 45.0, 58.0, 70.0],
	},
	"soul_burst": {
		"soul_burst_gauge_cost": [170.0, 153.0, 135.0, 118.0, 100.0],
	},
	"bulletproof_hat": {
		"stun_resist_pct": [6.0, 11.0, 15.0, 20.0, 24.0],
	},
	"spiked_helmet": {
		"knockback_resist_pct": [6.0, 11.0, 15.0, 20.0, 24.0],
	},
	"venom_mist_gauntlet": {
		"mist_trigger_chance_pct": [20.0, 29.0, 38.0, 46.0, 55.0],
		"mist_duration_sec": [1.5, 2.5, 3.5, 4.5, 5.5],
	},
	"speedgear": {
		"speedgear_turn_decel_multiplier": [2.5],
	},
	"sage_ring": {
		"perk_level_bonus": [1.0, 2.0, 3.0],
		"sage_speed_penalty_pct": [8.0, 16.0, 24.0],
		"sage_body_penalty_pct": [6.0, 12.0, 18.0],
	},
}

const CONVERTED_MYTHIC_VALUES := {
	"megingjord": {
		"extra_pick_chance": 40.0,
	},
	"transcendent_crown": {
		"skill_bonus": 2.0,
	},
	"sacred_laurel": {
		"leaf_count": 8.0,
	},
	"ragnarok_hammer": {
		"trigger_chance": 30.0,
		"stun_duration": 1.0,
		"speed_boost": 25.0,
		"gauge_cost": 30.0,
	},
	"hermes_shoes": {
		"speed_bonus": 50.0,
	},
	"poseidon_trident": {
		"cooldown": 6.0,
		"gauge_cost": 30.0,
		"vortex_size": 200.0,
	},
	"heavenly_cape": {
		"skill_slot_bonus": 1.0,
		"skill_cooldown_reduction": 15.0,
	},
	"horn_strawberry_mask": {
		"transform_duration": 60.0,
	},
	"odins_eye": {
		"revival_chance": 35.0,
	},
	"celestial_armor": {
		"trigger_chance_pct": 65.0,
		"gauge_cost": 30.0,
	},
	"baal_boots": {
		"gauge_recovery": 400.0,
	},
	"pandora_legacy": {
		"selection_quality": 20.0,
		"trigger_chance": 55.0,
	},
	"angel_blessing": {
		"buff_pct": 30.0,
	},
}


# 값이 낮을수록 이득인 레인 여부(쿨타임 초·게이지 코스트류 — 융합 페널티
# 레인의 polarity=reverse 판정). 방향은 저작 테이블에서 유도한다: 레벨
# 진행으로 마지막 값이 첫 값보다 작으면 lower-better — 별도 키 명단을 두면
# 테이블과 이중 소스가 되어 드리프트한다. 단일 엔트리/불리언 테이블은
# 방향이 없으므로 false.
static func is_lower_value_better(perk_id: String, key: String) -> bool:
	var clean_id := perk_id.strip_edges()
	if not CONVERTED_PERK_VALUES.has(clean_id):
		return false
	var table: Dictionary = CONVERTED_PERK_VALUES[clean_id]
	if not table.has(key):
		return false
	var values_value: Variant = table[key]
	if not (values_value is Array):
		return false
	var values: Array = values_value
	if values.size() < 2:
		return false
	return float(values[values.size() - 1]) < float(values[0])


# Effective-level overflow (Lv.6+) domain limits. Authored table entries are
# returned verbatim; only the extrapolated overflow segment is clamped here.
# Chance / resist / reduction-percent lanes cap at 100, resource costs floor
# at 0, and the sensor auto-dash cooldown keeps a 1s minimum so overflow can
# never produce a zero-cooldown auto dash. Boomerang stun/homing pct are
# NOT chances — they feed 1.0 + pct/100 multipliers in
# mythic_item_throw_bonus_runtime, so they carry no bound here and keep
# scaling. Balance-motivated caps do NOT
# belong here — per CLAUDE.md the overflow default is "keep scaling", and any
# intentional hard cap must be declared in catalog wording too.
# sage_ring is effective_level_exempt, so its lanes never reach overflow.
const OVERFLOW_VALUE_BOUNDS := {
	"adversity_armor": {"trigger_chance_pct": {"max": 100.0}},
	"sensor": {"auto_dash_cooldown_sec": {"min": 1.0}},
	"battery": {"gauge_preserve_pct": {"max": 100.0}},
	# 감소 계열 바운드는 각 소비 코드의 실효 한도와 1:1 정합한다(레거시
	# 클램프/최소 배율과 패리티): master=95(레거시 clamp·쿨0 금지),
	# neural=90(기본 게이지 90 감산·레거시 캡 90), commando prep=95(레거시
	# 캡·최소 배율 0.05), rainbow 쿨감=95(소비자 0.95 클램프).
	"master": {"item_cooldown_pct": {"max": 95.0}},
	"lucky_coin": {"double_spawn_pct": {"max": 100.0}},
	"shrapnel_armor": {
		"trigger_chance_pct": {"max": 100.0},
		"gauge_cost": {"min": 0.0},
	},
	"foul_whistle": {"negate_chance_pct": {"max": 100.0}},
	"neural_helmet": {"aipill_gauge_reduction": {"max": 90.0}},
	"commando_arm": {"prep_reduction_pct": {"max": 95.0}},
	"rainbow_fur_glove": {
		"rainbow_glove_trigger_chance_pct": {"max": 100.0},
		"rainbow_glove_cooldown_reduction_pct": {"max": 95.0},
	},
	"soul_burst": {"soul_burst_gauge_cost": {"min": 0.0}},
	"bulletproof_hat": {"stun_resist_pct": {"max": 100.0}},
	"spiked_helmet": {"knockback_resist_pct": {"max": 100.0}},
	"venom_mist_gauntlet": {"mist_trigger_chance_pct": {"max": 100.0}},
	"dowsing_goggles": {"bonus_perk_chance": {"max": 100.0}},
}


static func get_value(perk_id: String, key: String, level: int, fusion_overlay_source: Object = null) -> float:
	var clean_id := perk_id.strip_edges()
	if not CONVERTED_PERK_VALUES.has(clean_id):
		return 0.0
	var table: Dictionary = CONVERTED_PERK_VALUES[clean_id]
	if not table.has(key):
		return 0.0
	var values: Array = table[key]
	if values.is_empty():
		return 0.0
	var index := clampi(int(level), 1, values.size()) - 1
	var base_value := float(values[index])
	# 저작 테이블 밖 오버플로우 레벨(왕관/반지/한계돌파 성장)은 테이블
	# 평균 기울기로 선형 외삽한다 — plateau 모양 테이블(sensor 토큰
	# [1,1,2,2,2])은 마지막 구간 기울기가 0이라 그 방식으로는 레인이 영원히
	# 동결된다(씰 계약=평균 기울기). 유효레벨 오버플로우는 기본이 계속
	# 스케일이고(하드캡 금지), OVERFLOW_VALUE_BOUNDS는 도메인 무결(확률
	# >100%·음수 비용·0초 쿨다운)만 클램프한다.
	if int(level) > values.size() and values.size() >= 2:
		var average_step := (float(values[values.size() - 1]) - float(values[0])) / float(values.size() - 1)
		base_value += average_step * float(int(level) - values.size())
		base_value = _clamp_overflow_value(clean_id, key, base_value)
	# 4번째 인자(runtime_perk_state)가 있으면 융합 오버레이를 적용한다 —
	# 정수 레인은 코어가 성장한 base에 대해 라이브 재양자화한다(3인자
	# 호출은 융합 이전 원값으로 하위호환).
	if fusion_overlay_source != null and fusion_overlay_source.has_method("apply_perk_fusion_option_value"):
		return float(fusion_overlay_source.apply_perk_fusion_option_value(clean_id, key, base_value))
	return base_value


static func _clamp_overflow_value(perk_id: String, key: String, value: float) -> float:
	var perk_bounds: Dictionary = OVERFLOW_VALUE_BOUNDS.get(perk_id, {})
	var bounds: Dictionary = perk_bounds.get(key, {})
	var bounded := value
	if bounds.has("min"):
		bounded = maxf(bounded, float(bounds["min"]))
	if bounds.has("max"):
		bounded = minf(bounded, float(bounds["max"]))
	return bounded


static func get_mythic_value(perk_id: String, key: String) -> float:
	var clean_id := perk_id.strip_edges()
	if not CONVERTED_MYTHIC_VALUES.has(clean_id):
		return 0.0
	var table: Dictionary = CONVERTED_MYTHIC_VALUES[clean_id]
	return float(table.get(key, 0.0))


static func has_perk(perk_id: String) -> bool:
	var clean_id := perk_id.strip_edges()
	return CONVERTED_PERK_VALUES.has(clean_id) or CONVERTED_MYTHIC_VALUES.has(clean_id)


static func get_value_keys(perk_id: String) -> Array:
	var clean_id := perk_id.strip_edges()
	var keys: Array = []
	if CONVERTED_PERK_VALUES.has(clean_id):
		keys = CONVERTED_PERK_VALUES[clean_id].keys()
	elif CONVERTED_MYTHIC_VALUES.has(clean_id):
		keys = CONVERTED_MYTHIC_VALUES[clean_id].keys()
	keys.sort()
	return keys


static func get_effective_converted_perk_level(perk_id: String, base_level: int, bonus: int) -> int:
	var clean_id := perk_id.strip_edges()
	var safe_base: int = maxi(0, int(base_level))
	if safe_base <= 0:
		return 0
	if _is_effective_level_exempt(clean_id):
		return clampi(safe_base, 0, _get_catalog_max_level(clean_id))
	return safe_base + maxi(0, int(bonus))


static func _is_effective_level_exempt(perk_id: String) -> bool:
	var data: Dictionary = _get_catalog_data(perk_id)
	return bool(data.get("effective_level_exempt", false))


static func _get_catalog_max_level(perk_id: String) -> int:
	var data: Dictionary = _get_catalog_data(perk_id)
	return max(1, int(data.get("max_level", 1)))


static func _get_catalog_data(perk_id: String) -> Dictionary:
	if RuntimePerkCatalog.CONVERTED_PERKS.has(perk_id):
		return RuntimePerkCatalog.CONVERTED_PERKS[perk_id]
	if RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.has(perk_id):
		return RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS[perk_id]
	return {}
