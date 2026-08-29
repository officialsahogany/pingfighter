extends RefCounted

const PerkFusionOutcomeRules := preload("res://scripts/characters/perk_fusion_outcome_rules.gd")

const LIMIT_BREAK_ID := "limit_break"
const DELETE_CHANCE := 0.20
# 희귀 슬롯 완화(2026-08-12): +3개 롤은 마지막 슬롯 확정 희귀(기존 유지),
# +1/+2개 롤도 마지막 슬롯이 아래 확률로 희귀 승격된다. 롤은 확정 시점 1회.
const RARE_SLOT_CHANCE_BY_COUNT := {1: 0.15, 2: 0.25}
const RARE_SLOT_MAX_CHANCE := 0.60
const RARE_BYPRODUCT_IDS := {
	"core_stabilize": true,
	"limit_break": true,
	"dual_catalyst": true,
	"linked_arsenal": true,
	"returning_light_step": true,
	"spellbreaker_guard": true,
}


static func build_result(context: Dictionary, rolls: Dictionary) -> Dictionary:
	var source_ids: Array[String] = _normalize_ids(context.get("source_ids", []))
	var limit_break_sources: Array[String] = _normalize_limit_break_sources(
		context.get("limit_break_eligible_sources", []),
		source_ids
	)
	var byproduct_pool: Array[String] = _build_available_byproduct_pool(
		context.get("available_byproducts", []),
		context.get("owned_byproducts", []),
		limit_break_sources
	)
	var core_stabilize_armed := bool(context.get("core_stabilize_armed", false))
	var dual_catalyst_armed := bool(context.get("dual_catalyst_armed", false))
	var dual_catalyst_consumed := dual_catalyst_armed and not byproduct_pool.is_empty()
	var byproduct_count_shift_percent := maxf(
		0.0,
		float(context.get("byproduct_count_shift_percent", 0.0))
	)
	var rare_slot_chance_bonus_percent := maxf(
		0.0,
		float(context.get("rare_slot_chance_bonus_percent", 0.0))
	)
	var weights: Dictionary = build_weight_table(
		byproduct_pool.size(),
		dual_catalyst_consumed,
		byproduct_count_shift_percent
	)
	var raw_outcome := _resolve_weighted_outcome(float(rolls.get("outcome", 0.0)), weights)
	var outcome := raw_outcome
	if core_stabilize_armed and raw_outcome == PerkFusionOutcomeRules.OUTCOME_SIDE_EFFECT:
		outcome = PerkFusionOutcomeRules.OUTCOME_STABLE

	var result := {
		"outcome": outcome,
		"raw_outcome": raw_outcome,
		"weights": weights.duplicate(true),
		"option_penalties": {},
		"deleted_options": {},
		# Immutable material-option snapshot for S4/TAB/result-card display.
		# Runtime math continues to read the canonical live value gateways; this
		# payload is display-only and prevents unchanged lanes from disappearing.
		"commit_value_snapshots": _build_source_options(context, source_ids),
		"byproducts": [],
		"byproduct_payloads": {},
		"token_consumption": {
			"core_stabilize": core_stabilize_armed,
			"dual_catalyst": dual_catalyst_consumed,
		},
		"core_stabilize_consumed": core_stabilize_armed,
		"dual_catalyst_consumed": dual_catalyst_consumed,
	}

	if outcome == PerkFusionOutcomeRules.OUTCOME_SIDE_EFFECT:
		var side_effect: Dictionary = _build_side_effect(context, source_ids, rolls)
		result["option_penalties"] = side_effect.get("option_penalties", {})
		result["deleted_options"] = side_effect.get("deleted_options", {})
		if (result["option_penalties"] as Dictionary).is_empty() \
				and (result["deleted_options"] as Dictionary).is_empty():
			result["outcome"] = PerkFusionOutcomeRules.OUTCOME_STABLE
	elif outcome == PerkFusionOutcomeRules.OUTCOME_BYPRODUCT:
		var byproduct_result: Dictionary = _build_byproduct_result(
			byproduct_pool,
			limit_break_sources,
			weights,
			rolls,
			rare_slot_chance_bonus_percent
		)
		result["outcome"] = str(byproduct_result.get("outcome", outcome))
		result["byproducts"] = byproduct_result.get("byproducts", [])
		result["byproduct_payloads"] = byproduct_result.get("byproduct_payloads", {})

	return result


