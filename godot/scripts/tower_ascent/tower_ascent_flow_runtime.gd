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
	if _run_state.get_revealed_floor() <= 1:
		# 피드백2 9항 보강(코덱스 리뷰): 최초 1층 진입도 '층 진입'이다.
		# 걷힘이 없는 런 시작은 표시 전용 인트로 창으로 타이틀을 띄운다.
		_run_intro_title_start_sec = _map_ambient_drift_sec
	_current_node_id = _route_source_node_id
	if _is_audition_terminal_node(_get_node(_current_node_id)):
		var terminal_callback := finish_callback
		var callback_variant: Variant = context.get("run_finish_callback", Callable())
		if callback_variant is Callable and (callback_variant as Callable).is_valid():
			terminal_callback = callback_variant as Callable
		var clear_result := begin_floor_nine_resolution(
			"",
			terminal_callback,
			owner,
			_active_registry
		)
		if bool(clear_result.get("accepted", false)):
			return true
		_modal_lifecycle.leave()
		_reset_runtime_state()
		push_warning("[TowerAscent] begin rejected: audition_clear_resolution_failed")
		return false
	if not _enter_route_aim():
		_reset_runtime_state()
		push_warning("[TowerAscent] begin rejected: route_aim_failed")
		return false
	_request_redraw(owner)
	return true


func _is_audition_terminal_node(node: Dictionary) -> bool:
	return (
		bool(node.get("gatekeeper", false))
		and TowerAuditionBuildConfig.is_terminal_floor(int(node.get("floor", 0)))
	)


