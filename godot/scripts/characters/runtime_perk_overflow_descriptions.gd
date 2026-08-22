extends RefCounted

# Effective-level overflow perk stat-line generator.
#
# transcendent_crown / sage_ring / ignition aura raise a perk's effective level
# past its authored `descriptions` cap (usually Lv.3 for scalable Mugong). Runtime keeps scaling
# (CLAUDE.md effective-level overflow default), but tooltips fell back to the
# highest authored text, so an overflow rank must not display stale authored text.
# 증가" line (2026-07-10 bug). This is the Godot port of legacy pingfighter.py
# `get_runtime_skill_description()`.
#
# CONTRACT (sealed by runtime_perk_overflow_description_smoke.gd):
# - For every registered perk, `generate_stats_text()` must reproduce the
#   catalog's authored `descriptions[level]` VERBATIM at every defined level.
#   The pattern constants therefore cannot silently drift from catalog wording:
#   a catalog text edit fails the smoke and forces a matching template update.
# - Overflow values above each perk's authored maximum follow the RUNTIME lanes:
#   runtime_perk_effective_levels.gd constants, converted perks are
#   single-sourced through PerkConversionValues.get_value() (which already
#   extrapolates + bounds overflow), and the viper four_poisons tables mirror
#   ViperSkillRuntime FOUR_POISONS_* consts (equality-sealed in the smoke).
# - Korean-only: non-Korean locales rewrite every descriptions[level] to one
#   summary string (localize_perk_data), so overflow generation stays on the
#   authored-fallback path there (the collapsed single-panel behavior).
# - Known runtime-vs-catalog wording gaps (kick_enhance 정밀도/공속 lanes) keep
#   following the AUTHORED pattern so the overflow line stays consistent with
#   the authored lines the player already read; reconciling those numbers is a
#   design decision, not a display fix.

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")
const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")

# Linear "prefix + per_level * L + suffix" lanes (legacy skill_patterns port).
# per_level values mirror runtime_perk_effective_levels.gd's
# get_runtime_skill_bonus() match block; value_max mirrors the runtime clamp
# where one exists (item_recycle MAX_ITEM_RECYCLE_CHANCE, boost charge 100%).
const LINEAR_PATTERNS := {
	"dash_lightweight": {"prefix": "활주 재충전 ", "per_level": 12, "suffix": "% 감소"},
	"dash_module_control": {"prefix": "활주 후딜 ", "per_level": 18, "suffix": "% 감소"},
	"dash_jump": {"prefix": "활주 거리 ", "per_level": 7, "suffix": "% 증가"},
	"dash_amplification": {"prefix": "최대 활주 횟수 +", "per_level": 1, "suffix": ""},
	"dash_spirit": {"prefix": "활주시 ", "lane": "laser_chance", "scale": 100.0, "suffix": "% 확률로 레이저 잔상"},
	"item_luck": {"prefix": "아이템 스폰 대기 ", "lane": "spawn_wait_reduction", "scale": 100.0, "suffix": "% 감소"},
	"item_cooldown_mastery": {"prefix": "액티브 아이템 쿨타임 ", "per_level": 13, "suffix": "% 감소"},
	"item_gauge_mastery": {"prefix": "액티브 사용시 기력 +", "lane": "gauge_gain", "scale": 1.0, "suffix": ""},
	"item_caffeine": {"prefix": "타이머형 아이템 지속 ", "lane": "duration_bonus", "scale": 100.0, "suffix": "% 증가"},
	"item_polish": {"prefix": "모든 일반 성장형 무공의 수치 능력치 ", "lane": "general_amplify", "scale": 100.0, "suffix": "% 증폭"},
	"item_recycle": {"prefix": "아이템 유지 확률 ", "lane": "retain_chance", "scale": 100.0, "suffix": "%"},
	"common_swiftness": {"prefix": "이동속도 ", "per_level": 6, "suffix": "% 증가"},
	"common_bulk_up": {"prefix": "몸집 크기 ", "per_level": 6, "suffix": "% 증가"},
	"training_mastery": {"prefix": "모든 수련의 능력치 효과 ", "lane": "training_amplify", "scale": 100.0, "suffix": "% 증폭"},
	"common_training": {"prefix": "모든 초식 쿨타임 ", "per_level": 8, "suffix": "% 감소"},
	"perk_boost_charge": {"prefix": "확률 +", "lane": "trigger_chance_pct", "scale": 1.0, "suffix": "%, 발동 시 다음 활주 무료 + 재충전 -90%"},
	"perk_laurel_shield": {"prefix": "벽사 잎 ", "lane": "leaf_count", "scale": 1.0, "suffix": "개 보호"},
	"extension_gear": {"prefix": "경신보/청심결/건곤환문 지속시간 +", "lane": "duration_bonus", "scale": 100.0, "suffix": "%"},
}

