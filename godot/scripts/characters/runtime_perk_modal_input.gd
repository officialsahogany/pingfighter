extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

const CALLBACK_IS_CHOICE_ACTIVE := "is_choice_active"
const CALLBACK_IS_CHOICE_FLIGHT_ACTIVE := "is_choice_flight_active"
const CALLBACK_IS_UNLOCK_SHOWCASE_ACTIVE := "is_unlock_showcase_active"
const CALLBACK_HAS_PENDING_UNLOCK_SWAP := "has_pending_unlock_swap"
const CALLBACK_HANDLE_UNLOCK_SHOWCASE_INPUT := "handle_unlock_showcase_input"
const CALLBACK_CONSUME_CHOICE_GAMEPAD_NAVIGATION := "consume_choice_gamepad_navigation"
const CALLBACK_CONSUME_UNLOCK_SWAP_GAMEPAD_NAVIGATION := "consume_unlock_swap_gamepad_navigation"
const CALLBACK_MOVE_CHOICE_SELECTION := "move_choice_selection"
const CALLBACK_MOVE_UNLOCK_SWAP_SELECTION := "move_unlock_swap_selection"
const CALLBACK_CHOOSE_SELECTED := "choose_selected"
const CALLBACK_NOTE_CONFIRM_INPUT_SOURCE := "note_choice_confirm_input_source"
const CALLBACK_CONFIRM_UNLOCK_SWAP := "confirm_unlock_swap"
const CALLBACK_CANCEL_UNLOCK_SWAP := "cancel_unlock_swap"
const CALLBACK_GET_CARD_INDEX_AT := "get_card_index_at"
const CALLBACK_GET_UNLOCK_SWAP_INDEX_AT := "get_unlock_swap_index_at"
const CALLBACK_SELECT_CHOICE_INDEX := "select_choice_index"
const CALLBACK_SELECT_UNLOCK_SWAP_INDEX := "select_unlock_swap_index"


func build_state_callbacks(state: Object) -> Dictionary:
	if state == null:
		return {}
	return {
		CALLBACK_IS_CHOICE_ACTIVE: Callable(state, "is_choice_active"),
		CALLBACK_IS_CHOICE_FLIGHT_ACTIVE: Callable(state, "is_choice_flight_active"),
		CALLBACK_IS_UNLOCK_SHOWCASE_ACTIVE: Callable(state, "is_unlock_showcase_active"),
		CALLBACK_HAS_PENDING_UNLOCK_SWAP: Callable(state, "has_pending_unlock_swap"),
		CALLBACK_HANDLE_UNLOCK_SHOWCASE_INPUT: Callable(state, "_handle_unlock_showcase_input"),
		CALLBACK_CONSUME_CHOICE_GAMEPAD_NAVIGATION: Callable(state, "_consume_gamepad_choice_navigation"),
		CALLBACK_CONSUME_UNLOCK_SWAP_GAMEPAD_NAVIGATION: Callable(state, "_consume_gamepad_unlock_swap_navigation"),
		CALLBACK_MOVE_CHOICE_SELECTION: Callable(state, "move_selection"),
		CALLBACK_MOVE_UNLOCK_SWAP_SELECTION: Callable(state, "move_unlock_swap_selection"),
		CALLBACK_CHOOSE_SELECTED: Callable(state, "choose_selected"),
		CALLBACK_NOTE_CONFIRM_INPUT_SOURCE: Callable(state, "note_choice_confirm_input_source"),
		CALLBACK_CONFIRM_UNLOCK_SWAP: Callable(state, "confirm_pending_unlock_swap"),
		CALLBACK_CANCEL_UNLOCK_SWAP: Callable(state, "cancel_pending_unlock_swap"),
		CALLBACK_GET_CARD_INDEX_AT: Callable(state, "_get_card_index_at"),
		CALLBACK_GET_UNLOCK_SWAP_INDEX_AT: Callable(state, "_get_unlock_swap_index_at"),
		CALLBACK_SELECT_CHOICE_INDEX: Callable(state, "_select_choice_index"),
		CALLBACK_SELECT_UNLOCK_SWAP_INDEX: Callable(state, "_select_unlock_swap_index"),
	}


func handle_input_from_runtime_state(
	runtime_state: Object,
	event: InputEvent,
	owner: Object,
	registry: Object,
	view_size: Vector2
) -> bool:
	return handle_input(event, owner, registry, view_size, build_state_callbacks(runtime_state))


func handle_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	view_size: Vector2,
	callbacks: Dictionary
) -> bool:
	if not _call_bool(callbacks, CALLBACK_IS_CHOICE_ACTIVE):
		return false
	if _call_bool(callbacks, CALLBACK_IS_CHOICE_FLIGHT_ACTIVE):
		return true
	if _call_bool(callbacks, CALLBACK_IS_UNLOCK_SHOWCASE_ACTIVE):
		return _call_bool(callbacks, CALLBACK_HANDLE_UNLOCK_SHOWCASE_INPUT, [event, owner, registry], true)
	if _call_bool(callbacks, CALLBACK_HAS_PENDING_UNLOCK_SWAP):
		return handle_unlock_swap_input(event, owner, registry, view_size, callbacks)
	return handle_choice_input(event, owner, registry, view_size, callbacks)


