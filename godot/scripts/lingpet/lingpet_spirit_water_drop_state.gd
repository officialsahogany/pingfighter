extends RefCounted

# Run-scoped natural-drop latch for the guardian-only spirit water item.
# A queued portal item is only pending; the one-per-stage latch is consumed
# after the item is materialized in the field.
const SAVE_DROPPED_THIS_STAGE_KEY := "spirit_water_dropped_this_stage"
const VALUE_EPSILON := 0.001

var _drop_consumed := false
var _drop_pending := false


func reset_run() -> void:
	_drop_consumed = false
	_drop_pending = false


func can_offer(has_owned_guardian: bool, pool_current: float, pool_max: float) -> bool:
	return (
		has_owned_guardian
		and not _drop_consumed
		and not _drop_pending
		and pool_max > 0.0
		and pool_current < pool_max - VALUE_EPSILON
	)


func mark_drop_pending() -> bool:
	if _drop_consumed or _drop_pending:
		return false
	_drop_pending = true
	return true


func cancel_pending_drop() -> bool:
	if not _drop_pending:
		return false
	_drop_pending = false
	return true


func mark_drop_succeeded() -> bool:
	if _drop_consumed:
		return false
	_drop_pending = false
	_drop_consumed = true
	return true


func rearm_for_stage_transition() -> void:
	_drop_consumed = false
	_drop_pending = false


func is_drop_consumed() -> bool:
	return _drop_consumed


func is_drop_pending() -> bool:
	return _drop_pending


func export_run_state() -> Dictionary:
	return {SAVE_DROPPED_THIS_STAGE_KEY: _drop_consumed}


func import_run_state(data: Dictionary) -> void:
	_drop_consumed = bool(data.get(SAVE_DROPPED_THIS_STAGE_KEY, false))
	# Portal queues are not serialized. A pending item that never materialized
	# must remain eligible after restore, so pending is deliberately cleared.
	_drop_pending = false


func get_snapshot() -> Dictionary:
	return {
		"drop_consumed": _drop_consumed,
		"drop_pending": _drop_pending,
	}
