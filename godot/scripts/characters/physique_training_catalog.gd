extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const CATEGORY_ID := "physique_training"
const OFFER_LANE := "physique_training"

const ACCUMULATED_LABEL_BY_LOCALE := {
	"ko": "누적",
	"en": "Total",
	"zh": "累计",
	"ja": "累計",
	"es": "Total",
	"pt-BR": "Total",
	"ru": "Итог",
}

# 습득 횟수 상한 없음(2026-08-08 사용자 결정). 상한제 폐지 전에는 능력치별 4~5회 +
# 런 전체 6회였다 — 지금은 수납술(액티브 슬롯 +1)만 5회 한정으로 남고, 나머지 10종은
# 런 내 퍽 선택 횟수 자체가 실효 한도다. `max_count`에 이 값을 쓰면 무한 반복이다.
const UNLIMITED_COUNT := -1

# 실효 포화 천장(누적 %) — **표기·`get_bonus` 클램프 및 프로브 부재 시 폴백 전용**이다.
# ⚠ 후보 제외(자격 판정)의 정본은 이 고정 천장이 아니라
# `RuntimePerkState.is_physique_training_saturated`(최종 소비자 값 비교)다 — 기보유 이관
# 무공·신화 계층과 합성되면 실제 포화는 이 천장보다 **앞서** 일어난다. 여기 값은 수련
# 단독 기준의 구조적 최대치이며, 카드가 "105% 감소"처럼 존재할 수 없는 수치를 광고하지
# 않게 표기를 깎는 데 쓴다. 근거:
#  · 활주 재충전/후딜: 감소율 100%에서 배율이 0이 되고 프레임 하한
#    (MIN_DASH_RECHARGE_FRAMES 6.0 / MIN_DASH_RECOVERY_FRAMES 1.0)으로 고정된다.
#    출하 기본 프레임(300 / 42)에서는 100% 직전 습득까지 실제로 프레임이 더 줄어든다
#    (재충전 17회차 12→6, 후딜 13회차 1.68→1.0) — 그래서 천장이 곧 100%다.
#  · 액티브/초식 쿨타임: `cooldown_floor_policy`가 기본값의 5%를 최종 하한으로 강제 → 95%.
#  · 자세 보정: 소비자가 0~100으로 clamp 한다
#    (`player_movement_state.set_posture_correction_pct`).
#  · 이동속도·몸집·활주 거리·최대/타격 기력: 구조적 포화 없음 → 천장 없음.
# ⚠ 기본 프레임 상수(DASH_TOKEN_RECHARGE_FRAMES 300 / DASH_RECOVERY_FRAMES 42)나
#   MIN_DASH_* 하한, 쿨타임 하한 정책이 바뀌면 이 천장을 반드시 재검토할 것.
const CEILING_NONE := 0.0
const CEILING_FULL_REDUCTION := 100.0
const CEILING_COOLDOWN_REDUCTION := 95.0
const CEILING_POSTURE_CORRECTION := 100.0

const TRAINING_IDS: Array[String] = [
	"physique_dash_recharge",
	"physique_dash_recovery",
	"physique_dash_distance",
	"physique_move_speed",
	"physique_posture",
	"physique_paddle_size",
	"physique_max_gauge",
	"physique_hit_gauge",
	"physique_active_item_cooldown",
	"physique_chosik_cooldown",
	"physique_storage",
]

