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
	# Prayer becomes unavailable on the acquisition event itself. Codex storage
	# is a separate best-effort side effect and must not keep prayer unlocked.
	if not str(result.get("pet_id", "")).strip_edges().is_empty():
		_run_state.lock_guardian_prayer()
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
	_guardian_spring_node.sync_owner_projection(_active_owner, _run_state, _active_registry)
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

func get_training_stage_presentation_debug_state() -> Dictionary:
	if _node_modal_state == null:
		return {}
	return _node_modal_state.get_training_stage_debug_state()


func get_guardian_spring_presentation_debug_state() -> Dictionary:
	if _node_modal_state == null:
		return {}
	return _node_modal_state.get_guardian_spring_presentation_debug_state()


func set_training_stage_clock_msec_for_tests(value: int) -> void:
	if _node_modal_state != null:
		_node_modal_state.set_training_stage_clock_msec_for_tests(value)


func set_node_modal_clock_msec_for_tests(value: int) -> void:
	if _node_modal_state != null:
		_node_modal_state.set_clock_msec_for_tests(value)


func get_training_stage_visual_model_for_tests() -> Dictionary:
	if _node_modal_state == null:
		return {}
	return _node_modal_state.get_training_stage_visual_model_for_tests()


func get_training_timing_debug_state() -> Dictionary:
	if _node_modal_state == null:
		return {}
	return _node_modal_state.get_training_timing_debug_state()


func get_training_timing_visual_model_for_tests() -> Dictionary:
	if _node_modal_state == null:
		return {}
	return _node_modal_state.get_training_timing_visual_model_for_tests()


