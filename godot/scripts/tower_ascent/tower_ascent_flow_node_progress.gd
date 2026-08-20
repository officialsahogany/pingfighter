extends "res://scripts/tower_ascent/tower_ascent_flow_economy_progress.gd"

func has_soul_summoning() -> bool:
	return (
		TowerAscentFeatureFlags.is_vertical_slice_enabled()
		and _run_state.has_started()
		and _guardian_spring_node.has_soul_summoning()
	)

func record_guardian_identity_reveal(pet_id: String, registry: Object = null) -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled() or not _run_state.has_started():
		return {
			"accepted": true,
			"handled": false,
			"tower_sealed": false,
			"reason": "tower_run_inactive",
		}
	var result: Dictionary = _guardian_spring_node.record_identity_reveal(pet_id, registry)
	var codex_result: Dictionary = _dictionary_copy(result.get("codex_result", {}))
	if bool(codex_result.get("accepted", false)) and bool(codex_result.get("changed", false)):
		var discovery_id := str(codex_result.get("discovery_id", ""))
		var already_recorded := false
		for discovery in _codex_discoveries:
			if str(discovery.get("discovery_id", "")) == discovery_id:
				already_recorded = true
				break
		if not already_recorded:
			_codex_discoveries.append({
				"pet_id": str(codex_result.get("pet_id", pet_id)),
				"display_name": str(result.get("display_name", pet_id)),
				"discovery_id": discovery_id,
			})
	_guardian_state = _guardian_spring_node.export_state()
	_guardian_spring_node.sync_owner_projection(_active_owner)
	if _active and _phase == PHASE_NODE_MODAL and _node_modal_kind == "guardian_spring":
		_refresh_guardian_spring_modal("")
	return result

func get_node_modal_view_model(
	view_size: Vector2 = TowerAscentNodeModalState.BASE_VIEW_SIZE
) -> Dictionary:
	if _node_modal_state == null or not _node_modal_state.has_method("build_view_model"):
		return {}
	return _node_modal_state.build_view_model(view_size)

func get_node_modal_kind() -> String:
	return _node_modal_kind

func get_node_modal_render_context() -> Dictionary:
	return {
		"card_renderer": _get_cached_node_modal_render_module(
			"runtime_perk_overlay_renderer"
		),
		"icon_renderer": _get_cached_node_modal_render_module(
			"runtime_perk_icon_renderer"
		),
		"active_item_hud_visuals": _get_cached_node_modal_render_module(
			"active_item_hud_visuals"
		),
	}


func _get_cached_node_modal_render_module(key: String) -> Object:
	# This context is read from the fullscreen draw pass. Production registries
	# must therefore expose only already-warmed modules here; fixture registries
	# without a cached API retain their small compatibility path.
	if _active_registry == null:
		return null
	if _active_registry.has_method("get_cached_instance"):
		var cached_value: Variant = _active_registry.call("get_cached_instance", key)
		return cached_value as Object if cached_value is Object else null
	return _get_registry_instance(_active_registry, key)

func get_generated_fallen_monk_offers() -> Array[Dictionary]:
	return _fallen_monk_node.get_generated_offers()

func get_fallen_monk_history() -> Array[Dictionary]:
	return _fallen_monk_node.get_history()

func get_guardian_spring_history() -> Array[Dictionary]:
	return _guardian_spring_node.get_history()

func get_guardian_state() -> Dictionary:
	return _guardian_spring_node.export_state()

func get_rest_history() -> Array[Dictionary]:
	return _rest_node.get_history()

func execute_node_action(action_id: String, requested_resolution_id: String = "") -> Dictionary:
	if not _active or _phase != PHASE_NODE_MODAL:
		return {"accepted": false, "reason": "node_modal_inactive"}
	if _node_modal_kind == "shop" and action_id.begins_with("shop_purchase:"):
		return _execute_shop_purchase(
			action_id.trim_prefix("shop_purchase:"),
			requested_resolution_id
		)
	if _node_modal_kind == "training" and action_id.begins_with("training_"):
		return _execute_training_action(action_id, requested_resolution_id)
	if _node_modal_kind == "fallen_monk" and action_id.begins_with("fallen_monk:"):
		return _execute_fallen_monk_action(action_id, requested_resolution_id)
	if _node_modal_kind == "guardian_spring" and action_id.begins_with("guardian_spring:"):
		return _execute_guardian_spring_action(action_id, requested_resolution_id)
	if _node_modal_kind == "rest" and action_id.begins_with("rest:"):
		return _execute_rest_action(action_id, requested_resolution_id)
	return {"accepted": false, "reason": "unknown_node_action"}

func _open_node_modal() -> void:
	_node_modal_state.open(
		_current_node_id,
		_node_modal_kind,
		_run_state.export_economy(),
		_build_node_modal_actions()
	)
	if _node_modal_kind == "shop" and _get_shop_inventory_entry().is_empty():
		_node_modal_state.set_status_text(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SHOP_INVENTORY_UNAVAILABLE
		))
	elif _node_modal_kind == "training" and _get_training_offer_entry().is_empty():
		_node_modal_state.set_status_text(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_TRAINING_OFFER_UNAVAILABLE
		))
	elif _node_modal_kind == "fallen_monk" and _build_fallen_monk_actions().is_empty():
		_node_modal_state.set_status_text(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_MONK_OFFER_UNAVAILABLE
		))
	elif _node_modal_kind == "guardian_spring" and _build_guardian_spring_actions().is_empty():
		_node_modal_state.set_status_text(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SPRING_ACTION_UNAVAILABLE
		))

