extends RefCounted

const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const RuntimePerkCharacterContext := preload(
	"res://scripts/characters/runtime_perk_character_context.gd"
)
const RuntimePerkUnlockSwapFlow := preload(
	"res://scripts/characters/runtime_perk_unlock_swap_flow.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)

const OFFER_VERSION := "tower_fallen_monk_offer_v1"
const ACTION_PREFIX := "fallen_monk:"
const OP_ACQUIRE := "acquire"
const OP_SWAP := "swap"
const OP_REMOVE := "remove"

var _generated_offers: Array[Dictionary] = []
var _history: Array[Dictionary] = []
var _runtime_snapshot: Dictionary = {}
var _skill_config_snapshot: Dictionary = {}
var _pending_rollback: Dictionary = {}
var _character_context: Object = RuntimePerkCharacterContext.new()
var _unlock_swap_flow: Object = RuntimePerkUnlockSwapFlow.new()


func restore_state(
	offers_value: Variant,
	history_value: Variant,
	runtime_snapshot_value: Variant = {},
	skill_config_snapshot_value: Variant = {}
) -> void:
	_generated_offers.assign(_dictionary_array(offers_value))
	_history.assign(_dictionary_array(history_value))
	_runtime_snapshot = _dictionary(runtime_snapshot_value)
	_skill_config_snapshot = _dictionary(skill_config_snapshot_value)
	_pending_rollback.clear()


func reset() -> void:
	_generated_offers.clear()
	_history.clear()
	_runtime_snapshot.clear()
	_skill_config_snapshot.clear()
	_pending_rollback.clear()


func get_generated_offers() -> Array[Dictionary]:
	return _generated_offers.duplicate(true)


func get_history() -> Array[Dictionary]:
	return _history.duplicate(true)


func get_runtime_snapshot() -> Dictionary:
	return _runtime_snapshot.duplicate(true)


func get_skill_config_snapshot() -> Dictionary:
	return _skill_config_snapshot.duplicate(true)


func restore_runtime(owner: Object, registry: Object) -> bool:
	if _history.is_empty():
		return _runtime_snapshot.is_empty() and _skill_config_snapshot.is_empty()
	if _runtime_snapshot.is_empty() or _skill_config_snapshot.is_empty():
		return false
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var skill_config := _get_skill_config(owner, registry)
	if (
		runtime_state == null
		or skill_config == null
		or not runtime_state.has_method("apply_unlock_save_snapshot")
	):
		return false
	var restore_value: Variant = runtime_state.call(
		"apply_unlock_save_snapshot",
		_runtime_snapshot,
		owner,
		registry
	)
	if not (restore_value is Dictionary) or not bool((restore_value as Dictionary).get("restored", false)):
		return false
	if not _restore_equipped_skills(skill_config, _skill_config_snapshot.get("equipped_skills", [])):
		return false
	_unlock_swap_flow.sync_commando_weapon_controller(
		"",
		skill_config,
		registry,
		str(_skill_config_snapshot.get("character_type", _character_type(owner))),
		Callable(self, "_get_registry_instance")
	)
	return true


func build_actions(
	node_id: String,
	map_seed: int,
	run_state: Object,
	owner: Object,
	registry: Object
) -> Array[Dictionary]:
	var offer := _get_or_create_offer(node_id, map_seed, owner, registry)
	if offer.is_empty():
		return []
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var catalog := _get_registry_instance(registry, "runtime_perk_catalog")
	var skill_config := _get_skill_config(owner, registry)
	if runtime_state == null or catalog == null or skill_config == null:
		return []
	var runtime_levels := _runtime_levels(runtime_state)
	var balances := _economy(run_state)
	var counts := _operation_counts(node_id)
	var result: Array[Dictionary] = []
	for choice_value in offer.get("choices", []):
		if not (choice_value is Dictionary):
			continue
		var choice := choice_value as Dictionary
		var unlocked_skill := str(choice.get("unlocks_skill", "")).strip_edges()
		if unlocked_skill.is_empty() or _is_skill_equipped(skill_config, unlocked_skill):
			continue
		var swap_candidates := _swap_candidates(skill_config, unlocked_skill)
		if _is_shared_slot_full(skill_config) and not swap_candidates.is_empty():
			for removed_skill in swap_candidates:
				result.append(_build_action(
					OP_SWAP,
					choice,
					str(removed_skill),
					skill_config,
					balances,
					counts
				))
		else:
			result.append(_build_action(
				OP_ACQUIRE,
				choice,
				"",
				skill_config,
				balances,
				counts
			))
	for removable in _build_removal_candidates(runtime_levels, catalog, skill_config, owner):
		result.append(_build_action(
			OP_REMOVE,
			removable,
			str(removable.get("unlocks_skill", "")),
			skill_config,
			balances,
			counts
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
	var action := _find_action(
		action_id,
		build_actions(node_id, map_seed, run_state, owner, registry)
	)
	if action.is_empty():
		return {"accepted": false, "reason": "unknown_fallen_monk_action"}
	if not bool(action.get("enabled", false)):
		return {
			"accepted": false,
			"reason": str(action.get("disabled_reason", "fallen_monk_action_disabled")),
			"message": str(action.get("unavailable_reason", "")),
		}
	if action_transaction == null or not action_transaction.has_method("apply_once"):
		return {"accepted": false, "reason": "missing_action_transaction"}
	var operation := str(action.get("payload", {}).get("operation", ""))
	var cost := _operation_cost(operation)
	var effect_context := {
		"operation": operation,
		"choice": (action.get("payload", {}).get("choice", {}) as Dictionary).duplicate(true),
		"removed_skill": str(action.get("payload", {}).get("removed_skill", "")),
		"owner": owner,
		"registry": registry,
	}
	var transaction_result: Dictionary = action_transaction.call(
		"apply_once",
		resolution_id,
		{"muhon": cost},
		{},
		run_state,
		resolution_ids,
		Callable(self, "_apply_operation").bind(effect_context),
		Callable(self, "_rollback_operation").bind(owner, registry)
	)
	_pending_rollback.clear()
	if not bool(transaction_result.get("accepted", false)):
		return transaction_result
	if not bool(transaction_result.get("applied", false)):
		return transaction_result
	var choice: Dictionary = effect_context.get("choice", {})
	var record := {
		"node_id": node_id,
		"node_resolution_id": resolution_id,
		"operation": operation,
		"choice_id": str(choice.get("id", "")),
		"unlocked_skill": str(choice.get("unlocks_skill", "")),
		"removed_skill": str(effect_context.get("removed_skill", "")),
		"display_name": str(choice.get("name", choice.get("id", ""))),
		"cost": cost,
	}
	_history.append(record)
	transaction_result["record"] = record.duplicate(true)
	transaction_result["message"] = _success_message(operation, record)
	return transaction_result


func _get_or_create_offer(
	node_id: String,
	map_seed: int,
	owner: Object,
	registry: Object
) -> Dictionary:
	var normalized_node_id := node_id.strip_edges()
	if normalized_node_id.is_empty():
		return {}
	for offer in _generated_offers:
		if str(offer.get("node_id", "")) == normalized_node_id:
			return offer
	var generated := _build_offer(normalized_node_id, map_seed, owner, registry)
	if generated.is_empty():
		return {}
	_generated_offers.append(generated)
	return _generated_offers.back()


func _build_offer(
	node_id: String,
	map_seed: int,
	owner: Object,
	registry: Object
) -> Dictionary:
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var catalog := _get_registry_instance(registry, "runtime_perk_catalog")
	var skill_config := _get_skill_config(owner, registry)
	if (
		runtime_state == null
		or catalog == null
		or skill_config == null
		or not catalog.has_method("get_all_perk_data")
	):
		return {}
	var runtime_levels := _runtime_levels(runtime_state)
	var character_type := _character_type(owner)
	var all_data_value: Variant = catalog.call("get_all_perk_data")
	if not (all_data_value is Dictionary):
		return {}
	var all_data := all_data_value as Dictionary
	var candidate_ids: Array[String] = []
	for perk_id_value in all_data.keys():
		var perk_id := str(perk_id_value).strip_edges()
		var data_value: Variant = all_data.get(perk_id, {})
		if perk_id.is_empty() or not (data_value is Dictionary):
			continue
		var data := data_value as Dictionary
		var unlocked_skill := str(data.get("unlocks_skill", "")).strip_edges()
		var restriction := str(data.get("character_restriction", "")).strip_edges()
		if unlocked_skill.is_empty() or restriction.is_empty():
			continue
		if _character_context.normalize_character_type(restriction) != character_type:
			continue
		if int(runtime_levels.get(perk_id, 0)) > 0:
			continue
		if not TowerAscentUnlockFilter.is_content_unlocked(
			registry,
			TowerAscentUnlockFilter.CONTENT_RUNTIME_PERK,
			perk_id
		):
			continue
		if _skill_data(skill_config, unlocked_skill).is_empty():
			continue
		candidate_ids.append(perk_id)
	candidate_ids.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("%d:%s:%s" % [map_seed, node_id, OFFER_VERSION]))
	_shuffle_with_rng(candidate_ids, rng)
	var choices: Array[Dictionary] = []
	var choice_count := mini(RuntimePerkCatalog.BASE_CHOICE_COUNT, candidate_ids.size())
	for index in range(choice_count):
		var choice_value: Variant = catalog.call("get_perk_data", candidate_ids[index])
		if choice_value is Dictionary:
			var choice := (choice_value as Dictionary).duplicate(true)
			choice["id"] = candidate_ids[index]
			choice["current_level"] = 0
			choice["next_level"] = 1
			choices.append(choice)
	if choices.size() < 2:
		choices.clear()
	return {
		"offer_version": OFFER_VERSION,
		"node_id": node_id,
		"character_type": character_type,
		"choices": choices,
	}


func _build_action(
	operation: String,
	choice: Dictionary,
	removed_skill: String,
	skill_config: Object,
	balances: Dictionary,
	counts: Dictionary
) -> Dictionary:
	var choice_id := str(choice.get("id", "")).strip_edges()
	var cost := _operation_cost(operation)
	var used := int(counts.get(operation, 0)) >= _operation_limit(operation)
	var affordable := int(balances.get("muhon", 0)) >= cost
	var enabled := not used and affordable
	var unavailable_reason := ""
	var disabled_reason := ""
	if used:
		disabled_reason = "fallen_monk_visit_limit"
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			_operation_limit_key(operation)
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
	var unlocked_skill := str(choice.get("unlocks_skill", ""))
	var new_name := str(choice.get("name", choice_id))
	var old_name := str(_skill_data(skill_config, removed_skill).get("korean", removed_skill))
	var label_key := TowerAscentNodeModalLocalization.KEY_MONK_ACQUIRE_OPTION
	if operation == OP_SWAP:
		label_key = TowerAscentNodeModalLocalization.KEY_MONK_SWAP_OPTION
	elif operation == OP_REMOVE:
		label_key = TowerAscentNodeModalLocalization.KEY_MONK_REMOVE_OPTION
	var action_id := "%s%s:%s" % [ACTION_PREFIX, operation, choice_id]
	if not removed_skill.is_empty():
		action_id += ":%s" % removed_skill
	return {
		"id": action_id,
		"label": TowerAscentNodeModalLocalization.text(
			label_key,
			{
				"name": new_name,
				"old_name": old_name,
				"new_name": new_name,
			}
		),
		"cost_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_COST_MUHON,
			{"amount": cost}
		),
		"enabled": enabled,
		"disabled_reason": disabled_reason,
		"unavailable_reason": unavailable_reason,
		"payload": {
			"operation": operation,
			"choice": choice.duplicate(true),
			"unlocked_skill": unlocked_skill,
			"removed_skill": removed_skill,
		},
	}


func _build_removal_candidates(
	runtime_levels: Dictionary,
	catalog: Object,
	skill_config: Object,
	owner: Object
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var character_type := _character_type(owner)
	var sorted_ids: Array[String] = []
	for perk_id_value in runtime_levels.keys():
		sorted_ids.append(str(perk_id_value))
	sorted_ids.sort()
	for perk_id in sorted_ids:
		if int(runtime_levels.get(perk_id, 0)) <= 0:
			continue
		var data_value: Variant = catalog.call("get_perk_data", perk_id)
		if not (data_value is Dictionary):
			continue
		var data := data_value as Dictionary
		var unlocked_skill := str(data.get("unlocks_skill", "")).strip_edges()
		var restriction := str(data.get("character_restriction", "")).strip_edges()
		if (
			unlocked_skill.is_empty()
			or restriction.is_empty()
			or _character_context.normalize_character_type(restriction) != character_type
			or not _is_skill_equipped(skill_config, unlocked_skill)
		):
			continue
		var choice := data.duplicate(true)
		choice["id"] = perk_id
		result.append(choice)
	return result


func _apply_operation(context: Dictionary) -> bool:
	var owner: Object = context.get("owner", null)
	var registry: Object = context.get("registry", null)
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var catalog := _get_registry_instance(registry, "runtime_perk_catalog")
	var skill_config := _get_skill_config(owner, registry)
	if runtime_state == null or catalog == null or skill_config == null:
		return false
	_capture_rollback(runtime_state, skill_config, owner)
	if (_pending_rollback.get("runtime_snapshot", {}) as Dictionary).is_empty():
		_pending_rollback.clear()
		return false
	var operation := str(context.get("operation", ""))
	var choice: Dictionary = context.get("choice", {})
	var removed_skill := str(context.get("removed_skill", ""))
	var accepted := false
	if operation == OP_ACQUIRE:
		accepted = bool(runtime_state.call("apply_choice", choice, owner, registry))
	elif operation == OP_SWAP:
		accepted = _apply_swap(
			runtime_state,
			choice,
			removed_skill,
			owner,
			registry
		)
	elif operation == OP_REMOVE:
		accepted = _apply_remove(
			runtime_state,
			catalog,
			skill_config,
			removed_skill,
			owner,
			registry
		)
	if accepted and not _capture_committed_snapshots(owner, registry):
		accepted = false
	if not accepted:
		_rollback_operation(owner, registry)
		_pending_rollback.clear()
	return accepted


func _apply_swap(
	runtime_state: Object,
	choice: Dictionary,
	removed_skill: String,
	owner: Object,
	registry: Object
) -> bool:
	if bool(runtime_state.call("apply_choice", choice, owner, registry)):
		return false
	if (
		not runtime_state.has_method("has_pending_unlock_swap")
		or not bool(runtime_state.call("has_pending_unlock_swap"))
		or not runtime_state.has_method("get_pending_unlock_swap")
	):
		return false
	var pending_value: Variant = runtime_state.call("get_pending_unlock_swap")
	if not (pending_value is Dictionary):
		return false
	var candidates: Array = (pending_value as Dictionary).get("candidates", [])
	var selected_index := -1
	for index in range(candidates.size()):
		var candidate_value: Variant = candidates[index]
		if (
			candidate_value is Dictionary
			and str((candidate_value as Dictionary).get("skill_id", "")) == removed_skill
		):
			selected_index = index
			break
	if selected_index < 0:
		return false
	if selected_index > 0:
		if not runtime_state.has_method("move_unlock_swap_selection"):
			return false
		runtime_state.call("move_unlock_swap_selection", selected_index)
	return (
		runtime_state.has_method("confirm_pending_unlock_swap")
		and bool(runtime_state.call("confirm_pending_unlock_swap", owner, registry))
	)


func _apply_remove(
	runtime_state: Object,
	catalog: Object,
	skill_config: Object,
	removed_skill: String,
	owner: Object,
	registry: Object
) -> bool:
	if removed_skill.is_empty() or not skill_config.has_method("unequip_skill"):
		return false
	if not bool(skill_config.call("unequip_skill", removed_skill)):
		return false
	var runtime_levels := _runtime_levels_reference(runtime_state)
	var removed_perk_id := str(_unlock_swap_flow.remove_runtime_unlock_for_skill(
		runtime_levels,
		removed_skill,
		catalog
	))
	if removed_perk_id.is_empty():
		return false
	_sync_current_runtime_snapshot(runtime_state, owner, registry)
	_unlock_swap_flow.sync_commando_weapon_controller(
		"",
		skill_config,
		registry,
		_character_type(owner),
		Callable(self, "_get_registry_instance")
	)
	return true


func _capture_rollback(runtime_state: Object, skill_config: Object, owner: Object) -> void:
	_pending_rollback.clear()
	var runtime_snapshot: Dictionary = {}
	if runtime_state.has_method("build_unlock_save_snapshot"):
		var runtime_value: Variant = runtime_state.call("build_unlock_save_snapshot")
		if runtime_value is Dictionary:
			runtime_snapshot = (runtime_value as Dictionary).duplicate(true)
	_pending_rollback = {
		"runtime_snapshot": runtime_snapshot,
		"equipped_skills": _equipped_skills(skill_config),
		"character_type": _character_type(owner),
		"committed_runtime_snapshot": _runtime_snapshot.duplicate(true),
		"committed_skill_config_snapshot": _skill_config_snapshot.duplicate(true),
	}


func _rollback_operation(owner: Object, registry: Object) -> void:
	if _pending_rollback.is_empty():
		return
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var skill_config := _get_skill_config(owner, registry)
	if runtime_state != null and runtime_state.has_method("cancel_pending_unlock_swap"):
		runtime_state.call("cancel_pending_unlock_swap", owner)
	if skill_config != null:
		_restore_equipped_skills(skill_config, _pending_rollback.get("equipped_skills", []))
	var runtime_snapshot: Dictionary = _pending_rollback.get("runtime_snapshot", {})
	if (
		runtime_state != null
		and not runtime_snapshot.is_empty()
		and runtime_state.has_method("apply_unlock_save_snapshot")
	):
		runtime_state.call("apply_unlock_save_snapshot", runtime_snapshot, owner, registry)
	if skill_config != null:
		_unlock_swap_flow.sync_commando_weapon_controller(
			"",
			skill_config,
			registry,
			str(_pending_rollback.get("character_type", _character_type(owner))),
			Callable(self, "_get_registry_instance")
		)
	_runtime_snapshot = _dictionary(_pending_rollback.get("committed_runtime_snapshot", {}))
	_skill_config_snapshot = _dictionary(
		_pending_rollback.get("committed_skill_config_snapshot", {})
	)


func _capture_committed_snapshots(owner: Object, registry: Object) -> bool:
	_runtime_snapshot.clear()
	_skill_config_snapshot.clear()
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var skill_config := _get_skill_config(owner, registry)
	if runtime_state != null and runtime_state.has_method("build_unlock_save_snapshot"):
		var runtime_value: Variant = runtime_state.call("build_unlock_save_snapshot")
		if runtime_value is Dictionary:
			_runtime_snapshot = (runtime_value as Dictionary).duplicate(true)
	if skill_config != null:
		_skill_config_snapshot = {
			"character_type": _character_type(owner),
			"equipped_skills": _equipped_skills(skill_config),
		}
	return not _runtime_snapshot.is_empty() and not _skill_config_snapshot.is_empty()


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


func _sync_current_runtime_snapshot(runtime_state: Object, owner: Object, registry: Object) -> void:
	if (
		not runtime_state.has_method("build_unlock_save_snapshot")
		or not runtime_state.has_method("apply_unlock_save_snapshot")
	):
		return
	var snapshot_value: Variant = runtime_state.call("build_unlock_save_snapshot")
	if snapshot_value is Dictionary:
		runtime_state.call("apply_unlock_save_snapshot", snapshot_value, owner, registry)


func _find_action(action_id: String, actions: Array[Dictionary]) -> Dictionary:
	for action in actions:
		if str(action.get("id", "")) == action_id:
			return action
	return {}


func _operation_counts(node_id: String) -> Dictionary:
	var counts := {OP_ACQUIRE: 0, OP_SWAP: 0, OP_REMOVE: 0}
	for record in _history:
		if str(record.get("node_id", "")) != node_id:
			continue
		var operation := str(record.get("operation", ""))
		if counts.has(operation):
			counts[operation] = int(counts.get(operation, 0)) + 1
	return counts


func _operation_cost(operation: String) -> int:
	match operation:
		OP_ACQUIRE:
			return TowerAscentTuning.TEMP_PHASE_C_MONK_CHOSIK_ACQUIRE_COST
		OP_SWAP:
			return TowerAscentTuning.TEMP_PHASE_C_MONK_CHOSIK_SWAP_COST
		OP_REMOVE:
			return TowerAscentTuning.TEMP_PHASE_C_MONK_CHOSIK_REMOVE_COST
	return 0


func _operation_limit(operation: String) -> int:
	match operation:
		OP_ACQUIRE:
			return TowerAscentTuning.TEMP_PHASE_C_MONK_ACQUIRE_PER_VISIT
		OP_SWAP:
			return TowerAscentTuning.TEMP_PHASE_C_MONK_SWAP_PER_VISIT
		OP_REMOVE:
			return TowerAscentTuning.TEMP_PHASE_C_MONK_REMOVE_PER_VISIT
	return 0


func _operation_limit_key(operation: String) -> String:
	match operation:
		OP_ACQUIRE:
			return TowerAscentNodeModalLocalization.KEY_MONK_ACQUIRE_USED
		OP_SWAP:
			return TowerAscentNodeModalLocalization.KEY_MONK_SWAP_USED
		OP_REMOVE:
			return TowerAscentNodeModalLocalization.KEY_MONK_REMOVE_USED
	return TowerAscentNodeModalLocalization.KEY_STATUS_DISABLED


func _success_message(operation: String, record: Dictionary) -> String:
	var key := TowerAscentNodeModalLocalization.KEY_MONK_ACQUIRE_COMPLETED
	if operation == OP_SWAP:
		key = TowerAscentNodeModalLocalization.KEY_MONK_SWAP_COMPLETED
	elif operation == OP_REMOVE:
		key = TowerAscentNodeModalLocalization.KEY_MONK_REMOVE_COMPLETED
	return TowerAscentNodeModalLocalization.text(
		key,
		{"name": str(record.get("display_name", ""))}
	)


func _character_type(owner: Object) -> String:
	return _character_context.get_owner_character_type(owner)


func _get_skill_config(owner: Object, registry: Object) -> Object:
	var key: String = str(_character_context.get_skill_config_key(_character_type(owner)))
	return _get_registry_instance(registry, key)


func _runtime_levels(runtime_state: Object) -> Dictionary:
	var value: Variant = runtime_state.get("runtime_skill_levels")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _runtime_levels_reference(runtime_state: Object) -> Dictionary:
	var value: Variant = runtime_state.get("runtime_skill_levels")
	return value as Dictionary if value is Dictionary else {}


func _economy(run_state: Object) -> Dictionary:
	if run_state != null and run_state.has_method("export_economy"):
		var value: Variant = run_state.call("export_economy")
		if value is Dictionary:
			return value as Dictionary
	return {}


func _is_shared_slot_full(skill_config: Object) -> bool:
	return (
		skill_config != null
		and skill_config.has_method("is_shared_slot_full")
		and bool(skill_config.call("is_shared_slot_full"))
	)


func _is_skill_equipped(skill_config: Object, skill_id: String) -> bool:
	return (
		skill_config != null
		and skill_config.has_method("is_skill_equipped")
		and bool(skill_config.call("is_skill_equipped", skill_id))
	)


func _swap_candidates(skill_config: Object, unlocked_skill: String) -> Array:
	if skill_config == null or not skill_config.has_method("get_shared_slot_swap_candidates"):
		return []
	var value: Variant = skill_config.call("get_shared_slot_swap_candidates", unlocked_skill)
	return value as Array if value is Array else []


func _equipped_skills(skill_config: Object) -> Array:
	if skill_config == null:
		return []
	if skill_config.has_method("get_snapshot"):
		var snapshot_value: Variant = skill_config.call("get_snapshot")
		if snapshot_value is Dictionary:
			var equipped_value: Variant = (snapshot_value as Dictionary).get("equipped_skills", [])
			if equipped_value is Array:
				return (equipped_value as Array).duplicate()
	if skill_config.has_method("get_equipped_skills"):
		var equipped_value: Variant = skill_config.call("get_equipped_skills")
		if equipped_value is Array:
			return (equipped_value as Array).duplicate()
	return []


func _skill_data(skill_config: Object, skill_id: String) -> Dictionary:
	if skill_config == null or skill_id.is_empty() or not skill_config.has_method("get_skill_data"):
		return {}
	var value: Variant = skill_config.call("get_skill_data", skill_id)
	return value as Dictionary if value is Dictionary else {}


func _shuffle_with_rng(values: Array[String], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held := values[index]
		values[index] = values[swap_index]
		values[swap_index] = held


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	for method_name in ["get_instance", "get_cached_instance"]:
		if registry.has_method(method_name):
			var value: Variant = registry.call(method_name, key)
			if value is Object and value != null:
				return value as Object
	return null


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry_value in value as Array:
			if entry_value is Dictionary:
				result.append((entry_value as Dictionary).duplicate(true))
	return result


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
