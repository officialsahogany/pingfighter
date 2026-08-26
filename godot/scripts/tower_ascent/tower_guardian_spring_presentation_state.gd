extends RefCounted

const BASE_VIEW_SIZE := Vector2(760.0, 750.0)
const PHASE_CLOSED := "closed"
const PHASE_STATUE := "statue"
const PHASE_MENU := "menu"
const PHASE_ASCEND := "ascend"
const PHASE_REVEAL := "reveal"
const PHASE_CONFIRM := "confirm"
const PHASE_ABSORB := "absorb"
const PHASE_IMPACT := "impact"
const PHASE_PRAYER := "prayer"

const PALM_ASCEND_DURATION_SEC := 3.4
const PALM_REVEAL_DURATION_SEC := 0.4
const PALM_ABSORB_DURATION_SEC := 3.0
const PALM_IMPACT_DURATION_SEC := 0.4
const PRAYER_DURATION_SEC := 2.0
const RITUAL_PHASES := [
	PHASE_ASCEND,
	PHASE_REVEAL,
	PHASE_CONFIRM,
	PHASE_ABSORB,
	PHASE_IMPACT,
	PHASE_PRAYER,
]
const RITUAL_OPERATIONS := ["palm", "prayer"]

const STATUE_RECT := Rect2(218.0, 98.0, 324.0, 486.0)
const DIALOGUE_RECT := Rect2(92.0, 88.0, 576.0, 54.0)
const MENU_CARD_AREA := Rect2(58.0, 506.0, 644.0, 114.0)
const MENU_CARD_GAP := 14.0
const CAPSULE_RECTS := [
	Rect2(39.0, 166.0, 214.0, 285.0),
	Rect2(273.0, 166.0, 214.0, 285.0),
	Rect2(507.0, 166.0, 214.0, 285.0),
]
const CAPSULE_SECONDARY_LEFT_RECT := Rect2(112.0, 617.0, 238.0, 42.0)
const CAPSULE_SECONDARY_RIGHT_RECT := Rect2(410.0, 617.0, 238.0, 42.0)
const END_WORK_RECT := Rect2(246.0, 650.0, 268.0, 40.0)
const RITUAL_ICON_START_RECT := Rect2(322.0, 554.0, 116.0, 116.0)
const RITUAL_ICON_RISEN_RECT := Rect2(322.0, 206.0, 116.0, 116.0)
const CONFIRM_PANEL_RECT := Rect2(126.0, 434.0, 508.0, 176.0)
const CONFIRM_NO_RECT := Rect2(172.0, 532.0, 184.0, 48.0)
const CONFIRM_YES_RECT := Rect2(404.0, 532.0, 184.0, 48.0)

var _enabled := false
var _phase := PHASE_CLOSED
var _elapsed_sec := 0.0
var _phase_elapsed_sec := 0.0
var _ritual_elapsed_sec := 0.0
var _statue_hovered := false
var _statue_pressed := false
var _pending_action: Dictionary = {}
var _ritual_operation := ""
var _completed_action_ready := false
var _action_dispatched := false
var _acquisition_started := false
var _acquisition_start_count := 0
var _action_dispatch_count := 0
var _forced_cleanup_count := 0
var _confirmation_selection := 0
var _confirmation_decline_count := 0
var _acquisition_target_pos := Vector2(380.0, 690.0)


func configure(enabled: bool, acquisition_target_pos: Vector2 = Vector2(380.0, 690.0)) -> void:
	close_scene(false)
	_enabled = enabled
	_acquisition_target_pos = (
		acquisition_target_pos
		if acquisition_target_pos != Vector2.ZERO
		else Vector2(380.0, 690.0)
	)
	if _enabled:
		_phase = PHASE_STATUE


func close_scene(count_forced_cleanup: bool = true) -> void:
	if count_forced_cleanup and is_ritual_active():
		_forced_cleanup_count += 1
	_phase = PHASE_CLOSED
	_enabled = false
	_elapsed_sec = 0.0
	_phase_elapsed_sec = 0.0
	_ritual_elapsed_sec = 0.0
	_statue_hovered = false
	_statue_pressed = false
	_pending_action.clear()
	_ritual_operation = ""
	_completed_action_ready = false
	_action_dispatched = false
	_acquisition_started = false
	_confirmation_selection = 0


func is_enabled() -> bool:
	return _enabled


func is_statue_phase() -> bool:
	return _enabled and _phase == PHASE_STATUE


func is_ritual_active() -> bool:
	return _enabled and _phase in RITUAL_PHASES


func is_confirmation_active() -> bool:
	return _enabled and _phase == PHASE_CONFIRM


