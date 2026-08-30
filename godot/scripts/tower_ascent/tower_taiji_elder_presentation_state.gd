extends RefCounted

const PHASE_CLOSED := "closed"
const PHASE_DIALOGUE := "dialogue"
const PHASE_DECISION := "decision"
const PHASE_RESULT := "result"

const BASE_VIEW_SIZE := Vector2(760.0, 750.0)
const SOURCE_CARD_RECT := Rect2(72.0, 212.0, 282.0, 300.0)
const TARGET_CARD_RECT := Rect2(406.0, 212.0, 282.0, 300.0)
const DIALOGUE_RECT := Rect2(86.0, 510.0, 588.0, 116.0)
const QUESTION_RECT := Rect2(126.0, 526.0, 508.0, 48.0)
const ACCEPT_RECT := Rect2(154.0, 590.0, 204.0, 48.0)
const DECLINE_RECT := Rect2(402.0, 590.0, 204.0, 48.0)
const RESULT_RECT := Rect2(86.0, 526.0, 588.0, 102.0)
const RESULT_HOLD_SEC := 1.5

var _enabled := false
var _phase := PHASE_CLOSED
var _dialogue_lines: Array[String] = []
var _dialogue_index := 0
var _question := ""
var _accept_result := ""
var _decline_result := ""
var _result_text := ""
var _result_accepted := false
var _result_elapsed_sec := 0.0
var _route_ready := false
var _confirmation_ready_pending := false
var _selection := 1
var _pressed_decision := -1
var _dialogue_pointer_armed := false
var _offer_snapshot: Dictionary = {}


func configure(
	enabled: bool,
	offer_snapshot: Dictionary = {},
	dialogue_lines: Array = [],
	question: String = "",
	accept_result: String = "",
	decline_result: String = ""
) -> void:
	reset()
	_enabled = enabled
	if not _enabled:
		return
	_offer_snapshot = offer_snapshot.duplicate(true)
	_dialogue_lines.assign(_string_array(dialogue_lines))
	_question = question
	_accept_result = accept_result
	_decline_result = decline_result
	if bool(_offer_snapshot.get("choice_committed", false)):
		begin_result(bool(_offer_snapshot.get("accepted_exchange", false)))
	else:
		_phase = PHASE_DIALOGUE


func reset() -> void:
	_enabled = false
	_phase = PHASE_CLOSED
	_dialogue_lines.clear()
	_dialogue_index = 0
	_question = ""
	_accept_result = ""
	_decline_result = ""
	_result_text = ""
	_result_accepted = false
	_result_elapsed_sec = 0.0
	_route_ready = false
	_confirmation_ready_pending = false
	_selection = 1
	_pressed_decision = -1
	_dialogue_pointer_armed = false
	_offer_snapshot.clear()


func is_enabled() -> bool:
	return _enabled


func is_dialogue_phase() -> bool:
	return _enabled and _phase == PHASE_DIALOGUE


func is_decision_phase() -> bool:
	return _enabled and _phase == PHASE_DECISION


func is_result_phase() -> bool:
	return _enabled and _phase == PHASE_RESULT


func advance_dialogue() -> bool:
	if not is_dialogue_phase():
		return false
	if _dialogue_lines.is_empty():
		_phase = PHASE_DECISION
		_confirmation_ready_pending = true
		return true
	if _dialogue_index < _dialogue_lines.size() - 1:
		_dialogue_index += 1
		return true
	_phase = PHASE_DECISION
	_confirmation_ready_pending = true
	_pressed_decision = -1
	return true


func take_confirmation_ready() -> bool:
	if not _confirmation_ready_pending:
		return false
	_confirmation_ready_pending = false
	return true


func begin_dialogue_press(
	position: Vector2,
	view_size: Vector2 = BASE_VIEW_SIZE
) -> bool:
	_dialogue_pointer_armed = (
		is_dialogue_phase()
		and _scale_rect(DIALOGUE_RECT, view_size).has_point(position)
	)
	return _dialogue_pointer_armed


