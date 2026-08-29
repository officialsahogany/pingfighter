extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")
const TowerAscentFeatureFlags := preload("res://scripts/tower_ascent/tower_ascent_feature_flags.gd")

const MUGONG_ITEM_GRANTS := [
	{"perk_id": "master", "item_id": "wall"},
	{"perk_id": "neural_helmet", "item_id": "aipill"},
	{"perk_id": "reinforced_boomerang_gauntlet", "item_id": "boomerang"},
]

var _processed_entries: Dictionary = {}
var _last_result: Dictionary = {}


func reset() -> void:
	_processed_entries.clear()
	_last_result.clear()


func on_ball_spawn_intro_finished(
	runtime_state: Object,
	owner: Object,
	registry: Object
) -> Dictionary:
	if runtime_state == null or owner == null or registry == null:
		return _remember_result(_build_result(0, false, "missing_context"))

	var stage: int = _get_current_stage(runtime_state, owner)
	if stage <= 0:
		return _remember_result(_build_result(stage, false, "invalid_stage"))
	var entry: Dictionary = _resolve_battle_entry(stage, registry)
	var entry_key: String = str(entry.get("entry_key", ""))
	if entry_key.is_empty():
		return _remember_result(_build_result(stage, false, "invalid_battle_entry", entry))
	if _processed_entries.has(entry_key):
		return _remember_result(_build_result(stage, false, "already_processed", entry))

	# A valid stage intro owns exactly one grant opportunity. Consume it before
	# checking ownership, inventory capacity, or runtime availability so a rally
	# restart cannot turn a skipped entry into a mid-stage grant.
	_processed_entries[entry_key] = entry.duplicate(true)
	var result: Dictionary = _build_result(stage, true, "processed", entry)
	var owned_grants: Array[Dictionary] = []
	for grant_value: Variant in MUGONG_ITEM_GRANTS:
		var grant: Dictionary = grant_value
		var perk_id: String = str(grant.get("perk_id", ""))
		if _get_runtime_skill_level(runtime_state, perk_id) <= 0:
			continue
		owned_grants.append(grant)
		(result["owned_perk_ids"] as Array).append(perk_id)

	if owned_grants.is_empty():
		result["reason"] = "no_owned_mugong"
		return _remember_result(result)

	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime == null or not active_item_runtime.has_method("grant_item_to_slot"):
		result["reason"] = "active_item_runtime_unavailable"
		for grant: Dictionary in owned_grants:
			_record_skipped_grant(result, grant, "active_item_runtime_unavailable")
		return _remember_result(result)

	for grant: Dictionary in owned_grants:
		var perk_id: String = str(grant.get("perk_id", ""))
		var item_id: String = str(grant.get("item_id", ""))
		var granted: bool = bool(active_item_runtime.grant_item_to_slot(
			item_id,
			owner,
			registry,
			false
		))
		if granted:
			(result["granted_item_ids"] as Array).append(item_id)
			continue
		_record_skipped_grant(result, grant, "inventory_full_or_grant_rejected")
		push_warning(
			"[RuntimePerkStageStartItemGrant] Entry %s skipped %s -> %s: inventory full or grant rejected."
			% [entry_key, perk_id, item_id]
		)

	var granted_count: int = (result["granted_item_ids"] as Array).size()
	var skipped_count: int = (result["skipped_grants"] as Array).size()
	if skipped_count <= 0:
		result["reason"] = "granted"
	elif granted_count <= 0:
		result["reason"] = "grant_rejected"
	else:
		result["reason"] = "partially_granted"
	return _remember_result(result)


func get_snapshot() -> Dictionary:
	var entry_keys: Array[String] = []
	var stages: Array[int] = []
	for entry_key_value: Variant in _processed_entries.keys():
		var entry_key: String = str(entry_key_value)
		entry_keys.append(entry_key)
		var entry_value: Variant = _processed_entries.get(entry_key, {})
		if entry_value is Dictionary:
			var stage: int = int((entry_value as Dictionary).get("stage", 0))
			if stage > 0 and not stages.has(stage):
				stages.append(stage)
	entry_keys.sort()
	stages.sort()
	return {
		"processed_entry_keys": entry_keys,
		"processed_stages": stages,
		"last_result": _last_result.duplicate(true),
	}


func _resolve_battle_entry(stage: int, registry: Object) -> Dictionary:
	if TowerAscentFeatureFlags.is_vertical_slice_enabled():
		var flow_owner: Object = _get_instance(registry, "tower_ascent_flow_owner")
		if (
			flow_owner != null
			and flow_owner.has_method("get_run_id")
			and flow_owner.has_method("get_current_node_id")
		):
			var run_id: String = str(flow_owner.call("get_run_id")).strip_edges()
			var node_id: String = str(flow_owner.call("get_current_node_id")).strip_edges()
			if not run_id.is_empty() or not node_id.is_empty():
				return {
					"entry_key": (
						"tower:%d:%s:%d:%s"
						% [run_id.length(), run_id, node_id.length(), node_id]
						if not run_id.is_empty() and not node_id.is_empty()
						else ""
					),
					"entry_kind": "tower",
					"run_id": run_id,
					"node_id": node_id,
					"stage": stage,
				}
	return {
		"entry_key": "stage:%d" % stage,
		"entry_kind": "stage",
		"run_id": "",
		"node_id": "",
		"stage": stage,
	}


func _get_runtime_skill_level(runtime_state: Object, perk_id: String) -> int:
	if runtime_state == null or not runtime_state.has_method("get_runtime_skill_level"):
		return 0
	return maxi(0, int(runtime_state.call("get_runtime_skill_level", perk_id)))


func _get_current_stage(runtime_state: Object, owner: Object) -> int:
	var character_context: Object = RuntimePerkRuntimeStateAccess.get_object(
		runtime_state,
		"_character_context"
	)
	if character_context != null and character_context.has_method("get_current_stage"):
		return int(character_context.get_current_stage(owner))
	var stage_value: Variant = owner.get("current_stage")
	return max(0, int(stage_value)) if stage_value != null else 0


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _build_result(
	stage: int,
	processed: bool,
	reason: String,
	entry: Dictionary = {}
) -> Dictionary:
	var result := {
		"stage": stage,
		"processed": processed,
		"reason": reason,
		"owned_perk_ids": [],
		"granted_item_ids": [],
		"skipped_grants": [],
	}
	for key: String in ["entry_key", "entry_kind", "run_id", "node_id"]:
		result[key] = entry.get(key, "")
	return result


func _record_skipped_grant(result: Dictionary, grant: Dictionary, reason: String) -> void:
	(result["skipped_grants"] as Array).append({
		"perk_id": str(grant.get("perk_id", "")),
		"item_id": str(grant.get("item_id", "")),
		"reason": reason,
	})


func _remember_result(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return _last_result.duplicate(true)
