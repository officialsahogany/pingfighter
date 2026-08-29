extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkFusionLocalizationData := preload("res://scripts/characters/perk_fusion_localization_data.gd")

const EN := {
	"card_name": "Perk Fusion",
	"card_description": "Choose two max-level perks and combine them into one fusion perk.",
	"card_detail": "Select two fusion materials. The result is committed before the reveal animation.",
	"materials_title": "Choose Fusion Materials",
	"materials_subtitle": "Select two max-level perks.",
	"page": "%d / %d pages",
	"cancel": "Cancel",
	"confirm": "Review Fusion",
	"selected": "%d / 2 selected",
	"confirm_title": "Confirm Fusion",
	"confirm_subtitle": "The selected perks will be bound into one fusion.",
	"irreversible": "Once confirmed, this choice cannot be undone.",
	"reselect": "Reselect Materials",
	"commit": "Commit Fusion",
	"prob_success": "Preserved",
	"prob_side": "Qi Deviation",
	"prob_core_stable": "Core-stabilized",
	"prob_byproduct": "Superior Martial Art",
	"prob_byproduct_count": "Superior Martial Art +%d",
	"prob_rare_slot": "Rare slot %d%%",
	"animation_title": "Fusing...",
	"animation_subtitle": "Calculating the committed result.",
	"material_a": "Material A",
	"material_b": "Material B",
	"skip": "Confirm to skip animation",
	"reveal_subtitle": "A new fusion record has been created.",
	"stable_subtitle": "The qi deviation was stabilized; source effects were preserved.",
	"fusion_default": "Fusion",
	"level_fusion": "Fusion",
	"continue": "Confirm to continue",
	"result_stable": "Stable: no qi deviation",
	"result_success": "All source options preserved",
	"result_side": "Qi deviation weakened some options",
	"result_byproduct": "New Superior Martial Art acquired",
	"penalty_count": "Adjusted option records: %d",
	"deleted_count": "Deleted option records: %d",
	"option_change": "%s · %s: %s → %s (%s%% adverse)",
	"option_deleted": "%s · %s: removed",
	"byproduct_line": "Superior Martial Art: %s",
	"byproduct_with_detail": "Superior Martial Art: %s — %s",
	"byproduct_targets": "Eligible materials: %s",
	"result_change_summary": "Adjusted %d option(s) · removed %d",
	"result_byproduct_summary": "Superior Martial Arts: %s",
	"material_level": "%s · Lv.%d",
	"material_effective_level": "%s · Lv.%d → %d",
	"fusion_stats_header": "Material options",
	"option_preserved": "%s: %s",
	"option_changed_compact": "%s: %s → %s (%s%% adverse)",
	"option_deleted_compact": "%s: %s removed",
	"deleted_badge": "removed",
	"higher_is_better": "higher is better",
	"lower_is_better": "lower is better",
	"no_numeric_options": "No numeric fusion lane",
	"result_fallback": "Fusion result recorded.",
	"max_level": "Max level",
	"unknown_perk": "Unknown perk",
	"summary": "%s + %s · %s fusion",
	"summary_byproducts": " · Superior arts: %d",
	"label_stable": "stable", "label_success": "successful", "label_side": "qi deviation", "label_byproduct": "superior art",
	"outcome_stable": "Stable Fusion Complete",
	"outcome_success": "Fusion Success",
	"outcome_side": "Qi Deviation",
	"outcome_byproduct": "Superior Martial Art Acquired",
	"outcome_complete": "Fusion Complete",
}

