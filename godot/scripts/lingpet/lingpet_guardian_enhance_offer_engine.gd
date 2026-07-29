extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")
const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)

const PERK_ID := "lingpet_guardian_enhance"
const OFFER_COOLDOWN_SCREENS := 3
const DURATION_WEIGHT := 0.35
const DEFAULT_WEIGHT := 1.0

const _COPY_BY_LANGUAGE := {
	"ko": {
		"name": "수호령강화",
		"description": "현재 수호령에게 적용 가능한 강화 중 하나를 무작위로 획득합니다.",
		"active_skill": "액티브 스킬 +1",
		"passive_skill": "패시브 스킬 +1",
		"duration": "지속시간 +5초",
		"defense": "방어율 증가",
		"gauge": "기력 획득량 증가",
		"mobility": "이동속도 증가",
		"mobility_flight": "등장률 증가",
		"second_active_unlock": "액티브 스킬 추가 해금",
		"second_passive_unlock": "패시브 스킬 추가 해금",
		"result_level": "{name} Lv.{before} → Lv.{after}",
		"result_unlock": "{name} 해금",
		"result_amount": "{label} +{amount}{unit}",
		"result_acquired": "{label} 획득",
		"result_fallback": "모든 후보가 무효가 되어 지속시간 현재치 +15초로 대체되었습니다.",
		"unit_seconds": "초",
		"unit_points": "",
	},
	"en": {
		"name": "Guardian Enhancement",
		"description": "Gain one random enhancement that can be applied to the current guardian spirit.",
		"active_skill": "Active Skill +1",
		"passive_skill": "Passive Skill +1",
		"duration": "Duration +5 sec",
		"defense": "Defense Rate Up",
		"gauge": "Energy Gain Up",
		"mobility": "Move Speed Up",
		"mobility_flight": "Appearance Rate Up",
		"second_active_unlock": "Unlock Extra Active Skill",
		"second_passive_unlock": "Unlock Extra Passive Skill",
		"result_level": "{name} Lv.{before} → Lv.{after}",
		"result_unlock": "Unlocked {name}",
		"result_amount": "{label} +{amount}{unit}",
		"result_acquired": "Gained {label}",
		"result_fallback": "All candidates became invalid. Restored +15 sec to the current duration.",
		"unit_seconds": " sec",
		"unit_points": "",
	},
	"zh": {
		"name": "守护灵强化",
		"description": "随机获得一项当前守护灵可用的强化。",
		"active_skill": "主动技能 +1",
		"passive_skill": "被动技能 +1",
		"duration": "持续时间 +5秒",
		"defense": "防御率提升",
		"gauge": "能量获取量提升",
		"mobility": "移动速度提升",
		"mobility_flight": "出现率提升",
		"second_active_unlock": "解锁额外主动技能",
		"second_passive_unlock": "解锁额外被动技能",
		"result_level": "{name} Lv.{before} → Lv.{after}",
		"result_unlock": "解锁{name}",
		"result_amount": "{label} +{amount}{unit}",
		"result_acquired": "获得{label}",
		"result_fallback": "所有候选均已失效，当前持续时间恢复+15秒。",
		"unit_seconds": "秒",
		"unit_points": "",
	},
	"ja": {
		"name": "守護霊強化",
		"description": "現在の守護霊に適用できる強化をランダムで1つ獲得します。",
		"active_skill": "アクティブスキル +1",
		"passive_skill": "パッシブスキル +1",
		"duration": "持続時間 +5秒",
		"defense": "防御率上昇",
		"gauge": "気力獲得量上昇",
		"mobility": "移動速度上昇",
		"mobility_flight": "出現率上昇",
		"second_active_unlock": "追加アクティブスキル解放",
		"second_passive_unlock": "追加パッシブスキル解放",
		"result_level": "{name} Lv.{before} → Lv.{after}",
		"result_unlock": "{name} 解放",
		"result_amount": "{label} +{amount}{unit}",
		"result_acquired": "{label} 獲得",
		"result_fallback": "すべての候補が無効になったため、現在の持続時間を+15秒回復しました。",
		"unit_seconds": "秒",
		"unit_points": "",
	},
	"es": {
		"name": "Mejora del Guardián",
		"description": "Obtén una mejora aleatoria aplicable al espíritu guardián actual.",
		"active_skill": "Habilidad activa +1",
		"passive_skill": "Habilidad pasiva +1",
		"duration": "Duración +5 s",
		"defense": "Defensa aumentada",
		"gauge": "Ganancia de energía aumentada",
		"mobility": "Velocidad aumentada",
		"mobility_flight": "Frecuencia de aparición aumentada",
		"second_active_unlock": "Desbloquear activa adicional",
		"second_passive_unlock": "Desbloquear pasiva adicional",
		"result_level": "{name} Nv.{before} → Nv.{after}",
		"result_unlock": "{name} desbloqueada",
		"result_amount": "{label} +{amount}{unit}",
		"result_acquired": "Obtuviste {label}",
		"result_fallback": "Todos los candidatos quedaron inválidos. Se restauraron +15 s a la duración actual.",
		"unit_seconds": " s",
		"unit_points": "",
	},
	"pt-BR": {
		"name": "Aprimoramento do Guardião",
		"description": "Receba um aprimoramento aleatório aplicável ao espírito guardião atual.",
		"active_skill": "Habilidade ativa +1",
		"passive_skill": "Habilidade passiva +1",
		"duration": "Duração +5 s",
		"defense": "Defesa aumentada",
		"gauge": "Ganho de energia aumentado",
		"mobility": "Velocidade aumentada",
		"mobility_flight": "Taxa de aparição aumentada",
		"second_active_unlock": "Desbloquear ativa adicional",
		"second_passive_unlock": "Desbloquear passiva adicional",
		"result_level": "{name} Nv.{before} → Nv.{after}",
		"result_unlock": "{name} desbloqueada",
		"result_amount": "{label} +{amount}{unit}",
		"result_acquired": "Obteve {label}",
		"result_fallback": "Todos os candidatos ficaram inválidos. A duração atual recebeu +15 s.",
		"unit_seconds": " s",
		"unit_points": "",
	},
	"ru": {
		"name": "Усиление хранителя",
		"description": "Получите одно случайное доступное усиление для текущего духа-хранителя.",
		"active_skill": "Активный навык +1",
		"passive_skill": "Пассивный навык +1",
		"duration": "Длительность +5 сек.",
		"defense": "Повышение защиты",
		"gauge": "Повышение получения энергии",
		"mobility": "Повышение скорости",
		"mobility_flight": "Повышение частоты появления",
		"second_active_unlock": "Открыть доп. активный навык",
		"second_passive_unlock": "Открыть доп. пассивный навык",
		"result_level": "{name} Ур.{before} → Ур.{after}",
		"result_unlock": "Открыто: {name}",
		"result_amount": "{label} +{amount}{unit}",
		"result_acquired": "Получено: {label}",
		"result_fallback": "Все варианты стали недоступны. Текущая длительность восстановлена на +15 сек.",
		"unit_seconds": " сек.",
		"unit_points": "",
	},
}

