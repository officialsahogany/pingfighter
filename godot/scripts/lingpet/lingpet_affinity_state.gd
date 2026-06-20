extends RefCounted

const LingpetAffinityStore := preload("res://scripts/lingpet/lingpet_affinity_store.gd")

const SOURCE_ROUND_COMMIT := "round_commit"
const SOURCE_BALL_HIT := "ball_hit"
const SOURCE_CLICK := "click"
const SOURCE_HATCH := "hatch"
const SOURCE_VICTORY := "victory"
const SOURCE_FEED := "feed"

const REWARD_TYPE_ACTIVE_UNLOCK := "active_unlock"
const REWARD_TYPE_PASSIVE_UNLOCK := "passive_unlock"
const REWARD_TYPE_SECOND_ACTIVE_UNLOCK := "second_active_unlock"
const REWARD_TYPE_SECOND_PASSIVE_UNLOCK := "second_passive_unlock"
const REWARD_TYPE_ACTIVE_SKILL := "active_skill"
const REWARD_TYPE_PASSIVE_SKILL := "passive_skill"
const REWARD_TYPE_MOBILITY := "mobility"
const REWARD_TYPE_DEFENSE := "defense"
const REWARD_TYPE_GAUGE := "gauge"
const REWARD_TYPE_TITLE := "title"
const REWARD_TYPE_NO_REWARD := "no_reward"

const MOTION_STYLE_PATROL := "patrol"
const MOTION_STYLE_FLIGHT := "flight"

const MAX_LEVEL := 30
# V3 keeps the residue headstart ceiling at +4 until the stage-count/income
# tuning pass. The store may remember a higher best level, but a new run still
# starts conservatively.
const HEADSTART_MAX_LEVEL := 4
const MAX_ENHANCEMENT_CHIPS := 5
const ENHANCEMENT_CHIP_BONUS := 0.20
const MAX_FEED_USES_PER_RUN := 3
const LINGPET_FEED_MAX_LEVEL := 15
const SKILL_LEVEL_MAX := 5
const RING_CORE_CAP_UNCHANGED := -1
const MAX_MOBILITY_STACKS := 6
const MAX_DEFENSE_STACKS := 2
const MAX_GAUGE_STACKS := 4
const BOND_TITLE_DISPLAY_CAP := 25

const BOND_TITLE_AWKWARD := "어색함"
const BOND_TITLE_CLOSER := "가까워짐"
const BOND_TITLE_FRIENDLY := "친함"
const BOND_TITLE_BEST_FRIEND := "단짝"
const BOND_TITLE_SOULMATE := "영혼의 단짝"

const REQUIREMENT_BY_CURRENT_LEVEL := [
	50.0,
	75.0,
	100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0,
	125.0, 125.0, 125.0, 125.0, 125.0,
	150.0, 150.0, 150.0, 150.0, 150.0,
	175.0, 175.0, 175.0, 175.0, 175.0,
	200.0, 200.0, 200.0, 200.0, 200.0,
]

const REWARD_DECK_SEED_MOD := 2147483647
const DEFAULT_REWARD_DECK_SEED := 991

const LABEL_BY_REWARD_TYPE := {
	REWARD_TYPE_ACTIVE_UNLOCK: "액티브 스킬 해금",
	REWARD_TYPE_PASSIVE_UNLOCK: "패시브 스킬 해금",
	REWARD_TYPE_SECOND_ACTIVE_UNLOCK: "2번째 액티브 해금",
	REWARD_TYPE_SECOND_PASSIVE_UNLOCK: "2번째 패시브 해금",
	REWARD_TYPE_ACTIVE_SKILL: "액티브 스킬 +1",
	REWARD_TYPE_PASSIVE_SKILL: "패시브 스킬 +1",
	REWARD_TYPE_MOBILITY: "기동 강화",
	REWARD_TYPE_DEFENSE: "방어 강화",
	REWARD_TYPE_GAUGE: "게이지 강화",
	REWARD_TYPE_TITLE: "하트 공명",
	REWARD_TYPE_NO_REWARD: "보상 없음",
}

const CANONICAL_REWARD_TRACK := {
	1: {"type": REWARD_TYPE_ACTIVE_UNLOCK, "label": "액티브 스킬 해금"},
	2: {"type": REWARD_TYPE_PASSIVE_UNLOCK, "label": "패시브 스킬 해금"},
	3: {"type": REWARD_TYPE_DEFENSE, "label": "방어 강화"},
	4: {"type": REWARD_TYPE_MOBILITY, "label": "기동 강화"},
	5: {"type": REWARD_TYPE_ACTIVE_SKILL, "label": "액티브 스킬 +1", "skill_slot": 1},
	6: {"type": REWARD_TYPE_GAUGE, "label": "게이지 강화"},
	7: {"type": REWARD_TYPE_PASSIVE_SKILL, "label": "패시브 스킬 +1", "skill_slot": 1},
	8: {"type": REWARD_TYPE_DEFENSE, "label": "방어 강화"},
	9: {"type": REWARD_TYPE_ACTIVE_SKILL, "label": "액티브 스킬 +1", "skill_slot": 1},
	10: {"type": REWARD_TYPE_MOBILITY, "label": "기동 강화"},
	11: {"type": REWARD_TYPE_PASSIVE_SKILL, "label": "패시브 스킬 +1", "skill_slot": 1},
	12: {"type": REWARD_TYPE_GAUGE, "label": "게이지 강화"},
	13: {"type": REWARD_TYPE_DEFENSE, "label": "방어 강화"},
	14: {"type": REWARD_TYPE_ACTIVE_SKILL, "label": "액티브 스킬 +1", "skill_slot": 1},
	15: {"type": REWARD_TYPE_MOBILITY, "label": "기동 강화"},
	16: {"type": REWARD_TYPE_PASSIVE_SKILL, "label": "패시브 스킬 +1", "skill_slot": 1},
	17: {"type": REWARD_TYPE_GAUGE, "label": "게이지 강화"},
	18: {"type": REWARD_TYPE_DEFENSE, "label": "방어 강화"},
	19: {"type": REWARD_TYPE_ACTIVE_SKILL, "label": "액티브 스킬 +1", "skill_slot": 1},
	20: {"type": REWARD_TYPE_MOBILITY, "label": "기동 강화"},
	21: {"type": REWARD_TYPE_PASSIVE_SKILL, "label": "패시브 스킬 +1", "skill_slot": 1},
	22: {"type": REWARD_TYPE_SECOND_ACTIVE_UNLOCK, "label": "2번째 액티브 해금"},
	23: {"type": REWARD_TYPE_GAUGE, "label": "게이지 강화"},
	24: {"type": REWARD_TYPE_MOBILITY, "label": "기동 강화"},
	25: {"type": REWARD_TYPE_SECOND_PASSIVE_UNLOCK, "label": "2번째 패시브 해금"},
	26: {"type": REWARD_TYPE_ACTIVE_SKILL, "label": "2번째 액티브 스킬 +1", "skill_slot": 2},
	27: {"type": REWARD_TYPE_PASSIVE_SKILL, "label": "2번째 패시브 스킬 +1", "skill_slot": 2},
	28: {"type": REWARD_TYPE_GAUGE, "label": "게이지 강화"},
	29: {"type": REWARD_TYPE_ACTIVE_SKILL, "label": "2번째 액티브 스킬 +1", "skill_slot": 2},
	30: {"type": REWARD_TYPE_PASSIVE_SKILL, "label": "2번째 패시브 스킬 +1", "skill_slot": 2, "title": "하트 공명"},
}

const GAIN_TABLE := {
	SOURCE_ROUND_COMMIT: {"points": 5.0},
	SOURCE_BALL_HIT: {
		"points": 8.0,
		"reduced_points": 2.0,
		"full_round_cap": 4,
		"defense_bonus_points": 5.0,
		"defense_bonus_round_cap": 2,
	},
	SOURCE_CLICK: {
		"points": 5.0,
		"round_cap": 2,
		"battle_cap": 5,
	},
	SOURCE_HATCH: {"points": 25.0},
	SOURCE_VICTORY: {"points": 20.0},
	SOURCE_FEED: {"points": 35.0},
}