const KO := {
	"card_name": "무공 합일",
	"card_description": "대성한 무공 두 개의 이치를 하나로 합쳐 새로운 무공을 완성합니다.",
	"card_detail": "합일할 두 무공을 선택합니다. 결과는 연출 전에 확정됩니다.",
	"materials_title": "합일할 무공 선택",
	"materials_subtitle": "최대 경지에 오른 무공 두 개를 선택하세요.",
	"page": "%d / %d 페이지",
	"cancel": "취소",
	"confirm": "합일 확인",
	"selected": "%d / 2 선택",
	"confirm_title": "합일 확인",
	"confirm_subtitle": "선택한 두 무공의 이치를 하나로 합칩니다.",
	"irreversible": "확정하면 이번 선택으로 돌아갈 수 없습니다.",
	"reselect": "무공 다시 선택",
	"commit": "합일",
	"prob_success": "유지",
	"prob_side": "주화입마",
	"prob_core_stable": "합일 안정화",
	"prob_byproduct": "상승무공",
	"prob_byproduct_count": "상승무공 +%d개",
	"prob_rare_slot": "희귀 슬롯 %d%%",
	"animation_title": "합일 중...",
	"animation_subtitle": "확정된 결과를 계산하고 있습니다.",
	"material_a": "무공 A",
	"material_b": "무공 B",
	"skip": "결정 키로 연출 건너뛰기",
	"reveal_subtitle": "새로운 무공이 완성되었습니다.",
	"stable_subtitle": "주화입마가 진정되어 원본 성능을 유지합니다.",
	"fusion_default": "합일무공",
	"level_fusion": "합일",
	"continue": "결정 키를 눌러 계속",
	"result_stable": "안정화: 주화입마 없음",
	"result_success": "원본 무공 옵션 유지",
	"result_side": "주화입마로 일부 옵션 약화",
	"result_byproduct": "새 상승무공 습득",
	"penalty_count": "옵션 약화 기록 %d개",
	"deleted_count": "옵션 삭제 기록 %d개",
	"option_change": "%s · %s: %s → %s (실제 %s%% 약화)",
	"option_deleted": "%s · %s: 삭제",
	"byproduct_line": "상승무공: %s",
	"byproduct_with_detail": "상승무공: %s — %s",
	"byproduct_targets": "적용 가능 재료: %s",
	"result_change_summary": "옵션 약화 %d개 · 삭제 %d개",
	"result_byproduct_summary": "상승무공: %s",
	"material_level": "%s · Lv.%d",
	"material_effective_level": "%s · Lv.%d → %d",
	"fusion_stats_header": "무공 옵션",
	"option_preserved": "%s: %s",
	"option_changed_compact": "%s: %s → %s (실제 %s%% 약화)",
	"option_deleted_compact": "%s: %s 삭제",
	"deleted_badge": "삭제",
	"higher_is_better": "높을수록 유리",
	"lower_is_better": "낮을수록 유리",
	"no_numeric_options": "수치형 합일 옵션 없음",
	"result_fallback": "합일로 새로운 무공이 완성되었습니다.",
	"max_level": "극성",
	"unknown_perk": "알 수 없는 무공",
	"summary": "%s + %s · %s 합일",
	"summary_byproducts": " · 상승무공 %d개",
	"label_stable": "안정", "label_success": "성공", "label_side": "주화입마", "label_byproduct": "상승무공",
	"outcome_stable": "안정 합일 완료",
	"outcome_success": "합일 성공",
	"outcome_side": "주화입마 발생",
	"outcome_byproduct": "상승무공 발현",
	"outcome_complete": "합일 완료",
}

const OVERRIDES := PerkFusionLocalizationData.UI_OVERRIDES
const BYPRODUCT_LOCALIZED := PerkFusionLocalizationData.BYPRODUCT_NAMES
const BYPRODUCT_DETAIL_LOCALIZED := PerkFusionLocalizationData.BYPRODUCT_DETAILS
const OPTION_LABEL_LOCALIZED := PerkFusionLocalizationData.OPTION_LABELS
const OPTION_UNITS := PerkFusionLocalizationData.OPTION_UNITS

