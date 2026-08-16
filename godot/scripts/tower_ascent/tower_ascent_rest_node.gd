extends RefCounted

const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const ACTION_RESTORE := "rest:restore_chance_gem"

var _history: Array[Dictionary] = []


func reset() -> void:
	_history.clear()


func restore_state(value: Variant) -> void:
	_history = _dictionary_array(value)


func get_history() -> Array[Dictionary]:
	return _dictionary_array(_history)


func build_actions(node_id: String, run_state: Object) -> Array[Dictionary]:
	var used := _has_node_commit(node_id)
	var chance_gems := _chance_gems(run_state)
	var full := chance_gems >= TowerAscentRunState.MAX_CHANCE_GEMS
	var enabled := not used and not full
	var disabled_reason := ""
	var unavailable_reason := ""
	if used:
		disabled_reason = "rest_already_used"
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_REST_ALREADY_USED
		)
	elif full:
		disabled_reason = "chance_gems_full"
		unavailable_reason = TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_REST_CHANCE_GEMS_FULL,
			{"maximum": TowerAscentRunState.MAX_CHANCE_GEMS}
		)
	return [{
		"id": ACTION_RESTORE,
		"label": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_REST_RESTORE_OPTION,
			{"amount": TowerAscentTuning.TEMP_PHASE_C_REST_RESTORE_PER_NODE}
		),
		"cost_text": TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_COST_FREE
		),
		"enabled": enabled,
		"disabled_reason": disabled_reason,
		"unavailable_reason": unavailable_reason,
		"payload": {
			"chance_gems": TowerAscentTuning.TEMP_PHASE_C_REST_RESTORE_PER_NODE,
		},
	}]


func execute_action(
	action_id: String,
	resolution_id: String,
	node_id: String,
	run_state: Object,
	resolution_ids: Dictionary,
	action_transaction: Object
) -> Dictionary:
	var normalized_resolution_id := resolution_id.strip_edges()
	if normalized_resolution_id.is_empty():
		return {"accepted": false, "applied": false, "reason": "invalid_resolution_id"}
	if resolution_ids.has(normalized_resolution_id):
		return {
			"accepted": true,
			"applied": false,
			"reason": "already_committed",
			"node_resolution_id": normalized_resolution_id,
		}
	if action_id != ACTION_RESTORE:
		return {"accepted": false, "applied": false, "reason": "unknown_rest_action"}
	var action := build_actions(node_id, run_state)[0]
	if not bool(action.get("enabled", false)):
		return {
			"accepted": false,
			"applied": false,
			"reason": str(action.get("disabled_reason", "rest_action_disabled")),
			"message": str(action.get("unavailable_reason", "")),
		}
	if action_transaction == null or not action_transaction.has_method("apply_once"):
		return {"accepted": false, "applied": false, "reason": "missing_action_transaction"}
	var amount := TowerAscentTuning.TEMP_PHASE_C_REST_RESTORE_PER_NODE
	var result: Dictionary = action_transaction.call(
		"apply_once",
		normalized_resolution_id,
		{},
		{"chance_gems": amount},
		run_state,
		resolution_ids
	)
	if not bool(result.get("accepted", false)) or not bool(result.get("applied", false)):
		return result
	var record := {
		"node_id": node_id,
		"node_resolution_id": normalized_resolution_id,
		"chance_gems": amount,
	}
	_history.append(record)
	result["record"] = record.duplicate(true)
	result["message"] = TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_REST_COMPLETED,
		{"amount": amount}
	)
	return result


func _has_node_commit(node_id: String) -> bool:
	for record in _history:
		if str(record.get("node_id", "")) == node_id:
			return true
	return false


func _chance_gems(run_state: Object) -> int:
	if run_state != null and run_state.has_method("get_chance_gems"):
		return maxi(0, int(run_state.call("get_chance_gems")))
	return 0


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw_value in (value as Array):
			if raw_value is Dictionary:
				result.append((raw_value as Dictionary).duplicate(true))
	return result
