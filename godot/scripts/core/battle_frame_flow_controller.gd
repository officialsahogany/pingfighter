extends RefCounted


func update(delta: float, deps: Dictionary, callbacks: Dictionary) -> void:
	var scoreboard_state = deps.get("scoreboard_state", null)
	if scoreboard_state != null and scoreboard_state.is_active():
		_call_delta(callbacks, "update_effects", delta)
		return

	var power_state = deps.get("power_state", null)
	if power_state != null and power_state.is_freeze_active():
		_call_delta(callbacks, "update_ball", delta)
		_call_delta(callbacks, "update_effects", delta)
		_call(callbacks, "queue_redraw")
		return

	_call_delta(callbacks, "update_player_control", delta)
	_call_delta(callbacks, "update_active_items", delta)
	_call_delta(callbacks, "update_boss_ai", delta)

	var round_state = deps.get("round_state", null)
	if round_state != null and round_state.is_waiting_for_serve():
		var serve_flow_controller = deps.get("serve_flow_controller", null)
		if serve_flow_controller != null:
			serve_flow_controller.update(
				delta,
				_get_dictionary(deps, "serve_context"),
				{"round_state": round_state},
				callbacks
			)
		elif round_state.update_waiting(delta):
			_call(callbacks, "serve_ball")
	else:
		_call_delta(callbacks, "update_ball", delta)

	_call_delta(callbacks, "update_effects", delta)
	_call(callbacks, "queue_redraw")


func _call(callbacks: Dictionary, key: String) -> void:
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call()


func _call_delta(callbacks: Dictionary, key: String, delta: float) -> void:
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call(delta)


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}
