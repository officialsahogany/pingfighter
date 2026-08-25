extends RefCounted

const PhysiqueTrainingCatalog := preload(
	"res://scripts/characters/physique_training_catalog.gd"
)
const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)
const TowerAscentPerkCandidatePolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_perk_candidate_policy.gd"
)

const OFFER_VERSION := "tower_training_offer_v2"
const OFFER_KIND_TRAINING := "training"
const OFFER_KIND_MIXED_REWARD := "mixed_reward"
const TRAINING_CARD_COUNT := 6
# Mixed result rewards filter Chosik/system rows after the catalog draw, so ask
# for reserve rows without changing the six-card training-node contract.
const MIXED_REWARD_MUGONG_CHOICE_COUNT := 6

var _physique_catalog: Object = PhysiqueTrainingCatalog.new()
var _perk_candidate_policy: Object = TowerAscentPerkCandidatePolicy.new()


func build_offer(
	node_id: String,
	map_seed: int,
	owner: Object,
	registry: Object,
	offer_kind: String = OFFER_KIND_TRAINING
) -> Dictionary:
	var normalized_node_id := node_id.strip_edges()
	if normalized_node_id.is_empty():
		return {"accepted": false, "reason": "invalid_node_id"}
	var normalized_offer_kind := offer_kind.strip_edges()
	if normalized_offer_kind not in [OFFER_KIND_TRAINING, OFFER_KIND_MIXED_REWARD]:
		return {"accepted": false, "reason": "invalid_offer_kind"}
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	if runtime_state == null:
		return {"accepted": false, "reason": "missing_runtime_perk_contract"}
	var training_only := normalized_offer_kind == OFFER_KIND_TRAINING
	var stat_choices := _build_stat_choices(
		normalized_node_id,
		map_seed,
		runtime_state,
		registry,
		TRAINING_CARD_COUNT if training_only else RuntimePerkCatalog.BASE_CHOICE_COUNT,
		training_only
	)
	if training_only and stat_choices.size() != TRAINING_CARD_COUNT:
		return {
			"accepted": false,
			"reason": "insufficient_training_candidates",
			"candidate_count": stat_choices.size(),
		}
	var mugong_choices: Array[Dictionary] = []
	if not training_only:
		var perk_catalog := _get_registry_instance(registry, "runtime_perk_catalog")
		if perk_catalog == null:
			return {"accepted": false, "reason": "missing_runtime_perk_contract"}
		mugong_choices = _build_mugong_choices(
			owner,
			registry,
			runtime_state,
			perk_catalog,
			MIXED_REWARD_MUGONG_CHOICE_COUNT
		)
	if stat_choices.is_empty() and mugong_choices.is_empty():
		return {"accepted": false, "reason": "empty_training_offer"}
	return {
		"accepted": true,
		"reason": "generated",
		"offer_version": OFFER_VERSION,
		"offer_kind": normalized_offer_kind,
		"node_id": normalized_node_id,
		"stat_choices": stat_choices,
		"mugong_choices": mugong_choices,
	}


func is_current_training_offer(offer: Dictionary) -> bool:
	if (
		str(offer.get("offer_version", "")) != OFFER_VERSION
		or str(offer.get("offer_kind", "")) != OFFER_KIND_TRAINING
	):
		return false
	var stat_choices_value: Variant = offer.get("stat_choices", [])
	var mugong_choices_value: Variant = offer.get("mugong_choices", [])
	if not (stat_choices_value is Array) or not (mugong_choices_value is Array):
		return false
	var stat_choices := stat_choices_value as Array
	if stat_choices.size() != TRAINING_CARD_COUNT or not (mugong_choices_value as Array).is_empty():
		return false
	for choice_value in stat_choices:
		if not (choice_value is Dictionary) or not bool((choice_value as Dictionary).get(
			"is_physique_training",
			false
		)):
			return false
	return true


