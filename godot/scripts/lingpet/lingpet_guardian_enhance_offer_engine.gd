extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")
const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)

const PERK_ID := "lingpet_guardian_enhance"
const OFFER_COOLDOWN_SCREENS := 3
const MAX_PRESENTED_CANDIDATES := 3
const DURATION_WEIGHT := 0.35
const DEFAULT_WEIGHT := 1.0

const _COPY_BY_LANGUAGE := {
	"ko": {
		"name": "수호령강화",
		"description": "현재 수호령에게 적용 가능한 강화 중 하나를 선택합니다.",
		"active_skill": "액티브 스킬 +1",
		"passive_skill": "패시브 스킬 +1",
		"duration": "지속시간 +5초",
		"defense": "방어율 증가",
		"gauge": "기력 획득량 증가",
		"mobility": "이동속도 증가",
		"mobility_flight": "등장률 증가",
		"second_active_unlock": "액티브 스킬 추가 해금",
		"second_passive_unlock": "패시브 스킬 추가 해금",
	},
	"en": {
		"name": "Guardian Enhancement",
		"description": "Choose one enhancement that can be applied to the current guardian spirit.",
		"active_skill": "Active Skill +1",
		"passive_skill": "Passive Skill +1",
		"duration": "Duration +5 sec",
		"defense": "Defense Rate Up",
		"gauge": "Energy Gain Up",
		"mobility": "Move Speed Up",
		"mobility_flight": "Appearance Rate Up",
		"second_active_unlock": "Unlock Extra Active Skill",
		"second_passive_unlock": "Unlock Extra Passive Skill",
	},
	"zh": {
		"name": "守护灵强化",
		"description": "从当前守护灵可获得的强化中选择一项。",
		"active_skill": "主动技能 +1",
		"passive_skill": "被动技能 +1",
		"duration": "持续时间 +5秒",
		"defense": "防御率提升",
		"gauge": "能量获取量提升",
		"mobility": "移动速度提升",
		"mobility_flight": "出现率提升",
		"second_active_unlock": "解锁额外主动技能",
		"second_passive_unlock": "解锁额外被动技能",
	},
	"ja": {
		"name": "守護霊強化",
		"description": "現在の守護霊に適用できる強化から1つ選びます。",
		"active_skill": "アクティブスキル +1",
		"passive_skill": "パッシブスキル +1",
		"duration": "持続時間 +5秒",
		"defense": "防御率上昇",
		"gauge": "気力獲得量上昇",
		"mobility": "移動速度上昇",
		"mobility_flight": "出現率上昇",
		"second_active_unlock": "追加アクティブスキル解放",
		"second_passive_unlock": "追加パッシブスキル解放",
	},
	"es": {
		"name": "Mejora del Guardián",
		"description": "Elige una mejora aplicable al espíritu guardián actual.",
		"active_skill": "Habilidad activa +1",
		"passive_skill": "Habilidad pasiva +1",
		"duration": "Duración +5 s",
		"defense": "Defensa aumentada",
		"gauge": "Ganancia de energía aumentada",
		"mobility": "Velocidad aumentada",
		"mobility_flight": "Frecuencia de aparición aumentada",
		"second_active_unlock": "Desbloquear activa adicional",
		"second_passive_unlock": "Desbloquear pasiva adicional",
	},
	"pt-BR": {
		"name": "Aprimoramento do Guardião",
		"description": "Escolha um aprimoramento aplicável ao espírito guardião atual.",
		"active_skill": "Habilidade ativa +1",
		"passive_skill": "Habilidade passiva +1",
		"duration": "Duração +5 s",
		"defense": "Defesa aumentada",
		"gauge": "Ganho de energia aumentado",
		"mobility": "Velocidade aumentada",
		"mobility_flight": "Taxa de aparição aumentada",
		"second_active_unlock": "Desbloquear ativa adicional",
		"second_passive_unlock": "Desbloquear passiva adicional",
	},
	"ru": {
		"name": "Усиление хранителя",
		"description": "Выберите одно доступное усиление для текущего духа-хранителя.",
		"active_skill": "Активный навык +1",
		"passive_skill": "Пассивный навык +1",
		"duration": "Длительность +5 сек.",
		"defense": "Повышение защиты",
		"gauge": "Повышение получения энергии",
		"mobility": "Повышение скорости",
		"mobility_flight": "Повышение частоты появления",
		"second_active_unlock": "Открыть доп. активный навык",
		"second_passive_unlock": "Открыть доп. пассивный навык",
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
	has_second_passive_skill: bool = true,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	if not has_owned_guardian(owner):
		return _blocked("no_owned_guardian")
	var applicable := LingpetEnhancementBuffStore.build_guardian_enhancement_candidates(
		pet_data,
		duration_increase_count,
		has_second_active_skill,
		has_second_passive_skill
	)
	if applicable.size() < 2:
		return _blocked("fewer_than_two_candidates", applicable)
	if _cooldown_screens > 0:
		_cooldown_screens -= 1
		return _blocked("offer_cooldown", applicable)
	var reserve := not _initial_reservation_consumed
	_initial_reservation_consumed = true
	var presented := _sample_without_replacement(applicable, rng)
	return {
		"offer_allowed": true,
		"reserve": reserve,
		"candidates": _localize_candidates(presented),
		"applicable_count": applicable.size(),
		"cooldown_screens": _cooldown_screens,
	}


func mark_applied() -> void:
	_cooldown_screens = OFFER_COOLDOWN_SCREENS


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


func _sample_without_replacement(
	applicable: Array[Dictionary],
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var remaining: Array[Dictionary] = []
	for candidate in applicable:
		remaining.append(candidate.duplicate(true))
	var result: Array[Dictionary] = []
	var target_count := mini(MAX_PRESENTED_CANDIDATES, remaining.size())
	while result.size() < target_count and not remaining.is_empty():
		var total_weight := 0.0
		for candidate in remaining:
			total_weight += _candidate_weight(candidate)
		var roll := (
			rng.randf_range(0.0, total_weight)
			if rng != null
			else randf_range(0.0, total_weight)
		)
		var selected_index := remaining.size() - 1
		for index in range(remaining.size()):
			roll -= _candidate_weight(remaining[index])
			if roll <= 0.0:
				selected_index = index
				break
		result.append(remaining[selected_index])
		remaining.remove_at(selected_index)
	return result


static func _candidate_weight(candidate: Dictionary) -> float:
	return (
		DURATION_WEIGHT
		if str(candidate.get("type", "")) == LingpetEnhancementBuffStore.REWARD_TYPE_DURATION
		else DEFAULT_WEIGHT
	)


static func _localize_candidates(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var localized: Array[Dictionary] = []
	for candidate in candidates:
		localized.append(localize_candidate(candidate))
	return localized


static func _get_copy() -> Dictionary:
	var language := LanguageSettings.get_language()
	var value: Variant = _COPY_BY_LANGUAGE.get(language, _COPY_BY_LANGUAGE["en"])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _blocked(reason: String, candidates: Array[Dictionary] = []) -> Dictionary:
	return {
		"offer_allowed": false,
		"reserve": false,
		"blocked_reason": reason,
		"candidates": _localize_candidates(candidates),
	}
