extends RefCounted

const SNAPSHOT_SCHEMA_VERSION := 9
const PRE_VISION_BURN_SCHEMA_VERSION := 8
const LEGACY_SINGLE_PHASE_SCHEMA_VERSION := 7
const SNAPSHOT_POLICY_CURRENT := "current"
const SNAPSHOT_POLICY_RESET_LEGACY_SINGLE_PHASE := "reset_legacy_single_phase"
const SNAPSHOT_POLICY_REJECT_UNSUPPORTED := "reject_unsupported"
const DEFAULT_CHANCE_GEMS := 3
const MAX_CHANCE_GEMS := 3

var _run_id := ""
var _gold := 0
var _muhon := 0
var _chance_gems := 0
var _phases: Array[Dictionary] = []
var _active_phase_index := 0
var _revealed_floor := 0
var _skipped_boss_ids: Array[String] = []
var _burned_vision_boss_ids: Array[String] = []
var _start_card_result: Dictionary = {
	"consumed": true,
	"picked_perk_id": "",
	"picked_kind": "",
	"offer_ids": PackedStringArray(),
}


func begin(
	run_id: String,
	economy: Dictionary = {},
	phases: Array = [],
	progress: Dictionary = {}
) -> bool:
	reset()
	_run_id = run_id.strip_edges()
	if _run_id.is_empty():
		return false
	_import_economy(economy)
	_phases = _sanitize_phases(phases)
	_active_phase_index = int(progress.get("active_phase_index", 0))
	if not _phases.is_empty() and (
		_active_phase_index < 0 or _active_phase_index >= _phases.size()
	):
		reset()
		return false
	var phase_floor_start := int(
		_phases[_active_phase_index].get("floor_start", 0)
		if not _phases.is_empty()
		else 0
	)
	var requested_revealed_floor := maxi(0, int(progress.get("revealed_floor", phase_floor_start)))
	var maximum_floor := maxi(phase_floor_start, requested_revealed_floor)
	for phase in _phases:
		maximum_floor = maxi(maximum_floor, int(phase.get("floor_end", maximum_floor)))
	_revealed_floor = clampi(
		requested_revealed_floor,
		0,
		maximum_floor
	)
	_skipped_boss_ids.assign(_sanitize_ids(progress.get("skipped_boss_ids", [])))
	_burned_vision_boss_ids.assign(_sanitize_ids(progress.get("burned_vision_boss_ids", [])))
	_start_card_result = _sanitize_start_card_result(progress.get("start_card", {}))
	return true


func reset() -> void:
	_run_id = ""
	_gold = 0
	_muhon = 0
	_chance_gems = 0
	_phases.clear()
	_active_phase_index = 0
	_revealed_floor = 0
	_skipped_boss_ids.clear()
	_burned_vision_boss_ids.clear()
	_start_card_result = _default_start_card_result()


func restore_snapshot(snapshot: Dictionary) -> bool:
	if snapshot_restore_policy(snapshot) != SNAPSHOT_POLICY_CURRENT:
		return false
	var run_id := str(snapshot.get("run_id", "")).strip_edges()
	if run_id.is_empty():
		return false
	var economy_variant: Variant = snapshot.get("run_state", {})
	if not (economy_variant is Dictionary):
		return false
	var map_graph_variant: Variant = snapshot.get("map_graph", {})
	if not (map_graph_variant is Dictionary):
		return false
	var phases_variant: Variant = (map_graph_variant as Dictionary).get("phases", [])
	if not (phases_variant is Array) or (phases_variant as Array).is_empty():
		return false
	var progress_variant: Variant = snapshot.get("run_progress", {})
	if not (progress_variant is Dictionary):
		return false
	return begin(
		run_id,
		economy_variant as Dictionary,
		phases_variant as Array,
		progress_variant as Dictionary
	)


