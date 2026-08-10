extends SceneTree

const PlazaInteriorInputPolicy := preload("res://scripts/plaza/plaza_interior_input_policy.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_key_priority()
	_verify_pointer_priority()
	_verify_trade_mouse_priority()
	if _failures.is_empty():
		print("plaza_interior_input_policy_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_key_priority() -> void:
	_expect_action(_resolve_key(KEY_ESCAPE, false, false, false), PlazaInteriorInputPolicy.ACTION_CLOSE_VIEW, "street escape closes view")
	_expect_action(_resolve_key(KEY_ESCAPE, true, false, false), PlazaInteriorInputPolicy.ACTION_CLOSE_TRADE, "trade escape closes trade")
	_expect_action(_resolve_key(KEY_ESCAPE, true, true, false), PlazaInteriorInputPolicy.ACTION_CLEAR_TRADE_CONFIRM, "confirm escape clears confirmation first")
	_expect_action(_resolve_key(KEY_ENTER, false, false, true), PlazaInteriorInputPolicy.ACTION_CONFIRM_SELECTED, "enter confirms object panel")
	_expect_action(_resolve_key(KEY_SPACE, false, false, true), PlazaInteriorInputPolicy.ACTION_CONFIRM_SELECTED, "space confirms object panel")
	var digit := _resolve_key(KEY_4, false, false, false)
	_expect_action(digit, PlazaInteriorInputPolicy.ACTION_OPEN_ACTION_INDEX, "digit opens indexed object")
	_expect(int(digit.get("action_index", -1)) == 3, "digit action index should stay zero-based")
	_expect_action(_resolve_key(KEY_4, true, false, true), PlazaInteriorInputPolicy.ACTION_CONSUME, "open trade consumes digit before object shortcut")

	var released := InputEventKey.new()
	released.keycode = KEY_ESCAPE
	released.pressed = false
	_expect_action(PlazaInteriorInputPolicy.resolve(released, false, false, false), PlazaInteriorInputPolicy.ACTION_CONSUME, "released key is consumed without action")
	var echoed := InputEventKey.new()
	echoed.keycode = KEY_ESCAPE
	echoed.pressed = true
	echoed.echo = true
	_expect_action(PlazaInteriorInputPolicy.resolve(echoed, false, false, false), PlazaInteriorInputPolicy.ACTION_CONSUME, "echoed key is consumed without action")


func _verify_pointer_priority() -> void:
	var motion := InputEventMouseMotion.new()
	_expect_action(PlazaInteriorInputPolicy.resolve(motion, false, false, false), PlazaInteriorInputPolicy.ACTION_UPDATE_OBJECT_HOVER, "street motion updates object hover")
	_expect_action(PlazaInteriorInputPolicy.resolve(motion, true, false, false), PlazaInteriorInputPolicy.ACTION_UPDATE_TRADE_POINTER, "trade motion updates drag and trade hover")
	_expect_action(_resolve_mouse(MOUSE_BUTTON_LEFT, true, false, false, false), PlazaInteriorInputPolicy.ACTION_LEFT_CLICK, "street left press activates object")
	_expect_action(_resolve_mouse(MOUSE_BUTTON_LEFT, false, false, false, false), PlazaInteriorInputPolicy.ACTION_CONSUME, "street left release is consumed")


func _verify_trade_mouse_priority() -> void:
	_expect_action(_resolve_mouse(MOUSE_BUTTON_LEFT, true, true, false, true), PlazaInteriorInputPolicy.ACTION_BEGIN_TRADE_DRAG, "inside modal left press starts drag")
	_expect_action(_resolve_mouse(MOUSE_BUTTON_LEFT, false, true, false, true), PlazaInteriorInputPolicy.ACTION_FINISH_TRADE_DRAG, "left release finishes drag")
	_expect_action(_resolve_mouse(MOUSE_BUTTON_LEFT, true, true, false, false), PlazaInteriorInputPolicy.ACTION_DISMISS_TRADE, "outside modal left press dismisses trade")
	var wheel_up := _resolve_mouse(MOUSE_BUTTON_WHEEL_UP, true, true, false, true)
	_expect_action(wheel_up, PlazaInteriorInputPolicy.ACTION_TRADE_SCROLL, "wheel up scrolls trade")
	_expect(int(wheel_up.get("direction", 0)) == -1, "wheel up direction")
	var wheel_down := _resolve_mouse(MOUSE_BUTTON_WHEEL_DOWN, true, true, false, true)
	_expect_action(wheel_down, PlazaInteriorInputPolicy.ACTION_TRADE_SCROLL, "wheel down scrolls trade")
	_expect(int(wheel_down.get("direction", 0)) == 1, "wheel down direction")
	_expect_action(_resolve_mouse(MOUSE_BUTTON_RIGHT, true, true, false, true), PlazaInteriorInputPolicy.ACTION_TRADE_AT_POSITION, "trade right press performs direct trade")
	_expect_action(_resolve_mouse(MOUSE_BUTTON_LEFT, true, true, true, false), PlazaInteriorInputPolicy.ACTION_TRADE_CONFIRM_MOUSE, "confirmation captures mouse before modal dismissal")
	_expect_action(_resolve_mouse(MOUSE_BUTTON_RIGHT, true, true, true, false), PlazaInteriorInputPolicy.ACTION_TRADE_CONFIRM_MOUSE, "confirmation captures right press")


func _resolve_key(keycode: Key, trade_open: bool, confirm_open: bool, panel_open: bool) -> Dictionary:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return PlazaInteriorInputPolicy.resolve(event, trade_open, confirm_open, panel_open)


func _resolve_mouse(
	button_index: MouseButton,
	pressed: bool,
	trade_open: bool,
	confirm_open: bool,
	inside_modal: bool
) -> Dictionary:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	return PlazaInteriorInputPolicy.resolve(event, trade_open, confirm_open, false, inside_modal)


func _expect_action(decision: Dictionary, expected: StringName, label: String) -> void:
	var actual: StringName = decision.get("action", &"")
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
