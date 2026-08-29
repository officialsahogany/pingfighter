extends RefCounted

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")

const CONVERSION_SOURCE_TO_PERK := {
	"star_detector": "star_detector",
	"adversity_armor": "adversity_armor",
	"reinforced_boomerang_gauntlet": "reinforced_boomerang_gauntlet",
	"sensor": "sensor",
	"gravitybelt": "gravitybelt",
	"dowsing_pendulum": "dowsing_pendulum",
	"chargebag": "chargebag",
	"battery": "battery",
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
	"venom_mist_gauntlet": "venom_mist_gauntlet",
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
	"yangui_hoechun": "yangui_hoechun",
}

const RETIRED_CONVERTED_PERK_IDS := {
	"item_bag_expansion": true,
	"revival": true,
	"speedgear": true,
	"spiked_helmet": true,
}

const RETIRED_CONVERTED_PERK_MIGRATIONS := {
	"spiked_helmet": "bulletproof_hat",
}

const DELETED_ITEM_COMPENSATION := {
	"dashholder": ["dash_amplification"],
	"speedboots": ["common_swiftness"],
	"bulkup": ["common_bulk_up"],
	"spikeboots": ["dash_module_control", "dash_lightweight"],
	"dashgear": ["dash_jump", "perk_boost_charge"],
	"cooltime": ["item_cooldown_mastery"],
	"timer_belt": ["common_training"],
}

# R1 redesign group: gold_bar is intentionally absent from conversion and
# deleted-item compensation maps. The other redesign ids are wired as perks.
const NON_TARGET_CONVERTED_PERK_VALUES := {
	"gravitybelt": {
		"gravitybelt_instant_movement": [1.0],
	},
	"fuel_pouch": {
		"fuel_bonus_flat": [40.0, 65.0, 90.0, 115.0, 140.0],
	},
	"bluetooth_ring": {
		"gauge_gain_pct": [6.0, 11.0, 15.0, 20.0, 24.0],
	},
	"smartphone": {
		"smartphone_auto_use_enabled": [1.0],
	},
	"bulletproof_hat": {
		"posture_correction_pct": [6.0, 11.0, 15.0, 20.0, 24.0],
	},
}

# Compatibility inspection surface used by fusion/tests. Converted target and
# adjunct tables are mirrored once from RuntimePerkProgression at script load;
# gameplay reads those registered lanes directly from the owner below.
static var CONVERTED_PERK_VALUES: Dictionary = _build_converted_perk_values()

# 개광결은 전환 일반무공의 연속 수치 레인 전체를 증폭한다. 정수 횟수와
# on/off 상태는 배율을 곱하면 경계가 깨지므로 구조값으로 분류해 그대로 둔다.
# 신규 전환 레인은 기본적으로 증폭 대상이며, 구조값을 추가할 때만 이 표에
# 명시한다. 이 fail-open 정책은 "모든 무공의 수치 효과"라는 개광결 계약을
# 신규 무공에도 자동으로 유지하기 위한 것이다.
const NON_TARGET_POLISH_STRUCTURAL_OPTION_KEYS := {
	"gravitybelt": {
		"gravitybelt_instant_movement": true,
	},
	"smartphone": {
		"smartphone_auto_use_enabled": true,
	},
}

static var POLISH_STRUCTURAL_OPTION_KEYS: Dictionary = _build_polish_structural_option_keys()

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
	"yangui_hoechun": {
		"trigger_chance": 50.0,
		"gauge_cost": 30.0,
	},
}


static func _build_converted_perk_values() -> Dictionary:
	# One script-load-time compatibility index. No per-frame merge or copy.
	var index: Dictionary = NON_TARGET_CONVERTED_PERK_VALUES.duplicate(true)
	for perk_id_value: Variant in RuntimePerkProgression.PROGRESSIONS.keys():
		var perk_id := str(perk_id_value)
		if not RuntimePerkProgression.is_converted_perk(perk_id):
			continue
		var raw_lanes: Dictionary = {}
		for lane_id_value: Variant in RuntimePerkProgression.get_lane_ids(perk_id):
			var lane_id := str(lane_id_value)
			raw_lanes[lane_id] = RuntimePerkProgression.get_authored_values_reference(perk_id, lane_id)
		index[perk_id] = raw_lanes
	return index


