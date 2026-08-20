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

const OFFER_VERSION := "tower_training_offer_v1"

var _physique_catalog: Object = PhysiqueTrainingCatalog.new()
var _perk_candidate_policy: Object = TowerAscentPerkCandidatePolicy.new()


func build_offer(
	node_id: String,
	map_seed: int,
	owner: Object,
	registry: Object
) -> Dictionary:
	var normalized_node_id := node_id.strip_edges()
	if normalized_node_id.is_empty():
		return {"accepted": false, "reason": "invalid_node_id"}
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var perk_catalog := _get_registry_instance(registry, "runtime_perk_catalog")
	if runtime_state == null or perk_catalog == null:
		return {"accepted": false, "reason": "missing_runtime_perk_contract"}
	var stat_choices := _build_stat_choices(
		normalized_node_id,
		map_seed,
		runtime_state,
		registry
	)
	var mugong_choices := _build_mugong_choices(
		owner,
		registry,
		runtime_state,
		perk_catalog
	)
	if stat_choices.is_empty() and mugong_choices.is_empty():
		return {"accepted": false, "reason": "empty_training_offer"}
	return {
		"accepted": true,
		"reason": "generated",
		"offer_version": OFFER_VERSION,
		"node_id": normalized_node_id,
		"stat_choices": stat_choices,
		"mugong_choices": mugong_choices,
	}


func _build_stat_choices(
	node_id: String,
	map_seed: int,
	runtime_state: Object,
	registry: Object
) -> Array[Dictionary]:
	if (
		not runtime_state.has_method("get_physique_training_count")
		or not runtime_state.has_method("is_physique_training_saturated")
	):
		return []
	var candidates: Array[Dictionary] = []
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
		if bool(runtime_state.call("is_physique_training_saturated", training_id, registry)):
			continue
		var acquired_count := int(runtime_state.call("get_physique_training_count", training_id))
		var max_count := int(_physique_catalog.get_max_count(training_id))
		if max_count >= 0 and acquired_count >= max_count:
			continue
		candidates.append({
			"id": training_id,
			"weight": maxf(0.0, float(data.get("weight", 1.0))),
		})
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("%d:%s:%s:stat" % [map_seed, node_id, OFFER_VERSION]))
	var result: Array[Dictionary] = []
	var choice_limit := mini(RuntimePerkCatalog.BASE_CHOICE_COUNT, candidates.size())
	for _index in range(choice_limit):
		var picked_id := _take_weighted_id(candidates, rng)
		if picked_id.is_empty():
			break
		var multiplier := 1.0
		if runtime_state.has_method("get_physique_training_multiplier"):
			multiplier = maxf(
				1.0,
				float(runtime_state.call("get_physique_training_multiplier"))
			)
		var card: Dictionary = _physique_catalog.build_card(
			picked_id,
			int(runtime_state.call("get_physique_training_count", picked_id)),
			multiplier
		)
		if not card.is_empty():
			result.append(card)
	return result


func _build_mugong_choices(
	owner: Object,
	registry: Object,
	runtime_state: Object,
	perk_catalog: Object
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
		RuntimePerkCatalog.BASE_CHOICE_COUNT,
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


func _get_object_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	for property in owner.get_property_list():
		if str(property.get("name", "")) == key:
			return owner.get(key)
	return fallback