var _initial_reservation_consumed := false
var _cooldown_screens := 0


func reset() -> void:
	_initial_reservation_consumed = false
	_cooldown_screens = 0


func build_offer(
	owner: Object,
	pet_data: Dictionary,
	duration_increase_count: int,
	has_second_active_skill: bool = true,
	has_second_passive_skill: bool = true
) -> Dictionary:
	if not has_owned_guardian(owner):
		return _blocked("no_owned_guardian")
	var applicable := LingpetEnhancementBuffStore.build_guardian_enhancement_candidates(
		pet_data,
		duration_increase_count,
		has_second_active_skill,
		has_second_passive_skill
	)
	if applicable.is_empty():
		return _blocked("no_applicable_candidates")
	if _cooldown_screens > 0:
		_cooldown_screens -= 1
		return _blocked("offer_cooldown", applicable)
	var is_initial_reservation := not _initial_reservation_consumed
	_initial_reservation_consumed = true
	# Every eligible appearance is protected from the catalog shuffle. The
	# cooldown belongs to presentation, not acquisition, so declining the card
	# cannot turn later appearances into a probability roll.
	_cooldown_screens = OFFER_COOLDOWN_SCREENS
	return {
		"offer_allowed": true,
		"reserve": true,
		"is_initial_reservation": is_initial_reservation,
		"candidates": _localize_candidates(applicable),
		"applicable_count": applicable.size(),
		"cooldown_screens": _cooldown_screens,
	}