# Converted-perk lane templates. Values come straight from
# PerkConversionValues.get_value(id, key, level), which is the SAME call the
# runtime consumers make, so overflow text is single-sourced with gameplay
# (including OVERFLOW_VALUE_BOUNDS clamps). int_keys mirror consumers that
# read the lane with int(round(...)) (shard/token counts, knockback level).
const RUNTIME_PERCENT_POINT_SKILL_IDS := {
	"dash_lightweight": true,
	"dash_module_control": true,
	"dash_jump": true,
	"dash_spirit": true,
	"item_luck": true,
	"item_cooldown_mastery": true,
	"item_caffeine": true,
	"common_swiftness": true,
	"common_bulk_up": true,
	"training_mastery": true,
	"common_training": true,
}

const CONVERTED_TEMPLATES := {
	"star_detector": {"format": "무혼 보너스 출현 확률 +%s%%", "keys": ["star_bonus_pct"]},
	"adversity_armor": {"format": "실점 후 발동 %s%%, 보호 %s초", "keys": ["trigger_chance_pct", "invincible_duration_sec"]},
	"reinforced_boomerang_gauntlet": {
		"format": "부메랑 넉백 +%s%%, 스턴 +%s%%, 발사속도 +%s%%, 유도 +%s%%, 스폰 +%s%%",
		"keys": ["boomerang_knockback_pct", "boomerang_stun_pct", "boomerang_launch_speed_pct", "boomerang_homing_pct", "boomerang_spawn_bonus_pct"],
	},
	"sensor": {
		"format": "자동 활주 %s회, 쿨타임 %s초",
		"keys": ["auto_dash_token_count", "auto_dash_cooldown_sec"],
		"int_keys": {"auto_dash_token_count": true},
	},
	"dowsing_pendulum": {"format": "필드 아이템·무혼 흡인 범위 %spx", "keys": ["attraction_range"]},
	"dowsing_goggles": {
		"format": "무공 선택지 보너스 발동 확률 %s%%, 무공 합일 상승무공 발현 확률 +%s%%p",
		"keys": ["bonus_perk_chance", "fusion_byproduct_chance_pct"],
	},
	"chargebag": {"format": "벽 반사 기력 +%s%%", "keys": ["chargebag_pct"]},
	"battery": {"format": "스테이지 전환 기력 보존 %s%%", "keys": ["gauge_preserve_pct"]},
	"master": {
		"format": "토벽·널뛰기 폭 +%s%%, 아이템 쿨타임 %s%% 감소, 토벽패 등장 +%s%%",
		"keys": ["wall_length_pct", "item_cooldown_pct", "wall_spawn_bonus_pct"],
	},
	"gold_digger": {"format": "골드 획득량 +%s%%", "keys": ["gold_bonus_pct"]},
	"lucky_coin": {"format": "아이템 더블스폰 확률 %s%%", "keys": ["double_spawn_pct"]},
	"shrapnel_armor": {
		"format": "발동 %s%%, 파편 %s개, 넉백 Lv.%s, 기력 %s 소모",
		"keys": ["trigger_chance_pct", "shard_count", "knockback_level", "gauge_cost"],
		"int_keys": {"shard_count": true, "knockback_level": true},
	},
	"fuel_pouch": {"format": "최대 기력 +%s", "keys": ["fuel_bonus_flat"]},
	"bluetooth_ring": {"format": "타격 기력 +%s%%", "keys": ["gauge_gain_pct"]},
	"foul_whistle": {"format": "실점 무효 확률 %s%%", "keys": ["negate_chance_pct"]},
	"neural_helmet": {
		"format": "신령환 가드 기력 비용 %s 감소, 패들 반사 공속 추가 +%s%%, 스폰 +%s%%",
		"keys": ["aipill_gauge_reduction", "aipill_ball_speed_bonus_pct", "aipill_spawn_bonus_pct"],
	},
	"commando_arm": {
		"format": "투척 속도 +%s%%, 폭발 +%s%%, 연막 +%s%%, 준비 %s%% 감소",
		"keys": ["throw_speed_pct", "explosion_range_pct", "smoke_duration_pct", "prep_reduction_pct"],
	},
	"rainbow_fur_glove": {
		"format": "공 히트 시 발동 %s%%, 진행 중 초식의 전체 쿨타임 %s%% 감소",
		"keys": ["rainbow_glove_trigger_chance_pct", "rainbow_glove_cooldown_reduction_pct"],
	},
	"knee_pads": {"format": "짧은 활주 타격 기력 +%s%%", "keys": ["knee_charge_pct"]},
	"soul_burst": {"format": "활주 횟수가 없을 때 완전 활주 기력 %s", "keys": ["soul_burst_gauge_cost"]},
	"bulletproof_hat": {"format": "자세보정 +%s%%", "keys": ["posture_correction_pct"]},
	"venom_mist_gauntlet": {"format": "독안개 발동 %s%%, 지속 %s초", "keys": ["mist_trigger_chance_pct", "mist_duration_sec"]},
	"sage_ring": {
		"format": "공 타격 시 %s%%: 모든 무공 유효 경지 +%s (%s초)",
		"keys": ["trigger_chance_pct", "perk_level_bonus", "duration_sec"],
		"int_keys": {"perk_level_bonus": true},
	},
}

