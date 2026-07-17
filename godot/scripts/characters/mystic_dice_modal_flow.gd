extends RefCounted

const PHASE_INACTIVE := "inactive"
const PHASE_ROLLING := "rolling"
const PHASE_RESULT := "result"
const PHASE_COMMITTED := "committed"

const ACTION_REROLL := 0
const ACTION_CONFIRM := 1
const ROLL_DURATION := 2.0
const MAX_REROLLS := 2
const HOVER_TIME_WRAP := 1024.0

var _phase := PHASE_INACTIVE
var _card: Dictionary = {}
var _origin_choices: Array = []
var _current_roll: Dictionary = {}
var _committed_result: Dictionary = {}
var _committed_choice: Dictionary = {}
var _phase_elapsed := 0.0
var _rerolls_used := 0
var _selected_action := ACTION_CONFIRM
var _roll_generation := 0
var _commit_request_emitted := false


func start(card: Dictionary, origin_choices: Array, roll_payload: Dictionary) -> bool:
	reset()
	if card.is_empty() or not _is_valid_roll_payload(roll_payload):
		return false
	_card = card.duplicate(true)
	_origin_choices = origin_choices.duplicate(true)
	_current_roll = roll_payload.duplicate(true)
	_phase = PHASE_ROLLING
	_roll_generation = 1
	return true


func is_active() -> bool:
	return _phase != PHASE_INACTIVE


func get_phase() -> String:
	return _phase


func get_snapshot() -> Dictionary:
	return {
		"phase": _phase,
		"card": _card.duplicate(true),
		"origin_choices": _origin_choices.duplicate(true),
		"current_roll": _current_roll.duplicate(true),
		"committed_result": _committed_result.duplicate(true),
		"committed_choice": _committed_choice.duplicate(true),
		"phase_elapsed": _phase_elapsed,
		"roll_duration": ROLL_DURATION,
		"rerolls_used": _rerolls_used,
		"rerolls_remaining": get_rerolls_remaining(),
		"selected_action": _selected_action,
		"roll_generation": _roll_generation,
		"commit_request_emitted": _commit_request_emitted,
	}


func update(delta_seconds: float) -> Dictionary:
	if _phase in [PHASE_RESULT, PHASE_COMMITTED]:
		# D2 may be left open indefinitely. Keep a bounded animation clock so the
		# hover renderer never accumulates an unbounded tumble angle or loses
		# trigonometric precision after a long pause.
		_phase_elapsed = fmod(_phase_elapsed + maxf(0.0, delta_seconds), HOVER_TIME_WRAP)
		return {"entered_result": false}
	if _phase != PHASE_ROLLING:
		return {"entered_result": false}
	_phase_elapsed = minf(ROLL_DURATION, _phase_elapsed + maxf(0.0, delta_seconds))
	if _phase_elapsed < ROLL_DURATION:
		return {"entered_result": false}
	_phase = PHASE_RESULT
	_phase_elapsed = 0.0
	_selected_action = ACTION_CONFIRM
	return {
		"entered_result": true,
		"roll": _current_roll.duplicate(true),
	}


func get_rerolls_remaining() -> int:
	return maxi(0, MAX_REROLLS - _rerolls_used)


func move_selection(direction: int) -> bool:
	if _phase != PHASE_RESULT or direction == 0:
		return false
	var available_actions := _available_actions()
	var current_index := available_actions.find(_selected_action)
	if current_index < 0:
		current_index = 0
	_selected_action = int(available_actions[posmod(current_index + direction, available_actions.size())])
	return true


func set_selected_action(action_index: int) -> bool:
	if _phase != PHASE_RESULT or action_index not in _available_actions():
		return false
	_selected_action = action_index
	return true


func request_selected_action() -> Dictionary:
	if _phase == PHASE_COMMITTED:
		return {"consumed": true, "finish_requested": true}
	if _phase != PHASE_RESULT:
		return {"consumed": true, "blocked_reason": "roll_in_progress"}
	if _selected_action == ACTION_REROLL and get_rerolls_remaining() > 0:
		return {"consumed": true, "reroll_requested": true}
	if _commit_request_emitted:
		return {
			"consumed": true,
			"commit_requested": false,
			"already_requested": true,
		}
	_commit_request_emitted = true
	return {
		"consumed": true,
		"commit_requested": true,
		"raw": (_current_roll.get("raw", {}) as Dictionary).duplicate(true),
		"benefits": (_current_roll.get("benefits", {}) as Dictionary).duplicate(true),
	}


func begin_reroll(roll_payload: Dictionary) -> bool:
	if _phase != PHASE_RESULT or get_rerolls_remaining() <= 0 or not _is_valid_roll_payload(roll_payload):
		return false
	_current_roll = roll_payload.duplicate(true)
	_rerolls_used += 1
	_roll_generation += 1
	_phase = PHASE_ROLLING
	_phase_elapsed = 0.0
	_selected_action = ACTION_CONFIRM
	_commit_request_emitted = false
	return true


func reject_commit_request() -> void:
	if _phase == PHASE_RESULT:
		_commit_request_emitted = false


func mark_committed(commit_result: Dictionary, committed_choice: Dictionary) -> bool:
	if _phase != PHASE_RESULT or not _commit_request_emitted or not bool(commit_result.get("accepted", false)):
		return false
	_committed_result = commit_result.duplicate(true)
	_committed_choice = committed_choice.duplicate(true)
	_phase = PHASE_COMMITTED
	_phase_elapsed = 0.0
	return true


func reset() -> void:
	_phase = PHASE_INACTIVE
	_card.clear()
	_origin_choices.clear()
	_current_roll.clear()
	_committed_result.clear()
	_committed_choice.clear()
	_phase_elapsed = 0.0
	_rerolls_used = 0
	_selected_action = ACTION_CONFIRM
	_roll_generation = 0
	_commit_request_emitted = false


func _available_actions() -> Array[int]:
	var actions: Array[int] = []
	if get_rerolls_remaining() > 0:
		actions.append(ACTION_REROLL)
	actions.append(ACTION_CONFIRM)
	return actions


func _is_valid_roll_payload(roll_payload: Dictionary) -> bool:
	return (
		bool(roll_payload.get("accepted", false))
		and roll_payload.get("raw", null) is Dictionary
		and (roll_payload.get("raw", {}) as Dictionary).size() == 7
		and roll_payload.get("benefits", null) is Dictionary
		and (roll_payload.get("benefits", {}) as Dictionary).size() == 7
	)
