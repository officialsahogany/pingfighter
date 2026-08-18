extends RefCounted

const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const PerkFusionOfferPlanner := preload(
	"res://scripts/characters/perk_fusion_offer_planner.gd"
)
const TowerAscentTrainingOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_ascent_training_offer_builder.gd"
)
const TowerAscentBossRewardCatalog := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_reward_catalog.gd"
)
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)
const RuntimePerkCharacterContext := preload(
	"res://scripts/characters/runtime_perk_character_context.gd"
)
const TowerRewardPickLocalization := preload(
	"res://scripts/tower_ascent/tower_reward_pick_localization.gd"
)

const OFFER_VERSION := "tower_reward_pick_v1"
const CARD_COUNT := 4
const TEMP_TRAINING_COST := 1
const TEMP_MUGONG_COST := 2
const TEMP_FUSION_COST := 3
const TEMP_VISION_COST := 3
const TEMP_SUPREME_COST := 5
const TEMP_SUPREME_BASE_CHANCE := 0.05
const TEMP_SUPREME_FLOOR_BONUS_PER_FLOOR := 0.005
const TEMP_SUPREME_ELITE_BONUS := 0.03
const TEMP_SUPREME_ENRAGED_BONUS := 0.05
const TEMP_SUPREME_GATEKEEPER_BONUS := 0.04

var _training_builder: Object = TowerAscentTrainingOfferBuilder.new()
var _character_context: Object = RuntimePerkCharacterContext.new()


func build_offer(
	context: Dictionary,
	owner: Object,
	registry: Object,
	roll_overrides: Dictionary = {}
) -> Dictionary:
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var catalog := _get_registry_instance(registry, "runtime_perk_catalog")
	if runtime_state == null or catalog == null:
		return {"accepted": false, "reason": "missing_runtime_perk_contract"}
	var resolution_id := str(context.get("node_resolution_id", "")).strip_edges()
	var boss_slot_id := str(context.get("boss_slot_id", "")).strip_edges()
	if resolution_id.is_empty() or boss_slot_id.is_empty():
		return {"accepted": false, "reason": "missing_reward_pick_context"}
	var runtime_levels := _runtime_levels(runtime_state)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("%s:%s:%s" % [resolution_id, boss_slot_id, OFFER_VERSION]))
	var choices: Array[Dictionary] = []
	var seen: Dictionary = {}

	var vision_choice := _build_vision_choice(
		boss_slot_id,
		context,
		owner,
		registry,
		runtime_levels
	)
	if not vision_choice.is_empty():
		_append_choice(choices, seen, vision_choice, TEMP_VISION_COST, "vision")

	var supreme_chance := _supreme_chance(context, runtime_state)
	var supreme_roll := (
		float(roll_overrides.get("supreme", 1.0))
		if roll_overrides.has("supreme")
		else rng.randf()
	)
	var supreme_rolled := choices.size() < CARD_COUNT
	if supreme_rolled and supreme_roll < supreme_chance:
		var supreme := _build_supreme_choice(owner, registry, runtime_levels, catalog, rng)
		if not supreme.is_empty():
			_append_choice(choices, seen, supreme, TEMP_SUPREME_COST, "supreme")

	var basic_pool := _build_basic_pool(context, owner, registry, runtime_state, catalog, rng)
	_shuffle_with_rng(basic_pool, rng)
	for basic in basic_pool:
		if choices.size() >= CARD_COUNT:
			break
		var kind := str(basic.get("reward_pick_kind", "mugong"))
		var cost := TEMP_TRAINING_COST if kind == "training" else (
			TEMP_FUSION_COST if kind == "fusion" else TEMP_MUGONG_COST
		)
		_append_choice(choices, seen, basic, cost, kind)

	if choices.size() != CARD_COUNT:
		return {
			"accepted": false,
			"reason": "insufficient_reward_pick_stock",
			"available_count": choices.size(),
		}
	for index in range(choices.size()):
		choices[index]["reward_pick_slot_index"] = index
	return {
		"accepted": true,
		"reason": "generated",
		"offer_version": OFFER_VERSION,
		"node_resolution_id": resolution_id,
		"boss_slot_id": boss_slot_id,
		"vision_unlock_id": str(vision_choice.get("id", "")),
		"supreme_roll_performed": supreme_rolled,
		"supreme_roll": supreme_roll,
		"supreme_chance": supreme_chance,
		"choices": choices,
	}


func _build_vision_choice(
	boss_slot_id: String,
	context: Dictionary,
	owner: Object,
	registry: Object,
	runtime_levels: Dictionary
) -> Dictionary:
	var skipped: Array = context.get("skipped_boss_ids", []) as Array
	var burned: Array = context.get("burned_vision_boss_ids", []) as Array
	if skipped.has(boss_slot_id) or burned.has(boss_slot_id):
		return {}
	if TowerAscentBossRewardCatalog.is_owned(runtime_levels, boss_slot_id):
		return {}
	var choice := TowerAscentBossRewardCatalog.build_vision_choice(boss_slot_id)
	if choice.is_empty():
		return {}
	if not TowerAscentUnlockFilter.is_content_unlocked(
		registry,
		TowerAscentUnlockFilter.CONTENT_RUNTIME_PERK,
		str(choice.get("id", ""))
	):
		return {}
	var character_type: String = str(_character_context.get_owner_character_type(owner))
	var config_key: String = str(_character_context.get_skill_config_key(character_type))
	var skill_config := _get_registry_instance(registry, config_key)
	var unlocked_skill := str(choice.get("unlocks_skill", ""))
	if skill_config != null and skill_config.has_method("is_shared_slot_full"):
		var slot_full := bool(skill_config.call("is_shared_slot_full"))
		choice["vision_swap_required"] = slot_full
		if slot_full and skill_config.has_method("get_shared_slot_swap_candidates"):
			var candidates_value: Variant = skill_config.call(
				"get_shared_slot_swap_candidates",
				unlocked_skill
			)
			var candidates: Array = candidates_value if candidates_value is Array else []
			if candidates.is_empty():
				return {}
			choice["vision_swap_candidates"] = candidates.duplicate()
			choice["detail"] = "%s  %s" % [
				str(choice.get("detail", choice.get("description", ""))),
				TowerRewardPickLocalization.text("vision_swap"),
			]
	return choice


