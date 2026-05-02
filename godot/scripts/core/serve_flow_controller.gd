extends RefCounted

const BOSS_AUTO_SERVE_DELAY := 1.0
const PLAYER_AUTO_SERVE_DELAY := 3.0
const TUTORIAL_STAGE := 50

var serve_button_was_pressed := false
var mouse_button_was_pressed := false


func update(delta: float, context: Dictionary, deps: Dictionary, callbacks: Dictionary) -> void:
	var round_state = deps.get("round_state", null)
	if round_state == null or not round_state.is_waiting_for_serve():
		_update_serve_button_edge()
		return

	if round_state.does_player_serve():
		_update_player_serve(delta, context, round_state, callbacks)
	else:
		_update_boss_serve(delta, round_state, callbacks)


func _update_player_serve(
	delta: float,
	context: Dictionary,
	round_state: Object,
	callbacks: Dictionary
) -> void:
	var manual_serve_pressed: bool = _update_serve_button_edge()
	var current_stage: int = int(context.get("current_stage", 1))
	var auto_ready := false
	if current_stage != TUTORIAL_STAGE:
		auto_ready = round_state.update_waiting(delta, PLAYER_AUTO_SERVE_DELAY)
	if manual_serve_pressed or auto_ready:
		_call(callbacks, "serve_ball")


func _update_boss_serve(delta: float, round_state: Object, callbacks: Dictionary) -> void:
	_update_serve_button_edge()
	if round_state.update_waiting(delta, BOSS_AUTO_SERVE_DELAY):
		_call(callbacks, "serve_ball")


func _update_serve_button_edge() -> bool:
	var serve_button_pressed: bool = (
		Input.is_action_pressed("ui_accept")
		or Input.is_key_pressed(KEY_SPACE)
	)
	var mouse_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var just_pressed: bool = (
		(serve_button_pressed and not serve_button_was_pressed)
		or (mouse_pressed and not mouse_button_was_pressed)
	)
	serve_button_was_pressed = serve_button_pressed
	mouse_button_was_pressed = mouse_pressed
	return just_pressed


func _call(callbacks: Dictionary, key: String) -> void:
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call()
