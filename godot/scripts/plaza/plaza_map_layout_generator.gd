extends RefCounted

# R2-A candidate data plane only. Production PlazaScene intentionally remains
# on the R1 one-axis bridge until projection, navigation, retained Y-sort, and
# minimap ownership can move together in a later atomic slice.

const SCHEMA_VERSION := 1
const GENERATOR_VERSION := "hwangyeok_map_layout_r2a_v1"
const MAP_WORLD_SIZE := Vector2(2400.0, 1500.0)
const REQUIRED_PLOT_COUNT := 7
const MAX_LANDMARK_GAP_WORLD := 360.0
const ROAD_HALF_WIDTH_WORLD := 42.0
const ROAD_HALF_WIDTH_BY_KIND := {
	"main": ROAD_HALF_WIDTH_WORLD,
	"secondary": ROAD_HALF_WIDTH_WORLD * 0.58,
	"trail": ROAD_HALF_WIDTH_WORLD * 0.34,
	"approach": ROAD_HALF_WIDTH_WORLD * 0.72,
}
const WALKABLE_CAP_STYLE := "square"
const PLOT_BOUNDARY_OVERLAP_POLICY := "forbid_positive_area"
const MIN_DECOR_VISUAL_SIZE := Vector2(80.0, 60.0)
const MIN_PLOT_Y_SPAN_RATIO := 0.45
const MIN_STRUCTURAL_BBOX_HEIGHT_RATIO := 0.60
const MIN_CONTENT_ANCHOR_AREA_RATIO := 0.18
const MIN_UPPER_LOWER_PLOT_COUNT := 2
const MIN_SELECTED_BUILDING_COUNT := 2
const MAX_SELECTED_BUILDING_COUNT := 5
const KNOWN_BUILDING_TYPES := ["bank", "shop", "gacha", "lingpet_store", "blacksmith", "tavern", "academy"]
const LABEL_HEIGHT_WORLD := 42.0
const LABEL_STEM_GAP_WORLD := 12.0

const PLOT_ARCHETYPES := [
	{
		"id": "market_plot",
		"plot_class": "standard_market",
	},
	{
		"id": "left_access",
		"plot_class": "medium_left_access",
	},
	{
		"id": "rear_landmark",
		"plot_class": "rear_landmark_large",
	},
	{
		"id": "central_crossing",
		"plot_class": "intersection_large",
	},
	{
		"id": "spirit_plot",
		"plot_class": "medium",
	},
	{
		"id": "quiet_plot",
		"plot_class": "standard_quiet",
	},
	{
		"id": "forge_plot",
		"plot_class": "edge_large",
	},
]

const PLOT_ROUTE_SLOTS := [
	# Every parcel sits far enough to the right of its junction that the
	# canonical road shoulder can reach the lower-left entrance without cutting
	# through the authored footprint. The alternating y bands are intentional:
	# they keep same-band parcels disjoint while using the full 2D world.
	{"slot_index": 0, "size_group": "regular", "main_fraction": 0.08, "pivot_x_offset": 130.0, "target_y": 330.0},
	{"slot_index": 1, "size_group": "regular", "main_fraction": 0.21, "pivot_x_offset": 135.0, "target_y": 1130.0},
	{"slot_index": 2, "size_group": "large_landmark", "main_fraction": 0.34, "pivot_x_offset": 165.0, "target_y": 680.0},
	{"slot_index": 3, "size_group": "regular", "main_fraction": 0.47, "pivot_x_offset": 145.0, "target_y": 320.0},
	{"slot_index": 4, "size_group": "large_landmark", "main_fraction": 0.60, "pivot_x_offset": 160.0, "target_y": 1140.0},
	{"slot_index": 5, "size_group": "regular", "main_fraction": 0.73, "pivot_x_offset": 140.0, "target_y": 330.0},
	# edge_large is the only class narrow enough for this right-edge parcel.
	# Keeping it fixed also guarantees its right-growing label remains in-world.
	{"slot_index": 6, "size_group": "edge_large", "main_fraction": 0.86, "pivot_x_offset": 60.0, "target_y": 1080.0},
]

const ROAD_SKELETON_MOTIFS := [
	# Secondary loops always leave the spine from slots whose parcels occupy the
	# opposite vertical band. A mathematically valid loop that slices through a
	# building is not a usable road graph.
	{"id": "moon_arch", "route_y_offsets": [50.0, 105.0, 155.0, 190.0, 150.0, 100.0, 55.0], "secondary_anchor_slots": [1, 4], "secondary_hub_y": 100.0, "secondary_side": "upper"},
	{"id": "river_fold", "route_y_offsets": [65.0, 140.0, 105.0, 180.0, 120.0, 155.0, 60.0], "secondary_anchor_slots": [0, 3], "secondary_hub_y": 1320.0, "secondary_side": "lower"},
	{"id": "terrace_bow", "route_y_offsets": [45.0, 90.0, 145.0, 120.0, 175.0, 105.0, 50.0], "secondary_anchor_slots": [0, 5], "secondary_hub_y": 1320.0, "secondary_side": "lower"},
]

const LARGE_PLOT_CLASSES := ["rear_landmark_large", "intersection_large", "edge_large"]

# Tight class-owned parcels. Values are left/right/rear/front extents from the
# authored pivot and include a small allowance around each exact footprint.
# Unused plots still fit the common 144 x 72 decor blocker.
const PLOT_BOUNDARY_EXTENTS_BY_CLASS := {
	"standard_market": Vector4(150.0, 110.0, 120.0, 25.0),
	"medium_left_access": Vector4(215.0, 80.0, 140.0, 25.0),
	"rear_landmark_large": Vector4(216.0, 120.0, 165.0, 25.0),
	"intersection_large": Vector4(198.0, 110.0, 150.0, 25.0),
	"medium": Vector4(215.0, 80.0, 140.0, 25.0),
	"standard_quiet": Vector4(150.0, 92.0, 115.0, 25.0),
	"edge_large": Vector4(175.0, 90.0, 125.0, 25.0),
}

const DECOR_KINDS_BY_PLOT_CLASS := {
	"standard_market": ["market_stalls", "cloth_awning_cluster"],
	"medium_left_access": ["stone_lantern_gate", "small_vendor_court"],
	"rear_landmark_large": ["guardian_tree_grove"],
	"intersection_large": ["crossroad_lanterns", "seal_stone_court"],
	"medium": ["spirit_tree_cluster", "jade_rock_garden"],
	"standard_quiet": ["quiet_pond", "bench_and_lanterns"],
	"edge_large": ["boundary_pines", "stone_marker_cluster"],
}


static func generate(
	stage_id: int,
	map_seed: int,
	world_size: Vector2,
	selected_specs: Array[Dictionary],
	spawn_anchor: Vector2,
	exit_zone: Rect2
) -> Dictionary:
	var normalized_stage := maxi(1, stage_id)
	var safe_world_size := Vector2(maxf(1.0, world_size.x), maxf(1.0, world_size.y))
	var safe_spawn := _clamp_world_point(spawn_anchor, safe_world_size, 0.0)
	var safe_exit_zone := exit_zone
	var exit_center := _clamp_world_point(exit_zone.get_center(), safe_world_size, 0.0)

	# Phase-isolated streams are deliberate. Adding a decor variant must never
	# move a road, plot, or selected building for the same authoritative seed.
	var skeleton_rng := _build_phase_rng(normalized_stage, map_seed, "skeleton")
	var plot_rng := _build_phase_rng(normalized_stage, map_seed, "plots")
	var assignment_rng := _build_phase_rng(normalized_stage, map_seed, "assignment")
	var decor_rng := _build_phase_rng(normalized_stage, map_seed, "decor")

	var plot_assignments := _build_plot_assignments(assignment_rng, map_seed)
	var road_graph := _build_main_road_graph(
		safe_spawn,
		exit_center,
		safe_world_size,
		skeleton_rng,
		map_seed
	)
	var plots := _build_plots(road_graph, safe_world_size, plot_rng, plot_assignments)
	var buildings := _assign_buildings(selected_specs, plots, assignment_rng)
	_append_plot_approach_edges(road_graph, plots, buildings, safe_world_size)
	var decor_clusters := _fill_unused_plots(plots, buildings, road_graph, decor_rng)
	var blocked_polygons := _build_blocked_polygons(buildings, decor_clusters)
	var walkable_corridors := _build_walkable_corridors(road_graph)
	var interaction_portals := _build_interaction_portals(buildings)

	var selected_types: Array[String] = []
	for spec in selected_specs:
		selected_types.append(str(spec.get("type", "")))
	var layout := {
		"schema_version": SCHEMA_VERSION,
		"generator_version": GENERATOR_VERSION,
		"stage_id": normalized_stage,
		"map_seed": map_seed,
		"world_size": safe_world_size,
		"spawn_anchor": safe_spawn,
		"exit_zone": safe_exit_zone,
		"selected_building_types": selected_types,
		"road_graph": road_graph,
		"plot_boundary_overlap_policy": PLOT_BOUNDARY_OVERLAP_POLICY,
		"plot_assignment_signature": _plot_assignment_signature(plots),
		"plots": plots,
		"building_specs": buildings,
		"decor_clusters": decor_clusters,
		"blocked_polygons": blocked_polygons,
		"walkable_corridor_polygons": walkable_corridors,
		"interaction_portals": interaction_portals,
		"main_route_length_world": float(road_graph.get("main_route_length_world", 0.0)),
		"candidate_only": true,
		"production_connected": false,
	}
	layout["validation"] = validate_layout(layout)
	layout["fingerprint"] = build_fingerprint(layout)
	return layout


static func validate_layout(layout: Dictionary) -> Dictionary:
	return _validate_layout_internal(layout, GENERATOR_VERSION, true)


# R3 candidate owners reuse the mature plot/building/decor/road-clearance
# validators while owning their versioned road topology themselves. Keeping
# this entry point here prevents the integrated generator from copying the
# collision contract or weakening the production-disconnected R2 validator.
static func validate_candidate_geometry(
	layout: Dictionary,
	expected_generator_version: String
) -> Dictionary:
	return _validate_layout_internal(layout, expected_generator_version, false)


static func _validate_layout_internal(
	layout: Dictionary,
	expected_generator_version: String,
	validate_r2_road_topology: bool
) -> Dictionary:
	var violations: Array[Dictionary] = []
	var metrics := {
		"plot_count": 0,
		"building_count": 0,
		"decor_cluster_count": 0,
		"unused_plot_count": 0,
		"main_route_length_world": 0.0,
		"max_landmark_gap_world": INF,
	}
	_validate_consumed_field_contract(layout, violations)
	# Type/finite validation is a hard fan-in gate. Semantic validators below
	# intentionally use typed conversions, geometry APIs, and array indexing;
	# never execute them on a partially coercible external layout.
	if not violations.is_empty():
		return {
			"valid": false,
			"violations": violations,
			"metrics": metrics,
		}
	if int(layout.get("schema_version", -1)) != SCHEMA_VERSION:
		_add_violation(violations, "invalid_schema", "unexpected schema_version")
	if str(layout.get("generator_version", "")) != expected_generator_version:
		_add_violation(violations, "invalid_generator_version", "unexpected generator_version")
	if str(layout.get("plot_boundary_overlap_policy", "")) != PLOT_BOUNDARY_OVERLAP_POLICY:
		_add_violation(violations, "plot_boundary_overlap_policy_mismatch", str(layout.get("plot_boundary_overlap_policy", "")))
	var world_size := _coerce_vector2(layout.get("world_size", Vector2.ZERO))
	if not _is_finite_vector2(world_size) or world_size.x <= 1.0 or world_size.y <= 1.0:
		_add_violation(violations, "invalid_world_size", "world_size must be positive")
	elif world_size != MAP_WORLD_SIZE:
		_add_violation(
			violations,
			"world_size_contract_mismatch",
			"expected=%s actual=%s" % [_vector_token(MAP_WORLD_SIZE), _vector_token(world_size)]
		)

	var plots := _dictionary_array(layout.get("plots", []))
	var buildings := _dictionary_array(layout.get("building_specs", []))
	var decor_clusters := _dictionary_array(layout.get("decor_clusters", []))
	metrics["plot_count"] = plots.size()
	metrics["building_count"] = buildings.size()
	metrics["decor_cluster_count"] = decor_clusters.size()
	if plots.size() != REQUIRED_PLOT_COUNT:
		_add_violation(
			violations,
			"plot_count_not_seven",
			"expected %d semantic plots, got %d" % [REQUIRED_PLOT_COUNT, plots.size()]
		)

	_validate_selected_building_contract(layout, buildings, violations)
	if validate_r2_road_topology:
		_validate_road_graph(layout, world_size, violations)
	_validate_plot_assignment_contract(layout, plots, violations)
	_validate_plot_occupancy(plots, buildings, decor_clusters, violations, metrics)
	_validate_building_geometry(buildings, decor_clusters, world_size, violations)
	_validate_label_rects(buildings, decor_clusters, world_size, not validate_r2_road_topology, violations)
	_validate_plot_boundaries(plots, buildings, decor_clusters, world_size, violations)
	_validate_road_plot_boundary_clearance(layout, plots, violations)
	_validate_blocked_polygon_manifest(layout, buildings, decor_clusters, violations)
	_validate_road_core_clearance(layout, buildings, decor_clusters, violations)
	_validate_walkable_manifest(layout, buildings, world_size, validate_r2_road_topology, violations)
	_validate_approach_edges(layout, buildings, violations)
	_validate_route_distance_contract(layout, plots, buildings, decor_clusters, violations)
	# The 360-world landmark cadence is an R2 spine contract. R3 candidates own
	# a different road-first spine and validate its authored turn/coverage budget
	# in their versioned validator instead of inheriting an impossible R2 scalar.
	if validate_r2_road_topology:
		_validate_landmark_gap(layout, plots, violations, metrics)
	_validate_map_distribution(layout, plots, buildings, decor_clusters, world_size, violations, metrics)
	return {
		"valid": violations.is_empty(),
		"violations": violations,
		"metrics": metrics,
	}


