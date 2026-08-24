extends RefCounted

const CommonSkillCatalog := preload(
	"res://scripts/characters/common_skill_catalog.gd"
)
const RuntimePerkCharacterContext := preload(
	"res://scripts/characters/runtime_perk_character_context.gd"
)
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
const RNG_VERSION := "tower_guardian_spring_v1"

var _state: Dictionary = {}
var _pending_rollback: Dictionary = {}
var _last_effect_result: Dictionary = {}
var _character_context: Object = RuntimePerkCharacterContext.new()


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
		"perk_runtime_snapshot": {},
		"skill_config_snapshot": {},
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
	_state["sealed_guardians"] = []
	_state["history"] = _dictionary_array(source.get("history", []))
	_state["runtime_snapshot"] = _dictionary(source.get("runtime_snapshot", {}))
	_state["perk_runtime_snapshot"] = _dictionary(source.get("perk_runtime_snapshot", {}))
	_state["skill_config_snapshot"] = _dictionary(source.get("skill_config_snapshot", {}))


func export_state() -> Dictionary:
	var result := _state.duplicate(true)
	result["sealed_guardians"] = []
	return result


func has_soul_summoning() -> bool:
	return bool(_state.get("soul_summoning_owned", false))


func get_history() -> Array[Dictionary]:
	return _dictionary_array(_state.get("history", []))


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
	return {
		"accepted": bool(codex_result.get("accepted", false)),
		"changed": bool(codex_result.get("changed", false)),
		"handled": true,
		"tower_sealed": false,
		"reason": str(codex_result.get("reason", "codex_commit_failed")),
		"pet_id": normalized_pet_id,
		"display_name": LingpetCatalog.get_display_name(normalized_pet_id),
		"discovery_id": str(codex_result.get("discovery_id", "")),
		"codex_result": codex_result.duplicate(true),
	}


func restore_runtime(owner: Object, registry: Object) -> bool:
	var runtime_snapshot := _dictionary(_state.get("runtime_snapshot", {}))
	var guardian_restored := _dictionary(_state.get("active_guardian", {})).is_empty()
	if not runtime_snapshot.is_empty():
		var runtime := _get_registry_instance(registry, "lingpet_egg_runtime")
		if runtime == null or not runtime.has_method("apply_save_snapshot"):
			return false
		var result_value: Variant = runtime.call(
			"apply_save_snapshot",
			runtime_snapshot,
			owner,
			registry
		)
		guardian_restored = (
			result_value is Dictionary
			and bool((result_value as Dictionary).get("restored", false))
		)
	if not guardian_restored or not has_soul_summoning():
		return guardian_restored
	return _restore_soul_unlock_runtime(owner, registry)


func build_actions(
	node_id: String,
	map_seed: int,
	run_state: Object,
	owner: Object,
	registry: Object
) -> Array[Dictionary]:
	if not has_soul_summoning():
		# The free acquisition shares the campaign unlock bridge, then deploys
		# through the existing Lingpet owner. Missing wiring fails closed.
		if (
			_get_registry_instance(registry, "lingpet_egg_runtime") == null
			or _get_registry_instance(registry, "guardian_codex_store") == null
			or _get_registry_instance(registry, "runtime_perk_state") == null
			or _get_registry_instance(registry, "runtime_perk_catalog") == null
			or _get_skill_config(owner, registry) == null
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
	if not active_pet_id.is_empty():
		return [_build_enhance_action(
			node_id,
			map_seed,
			balances,
			owner,
			runtime
		)]
	return []


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
	var label := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SPRING_SOUL_SUMMONING_OPTION
	)
	var badge := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SPRING_CARD_BADGE_SOUL
	)
	return {
		"id": "%s%s" % [ACTION_PREFIX, OP_SOUL_SUMMONING],
		"label": label,
		"cost_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_COST_FREE
		),
		"enabled": true,
		"unavailable_reason": "",
		"payload": {
			"operation": OP_SOUL_SUMMONING,
			"choice": _build_guardian_card_choice(
				"",
				label,
				badge,
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SPRING_CARD_SOUL_DESCRIPTION
				)
			),
			"presentation": _build_guardian_presentation(
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_STATE_EMPTY
				),
				badge,
				label
			),
		},
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
		"payload": {
			"operation": "first_visit_complete",
			"choice": _build_guardian_card_choice(
				"",
				message,
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_STATE_OWNED
				),
				message
			),
			"presentation": _build_guardian_presentation(
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_STATE_OWNED
				),
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_STATE_OWNED
				),
				message
			),
		},
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
	var active_guardian := _dictionary(_state.get("active_guardian", {}))
	var pet_id := str(active_guardian.get("pet_id", ""))
	var display_name := str(active_guardian.get(
		"display_name",
		LingpetCatalog.get_display_name(pet_id)
	))
	var badge := TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SPRING_CARD_BADGE_ENHANCE
	)
	return {
		"id": "%s%s:%d" % [ACTION_PREFIX, OP_ENHANCE, sequence],
		"label": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SPRING_ENHANCE_OPTION,
			{"name": display_name}
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
			"pet_id": pet_id,
			"rng_seed": absi(hash("%s:%d:%s:%d" % [RNG_VERSION, map_seed, node_id, sequence])),
			"choice": _build_guardian_card_choice(
				pet_id,
				display_name,
				badge,
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SPRING_CARD_ENHANCE_DESCRIPTION
				)
			),
			"presentation": _build_guardian_presentation(
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SPRING_STATE_ACTIVE
				),
				TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SPRING_STATE_ENHANCED
				),
				display_name
			),
		},
	}