const BYPRODUCT_KO := {
	"overload_circuit": "벽력추진", "reverb": "잔향", "golden_trajectory": "황금 궤적", "static_field": "정전기장",
	"recycle_protocol": "절처봉생", "meridian_expand": "기맥 확장",
	"gravitybelt": "찰나신법", "smartphone": "응변결",
	"core_stabilize": "합일 안정화", "limit_break": "한계 돌파", "dual_catalyst": "이중 촉매", "linked_arsenal": "연환병장", "returning_light_step": "회광환보", "spellbreaker_guard": "파법호신결",
}
const BYPRODUCT_EN := {
	"overload_circuit": "Thunderbolt Drive", "reverb": "Reverb", "golden_trajectory": "Golden Trajectory", "static_field": "Static Field",
	"recycle_protocol": "Rebirth at the Brink", "meridian_expand": "Meridian Expansion",
	"gravitybelt": "Instant Shadow Art", "smartphone": "Adaptive Art",
	"core_stabilize": "Core Stabilizer", "limit_break": "Limit Break", "dual_catalyst": "Dual Catalyst", "linked_arsenal": "Linked Arsenal", "returning_light_step": "Last-Light Phantom Step", "spellbreaker_guard": "Spellbreaking Guard Art",
}

const BYPRODUCT_DETAIL_KO := {
	"overload_circuit": "활주 타격 시 15% 확률로 공 속도 +80%·붉은보라색 변환, 보스 가드 시 속도·색 원복",
	"reverb": "초식 사용 뒤 3초 동안 이동 속도 +70%",
	"golden_trajectory": "벽 반사마다 골드 2, 라운드당 최대 40",
	"static_field": "실점 뒤 서브 대기 중 최대 10초 동안 보스 이동 속도 -30%",
	"recycle_protocol": "실점 시 25% 확률로 활주 횟수 전부 회복",
	"meridian_expand": "이번 런의 무공 최대 슬롯 +1",
	"gravitybelt": "방향을 바꾸는 순간 무중력 상태가 되어, 관성 없이 즉시 반대 방향으로 움직입니다.",
	"smartphone": "위급 시 회복·스톱워치·금강결계 액티브 아이템 자동 사용",
	"core_stabilize": "다음 합일 1회의 주화입마를 안정화",
	"limit_break": "적용 가능 재료의 유효 레벨 +1",
	"dual_catalyst": "다음 상승무공 발현 가능 합일의 발현 확률 +15%p",
	"linked_arsenal": "보유한 활주구슬마다 액티브 아이템 슬롯 +1",
	"returning_light_step": "활주 토큰 0·실점 임박 시 30% 확률로 공의 낙하지점으로 순간이동",
	"spellbreaker_guard": "공을 받아칠 때 12% 확률로 5초 결계, 결계 중 패링 가능한 보스 스킬 무효화",
}
const BYPRODUCT_DETAIL_EN := {
	"overload_circuit": "15% chance for +80% ball speed and a red-purple ball on a dash hit; speed and color reset when the boss guards",
	"reverb": "+70% move speed for 3 seconds after using a skill",
	"golden_trajectory": "+2 gold per wall bounce, up to 40 each round",
	"static_field": "-30% boss move speed for up to 10 seconds during the serve wait after conceding",
	"recycle_protocol": "25% chance to refill every dash token after conceding",
	"meridian_expand": "+1 maximum Mugong slot for this run",
	"gravitybelt": "movement input instantly reaches max speed; releasing it stops immediately",
	"smartphone": "automatically uses recovery, Stopwatch, or Vajra Barrier active items in emergencies",
	"core_stabilize": "stabilizes qi deviation in the next fusion",
	"limit_break": "+1 effective level for eligible source materials",
	"dual_catalyst": "+15 percentage points to the next eligible Superior Martial Art roll",
	"linked_arsenal": "+1 active item slot per Glide Orb held",
	"returning_light_step": "30% chance to blink to the ball's landing point when no usable dash token remains and a score is imminent",
	"spellbreaker_guard": "12% chance on a return to raise a 5-second ward that parries eligible boss skills",
}

