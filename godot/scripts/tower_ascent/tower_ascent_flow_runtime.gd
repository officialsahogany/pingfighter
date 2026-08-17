extends "res://scripts/tower_ascent/tower_ascent_flow_node_progress.gd"


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




func restore_snapshot(
	snapshot: Dictionary,
	finish_callback: Callable = Callable(),
	owner: Object = null,
	registry: Object = null,
	gauntlet_transition_callback: Callable = Callable()
) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return false
	if not bool(snapshot.get("stable_boundary", false)):
		return false
	if str(snapshot.get("map_graph_storage", "")) != MAP_GRAPH_STORAGE_FULL:
		return false
	if str(snapshot.get("map_generator_version", "")) != MAP_GENERATOR_VERSION:
		return false
	if not snapshot.has("map_seed"):
		return false
	_reset_runtime_state()
	if not _run_state.restore_snapshot(snapshot):
		return false
	var phases: Array[Dictionary] = _run_state.get_phases()
	_graph_phases.assign(phases.duplicate(true))
	var graph: Dictionary = phases[0]
	var nodes_variant: Variant = graph.get("nodes", [])
	var edges_variant: Variant = graph.get("edges", [])
	if not (nodes_variant is Array) or (nodes_variant as Array).size() < 4:
		return false
	if not (edges_variant is Array) or (edges_variant as Array).size() < 3:
		return false
	_map_seed = int(snapshot.get("map_seed", 0))
	_header_subtitle = "생성 지도 검증판 · %s" % _run_state.get_run_id()
	_graph_nodes.assign((nodes_variant as Array).duplicate(true))
	_graph_edges.assign((edges_variant as Array).duplicate(true))
	_current_node_id = str(snapshot.get("current_node_id", ""))
	_completed_nodes.assign(_dictionary_array(snapshot.get("completed_nodes", [])))
	for entry in _completed_nodes:
		_resolution_ids[str(entry.get("node_resolution_id", ""))] = true
	_pending_rewards.assign(_dictionary_array(snapshot.get("pending_rewards", [])))
	_generated_shop_inventory.assign(_dictionary_array(snapshot.get("generated_shop_inventory", [])))
	_purchase_history.assign(_dictionary_array(snapshot.get("purchase_history", [])))
	for purchase in _purchase_history:
		var purchase_resolution_id := str(purchase.get("node_resolution_id", ""))
		if not purchase_resolution_id.is_empty():
			_resolution_ids[purchase_resolution_id] = true
	_generated_training_offers.assign(_dictionary_array(snapshot.get("generated_training_offers", [])))
	_training_history.assign(_dictionary_array(snapshot.get("training_history", [])))
	for training_record in _training_history:
		var training_resolution_id := str(training_record.get("node_resolution_id", ""))
		if not training_resolution_id.is_empty():
			_resolution_ids[training_resolution_id] = true
	_fallen_monk_node.restore_state(
		snapshot.get("generated_fallen_monk_offers", []),
		snapshot.get("fallen_monk_history", []),
		snapshot.get("fallen_monk_runtime_snapshot", {}),
		snapshot.get("fallen_monk_skill_config_snapshot", {})
	)
	for monk_record in _fallen_monk_node.get_history():
		var monk_resolution_id := str(monk_record.get("node_resolution_id", ""))
		if not monk_resolution_id.is_empty():
			_resolution_ids[monk_resolution_id] = true
	if not _fallen_monk_node.restore_runtime(owner, registry):
		_reset_runtime_state()
		return false
	_claimed_decoration_ids.assign(_string_array(snapshot.get("claimed_decoration_ids", [])))
	_build_state = _dictionary_copy(snapshot.get("build_state", {}))
	_guardian_state = _dictionary_copy(snapshot.get("guardian_state", {}))
	_guardian_spring_node.restore_state(_guardian_state)
	for guardian_record in _guardian_spring_node.get_history():
		var guardian_resolution_id := str(guardian_record.get("node_resolution_id", ""))
		if not guardian_resolution_id.is_empty():
			_resolution_ids[guardian_resolution_id] = true
	if not _guardian_spring_node.restore_runtime(owner, registry):
		_reset_runtime_state()
		return false
	_rest_node.restore_state(snapshot.get("rest_history", []))
	for rest_record in _rest_node.get_history():
		var rest_resolution_id := str(rest_record.get("node_resolution_id", ""))
		if not rest_resolution_id.is_empty():
			_resolution_ids[rest_resolution_id] = true
	if not _ending_state.restore_state(snapshot.get("ending_state", {})):
		_reset_runtime_state()
		return false
	var snapshot_phase := int(snapshot.get("phase", PHASE_NODE_MODAL))
	if snapshot_phase == PHASE_RUN_SETTLEMENT:
		var settlement_snapshot: Variant = snapshot.get("settlement_state", {})
		if not _settlement_state.restore_state(settlement_snapshot):
			_reset_runtime_state()
			return false
	var gauntlet_snapshot: Variant = snapshot.get("gauntlet_state", {})
	if gauntlet_snapshot is Dictionary and not (gauntlet_snapshot as Dictionary).is_empty():
		var gauntlet_has_identity := not str(
			(gauntlet_snapshot as Dictionary).get("node_resolution_id", "")
		).is_empty()
		if gauntlet_has_identity and not _gauntlet_state.restore_state(gauntlet_snapshot):
			_reset_runtime_state()
			return false
	_codex_discoveries.assign(_dictionary_array(snapshot.get("codex_discoveries", [])))
	_run_defeat_count = maxi(0, int(snapshot.get("run_defeat_count", 0)))
	_defeat_event_ids.assign(_string_array(snapshot.get("defeat_event_ids", [])))
	if _run_defeat_count != _defeat_event_ids.size():
		_reset_runtime_state()
		return false
	_gameplay_rng_state = _dictionary_copy(snapshot.get("gameplay_rng_state", {}))
	_route_history.assign(_dictionary_array(snapshot.get("route_history", [])))
	_route_source_node_id = str(snapshot.get("route_source_node_id", ""))
	_route_target_ids.assign(_string_array(snapshot.get("route_target_ids", [])))
	if _route_source_node_id.is_empty() or _route_target_ids.size() != 2:
		return false
	_refresh_route_target_cache()
	_selected_target_id = str(snapshot.get("selected_target_id", ""))
	_node_modal_kind = _normalize_node_modal_kind(str(snapshot.get(
		"node_modal_kind",
		"guardian_spring"
	)))
	_phase = clampi(
		snapshot_phase,
		PHASE_NODE_MODAL,
		PHASE_GAUNTLET_TRANSITION
	)
	_selector_position = snapshot.get("selector_position", SELECTOR_ORIGIN)
	_selector_velocity = snapshot.get("selector_velocity", Vector2.ZERO)
	_selector_launched = bool(snapshot.get("selector_launched", false))
	_aim_target_x = clampf(float(snapshot.get("aim_target_x", 220.0)), SELECTOR_LEFT_WALL, SELECTOR_RIGHT_WALL)
	_map_transition_progress = clampf(float(snapshot.get("map_transition_progress", 0.0)), 0.0, 1.0)
	_finish_callback = finish_callback
	_gauntlet_transition_callback = gauntlet_transition_callback
	if not _restore_runtime_perk_build_state(owner, registry):
		_reset_runtime_state()
		return false
	var lifecycle_result: Dictionary = _modal_lifecycle.enter(owner, registry)
	if not bool(lifecycle_result.get("accepted", false)):
		_reset_runtime_state()
		return false
	_active_owner = owner
	_active_registry = registry
	_guardian_spring_node.sync_owner_projection(owner)
	_active = true
	_prepared = false
	_prepared_resolution_id = ""
	if _phase == PHASE_NODE_MODAL:
		_open_node_modal()
	else:
		_node_modal_state.close()
	if _phase == PHASE_FAKE_ENDING_TEASER and not _ending_state.is_teaser_pending():
		_reset_runtime_state()
		return false
	if (
		_phase == PHASE_ENDING_CHOICE
		and not bool(_ending_state.export_state().get("choice_required", false))
	):
		_reset_runtime_state()
		return false
	if _phase == PHASE_RUN_SETTLEMENT and not _settlement_state.is_active():
		_reset_runtime_state()
		return false
	if _phase == PHASE_GAUNTLET_TRANSITION and not _gauntlet_state.is_transition_pending():
		_reset_runtime_state()
		return false
	return true


