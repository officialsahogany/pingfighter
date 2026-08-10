extends RefCounted

const ACTION_CONSUME := &"consume"
const ACTION_CLEAR_TRADE_CONFIRM := &"clear_trade_confirm"
const ACTION_CLOSE_TRADE := &"close_trade"
const ACTION_DISMISS_TRADE := &"dismiss_trade"
const ACTION_CLOSE_VIEW := &"close_view"
const ACTION_CONFIRM_SELECTED := &"confirm_selected"
const ACTION_OPEN_ACTION_INDEX := &"open_action_index"
const ACTION_UPDATE_TRADE_POINTER := &"update_trade_pointer"
const ACTION_UPDATE_OBJECT_HOVER := &"update_object_hover"
const ACTION_TRADE_CONFIRM_MOUSE := &"trade_confirm_mouse"
const ACTION_TRADE_SCROLL := &"trade_scroll"
const ACTION_TRADE_AT_POSITION := &"trade_at_position"
const ACTION_BEGIN_TRADE_DRAG := &"begin_trade_drag"
const ACTION_FINISH_TRADE_DRAG := &"finish_trade_drag"
const ACTION_LEFT_CLICK := &"left_click"


static func resolve(
	event: InputEvent,
	trade_ui_open: bool,
	trade_confirm_open: bool,
	object_panel_open: bool,
	inside_trade_modal: bool = false
) -> Dictionary:
	if event is InputEventKey:
		return _resolve_key(event as InputEventKey, trade_ui_open, trade_confirm_open, object_panel_open)
	if event is InputEventMouseMotion:
		return {
			"action": ACTION_UPDATE_TRADE_POINTER if trade_ui_open else ACTION_UPDATE_OBJECT_HOVER,
		}
	if event is InputEventMouseButton:
		return _resolve_mouse_button(event as InputEventMouseButton, trade_ui_open, trade_confirm_open, inside_trade_modal)
	return {"action": ACTION_CONSUME}


static func _resolve_key(
	event: InputEventKey,
	trade_ui_open: bool,
	trade_confirm_open: bool,
	object_panel_open: bool
) -> Dictionary:
	if not event.pressed or event.echo:
		return {"action": ACTION_CONSUME}
	if event.keycode == KEY_ESCAPE:
		if trade_ui_open:
			return {
				"action": ACTION_CLEAR_TRADE_CONFIRM if trade_confirm_open else ACTION_CLOSE_TRADE,
			}
		return {"action": ACTION_CLOSE_VIEW}
	if trade_ui_open:
		return {"action": ACTION_CONSUME}
	if object_panel_open and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
		return {"action": ACTION_CONFIRM_SELECTED}
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		return {
			"action": ACTION_OPEN_ACTION_INDEX,
			"action_index": int(event.keycode - KEY_1),
		}
	return {"action": ACTION_CONSUME}


static func _resolve_mouse_button(
	event: InputEventMouseButton,
	trade_ui_open: bool,
	trade_confirm_open: bool,
	inside_trade_modal: bool
) -> Dictionary:
	if trade_ui_open:
		if trade_confirm_open:
			return {"action": ACTION_TRADE_CONFIRM_MOUSE}
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			return {"action": ACTION_TRADE_SCROLL, "direction": -1}
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			return {"action": ACTION_TRADE_SCROLL, "direction": 1}
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			return {"action": ACTION_TRADE_AT_POSITION}
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				return {
					"action": ACTION_BEGIN_TRADE_DRAG if inside_trade_modal else ACTION_DISMISS_TRADE,
				}
			return {"action": ACTION_FINISH_TRADE_DRAG}
		return {"action": ACTION_CONSUME}
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		return {"action": ACTION_LEFT_CLICK}
	return {"action": ACTION_CONSUME}