const ROUND_CAP_BALL_HIT_COUNT := "ball_hit_count"
const ROUND_CAP_DEFENSE_BONUS_COUNT := "defense_bonus_count"
const ROUND_CAP_CLICK_COUNT := "click_count"
const BATTLE_CAP_CLICK_COUNT := "click_count"
const BATTLE_CAP_ROUND_COMMIT_TOTAL := "round_commit_total"
const BATTLE_CAP_ROUND_COMMIT_BY_PET := "round_commit_by_pet"
const BATTLE_CAP_VICTORY_PAID := "victory_paid"
const BATTLE_CAP_BOND_LEVEL_UPS_BY_PET := "bond_level_ups_by_pet"

var _pets: Dictionary = {}
var _round_caps: Dictionary = {}
var _battle_caps: Dictionary = {}
var _enhancement_chips := 0
var _feed_uses_this_run := 0
var _run_ring_core_tier := 0
var _dirty := false


# Run-end/test reset only. Do not call this for pet swaps or hatch flows because it clears
# hatch_bonus_granted and deliberately allows a fresh run to receive hatch bonuses again.
func reset_all() -> void:
	_pets.clear()
	_enhancement_chips = 0
	_feed_uses_this_run = 0
	_run_ring_core_tier = 0
	reset_battle_caps()
	_dirty = false


func reset_for_new_run() -> void:
	reset_all()


func reset_for_new_battle() -> void:
	reset_battle_caps()


func reset_round_caps() -> void:
	_round_caps.clear()


func reset_battle_caps() -> void:
	_round_caps.clear()
	_battle_caps.clear()


func is_dirty() -> bool:
	return _dirty


func clear_dirty() -> void:
	_dirty = false


func set_enhancement_chips(value: int) -> int:
	_enhancement_chips = clampi(value, 0, MAX_ENHANCEMENT_CHIPS)
	return _enhancement_chips


func add_enhancement_chip(amount: int = 1) -> int:
	return set_enhancement_chips(_enhancement_chips + maxi(0, amount))


func get_enhancement_chips() -> int:
	return clampi(_enhancement_chips, 0, MAX_ENHANCEMENT_CHIPS)


func get_enhancement_chip_multiplier() -> float:
	return 1.0 + float(get_enhancement_chips()) * ENHANCEMENT_CHIP_BONUS


func get_feed_uses_this_run() -> int:
	return clampi(_feed_uses_this_run, 0, MAX_FEED_USES_PER_RUN)


func get_run_ring_core_tier() -> int:
	return clampi(_run_ring_core_tier, 0, LingpetAffinityStore.MAX_RING_CORE_TIER)


func set_run_ring_core_tier(tier: int) -> void:
	_run_ring_core_tier = clampi(tier, 0, LingpetAffinityStore.MAX_RING_CORE_TIER)


func upgrade_run_ring_core_tier(target_tier: int = 0) -> bool:
	var current_tier := get_run_ring_core_tier()
	var next_tier := target_tier if target_tier > 0 else current_tier + 1
	next_tier = clampi(next_tier, 1, LingpetAffinityStore.MAX_RING_CORE_TIER)
	if next_tier <= current_tier:
		return false
	_run_ring_core_tier = next_tier
	return true


func get_run_ring_core_cap() -> int:
	return LingpetAffinityStore.get_ring_core_cap_for_tier(get_run_ring_core_tier())


func configure_reward_context(
	pet_id: String,
	motion_style: String = MOTION_STYLE_PATROL,
	active_skill_base_level: int = 1,
	passive_skill_base_level: int = 1,
	reward_seed: int = 0,
	force_rebuild: bool = false,
	ring_core_cap: int = RING_CORE_CAP_UNCHANGED
) -> void:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return
	var pet_data := _get_or_create_pet_data(normalized_pet_id)
	_ensure_unlock_state(normalized_pet_id, pet_data)
	var next_motion_style := _normalize_motion_style(motion_style)
	var next_active_base_level := clampi(active_skill_base_level, 1, SKILL_LEVEL_MAX)
	var next_passive_base_level := clampi(passive_skill_base_level, 1, SKILL_LEVEL_MAX)
	var current_ring_core_cap := clampi(int(pet_data.get("ring_core_cap", MAX_LEVEL)), 0, MAX_LEVEL)
	var next_ring_core_cap := current_ring_core_cap if ring_core_cap < 0 else clampi(ring_core_cap, 0, MAX_LEVEL)
	var context_changed := (
		str(pet_data.get("reward_motion_style", MOTION_STYLE_PATROL)) != next_motion_style
		or int(pet_data.get("active_skill_base_level", 1)) != next_active_base_level
		or int(pet_data.get("passive_skill_base_level", 1)) != next_passive_base_level
		or int(pet_data.get("ring_core_cap", MAX_LEVEL)) != next_ring_core_cap
	)
	var history: Array = pet_data.get("reward_history", []) as Array
	pet_data["reward_motion_style"] = next_motion_style
	pet_data["active_skill_base_level"] = next_active_base_level
	pet_data["passive_skill_base_level"] = next_passive_base_level
	pet_data["ring_core_cap"] = next_ring_core_cap
	if reward_seed > 0:
		var normalized_seed := maxi(1, reward_seed % REWARD_DECK_SEED_MOD)
		pet_data["reward_seed"] = normalized_seed
		pet_data["unlock_choice_seed_base"] = normalized_seed
	if force_rebuild or not _has_reward_deck(pet_data) or (context_changed and history.is_empty()):
		_build_reward_deck(normalized_pet_id, pet_data)
	_pets[normalized_pet_id] = pet_data


func set_unlock_choice_candidates(pet_id: String, reward_type: String, candidates: Array) -> void:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return
	var choice_key := _unlock_choice_key(reward_type)
	if choice_key == "":
		return
	var pet_data := _get_or_create_pet_data(normalized_pet_id)
	_ensure_unlock_state(normalized_pet_id, pet_data)
	var normalized_candidates := _normalize_choice_candidates(candidates)
	if normalized_candidates.size() < 2:
		return
	var pool: Dictionary = pet_data.get("unlock_candidate_pool", {}) as Dictionary
	pool[choice_key] = normalized_candidates
	pet_data["unlock_candidate_pool"] = pool
	var pending: Dictionary = pet_data.get("pending_unlock_choices", {}) as Dictionary
	if pending.has(choice_key):
		var choice: Dictionary = pending.get(choice_key, {}) as Dictionary
		choice["candidates"] = normalized_candidates.duplicate(true)
		pending[choice_key] = choice
		pet_data["pending_unlock_choices"] = pending
		var resolve_result := _resolve_random_unlock_choice(pet_data, choice)
		if bool(resolve_result.get("accepted", false)):
			_dirty = true
	_pets[normalized_pet_id] = pet_data


func get_pending_unlock_choices(pet_id: String) -> Dictionary:
	var pet_data := _get_existing_pet_data(_normalize_pet_id(pet_id))
	if pet_data.is_empty():
		return {}
	var pending: Dictionary = pet_data.get("pending_unlock_choices", {}) as Dictionary
	return pending.duplicate(true)


func get_resolved_unlock_choices(pet_id: String) -> Dictionary:
	var pet_data := _get_existing_pet_data(_normalize_pet_id(pet_id))
	if pet_data.is_empty():
		return {}
	var choices: Dictionary = pet_data.get("resolved_unlock_choices", {}) as Dictionary
	return choices.duplicate(true)


