extends RefCounted

const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const PerkFusionOfferPlanner := preload(
	"res://scripts/characters/perk_fusion_offer_planner.gd"
)
const TowerAscentBossRewardCatalog := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_reward_catalog.gd"
)
const TowerAscentPerkCandidatePolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_perk_candidate_policy.gd"
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
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const OFFER_VERSION := "tower_reward_pick_v3"
const CARD_COUNT := 4
const BAG_EXPANSION_CHOICE_ID := "tower_bag_expansion"
const REFRESH_CHOICE_ID := "common_refresh"
const TEMP_MUGONG_COST := 2
const TEMP_DASH_AMPLIFICATION_COST := 3
const TEMP_FUSION_COST := 3
const TEMP_VISION_COST := 3
const TEMP_SUPREME_COST := 5
const TEMP_BAG_EXPANSION_COST := 2
const TEMP_REFRESH_COST := 1
const TEMP_VISION_DROP_CHANCE := 0.20
const TEMP_REWARD_CHOSIK_CHANCE := 0.25
const TEMP_REFRESH_CHANCE := 0.15
const TEMP_SUPREME_BASE_CHANCE := 0.05
const TEMP_SUPREME_FLOOR_BONUS_PER_FLOOR := 0.005
const TEMP_SUPREME_ELITE_BONUS := 0.03
const TEMP_SUPREME_ENRAGED_BONUS := 0.05
const TEMP_SUPREME_GATEKEEPER_BONUS := 0.04

var _character_context: Object = RuntimePerkCharacterContext.new()
var _perk_candidate_policy: Object = TowerAscentPerkCandidatePolicy.new()


