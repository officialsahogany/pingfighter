extends RefCounted


func apply_once(
	resolution_id: String,
	costs: Dictionary,
	rewards: Dictionary,
	run_state: Object,
	committed_resolution_ids: Dictionary,
	effect_callback: Callable = Callable(),
	rollback_callback: Callable = Callable()
) -> Dictionary:
	var normalized_resolution_id := resolution_id.strip_edges()
	if normalized_resolution_id.is_empty():
		return {"accepted": false, "applied": false, "reason": "invalid_resolution_id"}
	if run_state == null or not run_state.has_method("can_afford") or not run_state.has_method("apply_economy_transaction"):
		return {"accepted": false, "applied": false, "reason": "missing_run_state_contract"}
	if committed_resolution_ids.has(normalized_resolution_id):
		return {
			"accepted": true,
			"applied": false,
			"reason": "already_committed",
			"node_resolution_id": normalized_resolution_id,
		}
	var affordability: Dictionary = run_state.call("can_afford", costs)
	if not bool(affordability.get("accepted", false)):
		affordability["applied"] = false
		affordability["node_resolution_id"] = normalized_resolution_id
		return affordability
	if effect_callback.is_valid() and not bool(effect_callback.call()):
		return {
			"accepted": false,
			"applied": false,
			"reason": "effect_rejected",
			"node_resolution_id": normalized_resolution_id,
		}
	var economy_result: Dictionary = run_state.call(
		"apply_economy_transaction",
		costs,
		rewards
	)
	if not bool(economy_result.get("accepted", false)):
		if rollback_callback.is_valid():
			rollback_callback.call()
		economy_result["applied"] = false
		economy_result["node_resolution_id"] = normalized_resolution_id
		return economy_result
	committed_resolution_ids[normalized_resolution_id] = true
	return {
		"accepted": true,
		"applied": true,
		"reason": "committed",
		"node_resolution_id": normalized_resolution_id,
		"costs": economy_result.get("costs", {}),
		"rewards": economy_result.get("rewards", {}),
		"balances_before": affordability.get("balances", {}),
		"balances": economy_result.get("balances", {}),
	}
