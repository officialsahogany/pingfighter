extends "res://scripts/tower_ascent/tower_ascent_flow_ending_progress.gd"

func restore_snapshot(
	snapshot: Dictionary,
	finish_callback: Callable = Callable(),
	owner: Object = null,
	registry: Object = null,
	gauntlet_transition_callback: Callable = Callable()
) -> bool:
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return false
	if (
		TowerAscentRunState.snapshot_restore_policy(snapshot)
		!= TowerAscentRunState.SNAPSHOT_POLICY_CURRENT
	):
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
	if phases.size() != 2:
		return false
	_graph_phases.assign(phases.duplicate(true))
	if not _repair_restored_boss_node_identities(int(snapshot.get("map_seed", 0))):
		_reset_runtime_state()
		return false
	_active_graph_phase_index = _run_state.get_active_phase_index()
	if _active_graph_phase_index < 0 or _active_graph_phase_index >= phases.size():
		return false
	var graph: Dictionary = _graph_phases[_active_graph_phase_index]
	var nodes_variant: Variant = graph.get("nodes", [])
	var edges_variant: Variant = graph.get("edges", [])
	if not (nodes_variant is Array) or (nodes_variant as Array).size() < 4:
		return false
	if not (edges_variant is Array) or (edges_variant as Array).size() < 3:
		return false
	_map_seed = int(snapshot.get("map_seed", 0))
	_map_seed_available = true
	_header_subtitle = "생성 지도 검증판 · %s" % _run_state.get_run_id()
	_graph_nodes.assign((nodes_variant as Array).duplicate(true))
	_graph_edges.assign((edges_variant as Array).duplicate(true))
	_rebuild_graph_indices()
	_map_render_revision += 1
	_current_node_id = str(snapshot.get("current_node_id", ""))
	var restored_current_node := _get_node(_current_node_id)
	_run_state.reveal_floor(int(restored_current_node.get(
		"segment_floor",
		restored_current_node.get("floor", 0)
	)))
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
	_reward_pick_history.assign(_dictionary_array(snapshot.get("reward_pick_history", [])))
	_add_history_resolution_ids(_reward_pick_history)
	_victory_margin_reward_history.assign(_dictionary_array(
		snapshot.get("victory_margin_reward_history", [])
	))
	_add_history_resolution_ids(_victory_margin_reward_history)
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
	_training_timing_roll_count = maxi(0, int(snapshot.get(
		"training_timing_roll_count",
		0
	)))
	_route_history.assign(_dictionary_array(snapshot.get("route_history", [])))
	_route_source_node_id = str(snapshot.get("route_source_node_id", ""))
	_route_target_ids.assign(_string_array(snapshot.get("route_target_ids", [])))
	if _route_source_node_id.is_empty() or _route_target_ids.size() not in [1, 2]:
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
	_retained_noncombat_background_kind = _normalize_retained_noncombat_background_kind(
		str(snapshot.get("retained_noncombat_background_kind", ""))
	)
	if _phase == PHASE_MAP_TRANSITION:
		var reveal_target_node := _get_node(_selected_target_id)
		_floor_reveal_state.begin_if_needed(
			int(reveal_target_node.get(
				"segment_floor",
				reveal_target_node.get("floor", 0)
			)),
			_run_state.get_revealed_floor()
		)
		var selected_node := _get_node(_selected_target_id)
		var selected_kind := str(selected_node.get("kind", ""))
		if selected_kind in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS:
			if _retained_noncombat_background_kind.is_empty():
				var current_kind := str(_get_node(_current_node_id).get("kind", ""))
				_retain_noncombat_node_background(current_kind)
			_prewarm_noncombat_node_background(selected_kind)
		else:
			_clear_retained_noncombat_node_background()
	elif _phase == PHASE_NODE_MODAL:
		var current_node := _get_node(_current_node_id)
		var current_kind := str(current_node.get("kind", ""))
		if current_kind in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS:
			_retain_noncombat_node_background(current_kind)
			_prewarm_noncombat_node_background(current_kind)
	else:
		_clear_retained_noncombat_node_background()
	_selector_position = snapshot.get("selector_position", SELECTOR_ORIGIN)
	_selector_velocity = snapshot.get("selector_velocity", Vector2.ZERO)
	_selector_launched = bool(snapshot.get("selector_launched", false))
	_aim_target_x = clampf(float(snapshot.get("aim_target_x", 220.0)), SELECTOR_LEFT_WALL, SELECTOR_RIGHT_WALL)
	_map_transition_progress = clampf(float(snapshot.get("map_transition_progress", 0.0)), 0.0, 1.0)
	if _phase == PHASE_MAP_TRANSITION:
		_transition_fade_state.begin_map_transition()
		_transition_fade_state.set_map_transition_progress_for_qa(_map_transition_progress)
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
	_guardian_spring_node.sync_owner_projection(owner, _run_state, _active_registry)
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