func _handle_node_modal_input(event: InputEvent) -> void:
	var view_size := _get_node_modal_view_size()
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode in [KEY_UP, KEY_W]:
			_node_modal_state.move_selection(-1)
			return
		if key_event.keycode in [KEY_DOWN, KEY_S]:
			_node_modal_state.move_selection(1)
			return
		if key_event.keycode == KEY_ESCAPE:
			_enter_route_aim()
			return
		if key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_confirm_node_modal_action()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _node_modal_state.select_at_position(mouse_event.position, view_size):
				_confirm_node_modal_action()
		return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if (
			touch_event.pressed
			and _node_modal_state.select_at_position(touch_event.position, view_size)
		):
			_confirm_node_modal_action()


func _get_node_modal_view_size() -> Vector2:
	if (
		_active_owner != null
		and _active_owner.has_method("is_inside_tree")
		and bool(_active_owner.is_inside_tree())
		and _active_owner.has_method("get_viewport_rect")
	):
		var viewport_rect_value: Variant = _active_owner.get_viewport_rect()
		if viewport_rect_value is Rect2:
			var viewport_size := (viewport_rect_value as Rect2).size
			if viewport_size.x > 0.0 and viewport_size.y > 0.0:
				return viewport_size
	return TowerAscentNodeModalState.BASE_VIEW_SIZE

func _confirm_node_modal_action() -> void:
	var action: Dictionary = _node_modal_state.get_selected_action()
	if action.is_empty():
		return
	if not bool(action.get("enabled", true)):
		_node_modal_state.set_status_text(str(action.get("unavailable_reason", "")))
		return
	if str(action.get("id", "")) == TowerAscentNodeModalState.ACTION_END_WORK:
		_enter_route_aim()
		return
	var action_result := execute_node_action(str(action.get("id", "")))
	if not bool(action_result.get("accepted", false)):
		_node_modal_state.set_status_text(str(action_result.get("message", action_result.get("reason", ""))))

func _build_node_modal_actions() -> Array[Dictionary]:
	if _node_modal_kind == "shop":
		return _build_shop_actions()
	if _node_modal_kind == "training":
		return _build_training_actions()
	if _node_modal_kind == "fallen_monk":
		return _build_fallen_monk_actions()
	if _node_modal_kind == "guardian_spring":
		return _build_guardian_spring_actions()
	if _node_modal_kind == "rest":
		return _build_rest_actions()
	return []

func _build_fallen_monk_actions() -> Array[Dictionary]:
	return _fallen_monk_node.build_actions(
		_current_node_id,
		_map_seed,
		_run_state,
		_active_owner,
		_active_registry
	)

func _execute_fallen_monk_action(
	action_id: String,
	requested_resolution_id: String = ""
) -> Dictionary:
	var resolution_id := requested_resolution_id.strip_edges()
	if resolution_id.is_empty():
		resolution_id = _make_resolution_id(_current_node_id, action_id)
	var result: Dictionary = _fallen_monk_node.execute_action(
		action_id,
		resolution_id,
		_current_node_id,
		_map_seed,
		_run_state,
		_resolution_ids,
		_node_action_transaction,
		_active_owner,
		_active_registry
	)
	if bool(result.get("accepted", false)) and bool(result.get("applied", false)):
		_build_state["chosik"] = _fallen_monk_node.get_history()
		_build_state["runtime_perk_snapshot"] = _fallen_monk_node.get_runtime_snapshot()
	_refresh_fallen_monk_modal(str(result.get("message", result.get("reason", ""))))
	return result

func _refresh_fallen_monk_modal(status_text: String) -> void:
	_node_modal_state.set_actions(_build_fallen_monk_actions())
	_node_modal_state.set_balances(_run_state.export_economy())
	_node_modal_state.set_status_text(status_text)

func _build_guardian_spring_actions() -> Array[Dictionary]:
	return _guardian_spring_node.build_actions(
		_current_node_id,
		_map_seed,
		_run_state,
		_active_owner,
		_active_registry
	)

func _execute_guardian_spring_action(
	action_id: String,
	requested_resolution_id: String = ""
) -> Dictionary:
	var resolution_id := requested_resolution_id.strip_edges()
	if resolution_id.is_empty():
		resolution_id = _make_resolution_id(_current_node_id, action_id)
	var result: Dictionary = _guardian_spring_node.execute_action(
		action_id,
		resolution_id,
		_current_node_id,
		_map_seed,
		_run_state,
		_resolution_ids,
		_node_action_transaction,
		_active_owner,
		_active_registry
	)
	_guardian_state = _guardian_spring_node.export_state()
	_guardian_spring_node.sync_owner_projection(_active_owner)
	_refresh_guardian_spring_modal(str(result.get("message", result.get("reason", ""))))
	return result

func _refresh_guardian_spring_modal(status_text: String) -> void:
	_node_modal_state.set_actions(_build_guardian_spring_actions())
	_node_modal_state.set_balances(_run_state.export_economy())
	_node_modal_state.set_status_text(status_text)

func _build_rest_actions() -> Array[Dictionary]:
	return _rest_node.build_actions(_current_node_id, _run_state)

func _execute_rest_action(
	action_id: String,
	requested_resolution_id: String = ""
) -> Dictionary:
	var resolution_id := requested_resolution_id.strip_edges()
	if resolution_id.is_empty():
		resolution_id = _make_resolution_id(_current_node_id, action_id)
	var result: Dictionary = _rest_node.execute_action(
		action_id,
		resolution_id,
		_current_node_id,
		_run_state,
		_resolution_ids,
		_node_action_transaction
	)
	_sync_owner_chance_gems(_active_owner)
	_refresh_rest_modal(str(result.get("message", result.get("reason", ""))))
	return result

func _refresh_rest_modal(status_text: String) -> void:
	_node_modal_state.set_actions(_build_rest_actions())
	_node_modal_state.set_balances(_run_state.export_economy())
	_node_modal_state.set_status_text(status_text)