func get_node_modal_render_context() -> Dictionary:
	var context := {
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
	if (
		_node_modal_kind == "training"
		and _node_modal_state != null
		and _node_modal_state.has_training_stats_hover()
	):
		# The canonical character-info tooltip host is requested only while a
		# retained stats row can actually consume it (GRT-043).
		context["training_stats_tooltip_overlay"] = (
			_get_cached_node_modal_render_module("character_info_overlay")
		)
	if (
		_node_modal_kind == "shop"
		and _node_modal_state != null
		and _node_modal_state.has_shop_item_hover()
	):
		# GRT-043: the canonical dual-tooltip host is injected only for a
		# retained occupied cell hover. An idle shop frame performs no tooltip
		# registry lookup and allocates no tooltip data.
		context["shop_item_tooltip_overlay"] = (
			_get_cached_node_modal_render_module("character_info_overlay")
		)
	if _node_modal_kind == "training" and _node_modal_state != null:
		var training_stage_presentation: Object = (
			_node_modal_state.get_training_stage_presentation()
		)
		if training_stage_presentation != null:
			# GRT-043: the retained RefCounted was configured once on modal
			# entry. This adds no registry lookup, layout build, or Node layer to
			# an unhovered frame.
			context["training_stage_presentation"] = training_stage_presentation
		var training_timing_presentation: Object = (
			_node_modal_state.get_training_timing_presentation()
		)
		if training_timing_presentation != null:
			# GRT-028/GRT-043: this RefCounted and its draw model exist only from
			# a valid card release until the owned strike presentation completes.
			context["training_timing_presentation"] = training_timing_presentation
	if (
		_node_modal_kind == "guardian_spring"
		and _node_modal_state != null
		and _node_modal_state.has_guardian_spring_presentation()
	):
		# Draw consumes only this already-warmed bundle. No ResourceLoader or
		# filesystem probe is reachable from the first visible node frame.
		context["guardian_spring_presentation_assets"] = (
			get_guardian_spring_presentation_asset_bundle()
		)
	return context


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
	# A node modal is a new opaque input owner. No reveal timer may survive into
	# it even if a future transition path opens the card early (GRT-019/GRT-058).
	_floor_reveal_state.cancel()
	_node_modal_state.open(
		_current_node_id,
		_node_modal_kind,
		_run_state.export_economy(),
		_build_node_modal_actions()
	)
	if _node_modal_kind == "shop":
		_node_modal_state.set_shop_owned_items(_build_shop_owned_items())
		_prewarm_shop_trade_cells()
	_configure_training_stage_presentation()
	_configure_guardian_spring_presentation()
	_prepare_training_stats_panel()
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


func _prewarm_shop_trade_cells() -> void:
	var card_renderer := _get_cached_node_modal_render_module(
		"runtime_perk_overlay_renderer"
	)
	if (
		card_renderer == null
		or not card_renderer.has_method("prewarm_tower_shop_cells")
	):
		return
	var model: Dictionary = _node_modal_state.build_view_model(
		TowerAscentNodeModalState.BASE_VIEW_SIZE
	)
	card_renderer.call(
		"prewarm_tower_shop_cells",
		model.get("actions", []),
		model.get("shop_owned_items", []),
		model,
		_get_cached_node_modal_render_module("active_item_hud_visuals")
	)

func _handle_node_modal_input(event: InputEvent) -> void:
	var view_size := _get_node_modal_view_size()
	if (
		_node_modal_kind == "guardian_spring"
		and _node_modal_state.has_active_guardian_spring_ritual()
	):
		# GRT-050 policy: the full two-second ritual is unskippable. Every key,
		# pointer, wheel, and touch event is consumed and discarded, never deferred.
		return
	if (
		_node_modal_kind == "training"
		and _node_modal_state.has_training_timing_interaction()
	):
		_handle_training_timing_owned_input(event)
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		_node_modal_state.cancel_pointer_press()
		if key_event.keycode in [KEY_UP, KEY_W]:
			_node_modal_state.move_selection(-1)
			return
		if key_event.keycode in [KEY_DOWN, KEY_S]:
			_node_modal_state.move_selection(1)
			return
		if key_event.keycode == KEY_PAGEUP:
			_node_modal_state.change_visible_page(-1)
			return
		if key_event.keycode == KEY_PAGEDOWN:
			_node_modal_state.change_visible_page(1)
			return
		if key_event.keycode == KEY_ESCAPE:
			if (
				_node_modal_kind == "guardian_spring"
				and _guardian_spring_node.is_first_pick_pending()
			):
				_node_modal_state.set_status_text(TowerAscentNodeModalLocalization.text(
					TowerAscentNodeModalLocalization.KEY_SPRING_FIRST_PICK_REQUIRED
				))
				return
			_try_enter_route_aim_from_node_modal()
			return
		if key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			if _reveal_guardian_spring_menu():
				return
			_confirm_node_modal_action()
		return
	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		_node_modal_state.update_hover_at_position(motion_event.position, view_size)
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_node_modal_state.change_visible_page(-1)
			return
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_node_modal_state.change_visible_page(1)
			return
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_node_modal_state.begin_pointer_press(mouse_event.position, view_size)
		else:
			var released_action: Dictionary = _node_modal_state.release_pointer_at_position(
				mouse_event.position,
				view_size
			)
			if str(released_action.get("_modal_control", "")) == "guardian_statue":
				_reveal_guardian_spring_menu()
				return
			if str(released_action.get("_modal_control", "")) == "page":
				return
			if not released_action.is_empty():
				_confirm_node_modal_action(released_action)
		return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_node_modal_state.begin_pointer_press(touch_event.position, view_size)
		else:
			var released_action: Dictionary = _node_modal_state.release_pointer_at_position(
				touch_event.position,
				view_size
			)
			if str(released_action.get("_modal_control", "")) == "guardian_statue":
				_reveal_guardian_spring_menu()
				return
			if str(released_action.get("_modal_control", "")) == "page":
				return
			if not released_action.is_empty():
				_confirm_node_modal_action(released_action)


func _handle_training_timing_owned_input(event: InputEvent) -> void:
	# GRT-019/GRT-022: while the gauge owns input, no press can arm another card,
	# page control, or the end-work footer. The stop happens on the new press, so
	# the release cannot be reinterpreted after the timing state becomes resolved.
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_ESCAPE:
			if _node_modal_state.has_running_training_timing():
				_cancel_training_timing()
			else:
				_enter_route_aim(true)
			return
		if (
			_node_modal_state.has_running_training_timing()
			and key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		):
			_resolve_training_timing()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if (
			_node_modal_state.has_running_training_timing()
			and mouse_event.button_index == MOUSE_BUTTON_LEFT
			and mouse_event.pressed
		):
			_resolve_training_timing()
		return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if _node_modal_state.has_running_training_timing() and touch_event.pressed:
			_resolve_training_timing()


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

func _confirm_node_modal_action(pointer_action: Dictionary = {}) -> void:
	var action: Dictionary = (
		pointer_action.duplicate(true)
		if not pointer_action.is_empty()
		else _node_modal_state.get_selected_action()
	)
	if action.is_empty():
		return
	action["_feedback_index"] = _node_modal_state.get_action_index_by_id(
		str(action.get("id", ""))
	)
	if not bool(action.get("enabled", true)):
		var unavailable_reason := str(action.get("unavailable_reason", ""))
		_node_modal_state.set_status_text(unavailable_reason)
		_node_modal_state.record_action_feedback(action, {
			"accepted": false,
			"applied": false,
			"reason": str(action.get("disabled_reason", "disabled")),
			"message": unavailable_reason,
		})
		return
	if str(action.get("id", "")) == TowerAscentNodeModalState.ACTION_END_WORK:
		_try_enter_route_aim_from_node_modal()
		return
	if (
		_node_modal_kind == "training"
		and str(action.get("id", "")).begins_with("training_")
	):
		var timing_result := _begin_training_timing_action(action)
		if not bool(timing_result.get("prepared", false)):
			_node_modal_state.record_action_feedback(action, timing_result)
			_node_modal_state.set_status_text(str(timing_result.get(
				"message",
				timing_result.get("reason", "")
			)))
		return
	var payload_value: Variant = action.get("payload", {})
	var payload: Dictionary = payload_value as Dictionary if payload_value is Dictionary else {}
	if (
		_node_modal_kind == "guardian_spring"
		and str(payload.get("operation", "")) == "palm"
		and _node_modal_state.begin_guardian_spring_palm_ritual(action)
	):
		return
	var action_result := execute_node_action(str(action.get("id", "")))
	_node_modal_state.record_action_feedback(action, action_result)
	if not bool(action_result.get("accepted", false)):
		_node_modal_state.set_status_text(str(action_result.get("message", action_result.get("reason", ""))))


func _try_enter_route_aim_from_node_modal() -> bool:
	# A comparison overlay is part of the Spring node transaction. Never close
	# the backing NODE_MODAL while that transaction is pending: the public input
	# route gives ESC to the overlay, which cancels it and clears runtime state.
	if (
		_node_modal_kind == "guardian_spring"
		and _guardian_spring_node.has_pending_browse_compare()
	):
		_node_modal_state.set_status_text(TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_SPRING_ACTION_UNAVAILABLE
		))
		return false
	return _enter_route_aim(true)


