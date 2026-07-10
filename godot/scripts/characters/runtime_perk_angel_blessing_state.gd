extends RefCounted

const PERK_ID := "angel_blessing"
const DEFAULT_BUFF_PCT := 30.0
const MIN_ROLL_FACE := 1
const MAX_ROLL_FACE := 3

const BUFF_PADDLE_SIZE := "paddle_size"
const BUFF_GAUGE_MAX := "gauge_max"
const BUFF_ITEM_COOLDOWN := "item_cooldown"
const BUFF_ACTIVE_COOLDOWN := "active_cooldown"
const BUFF_DASH_COOLDOWN := "dash_cooldown"
const BUFF_MOVE_SPEED := "move_speed"

const BUFF_IDS := [
	BUFF_PADDLE_SIZE,
	BUFF_GAUGE_MAX,
	BUFF_ITEM_COOLDOWN,
	BUFF_ACTIVE_COOLDOWN,
	BUFF_DASH_COOLDOWN,
	BUFF_MOVE_SPEED,
]
const POSITIVE_BUFF_IDS := [
	BUFF_PADDLE_SIZE,
	BUFF_GAUGE_MAX,
	BUFF_MOVE_SPEED,
]
const REDUCTION_BUFF_IDS := [
	BUFF_ITEM_COOLDOWN,
	BUFF_ACTIVE_COOLDOWN,
	BUFF_DASH_COOLDOWN,
]

var _rng := RandomNumberGenerator.new()
var _buff_pct := DEFAULT_BUFF_PCT
var _active_stage := 0
var _roll_face := 0
var _active_buff_ids: Array[String] = []
var _triggered_stages: Dictionary = {}
var _revision := 0


func _init() -> void:
	_rng.randomize()


func reset() -> void:
	_active_stage = 0
	_roll_face = 0
	_active_buff_ids.clear()
	_triggered_stages.clear()
	_revision += 1


func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value


func set_buff_pct(value: float) -> void:
	_buff_pct = maxf(0.0, value)


func get_buff_pct() -> float:
	return _buff_pct


func get_all_buff_ids() -> Array[String]:
	return _copy_string_array(BUFF_IDS)


func get_eligible_buff_ids(skill_cooldown_eligible: bool = true) -> Array[String]:
	var eligible: Array[String] = get_all_buff_ids()
	if not skill_cooldown_eligible:
		eligible.erase(BUFF_ACTIVE_COOLDOWN)
	return eligible


func roll_for_stage(
	stage: int,
	eligible_buff_ids: Array = [],
	forced_face: int = 0,
	forced_candidate_order: Array = []
) -> Dictionary:
	if stage < 1:
		return _build_roll_result(false, "invalid_stage")
	if has_triggered_stage(stage):
		return _build_roll_result(false, "already_triggered")

	var eligible: Array[String] = _normalize_eligible_buff_ids(eligible_buff_ids)
	if eligible.is_empty():
		return _build_roll_result(false, "no_eligible_buffs")

	var face: int = forced_face
	if face <= 0:
		face = _rng.randi_range(MIN_ROLL_FACE, MAX_ROLL_FACE)
	face = clampi(face, MIN_ROLL_FACE, mini(MAX_ROLL_FACE, eligible.size()))

	var candidate_order: Array[String] = _build_candidate_order(eligible, forced_candidate_order)
	var selected: Array[String] = []
	for index: int in range(face):
		selected.append(candidate_order[index])

	_active_stage = stage
	_roll_face = face
	_active_buff_ids = selected
	_triggered_stages[stage] = true
	_revision += 1
	return _build_roll_result(true, "rolled")


func has_triggered_stage(stage: int) -> bool:
	return bool(_triggered_stages.get(stage, false))


func is_buff_active(buff_id: String) -> bool:
	return buff_id.strip_edges() in _active_buff_ids


func get_multiplier_for_buff(buff_id: String) -> float:
	var clean_id: String = buff_id.strip_edges()
	if not is_buff_active(clean_id):
		return 1.0
	var magnitude: float = _buff_pct / 100.0
	if clean_id in POSITIVE_BUFF_IDS:
		return 1.0 + magnitude
	if clean_id in REDUCTION_BUFF_IDS:
		return maxf(0.0, 1.0 - magnitude)
	return 1.0


func get_active_stage() -> int:
	return _active_stage


func get_roll_face() -> int:
	return _roll_face


func get_active_buff_ids() -> Array[String]:
	return _active_buff_ids.duplicate()


func get_triggered_stages() -> Array[int]:
	var stages: Array[int] = []
	for stage_value: Variant in _triggered_stages.keys():
		stages.append(int(stage_value))
	stages.sort()
	return stages


func get_revision() -> int:
	return _revision


func get_multiplier_snapshot() -> Dictionary:
	var multipliers: Dictionary = {}
	for buff_id: String in BUFF_IDS:
		multipliers[buff_id] = get_multiplier_for_buff(buff_id)
	return multipliers


func get_snapshot() -> Dictionary:
	return {
		"perk_id": PERK_ID,
		"buff_pct": _buff_pct,
		"active_stage": _active_stage,
		"roll_face": _roll_face,
		"active_buff_ids": get_active_buff_ids(),
		"multipliers": get_multiplier_snapshot(),
		"triggered_stages": get_triggered_stages(),
		"revision": _revision,
	}


func _normalize_eligible_buff_ids(values: Array) -> Array[String]:
	var source: Array = values if not values.is_empty() else BUFF_IDS
	var normalized: Array[String] = []
	for value: Variant in source:
		var buff_id: String = str(value).strip_edges()
		if buff_id in BUFF_IDS and buff_id not in normalized:
			normalized.append(buff_id)
	return normalized


func _build_candidate_order(eligible: Array[String], forced_order: Array) -> Array[String]:
	if forced_order.is_empty():
		var shuffled: Array[String] = eligible.duplicate()
		_shuffle_with_rng(shuffled)
		return shuffled

	var ordered: Array[String] = []
	for value: Variant in forced_order:
		var buff_id: String = str(value).strip_edges()
		if buff_id in eligible and buff_id not in ordered:
			ordered.append(buff_id)
	for buff_id: String in eligible:
		if buff_id not in ordered:
			ordered.append(buff_id)
	return ordered


func _shuffle_with_rng(values: Array[String]) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = _rng.randi_range(0, index)
		var previous: String = values[index]
		values[index] = values[swap_index]
		values[swap_index] = previous


func _build_roll_result(rolled: bool, reason: String) -> Dictionary:
	return {
		"rolled": rolled,
		"reason": reason,
		"active_stage": _active_stage,
		"roll_face": _roll_face,
		"active_buff_ids": get_active_buff_ids(),
		"revision": _revision,
	}


func _copy_string_array(values: Array) -> Array[String]:
	var copied: Array[String] = []
	for value: Variant in values:
		copied.append(str(value))
	return copied