func build_offer(
	context: Dictionary,
	owner: Object,
	registry: Object,
	roll_overrides: Dictionary = {},
	reroll_counter: int = 0
) -> Dictionary:
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var catalog := _get_registry_instance(registry, "runtime_perk_catalog")
	if runtime_state == null or catalog == null:
		return {"accepted": false, "reason": "missing_runtime_perk_contract"}
	var resolution_id := str(context.get("node_resolution_id", "")).strip_edges()
	var boss_slot_id := str(context.get("boss_slot_id", "")).strip_edges()
	if resolution_id.is_empty() or boss_slot_id.is_empty():
		return {"accepted": false, "reason": "missing_reward_pick_context"}
	var offer_generation := maxi(0, reroll_counter)
	var runtime_levels := _runtime_levels(runtime_state)
	var seed_key := "%s:%s:%d:%s" % [
		resolution_id,
		boss_slot_id,
		offer_generation,
		OFFER_VERSION,
	]
	var choices: Array[Dictionary] = []
	var seen: Dictionary = {}

	var vision_choice := _build_vision_choice(
		boss_slot_id,
		context,
		owner,
		registry,
		runtime_levels
	)
	var vision_roll_performed := not vision_choice.is_empty()
	var vision_roll := 1.0
	if vision_roll_performed:
		vision_roll = (
			float(roll_overrides.get("vision", 1.0))
			if roll_overrides.has("vision")
			else _rng_for(seed_key, "vision_roll").randf()
		)
	if vision_roll_performed and vision_roll < TEMP_VISION_DROP_CHANCE:
		_append_choice(choices, seen, vision_choice, TEMP_VISION_COST, "vision")

	var supreme_chance := _supreme_chance(context, runtime_state)
	var supreme_roll := (
		float(roll_overrides.get("supreme", 1.0))
		if roll_overrides.has("supreme")
		else _rng_for(seed_key, "supreme_roll").randf()
	)
	var supreme_rolled := choices.size() < CARD_COUNT
	if supreme_rolled and supreme_roll < supreme_chance:
		var supreme := _build_supreme_choice(
			owner,
			registry,
			runtime_levels,
			catalog,
			_rng_for(seed_key, "supreme_pick")
		)
		if not supreme.is_empty():
			_append_choice(choices, seen, supreme, TEMP_SUPREME_COST, "supreme")

	var refresh_roll_performed := choices.size() < CARD_COUNT
	var refresh_roll := 1.0
	if refresh_roll_performed:
		refresh_roll = (
			float(roll_overrides.get("refresh", 1.0))
			if roll_overrides.has("refresh")
			else _rng_for(seed_key, "refresh_roll").randf()
		)
	if refresh_roll_performed and refresh_roll < TEMP_REFRESH_CHANCE:
		_append_choice(
			choices,
			seen,
			_build_refresh_choice(catalog),
			TEMP_REFRESH_COST,
			"refresh"
		)

	var basic_pools := _build_basic_pools(
		owner,
		registry,
		runtime_state,
		catalog,
		_rng_for(seed_key, "fusion_icon")
	)
	var mugong_pool: Array[Dictionary] = basic_pools.get("mugong", [])
	var chosik_pool: Array[Dictionary] = basic_pools.get("chosik", [])
	var extra_pool: Array[Dictionary] = basic_pools.get("extras", [])
	var has_mugong_candidate := not mugong_pool.is_empty()
	var chosik_roll_performed := (
		not chosik_pool.is_empty()
		and has_mugong_candidate
		and choices.size() <= CARD_COUNT - 2
	)
	var chosik_roll := 1.0
	if chosik_roll_performed:
		chosik_roll = (
			float(roll_overrides.get("chosik", 1.0))
			if roll_overrides.has("chosik")
			else _rng_for(seed_key, "chosik_roll").randf()
		)
	if chosik_roll_performed and chosik_roll < TEMP_REWARD_CHOSIK_CHANCE:
		_shuffle_with_rng(chosik_pool, _rng_for(seed_key, "chosik_order"))
		_append_choice(
			choices,
			seen,
			chosik_pool[0],
			TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST,
			"chosik"
		)
	_shuffle_with_rng(mugong_pool, _rng_for(seed_key, "mugong_order"))
	# Reward-pick upgrades now belong to the in-place owned-Mugong ledger. Keep
	# one genuinely new Mugong on the board whenever stock exists, regardless of
	# Chosik or special-card reservations.
	if not mugong_pool.is_empty() and choices.size() < CARD_COUNT:
		var required_mugong: Dictionary = mugong_pool.pop_front()
		_append_choice(
			choices,
			seen,
			required_mugong,
			resolve_basic_reward_pick_cost(required_mugong),
			"mugong"
		)
	var remainder_pool: Array[Dictionary] = []
	remainder_pool.append_array(mugong_pool)
	remainder_pool.append_array(extra_pool)
	_shuffle_with_rng(remainder_pool, _rng_for(seed_key, "remainder_order"))
	for basic in remainder_pool:
		if choices.size() >= CARD_COUNT:
			break
		var kind := str(basic.get("reward_pick_kind", "mugong"))
		var cost := resolve_basic_reward_pick_cost(basic)
		_append_choice(choices, seen, basic, cost, kind)

	# Late runs can exhaust ordinary Mugong while retaining only Fusion or another
	# protected lane. A smaller non-empty board is safer than dropping the entire
	# reward phase because the four-card target cannot be filled.
	if choices.is_empty():
		return {
			"accepted": false,
			"reason": "insufficient_reward_pick_stock",
			"available_count": 0,
		}
	for index in range(choices.size()):
		choices[index]["reward_pick_slot_index"] = index
		choices[index]["reward_pick_offer_generation"] = offer_generation
	return {
		"accepted": true,
		"reason": "generated",
		"offer_version": OFFER_VERSION,
		"offer_generation": offer_generation,
		"node_resolution_id": resolution_id,
		"boss_slot_id": boss_slot_id,
		"vision_unlock_id": (
			str(vision_choice.get("id", ""))
			if _count_kind(choices, "vision") > 0
			else ""
		),
		"vision_roll_performed": vision_roll_performed,
		"vision_roll": vision_roll,
		"vision_chance": TEMP_VISION_DROP_CHANCE,
		"supreme_roll_performed": supreme_rolled,
		"supreme_roll": supreme_roll,
		"supreme_chance": supreme_chance,
		"chosik_roll_performed": chosik_roll_performed,
		"chosik_roll": chosik_roll,
		"chosik_chance": TEMP_REWARD_CHOSIK_CHANCE,
		"refresh_roll_performed": refresh_roll_performed,
		"refresh_roll": refresh_roll,
		"refresh_chance": TEMP_REFRESH_CHANCE,
		"refresh_offered": _count_kind(choices, "refresh") > 0,
		"requested_card_count": CARD_COUNT,
		"actual_card_count": choices.size(),
		"card_count_policy": "fixed" if choices.size() == CARD_COUNT else "available_stock",
		"choices": choices,
	}


static func resolve_basic_reward_pick_cost(choice: Dictionary) -> int:
	var kind := str(choice.get("reward_pick_kind", "mugong"))
	if kind == "refresh":
		return TEMP_REFRESH_COST
	if kind == "bag_expansion":
		return TEMP_BAG_EXPANSION_COST
	if kind == "fusion":
		return TEMP_FUSION_COST
	if kind == "chosik":
		return TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST
	if str(choice.get("id", choice.get("perk_id", ""))) == "dash_amplification":
		return TEMP_DASH_AMPLIFICATION_COST
	return TEMP_MUGONG_COST