const DATA := {
	"physique_dash_recharge": {
		"name": "회기보 수련", "source_perk_id": "dash_lightweight",
		"stat_key": "dash_recharge_reduction_pct", "amount": 4.0,
		"max_count": UNLIMITED_COUNT, "weight": 1.0, "value_label": "활주 재충전 시간", "unit": "%",
		"effective_ceiling": CEILING_FULL_REDUCTION,
		"detail": "활주가 다시 채워지는 시간이 짧아집니다. 무공 슬롯을 쓰지 않습니다.",
	},
	"physique_dash_recovery": {
		"name": "수세결 수련", "source_perk_id": "dash_module_control",
		"stat_key": "dash_recovery_reduction_pct", "amount": 6.0,
		"max_count": UNLIMITED_COUNT, "weight": 1.0, "value_label": "활주 후딜", "unit": "%",
		"effective_ceiling": CEILING_FULL_REDUCTION,
		"detail": "활주 뒤 굳는 시간이 줄어 다음 행동이 빨라집니다. 무공 슬롯을 쓰지 않습니다.",
	},
	"physique_dash_distance": {
		"name": "비천보 수련", "source_perk_id": "dash_jump",
		"stat_key": "dash_distance_bonus_pct", "amount": 5.0,
		"max_count": UNLIMITED_COUNT, "weight": 1.0, "value_label": "활주 지속", "unit": "%",
		"detail": "활주가 이어지는 시간이 늘어 더 멀리 나아갑니다. 무공 슬롯을 쓰지 않습니다.",
	},
	"physique_move_speed": {
		"name": "유운보 수련", "source_perk_id": "common_swiftness",
		"stat_key": "move_speed_bonus_pct", "amount": 4.0,
		"max_count": UNLIMITED_COUNT, "weight": 1.0, "value_label": "이동 속도", "unit": "%",
		"detail": "좌우로 움직이는 속도가 빨라집니다. 무공 슬롯을 쓰지 않습니다.",
	},
	"physique_posture": {
		"name": "철심공 수련", "source_perk_id": "bulletproof_hat",
		"stat_key": "posture_correction_pct", "amount": 5.0,
		"max_count": UNLIMITED_COUNT, "weight": 1.0, "value_label": "자세 보정", "unit": "%",
		"effective_ceiling": CEILING_POSTURE_CORRECTION,
		"detail": "스턴 시간과 넉백 거리·지속시간이 줄어듭니다. 무공 슬롯을 쓰지 않습니다.",
	},
	"physique_paddle_size": {
		"name": "철산공 수련", "source_perk_id": "common_bulk_up",
		"stat_key": "paddle_size_bonus_pct", "amount": 2.0,
		"max_count": UNLIMITED_COUNT, "weight": 1.0, "value_label": "몸집 크기", "unit": "%",
		"detail": "몸집이 커져 공을 받는 범위가 넓어집니다. 무공 슬롯을 쓰지 않습니다.",
	},
	"physique_max_gauge": {
		"name": "태허심법 수련", "source_perk_id": "fuel_pouch",
		"stat_key": "max_gauge_flat", "amount": 30.0,
		"max_count": UNLIMITED_COUNT, "weight": 1.0, "value_label": "최대 기력", "unit": "",
		"detail": "지닐 수 있는 최대 기력이 늘어납니다. 무공 슬롯을 쓰지 않습니다.",
	},
	"physique_hit_gauge": {
		"name": "격기심법 수련", "source_perk_id": "bluetooth_ring",
		"stat_key": "hit_gauge_bonus_pct", "amount": 7.0,
		"max_count": UNLIMITED_COUNT, "weight": 1.0, "value_label": "타격 기력", "unit": "%",
		"detail": "공을 받아칠 때 얻는 기력이 늘어납니다. 무공 슬롯을 쓰지 않습니다.",
	},
	"physique_active_item_cooldown": {
		"name": "순환결 수련", "source_perk_id": "item_cooldown_mastery",
		"stat_key": "active_item_cooldown_reduction_pct", "amount": 7.0,
		"max_count": UNLIMITED_COUNT, "weight": 1.0, "value_label": "액티브 아이템 쿨타임", "unit": "%",
		"effective_ceiling": CEILING_COOLDOWN_REDUCTION,
		"detail": "액티브 아이템을 다시 쓰기까지가 짧아집니다. 무공 슬롯을 쓰지 않습니다.",
	},
	"physique_chosik_cooldown": {
		"name": "조식심법 수련", "source_perk_id": "common_training",
		"stat_key": "chosik_cooldown_reduction_pct", "amount": 3.0,
		"max_count": UNLIMITED_COUNT, "weight": 1.0, "value_label": "초식 쿨타임", "unit": "%",
		"effective_ceiling": CEILING_COOLDOWN_REDUCTION,
		"detail": "모든 초식을 다시 펼치기까지의 시간이 짧아집니다. 무공 슬롯을 쓰지 않습니다.",
	},
	"physique_storage": {
		"name": "수납술 수련", "source_perk_id": "",
		"stat_key": "active_item_slot_bonus", "amount": 1.0,
		# 5회까지 연장 가능(2026-08-25 사용자 결정, 기존 3회 한정에서 확대). 무한이 아닌
		# 이유는 슬롯 무한 증식 방지 — 상한제 폐지의 유일한 예외로 남는다.
		"max_count": 5, "weight": 0.5, "value_label": "액티브 아이템 슬롯", "unit": "",
		"unit_ko": "칸",
		"detail": "액티브 아이템을 넣는 칸이 한 칸 늘어납니다. 무공 슬롯을 쓰지 않습니다.",
	},
}


