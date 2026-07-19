extends RefCounted

# Lv.6+ (effective-level overflow) perk stat-line generator.
#
# transcendent_crown / sage_ring / ignition aura raise a perk's effective level
# past its authored `descriptions` cap (usually Lv.5). Runtime keeps scaling
# (CLAUDE.md effective-level overflow default), but tooltips fell back to the
# highest authored text, so a Lv.7 도약 still displayed the Lv.5 "대쉬 거리 35%
# 증가" line (2026-07-10 bug). This is the Godot port of legacy pingfighter.py
# `get_runtime_skill_description()`.
#
# CONTRACT (sealed by runtime_perk_overflow_description_smoke.gd):
# - For every registered perk, `generate_stats_text()` must reproduce the
#   catalog's authored `descriptions[level]` VERBATIM at every defined level.
#   The pattern constants therefore cannot silently drift from catalog wording:
#   a catalog text edit fails the smoke and forces a matching template update.
# - Overflow (Lv.6+) values follow the RUNTIME lanes: linear lanes mirror
#   runtime_perk_effective_levels.gd constants, converted perks are
#   single-sourced through PerkConversionValues.get_value() (which already
#   extrapolates + bounds overflow), and the viper four_poisons tables mirror
#   ViperSkillRuntime FOUR_POISONS_* consts (equality-sealed in the smoke).
# - Korean-only: non-Korean locales rewrite every descriptions[level] to one
#   summary string (localize_perk_data), so overflow generation stays on the
#   authored-fallback path there (the collapsed single-panel behavior).
# - Known runtime-vs-catalog wording gaps (kick_enhance 정밀도/공속 lanes) keep
#   following the AUTHORED pattern so the Lv.6+ line stays consistent with the
#   Lv.1~5 lines the player already read; reconciling those numbers is a
#   design decision, not a display fix.

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

# Linear "prefix + per_level * L + suffix" lanes (legacy skill_patterns port).
# per_level values mirror runtime_perk_effective_levels.gd's
# get_runtime_skill_bonus() match block; value_max mirrors the runtime clamp
# where one exists (item_recycle MAX_ITEM_RECYCLE_CHANCE, boost charge 100%).
const LINEAR_PATTERNS := {
	"dash_lightweight": {"prefix": "대쉬 쿨타임 ", "per_level": 12, "suffix": "% 감소"},
	"dash_module_control": {"prefix": "대쉬 후딜 ", "per_level": 18, "suffix": "% 감소"},
	"dash_jump": {"prefix": "대쉬 거리 ", "per_level": 7, "suffix": "% 증가"},
	"dash_acceleration": {"prefix": "대쉬시 패들 크기 ", "per_level": 70, "suffix": "% 증가"},
	"dash_amplification": {"prefix": "대쉬토큰 슬롯 +", "per_level": 1, "suffix": ""},
	"dash_spirit": {"prefix": "대쉬시 ", "per_level": 7, "suffix": "% 확률로 레이저 잔상"},
	"item_luck": {"prefix": "아이템 스폰 대기 ", "per_level": 12, "suffix": "% 감소"},
	"item_cooldown_mastery": {"prefix": "액티브 아이템 쿨타임 ", "per_level": 13, "suffix": "% 감소"},
	"item_gauge_mastery": {"prefix": "액티브 사용시 게이지 +", "per_level": 15, "suffix": ""},
	"item_caffeine": {"prefix": "타이머형 아이템 지속 ", "per_level": 30, "suffix": "% 증가"},
	"item_polish": {"prefix": "적용 대상 퍽의 수치 능력치 ", "per_level": 5, "suffix": "% 증폭"},
	"item_recycle": {"prefix": "아이템 유지 확률 ", "per_level": 7, "suffix": "%", "value_max": 90},
	"item_bag_expansion": {"prefix": "액티브 슬롯 +", "per_level": 1, "suffix": ""},
	"common_swiftness": {"prefix": "이동속도 ", "per_level": 6, "suffix": "% 증가"},
	"common_bulk_up": {"prefix": "패들 크기 ", "per_level": 6, "suffix": "% 증가"},
	"common_training": {"prefix": "모든 스킬 쿨타임 ", "per_level": 8, "suffix": "% 감소"},
	"perk_boost_charge": {"prefix": "확률 +", "per_level": 7, "suffix": "%, 발동 시 다음 대쉬 무료 + 토큰 충전 -90%", "value_max": 100},
	"perk_laurel_shield": {"prefix": "월계수 잎 ", "per_level": 1, "suffix": "개 보호"},
	"extension_gear": {"prefix": "리커버리/클렌즈/워프게이트 지속시간 +", "per_level": 25, "suffix": "%"},
}

