extends "res://scripts/tower_ascent/tower_ascent_flow_state.gd"

func prepare_vertical_slice_combat(owner: Object, context: Dictionary = {}) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled() or _active:
		return false
	if _prepared:
		return true
	var existing_run_id: String = str(_run_state.get_run_id())
	var existing_economy: Dictionary = _run_state.export_economy()
	var existing_progress := {
		"skipped_boss_ids": _run_state.get_skipped_boss_ids(),
	}
	var existing_map_seed := _map_seed
	var reuse_existing_run: bool = bool(
		_run_state.has_started() and not context.has("run_id")
	)
	_reset_runtime_state()
	var run_id := str(context.get(
		"run_id",
		existing_run_id if reuse_existing_run else "vertical-slice-%d" % Time.get_ticks_msec()
	))
	var economy_variant: Variant = context.get(
		"run_state",
		existing_economy if reuse_existing_run else {}
	)
	var economy: Dictionary = economy_variant if economy_variant is Dictionary else {}
	var progress := existing_progress if reuse_existing_run else {}
	if not _run_state.begin(run_id, economy, [], progress):
		return false
	var current_stage := int(context.get("current_stage", _get_owner_int(owner, "current_stage", 1)))
	_map_seed = int(context.get(
		"map_seed",
		existing_map_seed if reuse_existing_run else _derive_map_seed(run_id, current_stage)
	))
	_node_modal_kind = _normalize_node_modal_kind(str(context.get(
		"node_modal_kind",
		"guardian_spring"
	)))
	_header_subtitle = "생성 지도 검증판 · %s" % _run_state.get_run_id()
	if not _build_generated_graph(current_stage):
		return false
	_current_node_id = _route_source_node_id
	_sync_run_state_phases()
	_prepared_resolution_id = _make_resolution_id(_route_source_node_id, "combat_victory")
	var reward_bundle_variant: Variant = context.get("node_reward_bundle", {})
	var reward_bundle: Dictionary = reward_bundle_variant if reward_bundle_variant is Dictionary else {}
	var pending: Dictionary = _resolution_transaction.prepare(
		_run_state.get_run_id(),
		_route_source_node_id,
		"combat_victory",
		"victory_loot_phase",
		reward_bundle,
		_prepared_resolution_id
	)
	if pending.is_empty():
		return false
	_pending_rewards.append(pending)
	_prepared = true
	return true

func debug_advance_to_route_aim() -> void:
	if _active and _phase == PHASE_NODE_MODAL:
		_enter_route_aim()

func debug_launch_at_target(target_index: int) -> void:
	if not _active or _phase != PHASE_ROUTE_AIM:
		return
	_route_serve_runtime.debug_serve_toward(_route_target_aim_position(target_index))

func debug_launch_miss() -> void:
	if not _active or _phase != PHASE_ROUTE_AIM:
		return
	_route_serve_runtime.debug_serve_miss()

func get_graph_nodes() -> Array[Dictionary]:
	return _graph_nodes

func get_graph_phases() -> Array[Dictionary]:
	_sync_run_state_phases()
	return _graph_phases.duplicate(true)

func get_graph_floors() -> Array:
	if _graph_phases.is_empty():
		return []
	return _graph_phases[0].get("floors", [])

func get_route_target_ids() -> Array[String]:
	return _available_route_target_ids

func get_current_node_id() -> String:
	return _current_node_id

func get_route_aim_targets() -> Array[Dictionary]:
	return _route_aim_targets_cache

func get_skipped_boss_ids() -> Array[String]:
	return _run_state.get_skipped_boss_ids()

func get_current_node_risk_context() -> Dictionary:
	var node := _get_node(_current_node_id)
	if node.is_empty():
		node = _get_node(_route_source_node_id)
	return {
		"floor": maxi(1, int(node.get("floor", 1))),
		"is_elite": bool(node.get("elite", false)),
		"is_enraged": bool(node.get("enraged", false)),
		"is_gatekeeper": bool(node.get("gatekeeper", false)),
		"boss_slot_id": str(node.get("boss_slot_id", "")),
	}

func get_run_id() -> String:
	return _run_state.get_run_id()

func get_map_seed() -> int:
	return _map_seed

func get_graph_edges() -> Array[Dictionary]:
	return _graph_edges

func get_selected_target_id() -> String:
	return _selected_target_id

func get_selector_origin() -> Vector2:
	return SELECTOR_ORIGIN

