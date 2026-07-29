extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetDurationState := preload("res://scripts/lingpet/lingpet_duration_state.gd")
const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)

# Compatibility vocabulary retained while callers migrate off the historical owner
# name. There is no point-grant API or level/reward-deck executor in this owner.
const SOURCE_ROUND_COMMIT := "round_commit"
const SOURCE_BALL_HIT := "ball_hit"
const SOURCE_CLICK := "click"
const SOURCE_HATCH := "hatch"
const SOURCE_VICTORY := "victory"
const SOURCE_STAGE_CLEAR := "stage_clear"
const MAX_LEVEL := 30

const REWARD_TYPE_ACTIVE_UNLOCK := LingpetEnhancementBuffStore.REWARD_TYPE_ACTIVE_UNLOCK
const REWARD_TYPE_PASSIVE_UNLOCK := LingpetEnhancementBuffStore.REWARD_TYPE_PASSIVE_UNLOCK
const REWARD_TYPE_SECOND_ACTIVE_UNLOCK := LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_ACTIVE_UNLOCK
const REWARD_TYPE_SECOND_PASSIVE_UNLOCK := LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_PASSIVE_UNLOCK
const REWARD_TYPE_ACTIVE_SKILL := LingpetEnhancementBuffStore.REWARD_TYPE_ACTIVE_SKILL
const REWARD_TYPE_PASSIVE_SKILL := LingpetEnhancementBuffStore.REWARD_TYPE_PASSIVE_SKILL
const REWARD_TYPE_MOBILITY := LingpetEnhancementBuffStore.REWARD_TYPE_MOBILITY
const REWARD_TYPE_DEFENSE := LingpetEnhancementBuffStore.REWARD_TYPE_DEFENSE
const REWARD_TYPE_GAUGE := LingpetEnhancementBuffStore.REWARD_TYPE_GAUGE
const REWARD_TYPE_NO_REWARD := LingpetEnhancementBuffStore.REWARD_TYPE_NO_REWARD

const MOTION_STYLE_PATROL := LingpetEnhancementBuffStore.MOTION_STYLE_PATROL
const MOTION_STYLE_FLIGHT := LingpetEnhancementBuffStore.MOTION_STYLE_FLIGHT
const SKILL_LEVEL_MAX := LingpetEnhancementBuffStore.SKILL_LEVEL_MAX
const MAX_MOBILITY_STACKS := LingpetEnhancementBuffStore.MAX_MOBILITY_STACKS
const MAX_DEFENSE_STACKS := LingpetEnhancementBuffStore.MAX_DEFENSE_STACKS
const MAX_GAUGE_STACKS := LingpetEnhancementBuffStore.MAX_GAUGE_STACKS
const REWARD_DECK_SEED_MOD := 2147483647

const SATIETY_KEY := LingpetDurationState.SAVE_VALUE_KEY
const SATIETY_MIN := LingpetDurationState.DURATION_MIN
const SATIETY_MAX := LingpetDurationState.DURATION_MAX
const SATIETY_DRAIN_PER_SECOND := LingpetDurationState.DRAIN_PER_SECOND
const SATIETY_REST_RECOVERY_RATIO := LingpetDurationState.REST_RECOVERY_RATIO
const SATIETY_DRAIN_REDUCTION_PCT_BY_LEVEL := LingpetDurationState.DRAIN_REDUCTION_PCT_BY_LEVEL
const SATIETY_EXHAUSTED_KEY := LingpetDurationState.SAVE_EXHAUSTED_KEY
const SATIETY_EXHAUSTION_TIMER_KEY := LingpetDurationState.SAVE_EXHAUSTION_TIMER_KEY
const SATIETY_EXHAUSTION_TELEGRAPH_SECONDS := LingpetDurationState.EXHAUSTION_TELEGRAPH_SECONDS

