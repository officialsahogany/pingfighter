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
	var map_seed := _find_seed_for_initial_kind(generator, true)
	_expect(map_seed >= 0, "test fixture must find an initial combat candidate row")
	if map_seed < 0:
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {"run_id": "avoid-boss", "map_seed": map_seed}), "boss avoidance flow must begin")
	var raw_targets: Array = flow.export_snapshot().route_target_ids
	var unchosen_node := _find_node(flow.get_graph_nodes(), str(raw_targets[1]))
	var skipped_slot_id := str(unchosen_node.get("boss_slot_id", ""))
	_expect(not skipped_slot_id.is_empty(), "unchosen combat candidate must expose its boss slot")
	flow.debug_advance_to_route_aim()
	flow.debug_launch_at_target(0)
	flow.update_selective(1.5)
	var snapshot: Dictionary = flow.export_snapshot()
	_expect(snapshot.run_progress.skipped_boss_ids == [skipped_slot_id], "unchosen boss slot must be committed to run progress")
	var skipped_graph_node := _find_node(snapshot.map_graph.phases[0].nodes, str(raw_targets[1]))
	_expect(bool(skipped_graph_node.get("route_disabled", false)), "avoided boss node must be disabled in the serialized graph")
	var restored := TowerAscentFlowOwner.new()
	_expect(restored.restore_snapshot(snapshot), "avoided boss graph must restore")
	_expect(restored.get_skipped_boss_ids() == [skipped_slot_id], "restored flow must preserve the avoided boss slot")
	_expect(not restored.get_route_target_ids().has(str(raw_targets[1])), "candidate presentation must filter the avoided boss")
	var regenerated := generator.generate_tower(map_seed, [skipped_slot_id])
	var regenerated_node := _find_node(regenerated.phases[0].nodes, str(raw_targets[1]))
	_expect(bool(regenerated_node.get("route_disabled", false)), "later deterministic generation must respect the avoided boss list")
	var policy := TowerAscentRouteCandidatePolicy.new()
	_expect(policy.filter_available(regenerated.phases[0].nodes, raw_targets, [skipped_slot_id]).size() == 1, "candidate policy must remove exactly the avoided boss")
	flow.update_selective(1.0)
	_expect(not flow.is_active(), "first route transition must finish before the next combat fixture")
	_expect(flow.begin_vertical_slice(null, Callable()), "the same run must be able to prepare its next generated route")
	_expect(flow.get_skipped_boss_ids() == [skipped_slot_id], "later combat preparation must not clear the run-owned avoided boss list")


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


func _find_node(nodes: Array, node_id: String) -> Dictionary:
	for node_variant in nodes:
		if node_variant is Dictionary and str((node_variant as Dictionary).get("id", "")) == node_id:
			return node_variant as Dictionary
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
