extends RefCounted

const RuntimePerkCharacterContext := preload(
	"res://scripts/characters/runtime_perk_character_context.gd"
)
const RuntimePerkUnlockSwapFlow := preload(
	"res://scripts/characters/runtime_perk_unlock_swap_flow.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerAscentPerkCandidatePolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_perk_candidate_policy.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const OFFER_VERSION := "tower_fallen_monk_offer_v2"
const OFFER_GENERATION := 0
const ACTION_PREFIX := "fallen_monk:"
const OP_ACQUIRE := "acquire"
const CHOSIK_CARD_COUNT := 2

var _generated_offers: Array[Dictionary] = []
var _history: Array[Dictionary] = []
var _runtime_snapshot: Dictionary = {}
var _skill_config_snapshot: Dictionary = {}
var _pending_chosik_swap: Dictionary = {}
var _pending_rollback: Dictionary = {}
var _character_context: Object = RuntimePerkCharacterContext.new()
var _candidate_policy: Object = TowerAscentPerkCandidatePolicy.new()
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
	# A pending replacement is an in-session transaction. The matching runtime
	# modal and its rollback snapshot are deliberately not part of stable saves.
	_pending_chosik_swap.clear()
	_pending_rollback.clear()


func reset() -> void:
	_generated_offers.clear()
	_history.clear()
	_runtime_snapshot.clear()
	_skill_config_snapshot.clear()
	_pending_chosik_swap.clear()
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
	if (
		offer.is_empty()
		or has_pending_chosik_swap()
		or _has_committed_visit_pick(node_id)
	):
		return []
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var skill_config := _get_skill_config(owner, registry)
	if runtime_state == null or skill_config == null:
		return []
	var balances := _economy(run_state)
	var result: Array[Dictionary] = []
	for choice_value in offer.get("choices", []):
		if result.size() >= CHOSIK_CARD_COUNT:
			break
		if not (choice_value is Dictionary):
			continue
		var choice := choice_value as Dictionary
		if not _is_live_class_chosik_choice(
			choice,
			runtime_state,
			skill_config,
			owner,
			registry
		):
			continue
		var unlocked_skill := str(choice.get("unlocks_skill", "")).strip_edges()
		result.append(_build_action(
			OP_ACQUIRE,
			choice,
			unlocked_skill,
			balances
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
	if has_pending_chosik_swap():
		return {"accepted": false, "applied": false, "reason": "chosik_swap_pending"}
	if _has_committed_visit_pick(node_id):
		return {"accepted": false, "applied": false, "reason": "fallen_monk_visit_completed"}
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
	var payload := _dictionary(action.get("payload", {}))
	var operation := str(payload.get("operation", ""))
	if operation != OP_ACQUIRE:
		return {"accepted": false, "applied": false, "reason": "invalid_fallen_monk_operation"}
	var cost := TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST
	var effect_context := {
		"operation": operation,
		"choice": _dictionary(payload.get("choice", {})),
		"node_id": node_id,
		"map_seed": map_seed,
		"resolution_id": resolution_id,
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
	if (
		has_pending_chosik_swap()
		and str(_pending_chosik_swap.get("resolution_id", "")) == resolution_id
	):
		return {
			"accepted": true,
			"applied": false,
			"reason": "chosik_swap_opened",
			"node_resolution_id": resolution_id,
			"message": TowerAscentNodeModalLocalization.text(
				TowerAscentNodeModalLocalization.KEY_SPRING_CHOSIK_SWAP_OPENED
			),
		}
	if not bool(transaction_result.get("accepted", false)):
		_pending_rollback.clear()
		return transaction_result
	if not bool(transaction_result.get("applied", false)):
		_pending_rollback.clear()
		return transaction_result
	var choice: Dictionary = effect_context.get("choice", {})
	var record := {
		"node_id": node_id,
		"node_resolution_id": resolution_id,
		"operation": operation,
		"choice_id": str(choice.get("id", "")),
		"unlocked_skill": str(choice.get("unlocks_skill", "")),
		"removed_skill": "",
		"display_name": str(choice.get("name", choice.get("id", ""))),
		"cost": cost,
	}
	_history.append(record)
	_pending_rollback.clear()
	transaction_result["record"] = record.duplicate(true)
	transaction_result["message"] = _success_message(operation, record)
	return transaction_result


func has_pending_chosik_swap() -> bool:
	return not _pending_chosik_swap.is_empty()


func cancel_chosik_swap(owner: Object, registry: Object) -> Dictionary:
	if not has_pending_chosik_swap():
		return {"handled": false, "accepted": false, "reason": "no_pending_chosik_swap"}
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	if runtime_state != null and runtime_state.has_method("cancel_pending_unlock_swap"):
		runtime_state.call("cancel_pending_unlock_swap", owner)
	_pending_chosik_swap.clear()
	_rollback_operation(owner, registry)
	_pending_rollback.clear()
	return {
		"handled": true,
		"accepted": true,
		"applied": false,
		"reason": "chosik_swap_cancelled",
	}


func commit_chosik_swap(
	run_state: Object,
	resolution_ids: Dictionary,
	action_transaction: Object,
	owner: Object,
	registry: Object
) -> Dictionary:
	var pending := _pending_chosik_swap.duplicate(true)
	if pending.is_empty():
		return {"handled": false, "accepted": false, "reason": "no_pending_chosik_swap"}
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	if (
		runtime_state != null
		and runtime_state.has_method("has_pending_unlock_swap")
		and bool(runtime_state.call("has_pending_unlock_swap"))
	):
		return {"handled": false, "accepted": false, "reason": "chosik_swap_still_pending"}
	var skill_config := _get_skill_config(owner, registry)
	var confirmation := _confirmed_swap_postcondition(
		pending,
		runtime_state,
		skill_config
	)
	if not bool(confirmation.get("accepted", false)):
		var cancel_result := cancel_chosik_swap(owner, registry)
		cancel_result["reason"] = "chosik_swap_not_confirmed"
		return cancel_result
	if action_transaction == null or not action_transaction.has_method("apply_once"):
		var missing_result := cancel_chosik_swap(owner, registry)
		missing_result["accepted"] = false
		missing_result["reason"] = "missing_action_transaction"
		return missing_result
	var resolution_id := str(pending.get("resolution_id", "")).strip_edges()
	var result: Dictionary = action_transaction.call(
		"apply_once",
		resolution_id,
		{"muhon": TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST},
		{},
		run_state,
		resolution_ids,
		Callable(self, "_commit_confirmed_swap").bind(pending, owner, registry),
		Callable(self, "_rollback_operation").bind(owner, registry)
	)
	if not bool(result.get("accepted", false)) or not bool(result.get("applied", false)):
		_pending_chosik_swap.clear()
		_rollback_operation(owner, registry)
		_pending_rollback.clear()
		result["handled"] = true
		return result
	var choice := _dictionary(pending.get("choice", {}))
	var record := {
		"node_id": str(pending.get("node_id", "")),
		"node_resolution_id": resolution_id,
		"operation": OP_ACQUIRE,
		"choice_id": str(choice.get("id", "")),
		"unlocked_skill": str(choice.get("unlocks_skill", "")),
		"removed_skill": str(confirmation.get("removed_skill", "")),
		"display_name": str(choice.get("name", choice.get("id", ""))),
		"cost": TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST,
	}
	_history.append(record)
	_pending_chosik_swap.clear()
	_pending_rollback.clear()
	result["handled"] = true
	result["record"] = record.duplicate(true)
	result["message"] = _success_message(OP_ACQUIRE, record)
	return result


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
		var candidate_data := data.duplicate(true)
		candidate_data["id"] = perk_id
		if unlocked_skill.is_empty():
			continue
		if not _candidate_policy.is_chosik_candidate(
			candidate_data,
			runtime_levels,
			character_type,
			registry,
			skill_config
		):
			continue
		if _is_skill_equipped(skill_config, unlocked_skill):
			continue
		candidate_ids.append(perk_id)
	candidate_ids.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("%d:%s:%s:%d" % [
		map_seed,
		node_id,
		OFFER_VERSION,
		OFFER_GENERATION,
	]))
	_shuffle_with_rng(candidate_ids, rng)
	var choices: Array[Dictionary] = []
	var chosik_count := mini(CHOSIK_CARD_COUNT, candidate_ids.size())
	for index in range(chosik_count):
		var choice_value: Variant = catalog.call("get_perk_data", candidate_ids[index])
		if choice_value is Dictionary:
			var choice := (choice_value as Dictionary).duplicate(true)
			choice["id"] = candidate_ids[index]
			choice["current_level"] = 0
			choice["next_level"] = 1
			choices.append(choice)
	return {
		"offer_version": OFFER_VERSION,
		"offer_generation": OFFER_GENERATION,
		"node_id": node_id,
		"character_type": character_type,
		"choices": choices,
	}


func _build_action(
	operation: String,
	choice: Dictionary,
	unlocked_skill: String,
	balances: Dictionary
) -> Dictionary:
	var choice_id := str(choice.get("id", "")).strip_edges()
	var cost := TowerAscentTuning.CHOSIK_SELECTION_MUHON_COST
	var affordable := int(balances.get("muhon", 0)) >= cost
	var enabled := affordable
	var unavailable_reason := ""
	var disabled_reason := ""
	if not affordable:
		disabled_reason = "insufficient_muhon"
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_INSUFFICIENT_MUHON,
			{
				"required": cost,
				"shortfall": cost - int(balances.get("muhon", 0)),
			}
		)
	var new_name := str(choice.get("name", choice_id))
	var action_id := "%s%s:%s" % [ACTION_PREFIX, operation, choice_id]
	return {
		"id": action_id,
		"label": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_MONK_ACQUIRE_OPTION,
			{"name": new_name}
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
			"presentation": {
				"current": "Lv.%d" % int(choice.get("current_level", 0)),
				"result": "Lv.%d" % int(choice.get("next_level", 1)),
				"target": new_name,
			},
		},
	}


func _apply_operation(context: Dictionary) -> bool:
	var owner: Object = context.get("owner", null)
	var registry: Object = context.get("registry", null)
	var runtime_state := _get_registry_instance(registry, "runtime_perk_state")
	var skill_config := _get_skill_config(owner, registry)
	if (
		runtime_state == null
		or skill_config == null
		or not runtime_state.has_method("apply_choice")
		or (
			runtime_state.has_method("has_pending_unlock_swap")
			and bool(runtime_state.call("has_pending_unlock_swap"))
		)
	):
		return false
	_capture_rollback(runtime_state, skill_config, owner)
	if (_pending_rollback.get("runtime_snapshot", {}) as Dictionary).is_empty():
		_pending_rollback.clear()
		return false
	var operation := str(context.get("operation", ""))
	var choice := _dictionary(context.get("choice", {}))
	if operation != OP_ACQUIRE or choice.is_empty():
		_rollback_operation(owner, registry)
		_pending_rollback.clear()
		return false
	if bool(runtime_state.call("apply_choice", choice, owner, registry)):
		if _capture_committed_snapshots(owner, registry):
			return true
		_rollback_operation(owner, registry)
		_pending_rollback.clear()
		return false
	if _runtime_pending_matches_choice(runtime_state, choice):
		_pending_chosik_swap = {
			"node_id": str(context.get("node_id", "")),
			"map_seed": int(context.get("map_seed", 0)),
			"resolution_id": str(context.get("resolution_id", "")),
			"operation": OP_ACQUIRE,
			"choice": choice.duplicate(true),
		}
		return false
	_rollback_operation(owner, registry)
	_pending_rollback.clear()
	return false


func _runtime_pending_matches_choice(runtime_state: Object, choice: Dictionary) -> bool:
	if (
		runtime_state == null
		or not runtime_state.has_method("has_pending_unlock_swap")
		or not bool(runtime_state.call("has_pending_unlock_swap"))
		or not runtime_state.has_method("get_pending_unlock_swap")
	):
		return false
	var pending_value: Variant = runtime_state.call("get_pending_unlock_swap")
	if not (pending_value is Dictionary):
		return false
	var pending := pending_value as Dictionary
	var choice_id := str(choice.get("id", choice.get("perk_id", ""))).strip_edges()
	var unlocked_skill := str(choice.get("unlocks_skill", "")).strip_edges()
	return (
		not choice_id.is_empty()
		and not unlocked_skill.is_empty()
		and str(pending.get("choice_id", "")).strip_edges() == choice_id
		and str(pending.get("unlocks_skill", "")).strip_edges() == unlocked_skill
		and pending.get("candidates", []) is Array
		and not (pending.get("candidates", []) as Array).is_empty()
	)


func _commit_confirmed_swap(
	pending: Dictionary,
	owner: Object,
	registry: Object
) -> bool:
	var confirmation := _confirmed_swap_postcondition(
		pending,
		_get_registry_instance(registry, "runtime_perk_state"),
		_get_skill_config(owner, registry)
	)
	return (
		bool(confirmation.get("accepted", false))
		and _capture_committed_snapshots(owner, registry)
	)


func _confirmed_swap_postcondition(
	pending: Dictionary,
	runtime_state: Object,
	skill_config: Object
) -> Dictionary:
	if runtime_state == null or skill_config == null or _pending_rollback.is_empty():
		return {"accepted": false}
	var choice := _dictionary(pending.get("choice", {}))
	var choice_id := str(choice.get("id", choice.get("perk_id", ""))).strip_edges()
	var unlocked_skill := str(choice.get("unlocks_skill", "")).strip_edges()
	if choice_id.is_empty() or unlocked_skill.is_empty():
		return {"accepted": false}
	var previous_snapshot := _dictionary(_pending_rollback.get("runtime_snapshot", {}))
	var previous_levels := _dictionary(previous_snapshot.get("runtime_skill_levels", {}))
	var current_levels := _runtime_levels(runtime_state)
	if int(current_levels.get(choice_id, 0)) <= int(previous_levels.get(choice_id, 0)):
		return {"accepted": false}
	var previous_equipped := _array(_pending_rollback.get("equipped_skills", []))
	var current_equipped := _equipped_skills(skill_config)
	if not current_equipped.has(unlocked_skill) or current_equipped.size() != previous_equipped.size():
		return {"accepted": false}
	var removed_skill := ""
	for skill_value in previous_equipped:
		var skill_id := str(skill_value)
		if current_equipped.has(skill_id):
			continue
		if not removed_skill.is_empty():
			return {"accepted": false}
		removed_skill = skill_id
	if removed_skill.is_empty():
		return {"accepted": false}
	return {"accepted": true, "removed_skill": removed_skill}


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
		"skill_config_rollback_snapshot": _capture_skill_config_rollback_snapshot(
			skill_config
		),
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
		_restore_skill_config_rollback_snapshot(
			skill_config,
			_pending_rollback.get("skill_config_rollback_snapshot", {})
		)
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
	if _has_property(skill_config, "equipped_skills"):
		var typed_original: Array[String] = []
		for skill_value in original:
			typed_original.append(str(skill_value))
		skill_config.set("equipped_skills", typed_original)
		return _equipped_skills(skill_config) == original
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


func _capture_skill_config_rollback_snapshot(skill_config: Object) -> Dictionary:
	if skill_config == null:
		return {}
	for method_name in ["build_save_snapshot", "get_save_snapshot"]:
		if not skill_config.has_method(method_name):
			continue
		var value: Variant = skill_config.call(method_name)
		if value is Dictionary and not (value as Dictionary).is_empty():
			return {
				"restore_method": "apply_save_snapshot",
				"payload": (value as Dictionary).duplicate(true),
			}
	return {"equipped_skills": _equipped_skills(skill_config)}


func _restore_skill_config_rollback_snapshot(
	skill_config: Object,
	snapshot_value: Variant
) -> bool:
	var snapshot := _dictionary(snapshot_value)
	if snapshot.is_empty():
		return false
	if (
		str(snapshot.get("restore_method", "")) == "apply_save_snapshot"
		and skill_config.has_method("apply_save_snapshot")
	):
		var result_value: Variant = skill_config.call(
			"apply_save_snapshot",
			_dictionary(snapshot.get("payload", {}))
		)
		return not (result_value is Dictionary) or bool(
			(result_value as Dictionary).get("restored", false)
		)
	return _restore_equipped_skills(
		skill_config,
		snapshot.get("equipped_skills", [])
	)


func _find_action(action_id: String, actions: Array[Dictionary]) -> Dictionary:
	for action in actions:
		if str(action.get("id", "")) == action_id:
			return action
	return {}


func _has_committed_visit_pick(node_id: String) -> bool:
	for record in _history:
		if str(record.get("node_id", "")) == node_id:
			return true
	return false


func _success_message(_operation: String, record: Dictionary) -> String:
	return TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_MONK_ACQUIRE_COMPLETED,
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


func _is_live_class_chosik_choice(
	choice: Dictionary,
	runtime_state: Object,
	skill_config: Object,
	owner: Object,
	registry: Object
) -> bool:
	if runtime_state == null or skill_config == null:
		return false
	var choice_id := str(choice.get("id", choice.get("perk_id", ""))).strip_edges()
	var unlocked_skill := str(choice.get("unlocks_skill", "")).strip_edges()
	if choice_id.is_empty() or unlocked_skill.is_empty():
		return false
	if _is_skill_equipped(skill_config, unlocked_skill):
		return false
	return _candidate_policy.is_chosik_candidate(
		choice,
		_runtime_levels(runtime_state),
		_character_type(owner),
		registry,
		skill_config
	)


func _economy(run_state: Object) -> Dictionary:
	if run_state != null and run_state.has_method("export_economy"):
		var value: Variant = run_state.call("export_economy")
		if value is Dictionary:
			return value as Dictionary
	return {}


func _is_skill_equipped(skill_config: Object, skill_id: String) -> bool:
	return (
		skill_config != null
		and skill_config.has_method("is_skill_equipped")
		and bool(skill_config.call("is_skill_equipped", skill_id))
	)


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


func _has_property(instance: Object, property_name: String) -> bool:
	if instance == null:
		return false
	for property_value in instance.get_property_list():
		if (
			property_value is Dictionary
			and str((property_value as Dictionary).get("name", "")) == property_name
		):
			return true
	return false


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry_value in value as Array:
			if entry_value is Dictionary:
				result.append((entry_value as Dictionary).duplicate(true))
	return result


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
