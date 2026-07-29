extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")

const REWARD_COUNTS_KEY := "reward_counts"

const REWARD_TYPE_ACTIVE_UNLOCK := "active_unlock"
const REWARD_TYPE_PASSIVE_UNLOCK := "passive_unlock"
const REWARD_TYPE_SECOND_ACTIVE_UNLOCK := "second_active_unlock"
const REWARD_TYPE_SECOND_PASSIVE_UNLOCK := "second_passive_unlock"
const REWARD_TYPE_ACTIVE_SKILL := "active_skill"
const REWARD_TYPE_PASSIVE_SKILL := "passive_skill"
const REWARD_TYPE_MOBILITY := "mobility"
const REWARD_TYPE_DEFENSE := "defense"
const REWARD_TYPE_GAUGE := "gauge"
const REWARD_TYPE_DURATION := "duration"
const REWARD_TYPE_NO_REWARD := "no_reward"

const MOTION_STYLE_PATROL := "patrol"
const MOTION_STYLE_FLIGHT := "flight"
const SKILL_LEVEL_MAX := 5
const MAX_MOBILITY_STACKS := 6
const MAX_DEFENSE_STACKS := 2
const MAX_GAUGE_STACKS := 4
const MAX_DURATION_INCREASES := 2

# §9-3 reservation: a future duration-increase enhancement is run-global and
# belongs to the shared duration owner. It must never be persisted in this
# per-pet reward_counts store.


static func get_empty_reward_counts() -> Dictionary:
	return {
		"active_unlocked": false,
		"passive_unlocked": false,
		"second_active_unlocked": false,
		"second_passive_unlocked": false,
		"active_skill_bonus": 0,
		"passive_skill_bonus": 0,
		"second_active_skill_bonus": 0,
		"second_passive_skill_bonus": 0,
		"mobility_stacks": 0,
		"defense_stacks": 0,
		"gauge_stacks": 0,
		"support_stacks": 0,
		"title_unlocked": false,
		"signature": empty_reward_signature(),
	}


static func normalize_reward_counts(raw_counts: Dictionary) -> Dictionary:
	var counts := get_empty_reward_counts()
	for key in counts.keys():
		if raw_counts.has(key):
			counts[key] = raw_counts.get(key)
	counts["support_stacks"] = (
		int(counts.get("defense_stacks", 0))
		+ int(counts.get("gauge_stacks", 0))
	)
	counts["signature"] = build_reward_signature(counts)
	return counts


static func reward_counts_snapshot(pet_data: Dictionary) -> Dictionary:
	var raw_counts: Variant = pet_data.get(REWARD_COUNTS_KEY, {})
	if raw_counts is Dictionary:
		return normalize_reward_counts(raw_counts as Dictionary)
	return get_empty_reward_counts()


static func initialize_pet_state(pet_data: Dictionary) -> void:
	if not pet_data.has(REWARD_COUNTS_KEY):
		pet_data[REWARD_COUNTS_KEY] = get_empty_reward_counts()


static func sanitize_pet_run_state(pet_data: Dictionary) -> Dictionary:
	var pet_copy := pet_data.duplicate(true)
	if pet_copy.has(REWARD_COUNTS_KEY):
		pet_copy[REWARD_COUNTS_KEY] = reward_counts_snapshot(pet_copy)
	return pet_copy


static func get_reward_count(reward_counts: Dictionary, key: String) -> int:
	return int(reward_counts.get(key, 0))


static func get_effective_skill_level(
	base_level: int,
	reward_counts: Dictionary,
	bonus_key: String
) -> int:
	return LingpetCatalog.clamp_skill_level(
		base_level + get_reward_count(reward_counts, bonus_key)
	)