func export_snapshot() -> Dictionary:
	_sync_run_state_phases()
	_guardian_state = _guardian_spring_node.export_state()
	var snapshot: Dictionary = _run_state.export_snapshot_fields()
	snapshot.merge({
		"map_generator_version": MAP_GENERATOR_VERSION,
		"map_graph_storage": MAP_GRAPH_STORAGE_FULL,
		"map_seed": _map_seed,
		"current_node_id": _current_node_id,
		"completed_nodes": _completed_nodes.duplicate(true),
		"pending_rewards": _pending_rewards.duplicate(true),
		"generated_shop_inventory": _generated_shop_inventory.duplicate(true),
		"purchase_history": _purchase_history.duplicate(true),
		"generated_training_offers": _generated_training_offers.duplicate(true),
		"training_history": _training_history.duplicate(true),
		"generated_fallen_monk_offers": _fallen_monk_node.get_generated_offers(),
		"fallen_monk_history": _fallen_monk_node.get_history(),
		"fallen_monk_runtime_snapshot": _fallen_monk_node.get_runtime_snapshot(),
		"fallen_monk_skill_config_snapshot": _fallen_monk_node.get_skill_config_snapshot(),
		"claimed_decoration_ids": _claimed_decoration_ids.duplicate(),
		"build_state": _build_state.duplicate(true),
		"guardian_state": _guardian_state.duplicate(true),
		"rest_history": _rest_node.get_history(),
		"ending_state": _ending_state.export_state(),
		"settlement_state": _settlement_state.export_state(),
		"gauntlet_state": _gauntlet_state.export_state(),
		"codex_discoveries": _codex_discoveries.duplicate(true),
		"run_defeat_count": _run_defeat_count,
		"defeat_event_ids": _defeat_event_ids.duplicate(),
		"gameplay_rng_state": _gameplay_rng_state.duplicate(true),
		"route_history": _route_history.duplicate(true),
		"route_source_node_id": _route_source_node_id,
		"route_target_ids": _route_target_ids.duplicate(),
		"selected_target_id": _selected_target_id,
		"node_modal_kind": _node_modal_kind,
		"phase": _phase,
		"selector_position": _selector_position,
		"selector_velocity": _selector_velocity,
		"selector_launched": _selector_launched,
		"aim_target_x": _aim_target_x,
		"map_transition_progress": _map_transition_progress,
		"stable_boundary": _phase in [
			PHASE_NODE_MODAL,
			PHASE_MAP_TRANSITION,
			PHASE_FAKE_ENDING_TEASER,
			PHASE_ENDING_CHOICE,
			PHASE_RUN_SETTLEMENT,
			PHASE_GAUNTLET_TRANSITION,
		],
	}, true)
	return snapshot


