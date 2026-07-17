extends SceneTree

const MysticDiceModalFlow := preload("res://scripts/characters/mystic_dice_modal_flow.gd")
const MysticDiceModalInput := preload("res://scripts/characters/mystic_dice_modal_input.gd")
const MysticDiceModalLayout := preload("res://scripts/characters/mystic_dice_modal_layout.gd")

var _failures: Array[String] = []


func _init() -> void:
	var helper := MysticDiceModalInput.new()
	var layout := MysticDiceModalLayout.new()
	var snapshot := {
		"phase": MysticDiceModalFlow.PHASE_RESULT,
		"rerolls_remaining": 2,
		"selected_action": MysticDiceModalFlow.ACTION_CONFIRM,
	}
	var view_size := Vector2(760.0, 750.0)
	var rects: Dictionary = layout.get_action_rects(snapshot, view_size)

	var motion := InputEventMouseMotion.new()
	motion.position = (rects.get("reroll", Rect2()) as Rect2).get_center()
	_expect(int(helper.resolve(motion, snapshot, view_size).get("selected_action", -1)) == MysticDiceModalFlow.ACTION_REROLL, "mouse hover should resolve reroll")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = (rects.get("confirm", Rect2()) as Rect2).get_center()
	var click_action: Dictionary = helper.resolve(click, snapshot, view_size)
	_expect(int(click_action.get("selected_action", -1)) == MysticDiceModalFlow.ACTION_CONFIRM and bool(click_action.get("activate", false)), "mouse confirm click should select and activate confirm")

	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_RIGHT
	_expect(int(helper.resolve(key, snapshot, view_size).get("move", 0)) == 1, "right key should move D2 selection")
	key.keycode = KEY_ENTER
	_expect(bool(helper.resolve(key, snapshot, view_size).get("activate", false)), "enter should activate the selected D2 action")
	key.keycode = KEY_ESCAPE
	_expect(bool(helper.resolve(key, snapshot, view_size).get("cancel", false)), "escape should be consumed as the no-cancel action")

	helper.suppress_confirm_until_release()
	_expect(not bool(helper.resolve(_rt_axis(0.60), snapshot, view_size).get("activate", false)), "held parent RT must not cascade into D1/D2")
	helper.resolve(_rt_axis(0.10), snapshot, view_size)
	_expect(bool(helper.resolve(_rt_axis(0.60), snapshot, view_size).get("activate", false)), "released then pressed RT should emit one activation edge")
	_expect(not bool(helper.resolve(_rt_axis(0.90), snapshot, view_size).get("activate", false)), "held RT must not emit a second edge")

	if _failures.is_empty():
		print("mystic_dice_modal_input_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _rt_axis(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_RIGHT
	event.axis_value = value
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