# Builds the eight-category Guardian Enhance candidate pool before any roll.
# This is the single applicability source for both offer generation and the
# confirm-time revalidation path. Duration is the sole run-owner exception;
# every other candidate remains a reward_counts-backed per-pet enhancement.
static func build_guardian_enhancement_candidates(
	pet_data: Dictionary,
	duration_increase_count: int,
	has_second_active_skill: bool = true,
	has_second_passive_skill: bool = true
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var counts := reward_counts_snapshot(pet_data)
	var active_slot := _first_applicable_skill_bonus_slot(
		pet_data,
		counts,
		true,
		has_second_active_skill
	)
	if active_slot > 0:
		candidates.append(_make_guardian_candidate(REWARD_TYPE_ACTIVE_SKILL, active_slot))
	var passive_slot := _first_applicable_skill_bonus_slot(
		pet_data,
		counts,
		false,
		has_second_passive_skill
	)
	if passive_slot > 0:
		candidates.append(_make_guardian_candidate(REWARD_TYPE_PASSIVE_SKILL, passive_slot))
	if duration_increase_count < MAX_DURATION_INCREASES:
		candidates.append({
			"type": REWARD_TYPE_DURATION,
			"storage_owner": "lingpet_duration_state",
		})
	for reward_type in [REWARD_TYPE_DEFENSE, REWARD_TYPE_GAUGE, REWARD_TYPE_MOBILITY]:
		var stat_candidate := _make_guardian_candidate(str(reward_type))
		if can_apply_reward_card(
			pet_data,
			stat_candidate,
			has_second_active_skill,
			has_second_passive_skill
		):
			if reward_type == REWARD_TYPE_MOBILITY and _normalize_motion_style(
				str(pet_data.get("reward_motion_style", MOTION_STYLE_PATROL))
			) == MOTION_STYLE_FLIGHT:
				stat_candidate["remapped_stat"] = "appearance_rate"
			candidates.append(stat_candidate)
	for unlock_type in [REWARD_TYPE_ACTIVE_UNLOCK, REWARD_TYPE_PASSIVE_UNLOCK]:
		var unlock_candidate := _make_guardian_candidate(str(unlock_type))
		if can_apply_reward_card(
			pet_data,
			unlock_candidate,
			has_second_active_skill,
			has_second_passive_skill
		):
			candidates.append(unlock_candidate)
	for unlock_type in [REWARD_TYPE_SECOND_ACTIVE_UNLOCK, REWARD_TYPE_SECOND_PASSIVE_UNLOCK]:
		var unlock_candidate := _make_guardian_candidate(str(unlock_type))
		if can_apply_reward_card(
			pet_data,
			unlock_candidate,
			has_second_active_skill,
			has_second_passive_skill
		):
			candidates.append(unlock_candidate)
	return candidates


static func can_apply_guardian_enhancement(
	pet_data: Dictionary,
	candidate: Dictionary,
	duration_increase_count: int,
	has_second_active_skill: bool = true,
	has_second_passive_skill: bool = true
) -> bool:
	if str(candidate.get("type", "")) == REWARD_TYPE_DURATION:
		return duration_increase_count < MAX_DURATION_INCREASES
	return can_apply_reward_card(
		pet_data,
		candidate,
		has_second_active_skill,
		has_second_passive_skill
	)


static func apply_guardian_enhancement_to_pet(
	pet_data: Dictionary,
	candidate: Dictionary,
	has_second_active_skill: bool = true,
	has_second_passive_skill: bool = true
) -> Dictionary:
	if str(candidate.get("type", "")) == REWARD_TYPE_DURATION:
		return {"accepted": false, "blocked_reason": "duration_owner_required"}
	if not can_apply_reward_card(
		pet_data,
		candidate,
		has_second_active_skill,
		has_second_passive_skill
	):
		return {"accepted": false, "blocked_reason": "candidate_no_longer_applicable"}
	var counts := apply_reward_to_pet_counts(pet_data, candidate)
	return {
		"accepted": true,
		"candidate": candidate.duplicate(true),
		"reward_counts": counts.duplicate(true),
		"storage_owner": "lingpet_enhancement_buff_store",
	}


static func resolve_effective_reward_card(
	pet_data: Dictionary,
	card: Dictionary,
	label_by_reward_type: Dictionary,
	has_second_active_skill: bool = true,
	has_second_passive_skill: bool = true
) -> Dictionary:
	var card_type := str(card.get("type", ""))
	if can_apply_reward_card(
		pet_data,
		card,
		has_second_active_skill,
		has_second_passive_skill
	):
		return card.duplicate(true)
	var replacement := select_replacement_reward_card(
		pet_data,
		label_by_reward_type,
		has_second_active_skill,
		has_second_passive_skill
	)
	if replacement.is_empty():
		return {
			"type": REWARD_TYPE_NO_REWARD,
			"label": str(label_by_reward_type.get(REWARD_TYPE_NO_REWARD, "보상 없음")),
			"replaced_type": card_type,
			"no_reward": true,
		}
	var replacement_card := replacement.duplicate(true)
	replacement_card["replaced_type"] = card_type
	return replacement_card


static func can_apply_reward_card(
	pet_data: Dictionary,
	card: Dictionary,
	has_second_active_skill: bool = true,
	has_second_passive_skill: bool = true
) -> bool:
	var counts := reward_counts_snapshot(pet_data)
	var card_type := str(card.get("type", ""))
	var skill_slot := int(card.get("skill_slot", 0))
	match card_type:
		REWARD_TYPE_ACTIVE_UNLOCK:
			return not bool(counts.get("active_unlocked", false))
		REWARD_TYPE_PASSIVE_UNLOCK:
			return not bool(counts.get("passive_unlocked", false))
		REWARD_TYPE_SECOND_ACTIVE_UNLOCK:
			return not bool(counts.get("second_active_unlocked", false)) and has_second_active_skill
		REWARD_TYPE_SECOND_PASSIVE_UNLOCK:
			return not bool(counts.get("second_passive_unlocked", false)) and has_second_passive_skill
		REWARD_TYPE_ACTIVE_SKILL:
			return _can_apply_skill_bonus(pet_data, counts, true, skill_slot)
		REWARD_TYPE_PASSIVE_SKILL:
			return _can_apply_skill_bonus(pet_data, counts, false, skill_slot)
		REWARD_TYPE_MOBILITY:
			return int(counts.get("mobility_stacks", 0)) < MAX_MOBILITY_STACKS
		REWARD_TYPE_DEFENSE:
			return (
				_normalize_motion_style(str(pet_data.get("reward_motion_style", MOTION_STYLE_PATROL)))
				== MOTION_STYLE_PATROL
				and int(counts.get("defense_stacks", 0)) < MAX_DEFENSE_STACKS
			)
		REWARD_TYPE_GAUGE:
			return int(counts.get("gauge_stacks", 0)) < MAX_GAUGE_STACKS
		REWARD_TYPE_NO_REWARD:
			return true
	return true


static func select_replacement_reward_card(
	pet_data: Dictionary,
	label_by_reward_type: Dictionary,
	has_second_active_skill: bool = true,
	has_second_passive_skill: bool = true
) -> Dictionary:
	var motion_style := _normalize_motion_style(
		str(pet_data.get("reward_motion_style", MOTION_STYLE_PATROL))
	)
	var candidates: Array[Dictionary] = []
	if motion_style == MOTION_STYLE_PATROL:
		candidates.append(_make_reward_card(REWARD_TYPE_MOBILITY, label_by_reward_type))
		candidates.append(_make_reward_card(REWARD_TYPE_GAUGE, label_by_reward_type))
		candidates.append(_make_reward_card(REWARD_TYPE_DEFENSE, label_by_reward_type))
	else:
		candidates.append(_make_reward_card(REWARD_TYPE_GAUGE, label_by_reward_type))
		candidates.append(_make_reward_card(REWARD_TYPE_MOBILITY, label_by_reward_type))
	candidates.append(_make_reward_card(REWARD_TYPE_ACTIVE_SKILL, label_by_reward_type, 1))
	candidates.append(_make_reward_card(REWARD_TYPE_PASSIVE_SKILL, label_by_reward_type, 1))
	candidates.append(_make_reward_card(REWARD_TYPE_ACTIVE_SKILL, label_by_reward_type, 2))
	candidates.append(_make_reward_card(REWARD_TYPE_PASSIVE_SKILL, label_by_reward_type, 2))
	for candidate in candidates:
		if can_apply_reward_card(
			pet_data,
			candidate,
			has_second_active_skill,
			has_second_passive_skill
		):
			return candidate
	return {}


static func apply_reward_to_pet_counts(pet_data: Dictionary, reward: Dictionary) -> Dictionary:
	var counts := reward_counts_snapshot(pet_data)
	apply_reward_type_to_counts(
		counts,
		str(reward.get("type", "")),
		int(reward.get("skill_slot", 0))
	)
	# The live apply path is applicability-gated, so these clamps preserve shipped
	# behavior while making the store boundary safe against duplicate application.
	counts["mobility_stacks"] = mini(MAX_MOBILITY_STACKS, int(counts.get("mobility_stacks", 0)))
	counts["defense_stacks"] = mini(MAX_DEFENSE_STACKS, int(counts.get("defense_stacks", 0)))
	counts["gauge_stacks"] = mini(MAX_GAUGE_STACKS, int(counts.get("gauge_stacks", 0)))
	counts["support_stacks"] = (
		int(counts.get("defense_stacks", 0))
		+ int(counts.get("gauge_stacks", 0))
	)
	if reward.has("title"):
		counts["title_unlocked"] = true
	counts["signature"] = build_reward_signature(counts)
	pet_data[REWARD_COUNTS_KEY] = counts
	return counts


static func apply_reward_type_to_counts(
	counts: Dictionary,
	reward_type: String,
	skill_slot: int = 0
) -> void:
	match reward_type:
		REWARD_TYPE_ACTIVE_UNLOCK:
			counts["active_unlocked"] = true
		REWARD_TYPE_PASSIVE_UNLOCK:
			counts["passive_unlocked"] = true
		REWARD_TYPE_SECOND_ACTIVE_UNLOCK:
			counts["second_active_unlocked"] = true
		REWARD_TYPE_SECOND_PASSIVE_UNLOCK:
			counts["second_passive_unlocked"] = true
		REWARD_TYPE_ACTIVE_SKILL:
			if skill_slot == 2:
				counts["second_active_skill_bonus"] = int(counts.get("second_active_skill_bonus", 0)) + 1
			else:
				counts["active_skill_bonus"] = int(counts.get("active_skill_bonus", 0)) + 1
		REWARD_TYPE_PASSIVE_SKILL:
			if skill_slot == 2:
				counts["second_passive_skill_bonus"] = int(counts.get("second_passive_skill_bonus", 0)) + 1
			else:
				counts["passive_skill_bonus"] = int(counts.get("passive_skill_bonus", 0)) + 1
		REWARD_TYPE_MOBILITY:
			counts["mobility_stacks"] = int(counts.get("mobility_stacks", 0)) + 1
		REWARD_TYPE_DEFENSE:
			counts["defense_stacks"] = int(counts.get("defense_stacks", 0)) + 1
		REWARD_TYPE_GAUGE:
			counts["gauge_stacks"] = int(counts.get("gauge_stacks", 0)) + 1
	counts["support_stacks"] = (
		int(counts.get("defense_stacks", 0))
		+ int(counts.get("gauge_stacks", 0))
	)


static func empty_reward_signature() -> String:
	return "0|0|0|0|0|0|0|0|0|0|0|0"


static func build_reward_signature(counts: Dictionary) -> String:
	return "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [
		1 if bool(counts.get("active_unlocked", false)) else 0,
		1 if bool(counts.get("passive_unlocked", false)) else 0,
		1 if bool(counts.get("second_active_unlocked", false)) else 0,
		1 if bool(counts.get("second_passive_unlocked", false)) else 0,
		int(counts.get("active_skill_bonus", 0)),
		int(counts.get("passive_skill_bonus", 0)),
		int(counts.get("second_active_skill_bonus", 0)),
		int(counts.get("second_passive_skill_bonus", 0)),
		int(counts.get("mobility_stacks", 0)),
		int(counts.get("defense_stacks", 0)),
		int(counts.get("gauge_stacks", 0)),
		1 if bool(counts.get("title_unlocked", false)) else 0,
	]


