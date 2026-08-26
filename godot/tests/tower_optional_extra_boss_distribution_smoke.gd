extends SceneTree

const TowerAscentBossRegistry := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd"
)
const TowerAscentMapCloudLayer := preload(
	"res://scripts/tower_ascent/tower_ascent_map_cloud_layer.gd"
)
const TowerAscentMapPathGeometry := preload(
	"res://scripts/tower_ascent/tower_ascent_map_path_geometry.gd"
)
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)
const TowerAscentMapIconography := preload(
	"res://scripts/tower_ascent/tower_ascent_map_iconography.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAuditionBuildConfig := preload(
	"res://scripts/tower_ascent/tower_audition_build_config.gd"
)

const SAMPLE_SEED_COUNT := 256
const SAMPLE_SEED_START := 1009
const SAMPLE_SEED_STEP := 7919
const EXPECTED_GENERATOR_VERSION := "tower_map_v15_upper_floor_density"
const MAP_DRAW_CALL_LIMIT := 1536
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
const MAP_SCROLL_TILE_SIZE := Vector2(692.0, 320.0)
const MAP_SCROLL_ROW_PITCH := 160.0
const MAP_SCROLL_NODE_ART_SIZE := 32.0
const MAP_SCROLL_ROUTE_ENDPOINT_CLEARANCE_RATIO := 0.42

var _failures: Array[String] = []
var _spawns_by_floor: Dictionary = {}
var _encounter_histograms_by_floor: Dictionary = {}
var _minimum_bosses_by_floor: Dictionary = {}
var _maximum_bosses_by_floor: Dictionary = {}
var _generation_attempt_histogram: Dictionary = {}
var _generation_failure_count := 0
var _total_spawns := 0
var _unique_pool_exhausted_skips := 0
var _no_bypass_candidate_skips := 0
var _maximum_optional_bosses_in_one_floor := 0
var _maximum_boss_ratio := 0.0
var _minimum_npc_per_boss_ratio := INF
var _maximum_draw_calls := 0
var _maximum_draw_seed := 0
var _maximum_path_draw_calls := 0
var _maximum_cloud_draw_calls := 0
var _forced_fixture: Dictionary = {}
var _negative_leg_count := 0
var _row_cap_checks := 0