# Localization coverage still scans this compatibility label map. It describes the
# enhancement store only; no affinity-level deck consumes it.
const LABEL_BY_REWARD_TYPE := {
	REWARD_TYPE_ACTIVE_UNLOCK: "액티브 스킬 해금",
	REWARD_TYPE_PASSIVE_UNLOCK: "패시브 스킬 해금",
	REWARD_TYPE_SECOND_ACTIVE_UNLOCK: "2번째 액티브 스킬 해금",
	REWARD_TYPE_SECOND_PASSIVE_UNLOCK: "2번째 패시브 스킬 해금",
	REWARD_TYPE_ACTIVE_SKILL: "액티브 스킬 +1",
	REWARD_TYPE_PASSIVE_SKILL: "패시브 스킬 +1",
	REWARD_TYPE_MOBILITY: "기동 강화",
	REWARD_TYPE_DEFENSE: "방어 강화",
	REWARD_TYPE_GAUGE: "기력 강화",
	REWARD_TYPE_NO_REWARD: "보상 없음",
}

const RETIRED_RUN_STATE_KEYS := [
	"best_level",
	"bond_points",
	"bond_title",
	"ring_core_cap",
	"affinity_points",
	"affinity_level",
	"hatch_bonus_granted",
	"reward_seed",
	"unlock_choice_seed_base",
	"reward_deck",
	"reward_history",
]

var _pets: Dictionary = {}
var _dirty := false
var _duration_state: Object = LingpetDurationState.new()


func _init() -> void:
	_duration_state.bind_pet_store(_pets, Callable(self, "_get_or_create_pet_data"))


func reset_all() -> void:
	_pets.clear()
	_duration_state.reset_run()
	_dirty = false


func reset_for_new_run() -> void:
	reset_all()


func export_run_state() -> Dictionary:
	var pets_copy := {}
	for raw_pet_id in _pets.keys():
		var pet_data: Variant = _pets.get(raw_pet_id, {})
		if pet_data is Dictionary:
			pets_copy[str(raw_pet_id)] = _sanitize_pet_run_state(pet_data as Dictionary)
	var result := {"pets": pets_copy}
	result.merge(_duration_state.export_run_state(), true)
	return result


func import_run_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	_pets.clear()
	var raw_pets: Variant = data.get("pets", {})
	if raw_pets is Dictionary:
		for raw_pet_id in (raw_pets as Dictionary).keys():
			var raw_pet: Variant = (raw_pets as Dictionary).get(raw_pet_id, {})
			if raw_pet is Dictionary:
				_pets[_normalize_pet_id(str(raw_pet_id))] = _sanitize_pet_run_state(raw_pet as Dictionary)
	_duration_state.import_run_state(data)
	_dirty = true


func reset_round_caps() -> void:
	# Retained as a no-op compatibility seam until the owner is renamed in §9-4.
	pass


func is_dirty() -> bool:
	return _dirty


func clear_dirty() -> void:
	_dirty = false


func get_satiety(pet_id: String) -> float:
	return _duration_state.get_duration(pet_id)


func get_satiety_pct(pet_id: String) -> int:
	return _duration_state.get_duration_pct(pet_id)


func set_satiety(pet_id: String, value: float) -> float:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id.is_empty():
		return SATIETY_MAX
	_get_or_create_pet_data(normalized_pet_id)
	var result: Dictionary = _duration_state.set_duration(normalized_pet_id, value)
	if bool(result.get("changed", false)):
		_dirty = true
	return float(result.get("value", SATIETY_MAX))


func add_satiety(pet_id: String, amount: float) -> float:
	return set_satiety(pet_id, get_satiety(pet_id) + amount)


func advance_satiety(
	active_pet_id: String,
	battle_slot_pet_ids: Array,
	delta_seconds: float,
	active_drain_multiplier: float = 1.0,
	rest_recovery_multiplier: float = 1.0,
	active_resting: bool = false
) -> Dictionary:
	var result: Dictionary = _duration_state.advance_duration(
		active_pet_id,
		battle_slot_pet_ids,
		delta_seconds,
		active_drain_multiplier,
		rest_recovery_multiplier,
		active_resting
	)
	if bool(result.get("changed", false)):
		_dirty = true
	var facade_result := result.duplicate(true)
	facade_result["active_satiety"] = float(result.get("active_duration", SATIETY_MAX))
	return facade_result


func advance_satiety_exhaustion(
	pet_id: String,
	delta_seconds: float,
	telegraph_seconds: float = SATIETY_EXHAUSTION_TELEGRAPH_SECONDS,
	enabled: bool = true
) -> Dictionary:
	var result: Dictionary = _duration_state.advance_exhaustion(
		pet_id,
		delta_seconds,
		telegraph_seconds,
		enabled
	)
	if bool(result.get("changed", false)):
		_dirty = true
	return result