func choose_skill_unlock(pet_id: String, reward_type: String, selected_id: String) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return {"accepted": false, "blocked_reason": "missing_pet_id"}
	var choice_key := _unlock_choice_key(reward_type)
	if choice_key == "":
		return {"accepted": false, "blocked_reason": "not_unlock_type"}
	var pet_data := _get_existing_pet_data(normalized_pet_id)
	if pet_data.is_empty():
		return {"accepted": false, "blocked_reason": "missing_pet"}
	_ensure_unlock_state(normalized_pet_id, pet_data)
	var pending: Dictionary = pet_data.get("pending_unlock_choices", {}) as Dictionary
	if not pending.has(choice_key):
		return {"accepted": false, "blocked_reason": "missing_choice"}
	var choice: Dictionary = pending.get(choice_key, {}) as Dictionary
	var candidates: Array = choice.get("candidates", []) as Array
	var normalized_selected := selected_id.strip_edges()
	if normalized_selected == "" or not candidates.has(normalized_selected):
		return {"accepted": false, "blocked_reason": "invalid_selection", "candidates": candidates.duplicate(true)}
	var rejected: Array[String] = []
	for raw_candidate in candidates:
		var candidate := str(raw_candidate)
		if candidate != normalized_selected:
			rejected.append(candidate)
	var resolved := {
		"type": reward_type,
		"choice_key": choice_key,
		"selected": normalized_selected,
		"rejected": rejected,
		"candidates": candidates.duplicate(true),
	}
	var resolved_choices: Dictionary = pet_data.get("resolved_unlock_choices", {}) as Dictionary
	resolved_choices[choice_key] = resolved
	pending.erase(choice_key)
	pet_data["pending_unlock_choices"] = pending
	pet_data["resolved_unlock_choices"] = resolved_choices
	_pets[normalized_pet_id] = pet_data
	_dirty = true
	return {"accepted": true, "choice": resolved.duplicate(true)}


func apply_resolved_unlock_choice(pet_id: String, reward_type: String, selected_id: String, candidates: Array) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return {"accepted": false, "blocked_reason": "missing_pet_id"}
	var choice_key := _unlock_choice_key(reward_type)
	if choice_key == "":
		return {"accepted": false, "blocked_reason": "not_unlock_type"}
	var pet_data := _get_existing_pet_data(normalized_pet_id)
	if pet_data.is_empty():
		return {"accepted": false, "blocked_reason": "missing_pet"}
	_ensure_unlock_state(normalized_pet_id, pet_data)
	var normalized_candidates := _normalize_choice_candidates(candidates)
	var normalized_selected := selected_id.strip_edges()
	if normalized_selected == "" or not normalized_candidates.has(normalized_selected):
		return {"accepted": false, "blocked_reason": "invalid_selection", "candidates": normalized_candidates.duplicate(true)}
	var rejected: Array[String] = []
	for raw_candidate in normalized_candidates:
		var candidate := str(raw_candidate)
		if candidate != normalized_selected:
			rejected.append(candidate)
	var resolved := {
		"type": reward_type,
		"choice_key": choice_key,
		"selected": normalized_selected,
		"rejected": rejected,
		"candidates": normalized_candidates.duplicate(true),
	}
	var pending: Dictionary = pet_data.get("pending_unlock_choices", {}) as Dictionary
	pending.erase(choice_key)
	var resolved_choices: Dictionary = pet_data.get("resolved_unlock_choices", {}) as Dictionary
	resolved_choices[choice_key] = resolved
	pet_data["pending_unlock_choices"] = pending
	pet_data["resolved_unlock_choices"] = resolved_choices
	_pets[normalized_pet_id] = pet_data
	_dirty = true
	return {"accepted": true, "choice": resolved.duplicate(true)}


func resolve_single_unlock(pet_id: String, reward_type: String, only_id: String) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return {"accepted": false, "blocked_reason": "missing_pet_id"}
	var choice_key := _unlock_choice_key(reward_type)
	if choice_key == "":
		return {"accepted": false, "blocked_reason": "not_unlock_type"}
	var normalized_only_id := only_id.strip_edges()
	if normalized_only_id == "":
		return {"accepted": false, "blocked_reason": "missing_selection"}
	var pet_data := _get_or_create_pet_data(normalized_pet_id)
	_ensure_unlock_state(normalized_pet_id, pet_data)
	var counts := _reward_counts_snapshot(pet_data)
	_apply_reward_type_to_counts(counts, reward_type)
	counts["signature"] = _build_reward_signature_from_counts(counts)
	pet_data["reward_counts"] = counts
	var pending: Dictionary = pet_data.get("pending_unlock_choices", {}) as Dictionary
	pending.erase(choice_key)
	var resolved := {
		"type": reward_type,
		"choice_key": choice_key,
		"selected": normalized_only_id,
		"rejected": [],
		"candidates": [normalized_only_id],
		"single": true,
	}
	var resolved_choices: Dictionary = pet_data.get("resolved_unlock_choices", {}) as Dictionary
	resolved_choices[choice_key] = resolved
	pet_data["pending_unlock_choices"] = pending
	pet_data["resolved_unlock_choices"] = resolved_choices
	_pets[normalized_pet_id] = pet_data
	_dirty = true
	return {"accepted": true, "choice": resolved.duplicate(true)}


func resolve_random_unlock(pet_id: String, reward_type: String) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return {"accepted": false, "blocked_reason": "missing_pet_id"}
	var choice_key := _unlock_choice_key(reward_type)
	if choice_key == "":
		return {"accepted": false, "blocked_reason": "not_unlock_type"}
	var pet_data := _get_existing_pet_data(normalized_pet_id)
	if pet_data.is_empty():
		return {"accepted": false, "blocked_reason": "missing_pet"}
	_ensure_unlock_state(normalized_pet_id, pet_data)
	var result := _resolve_random_unlock_choice(pet_data, {"type": reward_type, "choice_key": choice_key})
	_pets[normalized_pet_id] = pet_data
	if bool(result.get("accepted", false)):
		_dirty = true
	return result


func set_reward_seed_for_tests(pet_id: String, reward_seed: int) -> void:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return
	var pet_data := _get_or_create_pet_data(normalized_pet_id)
	_ensure_unlock_state(normalized_pet_id, pet_data)
	pet_data["reward_seed"] = maxi(1, reward_seed % REWARD_DECK_SEED_MOD)
	pet_data["unlock_choice_seed_base"] = int(pet_data.get("reward_seed", 0))
	_build_reward_deck(normalized_pet_id, pet_data)
	_award_missing_rewards_up_to_level(pet_data, int(pet_data.get("affinity_level", 0)))
	_pets[normalized_pet_id] = pet_data


func add_points(pet_id: String, source: String, tags: Dictionary = {}) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return _build_blocked_result("", source, "missing_pet_id")
	if not GAIN_TABLE.has(source):
		return _build_blocked_result(normalized_pet_id, source, "unknown_source")
	var pet_data := _get_or_create_pet_data(normalized_pet_id)
	var level_before := int(pet_data.get("affinity_level", 0))
	var points_before := float(pet_data.get("affinity_points", 0.0))
	# Max-level sources do not consume point budgets. Round commits still update
	# attendance because victory eligibility depends on the full battle denominator.
	if level_before >= MAX_LEVEL:
		if source == SOURCE_ROUND_COMMIT:
			_record_round_commit(normalized_pet_id)
		return _build_result(normalized_pet_id, source, level_before, points_before, 0.0, 0.0, [], "max_level")

	var gain_result := _resolve_gain(normalized_pet_id, source, tags, pet_data)
	var granted_points := float(gain_result.get("points", 0.0))
	var bonus_points := float(gain_result.get("bonus_points", 0.0))
	var blocked_reason := str(gain_result.get("blocked_reason", ""))
	var enhancement_multiplier := 1.0 if source == SOURCE_FEED else get_enhancement_chip_multiplier()
	granted_points *= enhancement_multiplier
	bonus_points *= enhancement_multiplier
	if granted_points <= 0.0:
		_pets[normalized_pet_id] = pet_data
		return _build_result(normalized_pet_id, source, level_before, points_before, 0.0, bonus_points, [], blocked_reason)

	pet_data["affinity_points"] = points_before + granted_points
	var level_rewards: Array[Dictionary] = _apply_level_ups(normalized_pet_id, pet_data)
	if level_rewards.size() > 0:
		_record_bond_level_ups(normalized_pet_id, level_rewards.size())
	if source == SOURCE_FEED:
		_feed_uses_this_run = mini(_feed_uses_this_run + 1, MAX_FEED_USES_PER_RUN)
	_update_best_level(pet_data)
	_pets[normalized_pet_id] = pet_data
	_dirty = true
	return _build_result(
		normalized_pet_id,
		source,
		level_before,
		points_before,
		granted_points,
		bonus_points,
		level_rewards,
		""
	)