func _build_guardian_card_choice(
	pet_id: String,
	display_name: String,
	badge: String,
	description: String
) -> Dictionary:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	return {
		"id": (
			"guardian_spirit_egg"
			if normalized_pet_id.is_empty()
			else "guardian_portrait:%s" % normalized_pet_id
		),
		"icon_id": "guardian_spirit_egg" if normalized_pet_id.is_empty() else "",
		"name": display_name,
		"description": description,
		"level_text": badge,
		"tree": "guardian",
		"icon_color": Color(0.37, 0.72, 0.66),
		"card_content_kind": (
			"guardian_egg" if normalized_pet_id.is_empty() else "guardian_portrait"
		),
		"guardian_pet_id": normalized_pet_id,
		# The catalog path is presentation evidence only. The icon renderer resolves
		# and prewarms the same live catalog key; the draw path never loads it.
		"guardian_portrait_path": (
			""
			if normalized_pet_id.is_empty()
			else LingpetCatalog.get_visual_path(normalized_pet_id, "cutin_art")
		),
		"tower_node_strict_text_budget": true,
	}


func _build_guardian_presentation(
	current_text: String,
	result_text: String,
	target_text: String
) -> Dictionary:
	return {
		"current": current_text,
		"result": result_text,
		"target": target_text,
		"strict_text_budget": true,
	}


func _apply_operation(context: Dictionary) -> bool:
	_capture_rollback(context.get("owner", null), context.get("registry", null))
	_last_effect_result.clear()
	var operation := str(context.get("operation", ""))
	var accepted := false
	if operation == OP_SOUL_SUMMONING:
		accepted = _apply_soul_summoning_unlock(
			context.get("owner", null),
			context.get("registry", null)
		)
		if accepted:
			_state["soul_summoning_owned"] = true
			_state["soul_summoning_node_id"] = str(context.get("node_id", ""))
			_last_effect_result = {"accepted": true, "soul_summoning_owned": true}
			accepted = _capture_committed_soul_unlock_snapshots(
				context.get("owner", null),
				context.get("registry", null)
			)
	else:
		var runtime := _get_registry_instance(context.get("registry", null), "lingpet_egg_runtime")
		if runtime != null and operation == OP_ENHANCE:
			accepted = _apply_enhance(runtime, context)
	if accepted:
		_capture_committed_runtime_snapshot(
			context.get("owner", null),
			context.get("registry", null)
		)
	if not accepted:
		_rollback_operation(context.get("owner", null), context.get("registry", null))
		_pending_rollback.clear()
	return accepted


func _apply_soul_summoning_unlock(owner: Object, registry: Object) -> bool:
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var catalog := _get_registry_instance(registry, "runtime_perk_catalog")
	var skill_config := _get_skill_config(owner, registry)
	if (
		runtime_state == null
		or catalog == null
		or skill_config == null
		or not runtime_state.has_method("apply_choice")
		or not catalog.has_method("get_perk_data")
	):
		return false
	var choice_value: Variant = catalog.call(
		"get_perk_data",
		CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID
	)
	if not (choice_value is Dictionary):
		return false
	var choice := (choice_value as Dictionary).duplicate(true)
	if str(choice.get("unlocks_skill", "")) != CommonSkillCatalog.SOUL_SUMMON_ART_ID:
		return false
	return bool(runtime_state.call("apply_choice", choice, owner, registry))


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


func _capture_rollback(owner: Object, registry: Object) -> void:
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var skill_config := _get_skill_config(owner, registry)
	_pending_rollback = {
		"state": _state.duplicate(true),
		"runtime_snapshot": _capture_runtime_snapshot(registry),
		"perk_runtime_snapshot": _capture_perk_runtime_snapshot(runtime_state),
		"equipped_skills": _equipped_skills(skill_config),
	}


func _rollback_operation(owner: Object, registry: Object) -> void:
	if _pending_rollback.is_empty():
		return
	_state = _dictionary(_pending_rollback.get("state", {}))
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	if runtime_state != null and runtime_state.has_method("cancel_pending_unlock_swap"):
		runtime_state.call("cancel_pending_unlock_swap", owner)
	var skill_config := _get_skill_config(owner, registry)
	if skill_config != null:
		_restore_equipped_skills(skill_config, _pending_rollback.get("equipped_skills", []))
	var perk_runtime_snapshot := _dictionary(
		_pending_rollback.get("perk_runtime_snapshot", {})
	)
	if (
		runtime_state != null
		and not perk_runtime_snapshot.is_empty()
		and runtime_state.has_method("apply_unlock_save_snapshot")
	):
		runtime_state.call("apply_unlock_save_snapshot", perk_runtime_snapshot, owner, registry)
	var runtime_snapshot := _dictionary(_pending_rollback.get("runtime_snapshot", {}))
	var runtime := _get_registry_instance(registry, "lingpet_egg_runtime")
	if not runtime_snapshot.is_empty() and runtime != null and runtime.has_method("apply_save_snapshot"):
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


