extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)
const TowerAscentRouteCandidatePolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_route_candidate_policy.gd"
)
const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	_verify_run_state_owns_avoided_bosses()
	_verify_unchosen_boss_is_persisted_and_filtered()
	_verify_noncombat_choice_does_not_invent_avoided_boss()
	_verify_flag_off_preserves_legacy()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_ascent_boss_avoidance_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_run_state_owns_avoided_bosses() -> void:
	var state := TowerAscentRunState.new()
	_expect(state.begin("avoidance-owner"), "run-state avoidance fixture must begin")
	_expect(state.mark_boss_skipped("floor_02_molewang"), "first avoided boss commit must succeed")
	_expect(not state.mark_boss_skipped("floor_02_molewang"), "duplicate avoided boss commit must be idempotent")
	state.set_phases([{"id": "phase_01", "nodes": [{}], "edges": []}])
	var snapshot := state.export_snapshot_fields()
	_expect(snapshot.run_progress.skipped_boss_ids == ["floor_02_molewang"], "avoided bosses must live in run-state snapshot progress")
	var restored := TowerAscentRunState.new()
	_expect(restored.restore_snapshot(snapshot), "run-state avoided boss snapshot must restore")
	_expect(restored.get_skipped_boss_ids() == ["floor_02_molewang"], "restored run state must retain avoided bosses")
	restored.reset()
	_expect(restored.get_skipped_boss_ids().is_empty(), "a new run reset must clear prior avoided bosses")


func _verify_unchosen_boss_is_persisted_and_filtered() -> void:
	var generator := TowerAscentMapGenerator.new()
	var map_seed := _find_seed_for_boss_choice(generator)
	_expect(map_seed >= 0, "test fixture must find a mixed NPC and boss choice")
	if map_seed < 0:
		return
	var graph: Dictionary = generator.generate_tower(map_seed)
	var choice_fixture := _find_boss_choice_fixture(graph)
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {"run_id": "avoid-boss", "map_seed": map_seed}), "boss avoidance flow must begin")
	var raw_targets: Array[String] = []
	raw_targets.assign(choice_fixture.get("target_ids", []))
	flow.set("_route_source_node_id", str(choice_fixture.get("source_id", "")))
	flow.set("_route_target_ids", raw_targets)
	flow.call("_refresh_route_target_cache")
	var unchosen_node := _find_node(flow.get_graph_nodes(), str(choice_fixture.get("boss_id", "")))
	var skipped_slot_id := str(unchosen_node.get("boss_slot_id", ""))
	_expect(not skipped_slot_id.is_empty(), "unchosen boss candidate must expose its boss slot")
	flow.call("_resolve_route_target", str(choice_fixture.get("chosen_id", "")))
	var snapshot: Dictionary = flow.export_snapshot()
	_expect(snapshot.run_progress.skipped_boss_ids == [skipped_slot_id], "unchosen boss slot must be committed to run progress")
	var skipped_graph_node := _find_node(snapshot.map_graph.phases[0].nodes, str(choice_fixture.get("boss_id", "")))
	_expect(bool(skipped_graph_node.get("route_disabled", false)), "avoided boss node must be disabled in the serialized graph")
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(snapshot), "avoided boss graph must restore")
	_expect(restored.get_skipped_boss_ids() == [skipped_slot_id], "restored flow must preserve the avoided boss slot")
	_expect(not restored.get_route_target_ids().has(str(choice_fixture.get("boss_id", ""))), "candidate presentation must filter the avoided boss")
	var regenerated := generator.generate_tower(map_seed, [skipped_slot_id])
	var regenerated_node := _find_node(regenerated.phases[0].nodes, str(choice_fixture.get("boss_id", "")))
	_expect(bool(regenerated_node.get("route_disabled", false)), "later deterministic generation must respect the avoided boss list")
	var policy := TowerAscentRouteCandidatePolicy.new()
	_expect(policy.filter_available(regenerated.phases[0].nodes, raw_targets, [skipped_slot_id]).size() == raw_targets.size() - 1, "candidate policy must remove exactly the avoided boss")