static func build_fingerprint(layout: Dictionary) -> String:
	var parts: Array[String] = [
		"schema=%d" % int(layout.get("schema_version", -1)),
		"generator=%s" % str(layout.get("generator_version", "")),
		"stage=%d" % int(layout.get("stage_id", 0)),
		"seed=%d" % int(layout.get("map_seed", 0)),
		"world=%s" % _vector_token(_coerce_vector2(layout.get("world_size", Vector2.ZERO))),
		"spawn=%s" % _vector_token(_coerce_vector2(layout.get("spawn_anchor", Vector2.ZERO))),
		"main_route_length=%.3f" % float(layout.get("main_route_length_world", -1.0)),
		"plot_overlap=%s" % str(layout.get("plot_boundary_overlap_policy", "")),
	]
	var exit_value: Variant = layout.get("exit_zone", null)
	parts.append("exit=%s" % (_rect_token(exit_value as Rect2) if exit_value is Rect2 else "invalid"))
	for selected_type in layout.get("selected_building_types", []) as Array:
		parts.append("selected:%s" % str(selected_type))
	var road_graph_value: Variant = layout.get("road_graph", {})
	var road_graph: Dictionary = road_graph_value as Dictionary if road_graph_value is Dictionary else {}
	parts.append("skeleton:%s" % str(road_graph.get("skeleton_variant", "")))
	parts.append("secondary:%s:%s" % [str(road_graph.get("secondary_side", "")), str(road_graph.get("secondary_anchor_slots", []))])
	parts.append("road_anchors:%s:%s" % [str(road_graph.get("spawn_node_id", "")), str(road_graph.get("exit_node_id", ""))])
	parts.append("road_main_route_length:%.3f" % float(road_graph.get("main_route_length_world", -1.0)))
	parts.append("assignment:%s" % str(layout.get("plot_assignment_signature", "")))
	for node in _dictionary_array(road_graph.get("nodes", [])):
		parts.append("node:%s:%s:%s:%s:%.3f" % [
			str(node.get("id", "")),
			str(node.get("role", "")),
			str(node.get("plot_id", "")),
			_vector_token(_coerce_vector2(node.get("position", Vector2.ZERO))),
			float(node.get("route_distance_world", -1.0)),
		])
	for edge in _dictionary_array(road_graph.get("edges", [])):
		parts.append("edge:%s:%s:%s:%s:%s:%.3f" % [
			str(edge.get("id", "")),
			str(edge.get("kind", "")),
			str(edge.get("from", "")),
			str(edge.get("to", "")),
			str(edge.get("plot_id", "")),
			float(edge.get("half_width_world", -1.0)),
		])
		for point in _vector2_array(edge.get("polyline_world", [])):
			parts.append("edge_point:%s" % _vector_token(point))
	for plot in _dictionary_array(layout.get("plots", [])):
		parts.append("plot:%s:%s:%d:%s:%s:%s:%s:%.3f:%s:%s" % [
			str(plot.get("id", "")),
			str(plot.get("plot_class", "")),
			int(plot.get("route_slot_index", -1)),
			_vector_token(_coerce_vector2(plot.get("pivot_pos", Vector2.ZERO))),
			str(plot.get("main_node_id", "")),
			str(plot.get("approach_side", "")),
			str(plot.get("occupied_by", "")),
			float(plot.get("main_route_distance_world", -1.0)),
			str(plot.get("approach_edge_id", plot.get("trail_edge_id", ""))),
			str(plot.get("decor_cluster_id", "")),
		])
		for point in _vector2_array(plot.get("boundary_polygon_world", [])):
			parts.append("plot_boundary:%s" % _vector_token(point))
		for anchor_key in ["approach_anchor_world", "trail_anchor_world"]:
			if plot.has(anchor_key):
				parts.append("plot_%s:%s" % [anchor_key, _vector_token(_coerce_vector2(plot.get(anchor_key, Vector2.ZERO)))])
	for building in _dictionary_array(layout.get("building_specs", [])):
		var clearance_value: Variant = building.get("road_side_clearance", {})
		var clearance: Dictionary = clearance_value as Dictionary if clearance_value is Dictionary else {}
		parts.append("building_source:%s:%s:%s:%s:%s:%s:%s:%.3f:%.3f" % [
			_vector_token(_coerce_vector2(building.get("source_size", Vector2.ZERO))),
			_vector_token(_coerce_vector2(building.get("origin_pivot", Vector2.ZERO))),
			_vector_token(_coerce_vector2(building.get("entrance_anchor_offset", Vector2.ZERO))),
			_vector_token(_coerce_vector2(building.get("entrance_normal", Vector2.ZERO))),
			_vector_token(_coerce_vector2(building.get("sort_anchor", Vector2.ZERO))),
			_vector_token(_coerce_vector2(building.get("label_anchor", Vector2.ZERO))),
			_vector_token(_coerce_vector2(building.get("label_anchor_source_pixels", Vector2.ZERO))),
			float(clearance.get("cross_width", -1.0)),
			float(clearance.get("approach_depth", -1.0)),
		])
		parts.append("building:%s:%s:%d:%d:%s:%s:%s:%s:%s:%s:%s:%.3f:%.3f:%.6f" % [
			str(building.get("type", "")),
			str(building.get("plot_id", "")),
			int(building.get("selection_index", -1)),
			int(building.get("route_slot_index", -1)),
			_vector_token(_coerce_vector2(building.get("pivot_pos", Vector2.ZERO))),
			str(building.get("main_node_id", "")),
			_vector_token(_coerce_vector2(building.get("entrance_world_pos", Vector2.ZERO))),
			_vector_token(_coerce_vector2(building.get("sort_anchor_world", Vector2.ZERO))),
			_vector_token(_coerce_vector2(building.get("label_world_pos", Vector2.ZERO))),
			str(building.get("approach_edge_id", "")),
			str(building.get("interaction_portal_id", "")),
			float(building.get("y_sort_anchor", -1.0)),
			float(building.get("main_route_distance_world", -1.0)),
			float(building.get("display_scale", -1.0)),
		])
		for rect_key in ["visual_rect", "interaction_rect", "label_rect_world"]:
			var rect_value: Variant = building.get(rect_key, null)
			parts.append("building_%s:%s" % [rect_key, _rect_token(rect_value as Rect2) if rect_value is Rect2 else "invalid"])
		for point in _vector2_array(building.get("footprint_polygon", [])):
			parts.append("building_source_footprint:%s" % _vector_token(point))
		for point in _vector2_array(building.get("footprint_world_polygon", [])):
			parts.append("building_footprint:%s" % _vector_token(point))
		for point in _vector2_array(building.get("interaction_polygon_world", [])):
			parts.append("building_interaction:%s" % _vector_token(point))
		for point in _vector2_array(building.get("road_side_clearance_polygon_world", [])):
			parts.append("building_clearance:%s" % _vector_token(point))
	for decor in _dictionary_array(layout.get("decor_clusters", [])):
		parts.append("decor:%s:%s:%s:%s:%s:%s:%.3f" % [
			str(decor.get("id", "")),
			str(decor.get("plot_id", "")),
			str(decor.get("cluster_type", "")),
			_vector_token(_coerce_vector2(decor.get("anchor_world", Vector2.ZERO))),
			_vector_token(_coerce_vector2(decor.get("sort_anchor_world", Vector2.ZERO))),
			str(bool(decor.get("blocks_navigation", false))),
			float(decor.get("main_route_distance_world", -1.0)),
		])
		var decor_bounds_value: Variant = decor.get("visual_bounds_world", null)
		parts.append("decor_visual:%s" % (_rect_token(decor_bounds_value as Rect2) if decor_bounds_value is Rect2 else "invalid"))
		for point in _vector2_array(decor.get("footprint_world_polygon", [])):
			parts.append("decor_footprint:%s" % _vector_token(point))
	for blocker in _dictionary_array(layout.get("blocked_polygons", [])):
		parts.append("blocker:%s:%s" % [str(blocker.get("kind", "")), str(blocker.get("owner_id", ""))])
		for point in _vector2_array(blocker.get("polygon_world", [])):
			parts.append("blocker_point:%s" % _vector_token(point))
	for corridor in _dictionary_array(layout.get("walkable_corridor_polygons", [])):
		parts.append("corridor:%s:%s:%s:%s:%d:%.3f" % [
			str(corridor.get("id", "")),
			str(corridor.get("edge_id", "")),
			str(corridor.get("edge_kind", "")),
			str(corridor.get("cap_style", "")),
			int(corridor.get("segment_index", -1)),
			float(corridor.get("half_width_world", -1.0)),
		])
		for point in _vector2_array(corridor.get("polygon_world", [])):
			parts.append("corridor_point:%s" % _vector_token(point))
	for hub in _dictionary_array(layout.get("walkable_hub_polygons", [])):
		parts.append("walkable_hub:%s:%s:%s:%s:%s:%d:%.3f" % [
			str(hub.get("id", "")),
			str(hub.get("edge_id", "")),
			str(hub.get("edge_kind", "")),
			str(hub.get("cap_style", "")),
			str(hub.get("source_contract_id", "")),
			int(hub.get("segment_index", -1)),
			float(hub.get("half_width_world", -1.0)),
		])
		for point in _vector2_array(hub.get("polygon_world", [])):
			parts.append("walkable_hub_point:%s" % _vector_token(point))
	for portal in _dictionary_array(layout.get("interaction_portals", [])):
		parts.append("portal:%s:%s:%s:%s" % [str(portal.get("id", "")), str(portal.get("building_type", "")), str(portal.get("plot_id", "")), str(portal.get("approach_edge_id", ""))])
		for point in _vector2_array(portal.get("polygon_world", [])):
			parts.append("portal_point:%s" % _vector_token(point))
	return "\n".join(PackedStringArray(parts)).sha256_text()


static func _build_plot_assignments(_rng: RandomNumberGenerator, map_seed: int) -> Array[Dictionary]:
	var regular: Array[Dictionary] = []
	var rear_landmark: Dictionary = {}
	var intersection: Dictionary = {}
	var edge_large: Dictionary = {}
	for archetype_value in PLOT_ARCHETYPES:
		var archetype: Dictionary = archetype_value
		match str(archetype.get("plot_class", "")):
			"rear_landmark_large":
				rear_landmark = archetype.duplicate(true)
			"intersection_large":
				intersection = archetype.duplicate(true)
			"edge_large":
				edge_large = archetype.duplicate(true)
			_:
				regular.append(archetype.duplicate(true))
	# A cyclic seed permutation guarantees adjacent stage-map seeds move every
	# regular class instead of merely having a high probability of doing so.
	# This remains selection-RNG independent and keeps the seven class contracts.
	if not regular.is_empty():
		var rotation := posmod(map_seed, regular.size())
		for _step in range(rotation):
			regular.append(regular.pop_front())
		if posmod(map_seed / maxi(1, regular.size()), 2) == 1:
			regular.reverse()
	var landmark_slots: Array[Dictionary] = [rear_landmark, intersection]
	if posmod(map_seed, 2) == 1:
		landmark_slots.reverse()
	var assignments: Array[Dictionary] = []
	var regular_index := 0
	var landmark_index := 0
	for slot_value in PLOT_ROUTE_SLOTS:
		var slot: Dictionary = slot_value
		match str(slot.get("size_group", "")):
			"large_landmark":
				assignments.append(landmark_slots[landmark_index])
				landmark_index += 1
			"edge_large":
				assignments.append(edge_large)
			_:
				assignments.append(regular[regular_index])
				regular_index += 1
	return assignments