func release_dialogue_press(
	position: Vector2,
	view_size: Vector2 = BASE_VIEW_SIZE
) -> bool:
	var activated := (
		is_dialogue_phase()
		and _dialogue_pointer_armed
		and _scale_rect(DIALOGUE_RECT, view_size).has_point(position)
	)
	_dialogue_pointer_armed = false
	return activated


func move_selection(direction: int) -> bool:
	if not is_decision_phase() or direction == 0:
		return false
	var next_selection := 0 if _selection == 1 else 1
	var changed := next_selection != _selection
	_selection = next_selection
	_pressed_decision = -1
	return changed


func get_selected_action_id() -> String:
	if not is_decision_phase():
		return ""
	return "taiji_elder:accept" if _selection == 0 else "taiji_elder:decline"


func begin_pointer_press(position: Vector2, view_size: Vector2 = BASE_VIEW_SIZE) -> bool:
	_pressed_decision = _decision_index_at(position, view_size) if is_decision_phase() else -1
	return _pressed_decision >= 0


func release_pointer_press(position: Vector2, view_size: Vector2 = BASE_VIEW_SIZE) -> String:
	if not is_decision_phase():
		_pressed_decision = -1
		return ""
	var release_index := _decision_index_at(position, view_size)
	var activated := release_index >= 0 and release_index == _pressed_decision
	_pressed_decision = -1
	if not activated:
		return ""
	_selection = release_index
	return get_selected_action_id()


func cancel_pointer_press() -> void:
	_pressed_decision = -1
	_dialogue_pointer_armed = false


func begin_result(accepted_exchange: bool) -> bool:
	if not _enabled:
		return false
	var copy := _accept_result if accepted_exchange else _decline_result
	if copy.is_empty():
		return false
	_phase = PHASE_RESULT
	_result_accepted = accepted_exchange
	_result_text = copy
	_result_elapsed_sec = 0.0
	_route_ready = false
	_confirmation_ready_pending = false
	_pressed_decision = -1
	_dialogue_pointer_armed = false
	_offer_snapshot["choice_committed"] = true
	_offer_snapshot["accepted_exchange"] = accepted_exchange
	return true


func advance_result(delta: float) -> bool:
	if not is_result_phase() or _route_ready:
		return false
	_result_elapsed_sec += minf(0.5, maxf(0.0, delta))
	if _result_elapsed_sec >= RESULT_HOLD_SEC:
		_result_elapsed_sec = RESULT_HOLD_SEC
		_route_ready = true
	return true


func take_route_ready() -> bool:
	if not _route_ready:
		return false
	_route_ready = false
	return true


func get_action_rects(actions: Array, view_size: Vector2 = BASE_VIEW_SIZE) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for action_value in actions:
		var rect := Rect2()
		if is_decision_phase() and action_value is Dictionary:
			match str((action_value as Dictionary).get("id", "")):
				"taiji_elder:accept":
					rect = _scale_rect(ACCEPT_RECT, view_size)
				"taiji_elder:decline":
					rect = _scale_rect(DECLINE_RECT, view_size)
		result.append(rect)
	return result