func reveal_menu() -> bool:
	if not is_statue_phase():
		return false
	_phase = PHASE_MENU
	_statue_hovered = false
	_statue_pressed = false
	return true


func update_statue_hover(position: Vector2, view_size: Vector2 = BASE_VIEW_SIZE) -> bool:
	if not is_statue_phase():
		return false
	var hovered := get_statue_rect(view_size).has_point(position)
	var changed := hovered != _statue_hovered
	_statue_hovered = hovered
	return changed


func begin_statue_press(position: Vector2, view_size: Vector2 = BASE_VIEW_SIZE) -> bool:
	if not is_statue_phase():
		return false
	_statue_pressed = get_statue_rect(view_size).has_point(position)
	return _statue_pressed


func release_statue_press(position: Vector2, view_size: Vector2 = BASE_VIEW_SIZE) -> bool:
	if not is_statue_phase():
		_statue_pressed = false
		return false
	var activated := _statue_pressed and get_statue_rect(view_size).has_point(position)
	_statue_pressed = false
	return activated


func cancel_pointer_press() -> void:
	_statue_pressed = false


func begin_ritual(action: Dictionary) -> bool:
	var operation := str(_action_payload(action).get("operation", ""))
	if (
		not _enabled
		or _phase != PHASE_MENU
		or operation not in RITUAL_OPERATIONS
		or not bool(action.get("enabled", true))
	):
		return false
	_phase = PHASE_ASCEND if operation == "palm" else PHASE_PRAYER
	_phase_elapsed_sec = 0.0
	_ritual_elapsed_sec = 0.0
	_pending_action = action.duplicate(true)
	_ritual_operation = operation
	_completed_action_ready = false
	_action_dispatched = false
	_acquisition_started = false
	_confirmation_selection = 0
	_statue_hovered = false
	_statue_pressed = false
	return true


func advance(delta: float) -> bool:
	if not _enabled:
		return false
	var step := maxf(0.0, delta)
	_elapsed_sec += step
	if not is_ritual_active() or _phase == PHASE_CONFIRM:
		return step > 0.0
	_ritual_elapsed_sec += step
	_phase_elapsed_sec += step
	_advance_timed_phase()
	return step > 0.0


func confirm_palm_absorption(accepted: bool) -> bool:
	if not is_confirmation_active():
		return false
	if not accepted:
		_confirmation_decline_count += 1
		_return_to_menu_without_dispatch()
		return true
	_phase = PHASE_ABSORB
	_phase_elapsed_sec = 0.0
	_acquisition_started = true
	_acquisition_start_count += 1
	return true


func select_confirmation(index: int) -> bool:
	if not is_confirmation_active():
		return false
	var next_selection := clampi(index, 0, 1)
	var changed := next_selection != _confirmation_selection
	_confirmation_selection = next_selection
	return changed


func activate_confirmation_selection() -> bool:
	return confirm_palm_absorption(_confirmation_selection == 1)


func take_completed_action() -> Dictionary:
	if not _completed_action_ready or _action_dispatched or _pending_action.is_empty():
		return {}
	_action_dispatched = true
	_action_dispatch_count += 1
	_completed_action_ready = false
	_phase = PHASE_MENU
	_phase_elapsed_sec = 0.0
	_ritual_elapsed_sec = 0.0
	var result := _pending_action.duplicate(true)
	_pending_action.clear()
	_ritual_operation = ""
	return result


func get_statue_rect(view_size: Vector2 = BASE_VIEW_SIZE) -> Rect2:
	return _scale_rect(STATUE_RECT, view_size)


func get_dialogue_rect(view_size: Vector2 = BASE_VIEW_SIZE) -> Rect2:
	return _scale_rect(DIALOGUE_RECT, view_size)


func get_action_rects(actions: Array, view_size: Vector2 = BASE_VIEW_SIZE) -> Array[Rect2]:
	var result: Array[Rect2] = []
	result.resize(actions.size())
	if not _enabled or _phase == PHASE_CLOSED or _phase == PHASE_STATUE or is_ritual_active():
		return result
	if _has_capsule_choices(actions):
		return _build_capsule_action_rects(actions, view_size)
	var regular_indices: Array[int] = []
	for index in range(actions.size()):
		if str((actions[index] as Dictionary).get("id", "")) != "end_work":
			regular_indices.append(index)
	var regular_count := mini(3, regular_indices.size())
	var source_width := (
		(MENU_CARD_AREA.size.x - MENU_CARD_GAP * float(maxi(0, regular_count - 1)))
		/ float(maxi(1, regular_count))
	)
	for ordinal in range(regular_indices.size()):
		var action_index := regular_indices[ordinal]
		if ordinal < regular_count:
			result[action_index] = _scale_rect(Rect2(
				MENU_CARD_AREA.position + Vector2(float(ordinal) * (source_width + MENU_CARD_GAP), 0.0),
				Vector2(source_width, MENU_CARD_AREA.size.y)
			), view_size)
	for index in range(actions.size()):
		if str((actions[index] as Dictionary).get("id", "")) == "end_work":
			result[index] = _scale_rect(END_WORK_RECT, view_size)
	return result