func get_selector_position() -> Vector2:
	return _route_serve_runtime.get_ball_position()

func get_aim_preview_point() -> Vector2:
	return Vector2(_aim_target_x, SELECTOR_TARGET_Y)

func is_selector_launched() -> bool:
	return _route_serve_runtime.is_ball_in_flight()

func get_map_transition_progress() -> float:
	return _map_transition_progress

func get_rest_node_position() -> Vector2:
	return _node_position(_route_source_node_id)

func get_selected_target_position() -> Vector2:
	return _node_position(_selected_target_id)

func _build_generated_graph(_current_stage: int) -> bool:
	var generated: Dictionary = _map_generator.generate_tower(
		_map_seed,
		_run_state.get_skipped_boss_ids()
	)
	var phases_variant: Variant = generated.get("phases", [])
	if not (phases_variant is Array) or (phases_variant as Array).size() != 1:
		return false
	_graph_phases.assign(_dictionary_array(phases_variant))
	var phase_variant: Variant = _graph_phases[0]
	if not (phase_variant is Dictionary):
		return false
	var phase := phase_variant as Dictionary
	_graph_nodes.assign(_dictionary_array(phase.get("nodes", [])))
	_graph_edges.assign(_dictionary_array(phase.get("edges", [])))
	_route_source_node_id = str(phase.get("entry_node_id", ""))
	_route_target_ids.assign(_string_array(phase.get("initial_route_candidate_ids", [])))
	var valid: bool = (
		int(phase.get("total_floors", 0)) == TowerAscentMapGenerator.TOWER_FLOOR_COUNT
		and not _route_source_node_id.is_empty()
		and _route_target_ids.size() == 2
		and _get_node(_route_source_node_id).get("kind", "") == "boss"
	)
	if valid:
		_refresh_route_target_cache()
	return valid

func _enter_route_aim() -> bool:
	_node_modal_state.close()
	_phase = PHASE_ROUTE_AIM
	_reset_selector()
	var result: Dictionary = _route_serve_runtime.begin(_active_owner, _active_registry)
	return bool(result.get("accepted", false))

func _update_route_serve(delta: float) -> void:
	var result: Dictionary = _route_serve_runtime.update(delta, _route_aim_targets_cache)
	if str(result.get("status", "")) == TowerAscentRouteServeRuntime.STATUS_HIT:
		_resolve_route_target(str(result.get("target_id", "")))

func _resolve_route_target(target_id: String) -> void:
	if not get_route_target_ids().has(target_id):
		return
	_route_serve_runtime.finish_selection()
	_selected_target_id = target_id
	_commit_node_resolution(_route_source_node_id, "route_selected", {"target_node_id": target_id})
	for candidate_id in _route_target_ids:
		if candidate_id == target_id:
			continue
		var skipped_node := _get_node(candidate_id)
		var skipped_slot_id := str(skipped_node.get("boss_slot_id", ""))
		if (
			str(skipped_node.get("kind", "")) in TowerAscentRouteCandidatePolicy.COMBAT_NODE_KINDS
			and _run_state.mark_boss_skipped(skipped_slot_id)
		):
			_mark_boss_slot_skipped_in_graph(skipped_slot_id)
	_route_history.append({"from": _route_source_node_id, "to": target_id})
	_current_node_id = target_id
	_phase = PHASE_MAP_TRANSITION
	_map_transition_progress = 0.0
	_selector_launched = false
	_selector_velocity = Vector2.ZERO

func _commit_node_resolution(
	node_id: String,
	resolution_kind: String,
	payload: Dictionary,
	requested_resolution_id: String = ""
) -> bool:
	var resolution_id := requested_resolution_id
	if resolution_id.is_empty():
		resolution_id = _make_resolution_id(node_id, resolution_kind)
	if _resolution_ids.has(resolution_id):
		return false
	_resolution_ids[resolution_id] = true
	_completed_nodes.append({
		"node_id": node_id,
		"node_resolution_id": resolution_id,
		"resolution_kind": resolution_kind,
		"payload": payload.duplicate(true),
	})
	for node in _graph_nodes:
		if str(node.get("id", "")) == node_id:
			node["completed"] = true
			break
	return true

