extends "res://scripts/tower_ascent/tower_ascent_flow_snapshot_progress.gd"


func begin_vertical_slice(
	owner: Object,
	finish_callback: Callable,
	context: Dictionary = {}
) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		push_warning("[TowerAscent] begin rejected: feature_disabled")
		return false
	if _active:
		push_warning("[TowerAscent] begin rejected: flow_active")
		return false
	if not _prepared and not prepare_vertical_slice_combat(owner, context):
		push_warning("[TowerAscent] begin rejected: prepare_vertical_slice_combat_failed")
		return false
	var lifecycle_result: Dictionary = _modal_lifecycle.enter(
		owner,
		context.get("registry", null)
	)
	if not bool(lifecycle_result.get("accepted", false)):
		push_warning("[TowerAscent] begin rejected: modal_%s" % str(lifecycle_result.get("reason", "enter_failed")))
		return false
	_finish_callback = finish_callback
	if not _complete_prepared_combat_resolution():
		_modal_lifecycle.leave()
		push_warning("[TowerAscent] begin rejected: prepared_combat_resolution_failed")
		return false
	_prepared = false
	_prepared_resolution_id = ""
	_active_owner = owner
	_active_registry = context.get("registry", null)
	_guardian_spring_node.sync_owner_projection(owner)
	_active = true
	_current_node_id = _route_source_node_id
	if not _enter_route_aim():
		_reset_runtime_state()
		push_warning("[TowerAscent] begin rejected: route_aim_failed")
		return false
	_request_redraw(owner)
	return true


func open_map_overlay(
	owner: Object,
	registry: Object,
	context: Dictionary = {}
) -> bool:
	if (
		not TowerAscentFeatureFlags.is_vertical_slice_enabled()
		or _map_overlay_active
	):
		return false
	if _map_overlay_closing:
		_finish_map_overlay_close()
	if _active and _phase not in [PHASE_ROUTE_AIM, PHASE_MAP_TRANSITION]:
		return false
	if _graph_nodes.is_empty():
		var prepare_context := context.duplicate(true)
		prepare_context["registry"] = registry
		if not prepare_vertical_slice_combat(owner, prepare_context):
			return false
	var lifecycle_result: Dictionary = _modal_lifecycle.enter(owner, registry)
	if not bool(lifecycle_result.get("accepted", false)):
		return false
	_map_overlay_active = true
	_map_overlay_closing = false
	_map_overlay_lifecycle_owned = bool(lifecycle_result.get("changed", false))
	_map_overlay_owner = weakref(owner) if owner != null else null
	_map_overlay_registry = weakref(registry) if registry != null else null
	_transition_fade_state.begin_map_overlay_open()
	_request_redraw(owner)
	return true


func close_map_overlay() -> bool:
	if not _map_overlay_active:
		return false
	_map_overlay_active = false
	_map_overlay_closing = true
	_transition_fade_state.begin_map_overlay_close()
	if _map_overlay_lifecycle_owned:
		_modal_lifecycle.leave()
	_map_overlay_lifecycle_owned = false
	_request_redraw(_map_overlay_owner_value())
	return true


func _finish_map_overlay_close() -> void:
	if not _map_overlay_closing:
		return
	var owner := _map_overlay_owner_value()
	_map_overlay_closing = false
	_map_overlay_owner = null
	_map_overlay_registry = null
	_request_redraw(owner)


func is_map_overlay_active() -> bool:
	return _map_overlay_active


func can_open_map_overlay() -> bool:
	return (
		TowerAscentFeatureFlags.is_vertical_slice_enabled()
		and not _map_overlay_active
		and (not _active or _phase in [PHASE_ROUTE_AIM, PHASE_MAP_TRANSITION])
	)


func _is_map_toggle_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	return (
		key_event.pressed
		and not key_event.echo
		and (key_event.keycode == KEY_M or key_event.physical_keycode == KEY_M)
	)


func _is_map_close_event(event: InputEvent) -> bool:
	if _is_map_toggle_event(event):
		return true
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	return (
		key_event.pressed
		and not key_event.echo
		and (key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE)
	)














func is_active() -> bool:
	return _active or _map_overlay_active or _map_overlay_closing


func blocks_battle_physics() -> bool:
	return _active or _map_overlay_active or _map_overlay_closing


func get_phase() -> int:
	return _phase


func get_phase_name() -> String:
	if _map_overlay_active:
		return "MAP_OVERLAY"
	match _phase:
		PHASE_NODE_MODAL:
			return "NODE_MODAL"
		PHASE_ROUTE_AIM:
			return "ROUTE_AIM"
		PHASE_MAP_TRANSITION:
			return "MAP_TRANSITION"
		PHASE_FAKE_ENDING_TEASER:
			return "FAKE_ENDING_TEASER"
		PHASE_ENDING_CHOICE:
			return "ENDING_CHOICE"
		PHASE_RUN_SETTLEMENT:
			return "RUN_SETTLEMENT"
		PHASE_GAUNTLET_TRANSITION:
			return "GAUNTLET_TRANSITION"
	return "COMBAT"


