extends RefCounted

const PHASE_INTRO := "intro"
const PHASE_ROLL := "roll"
const PHASE_STAMP := "stamp"
const PHASE_REACTION := "reaction"
const PHASE_OUTRO := "outro"

const INTRO_SECONDS := 0.14
const ROLL_SECONDS := 0.75
const STAMP_SECONDS := 0.22
const OUTRO_SECONDS := 0.16
const ASSET_GATE_MAX_HOLD_SECONDS := 3.0

var active := false
var phase := PHASE_INTRO
var phase_elapsed := 0.0
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
	phase = PHASE_INTRO
	phase_elapsed = 0.0
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
	var remaining := maxf(0.0, delta)
	# Five timed phases plus the bounded asset gate fit in seven transitions. The
	# guard makes malformed zero-duration edits fail closed instead of spinning.
	for _transition_guard in range(8):
		match phase:
			PHASE_INTRO:
				remaining = _consume_phase_time(remaining, INTRO_SECONDS)
				if phase_elapsed < INTRO_SECONDS:
					return false
				_enter_phase(PHASE_ROLL)
			PHASE_ROLL:
				remaining = _consume_phase_time(remaining, ROLL_SECONDS)
				if phase_elapsed < ROLL_SECONDS:
					return false
				if not assets_ready and _asset_gate_hold_elapsed < ASSET_GATE_MAX_HOLD_SECONDS:
					var gate_remaining := ASSET_GATE_MAX_HOLD_SECONDS - _asset_gate_hold_elapsed
					var gate_consumed := minf(remaining, gate_remaining)
					_asset_gate_hold_elapsed += gate_consumed
					remaining -= gate_consumed
					if _asset_gate_hold_elapsed < ASSET_GATE_MAX_HOLD_SECONDS:
						return false
				_animation_contract = animation_contract.duplicate(true)
				_enter_phase(PHASE_STAMP)
			PHASE_STAMP:
				remaining = _consume_phase_time(remaining, STAMP_SECONDS)
				if phase_elapsed < STAMP_SECONDS:
					return false
				_enter_phase(PHASE_REACTION)
				reaction_elapsed = 0.0
			PHASE_REACTION:
				var reaction_seconds := _get_reaction_duration()
				var before := phase_elapsed
				remaining = _consume_phase_time(remaining, reaction_seconds)
				reaction_elapsed += phase_elapsed - before
				if phase_elapsed < reaction_seconds:
					return false
				reaction_elapsed = reaction_seconds
				_enter_phase(PHASE_OUTRO)
			PHASE_OUTRO:
				remaining = _consume_phase_time(remaining, OUTRO_SECONDS)
				if phase_elapsed < OUTRO_SECONDS:
					return false
				reset()
				return true
			_:
				reset()
				return true
		if remaining <= 0.0:
			return false
	reset()
	return true


func cancel_immediate() -> bool:
	if not active:
		return false
	reset()
	return true


func reset() -> void:
	active = false
	phase = PHASE_INTRO
	phase_elapsed = 0.0
	reaction_elapsed = 0.0
	pet_id = ""
	result.clear()
	_asset_gate_hold_elapsed = 0.0
	_animation_contract.clear()


func get_phase_progress() -> float:
	return clampf(phase_elapsed / _get_phase_duration(), 0.0, 1.0)


func get_roll_progress() -> float:
	if phase == PHASE_INTRO:
		return 0.0
	if phase != PHASE_ROLL:
		return 1.0
	return clampf(phase_elapsed / ROLL_SECONDS, 0.0, 1.0)


func get_animation_frame() -> int:
	var frame_count := maxi(1, int(_animation_contract.get("frame_count", 1)))
	var frame_interval := maxf(0.001, float(_animation_contract.get("frame_interval", 0.10)))
	return clampi(int(floor(reaction_elapsed / frame_interval)), 0, frame_count - 1)


func get_snapshot() -> Dictionary:
	return {
		"active": active,
		"phase": phase,
		"phase_elapsed": phase_elapsed,
		"phase_progress": get_phase_progress(),
		"pet_id": pet_id,
		"roll_progress": get_roll_progress(),
		"reaction_active": active and phase == PHASE_REACTION,
		"reaction_elapsed": reaction_elapsed,
		"animation_frame": get_animation_frame(),
		"animation_contract": _animation_contract.duplicate(true),
		"idle_fallback": bool(_animation_contract.get("idle_fallback", false)),
		"asset_gate_hold_elapsed": _asset_gate_hold_elapsed,
		"result": result.duplicate(true),
		"feedback_text": str(result.get("feedback_text", "강화 획득")),
	}


func _consume_phase_time(remaining: float, duration: float) -> float:
	var needed := maxf(0.0, duration - phase_elapsed)
	var consumed := minf(maxf(0.0, remaining), needed)
	phase_elapsed += consumed
	return maxf(0.0, remaining - consumed)


func _enter_phase(next_phase: String) -> void:
	phase = next_phase
	phase_elapsed = 0.0


func _get_phase_duration() -> float:
	match phase:
		PHASE_INTRO:
			return INTRO_SECONDS
		PHASE_ROLL:
			return ROLL_SECONDS
		PHASE_STAMP:
			return STAMP_SECONDS
		PHASE_REACTION:
			return _get_reaction_duration()
		PHASE_OUTRO:
			return OUTRO_SECONDS
	return 1.0


func _get_reaction_duration() -> float:
	var frame_count := maxi(1, int(_animation_contract.get("frame_count", 1)))
	var frame_interval := maxf(0.001, float(_animation_contract.get("frame_interval", 0.10)))
	return float(frame_count) * frame_interval
