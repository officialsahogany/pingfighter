extends "res://scripts/tower_ascent/tower_ascent_flow_state.gd"

const REENTRY_PROGRESS_FIELDS: Array[String] = [
	"active_phase_index",
	"current_node_id",
	"completed_nodes",
	"generated_shop_inventory",
	"purchase_history",
	"generated_training_offers",
	"training_history",
	"generated_fallen_monk_offers",
	"fallen_monk_history",
	"fallen_monk_runtime_snapshot",
	"fallen_monk_skill_config_snapshot",
	"claimed_decoration_ids",
	"build_state",
	"guardian_state",
	"rest_history",
	"ending_state",
	"gauntlet_state",
	"codex_discoveries",
	"run_defeat_count",
	"defeat_event_ids",
	"gameplay_rng_state",
	"route_history",
]

func prepare_vertical_slice_combat(owner: Object, context: Dictionary = {}) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled() or _active:
		return false
	if _prepared:
		return true
	var reuse_existing_run: bool = bool(
		_run_state.has_started() and not context.has("run_id")
	)
	var existing_run_id: String = str(_run_state.get_run_id())
	var existing_economy: Dictionary = _run_state.export_economy()
	var existing_progress := _capture_reentry_progress() if reuse_existing_run else {}
	var existing_map_seed := _map_seed
	var existing_combat_node_id := str(existing_progress.get("current_node_id", ""))
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
	var run_progress_variant: Variant = existing_progress.get("run_progress", {})
	var progress: Dictionary = run_progress_variant if run_progress_variant is Dictionary else {}
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
	if reuse_existing_run and not _restore_reentry_progress(existing_progress):
		return false
	_current_node_id = (
		existing_combat_node_id
		if reuse_existing_run and not existing_combat_node_id.is_empty()
		else _route_source_node_id
	)
	_sync_run_state_phases()
	_prepared_resolution_id = _make_resolution_id(_current_node_id, "combat_victory")
	var reward_bundle_variant: Variant = context.get("node_reward_bundle", {})
	var reward_bundle: Dictionary = reward_bundle_variant if reward_bundle_variant is Dictionary else {}
	var pending: Dictionary = _resolution_transaction.prepare(
		_run_state.get_run_id(),
		_current_node_id,
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


func _capture_reentry_progress() -> Dictionary:
	var all_progress := {
		"active_phase_index": _run_state.get_active_phase_index(),
		"current_node_id": _current_node_id,
		"completed_nodes": _completed_nodes,
		"generated_shop_inventory": _generated_shop_inventory,
		"purchase_history": _purchase_history,
		"generated_training_offers": _generated_training_offers,
		"training_history": _training_history,
		"generated_fallen_monk_offers": _fallen_monk_node.get_generated_offers(),
		"fallen_monk_history": _fallen_monk_node.get_history(),
		"fallen_monk_runtime_snapshot": _fallen_monk_node.get_runtime_snapshot(),
		"fallen_monk_skill_config_snapshot": _fallen_monk_node.get_skill_config_snapshot(),
		"claimed_decoration_ids": _claimed_decoration_ids,
		"build_state": _build_state,
		"guardian_state": _guardian_spring_node.export_state(),
		"rest_history": _rest_node.get_history(),
		"ending_state": _ending_state.export_state(),
		"gauntlet_state": _gauntlet_state.export_state(),
		"codex_discoveries": _codex_discoveries,
		"run_defeat_count": _run_defeat_count,
		"defeat_event_ids": _defeat_event_ids,
		"gameplay_rng_state": _gameplay_rng_state,
		"route_history": _route_history,
	}
	var result := {
		"run_progress": {
			"active_phase_index": _run_state.get_active_phase_index(),
			"skipped_boss_ids": _run_state.get_skipped_boss_ids(),
		},
	}
	for field_name in REENTRY_PROGRESS_FIELDS:
		if all_progress.has(field_name):
			result[field_name] = _copy_progress_value(all_progress[field_name])
	return result


func _restore_reentry_progress(progress: Dictionary) -> bool:
	var phase_index := int(progress.get("active_phase_index", 0))
	if phase_index != _active_graph_phase_index and not _activate_graph_phase(phase_index, false):
		return false
	_completed_nodes.assign(_dictionary_array(progress.get("completed_nodes", [])))
	_resolution_ids.clear()
	for entry in _completed_nodes:
		var resolution_id := str(entry.get("node_resolution_id", ""))
		if not resolution_id.is_empty():
			_resolution_ids[resolution_id] = true
		_mark_node_completed(str(entry.get("node_id", "")))
	_generated_shop_inventory.assign(_dictionary_array(progress.get("generated_shop_inventory", [])))
	_purchase_history.assign(_dictionary_array(progress.get("purchase_history", [])))
	_add_history_resolution_ids(_purchase_history)
	_generated_training_offers.assign(_dictionary_array(progress.get("generated_training_offers", [])))
	_training_history.assign(_dictionary_array(progress.get("training_history", [])))
	_add_history_resolution_ids(_training_history)
	_fallen_monk_node.restore_state(
		progress.get("generated_fallen_monk_offers", []),
		progress.get("fallen_monk_history", []),
		progress.get("fallen_monk_runtime_snapshot", {}),
		progress.get("fallen_monk_skill_config_snapshot", {})
	)
	_add_history_resolution_ids(_fallen_monk_node.get_history())
	_claimed_decoration_ids.assign(_string_array(progress.get("claimed_decoration_ids", [])))
	_build_state = _dictionary_copy(progress.get("build_state", {}))
	_guardian_state = _dictionary_copy(progress.get("guardian_state", {}))
	_guardian_spring_node.restore_state(_guardian_state)
	_add_history_resolution_ids(_guardian_spring_node.get_history())
	_rest_node.restore_state(progress.get("rest_history", []))
	_add_history_resolution_ids(_rest_node.get_history())
	if not _ending_state.restore_state(progress.get("ending_state", {})):
		return false
	var gauntlet_value: Variant = progress.get("gauntlet_state", {})
	if (
		gauntlet_value is Dictionary
		and not str((gauntlet_value as Dictionary).get("node_resolution_id", "")).is_empty()
	):
		if not _gauntlet_state.restore_state(gauntlet_value):
			return false
	_codex_discoveries.assign(_dictionary_array(progress.get("codex_discoveries", [])))
	_run_defeat_count = maxi(0, int(progress.get("run_defeat_count", 0)))
	_defeat_event_ids.assign(_string_array(progress.get("defeat_event_ids", [])))
	_gameplay_rng_state = _dictionary_copy(progress.get("gameplay_rng_state", {}))
	_route_history.assign(_dictionary_array(progress.get("route_history", [])))
	_current_node_id = str(progress.get("current_node_id", _route_source_node_id))
	if _get_node(_current_node_id).is_empty():
		return false
	_route_source_node_id = _current_node_id
	_route_target_ids.assign(_outgoing_target_ids(_current_node_id))
	_refresh_route_target_cache()
	return true


func _mark_node_completed(node_id: String) -> void:
	for node in _graph_nodes:
		if str(node.get("id", "")) == node_id:
			node["completed"] = true
			return


func _add_history_resolution_ids(entries: Array) -> void:
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var resolution_id := str((entry_variant as Dictionary).get("node_resolution_id", ""))
		if not resolution_id.is_empty():
			_resolution_ids[resolution_id] = true


func _copy_progress_value(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value

func debug_advance_to_route_aim() -> void:
	if _active and _phase == PHASE_NODE_MODAL:
		_enter_route_aim()

func debug_launch_at_target(target_index: int) -> void:
	if not _active or _phase != PHASE_ROUTE_AIM:
		return
	if target_index < 0 or target_index >= _route_aim_targets_cache.size():
		return
	var target: Dictionary = _route_aim_targets_cache[target_index]
	_route_serve_runtime.debug_serve_toward(_vector2(target.get("position", Vector2.ZERO)))

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
	return _graph_phases[_active_graph_phase_index].get("floors", [])

func get_active_graph_phase_index() -> int:
	return _active_graph_phase_index

func get_active_graph_phase() -> Dictionary:
	if _graph_phases.is_empty():
		return {}
	var phase := _graph_phases[_active_graph_phase_index].duplicate(true)
	phase["nodes"] = _graph_nodes.duplicate(true)
	phase["edges"] = _graph_edges.duplicate(true)
	return phase

func get_locked_phase_hints() -> Array:
	return get_active_graph_phase().get("locked_phase_hints", [])

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

func get_route_source_node_id() -> String:
	return _route_source_node_id

func is_phase_entry_transition() -> bool:
	return (
		_phase == PHASE_MAP_TRANSITION
		and _active_graph_phase_index == 1
		and _get_node(_route_source_node_id).is_empty()
		and not _selected_target_id.is_empty()
	)

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
	if not (phases_variant is Array) or (phases_variant as Array).size() != 2:
		return false
	_graph_phases.assign(_dictionary_array(phases_variant))
	if not _activate_graph_phase(0, false):
		return false
	var phase_variant: Variant = _graph_phases[0]
	if not (phase_variant is Dictionary):
		return false
	var phase := phase_variant as Dictionary
	_route_source_node_id = str(phase.get("entry_node_id", ""))
	_route_target_ids.assign(_string_array(phase.get("initial_route_candidate_ids", [])))
	var immortal_phase: Dictionary = _graph_phases[1]
	var valid: bool = (
		str(phase.get("id", "")) == TowerAscentMapGenerator.HUMAN_REALM_PHASE_ID
		and int(phase.get("floor_start", 0)) == 1
		and int(phase.get("floor_end", 0)) == TowerAscentMapGenerator.STANDARD_CLEAR_FLOOR
		and int(phase.get("total_floors", 0)) == TowerAscentMapGenerator.STANDARD_CLEAR_FLOOR
		and str(immortal_phase.get("id", "")) == TowerAscentMapGenerator.IMMORTAL_REALM_PHASE_ID
		and int(immortal_phase.get("floor_start", 0)) == 10
		and int(immortal_phase.get("floor_end", 0)) == TowerAscentMapGenerator.TOWER_FLOOR_COUNT
		and int(immortal_phase.get("total_floors", 0)) == 3
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

func _outgoing_target_ids(node_id: String) -> Array[String]:
	var result: Array[String] = []
	for edge in _graph_edges:
		if str(edge.get("from", "")) != node_id:
			continue
		var target_id := str(edge.get("to", ""))
		if not target_id.is_empty() and not result.has(target_id):
			result.append(target_id)
	return result

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
	if node.is_empty():
		node = _get_node_in_all_phases(node_id)
	if not node.is_empty():
		return _vector2(node.get("position", Vector2.ZERO))
	return Vector2.ZERO

func _get_node(node_id: String) -> Dictionary:
	for node in _graph_nodes:
		if str(node.get("id", "")) == node_id:
			return node
	return {}

func _get_node_in_all_phases(node_id: String) -> Dictionary:
	for phase_variant in _graph_phases:
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if (
				node_variant is Dictionary
				and str((node_variant as Dictionary).get("id", "")) == node_id
			):
				return (node_variant as Dictionary).duplicate(true)
	return {}

func _route_target_aim_position(target_index: int, target_count: int = 2) -> Vector2:
	if target_count <= 1:
		return Vector2(
			TowerAscentTuning.TEMP_ROUTE_TARGET_CENTER_X,
			TowerAscentTuning.TEMP_ROUTE_TARGET_Y
		)
	return Vector2(
			TowerAscentTuning.TEMP_ROUTE_TARGET_LEFT_X
			if target_index <= 0
			else TowerAscentTuning.TEMP_ROUTE_TARGET_RIGHT_X,
		TowerAscentTuning.TEMP_ROUTE_TARGET_Y
	)

func _mark_boss_slot_skipped_in_graph(boss_slot_id: String) -> void:
	if boss_slot_id.is_empty():
		return
	_sync_run_state_phases()
	for phase_index in range(_graph_phases.size()):
		var phase := _graph_phases[phase_index].duplicate(true)
		var nodes: Array = phase.get("nodes", [])
		for node_variant in nodes:
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if str(node.get("boss_slot_id", "")) == boss_slot_id:
				node["route_disabled"] = true
				node["skipped"] = true
		phase["nodes"] = nodes
		_graph_phases[phase_index] = phase
	_activate_graph_phase(_active_graph_phase_index, false)
	_refresh_route_target_cache()

func _refresh_route_target_cache() -> void:
	_available_route_target_ids.assign(_route_candidate_policy.filter_available(
		_graph_nodes,
		_route_target_ids,
		_run_state.get_skipped_boss_ids()
	))
	_route_aim_targets_cache.clear()
	var available_target_count := _available_route_target_ids.size()
	var display_index := 0
	for raw_index in range(_route_target_ids.size()):
		var target_id := _route_target_ids[raw_index]
		if not _available_route_target_ids.has(target_id):
			continue
		var node := _get_node(target_id)
		_route_aim_targets_cache.append({
			"id": target_id,
			"label": _route_target_display_label(node),
			"kind": str(node.get("kind", "")),
			"enraged": bool(node.get("enraged", false)),
			"position": _route_target_aim_position(display_index, available_target_count),
			"draw_radius": TowerAscentTuning.TEMP_ROUTE_TARGET_DRAW_RADIUS,
			"hit_radius": TowerAscentTuning.TEMP_ROUTE_TARGET_HIT_RADIUS,
			"map_position": _node_position(target_id),
		})
		display_index += 1

func _route_target_display_label(node: Dictionary) -> String:
	var kind := str(node.get("kind", ""))
	if kind in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS:
		return TowerAscentNodeModalLocalization.node_title(kind)
	return str(node.get("label", "행로"))

func _sync_run_state_phases() -> void:
	if _graph_nodes.is_empty():
		return
	if _graph_phases.is_empty() or _active_graph_phase_index >= _graph_phases.size():
		return
	var phase := _graph_phases[_active_graph_phase_index].duplicate(true)
	phase["nodes"] = _graph_nodes.duplicate(true)
	phase["edges"] = _graph_edges.duplicate(true)
	_graph_phases[_active_graph_phase_index] = phase
	_run_state.set_phases(_graph_phases)
	_run_state.set_active_phase_index(_active_graph_phase_index)

func _activate_graph_phase(phase_index: int, sync_current: bool = true) -> bool:
	if phase_index < 0 or phase_index >= _graph_phases.size():
		return false
	if sync_current and not _graph_nodes.is_empty():
		_sync_run_state_phases()
	var phase_variant: Variant = _graph_phases[phase_index]
	if not (phase_variant is Dictionary):
		return false
	var phase := phase_variant as Dictionary
	var nodes := _dictionary_array(phase.get("nodes", []))
	var edges := _dictionary_array(phase.get("edges", []))
	if nodes.is_empty():
		return false
	_active_graph_phase_index = phase_index
	_graph_nodes.assign(nodes)
	_graph_edges.assign(edges)
	_run_state.set_phases(_graph_phases)
	_run_state.set_active_phase_index(_active_graph_phase_index)
	return true