static func _build_source_options(context: Dictionary, source_ids: Array[String]) -> Dictionary:
	var source_lookup: Dictionary = {}
	for source_id: String in source_ids:
		source_lookup[source_id] = true
	var result: Dictionary = {}
	for lane_value: Variant in _array_or_empty(context.get("penalty_lanes", [])):
		if not lane_value is Dictionary:
			continue
		var lane: Dictionary = lane_value
		var perk_id := str(lane.get("perk_id", "")).strip_edges()
		var option_key := str(lane.get("key", "")).strip_edges()
		if not source_lookup.has(perk_id) or option_key.is_empty():
			continue
		var options: Dictionary = _dictionary_or_empty(result.get(perk_id, {}))
		options[option_key] = {
			"value": lane.get("value", 0.0),
			"polarity": str(lane.get("polarity", "forward")),
			"value_kind": str(lane.get("value_kind", "float")),
		}
		result[perk_id] = options
	return result


static func build_weight_table(
	available_byproduct_count: int,
	dual_catalyst_consumed: bool,
	byproduct_count_shift_percent: float = 0.0
) -> Dictionary:
	return PerkFusionOutcomeRules.build_final_outcome_weights(
		available_byproduct_count <= 0,
		dual_catalyst_consumed,
		byproduct_count_shift_percent,
		available_byproduct_count
	)


static func resolve_rare_slot_chance(requested_count: int, bonus_percent: float = 0.0) -> float:
	if requested_count >= 3:
		return 1.0
	var base_chance := float(RARE_SLOT_CHANCE_BY_COUNT.get(clampi(requested_count, 1, 2), 0.0))
	return clampf(
		base_chance + maxf(0.0, bonus_percent) / 100.0,
		0.0,
		RARE_SLOT_MAX_CHANCE
	)


static func _resolve_weighted_outcome(roll_unit: float, weights: Dictionary) -> String:
	var roll_percent := clampf(roll_unit, 0.0, 1.0) * 100.0
	var success_end := float(weights.get(PerkFusionOutcomeRules.OUTCOME_SUCCESS, 0.0))
	var side_effect_end := success_end + float(
		weights.get(PerkFusionOutcomeRules.OUTCOME_SIDE_EFFECT, 0.0)
	)
	if roll_percent < success_end:
		return PerkFusionOutcomeRules.OUTCOME_SUCCESS
	if float(weights.get(PerkFusionOutcomeRules.OUTCOME_BYPRODUCT, 0.0)) <= 0.0 \
			or roll_percent < side_effect_end:
		return PerkFusionOutcomeRules.OUTCOME_SIDE_EFFECT
	return PerkFusionOutcomeRules.OUTCOME_BYPRODUCT


static func _build_side_effect(
	context: Dictionary,
	source_ids: Array[String],
	rolls: Dictionary
) -> Dictionary:
	var eligible_lanes: Array[Dictionary] = _get_eligible_lanes(
		context.get("penalty_lanes", []),
		source_ids
	)
	if eligible_lanes.is_empty():
		return {"option_penalties": {}, "deleted_options": {}}

	var lane_rolls: Array = _array_or_empty(rolls.get("lane_selection", []))
	var selected_lanes: Array[Dictionary] = _select_lanes(eligible_lanes, lane_rolls)
	var delete_roll := clampf(
		float(rolls.get("delete", rolls.get("delete_roll", 1.0))),
		0.0,
		1.0
	)
	if delete_roll < DELETE_CHANCE:
		for selected_lane: Dictionary in selected_lanes:
			# Deletion means removing a beneficial option. A reverse lane stores
			# an adverse cost/cooldown, so resolving it to zero would turn the
			# side effect into a free-cost/shorter-cooldown buff.
			if str(selected_lane.get("polarity", "")) != "forward":
				continue
			if int(selected_lane.get("remaining_option_count", 0)) < 2:
				continue
			var deleted_perk_id := str(selected_lane.get("perk_id", ""))
			var deleted_key := str(selected_lane.get("key", ""))
			return {
				"option_penalties": {},
				"deleted_options": {deleted_perk_id: [deleted_key]},
			}

	var magnitude_rolls: Array = _array_or_empty(rolls.get("magnitude", []))
	var option_penalties: Dictionary = {}
	for lane_index: int in range(selected_lanes.size()):
		var magnitude_roll := 0.0
		if lane_index < magnitude_rolls.size():
			magnitude_roll = float(magnitude_rolls[lane_index])
		var penalty: Dictionary = _build_penalty(
			selected_lanes[lane_index],
			PerkFusionOutcomeRules.resolve_side_effect_magnitude(magnitude_roll)
		)
		if penalty.is_empty():
			continue
		var perk_id := str(selected_lanes[lane_index].get("perk_id", ""))
		var option_key := str(selected_lanes[lane_index].get("key", ""))
		var perk_penalties: Dictionary = _dictionary_or_empty(option_penalties.get(perk_id, {}))
		perk_penalties[option_key] = penalty
		option_penalties[perk_id] = perk_penalties
	return {"option_penalties": option_penalties, "deleted_options": {}}


