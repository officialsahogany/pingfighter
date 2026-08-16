extends RefCounted

const SNAPSHOT_SCHEMA_VERSION := 2
const DEFAULT_CHANCE_GEMS := 3
const MAX_CHANCE_GEMS := 3

var _run_id := ""
var _gold := 0
var _muhon := 0
var _chance_gems := 0
var _phases: Array[Dictionary] = []


func begin(run_id: String, economy: Dictionary = {}, phases: Array = []) -> bool:
	reset()
	_run_id = run_id.strip_edges()
	if _run_id.is_empty():
		return false
	_import_economy(economy)
	_phases = _sanitize_phases(phases)
	return true


func reset() -> void:
	_run_id = ""
	_gold = 0
	_muhon = 0
	_chance_gems = 0
	_phases.clear()


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
	return begin(run_id, economy_variant as Dictionary, phases_variant as Array)


func export_snapshot_fields() -> Dictionary:
	return {
		"schema_version": SNAPSHOT_SCHEMA_VERSION,
		"run_id": _run_id,
		"map_graph": {"phases": _phases.duplicate(true)},
		"run_state": export_economy(),
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


func get_chance_gems() -> int:
	return _chance_gems


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