const OPTION_LABEL_KO := {
	"runtime_skill_bonus": "효과 수치",
	"star_bonus_pct": "무혼 보너스",
	"trigger_chance_pct": "발동 확률",
	"invincible_duration_sec": "무적 지속시간",
	"boomerang_knockback_pct": "부메랑 넉백",
	"boomerang_stun_pct": "부메랑 기절 확률",
	"boomerang_launch_speed_pct": "부메랑 발사 속도",
	"boomerang_homing_pct": "부메랑 유도력",
	"boomerang_spawn_bonus_pct": "부메랑 생성량",
	"auto_dash_token_count": "자동 활주 횟수",
	"auto_dash_cooldown_sec": "자동 활주 재사용시간",
	"attraction_range": "끌어당김 범위",
	"bonus_perk_chance": "추가 무공 확률",
	"fusion_rare_slot_bonus_pct": "합일 희귀 슬롯 확률",
	"fusion_byproduct_count_shift_pct": "합일 다중 상승무공 비중",
	"chargebag_pct": "충전 가방 보너스",
	"gauge_preserve_pct": "기력 보존량",
	"wall_length_pct": "벽 길이",
	"item_cooldown_pct": "아이템 재사용 감소",
	"wall_spawn_bonus_pct": "벽 생성량",
	"gold_bonus_pct": "골드 보너스",
	"double_spawn_pct": "아이템 2배 생성 확률",
	"shard_count": "파편 수",
	"knockback_level": "넉백 단계",
	"gauge_cost": "기력 소모량",
	"fuel_bonus_flat": "연료 보너스",
	"gauge_gain_pct": "기력 획득량",
	"negate_chance_pct": "피해 무효 확률",
	"aipill_gauge_reduction": "신령환 기력 감소",
	"aipill_spawn_bonus_pct": "신령환 생성량",
	"throw_speed_pct": "투척 속도",
	"explosion_range_pct": "폭발 범위",
	"smoke_duration_pct": "연막 지속시간",
	"prep_reduction_pct": "준비시간 감소",
	"rainbow_glove_trigger_chance_pct": "무지개 장갑 발동 확률",
	"rainbow_glove_cooldown_reduction_pct": "무지개 장갑 재사용 감소",
	"knee_charge_pct": "무릎 보호대 충전량",
	"soul_burst_gauge_cost": "영혼 폭발 기력 소모량",
	"stun_resist_pct": "기절 저항",
	"knockback_resist_pct": "넉백 저항",
	"posture_correction_pct": "자세보정",
	"mist_trigger_chance_pct": "독안개 발동 확률",
	"mist_duration_sec": "독안개 지속시간",
	"perk_level_bonus": "무공 유효 레벨 보너스",
	"sage_speed_penalty_pct": "현자의 반지 속도 페널티",
	"sage_body_penalty_pct": "현자의 반지 크기 페널티",
}

const OPTION_LABEL_EN := {
	"runtime_skill_bonus": "Effect value",
	"star_bonus_pct": "Martial soul bonus",
	"trigger_chance_pct": "Trigger chance",
	"invincible_duration_sec": "Invincibility duration",
	"boomerang_knockback_pct": "Boomerang knockback",
	"boomerang_stun_pct": "Boomerang stun chance",
	"boomerang_launch_speed_pct": "Boomerang launch speed",
	"boomerang_homing_pct": "Boomerang homing",
	"boomerang_spawn_bonus_pct": "Boomerang spawn bonus",
	"auto_dash_token_count": "Auto-dash tokens",
	"auto_dash_cooldown_sec": "Auto-dash cooldown",
	"attraction_range": "Attraction range",
	"bonus_perk_chance": "Bonus perk chance",
	"fusion_rare_slot_bonus_pct": "Fusion rare-slot chance",
	"fusion_byproduct_count_shift_pct": "Fusion multi-result share",
	"chargebag_pct": "Charge bag bonus",
	"gauge_preserve_pct": "Gauge preserved",
	"wall_length_pct": "Wall length",
	"item_cooldown_pct": "Item cooldown reduction",
	"wall_spawn_bonus_pct": "Wall spawn bonus",
	"gold_bonus_pct": "Gold bonus",
	"double_spawn_pct": "Double-spawn chance",
	"shard_count": "Shard count",
	"knockback_level": "Knockback level",
	"gauge_cost": "Gauge cost",
	"fuel_bonus_flat": "Fuel bonus",
	"gauge_gain_pct": "Gauge gain",
	"negate_chance_pct": "Negate chance",
	"aipill_gauge_reduction": "Spirit Pill vigor reduction",
	"aipill_spawn_bonus_pct": "Spirit Pill spawn bonus",
	"throw_speed_pct": "Throw speed",
	"explosion_range_pct": "Explosion range",
	"smoke_duration_pct": "Smoke duration",
	"prep_reduction_pct": "Preparation reduction",
	"rainbow_glove_trigger_chance_pct": "Rainbow glove trigger chance",
	"rainbow_glove_cooldown_reduction_pct": "Rainbow glove cooldown reduction",
	"knee_charge_pct": "Knee charge",
	"soul_burst_gauge_cost": "Soul burst gauge cost",
	"stun_resist_pct": "Stun resistance",
	"knockback_resist_pct": "Knockback resistance",
	"posture_correction_pct": "Posture correction",
	"mist_trigger_chance_pct": "Mist trigger chance",
	"mist_duration_sec": "Mist duration",
	"perk_level_bonus": "Perk effective-level bonus",
	"sage_speed_penalty_pct": "Sage speed penalty",
	"sage_body_penalty_pct": "Sage body-size penalty",
}

