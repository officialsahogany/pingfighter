extends RefCounted

const STATUS_AWAITING_RESOLUTION := "awaiting_resolution"

var _applied_resolution_ids: Dictionary = {}


func reset() -> void:
	_applied_resolution_ids.clear()


func prepare(
	run_id: String,
	node_id: String,
	resolution_kind: String,
	reward_source: String,
	reward_bundle: Dictionary,
	requested_resolution_id: String = ""
) -> Dictionary:
	var normalized_run_id := run_id.strip_edges()
	var normalized_node_id := node_id.strip_edges()
	var normalized_kind := resolution_kind.strip_edges()
	if normalized_run_id.is_empty() or normalized_node_id.is_empty() or normalized_kind.is_empty():
		return {}
	var resolution_id := requested_resolution_id.strip_edges()
	if resolution_id.is_empty():
		resolution_id = "%s:%s:%s" % [normalized_run_id, normalized_node_id, normalized_kind]
	return {
		"run_id": normalized_run_id,
		"node_id": normalized_node_id,
		"node_resolution_id": resolution_id,
		"resolution_kind": normalized_kind,
		"reward_source": reward_source.strip_edges(),
		"reward_bundle": _sanitize_reward_bundle(reward_bundle),
		"status": STATUS_AWAITING_RESOLUTION,
	}


func apply_once(
	pending: Dictionary,
	run_state: Object,
	completed_resolution_ids: Dictionary
) -> Dictionary:
	var validation := validate_pending(pending)
	if not bool(validation.get("accepted", false)):
		return validation
	var resolution_id := str(pending.get("node_resolution_id", ""))
	if completed_resolution_ids.has(resolution_id):
		return {
			"accepted": true,
			"applied": false,
			"reason": "already_committed",
			"node_resolution_id": resolution_id,
		}
	if _applied_resolution_ids.has(resolution_id):
		return {
			"accepted": true,
			"applied": false,
			"reason": "already_applied_in_process",
			"node_resolution_id": resolution_id,
		}
	if run_state == null or not run_state.has_method("apply_reward_bundle"):
		return {"accepted": false, "applied": false, "reason": "missing_run_state"}
	var apply_result: Dictionary = run_state.call(
		"apply_reward_bundle",
		pending.get("reward_bundle", {})
	)
	_applied_resolution_ids[resolution_id] = true
	return {
		"accepted": true,
		"applied": true,
		"reason": "reward_applied",
		"node_resolution_id": resolution_id,
		"reward_result": apply_result,
	}


func mark_committed(resolution_id: String) -> void:
	_applied_resolution_ids.erase(resolution_id)


func validate_pending(pending: Dictionary, expected_run_id: String = "") -> Dictionary:
	var resolution_id := str(pending.get("node_resolution_id", "")).strip_edges()
	var run_id := str(pending.get("run_id", "")).strip_edges()
	var node_id := str(pending.get("node_id", "")).strip_edges()
	var resolution_kind := str(pending.get("resolution_kind", "")).strip_edges()
	if resolution_id.is_empty() or run_id.is_empty() or node_id.is_empty() or resolution_kind.is_empty():
		return {"accepted": false, "applied": false, "reason": "malformed_pending_record"}
	if not expected_run_id.is_empty() and run_id != expected_run_id:
		return {"accepted": false, "applied": false, "reason": "run_id_mismatch"}
	if str(pending.get("status", "")) != STATUS_AWAITING_RESOLUTION:
		return {"accepted": false, "applied": false, "reason": "invalid_pending_status"}
	var bundle_variant: Variant = pending.get("reward_bundle", {})
	if not (bundle_variant is Dictionary):
		return {"accepted": false, "applied": false, "reason": "invalid_reward_bundle"}
	return {"accepted": true, "applied": false, "reason": "pending_valid"}


func _sanitize_reward_bundle(reward_bundle: Dictionary) -> Dictionary:
	return {
		"gold": maxi(0, int(reward_bundle.get("gold", 0))),
		"muhon": maxi(0, int(reward_bundle.get("muhon", 0))),
		"chance_gems": maxi(0, int(reward_bundle.get("chance_gems", 0))),
	}