func seed_best_level(pet_id: String, best_level: int, mark_dirty: bool = false) -> void:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return
	var pet_data := _get_or_create_pet_data(normalized_pet_id)
	var clamped_best := clampi(best_level, 0, MAX_LEVEL)
	var previous_best := int(pet_data.get("best_level", 0))
	pet_data["best_level"] = max(previous_best, clamped_best)
	_pets[normalized_pet_id] = pet_data
	if mark_dirty and clamped_best > previous_best:
		_dirty = true


func apply_headstart_from_best(pet_id: String, best_level: int) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return {}
	var pet_data := _get_or_create_pet_data(normalized_pet_id)
	_ensure_unlock_state(normalized_pet_id, pet_data)
	var clamped_best := clampi(best_level, 0, MAX_LEVEL)
	var ring_core_cap := clampi(int(pet_data.get("ring_core_cap", MAX_LEVEL)), 0, MAX_LEVEL)
	var headstart_level := mini(clampi(int(floor(float(clamped_best) / 3.0)), 0, HEADSTART_MAX_LEVEL), ring_core_cap)
	var level_before := int(pet_data.get("affinity_level", 0))
	var level_after: int = max(level_before, headstart_level)
	pet_data["affinity_level"] = level_after
	pet_data["best_level"] = max(int(pet_data.get("best_level", 0)), clamped_best)
	if level_after > level_before:
		_award_missing_rewards_up_to_level(pet_data, level_after)
	_pets[normalized_pet_id] = pet_data
	_dirty = true
	return get_pet_data(normalized_pet_id)


func get_pet_data(pet_id: String) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return {}
	return _get_existing_pet_data(normalized_pet_id).duplicate(true)


func get_level(pet_id: String) -> int:
	var pet_data := _get_existing_pet_data(_normalize_pet_id(pet_id))
	return int(pet_data.get("affinity_level", 0))


func get_points(pet_id: String) -> float:
	var pet_data := _get_existing_pet_data(_normalize_pet_id(pet_id))
	return float(pet_data.get("affinity_points", 0.0))


func get_best_level(pet_id: String) -> int:
	var pet_data := _get_existing_pet_data(_normalize_pet_id(pet_id))
	return int(pet_data.get("best_level", 0))


func get_next_requirement(pet_id: String) -> float:
	return get_requirement_for_level(get_level(pet_id))


func get_cumulative_rewards(pet_id: String) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return get_empty_reward_counts()
	var pet_data := _get_existing_pet_data(normalized_pet_id)
	if pet_data.is_empty():
		return get_empty_reward_counts()
	return _reward_counts_snapshot(pet_data)


func get_reward_signature(pet_id: String) -> String:
	return str(get_cumulative_rewards(pet_id).get("signature", _empty_reward_signature()))


func get_next_reward(pet_id: String) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return {}
	var pet_data := _get_existing_pet_data(normalized_pet_id)
	if pet_data.is_empty():
		return get_reward_for_level(1)
	var level := int(pet_data.get("affinity_level", 0))
	if level >= MAX_LEVEL:
		return {"type": REWARD_TYPE_TITLE, "label": "하트 공명", "title": "하트 공명", "level": MAX_LEVEL}
	_ensure_reward_state(normalized_pet_id, pet_data)
	var deck: Array = pet_data.get("reward_deck", []) as Array
	if level >= 0 and level < deck.size():
		var next_reward: Dictionary = _resolve_effective_reward_card(pet_data, (deck[level] as Dictionary).duplicate(true))
		next_reward["level"] = level + 1
		return next_reward
	return get_reward_for_level(level + 1)


func get_reward_deck(pet_id: String) -> Array[Dictionary]:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return []
	var pet_data := _get_existing_pet_data(normalized_pet_id)
	if pet_data.is_empty():
		return []
	_ensure_reward_state(normalized_pet_id, pet_data)
	_pets[normalized_pet_id] = pet_data
	var result: Array[Dictionary] = []
	var deck: Array = pet_data.get("reward_deck", []) as Array
	for raw_card in deck:
		if raw_card is Dictionary:
			result.append((raw_card as Dictionary).duplicate(true))
	return result


func get_best_levels() -> Dictionary:
	var best_levels := {}
	for raw_pet_id in _pets.keys():
		var pet_id := str(raw_pet_id)
		var pet_data := _get_existing_pet_data(pet_id)
		var best_level := int(pet_data.get("best_level", 0))
		if best_level > 0:
			best_levels[pet_id] = best_level
	return best_levels


func get_tracked_pet_ids() -> Array[String]:
	var pet_ids: Array[String] = []
	for raw_pet_id in _pets.keys():
		pet_ids.append(str(raw_pet_id))
	pet_ids.sort()
	return pet_ids


func get_pending_bond_level_ups() -> Dictionary:
	return _get_battle_bond_level_ups_by_pet().duplicate(true)


func settle_bond_level_ups_for_victory() -> Dictionary:
	var pending := _get_battle_bond_level_ups_by_pet()
	var settled := {}
	var discarded := {}
	for raw_pet_id in pending.keys():
		var pet_id := str(raw_pet_id)
		var amount := int(pending.get(raw_pet_id, 0))
		if amount <= 0:
			continue
		if _is_victory_participation_eligible(pet_id):
			settled[pet_id] = amount
		else:
			discarded[pet_id] = amount
	_battle_caps.erase(BATTLE_CAP_BOND_LEVEL_UPS_BY_PET)
	return {
		"settled": settled,
		"discarded": discarded,
		"total_settled": _sum_int_values(settled),
		"total_discarded": _sum_int_values(discarded),
	}


func discard_pending_bond_level_ups() -> Dictionary:
	var pending := _get_battle_bond_level_ups_by_pet()
	_battle_caps.erase(BATTLE_CAP_BOND_LEVEL_UPS_BY_PET)
	return {
		"discarded": pending.duplicate(true),
		"total_discarded": _sum_int_values(pending),
	}


static func get_requirement_for_level(current_level: int) -> float:
	if current_level >= 0 and current_level < REQUIREMENT_BY_CURRENT_LEVEL.size():
		return float(REQUIREMENT_BY_CURRENT_LEVEL[current_level])
	return 0.0


static func get_bond_title_for_points(bond_points: int) -> String:
	var display_points := clampi(bond_points, 0, BOND_TITLE_DISPLAY_CAP)
	if display_points >= 21:
		return BOND_TITLE_SOULMATE
	if display_points >= 16:
		return BOND_TITLE_BEST_FRIEND
	if display_points >= 11:
		return BOND_TITLE_FRIENDLY
	if display_points >= 6:
		return BOND_TITLE_CLOSER
	return BOND_TITLE_AWKWARD


static func get_reward_for_level(level: int) -> Dictionary:
	if not CANONICAL_REWARD_TRACK.has(level):
		return {}
	var reward: Dictionary = CANONICAL_REWARD_TRACK.get(level, {})
	var result := reward.duplicate(true)
	result["level"] = level
	return result


# V2 live rewards are per-pet deck/history data. Keep this helper for canonical
# fallback/migration reads; runtime reward application must use get_cumulative_rewards(pet_id).
static func get_cumulative_rewards_for_level(level: int) -> Dictionary:
	var rewards := get_empty_reward_counts()
	var clamped_level := clampi(level, 0, MAX_LEVEL)
	for reward_level in range(1, clamped_level + 1):
		var reward := get_reward_for_level(reward_level)
		_apply_reward_type_to_counts(rewards, str(reward.get("type", "")), int(reward.get("skill_slot", 0)))
		if bool(reward.has("title")):
			rewards["title_unlocked"] = true
	rewards["signature"] = _build_reward_signature_from_counts(rewards)
	return rewards


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
		"signature": _empty_reward_signature(),
	}