func _configure_training_stage_presentation() -> void:
	if _node_modal_kind != "training" or _node_modal_state == null:
		return
	var texture_cache: Dictionary = {}
	var resources := _get_cached_node_modal_render_module("battle_resources")
	if resources != null and resources.has_method("get_resource_cache"):
		var cache_value: Variant = resources.get_resource_cache()
		if cache_value is Dictionary:
			texture_cache = cache_value as Dictionary
	var selected_character_type := "smasher"
	if _active_owner != null:
		var character_value: Variant = _active_owner.get("selected_character_type")
		if character_value != null:
			selected_character_type = str(character_value)
	var audio := _get_cached_node_modal_render_module("game_audio")
	_node_modal_state.configure_training_stage_presentation(
		selected_character_type,
		texture_cache,
		audio
	)


func _configure_guardian_spring_presentation() -> void:
	if _node_modal_kind != "guardian_spring" or _node_modal_state == null:
		return
	var bundle := get_guardian_spring_presentation_asset_bundle()
	var acquisition_target_pos := Vector2(380.0, 690.0)
	var view_size := _get_node_modal_view_size()
	if (
		bool(bundle.get("ready", false))
		and _guardian_spring_absorption_target_resolver != null
		and _guardian_spring_absorption_target_resolver.has_method("resolve_target")
	):
		var target_value: Variant = _guardian_spring_absorption_target_resolver.call(
			"resolve_target",
			{
				"id": "unlock_soul_summon_art",
				"unlocks_skill": "soul_summon_art",
				"is_skill_manual": true,
				"start_card_kind": "chosik",
			},
			_active_owner,
			_active_registry,
			view_size
		)
		if target_value is Dictionary:
			var target: Dictionary = target_value as Dictionary
			if target.get("target_pos", null) is Vector2:
				var screen_target: Vector2 = target.get("target_pos", acquisition_target_pos)
				var content_scale := minf(
					maxf(1.0, view_size.x) / TowerAscentNodeModalState.BASE_VIEW_SIZE.x,
					maxf(1.0, view_size.y) / TowerAscentNodeModalState.BASE_VIEW_SIZE.y
				)
				var content_offset := (
					view_size - TowerAscentNodeModalState.BASE_VIEW_SIZE * content_scale
				) * 0.5
				acquisition_target_pos = (
					(screen_target - content_offset) / maxf(0.001, content_scale)
				)
	_node_modal_state.configure_guardian_spring_presentation(
		bool(bundle.get("ready", false)),
		acquisition_target_pos
	)