# four_poisons lane tables — MUST stay equal to ViperSkillRuntime
# FOUR_POISONS_* consts (equality-sealed in the smoke). Index = level,
# overflow = values[last] + (L - last) * per_extra, clamped to cap
# (same math as ViperSkillScaling.get_four_poisons_scaled_pct).
static var FOUR_POISONS_PREP: Dictionary = _build_legacy_linear_lane("prep_reduction_pct")
static var FOUR_POISONS_SLEEP: Dictionary = _build_legacy_linear_lane("sleep_pct")
static var FOUR_POISONS_CONFUSION: Dictionary = _build_legacy_linear_lane("confusion_pct")
static var FOUR_POISONS_DUAL_DURATION: Dictionary = _build_legacy_linear_lane("dual_duration_pct")
static var FOUR_POISONS_COOLDOWN: Dictionary = _build_legacy_linear_lane("cooldown_reduction_pct")
static var FOUR_POISONS_CLONE_HP: Dictionary = _build_legacy_clone_hp_lane()

# pistol_enhance authored spread ladder (mirrors commando_firearm_runtime.gd
# PISTOL_ENHANCE_SPREAD_DEGREES minus the level-0 slot; the authored ladder
# clamps at Lv.3, so Lv.4+ keeps ±1°).
static var PISTOL_ENHANCE_SPREAD_DEGREES: Array = RuntimePerkProgression.get_authored_values_reference(
	"pistol_enhance", "spread_degrees"
)