func _repair_restored_boss_node_identities(map_seed: int) -> bool:
	var boss_registry := TowerAscentBossRegistry.new()
	for phase_index in range(_graph_phases.size()):
		var phase := _graph_phases[phase_index].duplicate(true)
		var nodes_variant: Variant = phase.get("nodes", [])
		if not (nodes_variant is Array):
			return false
		var nodes := nodes_variant as Array
		for node_index in range(nodes.size()):
			if not (nodes[node_index] is Dictionary):
				continue
			var node := nodes[node_index] as Dictionary
			if (
				str(node.get("kind", "")) not in TowerAscentBossRegistry.COMBAT_NODE_KINDS
				or (
					str(node.get("content_state", "")) == TowerAscentBossRegistry.CONTENT_REGISTRY_ONLY
					and not bool(node.get("gatekeeper", false))
				)
				or (not node.has("boss_slot_id") and not bool(node.get("gatekeeper", false)))
				or node.has("boss_sequence_slot_ids")
			):
				continue
			var repair := boss_registry.repair_boss_node_identity(node)
			if not bool(repair.get("valid", false)):
				if bool(node.get("gatekeeper", false)):
					var reseed := boss_registry.reseed_gatekeeper_boss_node_identity(
						node,
						map_seed
					)
					if bool(reseed.get("valid", false)):
						nodes[node_index] = reseed.get("node", node)
						push_warning(
							"[TowerAscent] snapshot gatekeeper identity reseeded node=%s slot=%s"
							% [
								str(node.get("id", "")),
								str((nodes[node_index] as Dictionary).get("boss_slot_id", "")),
							]
						)
						continue
					var npc_gate := _convert_unresolved_snapshot_gatekeeper_to_npc(node)
					nodes[node_index] = npc_gate
					push_warning(
						"[TowerAscent] snapshot gatekeeper converted to NPC node=%s floor=%d"
						% [
							str(node.get("id", "")),
							int(node.get("segment_floor", node.get("floor", 0))),
						]
					)
					continue
				var downgraded := _downgrade_unresolved_snapshot_boss_node(node)
				nodes[node_index] = downgraded
				push_warning(
					"[TowerAscent] snapshot boss identity downgraded node=%s slot=%s"
					% [
						str(node.get("id", "")),
						str(node.get("boss_slot_id", "")),
					]
				)
				continue
			if bool(repair.get("changed", false)):
				push_warning(
					"[TowerAscent] snapshot boss identity repaired node=%s slot=%s"
					% [
						str(node.get("id", "")),
						str(node.get("boss_slot_id", "")),
					]
				)
				nodes[node_index] = repair.get("node", node)
		phase["nodes"] = nodes
		_graph_phases[phase_index] = phase
	return _run_state.set_phases(_graph_phases)


func _downgrade_unresolved_snapshot_boss_node(node: Dictionary) -> Dictionary:
	var downgraded := node.duplicate(true)
	downgraded["content_state"] = TowerAscentBossRegistry.CONTENT_REGISTRY_ONLY
	downgraded["boss_assignment_state"] = "snapshot_identity_unresolved"
	downgraded["route_disabled"] = true
	downgraded.erase("skipped")
	downgraded.erase("standin")
	downgraded.erase("boss_encounter_key")
	downgraded.erase("map_icon_boss_id")
	return downgraded


func _convert_unresolved_snapshot_gatekeeper_to_npc(node: Dictionary) -> Dictionary:
	var converted := node.duplicate(true)
	for metadata_key in [
		"boss_slot_id",
		"boss_pool_slot_ids",
		"boss_port_status",
		"boss_encounter_key",
		"standin",
		"standin_duplicate_gate",
		"encounter_locked",
		"map_icon_boss_id",
		"route_disabled",
		"skipped",
	]:
		converted.erase(metadata_key)
	converted["kind"] = "rest"
	converted["label"] = "휴식"
	converted["content_state"] = TowerAscentBossRegistry.CONTENT_GENERATED
	converted["boss_assignment_state"] = "snapshot_gatekeeper_npc_fallback"
	return converted

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
		"reward_pick_history": _reward_pick_history.duplicate(true),
		"victory_margin_reward_history": _victory_margin_reward_history.duplicate(true),
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
		"training_timing_roll_count": _training_timing_roll_count,
		"route_history": _route_history.duplicate(true),
		"route_source_node_id": _route_source_node_id,
		"route_target_ids": _route_target_ids.duplicate(),
		"selected_target_id": _selected_target_id,
		"node_modal_kind": _node_modal_kind,
		"retained_noncombat_background_kind": _retained_noncombat_background_kind,
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