const PERCENT_OPTION_KEYS := {
	"star_bonus_pct": true, "trigger_chance_pct": true,
	"boomerang_knockback_pct": true, "boomerang_stun_pct": true,
	"boomerang_launch_speed_pct": true, "boomerang_homing_pct": true,
	"boomerang_spawn_bonus_pct": true, "bonus_perk_chance": true,
	"chargebag_pct": true, "gauge_preserve_pct": true, "wall_length_pct": true,
	"item_cooldown_pct": true, "wall_spawn_bonus_pct": true, "gold_bonus_pct": true,
	"double_spawn_pct": true, "gauge_gain_pct": true, "negate_chance_pct": true,
	"aipill_gauge_reduction": true, "aipill_spawn_bonus_pct": true,
	"throw_speed_pct": true, "explosion_range_pct": true, "smoke_duration_pct": true,
	"prep_reduction_pct": true, "rainbow_glove_trigger_chance_pct": true,
	"rainbow_glove_cooldown_reduction_pct": true, "knee_charge_pct": true,
	"stun_resist_pct": true, "knockback_resist_pct": true, "posture_correction_pct": true,
	"mist_trigger_chance_pct": true, "sage_speed_penalty_pct": true,
	"sage_body_penalty_pct": true,
}

const PERCENT_POINT_OPTION_KEYS := {
	"fusion_rare_slot_bonus_pct": true,
	"fusion_byproduct_count_shift_pct": true,
}

const STAT_HEADER_PREFIX := "[[fusion:header]]"
const STAT_NORMAL_PREFIX := "[[fusion:normal]]"
const STAT_PENALTY_PREFIX := "[[fusion:penalty]]"
const STAT_DELETED_PREFIX := "[[fusion:deleted]]"
const STAT_BYPRODUCT_PREFIX := "[[fusion:byproduct]]"


static func text(key: String) -> String:
	var locale := LanguageSettings.get_language()
	if locale == LanguageSettings.LANGUAGE_KOREAN:
		return str(KO.get(key, EN.get(key, key)))
	var localized: Dictionary = OVERRIDES.get(locale, {}) as Dictionary
	return str(localized.get(key, EN.get(key, key)))


static func format(key: String, values: Array) -> String:
	return text(key) % values


static func byproduct_name(byproduct_id: String) -> String:
	var locale := LanguageSettings.get_language()
	var names: Dictionary
	if locale == LanguageSettings.LANGUAGE_KOREAN:
		names = BYPRODUCT_KO
	elif locale == LanguageSettings.LANGUAGE_ENGLISH:
		names = BYPRODUCT_EN
	else:
		names = BYPRODUCT_LOCALIZED.get(locale, {}) as Dictionary
	return str(names.get(byproduct_id, byproduct_id))


