extends RefCounted

const PHASE_CLOSED := "closed"
const PHASE_DORMANT := "dormant"
const PHASE_INTRO := "intro"
const PHASE_MENU := "menu"
const PHASE_RESULT := "result"

const BASE_VIEW_SIZE := Vector2(760.0, 750.0)
const FIRE_RECT := Rect2(294.0, 232.0, 172.0, 172.0)
const CHOICE_RECTS := [
	Rect2(132.0, 458.0, 496.0, 52.0),
	Rect2(132.0, 522.0, 496.0, 52.0),
	Rect2(132.0, 586.0, 496.0, 52.0),
]
const INTRO_LINE_SECONDS := 1.25
const RESULT_LINE_SECONDS := 1.35

var _enabled := false
var _phase := PHASE_CLOSED
var _intro_lines: Array[String] = []
var _result_lines: Array[String] = []
var _dialogue_index := 0
var _elapsed_sec := 0.0
var _result_action_id := ""
var _fire_hovered := false
var _fire_pressed := false
var _route_ready := false


func configure(
	enabled: bool,
	intro_lines: Array = [],
	restored_action_id: String = "",
	restored_result_lines: Array = []
) -> void:
	reset()
	_enabled = enabled
	if not _enabled:
		return
	_intro_lines = _string_array(intro_lines)
	_phase = PHASE_DORMANT
	var restored_id := restored_action_id.strip_edges()
	var restored_lines := _string_array(restored_result_lines)
	if not restored_id.is_empty() and not restored_lines.is_empty():
		_result_action_id = restored_id
		_result_lines = restored_lines
		_phase = PHASE_RESULT


func reset() -> void:
	_enabled = false
	_phase = PHASE_CLOSED
	_intro_lines.clear()
	_result_lines.clear()
	_dialogue_index = 0
	_elapsed_sec = 0.0
	_result_action_id = ""
	_fire_hovered = false
	_fire_pressed = false
	_route_ready = false


func is_enabled() -> bool:
	return _enabled


func is_ignition_phase() -> bool:
	return _enabled and _phase == PHASE_DORMANT


func is_menu_phase() -> bool:
	return _enabled and _phase == PHASE_MENU


func is_sequence_input_locked() -> bool:
	return _enabled and _phase in [PHASE_INTRO, PHASE_RESULT]


func ignite() -> bool:
	if not is_ignition_phase():
		return false
	_fire_pressed = false
	_fire_hovered = false
	_dialogue_index = 0
	_elapsed_sec = 0.0
	_phase = PHASE_INTRO if not _intro_lines.is_empty() else PHASE_MENU
	return true


func begin_result(action_id: String, lines: Array) -> bool:
	var normalized_action_id := action_id.strip_edges()
	var normalized_lines := _string_array(lines)
	if (
		not _enabled
		or normalized_action_id.is_empty()
		or normalized_lines.is_empty()
	):
		return false
	_result_action_id = normalized_action_id
	_result_lines = normalized_lines
	_dialogue_index = 0
	_elapsed_sec = 0.0
	_phase = PHASE_RESULT
	_fire_hovered = false
	_fire_pressed = false
	_route_ready = false
	return true


func advance(delta: float) -> bool:
	if not _enabled or _phase not in [PHASE_INTRO, PHASE_RESULT]:
		return false
	# Cap one presentation step so a hitch cannot skip retained player copy.
	_elapsed_sec += minf(0.5, maxf(0.0, delta))
	var duration := (
		INTRO_LINE_SECONDS if _phase == PHASE_INTRO else RESULT_LINE_SECONDS
	)
	while _elapsed_sec >= duration:
		_elapsed_sec -= duration
		_dialogue_index += 1
		if _phase == PHASE_INTRO and _dialogue_index >= _intro_lines.size():
			_phase = PHASE_MENU
			_dialogue_index = 0
			_elapsed_sec = 0.0
			return true
		if _phase == PHASE_RESULT and _dialogue_index >= _result_lines.size():
			_dialogue_index = maxi(0, _result_lines.size() - 1)
			_elapsed_sec = 0.0
			_route_ready = true
			return true
	return true


func take_route_ready() -> bool:
	if not _route_ready:
		return false
	_route_ready = false
	return true


func update_fire_hover(position: Vector2, view_size: Vector2 = BASE_VIEW_SIZE) -> bool:
	if not is_ignition_phase():
		return false
	var next_hovered := get_fire_rect(view_size).has_point(position)
	var changed := next_hovered != _fire_hovered
	_fire_hovered = next_hovered
	return changed


func begin_fire_press(position: Vector2, view_size: Vector2 = BASE_VIEW_SIZE) -> bool:
	if not is_ignition_phase():
		return false
	_fire_pressed = get_fire_rect(view_size).has_point(position)
	return _fire_pressed