static func _shuffle_dictionary_array(values: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		if swap_index == index:
			continue
		var held := values[index]
		values[index] = values[swap_index]
		values[swap_index] = held


static func _plot_assignment_signature(plots: Array[Dictionary]) -> String:
	var tokens: Array[String] = []
	for plot in plots:
		tokens.append("%d:%s" % [int(plot.get("route_slot_index", -1)), str(plot.get("plot_class", ""))])
	return "|".join(PackedStringArray(tokens))


static func _build_main_road_graph(
	spawn_anchor: Vector2,
	exit_center: Vector2,
	world_size: Vector2,
	rng: RandomNumberGenerator,
	map_seed: int
) -> Dictionary:
	var ordered_nodes: Array[Dictionary] = [{
		"id": "spawn",
		"role": "spawn",
		"position": spawn_anchor,
	}]
	var motif_index := posmod(map_seed, ROAD_SKELETON_MOTIFS.size())
	var motif: Dictionary = ROAD_SKELETON_MOTIFS[motif_index]
	var offsets_value: Variant = motif.get("route_y_offsets", [])
	var offsets: Array = offsets_value as Array if offsets_value is Array else []
	var world_y_scale := world_size.y / 1500.0
	for index in range(PLOT_ROUTE_SLOTS.size()):
		var slot: Dictionary = PLOT_ROUTE_SLOTS[index]
		var fraction := float(slot.get("main_fraction", 0.5))
		fraction += rng.randf_range(-0.012, 0.012)
		var base_position := spawn_anchor.lerp(exit_center, fraction)
		var motif_offset := float(offsets[index]) if index < offsets.size() else 0.0
		var road_y := base_position.y + motif_offset * world_y_scale
		road_y += rng.randf_range(-6.0, 6.0) * world_y_scale
		var point := Vector2(base_position.x, clampf(road_y, 180.0, world_size.y - 180.0))
		ordered_nodes.append({
			"id": "main_%d" % index,
			"role": "main_plot_junction",
			"position": point,
		})
	ordered_nodes.append({
		"id": "exit",
		"role": "exit",
		"position": exit_center,
	})

	var nodes: Array[Dictionary] = []
	var edges: Array[Dictionary] = []
	var cumulative := 0.0
	for index in range(ordered_nodes.size()):
		var node := ordered_nodes[index].duplicate(true)
		if index > 0:
			var previous_position := _coerce_vector2(ordered_nodes[index - 1].get("position", Vector2.ZERO))
			var current_position := _coerce_vector2(node.get("position", Vector2.ZERO))
			cumulative += previous_position.distance_to(current_position)
			var previous_id := str(ordered_nodes[index - 1].get("id", ""))
			var current_id := str(node.get("id", ""))
			edges.append({
				"id": "main_%s_to_%s" % [previous_id, current_id],
				"kind": "main",
				"from": previous_id,
				"to": current_id,
				"half_width_world": ROAD_HALF_WIDTH_WORLD,
				"polyline_world": [previous_position, current_position],
			})
		node["route_distance_world"] = cumulative
		nodes.append(node)
	var anchor_slots_value: Variant = motif.get("secondary_anchor_slots", [])
	var anchor_slots: Array = anchor_slots_value as Array if anchor_slots_value is Array else []
	if anchor_slots.size() == 2:
		var left_slot := int(anchor_slots[0])
		var right_slot := int(anchor_slots[1])
		var left_main := _find_by_id(nodes, "main_%d" % left_slot)
		var right_main := _find_by_id(nodes, "main_%d" % right_slot)
		var left_main_position := _coerce_vector2(left_main.get("position", Vector2.ZERO))
		var right_main_position := _coerce_vector2(right_main.get("position", Vector2.ZERO))
		var hub_y := clampf(float(motif.get("secondary_hub_y", 150.0)) * world_y_scale, 80.0, world_size.y - 80.0)
		var left_channel_x := _find_secondary_vertical_channel_x(left_main_position, hub_y, world_size, nodes)
		var right_channel_x := _find_secondary_vertical_channel_x(right_main_position, hub_y, world_size, nodes)
		var left_hub_position := Vector2(left_channel_x, hub_y)
		var right_hub_position := Vector2(right_channel_x, hub_y)
		nodes.append({"id": "secondary_left", "role": "secondary_hub", "position": left_hub_position})
		nodes.append({"id": "secondary_right", "role": "secondary_hub", "position": right_hub_position})
		edges.append({
			"id": "secondary_from_main_%d" % left_slot,
			"kind": "secondary",
			"from": "main_%d" % left_slot,
			"to": "secondary_left",
			"half_width_world": _canonical_road_half_width("secondary"),
			"polyline_world": _compact_polyline([
				left_main_position,
				Vector2(left_channel_x, left_main_position.y),
				left_hub_position,
			]),
		})
		edges.append({
			"id": "secondary_hub_span",
			"kind": "secondary",
			"from": "secondary_left",
			"to": "secondary_right",
			"half_width_world": _canonical_road_half_width("secondary"),
			"polyline_world": [left_hub_position, right_hub_position],
		})
		edges.append({
			"id": "secondary_to_main_%d" % right_slot,
			"kind": "secondary",
			"from": "secondary_right",
			"to": "main_%d" % right_slot,
			"half_width_world": _canonical_road_half_width("secondary"),
			"polyline_world": _compact_polyline([
				right_hub_position,
				Vector2(right_channel_x, right_main_position.y),
				right_main_position,
			]),
		})
	return {
		"skeleton_variant": str(motif.get("id", "")),
		"secondary_side": str(motif.get("secondary_side", "")),
		"secondary_anchor_slots": [int(anchor_slots[0]), int(anchor_slots[1])] if anchor_slots.size() == 2 else [],
		"spawn_node_id": "spawn",
		"exit_node_id": "exit",
		"nodes": nodes,
		"edges": edges,
		"main_route_length_world": cumulative,
	}


static func _find_secondary_vertical_channel_x(
	anchor: Vector2,
	hub_y: float,
	world_size: Vector2,
	main_nodes: Array[Dictionary]
) -> float:
	var half_width := _canonical_road_half_width("secondary")
	var envelopes := _build_conservative_plot_envelopes(main_nodes, world_size)
	var candidate_offsets: Array[float] = [0.0]
	for step in range(1, 13):
		candidate_offsets.append(float(step) * 48.0)
		candidate_offsets.append(float(step) * -48.0)
	for offset in candidate_offsets:
		var candidate_x := clampf(anchor.x + offset, half_width * 2.0, world_size.x - half_width * 2.0)
		var segments: Array[Array] = []
		if absf(candidate_x - anchor.x) > 0.01:
			segments.append([anchor, Vector2(candidate_x, anchor.y)])
		segments.append([Vector2(candidate_x, anchor.y), Vector2(candidate_x, hub_y)])
		var clear := true
		for segment in segments:
			var corridor := _segment_corridor_polygon(segment[0] as Vector2, segment[1] as Vector2, half_width)
			for envelope in envelopes:
				if _polygon_intersection_area(corridor, _rect_polygon(envelope)) > 0.01:
					clear = false
					break
			if not clear:
				break
		if clear:
			return candidate_x
	# The production-independent validator will turn this into a concrete road
	# collision instead of silently accepting an unproven fallback channel.
	return anchor.x


static func _build_conservative_plot_envelopes(
	main_nodes: Array[Dictionary],
	world_size: Vector2
) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for slot_value in PLOT_ROUTE_SLOTS:
		var slot: Dictionary = slot_value
		var slot_index := int(slot.get("slot_index", -1))
		var node := _find_by_id(main_nodes, "main_%d" % slot_index)
		if node.is_empty():
			continue
		var extents := Vector4(215.0, 110.0, 140.0, 25.0)
		match str(slot.get("size_group", "")):
			"large_landmark":
				extents = Vector4(216.0, 120.0, 165.0, 25.0)
			"edge_large":
				extents = Vector4(175.0, 90.0, 125.0, 25.0)
		var main_position := _coerce_vector2(node.get("position", Vector2.ZERO))
		var nominal_pivot := Vector2(
			main_position.x + float(slot.get("pivot_x_offset", 0.0)),
			clampf(float(slot.get("target_y", main_position.y)), 300.0, world_size.y - 120.0)
		)
		# _build_plots authors +/-18 x and +/-12 y jitter. The envelope owns that
		# uncertainty explicitly so road generation never depends on plot RNG.
		result.append(Rect2(
			nominal_pivot + Vector2(-extents.x - 18.0, -extents.z - 12.0),
			Vector2(extents.x + extents.y + 36.0, extents.z + extents.w + 24.0)
		))
	return result


static func _build_plots(
	road_graph: Dictionary,
	world_size: Vector2,
	rng: RandomNumberGenerator,
	plot_assignments: Array[Dictionary]
) -> Array[Dictionary]:
	var plots: Array[Dictionary] = []
	var nodes := _dictionary_array(road_graph.get("nodes", []))
	for index in range(PLOT_ROUTE_SLOTS.size()):
		var slot: Dictionary = PLOT_ROUTE_SLOTS[index]
		var archetype: Dictionary = plot_assignments[index] if index < plot_assignments.size() else {}
		var main_node_id := "main_%d" % index
		var main_node := _find_by_id(nodes, main_node_id)
		var main_position := _coerce_vector2(main_node.get("position", Vector2.ZERO))
		var pivot := Vector2(
			main_position.x + float(slot.get("pivot_x_offset", 140.0)) + rng.randf_range(-18.0, 18.0),
			float(slot.get("target_y", main_position.y)) + rng.randf_range(-12.0, 12.0)
		)
		pivot.x = clampf(pivot.x, 220.0, world_size.x - 220.0)
		pivot.y = clampf(pivot.y, 300.0, world_size.y - 120.0)
		var plot_id := str(archetype.get("id", "plot_%d" % index))
		var plot_class := str(archetype.get("plot_class", ""))
		var extents_value: Variant = PLOT_BOUNDARY_EXTENTS_BY_CLASS.get(plot_class, Vector4(150.0, 110.0, 120.0, 25.0))
		var extents: Vector4 = extents_value
		var boundary: Array[Vector2] = [
			pivot + Vector2(-extents.x, -extents.z),
			pivot + Vector2(extents.y, -extents.z),
			pivot + Vector2(extents.y, extents.w),
			pivot + Vector2(-extents.x, extents.w),
		]
		for boundary_index in range(boundary.size()):
			boundary[boundary_index] = _clamp_world_point(boundary[boundary_index], world_size, 0.0)
		plots.append({
			"id": plot_id,
			"plot_class": plot_class,
			"route_slot_index": index,
			"main_node_id": main_node_id,
			"main_route_distance_world": float(main_node.get("route_distance_world", 0.0)),
			"pivot_pos": pivot,
			"boundary_polygon_world": boundary,
			"approach_side": "lower_left",
			"occupied_by": "",
			"decor_cluster_id": "",
		})
	return plots


static func _assign_buildings(
	selected_specs: Array[Dictionary],
	plots: Array[Dictionary],
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for index in range(selected_specs.size()):
		var source := selected_specs[index]
		candidates.append({
			"selection_index": index,
			"hierarchy_rank": int(source.get("hierarchy_rank", 100)),
			"tie_break": rng.randi(),
			"spec": source.duplicate(true),
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rank_a := int(a.get("hierarchy_rank", 100))
		var rank_b := int(b.get("hierarchy_rank", 100))
		if rank_a != rank_b:
			return rank_a < rank_b
		return int(a.get("tie_break", 0)) < int(b.get("tie_break", 0))
	)

	var buildings: Array[Dictionary] = []
	for candidate in candidates:
		var spec_value: Variant = candidate.get("spec", {})
		var spec: Dictionary = spec_value as Dictionary if spec_value is Dictionary else {}
		var plot_class := str(spec.get("plot_class", ""))
		var plot_index := _find_open_plot_index(plots, plot_class)
		if plot_index < 0:
			spec["selection_index"] = int(candidate.get("selection_index", -1))
			spec["plot_id"] = ""
			buildings.append(spec)
			continue
		var plot: Dictionary = plots[plot_index]
		var placed := _place_building_spec(
			spec,
			plot,
			int(candidate.get("selection_index", -1))
		)
		plots[plot_index]["occupied_by"] = str(placed.get("type", ""))
		buildings.append(placed)
	buildings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("selection_index", -1)) < int(b.get("selection_index", -1))
	)
	return buildings


static func _place_building_spec(spec: Dictionary, plot: Dictionary, selection_index: int) -> Dictionary:
	var placed := spec.duplicate(true)
	var pivot := _coerce_vector2(plot.get("pivot_pos", Vector2.ZERO))
	var source_size := _coerce_vector2(placed.get("source_size", Vector2.ONE))
	var origin_pivot := _coerce_vector2(placed.get("origin_pivot", source_size * 0.5))
	var display_scale := maxf(0.0001, float(placed.get("display_scale", 1.0)))
	var footprint_world: Array[Vector2] = []
	for source_offset in _vector2_array(placed.get("footprint_polygon", [])):
		footprint_world.append(pivot + source_offset * display_scale)
	var entrance_offset := _coerce_vector2(placed.get("entrance_anchor_offset", Vector2.ZERO))
	var entrance_world := pivot + entrance_offset * display_scale
	var entrance_normal := _coerce_vector2(placed.get("entrance_normal", Vector2(-1.0, 0.5)))
	if entrance_normal.length_squared() <= 0.0001:
		entrance_normal = Vector2(-1.0, 0.5)
	entrance_normal = entrance_normal.normalized()
	var clearance_value: Variant = placed.get("road_side_clearance", {})
	var clearance: Dictionary = clearance_value as Dictionary if clearance_value is Dictionary else {}
	var cross_width := maxf(1.0, float(clearance.get("cross_width", 120.0)))
	var approach_depth := maxf(1.0, float(clearance.get("approach_depth", 90.0)))
	var clearance_polygon := _oriented_approach_polygon(
		entrance_world,
		entrance_normal,
		cross_width,
		approach_depth
	)
	var interaction_polygon := _oriented_approach_polygon(
		entrance_world,
		entrance_normal,
		minf(cross_width, 120.0),
		minf(approach_depth, 78.0)
	)
	var sort_anchor_offset := _coerce_vector2(placed.get("sort_anchor", Vector2.ZERO))
	var label_anchor_offset := _coerce_vector2(placed.get("label_anchor", Vector2.ZERO))
	var label_world_pos := pivot + label_anchor_offset * display_scale
	var display_name := str(placed.get("display_name", placed.get("type", "")))
	var label_size := Vector2(clampf(36.0 + float(display_name.length()) * 26.0, 114.0, 192.0), LABEL_HEIGHT_WORLD)
	placed["selection_index"] = selection_index
	placed["plot_id"] = str(plot.get("id", ""))
	placed["route_slot_index"] = int(plot.get("route_slot_index", -1))
	placed["main_node_id"] = str(plot.get("main_node_id", ""))
	placed["pivot_pos"] = pivot
	placed["visual_rect"] = Rect2(pivot - origin_pivot * display_scale, source_size * display_scale)
	placed["footprint_world_polygon"] = footprint_world
	placed["entrance_world_pos"] = entrance_world
	placed["interaction_polygon_world"] = interaction_polygon
	placed["interaction_rect"] = _polygon_aabb(interaction_polygon)
	placed["interaction_portal_id"] = "portal_%s" % str(placed.get("type", "building"))
	placed["road_side_clearance_polygon_world"] = clearance_polygon
	placed["sort_anchor_world"] = pivot + sort_anchor_offset * display_scale
	placed["y_sort_anchor"] = (pivot + sort_anchor_offset * display_scale).y
	placed["label_world_pos"] = label_world_pos
	# label_world_pos is the authored stem, not the label centre. The rectangle
	# grows to the right after a fixed map-world gap so every building shares the
	# manifest's stem_plus_rightward_half_label_width_plus_12_world contract.
	placed["label_rect_world"] = Rect2(
		label_world_pos + Vector2(LABEL_STEM_GAP_WORLD, -label_size.y * 0.5),
		label_size
	)
	placed["main_route_distance_world"] = float(plot.get("main_route_distance_world", 0.0))
	placed["approach_edge_id"] = "approach_%s" % str(plot.get("id", ""))
	return placed


static func _fill_unused_plots(
	plots: Array[Dictionary],
	buildings: Array[Dictionary],
	road_graph: Dictionary,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var decor_clusters: Array[Dictionary] = []
	for index in range(plots.size()):
		var plot: Dictionary = plots[index]
		if str(plot.get("occupied_by", "")) != "":
			continue
		var plot_class := str(plot.get("plot_class", ""))
		var kinds_value: Variant = DECOR_KINDS_BY_PLOT_CLASS.get(plot_class, ["stone_marker_cluster"])
		var kinds: Array = kinds_value as Array if kinds_value is Array else ["stone_marker_cluster"]
		var kind_index := rng.randi_range(0, maxi(0, kinds.size() - 1))
		var pivot := _coerce_vector2(plot.get("pivot_pos", Vector2.ZERO))
		var seed_jitter := Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-5.0, 5.0))
		var candidate_offsets: Array[Vector2] = [
			Vector2.ZERO,
			Vector2(70.0, -55.0),
			Vector2(-70.0, -55.0),
			Vector2(0.0, -105.0),
			Vector2(105.0, -80.0),
			Vector2(-105.0, -80.0),
		]
		var anchor := pivot + seed_jitter
		var footprint := _decor_footprint(anchor)
		for candidate_offset in candidate_offsets:
			var candidate_anchor := pivot + candidate_offset + seed_jitter
			var candidate_footprint := _decor_footprint(candidate_anchor)
			if not _decor_candidate_is_clear(
				candidate_footprint,
				_vector2_array(plot.get("boundary_polygon_world", [])),
				buildings,
				decor_clusters,
				road_graph
			):
				continue
			anchor = candidate_anchor
			footprint = candidate_footprint
			break
		var visual_size := Vector2(
			rng.randf_range(148.0, 184.0),
			rng.randf_range(100.0, 138.0)
		)
		var cluster_id := "decor_%s" % str(plot.get("id", index))
		var cluster := {
			"id": cluster_id,
			"plot_id": str(plot.get("id", "")),
			"cluster_type": str(kinds[kind_index]) if not kinds.is_empty() else "stone_marker_cluster",
			"anchor_world": anchor,
			"sort_anchor_world": anchor,
			"visual_bounds_world": Rect2(anchor - Vector2(visual_size.x * 0.5, visual_size.y), visual_size),
			"footprint_world_polygon": footprint,
			"main_route_distance_world": float(plot.get("main_route_distance_world", 0.0)),
			"blocks_navigation": true,
		}
		decor_clusters.append(cluster)
		plots[index]["decor_cluster_id"] = cluster_id
	return decor_clusters


static func _decor_footprint(anchor: Vector2) -> Array[Vector2]:
	return [
		anchor + Vector2(0.0, -54.0),
		anchor + Vector2(72.0, -18.0),
		anchor + Vector2(0.0, 18.0),
		anchor + Vector2(-72.0, -18.0),
	]


static func _decor_candidate_is_clear(
	footprint: Array[Vector2],
	plot_boundary: Array[Vector2],
	buildings: Array[Dictionary],
	existing_decor: Array[Dictionary],
	road_graph: Dictionary
) -> bool:
	for point in footprint:
		if not _point_in_or_on_polygon(point, plot_boundary):
			return false
	for building in buildings:
		if _polygon_intersection_area(footprint, _vector2_array(building.get("footprint_world_polygon", []))) > 0.01:
			return false
		if _polygon_intersection_area(footprint, _vector2_array(building.get("road_side_clearance_polygon_world", []))) > 0.01:
			return false
	for decor in existing_decor:
		if _polygon_intersection_area(footprint, _vector2_array(decor.get("footprint_world_polygon", []))) > 0.01:
			return false
	for edge in _dictionary_array(road_graph.get("edges", [])):
		var edge_half_width := float(edge.get("half_width_world", ROAD_HALF_WIDTH_WORLD))
		var polyline := _vector2_array(edge.get("polyline_world", []))
		for segment_index in range(polyline.size() - 1):
			var start := polyline[segment_index]
			var finish := polyline[segment_index + 1]
			if str(edge.get("kind", "")) == "approach" and segment_index == polyline.size() - 2:
				finish = finish.move_toward(start, edge_half_width + 1.0)
			if _polygon_intersection_area(footprint, _segment_corridor_polygon(start, finish, edge_half_width)) > 0.01:
				return false
	return true


static func _append_plot_approach_edges(
	road_graph: Dictionary,
	plots: Array[Dictionary],
	buildings: Array[Dictionary],
	world_size: Vector2
) -> void:
	var nodes := _dictionary_array(road_graph.get("nodes", []))
	var edges := _dictionary_array(road_graph.get("edges", []))
	for plot_index in range(plots.size()):
		var plot: Dictionary = plots[plot_index]
		var plot_id := str(plot.get("id", ""))
		var building_index := _find_building_index_by_plot(buildings, plot_id)
		var main_node_id := str(plot.get("main_node_id", ""))
		var main_node := _find_by_id(nodes, main_node_id)
		var main_position := _coerce_vector2(main_node.get("position", Vector2.ZERO))
		# Filler decor receives a visible narrow trail, never an interaction
		# portal. This makes the 2D parcel legible without inventing a destination.
		if building_index < 0:
			# The trail terminates in the parcel's left-side arrival court. Filler
			# placement happens after this edge is authored and must choose a clear
			# point elsewhere in the same parcel.
			var trail_anchor := _coerce_vector2(plot.get("pivot_pos", Vector2.ZERO)) + Vector2(-100.0, 0.0)
			var trail_node_id := "trail_%s" % plot_id
			var trail_edge_id := "trail_%s" % plot_id
			var trail_half_width := _canonical_road_half_width("trail")
			var trail_polyline := _route_around_other_plots(
				main_position,
				trail_anchor,
				trail_anchor.x,
				trail_half_width,
				plots,
				plot_id,
				world_size,
				false
			)
			nodes.append({
				"id": trail_node_id,
				"role": "decor_trail_end",
				"plot_id": plot_id,
				"position": trail_anchor,
			})
			edges.append({
				"id": trail_edge_id,
				"kind": "trail",
				"from": main_node_id,
				"to": trail_node_id,
				"plot_id": plot_id,
				"half_width_world": trail_half_width,
				"polyline_world": trail_polyline,
			})
			plots[plot_index]["trail_anchor_world"] = trail_anchor
			plots[plot_index]["trail_edge_id"] = trail_edge_id
			continue
		var approach := _coerce_vector2(plot.get("pivot_pos", Vector2.ZERO)) + Vector2(-100.0, -15.0)
		var approach_normal := Vector2(-1.0, 0.5).normalized()
		var approach_depth := 90.0
		approach = _coerce_vector2(buildings[building_index].get("entrance_world_pos", approach))
		approach_normal = _coerce_vector2(buildings[building_index].get("entrance_normal", approach_normal))
		if approach_normal.length_squared() <= 0.0001:
			approach_normal = Vector2(-1.0, 0.5)
		approach_normal = approach_normal.normalized()
		var clearance_value: Variant = buildings[building_index].get("road_side_clearance", {})
		var clearance: Dictionary = clearance_value as Dictionary if clearance_value is Dictionary else {}
		approach_depth = maxf(1.0, float(clearance.get("approach_depth", approach_depth)))
		var approach_node_id := "approach_%s" % plot_id
		var edge_id := "approach_%s" % plot_id
		var approach_half_width := _canonical_road_half_width("approach")
		var clearance_far := approach + approach_normal * (approach_depth + approach_half_width * 1.6)
		var footprint_bounds := _polygon_aabb(_vector2_array(buildings[building_index].get("footprint_world_polygon", [])))
		var lane_x := minf(clearance_far.x, footprint_bounds.position.x - approach_half_width - 4.0)
		var approach_polyline := _route_around_other_plots(
			main_position,
			approach,
			lane_x,
			approach_half_width,
			plots,
			plot_id,
			world_size,
			true,
			clearance_far
		)
		nodes.append({
			"id": approach_node_id,
			"role": "plot_approach",
			"plot_id": plot_id,
			"position": approach,
		})
		edges.append({
			"id": edge_id,
			"kind": "approach",
			"from": main_node_id,
			"to": approach_node_id,
			"plot_id": plot_id,
			"half_width_world": approach_half_width,
			"polyline_world": approach_polyline,
		})
		plots[plot_index]["approach_anchor_world"] = approach
		plots[plot_index]["approach_edge_id"] = edge_id
		buildings[building_index]["approach_edge_id"] = edge_id
	road_graph["nodes"] = nodes
	road_graph["edges"] = edges


static func _route_around_other_plots(
	start: Vector2,
	destination: Vector2,
	preferred_lane_x: float,
	half_width: float,
	plots: Array[Dictionary],
	owned_plot_id: String,
	world_size: Vector2,
	trim_final_segment: bool,
	pre_destination: Vector2 = Vector2(INF, INF)
) -> Array[Vector2]:
	var candidate_offsets: Array[float] = [0.0]
	for step in range(1, 17):
		candidate_offsets.append(float(step) * 40.0)
		candidate_offsets.append(float(step) * -40.0)
	for offset in candidate_offsets:
		var lane_x := clampf(preferred_lane_x + offset, half_width * 2.0, world_size.x - half_width * 2.0)
		var turn_target := destination
		if _is_finite_vector2(pre_destination):
			turn_target = pre_destination
		var candidate := _compact_polyline([
			start,
			Vector2(lane_x, start.y),
			Vector2(lane_x, turn_target.y),
			turn_target,
			destination,
		])
		if _polyline_avoids_other_plot_boundaries(candidate, half_width, plots, owned_plot_id, trim_final_segment):
			return candidate
	return _compact_polyline([start, Vector2(preferred_lane_x, start.y), destination])


