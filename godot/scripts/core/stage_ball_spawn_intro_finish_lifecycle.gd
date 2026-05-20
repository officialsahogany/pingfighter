extends RefCounted


func finish_intro(intro: Object, owner: Object, registry: Object, target_pos: Vector2, reset_lifecycle: Object) -> void:
	if intro == null or not _is_overlay_active(intro):
		return
	var was_handed_off: bool = false
	if intro.has_method("_has_completed_serve_handoff"):
		was_handed_off = bool(intro._has_completed_serve_handoff())
	intro.active = false
	intro.overlay_active = false
	intro.elapsed_sec = 0.0
	_stop_intro_audio(registry)
	if reset_lifecycle != null and reset_lifecycle.has_method("reset_state"):
		reset_lifecycle.reset_state(intro)

	if not was_handed_off:
		intro._apply_owner_spawn_snapshot(owner, target_pos)
		var round_state: Object = _get_instance(registry, "round_flow_state")
		if round_state != null:
			if round_state.has_method("prepare_serve_after_intro"):
				round_state.prepare_serve_after_intro()
			elif round_state.has_method("reset_round_wait"):
				round_state.reset_round_wait()
		intro._sync_serve_input(registry)
	intro.serve_handoff_done = false


func _is_overlay_active(intro: Object) -> bool:
	if intro.has_method("is_overlay_active"):
		return bool(intro.is_overlay_active())
	return bool(intro.active)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _stop_intro_audio(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("stop_ball_spawn_intro"):
		audio.stop_ball_spawn_intro()