static func _can_apply_skill_bonus(
	pet_data: Dictionary,
	counts: Dictionary,
	active: bool,
	skill_slot: int
) -> bool:
	var normalized_slot := 1 if skill_slot <= 1 else 2
	if active:
		if normalized_slot == 2:
			return (
				bool(counts.get("second_active_unlocked", false))
				and int(counts.get("second_active_skill_bonus", 0)) < SKILL_LEVEL_MAX - 1
			)
		return (
			bool(counts.get("active_unlocked", false))
			and int(counts.get("active_skill_bonus", 0)) < _available_active_skill_bonus_slots(pet_data)
		)
	if normalized_slot == 2:
		return (
			bool(counts.get("second_passive_unlocked", false))
			and int(counts.get("second_passive_skill_bonus", 0)) < SKILL_LEVEL_MAX - 1
		)
	return (
		bool(counts.get("passive_unlocked", false))
		and int(counts.get("passive_skill_bonus", 0)) < _available_passive_skill_bonus_slots(pet_data)
	)


static func _first_applicable_skill_bonus_slot(
	pet_data: Dictionary,
	counts: Dictionary,
	active: bool,
	has_second_skill: bool
) -> int:
	if _can_apply_skill_bonus(pet_data, counts, active, 1):
		return 1
	if has_second_skill and _can_apply_skill_bonus(pet_data, counts, active, 2):
		return 2
	return 0


