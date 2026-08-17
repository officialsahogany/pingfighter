extends RefCounted

const SNAPSHOT_SCHEMA_VERSION := 5
const DEFAULT_CHANCE_GEMS := 3
const MAX_CHANCE_GEMS := 3

var _run_id := ""
var _gold := 0
var _muhon := 0
var _chance_gems := 0
var _phases: Array[Dictionary] = []
var _skipped_boss_ids: Array[String] = []


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
	_skipped_boss_ids.assign(_sanitize_ids(progress.get("skipped_boss_ids", [])))
	return true


func reset() -> void:
	_run_id = ""
	_gold = 0
	_muhon = 0
	_chance_gems = 0
	_phases.clear()
	_skipped_boss_ids.clear()


func restore_snapshot(snapshot: Dictionary) -> bool:
	if int(snapshot.get("schema_version", -1)) != SNAPSHOT_SCHEMA_VERSION:
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
		"run_progress": {"skipped_boss_ids": _skipped_boss_ids.duplicate()},
	}


func set_phases(phases: Array) -> bool:
	var sanitized := _sanitize_phases(phases)
	if sanitized.is_empty():
		return false
	_phases = sanitized
	return true


func get_phases() -> Array[Dictionary]:
	return _phases.duplicate(true)


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