func has_training(training_id: String) -> bool:
	return DATA.has(training_id.strip_edges())


func get_training_data(training_id: String) -> Dictionary:
	var clean_id := training_id.strip_edges()
	if not DATA.has(clean_id):
		return {}
	var data: Dictionary = (DATA[clean_id] as Dictionary).duplicate(true)
	data["id"] = clean_id
	return data


func get_all_training_data() -> Array:
	var result: Array = []
	for training_id: String in TRAINING_IDS:
		result.append(get_training_data(training_id))
	return result


func get_max_count(training_id: String) -> int:
	var raw := int(get_training_data(training_id).get("max_count", 0))
	return UNLIMITED_COUNT if raw < 0 else maxi(0, raw)


func is_unlimited(training_id: String) -> bool:
	return get_max_count(training_id) == UNLIMITED_COUNT


# 0 = 천장 없음(무한 성장). > 0 이면 그 누적 %에서 소비자가 포화한다.
func get_effective_ceiling(training_id: String) -> float:
	return maxf(0.0, float(get_training_data(training_id).get("effective_ceiling", CEILING_NONE)))


func get_stat_key(training_id: String) -> String:
	return str(get_training_data(training_id).get("stat_key", ""))


func get_amount(training_id: String) -> float:
	return float(get_training_data(training_id).get("amount", 0.0))


func is_training_mastery_amplifiable_stat(stat_key: String) -> bool:
	return stat_key.strip_edges() != "active_item_slot_bonus"