static func _make_guardian_candidate(reward_type: String, skill_slot: int = 0) -> Dictionary:
	var candidate := {
		"type": reward_type,
		"storage_owner": "lingpet_enhancement_buff_store",
	}
	if skill_slot > 0:
		candidate["skill_slot"] = skill_slot
	return candidate


static func _available_active_skill_bonus_slots(pet_data: Dictionary) -> int:
	return maxi(0, SKILL_LEVEL_MAX - int(pet_data.get("active_skill_base_level", 1)))


static func _available_passive_skill_bonus_slots(pet_data: Dictionary) -> int:
	return maxi(0, SKILL_LEVEL_MAX - int(pet_data.get("passive_skill_base_level", 1)))


static func _make_reward_card(
	reward_type: String,
	label_by_reward_type: Dictionary,
	skill_slot: int = 0
) -> Dictionary:
	var card := {
		"type": reward_type,
		"label": str(label_by_reward_type.get(reward_type, "보상")),
	}
	if skill_slot > 0:
		card["skill_slot"] = skill_slot
		if reward_type == REWARD_TYPE_ACTIVE_SKILL and skill_slot == 2:
			card["label"] = "2번째 액티브 스킬 +1"
		elif reward_type == REWARD_TYPE_PASSIVE_SKILL and skill_slot == 2:
			card["label"] = "2번째 패시브 스킬 +1"
	return card


static func _normalize_motion_style(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized == MOTION_STYLE_PATROL:
		return MOTION_STYLE_PATROL
	return MOTION_STYLE_FLIGHT
