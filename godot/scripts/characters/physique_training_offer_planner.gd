extends RefCounted

const PerkFusionOfferPlanner := preload("res://scripts/characters/perk_fusion_offer_planner.gd")

# 등장률(2026-08-08 사용자 결정으로 0.40 → 0.60 상향): 선택창이 무공 위주로 읽힌다는
# 판단에 따른 튜닝값이다. 주사위 은퇴 후 조건부 게이트가 사라졌으므로 이 값이 곧 실제
# 체감률이며, 등장해도 기본 3장 중 1장만 교체하므로 나머지는 무공/초식이 유지된다.
const APPEARANCE_CHANCE := 0.60
const OFFER_SOURCE_BATTLE_STARPOINT := "battle_starpoint"
const OFFER_SOURCE_RESULT_BOX_STARPOINT_CHOICE := "result_box_starpoint_choice"

const ALLOWED_OFFER_SOURCES := {
	OFFER_SOURCE_BATTLE_STARPOINT: true,
	OFFER_SOURCE_RESULT_BOX_STARPOINT_CHOICE: true,
}

var _replaceability_source: Object = PerkFusionOfferPlanner.new()


func plan_offer(
	choices: Array,
	offer_source: String,
	state: Object,
	catalog: Object,
	appearance_roll_unit: float,
	selection_roll_unit: float,
	replacement_roll_unit: float,
	saturation_probe: Object = null,
	saturation_registry: Object = null
) -> Dictionary:
	var planned_choices := choices.duplicate(true)
	var result := {
		"choices": planned_choices,
		"rolled": false,
		"appeared": false,
		"replacement_index": -1,
	}
	var candidates := build_candidates(state, catalog, saturation_probe, saturation_registry)
	var replaceable_indices := _get_replaceable_indices(planned_choices)
	if not can_roll(planned_choices, offer_source, state, catalog, candidates, replaceable_indices):
		return result
	result["rolled"] = true
	if clampf(appearance_roll_unit, 0.0, 1.0) >= APPEARANCE_CHANCE:
		return result
	var training_id := _pick_weighted_id(candidates, selection_roll_unit)
	if training_id == "":
		return result
	var training_multiplier := 1.0
	if (
		saturation_probe != null
		and saturation_probe.has_method("get_physique_training_multiplier")
	):
		training_multiplier = maxf(
			1.0,
			float(saturation_probe.get_physique_training_multiplier())
		)
	var card: Dictionary = catalog.build_card(
		training_id,
		int(state.get_count(training_id)),
		training_multiplier,
		float(state.get_applied_count(training_id))
	)
	if card.is_empty():
		return result
	var replacement_slot := _index_from_unit(replacement_roll_unit, replaceable_indices.size())
	var replacement_index: int = replaceable_indices[replacement_slot]
	result["replacement_index"] = replacement_index
	planned_choices[replacement_index] = card
	result["appeared"] = true
	result["training_id"] = training_id
	return result


func can_roll(
	choices: Array,
	offer_source: String,
	state: Object,
	catalog: Object,
	candidates: Array = [],
	replaceable_indices: Array[int] = [],
	saturation_probe: Object = null,
	saturation_registry: Object = null
) -> bool:
	if choices.is_empty() or not bool(ALLOWED_OFFER_SOURCES.get(offer_source.strip_edges(), false)):
		return false
	if state == null or catalog == null or not state.has_method("can_acquire_any"):
		return false
	if not bool(state.can_acquire_any(catalog)):
		return false
	var resolved_candidates := (
		candidates
		if not candidates.is_empty()
		else build_candidates(state, catalog, saturation_probe, saturation_registry)
	)
	if resolved_candidates.is_empty():
		return false
	var resolved_replaceable_indices := (
		replaceable_indices
		if not replaceable_indices.is_empty()
		else _get_replaceable_indices(choices)
	)
	return not resolved_replaceable_indices.is_empty()


# saturation_probe = 최종 소비자 값 비교로 "이 습득이 결과를 바꾸는가"를 답하는 객체
# (프로덕션에서는 RuntimePerkState). 상한(state.can_acquire)은 수련 누적치만 보므로,
# 기보유 이관 무공과 합성되는 호환 런의 조기 포화는 이 프로브만 잡는다.
func build_candidates(
	state: Object,
	catalog: Object,
	saturation_probe: Object = null,
	saturation_registry: Object = null
) -> Array:
	var candidates: Array = []
	if state == null or catalog == null or not catalog.has_method("get_all_training_data"):
		return candidates
	var probe_ready := (
		saturation_probe != null
		and saturation_probe.has_method("is_physique_training_saturated")
	)
	for data_value: Variant in catalog.get_all_training_data():
		if not data_value is Dictionary:
			continue
		var data: Dictionary = data_value as Dictionary
		var training_id := str(data.get("id", ""))
		# ⚠ registry 를 같이 넘겨야 신화 계층까지 포함한 최종값으로 판정된다.
		if probe_ready and bool(saturation_probe.is_physique_training_saturated(training_id, saturation_registry)):
			continue
		if bool(state.can_acquire(training_id, catalog)):
			candidates.append({
				"id": training_id,
				"weight": maxf(0.0, float(data.get("weight", 1.0))),
			})
	return candidates


func _get_replaceable_indices(choices: Array) -> Array[int]:
	var indices: Array[int] = []
	for index: int in range(choices.size()):
		if bool(_replaceability_source.is_choice_replaceable(choices[index])):
			indices.append(index)
	return indices


func _pick_weighted_id(candidates: Array, selection_roll_unit: float) -> String:
	var total_weight := 0.0
	for candidate_value: Variant in candidates:
		if candidate_value is Dictionary:
			total_weight += maxf(0.0, float((candidate_value as Dictionary).get("weight", 0.0)))
	if total_weight <= 0.0:
		return ""
	var cursor := clampf(selection_roll_unit, 0.0, 0.999999) * total_weight
	for candidate_value: Variant in candidates:
		if not candidate_value is Dictionary:
			continue
		var candidate: Dictionary = candidate_value as Dictionary
		cursor -= maxf(0.0, float(candidate.get("weight", 0.0)))
		if cursor < 0.0:
			return str(candidate.get("id", ""))
	return str((candidates[candidates.size() - 1] as Dictionary).get("id", ""))


func _index_from_unit(roll_unit: float, item_count: int) -> int:
	if item_count <= 1:
		return 0
	var normalized_roll := clampf(roll_unit, 0.0, 1.0)
	return mini(item_count - 1, int(floor(normalized_roll * float(item_count))))