static func _get_eligible_lanes(raw_lanes: Variant, source_ids: Array[String]) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	if not raw_lanes is Array or source_ids.is_empty():
		return eligible
	for lane_value: Variant in raw_lanes as Array:
		if not lane_value is Dictionary:
			continue
		var lane: Dictionary = (lane_value as Dictionary).duplicate(true)
		var perk_id := str(lane.get("perk_id", "")).strip_edges()
		var option_key := str(lane.get("key", "")).strip_edges()
		var polarity := str(lane.get("polarity", ""))
		var value_kind := str(lane.get("value_kind", ""))
		if not source_ids.has(perk_id) or option_key.is_empty():
			continue
		if polarity != "forward" and polarity != "reverse":
			continue
		if bool(lane.get("is_boolean", false)):
			continue
		if value_kind == "float":
			var float_value := float(lane.get("value", 0.0))
			if not is_finite(float_value) or float_value <= 0.0:
				continue
		elif value_kind == "int":
			var integer_value := int(lane.get("value", 0))
			var probe: Dictionary
			if polarity == "reverse":
				probe = PerkFusionOutcomeRules.apply_reverse_integer_penalty(integer_value, 0.20)
			else:
				probe = PerkFusionOutcomeRules.apply_forward_integer_penalty(integer_value, 0.20)
			if not bool(probe.get("applied", false)):
				continue
		else:
			continue
		eligible.append(lane)
	eligible.sort_custom(_lane_less)
	return eligible


static func _select_lanes(
	eligible_lanes: Array[Dictionary],
	lane_rolls: Array
) -> Array[Dictionary]:
	var remaining: Array[Dictionary] = eligible_lanes.duplicate(true)
	var selected: Array[Dictionary] = []
	var selection_count := mini(2, maxi(1, lane_rolls.size()))
	selection_count = mini(selection_count, remaining.size())
	for selection_index: int in range(selection_count):
		var selection_roll := 0.0
		if selection_index < lane_rolls.size():
			selection_roll = float(lane_rolls[selection_index])
		var selected_index := mini(
			int(floor(clampf(selection_roll, 0.0, 1.0) * float(remaining.size()))),
			remaining.size() - 1
		)
		selected.append(remaining[selected_index].duplicate(true))
		remaining.remove_at(selected_index)
	return selected


static func _build_penalty(lane: Dictionary, magnitude: float) -> Dictionary:
	var polarity := str(lane.get("polarity", "forward"))
	var value_kind := str(lane.get("value_kind", "float"))
	var original_value: Variant = lane.get("value", 0.0)
	var adjusted_value: Variant
	if value_kind == "int":
		var quantized: Dictionary
		if polarity == "reverse":
			quantized = PerkFusionOutcomeRules.apply_reverse_integer_penalty(
				int(original_value),
				magnitude
			)
		else:
			quantized = PerkFusionOutcomeRules.apply_forward_integer_penalty(
				int(original_value),
				magnitude
			)
		if not bool(quantized.get("applied", false)):
			return {}
		adjusted_value = int(quantized.get("value", int(original_value)))
	else:
		if polarity == "reverse":
			adjusted_value = PerkFusionOutcomeRules.apply_reverse_penalty(
				float(original_value),
				magnitude
			)
		else:
			adjusted_value = PerkFusionOutcomeRules.apply_forward_penalty(
				float(original_value),
				magnitude
			)

	var multiplier := 1.0
	if not is_zero_approx(float(original_value)):
		multiplier = float(adjusted_value) / float(original_value)
	return {
		"original_value": original_value,
		"adjusted_value": adjusted_value,
		"nominal_pct": magnitude * 100.0,
		"multiplier": multiplier,
		"polarity": polarity,
		"value_kind": value_kind,
	}