func _resolve_gain(pet_id: String, source: String, tags: Dictionary, pet_data: Dictionary) -> Dictionary:
	match source:
		SOURCE_ROUND_COMMIT:
			return _resolve_round_commit_gain(pet_id)
		SOURCE_BALL_HIT:
			return _resolve_ball_hit_gain(tags)
		SOURCE_CLICK:
			return _resolve_click_gain()
		SOURCE_HATCH:
			return _resolve_hatch_gain(pet_id, pet_data)
		SOURCE_VICTORY:
			return _resolve_victory_gain(pet_id, tags)
		SOURCE_FEED:
			return _resolve_feed_gain(pet_data)
	return {"points": 0.0, "blocked_reason": "unknown_source"}


func _resolve_round_commit_gain(pet_id: String) -> Dictionary:
	_record_round_commit(pet_id)
	return {"points": _get_gain_value(SOURCE_ROUND_COMMIT, "points")}


func _record_round_commit(pet_id: String) -> void:
	var total_rounds := int(_battle_caps.get(BATTLE_CAP_ROUND_COMMIT_TOTAL, 0)) + 1
	var by_pet: Dictionary = _get_battle_round_commit_by_pet()
	by_pet[pet_id] = int(by_pet.get(pet_id, 0)) + 1
	_battle_caps[BATTLE_CAP_ROUND_COMMIT_TOTAL] = total_rounds
	_battle_caps[BATTLE_CAP_ROUND_COMMIT_BY_PET] = by_pet


func _record_bond_level_ups(pet_id: String, levels_gained: int) -> void:
	if levels_gained <= 0:
		return
	var by_pet := _get_battle_bond_level_ups_by_pet()
	by_pet[pet_id] = int(by_pet.get(pet_id, 0)) + levels_gained
	_battle_caps[BATTLE_CAP_BOND_LEVEL_UPS_BY_PET] = by_pet


func _resolve_ball_hit_gain(tags: Dictionary) -> Dictionary:
	var hit_count := int(_round_caps.get(ROUND_CAP_BALL_HIT_COUNT, 0))
	var full_cap := int(_get_gain_value(SOURCE_BALL_HIT, "full_round_cap"))
	var base_points := _get_gain_value(SOURCE_BALL_HIT, "points") if hit_count < full_cap else _get_gain_value(SOURCE_BALL_HIT, "reduced_points")
	_round_caps[ROUND_CAP_BALL_HIT_COUNT] = hit_count + 1
	var bonus_points := 0.0
	if _has_defense_bonus_tag(tags):
		var defense_count := int(_round_caps.get(ROUND_CAP_DEFENSE_BONUS_COUNT, 0))
		var defense_cap := int(_get_gain_value(SOURCE_BALL_HIT, "defense_bonus_round_cap"))
		if defense_count < defense_cap:
			bonus_points = _get_gain_value(SOURCE_BALL_HIT, "defense_bonus_points")
			_round_caps[ROUND_CAP_DEFENSE_BONUS_COUNT] = defense_count + 1
	return {
		"points": base_points + bonus_points,
		"bonus_points": bonus_points,
	}


func _resolve_click_gain() -> Dictionary:
	var round_count := int(_round_caps.get(ROUND_CAP_CLICK_COUNT, 0))
	var battle_count := int(_battle_caps.get(BATTLE_CAP_CLICK_COUNT, 0))
	if round_count >= int(_get_gain_value(SOURCE_CLICK, "round_cap")):
		return {"points": 0.0, "blocked_reason": "round_cap"}
	if battle_count >= int(_get_gain_value(SOURCE_CLICK, "battle_cap")):
		return {"points": 0.0, "blocked_reason": "battle_cap"}
	_round_caps[ROUND_CAP_CLICK_COUNT] = round_count + 1
	_battle_caps[BATTLE_CAP_CLICK_COUNT] = battle_count + 1
	return {"points": _get_gain_value(SOURCE_CLICK, "points")}


func _resolve_victory_gain(pet_id: String, tags: Dictionary) -> Dictionary:
	if bool(_battle_caps.get(BATTLE_CAP_VICTORY_PAID, false)):
		return {"points": 0.0, "blocked_reason": "victory_already_paid"}
	if tags.has("eligible") and not bool(tags.get("eligible", false)):
		return {"points": 0.0, "blocked_reason": "ineligible"}
	if not _is_victory_participation_eligible(pet_id):
		return {"points": 0.0, "blocked_reason": "ineligible"}
	_battle_caps[BATTLE_CAP_VICTORY_PAID] = true
	return {"points": _get_gain_value(SOURCE_VICTORY, "points")}


func _resolve_hatch_gain(_pet_id: String, pet_data: Dictionary) -> Dictionary:
	if bool(pet_data.get("hatch_bonus_granted", false)):
		return {"points": 0.0, "blocked_reason": "hatch_bonus_granted"}
	pet_data["hatch_bonus_granted"] = true
	return {"points": _get_gain_value(SOURCE_HATCH, "points")}


func _resolve_feed_gain(pet_data: Dictionary) -> Dictionary:
	if _feed_uses_this_run >= MAX_FEED_USES_PER_RUN:
		return {"points": 0.0, "blocked_reason": "max_feed_uses"}
	var level := int(pet_data.get("affinity_level", 0))
	var points := float(pet_data.get("affinity_points", 0.0))
	var remaining_to_feed_cap := _points_remaining_until_level(level, points, LINGPET_FEED_MAX_LEVEL)
	if remaining_to_feed_cap <= 0.0:
		return {"points": 0.0, "blocked_reason": "max_feed_level"}
	var feed_points := minf(_get_gain_value(SOURCE_FEED, "points"), remaining_to_feed_cap)
	return {"points": feed_points}


func _apply_level_ups(pet_id: String, pet_data: Dictionary) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var level := int(pet_data.get("affinity_level", 0))
	var points := float(pet_data.get("affinity_points", 0.0))
	_ensure_reward_state(pet_id, pet_data)
	var level_cap := clampi(int(pet_data.get("ring_core_cap", MAX_LEVEL)), 0, MAX_LEVEL)
	while level < level_cap:
		var requirement := get_requirement_for_level(level)
		if requirement <= 0.0 or points < requirement:
			break
		points -= requirement
		level += 1
		rewards.append(_award_reward_for_level(pet_data, level))
	# Temporary ring-core caps preserve overflow for the next cap upgrade. Only the
	# absolute Lv.30 cap discards overflow so long runs cannot bank beyond max.
	if level >= MAX_LEVEL:
		points = 0.0
	pet_data["affinity_level"] = level
	pet_data["affinity_points"] = points
	return rewards


func _award_missing_rewards_up_to_level(pet_data: Dictionary, target_level: int) -> void:
	_ensure_reward_state(str(pet_data.get("pet_id", "")), pet_data)
	var history: Array = pet_data.get("reward_history", []) as Array
	for reward_level in range(history.size() + 1, clampi(target_level, 0, MAX_LEVEL) + 1):
		_award_reward_for_level(pet_data, reward_level)


func _award_reward_for_level(pet_data: Dictionary, level: int) -> Dictionary:
	_ensure_reward_state(str(pet_data.get("pet_id", "")), pet_data)
	var deck: Array = pet_data.get("reward_deck", []) as Array
	var base_card: Dictionary = get_reward_for_level(level)
	if level > 0 and level <= deck.size() and deck[level - 1] is Dictionary:
		base_card = (deck[level - 1] as Dictionary).duplicate(true)
	var awarded_card := _resolve_effective_reward_card(pet_data, base_card)
	awarded_card["level"] = level
	if level >= MAX_LEVEL:
		awarded_card["title"] = "하트 공명"
	_apply_reward_to_pet_counts(pet_data, awarded_card)
	var history: Array = pet_data.get("reward_history", []) as Array
	history.append(awarded_card.duplicate(true))
	pet_data["reward_history"] = history
	return awarded_card


func _resolve_effective_reward_card(pet_data: Dictionary, card: Dictionary) -> Dictionary:
	var card_type := str(card.get("type", ""))
	if _can_apply_reward_card(pet_data, card):
		return card.duplicate(true)
	var replacement_type := _select_replacement_stat_reward_type(pet_data)
	if replacement_type == "":
		return {
			"type": REWARD_TYPE_NO_REWARD,
			"label": str(LABEL_BY_REWARD_TYPE.get(REWARD_TYPE_NO_REWARD, "보상 없음")),
			"replaced_type": card_type,
			"no_reward": true,
		}
	return {
		"type": replacement_type,
		"label": str(LABEL_BY_REWARD_TYPE.get(replacement_type, "스탯 강화")),
		"replaced_type": card_type,
	}