func export_snapshot_fields() -> Dictionary:
	return {
		"schema_version": SNAPSHOT_SCHEMA_VERSION,
		"run_id": _run_id,
		"map_graph": {"phases": _phases.duplicate(true)},
		"run_state": export_economy(),
		"run_progress": {
			"active_phase_index": _active_phase_index,
			"revealed_floor": _revealed_floor,
			"skipped_boss_ids": _skipped_boss_ids.duplicate(),
			"burned_vision_boss_ids": _burned_vision_boss_ids.duplicate(),
			"start_card": _start_card_result.duplicate(true),
		},
	}


func set_phases(phases: Array) -> bool:
	var sanitized := _sanitize_phases(phases)
	if sanitized.is_empty():
		return false
	_phases = sanitized
	_active_phase_index = mini(_active_phase_index, _phases.size() - 1)
	return true


func get_phases() -> Array[Dictionary]:
	return _phases.duplicate(true)


func set_active_phase_index(phase_index: int) -> bool:
	if phase_index < 0 or phase_index >= _phases.size():
		return false
	_active_phase_index = phase_index
	return true


func get_active_phase_index() -> int:
	return _active_phase_index


func reveal_floor(floor_number: int) -> bool:
	var normalized_floor := maxi(0, floor_number)
	if normalized_floor <= _revealed_floor:
		return false
	_revealed_floor = normalized_floor
	return true


func get_revealed_floor() -> int:
	return _revealed_floor


static func snapshot_restore_policy(snapshot: Dictionary) -> String:
	var schema_version := int(snapshot.get("schema_version", -1))
	if schema_version in [SNAPSHOT_SCHEMA_VERSION, PRE_VISION_BURN_SCHEMA_VERSION]:
		return SNAPSHOT_POLICY_CURRENT
	if schema_version == LEGACY_SINGLE_PHASE_SCHEMA_VERSION:
		return SNAPSHOT_POLICY_RESET_LEGACY_SINGLE_PHASE
	return SNAPSHOT_POLICY_REJECT_UNSUPPORTED


func get_run_id() -> String:
	return _run_id


func has_started() -> bool:
	return not _run_id.is_empty()


func export_economy() -> Dictionary:
	return {
		"gold": _gold,
		"muhon": _muhon,
		"chance_gems": _chance_gems,
	}


func apply_reward_bundle(reward_bundle: Dictionary) -> Dictionary:
	var applied := {
		"gold": maxi(0, int(reward_bundle.get("gold", 0))),
		"muhon": maxi(0, int(reward_bundle.get("muhon", 0))),
		"chance_gems": maxi(0, int(reward_bundle.get("chance_gems", 0))),
	}
	_gold += int(applied.gold)
	_muhon += int(applied.muhon)
	_chance_gems = mini(MAX_CHANCE_GEMS, _chance_gems + int(applied.chance_gems))
	return {
		"applied": applied,
		"balances": export_economy(),
	}


func can_afford(costs: Dictionary) -> Dictionary:
	var normalized := {
		"gold": maxi(0, int(costs.get("gold", 0))),
		"muhon": maxi(0, int(costs.get("muhon", 0))),
	}
	for currency in ["gold", "muhon"]:
		var balance := _gold if currency == "gold" else _muhon
		var required := int(normalized.get(currency, 0))
		if balance < required:
			return {
				"accepted": false,
				"reason": "insufficient_%s" % currency,
				"currency": currency,
				"required": required,
				"balance": balance,
				"shortfall": required - balance,
				"costs": normalized,
			}
	return {
		"accepted": true,
		"reason": "affordable",
		"costs": normalized,
		"balances": export_economy(),
	}


func apply_economy_transaction(costs: Dictionary, rewards: Dictionary = {}) -> Dictionary:
	var affordability := can_afford(costs)
	if not bool(affordability.get("accepted", false)):
		return affordability
	var normalized_costs: Dictionary = affordability.get("costs", {})
	_gold -= int(normalized_costs.get("gold", 0))
	_muhon -= int(normalized_costs.get("muhon", 0))
	var reward_result := apply_reward_bundle(rewards)
	return {
		"accepted": true,
		"reason": "applied",
		"costs": normalized_costs.duplicate(true),
		"rewards": reward_result.get("applied", {}),
		"balances": export_economy(),
	}


