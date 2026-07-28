extends RefCounted

const PHASE_ROLL := "roll"
const PHASE_REACTION := "reaction"
const ROLL_SECONDS := 0.58
const ASSET_GATE_MAX_HOLD_SECONDS := 3.0

var active := false
var phase := PHASE_ROLL
var elapsed := 0.0
var reaction_elapsed := 0.0
var pet_id := ""
var result: Dictionary = {}
var _asset_gate_hold_elapsed := 0.0
var _animation_contract: Dictionary = {}


func start(display_pet_id: String, applied_result: Dictionary) -> bool:
	var normalized_pet_id := display_pet_id.strip_edges().to_lower()
	if normalized_pet_id == "" or not bool(applied_result.get("accepted", false)):
		return false
	active = true
	phase = PHASE_ROLL
	elapsed = 0.0
	reaction_elapsed = 0.0
	pet_id = normalized_pet_id
	result = applied_result.duplicate(true)
	_asset_gate_hold_elapsed = 0.0
	_animation_contract.clear()
	return true


func advance(
	delta: float,
	assets_ready: bool = true,
	animation_contract: Dictionary = {}
) -> bool:
	if not active:
		return false
	var safe_delta := maxf(0.0, delta)
	if phase == PHASE_ROLL:
		elapsed += safe_delta
		if elapsed < ROLL_SECONDS:
			return false
		if not assets_ready:
			_asset_gate_hold_elapsed += safe_delta
			if _asset_gate_hold_elapsed < ASSET_GATE_MAX_HOLD_SECONDS:
				elapsed = ROLL_SECONDS
				return false
		_begin_reaction(animation_contract)
		return false
	reaction_elapsed += safe_delta
	return _finish_reaction_if_complete()


func cancel_immediate() -> bool:
	if not active:
		return false
	reset()
	return true


func reset() -> void:
	active = false
	phase = PHASE_ROLL
	elapsed = 0.0
	reaction_elapsed = 0.0
	pet_id = ""
	result.clear()
	_asset_gate_hold_elapsed = 0.0
	_animation_contract.clear()


func get_roll_progress() -> float:
	return clampf(elapsed / ROLL_SECONDS, 0.0, 1.0)


func get_animation_frame() -> int:
	var frame_count := maxi(1, int(_animation_contract.get("frame_count", 1)))
	var frame_interval := maxf(0.001, float(_animation_contract.get("frame_interval", 0.10)))
	return clampi(int(floor(reaction_elapsed / frame_interval)), 0, frame_count - 1)


func get_snapshot() -> Dictionary:
	return {
		"active": active,
		"phase": phase,
		"pet_id": pet_id,
		"roll_progress": get_roll_progress(),
		"reaction_active": active and phase == PHASE_REACTION,
		"reaction_elapsed": reaction_elapsed,
		"animation_frame": get_animation_frame(),
		"animation_contract": _animation_contract.duplicate(true),
		"idle_fallback": bool(_animation_contract.get("idle_fallback", false)),
		"result": result.duplicate(true),
		"feedback_text": str(result.get("feedback_text", "강화 획득")),
	}


func _begin_reaction(animation_contract: Dictionary) -> void:
	phase = PHASE_REACTION
	reaction_elapsed = 0.0
	_animation_contract = animation_contract.duplicate(true)


func _finish_reaction_if_complete() -> bool:
	var frame_count := maxi(1, int(_animation_contract.get("frame_count", 1)))
	var frame_interval := maxf(0.001, float(_animation_contract.get("frame_interval", 0.10)))
	if reaction_elapsed < float(frame_count) * frame_interval:
		return false
	reset()
	return true