func build_visual_model(actions: Array, view_size: Vector2 = BASE_VIEW_SIZE) -> Dictionary:
	if not _enabled:
		return {"enabled": false, "fallback_to_v1": true}
	var action_rects := get_action_rects(actions, view_size)
	var phase_duration := _phase_duration_sec()
	var phase_progress := clampf(_phase_elapsed_sec / maxf(0.001, phase_duration), 0.0, 1.0)
	var icon_rise_progress := phase_progress if _phase == PHASE_ASCEND else 1.0
	var acquisition_progress := phase_progress if _phase == PHASE_ABSORB else (1.0 if _phase == PHASE_IMPACT else 0.0)
	return {
		"enabled": true,
		"fallback_to_v1": false,
		"phase": _phase,
		"statue_rect": get_statue_rect(view_size),
		"statue_hovered": _statue_hovered,
		"statue_pressed": _statue_pressed,
		"dialogue_rect": get_dialogue_rect(view_size),
		"capsule_mode": _has_capsule_choices(actions),
		"action_rects": action_rects,
		"elapsed_sec": _elapsed_sec,
		"operation": _ritual_operation,
		"phase_elapsed_sec": _phase_elapsed_sec,
		"phase_duration_sec": phase_duration,
		"phase_progress": phase_progress,
		"ritual_elapsed_sec": _ritual_elapsed_sec,
		"acquisition_started": _acquisition_started,
		"acquisition_progress": acquisition_progress,
		"acquisition_target_pos": _scale_point(_acquisition_target_pos, view_size),
		"ritual_icon_source_rect": _scale_rect(RITUAL_ICON_RISEN_RECT, view_size),
		"ritual_icon_rect": _build_ritual_icon_rect(
			view_size,
			icon_rise_progress,
			acquisition_progress
		),
		"confirmation_panel_rect": _scale_rect(CONFIRM_PANEL_RECT, view_size),
		"confirmation_no_rect": _scale_rect(CONFIRM_NO_RECT, view_size),
		"confirmation_yes_rect": _scale_rect(CONFIRM_YES_RECT, view_size),
		"confirmation_selection": _confirmation_selection,
		"input_policy": "confirmation_owned" if is_confirmation_active() else "discard_all_no_skip",
	}


func get_debug_state() -> Dictionary:
	return {
		"enabled": _enabled,
		"phase": _phase,
		"statue_hovered": _statue_hovered,
		"statue_pressed": _statue_pressed,
		"ritual_active": is_ritual_active(),
		"confirmation_active": is_confirmation_active(),
		"operation": _ritual_operation,
		"phase_elapsed_sec": _phase_elapsed_sec,
		"ritual_elapsed_sec": _ritual_elapsed_sec,
		"acquisition_started": _acquisition_started,
		"acquisition_start_count": _acquisition_start_count,
		"action_dispatch_count": _action_dispatch_count,
		"confirmation_decline_count": _confirmation_decline_count,
		"confirmation_selection": _confirmation_selection,
		"forced_cleanup_count": _forced_cleanup_count,
		"input_policy": "confirmation_owned" if is_confirmation_active() else "discard_all_no_skip",
	}


func _advance_timed_phase() -> void:
	while true:
		var duration := _phase_duration_sec()
		if duration <= 0.0 or _phase_elapsed_sec < duration:
			return
		_phase_elapsed_sec -= duration
		match _phase:
			PHASE_ASCEND:
				_phase = PHASE_REVEAL
			PHASE_REVEAL:
				_phase = PHASE_CONFIRM
				_phase_elapsed_sec = 0.0
				return
			PHASE_ABSORB:
				_phase = PHASE_IMPACT
			PHASE_IMPACT, PHASE_PRAYER:
				_completed_action_ready = true
				_phase_elapsed_sec = 0.0
				return
			_:
				return