static func _build_legacy_linear_lane(lane_id: String) -> Dictionary:
	var authored_max := RuntimePerkProgression.get_authored_max_level("four_poisons")
	var values: Array = [0]
	for level in range(1, authored_max + 1):
		values.append(RuntimePerkProgression.get_int_value("four_poisons", lane_id, level))
	return {
		"values": values,
		"per_extra": RuntimePerkProgression.get_int_value("four_poisons", lane_id, authored_max + 1) - int(values[authored_max]),
		"cap": RuntimePerkProgression.get_int_value("four_poisons", lane_id, 10000),
	}


static func _build_legacy_clone_hp_lane() -> Dictionary:
	var authored_max := RuntimePerkProgression.get_authored_max_level("four_poisons")
	var values: Array = [RuntimePerkProgression.get_int_value("four_poisons", "clone_hp", 0)]
	for level in range(1, authored_max + 1):
		values.append(RuntimePerkProgression.get_int_value("four_poisons", "clone_hp", level))
	return {
		"values": values,
		"cap": RuntimePerkProgression.get_int_value("four_poisons", "clone_hp", 10000),
	}


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


# 개광결은 대상 무공의 최종 수치에 독립 배율로 적용되므로, 기본 레벨 문구만
# 그리면 실제 효과와 UI가 어긋난다. 생산 툴팁들이 같은 함수를 사용해 현재
# 개광결 배율로 생긴 절대 추가분을 `(+N%)`(기령심법은 무단위)로 표시한다.
static func resolve_stats_text_with_polish(
	skill_id: String,
	descriptions: Dictionary,
	level: int,
	runtime_state: Object
) -> String:
	return append_polish_delta(resolve_stats_text(skill_id, descriptions, level), skill_id, level, runtime_state)


# TAB/ESC 보유 무공 툴팁 전용 상태 표기. 수치 추가분만 `(+N)`으로 붙이면
# 개광결 대상이 하나도 없는 런(활주구슬 같은 카운트형 + 절세무공만 보유)에서
# 적용 실패처럼 보인다. 개광결 자체에는 현재 적용 대상 수를, 다른 무공에는
# 실제 배율 적용/대상 제외 여부를 한 줄로 명시한다. 선택 카드의 좁은 설명
# 예산에는 이 상태 행을 넣지 않고 append_polish_delta()만 사용한다.
static func append_polish_status(stats_text: String, skill_id: String, runtime_state: Object) -> String:
	var status_text: String = get_polish_status_text(skill_id, runtime_state)
	if status_text == "":
		return stats_text
	if stats_text.strip_edges() == "":
		return status_text
	return "%s, %s" % [stats_text, status_text]


static func get_polish_status_text(skill_id: String, runtime_state: Object) -> String:
	if runtime_state == null or LanguageSettings.get_language() != LanguageSettings.LANGUAGE_KOREAN:
		return ""
	var polish_level: int = _get_runtime_skill_level(runtime_state, RuntimePerkEffectiveLevels.ITEM_POLISH_ID)
	if polish_level <= 0:
		return ""
	var clean_id: String = skill_id.strip_edges()
	if clean_id == "":
		return ""
	if clean_id == RuntimePerkEffectiveLevels.ITEM_POLISH_ID:
		var target_count: int = _get_owned_polish_target_count(runtime_state)
		return "현재 적용 대상 없음" if target_count <= 0 else "현재 적용 대상 %d개" % target_count
	if not _is_polish_amplifiable_perk_id(clean_id):
		return "개광결 미적용 · 대상 제외"
	var multiplier: float = _get_polish_multiplier(runtime_state, clean_id)
	if multiplier <= 1.0 + 0.0001:
		return "개광결 미적용"
	return "개광결 +%s%% 적용" % _format_number((multiplier - 1.0) * 100.0)