# Converted-perk lane templates. Values come straight from
# PerkConversionValues.get_value(id, key, level), which is the SAME call the
# runtime consumers make, so the Lv.6+ text is single-sourced with gameplay
# (including OVERFLOW_VALUE_BOUNDS clamps). int_keys mirror consumers that
# read the lane with int(round(...)) (shard/token counts, knockback level).
const CONVERTED_TEMPLATES := {
	"star_detector": {"format": "스타포인트 보너스 드랍 확률 +%s%%", "keys": ["star_bonus_pct"]},
	"adversity_armor": {"format": "실점 후 발동 %s%%, 보호 %s초", "keys": ["trigger_chance_pct", "invincible_duration_sec"]},
	"reinforced_boomerang_gauntlet": {
		"format": "부메랑 넉백 +%s%%, 스턴 +%s%%, 발사속도 +%s%%, 유도 +%s%%, 스폰 +%s%%",
		"keys": ["boomerang_knockback_pct", "boomerang_stun_pct", "boomerang_launch_speed_pct", "boomerang_homing_pct", "boomerang_spawn_bonus_pct"],
	},
	"sensor": {
		"format": "자동대쉬 토큰 %s개, 쿨타임 %s초",
		"keys": ["auto_dash_token_count", "auto_dash_cooldown_sec"],
		"int_keys": {"auto_dash_token_count": true},
	},
	"dowsing_pendulum": {"format": "필드 아이템·스타포인트 흡인 범위 %spx", "keys": ["attraction_range"]},
	"dowsing_goggles": {"format": "퍽 선택지 보너스 발동 확률 %s%%", "keys": ["bonus_perk_chance"]},
	"chargebag": {"format": "벽 반사 게이지 +%s%%", "keys": ["chargebag_pct"]},
	"battery": {"format": "스테이지 전환 게이지 보존 %s%%", "keys": ["gauge_preserve_pct"]},
	"master": {
		"format": "벽돌 길이 +%s%%, 아이템 쿨타임 %s%% 감소, 벽돌 스폰 +%s%%",
		"keys": ["wall_length_pct", "item_cooldown_pct", "wall_spawn_bonus_pct"],
	},
	"gold_digger": {"format": "골드 획득 +%s%%", "keys": ["gold_bonus_pct"]},
	"lucky_coin": {"format": "아이템 더블스폰 확률 %s%%", "keys": ["double_spawn_pct"]},
	"shrapnel_armor": {
		"format": "발동 %s%%, 파편 %s개, 넉백 Lv.%s, 게이지 %s 소모",
		"keys": ["trigger_chance_pct", "shard_count", "knockback_level", "gauge_cost"],
		"int_keys": {"shard_count": true, "knockback_level": true},
	},
	"fuel_pouch": {"format": "최대 게이지 +%s", "keys": ["fuel_bonus_flat"]},
	"bluetooth_ring": {"format": "히트 게이지 +%s%%", "keys": ["gauge_gain_pct"]},
	"foul_whistle": {"format": "실점 무효 확률 %s%%", "keys": ["negate_chance_pct"]},
	"neural_helmet": {
		"format": "AI알약 게이지 비용 %s 감소, 스폰 +%s%%",
		"keys": ["aipill_gauge_reduction", "aipill_spawn_bonus_pct"],
	},
	"commando_arm": {
		"format": "투척 속도 +%s%%, 폭발 +%s%%, 연막 +%s%%, 준비 %s%% 감소",
		"keys": ["throw_speed_pct", "explosion_range_pct", "smoke_duration_pct", "prep_reduction_pct"],
	},
	"rainbow_fur_glove": {
		"format": "공 히트 시 발동 %s%%, 진행 중 스킬 쿨타임 %s%% 감소",
		"keys": ["rainbow_glove_trigger_chance_pct", "rainbow_glove_cooldown_reduction_pct"],
	},
	"knee_pads": {"format": "하프대쉬 히트 게이지 +%s%%", "keys": ["knee_charge_pct"]},
	"soul_burst": {"format": "대쉬 토큰이 없을 때 풀대쉬 소모 %s", "keys": ["soul_burst_gauge_cost"]},
	"bulletproof_hat": {"format": "스턴 저항 +%s%%", "keys": ["stun_resist_pct"]},
	"spiked_helmet": {"format": "넉백 저항 +%s%%", "keys": ["knockback_resist_pct"]},
	"venom_mist_gauntlet": {"format": "독안개 발동 %s%%, 지속 %s초", "keys": ["mist_trigger_chance_pct", "mist_duration_sec"]},
}

