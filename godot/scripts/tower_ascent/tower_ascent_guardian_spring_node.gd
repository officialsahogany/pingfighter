extends RefCounted

const GuardianCodexDiscoveryRecorder := preload(
	"res://scripts/lingpet/guardian_codex_discovery_recorder.gd"
)
const LingpetCatalog := preload(
	"res://scripts/lingpet/lingpet_catalog.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const ACTION_PREFIX := "guardian_spring:"
const OP_SOUL_SUMMONING := "soul_summoning"
const OP_ENHANCE := "enhance"
const OP_SWAP := "swap"
const OP_ABSORB := "absorb"
const RNG_VERSION := "tower_guardian_spring_v1"

var _state: Dictionary = {}
var _pending_rollback: Dictionary = {}
var _last_effect_result: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	_state = {
		"soul_summoning_owned": false,
		"soul_summoning_node_id": "",
		"active_guardian": {},
		"sealed_guardians": [],
		"history": [],
		"runtime_snapshot": {},
	}
	_pending_rollback.clear()
	_last_effect_result.clear()


func restore_state(value: Variant) -> void:
	reset()
	if not (value is Dictionary):
		return
	var source := value as Dictionary
	_state["soul_summoning_owned"] = bool(source.get("soul_summoning_owned", false))
	_state["soul_summoning_node_id"] = str(source.get("soul_summoning_node_id", ""))
	_state["active_guardian"] = _dictionary(source.get("active_guardian", {}))
	_state["sealed_guardians"] = _normalize_sealed_guardians(source.get("sealed_guardians", []))
	_state["history"] = _dictionary_array(source.get("history", []))
	_state["runtime_snapshot"] = _dictionary(source.get("runtime_snapshot", {}))


func export_state() -> Dictionary:
	return _state.duplicate(true)


func has_soul_summoning() -> bool:
	return bool(_state.get("soul_summoning_owned", false))


func get_history() -> Array[Dictionary]:
	return _dictionary_array(_state.get("history", []))


func get_sealed_guardians() -> Array[Dictionary]:
	return _dictionary_array(_state.get("sealed_guardians", []))


func record_identity_reveal(pet_id: String, registry: Object) -> Dictionary:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	if normalized_pet_id.is_empty() or not LingpetCatalog.has_pet(normalized_pet_id):
		return {
			"accepted": false,
			"handled": true,
			"tower_sealed": false,
			"reason": "invalid_pet_id",
		}
	var codex_result: Dictionary = GuardianCodexDiscoveryRecorder.record_identity_reveal(
		registry,
		normalized_pet_id
	)
	if not bool(codex_result.get("accepted", false)):
		return {
			"accepted": false,
			"handled": true,
			"tower_sealed": false,
			"reason": str(codex_result.get("reason", "codex_commit_failed")),
			"pet_id": normalized_pet_id,
			"discovery_id": str(codex_result.get("discovery_id", "")),
			"codex_result": codex_result.duplicate(true),
		}
	var active_pet_id := str((_state.get("active_guardian", {}) as Dictionary).get("pet_id", ""))
	var changed := false
	if active_pet_id != normalized_pet_id and _find_sealed_index(normalized_pet_id) < 0:
		var sealed: Array = _state.get("sealed_guardians", [])
		sealed.append({
			"pet_id": normalized_pet_id,
			"discovery_id": str(codex_result.get(
				"discovery_id",
				GuardianCodexDiscoveryRecorder.make_discovery_id(normalized_pet_id)
			)),
			"display_name": LingpetCatalog.get_display_name(normalized_pet_id),
		})
		_state["sealed_guardians"] = sealed
		changed = true
	return {
		"accepted": bool(codex_result.get("accepted", false)),
		"changed": changed,
		"handled": true,
		"tower_sealed": true,
		"reason": str(codex_result.get("reason", "codex_commit_failed")),
		"pet_id": normalized_pet_id,
		"display_name": LingpetCatalog.get_display_name(normalized_pet_id),
		"discovery_id": str(codex_result.get("discovery_id", "")),
		"codex_result": codex_result.duplicate(true),
	}


func restore_runtime(owner: Object, registry: Object) -> bool:
	var runtime_snapshot := _dictionary(_state.get("runtime_snapshot", {}))
	if runtime_snapshot.is_empty():
		return _dictionary(_state.get("active_guardian", {})).is_empty()
	var runtime := _get_registry_instance(registry, "lingpet_egg_runtime")
	if runtime == null or not runtime.has_method("apply_save_snapshot"):
		return false
	var result_value: Variant = runtime.call("apply_save_snapshot", runtime_snapshot, owner, registry)
	return result_value is Dictionary and bool((result_value as Dictionary).get("restored", false))


func build_actions(
	node_id: String,
	map_seed: int,
	run_state: Object,
	owner: Object,
	registry: Object
) -> Array[Dictionary]:
	if not has_soul_summoning():
		# The free acquisition is only actionable when the two production owners
		# needed by the resulting egg flow are registered. Missing wiring keeps
		# the modal on its ordinary end-work action and fails closed.
		if (
			_get_registry_instance(registry, "lingpet_egg_runtime") == null
			or _get_registry_instance(registry, "guardian_codex_store") == null
		):
			return []
		return [_build_soul_summoning_action()]
	if str(_state.get("soul_summoning_node_id", "")) == node_id:
		return [_build_first_visit_complete_action()]
	_sync_active_guardian_from_runtime(owner, registry)
	var runtime := _get_registry_instance(registry, "lingpet_egg_runtime")
	var balances := _economy(run_state)
	var active_guardian := _dictionary(_state.get("active_guardian", {}))
	var active_pet_id := str(active_guardian.get("pet_id", ""))
	var result: Array[Dictionary] = []
	if not active_pet_id.is_empty():
		result.append(_build_enhance_action(
			node_id,
			map_seed,
			balances,
			owner,
			runtime
		))
	for sealed in get_sealed_guardians():
		result.append(_build_sealed_action(OP_SWAP, sealed, runtime != null, true))
		result.append(_build_sealed_action(
			OP_ABSORB,
			sealed,
			runtime != null,
			not active_pet_id.is_empty()
		))
	return result


func execute_action(
	action_id: String,
	resolution_id: String,
	node_id: String,
	map_seed: int,
	run_state: Object,
	resolution_ids: Dictionary,
	action_transaction: Object,
	owner: Object,
	registry: Object
) -> Dictionary:
	var normalized_resolution_id := resolution_id.strip_edges()
	if normalized_resolution_id.is_empty():
		return {"accepted": false, "reason": "invalid_resolution_id"}
	if resolution_ids.has(normalized_resolution_id):
		return {
			"accepted": true,
			"applied": false,
			"reason": "already_committed",
			"node_resolution_id": normalized_resolution_id,
		}
	var action := _find_action(
		action_id,
		build_actions(node_id, map_seed, run_state, owner, registry)
	)
	if action.is_empty():
		return {"accepted": false, "reason": "unknown_guardian_spring_action"}
	if not bool(action.get("enabled", false)):
		return {
			"accepted": false,
			"reason": str(action.get("disabled_reason", "guardian_spring_action_disabled")),
			"message": str(action.get("unavailable_reason", "")),
		}
	if action_transaction == null or not action_transaction.has_method("apply_once"):
		return {"accepted": false, "reason": "missing_action_transaction"}
	var payload := _dictionary(action.get("payload", {}))
	var operation := str(payload.get("operation", ""))
	var cost := TowerAscentTuning.TEMP_PHASE_C_SPRING_ENHANCE_COST if operation == OP_ENHANCE else 0
	var effect_context := {
		"operation": operation,
		"pet_id": str(payload.get("pet_id", "")),
		"node_id": node_id,
		"map_seed": map_seed,
		"owner": owner,
		"registry": registry,
	}
	var transaction_result: Dictionary = action_transaction.call(
		"apply_once",
		normalized_resolution_id,
		{"muhon": cost},
		{},
		run_state,
		resolution_ids,
		Callable(self, "_apply_operation").bind(effect_context),
		Callable(self, "_rollback_operation").bind(owner, registry)
	)
	_pending_rollback.clear()
	if not bool(transaction_result.get("accepted", false)) or not bool(transaction_result.get("applied", false)):
		return transaction_result
	var record := {
		"node_id": node_id,
		"node_resolution_id": normalized_resolution_id,
		"operation": operation,
		"pet_id": str(payload.get("pet_id", "")),
		"cost": cost,
		"effect_result": _last_effect_result.duplicate(true),
	}
	var history: Array = _state.get("history", [])
	history.append(record)
	_state["history"] = history
	_capture_committed_runtime_snapshot(owner, registry)
	transaction_result["record"] = record.duplicate(true)
	transaction_result["message"] = _success_message(operation, record)
	return transaction_result


func _build_soul_summoning_action() -> Dictionary:
	return {
		"id": "%s%s" % [ACTION_PREFIX, OP_SOUL_SUMMONING],
		"label": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SPRING_SOUL_SUMMONING_OPTION
		),
		"cost_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_COST_FREE
		),
		"enabled": true,
		"unavailable_reason": "",
		"payload": {"operation": OP_SOUL_SUMMONING},
	}


