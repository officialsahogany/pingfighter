extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const MysticDiceModalLayout := preload("res://scripts/characters/mystic_dice_modal_layout.gd")

var _layout := MysticDiceModalLayout.new()
var _rt_confirm_latched := false


func suppress_confirm_until_release() -> void:
	_rt_confirm_latched = true


func reset() -> void:
	_rt_confirm_latched = false


func resolve(event: InputEvent, snapshot: Dictionary, view_size: Vector2) -> Dictionary:
	if event == null:
		return {"consumed": false}
	if GamepadInput.is_gamepad_event(event):
		if event is InputEventJoypadMotion:
			var trigger_motion := event as InputEventJoypadMotion
			if trigger_motion.axis == JOY_AXIS_TRIGGER_RIGHT:
				if trigger_motion.axis_value <= GamepadInput.PRIMARY_ACTION_TRIGGER_SUPPRESS_RELEASE_THRESHOLD:
					_rt_confirm_latched = false
					return {"consumed": true}
				if trigger_motion.axis_value >= GamepadInput.TRIGGER_DEADZONE:
					if _rt_confirm_latched:
						return {"consumed": true}
					_rt_confirm_latched = true
					return {"consumed": true, "activate": true}
		var direction := GamepadInput.get_menu_horizontal_event(event)
		if direction != 0:
			return {"consumed": true, "move": direction}
		if GamepadInput.is_confirm_event(event):
			return {"consumed": true, "activate": true}
		if GamepadInput.is_cancel_event(event):
			return {"consumed": true, "cancel": true}
		return {"consumed": true}
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return {"consumed": true}
		match key_event.keycode:
			KEY_LEFT, KEY_UP:
				return {"consumed": true, "move": -1}
			KEY_RIGHT, KEY_DOWN:
				return {"consumed": true, "move": 1}
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z:
				return {"consumed": true, "activate": true}
			KEY_ESCAPE, KEY_X:
				return {"consumed": true, "cancel": true}
		return {"consumed": true}
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		return {
			"consumed": true,
			"selected_action": _layout.get_action_index_at(snapshot, motion.position, view_size),
		}
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
			return {"consumed": true}
		var selected_action := _layout.get_action_index_at(snapshot, mouse.position, view_size)
		if selected_action >= 0:
			return {
				"consumed": true,
				"selected_action": selected_action,
				"activate": true,
			}
		return {"consumed": true}
	return {"consumed": true}
