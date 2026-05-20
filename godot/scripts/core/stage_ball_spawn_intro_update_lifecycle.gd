extends RefCounted


func update_intro(intro: Object, delta: float, owner: Object, registry: Object, config: Dictionary) -> void:
	if intro == null or not _is_overlay_active(intro):
		return
	var phase_1_duration: float = float(config.get("phase_1_duration", 2.0))
	var phase_2_duration: float = float(config.get("phase_2_duration", 0.75))
	var phase_3_duration: float = float(config.get("phase_3_duration", 1.25))
	var blocking_duration: float = float(config.get("blocking_duration", phase_1_duration + phase_2_duration + phase_3_duration))
	var total_duration: float = float(config.get("total_duration", 4.0))
	var dt: float = clamp(delta, 0.0, 0.05)
	intro.elapsed_sec += dt
	if intro.elapsed_sec >= total_duration:
		intro._finish(owner, registry)
		return
	if intro.elapsed_sec >= blocking_duration and not _has_completed_serve_handoff(intro):
		intro._complete_gameplay_handoff(owner, registry)

	if intro.elapsed_sec < phase_1_duration:
		intro._update_phase_1(dt)
	elif intro.elapsed_sec < phase_1_duration + phase_2_duration:
		intro._update_phase_2(dt)
	elif intro.elapsed_sec < blocking_duration:
		intro._update_phase_3(dt)
	elif intro.has_method("_update_outro"):
		intro._update_outro(dt)

	var ball_state: Dictionary = intro._get_ball_state()
	intro._sync_fx_host_state(ball_state)
	if intro.has_method("_sync_pillar_overlay_host"):
		intro._sync_pillar_overlay_host()
	if bool(intro.active) and bool(ball_state.get("visible", false)):
		intro._apply_owner_spawn_snapshot(owner, ball_state.get("pos", intro.start_pos))


func _is_overlay_active(intro: Object) -> bool:
	if intro.has_method("is_overlay_active"):
		return bool(intro.is_overlay_active())
	return bool(intro.active)


func _has_completed_serve_handoff(intro: Object) -> bool:
	if intro.has_method("_has_completed_serve_handoff"):
		return bool(intro._has_completed_serve_handoff())
	return false