func _reveal_guardian_spring_menu() -> bool:
	if (
		_node_modal_kind != "guardian_spring"
		or _node_modal_state == null
		or not _node_modal_state.reveal_guardian_spring_menu()
	):
		return false
	_node_modal_state.set_status_text(TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SPRING_STATUE_DIALOGUE
	))
	return true

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
	_guardian_spring_node.sync_owner_projection(_active_owner, _run_state, _active_registry)
	_refresh_guardian_spring_modal(str(result.get("message", result.get("reason", ""))))
	return result

func _refresh_guardian_spring_modal(status_text: String) -> void:
	_node_modal_state.set_actions(_build_guardian_spring_actions())
	_node_modal_state.set_balances(_run_state.export_economy())
	_node_modal_state.set_status_text(status_text)


func _complete_guardian_spring_palm_ritual_if_ready() -> bool:
	if _node_modal_kind != "guardian_spring" or _node_modal_state == null:
		return false
	var action: Dictionary = _node_modal_state.take_completed_guardian_spring_palm_action()
	if action.is_empty():
		return false
	action["_feedback_index"] = _node_modal_state.get_action_index_by_id(
		str(action.get("id", ""))
	)
	var action_result := execute_node_action(str(action.get("id", "")))
	_node_modal_state.record_action_feedback(action, action_result)
	return true


func has_pending_guardian_spring_browse_compare(pet_id: String = "") -> bool:
	return _guardian_spring_node.has_pending_browse_compare(pet_id)


func cancel_guardian_spring_browse_compare() -> Dictionary:
	var result: Dictionary = _guardian_spring_node.cancel_browse_compare()
	if bool(result.get("handled", false)):
		_guardian_state = _guardian_spring_node.export_state()
		_refresh_guardian_spring_modal("")
	return result


func commit_guardian_spring_browse_purchase(
	slot_index: int,
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	var commit_owner: Object = owner if owner != null else _active_owner
	var commit_registry: Object = registry if registry != null else _active_registry
	var result: Dictionary = _guardian_spring_node.commit_browse_purchase(
		slot_index,
		_run_state,
		_resolution_ids,
		_node_action_transaction,
		commit_owner,
		commit_registry
	)
	if bool(result.get("handled", false)):
		_guardian_state = _guardian_spring_node.export_state()
		_guardian_spring_node.sync_owner_projection(commit_owner, _run_state, commit_registry)
		_refresh_guardian_spring_modal(str(result.get("reason", "")))
	return result

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