static func _polyline_avoids_other_plot_boundaries(
	polyline: Array[Vector2],
	half_width: float,
	plots: Array[Dictionary],
	owned_plot_id: String,
	trim_final_segment: bool
) -> bool:
	for segment_index in range(polyline.size() - 1):
		var start := polyline[segment_index]
		var finish := polyline[segment_index + 1]
		if trim_final_segment and segment_index == polyline.size() - 2:
			finish = finish.move_toward(start, half_width + 1.0)
		var corridor := _segment_corridor_polygon(start, finish, half_width)
		if corridor.is_empty():
			continue
		for plot in plots:
			if str(plot.get("id", "")) == owned_plot_id:
				continue
			if _polygon_intersection_area(corridor, _vector2_array(plot.get("boundary_polygon_world", []))) > 0.01:
				return false
	return true


static func _build_blocked_polygons(
	buildings: Array[Dictionary],
	decor_clusters: Array[Dictionary]
) -> Array[Dictionary]:
	var blocked: Array[Dictionary] = []
	for building in buildings:
		blocked.append({
			"owner_id": str(building.get("type", "")),
			"kind": "building",
			"polygon_world": _vector2_array(building.get("footprint_world_polygon", [])),
		})
	for decor in decor_clusters:
		if not bool(decor.get("blocks_navigation", false)):
			continue
		blocked.append({
			"owner_id": str(decor.get("id", "")),
			"kind": "decor",
			"polygon_world": _vector2_array(decor.get("footprint_world_polygon", [])),
		})
	return blocked


static func _build_walkable_corridors(road_graph: Dictionary) -> Array[Dictionary]:
	var corridors: Array[Dictionary] = []
	for edge in _dictionary_array(road_graph.get("edges", [])):
		var half_width_value: Variant = edge.get("half_width_world", null)
		if not _is_finite_number(half_width_value) or float(half_width_value) <= 0.0:
			continue
		var half_width := float(half_width_value)
		var polyline := _vector2_array(edge.get("polyline_world", []))
		for segment_index in range(polyline.size() - 1):
			var start := polyline[segment_index]
			var finish := polyline[segment_index + 1]
			if str(edge.get("kind", "")) == "approach" and segment_index == polyline.size() - 2:
				finish = finish.move_toward(start, half_width + 1.0)
			corridors.append({
				"id": "%s_segment_%d" % [str(edge.get("id", "")), segment_index],
				"edge_id": str(edge.get("id", "")),
				"edge_kind": str(edge.get("kind", "")),
				"segment_index": segment_index,
				"half_width_world": half_width,
				"cap_style": WALKABLE_CAP_STYLE,
				"polygon_world": _segment_corridor_polygon(start, finish, half_width),
			})
	return corridors


static func _build_interaction_portals(buildings: Array[Dictionary]) -> Array[Dictionary]:
	var portals: Array[Dictionary] = []
	for building in buildings:
		portals.append({
			"id": str(building.get("interaction_portal_id", "")),
			"building_type": str(building.get("type", "")),
			"plot_id": str(building.get("plot_id", "")),
			"approach_edge_id": str(building.get("approach_edge_id", "")),
			"polygon_world": _vector2_array(building.get("interaction_polygon_world", [])),
		})
	return portals


static func _validate_consumed_field_contract(layout: Dictionary, violations: Array[Dictionary]) -> void:
	_require_int_field(layout, "schema_version", "layout", violations)
	_require_string_field(layout, "generator_version", "layout", true, violations)
	_require_int_field(layout, "stage_id", "layout", violations)
	_require_int_field(layout, "map_seed", "layout", violations)
	_require_bool_field(layout, "candidate_only", "layout", violations)
	_require_bool_field(layout, "production_connected", "layout", violations)
	_require_string_field(layout, "plot_assignment_signature", "layout", true, violations)
	_require_string_field(layout, "plot_boundary_overlap_policy", "layout", true, violations)
	_require_vector2_field(layout, "world_size", "layout", violations)
	_require_vector2_field(layout, "spawn_anchor", "layout", violations)
	_require_rect2_field(layout, "exit_zone", "layout", true, violations)
	_require_finite_number_field(layout, "main_route_length_world", "layout", true, violations)
	for key_value in ["road_graph", "plots", "building_specs", "decor_clusters", "blocked_polygons", "walkable_corridor_polygons", "interaction_portals", "selected_building_types"]:
		var key: String = str(key_value)
		var value: Variant = layout.get(key, null)
		var expected_dictionary: bool = key == "road_graph"
		var valid_container: bool = value is Dictionary if expected_dictionary else value is Array
		if valid_container and not expected_dictionary and key != "selected_building_types":
			valid_container = _is_dictionary_array(value)
		if valid_container and key == "selected_building_types":
			for selected_value in value as Array:
				if not (selected_value is String):
					valid_container = false
					break
		if not valid_container:
			_add_violation(violations, "consumed_field_invalid", "layout.%s" % key)
	if layout.has("walkable_hub_polygons") and not _is_dictionary_array(layout.get("walkable_hub_polygons", null)):
		_add_violation(violations, "consumed_field_invalid", "layout.walkable_hub_polygons")

	var road_value: Variant = layout.get("road_graph", {})
	var road: Dictionary = road_value as Dictionary if road_value is Dictionary else {}
	for key_value in ["skeleton_variant", "secondary_side", "spawn_node_id", "exit_node_id"]:
		_require_string_field(road, str(key_value), "road_graph", true, violations)
	_require_finite_number_field(road, "main_route_length_world", "road_graph", true, violations)
	var secondary_slots_value: Variant = road.get("secondary_anchor_slots", null)
	if not (secondary_slots_value is Array) or (secondary_slots_value as Array).size() != 2:
		_add_violation(violations, "consumed_field_invalid", "road_graph.secondary_anchor_slots")
	else:
		for slot_value in secondary_slots_value as Array:
			if not (slot_value is int):
				_add_violation(violations, "consumed_field_invalid", "road_graph.secondary_anchor_slots")
				break
	for key_value in ["nodes", "edges"]:
		var key: String = str(key_value)
		if not _is_dictionary_array(road.get(key, null)):
			_add_violation(violations, "consumed_field_invalid", "road_graph.%s" % key)
	for node in _dictionary_array(road.get("nodes", [])):
		var node_context := "road_node:%s" % str(node.get("id", ""))
		_require_string_field(node, "id", node_context, true, violations)
		_require_string_field(node, "role", node_context, true, violations)
		_require_vector2_field(node, "position", node_context, violations)
		if node.has("plot_id"):
			_require_string_field(node, "plot_id", node_context, true, violations)
		if node.has("route_distance_world"):
			_require_finite_number_field(node, "route_distance_world", node_context, false, violations)
	for edge in _dictionary_array(road.get("edges", [])):
		var edge_context := "road_edge:%s" % str(edge.get("id", ""))
		for key_value in ["id", "kind", "from", "to"]:
			_require_string_field(edge, str(key_value), edge_context, true, violations)
		if edge.has("plot_id"):
			_require_string_field(edge, "plot_id", edge_context, true, violations)
		_require_finite_number_field(edge, "half_width_world", edge_context, true, violations)
		_require_vector2_array_field(edge, "polyline_world", edge_context, violations)

	for plot in _dictionary_array(layout.get("plots", [])):
		var plot_context := "plot:%s" % str(plot.get("id", ""))
		for key_value in ["id", "plot_class", "main_node_id", "approach_side", "occupied_by", "decor_cluster_id"]:
			_require_string_field(plot, str(key_value), plot_context, str(key_value) in ["id", "plot_class", "main_node_id", "approach_side"], violations)
		_require_int_field(plot, "route_slot_index", plot_context, violations)
		_require_vector2_field(plot, "pivot_pos", plot_context, violations)
		_require_vector2_array_field(plot, "boundary_polygon_world", plot_context, violations)
		_require_finite_number_field(plot, "main_route_distance_world", plot_context, false, violations)
		if plot.has("approach_anchor_world"):
			_require_vector2_field(plot, "approach_anchor_world", plot_context, violations)
			_require_string_field(plot, "approach_edge_id", plot_context, true, violations)
		if plot.has("trail_anchor_world"):
			_require_vector2_field(plot, "trail_anchor_world", plot_context, violations)
			_require_string_field(plot, "trail_edge_id", plot_context, true, violations)

	for building in _dictionary_array(layout.get("building_specs", [])):
		var building_context := "building:%s" % str(building.get("type", ""))
		for key_value in ["type", "display_name", "plot_id", "main_node_id", "interaction_portal_id", "approach_edge_id"]:
			_require_string_field(building, str(key_value), building_context, true, violations)
		_require_int_field(building, "selection_index", building_context, violations)
		_require_int_field(building, "route_slot_index", building_context, violations)
		for key_value in ["pivot_pos", "source_size", "origin_pivot", "entrance_anchor_offset", "entrance_normal", "entrance_world_pos", "sort_anchor", "sort_anchor_world", "label_anchor", "label_anchor_source_pixels", "label_world_pos"]:
			var key: String = str(key_value)
			_require_vector2_field(building, key, building_context, violations)
		for key_value in ["visual_rect", "interaction_rect", "label_rect_world"]:
			var key: String = str(key_value)
			_require_rect2_field(building, key, building_context, true, violations)
		for key_value in ["footprint_polygon", "footprint_world_polygon", "interaction_polygon_world", "road_side_clearance_polygon_world"]:
			var key: String = str(key_value)
			_require_vector2_array_field(building, key, building_context, violations)
		for key_value in ["display_scale", "y_sort_anchor", "main_route_distance_world"]:
			var key: String = str(key_value)
			_require_finite_number_field(building, key, building_context, key == "display_scale", violations)
		var clearance_value: Variant = building.get("road_side_clearance", null)
		if not (clearance_value is Dictionary):
			_add_violation(violations, "consumed_field_invalid", "%s.road_side_clearance" % building_context)
		else:
			var clearance := clearance_value as Dictionary
			_require_finite_number_field(clearance, "cross_width", "%s.road_side_clearance" % building_context, true, violations)
			_require_finite_number_field(clearance, "approach_depth", "%s.road_side_clearance" % building_context, true, violations)

	for decor in _dictionary_array(layout.get("decor_clusters", [])):
		var decor_context := "decor:%s" % str(decor.get("id", ""))
		for key_value in ["id", "plot_id", "cluster_type"]:
			_require_string_field(decor, str(key_value), decor_context, true, violations)
		for key_value in ["anchor_world", "sort_anchor_world"]:
			var key: String = str(key_value)
			_require_vector2_field(decor, key, decor_context, violations)
		_require_rect2_field(decor, "visual_bounds_world", decor_context, true, violations)
		_require_vector2_array_field(decor, "footprint_world_polygon", decor_context, violations)
		_require_finite_number_field(decor, "main_route_distance_world", decor_context, false, violations)
		_require_bool_field(decor, "blocks_navigation", decor_context, violations)

	for blocker in _dictionary_array(layout.get("blocked_polygons", [])):
		var blocker_context := "blocker:%s:%s" % [str(blocker.get("kind", "")), str(blocker.get("owner_id", ""))]
		_require_string_field(blocker, "kind", blocker_context, true, violations)
		_require_string_field(blocker, "owner_id", blocker_context, true, violations)
		_require_vector2_array_field(
			blocker,
			"polygon_world",
			blocker_context,
			violations
		)
	for corridor in _dictionary_array(layout.get("walkable_corridor_polygons", [])):
		var corridor_context := "corridor:%s" % str(corridor.get("id", ""))
		for key_value in ["id", "edge_id", "edge_kind", "cap_style"]:
			_require_string_field(corridor, str(key_value), corridor_context, true, violations)
		_require_int_field(corridor, "segment_index", corridor_context, violations)
		_require_finite_number_field(corridor, "half_width_world", corridor_context, true, violations)
		_require_vector2_array_field(corridor, "polygon_world", corridor_context, violations)
	for hub in _dictionary_array(layout.get("walkable_hub_polygons", [])):
		var hub_context := "walkable_hub:%s" % str(hub.get("id", ""))
		for key_value in ["id", "edge_id", "edge_kind", "cap_style", "source_contract_id"]:
			_require_string_field(hub, str(key_value), hub_context, true, violations)
		_require_int_field(hub, "segment_index", hub_context, violations)
		_require_finite_number_field(hub, "half_width_world", hub_context, true, violations)
		_require_vector2_array_field(hub, "polygon_world", hub_context, violations)
	for portal in _dictionary_array(layout.get("interaction_portals", [])):
		var portal_context := "portal:%s" % str(portal.get("id", ""))
		for key_value in ["id", "building_type", "plot_id", "approach_edge_id"]:
			_require_string_field(portal, str(key_value), portal_context, true, violations)
		_require_vector2_array_field(
			portal,
			"polygon_world",
			portal_context,
			violations
		)


static func _require_vector2_field(
	owner: Dictionary,
	key: String,
	context: String,
	violations: Array[Dictionary]
) -> void:
	var value: Variant = owner.get(key, null)
	if not (value is Vector2):
		_add_violation(violations, "consumed_field_invalid", "%s.%s" % [context, key])
		return
	if not _is_finite_vector2(value as Vector2):
		_add_violation(violations, "consumed_field_invalid", "%s.%s" % [context, key])
		_add_violation(violations, "non_finite_geometry", "%s.%s" % [context, key])


static func _require_string_field(
	owner: Dictionary,
	key: String,
	context: String,
	require_non_empty: bool,
	violations: Array[Dictionary]
) -> void:
	var value: Variant = owner.get(key, null)
	if not (value is String) or (require_non_empty and (value as String).is_empty()):
		_add_violation(violations, "consumed_field_invalid", "%s.%s" % [context, key])


static func _require_int_field(
	owner: Dictionary,
	key: String,
	context: String,
	violations: Array[Dictionary]
) -> void:
	if not (owner.get(key, null) is int):
		_add_violation(violations, "consumed_field_invalid", "%s.%s" % [context, key])


static func _require_bool_field(
	owner: Dictionary,
	key: String,
	context: String,
	violations: Array[Dictionary]
) -> void:
	if not (owner.get(key, null) is bool):
		_add_violation(violations, "consumed_field_invalid", "%s.%s" % [context, key])


static func _require_rect2_field(
	owner: Dictionary,
	key: String,
	context: String,
	require_positive_size: bool,
	violations: Array[Dictionary]
) -> void:
	var value: Variant = owner.get(key, null)
	if not (value is Rect2):
		_add_violation(violations, "consumed_field_invalid", "%s.%s" % [context, key])
		return
	var rect := value as Rect2
	if not _is_finite_vector2(rect.position) or not _is_finite_vector2(rect.size) or (require_positive_size and (rect.size.x <= 0.0 or rect.size.y <= 0.0)):
		_add_violation(violations, "consumed_field_invalid", "%s.%s" % [context, key])
		if not _is_finite_vector2(rect.position) or not _is_finite_vector2(rect.size):
			_add_violation(violations, "non_finite_geometry", "%s.%s" % [context, key])


static func _require_finite_number_field(
	owner: Dictionary,
	key: String,
	context: String,
	require_positive: bool,
	violations: Array[Dictionary]
) -> void:
	var value: Variant = owner.get(key, null)
	if not _is_finite_number(value) or (require_positive and float(value) <= 0.0):
		_add_violation(violations, "consumed_field_invalid", "%s.%s" % [context, key])
		if (value is int or value is float) and not is_finite(float(value)):
			_add_violation(violations, "non_finite_geometry", "%s.%s" % [context, key])


static func _require_vector2_array_field(
	owner: Dictionary,
	key: String,
	context: String,
	violations: Array[Dictionary]
) -> void:
	var value: Variant = owner.get(key, null)
	if not _is_finite_vector2_array(value):
		_add_violation(violations, "consumed_field_invalid", "%s.%s" % [context, key])
		if value is Array or value is PackedVector2Array:
			var points := _vector2_array(value)
			var raw_size := (value as Array).size() if value is Array else (value as PackedVector2Array).size()
			if points.size() == raw_size and not _polygon_is_finite(points):
				_add_violation(violations, "non_finite_geometry", "%s.%s" % [context, key])


static func _is_dictionary_array(value: Variant) -> bool:
	if not (value is Array):
		return false
	for item in value as Array:
		if not (item is Dictionary):
			return false
	return true


static func _is_finite_vector2_array(value: Variant) -> bool:
	if not (value is Array or value is PackedVector2Array):
		return false
	var points := _vector2_array(value)
	var raw_size := (value as Array).size() if value is Array else (value as PackedVector2Array).size()
	return points.size() == raw_size and _polygon_is_finite(points)


static func _is_finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _validate_selected_building_contract(
	layout: Dictionary,
	buildings: Array[Dictionary],
	violations: Array[Dictionary]
) -> void:
	var selected_value: Variant = layout.get("selected_building_types", [])
	var selected_types: Array[String] = []
	if selected_value is Array:
		for value in selected_value as Array:
			selected_types.append(str(value))
	if selected_types.size() < MIN_SELECTED_BUILDING_COUNT or selected_types.size() > MAX_SELECTED_BUILDING_COUNT:
		_add_violation(violations, "selected_building_roster_invalid", "count=%d" % selected_types.size())
	var seen_types := {}
	var bank_count := 0
	for building_type in selected_types:
		if building_type == "bank":
			bank_count += 1
		if not KNOWN_BUILDING_TYPES.has(building_type) or seen_types.has(building_type):
			_add_violation(violations, "selected_building_roster_invalid", building_type)
		seen_types[building_type] = true
	if bank_count != 1:
		_add_violation(violations, "selected_building_roster_invalid", "bank_count=%d" % bank_count)
	if selected_types.size() != buildings.size():
		_add_violation(
			violations,
			"selected_building_contract_mismatch",
			"selected=%d placed=%d" % [selected_types.size(), buildings.size()]
		)
		return
	for index in range(buildings.size()):
		var building := buildings[index]
		if int(building.get("selection_index", -1)) != index or str(building.get("type", "")) != selected_types[index]:
			_add_violation(
				violations,
				"selected_building_contract_mismatch",
				"index=%d selected=%s placed=%s placed_index=%d" % [
					index,
					selected_types[index],
					str(building.get("type", "")),
					int(building.get("selection_index", -1)),
				]
			)