static func _get_runtime_skill_level(runtime_state: Object, skill_id: String) -> int:
	if runtime_state.has_method("get_runtime_skill_level"):
		return max(0, int(runtime_state.call("get_runtime_skill_level", skill_id)))
	if runtime_state.has_method("get_effective_runtime_skill_levels"):
		var levels_value: Variant = runtime_state.call("get_effective_runtime_skill_levels")
		if levels_value is Dictionary:
			return max(0, int((levels_value as Dictionary).get(skill_id, 0)))
	return 0


static func _get_owned_polish_target_count(runtime_state: Object) -> int:
	if not runtime_state.has_method("get_effective_runtime_skill_levels"):
		return 0
	var levels_value: Variant = runtime_state.call("get_effective_runtime_skill_levels")
	if not (levels_value is Dictionary):
		return 0
	var levels: Dictionary = levels_value as Dictionary
	var count := 0
	for perk_id_value: Variant in levels.keys():
		var perk_id := str(perk_id_value)
		if int(levels.get(perk_id_value, 0)) > 0 and _is_polish_amplifiable_perk_id(perk_id):
			count += 1
	return count


static func append_polish_delta(stats_text: String, skill_id: String, level: int, runtime_state: Object) -> String:
	if stats_text == "" or level <= 0 or runtime_state == null:
		return stats_text
	if LanguageSettings.get_language() != LanguageSettings.LANGUAGE_KOREAN:
		return stats_text
	var clean_id: String = skill_id.strip_edges()
	if not _is_polish_amplifiable_perk_id(clean_id):
		return stats_text
	var multiplier: float = _get_polish_multiplier(runtime_state, clean_id)
	if multiplier <= 1.0 + 0.0001:
		return stats_text
	if CONVERTED_TEMPLATES.has(clean_id):
		return _converted_template_text_with_polish(clean_id, level, runtime_state)
	var amplify_ratio: float = multiplier - 1.0
	if clean_id == "dash_acceleration":
		return _dash_acceleration_text_with_polish(level, amplify_ratio)
	if not LINEAR_PATTERNS.has(clean_id):
		return stats_text
	return _linear_pattern_text_with_polish(clean_id, level, runtime_state)


static func _is_polish_amplifiable_perk_id(skill_id: String) -> bool:
	return RuntimePerkEffectiveLevels.is_polish_amplifiable_perk_id(skill_id)


static func _converted_template_text_with_polish(
	skill_id: String,
	level: int,
	runtime_state: Object
) -> String:
	var template: Dictionary = CONVERTED_TEMPLATES[skill_id]
	var keys: Array = template["keys"]
	var int_keys: Dictionary = template.get("int_keys", {})
	var args: Array = []
	for key_value: Variant in keys:
		var key := str(key_value)
		var base_value := PerkConversionValues.get_value(skill_id, key, level)
		var amplified_value := PerkConversionValues.get_value_before_fusion(
			skill_id,
			key,
			level,
			runtime_state
		)
		if bool(int_keys.get(key, false)):
			args.append(str(int(round(base_value))))
			continue
		var rendered_value := _format_number(base_value)
		var delta := amplified_value - base_value
		if absf(delta) > 0.0001:
			rendered_value += " (%s%s)" % ["+" if delta > 0.0 else "", _format_number(delta)]
		args.append(rendered_value)
	return str(template["format"]) % args


static func _get_polish_multiplier(runtime_state: Object, skill_id: String) -> float:
	if runtime_state.has_method("get_perk_amplify_multiplier"):
		return maxf(1.0, float(runtime_state.call("get_perk_amplify_multiplier", skill_id)))
	# Compatibility for focused fakes and older runtime-state surfaces.
	if runtime_state.has_method("_get_perk_amplify_multiplier"):
		return maxf(1.0, float(runtime_state.call("_get_perk_amplify_multiplier", skill_id)))
	return 1.0