func build_live_choice_projection(
	choice_kind: String,
	offered_choice: Dictionary,
	runtime_state: Object
) -> Dictionary:
	var choice_id := str(offered_choice.get(
		"id",
		offered_choice.get("perk_id", "")
	)).strip_edges()
	if choice_id.is_empty() or runtime_state == null:
		return offered_choice.duplicate(true)
	if choice_kind == "stat" and runtime_state.has_method("get_physique_training_count"):
		var count := int(runtime_state.call("get_physique_training_count", choice_id))
		var multiplier := 1.0
		if runtime_state.has_method("get_physique_training_multiplier"):
			multiplier = maxf(
				1.0,
				float(runtime_state.call("get_physique_training_multiplier"))
			)
		var stat_choice: Dictionary = _physique_catalog.build_card(
			choice_id,
			count,
			multiplier,
			_get_applied_training_count(runtime_state, choice_id, count)
		)
		if stat_choice.is_empty():
			return offered_choice.duplicate(true)
		var stat_max := int(stat_choice.get("training_max_count", -1))
		stat_choice["current_level"] = count
		stat_choice["next_level"] = count + 1 if stat_max < 0 else mini(count + 1, stat_max)
		stat_choice["max_level"] = stat_max
		stat_choice["level_text"] = (
			"Lv.%d" % count
			if stat_max < 0
			else "%d/%d" % [count, stat_max]
		)
		return stat_choice
	var projected := offered_choice.duplicate(true)
	var levels_value: Variant = runtime_state.get("runtime_skill_levels")
	var runtime_levels: Dictionary = (
		(levels_value as Dictionary)
		if levels_value is Dictionary
		else {}
	)
	var current_level := maxi(0, int(runtime_levels.get(
		choice_id,
		projected.get("current_level", 0)
	)))
	var max_level := int(projected.get("max_level", -1))
	var next_level := current_level + 1 if max_level < 0 else mini(current_level + 1, max_level)
	projected["current_level"] = current_level
	projected["next_level"] = next_level
	projected["level_text"] = (
		"Lv.%d" % current_level
		if max_level < 0
		else "%d / %d" % [current_level, max_level]
	)
	var descriptions_value: Variant = projected.get("descriptions", {})
	if descriptions_value is Dictionary:
		var descriptions := descriptions_value as Dictionary
		projected["description"] = str(descriptions.get(
			next_level,
			descriptions.get(max_level, projected.get("description", ""))
		))
	return projected


func is_live_choice_at_maximum(
	choice_kind: String,
	projected_choice: Dictionary,
	runtime_state: Object,
	registry: Object = null
) -> bool:
	if runtime_state == null:
		return false
	var choice_id := str(projected_choice.get(
		"id",
		projected_choice.get("perk_id", "")
	)).strip_edges()
	if choice_kind == "stat":
		var max_count := int(projected_choice.get("training_max_count", -1))
		if max_count >= 0 and int(projected_choice.get("current_level", 0)) >= max_count:
			return true
		return (
			runtime_state.has_method("is_physique_training_saturated")
			and bool(runtime_state.call(
				"is_physique_training_saturated",
				choice_id,
				registry
			))
		)
	var max_level := int(projected_choice.get("max_level", -1))
	return max_level >= 0 and int(projected_choice.get("current_level", 0)) >= max_level


func _build_stat_choices(
	node_id: String,
	map_seed: int,
	runtime_state: Object,
	registry: Object,
	requested_count: int,
	use_saturated_fallback: bool
) -> Array[Dictionary]:
	if (
		not runtime_state.has_method("get_physique_training_count")
		or not runtime_state.has_method("is_physique_training_saturated")
	):
		return []
	var candidates: Array[Dictionary] = []
	var saturated_candidates: Array[Dictionary] = []
	for data_value in _physique_catalog.get_all_training_data():
		if not (data_value is Dictionary):
			continue
		var data := data_value as Dictionary
		var training_id := str(data.get("id", ""))
		if training_id.is_empty():
			continue
		if not TowerAscentUnlockFilter.is_content_unlocked(
			registry,
			TowerAscentUnlockFilter.CONTENT_RUNTIME_PERK,
			training_id
		):
			continue
		var acquired_count := int(runtime_state.call("get_physique_training_count", training_id))
		var max_count := int(_physique_catalog.get_max_count(training_id))
		var saturated := (
			bool(runtime_state.call("is_physique_training_saturated", training_id, registry))
			or (max_count >= 0 and acquired_count >= max_count)
		)
		if saturated and not use_saturated_fallback:
			continue
		var candidate := {
			"id": training_id,
			"weight": maxf(0.0, float(data.get("weight", 1.0))),
		}
		if saturated:
			saturated_candidates.append(candidate)
		else:
			candidates.append(candidate)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("%d:%s:%s:stat" % [map_seed, node_id, OFFER_VERSION]))
	var result: Array[Dictionary] = []
	var multiplier := 1.0
	if runtime_state.has_method("get_physique_training_multiplier"):
		multiplier = maxf(
			1.0,
			float(runtime_state.call("get_physique_training_multiplier"))
		)
	_append_stat_choices(
		result,
		candidates,
		maxi(0, requested_count),
		rng,
		runtime_state,
		multiplier
	)
	if use_saturated_fallback and result.size() < requested_count:
		_append_stat_choices(
			result,
			saturated_candidates,
			requested_count,
			rng,
			runtime_state,
			multiplier
		)
	return result


