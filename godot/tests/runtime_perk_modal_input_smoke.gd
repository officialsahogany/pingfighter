extends SceneTree

const RuntimePerkModalInput := preload("res://scripts/characters/runtime_perk_modal_input.gd")

var _failures: Array[String] = []
var _active := true
var _flight_active := false
var _showcase_active := false
var _pending_swap := false
var _choice_move_calls := 0
var _choice_move_delta := 0
var _choice_choose_calls := 0
var _choice_selected_index := -1
var _swap_move_calls := 0
var _swap_move_delta := 0
var _swap_confirm_calls := 0
var _swap_cancel_calls := 0
var _swap_selected_index := -1
var _showcase_calls := 0


func _init() -> void:
	_verify_choice_input_routing()
	_verify_unlock_swap_input_routing()
	_verify_runtime_state_facade_routes_modal_input()
	_verify_state_source_contract()

	if _failures.is_empty():
		print("runtime_perk_modal_input_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_choice_input_routing() -> void:
	var helper := RuntimePerkModalInput.new()
	var callbacks := _callbacks()
	_reset_calls()
	_active = false
	_expect(not helper.handle_input(_key(KEY_RIGHT), null, null, Vector2(1280.0, 720.0), callbacks), "inactive choice modal should not consume input")

	_active = true
	_flight_active = true
	_expect(helper.handle_input(_key(KEY_RIGHT), null, null, Vector2(1280.0, 720.0), callbacks), "active flight should consume input")
	_expect(_choice_move_calls == 0, "active flight should not route selection input")

	_flight_active = false
	_showcase_active = true
	_expect(helper.handle_input(_key(KEY_ENTER), null, null, Vector2(1280.0, 720.0), callbacks), "unlock showcase should consume input through its callback")
	_expect(_showcase_calls == 1, "unlock showcase should receive routed input once")

	_showcase_active = false
	_expect(helper.handle_input(_key(KEY_RIGHT), null, null, Vector2(1280.0, 720.0), callbacks), "right key should be consumed")
	_expect(_choice_move_calls == 1 and _choice_move_delta == 1, "right key should move choice selection")
	_expect(helper.handle_input(_key(KEY_LEFT), null, null, Vector2(1280.0, 720.0), callbacks), "left key should be consumed")
	_expect(_choice_move_calls == 2 and _choice_move_delta == -1, "left key should move choice selection backward")
	_expect(helper.handle_input(_key(KEY_ENTER), null, null, Vector2(1280.0, 720.0), callbacks), "confirm key should be consumed")
	_expect(_choice_choose_calls == 1, "confirm key should choose the selected perk")

	_expect(helper.handle_input(_mouse_motion(Vector2(2.0, 10.0)), null, null, Vector2(1280.0, 720.0), callbacks), "choice mouse motion should be consumed")
	_expect(_choice_selected_index == 2, "choice mouse motion should route hover selection")
	_expect(helper.handle_input(_mouse_click(Vector2(3.0, 10.0)), null, null, Vector2(1280.0, 720.0), callbacks), "choice mouse click should be consumed")
	_expect(_choice_selected_index == 3 and _choice_choose_calls == 2, "choice mouse click should select and choose")

	_expect(helper.handle_input(_axis(JOY_AXIS_LEFT_X, 0.86), null, null, Vector2(1280.0, 720.0), callbacks), "choice gamepad navigation should be consumed")
	_expect(_choice_move_delta == 1, "choice gamepad navigation should route horizontal movement")
	_expect(helper.handle_input(_joy_button(JOY_BUTTON_A), null, null, Vector2(1280.0, 720.0), callbacks), "choice gamepad confirm should be consumed")
	_expect(_choice_choose_calls == 3, "choice gamepad confirm should choose the selected perk")


func _verify_unlock_swap_input_routing() -> void:
	var helper := RuntimePerkModalInput.new()
	var callbacks := _callbacks()
	_reset_calls()
	_active = true
	_pending_swap = true
	_expect(helper.handle_input(_key(KEY_RIGHT), null, null, Vector2(1280.0, 720.0), callbacks), "swap right key should be consumed")
	_expect(_swap_move_calls == 1 and _swap_move_delta == 1, "swap right key should move swap selection")
	_expect(helper.handle_input(_key(KEY_ESCAPE), null, null, Vector2(1280.0, 720.0), callbacks), "swap cancel key should be consumed")
	_expect(_swap_cancel_calls == 1, "swap cancel key should cancel the pending swap")
	_expect(helper.handle_input(_key(KEY_ENTER), null, null, Vector2(1280.0, 720.0), callbacks), "swap confirm key should be consumed")
	_expect(_swap_confirm_calls == 1, "swap confirm key should confirm the pending swap")

	_expect(helper.handle_input(_mouse_motion(Vector2(2.0, 10.0)), null, null, Vector2(1280.0, 720.0), callbacks), "swap mouse motion should be consumed")
	_expect(_swap_selected_index == 2, "swap mouse motion should route hover selection")
	_expect(helper.handle_input(_mouse_click(Vector2(3.0, 10.0)), null, null, Vector2(1280.0, 720.0), callbacks), "swap mouse click should be consumed")
	_expect(_swap_selected_index == 3 and _swap_confirm_calls == 2, "swap mouse click should select and confirm")

	_expect(helper.handle_input(_axis(JOY_AXIS_LEFT_X, -0.86), null, null, Vector2(1280.0, 720.0), callbacks), "swap gamepad navigation should be consumed")
	_expect(_swap_move_delta == -1, "swap gamepad navigation should route horizontal movement")
	_expect(helper.handle_input(_joy_button(JOY_BUTTON_A), null, null, Vector2(1280.0, 720.0), callbacks), "swap gamepad confirm should be consumed")
	_expect(_swap_confirm_calls == 3, "swap gamepad confirm should confirm the pending swap")
	_expect(helper.handle_input(_joy_button(JOY_BUTTON_B), null, null, Vector2(1280.0, 720.0), callbacks), "swap gamepad cancel should be consumed")
	_expect(_swap_cancel_calls == 2, "swap gamepad cancel should cancel the pending swap")


func _verify_runtime_state_facade_routes_modal_input() -> void:
	var helper := RuntimePerkModalInput.new()
	var state := FakeRuntimeState.new()
	state.active = false
	_expect(
		not helper.handle_input_from_runtime_state(state, _key(KEY_RIGHT), null, null, Vector2(1280.0, 720.0)),
		"runtime-state facade should not consume input when modal is inactive"
	)

	state.active = true
	_expect(
		helper.handle_input_from_runtime_state(state, _key(KEY_RIGHT), null, null, Vector2(1280.0, 720.0)),
		"runtime-state facade should consume active choice input"
	)
	_expect(state.choice_move_calls == 1 and state.choice_move_delta == 1, "runtime-state facade should route choice movement")

	_expect(
		helper.handle_input_from_runtime_state(state, _mouse_click(Vector2(3.0, 10.0)), null, null, Vector2(1280.0, 720.0)),
		"runtime-state facade should consume choice mouse click"
	)
	_expect(state.choice_selected_index == 3 and state.choice_choose_calls == 1, "runtime-state facade should select and choose clicked choices")

	state.pending_swap = true
	_expect(
		helper.handle_input_from_runtime_state(state, _key(KEY_ESCAPE), FakeOwner.new(), FakeRegistry.new(), Vector2(1280.0, 720.0)),
		"runtime-state facade should consume swap cancel key"
	)
	_expect(state.swap_cancel_calls == 1, "runtime-state facade should route swap cancellation")


func _verify_state_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_modal_input.gd")
	var handle_body := _function_body(state_source, "func handle_input(")
	var facade_body := _function_body(helper_source, "func handle_input_from_runtime_state(")
	_expect(state_source.find("RuntimePerkModalInput") >= 0, "state should preload the modal-input router")
	_expect(handle_body.find("_modal_input.handle_input_from_runtime_state") >= 0, "state handle_input should delegate runtime-state assembly to the modal-input router")
	_expect(handle_body.find("build_state_callbacks(self)") < 0, "state handle_input should not build callback map inline")
	_expect(helper_source.find("func handle_input_from_runtime_state(") >= 0, "modal-input router should expose runtime-state facade")
	_expect(facade_body.find("build_state_callbacks(runtime_state)") >= 0, "modal-input facade should own callback-map assembly")
	_expect(handle_body.find("InputEventKey") < 0, "state handle_input should not classify key events inline")
	_expect(handle_body.find("InputEventMouseButton") < 0, "state handle_input should not classify mouse button events inline")
	_expect(handle_body.find("InputEventMouseMotion") < 0, "state handle_input should not classify mouse motion inline")
	_expect(handle_body.find("GamepadInput.is_gamepad_event") < 0, "state handle_input should not classify gamepad events inline")
	_expect(state_source.find("func _handle_unlock_swap_input(") < 0, "state should not keep the unlock-swap input router")
	_expect(state_source.find("func _select_choice_index(") >= 0, "state should keep a narrow choice index-selection wrapper")
	_expect(state_source.find("func _select_unlock_swap_index(") >= 0, "state should keep a narrow unlock-swap index-selection wrapper")
	_expect(helper_source.find("GamepadInput.is_gamepad_event") >= 0, "modal-input router should own gamepad event classification")
	_expect(helper_source.find("InputEventKey") >= 0, "modal-input router should own key event classification")
	_expect(helper_source.find("InputEventMouseButton") >= 0, "modal-input router should own mouse button event classification")
	_expect(helper_source.find("InputEventMouseMotion") >= 0, "modal-input router should own mouse motion event classification")


func _callbacks() -> Dictionary:
	return {
		RuntimePerkModalInput.CALLBACK_IS_CHOICE_ACTIVE: Callable(self, "_is_choice_active"),
		RuntimePerkModalInput.CALLBACK_IS_CHOICE_FLIGHT_ACTIVE: Callable(self, "_is_choice_flight_active"),
		RuntimePerkModalInput.CALLBACK_IS_UNLOCK_SHOWCASE_ACTIVE: Callable(self, "_is_unlock_showcase_active"),
		RuntimePerkModalInput.CALLBACK_HAS_PENDING_UNLOCK_SWAP: Callable(self, "_has_pending_unlock_swap"),
		RuntimePerkModalInput.CALLBACK_HANDLE_UNLOCK_SHOWCASE_INPUT: Callable(self, "_handle_unlock_showcase_input"),
		RuntimePerkModalInput.CALLBACK_CONSUME_CHOICE_GAMEPAD_NAVIGATION: Callable(self, "_consume_choice_gamepad_navigation"),
		RuntimePerkModalInput.CALLBACK_CONSUME_UNLOCK_SWAP_GAMEPAD_NAVIGATION: Callable(self, "_consume_unlock_swap_gamepad_navigation"),
		RuntimePerkModalInput.CALLBACK_MOVE_CHOICE_SELECTION: Callable(self, "_move_choice_selection"),
		RuntimePerkModalInput.CALLBACK_MOVE_UNLOCK_SWAP_SELECTION: Callable(self, "_move_unlock_swap_selection"),
		RuntimePerkModalInput.CALLBACK_CHOOSE_SELECTED: Callable(self, "_choose_selected"),
		RuntimePerkModalInput.CALLBACK_CONFIRM_UNLOCK_SWAP: Callable(self, "_confirm_unlock_swap"),
		RuntimePerkModalInput.CALLBACK_CANCEL_UNLOCK_SWAP: Callable(self, "_cancel_unlock_swap"),
		RuntimePerkModalInput.CALLBACK_GET_CARD_INDEX_AT: Callable(self, "_get_card_index_at"),
		RuntimePerkModalInput.CALLBACK_GET_UNLOCK_SWAP_INDEX_AT: Callable(self, "_get_unlock_swap_index_at"),
		RuntimePerkModalInput.CALLBACK_SELECT_CHOICE_INDEX: Callable(self, "_select_choice_index"),
		RuntimePerkModalInput.CALLBACK_SELECT_UNLOCK_SWAP_INDEX: Callable(self, "_select_unlock_swap_index"),
	}


func _reset_calls() -> void:
	_choice_move_calls = 0
	_choice_move_delta = 0
	_choice_choose_calls = 0
	_choice_selected_index = -1
	_swap_move_calls = 0
	_swap_move_delta = 0
	_swap_confirm_calls = 0
	_swap_cancel_calls = 0
	_swap_selected_index = -1
	_showcase_calls = 0
	_flight_active = false
	_showcase_active = false
	_pending_swap = false


func _is_choice_active() -> bool:
	return _active


func _is_choice_flight_active() -> bool:
	return _flight_active


func _is_unlock_showcase_active() -> bool:
	return _showcase_active


func _has_pending_unlock_swap() -> bool:
	return _pending_swap


func _handle_unlock_showcase_input(_event: InputEvent, _owner: Object, _registry: Object) -> bool:
	_showcase_calls += 1
	return true


func _consume_choice_gamepad_navigation(_event: InputEvent, direction: int) -> int:
	return direction


func _consume_unlock_swap_gamepad_navigation(_event: InputEvent, direction: int) -> int:
	return direction


func _move_choice_selection(delta: int) -> void:
	_choice_move_calls += 1
	_choice_move_delta = delta


func _move_unlock_swap_selection(delta: int) -> void:
	_swap_move_calls += 1
	_swap_move_delta = delta


func _choose_selected(_owner: Object, _registry: Object, _view_size: Vector2 = Vector2.ZERO) -> void:
	_choice_choose_calls += 1


func _confirm_unlock_swap(_owner: Object, _registry: Object) -> bool:
	_swap_confirm_calls += 1
	return true


func _cancel_unlock_swap(_owner: Object = null) -> bool:
	_swap_cancel_calls += 1
	return true


func _get_card_index_at(position: Vector2, _view_size: Vector2) -> int:
	return int(position.x)


func _get_unlock_swap_index_at(position: Vector2, _view_size: Vector2) -> int:
	return int(position.x)


func _select_choice_index(index: int) -> void:
	_choice_selected_index = index


func _select_unlock_swap_index(index: int) -> void:
	_swap_selected_index = index


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event


func _mouse_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeRuntimeState:
	extends RefCounted

	var active := true
	var flight_active := false
	var showcase_active := false
	var pending_swap := false
	var choice_move_calls := 0
	var choice_move_delta := 0
	var choice_choose_calls := 0
	var choice_selected_index := -1
	var swap_cancel_calls := 0

	func is_choice_active() -> bool:
		return active

	func is_choice_flight_active() -> bool:
		return flight_active

	func is_unlock_showcase_active() -> bool:
		return showcase_active

	func has_pending_unlock_swap() -> bool:
		return pending_swap

	func _handle_unlock_showcase_input(_event: InputEvent, _owner: Object, _registry: Object) -> bool:
		return true

	func _consume_gamepad_choice_navigation(_event: InputEvent, direction: int) -> int:
		return direction

	func _consume_gamepad_unlock_swap_navigation(_event: InputEvent, direction: int) -> int:
		return direction

	func move_selection(delta: int) -> void:
		choice_move_calls += 1
		choice_move_delta = delta

	func move_unlock_swap_selection(_delta: int) -> void:
		pass

	func choose_selected(_owner: Object, _registry: Object, _view_size: Vector2 = Vector2.ZERO) -> void:
		choice_choose_calls += 1

	func confirm_pending_unlock_swap(_owner: Object, _registry: Object) -> bool:
		return true

	func cancel_pending_unlock_swap(_owner: Object = null) -> bool:
		swap_cancel_calls += 1
		return true

	func _get_card_index_at(position: Vector2, _view_size: Vector2) -> int:
		return int(position.x)

	func _get_unlock_swap_index_at(position: Vector2, _view_size: Vector2) -> int:
		return int(position.x)

	func _select_choice_index(index: int) -> void:
		choice_selected_index = index

	func _select_unlock_swap_index(_index: int) -> void:
		pass


class FakeOwner:
	extends RefCounted


class FakeRegistry:
	extends RefCounted
