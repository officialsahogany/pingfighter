extends RefCounted

const LingpetRingCoreRules := preload("res://scripts/lingpet/lingpet_ring_core_rules.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")

const SOURCE_ROUND_COMMIT := "round_commit"
const SOURCE_BALL_HIT := "ball_hit"
const SOURCE_CLICK := "click"
const SOURCE_HATCH := "hatch"
const SOURCE_VICTORY := "victory"
const SOURCE_STAGE_CLEAR := "stage_clear"
const SOURCE_RING_CORE_UPGRADE := "ring_core_upgrade"

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
const MAX_ENHANCEMENT_CHIPS := 5
const ENHANCEMENT_CHIP_BONUS := 0.20
const SKILL_LEVEL_MAX := 5
const RING_CORE_CAP_UNCHANGED := -1
const MAX_MOBILITY_STACKS := 6
const MAX_DEFENSE_STACKS := 2
const MAX_GAUGE_STACKS := 4
const RING_CORE_OFFER_COOLDOWN_SCREENS := 3
const LEGACY_PET_RUN_STATE_KEYS := ["best_level", "bond_points", "bond_title"]
const SATIETY_KEY := "satiety"
const SATIETY_MIN := 0.0
const SATIETY_MAX := 100.0
const SATIETY_DRAIN_PER_SECOND := 0.25
const SATIETY_REST_RECOVERY_RATIO := 1.0 / 3.0
const SATIETY_DRAIN_REDUCTION_PCT_BY_LEVEL := [10.0, 17.0, 24.0, 31.0, 38.0]
const SATIETY_EXHAUSTED_KEY := "satiety_exhausted"
const SATIETY_EXHAUSTION_TIMER_KEY := "satiety_exhaustion_timer"
const SATIETY_SLOW_START := 50.0
const SATIETY_SLOW_FLOOR_START := 10.0
const SATIETY_SLOW_MIN_MULTIPLIER := 0.60
const SATIETY_EXHAUSTION_TELEGRAPH_SECONDS := 1.75
const SATIETY_WAKE_THRESHOLD := 10.0

const REQUIREMENT_BY_CURRENT_LEVEL := [
	50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0,
	50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0,
	50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0,
]

const REWARD_DECK_SEED_MOD := 2147483647
const DEFAULT_REWARD_DECK_SEED := 991

# Second-slot unlocks are no longer fixed deck cards (they used to be pinned to
# Lv16/Lv17). They are now gated behind the pet's combined FIRST active + FIRST
# passive EFFECTIVE skill level reaching this sum, and -- once that prerequisite
# is met -- granted by an independent per-level-up probability roll, so the exact
# level they appear is intentionally unpredictable ("언제 나올진 모름"). The roll is
# seeded per (reward_seed, level, salt), so it stays fully deterministic for
# replay / save-restore (_award_missing_rewards_up_to_level) and for repeated
# runs with the same pet seed. See _maybe_roll_second_unlock_card.
const SECOND_UNLOCK_SKILL_LEVEL_SUM_REQUIREMENT := 5
const SECOND_UNLOCK_ROLL_CHANCE_PCT := 30
const SECOND_UNLOCK_ROLL_SALT_ACTIVE := 1009
const SECOND_UNLOCK_ROLL_SALT_PASSIVE := 2017

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
	# Second-slot unlocks are no longer fixed track entries -- they are granted by a
	# per-level probability roll gated on combined skill level (see
	# _maybe_roll_second_unlock_card). This canonical track is only a fallback/
	# migration read; the live deck (_build_reward_deck) is the authority. Lv16/17
	# carry ordinary skill cards so the fallback never deterministically grants the
	# unlocks here.
	16: {"type": REWARD_TYPE_ACTIVE_SKILL, "label": "액티브 스킬 +1", "skill_slot": 1},
	17: {"type": REWARD_TYPE_PASSIVE_SKILL, "label": "패시브 스킬 +1", "skill_slot": 1},
	18: {"type": REWARD_TYPE_PASSIVE_SKILL, "label": "패시브 스킬 +1", "skill_slot": 1},
	19: {"type": REWARD_TYPE_GAUGE, "label": "게이지 강화"},
	20: {"type": REWARD_TYPE_DEFENSE, "label": "방어 강화"},
	21: {"type": REWARD_TYPE_ACTIVE_SKILL, "label": "액티브 스킬 +1", "skill_slot": 1},
	22: {"type": REWARD_TYPE_MOBILITY, "label": "기동 강화"},
	23: {"type": REWARD_TYPE_PASSIVE_SKILL, "label": "패시브 스킬 +1", "skill_slot": 1},
	24: {"type": REWARD_TYPE_GAUGE, "label": "게이지 강화"},
	25: {"type": REWARD_TYPE_MOBILITY, "label": "기동 강화"},
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
		"points": 20.0,
		"flight_points": 30.0,
		"round_cap": 2,
		"battle_cap": 5,
	},
	SOURCE_HATCH: {"points": 25.0},
	SOURCE_VICTORY: {"points": 20.0},
	SOURCE_STAGE_CLEAR: {"points": 50.0},
	SOURCE_RING_CORE_UPGRADE: {"points": 50.0},
}

# Flight-style companions get fewer ball-hit / click opportunities than patrol pets
# (no patrol defense-intercept and often hidden / airborne), so the BALL-HIT opportunity
# source pays double for them. The style-agnostic floor sources (round commit / victory /
# stage clear / hatch) stay flat. CLICK no longer routes through this generic
# multiplier — it carries its own explicit patrol(20)/flight(30) values in GAIN_TABLE
# (a 1.5x design value, not the ball-hit 2x). The caps stay by COUNT — only the per-event
# points scale, so a rarer flight hit feels proportionally rewarding.
# Placeholder magnitude — tuned in the V3-6 income-log pass with the rest of GAIN_TABLE.
const FLIGHT_OPPORTUNITY_MULTIPLIER := 2.0