func export_persistable_snapshot() -> Dictionary:
	var snapshot := export_snapshot()
	if not bool(snapshot.get("stable_boundary", false)) or not _pending_rewards.is_empty():
		return {}
	return snapshot


func export_pending_reward_journal() -> Dictionary:
	return {
		"run_id": _run_state.get_run_id(),
		"pending_rewards": _pending_rewards.duplicate(true),
	}


func recover_pending_reward_journal(journal: Dictionary) -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return {"accepted": false, "reason": "feature_disabled"}
	if str(journal.get("run_id", "")) != _run_state.get_run_id():
		return {"accepted": false, "reason": "run_id_mismatch"}
	var pending_entries := _dictionary_array(journal.get("pending_rewards", []))
	var applied_count := 0
	var committed_count := 0
	var skipped_count := 0
	for pending in pending_entries:
		var validation: Dictionary = _resolution_transaction.validate_pending(
			pending,
			_run_state.get_run_id()
		)
		if not bool(validation.get("accepted", false)):
			return {"accepted": false, "reason": validation.get("reason", "invalid_pending")}
		var resolution_id := str(pending.get("node_resolution_id", ""))
		if _resolution_ids.has(resolution_id):
			skipped_count += 1
			continue
		var apply_result: Dictionary = _resolution_transaction.apply_once(
			pending,
			_run_state,
			_resolution_ids
		)
		if not bool(apply_result.get("accepted", false)):
			return {"accepted": false, "reason": apply_result.get("reason", "reward_apply_failed")}
		if bool(apply_result.get("applied", false)):
			applied_count += 1
		if _commit_node_resolution(
			str(pending.get("node_id", "")),
			str(pending.get("resolution_kind", "")),
			{"reward_source": pending.get("reward_source", ""), "reward_bundle": pending.get("reward_bundle", {})},
			resolution_id
		):
			committed_count += 1
		_resolution_transaction.mark_committed(resolution_id)
	return {
		"accepted": true,
		"applied_count": applied_count,
		"committed_count": committed_count,
		"skipped_count": skipped_count,
	}


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






