static func _linear_pattern_text_with_polish(
	skill_id: String,
	level: int,
	runtime_state: Object
) -> String:
	var pattern: Dictionary = LINEAR_PATTERNS[skill_id]
	var base_value: float
	if pattern.has("lane"):
		base_value = RuntimePerkProgression.get_value(skill_id, str(pattern["lane"]), level) * float(pattern.get("scale", 1.0))
	else:
		base_value = float(int(pattern["per_level"]) * level)
	if pattern.has("value_max"):
		base_value = minf(base_value, float(pattern["value_max"]))
	var amplified_value := base_value
	if runtime_state.has_method("get_runtime_skill_bonus_before_fusion"):
		amplified_value = float(runtime_state.call("get_runtime_skill_bonus_before_fusion", skill_id))
		if bool(RUNTIME_PERCENT_POINT_SKILL_IDS.get(skill_id, false)):
			amplified_value *= 100.0
	if pattern.has("value_max"):
		amplified_value = minf(amplified_value, float(pattern["value_max"]))
	var prefix: String = str(pattern["prefix"])
	var suffix: String = str(pattern["suffix"])
	var base_text: String = _format_number(base_value)
	var has_percent_unit: bool = suffix.begins_with("%")
	var delta_text: String = _format_polish_delta(amplified_value - base_value, has_percent_unit)
	if has_percent_unit:
		return "%s%s%% %s%s" % [prefix, base_text, delta_text, suffix.substr(1)]
	return "%s%s %s%s" % [prefix, base_text, delta_text, suffix]


static func _dash_acceleration_text_with_polish(level: int, amplify_ratio: float) -> String:
	var height_value: float = RuntimePerkProgression.get_value("dash_acceleration", "vertical_scale_bonus", level) * 100.0
	var width_value: float = RuntimePerkProgression.get_value("dash_acceleration", "horizontal_scale_bonus", level) * 100.0
	return "활주시 몸집 세로 %s%% %s·가로 %s%% %s 증가" % [
		_format_number(height_value),
		_format_polish_delta(height_value * amplify_ratio, true),
		_format_number(width_value),
		_format_polish_delta(width_value * amplify_ratio, true),
	]


static func _format_polish_delta(delta: float, percent_unit: bool) -> String:
	return "(+%s%s)" % [_format_number(maxf(0.0, delta)), "%" if percent_unit else ""]


# Pattern-generated stat line for any level (the smoke also calls this at
# authored levels to seal template-vs-catalog equality). Returns "" for
# unregistered perks and non-Korean locales.
static func generate_stats_text(skill_id: String, level: int) -> String:
	if level <= 0:
		return ""
	if LanguageSettings.get_language() != LanguageSettings.LANGUAGE_KOREAN:
		return ""
	var clean_id: String = skill_id.strip_edges()
	if clean_id == "dash_acceleration":
		return _dash_acceleration_text(level)
	if LINEAR_PATTERNS.has(clean_id):
		return _linear_pattern_text(clean_id, level)
	if CONVERTED_TEMPLATES.has(clean_id):
		return _converted_template_text(clean_id, level)
	match clean_id:
		"downtown_treasure_map":
			return _treasure_map_text(level)
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


static func _dash_acceleration_text(level: int) -> String:
	return "활주시 몸집 세로 %d%%·가로 %d%% 증가" % [
		_round_display_int(RuntimePerkProgression.get_value("dash_acceleration", "vertical_scale_bonus", level) * 100.0),
		_round_display_int(RuntimePerkProgression.get_value("dash_acceleration", "horizontal_scale_bonus", level) * 100.0),
	]


static func _linear_pattern_text(skill_id: String, level: int) -> String:
	var pattern: Dictionary = LINEAR_PATTERNS[skill_id]
	var value: int
	if pattern.has("lane"):
		value = _round_display_int(RuntimePerkProgression.get_value(skill_id, str(pattern["lane"]), level) * float(pattern.get("scale", 1.0)))
	else:
		value = int(pattern["per_level"]) * level
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