# four_poisons lane tables — MUST stay equal to ViperSkillRuntime
# FOUR_POISONS_* consts (equality-sealed in the smoke). Index = level,
# overflow = values[last] + (L - last) * per_extra, clamped to cap
# (same math as ViperSkillScaling.get_four_poisons_scaled_pct).
const FOUR_POISONS_PREP := {"values": [0, 8, 16, 25, 33, 40], "per_extra": 4, "cap": 70}
const FOUR_POISONS_SLEEP := {"values": [0, 5, 10, 15, 20, 25], "per_extra": 5, "cap": 50}
const FOUR_POISONS_CONFUSION := {"values": [0, 12, 24, 36, 48, 70], "per_extra": 10, "cap": 150}
const FOUR_POISONS_DUAL_DURATION := {"values": [0, 7, 14, 20, 27, 33], "per_extra": 5, "cap": 45}
const FOUR_POISONS_COOLDOWN := {"values": [0, 0, 0, 10, 15, 20], "per_extra": 4, "cap": 40}
const FOUR_POISONS_CLONE_HP := {"values": [2, 2, 2, 3, 3, 4], "cap": 6}

# pistol_enhance authored spread ladder (mirrors commando_firearm_runtime.gd
# PISTOL_ENHANCE_SPREAD_DEGREES minus the level-0 slot; index clamps at Lv.5
# like the runtime consumer, so Lv.6+ keeps ±1°).
const PISTOL_ENHANCE_SPREAD_DEGREES := [12, 9, 6, 3, 1]


# Full stat-line resolution: authored text at defined levels, generated text
# for Korean overflow levels, highest-defined text as the final fallback
# (non-Korean locales and unregistered perks). Returns "" only when the
# descriptions dict itself is empty/unusable.
static func resolve_stats_text(skill_id: String, descriptions: Dictionary, level: int) -> String:
	var authored: Variant = _description_at(descriptions, level)
	if authored != null:
		return str(authored)
	if level <= 0:
		return ""
	var generated: String = generate_stats_text(skill_id, level)
	if generated != "":
		return generated
	var highest: Variant = _highest_defined_description(descriptions, level)
	return str(highest) if highest != null else ""