func get_chance_gems() -> int:
	return _chance_gems


func mark_boss_skipped(boss_slot_id: String) -> bool:
	var normalized := boss_slot_id.strip_edges()
	if normalized.is_empty() or _skipped_boss_ids.has(normalized):
		return false
	_skipped_boss_ids.append(normalized)
	return true


func get_skipped_boss_ids() -> Array[String]:
	return _skipped_boss_ids.duplicate()


func mark_vision_boss_burned(boss_slot_id: String) -> bool:
	var normalized := boss_slot_id.strip_edges()
	if normalized.is_empty() or _burned_vision_boss_ids.has(normalized):
		return false
	_burned_vision_boss_ids.append(normalized)
	return true


func unmark_vision_boss_burned(boss_slot_id: String) -> bool:
	var normalized := boss_slot_id.strip_edges()
	if not _burned_vision_boss_ids.has(normalized):
		return false
	_burned_vision_boss_ids.erase(normalized)
	return true


func get_burned_vision_boss_ids() -> Array[String]:
	return _burned_vision_boss_ids.duplicate()


func record_start_card_result(result: Dictionary) -> bool:
	if not has_started():
		return false
	var sanitized := _sanitize_start_card_result(result)
	var picked_perk_id := str(sanitized.get("picked_perk_id", ""))
	var picked_kind := str(sanitized.get("picked_kind", ""))
	var offer_ids := sanitized.get("offer_ids", PackedStringArray()) as PackedStringArray
	if (
		not bool(sanitized.get("consumed", false))
		or picked_perk_id.is_empty()
		or picked_kind not in ["chosik", "mugong"]
		or not offer_ids.has(picked_perk_id)
	):
		return false
	var existing_id := str(_start_card_result.get("picked_perk_id", ""))
	if not existing_id.is_empty():
		return _start_card_result == sanitized
	_start_card_result = sanitized
	return true


func get_start_card_result() -> Dictionary:
	return _start_card_result.duplicate(true)


func consume_chance_gem() -> Dictionary:
	if _chance_gems <= 0:
		return {"accepted": false, "remaining": 0, "reason": "empty"}
	_chance_gems -= 1
	return {"accepted": true, "remaining": _chance_gems, "reason": "consumed"}


func _import_economy(economy: Dictionary) -> void:
	_gold = maxi(0, int(economy.get("gold", 0)))
	_muhon = maxi(0, int(economy.get("muhon", 0)))
	_chance_gems = clampi(
		int(economy.get("chance_gems", DEFAULT_CHANCE_GEMS)),
		0,
		MAX_CHANCE_GEMS
	)


func _sanitize_phases(value: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for phase_variant in value:
		if phase_variant is Dictionary:
			result.append((phase_variant as Dictionary).duplicate(true))
	return result


func _sanitize_ids(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value as Array:
			var normalized := str(entry).strip_edges()
			if not normalized.is_empty() and not result.has(normalized):
				result.append(normalized)
	return result


func _default_start_card_result() -> Dictionary:
	return {
		"consumed": true,
		"picked_perk_id": "",
		"picked_kind": "",
		"offer_ids": PackedStringArray(),
	}


func _sanitize_start_card_result(value: Variant) -> Dictionary:
	var result := _default_start_card_result()
	if not (value is Dictionary):
		return result
	var source := value as Dictionary
	result["consumed"] = bool(source.get("consumed", true))
	result["picked_perk_id"] = str(source.get("picked_perk_id", "")).strip_edges()
	var picked_kind := str(source.get("picked_kind", "")).strip_edges()
	result["picked_kind"] = picked_kind if picked_kind in ["chosik", "mugong"] else ""
	var offer_ids := PackedStringArray()
	var offer_value: Variant = source.get("offer_ids", [])
	if offer_value is Array or offer_value is PackedStringArray:
		for entry in offer_value:
			var normalized := str(entry).strip_edges()
			if not normalized.is_empty() and not offer_ids.has(normalized):
				offer_ids.append(normalized)
	result["offer_ids"] = offer_ids
	return result