func _can_apply_reward_type(pet_data: Dictionary, card_type: String) -> bool:
	return _can_apply_reward_card(pet_data, {"type": card_type})


func _can_apply_reward_card(pet_data: Dictionary, card: Dictionary) -> bool:
	var counts := _reward_counts_snapshot(pet_data)
	var card_type := str(card.get("type", ""))
	var skill_slot := int(card.get("skill_slot", 0))
	match card_type:
		REWARD_TYPE_ACTIVE_UNLOCK:
			return not bool(counts.get("active_unlocked", false))
		REWARD_TYPE_PASSIVE_UNLOCK:
			return not bool(counts.get("passive_unlocked", false))
		REWARD_TYPE_SECOND_ACTIVE_UNLOCK:
			return not bool(counts.get("second_active_unlocked", false))
		REWARD_TYPE_SECOND_PASSIVE_UNLOCK:
			return not bool(counts.get("second_passive_unlocked", false))
		REWARD_TYPE_ACTIVE_SKILL:
			return _can_apply_skill_bonus(pet_data, counts, true, skill_slot)
		REWARD_TYPE_PASSIVE_SKILL:
			return _can_apply_skill_bonus(pet_data, counts, false, skill_slot)
		REWARD_TYPE_MOBILITY:
			return int(counts.get("mobility_stacks", 0)) < MAX_MOBILITY_STACKS
		REWARD_TYPE_DEFENSE:
			return _normalize_motion_style(str(pet_data.get("reward_motion_style", MOTION_STYLE_PATROL))) == MOTION_STYLE_PATROL and int(counts.get("defense_stacks", 0)) < MAX_DEFENSE_STACKS
		REWARD_TYPE_GAUGE:
			return int(counts.get("gauge_stacks", 0)) < MAX_GAUGE_STACKS
		REWARD_TYPE_NO_REWARD:
			return true
	return true


func _select_replacement_stat_reward_type(pet_data: Dictionary) -> String:
	var motion_style := _normalize_motion_style(str(pet_data.get("reward_motion_style", MOTION_STYLE_PATROL)))
	var order: Array[String] = [REWARD_TYPE_GAUGE, REWARD_TYPE_MOBILITY]
	if motion_style == MOTION_STYLE_PATROL:
		order = [REWARD_TYPE_MOBILITY, REWARD_TYPE_GAUGE, REWARD_TYPE_DEFENSE]
	for reward_type in order:
		if _can_apply_reward_type(pet_data, reward_type):
			return reward_type
	return ""


func _apply_reward_to_pet_counts(pet_data: Dictionary, reward: Dictionary) -> void:
	var counts := _reward_counts_snapshot(pet_data)
	_apply_reward_type_to_counts(counts, str(reward.get("type", "")), int(reward.get("skill_slot", 0)))
	if bool(reward.has("title")):
		counts["title_unlocked"] = true
	counts["signature"] = _build_reward_signature_from_counts(counts)
	pet_data["reward_counts"] = counts
	if _is_unlock_reward_type(str(reward.get("type", ""))):
		_record_pending_unlock_choice(pet_data, reward)


static func _apply_reward_type_to_counts(counts: Dictionary, reward_type: String, skill_slot: int = 0) -> void:
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
	counts["support_stacks"] = int(counts.get("defense_stacks", 0)) + int(counts.get("gauge_stacks", 0))


func _ensure_reward_state(pet_id: String, pet_data: Dictionary) -> void:
	_ensure_unlock_state(pet_id, pet_data)
	if not pet_data.has("reward_counts"):
		pet_data["reward_counts"] = get_empty_reward_counts()
	if not pet_data.has("reward_history"):
		pet_data["reward_history"] = []
	if not _has_reward_deck(pet_data):
		_build_reward_deck(pet_id, pet_data)


func _build_reward_deck(pet_id: String, pet_data: Dictionary) -> void:
	var motion_style := _normalize_motion_style(str(pet_data.get("reward_motion_style", MOTION_STYLE_PATROL)))
	var seed := int(pet_data.get("reward_seed", 0))
	if seed <= 0:
		seed = _build_default_reward_seed(pet_id, motion_style)
	pet_data["reward_seed"] = seed
	var support_card_type := REWARD_TYPE_DEFENSE if motion_style == MOTION_STYLE_PATROL else REWARD_TYPE_GAUGE
	var level_cards: Array[Dictionary] = []
	level_cards.append(_make_reward_card(REWARD_TYPE_ACTIVE_UNLOCK))
	level_cards.append(_make_reward_card(REWARD_TYPE_PASSIVE_UNLOCK))
	level_cards.append_array(_shuffle_reward_card_band([
		_make_reward_card(support_card_type),
		_make_reward_card(REWARD_TYPE_MOBILITY),
		_make_reward_card(REWARD_TYPE_ACTIVE_SKILL, 1),
	], seed, 3))
	level_cards.append_array(_shuffle_reward_card_band([
		_make_reward_card(REWARD_TYPE_GAUGE),
		_make_reward_card(REWARD_TYPE_PASSIVE_SKILL, 1),
		_make_reward_card(support_card_type),
		_make_reward_card(REWARD_TYPE_ACTIVE_SKILL, 1),
		_make_reward_card(REWARD_TYPE_MOBILITY),
	], seed, 6))
	level_cards.append_array(_shuffle_reward_card_band([
		_make_reward_card(REWARD_TYPE_PASSIVE_SKILL, 1),
		_make_reward_card(REWARD_TYPE_GAUGE),
		_make_reward_card(support_card_type),
		_make_reward_card(REWARD_TYPE_ACTIVE_SKILL, 1),
		_make_reward_card(REWARD_TYPE_MOBILITY),
	], seed, 11))
	level_cards.append_array(_shuffle_reward_card_band([
		_make_reward_card(REWARD_TYPE_PASSIVE_SKILL, 1),
		_make_reward_card(REWARD_TYPE_GAUGE),
		_make_reward_card(support_card_type),
		_make_reward_card(REWARD_TYPE_ACTIVE_SKILL, 1),
		_make_reward_card(REWARD_TYPE_MOBILITY),
	], seed, 16))
	var pre_second_unlock_band := _shuffle_reward_card_band([
		_make_reward_card(REWARD_TYPE_PASSIVE_SKILL, 1),
		_make_reward_card(REWARD_TYPE_GAUGE),
		_make_reward_card(REWARD_TYPE_MOBILITY),
	], seed, 21)
	level_cards.append(pre_second_unlock_band[0])
	level_cards.append(_make_reward_card(REWARD_TYPE_SECOND_ACTIVE_UNLOCK))
	level_cards.append(pre_second_unlock_band[1])
	level_cards.append(pre_second_unlock_band[2])
	level_cards.append(_make_reward_card(REWARD_TYPE_SECOND_PASSIVE_UNLOCK))
	var final_band: Array[Dictionary] = [
		_make_reward_card(REWARD_TYPE_ACTIVE_SKILL, 2),
		_make_reward_card(REWARD_TYPE_PASSIVE_SKILL, 2),
		_make_reward_card(REWARD_TYPE_GAUGE),
		_make_reward_card(REWARD_TYPE_ACTIVE_SKILL, 2),
		_make_reward_card(REWARD_TYPE_PASSIVE_SKILL, 2),
	]
	if motion_style == MOTION_STYLE_FLIGHT:
		final_band[2] = _make_reward_card(REWARD_TYPE_MOBILITY)
	level_cards.append_array(_shuffle_reward_card_band(final_band, seed, 26))
	if level_cards.size() >= MAX_LEVEL and level_cards[MAX_LEVEL - 1] is Dictionary:
		(level_cards[MAX_LEVEL - 1] as Dictionary)["title"] = "하트 공명"
	pet_data["reward_deck"] = level_cards