static func _validate_plot_assignment_contract(
	layout: Dictionary,
	plots: Array[Dictionary],
	violations: Array[Dictionary]
) -> void:
	var expected_class_by_id := {}
	for archetype_value in PLOT_ARCHETYPES:
		var archetype: Dictionary = archetype_value
		expected_class_by_id[str(archetype.get("id", ""))] = str(archetype.get("plot_class", ""))
	var seen_slots := {}
	var seen_ids := {}
	for plot in plots:
		var plot_id := str(plot.get("id", ""))
		var plot_class := str(plot.get("plot_class", ""))
		var slot_index := int(plot.get("route_slot_index", -1))
		if not expected_class_by_id.has(plot_id) or str(expected_class_by_id.get(plot_id, "")) != plot_class or seen_ids.has(plot_id):
			_add_violation(violations, "plot_assignment_contract_mismatch", "id:%s class:%s" % [plot_id, plot_class])
		seen_ids[plot_id] = true
		if slot_index < 0 or slot_index >= PLOT_ROUTE_SLOTS.size() or seen_slots.has(slot_index):
			_add_violation(violations, "plot_assignment_contract_mismatch", "slot:%d" % slot_index)
			continue
		seen_slots[slot_index] = true
		var slot: Dictionary = PLOT_ROUTE_SLOTS[slot_index]
		var expected_group := str(slot.get("size_group", ""))
		var class_matches_slot := (
			(expected_group == "regular" and not LARGE_PLOT_CLASSES.has(plot_class))
			or (expected_group == "large_landmark" and ["rear_landmark_large", "intersection_large"].has(plot_class))
			or (expected_group == "edge_large" and plot_class == "edge_large")
		)
		if not class_matches_slot or str(plot.get("main_node_id", "")) != "main_%d" % slot_index:
			_add_violation(violations, "plot_assignment_contract_mismatch", "slot:%d class:%s node:%s" % [slot_index, plot_class, str(plot.get("main_node_id", ""))])
	if seen_ids.size() != PLOT_ARCHETYPES.size() or seen_slots.size() != PLOT_ROUTE_SLOTS.size():
		_add_violation(violations, "plot_assignment_contract_mismatch", "incomplete assignment")
	if str(layout.get("plot_assignment_signature", "")) != _plot_assignment_signature(plots):
		_add_violation(violations, "plot_assignment_signature_mismatch", "stored signature does not match plots")


static func _validate_road_graph(
	layout: Dictionary,
	world_size: Vector2,
	violations: Array[Dictionary]
) -> void:
	var road_value: Variant = layout.get("road_graph", {})
	var road: Dictionary = road_value as Dictionary if road_value is Dictionary else {}
	var expected_motif_index := posmod(int(layout.get("map_seed", 0)), ROAD_SKELETON_MOTIFS.size())
	var expected_motif: Dictionary = ROAD_SKELETON_MOTIFS[expected_motif_index]
	if str(road.get("skeleton_variant", "")) != str(expected_motif.get("id", "")):
		_add_violation(violations, "road_skeleton_variant_mismatch", str(road.get("skeleton_variant", "")))
	if str(road.get("secondary_side", "")) != str(expected_motif.get("secondary_side", "")) or road.get("secondary_anchor_slots", []) != expected_motif.get("secondary_anchor_slots", []):
		_add_violation(violations, "road_secondary_motif_mismatch", str(road.get("secondary_side", "")))
	var nodes := _dictionary_array(road.get("nodes", []))
	var edges := _dictionary_array(road.get("edges", []))
	var node_ids := {}
	for node in nodes:
		var node_id := str(node.get("id", ""))
		if node_id == "" or node_ids.has(node_id):
			_add_violation(violations, "invalid_road_node", "road node ids must be non-empty and unique")
			continue
		var node_position := _coerce_vector2(node.get("position", Vector2.ZERO))
		if not _is_finite_vector2(node_position):
			_add_violation(violations, "non_finite_geometry", "road_node:%s" % node_id)
		elif node_position.x < -0.01 or node_position.y < -0.01 or node_position.x > world_size.x + 0.01 or node_position.y > world_size.y + 0.01:
			_add_violation(violations, "road_node_out_of_world", node_id)
		node_ids[node_id] = true
	var adjacency := {}
	var edge_ids := {}
	for node_id_value in node_ids.keys():
		adjacency[str(node_id_value)] = []
	for edge in edges:
		var edge_id := str(edge.get("id", ""))
		if edge_id == "" or edge_ids.has(edge_id):
			_add_violation(violations, "invalid_road_edge", edge_id)
		else:
			edge_ids[edge_id] = true
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		var edge_kind := str(edge.get("kind", ""))
		var expected_half_width := _canonical_road_half_width(edge_kind)
		if expected_half_width <= 0.0 or not is_equal_approx(float(edge.get("half_width_world", -1.0)), expected_half_width):
			_add_violation(
				violations,
				"road_half_width_contract_mismatch",
				"%s:%s expected=%.3f actual=%.3f" % [edge_id, edge_kind, expected_half_width, float(edge.get("half_width_world", -1.0))]
			)
		if not node_ids.has(from_id) or not node_ids.has(to_id):
			_add_violation(violations, "road_edge_missing_node", str(edge.get("id", "")))
			continue
		var polyline := _vector2_array(edge.get("polyline_world", []))
		if polyline.size() < 2:
			_add_violation(violations, "road_edge_polyline_invalid", str(edge.get("id", "")))
		else:
			for point in polyline:
				if not _is_finite_vector2(point):
					_add_violation(violations, "non_finite_geometry", "road_edge:%s" % str(edge.get("id", "")))
					break
			for segment_index in range(polyline.size() - 1):
				if polyline[segment_index].distance_squared_to(polyline[segment_index + 1]) <= 0.0001:
					_add_violation(violations, "road_edge_segment_degenerate", "%s:%d" % [edge_id, segment_index])
			var from_node := _find_by_id(nodes, from_id)
			var to_node := _find_by_id(nodes, to_id)
			if not polyline[0].is_equal_approx(_coerce_vector2(from_node.get("position", Vector2.ZERO))) or not polyline[polyline.size() - 1].is_equal_approx(_coerce_vector2(to_node.get("position", Vector2.ZERO))):
				_add_violation(violations, "road_edge_endpoint_mismatch", str(edge.get("id", "")))
		(adjacency[from_id] as Array).append(to_id)
		(adjacency[to_id] as Array).append(from_id)
	_validate_exact_main_route_topology(nodes, edges, violations)
	_validate_exact_full_road_topology(layout, nodes, edges, expected_motif, violations)
	var spawn_id := str(road.get("spawn_node_id", ""))
	var exit_id := str(road.get("exit_node_id", ""))
	if not node_ids.has(spawn_id) or not node_ids.has(exit_id):
		_add_violation(violations, "missing_spawn_or_exit_node", "road graph requires spawn and exit nodes")
		return
	var spawn_value: Variant = layout.get("spawn_anchor", null)
	var exit_value: Variant = layout.get("exit_zone", null)
	if spawn_value is Vector2 and not _coerce_vector2(_find_by_id(nodes, spawn_id).get("position", Vector2.ZERO)).is_equal_approx(spawn_value as Vector2):
		_add_violation(violations, "anchor_contract_mismatch", "spawn")
	if exit_value is Rect2 and not _coerce_vector2(_find_by_id(nodes, exit_id).get("position", Vector2.ZERO)).is_equal_approx((exit_value as Rect2).get_center()):
		_add_violation(violations, "anchor_contract_mismatch", "exit")
	var visited := {spawn_id: true}
	var queue: Array[String] = [spawn_id]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for next_value in adjacency.get(current, []):
			var next_id := str(next_value)
			if visited.has(next_id):
				continue
			visited[next_id] = true
			queue.append(next_id)
	if not visited.has(exit_id):
		_add_violation(violations, "exit_disconnected", "spawn cannot reach exit through road edges")
	for plot in _dictionary_array(layout.get("plots", [])):
		var plot_id := str(plot.get("id", ""))
		if str(plot.get("occupied_by", "")) == "":
			var trail_node_id := "trail_%s" % plot_id
			if not visited.has(trail_node_id):
				_add_violation(violations, "plot_trail_disconnected", plot_id)
		else:
			var approach_node_id := "approach_%s" % plot_id
			if not visited.has(approach_node_id):
				_add_violation(violations, "plot_approach_disconnected", plot_id)
	var cycle_rank := _structural_cycle_rank(road)
	var secondary_edge_count := 0
	for edge in edges:
		if str(edge.get("kind", "")) == "secondary":
			secondary_edge_count += 1
	if secondary_edge_count < 3 or cycle_rank < 1:
		_add_violation(violations, "secondary_cycle_missing", "edges=%d rank=%d" % [secondary_edge_count, cycle_rank])
	_validate_secondary_cycle_contract(road, expected_motif, violations)
	var main_geometry := _compute_main_route_geometry(layout)
	if not bool(main_geometry.get("valid", false)):
		_add_violation(violations, "main_route_geometry_invalid", str(main_geometry.get("detail", "")))
	else:
		var computed_length := float(main_geometry.get("route_length_world", 0.0))
		if not is_equal_approx(float(road.get("main_route_length_world", -1.0)), computed_length) or not is_equal_approx(float(layout.get("main_route_length_world", -1.0)), computed_length):
			_add_violation(violations, "main_route_length_mismatch", "computed=%.3f" % computed_length)


static func _validate_exact_main_route_topology(
	nodes: Array[Dictionary],
	edges: Array[Dictionary],
	violations: Array[Dictionary]
) -> void:
	var expected_node_roles := {"spawn": "spawn", "exit": "exit"}
	for index in range(REQUIRED_PLOT_COUNT):
		expected_node_roles["main_%d" % index] = "main_plot_junction"
	var seen_structural_nodes := {}
	for node in nodes:
		var role := str(node.get("role", ""))
		if not ["spawn", "main_plot_junction", "exit"].has(role):
			continue
		var node_id := str(node.get("id", ""))
		if not expected_node_roles.has(node_id) or str(expected_node_roles.get(node_id, "")) != role or seen_structural_nodes.has(node_id):
			_add_violation(violations, "main_route_topology_mismatch", "node:%s:%s" % [node_id, role])
		seen_structural_nodes[node_id] = true
	if seen_structural_nodes.size() != expected_node_roles.size():
		_add_violation(violations, "main_route_topology_mismatch", "node_count=%d expected=%d" % [seen_structural_nodes.size(), expected_node_roles.size()])

	var expected_edges := {}
	var ordered_ids: Array[String] = ["spawn"]
	for index in range(REQUIRED_PLOT_COUNT):
		ordered_ids.append("main_%d" % index)
	ordered_ids.append("exit")
	for index in range(ordered_ids.size() - 1):
		var from_id := ordered_ids[index]
		var to_id := ordered_ids[index + 1]
		expected_edges["main_%s_to_%s" % [from_id, to_id]] = [from_id, to_id]
	var seen_main_edges := {}
	for edge in edges:
		if str(edge.get("kind", "")) != "main":
			continue
		var edge_id := str(edge.get("id", ""))
		var endpoints_value: Variant = expected_edges.get(edge_id, null)
		var endpoints: Array = endpoints_value as Array if endpoints_value is Array else []
		if endpoints.size() != 2 or str(edge.get("from", "")) != str(endpoints[0]) or str(edge.get("to", "")) != str(endpoints[1]) or seen_main_edges.has(edge_id):
			_add_violation(violations, "main_route_topology_mismatch", "edge:%s:%s:%s" % [edge_id, str(edge.get("from", "")), str(edge.get("to", ""))])
		seen_main_edges[edge_id] = true
	if seen_main_edges.size() != expected_edges.size():
		_add_violation(violations, "main_route_topology_mismatch", "edge_count=%d expected=%d" % [seen_main_edges.size(), expected_edges.size()])


static func _validate_exact_full_road_topology(
	layout: Dictionary,
	nodes: Array[Dictionary],
	edges: Array[Dictionary],
	motif: Dictionary,
	violations: Array[Dictionary]
) -> void:
	var expected_nodes := {
		"spawn": {"role": "spawn", "plot_id": ""},
		"exit": {"role": "exit", "plot_id": ""},
		"secondary_left": {"role": "secondary_hub", "plot_id": ""},
		"secondary_right": {"role": "secondary_hub", "plot_id": ""},
	}
	for index in range(REQUIRED_PLOT_COUNT):
		expected_nodes["main_%d" % index] = {"role": "main_plot_junction", "plot_id": ""}
	var expected_edges := {}
	var ordered_main_ids: Array[String] = ["spawn"]
	for index in range(REQUIRED_PLOT_COUNT):
		ordered_main_ids.append("main_%d" % index)
	ordered_main_ids.append("exit")
	for index in range(ordered_main_ids.size() - 1):
		var from_id := ordered_main_ids[index]
		var to_id := ordered_main_ids[index + 1]
		expected_edges["main_%s_to_%s" % [from_id, to_id]] = {
			"kind": "main", "from": from_id, "to": to_id, "plot_id": "",
		}
	var slots_value: Variant = motif.get("secondary_anchor_slots", [])
	var slots: Array = slots_value as Array if slots_value is Array else []
	if slots.size() == 2:
		var left_slot := int(slots[0])
		var right_slot := int(slots[1])
		expected_edges["secondary_from_main_%d" % left_slot] = {
			"kind": "secondary", "from": "main_%d" % left_slot, "to": "secondary_left", "plot_id": "",
		}
		expected_edges["secondary_hub_span"] = {
			"kind": "secondary", "from": "secondary_left", "to": "secondary_right", "plot_id": "",
		}
		expected_edges["secondary_to_main_%d" % right_slot] = {
			"kind": "secondary", "from": "secondary_right", "to": "main_%d" % right_slot, "plot_id": "",
		}

	for plot in _dictionary_array(layout.get("plots", [])):
		var plot_id := str(plot.get("id", ""))
		var main_node_id := str(plot.get("main_node_id", ""))
		var occupied := str(plot.get("occupied_by", "")) != ""
		var branch_prefix := "approach" if occupied else "trail"
		var branch_id := "%s_%s" % [branch_prefix, plot_id]
		var expected_role := "plot_approach" if occupied else "decor_trail_end"
		expected_nodes[branch_id] = {"role": expected_role, "plot_id": plot_id}
		expected_edges[branch_id] = {
			"kind": branch_prefix,
			"from": main_node_id,
			"to": branch_id,
			"plot_id": plot_id,
		}
		var anchor_key := "%s_anchor_world" % branch_prefix
		var edge_key := "%s_edge_id" % branch_prefix
		var opposite_prefix := "trail" if occupied else "approach"
		if not plot.has(anchor_key) or str(plot.get(edge_key, "")) != branch_id or plot.has("%s_anchor_world" % opposite_prefix) or plot.has("%s_edge_id" % opposite_prefix):
			_add_violation(violations, "road_topology_mismatch", "plot_branch_fields:%s" % plot_id)

	if nodes.size() != expected_nodes.size():
		_add_violation(violations, "road_topology_mismatch", "node_count=%d expected=%d" % [nodes.size(), expected_nodes.size()])
	var seen_node_ids := {}
	for node in nodes:
		var node_id := str(node.get("id", ""))
		var node_expected_value: Variant = expected_nodes.get(node_id, null)
		var node_expected: Dictionary = node_expected_value as Dictionary if node_expected_value is Dictionary else {}
		if node_expected.is_empty() or seen_node_ids.has(node_id) or str(node.get("role", "")) != str(node_expected.get("role", "")) or str(node.get("plot_id", "")) != str(node_expected.get("plot_id", "")):
			_add_violation(violations, "road_topology_mismatch", "node:%s" % node_id)
		seen_node_ids[node_id] = true
		var expected_plot_id := str(node_expected.get("plot_id", ""))
		if expected_plot_id != "":
			var plot := _find_by_id(_dictionary_array(layout.get("plots", [])), expected_plot_id)
			var anchor_key := "%s_anchor_world" % ("approach" if str(node_expected.get("role", "")) == "plot_approach" else "trail")
			if plot.is_empty() or not _coerce_vector2(node.get("position", Vector2.ZERO)).is_equal_approx(_coerce_vector2(plot.get(anchor_key, Vector2.ZERO))):
				_add_violation(violations, "road_topology_mismatch", "node_anchor:%s" % node_id)
	if seen_node_ids.size() != expected_nodes.size():
		_add_violation(violations, "road_topology_mismatch", "node_set")

	if edges.size() != expected_edges.size():
		_add_violation(violations, "road_topology_mismatch", "edge_count=%d expected=%d" % [edges.size(), expected_edges.size()])
	var seen_edge_ids := {}
	for edge in edges:
		var edge_id := str(edge.get("id", ""))
		var edge_expected_value: Variant = expected_edges.get(edge_id, null)
		var edge_expected: Dictionary = edge_expected_value as Dictionary if edge_expected_value is Dictionary else {}
		if edge_expected.is_empty() or seen_edge_ids.has(edge_id) or str(edge.get("kind", "")) != str(edge_expected.get("kind", "")) or str(edge.get("from", "")) != str(edge_expected.get("from", "")) or str(edge.get("to", "")) != str(edge_expected.get("to", "")) or str(edge.get("plot_id", "")) != str(edge_expected.get("plot_id", "")):
			_add_violation(violations, "road_topology_mismatch", "edge:%s" % edge_id)
		seen_edge_ids[edge_id] = true
	if seen_edge_ids.size() != expected_edges.size():
		_add_violation(violations, "road_topology_mismatch", "edge_set")