func _build_supreme_choice(
	owner: Object,
	registry: Object,
	runtime_levels: Dictionary,
	catalog: Object,
	rng: RandomNumberGenerator
) -> Dictionary:
	if not catalog.has_method("has_open_perk_slot") or not bool(catalog.call(
		"has_open_perk_slot",
		runtime_levels,
		registry
	)):
		return {}
	var character_type: String = str(_character_context.get_owner_character_type(owner))
	var ids: Array[String] = []
	for id_value in RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.keys():
		var perk_id := str(id_value)
		var data: Dictionary = RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS[perk_id]
		var restriction := str(data.get("character_restriction", "")).strip_edges().to_lower()
		if int(runtime_levels.get(perk_id, 0)) <= 0 and (restriction.is_empty() or restriction == character_type):
			if TowerAscentUnlockFilter.is_content_unlocked(
				registry,
				TowerAscentUnlockFilter.CONTENT_RUNTIME_PERK,
				perk_id
			):
				ids.append(perk_id)
	if ids.is_empty():
		return {}
	ids.sort()
	var perk_id := ids[rng.randi_range(0, ids.size() - 1)]
	var choice_value: Variant = catalog.call("get_perk_data", perk_id)
	if not (choice_value is Dictionary):
		return {}
	var choice := (choice_value as Dictionary).duplicate(true)
	choice["id"] = perk_id
	choice["current_level"] = 0
	choice["next_level"] = 1
	choice["offer_lane"] = "tower_reward_supreme"
	choice["offer_protected"] = true
	return choice


func _build_basic_pool(
	context: Dictionary,
	owner: Object,
	registry: Object,
	runtime_state: Object,
	catalog: Object,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var generated: Dictionary = _training_builder.build_offer(
		"reward_pick:%s" % str(context.get("node_resolution_id", "")),
		int(context.get("map_seed", 0)),
		owner,
		registry
	)
	var result: Array[Dictionary] = []
	if bool(generated.get("accepted", false)):
		for value in generated.get("stat_choices", []):
			if value is Dictionary:
				var training := (value as Dictionary).duplicate(true)
				training["reward_pick_kind"] = "training"
				result.append(training)
		for value in generated.get("mugong_choices", []):
			if value is Dictionary:
				var mugong := (value as Dictionary).duplicate(true)
				mugong["reward_pick_kind"] = "mugong"
				result.append(mugong)
	var fusion_candidates: Array = []
	if runtime_state.has_method("get_perk_fusion_candidate_ids"):
		var candidate_value: Variant = runtime_state.call("get_perk_fusion_candidate_ids", catalog)
		if candidate_value is Array:
			fusion_candidates = candidate_value as Array
	if fusion_candidates.size() >= 2:
		var planner := PerkFusionOfferPlanner.new()
		if planner.has_method("build_offer_card"):
			var fusion: Dictionary = planner.call(
				"build_offer_card",
				fusion_candidates,
				rng.randi_range(0, PerkFusionOfferPlanner.ICON_VARIANT_COUNT - 1)
			)
			if not fusion.is_empty():
				fusion["reward_pick_kind"] = "fusion"
				result.append(fusion)
	return result


func _supreme_chance(context: Dictionary, runtime_state: Object) -> float:
	var floor_number := maxi(1, int(context.get("floor", 1)))
	var chance := TEMP_SUPREME_BASE_CHANCE
	chance += float(floor_number - 1) * TEMP_SUPREME_FLOOR_BONUS_PER_FLOOR
	if bool(context.get("is_elite", false)):
		chance += TEMP_SUPREME_ELITE_BONUS
	if bool(context.get("is_enraged", false)):
		chance += TEMP_SUPREME_ENRAGED_BONUS
	if bool(context.get("is_gatekeeper", false)):
		chance += TEMP_SUPREME_GATEKEEPER_BONUS
	if runtime_state.has_method("get_downtown_treasure_map_mythic_multiplier"):
		chance *= maxf(1.0, float(runtime_state.call(
			"get_downtown_treasure_map_mythic_multiplier"
		)))
	return clampf(chance, 0.0, 1.0)


func _append_choice(
	choices: Array[Dictionary],
	seen: Dictionary,
	choice_value: Dictionary,
	cost: int,
	kind: String
) -> void:
	var choice := choice_value.duplicate(true)
	var choice_id := str(choice.get("id", choice.get("perk_id", ""))).strip_edges()
	if choice_id.is_empty() or seen.has(choice_id):
		return
	seen[choice_id] = true
	choice["id"] = choice_id
	choice["reward_pick_kind"] = kind
	choice["reward_pick_cost"] = maxi(0, cost)
	choice["reward_pick_price_text"] = TowerRewardPickLocalization.text(
		"price",
		{"amount": maxi(0, cost)}
	)
	choices.append(choice)


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