func _append_stat_choices(
	result: Array[Dictionary],
	candidates: Array[Dictionary],
	requested_count: int,
	rng: RandomNumberGenerator,
	runtime_state: Object,
	multiplier: float
) -> void:
	while result.size() < requested_count and not candidates.is_empty():
		var picked_id := _take_weighted_id(candidates, rng)
		if picked_id.is_empty():
			break
		var card: Dictionary = _physique_catalog.build_card(
			picked_id,
			int(runtime_state.call("get_physique_training_count", picked_id)),
			multiplier,
			_get_applied_training_count(
				runtime_state,
				picked_id,
				int(runtime_state.call("get_physique_training_count", picked_id))
			)
		)
		if not card.is_empty():
			result.append(card)


func _build_mugong_choices(
	owner: Object,
	registry: Object,
	runtime_state: Object,
	perk_catalog: Object,
	requested_count: int
) -> Array[Dictionary]:
	if not perk_catalog.has_method("get_choices"):
		return []
	var runtime_levels: Dictionary = {}
	var levels_value: Variant = runtime_state.get("runtime_skill_levels")
	if levels_value is Dictionary:
		runtime_levels = (levels_value as Dictionary).duplicate(true)
	var character_type := str(_get_object_value(owner, "selected_character_type", "smasher"))
	var offered_value: Variant = perk_catalog.call(
		"get_choices",
		character_type,
		runtime_levels,
		true,
		maxi(RuntimePerkCatalog.BASE_CHOICE_COUNT, requested_count),
		owner,
		registry
	)
	var result: Array[Dictionary] = []
	if not (offered_value is Array):
		return result
	for choice_value in offered_value as Array:
		if not (choice_value is Dictionary):
			continue
		var choice := choice_value as Dictionary
		if (
			_is_mugong_choice(choice)
			and _perk_candidate_policy.is_mugong_candidate(
				choice,
				runtime_levels,
				character_type,
				registry
			)
		):
			result.append(choice.duplicate(true))
	return result


func _is_mugong_choice(choice: Dictionary) -> bool:
	var choice_id := str(choice.get("id", choice.get("perk_id", ""))).strip_edges()
	if choice_id.is_empty() or choice_id == "convert_to_gold":
		return false
	if not str(choice.get("unlocks_skill", "")).strip_edges().is_empty():
		return false
	for excluded_flag in [
		"is_instant",
		"is_gold_conversion",
		"is_physique_training",
		"is_mystic_dice",
		"is_perk_fusion",
		"is_lingpet_guardian_enhance",
	]:
		if bool(choice.get(excluded_flag, false)):
			return false
	return true


func _take_weighted_id(
	candidates: Array[Dictionary],
	rng: RandomNumberGenerator
) -> String:
	if candidates.is_empty():
		return ""
	var total_weight := 0.0
	for candidate in candidates:
		total_weight += maxf(0.0, float(candidate.get("weight", 0.0)))
	var picked_index := 0
	if total_weight > 0.0:
		var cursor := rng.randf() * total_weight
		for index in range(candidates.size()):
			cursor -= maxf(0.0, float(candidates[index].get("weight", 0.0)))
			if cursor <= 0.0:
				picked_index = index
				break
	var picked_id := str(candidates[picked_index].get("id", ""))
	candidates.remove_at(picked_index)
	return picked_id


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	for method_name in ["get_instance", "get_cached_instance"]:
		if registry.has_method(method_name):
			var value: Variant = registry.call(method_name, key)
			if value is Object and value != null:
				return value as Object
	return null


func _get_applied_training_count(
	runtime_state: Object,
	training_id: String,
	fallback_count: int
) -> float:
	if runtime_state.has_method("get_physique_training_applied_count"):
		return maxf(
			float(fallback_count),
			float(runtime_state.call("get_physique_training_applied_count", training_id))
		)
	return float(fallback_count)


func _get_object_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	for property in owner.get_property_list():
		if str(property.get("name", "")) == key:
			return owner.get(key)
	return fallback
