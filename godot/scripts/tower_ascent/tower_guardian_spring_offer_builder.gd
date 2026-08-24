extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)
const LingpetGuardianRunState := preload(
	"res://scripts/lingpet/lingpet_guardian_run_state.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const FIRST_PICK_SEED_NAMESPACE := "tower_spring_first_pick_v1"
const BROWSE_SEED_NAMESPACE := "tower_spring_browse_v1"
const OFFER_COUNT := 3
const EXCLUDED_ELITE_REWARD_TYPES := [
	LingpetEnhancementBuffStore.REWARD_TYPE_DURATION,
]


func build_first_pick_candidates(
	map_seed: int,
	node_id: String,
	excluded_pet_ids: Array = []
) -> Array[Dictionary]:
	var seed_text := "%s:%d:%s" % [FIRST_PICK_SEED_NAMESPACE, map_seed, node_id]
	var result: Array[Dictionary] = []
	for pet_id in _pick_unique_pet_ids(seed_text, excluded_pet_ids):
		result.append({
			"pet_id": pet_id,
			"display_name": LingpetCatalog.get_display_name(pet_id),
			"art_path": LingpetCatalog.get_visual_path(pet_id, "cutin_art"),
		})
	return result


func build_browse_offers(
	map_seed: int,
	node_id: String,
	sequence: int,
	current_floor: int,
	excluded_pet_ids: Array = []
) -> Array[Dictionary]:
	var normalized_sequence := maxi(0, sequence)
	var roll_count := clampi(
		current_floor,
		TowerAscentTuning.TEMP_SPRING_BROWSE_ROLL_MIN,
		TowerAscentTuning.TEMP_SPRING_BROWSE_ROLL_MAX
	)
	var seed_text := "%s:%d:%s:%d" % [
		BROWSE_SEED_NAMESPACE,
		map_seed,
		node_id,
		normalized_sequence,
	]
	var offers: Array[Dictionary] = []
	var pet_ids := _pick_unique_pet_ids(seed_text, excluded_pet_ids)
	for offer_index in range(pet_ids.size()):
		var pet_id := str(pet_ids[offer_index])
		offers.append(_build_elite_offer(
			pet_id,
			roll_count,
			"%s:%d" % [seed_text, offer_index]
		))
	return offers


func price_for_roll_count(applied_roll_count: int) -> int:
	return (
		TowerAscentTuning.TEMP_SPRING_BROWSE_BASE_PRICE_GOLD
		+ TowerAscentTuning.TEMP_SPRING_BROWSE_PRICE_PER_ROLL_GOLD
		* maxi(0, applied_roll_count)
	)


func _build_elite_offer(pet_id: String, roll_count: int, seed_text: String) -> Dictionary:
	var base_loadout := LingpetCatalog.build_default_loadout(pet_id)
	var local_state: Object = LingpetGuardianRunState.new()
	local_state.configure_reward_context(
		pet_id,
		LingpetCatalog.get_motion_style(pet_id),
		maxi(1, int(base_loadout.get("active_skill_level", 1))),
		maxi(1, int(base_loadout.get("passive_skill_level", 1))),
		absi(hash(seed_text)),
		false,
		str(base_loadout.get("active_skill_id", "")),
		str(base_loadout.get("passive_skill_id", ""))
	)
	var availability: Dictionary = local_state.get_guardian_enhancement_skill_availability(pet_id)
	var has_second_active := bool(availability.get("has_second_active", false))
	var has_second_passive := bool(availability.get("has_second_passive", false))
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(seed_text))
	var applied_rolls: Array[Dictionary] = []
	for _roll_index in range(roll_count):
		var candidates: Array[Dictionary] = local_state.build_guardian_enhancement_candidates(
			pet_id,
			has_second_active,
			has_second_passive
		)
		var eligible: Array[Dictionary] = []
		for candidate in candidates:
			if str(candidate.get("type", "")) not in EXCLUDED_ELITE_REWARD_TYPES:
				eligible.append(candidate.duplicate(true))
		if eligible.is_empty():
			break
		var selected := eligible[rng.randi_range(0, eligible.size() - 1)].duplicate(true)
		var apply_result: Dictionary = local_state.apply_guardian_enhancement(
			pet_id,
			selected,
			has_second_active,
			has_second_passive
		)
		if not bool(apply_result.get("accepted", false)):
			break
		applied_rolls.append(selected)
		_resolve_deterministic_unlock(local_state, pet_id, selected, base_loadout, rng)
	var reward_counts: Dictionary = local_state.get_cumulative_rewards(pet_id)
	var resolved_unlocks: Dictionary = local_state.get_resolved_unlock_choices(pet_id)
	var elite_loadout := _build_elite_loadout(
		base_loadout,
		reward_counts,
		resolved_unlocks
	)
	return {
		"pet_id": pet_id,
		"display_name": LingpetCatalog.get_display_name(pet_id),
		"art_path": LingpetCatalog.get_visual_path(pet_id, "cutin_art"),
		"motion_style": LingpetCatalog.get_motion_style(pet_id),
		"offer_seed": absi(hash(seed_text)),
		"roll_count": roll_count,
		"applied_roll_count": applied_rolls.size(),
		"price_gold": price_for_roll_count(applied_rolls.size()),
		"applied_rolls": applied_rolls,
		"reward_counts": reward_counts,
		"resolved_unlocks": resolved_unlocks,
		"base_loadout": _build_base_loadout_with_resolved_slots(
			base_loadout,
			resolved_unlocks
		),
		"loadout": elite_loadout,
		"reward_summary": _build_reward_summary(reward_counts),
	}