func open_map_overlay(
	owner: Object,
	registry: Object,
	context: Dictionary = {}
) -> bool:
	if (
		not TowerAscentFeatureFlags.is_vertical_slice_enabled()
		or _map_overlay_active
		or _floor_reveal_state.is_pending()
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
	_map_drag_state.reset_surface()
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
	_map_drag_state.reset_surface()
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
		and not _floor_reveal_state.is_pending()
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
		else:
			_handle_fullscreen_map_pointer_input(event, true)
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
	if _phase == PHASE_MAP_TRANSITION:
		_handle_fullscreen_map_pointer_input(event, false)
		return true
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


func _handle_fullscreen_map_pointer_input(
	event: InputEvent,
	allow_node_selection: bool
) -> bool:
	if event is InputEventMouseMotion:
		if _map_drag_state.is_press_active():
			_map_drag_state.update_pointer((event as InputEventMouseMotion).position)
		return true
	if not (event is InputEventMouseButton):
		return false
	var mouse_event := event as InputEventMouseButton
	if (
		_floor_reveal_state.has_visible_animation_started()
		and mouse_event.button_index == MOUSE_BUTTON_LEFT
		and mouse_event.pressed
	):
		# The reveal repeats every newly reached floor, so a single click skips its
		# remaining presentation. It is consumed here and cannot also begin a drag.
		_floor_reveal_state.skip()
		_complete_pending_floor_reveal()
		return true
	if (
		mouse_event.pressed
		and mouse_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	):
		return _apply_fullscreen_map_wheel_zoom(mouse_event)
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if mouse_event.pressed:
		_map_drag_state.begin_press(
			mouse_event.position,
			_renderer.get_last_fullscreen_camera_offset()
		)
		return true
	var release_kind := int(_map_drag_state.release(mouse_event.position))
	if (
		allow_node_selection
		and release_kind == TowerAscentMapDragState.RELEASE_CLICK
	):
		# Pointer selection is presentation-only focus. Route commitment remains
		# owned by the selector-ball collision path, so an M-key inspection click
		# cannot advance authoritative run state.
		_map_drag_state.select_node(
			_renderer.resolve_fullscreen_node_id_at_screen_position(
				mouse_event.position
			)
		)
	return release_kind != TowerAscentMapDragState.RELEASE_NONE


func _apply_fullscreen_map_wheel_zoom(mouse_event: InputEventMouseButton) -> bool:
	var camera_model: Dictionary = _renderer.get_last_fullscreen_camera_model()
	if camera_model.is_empty():
		return true
	var current_zoom := float(camera_model.get(
		"render_zoom_multiplier",
		camera_model.get("zoom_multiplier", 1.0)
	))
	var wheel_notches := maxf(0.01, absf(mouse_event.factor))
	var zoom_step := pow(
		TowerAscentTuning.TEMP_MAP_WHEEL_ZOOM_STEP_MULTIPLIER,
		wheel_notches
	)
	var requested_zoom := (
		current_zoom * zoom_step
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP
		else current_zoom / zoom_step
	)
	var minimum_zoom := float(camera_model.get(
		"minimum_fit_all_zoom",
		TowerAscentMapCameraModel.minimum_fit_all_zoom(
			camera_model.get("view_rect", Rect2()),
			camera_model.get("world_rect", Rect2())
		)
	))
	var zoom_override := TowerAscentMapCameraModel.build_cursor_zoom_override(
		camera_model,
		mouse_event.position,
		requested_zoom,
		minimum_zoom,
		float(camera_model.get(
			"maximum_zoom",
			TowerAscentTuning.TEMP_MAP_WHEEL_ZOOM_MAX
		))
	)
	if not zoom_override.is_empty():
		_map_drag_state.apply_zoom_override(
			float(zoom_override.get("render_zoom_multiplier", current_zoom)),
			zoom_override.get("offset", Vector2.ZERO)
		)
		_request_redraw(
			_map_overlay_owner_value() if _map_overlay_active else _active_owner
		)
	return true


func get_map_drag_threshold_screen_px() -> float:
	return float(_map_drag_state.get_threshold_screen_px())


func is_map_camera_dragging() -> bool:
	return bool(_map_drag_state.is_dragging())


func has_map_camera_manual_override() -> bool:
	return bool(_map_drag_state.has_manual_camera_override())


func get_map_camera_manual_offset() -> Vector2:
	return _map_drag_state.get_manual_camera_offset()


func has_map_camera_manual_zoom_override() -> bool:
	return bool(_map_drag_state.has_manual_zoom_override())


func get_map_camera_manual_zoom_multiplier() -> float:
	return float(_map_drag_state.get_manual_zoom_multiplier())


func get_map_pointer_selected_node_id() -> String:
	return str(_map_drag_state.get_selected_node_id())


func update_selective(delta: float, owner: Object = null) -> void:
	# 피드백2 5항: 구름 상시 드리프트용 단조증가 앰비언트 클록. 걷힘 타이머와
	# 합류해 하나의 시간원만 소비되므로 걷힘 시작/종료에 구름이 스냅하지 않는다.
	_map_ambient_drift_sec += maxf(0.0, delta)
	if (
		_run_intro_title_start_sec >= 0.0
		and _map_ambient_drift_sec - _run_intro_title_start_sec
			> TowerAscentTuning.TEMP_MAP_FLOOR_REVEAL_SEC
	):
		_run_intro_title_start_sec = -1.0
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
		_update_map_transition_with_floor_reveal(maxf(0.0, delta))
	elif _phase == PHASE_NODE_MODAL:
		_transition_fade_state.update_node_modal_fade(maxf(0.0, delta))
		# GRT-016 / GRT-043: modal physics is blocked, so the training gauge and strike
		# advances from wall time in the existing selective-idle gate. The state
		# update is never entered before a card click or after cleanup.
		if (
			_node_modal_kind == "training"
			and (
				_node_modal_state.has_active_training_strike()
				or _node_modal_state.has_running_training_timing()
			)
		):
			_node_modal_state.update_training_presentations_wall_clock()
	_request_redraw(owner)


func _update_map_transition_with_floor_reveal(delta: float) -> void:
	if _floor_reveal_state.is_pending():
		if not _floor_reveal_state.has_visible_animation_started():
			var transition_finished := bool(
				_transition_fade_state.update_map_transition(delta)
			)
			_map_transition_progress = _transition_fade_state.get_map_transition_progress()
			if transition_finished:
				# Defensive only: the map becomes visible near the start of the timeline,
				# so a pending reveal must normally take ownership before completion.
				_floor_reveal_state.cancel()
				_complete_map_transition()
				return
			if bool(get_map_transition_visual_model().get("map_visible", false)):
				_floor_reveal_state.begin_visible_animation()
			return
		if _floor_reveal_state.update(delta):
			_complete_pending_floor_reveal()
		return
	var transition_finished := bool(
		_transition_fade_state.update_map_transition(delta)
	)
	_map_transition_progress = _transition_fade_state.get_map_transition_progress()
	if transition_finished:
		_complete_map_transition()


func _complete_pending_floor_reveal() -> void:
	var revealed_floor: int = int(_floor_reveal_state.finish())
	if revealed_floor <= 0:
		return
	_run_state.reveal_floor(revealed_floor)


func get_floor_reveal_visual_model() -> Dictionary:
	var model: Dictionary = _floor_reveal_state.get_visual_model(
		_run_state.get_revealed_floor()
	)
	# The reveal-owned clock ran 0 -> 2s and reset, so clouds froze at idle and
	# snapped around each reveal. The ambient clock is monotone across both.
	model["drift_time_sec"] = _map_ambient_drift_sec
	return model


func get_run_intro_title_visual_model() -> Dictionary:
	# 표시 전용 — 걷힘 모델과 분리해 구름·씰의 reveal 의미론을 건드리지
	# 않는다. 렌더러는 걷힘 비활성일 때만 이 모델로 타이틀을 그린다.
	if _run_intro_title_start_sec < 0.0:
		return {}
	var duration := maxf(0.001, TowerAscentTuning.TEMP_MAP_FLOOR_REVEAL_SEC)
	var intro_elapsed := _map_ambient_drift_sec - _run_intro_title_start_sec
	if intro_elapsed < 0.0 or intro_elapsed > duration:
		return {}
	return {
		"active": true,
		"target_floor": maxi(1, _run_state.get_revealed_floor()),
		"progress": clampf(intro_elapsed / duration, 0.0, 1.0),
	}


func is_floor_reveal_pending() -> bool:
	return bool(_floor_reveal_state.is_pending())


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


func draw_retained_noncombat_node_background(
	canvas: CanvasItem,
	fallback_rect: Rect2 = Rect2()
) -> void:
	if _renderer != null and _renderer.has_method("draw_retained_noncombat_node_background"):
		_renderer.draw_retained_noncombat_node_background(canvas, self, fallback_rect)


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
