extends RefCounted

const REVEAL_SECONDS := 1.15
const DISMISS_SECONDS := 0.75
const ASSET_GATE_FRACTION := 0.52
const ASSET_GATE_MAX_HOLD_SECONDS := 3.0

var active := false
var elapsed := 0.0
var dismissing := false
var dismiss_elapsed := 0.0
var pet_id := ""
var result: Dictionary = {}
var _asset_gate_hold_elapsed := 0.0


func start(display_pet_id: String, applied_result: Dictionary) -> bool:
	var normalized_pet_id := display_pet_id.strip_edges().to_lower()
	if normalized_pet_id == "" or not bool(applied_result.get("accepted", false)):
		return false
	active = true
	elapsed = 0.0
	dismissing = false
	dismiss_elapsed = 0.0
	pet_id = normalized_pet_id
	result = applied_result.duplicate(true)
	_asset_gate_hold_elapsed = 0.0
	return true


func advance(delta: float, assets_ready: bool = true) -> bool:
	if not active:
		return false
	var before_active := active
	var safe_delta := maxf(0.0, delta)
	if dismissing:
		dismiss_elapsed += safe_delta
		if dismiss_elapsed >= DISMISS_SECONDS:
			reset()
		return before_active != active
	elapsed += safe_delta
	if not assets_ready:
		var gate_cap := REVEAL_SECONDS * ASSET_GATE_FRACTION
		if elapsed > gate_cap:
			_asset_gate_hold_elapsed += safe_delta
			if _asset_gate_hold_elapsed < ASSET_GATE_MAX_HOLD_SECONDS:
				elapsed = gate_cap
	return false


func is_awaiting_dismiss() -> bool:
	return active and not dismissing and elapsed >= REVEAL_SECONDS


func begin_dismiss() -> bool:
	if not is_awaiting_dismiss():
		return false
	dismissing = true
	dismiss_elapsed = 0.0
	return true


func cancel_immediate() -> bool:
	if not active:
		return false
	reset()
	return true


func reset() -> void:
	active = false
	elapsed = 0.0
	dismissing = false
	dismiss_elapsed = 0.0
	pet_id = ""
	result.clear()
	_asset_gate_hold_elapsed = 0.0


func get_progress() -> float:
	return clampf(elapsed / REVEAL_SECONDS, 0.0, 1.0)


func get_dismiss_progress() -> float:
	return clampf(dismiss_elapsed / DISMISS_SECONDS, 0.0, 1.0)


func get_snapshot() -> Dictionary:
	return {
		"active": active,
		"pet_id": pet_id,
		"progress": get_progress(),
		"awaiting_dismiss": is_awaiting_dismiss(),
		"dismissing": dismissing,
		"dismiss_progress": get_dismiss_progress(),
		"result": result.duplicate(true),
		"feedback_text": str(result.get("feedback_text", "강화 완료")),
	}
