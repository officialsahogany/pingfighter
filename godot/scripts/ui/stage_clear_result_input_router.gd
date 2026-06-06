extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")

const ROUTE_NONE := "none"
const ROUTE_CONSUME := "consume"
const ROUTE_MYTHIC_ACQUISITION := "mythic_acquisition"
const ROUTE_RUNTIME_PERK := "runtime_perk"
const ROUTE_TREASURE_HUNT := "treasure_hunt"
const ROUTE_ADVANCE := "advance"
const ROUTE_ESCAPE := "escape"
const ROUTE_MOUSE_DRAG_UPDATE := "mouse_drag_update"
const ROUTE_MOUSE_HOVER_BUTTON := "mouse_hover_button"
const ROUTE_MOUSE_HOVER_BOX := "mouse_hover_box"
const ROUTE_MOUSE_DRAG_FINISH := "mouse_drag_finish"
const ROUTE_MOUSE_LEFT_PRESS := "mouse_left_press"


static func get_input_router_context(
	mythic_acquisition_active: bool,
	runtime_perk_choice_active: bool,
	treasure_hunt_effect_active: bool,
	scroll_dragging: bool,
	scroll_phase: String
) -> Dictionary:
	return {
		"mythic_acquisition_active": mythic_acquisition_active,
		"runtime_perk_choice_active": runtime_perk_choice_active,
		"treasure_hunt_effect_active": treasure_hunt_effect_active,
		"scroll_dragging": scroll_dragging,
		"scroll_phase": scroll_phase,
	}


static func get_result_input_route(event: InputEvent, context: Dictionary) -> Dictionary:
	if bool(context.get("mythic_acquisition_active", false)):
		return _route(ROUTE_MYTHIC_ACQUISITION, true)
	if bool(context.get("runtime_perk_choice_active", false)):
		return _route(ROUTE_RUNTIME_PERK, true)
	if bool(context.get("treasure_hunt_effect_active", false)):
		return _route(ROUTE_TREASURE_HUNT, true)

	if GamepadInput.is_gamepad_event(event):
		if GamepadInput.is_confirm_event(event):
			return _route(ROUTE_ADVANCE, true)
		if GamepadInput.is_cancel_event(event):
			return _route(ROUTE_ESCAPE, true)
		return _route(ROUTE_CONSUME, true)

	if event is InputEventKey:
		return _get_key_route(event)
	if event is InputEventMouseMotion:
		return _get_mouse_motion_route(event, context)
	if event is InputEventMouseButton:
		return _get_mouse_button_route(event, context)
	return _route(ROUTE_CONSUME, true)


static func _get_key_route(event: InputEventKey) -> Dictionary:
	if not event.pressed or event.echo:
		return _route(ROUTE_NONE, false)
	match event.keycode:
		KEY_ENTER, KEY_SPACE:
			return _route(ROUTE_ADVANCE, true)
		KEY_ESCAPE:
			return _route(ROUTE_ESCAPE, true)
	return _route(ROUTE_NONE, false)


static func _get_mouse_motion_route(event: InputEventMouseMotion, context: Dictionary) -> Dictionary:
	if bool(context.get("scroll_dragging", false)):
		return _route_with_position(ROUTE_MOUSE_DRAG_UPDATE, event.position)
	if str(context.get("scroll_phase", "")) == StageClearResultInteractionState.PHASE_VISIBLE:
		return _route_with_position(ROUTE_MOUSE_HOVER_BUTTON, event.position)
	return _route_with_position(ROUTE_MOUSE_HOVER_BOX, event.position)


static func _get_mouse_button_route(event: InputEventMouseButton, context: Dictionary) -> Dictionary:
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if bool(context.get("scroll_dragging", false)):
			return _route_with_position(ROUTE_MOUSE_DRAG_FINISH, event.position)
		return _route(ROUTE_CONSUME, true)
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		return _route_with_position(ROUTE_MOUSE_LEFT_PRESS, event.position)
	return _route(ROUTE_CONSUME, true)


static func _route(route: String, consumed: bool) -> Dictionary:
	return {
		"route": route,
		"consumed": consumed,
	}


static func _route_with_position(route: String, mouse_position: Vector2) -> Dictionary:
	var result: Dictionary = _route(route, true)
	result["mouse_position"] = mouse_position
	return result