func _shuffle_reward_band(types: Array[String], base_seed: int, band_start_level: int) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for reward_type in types:
		cards.append(_make_reward_card(reward_type))
	return _shuffle_reward_card_band(cards, base_seed, band_start_level)


func _shuffle_reward_card_band(cards: Array[Dictionary], base_seed: int, band_start_level: int) -> Array[Dictionary]:
	var state_seed := maxi(1, int((base_seed + band_start_level * 1103) % REWARD_DECK_SEED_MOD))
	var shuffled := cards.duplicate(true)
	for i in range(shuffled.size() - 1, 0, -1):
		state_seed = _advance_reward_seed(state_seed)
		var j := state_seed % (i + 1)
		var tmp: Dictionary = (shuffled[i] as Dictionary).duplicate(true)
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	var result: Array[Dictionary] = []
	for raw_card in shuffled:
		if raw_card is Dictionary:
			result.append((raw_card as Dictionary).duplicate(true))
	return result


func _make_reward_card(reward_type: String, skill_slot: int = 0) -> Dictionary:
	var card := {
		"type": reward_type,
		"label": str(LABEL_BY_REWARD_TYPE.get(reward_type, "보상")),
	}
	if skill_slot > 0:
		card["skill_slot"] = skill_slot
		if reward_type == REWARD_TYPE_ACTIVE_SKILL and skill_slot == 2:
			card["label"] = "2번째 액티브 스킬 +1"
		elif reward_type == REWARD_TYPE_PASSIVE_SKILL and skill_slot == 2:
			card["label"] = "2번째 패시브 스킬 +1"
	return card


func _has_reward_deck(pet_data: Dictionary) -> bool:
	var raw_deck: Variant = pet_data.get("reward_deck", [])
	return raw_deck is Array and (raw_deck as Array).size() >= MAX_LEVEL


func _available_active_skill_bonus_slots(pet_data: Dictionary) -> int:
	return maxi(0, SKILL_LEVEL_MAX - int(pet_data.get("active_skill_base_level", 1)))


func _available_passive_skill_bonus_slots(pet_data: Dictionary) -> int:
	return maxi(0, SKILL_LEVEL_MAX - int(pet_data.get("passive_skill_base_level", 1)))


func _can_apply_skill_bonus(pet_data: Dictionary, counts: Dictionary, active: bool, skill_slot: int) -> bool:
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


func _record_pending_unlock_choice(pet_data: Dictionary, reward: Dictionary) -> void:
	var reward_type := str(reward.get("type", ""))
	var choice_key := _unlock_choice_key(reward_type)
	if choice_key == "":
		return
	var pending: Dictionary = pet_data.get("pending_unlock_choices", {}) as Dictionary
	var resolved: Dictionary = pet_data.get("resolved_unlock_choices", {}) as Dictionary
	if pending.has(choice_key) or resolved.has(choice_key):
		return
	var pool: Dictionary = pet_data.get("unlock_candidate_pool", {}) as Dictionary
	var pooled: Variant = pool.get(choice_key, [])
	var candidates: Array[String] = []
	if pooled is Array:
		candidates = _normalize_choice_candidates(pooled as Array)
	pending[choice_key] = {
		"type": reward_type,
		"choice_key": choice_key,
		"candidates": candidates,
		"selected": "",
		"rejected": [],
	}
	pet_data["pending_unlock_choices"] = pending
	if candidates.size() >= 2:
		_resolve_random_unlock_choice(pet_data, reward)


func _resolve_random_unlock_choice(pet_data: Dictionary, reward: Dictionary) -> Dictionary:
	var reward_type := str(reward.get("type", ""))
	var choice_key := _unlock_choice_key(reward_type)
	if choice_key == "":
		choice_key = str(reward.get("choice_key", ""))
		reward_type = _reward_type_for_unlock_choice_key(choice_key)
	if choice_key == "" or reward_type == "":
		return {"accepted": false, "blocked_reason": "not_unlock_type"}
	var pending: Dictionary = pet_data.get("pending_unlock_choices", {}) as Dictionary
	var resolved: Dictionary = pet_data.get("resolved_unlock_choices", {}) as Dictionary
	if resolved.has(choice_key):
		if pending.has(choice_key):
			pending.erase(choice_key)
			pet_data["pending_unlock_choices"] = pending
		return {"accepted": false, "blocked_reason": "already_resolved", "choice": (resolved.get(choice_key, {}) as Dictionary).duplicate(true)}
	var candidates: Array[String] = []
	if pending.has(choice_key):
		var choice: Dictionary = pending.get(choice_key, {}) as Dictionary
		var choice_candidates: Array = choice.get("candidates", []) as Array
		candidates = _normalize_choice_candidates(choice_candidates)
	if candidates.size() < 2:
		candidates = _get_unlock_candidates(pet_data, reward_type)
	if candidates.is_empty():
		return {"accepted": false, "blocked_reason": "missing_candidates"}
	var pick_seed := _next_unlock_choice_seed(pet_data, choice_key)
	var selected_index := pick_seed % candidates.size()
	var selected := str(candidates[selected_index])
	var rejected: Array[String] = []
	for candidate in candidates:
		if candidate != selected:
			rejected.append(candidate)
	var resolved_choice := {
		"type": reward_type,
		"choice_key": choice_key,
		"selected": selected,
		"rejected": rejected,
		"candidates": candidates.duplicate(true),
		"auto": true,
		"random": candidates.size() > 1,
	}
	resolved[choice_key] = resolved_choice
	if pending.has(choice_key):
		pending.erase(choice_key)
	pet_data["pending_unlock_choices"] = pending
	pet_data["resolved_unlock_choices"] = resolved
	return {"accepted": true, "choice": resolved_choice.duplicate(true)}


func _get_unlock_candidates(pet_data: Dictionary, reward_type: String) -> Array[String]:
	var choice_key := _unlock_choice_key(reward_type)
	var pool: Dictionary = pet_data.get("unlock_candidate_pool", {}) as Dictionary
	var pooled: Variant = pool.get(choice_key, [])
	if pooled is Array:
		var normalized := _normalize_choice_candidates(pooled as Array)
		if normalized.size() >= 2:
			return normalized
	return _default_unlock_candidates(str(pet_data.get("pet_id", "")), reward_type)


func _default_unlock_candidates(pet_id: String, reward_type: String) -> Array[String]:
	var choice_key := _unlock_choice_key(reward_type)
	if choice_key == "":
		return []
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		normalized_pet_id = "lingpet"
	return [
		"%s_%s_a" % [normalized_pet_id, choice_key],
		"%s_%s_b" % [normalized_pet_id, choice_key],
	]


