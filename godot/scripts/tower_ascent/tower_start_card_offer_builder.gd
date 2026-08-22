extends RefCounted

const RuntimePerkCharacterContext := preload(
	"res://scripts/characters/runtime_perk_character_context.gd"
)
const TowerAscentPerkCandidatePolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_perk_candidate_policy.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

var _character_context: Object = RuntimePerkCharacterContext.new()
var _candidate_policy: Object = TowerAscentPerkCandidatePolicy.new()


func build_offer(run_id: String, owner: Object, registry: Object) -> Dictionary:
	var normalized_run_id := run_id.strip_edges()
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var catalog := _get_registry_instance(registry, "runtime_perk_catalog")
	if normalized_run_id.is_empty() or runtime_state == null or catalog == null:
		return {"accepted": false, "reason": "missing_start_card_contract"}
	if not catalog.has_method("get_all_perk_data"):
		return {"accepted": false, "reason": "missing_start_card_catalog"}

	# GRT-032: this is the only bulk catalog lookup for one offer build.
	var all_data_value: Variant = catalog.call("get_all_perk_data")
	if not (all_data_value is Dictionary):
		return {"accepted": false, "reason": "invalid_start_card_catalog"}
	var all_data := all_data_value as Dictionary
	var runtime_levels := _runtime_levels(runtime_state)
	var character_type: String = str(
		_character_context.get_normalized_owner_character_type(owner)
	)
	var skill_config_key: String = str(
		_character_context.get_skill_config_key(character_type)
	)
	var skill_config := _get_registry_instance(registry, skill_config_key)
	var shared_slots_full := (
		skill_config != null
		and skill_config.has_method("is_shared_slot_full")
		and bool(skill_config.call("is_shared_slot_full"))
	)
	var mugong_pool: Array[Dictionary] = []
	var chosik_pool: Array[Dictionary] = []
	var sorted_ids: Array[String] = []
	for id_value in all_data.keys():
		sorted_ids.append(str(id_value))
	sorted_ids.sort()
	for perk_id in sorted_ids:
		var data_value: Variant = all_data.get(perk_id, {})
		if not (data_value is Dictionary):
			continue
		var data := (data_value as Dictionary).duplicate(true)
		data["id"] = perk_id
		var unlocked_skill := str(data.get("unlocks_skill", "")).strip_edges()
		if (
			not unlocked_skill.is_empty()
			and not shared_slots_full
			and _candidate_policy.is_chosik_candidate(
				data,
				runtime_levels,
				character_type,
				registry,
				skill_config
			)
		):
			chosik_pool.append(data)
		elif (
			unlocked_skill.is_empty()
			and int(data.get("max_level", 0)) >= TowerAscentTuning.TEMP_START_CARD_MUGONG_START_LEVEL
			and _candidate_policy.is_mugong_candidate(
			data,
			runtime_levels,
			character_type,
			registry
			)
		):
			mugong_pool.append(data)

	if chosik_pool.size() + mugong_pool.size() < TowerAscentTuning.TEMP_START_CARD_MIN_TOTAL_CANDIDATES:
		return {
			"accepted": false,
			"reason": "start_card_skipped",
			"available_count": chosik_pool.size() + mugong_pool.size(),
			"choices": [],
		}

	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("%s:%s:start_card:%d" % [
		normalized_run_id,
		character_type,
		TowerAscentTuning.TEMP_START_CARD_OFFER_VERSION,
	]))
	_shuffle_with_rng(chosik_pool, rng)
	_shuffle_with_rng(mugong_pool, rng)
	var chosik_count := 0
	if not chosik_pool.is_empty():
		chosik_count = TowerAscentTuning.TEMP_START_CARD_MIN_CHOSIK_COUNT
		if (
			chosik_pool.size() >= TowerAscentTuning.TEMP_START_CARD_MAX_CHOSIK_COUNT
			and rng.randf() < TowerAscentTuning.TEMP_START_CARD_TWO_CHOSIK_CHANCE
		):
			chosik_count = TowerAscentTuning.TEMP_START_CARD_MAX_CHOSIK_COUNT
	var mugong_count := TowerAscentTuning.TEMP_START_CARD_TOTAL_COUNT - chosik_count
	if mugong_count > mugong_pool.size():
		var required_chosik_count := TowerAscentTuning.TEMP_START_CARD_TOTAL_COUNT - mugong_pool.size()
		chosik_count = mini(
			TowerAscentTuning.TEMP_START_CARD_MAX_CHOSIK_COUNT,
			maxi(chosik_count, required_chosik_count)
		)
		chosik_count = mini(chosik_count, chosik_pool.size())
		mugong_count = TowerAscentTuning.TEMP_START_CARD_TOTAL_COUNT - chosik_count

	var choices: Array[Dictionary] = []
	for index in range(chosik_count):
		choices.append(_prepare_choice(chosik_pool[index], "chosik", runtime_levels))
	for index in range(mugong_count):
		choices.append(_prepare_choice(mugong_pool[index], "mugong", runtime_levels))
	_shuffle_with_rng(choices, rng)
	if choices.size() != TowerAscentTuning.TEMP_START_CARD_TOTAL_COUNT:
		return {
			"accepted": false,
			"reason": "start_card_skipped",
			"available_count": choices.size(),
			"choices": [],
		}
	for index in range(choices.size()):
		choices[index]["start_card_slot_index"] = index
	return {
		"accepted": true,
		"reason": "generated",
		"offer_version": TowerAscentTuning.TEMP_START_CARD_OFFER_VERSION,
		"run_id": normalized_run_id,
		"character_type": character_type,
		"choices": choices,
	}


func _prepare_choice(
	data: Dictionary,
	kind: String,
	runtime_levels: Dictionary
) -> Dictionary:
	var choice := data.duplicate(true)
	var perk_id := str(choice.get("id", ""))
	var current_level := maxi(0, int(runtime_levels.get(perk_id, 0)))
	choice["current_level"] = current_level
	choice["next_level"] = (
		TowerAscentTuning.TEMP_START_CARD_MUGONG_START_LEVEL
		if kind == "mugong"
		else current_level + 1
	)
	choice["start_card_kind"] = kind
	choice["enabled"] = true
	for forbidden_key in ["reward_pick_cost", "reward_pick_price_text", "balance_text"]:
		choice.erase(forbidden_key)
	return choice


func _runtime_levels(runtime_state: Object) -> Dictionary:
	var value: Variant = runtime_state.get("runtime_skill_levels")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _shuffle_with_rng(values: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held := values[index]
		values[index] = values[swap_index]
		values[swap_index] = held


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null or key.is_empty():
		return null
	for method_name in ["get_cached_instance", "get_instance"]:
		if registry.has_method(method_name):
			var value: Variant = registry.call(method_name, key)
			if value is Object and value != null:
				return value as Object
	return null
