extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

const PLAYER_AUTO_SERVE_DELAY := 3.0
const TUTORIAL_STAGE := 50
const BOSS_SERVE_IMMEDIATE_CHANCE := 0.12

var serve_button_was_pressed := false
var mouse_button_was_pressed := false
var boss_serve_delay := 1.0
var boss_serve_delay_armed := false


func sync_current_input_state() -> void:
	serve_button_was_pressed = _is_serve_action_pressed()
	mouse_button_was_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func update(delta: float, context: Dictionary, deps: Dictionary, callbacks: Dictionary) -> void:
	var round_state = deps.get("round_state", null)
	if round_state == null or not round_state.is_waiting_for_serve():
		boss_serve_delay_armed = false
		_update_serve_button_edge()
		return

	if _update_serve_banner(delta, round_state):
		var manual_serve_pressed := _update_serve_button_edge()
		if round_state.does_player_serve() and manual_serve_pressed:
			_call(callbacks, "serve_ball")
		return
	if _update_round_restart_notice(delta, round_state):
		_update_serve_button_edge()
		return

	if round_state.does_player_serve():
		boss_serve_delay_armed = false
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
	if not boss_serve_delay_armed:
		boss_serve_delay = _pick_boss_serve_delay()
		boss_serve_delay_armed = true
	if round_state.update_waiting(delta, boss_serve_delay):
		boss_serve_delay_armed = false
		_call(callbacks, "serve_ball")


func _update_serve_banner(delta: float, round_state: Object) -> bool:
	if round_state == null or not round_state.has_method("is_serve_banner_active"):
		return false
	if not bool(round_state.is_serve_banner_active()):
		return false
	if round_state.has_method("update_serve_banner"):
		round_state.update_serve_banner(delta)
	return bool(round_state.is_serve_banner_active())


func _update_round_restart_notice(delta: float, round_state: Object) -> bool:
	if round_state == null or not round_state.has_method("is_round_restart_notice_active"):
		return false
	if not bool(round_state.is_round_restart_notice_active()):
		return false
	if round_state.has_method("update_round_restart_notice"):
		round_state.update_round_restart_notice(delta)
	return bool(round_state.is_round_restart_notice_active())


func _pick_boss_serve_delay() -> float:
	var roll: float = randf()
	if roll < BOSS_SERVE_IMMEDIATE_CHANCE:
		return 0.0
	if roll < 0.34:
		return randf_range(0.25, 0.85)
	if roll < 0.82:
		return randf_range(0.95, 2.40)
	return randf_range(2.40, 3.50)


func _update_serve_button_edge() -> bool:
	var serve_button_pressed: bool = _is_serve_action_pressed()
	var mouse_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var just_pressed: bool = (
		(serve_button_pressed and not serve_button_was_pressed)
		or (mouse_pressed and not mouse_button_was_pressed)
	)
	serve_button_was_pressed = serve_button_pressed
	mouse_button_was_pressed = mouse_pressed
	return just_pressed


func _is_serve_action_pressed() -> bool:
	return (
		Input.is_action_pressed("ui_accept")
		or Input.is_key_pressed(KEY_SPACE)
		or GamepadInput.is_primary_action_pressed()
	)


func _call(callbacks: Dictionary, key: String) -> void:
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call()