func _build_first_visit_complete_action() -> Dictionary:
	var message := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SPRING_FIRST_VISIT_COMPLETE
	)
	return {
		"id": "%sfirst_visit_complete" % ACTION_PREFIX,
		"label": message,
		"cost_text": "",
		"enabled": false,
		"disabled_reason": "guardian_spring_first_visit_complete",
		"unavailable_reason": message,
		"payload": {},
	}


func _build_enhance_action(
	node_id: String,
	map_seed: int,
	balances: Dictionary,
	owner: Object,
	runtime: Object
) -> Dictionary:
	var cost := TowerAscentTuning.TEMP_PHASE_C_SPRING_ENHANCE_COST
	var candidates: Array = []
	if runtime != null and runtime.has_method("build_guardian_enhance_live_candidates"):
		var candidates_value: Variant = runtime.call("build_guardian_enhance_live_candidates", owner)
		if candidates_value is Array:
			candidates = candidates_value as Array
	var affordable := int(balances.get("muhon", 0)) >= cost
	var enabled := runtime != null and not candidates.is_empty() and affordable
	var unavailable_reason := ""
	var disabled_reason := ""
	if runtime == null:
		disabled_reason = "missing_lingpet_runtime"
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SPRING_RUNTIME_UNAVAILABLE
		)
	elif candidates.is_empty():
		disabled_reason = "no_guardian_enhancement_candidates"
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SPRING_ENHANCE_UNAVAILABLE
		)
	elif not affordable:
		disabled_reason = "insufficient_muhon"
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_INSUFFICIENT_MUHON,
			{
				"required": cost,
				"shortfall": cost - int(balances.get("muhon", 0)),
			}
		)
	var sequence := _operation_count(node_id, OP_ENHANCE)
	return {
		"id": "%s%s:%d" % [ACTION_PREFIX, OP_ENHANCE, sequence],
		"label": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SPRING_ENHANCE_OPTION,
			{"name": str((_state.get("active_guardian", {}) as Dictionary).get("display_name", ""))}
		),
		"cost_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_COST_MUHON,
			{"amount": cost}
		),
		"enabled": enabled,
		"disabled_reason": disabled_reason,
		"unavailable_reason": unavailable_reason,
		"payload": {
			"operation": OP_ENHANCE,
			"rng_seed": absi(hash("%s:%d:%s:%d" % [RNG_VERSION, map_seed, node_id, sequence])),
		},
	}