static func option_label(option_key: String) -> String:
	var locale := LanguageSettings.get_language()
	var labels: Dictionary
	if locale == LanguageSettings.LANGUAGE_KOREAN:
		labels = OPTION_LABEL_KO
	elif locale == LanguageSettings.LANGUAGE_ENGLISH:
		labels = OPTION_LABEL_EN
	else:
		labels = OPTION_LABEL_LOCALIZED.get(locale, {}) as Dictionary
	var clean_key := option_key.strip_edges()
	if labels.has(clean_key):
		return str(labels.get(clean_key, clean_key))
	return clean_key.replace("_", " ").capitalize()


static func option_value_text(option_key: String, value: Variant) -> String:
	var number := float(value)
	var formatted := _format_number(number)
	if bool(PERCENT_POINT_OPTION_KEYS.get(option_key, false)):
		return "+%s%%p" % formatted
	var unit := _option_unit(option_key)
	if unit.is_empty() or unit == "%":
		return formatted + unit
	return "%s %s" % [formatted, unit]


static func option_preview(option_key: String, value: Variant, _polarity: String) -> String:
	return "%s: %s" % [
		option_label(option_key),
		option_value_text(option_key, value),
	]


static func byproduct_detail(
	byproduct_id: String,
	payload: Dictionary = {},
	source_labels: Dictionary = {}
) -> String:
	var locale := LanguageSettings.get_language()
	var details: Dictionary
	if locale == LanguageSettings.LANGUAGE_KOREAN:
		details = BYPRODUCT_DETAIL_KO
	elif locale == LanguageSettings.LANGUAGE_ENGLISH:
		details = BYPRODUCT_DETAIL_EN
	else:
		details = BYPRODUCT_DETAIL_LOCALIZED.get(locale, {}) as Dictionary
	var detail := str(details.get(byproduct_id, ""))
	if byproduct_id == "limit_break":
		var eligible_labels: Array[String] = []
		for source_value: Variant in _as_array(payload.get("eligible_sources", [])):
			var source_id := str(source_value)
			eligible_labels.append(str(source_labels.get(source_id, source_id)))
		if not eligible_labels.is_empty():
			var targets := format("byproduct_targets", [", ".join(eligible_labels)])
			detail = "%s · %s" % [detail, targets] if not detail.is_empty() else targets
	return detail


static func record_detail_lines(record: Dictionary, source_labels: Dictionary = {}) -> Array[String]:
	var lines: Array[String] = []
	var penalties: Dictionary = _as_dictionary(record.get("option_penalties", {}))
	var perk_ids: Array[String] = []
	for perk_id_value: Variant in penalties.keys():
		perk_ids.append(str(perk_id_value))
	perk_ids.sort()
	for perk_id: String in perk_ids:
		var options: Dictionary = _as_dictionary(penalties.get(perk_id, {}))
		var option_keys: Array[String] = []
		for option_key_value: Variant in options.keys():
			option_keys.append(str(option_key_value))
		option_keys.sort()
		for option_key: String in option_keys:
			var adjustment: Dictionary = _as_dictionary(options.get(option_key, {}))
			var before := float(adjustment.get("original_value", 0.0))
			var after := float(adjustment.get("adjusted_value", before))
			var realized_pct := 0.0
			if not is_zero_approx(before):
				realized_pct = absf(after - before) / absf(before) * 100.0
			lines.append(format("option_change", [
				str(source_labels.get(perk_id, perk_id)),
				option_label(option_key),
				option_value_text(option_key, before),
				option_value_text(option_key, after),
				_format_number(realized_pct),
			]))

	var deleted: Dictionary = _as_dictionary(record.get("deleted_options", {}))
	var deleted_perk_ids: Array[String] = []
	for perk_id_value: Variant in deleted.keys():
		deleted_perk_ids.append(str(perk_id_value))
	deleted_perk_ids.sort()
	for perk_id: String in deleted_perk_ids:
		var option_values: Variant = deleted.get(perk_id, [])
		if not (option_values is Array):
			continue
		var option_keys: Array[String] = []
		for option_value: Variant in option_values as Array:
			option_keys.append(str(option_value))
		option_keys.sort()
		for option_key: String in option_keys:
			lines.append(format("option_deleted", [
				str(source_labels.get(perk_id, perk_id)),
				option_label(option_key),
			]))

	var payloads: Dictionary = _as_dictionary(record.get("byproduct_payloads", {}))
	var byproducts_value: Variant = record.get("byproducts", [])
	if byproducts_value is Array:
		for byproduct_value: Variant in byproducts_value as Array:
			var byproduct_id := str(byproduct_value.get("id", "")) if byproduct_value is Dictionary else str(byproduct_value)
			var detail := byproduct_detail(
				byproduct_id,
				_as_dictionary(payloads.get(byproduct_id, {})),
				source_labels
			)
			lines.append(format(
				"byproduct_with_detail" if not detail.is_empty() else "byproduct_line",
				[byproduct_name(byproduct_id), detail] if not detail.is_empty() else [byproduct_name(byproduct_id)]
			))
	return lines


