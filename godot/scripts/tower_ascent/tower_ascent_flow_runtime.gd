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
	_current_node_id = _route_source_node_id
	if not _enter_route_aim():
		_reset_runtime_state()
		return false
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
	return true


func update_selective(delta: float, owner: Object = null) -> void:
	if not _active:
		return
	if _phase == PHASE_ROUTE_AIM:
		_update_route_serve(maxf(0.0, delta))
	elif _phase == PHASE_MAP_TRANSITION:
		_map_transition_progress = minf(1.0, _map_transition_progress + maxf(0.0, delta) / MAP_TRANSITION_SECONDS)
		if _map_transition_progress >= 1.0:
			_complete_map_transition()
	_request_redraw(owner)


func draw(canvas: CanvasItem) -> void:
	if _renderer != null and _renderer.has_method("draw"):
		_renderer.draw(canvas, self)








































func get_header_subtitle() -> String:
	return _header_subtitle