func _build_sealed_action(
	operation: String,
	sealed: Dictionary,
	runtime_available: bool,
	operation_available: bool
) -> Dictionary:
	var pet_id := str(sealed.get("pet_id", ""))
	var display_name := str(sealed.get("display_name", LingpetCatalog.get_display_name(pet_id)))
	var enabled := runtime_available and operation_available
	var unavailable_reason := ""
	var disabled_reason := ""
	if not runtime_available:
		disabled_reason = "missing_lingpet_runtime"
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SPRING_RUNTIME_UNAVAILABLE
		)
	elif not operation_available:
		disabled_reason = "missing_active_guardian"
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SPRING_ACTIVE_GUARDIAN_REQUIRED
		)
	var label_key := (
		TowerAscentNodeModalLocalization.KEY_SPRING_SWAP_OPTION
		if operation == OP_SWAP
		else TowerAscentNodeModalLocalization.KEY_SPRING_ABSORB_OPTION
	)
	return {
		"id": "%s%s:%s" % [ACTION_PREFIX, operation, pet_id],
		"label": TowerAscentNodeModalLocalization.text(label_key, {"name": display_name}),
		"cost_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_COST_FREE
		),
		"enabled": enabled,
		"disabled_reason": disabled_reason,
		"unavailable_reason": unavailable_reason,
		"payload": {"operation": operation, "pet_id": pet_id},
	}


func _apply_operation(context: Dictionary) -> bool:
	_capture_rollback(context.get("registry", null))
	_last_effect_result.clear()
	var operation := str(context.get("operation", ""))
	var accepted := false
	if operation == OP_SOUL_SUMMONING:
		_state["soul_summoning_owned"] = true
		_state["soul_summoning_node_id"] = str(context.get("node_id", ""))
		_last_effect_result = {"accepted": true, "soul_summoning_owned": true}
		accepted = true
	else:
		var runtime := _get_registry_instance(context.get("registry", null), "lingpet_egg_runtime")
		if runtime != null:
			if operation == OP_ENHANCE:
				accepted = _apply_enhance(runtime, context)
			elif operation == OP_SWAP:
				accepted = _apply_swap(runtime, context)
			elif operation == OP_ABSORB:
				accepted = _apply_absorb(runtime, context)
	if accepted:
		_capture_committed_runtime_snapshot(
			context.get("owner", null),
			context.get("registry", null)
		)
	if not accepted:
		_rollback_operation(context.get("owner", null), context.get("registry", null))
		_pending_rollback.clear()
	return accepted