func _phase_duration_sec() -> float:
	match _phase:
		PHASE_ASCEND:
			return PALM_ASCEND_DURATION_SEC
		PHASE_REVEAL:
			return PALM_REVEAL_DURATION_SEC
		PHASE_ABSORB:
			return PALM_ABSORB_DURATION_SEC
		PHASE_IMPACT:
			return PALM_IMPACT_DURATION_SEC
		PHASE_PRAYER:
			return PRAYER_DURATION_SEC
	return 0.0


func _return_to_menu_without_dispatch() -> void:
	_phase = PHASE_MENU
	_phase_elapsed_sec = 0.0
	_ritual_elapsed_sec = 0.0
	_pending_action.clear()
	_ritual_operation = ""
	_completed_action_ready = false
	_action_dispatched = false
	_acquisition_started = false


func _build_capsule_action_rects(actions: Array, view_size: Vector2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	result.resize(actions.size())
	var capsule_ordinal := 0
	var secondary_ordinal := 0
	for index in range(actions.size()):
		var action := actions[index] as Dictionary
		if _is_capsule_action(action):
			if capsule_ordinal < CAPSULE_RECTS.size():
				var source_rect: Rect2 = CAPSULE_RECTS[capsule_ordinal]
				source_rect.position += _capsule_float_offset(capsule_ordinal)
				result[index] = _scale_rect(source_rect, view_size)
			capsule_ordinal += 1
			continue
		if str(action.get("id", "")) == "end_work":
			result[index] = _scale_rect(END_WORK_RECT, view_size)
			continue
		result[index] = _scale_rect(
			CAPSULE_SECONDARY_LEFT_RECT
			if secondary_ordinal == 0
			else CAPSULE_SECONDARY_RIGHT_RECT,
			view_size
		)
		secondary_ordinal += 1
	return result


func _build_ritual_icon_rect(
	view_size: Vector2,
	icon_rise_progress: float,
	acquisition_progress: float
) -> Rect2:
	var eased_rise := 1.0 - pow(1.0 - icon_rise_progress, 3.0)
	var source_rect := Rect2(
		RITUAL_ICON_START_RECT.position.lerp(RITUAL_ICON_RISEN_RECT.position, eased_rise),
		RITUAL_ICON_START_RECT.size
	)
	if acquisition_progress > 0.0:
		var target := _acquisition_target_pos
		var start_center := source_rect.get_center()
		var side := -1.0 if start_center.x > target.x else 1.0
		var control := (start_center + target) * 0.5 + Vector2(side * 52.0, -66.0)
		var eased := acquisition_progress * acquisition_progress * (3.0 - 2.0 * acquisition_progress)
		var inverse := 1.0 - eased
		var center := (
			start_center * inverse * inverse
			+ control * 2.0 * inverse * eased
			+ target * eased * eased
		)
		var scale_factor := lerpf(1.0, 0.12, eased)
		source_rect = Rect2(center - source_rect.size * scale_factor * 0.5, source_rect.size * scale_factor)
	return _scale_rect(source_rect, view_size)


func _capsule_float_offset(capsule_ordinal: int) -> Vector2:
	return Vector2(
		0.0,
		sin(_elapsed_sec * 1.35 + float(capsule_ordinal) * 1.70) * 7.0
	)


func _has_capsule_choices(actions: Array) -> bool:
	var capsule_count := 0
	for action_value in actions:
		if action_value is Dictionary and _is_capsule_action(action_value as Dictionary):
			capsule_count += 1
	return capsule_count == 3


func _is_capsule_action(action: Dictionary) -> bool:
	return str(_action_payload(action).get("operation", "")) in [
		"first_pick",
		"browse_candidate",
	]


func _action_payload(action: Dictionary) -> Dictionary:
	var payload_value: Variant = action.get("payload", {})
	return payload_value as Dictionary if payload_value is Dictionary else {}


func _scale_rect(rect: Rect2, view_size: Vector2) -> Rect2:
	var transform := _content_transform(view_size)
	return Rect2(
		(transform.offset as Vector2) + rect.position * float(transform.scale),
		rect.size * float(transform.scale)
	)


func _scale_point(point: Vector2, view_size: Vector2) -> Vector2:
	var transform := _content_transform(view_size)
	return (transform.offset as Vector2) + point * float(transform.scale)


func _content_transform(view_size: Vector2) -> Dictionary:
	var safe_size := Vector2(maxf(1.0, view_size.x), maxf(1.0, view_size.y))
	var scale_value := minf(safe_size.x / BASE_VIEW_SIZE.x, safe_size.y / BASE_VIEW_SIZE.y)
	return {
		"scale": scale_value,
		"offset": (safe_size - BASE_VIEW_SIZE * scale_value) * 0.5,
	}