static func _build_polish_structural_option_keys() -> Dictionary:
	var index: Dictionary = NON_TARGET_POLISH_STRUCTURAL_OPTION_KEYS.duplicate(true)
	for perk_id_value: Variant in RuntimePerkProgression.PROGRESSIONS.keys():
		var perk_id := str(perk_id_value)
		if not RuntimePerkProgression.is_converted_perk(perk_id):
			continue
		var structural_lanes: Dictionary = {}
		for lane_id_value: Variant in RuntimePerkProgression.get_lane_ids(perk_id):
			var lane_id := str(lane_id_value)
			if not RuntimePerkProgression.is_polish_amplifiable_lane(perk_id, lane_id):
				structural_lanes[lane_id] = true
		if not structural_lanes.is_empty():
			index[perk_id] = structural_lanes
	return index


static func _build_overflow_value_bounds() -> Dictionary:
	var index: Dictionary = NON_TARGET_OVERFLOW_VALUE_BOUNDS.duplicate(true)
	for perk_id_value: Variant in RuntimePerkProgression.PROGRESSIONS.keys():
		var perk_id := str(perk_id_value)
		if not RuntimePerkProgression.is_converted_perk(perk_id):
			continue
		var progression: Dictionary = RuntimePerkProgression.PROGRESSIONS.get(perk_id, {})
		var lanes: Dictionary = progression.get("lanes", {})
		var perk_bounds: Dictionary = {}
		for lane_id_value: Variant in lanes.keys():
			var lane_id := str(lane_id_value)
			var lane: Dictionary = lanes.get(lane_id, {})
			var bounds: Dictionary = {}
			if lane.has("min"):
				bounds["min"] = float(lane["min"])
			if lane.has("max"):
				bounds["max"] = float(lane["max"])
			if not bounds.is_empty():
				perk_bounds[lane_id] = bounds
		if not perk_bounds.is_empty():
			index[perk_id] = perk_bounds
	return index


static func is_retired_converted_perk_id(perk_id: String) -> bool:
	return bool(RETIRED_CONVERTED_PERK_IDS.get(perk_id.strip_edges(), false))


static func sanitize_runtime_levels(runtime_levels: Dictionary) -> Dictionary:
	var sanitized: Dictionary = runtime_levels.duplicate(true)
	for source_id_value: Variant in RETIRED_CONVERTED_PERK_MIGRATIONS.keys():
		var source_id := str(source_id_value)
		var target_id := str(RETIRED_CONVERTED_PERK_MIGRATIONS[source_id_value])
		var source_level := _get_stored_runtime_level(sanitized, source_id)
		var target_level := _get_stored_runtime_level(sanitized, target_id)
		sanitized.erase(source_id)
		sanitized.erase(StringName(source_id))
		sanitized.erase(target_id)
		sanitized.erase(StringName(target_id))
		if source_level > 0 or target_level > 0:
			var target_data: Dictionary = RuntimePerkCatalog.CONVERTED_PERKS.get(target_id, {})
			var max_level := maxi(1, int(target_data.get(
				"max_level", RuntimePerkProgression.get_authored_max_level(target_id)
			)))
			sanitized[target_id] = mini(max_level, source_level + target_level)
	for perk_id_value: Variant in RETIRED_CONVERTED_PERK_IDS.keys():
		var perk_id := str(perk_id_value)
		sanitized.erase(perk_id)
		sanitized.erase(StringName(perk_id))
	return sanitized


static func count_retired_runtime_level_entries(runtime_levels: Dictionary) -> int:
	var count := 0
	for perk_id_value: Variant in RETIRED_CONVERTED_PERK_IDS.keys():
		var perk_id := str(perk_id_value)
		if runtime_levels.has(perk_id) or runtime_levels.has(StringName(perk_id)):
			count += 1
	return count