func resolve_defeat(
	registry: Object,
	owner: Object,
	continue_callback: Callable,
	exit_callback: Callable
) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return false
	if not _defeat_resolver.is_scoreboard_player_defeat(registry):
		return false
	if not ensure_run_started(owner):
		return false
	var defeat_result := record_run_defeat()
	if not bool(defeat_result.get("accepted", false)):
		return false
	if _gauntlet_state.is_active():
		_gauntlet_state.record_defeat(
			str(defeat_result.get("event_id", ""))
		)
	if _run_state.get_chance_gems() <= 0:
		var floor := maxi(
			int(get_current_node_risk_context().get("floor", 1)),
			_get_owner_int(owner, "current_stage", 1)
		)
		var settlement_result := begin_run_settlement(
			TowerAscentSettlementState.RESULT_DEFEAT,
			floor,
			_make_resolution_id("floor_%02d" % floor, "defeat_settlement"),
			exit_callback,
			owner,
			registry
		)
		return bool(settlement_result.get("accepted", false))
	return _defeat_resolver.resolve(
		registry,
		owner,
		_run_state,
		continue_callback,
		exit_callback
	)


func get_header_subtitle() -> String:
	return _header_subtitle
























func set_record_store_path_for_tests(path: String) -> void:
	_record_store.set_save_path(path)


func get_record_snapshot() -> Dictionary:
	return _record_store.get_snapshot()