static func _build_byproduct_result(
	byproduct_pool: Array[String],
	limit_break_sources: Array[String],
	weights: Dictionary,
	rolls: Dictionary,
	rare_slot_bonus_percent: float = 0.0
) -> Dictionary:
	var count_roll := clampf(float(rolls.get("byproduct_count", 0.0)), 0.0, 1.0)
	var requested_count := PerkFusionOutcomeRules.resolve_byproduct_count(count_roll, weights)
	var byproducts: Array[String] = _select_byproducts_with_rare_slot(
		byproduct_pool,
		requested_count,
		_array_or_empty(rolls.get("byproduct_selection", [])),
		clampf(float(rolls.get("rare_slot", 1.0)), 0.0, 1.0),
		rare_slot_bonus_percent
	)
	var resolved_outcome := PerkFusionOutcomeRules.OUTCOME_BYPRODUCT
	if byproducts.is_empty():
		resolved_outcome = PerkFusionOutcomeRules.OUTCOME_SUCCESS
	var payloads: Dictionary = {}
	if byproducts.has(LIMIT_BREAK_ID):
		payloads[LIMIT_BREAK_ID] = {"eligible_sources": limit_break_sources.duplicate()}
	return {
		"outcome": resolved_outcome,
		"byproducts": byproducts.duplicate(),
		"byproduct_payloads": payloads,
	}


static func _select_byproducts_with_rare_slot(
	byproduct_pool: Array[String],
	requested_count: int,
	selection_rolls: Array,
	rare_slot_roll: float = 1.0,
	rare_slot_bonus_percent: float = 0.0
) -> Array[String]:
	var general: Array[String] = []
	var rare: Array[String] = []
	for byproduct_id: String in byproduct_pool:
		if bool(RARE_BYPRODUCT_IDS.get(byproduct_id, false)):
			rare.append(byproduct_id)
		else:
			general.append(byproduct_id)
	var resolved_count: int = mini(clampi(requested_count, 1, 3), general.size() + rare.size())
	var last_slot_rare: bool = requested_count >= 3
	if not last_slot_rare:
		var rare_chance := resolve_rare_slot_chance(requested_count, rare_slot_bonus_percent)
		last_slot_rare = rare_slot_roll < rare_chance
	var slot_types: Array[String] = []
	for slot_index in range(resolved_count):
		slot_types.append("rare" if last_slot_rare and slot_index == resolved_count - 1 else "general")
	var selected: Array[String] = []
	for slot_index in range(slot_types.size()):
		var prefer_rare: bool = slot_types[slot_index] == "rare"
		var candidates: Array[String] = rare if prefer_rare else general
		if candidates.is_empty():
			candidates = general if prefer_rare else rare
		if candidates.is_empty():
			break
		var roll_unit := 0.0
		if slot_index < selection_rolls.size():
			roll_unit = clampf(float(selection_rolls[slot_index]), 0.0, 1.0)
		var selected_index := mini(candidates.size() - 1, int(floor(roll_unit * float(candidates.size()))))
		var selected_id: String = candidates[selected_index]
		selected.append(selected_id)
		general.erase(selected_id)
		rare.erase(selected_id)
	return selected


static func _build_available_byproduct_pool(
	raw_pool: Variant,
	raw_owned: Variant,
	limit_break_sources: Array[String]
) -> Array[String]:
	var owned_lookup: Dictionary = {}
	for owned_id: String in _normalize_ids(raw_owned):
		owned_lookup[owned_id] = true
	var available: Array[String] = []
	if not raw_pool is Array:
		return available
	for pool_value: Variant in raw_pool as Array:
		var byproduct_id := str(pool_value).strip_edges()
		if byproduct_id.is_empty() or owned_lookup.has(byproduct_id) or available.has(byproduct_id):
			continue
		if byproduct_id == LIMIT_BREAK_ID and limit_break_sources.is_empty():
			continue
		available.append(byproduct_id)
	return available


static func _normalize_limit_break_sources(
	raw_sources: Variant,
	fusion_sources: Array[String]
) -> Array[String]:
	var normalized: Array[String] = []
	for source_id: String in _normalize_ids(raw_sources):
		if fusion_sources.has(source_id):
			normalized.append(source_id)
	return normalized


static func _normalize_ids(raw_ids: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if not raw_ids is Array:
		return normalized
	for raw_value: Variant in raw_ids as Array:
		var normalized_id := str(raw_value).strip_edges()
		if normalized_id.is_empty() or normalized.has(normalized_id):
			continue
		normalized.append(normalized_id)
	normalized.sort()
	return normalized


static func _lane_less(left: Dictionary, right: Dictionary) -> bool:
	var left_perk_id := str(left.get("perk_id", ""))
	var right_perk_id := str(right.get("perk_id", ""))
	if left_perk_id == right_perk_id:
		return str(left.get("key", "")) < str(right.get("key", ""))
	return left_perk_id < right_perk_id


static func _array_or_empty(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


static func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