func get_satiety_exhaustion_ratio(
	pet_id: String,
	telegraph_seconds: float = SATIETY_EXHAUSTION_TELEGRAPH_SECONDS
) -> float:
	return _duration_state.get_exhaustion_ratio(pet_id, telegraph_seconds)


func is_satiety_exhausted(pet_id: String) -> bool:
	return _duration_state.is_exhausted(pet_id)


func get_satiety_exhaustion_timer(pet_id: String) -> float:
	return _duration_state.get_exhaustion_timer(pet_id)


func get_satiety_speed_multiplier(pet_id: String) -> float:
	return _duration_state.get_speed_multiplier(pet_id)


func ensure_duration_pool_roll(
	rng: RandomNumberGenerator = null,
	forced_roll: int = 0
) -> Dictionary:
	var result: Dictionary = _duration_state.ensure_initial_roll(rng, forced_roll)
	if bool(result.get("accepted", false)):
		_dirty = true
	return result


func get_duration_pool_current() -> float:
	return _duration_state.get_pool_current()


func get_duration_pool_max() -> float:
	return _duration_state.get_pool_max()


func get_duration_pool_pct() -> int:
	return _duration_state.get_pool_pct()


func get_duration_increase_count() -> int:
	return _duration_state.get_duration_increase_count()


func set_duration_pool_for_tests(current: float, maximum: float = 0.0) -> void:
	_duration_state.set_pool_for_tests(current, maximum)
	_dirty = true


func refill_duration_pool_for_stage_transition() -> bool:
	var changed: bool = bool(_duration_state.refill_to_max())
	_dirty = _dirty or changed
	return changed


func restore_duration_pool_to_full_preserving_overfill() -> Dictionary:
	var result: Dictionary = _duration_state.restore_to_full_preserving_overfill()
	_dirty = _dirty or bool(result.get("changed", false))
	return result


func can_resummon_guardian() -> bool:
	return _duration_state.can_resummon()


func is_duration_resummon_locked() -> bool:
	return _duration_state.is_resummon_locked()


func get_duration_resummon_lock_remaining() -> float:
	return _duration_state.get_resummon_lock_remaining()


func latch_duration_drain_exempt(owner: Object, collection_state: Object) -> bool:
	return _duration_state.latch_drain_exempt(owner, collection_state)


func clear_duration_drain_exempt_latch() -> void:
	_duration_state.clear_drain_exempt_latch()


func is_duration_drain_exempt_latched() -> bool:
	return _duration_state.is_drain_exempt_latched()


static func get_satiety_speed_multiplier_for_value(value: float) -> float:
	return LingpetDurationState.get_duration_speed_multiplier_for_value(value)


static func get_satiety_drain_reduction_pct_for_level(level: int) -> float:
	return LingpetDurationState.get_drain_reduction_pct_for_level(level)


func build_guardian_enhancement_candidates(
	pet_id: String,
	has_second_active_skill: bool = true,
	has_second_passive_skill: bool = true
) -> Array[Dictionary]:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id.is_empty():
		return []
	return LingpetEnhancementBuffStore.build_guardian_enhancement_candidates(
		_get_or_create_pet_data(normalized_pet_id),
		get_duration_increase_count(),
		has_second_active_skill,
		has_second_passive_skill
	)


func can_apply_guardian_enhancement(
	pet_id: String,
	candidate: Dictionary,
	has_second_active_skill: bool = true,
	has_second_passive_skill: bool = true
) -> bool:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id.is_empty():
		return false
	return LingpetEnhancementBuffStore.can_apply_guardian_enhancement(
		_get_or_create_pet_data(normalized_pet_id),
		candidate,
		get_duration_increase_count(),
		has_second_active_skill,
		has_second_passive_skill
	)