# 천기보도의 절세무공 카드 등장 배율은 런타임에서 레벨 상한 없이 선형 증가한다.
# 절세무공 확률: runtime_perk_effective_levels TREASURE_MAP_MYTHIC_BONUS_PER_LEVEL
# (1.50 = +150%/lv) → tower_reward_pick_offer_builder의 절세무공 카드 확률.
static func _treasure_map_text(level: int) -> String:
	return "승리 보상 픽 절세무공 등장 확률 +%d%%" % (
		_round_display_int(RuntimePerkProgression.get_value("downtown_treasure_map", "mythic_offer_bonus", level) * 100.0)
	)


# drive_curve and the initial-boost decay reduction reach their authored caps
# at Lv.3; the owner supplies both milestone levels.
static func _combo_amplifier_chip_text(level: int) -> String:
	var drive_speed: int = _round_display_int(RuntimePerkProgression.get_value("combo_amplifier_chip", "drive_speed_bonus", level) * 100.0)
	var curve: int = _round_display_int(RuntimePerkProgression.get_value("combo_amplifier_chip", "drive_curve_bonus", level) * 100.0)
	var curve_cap_level := RuntimePerkProgression.get_milestone_level("combo_amplifier_chip", "drive_curve_bonus", "cap_reached")
	var curve_cap: String = "(캡)" if level > curve_cap_level else ""
	var smash_speed: int = _round_display_int(RuntimePerkProgression.get_value("combo_amplifier_chip", "smash_speed_bonus", level) * 100.0)
	var decay: int = _round_display_int(RuntimePerkProgression.get_value("combo_amplifier_chip", "initial_boost_decay_reduction", level) * 100.0)
	var decay_cap_level := RuntimePerkProgression.get_milestone_level("combo_amplifier_chip", "initial_boost_decay_reduction", "cap_reached")
	var decay_cap: String = "(캡)" if level >= decay_cap_level else ""
	return "콤보 효과 증폭: 벽력타 공속+%d%%, 커브+%d%%%s, 천뢰격 공속+%d%%, 초기부스트 감쇄 -%d%%%s" % [
		drive_speed, curve, curve_cap, smash_speed, decay, decay_cap,
	]


# Lv.4+ contract is documented in the catalog detail: accuracy/speed/knockback
# hold at the Lv.3 values while the magazine keeps growing +1 per level.
static func _pistol_enhance_text(level: int) -> String:
	var spread_deg := RuntimePerkProgression.get_int_value("pistol_enhance", "spread_degrees", level)
	var speed := RuntimePerkProgression.get_int_value("pistol_enhance", "speed_bonus_pct", level)
	var knockback := RuntimePerkProgression.get_int_value("pistol_enhance", "knockback_bonus_pct", level)
	var magazine := RuntimePerkProgression.get_int_value("pistol_enhance", "magazine_size", level)
	return "단총통 정확도 ±%d°, 탄속 +%d%%, 넉백 +%d%%, 장전 %d발" % [
		spread_deg, speed, knockback, magazine,
	]


# Runtime: viper_jetpack_state.gd — max gauge +20%/lv uncapped, airborne
# gauge gain (L-2)*10% from Lv.3 uncapped.
static func _jetpack_enhance_text(level: int) -> String:
	var max_gauge := _round_display_int(RuntimePerkProgression.get_value("jetpack_enhance", "max_gauge_bonus", level) * 100.0)
	var text: String = "제트팩 최대 게이지 +%d%%" % max_gauge
	var airborne_start := RuntimePerkProgression.get_milestone_level("jetpack_enhance", "airborne_gauge_gain_bonus", "starts")
	if level >= airborne_start:
		var airborne := _round_display_int(RuntimePerkProgression.get_value("jetpack_enhance", "airborne_gauge_gain_bonus", level) * 100.0)
		text += ", 체공 중 게이지 획득 +%d%%" % airborne
	return text