func _verify_noncombat_choice_does_not_invent_avoided_boss() -> void:
	var generator := TowerAscentMapGenerator.new()
	var map_seed := _find_seed_for_initial_kind(generator, false)
	_expect(map_seed >= 0, "test fixture must find an initial noncombat candidate row")
	if map_seed < 0:
		return
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {"run_id": "avoid-noncombat", "map_seed": map_seed}), "noncombat avoidance flow must begin")
	flow.debug_advance_to_route_aim()
	flow.debug_launch_at_target(0)
	flow.update_selective(1.5)
	_expect(flow.get_skipped_boss_ids().is_empty(), "passing a noncombat node must not create an avoided boss record")


func _verify_flag_off_preserves_legacy() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	_expect(not TowerAscentFlowOwner.new().begin_vertical_slice(null, Callable(), {"run_id": "avoidance-off"}), "flag OFF must bypass boss avoidance policy")


func _find_seed_for_initial_kind(generator: Object, combat: bool) -> int:
	for map_seed in range(0, 256):
		var graph: Dictionary = generator.generate_tower(map_seed)
		var phase: Dictionary = graph.phases[0]
		var target_id := str(phase.initial_route_candidate_ids[0])
		var node := _find_node(phase.nodes, target_id)
		var is_combat := str(node.get("kind", "")) in TowerAscentRouteCandidatePolicy.COMBAT_NODE_KINDS
		if is_combat == combat:
			return map_seed
	return -1


func _find_seed_for_boss_choice(generator: Object) -> int:
	for map_seed in range(0, 256):
		if not _find_boss_choice_fixture(generator.generate_tower(map_seed)).is_empty():
			return map_seed
	return -1


func _find_boss_choice_fixture(graph: Dictionary) -> Dictionary:
	for phase_value in graph.get("phases", []):
		if not (phase_value is Dictionary):
			continue
		var phase := phase_value as Dictionary
		var nodes_by_id: Dictionary = {}
		for node_value in phase.get("nodes", []):
			if node_value is Dictionary:
				var node := node_value as Dictionary
				nodes_by_id[str(node.get("id", ""))] = node
		var target_ids_by_source: Dictionary = {}
		for edge_value in phase.get("edges", []):
			if not (edge_value is Dictionary):
				continue
			var edge := edge_value as Dictionary
			var source_id := str(edge.get("from", ""))
			var target_ids: Array = target_ids_by_source.get(source_id, [])
			target_ids.append(str(edge.get("to", "")))
			target_ids_by_source[source_id] = target_ids
		for source_id in target_ids_by_source:
			var target_ids: Array = target_ids_by_source[source_id]
			if target_ids.size() != 2:
				continue
			var boss_id := ""
			var chosen_id := ""
			for target_id_value in target_ids:
				var target_id := str(target_id_value)
				var target: Dictionary = nodes_by_id.get(target_id, {})
				if (
					str(target.get("content_state", "")) == "generated"
					and str(target.get("kind", "")) in TowerAscentRouteCandidatePolicy.COMBAT_NODE_KINDS
					and not str(target.get("boss_slot_id", "")).is_empty()
				):
					boss_id = target_id
				else:
					chosen_id = target_id
			if not boss_id.is_empty() and not chosen_id.is_empty():
				return {
					"source_id": str(source_id),
					"target_ids": target_ids.duplicate(),
					"boss_id": boss_id,
					"chosen_id": chosen_id,
				}
	return {}


func _find_node(nodes: Array, node_id: String) -> Dictionary:
	for node_variant in nodes:
		if node_variant is Dictionary and str((node_variant as Dictionary).get("id", "")) == node_id:
			return node_variant as Dictionary
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