func apply_guardian_enhancement(
	pet_id: String,
	candidate: Dictionary,
	has_second_active_skill: bool = true,
	has_second_passive_skill: bool = true
) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id.is_empty():
		return {"accepted": false, "blocked_reason": "missing_pet_id"}
	if not can_apply_guardian_enhancement(
		normalized_pet_id,
		candidate,
		has_second_active_skill,
		has_second_passive_skill
	):
		return {"accepted": false, "blocked_reason": "candidate_no_longer_applicable"}
	if str(candidate.get("type", "")) == LingpetEnhancementBuffStore.REWARD_TYPE_DURATION:
		var duration_result: Dictionary = _duration_state.apply_duration_increase()
		_dirty = _dirty or bool(duration_result.get("accepted", false))
		return duration_result
	var pet_data := _get_or_create_pet_data(normalized_pet_id)
	var result: Dictionary = LingpetEnhancementBuffStore.apply_guardian_enhancement_to_pet(
		pet_data,
		candidate,
		has_second_active_skill,
		has_second_passive_skill
	)
	if bool(result.get("accepted", false)):
		_pets[normalized_pet_id] = pet_data
		_dirty = true
		result["pet_id"] = normalized_pet_id
	return result


func apply_guardian_enhance_duration_fallback() -> Dictionary:
	var result: Dictionary = _duration_state.apply_revalidation_fallback()
	_dirty = _dirty or bool(result.get("accepted", false))
	return result


func configure_reward_context(
	pet_id: String,
	motion_style: String = MOTION_STYLE_PATROL,
	active_skill_base_level: int = 1,
	passive_skill_base_level: int = 1,
	_reward_seed: int = 0,
	_force_rebuild: bool = false,
	active_present_id: String = "",
	passive_present_id: String = ""
) -> void:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id.is_empty():
		return
	var pet_data := _get_or_create_pet_data(normalized_pet_id)
	pet_data["reward_motion_style"] = _normalize_motion_style(motion_style)
	pet_data["active_skill_base_level"] = clampi(active_skill_base_level, 1, SKILL_LEVEL_MAX)
	pet_data["passive_skill_base_level"] = clampi(passive_skill_base_level, 1, SKILL_LEVEL_MAX)
	_seed_present_skill(pet_data, REWARD_TYPE_ACTIVE_UNLOCK, active_present_id)
	_seed_present_skill(pet_data, REWARD_TYPE_PASSIVE_UNLOCK, passive_present_id)
	_pets[normalized_pet_id] = pet_data


func set_hatch_stat_roll(pet_id: String, mobility_headstart: float, defense_headstart: float) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id.is_empty():
		return get_empty_hatch_stat_roll()
	var pet_data := _get_or_create_pet_data(normalized_pet_id)
	pet_data["hatch_mobility_headstart"] = clampf(mobility_headstart, 0.0, 1.0)
	pet_data["hatch_defense_headstart"] = clampf(defense_headstart, 0.0, 1.0)
	pet_data["hatch_stat_roll_set"] = true
	_pets[normalized_pet_id] = pet_data
	_dirty = true
	return get_hatch_stat_roll(normalized_pet_id)


func has_hatch_stat_roll(pet_id: String) -> bool:
	return bool(get_hatch_stat_roll(pet_id).get("has_roll", false))


func get_hatch_stat_roll(pet_id: String) -> Dictionary:
	var pet_data := _get_existing_pet_data(_normalize_pet_id(pet_id))
	if pet_data.is_empty():
		return get_empty_hatch_stat_roll()
	return {
		"mobility": clampf(float(pet_data.get("hatch_mobility_headstart", 0.0)), 0.0, 1.0),
		"defense": clampf(float(pet_data.get("hatch_defense_headstart", 0.0)), 0.0, 1.0),
		"has_roll": bool(pet_data.get("hatch_stat_roll_set", false)),
	}


static func get_empty_hatch_stat_roll() -> Dictionary:
	return {"mobility": 0.0, "defense": 0.0, "has_roll": false}


func get_pet_data(pet_id: String) -> Dictionary:
	return _get_existing_pet_data(_normalize_pet_id(pet_id)).duplicate(true)


func get_cumulative_rewards(pet_id: String) -> Dictionary:
	var pet_data := _get_existing_pet_data(_normalize_pet_id(pet_id))
	if pet_data.is_empty():
		return get_empty_reward_counts()
	return LingpetEnhancementBuffStore.reward_counts_snapshot(pet_data)


func get_reward_signature(pet_id: String) -> String:
	return str(get_cumulative_rewards(pet_id).get("signature", LingpetEnhancementBuffStore.empty_reward_signature()))