static func _structural_cycle_rank(road: Dictionary) -> int:
	var adjacency := {}
	var edge_count := 0
	for edge in _dictionary_array(road.get("edges", [])):
		if not ["main", "secondary"].has(str(edge.get("kind", ""))):
			continue
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		if from_id == "" or to_id == "":
			continue
		if not adjacency.has(from_id):
			adjacency[from_id] = []
		if not adjacency.has(to_id):
			adjacency[to_id] = []
		(adjacency[from_id] as Array).append(to_id)
		(adjacency[to_id] as Array).append(from_id)
		edge_count += 1
	var visited := {}
	var component_count := 0
	for node_value in adjacency.keys():
		var node_id := str(node_value)
		if visited.has(node_id):
			continue
		component_count += 1
		visited[node_id] = true
		var queue: Array[String] = [node_id]
		while not queue.is_empty():
			var current: String = queue.pop_front()
			for next_value in adjacency.get(current, []):
				var next_id := str(next_value)
				if visited.has(next_id):
					continue
				visited[next_id] = true
				queue.append(next_id)
	return maxi(0, edge_count - adjacency.size() + component_count)


static func _validate_secondary_cycle_contract(
	road: Dictionary,
	motif: Dictionary,
	violations: Array[Dictionary]
) -> void:
	var nodes := _dictionary_array(road.get("nodes", []))
	var edges := _dictionary_array(road.get("edges", []))
	var slots_value: Variant = motif.get("secondary_anchor_slots", [])
	if not (slots_value is Array) or (slots_value as Array).size() != 2:
		_add_violation(violations, "secondary_cycle_contract_mismatch", "motif slots")
		return
	var left_slot := int((slots_value as Array)[0])
	var right_slot := int((slots_value as Array)[1])
	var left_hub := _find_by_id(nodes, "secondary_left")
	var right_hub := _find_by_id(nodes, "secondary_right")
	var left_main := _find_by_id(nodes, "main_%d" % left_slot)
	var right_main := _find_by_id(nodes, "main_%d" % right_slot)
	if left_hub.is_empty() or right_hub.is_empty() or str(left_hub.get("role", "")) != "secondary_hub" or str(right_hub.get("role", "")) != "secondary_hub":
		_add_violation(violations, "secondary_cycle_contract_mismatch", "hub roles")
		return
	var expected_edges := {
		"secondary_from_main_%d" % left_slot: ["main_%d" % left_slot, "secondary_left"],
		"secondary_hub_span": ["secondary_left", "secondary_right"],
		"secondary_to_main_%d" % right_slot: ["secondary_right", "main_%d" % right_slot],
	}
	var secondary_count := 0
	for edge in edges:
		if str(edge.get("kind", "")) != "secondary":
			continue
		secondary_count += 1
		var edge_id := str(edge.get("id", ""))
		if not expected_edges.has(edge_id):
			_add_violation(violations, "secondary_cycle_contract_mismatch", "unexpected:%s" % edge_id)
			continue
		var endpoints_value: Variant = expected_edges.get(edge_id, [])
		var endpoints: Array = endpoints_value as Array if endpoints_value is Array else []
		if endpoints.size() != 2 or str(edge.get("from", "")) != str(endpoints[0]) or str(edge.get("to", "")) != str(endpoints[1]):
			_add_violation(violations, "secondary_cycle_contract_mismatch", "endpoints:%s" % edge_id)
	if secondary_count != 3:
		_add_violation(violations, "secondary_cycle_contract_mismatch", "edge_count=%d" % secondary_count)
	var left_hub_position := _coerce_vector2(left_hub.get("position", Vector2.ZERO))
	var right_hub_position := _coerce_vector2(right_hub.get("position", Vector2.ZERO))
	var left_main_position := _coerce_vector2(left_main.get("position", Vector2.ZERO))
	var right_main_position := _coerce_vector2(right_main.get("position", Vector2.ZERO))
	if absf(left_hub_position.y - left_main_position.y) < 80.0 or absf(right_hub_position.y - right_main_position.y) < 80.0 or absf(left_hub_position.y - right_hub_position.y) > 0.01 or left_hub_position.distance_to(right_hub_position) < 240.0:
		_add_violation(violations, "secondary_cycle_contract_mismatch", "hubs are not an off-spine span")


static func _validate_plot_occupancy(
	plots: Array[Dictionary],
	buildings: Array[Dictionary],
	decor_clusters: Array[Dictionary],
	violations: Array[Dictionary],
	metrics: Dictionary
) -> void:
	var building_by_plot := {}
	for building in buildings:
		var plot_id := str(building.get("plot_id", ""))
		if plot_id == "":
			_add_violation(violations, "building_plot_missing", str(building.get("type", "")))
			continue
		if building_by_plot.has(plot_id):
			_add_violation(violations, "duplicate_building_plot", plot_id)
		building_by_plot[plot_id] = str(building.get("type", ""))
	var decor_counts := {}
	for decor in decor_clusters:
		var plot_id := str(decor.get("plot_id", ""))
		decor_counts[plot_id] = int(decor_counts.get(plot_id, 0)) + 1
		var bounds_value: Variant = decor.get("visual_bounds_world", null)
		if not (bounds_value is Rect2):
			continue
		var bounds := bounds_value as Rect2
		if bounds.size.x < MIN_DECOR_VISUAL_SIZE.x or bounds.size.y < MIN_DECOR_VISUAL_SIZE.y:
			_add_violation(violations, "decor_visual_bounds_too_small", str(decor.get("id", "")))
	var unused_count := 0
	for plot in plots:
		var plot_id := str(plot.get("id", ""))
		var occupied_by := str(plot.get("occupied_by", ""))
		if occupied_by == "":
			unused_count += 1
			if int(decor_counts.get(plot_id, 0)) != 1:
				_add_violation(violations, "unused_plot_unfilled", plot_id)
		elif not building_by_plot.has(plot_id) or str(building_by_plot.get(plot_id, "")) != occupied_by:
			_add_violation(violations, "plot_occupancy_mismatch", plot_id)
		if occupied_by != "" and int(decor_counts.get(plot_id, 0)) > 0:
			_add_violation(violations, "decor_on_occupied_plot", plot_id)
	metrics["unused_plot_count"] = unused_count


static func _validate_building_geometry(
	buildings: Array[Dictionary],
	decor_clusters: Array[Dictionary],
	world_size: Vector2,
	violations: Array[Dictionary]
) -> void:
	for building in buildings:
		var building_type := str(building.get("type", ""))
		var pivot := _coerce_vector2(building.get("pivot_pos", Vector2.ZERO))
		var source_size := _coerce_vector2(building.get("source_size", Vector2.ZERO))
		var origin_pivot := _coerce_vector2(building.get("origin_pivot", Vector2.ZERO))
		var entrance_offset := _coerce_vector2(building.get("entrance_anchor_offset", Vector2.ZERO))
		var entrance_normal := _coerce_vector2(building.get("entrance_normal", Vector2.ZERO))
		var sort_anchor := _coerce_vector2(building.get("sort_anchor", Vector2.ZERO))
		var label_anchor := _coerce_vector2(building.get("label_anchor", Vector2.ZERO))
		var label_source_pixels := _coerce_vector2(building.get("label_anchor_source_pixels", Vector2.ZERO))
		var display_scale := float(building.get("display_scale", 0.0))
		var clearance_value: Variant = building.get("road_side_clearance", {})
		var clearance: Dictionary = clearance_value as Dictionary if clearance_value is Dictionary else {}
		var cross_width := float(clearance.get("cross_width", 0.0))
		var approach_depth := float(clearance.get("approach_depth", 0.0))
		var visual_value: Variant = building.get("visual_rect", null)
		if visual_value is Rect2:
			var visual_rect := visual_value as Rect2
			if visual_rect.position.x < -0.01 or visual_rect.position.y < -0.01 or visual_rect.end.x > world_size.x + 0.01 or visual_rect.end.y > world_size.y + 0.01:
				_add_violation(violations, "building_visual_out_of_world", building_type)
			var expected_visual := Rect2(pivot - origin_pivot * display_scale, source_size * display_scale)
			if not visual_rect.is_equal_approx(expected_visual):
				_add_violation(violations, "building_authored_transform_mismatch", "%s:visual" % building_type)
		var footprint := _vector2_array(building.get("footprint_world_polygon", []))
		var source_footprint := _vector2_array(building.get("footprint_polygon", []))
		if footprint.size() < 3:
			_add_violation(violations, "building_footprint_invalid", building_type)
			continue
		if not _polygon_is_finite(footprint):
			_add_violation(violations, "non_finite_geometry", "building:%s" % building_type)
			continue
		if absf(_array_polygon_signed_area(footprint)) <= 1.0:
			_add_violation(violations, "building_footprint_area_invalid", building_type)
		if source_footprint.size() != footprint.size():
			_add_violation(violations, "building_authored_transform_mismatch", "%s:footprint_count" % building_type)
		else:
			for index in range(footprint.size()):
				if not footprint[index].is_equal_approx(pivot + source_footprint[index] * display_scale):
					_add_violation(violations, "building_authored_transform_mismatch", "%s:footprint:%d" % [building_type, index])
					break
		var entrance_world := _coerce_vector2(building.get("entrance_world_pos", Vector2.ZERO))
		if not entrance_world.is_equal_approx(pivot + entrance_offset * display_scale):
			_add_violation(violations, "building_authored_transform_mismatch", "%s:entrance" % building_type)
		if entrance_normal.length_squared() <= 0.0001:
			_add_violation(violations, "building_authored_transform_mismatch", "%s:entrance_normal" % building_type)
		else:
			var normalized_entrance := entrance_normal.normalized()
			var expected_clearance := _oriented_approach_polygon(entrance_world, normalized_entrance, cross_width, approach_depth)
			var expected_interaction := _oriented_approach_polygon(entrance_world, normalized_entrance, minf(cross_width, 120.0), minf(approach_depth, 78.0))
			if not _polygons_equal_approx(_vector2_array(building.get("road_side_clearance_polygon_world", [])), expected_clearance):
				_add_violation(violations, "building_authored_transform_mismatch", "%s:clearance" % building_type)
			if not _polygons_equal_approx(_vector2_array(building.get("interaction_polygon_world", [])), expected_interaction):
				_add_violation(violations, "building_authored_transform_mismatch", "%s:interaction" % building_type)
		var sort_world := _coerce_vector2(building.get("sort_anchor_world", Vector2.ZERO))
		var expected_sort_world := pivot + sort_anchor * display_scale
		if not sort_world.is_equal_approx(expected_sort_world) or not is_equal_approx(float(building.get("y_sort_anchor", INF)), expected_sort_world.y):
			_add_violation(violations, "building_authored_transform_mismatch", "%s:sort" % building_type)
		if not label_anchor.is_equal_approx(label_source_pixels - origin_pivot):
			_add_violation(violations, "building_authored_transform_mismatch", "%s:label_source" % building_type)
		if not _coerce_vector2(building.get("label_world_pos", Vector2.ZERO)).is_equal_approx(pivot + label_anchor * display_scale):
			_add_violation(violations, "building_authored_transform_mismatch", "%s:label_world" % building_type)
		var interaction_rect_value: Variant = building.get("interaction_rect", null)
		if interaction_rect_value is Rect2 and not (interaction_rect_value as Rect2).is_equal_approx(_polygon_aabb(_vector2_array(building.get("interaction_polygon_world", [])))):
			_add_violation(violations, "building_authored_transform_mismatch", "%s:interaction_rect" % building_type)
		for polygon_key in ["interaction_polygon_world", "road_side_clearance_polygon_world"]:
			var authored_polygon := _vector2_array(building.get(polygon_key, []))
			if authored_polygon.size() < 3 or absf(_array_polygon_signed_area(authored_polygon)) <= 1.0:
				_add_violation(violations, "building_authored_polygon_area_invalid", "%s:%s" % [building_type, polygon_key])
		for point in footprint:
			if point.x < -0.01 or point.y < -0.01 or point.x > world_size.x + 0.01 or point.y > world_size.y + 0.01:
				_add_violation(violations, "building_footprint_out_of_world", building_type)
				break
	for decor in decor_clusters:
		var decor_id := str(decor.get("id", "decor"))
		var anchor := _coerce_vector2(decor.get("anchor_world", Vector2.ZERO))
		var footprint := _vector2_array(decor.get("footprint_world_polygon", []))
		if footprint.size() < 3:
			_add_violation(violations, "decor_footprint_invalid", decor_id)
			continue
		if not _polygon_is_finite(footprint):
			_add_violation(violations, "non_finite_geometry", "decor:%s" % decor_id)
			continue
		if absf(_array_polygon_signed_area(footprint)) <= 1.0:
			_add_violation(violations, "decor_footprint_area_invalid", decor_id)
		if not _polygons_equal_approx(footprint, _decor_footprint(anchor)):
			_add_violation(violations, "decor_authored_transform_mismatch", "%s:footprint" % decor_id)
		if not _coerce_vector2(decor.get("sort_anchor_world", Vector2.ZERO)).is_equal_approx(anchor):
			_add_violation(violations, "decor_authored_transform_mismatch", "%s:sort" % decor_id)
		var visual_value: Variant = decor.get("visual_bounds_world", null)
		if visual_value is Rect2:
			var visual := visual_value as Rect2
			var visual_bottom_center := Vector2(visual.get_center().x, visual.end.y)
			if not visual_bottom_center.is_equal_approx(anchor):
				_add_violation(violations, "decor_authored_transform_mismatch", "%s:visual_anchor" % decor_id)
		for point in footprint:
			if point.x < -0.01 or point.y < -0.01 or point.x > world_size.x + 0.01 or point.y > world_size.y + 0.01:
				_add_violation(violations, "decor_footprint_out_of_world", decor_id)
				break
	for left_index in range(buildings.size()):
		var left := buildings[left_index]
		var left_polygon := _vector2_array(left.get("footprint_world_polygon", []))
		for right_index in range(left_index + 1, buildings.size()):
			var right := buildings[right_index]
			var right_polygon := _vector2_array(right.get("footprint_world_polygon", []))
			if _polygon_intersection_area(left_polygon, right_polygon) > 0.01:
				_add_violation(
					violations,
					"building_footprint_overlap",
					"%s:%s" % [str(left.get("type", "")), str(right.get("type", ""))]
				)
	for building in buildings:
		var building_polygon := _vector2_array(building.get("footprint_world_polygon", []))
		for decor in decor_clusters:
			var decor_polygon := _vector2_array(decor.get("footprint_world_polygon", []))
			if _polygon_intersection_area(building_polygon, decor_polygon) > 0.01:
				_add_violation(
					violations,
					"building_decor_footprint_overlap",
					"%s:%s" % [str(building.get("type", "")), str(decor.get("id", ""))]
				)
	for left_index in range(decor_clusters.size()):
		var left := decor_clusters[left_index]
		var left_polygon := _vector2_array(left.get("footprint_world_polygon", []))
		for right_index in range(left_index + 1, decor_clusters.size()):
			var right := decor_clusters[right_index]
			var right_polygon := _vector2_array(right.get("footprint_world_polygon", []))
			if _polygon_intersection_area(left_polygon, right_polygon) > 0.01:
				_add_violation(
					violations,
					"decor_footprint_overlap",
					"%s:%s" % [str(left.get("id", "")), str(right.get("id", ""))]
				)
	for building in buildings:
		var clearance := _vector2_array(building.get("road_side_clearance_polygon_world", []))
		if clearance.size() < 3:
			_add_violation(violations, "building_clearance_invalid", str(building.get("type", "")))
			continue
		if not _polygon_is_finite(clearance):
			_add_violation(violations, "non_finite_geometry", "clearance:%s" % str(building.get("type", "")))
			continue
		for other in buildings:
			if other == building:
				continue
			if _polygon_intersection_area(clearance, _vector2_array(other.get("footprint_world_polygon", []))) > 0.01:
				_add_violation(
					violations,
					"clearance_overlap",
					"%s:%s" % [str(building.get("type", "")), str(other.get("type", ""))]
				)
		for decor in decor_clusters:
			if _polygon_intersection_area(clearance, _vector2_array(decor.get("footprint_world_polygon", []))) > 0.01:
				_add_violation(
					violations,
					"clearance_overlap",
					"%s:%s" % [str(building.get("type", "")), str(decor.get("id", ""))]
				)