static func _get_stored_runtime_level(runtime_levels: Dictionary, perk_id: String) -> int:
	return maxi(
		maxi(0, int(runtime_levels.get(perk_id, 0))),
		maxi(0, int(runtime_levels.get(StringName(perk_id), 0)))
	)


# 값이 낮을수록 이득인 레인 여부(쿨타임 초·게이지 코스트류 — 융합 페널티
# 레인의 polarity=reverse 판정). 방향은 저작 테이블에서 유도한다: 레벨
# 진행으로 마지막 값이 첫 값보다 작으면 lower-better — 별도 키 명단을 두면
# 테이블과 이중 소스가 되어 드리프트한다. 단일 엔트리/불리언 테이블은
# 방향이 없으므로 false.
static func is_lower_value_better(perk_id: String, key: String) -> bool:
	var clean_id := perk_id.strip_edges()
	var clean_key := key.strip_edges()
	if RuntimePerkProgression.is_converted_perk(clean_id):
		return (
			RuntimePerkProgression.has_lane(clean_id, clean_key)
			and RuntimePerkProgression.get_lane_polarity(clean_id, clean_key)
				== RuntimePerkProgression.POLARITY_LOWER_IS_BETTER
		)
	if not CONVERTED_PERK_VALUES.has(clean_id):
		return false
	var table: Dictionary = CONVERTED_PERK_VALUES[clean_id]
	if not table.has(clean_key):
		return false
	var values_value: Variant = table[clean_key]
	if not (values_value is Array):
		return false
	var values: Array = values_value
	if values.size() < 2:
		return false
	return float(values[values.size() - 1]) < float(values[0])


static func is_polish_amplifiable_option(perk_id: String, key: String) -> bool:
	var clean_id := perk_id.strip_edges()
	var clean_key := key.strip_edges()
	if RuntimePerkProgression.is_converted_perk(clean_id):
		return (
			RuntimePerkProgression.has_lane(clean_id, clean_key)
			and RuntimePerkProgression.is_polish_amplifiable_lane(clean_id, clean_key)
		)
	if clean_id.is_empty() or clean_key.is_empty() or not CONVERTED_PERK_VALUES.has(clean_id):
		return false
	var table: Dictionary = CONVERTED_PERK_VALUES[clean_id]
	if not table.has(clean_key):
		return false
	if not POLISH_STRUCTURAL_OPTION_KEYS.has(clean_id):
		return true
	var structural_keys: Dictionary = POLISH_STRUCTURAL_OPTION_KEYS[clean_id]
	return not bool(structural_keys.get(clean_key, false))


static func has_polish_amplifiable_option(perk_id: String) -> bool:
	var clean_id := perk_id.strip_edges()
	if RuntimePerkProgression.is_converted_perk(clean_id):
		return RuntimePerkProgression.has_polish_amplifiable_lane(clean_id)
	if not CONVERTED_PERK_VALUES.has(clean_id):
		return false
	var option_table: Dictionary = CONVERTED_PERK_VALUES[clean_id]
	if not POLISH_STRUCTURAL_OPTION_KEYS.has(clean_id):
		return not option_table.is_empty()
	var structural_keys: Dictionary = POLISH_STRUCTURAL_OPTION_KEYS[clean_id]
	for key_value: Variant in option_table.keys():
		if not bool(structural_keys.get(str(key_value), false)):
			return true
	return false