static func get_empty_reward_counts() -> Dictionary:
	return LingpetEnhancementBuffStore.get_empty_reward_counts()


static func get_requirement_for_level(_current_level: int) -> float:
	return 0.0


static func get_reward_for_level(_level: int) -> Dictionary:
	return {"type": REWARD_TYPE_NO_REWARD, "label": "보상 없음", "no_reward": true}


func get_guardian_enhancement_skill_availability(pet_id: String) -> Dictionary:
	return {
		"has_second_active": LingpetCatalog.get_active_skill_pool(pet_id).size() >= 2,
		"has_second_passive": LingpetCatalog.get_passive_skill_pool(pet_id).size() >= 2,
	}


func set_unlock_choice_candidates(pet_id: String, reward_type: String, candidates: Array) -> void:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	var choice_key := _unlock_choice_key(reward_type)
	if normalized_pet_id.is_empty() or choice_key.is_empty():
		return
	var normalized_candidates := _normalize_choice_candidates(candidates)
	if normalized_candidates.size() < 2:
		return
	var pet_data := _get_or_create_pet_data(normalized_pet_id)
	var pool: Dictionary = pet_data.get("unlock_candidate_pool", {}) as Dictionary
	pool[choice_key] = normalized_candidates
	pet_data["unlock_candidate_pool"] = pool
	var pending: Dictionary = pet_data.get("pending_unlock_choices", {}) as Dictionary
	if not (pet_data.get("resolved_unlock_choices", {}) as Dictionary).has(choice_key):
		pending[choice_key] = {
			"type": reward_type,
			"choice_key": choice_key,
			"candidates": normalized_candidates.duplicate(),
		}
		pet_data["pending_unlock_choices"] = pending
	_pets[normalized_pet_id] = pet_data


func get_pending_unlock_choices(pet_id: String) -> Dictionary:
	var pet_data := _get_existing_pet_data(_normalize_pet_id(pet_id))
	return (pet_data.get("pending_unlock_choices", {}) as Dictionary).duplicate(true)


func get_resolved_unlock_choices(pet_id: String) -> Dictionary:
	var pet_data := _get_existing_pet_data(_normalize_pet_id(pet_id))
	return (pet_data.get("resolved_unlock_choices", {}) as Dictionary).duplicate(true)


func resolve_single_unlock(pet_id: String, reward_type: String, only_id: String) -> Dictionary:
	var selected := only_id.strip_edges()
	if selected.is_empty():
		return {"accepted": false, "blocked_reason": "missing_selection"}
	return apply_resolved_unlock_choice(pet_id, reward_type, selected, [selected])


func resolve_random_unlock(pet_id: String, reward_type: String) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	var choice_key := _unlock_choice_key(reward_type)
	if normalized_pet_id.is_empty() or choice_key.is_empty():
		return {"accepted": false, "blocked_reason": "not_unlock_type"}
	var pet_data := _get_existing_pet_data(normalized_pet_id)
	var pending: Dictionary = pet_data.get("pending_unlock_choices", {}) as Dictionary
	var choice: Dictionary = pending.get(choice_key, {}) as Dictionary
	var candidates := _normalize_choice_candidates(choice.get("candidates", []) as Array)
	if candidates.is_empty():
		return {"accepted": false, "blocked_reason": "missing_candidates"}
	return apply_resolved_unlock_choice(
		normalized_pet_id,
		reward_type,
		candidates[randi() % candidates.size()],
		candidates
	)