static func _validate_plot_boundaries(
	plots: Array[Dictionary],
	buildings: Array[Dictionary],
	decor_clusters: Array[Dictionary],
	world_size: Vector2,
	violations: Array[Dictionary]
) -> void:
	var boundaries_by_plot := {}
	for plot in plots:
		var plot_id := str(plot.get("id", ""))
		var boundary := _vector2_array(plot.get("boundary_polygon_world", []))
		if plot_id == "" or boundaries_by_plot.has(plot_id):
			_add_violation(violations, "invalid_plot_id", plot_id)
			continue
		if boundary.size() < 3 or not _polygon_is_finite(boundary) or absf(_array_polygon_signed_area(boundary)) <= 1.0:
			_add_violation(violations, "plot_boundary_invalid", plot_id)
			continue
		for point in boundary:
			if point.x < -0.01 or point.y < -0.01 or point.x > world_size.x + 0.01 or point.y > world_size.y + 0.01:
				_add_violation(violations, "plot_boundary_out_of_world", "%s:%s" % [plot_id, _vector_token(point)])
				break
		boundaries_by_plot[plot_id] = boundary
	for left_index in range(plots.size()):
		var left := plots[left_index]
		var left_boundary := _vector2_array(left.get("boundary_polygon_world", []))
		for right_index in range(left_index + 1, plots.size()):
			var right := plots[right_index]
			var right_boundary := _vector2_array(right.get("boundary_polygon_world", []))
			if _polygon_intersection_area(left_boundary, right_boundary) > 0.01:
				_add_violation(
					violations,
					"plot_boundary_overlap",
					"%s:%s" % [str(left.get("id", "")), str(right.get("id", ""))]
				)
	for building in buildings:
		_validate_blocker_inside_plot(
			str(building.get("plot_id", "")),
			str(building.get("type", "building")),
			"building_outside_plot_boundary",
			_vector2_array(building.get("footprint_world_polygon", [])),
			boundaries_by_plot,
			violations
		)
	for decor in decor_clusters:
		_validate_blocker_inside_plot(
			str(decor.get("plot_id", "")),
			str(decor.get("id", "decor")),
			"decor_outside_plot_boundary",
			_vector2_array(decor.get("footprint_world_polygon", [])),
			boundaries_by_plot,
			violations
		)


static func _validate_label_rects(
	buildings: Array[Dictionary],
	decor_clusters: Array[Dictionary],
	world_size: Vector2,
	allow_world_fit_direction: bool,
	violations: Array[Dictionary]
) -> void:
	for index in range(buildings.size()):
		var building := buildings[index]
		var rect_value: Variant = building.get("label_rect_world", null)
		if not (rect_value is Rect2):
			continue
		var label_rect := rect_value as Rect2
		var label_stem := _coerce_vector2(building.get("label_world_pos", Vector2.ZERO))
		var display_name := str(building.get("display_name", building.get("type", "")))
		var expected_size := Vector2(
			clampf(36.0 + float(display_name.length()) * 26.0, 114.0, 192.0),
			LABEL_HEIGHT_WORLD
		)
		var expected_right_position := label_stem + Vector2(LABEL_STEM_GAP_WORLD, -expected_size.y * 0.5)
		var expected_left_position := label_stem + Vector2(-LABEL_STEM_GAP_WORLD - expected_size.x, -expected_size.y * 0.5)
		var expected_position := expected_right_position
		if allow_world_fit_direction and expected_right_position.x + expected_size.x > world_size.x + 0.01:
			expected_position = expected_left_position
		var position_matches := label_rect.position.is_equal_approx(expected_position)
		if not position_matches or not label_rect.size.is_equal_approx(expected_size):
			_add_violation(violations, "label_rect_anchor_contract_mismatch", str(building.get("type", "")))
		if label_rect.position.x < -0.01 or label_rect.position.y < -0.01 or label_rect.end.x > world_size.x + 0.01 or label_rect.end.y > world_size.y + 0.01:
			_add_violation(violations, "label_rect_out_of_world", str(building.get("type", "")))
		var label_polygon := _rect_polygon(label_rect)
		for other_index in range(buildings.size()):
			if other_index == index:
				continue
			var other := buildings[other_index]
			var other_label_value: Variant = other.get("label_rect_world", null)
			if other_index > index and other_label_value is Rect2 and label_rect.intersects(other_label_value as Rect2):
				_add_violation(
					violations,
					"label_rect_overlap",
					"%s:%s" % [str(building.get("type", "")), str(other.get("type", ""))]
				)
			var other_visual_value: Variant = other.get("visual_rect", null)
			if other_visual_value is Rect2 and label_rect.intersects(other_visual_value as Rect2):
				_add_violation(
					violations,
					"label_rect_visual_overlap",
					"%s:%s" % [str(building.get("type", "")), str(other.get("type", ""))]
				)
			if _polygon_intersection_area(label_polygon, _vector2_array(other.get("footprint_world_polygon", []))) > 0.01:
				_add_violation(
					violations,
					"label_rect_footprint_overlap",
					"%s:%s" % [str(building.get("type", "")), str(other.get("type", ""))]
				)
		for decor in decor_clusters:
			var decor_visual_value: Variant = decor.get("visual_bounds_world", null)
			if decor_visual_value is Rect2 and label_rect.intersects(decor_visual_value as Rect2):
				_add_violation(
					violations,
					"label_rect_decor_visual_overlap",
					"%s:%s" % [str(building.get("type", "")), str(decor.get("id", ""))]
				)
			if _polygon_intersection_area(label_polygon, _vector2_array(decor.get("footprint_world_polygon", []))) > 0.01:
				_add_violation(
					violations,
					"label_rect_decor_footprint_overlap",
					"%s:%s" % [str(building.get("type", "")), str(decor.get("id", ""))]
				)


static func _validate_blocker_inside_plot(
	plot_id: String,
	owner_id: String,
	violation_code: String,
	blocker: Array[Vector2],
	boundaries_by_plot: Dictionary,
	violations: Array[Dictionary]
) -> void:
	if not _polygon_is_finite(blocker):
		return
	if not boundaries_by_plot.has(plot_id):
		_add_violation(violations, violation_code, "%s:%s:missing_boundary" % [plot_id, owner_id])
		return
	var boundary_value: Variant = boundaries_by_plot.get(plot_id, [])
	var boundary := _vector2_array(boundary_value)
	for point in blocker:
		if not _point_in_or_on_polygon(point, boundary):
			var bounds := _polygon_aabb(boundary)
			_add_violation(violations, violation_code, "%s:%s:%s:bounds=%s/%s" % [plot_id, owner_id, _vector_token(point), _vector_token(bounds.position), _vector_token(bounds.size)])
			return


static func _validate_road_plot_boundary_clearance(
	layout: Dictionary,
	plots: Array[Dictionary],
	violations: Array[Dictionary]
) -> void:
	var road_value: Variant = layout.get("road_graph", {})
	var road: Dictionary = road_value as Dictionary if road_value is Dictionary else {}
	var seen := {}
	for edge in _dictionary_array(road.get("edges", [])):
		var edge_kind := str(edge.get("kind", ""))
		if not ["secondary", "approach", "trail"].has(edge_kind):
			continue
		var edge_id := str(edge.get("id", ""))
		var owned_plot_id := str(edge.get("plot_id", ""))
		var half_width := float(edge.get("half_width_world", 0.0))
		var polyline := _vector2_array(edge.get("polyline_world", []))
		for segment_index in range(polyline.size() - 1):
			var start := polyline[segment_index]
			var finish := polyline[segment_index + 1]
			if edge_kind == "approach" and segment_index == polyline.size() - 2:
				finish = finish.move_toward(start, half_width + 1.0)
			var corridor := _segment_corridor_polygon(start, finish, half_width)
			for plot in plots:
				var plot_id := str(plot.get("id", ""))
				if edge_kind != "secondary" and plot_id == owned_plot_id:
					continue
				if _polygon_intersection_area(corridor, _vector2_array(plot.get("boundary_polygon_world", []))) <= 0.01:
					continue
				var collision_key := "%s:%s" % [edge_id, plot_id]
				if seen.has(collision_key):
					continue
				seen[collision_key] = true
				_add_violation(violations, "road_plot_boundary_overlap", collision_key)


static func _validate_blocked_polygon_manifest(
	layout: Dictionary,
	buildings: Array[Dictionary],
	decor_clusters: Array[Dictionary],
	violations: Array[Dictionary]
) -> void:
	var expected := _build_blocked_polygons(buildings, decor_clusters)
	var actual := _dictionary_array(layout.get("blocked_polygons", []))
	if actual.size() != expected.size():
		_add_violation(
			violations,
			"blocked_polygon_manifest_mismatch",
			"expected %d entries, got %d" % [expected.size(), actual.size()]
		)
		return
	var actual_by_key := {}
	for blocker in actual:
		var key := "%s:%s" % [str(blocker.get("kind", "")), str(blocker.get("owner_id", ""))]
		if actual_by_key.has(key):
			_add_violation(violations, "blocked_polygon_manifest_mismatch", "duplicate:%s" % key)
			continue
		var blocker_polygon := _vector2_array(blocker.get("polygon_world", []))
		if blocker_polygon.size() < 3 or absf(_array_polygon_signed_area(blocker_polygon)) <= 1.0:
			_add_violation(violations, "blocked_polygon_area_invalid", key)
		actual_by_key[key] = blocker_polygon
	for blocker in expected:
		var key := "%s:%s" % [str(blocker.get("kind", "")), str(blocker.get("owner_id", ""))]
		if not actual_by_key.has(key):
			_add_violation(violations, "blocked_polygon_manifest_mismatch", "missing:%s" % key)
			continue
		var actual_polygon := _vector2_array(actual_by_key.get(key, []))
		var expected_polygon := _vector2_array(blocker.get("polygon_world", []))
		if not _polygons_equal_approx(actual_polygon, expected_polygon):
			_add_violation(violations, "blocked_polygon_manifest_mismatch", "geometry:%s" % key)


static func _validate_road_core_clearance(
	layout: Dictionary,
	buildings: Array[Dictionary],
	decor_clusters: Array[Dictionary],
	violations: Array[Dictionary]
) -> void:
	var road_value: Variant = layout.get("road_graph", {})
	var road: Dictionary = road_value as Dictionary if road_value is Dictionary else {}
	var blockers := _build_blocked_polygons(buildings, decor_clusters)
	var seen_collisions := {}
	for edge in _dictionary_array(road.get("edges", [])):
		var edge_id := str(edge.get("id", ""))
		var half_width_value: Variant = edge.get("half_width_world", null)
		if not _is_finite_number(half_width_value) or float(half_width_value) <= 0.0:
			continue
		var edge_half_width := float(half_width_value)
		var polyline := _vector2_array(edge.get("polyline_world", []))
		if polyline.size() < 2:
			_add_violation(violations, "road_core_invalid", edge_id)
			continue
		for segment_index in range(polyline.size() - 1):
			var start := polyline[segment_index]
			var finish := polyline[segment_index + 1]
			if str(edge.get("kind", "")) == "approach" and segment_index == polyline.size() - 2:
				finish = finish.move_toward(start, edge_half_width + 1.0)
			var core := _segment_corridor_polygon(start, finish, edge_half_width)
			for blocker in blockers:
				var blocker_polygon := _vector2_array(blocker.get("polygon_world", []))
				if _polygon_intersection_area(core, blocker_polygon) <= 0.01:
					continue
				var collision_key := "%s:%s:%s" % [
					edge_id,
					str(blocker.get("kind", "")),
					str(blocker.get("owner_id", "")),
				]
				if seen_collisions.has(collision_key):
					continue
				seen_collisions[collision_key] = true
				_add_violation(
					violations,
					"road_corridor_blocked",
					"%s:%s:%s" % [collision_key, _vector_token(start), _vector_token(finish)]
				)


static func _validate_walkable_manifest(
	layout: Dictionary,
	buildings: Array[Dictionary],
	world_size: Vector2,
	validate_r2_road_topology: bool,
	violations: Array[Dictionary]
) -> void:
	var road_value: Variant = layout.get("road_graph", {})
	var road: Dictionary = road_value as Dictionary if road_value is Dictionary else {}
	var expected_corridors := _build_walkable_corridors(road)
	var hubs := _dictionary_array(layout.get("walkable_hub_polygons", []))
	if validate_r2_road_topology and not hubs.is_empty():
		_add_violation(violations, "walkable_hub_forbidden_in_r2", "R2 topology does not publish authored hubs")
	if not validate_r2_road_topology:
		for hub in hubs:
			expected_corridors.append(hub.duplicate(true))
	var actual_corridors := _dictionary_array(layout.get("walkable_corridor_polygons", []))
	var actual_by_id := {}
	for corridor in actual_corridors:
		var corridor_id := str(corridor.get("id", ""))
		if corridor_id == "" or actual_by_id.has(corridor_id):
			_add_violation(violations, "walkable_corridor_manifest_mismatch", "duplicate:%s" % corridor_id)
			continue
		actual_by_id[corridor_id] = corridor
	if actual_corridors.size() != expected_corridors.size():
		_add_violation(
			violations,
			"walkable_corridor_manifest_mismatch",
			"expected=%d actual=%d" % [expected_corridors.size(), actual_corridors.size()]
		)
	for expected in expected_corridors:
		var corridor_id := str(expected.get("id", ""))
		if not actual_by_id.has(corridor_id):
			_add_violation(violations, "walkable_corridor_manifest_mismatch", "missing:%s" % corridor_id)
			continue
		var actual_value: Variant = actual_by_id.get(corridor_id, {})
		var actual: Dictionary = actual_value as Dictionary if actual_value is Dictionary else {}
		if str(actual.get("edge_id", "")) != str(expected.get("edge_id", "")) or str(actual.get("edge_kind", "")) != str(expected.get("edge_kind", "")) or str(actual.get("cap_style", "")) != str(expected.get("cap_style", WALKABLE_CAP_STYLE)) or int(actual.get("segment_index", -1)) != int(expected.get("segment_index", -1)) or not _is_finite_number(actual.get("half_width_world", null)) or not is_equal_approx(float(actual.get("half_width_world", 0.0)), float(expected.get("half_width_world", -1.0))) or not _polygons_equal_approx(_vector2_array(actual.get("polygon_world", [])), _vector2_array(expected.get("polygon_world", []))):
			_add_violation(violations, "walkable_corridor_manifest_mismatch", "geometry:%s" % corridor_id)
		var actual_polygon := _vector2_array(actual.get("polygon_world", []))
		if actual_polygon.size() < 3 or absf(_array_polygon_signed_area(actual_polygon)) <= 0.01:
			_add_violation(violations, "walkable_corridor_invalid", corridor_id)
		for point in actual_polygon:
			if point.x < -0.01 or point.y < -0.01 or point.x > world_size.x + 0.01 or point.y > world_size.y + 0.01:
				_add_violation(violations, "walkable_corridor_out_of_world", "%s:%s" % [corridor_id, _vector_token(point)])
				break
	if not validate_r2_road_topology:
		for hub in hubs:
			var hub_id := str(hub.get("id", ""))
			var actual_hub_value: Variant = actual_by_id.get(hub_id, null)
			var actual_hub: Dictionary = actual_hub_value as Dictionary if actual_hub_value is Dictionary else {}
			if actual_hub != hub:
				_add_violation(violations, "walkable_hub_manifest_mismatch", hub_id)
			var hub_polygon := _vector2_array(hub.get("polygon_world", []))
			if str(hub.get("edge_kind", "")) != "hub" or str(hub.get("cap_style", "")) != "authored_polygon" or str(hub.get("source_contract_id", "")) == "" or hub_polygon.size() < 3 or absf(_array_polygon_signed_area(hub_polygon)) <= 0.01:
				_add_violation(violations, "walkable_hub_invalid", hub_id)

	var expected_portals := _build_interaction_portals(buildings)
	var actual_portals := _dictionary_array(layout.get("interaction_portals", []))
	var actual_portal_by_id := {}
	for portal in actual_portals:
		actual_portal_by_id[str(portal.get("id", ""))] = portal
	if actual_portals.size() != expected_portals.size():
		_add_violation(violations, "interaction_portal_manifest_mismatch", "count")
	for expected in expected_portals:
		var portal_id := str(expected.get("id", ""))
		if not actual_portal_by_id.has(portal_id):
			_add_violation(violations, "interaction_portal_manifest_mismatch", "missing:%s" % portal_id)
			continue
		var portal_value: Variant = actual_portal_by_id.get(portal_id, {})
		var portal: Dictionary = portal_value as Dictionary if portal_value is Dictionary else {}
		if str(portal.get("building_type", "")) != str(expected.get("building_type", "")) or str(portal.get("plot_id", "")) != str(expected.get("plot_id", "")) or str(portal.get("approach_edge_id", "")) != str(expected.get("approach_edge_id", "")) or not _polygons_equal_approx(_vector2_array(portal.get("polygon_world", [])), _vector2_array(expected.get("polygon_world", []))):
			_add_violation(violations, "interaction_portal_manifest_mismatch", "geometry:%s" % portal_id)
		var linked := false
		for corridor in actual_corridors:
			if str(corridor.get("edge_id", "")) != str(portal.get("approach_edge_id", "")):
				continue
			if _polygon_intersection_area(_vector2_array(corridor.get("polygon_world", [])), _vector2_array(portal.get("polygon_world", []))) > 0.01:
				linked = true
				break
		if not linked:
			_add_violation(violations, "walkable_portal_disconnected", portal_id)