func release_fire_press(position: Vector2, view_size: Vector2 = BASE_VIEW_SIZE) -> bool:
	if not is_ignition_phase():
		_fire_pressed = false
		return false
	var activated := _fire_pressed and get_fire_rect(view_size).has_point(position)
	_fire_pressed = false
	return activated


func cancel_pointer_press() -> void:
	_fire_pressed = false


func get_fire_rect(view_size: Vector2 = BASE_VIEW_SIZE) -> Rect2:
	return _scale_rect(FIRE_RECT, view_size)


func get_action_rects(actions: Array, view_size: Vector2 = BASE_VIEW_SIZE) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var choice_index := 0
	for action_value in actions:
		var rect := Rect2()
		if (
			_phase == PHASE_MENU
			and action_value is Dictionary
			and str((action_value as Dictionary).get("id", "")) != "end_work"
			and choice_index < CHOICE_RECTS.size()
		):
			rect = _scale_rect(CHOICE_RECTS[choice_index], view_size)
			choice_index += 1
		result.append(rect)
	return result


func build_visual_model(
	actions: Array,
	view_size: Vector2 = BASE_VIEW_SIZE
) -> Dictionary:
	if not _enabled:
		return {}
	var dialogue_text := ""
	if _phase == PHASE_INTRO and _dialogue_index < _intro_lines.size():
		dialogue_text = _intro_lines[_dialogue_index]
	elif _phase == PHASE_RESULT and _dialogue_index < _result_lines.size():
		dialogue_text = _result_lines[_dialogue_index]
	var banana_result := _result_action_id == "rest:cook_banana"
	return {
		"enabled": true,
		"phase": _phase,
		"intro_lines": _intro_lines.duplicate(),
		"result_lines": _result_lines.duplicate(),
		"dialogue_text": dialogue_text,
		"dialogue_index": _dialogue_index,
		"result_action_id": _result_action_id,
		"menu_visible": _phase == PHASE_MENU,
		"fire_rect": get_fire_rect(view_size),
		"fire_hovered": _fire_hovered,
		"fire_pressed": _fire_pressed,
		"flame_intensity": _flame_intensity(),
		"rainbow_glow": banana_result and _phase == PHASE_RESULT and _dialogue_index >= 1,
		"elapsed_sec": _elapsed_sec,
		"action_rects": get_action_rects(actions, view_size),
		"route_ready": _route_ready,
	}


func get_debug_state() -> Dictionary:
	return {
		"enabled": _enabled,
		"phase": _phase,
		"dialogue_index": _dialogue_index,
		"result_action_id": _result_action_id,
		"route_ready": _route_ready,
		"intro_line_count": _intro_lines.size(),
		"result_line_count": _result_lines.size(),
	}


func export_state() -> Dictionary:
	if not _enabled:
		return {}
	return {
		"phase": _phase,
		"dialogue_index": _dialogue_index,
		"elapsed_sec": _elapsed_sec,
		"result_action_id": _result_action_id,
		"route_ready": _route_ready,
	}


func restore_state(value: Variant) -> bool:
	if not _enabled or not (value is Dictionary):
		return false
	var state := value as Dictionary
	var restored_phase := str(state.get("phase", PHASE_DORMANT))
	if restored_phase not in [PHASE_DORMANT, PHASE_INTRO, PHASE_MENU, PHASE_RESULT]:
		return false
	var restored_action_id := str(state.get("result_action_id", "")).strip_edges()
	var configured_result_action_id := _result_action_id
	if restored_phase == PHASE_RESULT:
		if (
			restored_action_id.is_empty()
			or restored_action_id != configured_result_action_id
			or _result_lines.is_empty()
		):
			return false
		_result_action_id = restored_action_id
	else:
		if not configured_result_action_id.is_empty():
			return false
		_result_action_id = ""
		_result_lines.clear()
	_phase = restored_phase
	var line_count := (
		_result_lines.size() if _phase == PHASE_RESULT else _intro_lines.size()
	)
	_dialogue_index = clampi(
		int(state.get("dialogue_index", 0)),
		0,
		maxi(0, line_count - 1)
	)
	_elapsed_sec = maxf(0.0, float(state.get("elapsed_sec", 0.0)))
	_route_ready = bool(state.get("route_ready", false)) if _phase == PHASE_RESULT else false
	_fire_hovered = false
	_fire_pressed = false
	return true


func _flame_intensity() -> float:
	match _phase:
		PHASE_DORMANT:
			return 0.42 + (0.16 if _fire_hovered else 0.0)
		PHASE_INTRO:
			return lerpf(0.62, 1.08, clampf(_elapsed_sec / 0.55, 0.0, 1.0))
		PHASE_MENU:
			return 0.92
		PHASE_RESULT:
			return 1.26 if _result_action_id == "rest:cook_banana" else 1.02
	return 0.0


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
			var line := str(line_value)
			if not line.is_empty():
				result.append(line)
	return result