func _build_vision_choice(
	boss_slot_id: String,
	context: Dictionary,
	owner: Object,
	registry: Object,
	runtime_levels: Dictionary
) -> Dictionary:
	if not _owner_boss_identity_matches_slot(owner, boss_slot_id):
		return {}
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


func _owner_boss_identity_matches_slot(owner: Object, boss_slot_id: String) -> bool:
	var current_stage := int(_get_owner_value(owner, "current_stage", 0))
	var variant_property := "stage1_boss_variant" if current_stage == 1 else "stage_boss_variant"
	var owner_variant: Variant = _get_owner_value(owner, variant_property, "")
	var owner_slot_id := TowerAscentBossRewardCatalog.get_boss_slot_id_for_stage_variant(
		current_stage,
		owner_variant
	)
	if owner_slot_id.is_empty():
		return false
	var owner_key := TowerAscentBossRewardCatalog.get_canonical_encounter_key(owner_slot_id)
	var node_key := TowerAscentBossRewardCatalog.get_canonical_encounter_key(boss_slot_id)
	return not owner_key.is_empty() and owner_key == node_key


func _build_supreme_choice(
	owner: Object,
	registry: Object,
	runtime_levels: Dictionary,
	catalog: Object,
	rng: RandomNumberGenerator
) -> Dictionary:
	var character_type: String = str(
		_character_context.get_normalized_owner_character_type(owner)
	)
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
	choice["reward_pick_mugong_acquisition"] = true
	choice["reward_pick_replacement_eligible"] = true
	return choice


func _build_basic_pools(
	owner: Object,
	registry: Object,
	runtime_state: Object,
	catalog: Object,
	rng: RandomNumberGenerator
) -> Dictionary:
	var all_data: Dictionary = {}
	if catalog.has_method("get_all_perk_data"):
		var all_data_value: Variant = catalog.call("get_all_perk_data")
		if all_data_value is Dictionary:
			all_data = (all_data_value as Dictionary).duplicate(true)
	var runtime_levels := _runtime_levels(runtime_state)
	var mugong_result := _build_mugong_choices(
		all_data,
		owner,
		registry,
		runtime_levels
	)
	var chosik_result := _build_chosik_choices(
		all_data,
		owner,
		registry,
		runtime_levels
	)
	var extras: Array[Dictionary] = []
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
				extras.append(fusion)
	var bag_expansion := _build_bag_expansion_choice()
	bag_expansion["reward_pick_kind"] = "bag_expansion"
	extras.append(bag_expansion)
	return {
		"mugong": mugong_result,
		"chosik": chosik_result,
		"extras": extras,
	}


func _build_mugong_choices(
	all_data: Dictionary,
	owner: Object,
	registry: Object,
	runtime_levels: Dictionary
) -> Array[Dictionary]:
	var character_type: String = str(
		_character_context.get_normalized_owner_character_type(owner)
	)
	var sorted_ids: Array[String] = []
	for id_value: Variant in all_data.keys():
		sorted_ids.append(str(id_value))
	sorted_ids.sort()
	var result: Array[Dictionary] = []
	for perk_id: String in sorted_ids:
		if int(runtime_levels.get(perk_id, 0)) != 0:
			continue
		var data_value: Variant = all_data.get(perk_id, {})
		if not (data_value is Dictionary):
			continue
		var choice := (data_value as Dictionary).duplicate(true)
		choice["id"] = perk_id
		if not _is_mugong_choice(choice):
			continue
		if not _perk_candidate_policy.is_mugong_candidate(
			choice,
			runtime_levels,
			character_type,
			registry,
			false
		):
			continue
		choice["current_level"] = 0
		choice["next_level"] = 1
		choice["max_level"] = maxi(1, int(choice.get("max_level", 1)))
		var descriptions_value: Variant = choice.get("descriptions", {})
		if descriptions_value is Dictionary:
			var descriptions := descriptions_value as Dictionary
			choice["description"] = str(descriptions.get(
				1,
				descriptions.get("1", choice.get("description", ""))
			))
		choice["offer_lane"] = "tower_reward_mugong"
		choice["offer_protected"] = false
		choice["reward_pick_kind"] = "mugong"
		choice["reward_pick_mugong_acquisition"] = true
		choice["reward_pick_replacement_eligible"] = true
		result.append(choice)
	return result