static func result_log_lines(record: Dictionary, source_labels: Dictionary = {}) -> Array[String]:
	var lines: Array[String] = []
	match str(record.get("outcome", "success")):
		"stable":
			lines.append(text("result_stable"))
		"side_effect":
			lines.append(text("result_side"))
		"byproduct":
			lines.append(text("result_byproduct"))
		_:
			lines.append(text("result_success"))
	var changed_count := _nested_option_count(_as_dictionary(record.get("option_penalties", {})))
	var deleted_count := _deleted_option_count(_as_dictionary(record.get("deleted_options", {})))
	if changed_count > 0 or deleted_count > 0:
		lines.append(format("result_change_summary", [changed_count, deleted_count]))
	var byproduct_names: Array[String] = []
	for byproduct_value: Variant in _as_array(record.get("byproducts", [])):
		var byproduct_id := str(byproduct_value.get("id", "")) if byproduct_value is Dictionary else str(byproduct_value)
		byproduct_names.append(byproduct_name(byproduct_id))
	if not byproduct_names.is_empty():
		lines.append(format("result_byproduct_summary", [", ".join(byproduct_names)]))
	return lines.slice(0, mini(3, lines.size()))


static func tooltip_stat_lines(
	record: Dictionary,
	source_labels: Dictionary = {},
	base_levels: Dictionary = {},
	effective_levels: Dictionary = {}
) -> Array[String]:
	var lines: Array[String] = []
	var penalties := _as_dictionary(record.get("option_penalties", {}))
	var deleted := _as_dictionary(record.get("deleted_options", {}))
	var source_options := _as_dictionary(record.get("source_options", {}))
	var sources: Array[String] = []
	for source_value: Variant in _as_array(record.get("sources", [])):
		var source_id := str(source_value).strip_edges()
		if not source_id.is_empty() and source_id not in sources:
			sources.append(source_id)
	for source_value: Variant in source_options.keys() + penalties.keys() + deleted.keys():
		var source_id := str(source_value).strip_edges()
		if not source_id.is_empty() and source_id not in sources:
			sources.append(source_id)

	for source_id: String in sources:
		var label := str(source_labels.get(source_id, source_id))
		var base_level := int(base_levels.get(source_id, 0))
		var effective_level := int(effective_levels.get(source_id, base_level))
		var header := label
		if base_level > 0:
			# 합일 가능한 원본 무공은 base_level이 곧 저작 최대 경지다.
			var base_level_text := LanguageSettings.format_mugong_level(base_level, base_level)
			header = "%s · %s" % [label, base_level_text]
			if effective_level != base_level:
				header += " → " + LanguageSettings.format_mugong_level(effective_level, base_level)
		lines.append(STAT_HEADER_PREFIX + header)

		var option_snapshots := _as_dictionary(source_options.get(source_id, {}))
		var source_penalties := _as_dictionary(penalties.get(source_id, {}))
		var deleted_lookup: Dictionary = {}
		for option_value: Variant in _as_array(deleted.get(source_id, [])):
			deleted_lookup[str(option_value)] = true
		var option_keys: Array[String] = []
		for option_value: Variant in option_snapshots.keys() + source_penalties.keys() + deleted_lookup.keys():
			var option_key := str(option_value)
			if not option_key.is_empty() and option_key not in option_keys:
				option_keys.append(option_key)
		option_keys.sort()
		if option_keys.is_empty():
			lines.append(STAT_NORMAL_PREFIX + text("no_numeric_options"))
			continue
		for option_key: String in option_keys:
			var snapshot := _as_dictionary(option_snapshots.get(option_key, {}))
			var snapshot_value: Variant = snapshot.get("value", snapshot.get("original_value", 0.0))
			if deleted_lookup.has(option_key) or bool(snapshot.get("deleted", false)):
				var deleted_text := format("option_preserved", [
					option_label(option_key),
					option_value_text(option_key, snapshot_value),
				])
				lines.append(STAT_DELETED_PREFIX + "%s · %s" % [
					deleted_text,
					text("deleted_badge"),
				])
				continue
			if source_penalties.has(option_key):
				var adjustment := _as_dictionary(source_penalties.get(option_key, {}))
				var before := float(snapshot.get(
					"value",
					adjustment.get("original_value", snapshot_value)
				))
				var after := float(snapshot.get(
					"adjusted_value",
					adjustment.get("adjusted_value", before)
				))
				var realized_pct := 0.0
				if not is_zero_approx(before):
					realized_pct = absf(after - before) / absf(before) * 100.0
				lines.append(STAT_PENALTY_PREFIX + format("option_changed_compact", [
					option_label(option_key),
					option_value_text(option_key, before),
					option_value_text(option_key, after),
					_format_number(realized_pct),
				]))
				continue
			lines.append(STAT_NORMAL_PREFIX + format("option_preserved", [
				option_label(option_key),
				option_value_text(option_key, snapshot_value),
			]))

	var payloads := _as_dictionary(record.get("byproduct_payloads", {}))
	for byproduct_value: Variant in _as_array(record.get("byproducts", [])):
		var byproduct_id := str(byproduct_value.get("id", "")) if byproduct_value is Dictionary else str(byproduct_value)
		var detail := byproduct_detail(
			byproduct_id,
			_as_dictionary(payloads.get(byproduct_id, {})),
			source_labels
		)
		var byproduct_text := byproduct_name(byproduct_id)
		if not detail.is_empty():
			byproduct_text += " — " + detail
		lines.append(STAT_BYPRODUCT_PREFIX + byproduct_text)
	return lines


