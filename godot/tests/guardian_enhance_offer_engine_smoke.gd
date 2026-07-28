extends SceneTree

const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)
const GuardianEnhanceOfferEngine := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_offer_engine.gd"
)
const PerkFusionCatalog := preload("res://scripts/characters/perk_fusion_catalog.gd")

var _failures := 0


class DynamicOwner:
	extends Node
	var lingpet_owned_pet_ids: Array[String] = []


func _init() -> void:
	_verify_owned_gate_and_offer_pacing()
	_verify_prefilter_axes_and_cardinality()
	_verify_perk_metadata_and_fusion_exclusion()
	if _failures == 0:
		print("guardian_enhance_offer_engine_smoke: ok")
	quit(_failures)


func _verify_owned_gate_and_offer_pacing() -> void:
	var engine := GuardianEnhanceOfferEngine.new()
	var owner := DynamicOwner.new()
	root.add_child(owner)
	var pet_data := _open_pet_data("patrol")
	var blocked := engine.build_offer(owner, pet_data, 0, true, true, _seeded_rng())
	_expect(not bool(blocked.get("offer_allowed", false)), "unowned players must never see Guardian Enhancement")
	owner.lingpet_owned_pet_ids = ["maribo"]
	var first := engine.build_offer(owner, pet_data, 0, true, true, _seeded_rng())
	_expect(bool(first.get("offer_allowed", false)), "owned guardian should open the enhancement lane")
	_expect(bool(first.get("reserve", false)), "first eligible screen after ownership must be reserved")
	engine.mark_applied()
	for hidden_index in range(3):
		var hidden := engine.build_offer(owner, pet_data, 0, true, true, _seeded_rng())
		_expect(not bool(hidden.get("offer_allowed", false)), "applied enhancement must hide on cooldown screen %d" % (hidden_index + 1))
	var reappeared := engine.build_offer(owner, pet_data, 0, true, true, _seeded_rng())
	_expect(bool(reappeared.get("offer_allowed", false)), "enhancement should become eligible after exactly three hidden screens")
	_expect(not bool(reappeared.get("reserve", true)), "only the first ownership offer receives reservation priority")
	owner.queue_free()


func _verify_prefilter_axes_and_cardinality() -> void:
	var owner := DynamicOwner.new()
	root.add_child(owner)
	owner.lingpet_owned_pet_ids = ["maribo"]
	var saturated := _saturated_pet_data("patrol")
	var under_two := GuardianEnhanceOfferEngine.new().build_offer(
		owner,
		saturated,
		1,
		false,
		false,
		_seeded_rng()
	)
	_expect(not bool(under_two.get("offer_allowed", false)), "fewer than two valid candidates must suppress the perk card")
	_expect((under_two.get("candidates", []) as Array).size() == 1, "fixture must leave exactly one candidate instead of passing vacuously")

	saturated["reward_counts"]["gauge_stacks"] = LingpetEnhancementBuffStore.MAX_GAUGE_STACKS - 1
	var exactly_two := GuardianEnhanceOfferEngine.new().build_offer(
		owner,
		saturated,
		1,
		false,
		false,
		_seeded_rng()
	)
	_expect((exactly_two.get("candidates", []) as Array).size() == 2, "exactly two valid candidates must both be presented")

	var open_offer := GuardianEnhanceOfferEngine.new().build_offer(
		owner,
		_open_pet_data("patrol"),
		0,
		true,
		true,
		_seeded_rng()
	)
	var presented: Array = open_offer.get("candidates", []) as Array
	_expect(presented.size() == 3, "three or more valid candidates must present exactly three")
	var seen := {}
	for candidate_value in presented:
		var candidate := candidate_value as Dictionary
		var key := "%s:%d" % [str(candidate.get("type", "")), int(candidate.get("skill_slot", 0))]
		seen[key] = true
	_expect(seen.size() == presented.size(), "presented candidates must be sampled without replacement")

	var flight_candidates := LingpetEnhancementBuffStore.build_guardian_enhancement_candidates(
		_open_pet_data("flight"),
		0,
		true,
		true
	)
	_expect(not _has_type(flight_candidates, LingpetEnhancementBuffStore.REWARD_TYPE_DEFENSE), "flight guardian must prefilter the permanent-zero defense candidate")
	var flight_mobility := _find_type(flight_candidates, LingpetEnhancementBuffStore.REWARD_TYPE_MOBILITY)
	_expect(str(flight_mobility.get("remapped_stat", "")) == "appearance_rate", "flight mobility must remain valid through the appearance-rate remap")

	var duration_candidate := GuardianEnhanceOfferEngine.localize_candidate({"type": LingpetEnhancementBuffStore.REWARD_TYPE_DURATION})
	_expect(float(duration_candidate.get("weight", 1.0)) < GuardianEnhanceOfferEngine.DEFAULT_WEIGHT, "duration increase must carry a lower presentation weight")
	owner.queue_free()