func _capture_committed_soul_unlock_snapshots(owner: Object, registry: Object) -> bool:
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var skill_config := _get_skill_config(owner, registry)
	var perk_runtime_snapshot := _capture_perk_runtime_snapshot(runtime_state)
	var equipped_skills := _equipped_skills(skill_config)
	if (
		perk_runtime_snapshot.is_empty()
		or not equipped_skills.has(CommonSkillCatalog.SOUL_SUMMON_ART_ID)
	):
		return false
	_state["perk_runtime_snapshot"] = perk_runtime_snapshot
	_state["skill_config_snapshot"] = {
		"character_type": _character_type(owner),
		"equipped_skills": equipped_skills,
	}
	return true


func _restore_soul_unlock_runtime(owner: Object, registry: Object) -> bool:
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var skill_config := _get_skill_config(owner, registry)
	if runtime_state == null or skill_config == null:
		return false
	var perk_runtime_snapshot := _dictionary(_state.get("perk_runtime_snapshot", {}))
	var skill_config_snapshot := _dictionary(_state.get("skill_config_snapshot", {}))
	if perk_runtime_snapshot.is_empty() or skill_config_snapshot.is_empty():
		if not _apply_soul_summoning_unlock(owner, registry):
			return false
		return _capture_committed_soul_unlock_snapshots(owner, registry)
	if not _restore_equipped_skills(
		skill_config,
		skill_config_snapshot.get("equipped_skills", [])
	):
		return false
	if not runtime_state.has_method("apply_unlock_save_snapshot"):
		return false
	var result_value: Variant = runtime_state.call(
		"apply_unlock_save_snapshot",
		perk_runtime_snapshot,
		owner,
		registry
	)
	return result_value is Dictionary and bool((result_value as Dictionary).get("restored", false))


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
		[],
		has_soul_summoning()
	)


func _capture_runtime_snapshot(registry: Object) -> Dictionary:
	var runtime := _get_registry_instance(registry, "lingpet_egg_runtime")
	if runtime == null or not runtime.has_method("build_save_snapshot"):
		return {}
	var value: Variant = runtime.call("build_save_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _capture_perk_runtime_snapshot(runtime_state: Object) -> Dictionary:
	if runtime_state == null or not runtime_state.has_method("build_unlock_save_snapshot"):
		return {}
	var value: Variant = runtime_state.call("build_unlock_save_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _restore_equipped_skills(skill_config: Object, original_value: Variant) -> bool:
	if skill_config == null or not (original_value is Array):
		return false
	var original := (original_value as Array).duplicate()
	var current := _equipped_skills(skill_config)
	for skill_value in current:
		var skill_id := str(skill_value)
		if not original.has(skill_id):
			if (
				not skill_config.has_method("unequip_skill")
				or not bool(skill_config.call("unequip_skill", skill_id))
			):
				return false
	current = _equipped_skills(skill_config)
	for skill_value in original:
		var skill_id := str(skill_value)
		if not current.has(skill_id):
			if (
				not skill_config.has_method("unlock_and_equip_skill")
				or not bool(skill_config.call("unlock_and_equip_skill", skill_id))
			):
				return false
	return _equipped_skills(skill_config) == original


func _equipped_skills(skill_config: Object) -> Array:
	if skill_config == null:
		return []
	if skill_config.has_method("get_snapshot"):
		var snapshot_value: Variant = skill_config.call("get_snapshot")
		if snapshot_value is Dictionary:
			var equipped_value: Variant = (snapshot_value as Dictionary).get(
				"equipped_skills",
				[]
			)
			if equipped_value is Array:
				return (equipped_value as Array).duplicate()
	if skill_config.has_method("get_equipped_skills"):
		var equipped_value: Variant = skill_config.call("get_equipped_skills")
		if equipped_value is Array:
			return (equipped_value as Array).duplicate()
	return []


func _character_type(owner: Object) -> String:
	return _character_context.get_owner_character_type(owner)


func _get_skill_config(owner: Object, registry: Object) -> Object:
	var key: String = str(_character_context.get_skill_config_key(_character_type(owner)))
	return _get_registry_instance(registry, key)


func _operation_count(node_id: String, operation: String) -> int:
	var count := 0
	for record in get_history():
		if str(record.get("node_id", "")) == node_id and str(record.get("operation", "")) == operation:
			count += 1
	return count


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


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw_value in (value as Array):
			if raw_value is Dictionary:
				result.append((raw_value as Dictionary).duplicate(true))
	return result