func apply_resolved_unlock_choice(
	pet_id: String,
	reward_type: String,
	selected_id: String,
	candidates: Array
) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	var choice_key := _unlock_choice_key(reward_type)
	var selected := selected_id.strip_edges()
	var normalized_candidates := _normalize_choice_candidates(candidates)
	if normalized_pet_id.is_empty() or choice_key.is_empty() or selected.is_empty():
		return {"accepted": false, "blocked_reason": "invalid_selection"}
	if not normalized_candidates.has(selected):
		return {"accepted": false, "blocked_reason": "invalid_selection"}
	var pet_data := _get_or_create_pet_data(normalized_pet_id)
	var resolved: Dictionary = pet_data.get("resolved_unlock_choices", {}) as Dictionary
	if resolved.has(choice_key):
		return {"accepted": false, "blocked_reason": "already_resolved"}
	var rejected: Array[String] = []
	for candidate in normalized_candidates:
		if candidate != selected:
			rejected.append(candidate)
	var resolved_choice := {
		"type": reward_type,
		"choice_key": choice_key,
		"selected": selected,
		"rejected": rejected,
		"candidates": normalized_candidates.duplicate(),
		"auto": true,
		"random": normalized_candidates.size() > 1,
	}
	resolved[choice_key] = resolved_choice
	pet_data["resolved_unlock_choices"] = resolved
	var counts := LingpetEnhancementBuffStore.reward_counts_snapshot(pet_data)
	LingpetEnhancementBuffStore.apply_reward_type_to_counts(counts, reward_type)
	counts["signature"] = LingpetEnhancementBuffStore.build_reward_signature(counts)
	pet_data[LingpetEnhancementBuffStore.REWARD_COUNTS_KEY] = counts
	var pending: Dictionary = pet_data.get("pending_unlock_choices", {}) as Dictionary
	pending.erase(choice_key)
	pet_data["pending_unlock_choices"] = pending
	_pets[normalized_pet_id] = pet_data
	_dirty = true
	return {"accepted": true, "choice": resolved_choice.duplicate(true)}


func _seed_present_skill(pet_data: Dictionary, reward_type: String, present_id: String) -> void:
	var selected := present_id.strip_edges()
	var choice_key := _unlock_choice_key(reward_type)
	if selected.is_empty() or choice_key.is_empty():
		return
	var counts := LingpetEnhancementBuffStore.reward_counts_snapshot(pet_data)
	LingpetEnhancementBuffStore.apply_reward_type_to_counts(counts, reward_type)
	counts["signature"] = LingpetEnhancementBuffStore.build_reward_signature(counts)
	pet_data[LingpetEnhancementBuffStore.REWARD_COUNTS_KEY] = counts
	var resolved: Dictionary = pet_data.get("resolved_unlock_choices", {}) as Dictionary
	if not resolved.has(choice_key):
		resolved[choice_key] = {
			"type": reward_type,
			"choice_key": choice_key,
			"selected": selected,
			"rejected": [],
			"candidates": [selected],
			"auto": true,
			"random": false,
		}
		pet_data["resolved_unlock_choices"] = resolved


func _get_or_create_pet_data(pet_id: String) -> Dictionary:
	if _pets.has(pet_id) and _pets.get(pet_id) is Dictionary:
		return _pets.get(pet_id) as Dictionary
	var pet_data := {
		"pet_id": pet_id,
		"reward_motion_style": MOTION_STYLE_PATROL,
		"active_skill_base_level": 1,
		"passive_skill_base_level": 1,
		"reward_counts": get_empty_reward_counts(),
		"unlock_candidate_pool": {},
		"pending_unlock_choices": {},
		"resolved_unlock_choices": {},
	}
	_duration_state.initialize_pet_state(pet_data)
	LingpetEnhancementBuffStore.initialize_pet_state(pet_data)
	_pets[pet_id] = pet_data
	return pet_data


func _get_existing_pet_data(pet_id: String) -> Dictionary:
	if _pets.has(pet_id) and _pets.get(pet_id) is Dictionary:
		return _pets.get(pet_id) as Dictionary
	return {}


func _sanitize_pet_run_state(pet_data: Dictionary) -> Dictionary:
	var pet_copy := pet_data.duplicate(true)
	for retired_key in RETIRED_RUN_STATE_KEYS:
		pet_copy.erase(retired_key)
	pet_copy = _duration_state.sanitize_pet_run_state(pet_copy)
	pet_copy = LingpetEnhancementBuffStore.sanitize_pet_run_state(pet_copy)
	return pet_copy


static func _normalize_motion_style(value: String) -> String:
	return MOTION_STYLE_PATROL if value.strip_edges().to_lower() == MOTION_STYLE_PATROL else MOTION_STYLE_FLIGHT


static func _normalize_choice_candidates(candidates: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_candidate in candidates:
		var candidate := str(raw_candidate).strip_edges()
		if not candidate.is_empty() and not result.has(candidate):
			result.append(candidate)
	return result


static func _unlock_choice_key(reward_type: String) -> String:
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


static func _normalize_pet_id(value: String) -> String:
	return value.strip_edges().to_lower()
