extends RefCounted

const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")

const FUSION_CARD_ID := "perk_fusion"
const APPEARANCE_CHANCE := 0.35
const ICON_VARIANT_COUNT := 5

const OFFER_SOURCE_BATTLE_STARPOINT := "battle_starpoint"
const OFFER_SOURCE_RESULT_BOX_STARPOINT_CHOICE := "result_box_starpoint_choice"
const OFFER_LANE_REPLACEABLE := "replaceable"
const OFFER_LANE_FUSION := "fusion"

const ALLOWED_OFFER_SOURCES := {
	OFFER_SOURCE_BATTLE_STARPOINT: true,
	OFFER_SOURCE_RESULT_BOX_STARPOINT_CHOICE: true,
}


func plan_offer(
	choices: Array,
	eligible_source_ids: Array,
	offer_source: String,
	appearance_roll_unit: float,
	replacement_roll_unit: float
) -> Dictionary:
	var normalized_sources: Array[String] = _normalize_source_ids(eligible_source_ids)
	var planned_choices: Array = choices.duplicate(true)
	var base_result := {
		"choices": planned_choices,
		"rolled": false,
		"appeared": false,
		"replacement_index": -1,
		"eligible_sources": normalized_sources.duplicate(),
	}
	if not is_offer_source_allowed(offer_source):
		return base_result
	if normalized_sources.size() < 2:
		return base_result

	var replaceable_indices: Array[int] = _get_replaceable_indices(planned_choices)
	if replaceable_indices.is_empty():
		return base_result

	base_result["rolled"] = true
	if clampf(appearance_roll_unit, 0.0, 1.0) >= APPEARANCE_CHANCE:
		return base_result

	var replacement_slot: int = _index_from_unit(replacement_roll_unit, replaceable_indices.size())
	var replacement_index: int = replaceable_indices[replacement_slot]
	var replaced_choice: Dictionary = (planned_choices[replacement_index] as Dictionary).duplicate(true)
	planned_choices[replacement_index] = _build_fusion_card(
		normalized_sources,
		replaced_choice,
		_index_from_unit(replacement_roll_unit, ICON_VARIANT_COUNT)
	)
	base_result["appeared"] = true
	base_result["replacement_index"] = replacement_index
	return base_result


func is_offer_source_allowed(offer_source: String) -> bool:
	return bool(ALLOWED_OFFER_SOURCES.get(offer_source.strip_edges(), false))


func is_choice_replaceable(choice_value: Variant) -> bool:
	if not choice_value is Dictionary:
		return false
	var choice: Dictionary = choice_value as Dictionary
	var has_protection_marker: bool = choice.has("offer_protected")
	var lane: String = str(choice.get("offer_lane", "")).strip_edges().to_lower()
	if has_protection_marker and bool(choice.get("offer_protected", true)):
		return false
	if not lane.is_empty() and lane != OFFER_LANE_REPLACEABLE:
		return false
	return (has_protection_marker and not bool(choice.get("offer_protected", true))) or lane == OFFER_LANE_REPLACEABLE


func _get_replaceable_indices(choices: Array) -> Array[int]:
	var indices: Array[int] = []
	for index: int in range(choices.size()):
		if is_choice_replaceable(choices[index]):
			indices.append(index)
	return indices


func _normalize_source_ids(source_ids: Array) -> Array[String]:
	var normalized: Array[String] = []
	var seen: Dictionary = {}
	for source_id_value: Variant in source_ids:
		var source_id: String = str(source_id_value).strip_edges()
		if source_id.is_empty() or seen.has(source_id):
			continue
		seen[source_id] = true
		normalized.append(source_id)
	normalized.sort()
	return normalized


func _build_fusion_card(
	eligible_sources: Array[String],
	replaced_choice_snapshot: Dictionary,
	icon_variant: int
) -> Dictionary:
	return {
		"id": FUSION_CARD_ID,
		"name": PerkFusionLocalization.text("card_name"),
		"description": PerkFusionLocalization.text("card_description"),
		"detail": PerkFusionLocalization.text("card_detail"),
		"name_key": "runtime_perk.perk_fusion.name",
		"description_key": "runtime_perk.perk_fusion.description",
		"detail_key": "runtime_perk.perk_fusion.detail",
		"eligible_sources": eligible_sources.duplicate(),
		"replaced_choice_snapshot": replaced_choice_snapshot.duplicate(true),
		"offer_protected": true,
		"offer_lane": OFFER_LANE_FUSION,
		"is_perk_fusion": true,
		"icon_variant": clampi(icon_variant, 0, ICON_VARIANT_COUNT - 1),
		"icon_id": "perk_fusion_%d" % clampi(icon_variant, 0, ICON_VARIANT_COUNT - 1),
		"current_level": 0,
		"next_level": 0,
		"max_level": 0,
	}


func _index_from_unit(roll_unit: float, item_count: int) -> int:
	if item_count <= 1:
		return 0
	var normalized_roll: float = clampf(roll_unit, 0.0, 1.0)
	return mini(item_count - 1, int(floor(normalized_roll * float(item_count))))