func _build_elite_loadout(
	base_loadout: Dictionary,
	reward_counts: Dictionary,
	resolved_unlocks: Dictionary
) -> Dictionary:
	var result := _build_base_loadout_with_resolved_slots(base_loadout, resolved_unlocks)
	var active_id := str(result.get("active_skill_id", ""))
	var passive_id := str(result.get("passive_skill_id", ""))
	var second_active_id := str(result.get("second_active_skill_id", ""))
	var second_passive_id := str(result.get("second_passive_skill_id", ""))
	var active_level := LingpetCatalog.clamp_skill_level(
		maxi(1, int(result.get("active_skill_level", 1)))
		+ int(reward_counts.get("active_skill_bonus", 0))
	)
	var passive_level := LingpetCatalog.clamp_skill_level(
		maxi(1, int(result.get("passive_skill_level", 1)))
		+ int(reward_counts.get("passive_skill_bonus", 0))
	)
	result["active_skill_level"] = active_level
	result["passive_skill_level"] = passive_level
	var active_levels := {active_id: active_level} if active_id != "" else {}
	var passive_levels := {passive_id: passive_level} if passive_id != "" else {}
	if second_active_id != "":
		var second_active_level := LingpetCatalog.clamp_skill_level(
			1 + int(reward_counts.get("second_active_skill_bonus", 0))
		)
		result["second_active_skill_level"] = second_active_level
		active_levels[second_active_id] = second_active_level
	if second_passive_id != "":
		var second_passive_level := LingpetCatalog.clamp_skill_level(
			1 + int(reward_counts.get("second_passive_skill_bonus", 0))
		)
		result["second_passive_skill_level"] = second_passive_level
		passive_levels[second_passive_id] = second_passive_level
	result["active_skill_levels"] = active_levels
	result["passive_skill_levels"] = passive_levels
	var active_ids: Array[String] = []
	var passive_ids: Array[String] = []
	if active_id != "":
		active_ids.append(active_id)
	if second_active_id != "":
		active_ids.append(second_active_id)
	if passive_id != "":
		passive_ids.append(passive_id)
	if second_passive_id != "":
		passive_ids.append(second_passive_id)
	result["active_skill_ids"] = active_ids
	result["passive_skill_ids"] = passive_ids
	return result