func handle_input(event: InputEvent) -> bool:
	if _map_overlay_active:
		if _is_map_close_event(event):
			close_map_overlay()
		return true
	if _map_overlay_closing:
		if _is_map_toggle_event(event):
			var owner := _map_overlay_owner_value()
			var registry := _map_overlay_registry_value()
			_finish_map_overlay_close()
			return open_map_overlay(owner, registry)
		return true
	if not _active:
		return false
	if _is_map_toggle_event(event) and can_open_map_overlay():
		return open_map_overlay(_active_owner, _active_registry)
	if _phase == PHASE_FAKE_ENDING_TEASER:
		if _is_confirm_event(event):
			_dismiss_fake_ending_teaser()
		return true
	if _phase == PHASE_ENDING_CHOICE:
		_handle_ending_choice_input(event)
		return true
	if _phase == PHASE_RUN_SETTLEMENT:
		if _is_confirm_event(event):
			_confirm_run_settlement()
		return true
	if _phase == PHASE_GAUNTLET_TRANSITION:
		if _is_confirm_event(event):
			_confirm_gauntlet_transition()
		return true
	if _phase == PHASE_NODE_MODAL:
		_handle_node_modal_input(event)
		return true
	if _phase != PHASE_ROUTE_AIM:
		return true
	return true


func update_selective(delta: float, owner: Object = null) -> void:
	if _map_overlay_active or _map_overlay_closing:
		var overlay_finished: bool = bool(
			_transition_fade_state.update_map_overlay(maxf(0.0, delta))
		)
		if overlay_finished and _map_overlay_closing:
			_finish_map_overlay_close()
		_request_redraw(owner)
		return
	if not _active:
		return
	if _phase == PHASE_ROUTE_AIM:
		_update_route_serve(maxf(0.0, delta))
	elif _phase == PHASE_MAP_TRANSITION:
		var transition_finished: bool = bool(
			_transition_fade_state.update_map_transition(maxf(0.0, delta))
		)
		_map_transition_progress = _transition_fade_state.get_map_transition_progress()
		if transition_finished:
			_complete_map_transition()
	elif _phase == PHASE_NODE_MODAL:
		_transition_fade_state.update_node_modal_fade(maxf(0.0, delta))
	_request_redraw(owner)


func draw(canvas: CanvasItem) -> void:
	if _renderer != null and _renderer.has_method("draw"):
		_renderer.draw(canvas, self)


func draw_fullscreen_map(
	canvas: CanvasItem,
	fallback_rect: Rect2 = Rect2(),
	walker_model: Dictionary = {}
) -> void:
	if _renderer != null and _renderer.has_method("draw_fullscreen_map"):
		_renderer.draw_fullscreen_map(canvas, self, fallback_rect, walker_model)


func draw_fullscreen_surface(
	canvas: CanvasItem,
	fallback_rect: Rect2 = Rect2(),
	walker_model: Dictionary = {}
) -> void:
	if _renderer != null and _renderer.has_method("draw_fullscreen_surface"):
		_renderer.draw_fullscreen_surface(canvas, self, fallback_rect, walker_model)


func draw_fullscreen_fade(canvas: CanvasItem, fallback_rect: Rect2 = Rect2()) -> void:
	if canvas == null:
		return
	var rect := fallback_rect
	if canvas.is_inside_tree():
		rect = canvas.get_viewport_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var alpha := get_fullscreen_fade_alpha()
	if alpha > 0.0:
		canvas.draw_rect(rect, Color(0.0, 0.0, 0.0, alpha), true)


func should_draw_fullscreen_map() -> bool:
	if get_phase_name() != "MAP_TRANSITION":
		return true
	return bool(_transition_fade_state.get_map_transition_visual_model().get("map_visible", false))


func get_map_transition_visual_model() -> Dictionary:
	return _transition_fade_state.get_map_transition_visual_model()


func get_fullscreen_fade_alpha() -> float:
	if _map_overlay_closing:
		return 1.0 - _transition_fade_state.get_map_overlay_fade_progress()
	var phase_name := get_phase_name()
	if phase_name == "MAP_TRANSITION":
		return float(get_map_transition_visual_model().get("blackout_alpha", 0.0))
	if phase_name == "NODE_MODAL":
		return 1.0 - _transition_fade_state.get_node_modal_fade_progress()
	if phase_name == "MAP_OVERLAY":
		return 1.0 - _transition_fade_state.get_map_overlay_fade_progress()
	return 0.0


func is_map_overlay_closing() -> bool:
	return _map_overlay_closing


func _map_overlay_owner_value() -> Object:
	if _map_overlay_owner is WeakRef:
		return (_map_overlay_owner as WeakRef).get_ref()
	return null


func _map_overlay_registry_value() -> Object:
	if _map_overlay_registry is WeakRef:
		return (_map_overlay_registry as WeakRef).get_ref()
	return null


func set_transition_progress_for_qa(progress: float) -> void:
	_transition_fade_state.set_map_transition_progress_for_qa(progress)
	_map_transition_progress = _transition_fade_state.get_map_transition_progress()


func set_node_modal_fade_progress_for_qa(progress: float) -> void:
	_transition_fade_state.set_node_modal_fade_progress_for_qa(progress)


func set_map_overlay_fade_progress_for_qa(progress: float) -> void:
	_transition_fade_state.set_map_overlay_fade_progress_for_qa(progress)








































func get_header_subtitle() -> String:
	return _header_subtitle