func begin_floor_nine_resolution(
	resolution_id: String = "",
	finish_callback: Callable = Callable(),
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return {"accepted": false, "reason": "feature_disabled"}
	if not ensure_run_started(owner):
		return {"accepted": false, "reason": "run_unavailable"}
	var normalized_resolution_id := resolution_id.strip_edges()
	if normalized_resolution_id.is_empty():
		normalized_resolution_id = _make_resolution_id(
			"floor_09_fake_ending",
			"ending_judgment"
		)
	var result: Dictionary = _ending_state.resolve_floor_nine(
		_run_state.get_run_id(),
		normalized_resolution_id,
		_record_store
	)
	if not bool(result.get("accepted", false)):
		return result
	var ending_state: Dictionary = _ending_state.export_state()
	var target_phase := PHASE_COMBAT
	if _ending_state.is_teaser_pending():
		target_phase = PHASE_FAKE_ENDING_TEASER
	elif bool(ending_state.get("choice_required", false)):
		target_phase = PHASE_ENDING_CHOICE
	else:
		return result
	if not _modal_lifecycle.is_active():
		var lifecycle_result: Dictionary = _modal_lifecycle.enter(owner, registry)
		if not bool(lifecycle_result.get("accepted", false)):
			return {"accepted": false, "reason": lifecycle_result.get("reason", "modal_enter_failed")}
	_active_owner = owner
	_active_registry = registry
	_finish_callback = finish_callback
	_active = true
	_phase = target_phase
	_node_modal_state.close()
	_request_redraw(owner)
	return result


func get_ending_state_snapshot() -> Dictionary:
	return _ending_state.export_state()


func get_ending_view_model() -> Dictionary:
	return _ending_state.build_teaser_view_model()


func get_ending_choice_view_model() -> Dictionary:
	return _ending_state.build_choice_view_model()


func get_settlement_state_snapshot() -> Dictionary:
	return _settlement_state.export_state()


func get_settlement_view_model() -> Dictionary:
	return _settlement_state.build_view_model()


func get_gauntlet_state_snapshot() -> Dictionary:
	return _gauntlet_state.export_state()


func get_gauntlet_transition_view_model() -> Dictionary:
	return _gauntlet_state.build_transition_view_model()


func get_run_defeat_count() -> int:
	return _run_defeat_count


func record_run_defeat(event_id: String = "") -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled() or not _run_state.has_started():
		return {"accepted": false, "changed": false, "reason": "run_unavailable"}
	var normalized_id := event_id.strip_edges()
	if normalized_id.is_empty():
		normalized_id = "%s:defeat:%d" % [_run_state.get_run_id(), _run_defeat_count + 1]
	if _defeat_event_ids.has(normalized_id):
		return {
			"accepted": true,
			"changed": false,
			"reason": "already_committed",
			"event_id": normalized_id,
			"defeat_count": _run_defeat_count,
		}
	_defeat_event_ids.append(normalized_id)
	_run_defeat_count += 1
	return {
		"accepted": true,
		"changed": true,
		"reason": "recorded",
		"event_id": normalized_id,
		"defeat_count": _run_defeat_count,
	}


func begin_floor_eleven_gauntlet(node_resolution_id: String = "") -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return {"accepted": false, "reason": "feature_disabled"}
	var group_node := _find_floor_eleven_gauntlet_node()
	if group_node.is_empty():
		return {"accepted": false, "reason": "missing_floor_eleven_group"}
	var slot_ids := _string_array(group_node.get("boss_sequence_slot_ids", []))
	var standins := _dictionary_array(group_node.get("standin_sequence", []))
	if slot_ids.size() != TowerAscentGauntletState.ENCOUNTER_COUNT or standins.size() != slot_ids.size():
		return {"accepted": false, "reason": "invalid_floor_eleven_sequence"}
	var sequence: Array[Dictionary] = []
	for index in range(slot_ids.size()):
		var slot := TowerAscentBossRegistry.new().get_slot(slot_ids[index])
		sequence.append({
			"slot_id": slot_ids[index],
			"display_name": str(slot.get("display_name", "4천왕 슬롯")),
			"standin": standins[index].duplicate(true),
		})
	var normalized_id := node_resolution_id.strip_edges()
	if normalized_id.is_empty():
		normalized_id = _make_resolution_id(
			str(group_node.get("id", "floor_11_four_kings_group")),
			"four_kings_gauntlet"
		)
	var result: Dictionary = _gauntlet_state.start(normalized_id, sequence)
	if bool(result.get("accepted", false)):
		_set_floor_eleven_encounter_locked(false)
	return result


func resolve_gauntlet_victory(
	transition_callback: Callable = Callable(),
	owner: Object = null,
	registry: Object = null,
	event_id: String = ""
) -> Dictionary:
	if not _gauntlet_state.is_active():
		var start_result := begin_floor_eleven_gauntlet()
		if not bool(start_result.get("accepted", false)):
			return start_result
	var encounter_index := int(_gauntlet_state.export_state().get("encounter_index", 0))
	var normalized_event_id := event_id.strip_edges()
	if normalized_event_id.is_empty():
		normalized_event_id = "%s:encounter:%d:victory" % [
			str(_gauntlet_state.export_state().get("node_resolution_id", "")),
			encounter_index,
		]
	var result: Dictionary = _gauntlet_state.resolve_victory(normalized_event_id)
	if not bool(result.get("accepted", false)) or not bool(result.get("changed", false)):
		return result
	if str(result.get("reason", "")) == "gauntlet_completed":
		return result
	if not _modal_lifecycle.is_active():
		var lifecycle_result: Dictionary = _modal_lifecycle.enter(owner, registry)
		if not bool(lifecycle_result.get("accepted", false)):
			return {
				"accepted": false,
				"reason": lifecycle_result.get("reason", "modal_enter_failed"),
			}
	_active_owner = owner
	_active_registry = registry
	_gauntlet_transition_callback = transition_callback
	_active = true
	_phase = PHASE_GAUNTLET_TRANSITION
	_node_modal_state.close()
	_request_redraw(owner)
	return result


func begin_floor_twelve_true_ending(
	resolution_id: String = "",
	finish_callback: Callable = Callable(),
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return {"accepted": false, "reason": "feature_disabled"}
	if not ensure_run_started(owner):
		return {"accepted": false, "reason": "run_unavailable"}
	if not bool(_ending_state.export_state().get("route_unlocked", false)):
		return {"accepted": false, "reason": "true_route_locked"}
	if not bool(_gauntlet_state.export_state().get("completed", false)):
		return {"accepted": false, "reason": "gauntlet_incomplete"}
	var normalized_id := resolution_id.strip_edges()
	if normalized_id.is_empty():
		normalized_id = _make_resolution_id("floor_12_true_ending", "true_ending")
	var record_result: Dictionary = _record_store.record_clear(
		12,
		TowerAscentRecordStore.ENDING_TRUE,
		_run_defeat_count == 0,
		"%s:true_clear" % normalized_id
	)
	if not bool(record_result.get("accepted", false)):
		return record_result
	var settlement_result := begin_run_settlement(
		TowerAscentSettlementState.RESULT_TRUE_ENDING,
		12,
		"%s:settlement" % normalized_id,
		finish_callback,
		owner,
		registry
	)
	settlement_result["record_result"] = record_result.duplicate(true)
	settlement_result["undefeated"] = _run_defeat_count == 0
	return settlement_result


func begin_run_settlement(
	result_kind: String,
	floor: int,
	resolution_id: String,
	finish_callback: Callable = Callable(),
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return {"accepted": false, "reason": "feature_disabled"}
	if not ensure_run_started(owner):
		return {"accepted": false, "reason": "run_unavailable"}
	var lost_build := TowerAscentSettlementState.build_lost_build_summary(
		_run_state.export_economy(),
		_build_state,
		_guardian_spring_node.export_state()
	)
	var floor_result: Dictionary = _record_store.record_floor_reached(
		floor,
		"%s:floor_reached" % resolution_id.strip_edges()
	)
	if not bool(floor_result.get("accepted", false)):
		return floor_result
	var persistent_income := TowerAscentSettlementState.build_persistent_income(
		_record_store.get_snapshot(),
		_codex_discoveries
	)
	var open_result: Dictionary = _settlement_state.open(
		result_kind,
		resolution_id,
		floor,
		lost_build,
		persistent_income
	)
	if not bool(open_result.get("accepted", false)):
		return open_result
	if not _modal_lifecycle.is_active():
		var lifecycle_result: Dictionary = _modal_lifecycle.enter(owner, registry)
		if not bool(lifecycle_result.get("accepted", false)):
			_settlement_state.reset()
			return {
				"accepted": false,
				"reason": lifecycle_result.get("reason", "modal_enter_failed"),
			}
	_active_owner = owner
	_active_registry = registry
	if finish_callback.is_valid():
		_finish_callback = finish_callback
	_active = true
	_phase = PHASE_RUN_SETTLEMENT
	_node_modal_state.close()
	_request_redraw(owner)
	return open_result


func choose_ending_route(choice: String) -> Dictionary:
	var result: Dictionary = _ending_state.commit_choice(choice, _record_store)
	if not bool(result.get("accepted", false)) or not bool(result.get("changed", false)):
		return result
	if choice.strip_edges().to_lower() == TowerAscentEndingState.CHOICE_DESCEND:
		return begin_run_settlement(
			TowerAscentSettlementState.RESULT_STANDARD_CLEAR,
			9,
			_make_resolution_id("floor_09", "standard_clear_settlement"),
			_finish_callback,
			_active_owner,
			_active_registry
		)
	_unlock_true_ending_route()
	_enter_true_route_transition()
	_request_redraw(_active_owner)
	return result
























































































































func _finish_vertical_slice() -> void:
	var callback := _finish_callback
	_finish_callback = Callable()
	_modal_lifecycle.leave()
	_node_modal_state.close()
	_active_owner = null
	_active_registry = null
	_active = false
	_map_seed = 0
	_phase = PHASE_COMBAT
	if callback.is_valid():
		callback.call()


func _dismiss_fake_ending_teaser() -> void:
	var result: Dictionary = _ending_state.mark_teaser_presented()
	if not bool(result.get("accepted", false)) or not bool(result.get("changed", false)):
		return
	begin_run_settlement(
		TowerAscentSettlementState.RESULT_STANDARD_CLEAR,
		9,
		_make_resolution_id("floor_09", "standard_clear_settlement"),
		_finish_callback,
		_active_owner,
		_active_registry
	)


func _confirm_run_settlement() -> void:
	var result: Dictionary = _settlement_state.confirm()
	if not bool(result.get("accepted", false)) or not bool(result.get("changed", false)):
		return
	_finish_vertical_slice()


func _confirm_gauntlet_transition() -> void:
	var result: Dictionary = _gauntlet_state.acknowledge_transition()
	if not bool(result.get("accepted", false)) or not bool(result.get("changed", false)):
		return
	var callback := _gauntlet_transition_callback
	_gauntlet_transition_callback = Callable()
	_modal_lifecycle.leave()
	_node_modal_state.close()
	_active_owner = null
	_active_registry = null
	_active = false
	_phase = PHASE_COMBAT
	if callback.is_valid():
		callback.call(result.get("transition_plan", {}))


func _handle_ending_choice_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode in [KEY_UP, KEY_LEFT, KEY_W, KEY_A]:
			_ending_state.move_choice_selection(-1)
		elif key_event.keycode in [KEY_DOWN, KEY_RIGHT, KEY_S, KEY_D]:
			_ending_state.move_choice_selection(1)
		elif key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			choose_ending_route(_ending_state.get_selected_choice())
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var index := _ending_choice_index_at(mouse_event.position)
			if _ending_state.select_choice_index(index):
				choose_ending_route(_ending_state.get_selected_choice())
		return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			var index := _ending_choice_index_at(touch_event.position)
			if _ending_state.select_choice_index(index):
				choose_ending_route(_ending_state.get_selected_choice())


func _ending_choice_index_at(position: Vector2) -> int:
	for index in range(2):
		if Rect2(158.0, 382.0 + float(index) * 64.0, 444.0, 50.0).has_point(position):
			return index
	return -1


func _unlock_true_ending_route() -> void:
	for node in _graph_nodes:
		if int(node.get("floor", 0)) >= 10:
			node["route_locked"] = false
	_sync_run_state_phases()


func _enter_true_route_transition() -> void:
	var source_id := _find_floor_node_id(9, false)
	var target_id := _find_floor_node_id(10, true)
	if not source_id.is_empty():
		_route_source_node_id = source_id
		_current_node_id = source_id
	if not target_id.is_empty():
		_selected_target_id = target_id
		_route_history.append({"from": _route_source_node_id, "to": target_id})
	_phase = PHASE_MAP_TRANSITION
	_map_transition_progress = 0.0
	_selector_launched = false
	_selector_velocity = Vector2.ZERO
