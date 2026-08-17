extends "res://scripts/tower_ascent/tower_ascent_flow_snapshot_progress.gd"


func begin_vertical_slice(
	owner: Object,
	finish_callback: Callable,
	context: Dictionary = {}
) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled() or _active:
		return false
	if not _prepared and not prepare_vertical_slice_combat(owner, context):
		return false
	var lifecycle_result: Dictionary = _modal_lifecycle.enter(
		owner,
		context.get("registry", null)
	)
	if not bool(lifecycle_result.get("accepted", false)):
		return false
	_finish_callback = finish_callback
	if not _complete_prepared_combat_resolution():
		_modal_lifecycle.leave()
		return false
	_prepared = false
	_prepared_resolution_id = ""
	_active_owner = owner
	_active_registry = context.get("registry", null)
	_guardian_spring_node.sync_owner_projection(owner)
	_active = true
	_phase = PHASE_NODE_MODAL
	_current_node_id = _route_source_node_id
	_open_node_modal()
	_request_redraw(owner)
	return true














func is_active() -> bool:
	return _active


func blocks_battle_physics() -> bool:
	return _active


func get_phase() -> int:
	return _phase


func get_phase_name() -> String:
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
	if not _active:
		return false
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
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_LEFT or key_event.physical_keycode == KEY_LEFT:
				_set_aim_target(220.0)
			elif key_event.keycode == KEY_RIGHT or key_event.physical_keycode == KEY_RIGHT:
				_set_aim_target(540.0)
			elif key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_launch_selector()
	elif event is InputEventMouseMotion:
		_set_aim_target(220.0 if (event as InputEventMouseMotion).position.x < 380.0 else 540.0)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_set_aim_target(220.0 if mouse_event.position.x < 380.0 else 540.0)
			_launch_selector()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_set_aim_target(220.0 if touch_event.position.x < 380.0 else 540.0)
			_launch_selector()
	return true


func update_selective(delta: float, owner: Object = null) -> void:
	if not _active:
		return
	if _phase == PHASE_ROUTE_AIM and _selector_launched:
		_update_selector(maxf(0.0, delta))
	elif _phase == PHASE_MAP_TRANSITION:
		_map_transition_progress = minf(1.0, _map_transition_progress + maxf(0.0, delta) / MAP_TRANSITION_SECONDS)
		if _map_transition_progress >= 1.0:
			_finish_vertical_slice()
	_request_redraw(owner)


func draw(canvas: CanvasItem) -> void:
	if _renderer != null and _renderer.has_method("draw"):
		_renderer.draw(canvas, self)








































func get_header_subtitle() -> String:
	return _header_subtitle
