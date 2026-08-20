extends "res://scripts/tower_ascent/tower_ascent_flow_node_progress.gd"

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
	var clear_floor: int = TowerAuditionBuildConfig.get_clear_floor()
	if normalized_resolution_id.is_empty():
		normalized_resolution_id = _make_resolution_id(
			"floor_%02d_standard_clear" % clear_floor,
			"ending_judgment"
		)
	var result: Dictionary = _ending_state.resolve_floor_nine(
		_run_state.get_run_id(),
		normalized_resolution_id,
		_record_store,
		clear_floor
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
		var clear_floor: int = _ending_state.get_clear_floor()
		return begin_run_settlement(
			TowerAscentSettlementState.RESULT_STANDARD_CLEAR,
			clear_floor,
			_make_resolution_id("floor_%02d" % clear_floor, "standard_clear_settlement"),
			_finish_callback,
			_active_owner,
			_active_registry
		)
	_unlock_true_ending_route()
	_enter_true_route_transition()
	_request_redraw(_active_owner)
	return result

func _finish_vertical_slice(encounter: Dictionary = {}) -> void:
	var callback := _finish_callback
	_finish_callback = Callable()
	_route_serve_runtime.cancel()
	_modal_lifecycle.leave()
	_node_modal_state.close()
	_clear_retained_noncombat_node_background()
	_active_owner = null
	_active_registry = null
	_active = false
	_phase = PHASE_COMBAT
	if callback.is_valid():
		# Route callbacks consume the encounter dictionary while settlement and
		# node-exit callbacks consume no arguments. Dispatch by the Callable's
		# remaining arity; method-name strings are not a contract and silently break
		# when a production callback is renamed (GRT-048).
		var callback_argument_count := callback.get_argument_count()
		if callback_argument_count == 0:
			callback.call()
		elif callback_argument_count == 1:
			callback.call(encounter)
		else:
			push_warning(
				"[TowerAscent] finish callback rejected: unsupported arity %d"
				% callback_argument_count
			)

func _complete_map_transition() -> void:
	var arrived_node := _get_node(_selected_target_id)
	if arrived_node.is_empty():
		_finish_vertical_slice()
		return
	_current_node_id = _selected_target_id
	_route_source_node_id = _current_node_id
	_route_target_ids.assign(_outgoing_target_ids(_current_node_id))
	_selected_target_id = ""
	_refresh_route_target_cache()
	var arrived_kind := str(arrived_node.get("kind", ""))
	if arrived_kind in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS:
		_node_modal_kind = _normalize_node_modal_kind(arrived_kind)
		_retain_noncombat_node_background(arrived_kind)
		_phase = PHASE_NODE_MODAL
		_open_node_modal()
		_transition_fade_state.begin_node_modal_fade()
		return
	var encounter := TowerAscentBossRegistry.new().resolve_battle_encounter(
		str(arrived_node.get("boss_slot_id", ""))
	)
	if encounter.is_empty():
		push_error("[TowerAscent] combat node has no routable boss encounter: %s" % str(arrived_node.get("id", "")))
		_finish_vertical_slice()
		return
	if bool(encounter.get("fallback_used", false)):
		push_warning(
			"[TowerAscent] boss slot %s uses stand-in stage %d boss %s"
			% [
				str(encounter.get("boss_slot_id", "")),
				int(encounter.get("stage", 0)),
				str(encounter.get("boss_id", "")),
			]
		)
	_finish_vertical_slice(encounter)

func _dismiss_fake_ending_teaser() -> void:
	var result: Dictionary = _ending_state.mark_teaser_presented()
	if not bool(result.get("accepted", false)) or not bool(result.get("changed", false)):
		return
	var clear_floor: int = _ending_state.get_clear_floor()
	begin_run_settlement(
		TowerAscentSettlementState.RESULT_STANDARD_CLEAR,
		clear_floor,
		_make_resolution_id("floor_%02d" % clear_floor, "standard_clear_settlement"),
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
	_sync_run_state_phases()
	for phase_index in range(_graph_phases.size()):
		var phase := _graph_phases[phase_index].duplicate(true)
		var nodes: Array = phase.get("nodes", [])
		for node_variant in nodes:
			if node_variant is Dictionary and int((node_variant as Dictionary).get("floor", 0)) >= 10:
				(node_variant as Dictionary)["route_locked"] = false
		var hints: Array = phase.get("locked_phase_hints", [])
		for hint_variant in hints:
			if hint_variant is Dictionary:
				(hint_variant as Dictionary)["locked"] = false
		phase["nodes"] = nodes
		phase["locked_phase_hints"] = hints
		_graph_phases[phase_index] = phase
	_activate_graph_phase(_active_graph_phase_index, false)
	_sync_run_state_phases()

func _enter_true_route_transition() -> void:
	var source_id := _find_floor_node_id(9, false)
	if not _activate_graph_phase(1):
		return
	var target_id := _find_floor_node_id(10, true)
	if not source_id.is_empty():
		_route_source_node_id = source_id
		_current_node_id = source_id
	if not target_id.is_empty():
		_route_target_ids.assign([target_id])
		_selected_target_id = target_id
		_route_history.append({"from": _route_source_node_id, "to": target_id})
	_phase = PHASE_MAP_TRANSITION
	_map_transition_progress = 0.0
	_transition_fade_state.begin_map_transition()
	_selector_launched = false
	_selector_velocity = Vector2.ZERO