func build_card(
	training_id: String,
	acquired_count: int,
	training_multiplier: float = 1.0,
	applied_count_before: float = -1.0
) -> Dictionary:
	var data := get_training_data(training_id)
	if data.is_empty():
		return {}
	var max_count := int(data.get("max_count", 0))
	var unlimited := max_count < 0
	# 상한 없는 수련은 클램프 대상이 아니다 — 상한제 시절의 clampi/mini 를 그대로 두면
	# max_count(-1)이 누적 표기를 0으로 접어 카드가 "0% 증가"로 읽힌다.
	var before_count := maxi(0, acquired_count) if unlimited else clampi(acquired_count, 0, max_count)
	var after_count := before_count + 1 if unlimited else mini(before_count + 1, max_count)
	var before_applied_count := (
		maxf(float(before_count), applied_count_before)
		if applied_count_before >= 0.0
		else float(before_count)
	)
	var after_applied_count := before_applied_count + (1.0 if after_count > before_count else 0.0)
	var amount := float(data.get("amount", 0.0))
	var ceiling := float(data.get("effective_ceiling", CEILING_NONE))
	# 카드는 실효값을 말해야 한다 — 천장을 넘는 누적치를 그대로 찍으면 순환결이
	# "105% 감소"처럼 존재할 수 없는 수치를 광고한다.
	var stat_key := str(data.get("stat_key", ""))
	var applied_multiplier := (
		maxf(1.0, training_multiplier)
		if is_training_mastery_amplifiable_stat(stat_key)
		else 1.0
	)
	var per_level_value := amount * applied_multiplier
	# Training Mastery is part of the advertised and applied value. Multiply it
	# before the effective ceiling so cards and final consumers share one order.
	var before_value := amount * before_applied_count * applied_multiplier
	var after_value := amount * after_applied_count * applied_multiplier
	if ceiling > 0.0:
		before_value = minf(before_value, ceiling)
		after_value = minf(after_value, ceiling)
	var value_label := str(data.get("value_label", ""))
	var unit := str(data.get("unit", ""))
	var reduction := training_id in [
		"physique_dash_recharge",
		"physique_dash_recovery",
		"physique_active_item_cooldown",
		"physique_chosik_cooldown",
	]
	var unit_ko := str(data.get("unit_ko", unit))
	var card := {
		"id": training_id,
		"name": str(data.get("name", training_id)),
		# 카드 문구 계약(2026-08-24): 앞쪽 수치는 언제나 원시 퍼레벨 증가량이다.
		# 이미 적용된 수련이 있을 때만 판정 배율·숙련 배율을 포함한 다음 총합을 괄호로 붙인다.
		"description": _build_effect_line(
			value_label,
			per_level_value,
			after_value,
			unit,
			unit_ko,
			reduction,
			before_applied_count > 0.0
		),
		"detail": str(data.get("detail", "무공 슬롯을 쓰지 않는 기초 수련입니다.")),
		"icon_color": Color(0.64, 0.43, 0.18),
		"tree": CATEGORY_ID,
		"character_restriction": "",
		"is_physique_training": true,
		"offer_protected": true,
		"offer_lane": OFFER_LANE,
		"source_perk_id": str(data.get("source_perk_id", "")),
		"training_stat_key": stat_key,
		"training_amount": amount,
		"training_multiplier": applied_multiplier,
		"training_count_before": before_count,
		"training_count_after": after_count,
		"training_applied_count_before": before_applied_count,
		"training_applied_count_after": after_applied_count,
		"training_value_before": before_value,
		"training_value_after": after_value,
		"training_value_label": value_label,
		"training_unit": unit,
		"training_unit_ko": unit_ko,
		"training_reduction": reduction,
		# 디버그 피커의 "N회 한정 / 반복 습득" 배지가 카탈로그를 단일 소스로 읽게 한다
		# (리터럴 복사본을 두면 상한을 바꿀 때 배지만 옛 값으로 남는다).
		"training_max_count": max_count,
		"current_level": 0,
		"next_level": 0,
		"max_level": 0,
	}
	var localized: Dictionary = LanguageSettings.localize_perk_data(card)
	# localize_perk_data 는 비한국어에서 description 을 PERK_SUMMARY 문장으로 덮어쓰므로
	# 수치 강조줄은 항상 이 시점에 다시 넣는다(한국어는 no-op 재계산).
	localized["description"] = _build_effect_line(
		value_label,
		per_level_value,
		after_value,
		unit,
		unit_ko,
		reduction,
		before_applied_count > 0.0
	)
	return localized


# 한국어는 "<대상> <수치> 증가/감소" 어순을, 그 외 로케일은 어순 의존이 없는
# 부호 표기("<label> +3%")를 쓴다. 로케일별 서술어 어순을 억지로 한국어 틀에
# 끼워 맞추면 "Dash Distance 3% Increase" 같은 번역투가 된다.
func _build_effect_line(
	value_label: String,
	per_level_value: float,
	accumulated_value: float,
	unit: String,
	unit_ko: String,
	reduction: bool,
	show_accumulated: bool
) -> String:
	var localized_label := LanguageSettings.translate_text(value_label, value_label)
	var sign := "-" if reduction else "+"
	var accumulated_label := str(ACCUMULATED_LABEL_BY_LOCALE.get(
		LanguageSettings.get_language(),
		ACCUMULATED_LABEL_BY_LOCALE[LanguageSettings.LANGUAGE_ENGLISH]
	))
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_KOREAN:
		var korean_line := "%s %s%s %s" % [
			value_label,
			_format_number(per_level_value),
			unit_ko,
			"감소" if reduction else "증가",
		]
		if not show_accumulated:
			return korean_line
		return "%s (%s %s%s)" % [
			korean_line,
			accumulated_label,
			_format_number(accumulated_value),
			unit_ko,
		]
	var localized_line := "%s %s%s%s" % [
		localized_label,
		sign,
		_format_number(per_level_value),
		unit,
	]
	if not show_accumulated:
		return localized_line
	return "%s (%s %s%s%s)" % [
		localized_line,
		accumulated_label,
		sign,
		_format_number(accumulated_value),
		unit,
	]


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value