func _build_chosik_choices(
	all_data: Dictionary,
	owner: Object,
	registry: Object,
	runtime_levels: Dictionary
) -> Array[Dictionary]:
	var character_type: String = str(
		_character_context.get_normalized_owner_character_type(owner)
	)
	var skill_config_key: String = str(
		_character_context.get_skill_config_key(character_type)
	)
	var skill_config := _get_registry_instance(registry, skill_config_key)
	if (
		skill_config == null
		or not skill_config.has_method("is_shared_slot_full")
		or bool(skill_config.call("is_shared_slot_full"))
	):
		return []
	var sorted_ids: Array[String] = []
	for id_value: Variant in all_data.keys():
		sorted_ids.append(str(id_value))
	sorted_ids.sort()
	var result: Array[Dictionary] = []
	for perk_id: String in sorted_ids:
		var data_value: Variant = all_data.get(perk_id, {})
		if not (data_value is Dictionary):
			continue
		var choice := (data_value as Dictionary).duplicate(true)
		choice["id"] = perk_id
		if not _perk_candidate_policy.is_chosik_candidate(
			choice,
			runtime_levels,
			character_type,
			registry,
			skill_config
		):
			continue
		choice["current_level"] = 0
		choice["next_level"] = 1
		result.append(choice)
	return result


func _build_refresh_choice(catalog: Object) -> Dictionary:
	var choice: Dictionary = {}
	if catalog != null and catalog.has_method("get_perk_data"):
		var choice_value: Variant = catalog.call("get_perk_data", REFRESH_CHOICE_ID)
		if choice_value is Dictionary:
			choice = (choice_value as Dictionary).duplicate(true)
	choice["id"] = REFRESH_CHOICE_ID
	choice["name"] = TowerRewardPickLocalization.text("refresh_name")
	choice["description"] = TowerRewardPickLocalization.text("refresh_description")
	choice["detail"] = TowerRewardPickLocalization.text("refresh_detail")
	choice["current_level"] = 0
	choice["next_level"] = 0
	choice["max_level"] = 0
	choice["tree"] = "instant"
	choice["is_instant"] = true
	choice["offer_lane"] = "tower_reward_refresh"
	choice["offer_protected"] = true
	return choice


func _build_bag_expansion_choice() -> Dictionary:
	return {
		"id": BAG_EXPANSION_CHOICE_ID,
		"name": TowerRewardPickLocalization.text("bag_expansion_name"),
		"description": TowerRewardPickLocalization.text("bag_expansion_description"),
		"detail": TowerRewardPickLocalization.text("bag_expansion_detail"),
		"current_level": 0,
		"next_level": 0,
		"max_level": 0,
		"tree": "instant",
		"is_instant": true,
		"offer_lane": "tower_reward_special",
		"offer_protected": false,
	}


func _is_mugong_choice(choice: Dictionary) -> bool:
	var choice_id := str(choice.get("id", choice.get("perk_id", ""))).strip_edges()
	if choice_id.is_empty() or choice_id == "convert_to_gold":
		return false
	if not str(choice.get("unlocks_skill", "")).strip_edges().is_empty():
		return false
	for excluded_flag in TowerAscentPerkCandidatePolicy.EXCLUDED_MUGONG_FLAGS:
		if bool(choice.get(excluded_flag, false)):
			return false
	return true


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
	var treasure_method := (
		"get_downtown_treasure_map_reward_pick_multiplier"
		if runtime_state.has_method("get_downtown_treasure_map_reward_pick_multiplier")
		else "get_downtown_treasure_map_mythic_multiplier"
	)
	if runtime_state.has_method(treasure_method):
		chance *= maxf(1.0, float(runtime_state.call(treasure_method)))
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


static func _count_kind(choices: Array[Dictionary], kind: String) -> int:
	var count := 0
	for choice: Dictionary in choices:
		if str(choice.get("reward_pick_kind", "")) == kind:
			count += 1
	return count


func _runtime_levels(runtime_state: Object) -> Dictionary:
	var value: Variant = runtime_state.get("runtime_skill_levels")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else value


func _shuffle_with_rng(values: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held := values[index]
		values[index] = values[swap_index]
		values[swap_index] = held


func _rng_for(seed_key: String, domain: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("%s:%s" % [seed_key, domain]))
	return rng


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null or key.is_empty():
		return null
	for method_name in ["get_cached_instance", "get_instance"]:
		if registry.has_method(method_name):
			var value: Variant = registry.call(method_name, key)
			if value is Object and value != null:
				return value as Object
	return null