# Continues the AUTHORED overflow slope (정밀도 8%/lv, 공속 12%/lv) even
# though the runtime lanes currently use different constants (0.09 / 0.04 in
# viper_skill_geometry/scaling) — see module header. 준비 cap 90 and the
# furnace knockback-ball (L-2)*10% cap 100 mirror the runtime.
static func _kick_enhance_text(level: int) -> String:
	var text: String = "킥 발사 정밀도 +%d%%, 공속 +%d%%, 준비 -%d%%" % [
		RuntimePerkProgression.get_int_value("kick_enhance", "authored_precision_pct", level),
		RuntimePerkProgression.get_int_value("kick_enhance", "authored_speed_pct", level),
		_round_display_int(RuntimePerkProgression.get_value("kick_enhance", "prep_reduction", level) * 100.0),
	]
	var furnace_start := RuntimePerkProgression.get_milestone_level("kick_enhance", "furnace_knockback_chance", "starts")
	if level >= furnace_start:
		text += ", 용광로 넉백볼 %d%%" % _round_display_int(RuntimePerkProgression.get_value("kick_enhance", "furnace_knockback_chance", level) * 100.0)
	return text


# Runtime: range/width clamps at Lv.3 (+50%), speed keeps scaling +10%/lv
# (viper_skill_geometry.gd). The homing labels follow the authored gating.
static func _blade_amp_text(level: int) -> String:
	var authored_count := RuntimePerkProgression.get_authored_level_count("blade_amp", "range_width_bonus")
	var range_cap: String = "(캡)" if level > authored_count else ""
	var text: String = "참격 사거리/가로폭 +%d%%%s, 참격 속도 +%d%%" % [
		_round_display_int(RuntimePerkProgression.get_value("blade_amp", "range_width_bonus", level) * 100.0),
		range_cap,
		_round_display_int(RuntimePerkProgression.get_value("blade_amp", "projectile_speed_bonus", level) * 100.0),
	]
	var homing_tier := RuntimePerkProgression.get_int_value("blade_amp", "homing_tier", level)
	if homing_tier >= 2:
		text += ", 추가 유도검기"
	elif homing_tier >= 1:
		text += ", 유도검기"
	return text


static func _four_poisons_text(level: int) -> String:
	var text: String = "천뢰진각/혼천흑창 준비 -%d%%, 천뢰진각 수면 +%d%%, 독영절맥 혼란 +%d%%, 쌍영분신 지속 +%d%%" % [
		RuntimePerkProgression.get_int_value("four_poisons", "prep_reduction_pct", level),
		RuntimePerkProgression.get_int_value("four_poisons", "sleep_pct", level),
		RuntimePerkProgression.get_int_value("four_poisons", "confusion_pct", level),
		RuntimePerkProgression.get_int_value("four_poisons", "dual_duration_pct", level),
	]
	var superarmor_start := RuntimePerkProgression.get_milestone_level("four_poisons", "superarmor", "starts")
	if level >= superarmor_start:
		text += ", 쌍영분신 HP %d, 4초식 쿨 -%d%%, 슈퍼아머" % [
			RuntimePerkProgression.get_int_value("four_poisons", "clone_hp", level),
			RuntimePerkProgression.get_int_value("four_poisons", "cooldown_reduction_pct", level),
		]
	var replication_start := RuntimePerkProgression.get_milestone_level("four_poisons", "clone_replication", "starts")
	if level >= replication_start:
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


# Same owner lookup as ViperSkillScaling.get_dual_glitch_clone_hp.
static func _four_poisons_clone_hp(level: int) -> int:
	return RuntimePerkProgression.get_int_value("four_poisons", "clone_hp", level)


# Stabilize authored decimal percentages before round-half-away-from-zero so a
# binary representation such as 0.145 * 100 cannot display as 14 instead of 15.
static func _round_display_int(value: float) -> int:
	return int(round(value + 0.000001 if value >= 0.0 else value - 0.000001))


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