const ROUND_CAP_BALL_HIT_COUNT := "ball_hit_count"
const ROUND_CAP_DEFENSE_BONUS_COUNT := "defense_bonus_count"
const ROUND_CAP_CLICK_COUNT := "click_count"
const BATTLE_CAP_CLICK_COUNT := "click_count"
const BATTLE_CAP_ROUND_COMMIT_TOTAL := "round_commit_total"
const BATTLE_CAP_ROUND_COMMIT_BY_PET := "round_commit_by_pet"
const BATTLE_CAP_VICTORY_PAID := "victory_paid"
const BATTLE_CAP_STAGE_CLEAR_PAID := "stage_clear_paid"
const BATTLE_CAP_BOND_LEVEL_UPS_BY_PET := "bond_level_ups_by_pet"

var _pets: Dictionary = {}
var _round_caps: Dictionary = {}
var _battle_caps: Dictionary = {}
var _enhancement_chips := 0
var _run_ring_core_tier := 0
var _ring_core_offer_cooldown_screens := 0
var _dirty := false


# Run-end/test reset only. Do not call this for pet swaps or hatch flows because it clears
# hatch_bonus_granted and deliberately allows a fresh run to receive hatch bonuses again.
func reset_all() -> void:
	_pets.clear()
	_enhancement_chips = 0
	_run_ring_core_tier = 0
	_ring_core_offer_cooldown_screens = 0
	reset_battle_caps()
	_dirty = false


func reset_for_new_run() -> void:
	reset_all()


# Run-scoped progression export/import. The lingpet save/restore round trip
# (apply_save_snapshot) unconditionally calls reset_for_tests()->reset_for_new_run(),
# which wipes the run progression. The save snapshot must therefore carry this run
# state and re-import it on restore so a pet swap / plaza round trip / in-run restore
# does NOT lose per-pet affinity OR the run-global ring core tier. This is in-memory /
# in-run only: the disk save deliberately clears volatile run snapshots, so a game
# restart still resets the run (see lingpet_save_store._is_volatile_run_snapshot).
func export_run_state() -> Dictionary:
	var pets_copy := {}
	for raw_pet_id in _pets.keys():
		var pet_data: Variant = _pets[raw_pet_id]
		if pet_data is Dictionary:
			pets_copy[str(raw_pet_id)] = _sanitize_pet_run_state(pet_data as Dictionary)
	return {
		"pets": pets_copy,
		"enhancement_chips": _enhancement_chips,
		"run_ring_core_tier": _run_ring_core_tier,
		"ring_core_offer_cooldown_screens": _ring_core_offer_cooldown_screens,
	}