func mark_applied() -> void:
	# The offer already arms the screen cooldown. Keep this idempotent for the
	# apply path and for direct/debug grants that bypassed offer construction.
	_cooldown_screens = maxi(_cooldown_screens, OFFER_COOLDOWN_SCREENS)


func get_state_for_tests() -> Dictionary:
	return {
		"initial_reservation_consumed": _initial_reservation_consumed,
		"cooldown_screens": _cooldown_screens,
	}


static func has_owned_guardian(owner: Object) -> bool:
	return not LingpetCollectionState.new().get_owned_pet_ids_from_owner(owner).is_empty()


static func get_perk_data() -> Dictionary:
	var copy := _get_copy()
	return {
		"name": str(copy.get("name", "수호령강화")),
		"max_level": 1,
		"descriptions": {1: str(copy.get("description", ""))},
		"detail": str(copy.get("description", "")),
		"icon_color": Color(0.46, 0.94, 0.82, 1.0),
		"tree": "lingpet",
		"repeatable_choice": true,
		"is_lingpet_guardian_enhance": true,
		"exclude_from_perk_fusion": true,
	}


static func localize_candidate(candidate: Dictionary) -> Dictionary:
	var result := candidate.duplicate(true)
	var copy := _get_copy()
	var reward_type := str(result.get("type", ""))
	var label_key := reward_type
	if reward_type == LingpetEnhancementBuffStore.REWARD_TYPE_MOBILITY and str(
		result.get("remapped_stat", "")
	) == "appearance_rate":
		label_key = "mobility_flight"
	result["label"] = str(copy.get(label_key, reward_type))
	result["weight"] = (
		DURATION_WEIGHT
		if reward_type == LingpetEnhancementBuffStore.REWARD_TYPE_DURATION
		else DEFAULT_WEIGHT
	)
	return result


static func format_result_feedback(
	candidate: Dictionary,
	detail: Dictionary,
	fallback_used: bool = false
) -> String:
	var copy := _get_copy()
	if fallback_used:
		return str(copy.get("result_fallback", "Duration +15 sec"))
	var localized := localize_candidate(candidate)
	var label := str(localized.get("label", copy.get("name", "Guardian Enhancement")))
	var kind := str(detail.get("kind", ""))
	var skill_name := str(detail.get("skill_display_name", "")).strip_edges()
	if kind == "skill_level" and skill_name != "":
		return str(copy.get("result_level", "{name} Lv.{before} → Lv.{after}")).format({
			"name": skill_name,
			"before": int(detail.get("previous_level", 0)),
			"after": int(detail.get("new_level", 0)),
		})
	if kind == "skill_unlock" and skill_name != "":
		return str(copy.get("result_unlock", "Unlocked {name}")).format({"name": skill_name})
	if kind == "stat" and float(detail.get("stat_amount", 0.0)) > 0.0:
		return str(copy.get("result_amount", "{label} +{amount}{unit}")).format({
			"label": label,
			"amount": _format_amount(float(detail.get("stat_amount", 0.0))),
			"unit": _result_unit(str(detail.get("stat_unit", "")), copy),
		})
	return str(copy.get("result_acquired", "Gained {label}")).format({"label": label})


static func get_result_copy_for_tests() -> Dictionary:
	return _get_copy()


static func get_result_copy_for_language_for_tests(language: String) -> Dictionary:
	var value: Variant = _COPY_BY_LANGUAGE.get(language, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _localize_candidates(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var localized: Array[Dictionary] = []
	for candidate in candidates:
		localized.append(localize_candidate(candidate))
	return localized


static func _get_copy() -> Dictionary:
	var language := LanguageSettings.get_language()
	var value: Variant = _COPY_BY_LANGUAGE.get(language, _COPY_BY_LANGUAGE["en"])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _format_amount(value: float) -> String:
	return str(int(round(value))) if is_equal_approx(value, round(value)) else "%.1f" % value


static func _result_unit(unit: String, copy: Dictionary) -> String:
	match unit:
		"percent":
			return "%"
		"seconds":
			return str(copy.get("unit_seconds", " sec"))
		"points":
			return str(copy.get("unit_points", ""))
	return ""


static func _blocked(reason: String, candidates: Array[Dictionary] = []) -> Dictionary:
	return {
		"offer_allowed": false,
		"reserve": false,
		"blocked_reason": reason,
		"candidates": _localize_candidates(candidates),
	}
