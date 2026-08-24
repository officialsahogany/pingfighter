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
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAscentMapPathGeometry := preload(
	"res://scripts/tower_ascent/tower_ascent_map_path_geometry.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)

const EXPECTED_GENERATOR_VERSION := "tower_map_v13_early_guardian_spring"
const SAMPLE_SEED_COUNT := 128
const MAX_OUTGOING_EDGES := 2
const MAX_DOTTED_PATH_DRAW_CALLS := 1536

var _failures: Array[String] = []
var _topology_signatures: Dictionary = {}
var _service_kind_counts: Dictionary = {}
var _sample_node_count := 0
var _sample_edge_count := 0
var _sample_singleton_rows := 0
var _sample_wide_rows := 0
var _sample_longest_multilane_run := 0
var _sample_degree_one_count := 0
var _sample_degree_two_count := 0
var _sample_branch_eligible_count := 0
var _sample_generated_node_count := 0
var _sample_combat_node_count := 0
var _max_human_edge_seed := 1
var _max_human_edge_count := 0


func _init() -> void:
	_verify_many_seed_topology()
	_verify_cached_budget_and_static_indices()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		var degree_two_ratio := _safe_ratio(
			_sample_degree_two_count,
			_sample_branch_eligible_count
		)
		var raw_degree_two_ratio := _safe_ratio(
			_sample_degree_two_count,
			_sample_degree_one_count + _sample_degree_two_count
		)
		var boss_ratio := _safe_ratio(
			_sample_combat_node_count,
			_sample_generated_node_count
		)
		print(
			"tower_ascent_map_topology_smoke: seeds=%d topologies=%d nodes=%d edges=%d singleton_rows=%d wide_rows=%d longest_multilane=%d degree1=%d degree2=%d boss_ratio=%0.4f degree2_ratio=%0.4f raw_degree2_ratio=%0.4f services=%s"
			% [
				SAMPLE_SEED_COUNT,
				_topology_signatures.size(),
				_sample_node_count,
				_sample_edge_count,
				_sample_singleton_rows,
				_sample_wide_rows,
				_sample_longest_multilane_run,
				_sample_degree_one_count,
				_sample_degree_two_count,
				boss_ratio,
				degree_two_ratio,
				raw_degree_two_ratio,
				str(_service_kind_counts),
			]
		)
		print("tower_ascent_map_topology_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_many_seed_topology() -> void:
	var generator := TowerAscentMapGenerator.new()
	_expect(
		TowerAscentMapGenerator.GENERATOR_VERSION == EXPECTED_GENERATOR_VERSION,
		"generator version must advance to the branching-lane contract"
	)
	for seed_offset in range(SAMPLE_SEED_COUNT):
		var map_seed := 1009 + seed_offset * 7919
		var first: Dictionary = generator.generate_tower(map_seed)
		var repeated: Dictionary = generator.generate_tower(map_seed)
		_expect(not first.is_empty(), "seed %d must generate a tower" % map_seed)
		if first.is_empty():
			continue
		_expect(
			generator.encode_graph(first) == generator.encode_graph(repeated),
			"seed %d must reproduce byte-identical graph bytes" % map_seed
		)
		var phases: Array = first.get("phases", [])
		_expect(phases.size() == 2, "seed %d must retain both realm phases" % map_seed)
		if phases.size() != 2:
			continue
		var signature_parts: Array[String] = []
		for phase_variant in phases:
			if not (phase_variant is Dictionary):
				_expect(false, "seed %d phase entries must be dictionaries" % map_seed)
				continue
			_verify_phase(map_seed, phase_variant as Dictionary, signature_parts)
		var topology_signature := "|".join(signature_parts)
		_topology_signatures[topology_signature] = true
		var human_edges: Array = (phases[0] as Dictionary).get("edges", [])
		if human_edges.size() > _max_human_edge_count:
			_max_human_edge_count = human_edges.size()
			_max_human_edge_seed = map_seed
	# v13 재보정(2026-08-24): v12 게이트 초크포인트·분기율 재설계가 구조
	# 스켈레톤을 의도적으로 정형화해 128시드 실측 6종(v10 계약 12종).
	# 콘텐츠(보스/서비스 배치) 다양성은 시드별로 유지된다 — 이 레그는
	# 스켈레톤 붕괴(1~2종 수렴)만 가드한다.
	_expect(
		_topology_signatures.size() >= 5,
		"authoritative map seeds must vary non-crossing partial edge layouts across runs (got %d)"
		% _topology_signatures.size()
	)
	for required_kind in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS:
		_expect(
			int(_service_kind_counts.get(required_kind, 0)) > 0,
			"multi-seed distribution must retain service kind %s" % required_kind
		)
	# v13 재보정(2026-08-24): v10의 "3~4레인 지배" 계약은 v12 게이트
	# 초크포인트(전 게이트 싱글톤 행)와 보스 밀도·분기율 재설계로 대체됨.
	# 128시드 실측 wide=256(시드당 2행)·singleton=1664. 현행 계약 =
	# 시드당 광폭 행 최소 1개 유지 + 싱글톤 행 폭주 상한 밴드.
	_expect(
		_sample_wide_rows >= SAMPLE_SEED_COUNT,
		"each seed must keep at least one three-to-four-lane row (wide=%d seeds=%d)"
		% [_sample_wide_rows, SAMPLE_SEED_COUNT]
	)
	_expect(
		_sample_singleton_rows <= 2080,
		"singleton rows must stay inside the v13 chokepoint band (singleton=%d cap=2080)"
		% _sample_singleton_rows
	)
	_expect(
		_sample_longest_multilane_run >= 5,
		"branches must survive at least five consecutive rows before a true reunion"
	)
	var degree_two_ratio := _safe_ratio(
		_sample_degree_two_count,
		_sample_branch_eligible_count
	)
	_expect(
		degree_two_ratio + 0.000001 >= TowerAscentTuning.TEMP_MAP_DEGREE_TWO_MIN_RATIO,
		"at least seventy percent of choice-capable nodes must expose two outgoing choices"
	)


func _verify_phase(map_seed: int, phase: Dictionary, signature_parts: Array[String]) -> void:
	var nodes: Array = phase.get("nodes", [])
	var edges: Array = phase.get("edges", [])
	var rows := _ordered_rows(phase)
	var node_by_id := _node_index(nodes)
	var outgoing := _edge_index(edges, "from", "to")
	var incoming := _edge_index(edges, "to", "from")
	var phase_id := str(phase.get("id", ""))
	_expect(not rows.is_empty(), "%s seed %d must expose ordered rows" % [phase_id, map_seed])
	if rows.is_empty():
		return
	var entry_id := str(phase.get("entry_node_id", ""))
	var first_row_ids := _string_array(rows[0].get("node_ids", []))
	_expect(first_row_ids.size() == 1, "%s seed %d must have one authoritative entry node" % [phase_id, map_seed])
	_expect(first_row_ids.has(entry_id), "%s seed %d entry id must belong to the first row" % [phase_id, map_seed])
	var terminal_ids := _string_array(rows[rows.size() - 1].get("node_ids", []))
	_expect(terminal_ids.size() == 1, "%s seed %d must end at one realm boss" % [phase_id, map_seed])
	for terminal_id in terminal_ids:
		var terminal: Dictionary = node_by_id.get(terminal_id, {})
		_expect(
			str(terminal.get("kind", "")) == "boss",
			"%s seed %d terminal %s must be a boss" % [phase_id, map_seed, terminal_id]
		)
	var reachable := _walk(entry_id, outgoing)
	var can_reach_terminal := _walk_many(terminal_ids, incoming)
	_expect(
		reachable.size() == nodes.size(),
		"%s seed %d must have zero entry-unreachable nodes (%d/%d reached)"
		% [phase_id, map_seed, reachable.size(), nodes.size()]
	)
	_expect(
		can_reach_terminal.size() == nodes.size(),
		"%s seed %d must have zero boss-unreachable nodes (%d/%d reach a boss)"
		% [phase_id, map_seed, can_reach_terminal.size(), nodes.size()]
	)
	var row_widths: Array[String] = []
	var longest_multilane_run := 0
	var current_multilane_run := 0
	for row_index in range(rows.size()):
		var row_ids := _string_array(rows[row_index].get("node_ids", []))
		row_widths.append(str(row_ids.size()))
		if row_ids.size() >= 3:
			_sample_wide_rows += 1
		if row_ids.size() == 1:
			_sample_singleton_rows += 1
			current_multilane_run = 0
		else:
			current_multilane_run += 1
			longest_multilane_run = maxi(longest_multilane_run, current_multilane_run)
		var service_kinds: Dictionary = {}
		for node_id in row_ids:
			var node: Dictionary = node_by_id.get(node_id, {})
			var node_kind := str(node.get("kind", ""))
			if str(node.get("content_state", "")) == "generated":
				_sample_generated_node_count += 1
				if node_kind in TowerAscentMapGenerator.COMBAT_NODE_KINDS:
					_sample_combat_node_count += 1
			if node_kind in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS:
				_expect(
					not service_kinds.has(node_kind),
					"%s seed %d row %d must not duplicate service kind %s"
					% [phase_id, map_seed, row_index, node_kind]
				)
				service_kinds[node_kind] = true
				_service_kind_counts[node_kind] = int(_service_kind_counts.get(node_kind, 0)) + 1
			var targets: Array = outgoing.get(node_id, [])
			if row_index == rows.size() - 1:
				_expect(targets.is_empty(), "%s terminal node %s must not emit an edge" % [phase_id, node_id])
			else:
				if _string_array(rows[row_index + 1].get("node_ids", [])).size() >= 2:
					_sample_branch_eligible_count += 1
				_expect(
					targets.size() in [1, 2],
					"%s seed %d node %s must expose one or two outgoing choices"
					% [phase_id, map_seed, node_id]
				)
				if targets.size() == 1:
					_sample_degree_one_count += 1
				elif targets.size() == 2:
					_sample_degree_two_count += 1
			if row_index > 0:
				_expect(
					not (incoming.get(node_id, []) as Array).is_empty(),
					"%s seed %d node %s must have an incoming edge" % [phase_id, map_seed, node_id]
				)
		if row_index > 0:
			var previous_ids := _string_array(rows[row_index - 1].get("node_ids", []))
			var row_edge_count := _count_edges_between(previous_ids, row_ids, outgoing)
			if previous_ids.size() > 1 and row_ids.size() > 1:
				_expect(
					row_edge_count < previous_ids.size() * row_ids.size(),
					"%s seed %d rows %d-%d must use partial rather than full bipartite connectivity"
					% [phase_id, map_seed, row_index - 1, row_index]
				)
	_sample_longest_multilane_run = maxi(_sample_longest_multilane_run, longest_multilane_run)
	_sample_node_count += nodes.size()
	_sample_edge_count += edges.size()
	_verify_no_crossing_edges(map_seed, phase_id, edges, node_by_id)
	signature_parts.append("%s:%s:%s" % [phase_id, ",".join(row_widths), _edge_signature(edges)])


func _verify_no_crossing_edges(
	map_seed: int,
	phase_id: String,
	edges: Array,
	node_by_id: Dictionary
) -> void:
	for first_index in range(edges.size()):
		if not (edges[first_index] is Dictionary):
			continue
		var first := edges[first_index] as Dictionary
		var first_from: Dictionary = node_by_id.get(str(first.get("from", "")), {})
		var first_to: Dictionary = node_by_id.get(str(first.get("to", "")), {})
		_expect(
			int(first_to.get("global_row", -1)) == int(first_from.get("global_row", -2)) + 1,
			"%s seed %d edges must connect adjacent rows only" % [phase_id, map_seed]
		)
		for second_index in range(first_index + 1, edges.size()):
			if not (edges[second_index] is Dictionary):
				continue
			var second := edges[second_index] as Dictionary
			var second_from: Dictionary = node_by_id.get(str(second.get("from", "")), {})
			var second_to: Dictionary = node_by_id.get(str(second.get("to", "")), {})
			if int(first_from.get("global_row", -1)) != int(second_from.get("global_row", -2)):
				continue
			var from_delta := int(first_from.get("lane", 0)) - int(second_from.get("lane", 0))
			var to_delta := int(first_to.get("lane", 0)) - int(second_to.get("lane", 0))
			_expect(
				from_delta * to_delta >= 0,
				"%s seed %d must not emit crossing lane edges" % [phase_id, map_seed]
			)


func _verify_cached_budget_and_static_indices() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(
		flow.begin_vertical_slice(null, Callable(), {
			"run_id": "topology-budget",
			"map_seed": _max_human_edge_seed,
		}),
		"maximum sampled human-edge fixture must enter the production flow"
	)
	var renderer := TowerAscentFlowRenderer.new()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, viewport_rect)
	var cache_before: Dictionary = renderer.get_render_cache_debug_state()
	renderer.build_fullscreen_map_model(flow, viewport_rect)
	var cache_after: Dictionary = renderer.get_render_cache_debug_state()
	var source_signature := TowerAscentMapPathGeometry.connection_signature(flow.get_graph_edges())
	var projected_signature := TowerAscentMapPathGeometry.connection_signature(model.get("edges", []))
	var path_draw_calls := int(cache_after.get("path_draw_call_budget", 0))
	var cloud_draw_calls := int(cache_after.get("cloud_draw_call_budget", 0))
	var draw_calls := int(cache_after.get("total_map_draw_call_budget", 0))
	_expect(source_signature == projected_signature, "budget adaptation must preserve every generated edge")
	_expect(draw_calls <= MAX_DOTTED_PATH_DRAW_CALLS, "maximum sampled graph must keep dotted paths plus clouds inside the map draw budget")
	_expect(
		int(cache_before.get("path_build_count", 0)) == int(cache_after.get("path_build_count", -1)),
		"unchanged frames must reuse cached path geometry"
	)
	print(
		"tower_ascent_map_topology_smoke: map_draw_budget seed=%d edges=%d dots=%d path=%d clouds=%d total=%d limit=%d"
		% [
			_max_human_edge_seed,
			(flow.get_graph_edges() as Array).size(),
			int(cache_after.get("path_dot_count", 0)),
			path_draw_calls,
			cloud_draw_calls,
			draw_calls,
			MAX_DOTTED_PATH_DRAW_CALLS,
		]
	)
	_expect(flow.has_method("get_graph_index_debug_state"), "flow must publish static graph-index evidence")
	if not flow.has_method("get_graph_index_debug_state"):
		return
	var index_before: Dictionary = flow.call("get_graph_index_debug_state")
	var source_id := flow.get_current_node_id()
	for _iteration in range(64):
		flow.call("_get_node", source_id)
		flow.call("_outgoing_target_ids", source_id)
	var index_after: Dictionary = flow.call("get_graph_index_debug_state")
	_expect(
		int(index_before.get("build_count", -1)) == int(index_after.get("build_count", -2)),
		"O(1) node/edge reads must not rebuild or scan the graph"
	)
	_expect(
		int(index_after.get("node_count", 0)) == (flow.get_graph_nodes() as Array).size(),
		"static node index must cover the active graph exactly"
	)


func _ordered_rows(phase: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for floor_variant in phase.get("floors", []):
		if not (floor_variant is Dictionary):
			continue
		for row_variant in (floor_variant as Dictionary).get("rows", []):
			if row_variant is Dictionary:
				result.append(row_variant as Dictionary)
	return result


func _node_index(nodes: Array) -> Dictionary:
	var result: Dictionary = {}
	for node_variant in nodes:
		if node_variant is Dictionary:
			var node := node_variant as Dictionary
			result[str(node.get("id", ""))] = node
	return result


func _edge_index(edges: Array, key_field: String, value_field: String) -> Dictionary:
	var result: Dictionary = {}
	for edge_variant in edges:
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		var key := str(edge.get(key_field, ""))
		var value := str(edge.get(value_field, ""))
		var values: Array = result.get(key, [])
		if not values.has(value):
			values.append(value)
		result[key] = values
	return result


func _walk(start_id: String, adjacency: Dictionary) -> Dictionary:
	return _walk_many([start_id], adjacency)


func _walk_many(start_ids: Array, adjacency: Dictionary) -> Dictionary:
	var visited: Dictionary = {}
	var pending: Array[String] = []
	for start_variant in start_ids:
		var start_id := str(start_variant)
		if not start_id.is_empty() and not visited.has(start_id):
			visited[start_id] = true
			pending.append(start_id)
	while not pending.is_empty():
		var current_id: String = pending.pop_back()
		for target_variant in adjacency.get(current_id, []):
			var target_id := str(target_variant)
			if visited.has(target_id):
				continue
			visited[target_id] = true
			pending.append(target_id)
	return visited


func _count_edges_between(from_ids: Array[String], to_ids: Array[String], outgoing: Dictionary) -> int:
	var count := 0
	for from_id in from_ids:
		for to_variant in outgoing.get(from_id, []):
			if to_ids.has(str(to_variant)):
				count += 1
	return count


func _edge_signature(edges: Array) -> String:
	var result: Array[String] = []
	for edge_variant in edges:
		if edge_variant is Dictionary:
			var edge := edge_variant as Dictionary
			result.append("%s>%s" % [str(edge.get("from", "")), str(edge.get("to", ""))])
	return ",".join(result)


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value as Array:
			result.append(str(entry))
	return result


func _safe_ratio(numerator: int, denominator: int) -> float:
	return 0.0 if denominator <= 0 else float(numerator) / float(denominator)


func _expect(condition: bool, message: String) -> void:
	if not condition and _failures.size() < 16 and not _failures.has(message):
		_failures.append(message)