func import_run_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	var pets_in: Dictionary = data.get("pets", {}) as Dictionary
	_pets.clear()
	for raw_pet_id in pets_in.keys():
		var pet_data: Variant = pets_in[raw_pet_id]
		if pet_data is Dictionary:
			_pets[str(raw_pet_id)] = _sanitize_pet_run_state(pet_data as Dictionary)
	_enhancement_chips = clampi(int(data.get("enhancement_chips", 0)), 0, MAX_ENHANCEMENT_CHIPS)
	_run_ring_core_tier = clampi(int(data.get("run_ring_core_tier", 0)), 0, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	_ring_core_offer_cooldown_screens = maxi(0, int(data.get("ring_core_offer_cooldown_screens", 0)))
	_dirty = true


func reset_for_new_battle() -> void:
	reset_battle_caps()


func reset_round_caps() -> void:
	_round_caps.clear()


func reset_battle_caps() -> void:
	_round_caps.clear()
	_battle_caps.clear()


func _sanitize_pet_run_state(pet_data: Dictionary) -> Dictionary:
	var pet_copy := pet_data.duplicate(true)
	for legacy_key in LEGACY_PET_RUN_STATE_KEYS:
		pet_copy.erase(legacy_key)
	var sanitized_satiety := _sanitize_satiety_value(pet_copy.get(SATIETY_KEY, SATIETY_MAX))
	pet_copy[SATIETY_KEY] = sanitized_satiety
	pet_copy[SATIETY_EXHAUSTION_TIMER_KEY] = _sanitize_satiety_exhaustion_timer(
		pet_copy.get(SATIETY_EXHAUSTION_TIMER_KEY, 0.0),
		sanitized_satiety
	)
	pet_copy[SATIETY_EXHAUSTED_KEY] = sanitized_satiety < SATIETY_WAKE_THRESHOLD and (
		bool(pet_copy.get(SATIETY_EXHAUSTED_KEY, false))
		or float(pet_copy.get(SATIETY_EXHAUSTION_TIMER_KEY, 0.0)) >= SATIETY_EXHAUSTION_TELEGRAPH_SECONDS
	)
	return pet_copy


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


func get_satiety(pet_id: String) -> float:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return SATIETY_MAX
	var pet_data := _get_existing_pet_data(normalized_pet_id)
	if pet_data.is_empty():
		return SATIETY_MAX
	return _sanitize_satiety_value(pet_data.get(SATIETY_KEY, SATIETY_MAX))


func get_satiety_pct(pet_id: String) -> int:
	return clampi(roundi(get_satiety(pet_id)), int(SATIETY_MIN), int(SATIETY_MAX))


func set_satiety(pet_id: String, value: float) -> float:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return SATIETY_MAX
	var pet_data := _get_or_create_pet_data(normalized_pet_id)
	var next_satiety := _sanitize_satiety_value(value)
	var changed := false
	if not is_equal_approx(float(pet_data.get(SATIETY_KEY, SATIETY_MAX)), next_satiety):
		pet_data[SATIETY_KEY] = next_satiety
		changed = true
	if next_satiety >= SATIETY_WAKE_THRESHOLD:
		if bool(pet_data.get(SATIETY_EXHAUSTED_KEY, false)) or float(pet_data.get(SATIETY_EXHAUSTION_TIMER_KEY, 0.0)) > 0.0:
			pet_data[SATIETY_EXHAUSTED_KEY] = false
			pet_data[SATIETY_EXHAUSTION_TIMER_KEY] = 0.0
			changed = true
	elif next_satiety > SATIETY_MIN:
		if bool(pet_data.get(SATIETY_EXHAUSTED_KEY, false)):
			var rested_timer := maxf(float(pet_data.get(SATIETY_EXHAUSTION_TIMER_KEY, 0.0)), SATIETY_EXHAUSTION_TELEGRAPH_SECONDS)
			if not is_equal_approx(float(pet_data.get(SATIETY_EXHAUSTION_TIMER_KEY, 0.0)), rested_timer):
				pet_data[SATIETY_EXHAUSTION_TIMER_KEY] = rested_timer
				changed = true
		elif float(pet_data.get(SATIETY_EXHAUSTION_TIMER_KEY, 0.0)) > 0.0:
			pet_data[SATIETY_EXHAUSTION_TIMER_KEY] = 0.0
			changed = true
	if changed:
		_pets[normalized_pet_id] = pet_data
		_dirty = true
	return next_satiety


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
	if delta_seconds <= 0.0:
		return {"changed": false, "active_satiety": get_satiety(active_pet_id)}
	var normalized_active_pet_id := _normalize_pet_id(active_pet_id)
	var changed := false
	var rest_amount := SATIETY_DRAIN_PER_SECOND * SATIETY_REST_RECOVERY_RATIO * delta_seconds * maxf(0.0, rest_recovery_multiplier)
	if normalized_active_pet_id != "":
		if active_resting:
			if rest_amount > 0.0:
				var before_active_rest := get_satiety(normalized_active_pet_id)
				var after_active_rest := set_satiety(normalized_active_pet_id, before_active_rest + rest_amount)
				changed = changed or not is_equal_approx(before_active_rest, after_active_rest)
		else:
			var drain_amount := SATIETY_DRAIN_PER_SECOND * delta_seconds * maxf(0.0, active_drain_multiplier)
			if drain_amount > 0.0:
				var before_active := get_satiety(normalized_active_pet_id)
				var after_active := set_satiety(normalized_active_pet_id, before_active - drain_amount)
				changed = changed or not is_equal_approx(before_active, after_active)
	if rest_amount > 0.0:
		var seen := {}
		for raw_pet_id in battle_slot_pet_ids:
			var rest_pet_id := _normalize_pet_id(str(raw_pet_id))
			if rest_pet_id == "" or rest_pet_id == normalized_active_pet_id or seen.has(rest_pet_id):
				continue
			seen[rest_pet_id] = true
			var before_rest := get_satiety(rest_pet_id)
			var after_rest := set_satiety(rest_pet_id, before_rest + rest_amount)
			changed = changed or not is_equal_approx(before_rest, after_rest)
	return {
		"changed": changed,
		"active_satiety": get_satiety(normalized_active_pet_id),
	}


func advance_satiety_exhaustion(
	pet_id: String,
	delta_seconds: float,
	telegraph_seconds: float = SATIETY_EXHAUSTION_TELEGRAPH_SECONDS,
	enabled: bool = true
) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return {"changed": false, "exhausted": false, "timer": 0.0, "ratio": 0.0}
	var pet_data := _get_or_create_pet_data(normalized_pet_id)
	var current_satiety := get_satiety(normalized_pet_id)
	var before_timer := _sanitize_satiety_exhaustion_timer(
		pet_data.get(SATIETY_EXHAUSTION_TIMER_KEY, 0.0),
		current_satiety
	)
	var before_exhausted := bool(pet_data.get(SATIETY_EXHAUSTED_KEY, false))
	var next_timer := before_timer
	var next_exhausted := before_exhausted
	if not enabled or current_satiety >= SATIETY_WAKE_THRESHOLD:
		next_timer = 0.0
		next_exhausted = false
	elif before_exhausted:
		next_timer = maxf(before_timer, maxf(0.0, telegraph_seconds))
		next_exhausted = true
	elif current_satiety > SATIETY_MIN:
		next_timer = 0.0
		next_exhausted = false
	else:
		next_timer = maxf(0.0, before_timer + maxf(0.0, delta_seconds))
		next_exhausted = next_timer >= maxf(0.0, telegraph_seconds)
	var changed := (
		not is_equal_approx(before_timer, next_timer)
		or before_exhausted != next_exhausted
	)
	if changed:
		pet_data[SATIETY_EXHAUSTION_TIMER_KEY] = next_timer
		pet_data[SATIETY_EXHAUSTED_KEY] = next_exhausted
		_pets[normalized_pet_id] = pet_data
		_dirty = true
	return {
		"changed": changed,
		"exhausted": next_exhausted,
		"timer": next_timer,
		"ratio": _get_satiety_exhaustion_ratio(next_timer, telegraph_seconds),
	}


func is_satiety_exhausted(pet_id: String) -> bool:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "" or get_satiety(normalized_pet_id) >= SATIETY_WAKE_THRESHOLD:
		return false
	var pet_data := _get_existing_pet_data(normalized_pet_id)
	return bool(pet_data.get(SATIETY_EXHAUSTED_KEY, false))


func get_satiety_exhaustion_timer(pet_id: String) -> float:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return 0.0
	var pet_data := _get_existing_pet_data(normalized_pet_id)
	return _sanitize_satiety_exhaustion_timer(
		pet_data.get(SATIETY_EXHAUSTION_TIMER_KEY, 0.0),
		get_satiety(normalized_pet_id)
	)


func get_satiety_exhaustion_ratio(
	pet_id: String,
	telegraph_seconds: float = SATIETY_EXHAUSTION_TELEGRAPH_SECONDS
) -> float:
	return _get_satiety_exhaustion_ratio(get_satiety_exhaustion_timer(pet_id), telegraph_seconds)


func get_satiety_speed_multiplier(pet_id: String) -> float:
	return get_satiety_speed_multiplier_for_value(get_satiety(pet_id))


static func get_satiety_speed_multiplier_for_value(value: float) -> float:
	var satiety := clampf(value, SATIETY_MIN, SATIETY_MAX)
	if satiety > SATIETY_SLOW_START:
		return 1.0
	if satiety >= SATIETY_SLOW_FLOOR_START:
		var ratio := (satiety - SATIETY_SLOW_FLOOR_START) / (SATIETY_SLOW_START - SATIETY_SLOW_FLOOR_START)
		return lerpf(SATIETY_SLOW_MIN_MULTIPLIER, 1.0, ratio)
	return SATIETY_SLOW_MIN_MULTIPLIER


func get_run_ring_core_tier() -> int:
	return clampi(_run_ring_core_tier, 0, LingpetRingCoreRules.MAX_RING_CORE_TIER)


func set_run_ring_core_tier(tier: int) -> void:
	_run_ring_core_tier = clampi(tier, 0, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	if _run_ring_core_tier <= 0:
		_ring_core_offer_cooldown_screens = 0


func upgrade_run_ring_core_tier(target_tier: int = 0) -> bool:
	var current_tier := get_run_ring_core_tier()
	var next_tier := target_tier if target_tier > 0 else current_tier + 1
	next_tier = clampi(next_tier, 1, LingpetRingCoreRules.MAX_RING_CORE_TIER)
	if next_tier <= current_tier:
		return false
	_run_ring_core_tier = next_tier
	_ring_core_offer_cooldown_screens = RING_CORE_OFFER_COOLDOWN_SCREENS
	return true


func get_run_ring_core_cap() -> int:
	return LingpetRingCoreRules.get_ring_core_cap_for_tier(get_run_ring_core_tier())


func get_ring_core_offer_cooldown_screens() -> int:
	return maxi(0, _ring_core_offer_cooldown_screens)


func tick_ring_core_offer_cooldown() -> void:
	if _ring_core_offer_cooldown_screens > 0:
		_ring_core_offer_cooldown_screens -= 1


func configure_reward_context(
	pet_id: String,
	motion_style: String = MOTION_STYLE_PATROL,
	active_skill_base_level: int = 1,
	passive_skill_base_level: int = 1,
	reward_seed: int = 0,
	force_rebuild: bool = false,
	ring_core_cap: int = RING_CORE_CAP_UNCHANGED,
	active_present_id: String = "",
	passive_present_id: String = ""
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
	_resolve_present_unlock_if_needed(normalized_pet_id, REWARD_TYPE_ACTIVE_UNLOCK, active_present_id)
	_resolve_present_unlock_if_needed(normalized_pet_id, REWARD_TYPE_PASSIVE_UNLOCK, passive_present_id)


func set_hatch_stat_roll(pet_id: String, mobility_headstart: float, defense_headstart: float) -> Dictionary:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
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
	var has_roll := bool(pet_data.get(
		"hatch_stat_roll_set",
		pet_data.has("hatch_mobility_headstart") or pet_data.has("hatch_defense_headstart")
	))
	return {
		"mobility": clampf(float(pet_data.get("hatch_mobility_headstart", 0.0)), 0.0, 1.0),
		"defense": clampf(float(pet_data.get("hatch_defense_headstart", 0.0)), 0.0, 1.0),
		"has_roll": has_roll,
	}


static func get_empty_hatch_stat_roll() -> Dictionary:
	return {
		"mobility": 0.0,
		"defense": 0.0,
		"has_roll": false,
	}


static func get_satiety_drain_reduction_pct_for_level(level: int) -> float:
	if level <= 0:
		return 0.0
	var index := clampi(level, 1, SATIETY_DRAIN_REDUCTION_PCT_BY_LEVEL.size()) - 1
	return float(SATIETY_DRAIN_REDUCTION_PCT_BY_LEVEL[index])


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


func _resolve_present_unlock_if_needed(pet_id: String, reward_type: String, present_id: String) -> void:
	var normalized_present_id := present_id.strip_edges()
	if normalized_present_id == "":
		return
	var choice_key := _unlock_choice_key(reward_type)
	if choice_key == "":
		return
	var resolved: Dictionary = get_resolved_unlock_choices(pet_id)
	if resolved.has(choice_key):
		return
	resolve_single_unlock(pet_id, reward_type, normalized_present_id)


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
	# The ring-core-upgrade roster grant is a deliberate flat reward, so enhancement
	# chips do not inflate it (every other affinity source scales with chips).
	var enhancement_multiplier := 1.0 if source == SOURCE_RING_CORE_UPGRADE else get_enhancement_chip_multiplier()
	granted_points *= enhancement_multiplier
	bonus_points *= enhancement_multiplier
	if granted_points <= 0.0:
		_pets[normalized_pet_id] = pet_data
		return _build_result(normalized_pet_id, source, level_before, points_before, 0.0, bonus_points, [], blocked_reason)

	pet_data["affinity_points"] = points_before + granted_points
	var level_rewards: Array[Dictionary] = _apply_level_ups(normalized_pet_id, pet_data)
	if level_rewards.size() > 0:
		_record_bond_level_ups(normalized_pet_id, level_rewards.size())
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


# Existing per-pet reward seed (0 when the pet has no seed yet). The context coordinator
# adopts this on a seed-cache miss so a restored pet keeps its deterministic reward deck /
# unlock-choice shuffle instead of being re-randomized after a save/restore round trip.
func get_reward_seed(pet_id: String) -> int:
	var pet_data := _get_existing_pet_data(_normalize_pet_id(pet_id))
	return int(pet_data.get("reward_seed", 0))


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


# Player-facing "다음 보상" label. Layers run-state context on top of get_next_reward
# so the panel never shows a bare, dead-end "보상 없음":
#   - at Lv.MAX            -> the terminal title (하트 공명)
#   - rewards exhausted    -> "최대 강화 완료" (genuinely nothing left to grant)
#   - sitting at the ring  -> "링코어 강화 시 해금" (a real reward exists, but it is
#     core cap                gated behind the next ring core tier — the user's
#                             "upgraded the ring core but it stayed 보상 없음"
#                             confusion came from previewing this locked reward as
#                             if it were reachable)
#   - otherwise            -> the next reward's own label/title.
# Single source for both owner-surface (TAB panel) and grant-controller (level-up
# toast) so the two paths cannot drift.
func get_next_reward_display_label(pet_id: String) -> String:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return ""
	var level := get_level(normalized_pet_id)
	if level >= MAX_LEVEL:
		return "하트 공명"
	var pet_data := _get_existing_pet_data(normalized_pet_id)
	if pet_data.is_empty():
		# Untracked pet — preview the level-1 reward directly.
		var seed_reward := get_next_reward(normalized_pet_id)
		if seed_reward.has("title"):
			return str(seed_reward.get("title", "하트 공명"))
		return str(seed_reward.get("label", ""))
	_ensure_reward_state(normalized_pet_id, pet_data)
	_pets[normalized_pet_id] = pet_data
	# The immediate next card may resolve to NO_REWARD (a dry draw: maxed stats +
	# maxed/locked skill slots) while real rewards still wait at later levels —
	# unlock cards open new skill slots, and higher ring-core tiers expose more
	# levels. A high starting skill level (e.g. base skill 5/5) makes this gap
	# routine. So scan the deck forward for the next genuinely grantable reward
	# instead of treating the first dry card as terminal.
	var cap := clampi(int(get_run_ring_core_cap()), 0, MAX_LEVEL)
	var next_grantable := _find_next_grantable_reward(pet_data, level)
	if next_grantable.is_empty():
		# The deck has nothing grantable left, BUT a second-slot unlock can still be
		# rolled in (it is no longer a visible deck card). Distinguish three cases:
		# at/above the ring core cap it is gated behind a ring core upgrade; below the
		# cap a surprise unlock can still land, so show a non-spoiler placeholder
		# instead of the terminal "최대 강화 완료"; only when no roll remains is it terminal.
		if _has_pending_rollable_second_unlock(pet_data):
			if level >= cap and cap < MAX_LEVEL:
				return "링코어 강화 시 해금"
			return "교감 보상"
		# Nothing real remains across every future level — genuinely terminal.
		return "최대 강화 완료"
	if int(next_grantable.get("level", MAX_LEVEL)) > cap:
		# A real reward exists, but only above the current ring core cap, so a
		# ring core upgrade is the gate (the "강화했는데 보상 없음" confusion case).
		return "링코어 강화 시 해금"
	if next_grantable.has("title"):
		return str(next_grantable.get("title", "하트 공명"))
	return str(next_grantable.get("label", ""))


# Scans the reward deck forward from current_level and returns the first level
# whose card resolves to a genuinely grantable reward (not NO_REWARD), with the
# resolved card plus its 1-based "level". Every level between current_level and
# that result necessarily resolved to NO_REWARD, which grants nothing and so
# leaves reward counts unchanged — therefore resolving each forward card against
# the pet's CURRENT counts is sufficient and no forward state replay is needed.
# Returns {} when nothing real remains through MAX_LEVEL.
func _find_next_grantable_reward(pet_data: Dictionary, current_level: int) -> Dictionary:
	if pet_data.is_empty():
		return {}
	var deck: Array = pet_data.get("reward_deck", []) as Array
	for probe_level in range(maxi(current_level, 0) + 1, MAX_LEVEL + 1):
		var base_card: Dictionary = get_reward_for_level(probe_level)
		if probe_level > 0 and probe_level <= deck.size() and deck[probe_level - 1] is Dictionary:
			base_card = (deck[probe_level - 1] as Dictionary).duplicate(true)
		var resolved := _resolve_effective_reward_card(pet_data, base_card)
		if str(resolved.get("type", "")) != REWARD_TYPE_NO_REWARD:
			resolved["level"] = probe_level
			return resolved
	return {}


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
			return _apply_opportunity_multiplier(_resolve_ball_hit_gain(tags), pet_data)
		SOURCE_CLICK:
			return _resolve_click_gain(pet_data)
		SOURCE_HATCH:
			return _resolve_hatch_gain(pet_id, pet_data)
		SOURCE_VICTORY:
			return _resolve_victory_gain(pet_id, tags)
		SOURCE_STAGE_CLEAR:
			return _resolve_stage_clear_gain(pet_id)
		SOURCE_RING_CORE_UPGRADE:
			# Flat roster-wide reward when this run's ring core tier rises. No cap / self-seal:
			# the caller fires it once per pet per successful upgrade.
			return {"points": _get_gain_value(SOURCE_RING_CORE_UPGRADE, "points")}
	return {"points": 0.0, "blocked_reason": "unknown_source"}


# Flight pets double the ball-hit opportunity source (click carries its own explicit
# patrol/flight values in GAIN_TABLE and no longer routes through here). ONLY the
# base/reduced hit points scale -- the defense/guard bonus (defense_intercept OR
# ring_dash_block, which flight pets CAN earn via Linkport/ring-dash) is not an
# opportunity reward, so it stays flat. A flight guard hit therefore pays base*2 + bonus
# (e.g. 8*2 + 5 = 21), never (base+bonus)*2 = 26 and never base+bonus = 13 (multiplier off).
# Applied BEFORE the enhancement-chip multiplier in add_points, so chips stack on top.
func _apply_opportunity_multiplier(result: Dictionary, pet_data: Dictionary) -> Dictionary:
	var multiplier := _opportunity_multiplier_for_pet(pet_data)
	if is_equal_approx(multiplier, 1.0):
		return result
	if result.has("points"):
		var bonus_points := float(result.get("bonus_points", 0.0))
		var base_points := float(result.get("points", 0.0)) - bonus_points
		result["points"] = base_points * multiplier + bonus_points
	return result


func _opportunity_multiplier_for_pet(pet_data: Dictionary) -> float:
	var motion_style := _normalize_motion_style(str(pet_data.get("reward_motion_style", MOTION_STYLE_PATROL)))
	return FLIGHT_OPPORTUNITY_MULTIPLIER if motion_style == MOTION_STYLE_FLIGHT else 1.0


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


func _resolve_click_gain(pet_data: Dictionary) -> Dictionary:
	var round_count := int(_round_caps.get(ROUND_CAP_CLICK_COUNT, 0))
	var battle_count := int(_battle_caps.get(BATTLE_CAP_CLICK_COUNT, 0))
	if round_count >= int(_get_gain_value(SOURCE_CLICK, "round_cap")):
		return {"points": 0.0, "blocked_reason": "round_cap"}
	if battle_count >= int(_get_gain_value(SOURCE_CLICK, "battle_cap")):
		return {"points": 0.0, "blocked_reason": "battle_cap"}
	_round_caps[ROUND_CAP_CLICK_COUNT] = round_count + 1
	_battle_caps[BATTLE_CAP_CLICK_COUNT] = battle_count + 1
	# Click is opportunity-based but uses explicit per-style values (patrol 20 / flight 30,
	# a 1.5x design value) instead of the generic ball-hit 2x multiplier. Enhancement chips
	# still stack on top inside add_points.
	var motion_style := _normalize_motion_style(str(pet_data.get("reward_motion_style", MOTION_STYLE_PATROL)))
	var points_key := "flight_points" if motion_style == MOTION_STYLE_FLIGHT else "points"
	return {"points": _get_gain_value(SOURCE_CLICK, points_key)}


func _resolve_victory_gain(pet_id: String, tags: Dictionary) -> Dictionary:
	if bool(_battle_caps.get(BATTLE_CAP_VICTORY_PAID, false)):
		return {"points": 0.0, "blocked_reason": "victory_already_paid"}
	if tags.has("eligible") and not bool(tags.get("eligible", false)):
		return {"points": 0.0, "blocked_reason": "ineligible"}
	if not _is_victory_participation_eligible(pet_id):
		return {"points": 0.0, "blocked_reason": "ineligible"}
	_battle_caps[BATTLE_CAP_VICTORY_PAID] = true
	return {"points": _get_gain_value(SOURCE_VICTORY, "points")}


func _resolve_stage_clear_gain(pet_id: String) -> Dictionary:
	# Stage clear == the player-won match-finish moment (one boss per stage). Mirrors victory:
	# participation-gated (50%+ rounds) and self-sealing once per battle, paid ON TOP of the
	# +20 victory award. Style-agnostic floor (no flight multiplier); enhancement chips still
	# stack in add_points.
	if bool(_battle_caps.get(BATTLE_CAP_STAGE_CLEAR_PAID, false)):
		return {"points": 0.0, "blocked_reason": "stage_clear_already_paid"}
	if not _is_victory_participation_eligible(pet_id):
		return {"points": 0.0, "blocked_reason": "ineligible"}
	_battle_caps[BATTLE_CAP_STAGE_CLEAR_PAID] = true
	return {"points": _get_gain_value(SOURCE_STAGE_CLEAR, "points")}


func _resolve_hatch_gain(_pet_id: String, pet_data: Dictionary) -> Dictionary:
	if bool(pet_data.get("hatch_bonus_granted", false)):
		return {"points": 0.0, "blocked_reason": "hatch_bonus_granted"}
	pet_data["hatch_bonus_granted"] = true
	return {"points": _get_gain_value(SOURCE_HATCH, "points")}


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
	# Clamp banked points at the ring-core cap ceiling: at a temporary cap the affinity
	# points must NOT overshoot the next (locked) level's requirement -- the bar shows
	# 50/50, not 1054/50. Affinity earned beyond the ceiling is intentionally wasted so
	# the ring-core stays the investment that makes affinity count (a cap upgrade then
	# grants only a bounded head start, not a banked level burst). The absolute Lv.30
	# cap still discards all overflow.
	if level >= MAX_LEVEL:
		points = 0.0
	elif level >= level_cap:
		points = minf(points, get_requirement_for_level(level))
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
	# Probabilistic second-slot unlock: once the skill-level prerequisite is met, an
	# independent per-level roll can replace this level's deck card with a second
	# active/passive unlock. Done here (the single authoritative grant path used by
	# both live level-up and replay) so real grants and save-restore replay agree.
	var rolled_unlock := _maybe_roll_second_unlock_card(pet_data, level)
	if not rolled_unlock.is_empty():
		base_card = rolled_unlock
	var awarded_card := _resolve_effective_reward_card(pet_data, base_card)
	awarded_card["level"] = level
	if level >= MAX_LEVEL:
		awarded_card["title"] = "하트 공명"
	_apply_reward_to_pet_counts(pet_data, awarded_card)
	var history: Array = pet_data.get("reward_history", []) as Array
	history.append(awarded_card.duplicate(true))
	pet_data["reward_history"] = history
	return awarded_card


# Decide whether this level grants a second-slot unlock instead of its deck card.
# Returns the unlock card to inject, or {} to keep the normal deck card. The
# prerequisite (combined first active + first passive effective skill level) and
# the per-level roll are both evaluated against the pet's CURRENT cumulative
# counts, so this is deterministic across replay. At most ONE unlock is injected
# per level (active takes priority; an unrolled/blocked passive simply re-rolls
# on the next level), since a level grants a single reward.
func _maybe_roll_second_unlock_card(pet_data: Dictionary, level: int) -> Dictionary:
	if not _second_unlock_prerequisite_met(pet_data):
		return {}
	var counts := _reward_counts_snapshot(pet_data)
	# A second-slot unlock can never precede its first-slot unlock; gating on BOTH
	# first unlocks also guarantees the roll can't displace the fixed Lv1/Lv2 first
	# active/passive unlock deck cards (e.g. a high-base 5/5 pet meets the skill-sum
	# prerequisite immediately, so without this guard the Lv1 roll could eat the
	# first active unlock).
	if not bool(counts.get("active_unlocked", false)) or not bool(counts.get("passive_unlocked", false)):
		return {}
	var seed := int(pet_data.get("reward_seed", 0))
	if (
		not bool(counts.get("second_active_unlocked", false))
		and _pet_has_second_active_skill(pet_data)
		and _second_unlock_roll_hits(seed, level, SECOND_UNLOCK_ROLL_SALT_ACTIVE)
	):
		return _make_reward_card(REWARD_TYPE_SECOND_ACTIVE_UNLOCK)
	if (
		not bool(counts.get("second_passive_unlocked", false))
		and _pet_has_second_passive_skill(pet_data)
		and _second_unlock_roll_hits(seed, level, SECOND_UNLOCK_ROLL_SALT_PASSIVE)
	):
		return _make_reward_card(REWARD_TYPE_SECOND_PASSIVE_UNLOCK)
	return {}


# Combined FIRST active + FIRST passive effective skill level (base + affinity
# bonus). Second-slot bonuses are intentionally excluded -- they only exist after
# a second unlock, which is exactly what this gate guards.
func _second_unlock_prerequisite_met(pet_data: Dictionary) -> bool:
	var counts := _reward_counts_snapshot(pet_data)
	var active_level := int(pet_data.get("active_skill_base_level", 1)) + int(counts.get("active_skill_bonus", 0))
	var passive_level := int(pet_data.get("passive_skill_base_level", 1)) + int(counts.get("passive_skill_bonus", 0))
	return active_level + passive_level >= SECOND_UNLOCK_SKILL_LEVEL_SUM_REQUIREMENT


func _second_unlock_roll_hits(seed: int, level: int, salt: int) -> bool:
	var roll_seed := maxi(1, int((seed + level * 7919 + salt) % REWARD_DECK_SEED_MOD))
	roll_seed = _advance_reward_seed(roll_seed)
	return (roll_seed % 100) < SECOND_UNLOCK_ROLL_CHANCE_PCT


# True when the prerequisite is met and at least one second-slot unlock the pet
# actually owns is still locked -- i.e. a future level-up roll can still grant it.
# Used only by the "다음 보상" preview so a roll-eligible pet never previews as a
# dead-end terminal even when the deck itself has nothing grantable left.
func _has_pending_rollable_second_unlock(pet_data: Dictionary) -> bool:
	if not _second_unlock_prerequisite_met(pet_data):
		return false
	var counts := _reward_counts_snapshot(pet_data)
	if not bool(counts.get("second_active_unlocked", false)) and _pet_has_second_active_skill(pet_data):
		return true
	if not bool(counts.get("second_passive_unlocked", false)) and _pet_has_second_passive_skill(pet_data):
		return true
	return false


func _resolve_effective_reward_card(pet_data: Dictionary, card: Dictionary) -> Dictionary:
	var card_type := str(card.get("type", ""))
	if _can_apply_reward_card(pet_data, card):
		return card.duplicate(true)
	var replacement := _select_replacement_reward_card(pet_data)
	if replacement.is_empty():
		return {
			"type": REWARD_TYPE_NO_REWARD,
			"label": str(LABEL_BY_REWARD_TYPE.get(REWARD_TYPE_NO_REWARD, "보상 없음")),
			"replaced_type": card_type,
			"no_reward": true,
		}
	var replacement_card := replacement.duplicate(true)
	replacement_card["replaced_type"] = card_type
	return replacement_card


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
			# A pet whose catalog active pool only has one skill has nothing to put in
			# the second active slot, so granting the unlock would set the flag but leave
			# an empty second-active card (the reconciler erases the primary from the
			# candidate pool, leaving zero candidates). WIP pets ship with one active
			# skill today and their second skill is authored later; gating on pool size
			# auto-enables this unlock the moment a second active skill lands, with no
			# further code change. The reward level is recovered into the next available
			# reward by _select_replacement_reward_card.
			return not bool(counts.get("second_active_unlocked", false)) and _pet_has_second_active_skill(pet_data)
		REWARD_TYPE_SECOND_PASSIVE_UNLOCK:
			return not bool(counts.get("second_passive_unlocked", false)) and _pet_has_second_passive_skill(pet_data)
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


# When a drawn card cannot apply (maxed stat, locked/maxed skill, already-done
# unlock), recover the level into the next still-available reward instead of
# dead-drawing straight into NO_REWARD. The reward deck demands more stat cards
# (14) than the stat caps allow (12), and a pet hatched with high starting skill
# levels also leaves skill-bonus cards unusable, so a stat-ONLY fallback left
# several mid/late levels (and every level past the reward ceiling) showing
# "보상 없음" with no recourse — raising the ring core cap only exposed more empty
# levels. Stats run first (keeps the stat-reward feel); then unused skill-bonus
# capacity (slot 1, then slot 2 once its unlock has landed). {} means the pet is
# genuinely fully enhanced — the only true NO_REWARD case now.
func _select_replacement_reward_card(pet_data: Dictionary) -> Dictionary:
	var motion_style := _normalize_motion_style(str(pet_data.get("reward_motion_style", MOTION_STYLE_PATROL)))
	var candidates: Array[Dictionary] = []
	if motion_style == MOTION_STYLE_PATROL:
		candidates.append(_make_reward_card(REWARD_TYPE_MOBILITY))
		candidates.append(_make_reward_card(REWARD_TYPE_GAUGE))
		candidates.append(_make_reward_card(REWARD_TYPE_DEFENSE))
	else:
		candidates.append(_make_reward_card(REWARD_TYPE_GAUGE))
		candidates.append(_make_reward_card(REWARD_TYPE_MOBILITY))
	candidates.append(_make_reward_card(REWARD_TYPE_ACTIVE_SKILL, 1))
	candidates.append(_make_reward_card(REWARD_TYPE_PASSIVE_SKILL, 1))
	candidates.append(_make_reward_card(REWARD_TYPE_ACTIVE_SKILL, 2))
	candidates.append(_make_reward_card(REWARD_TYPE_PASSIVE_SKILL, 2))
	for candidate in candidates:
		if _can_apply_reward_card(pet_data, candidate):
			return candidate
	return {}


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
	# Second-slot unlocks are NO LONGER fixed deck cards. They are granted by a
	# per-level probability roll once the combined first active + first passive
	# effective skill level reaches SECOND_UNLOCK_SKILL_LEVEL_SUM_REQUIREMENT
	# (see _maybe_roll_second_unlock_card), so their appearance level is
	# intentionally unpredictable. The two former pinned slots are returned to the
	# Lv16-25 region as ordinary skill/stat cards, making it a single 10-card
	# shuffled band; an injected unlock simply displaces that level's drawn card.
	level_cards.append_array(_shuffle_reward_card_band([
		_make_reward_card(REWARD_TYPE_ACTIVE_SKILL, 1),
		_make_reward_card(REWARD_TYPE_PASSIVE_SKILL, 1),
		_make_reward_card(REWARD_TYPE_PASSIVE_SKILL, 1),
		_make_reward_card(REWARD_TYPE_GAUGE),
		_make_reward_card(support_card_type),
		_make_reward_card(REWARD_TYPE_ACTIVE_SKILL, 1),
		_make_reward_card(REWARD_TYPE_MOBILITY),
		_make_reward_card(REWARD_TYPE_PASSIVE_SKILL, 1),
		_make_reward_card(REWARD_TYPE_GAUGE),
		_make_reward_card(REWARD_TYPE_MOBILITY),
	], seed, 16))
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


func _pet_has_second_active_skill(pet_data: Dictionary) -> bool:
	var pet_id := str(pet_data.get("pet_id", "")).strip_edges()
	if pet_id == "":
		# Unknown pet: never suppress a real unlock on missing context.
		return true
	return LingpetCatalog.get_active_skill_pool(pet_id).size() >= 2


func _pet_has_second_passive_skill(pet_data: Dictionary) -> bool:
	var pet_id := str(pet_data.get("pet_id", "")).strip_edges()
	if pet_id == "":
		return true
	return LingpetCatalog.get_passive_skill_pool(pet_id).size() >= 2


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


func _get_or_create_pet_data(pet_id: String) -> Dictionary:
	if _pets.has(pet_id):
		var existing: Variant = _pets.get(pet_id, {})
		if existing is Dictionary:
			return existing as Dictionary
	var pet_data := {
		"pet_id": pet_id,
		"affinity_points": 0.0,
		"affinity_level": 0,
		SATIETY_KEY: SATIETY_MAX,
		SATIETY_EXHAUSTED_KEY: false,
		SATIETY_EXHAUSTION_TIMER_KEY: 0.0,
		"hatch_bonus_granted": false,
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


func _sanitize_satiety_value(value: Variant) -> float:
	return clampf(float(value), SATIETY_MIN, SATIETY_MAX)


func _sanitize_satiety_exhaustion_timer(value: Variant, satiety: float) -> float:
	if satiety >= SATIETY_WAKE_THRESHOLD:
		return 0.0
	return maxf(0.0, float(value))


func _get_satiety_exhaustion_ratio(timer: float, telegraph_seconds: float) -> float:
	var duration := maxf(0.001, telegraph_seconds)
	return clampf(maxf(0.0, timer) / duration, 0.0, 1.0)


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