static func _as_dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


static func _as_array(value: Variant) -> Array:
	return value as Array if value is Array else []


static func _option_unit(option_key: String) -> String:
	if bool(PERCENT_OPTION_KEYS.get(option_key, false)):
		return "%"
	var units: Dictionary = OPTION_UNITS.get(LanguageSettings.get_language(), OPTION_UNITS[LanguageSettings.LANGUAGE_ENGLISH]) as Dictionary
	if option_key.ends_with("_sec"):
		return str(units.get("seconds", ""))
	match option_key:
		"auto_dash_token_count", "shard_count":
			return str(units.get("count", ""))
		"knockback_level":
			return str(units.get("levels", ""))
		"perk_level_bonus":
			return str(units.get("perk_level", ""))
		"attraction_range":
			return str(units.get("pixels", ""))
		"gauge_cost", "soul_burst_gauge_cost":
			return str(units.get("gauge", ""))
		"fuel_bonus_flat":
			return str(units.get("fuel", ""))
	return ""


static func _nested_option_count(options_by_source: Dictionary) -> int:
	var count := 0
	for options_value: Variant in options_by_source.values():
		if options_value is Dictionary:
			count += (options_value as Dictionary).size()
	return count


static func _deleted_option_count(deleted_by_source: Dictionary) -> int:
	var count := 0
	for options_value: Variant in deleted_by_source.values():
		if options_value is Array:
			count += (options_value as Array).size()
	return count


static func _format_number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return "%.1f" % value