func _verify_perk_metadata_and_fusion_exclusion() -> void:
	var data := GuardianEnhanceOfferEngine.get_perk_data()
	_expect(str(data.get("name", "")) == "수호령강화", "Korean player-facing perk name must be 수호령강화")
	_expect(bool(data.get("repeatable_choice", false)), "enhancement card must remain repeatable after cooldown")
	_expect(bool(data.get("exclude_from_perk_fusion", false)), "enhancement must opt out of perk fusion")
	var classification := PerkFusionCatalog.new().classify_perk(
		GuardianEnhanceOfferEngine.PERK_ID,
		FakeCatalog.new(),
		0
	)
	_expect(not bool(classification.get("is_candidate_class", true)), "fusion classifier must honor the explicit exclusion")


class FakeCatalog:
	extends RefCounted

	func get_perk_data(perk_id: String) -> Dictionary:
		if perk_id == GuardianEnhanceOfferEngine.PERK_ID:
			return GuardianEnhanceOfferEngine.get_perk_data()
		return {}


func _open_pet_data(motion_style: String) -> Dictionary:
	var counts := LingpetEnhancementBuffStore.get_empty_reward_counts()
	counts["active_unlocked"] = true
	counts["passive_unlocked"] = true
	counts["signature"] = LingpetEnhancementBuffStore.build_reward_signature(counts)
	return {
		"pet_id": "maribo",
		"reward_motion_style": motion_style,
		"active_skill_base_level": 1,
		"passive_skill_base_level": 1,
		"reward_counts": counts,
	}


func _saturated_pet_data(motion_style: String) -> Dictionary:
	var counts := LingpetEnhancementBuffStore.get_empty_reward_counts()
	counts["active_unlocked"] = true
	counts["passive_unlocked"] = true
	counts["mobility_stacks"] = LingpetEnhancementBuffStore.MAX_MOBILITY_STACKS
	counts["defense_stacks"] = LingpetEnhancementBuffStore.MAX_DEFENSE_STACKS
	counts["gauge_stacks"] = LingpetEnhancementBuffStore.MAX_GAUGE_STACKS
	counts["signature"] = LingpetEnhancementBuffStore.build_reward_signature(counts)
	return {
		"pet_id": "maribo",
		"reward_motion_style": motion_style,
		"active_skill_base_level": LingpetEnhancementBuffStore.SKILL_LEVEL_MAX,
		"passive_skill_base_level": LingpetEnhancementBuffStore.SKILL_LEVEL_MAX,
		"reward_counts": counts,
	}


func _seeded_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260728
	return rng


func _has_type(candidates: Array[Dictionary], reward_type: String) -> bool:
	return not _find_type(candidates, reward_type).is_empty()


func _find_type(candidates: Array[Dictionary], reward_type: String) -> Dictionary:
	for candidate in candidates:
		if str(candidate.get("type", "")) == reward_type:
			return candidate
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