# Pattern-generated stat line for any level (the smoke also calls this at
# authored levels to seal template-vs-catalog equality). Returns "" for
# unregistered perks and non-Korean locales.
static func generate_stats_text(skill_id: String, level: int) -> String:
	if level <= 0:
		return ""
	if LanguageSettings.get_language() != LanguageSettings.LANGUAGE_KOREAN:
		return ""
	var clean_id: String = skill_id.strip_edges()
	if LINEAR_PATTERNS.has(clean_id):
		return _linear_pattern_text(clean_id, level)
	if CONVERTED_TEMPLATES.has(clean_id):
		return _converted_template_text(clean_id, level)
	match clean_id:
		"combo_amplifier_chip":
			return _combo_amplifier_chip_text(level)
		"pistol_enhance":
			return _pistol_enhance_text(level)
		"jetpack_enhance":
			return _jetpack_enhance_text(level)
		"kick_enhance":
			return _kick_enhance_text(level)
		"blade_amp":
			return _blade_amp_text(level)
		"four_poisons":
			return _four_poisons_text(level)
	return ""


static func _linear_pattern_text(skill_id: String, level: int) -> String:
	var pattern: Dictionary = LINEAR_PATTERNS[skill_id]
	var value: int = int(pattern["per_level"]) * level
	if pattern.has("value_max"):
		value = mini(value, int(pattern["value_max"]))
	return "%s%d%s" % [str(pattern["prefix"]), value, str(pattern["suffix"])]


static func _converted_template_text(skill_id: String, level: int) -> String:
	var template: Dictionary = CONVERTED_TEMPLATES[skill_id]
	var keys: Array = template["keys"]
	var int_keys: Dictionary = template.get("int_keys", {})
	var args: Array = []
	for key_value in keys:
		var key: String = str(key_value)
		var value: float = PerkConversionValues.get_value(skill_id, key, level)
		if bool(int_keys.get(key, false)):
			args.append(str(int(round(value))))
		else:
			args.append(_format_number(value))
	return str(template["format"]) % args


# drive_curve caps at Lv.3 and the initial-boost decay reduction at 50%
# (runtime: get_combo_amplifier_chip_bonus min(L,3), smasher_power_smash_
# motion_resolver max(0.5, 1 - L*0.10)); the authored text marks both with
# "(캡)" from the level the cap engages.
static func _combo_amplifier_chip_text(level: int) -> String:
	var drive_speed: int = 90 * level
	var curve: int = 5 * mini(level, 3)
	var curve_cap: String = "(캡)" if level > 3 else ""
	var smash_speed: int = 45 * level
	var decay: int = mini(10 * level, 50)
	var decay_cap: String = "(캡)" if 10 * level >= 50 else ""
	return "콤보 효과 증폭: 드라이브 공속+%d%%, 커브+%d%%%s, 파워스매시 공속+%d%%, 초기부스트 감쇄 -%d%%%s" % [
		drive_speed, curve, curve_cap, smash_speed, decay, decay_cap,
	]


# Lv.6+ contract is documented in the catalog detail: accuracy/speed/knockback
# hold at the Lv.5 values while the magazine keeps growing +1 per level
# (runtime: commando_firearm_runtime.gd clampi(L,·,5) lanes + ammo bonus
# L-3 for L>=5).
static func _pistol_enhance_text(level: int) -> String:
	var spread_deg: int = PISTOL_ENHANCE_SPREAD_DEGREES[clampi(level, 1, 5) - 1]
	var speed: int = 10 * mini(level, 5)
	var knockback: int = 30 * mini(level, 5)
	var ammo_bonus: int = 0
	if level >= 5:
		ammo_bonus = level - 3
	elif level >= 3:
		ammo_bonus = 1
	return "기본권총 정확도 ±%d°, 탄속 +%d%%, 넉백 +%d%%, 탄창 %d발" % [
		spread_deg, speed, knockback, 5 + ammo_bonus,
	]


# Runtime: viper_jetpack_state.gd — max gauge +20%/lv uncapped, airborne
# gauge gain (L-2)*10% from Lv.3 uncapped.
static func _jetpack_enhance_text(level: int) -> String:
	var text: String = "제트팩 최대 게이지 +%d%%" % (20 * level)
	if level >= 3:
		text += ", 체공 중 게이지 획득 +%d%%" % (10 * (level - 2))
	return text