func _apply_enhance(runtime: Object, context: Dictionary) -> bool:
	if (
		not runtime.has_method("build_guardian_enhance_live_candidates")
		or not runtime.has_method("apply_guardian_enhance_random_roll")
	):
		return false
	var candidates_value: Variant = runtime.call(
		"build_guardian_enhance_live_candidates",
		context.get("owner", null)
	)
	if not (candidates_value is Array) or (candidates_value as Array).is_empty():
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("%s:%d:%s:%d" % [
		RNG_VERSION,
		int(context.get("map_seed", 0)),
		str(context.get("node_id", "")),
		_operation_count(str(context.get("node_id", "")), OP_ENHANCE),
	]))
	var result_value: Variant = runtime.call(
		"apply_guardian_enhance_random_roll",
		candidates_value,
		context.get("owner", null),
		context.get("registry", null),
		"tower_guardian_spring",
		rng
	)
	if result_value is Dictionary:
		_last_effect_result = (result_value as Dictionary).duplicate(true)
	return bool(_last_effect_result.get("accepted", false))


func _apply_swap(runtime: Object, context: Dictionary) -> bool:
	if not runtime.has_method("activate_tower_sealed_guardian"):
		return false
	var pet_id := str(context.get("pet_id", ""))
	var sealed_index := _find_sealed_index(pet_id)
	if sealed_index < 0:
		return false
	var previous_active := _dictionary(_state.get("active_guardian", {}))
	var result_value: Variant = runtime.call(
		"activate_tower_sealed_guardian",
		pet_id,
		context.get("owner", null),
		context.get("registry", null)
	)
	if not (result_value is Dictionary) or not bool((result_value as Dictionary).get("accepted", false)):
		return false
	_last_effect_result = (result_value as Dictionary).duplicate(true)
	var sealed: Array = _state.get("sealed_guardians", [])
	sealed.remove_at(sealed_index)
	var previous_pet_id := str(previous_active.get("pet_id", ""))
	if not previous_pet_id.is_empty() and previous_pet_id != pet_id and _find_pet_index(sealed, previous_pet_id) < 0:
		sealed.append({
			"pet_id": previous_pet_id,
			"display_name": str(previous_active.get(
				"display_name",
				LingpetCatalog.get_display_name(previous_pet_id)
			)),
			"discovery_id": GuardianCodexDiscoveryRecorder.make_discovery_id(previous_pet_id),
		})
	_state["sealed_guardians"] = sealed
	_state["active_guardian"] = {
		"pet_id": pet_id,
		"display_name": LingpetCatalog.get_display_name(pet_id),
	}
	return true


func _apply_absorb(runtime: Object, context: Dictionary) -> bool:
	if not runtime.has_method("absorb_tower_sealed_guardian"):
		return false
	var pet_id := str(context.get("pet_id", ""))
	var sealed_index := _find_sealed_index(pet_id)
	if sealed_index < 0:
		return false
	var result_value: Variant = runtime.call(
		"absorb_tower_sealed_guardian",
		pet_id,
		context.get("owner", null),
		context.get("registry", null)
	)
	if not (result_value is Dictionary) or not bool((result_value as Dictionary).get("accepted", false)):
		return false
	_last_effect_result = (result_value as Dictionary).duplicate(true)
	var sealed: Array = _state.get("sealed_guardians", [])
	sealed.remove_at(sealed_index)
	_state["sealed_guardians"] = sealed
	return true


func _capture_rollback(registry: Object) -> void:
	_pending_rollback = {
		"state": _state.duplicate(true),
		"runtime_snapshot": _capture_runtime_snapshot(registry),
	}


func _rollback_operation(owner: Object, registry: Object) -> void:
	if _pending_rollback.is_empty():
		return
	_state = _dictionary(_pending_rollback.get("state", {}))
	var runtime_snapshot := _dictionary(_pending_rollback.get("runtime_snapshot", {}))
	if runtime_snapshot.is_empty():
		return
	var runtime := _get_registry_instance(registry, "lingpet_egg_runtime")
	if runtime != null and runtime.has_method("apply_save_snapshot"):
		runtime.call("apply_save_snapshot", runtime_snapshot, owner, registry)