static func _validate_approach_edges(
	layout: Dictionary,
	buildings: Array[Dictionary],
	violations: Array[Dictionary]
) -> void:
	var road_value: Variant = layout.get("road_graph", {})
	var road: Dictionary = road_value as Dictionary if road_value is Dictionary else {}
	var edges := _dictionary_array(road.get("edges", []))
	for building in buildings:
		var edge_id := str(building.get("approach_edge_id", ""))
		var edge := _find_by_id(edges, edge_id)
		if edge.is_empty():
			_add_violation(violations, "building_approach_edge_missing", str(building.get("type", "")))
			continue
		var polyline := _vector2_array(edge.get("polyline_world", []))
		var entrance := _coerce_vector2(building.get("entrance_world_pos", Vector2.ZERO))
		if polyline.size() < 2 or not polyline[polyline.size() - 1].is_equal_approx(entrance):
			_add_violation(violations, "building_approach_endpoint_mismatch", str(building.get("type", "")))
			continue
		var clearance := _vector2_array(building.get("road_side_clearance_polygon_world", []))
		var previous := polyline[polyline.size() - 2]
		var inside_sample := entrance.lerp(previous, 0.5)
		if clearance.size() < 3 or not Geometry2D.is_point_in_polygon(inside_sample, PackedVector2Array(clearance)):
			_add_violation(violations, "building_approach_misses_clearance", str(building.get("type", "")))


static func _validate_route_distance_contract(
	layout: Dictionary,
	plots: Array[Dictionary],
	buildings: Array[Dictionary],
	decor_clusters: Array[Dictionary],
	violations: Array[Dictionary]
) -> void:
	var geometry := _compute_main_route_geometry(layout)
	if not bool(geometry.get("valid", false)):
		return
	var distances_value: Variant = geometry.get("distance_by_node", {})
	var distance_by_node: Dictionary = distances_value as Dictionary if distances_value is Dictionary else {}
	var plot_distance_by_id := {}
	for plot in plots:
		var plot_id := str(plot.get("id", ""))
		var node_id := str(plot.get("main_node_id", ""))
		if not distance_by_node.has(node_id):
			_add_violation(violations, "route_distance_mismatch", "plot:%s:missing_node" % plot_id)
			continue
		var computed := float(distance_by_node.get(node_id, 0.0))
		plot_distance_by_id[plot_id] = computed
		if not is_equal_approx(float(plot.get("main_route_distance_world", -1.0)), computed):
			_add_violation(violations, "route_distance_mismatch", "plot:%s" % plot_id)
	for building in buildings:
		var plot_id := str(building.get("plot_id", ""))
		if not plot_distance_by_id.has(plot_id) or not is_equal_approx(float(building.get("main_route_distance_world", -1.0)), float(plot_distance_by_id.get(plot_id, 0.0))):
			_add_violation(violations, "route_distance_mismatch", "building:%s" % str(building.get("type", "")))
	for decor in decor_clusters:
		var plot_id := str(decor.get("plot_id", ""))
		if not plot_distance_by_id.has(plot_id) or not is_equal_approx(float(decor.get("main_route_distance_world", -1.0)), float(plot_distance_by_id.get(plot_id, 0.0))):
			_add_violation(violations, "route_distance_mismatch", "decor:%s" % str(decor.get("id", "")))


static func _validate_landmark_gap(
	layout: Dictionary,
	plots: Array[Dictionary],
	violations: Array[Dictionary],
	metrics: Dictionary
) -> void:
	var geometry := _compute_main_route_geometry(layout)
	if not bool(geometry.get("valid", false)):
		return
	var route_length := float(geometry.get("route_length_world", 0.0))
	var distances_value: Variant = geometry.get("distance_by_node", {})
	var distance_by_node: Dictionary = distances_value as Dictionary if distances_value is Dictionary else {}
	metrics["main_route_length_world"] = route_length
	var distances: Array[float] = [0.0, route_length]
	for plot in plots:
		var node_id := str(plot.get("main_node_id", ""))
		if distance_by_node.has(node_id):
			distances.append(float(distance_by_node.get(node_id, 0.0)))
	distances.sort()
	var max_gap := 0.0
	for index in range(1, distances.size()):
		max_gap = maxf(max_gap, distances[index] - distances[index - 1])
	metrics["max_landmark_gap_world"] = max_gap
	if max_gap > MAX_LANDMARK_GAP_WORLD + 0.01:
		_add_violation(
			violations,
			"landmark_gap_exceeded",
			"%.3f > %.3f" % [max_gap, MAX_LANDMARK_GAP_WORLD]
		)


static func _validate_map_distribution(
	layout: Dictionary,
	plots: Array[Dictionary],
	buildings: Array[Dictionary],
	decor_clusters: Array[Dictionary],
	world_size: Vector2,
	violations: Array[Dictionary],
	metrics: Dictionary
) -> void:
	var pivot_points: Array[Vector2] = []
	var upper_count := 0
	var lower_count := 0
	for plot in plots:
		var pivot := _coerce_vector2(plot.get("pivot_pos", Vector2.ZERO))
		pivot_points.append(pivot)
		if pivot.y < world_size.y * 0.40:
			upper_count += 1
		if pivot.y > world_size.y * 0.65:
			lower_count += 1
	var plot_y_span := _point_axis_span(pivot_points, false)
	var plot_y_span_ratio := plot_y_span / maxf(1.0, world_size.y)
	metrics["plot_y_span_world"] = plot_y_span
	metrics["plot_y_span_ratio"] = plot_y_span_ratio
	metrics["upper_plot_count"] = upper_count
	metrics["lower_plot_count"] = lower_count
	if plot_y_span_ratio < MIN_PLOT_Y_SPAN_RATIO or upper_count < MIN_UPPER_LOWER_PLOT_COUNT or lower_count < MIN_UPPER_LOWER_PLOT_COUNT:
		_add_violation(
			violations,
			"map_vertical_distribution_compressed",
			"span_ratio=%.3f upper=%d lower=%d" % [plot_y_span_ratio, upper_count, lower_count]
		)

	var content_anchors: Array[Vector2] = []
	for building in buildings:
		content_anchors.append(_coerce_vector2(building.get("pivot_pos", Vector2.ZERO)))
	for decor in decor_clusters:
		content_anchors.append(_coerce_vector2(decor.get("anchor_world", Vector2.ZERO)))
	var anchor_bounds := _points_aabb(content_anchors)
	var anchor_area_ratio := (anchor_bounds.size.x * anchor_bounds.size.y) / maxf(1.0, world_size.x * world_size.y)
	var anchor_y_span_ratio := anchor_bounds.size.y / maxf(1.0, world_size.y)
	metrics["content_anchor_bbox_area_ratio"] = anchor_area_ratio
	metrics["content_anchor_y_span_ratio"] = anchor_y_span_ratio
	if anchor_area_ratio < MIN_CONTENT_ANCHOR_AREA_RATIO or anchor_y_span_ratio < MIN_PLOT_Y_SPAN_RATIO:
		_add_violation(
			violations,
			"content_anchor_distribution_compressed",
			"area_ratio=%.3f y_ratio=%.3f" % [anchor_area_ratio, anchor_y_span_ratio]
		)

	var structural_points: Array[Vector2] = []
	for plot in plots:
		structural_points.append_array(_vector2_array(plot.get("boundary_polygon_world", [])))
	var road_value: Variant = layout.get("road_graph", {})
	var road: Dictionary = road_value as Dictionary if road_value is Dictionary else {}
	for edge in _dictionary_array(road.get("edges", [])):
		structural_points.append_array(_vector2_array(edge.get("polyline_world", [])))
	var structural_height_ratio := _point_axis_span(structural_points, false) / maxf(1.0, world_size.y)
	metrics["structural_bbox_height_ratio"] = structural_height_ratio
	metrics["secondary_cycle_rank"] = _structural_cycle_rank(road)
	if structural_height_ratio < MIN_STRUCTURAL_BBOX_HEIGHT_RATIO:
		_add_violation(
			violations,
			"structural_bbox_height_compressed",
			"height_ratio=%.3f" % structural_height_ratio
		)


static func _compute_main_route_geometry(layout: Dictionary) -> Dictionary:
	var road_value: Variant = layout.get("road_graph", {})
	var road: Dictionary = road_value as Dictionary if road_value is Dictionary else {}
	var nodes := _dictionary_array(road.get("nodes", []))
	var edges := _dictionary_array(road.get("edges", []))
	var ordered_ids: Array[String] = ["spawn"]
	for index in range(REQUIRED_PLOT_COUNT):
		ordered_ids.append("main_%d" % index)
	ordered_ids.append("exit")
	var distance_by_node := {"spawn": 0.0}
	var cumulative := 0.0
	for index in range(ordered_ids.size() - 1):
		var from_id := ordered_ids[index]
		var to_id := ordered_ids[index + 1]
		var matching_edges: Array[Dictionary] = []
		for edge in edges:
			if str(edge.get("kind", "")) == "main" and str(edge.get("from", "")) == from_id and str(edge.get("to", "")) == to_id:
				matching_edges.append(edge)
		if matching_edges.size() != 1:
			return {"valid": false, "detail": "%s->%s count=%d" % [from_id, to_id, matching_edges.size()]}
		var polyline := _vector2_array(matching_edges[0].get("polyline_world", []))
		var from_node := _find_by_id(nodes, from_id)
		var to_node := _find_by_id(nodes, to_id)
		if polyline.size() < 2 or from_node.is_empty() or to_node.is_empty():
			return {"valid": false, "detail": "%s->%s missing geometry" % [from_id, to_id]}
		if not polyline[0].is_equal_approx(_coerce_vector2(from_node.get("position", Vector2.ZERO))) or not polyline[polyline.size() - 1].is_equal_approx(_coerce_vector2(to_node.get("position", Vector2.ZERO))):
			return {"valid": false, "detail": "%s->%s endpoint mismatch" % [from_id, to_id]}
		var segment_length := _polyline_length(polyline)
		if not is_finite(segment_length) or segment_length <= 0.0:
			return {"valid": false, "detail": "%s->%s invalid length" % [from_id, to_id]}
		cumulative += segment_length
		distance_by_node[to_id] = cumulative
	return {
		"valid": true,
		"route_length_world": cumulative,
		"distance_by_node": distance_by_node,
	}


static func _polyline_length(polyline: Array[Vector2]) -> float:
	var total := 0.0
	for index in range(polyline.size() - 1):
		total += polyline[index].distance_to(polyline[index + 1])
	return total


static func _compact_polyline(points: Array[Vector2]) -> Array[Vector2]:
	var compacted: Array[Vector2] = []
	for point in points:
		if not compacted.is_empty() and compacted[compacted.size() - 1].is_equal_approx(point):
			continue
		compacted.append(point)
	return compacted


static func _canonical_road_half_width(edge_kind: String) -> float:
	var value: Variant = ROAD_HALF_WIDTH_BY_KIND.get(edge_kind, null)
	return float(value) if _is_finite_number(value) else -1.0


static func _oriented_approach_polygon(
	entrance: Vector2,
	normal: Vector2,
	cross_width: float,
	depth: float
) -> Array[Vector2]:
	var safe_normal := normal.normalized() if normal.length_squared() > 0.0001 else Vector2(-1.0, 0.5).normalized()
	var tangent := Vector2(-safe_normal.y, safe_normal.x)
	var half_width := cross_width * 0.5
	var far_center := entrance + safe_normal * depth
	return [
		entrance - tangent * half_width,
		entrance + tangent * half_width,
		far_center + tangent * half_width,
		far_center - tangent * half_width,
	]


static func _polygon_intersection_area(left: Array[Vector2], right: Array[Vector2]) -> float:
	if left.size() < 3 or right.size() < 3 or not _polygon_is_finite(left) or not _polygon_is_finite(right):
		return 0.0
	var total := 0.0
	var intersections := Geometry2D.intersect_polygons(PackedVector2Array(left), PackedVector2Array(right))
	for intersection_value in intersections:
		var polygon := PackedVector2Array(intersection_value)
		total += absf(_packed_polygon_signed_area(polygon))
	return total


static func _array_polygon_signed_area(polygon: Array[Vector2]) -> float:
	return _packed_polygon_signed_area(PackedVector2Array(polygon))


static func _polygon_is_finite(polygon: Array[Vector2]) -> bool:
	for point in polygon:
		if not _is_finite_vector2(point):
			return false
	return true


static func _is_finite_vector2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


static func _packed_polygon_signed_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var twice_area := 0.0
	for index in range(polygon.size()):
		var next_index := (index + 1) % polygon.size()
		twice_area += polygon[index].x * polygon[next_index].y
		twice_area -= polygon[next_index].x * polygon[index].y
	return twice_area * 0.5


static func _point_in_or_on_polygon(point: Vector2, polygon: Array[Vector2]) -> bool:
	if polygon.size() < 3:
		return false
	if Geometry2D.is_point_in_polygon(point, PackedVector2Array(polygon)):
		return true
	for index in range(polygon.size()):
		var closest := Geometry2D.get_closest_point_to_segment(
			point,
			polygon[index],
			polygon[(index + 1) % polygon.size()]
		)
		if closest.distance_squared_to(point) <= 0.0001:
			return true
	return false


static func _polygons_equal_approx(left: Array[Vector2], right: Array[Vector2]) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if not left[index].is_equal_approx(right[index]):
			return false
	return true


static func _segment_corridor_polygon(start: Vector2, finish: Vector2, half_width: float) -> Array[Vector2]:
	var delta := finish - start
	if delta.length_squared() <= 0.0001:
		return []
	var tangent := delta.normalized()
	var normal := Vector2(-tangent.y, tangent.x) * half_width
	# Square caps extend by the lane half-width on both ends. Adjacent segments
	# therefore overlap at a bend instead of leaving the flat-cap wedge that can
	# catch a moving player footprint while turning through a road node.
	var capped_start := start - tangent * half_width
	var capped_finish := finish + tangent * half_width
	return [capped_start + normal, capped_finish + normal, capped_finish - normal, capped_start - normal]


static func _rect_polygon(rect: Rect2) -> Array[Vector2]:
	return [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]


static func _polygon_aabb(points: Array[Vector2]) -> Rect2:
	if points.is_empty():
		return Rect2()
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


static func _points_aabb(points: Array[Vector2]) -> Rect2:
	return _polygon_aabb(points)


static func _point_axis_span(points: Array[Vector2], use_x_axis: bool) -> float:
	if points.is_empty():
		return 0.0
	var minimum := points[0].x if use_x_axis else points[0].y
	var maximum := minimum
	for point in points:
		var value := point.x if use_x_axis else point.y
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
	return maximum - minimum


static func _find_open_plot_index(plots: Array[Dictionary], plot_class: String) -> int:
	for index in range(plots.size()):
		if str(plots[index].get("occupied_by", "")) != "":
			continue
		if str(plots[index].get("plot_class", "")) == plot_class:
			return index
	return -1


static func _find_building_index_by_plot(buildings: Array[Dictionary], plot_id: String) -> int:
	for index in range(buildings.size()):
		if str(buildings[index].get("plot_id", "")) == plot_id:
			return index
	return -1


static func _find_by_id(values: Array[Dictionary], value_id: String) -> Dictionary:
	for value in values:
		if str(value.get("id", "")) == value_id:
			return value
	return {}


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item in value as Array:
		if item is Dictionary:
			result.append(item as Dictionary)
	return result


static func _vector2_array(value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if value is PackedVector2Array:
		for point in value as PackedVector2Array:
			result.append(point)
		return result
	if not (value is Array):
		return result
	for item in value as Array:
		if item is Vector2:
			result.append(item as Vector2)
		elif item is Vector2i:
			result.append(Vector2(item as Vector2i))
	return result


static func _coerce_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Vector2i:
		return Vector2(value as Vector2i)
	return Vector2.ZERO


static func _clamp_world_point(point: Vector2, world_size: Vector2, margin: float) -> Vector2:
	return Vector2(
		clampf(point.x, margin, maxf(margin, world_size.x - margin)),
		clampf(point.y, margin, maxf(margin, world_size.y - margin))
	)


static func _build_phase_rng(stage_id: int, map_seed: int, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var safe_seed := map_seed if map_seed > 0 else int(abs(hash("plaza:%d" % stage_id)))
	rng.seed = int(abs(hash("%s:%d:%d:%s" % [GENERATOR_VERSION, stage_id, safe_seed, salt])))
	return rng


static func _vector_token(value: Vector2) -> String:
	return "%.3f,%.3f" % [value.x, value.y]


static func _rect_token(value: Rect2) -> String:
	return "%s/%s" % [_vector_token(value.position), _vector_token(value.size)]


static func _add_violation(violations: Array[Dictionary], code: String, detail: String) -> void:
	violations.append({"code": code, "detail": detail})