func _complete_prepared_combat_resolution() -> bool:
	var pending := _find_pending_reward(_prepared_resolution_id)
	if pending.is_empty():
		return false
	var apply_result: Dictionary = _resolution_transaction.apply_once(
		pending,
		_run_state,
		_resolution_ids
	)
	if not bool(apply_result.get("accepted", false)):
		return false
	var committed := _commit_node_resolution(
		str(pending.get("node_id", _route_source_node_id)),
		str(pending.get("resolution_kind", "combat_victory")),
		{
			"reward_source": pending.get("reward_source", "victory_loot_phase"),
			"reward_status": apply_result.get("reason", "reward_applied"),
			"reward_bundle": pending.get("reward_bundle", {}),
		},
		_prepared_resolution_id
	)
	if not committed and not _resolution_ids.has(_prepared_resolution_id):
		return false
	_resolution_transaction.mark_committed(_prepared_resolution_id)
	_remove_pending_reward(_prepared_resolution_id)
	return true

func _find_pending_reward(resolution_id: String) -> Dictionary:
	for pending in _pending_rewards:
		if str(pending.get("node_resolution_id", "")) == resolution_id:
			return pending
	return {}

func _remove_pending_reward(resolution_id: String) -> void:
	for index in range(_pending_rewards.size() - 1, -1, -1):
		if str(_pending_rewards[index].get("node_resolution_id", "")) == resolution_id:
			_pending_rewards.remove_at(index)

func _find_floor_node_id(floor: int, first_row: bool) -> String:
	var selected_id := ""
	var selected_row := 2147483647 if first_row else -2147483648
	for node in _graph_nodes:
		if int(node.get("floor", 0)) != floor:
			continue
		var row := int(node.get("row_index", node.get("row", 0)))
		if (first_row and row < selected_row) or (not first_row and row > selected_row):
			selected_row = row
			selected_id = str(node.get("id", ""))
	return selected_id

func _find_floor_eleven_gauntlet_node() -> Dictionary:
	for node in _graph_nodes:
		if (
			int(node.get("floor", 0)) == 11
			and str(node.get("boss_slot_id", "")) == "floor_11_four_kings_group"
		):
			return node.duplicate(true)
	return {}

func _set_floor_eleven_encounter_locked(locked: bool) -> void:
	for node in _graph_nodes:
		if (
			int(node.get("floor", 0)) == 11
			and str(node.get("boss_slot_id", "")) == "floor_11_four_kings_group"
		):
			node["encounter_locked"] = locked
			break
	_sync_run_state_phases()

func _node_position(node_id: String) -> Vector2:
	var node := _get_node(node_id)
	if not node.is_empty():
		return _vector2(node.get("position", Vector2.ZERO))
	return Vector2.ZERO

func _get_node(node_id: String) -> Dictionary:
	for node in _graph_nodes:
		if str(node.get("id", "")) == node_id:
			return node
	return {}

func _route_target_aim_position(target_index: int) -> Vector2:
	return Vector2(220.0 if target_index <= 0 else 540.0, SELECTOR_TARGET_Y)

func _mark_boss_slot_skipped_in_graph(boss_slot_id: String) -> void:
	if boss_slot_id.is_empty():
		return
	for node in _graph_nodes:
		if str(node.get("boss_slot_id", "")) == boss_slot_id:
			node["route_disabled"] = true
			node["skipped"] = true
	_refresh_route_target_cache()

func _refresh_route_target_cache() -> void:
	_available_route_target_ids.assign(_route_candidate_policy.filter_available(
		_graph_nodes,
		_route_target_ids,
		_run_state.get_skipped_boss_ids()
	))
	_route_aim_targets_cache.clear()
	for raw_index in range(_route_target_ids.size()):
		var target_id := _route_target_ids[raw_index]
		if not _available_route_target_ids.has(target_id):
			continue
		var node := _get_node(target_id)
		_route_aim_targets_cache.append({
			"id": target_id,
			"label": str(node.get("label", "행로")),
			"kind": str(node.get("kind", "")),
			"enraged": bool(node.get("enraged", false)),
			"position": _route_target_aim_position(raw_index),
			"hit_radius": ROUTE_TARGET_HIT_RADIUS,
			"map_position": _node_position(target_id),
		})

func _sync_run_state_phases() -> void:
	if _graph_nodes.is_empty():
		return
	var phase := (
		_graph_phases[0].duplicate(true)
		if not _graph_phases.is_empty()
		else {"id": "phase_01"}
	)
	phase["nodes"] = _graph_nodes.duplicate(true)
	phase["edges"] = _graph_edges.duplicate(true)
	_graph_phases = [phase]
	_run_state.set_phases(_graph_phases)