func _normalize_choice_candidates(candidates: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_candidate in candidates:
		var candidate := str(raw_candidate).strip_edges()
		if candidate != "" and not result.has(candidate):
			result.append(candidate)
		if result.size() >= 2:
			break
	return result


func _is_unlock_reward_type(reward_type: String) -> bool:
	return _unlock_choice_key(reward_type) != ""


func _unlock_choice_key(reward_type: String) -> String:
	match reward_type:
		REWARD_TYPE_ACTIVE_UNLOCK:
			return "active"
		REWARD_TYPE_PASSIVE_UNLOCK:
			return "passive"
		REWARD_TYPE_SECOND_ACTIVE_UNLOCK:
			return "second_active"
		REWARD_TYPE_SECOND_PASSIVE_UNLOCK:
			return "second_passive"
	return ""


func _reward_type_for_unlock_choice_key(choice_key: String) -> String:
	match choice_key:
		"active":
			return REWARD_TYPE_ACTIVE_UNLOCK
		"passive":
			return REWARD_TYPE_PASSIVE_UNLOCK
		"second_active":
			return REWARD_TYPE_SECOND_ACTIVE_UNLOCK
		"second_passive":
			return REWARD_TYPE_SECOND_PASSIVE_UNLOCK
	return ""


func _is_victory_participation_eligible(pet_id: String) -> bool:
	var total_rounds := int(_battle_caps.get(BATTLE_CAP_ROUND_COMMIT_TOTAL, 0))
	if total_rounds <= 0:
		return false
	var by_pet: Dictionary = _get_battle_round_commit_by_pet()
	var pet_rounds := int(by_pet.get(pet_id, 0))
	return pet_rounds * 2 >= total_rounds


func _get_battle_round_commit_by_pet() -> Dictionary:
	var raw_by_pet: Variant = _battle_caps.get(BATTLE_CAP_ROUND_COMMIT_BY_PET, {})
	if raw_by_pet is Dictionary:
		return raw_by_pet as Dictionary
	return {}


func _get_battle_bond_level_ups_by_pet() -> Dictionary:
	var raw_by_pet: Variant = _battle_caps.get(BATTLE_CAP_BOND_LEVEL_UPS_BY_PET, {})
	if raw_by_pet is Dictionary:
		return raw_by_pet as Dictionary
	return {}


func _sum_int_values(values: Dictionary) -> int:
	var total := 0
	for raw_value in values.values():
		total += int(raw_value)
	return total


func _points_remaining_until_level(current_level: int, current_points: float, target_level: int) -> float:
	var clamped_current := clampi(current_level, 0, MAX_LEVEL)
	var clamped_target := clampi(target_level, 0, MAX_LEVEL)
	if clamped_current >= clamped_target:
		return 0.0
	var total := -maxf(0.0, current_points)
	for level in range(clamped_current, clamped_target):
		total += get_requirement_for_level(level)
	return maxf(0.0, total)


func _update_best_level(pet_data: Dictionary) -> void:
	var level := int(pet_data.get("affinity_level", 0))
	if level > int(pet_data.get("best_level", 0)):
		pet_data["best_level"] = level


func _get_or_create_pet_data(pet_id: String) -> Dictionary:
	if _pets.has(pet_id):
		var existing: Variant = _pets.get(pet_id, {})
		if existing is Dictionary:
			return existing as Dictionary
	var pet_data := {
		"pet_id": pet_id,
		"affinity_points": 0.0,
		"affinity_level": 0,
		"hatch_bonus_granted": false,
		"best_level": 0,
		"reward_motion_style": MOTION_STYLE_PATROL,
		"active_skill_base_level": 1,
		"passive_skill_base_level": 1,
		"ring_core_cap": MAX_LEVEL,
		"reward_seed": 0,
		"unlock_choice_seed_base": 0,
		"reward_deck": [],
		"reward_history": [],
		"reward_counts": get_empty_reward_counts(),
		"unlock_candidate_pool": {},
		"pending_unlock_choices": {},
		"resolved_unlock_choices": {},
	}
	_ensure_unlock_state(pet_id, pet_data)
	_pets[pet_id] = pet_data
	return pet_data


func _get_existing_pet_data(pet_id: String) -> Dictionary:
	if _pets.has(pet_id):
		var existing: Variant = _pets.get(pet_id, {})
		if existing is Dictionary:
			return existing as Dictionary
	return {}


func _reward_counts_snapshot(pet_data: Dictionary) -> Dictionary:
	var raw_counts: Variant = pet_data.get("reward_counts", {})
	var counts := get_empty_reward_counts()
	if raw_counts is Dictionary:
		for key in counts.keys():
			if (raw_counts as Dictionary).has(key):
				counts[key] = (raw_counts as Dictionary).get(key)
	counts["support_stacks"] = int(counts.get("defense_stacks", 0)) + int(counts.get("gauge_stacks", 0))
	counts["signature"] = _build_reward_signature_from_counts(counts)
	return counts


func _ensure_unlock_state(pet_id: String, pet_data: Dictionary) -> void:
	if not pet_data.has("ring_core_cap"):
		pet_data["ring_core_cap"] = MAX_LEVEL
	if not pet_data.has("unlock_candidate_pool"):
		pet_data["unlock_candidate_pool"] = {}
	if not pet_data.has("pending_unlock_choices"):
		pet_data["pending_unlock_choices"] = {}
	if not pet_data.has("resolved_unlock_choices"):
		pet_data["resolved_unlock_choices"] = {}
	if not pet_data.has("pet_id") or str(pet_data.get("pet_id", "")) == "":
		pet_data["pet_id"] = _normalize_pet_id(pet_id)
	_migrate_seeded_pending_unlock_choices_to_random_resolved(pet_data)


func _migrate_seeded_pending_unlock_choices_to_random_resolved(pet_data: Dictionary) -> void:
	var pending: Dictionary = pet_data.get("pending_unlock_choices", {}) as Dictionary
	if pending.is_empty():
		return
	for raw_choice_key in pending.keys().duplicate():
		var choice_key := str(raw_choice_key)
		var choice: Dictionary = pending.get(choice_key, {}) as Dictionary
		var candidates: Array = choice.get("candidates", []) as Array
		if _normalize_choice_candidates(candidates).size() < 2:
			continue
		var reward_type := str(choice.get("type", ""))
		if reward_type == "":
			reward_type = _reward_type_for_unlock_choice_key(choice_key)
		var resolve_result := _resolve_random_unlock_choice(pet_data, {"type": reward_type, "choice_key": choice_key})
		if bool(resolve_result.get("accepted", false)):
			_dirty = true


static func _empty_reward_signature() -> String:
	return "0|0|0|0|0|0|0|0|0|0|0|0"


static func _build_reward_signature_from_counts(counts: Dictionary) -> String:
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


func _build_blocked_result(pet_id: String, source: String, reason: String) -> Dictionary:
	return _build_result(pet_id, source, 0, 0.0, 0.0, 0.0, [], reason)


func _build_result(
	pet_id: String,
	source: String,
	level_before: int,
	points_before: float,
	granted_points: float,
	bonus_points: float,
	rewards: Array,
	blocked_reason: String
) -> Dictionary:
	var pet_data := get_pet_data(pet_id)
	var level_after := int(pet_data.get("affinity_level", level_before))
	var points_after := float(pet_data.get("affinity_points", points_before))
	return {
		"pet_id": pet_id,
		"source": source,
		"granted_points": granted_points,
		"bonus_points": bonus_points,
		"level_before": level_before,
		"level_after": level_after,
		"points_before": points_before,
		"points_after": points_after,
		"levels_gained": max(0, level_after - level_before),
		"rewards": rewards.duplicate(true),
		"blocked_reason": blocked_reason,
		"best_level": int(pet_data.get("best_level", level_after)),
		"reward_counts": _reward_counts_snapshot(pet_data),
		"next_reward": get_next_reward(pet_id),
	}


func _get_gain_value(source: String, key: String) -> float:
	var entry: Variant = GAIN_TABLE.get(source, {})
	if entry is Dictionary:
		return float((entry as Dictionary).get(key, 0.0))
	return 0.0


func _has_defense_bonus_tag(tags: Dictionary) -> bool:
	return bool(tags.get("defense_intercept", false)) or bool(tags.get("ring_dash_block", false))


func _normalize_motion_style(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized == MOTION_STYLE_PATROL:
		return MOTION_STYLE_PATROL
	return MOTION_STYLE_FLIGHT


func _build_default_reward_seed(pet_id: String, motion_style: String) -> int:
	var seed := DEFAULT_REWARD_DECK_SEED
	for i in range(pet_id.length()):
		seed = int((seed * 131 + pet_id.unicode_at(i)) % REWARD_DECK_SEED_MOD)
	for i in range(motion_style.length()):
		seed = int((seed * 131 + motion_style.unicode_at(i)) % REWARD_DECK_SEED_MOD)
	return maxi(1, seed)


func _advance_reward_seed(seed: int) -> int:
	return maxi(1, int((seed * 1103515245 + 12345) % REWARD_DECK_SEED_MOD))


func _next_unlock_choice_seed(pet_data: Dictionary, choice_key: String) -> int:
	var seed := int(pet_data.get("unlock_choice_seed_base", 0))
	if seed <= 0:
		seed = _build_default_reward_seed(str(pet_data.get("pet_id", "")), str(pet_data.get("reward_motion_style", MOTION_STYLE_PATROL)))
	for i in range(choice_key.length()):
		seed = int((seed * 131 + choice_key.unicode_at(i)) % REWARD_DECK_SEED_MOD)
	return _advance_reward_seed(seed)


func _normalize_pet_id(value: String) -> String:
	return value.strip_edges().to_lower()