# Effective-level overflow (Lv.4+ for the migrated 37) domain limits. Authored table entries are
# returned verbatim; only the extrapolated overflow segment is clamped here.
# Chance / resist lanes cap at 100; reduction-percent lanes cap at their
# CONSUMER's effective limit (neural 90 = base-gauge subtraction, master /
# commando / rainbow 95 = legacy clamps and the 0.95 consumer fraction);
# resource costs floor at 0, and the sensor auto-dash cooldown keeps a 1s
# minimum so overflow can never produce a zero-cooldown auto dash. Boomerang stun/homing pct are
# NOT chances — they feed 1.0 + pct/100 multipliers in
# mythic_item_throw_bonus_runtime, so they carry no bound here and keep
# scaling. Balance-motivated caps do NOT
# belong here — per CLAUDE.md the overflow default is "keep scaling", and any
# intentional hard cap must be declared in catalog wording too.
# sage_ring is effective_level_exempt, so its proc spec always follows the
# invested Lv.1-3 table and never extrapolates from another level-buff source.
const NON_TARGET_OVERFLOW_VALUE_BOUNDS := {
	"bulletproof_hat": {"posture_correction_pct": {"max": 100.0}},
}

static var OVERFLOW_VALUE_BOUNDS: Dictionary = _build_overflow_value_bounds()


static func get_value(perk_id: String, key: String, level: int, fusion_overlay_source: Object = null) -> float:
	var resolved_value := get_value_before_fusion(perk_id, key, level, fusion_overlay_source)
	if (
		fusion_overlay_source != null
		and fusion_overlay_source.has_method("apply_perk_fusion_option_value")
	):
		resolved_value = float(fusion_overlay_source.apply_perk_fusion_option_value(
			perk_id.strip_edges(),
			key.strip_edges(),
			resolved_value
		))
	return resolved_value


# Four-argument canonical read for displays that need the current live value
# before a fusion scar is applied. This shares the same authored table,
# overflow bounds, and Polish direction rules as get_value(); consumers must
# not rebuild the value from the three-argument raw read plus a multiplier.
static func get_value_before_fusion(
	perk_id: String,
	key: String,
	level: int,
	runtime_state: Object = null
) -> float:
	var clean_id := perk_id.strip_edges()
	if not CONVERTED_PERK_VALUES.has(clean_id):
		return 0.0
	var clean_key := key.strip_edges()
	if RuntimePerkProgression.is_converted_perk(clean_id):
		if not RuntimePerkProgression.has_lane(clean_id, clean_key):
			return 0.0
		var canonical_value := RuntimePerkProgression.get_value(clean_id, clean_key, level)
		if (
			runtime_state == null
			or not is_polish_amplifiable_option(clean_id, clean_key)
			or not runtime_state.has_method("get_perk_amplify_multiplier")
		):
			return canonical_value
		return apply_polish_amplification(
			clean_id,
			clean_key,
			canonical_value,
			float(runtime_state.call("get_perk_amplify_multiplier", clean_id))
		)
	var table: Dictionary = CONVERTED_PERK_VALUES[clean_id]
	if not table.has(clean_key):
		return 0.0
	var values: Array = table[clean_key]
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
		base_value = _clamp_overflow_value(clean_id, clean_key, base_value)
	if (
		runtime_state == null
		or not is_polish_amplifiable_option(clean_id, clean_key)
		or not runtime_state.has_method("get_perk_amplify_multiplier")
	):
		return base_value
	return apply_polish_amplification(
		clean_id,
		clean_key,
		base_value,
		float(runtime_state.call("get_perk_amplify_multiplier", clean_id))
	)


static func apply_polish_amplification(perk_id: String, key: String, value: float, multiplier: float) -> float:
	var clean_id := perk_id.strip_edges()
	var clean_key := key.strip_edges()
	if not is_polish_amplifiable_option(clean_id, clean_key):
		return value
	var safe_multiplier := maxf(1.0, multiplier)
	if safe_multiplier <= 1.0 + 0.0001:
		return value
	# 쿨타임·기력 비용처럼 낮을수록 좋은 저하향 레인은 나눗셈으로 강화한다.
	# 일반 레인은 곱셈으로 강화해 어느 방향이든 플레이어에게 이득이 된다.
	var amplified := value / safe_multiplier if is_lower_value_better(clean_id, clean_key) else value * safe_multiplier
	return _clamp_overflow_value(clean_id, clean_key, amplified)


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