func handle_choice_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	view_size: Vector2,
	callbacks: Dictionary
) -> bool:
	if GamepadInput.is_gamepad_event(event):
		var horizontal_direction: int = GamepadInput.get_menu_horizontal_event(event)
		var navigation_direction := _call_int(
			callbacks,
			CALLBACK_CONSUME_CHOICE_GAMEPAD_NAVIGATION,
			[event, horizontal_direction]
		)
		if navigation_direction != 0:
			_call_void(callbacks, CALLBACK_MOVE_CHOICE_SELECTION, [navigation_direction])
			return true
		if GamepadInput.is_confirm_event(event):
			# 진입 입력원 전달: 공용 choose_selected callback은 3인자 계약을
			# 유지한다(스텁·소비자 호환) — RT 여부는 별도 note 채널로 먼저
			# 알린 뒤 표준 3인자로 호출한다. 주사위 모달은 RT 진입일 때만
			# 첫 RT 캐스케이드 억제 래치를 무장한다.
			_call_void(callbacks, CALLBACK_NOTE_CONFIRM_INPUT_SOURCE, [
				event is InputEventJoypadMotion
				and (event as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT
			])
			_call_void(callbacks, CALLBACK_CHOOSE_SELECTED, [owner, registry, view_size])
			return true
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return true
		match key_event.keycode:
			KEY_LEFT:
				_call_void(callbacks, CALLBACK_MOVE_CHOICE_SELECTION, [-1])
				return true
			KEY_RIGHT:
				_call_void(callbacks, CALLBACK_MOVE_CHOICE_SELECTION, [1])
				return true
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z:
				_call_void(callbacks, CALLBACK_CHOOSE_SELECTED, [owner, registry, view_size])
				return true
		return true
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return true
		var clicked_index: int = _call_int(
			callbacks,
			CALLBACK_GET_CARD_INDEX_AT,
			[mouse_event.position, view_size],
			-1
		)
		if clicked_index >= 0:
			_call_void(callbacks, CALLBACK_SELECT_CHOICE_INDEX, [clicked_index])
			_call_void(callbacks, CALLBACK_CHOOSE_SELECTED, [owner, registry, view_size])
		return true
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		var hovered_index: int = _call_int(
			callbacks,
			CALLBACK_GET_CARD_INDEX_AT,
			[motion_event.position, view_size],
			-1
		)
		if hovered_index >= 0:
			_call_void(callbacks, CALLBACK_SELECT_CHOICE_INDEX, [hovered_index])
		return true
	return true


func handle_unlock_swap_input(
	event: InputEvent,
	owner: Object,
	registry: Object,
	view_size: Vector2,
	callbacks: Dictionary
) -> bool:
	if GamepadInput.is_gamepad_event(event):
		var horizontal_direction: int = GamepadInput.get_menu_horizontal_event(event)
		var navigation_direction := _call_int(
			callbacks,
			CALLBACK_CONSUME_UNLOCK_SWAP_GAMEPAD_NAVIGATION,
			[event, horizontal_direction]
		)
		if navigation_direction != 0:
			_call_void(callbacks, CALLBACK_MOVE_UNLOCK_SWAP_SELECTION, [navigation_direction])
			return true
		if GamepadInput.is_confirm_event(event):
			_call_void(callbacks, CALLBACK_CONFIRM_UNLOCK_SWAP, [owner, registry])
			return true
		if GamepadInput.is_cancel_event(event):
			_call_void(callbacks, CALLBACK_CANCEL_UNLOCK_SWAP, [owner])
			return true
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return true
		match key_event.keycode:
			KEY_LEFT:
				_call_void(callbacks, CALLBACK_MOVE_UNLOCK_SWAP_SELECTION, [-1])
				return true
			KEY_RIGHT:
				_call_void(callbacks, CALLBACK_MOVE_UNLOCK_SWAP_SELECTION, [1])
				return true
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z:
				_call_void(callbacks, CALLBACK_CONFIRM_UNLOCK_SWAP, [owner, registry])
				return true
			KEY_ESCAPE, KEY_X:
				_call_void(callbacks, CALLBACK_CANCEL_UNLOCK_SWAP, [owner])
				return true
		return true
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return true
		var clicked_index: int = _call_int(
			callbacks,
			CALLBACK_GET_UNLOCK_SWAP_INDEX_AT,
			[mouse_event.position, view_size],
			-1
		)
		if clicked_index >= 0:
			_call_void(callbacks, CALLBACK_SELECT_UNLOCK_SWAP_INDEX, [clicked_index])
			_call_void(callbacks, CALLBACK_CONFIRM_UNLOCK_SWAP, [owner, registry])
		return true
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		var hovered_index: int = _call_int(
			callbacks,
			CALLBACK_GET_UNLOCK_SWAP_INDEX_AT,
			[motion_event.position, view_size],
			-1
		)
		if hovered_index >= 0:
			_call_void(callbacks, CALLBACK_SELECT_UNLOCK_SWAP_INDEX, [hovered_index])
		return true
	return true


func _call_bool(callbacks: Dictionary, key: String, args: Array = [], fallback: bool = false) -> bool:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return fallback
	return bool(callback.callv(args))


func _call_int(callbacks: Dictionary, key: String, args: Array = [], fallback: int = 0) -> int:
	var callback := _get_callback(callbacks, key)
	if not callback.is_valid():
		return fallback
	return int(callback.callv(args))


func _call_void(callbacks: Dictionary, key: String, args: Array = []) -> void:
	var callback := _get_callback(callbacks, key)
	if callback.is_valid():
		callback.callv(args)


func _get_callback(callbacks: Dictionary, key: String) -> Callable:
	var value: Variant = callbacks.get(key, Callable())
	if value is Callable:
		return value
	return Callable()