func _resolve_deterministic_unlock(
	local_state: Object,
	pet_id: String,
	candidate: Dictionary,
	base_loadout: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var reward_type := str(candidate.get("type", ""))
	var ids: Array[String] = []
	var primary_id := ""
	if reward_type == LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_ACTIVE_UNLOCK:
		primary_id = str(base_loadout.get("active_skill_id", ""))
		for skill in LingpetCatalog.get_acquirable_active_skill_pool(pet_id):
			ids.append(str(skill.get("id", "")))
	elif reward_type == LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_PASSIVE_UNLOCK:
		primary_id = str(base_loadout.get("passive_skill_id", ""))
		for skill in LingpetCatalog.get_passive_skill_pool(pet_id):
			ids.append(str(skill.get("id", "")))
	else:
		return
	ids.erase(primary_id)
	if ids.is_empty():
		return
	var selected_id := ids[rng.randi_range(0, ids.size() - 1)]
	local_state.resolve_single_unlock(pet_id, reward_type, selected_id)


func _build_base_loadout_with_resolved_slots(
	base_loadout: Dictionary,
	resolved_unlocks: Dictionary
) -> Dictionary:
	var result := base_loadout.duplicate(true)
	var second_active_id := _resolved_unlock_id(resolved_unlocks, "second_active")
	var second_passive_id := _resolved_unlock_id(resolved_unlocks, "second_passive")
	result["second_active_skill_id"] = second_active_id
	result["second_passive_skill_id"] = second_passive_id
	result["second_active_skill_level"] = 1 if second_active_id != "" else 0
	result["second_passive_skill_level"] = 1 if second_passive_id != "" else 0
	result["active_slot_count"] = 2 if second_active_id != "" else 1
	result["passive_slot_count"] = 2 if second_passive_id != "" else 1
	return result


func _resolved_unlock_id(resolved_unlocks: Dictionary, choice_key: String) -> String:
	var choice: Dictionary = resolved_unlocks.get(choice_key, {}) as Dictionary
	return str(choice.get("selected", ""))


func _build_reward_summary(counts: Dictionary) -> Array[String]:
	var result: Array[String] = []
	_append_count_label(result, "액티브", int(counts.get("active_skill_bonus", 0)))
	_append_count_label(result, "패시브", int(counts.get("passive_skill_bonus", 0)))
	if bool(counts.get("second_active_unlocked", false)):
		result.append("액티브 2슬롯")
	if bool(counts.get("second_passive_unlocked", false)):
		result.append("패시브 2슬롯")
	_append_count_label(result, "액티브2", int(counts.get("second_active_skill_bonus", 0)))
	_append_count_label(result, "패시브2", int(counts.get("second_passive_skill_bonus", 0)))
	_append_count_label(result, "기동", int(counts.get("mobility_stacks", 0)))
	_append_count_label(result, "방어", int(counts.get("defense_stacks", 0)))
	_append_count_label(result, "기력", int(counts.get("gauge_stacks", 0)))
	return result


func _append_count_label(result: Array[String], label: String, count: int) -> void:
	if count > 0:
		result.append("%s +%d" % [label, count])


func _pick_unique_pet_ids(seed_text: String, excluded_pet_ids: Array) -> Array[String]:
	var excluded: Dictionary = {}
	for raw_pet_id in excluded_pet_ids:
		excluded[str(raw_pet_id).strip_edges().to_lower()] = true
	var candidates: Array[String] = []
	for pet_id in LingpetCatalog.get_pet_ids():
		var normalized := str(pet_id).strip_edges().to_lower()
		if normalized != "" and not excluded.has(normalized):
			candidates.append(normalized)
	candidates.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(seed_text))
	for i in range(candidates.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, i)
		var held := candidates[i]
		candidates[i] = candidates[swap_index]
		candidates[swap_index] = held
	var result: Array[String] = []
	for i in range(mini(OFFER_COUNT, candidates.size())):
		result.append(candidates[i])
	return result