func _init() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(false)
	_verify_distribution()
	_verify_audition_scope_contract()
	_verify_forced_passage_negative_leg()
	TowerAuditionBuildConfig.debug_clear_enabled_override()
	if _failures.is_empty():
		print(
			"tower_optional_extra_boss_distribution_smoke: seeds=%d floor_boss_ranges=%s optional_spawns=%s encounter_histograms=%s attempts=%s generation_failures=%d"
			% [
				SAMPLE_SEED_COUNT,
				str(_floor_boss_ranges()),
				str(_spawns_by_floor),
				str(_encounter_histograms_by_floor),
				str(_generation_attempt_histogram),
				_generation_failure_count,
			]
		)
		print(
			"tower_optional_extra_boss_distribution_smoke: spawned=%d unique_pool_exhausted_skips=%d no_bypass_candidate_skips=%d max_per_floor=%d row_cap_checks=%d max_boss_ratio=%0.6f min_npc_per_boss=%0.6f worst_draw_seed=%d path_draw_calls=%d cloud_draw_calls=%d total_draw_calls=%d headroom=%d negative_legs=%d"
			% [
				_total_spawns,
				_unique_pool_exhausted_skips,
				_no_bypass_candidate_skips,
				_maximum_optional_bosses_in_one_floor,
				_row_cap_checks,
				_maximum_boss_ratio,
				_minimum_npc_per_boss_ratio,
				_maximum_draw_seed,
				_maximum_path_draw_calls,
				_maximum_cloud_draw_calls,
				_maximum_draw_calls,
				MAP_DRAW_CALL_LIMIT - _maximum_draw_calls,
				_negative_leg_count,
			]
		)
		print("tower_optional_extra_boss_distribution_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_distribution() -> void:
	var generator := TowerAscentMapGenerator.new()
	var registry := TowerAscentBossRegistry.new()
	var active_clear_floor := TowerAuditionBuildConfig.get_clear_floor()
	_expect(
		TowerAscentMapGenerator.GENERATOR_VERSION == EXPECTED_GENERATOR_VERSION,
		"generator version must advance to the optional extra-boss contract"
	)
	_expect(
		active_clear_floor == TowerAuditionBuildConfig.STANDARD_CLEAR_FLOOR,
		"distribution seal must run against the standard tower"
	)
	for floor_number in range(
		TowerAscentBossRegistry.TEMP_OPTIONAL_EXTRA_BOSS_FLOOR_MIN,
		active_clear_floor
	):
		_spawns_by_floor[floor_number] = 0
		_encounter_histograms_by_floor[floor_number] = {1: 0, 3: 0}
		_minimum_bosses_by_floor[floor_number] = 999
		_maximum_bosses_by_floor[floor_number] = 0
	for seed_offset in range(SAMPLE_SEED_COUNT):
		var map_seed := SAMPLE_SEED_START + seed_offset * SAMPLE_SEED_STEP
		var graph: Dictionary = generator.generate_tower(map_seed)
		var repeated: Dictionary = generator.generate_tower(map_seed)
		_expect(not graph.is_empty(), "seed %d must generate a tower" % map_seed)
		if graph.is_empty():
			_generation_failure_count += 1
			continue
		var generation_attempt := int(graph.get("generation_attempt", -1))
		_generation_attempt_histogram[generation_attempt] = int(
			_generation_attempt_histogram.get(generation_attempt, 0)
		) + 1
		_expect(
			generator.encode_graph(graph) == generator.encode_graph(repeated),
			"seed %d must remain byte deterministic" % map_seed
		)
		if _forced_fixture.is_empty():
			_forced_fixture = graph.duplicate(true)
		var distribution_variant: Variant = graph.get(
			TowerAscentBossRegistry.OPTIONAL_EXTRA_BOSS_DISTRIBUTION_KEY,
			{}
		)
		_expect(
			distribution_variant is Dictionary,
			"seed %d must publish optional extra-boss distribution evidence" % map_seed
		)
		if not (distribution_variant is Dictionary):
			continue
		var distribution := distribution_variant as Dictionary
		_expect(
			str(distribution.get("assignment_mode", "")) == "pool_driven",
			"seed %d optional bosses must be induced by the live unique pool" % map_seed
		)
		_expect(
			int(distribution.get("floor_min", -1))
				== TowerAscentBossRegistry.TEMP_OPTIONAL_EXTRA_BOSS_FLOOR_MIN,
			"seed %d must preserve the floor-2 lower bound" % map_seed
		)
		_expect(
			int(distribution.get("floor_max", -1)) == active_clear_floor - 1,
			"seed %d must derive the upper bound from the terminal floor" % map_seed
		)
		var floor_reports: Dictionary = distribution.get("floor_reports", {})
		var graph_optional_count := 0
		for floor_number in range(
			TowerAscentBossRegistry.TEMP_OPTIONAL_EXTRA_BOSS_FLOOR_MIN,
			active_clear_floor
		):
			var floor_report: Dictionary = floor_reports.get(floor_number, {})
			_expect(
				not floor_report.is_empty(),
				"seed %d floor %d must publish a pool report" % [map_seed, floor_number]
			)
			var optional_nodes := _optional_nodes_for_floor(graph, floor_number)
			var optional_count := optional_nodes.size()
			var expected_optional_count := 2 if floor_number in [2, 3] else 0
			graph_optional_count += optional_count
			_maximum_optional_bosses_in_one_floor = maxi(
				_maximum_optional_bosses_in_one_floor,
				optional_count
			)
			_expect(
				optional_count <= TowerAscentBossRegistry.TEMP_OPTIONAL_EXTRA_BOSS_MAX_PER_FLOOR,
				"seed %d floor %d must add at most two optional bosses"
				% [map_seed, floor_number]
			)
			_expect(
				optional_count == expected_optional_count,
				"seed %d floor %d must add exactly %d pool-driven optional bosses"
				% [map_seed, floor_number, expected_optional_count]
			)
			_expect(
				int(floor_report.get("spawned_count", -1)) == optional_count,
				"seed %d floor %d report and graph spawn counts must agree"
				% [map_seed, floor_number]
			)
			_spawns_by_floor[floor_number] = int(
				_spawns_by_floor.get(floor_number, 0)
			) + optional_count
			var encounter_count := 1 + optional_count
			_minimum_bosses_by_floor[floor_number] = mini(
				int(_minimum_bosses_by_floor.get(floor_number, encounter_count)),
				encounter_count
			)
			_maximum_bosses_by_floor[floor_number] = maxi(
				int(_maximum_bosses_by_floor.get(floor_number, encounter_count)),
				encounter_count
			)
			var floor_histogram: Dictionary = _encounter_histograms_by_floor[floor_number]
			floor_histogram[encounter_count] = int(
				floor_histogram.get(encounter_count, 0)
			) + 1
			_encounter_histograms_by_floor[floor_number] = floor_histogram
			for optional_node in optional_nodes:
				_verify_optional_node(
					map_seed,
					floor_number,
					optional_node,
					graph,
					registry
				)
			_verify_optional_row_cap(map_seed, floor_number, optional_nodes)
		_total_spawns += graph_optional_count
		_expect(
			_count_optional_nodes_for_floor(graph, 1) == 0,
			"seed %d must leave the entire first-floor structure unchanged" % map_seed
		)
		_expect(
			_count_optional_nodes_for_floor(graph, active_clear_floor) == 0,
			"seed %d must not touch the terminal floor" % map_seed
		)
		_expect(
			_count_floor_one_generated_bosses(graph) == 3,
			"seed %d must retain the full three-boss first-floor roster" % map_seed
		)
		var bypass_report := registry.analyze_optional_extra_boss_bypass(
			graph,
			active_clear_floor
		)
		_expect(
			bool(bypass_report.get("valid", false)),
			"seed %d every optional boss must have an entry-to-terminal bypass: %s"
			% [map_seed, str(bypass_report.get("issues", []))]
		)
		_expect(
			int(bypass_report.get("optional_node_count", -1)) == graph_optional_count,
			"seed %d bypass analyzer must inspect every optional boss" % map_seed
		)
		_expect(
			int(bypass_report.get("simultaneous_floor_count", -1)) == 2,
			"seed %d bypass analyzer must verify both two-boss floors simultaneously"
			% map_seed
		)
		var uniqueness_report := registry.analyze_visible_boss_contract(
			graph,
			active_clear_floor
		)
		_expect(
			bool(uniqueness_report.get("valid", false)),
			"seed %d canonical encounter keys must remain unique: %s"
			% [map_seed, str(uniqueness_report.get("issues", []))]
		)
		_verify_explicit_canonical_uniqueness(map_seed, graph, registry)
		var integrity := generator.analyze_graph_integrity(graph, true, true)
		_expect(
			bool(integrity.get("valid", false)),
			"seed %d distribution integrity must remain GREEN: %s"
			% [map_seed, str(integrity.get("issues", []))]
		)
		var boss_count := int(integrity.get("combat_node_count", 0))
		var npc_count := int(integrity.get("npc_node_count", 0))
		var boss_ratio := float(integrity.get("boss_ratio", 0.0))
		var npc_per_boss := _safe_ratio(npc_count, boss_count)
		_maximum_boss_ratio = maxf(_maximum_boss_ratio, boss_ratio)
		_minimum_npc_per_boss_ratio = minf(_minimum_npc_per_boss_ratio, npc_per_boss)
		_expect(
			boss_ratio <= TowerAscentTuning.TEMP_GENERATED_BOSS_NODE_MAX_RATIO + 0.000001,
			"seed %d recalibrated boss ratio must remain within its ceiling" % map_seed
		)
		_expect(
			npc_per_boss + 0.000001 >= TowerAscentTuning.TEMP_GENERATED_NPC_PER_BOSS_MIN,
			"seed %d recalibrated NPC:boss ratio must remain within its floor" % map_seed
		)
		_unique_pool_exhausted_skips += int(
			distribution.get("unique_pool_exhausted_skip_count", 0)
		)
		_no_bypass_candidate_skips += int(
			distribution.get("no_bypass_candidate_skip_count", 0)
		)
		_verify_fit_all_budget(map_seed, graph)
	_expect(_generation_failure_count == 0, "256 seeds must generate without an empty graph")
	_expect(
		_total_spawns == SAMPLE_SEED_COUNT * 4,
		"256 seeds must add exactly two bosses on each of floors 2 and 3"
	)
	_expect(
		_no_bypass_candidate_skips == 0,
		"all current wide-row candidates must retain a bypass"
	)
	for floor_number in range(
		TowerAscentBossRegistry.TEMP_OPTIONAL_EXTRA_BOSS_FLOOR_MIN,
		active_clear_floor
	):
		var spawned_count := int(_spawns_by_floor.get(floor_number, 0))
		if floor_number in [2, 3]:
			_expect(
				spawned_count == SAMPLE_SEED_COUNT * 2,
				"floor %d must realize both unused canonical slots for every seed"
				% floor_number
			)
		else:
			_expect(
				spawned_count == 0,
				"floor %d shell pool is canonically exhausted and must skip safely"
				% floor_number
			)
		var expected_boss_count := 3 if floor_number in [2, 3] else 1
		_expect(
			int(_minimum_bosses_by_floor.get(floor_number, -1)) == expected_boss_count
			and int(_maximum_bosses_by_floor.get(floor_number, -1)) == expected_boss_count,
			"floor %d total boss count must be seed-invariant at %d"
			% [floor_number, expected_boss_count]
		)


func _verify_audition_scope_contract() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(true)
	var graph := TowerAscentMapGenerator.new().generate_tower(83521)
	_expect(not graph.is_empty(), "audition topology must continue generating")
	if not graph.is_empty():
		var distribution: Dictionary = graph.get(
			TowerAscentBossRegistry.OPTIONAL_EXTRA_BOSS_DISTRIBUTION_KEY,
			{}
		)
		_expect(
			str(distribution.get("scope_status", "")) == "audition_topology_excluded",
			"the one-row audition topology must explicitly retain its prior boss scope"
		)
		_expect(
			int(distribution.get("spawned_count", -1)) == 0,
			"audition topology must not exceed its existing density contract"
		)
		_expect(
			_count_all_optional_nodes(graph) == 0,
			"audition topology must not receive standard-tower optional bosses"
		)
	TowerAuditionBuildConfig.debug_set_enabled(false)


func _verify_optional_node(
	map_seed: int,
	floor_number: int,
	node: Dictionary,
	graph: Dictionary,
	registry: RefCounted
) -> void:
	_expect(
		str(node.get("optional_extra_boss_source_kind", ""))
			in TowerAscentBossRegistry.NPC_FILL_KINDS,
		"seed %d floor %d optional boss must come from an NPC node"
		% [map_seed, floor_number]
	)
	_expect(
		not bool(node.get("gatekeeper", false))
			and not bool(node.get("floor_one_boss_choice", false)),
		"seed %d floor %d optional boss must not rewrite a gate or floor-one choice"
		% [map_seed, floor_number]
	)
	var row_nodes := _nodes_in_global_row(graph, int(node.get("global_row", -1)))
	var combat_count := 0
	var npc_count := 0
	for row_node in row_nodes:
		var node_kind := str(row_node.get("kind", ""))
		if node_kind in TowerAscentMapGenerator.COMBAT_NODE_KINDS:
			combat_count += 1
		elif node_kind in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS:
			npc_count += 1
	_expect(
		combat_count == 1 and npc_count == row_nodes.size() - 1,
		"seed %d floor %d optional row must contain exactly one boss"
		% [map_seed, floor_number]
	)
	var slot_id := str(node.get("boss_slot_id", ""))
	var slot: Dictionary = registry.call("get_slot", slot_id)
	_expect(
		int(slot.get("slot_floor", 0)) == floor_number,
		"seed %d floor %d optional boss must consume that floor's slot pool"
		% [map_seed, floor_number]
	)
	var encounter: Dictionary = registry.call("resolve_battle_encounter", slot_id)
	_expect(
		not encounter.is_empty(),
		"seed %d floor %d optional boss must use existing battle routing"
		% [map_seed, floor_number]
	)
	var iconography := TowerAscentMapIconography.new()
	var boss_icon_id := iconography.resolve_boss_id_for_node(node)
	var icon_path := iconography.resolve_icon_path(str(node.get("kind", "")), boss_icon_id)
	_expect(
		not boss_icon_id.is_empty() and FileAccess.file_exists(icon_path),
		"seed %d floor %d optional boss must resolve an existing map icon"
		% [map_seed, floor_number]
	)


func _verify_optional_row_cap(
	map_seed: int,
	floor_number: int,
	optional_nodes: Array[Dictionary]
) -> void:
	var count_by_row: Dictionary = {}
	for node in optional_nodes:
		var global_row := int(node.get("global_row", -1))
		count_by_row[global_row] = int(count_by_row.get(global_row, 0)) + 1
	for count_variant in count_by_row.values():
		_expect(
			int(count_variant) == 1,
			"seed %d floor %d must place at most one optional boss in each NPC row"
			% [map_seed, floor_number]
		)
		_row_cap_checks += 1
	if floor_number in [2, 3]:
		_expect(
			count_by_row.size() == 2,
			"seed %d floor %d must use both NPC rows"
			% [map_seed, floor_number]
		)


func _nodes_in_global_row(graph: Dictionary, global_row: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if (
				node_variant is Dictionary
				and int((node_variant as Dictionary).get("global_row", -1)) == global_row
			):
				result.append(node_variant as Dictionary)
	return result


func _verify_explicit_canonical_uniqueness(
	map_seed: int,
	graph: Dictionary,
	registry: RefCounted
) -> void:
	var encountered_by_key: Dictionary = {}
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if (
				str(node.get("content_state", ""))
					!= TowerAscentBossRegistry.CONTENT_GENERATED
				or str(node.get("kind", "")) not in TowerAscentBossRegistry.COMBAT_NODE_KINDS
				or bool(node.get("standin_duplicate_gate", false))
			):
				continue
			var encounter_key := str(node.get("boss_encounter_key", ""))
			if encounter_key.is_empty():
				encounter_key = str(registry.call(
					"canonical_encounter_key",
					node.get("standin", {})
				))
			_expect(
				not encountered_by_key.has(encounter_key),
				"seed %d canonical encounter key %s must not repeat"
				% [map_seed, encounter_key]
			)
			encountered_by_key[encounter_key] = str(node.get("id", ""))


func _verify_fit_all_budget(map_seed: int, graph: Dictionary) -> void:
	var budget := _estimate_fit_all_draw_budget(graph, map_seed)
	var path_draw_calls := int(budget.get("path_draw_calls", 0))
	var cloud_draw_calls := int(budget.get("cloud_draw_calls", 0))
	var total_draw_calls := int(budget.get("total_draw_calls", 0))
	_expect(
		total_draw_calls <= MAP_DRAW_CALL_LIMIT,
		"seed %d fit-all dotted paths plus clouds exceed %d (%d)"
		% [map_seed, MAP_DRAW_CALL_LIMIT, total_draw_calls]
	)
	if total_draw_calls > _maximum_draw_calls:
		_maximum_draw_calls = total_draw_calls
		_maximum_draw_seed = map_seed
		_maximum_path_draw_calls = path_draw_calls
		_maximum_cloud_draw_calls = cloud_draw_calls


func _estimate_fit_all_draw_budget(graph: Dictionary, map_seed: int) -> Dictionary:
	var nodes: Array[Dictionary] = []
	var edges: Array[Dictionary] = []
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		var phase := phase_variant as Dictionary
		for node_variant in phase.get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := (node_variant as Dictionary).duplicate(true)
			node["overview_hidden"] = (
				str(node.get("content_state", "generated")) != "generated"
			)
			nodes.append(node)
		for edge_variant in phase.get("edges", []):
			if edge_variant is Dictionary:
				edges.append((edge_variant as Dictionary).duplicate(true))
	var outer_margin := minf(
		VIEWPORT_RECT.size.x,
		VIEWPORT_RECT.size.y
	) * TowerAscentTuning.TEMP_MAP_OUTER_MARGIN_RATIO
	var safe_content_bounds := VIEWPORT_RECT.grow(-outer_margin)
	var side_gutter := (
		safe_content_bounds.size.x * TowerAscentTuning.TEMP_MAP_SIDE_GUTTER_RATIO
	)
	var top_inset := (
		VIEWPORT_RECT.size.y * TowerAscentTuning.TEMP_MAP_CONTENT_TOP_RATIO
	)
	var bottom_inset := (
		VIEWPORT_RECT.size.y * TowerAscentTuning.TEMP_MAP_CONTENT_BOTTOM_RATIO
	)
	var content_rect := Rect2(
		safe_content_bounds.position + Vector2(side_gutter, top_inset),
		Vector2(
			maxf(1.0, safe_content_bounds.size.x - side_gutter * 2.0),
			maxf(
				1.0,
				safe_content_bounds.size.y - top_inset - bottom_inset
			)
		)
	)
	var map_scale := maxf(0.001, content_rect.size.x / MAP_SCROLL_TILE_SIZE.x)
	var scaled_row_pitch := MAP_SCROLL_ROW_PITCH * map_scale
	var art_size := MAP_SCROLL_NODE_ART_SIZE * map_scale
	var source_min_x := INF
	var source_max_x := -INF
	var unique_rows: Dictionary = {}
	for node in nodes:
		var source_position := _as_vector2(node.get("position", Vector2.ZERO))
		source_min_x = minf(source_min_x, source_position.x)
		source_max_x = maxf(source_max_x, source_position.x)
		unique_rows[int(round(source_position.y))] = true
	var sorted_source_rows: Array = unique_rows.keys()
	sorted_source_rows.sort()
	var row_index_by_source_y: Dictionary = {}
	for row_index in range(sorted_source_rows.size()):
		row_index_by_source_y[int(sorted_source_rows[row_index])] = row_index
	var lane_span := (
		MAP_SCROLL_TILE_SIZE.x
		* map_scale
		* TowerAscentTuning.TEMP_MAP_LANE_SPAN_RATIO
	)
	var center_x := content_rect.get_center().x
	var position_by_id: Dictionary = {}
	var projected_node_by_id: Dictionary = {}
	var projected_nodes: Array[Dictionary] = []
	for source_node in nodes:
		var node := source_node.duplicate(true)
		var source_position := _as_vector2(node.get("position", Vector2.ZERO))
		var source_x_ratio := (
			lerpf(
				-1.0,
				1.0,
				inverse_lerp(source_min_x, source_max_x, source_position.x)
			)
			if not is_equal_approx(source_min_x, source_max_x)
			else 0.0
		)
		var source_row_index := int(row_index_by_source_y.get(
			int(round(source_position.y)),
			0
		))
		var world_position := Vector2(
			center_x + source_x_ratio * lane_span,
			content_rect.position.y + float(source_row_index) * scaled_row_pitch
		)
		node["world_position"] = world_position
		var node_id := str(node.get("id", ""))
		position_by_id[node_id] = world_position
		projected_node_by_id[node_id] = node
		projected_nodes.append(node)
	var straight_edges: Array[Dictionary] = []
	for edge in edges:
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		if not position_by_id.has(from_id) or not position_by_id.has(to_id):
			continue
		if (
			bool((projected_node_by_id[from_id] as Dictionary).get("overview_hidden", false))
			or bool((projected_node_by_id[to_id] as Dictionary).get("overview_hidden", false))
		):
			continue
		straight_edges.append({
			"from": from_id,
			"to": to_id,
			"from_position": position_by_id[from_id],
			"to_position": position_by_id[to_id],
		})
	var curved_edges := TowerAscentMapPathGeometry.build(
		straight_edges,
		map_seed,
		art_size,
		TowerAscentTuning.TEMP_MAP_PATH_CURVE_MIN_RATIO,
		TowerAscentTuning.TEMP_MAP_PATH_CURVE_MAX_RATIO,
		TowerAscentTuning.TEMP_MAP_PATH_CURVE_SKEW_RATIO,
		MAP_SCROLL_ROUTE_ENDPOINT_CLEARANCE_RATIO,
		TowerAscentTuning.TEMP_MAP_PATH_SAMPLE_MIN,
		TowerAscentTuning.TEMP_MAP_PATH_SAMPLE_MAX
	)
	var cloud_draw_calls := TowerAscentMapCloudLayer.estimate_draw_calls(
		projected_nodes,
		art_size,
		map_scale
	)
	var route_draw_call_budget := maxi(
		2,
		TowerAscentTuning.TEMP_MAP_PATH_DRAW_CALL_BUDGET - cloud_draw_calls
	)
	var dot_gap := art_size * TowerAscentTuning.TEMP_MAP_PATH_DOT_GAP_ART_RATIO
	var dotted_edges: Array[Dictionary] = []
	for _budget_attempt in range(4):
		dotted_edges = TowerAscentMapPathGeometry.attach_dots(
			curved_edges,
			dot_gap,
			art_size * TowerAscentTuning.TEMP_MAP_PATH_DOT_OUTER_RADIUS_ART_RATIO,
			art_size * TowerAscentTuning.TEMP_MAP_PATH_DOT_INNER_RADIUS_ART_RATIO,
			TowerAscentTuning.TEMP_MAP_PATH_DOT_CIRCLE_SEGMENTS
		)
		var draw_call_count := (
			TowerAscentMapPathGeometry.dot_count(dotted_edges) * 2
		)
		if draw_call_count <= route_draw_call_budget:
			break
		dot_gap *= maxf(
			1.05,
			float(draw_call_count) / float(route_draw_call_budget)
		)
	var path_draw_calls := TowerAscentMapPathGeometry.dot_count(dotted_edges) * 2
	return {
		"path_draw_calls": path_draw_calls,
		"cloud_draw_calls": cloud_draw_calls,
		"total_draw_calls": path_draw_calls + cloud_draw_calls,
	}


func _verify_forced_passage_negative_leg() -> void:
	_expect(not _forced_fixture.is_empty(), "forced-passage fixture source must exist")
	if _forced_fixture.is_empty():
		return
	var fixture := _forced_fixture.duplicate(true)
	var forced_node_id := ""
	for phase_variant in fixture.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if (
				bool(node.get("gatekeeper", false))
				and int(node.get("segment_floor", 0)) == 2
			):
				node["optional_extra_boss"] = true
				forced_node_id = str(node.get("id", ""))
				break
		if not forced_node_id.is_empty():
			break
	var report := TowerAscentBossRegistry.new().analyze_optional_extra_boss_bypass(
		fixture,
		TowerAuditionBuildConfig.get_clear_floor()
	)
	_expect(not forced_node_id.is_empty(), "forced-passage fixture must mark a floor-2 gate")
	_expect(
		not bool(report.get("valid", true)),
		"marking a forced gate as optional must be RED"
	)
	_expect(
		_issue_contains(report, "forced_optional_extra_boss=%s" % forced_node_id),
		"forced-passage RED leg must name the unavoidable node"
	)
	_negative_leg_count += 1
	_verify_same_row_negative_leg()


func _verify_same_row_negative_leg() -> void:
	var fixture := _forced_fixture.duplicate(true)
	var target_floor := 2
	var optional_node_id := ""
	var optional_row := -1
	for phase_variant in fixture.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if (
				int(node.get("segment_floor", 0)) == target_floor
				and bool(node.get("optional_extra_boss", false))
			):
				optional_node_id = str(node.get("id", ""))
				optional_row = int(node.get("global_row", -1))
				break
		if not optional_node_id.is_empty():
			break
	var sibling_node_id := ""
	for phase_variant in fixture.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if (
				str(node.get("id", "")) != optional_node_id
				and int(node.get("global_row", -2)) == optional_row
			):
				node["optional_extra_boss"] = true
				sibling_node_id = str(node.get("id", ""))
				break
		if not sibling_node_id.is_empty():
			break
	var report := TowerAscentBossRegistry.new().analyze_optional_extra_boss_bypass(
		fixture,
		TowerAuditionBuildConfig.get_clear_floor()
	)
	_expect(
		not optional_node_id.is_empty() and not sibling_node_id.is_empty(),
		"same-row RED fixture must find a floor-2 optional boss and sibling"
	)
	_expect(
		not bool(report.get("valid", true)),
		"placing two optional bosses in one NPC row must be RED"
	)
	_expect(
		_issue_contains(report, "optional_extra_boss_row_cap="),
		"same-row RED leg must name the violated row"
	)
	_negative_leg_count += 1


func _optional_nodes_for_floor(graph: Dictionary, floor_number: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if (
				bool(node.get("optional_extra_boss", false))
				and int(node.get("segment_floor", 0)) == floor_number
			):
				result.append(node)
	return result


func _count_all_optional_nodes(graph: Dictionary) -> int:
	var result := 0
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if (
				node_variant is Dictionary
				and bool((node_variant as Dictionary).get("optional_extra_boss", false))
			):
				result += 1
	return result


func _count_optional_nodes_for_floor(graph: Dictionary, floor_number: int) -> int:
	return _optional_nodes_for_floor(graph, floor_number).size()


func _count_floor_one_generated_bosses(graph: Dictionary) -> int:
	var result := 0
	for phase_variant in graph.get("phases", []):
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if (
				int(node.get("segment_floor", 0)) == 1
				and str(node.get("content_state", ""))
					== TowerAscentBossRegistry.CONTENT_GENERATED
				and str(node.get("kind", "")) in TowerAscentBossRegistry.COMBAT_NODE_KINDS
			):
				result += 1
	return result


func _floor_boss_ranges() -> Dictionary:
	var result: Dictionary = {}
	for floor_variant in _minimum_bosses_by_floor.keys():
		var floor_number := int(floor_variant)
		result[floor_number] = {
			"min": int(_minimum_bosses_by_floor.get(floor_number, -1)),
			"max": int(_maximum_bosses_by_floor.get(floor_number, -1)),
		}
	return result


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _issue_contains(report: Dictionary, fragment: String) -> bool:
	for issue_variant in report.get("issues", []):
		if str(issue_variant).contains(fragment):
			return true
	return false


func _safe_ratio(numerator: int, denominator: int) -> float:
	return 0.0 if denominator <= 0 else float(numerator) / float(denominator)


func _expect(condition: bool, message: String) -> void:
	if not condition and _failures.size() < 32 and not _failures.has(message):
		_failures.append(message)