func _capture_committed_runtime_snapshot(owner: Object, registry: Object) -> void:
	var runtime_snapshot := _capture_runtime_snapshot(registry)
	if runtime_snapshot.is_empty():
		return
	_state["runtime_snapshot"] = runtime_snapshot
	var runtime_state := str(runtime_snapshot.get("state", "")).strip_edges().to_lower()
	var pet_id := str(runtime_snapshot.get("pet_id", "")).strip_edges().to_lower()
	if runtime_state == "companion" and not pet_id.is_empty():
		_state["active_guardian"] = {
			"pet_id": pet_id,
			"display_name": LingpetCatalog.get_display_name(pet_id),
			"guardian_run_state": _dictionary(runtime_snapshot.get("guardian_run_state", {})),
		}
	_sync_sealed_owner_projection(owner)


func _sync_active_guardian_from_runtime(owner: Object, registry: Object) -> void:
	if not _dictionary(_state.get("active_guardian", {})).is_empty():
		_sync_sealed_owner_projection(owner)
		return
	_capture_committed_runtime_snapshot(owner, registry)


func sync_owner_projection(owner: Object) -> void:
	_sync_sealed_owner_projection(owner)


func _sync_sealed_owner_projection(owner: Object) -> void:
	if owner == null or not owner.has_method("set_tower_ascent_guardian_projection"):
		return
	owner.call(
		"set_tower_ascent_guardian_projection",
		get_sealed_guardians(),
		has_soul_summoning()
	)


func _capture_runtime_snapshot(registry: Object) -> Dictionary:
	var runtime := _get_registry_instance(registry, "lingpet_egg_runtime")
	if runtime == null or not runtime.has_method("build_save_snapshot"):
		return {}
	var value: Variant = runtime.call("build_save_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _operation_count(node_id: String, operation: String) -> int:
	var count := 0
	for record in get_history():
		if str(record.get("node_id", "")) == node_id and str(record.get("operation", "")) == operation:
			count += 1
	return count


func _find_sealed_index(pet_id: String) -> int:
	return _find_pet_index(_state.get("sealed_guardians", []), pet_id)


func _find_pet_index(source: Variant, pet_id: String) -> int:
	if not (source is Array):
		return -1
	var normalized := pet_id.strip_edges().to_lower()
	for index in range((source as Array).size()):
		var value: Variant = (source as Array)[index]
		if value is Dictionary and str((value as Dictionary).get("pet_id", "")) == normalized:
			return index
	return -1


func _find_action(action_id: String, actions: Array[Dictionary]) -> Dictionary:
	for action in actions:
		if str(action.get("id", "")) == action_id:
			return action
	return {}


func _success_message(operation: String, record: Dictionary) -> String:
	var pet_id := str(record.get("pet_id", ""))
	var display_name := LingpetCatalog.get_display_name(pet_id) if not pet_id.is_empty() else ""
	var key := TowerAscentNodeModalLocalization.KEY_SPRING_SOUL_SUMMONING_COMPLETED
	if operation == OP_ENHANCE:
		key = TowerAscentNodeModalLocalization.KEY_SPRING_ENHANCE_COMPLETED
	elif operation == OP_SWAP:
		key = TowerAscentNodeModalLocalization.KEY_SPRING_SWAP_COMPLETED
	elif operation == OP_ABSORB:
		key = TowerAscentNodeModalLocalization.KEY_SPRING_ABSORB_COMPLETED
	return TowerAscentNodeModalLocalization.text(key, {"name": display_name})


func _economy(run_state: Object) -> Dictionary:
	if run_state != null and run_state.has_method("export_economy"):
		var value: Variant = run_state.call("export_economy")
		if value is Dictionary:
			return value as Dictionary
	return {}


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	for method_name in ["get_instance", "get_cached_instance"]:
		if not registry.has_method(method_name):
			continue
		var value: Variant = registry.call(method_name, key)
		if value is Object and value != null:
			return value as Object
	return null


func _normalize_sealed_guardians(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for raw_entry in (value as Array):
		if not (raw_entry is Dictionary):
			continue
		var entry := (raw_entry as Dictionary).duplicate(true)
		var pet_id := str(entry.get("pet_id", "")).strip_edges().to_lower()
		if pet_id.is_empty() or not LingpetCatalog.has_pet(pet_id) or _find_pet_index(result, pet_id) >= 0:
			continue
		entry["pet_id"] = pet_id
		entry["display_name"] = str(entry.get("display_name", LingpetCatalog.get_display_name(pet_id)))
		result.append(entry)
	return result


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw_value in (value as Array):
			if raw_value is Dictionary:
				result.append((raw_value as Dictionary).duplicate(true))
	return result