# Continues the AUTHORED per-level pattern (정밀도 8%/lv, 공속 12%/lv) even
# though the runtime lanes currently use different constants (0.09 / 0.04 in
# viper_skill_geometry/scaling) — see module header. 준비 cap 90 and the
# furnace knockback-ball (L-2)*10% cap 100 mirror the runtime.
static func _kick_enhance_text(level: int) -> String:
	var text: String = "킥 발사 정밀도 +%d%%, 공속 +%d%%, 준비 -%d%%" % [
		8 * level, 12 * level, mini(7 * level, 90),
	]
	if level >= 3:
		text += ", 용광로 넉백볼 %d%%" % mini((level - 2) * 10, 100)
	return text


# Runtime: range/width clamps at Lv.5 (+50%), speed keeps scaling +10%/lv
# (viper_skill_geometry.gd). The homing labels follow the authored gating.
static func _blade_amp_text(level: int) -> String:
	var range_cap: String = "(캡)" if level > 5 else ""
	var text: String = "검기 사거리/가로폭 +%d%%%s, 검기 속도 +%d%%" % [
		10 * mini(level, 5), range_cap, 10 * level,
	]
	if level >= 5:
		text += ", 추가 유도검기"
	elif level >= 3:
		text += ", 유도검기"
	return text


static func _four_poisons_text(level: int) -> String:
	var text: String = "EMP/카오스 준비 -%d%%, EMP 수면 +%d%%, 베놈 혼란 +%d%%, 듀얼 지속 +%d%%" % [
		_four_poisons_scaled_pct(level, FOUR_POISONS_PREP),
		_four_poisons_scaled_pct(level, FOUR_POISONS_SLEEP),
		_four_poisons_scaled_pct(level, FOUR_POISONS_CONFUSION),
		_four_poisons_scaled_pct(level, FOUR_POISONS_DUAL_DURATION),
	]
	if level >= 3:
		text += ", 듀얼 HP %d, 4스킬 쿨 -%d%%, 슈퍼아머" % [
			_four_poisons_clone_hp(level),
			_four_poisons_scaled_pct(level, FOUR_POISONS_COOLDOWN),
		]
	if level >= 5:
		text += ", 분신 복제"
	return text


# Same math as ViperSkillScaling.get_four_poisons_scaled_pct.
static func _four_poisons_scaled_pct(level: int, lane: Dictionary) -> int:
	if level <= 0:
		return 0
	var values: Array = lane["values"]
	if level < values.size():
		return int(values[level])
	var last_index: int = values.size() - 1
	return mini(int(lane["cap"]), int(values[last_index]) + (level - last_index) * int(lane["per_extra"]))


# Same math as ViperSkillScaling.get_dual_glitch_clone_hp.
static func _four_poisons_clone_hp(level: int) -> int:
	var safe_level: int = maxi(0, level)
	var values: Array = FOUR_POISONS_CLONE_HP["values"]
	var clone_hp: int = int(values[mini(values.size() - 1, safe_level)])
	if safe_level > 5:
		clone_hp += mini(2, maxi(0, int(floor(float(safe_level - 4) / 2.0))))
	return mini(int(FOUR_POISONS_CLONE_HP["cap"]), clone_hp)


# Integral values print without decimals; fractional overflow values (average
# per-level extrapolation can produce halves/quarters) keep up to 2 trimmed
# decimals ("17.5", "19.75").
static func _format_number(value: float) -> String:
	var rounded: float = roundf(value * 100.0) / 100.0
	if is_equal_approx(rounded, roundf(rounded)):
		return str(int(roundf(rounded)))
	var text: String = "%.2f" % rounded
	if text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	return text


static func _description_at(descriptions: Dictionary, level: int) -> Variant:
	for key in descriptions.keys():
		if int(key) == level:
			return descriptions[key]
	return null


static func _highest_defined_description(descriptions: Dictionary, level: int) -> Variant:
	var best_key: int = -1
	var best_value: Variant = null
	for key in descriptions.keys():
		var key_int: int = int(key)
		if key_int <= level and key_int > best_key:
			best_key = key_int
			best_value = descriptions[key]
	return best_value