func build_visual_model(actions: Array, view_size: Vector2 = BASE_VIEW_SIZE) -> Dictionary:
	if not _enabled:
		return {}
	var current_dialogue := ""
	if is_dialogue_phase() and _dialogue_index < _dialogue_lines.size():
		current_dialogue = _dialogue_lines[_dialogue_index]
	var result := _offer_snapshot.duplicate(true)
	result.merge({
		"enabled": true,
		"phase": _phase,
		"dialogue_index": _dialogue_index,
		"dialogue_lines": _dialogue_lines.duplicate(),
		"current_dialogue": current_dialogue,
		"question": _question,
		"result_text": _result_text,
		"result_accepted": _result_accepted,
		"result_elapsed_sec": _result_elapsed_sec,
		"result_hold_sec": RESULT_HOLD_SEC,
		"route_ready": _route_ready,
		"selection": _selection,
		"pressed_decision": _pressed_decision,
		"dialogue_pointer_armed": _dialogue_pointer_armed,
		"source_card_rect": _scale_rect(SOURCE_CARD_RECT, view_size),
		"target_card_rect": _scale_rect(TARGET_CARD_RECT, view_size),
		"dialogue_rect": _scale_rect(DIALOGUE_RECT, view_size),
		"question_rect": _scale_rect(QUESTION_RECT, view_size),
		"accept_rect": _scale_rect(ACCEPT_RECT, view_size),
		"decline_rect": _scale_rect(DECLINE_RECT, view_size),
		"result_rect": _scale_rect(RESULT_RECT, view_size),
		"action_rects": get_action_rects(actions, view_size),
	}, true)
	return result


func get_debug_state() -> Dictionary:
	return {
		"enabled": _enabled,
		"phase": _phase,
		"dialogue_index": _dialogue_index,
		"selection": _selection,
		"result_accepted": _result_accepted,
		"route_ready": _route_ready,
		"confirmation_ready_pending": _confirmation_ready_pending,
	}


func export_state() -> Dictionary:
	if not _enabled:
		return {}
	return {
		"phase": _phase,
		"dialogue_index": _dialogue_index,
		"selection": _selection,
		"result_accepted": _result_accepted,
		"result_elapsed_sec": _result_elapsed_sec,
		"route_ready": _route_ready,
	}


func restore_state(value: Variant) -> bool:
	if not _enabled or not (value is Dictionary):
		return false
	var state := value as Dictionary
	var restored_phase := str(state.get("phase", PHASE_DIALOGUE))
	if restored_phase not in [PHASE_DIALOGUE, PHASE_DECISION, PHASE_RESULT]:
		return false
	var choice_committed := bool(_offer_snapshot.get("choice_committed", false))
	if (restored_phase == PHASE_RESULT) != choice_committed:
		return false
	_phase = restored_phase
	_dialogue_index = clampi(
		int(state.get("dialogue_index", 0)),
		0,
		maxi(0, _dialogue_lines.size() - 1)
	)
	_selection = clampi(int(state.get("selection", 1)), 0, 1)
	_result_accepted = bool(state.get(
		"result_accepted",
		_offer_snapshot.get("accepted_exchange", false)
	))
	_result_text = (
		(_accept_result if _result_accepted else _decline_result)
		if restored_phase == PHASE_RESULT
		else ""
	)
	_result_elapsed_sec = clampf(
		float(state.get("result_elapsed_sec", 0.0)),
		0.0,
		RESULT_HOLD_SEC
	) if restored_phase == PHASE_RESULT else 0.0
	_route_ready = bool(state.get("route_ready", false)) if restored_phase == PHASE_RESULT else false
	_confirmation_ready_pending = false
	_pressed_decision = -1
	_dialogue_pointer_armed = false
	return true


func _decision_index_at(position: Vector2, view_size: Vector2) -> int:
	if _scale_rect(ACCEPT_RECT, view_size).has_point(position):
		return 0
	if _scale_rect(DECLINE_RECT, view_size).has_point(position):
		return 1
	return -1


func _scale_rect(rect: Rect2, view_size: Vector2) -> Rect2:
	var safe_size := Vector2(maxf(1.0, view_size.x), maxf(1.0, view_size.y))
	var scale_value := minf(
		safe_size.x / BASE_VIEW_SIZE.x,
		safe_size.y / BASE_VIEW_SIZE.y
	)
	var offset := (safe_size - BASE_VIEW_SIZE * scale_value) * 0.5
	return Rect2(offset + rect.position * scale_value, rect.size * scale_value)


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for line_value in value as Array:
			result.append(str(line_value))
	return result
