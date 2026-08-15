extends RefCounted

# R3-A0.6 production-disconnected integrated map authority. The canonical road
# skeleton is built before plots; plots, building placement, approach clearance,
# and decor are then derived from that road. R2 selection/order/plot-class and
# four phase RNG semantics remain the differential authority, while every world
# coordinate is deliberately versioned R3 output.

const PlazaMapLayoutGenerator := preload("res://scripts/plaza/plaza_map_layout_generator.gd")

const GENERATOR_VERSION := "hwangyeok_map_layout_r3a06_walkable_hub_side_trees_v1"
const BASIS_SLOPE_MAGNITUDE := 0.5
const BASIS_EPSILON := 0.001
const MAX_SELECTED_BUILDING_COUNT := 5
const THREE_WAY_ARM_RUN_WORLD := 60.0
const TERMINUS_ARM_RUN_WORLD := 60.0
const PLOT_SPUR_ARM_RUN_WORLD := 64.0
const ENTRANCE_FORECOURT_ARM_RUN_WORLD := 75.0
const THREE_WAY_SOUTH_ARM_REACH_PER_TARGET_WIDTH := 174.0 / 480.0
const MAX_MAIN_SPINE_TURN_COUNT := 4
const STRAIGHT_CAP_OVERLAP_WORLD := 12.0
const MAX_ROAD_TURN_COURT_COUNT := 20
const CENTRAL_PLAZA_EXCLUSION_ID := "approved_ground_central_plaza"
const CENTRAL_PLAZA_HUB_ID := "approved_ground_central_plaza_walkable_hub"
const CENTRAL_PLAZA_HUB_MANIFEST_PATH := "res://assets/ui/plaza/environment/hwangyeok_r2/plaza_hwangyeok_r3a1_road_hierarchy_manifest.json"
const CENTRAL_PLAZA_HUB_CONTRACT_ID := "hwangyeok_r3a1_central_plaza_hub_v1"
const BUILDING_LABEL_FIT_POLICY := "right_default_left_only_when_right_exits_fixed_world"
const CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD: Array[Vector2] = [
	Vector2(214.0, 576.0),
	Vector2(1006.0, 190.0),
	Vector2(2286.0, 951.0),
	Vector2(1462.0, 1347.0),
]
# Plot classes keep their R2 semantic assignment order, but their R3 world
# sites are class-owned. Keying the sites by route slot made a seed rotation
# silently move a large building into a regular parcel and caused label/road
# overlaps. These seven reservations are authored before plot/building output.
const R3_PLOT_SITE_BY_CLASS := {
	# The shop's authored southwest forecourt reaches roughly 100 world below
	# its pivot. Keep the lower-band parcel inside the 1500-world map after the
	# route-lattice snap instead of clipping the manifest-owned clearance shape.
	"standard_market": Vector2(1740.0, 1390.0),
	"standard_quiet": Vector2(350.0, 360.0),
	"rear_landmark_large": Vector2(1700.0, 340.0),
	"medium_left_access": Vector2(630.0, 1250.0),
	# The exact NE main_6 -> exit gate occupies the lower part of this band.
	# Blacksmith remains above that corridor; the adjacent medium parcel moves
	# one row upward so both class-owned boundaries retain positive separation.
	"edge_large": Vector2(2200.0, 500.0),
	# Academy's wide southwest forecourt reaches farther left than its parcel.
	# Reserve the clearance shape, not just the building footprint, in-world.
	"intersection_large": Vector2(270.0, 1300.0),
	# The north-east pocket cannot hold rear_landmark + edge_large + medium.
	# Medium therefore owns the previously empty south-east quadrant through a
	# dedicated plaza-rim gate instead of drifting inside the approved hub art.
	"medium": Vector2(2160.0, 1260.0),
}
# These are semantic pivot bands, not final coordinates. The road phase is
# authoritative, so each class resolves the nearest lattice-aligned pivot that
# keeps its complete parcel/building/forecourt geometry clear. Search never
# consumes an RNG draw; the authored class identity and phase-stream tails stay
# identical to R2 while world coordinates follow the versioned R3 topology.
const R3_PLOT_SITE_BAND_BY_CLASS := {
	"standard_market": Rect2(Vector2(1680.0, 1350.0), Vector2(180.0, 60.0)),
	"standard_quiet": Rect2(Vector2(260.0, 300.0), Vector2(280.0, 220.0)),
	"rear_landmark_large": Rect2(Vector2(1380.0, 240.0), Vector2(560.0, 220.0)),
	"medium_left_access": Rect2(Vector2(480.0, 1140.0), Vector2(380.0, 250.0)),
	"edge_large": Rect2(Vector2(2040.0, 400.0), Vector2(240.0, 360.0)),
	"intersection_large": Rect2(Vector2(220.0, 1140.0), Vector2(300.0, 250.0)),
	"medium": Rect2(Vector2(2120.0, 1240.0), Vector2(60.0, 100.0)),
}
const R3_PLOT_SITE_SEARCH_STEP_WORLD := 20.0
const R3_PLOT_RESOLUTION_PRIORITY_BY_CLASS := {
	# Resolve the narrow lower-side sequence from its plaza gate outward. The
	# flexible market band must not reserve a corridor across central/left plots.
	"intersection_large": 0,
	"medium_left_access": 1,
	"standard_market": 2,
	# Upper-side edge/landmark parcels are less mobile than the wide medium band.
	"standard_quiet": 3,
	"rear_landmark_large": 4,
	"edge_large": 5,
	"medium": 6,
}
const R3_PLOT_BRANCH_NODE_BY_CLASS := {
	"standard_quiet": "upper_plot_junction_0",
	"rear_landmark_large": "upper_plot_junction_1",
	"medium_left_access": "lower_plot_junction_1",
	"edge_large": "upper_plot_junction_3",
	"intersection_large": "lower_plot_junction_0",
	"standard_market": "southeast_market_gate",
	"medium": "southeast_connector_0",
}
const R3_MAIN_BRANCH_ROOT_IDS: Array[String] = []
const R3_SECONDARY_NODE_SPECS := [
	{"id": "upper_connector_0", "role": "road_turn_node", "position": Vector2(150.0, 40.0), "trunk": "upper", "turn_court_edge_kind": "secondary"},
	{"id": "upper_plot_junction_0", "role": "road_piece_junction", "position": Vector2(350.0, 140.0), "trunk": "upper"},
	{"id": "upper_connector_1", "role": "road_turn_node", "position": Vector2(550.0, 40.0), "trunk": "upper", "turn_court_edge_kind": "secondary"},
	{"id": "upper_connector_2", "role": "road_turn_node", "position": Vector2(1380.0, 40.0), "trunk": "upper", "turn_court_edge_kind": "secondary"},
	{"id": "upper_plot_junction_1", "role": "road_piece_junction", "position": Vector2(1500.0, 100.0), "trunk": "upper"},
	{"id": "upper_connector_3", "role": "road_turn_node", "position": Vector2(1620.0, 40.0), "trunk": "upper", "turn_court_edge_kind": "secondary"},
	{"id": "upper_plot_junction_2", "role": "road_turn_node", "position": Vector2(1820.0, 140.0), "trunk": "upper", "turn_court_edge_kind": "secondary"},
	{"id": "upper_connector_4", "role": "road_turn_node", "position": Vector2(1995.0, 52.5), "trunk": "upper", "turn_court_edge_kind": "secondary"},
	{"id": "upper_plot_junction_3", "role": "road_turn_node", "position": Vector2(2170.0, 140.0), "trunk": "upper", "turn_court_edge_kind": "secondary"},
	{"id": "lower_connector_0", "role": "road_turn_node", "position": Vector2(100.0, 975.0), "trunk": "lower", "turn_court_edge_kind": "secondary"},
	{"id": "lower_plot_junction_0", "role": "road_piece_junction", "position": Vector2(250.0, 1050.0), "trunk": "lower"},
	{"id": "lower_connector_1", "role": "road_turn_node", "position": Vector2(400.0, 975.0), "trunk": "lower", "turn_court_edge_kind": "secondary"},
	{"id": "lower_connector_1b", "role": "road_turn_node", "position": Vector2(700.0, 975.0), "trunk": "lower", "turn_court_edge_kind": "secondary"},
	# The left-access endpoint belongs beyond the parcel's east edge. It is a
	# degree-two street/approach court, not a three-way with an unused east arm.
	{"id": "lower_plot_junction_1", "role": "road_turn_node", "position": Vector2(850.0, 1050.0), "trunk": "lower", "turn_court_edge_kind": "secondary"},
	# Separate south-east hub gates keep market and spirit approaches independent.
	# Trying to put a three-way S arm below the plaza left no parcel depth before
	# the 1500-world boundary; the hub itself is the authored connectivity owner.
	{"id": "southeast_market_gate", "role": "road_turn_node", "position": Vector2(1524.208, 1317.104), "trunk": "southeast_market", "turn_court_edge_kind": "secondary"},
	{"id": "southeast_connector_0", "role": "road_turn_node", "position": Vector2(2286.0, 951.0), "trunk": "southeast", "turn_court_edge_kind": "secondary"},
]
const R3_SECONDARY_EDGE_SPECS := [
	{"id": "secondary_upper_root", "from": "main_1", "to": "upper_connector_0", "trunk": "upper", "root": true, "negative_first": true},
	{"id": "secondary_upper_0", "from": "upper_connector_0", "to": "upper_plot_junction_0", "trunk": "upper"},
	{"id": "secondary_upper_1", "from": "upper_plot_junction_0", "to": "upper_connector_1", "trunk": "upper"},
	{"id": "secondary_upper_2", "from": "upper_connector_1", "to": "upper_connector_2", "trunk": "upper"},
	{"id": "secondary_upper_3", "from": "upper_connector_2", "to": "upper_plot_junction_1", "trunk": "upper"},
	{"id": "secondary_upper_4", "from": "upper_plot_junction_1", "to": "upper_connector_3", "trunk": "upper"},
	{"id": "secondary_upper_5", "from": "upper_connector_3", "to": "upper_plot_junction_2", "trunk": "upper"},
	{"id": "secondary_upper_6", "from": "upper_plot_junction_2", "to": "upper_connector_4", "trunk": "upper"},
	{"id": "secondary_upper_7", "from": "upper_connector_4", "to": "upper_plot_junction_3", "trunk": "upper"},
	{"id": "secondary_lower_root", "from": "main_4", "to": "lower_connector_0", "trunk": "lower", "root": true, "negative_first": false},
	{"id": "secondary_lower_0", "from": "lower_connector_0", "to": "lower_plot_junction_0", "trunk": "lower"},
	{"id": "secondary_lower_1", "from": "lower_plot_junction_0", "to": "lower_connector_1", "trunk": "lower"},
	{"id": "secondary_lower_2", "from": "lower_connector_1", "to": "lower_connector_1b", "trunk": "lower"},
	{"id": "secondary_lower_3", "from": "lower_connector_1b", "to": "lower_plot_junction_1", "trunk": "lower"},
	{"id": "secondary_southeast_root", "from": "main_6", "to": "southeast_connector_0", "trunk": "southeast", "root": true, "negative_first": true},
	{"id": "secondary_southeast_market_root", "from": "main_5", "to": "southeast_market_gate", "trunk": "southeast_market", "root": true, "negative_first": true},
]
const EXPECTED_CENTRAL_PLAZA_RIM_JOIN_COUNT := 6
const R3_MAIN_SITE_BY_SLOT: Array[Vector2] = [
	# The first/last semantic main nodes are also the visible plaza-rim gates.
	# Intermediate main nodes remain inside the authored hub and are deliberately
	# absent from the stamped-road manifest.
	Vector2(117398.0 / 465.0, 278891.0 / 465.0),
	Vector2(800.0, 720.0),
	Vector2(1000.0, 720.0),
	Vector2(1200.0, 720.0),
	Vector2(1400.0, 720.0),
	Vector2(1600.0, 720.0),
	Vector2(940842.0 / 467.0, 368778.0 / 467.0),
]
const R3_PLOT_FORECOURT_FRONT_RESERVE_WORLD := 84.0
const R3_DECOR_TRAIL_ANCHOR_OFFSET_X := -132.0
const R3_ROUTE_GRID_X_WORLD := 40.0
const R3_ROUTE_GRID_Y_WORLD := 20.0
const R3_ROUTE_MAX_EXPANSIONS := 6000
const SPECIAL_ROAD_TARGET_WIDTH_WORLD := {
	# Approved PNG runtime alpha: south arm reaches 174 px from its 480 px
	# content width. At 150 world the arm overlaps a 60-world route port without
	# stretching or exceeding the approved special-piece placement range.
	"three_way": 150.0,
	"plot_spur": 112.0,
	"terminus": 108.0,
	"entrance_forecourt": 150.0,
	"turn_court": 168.0,
}
const ROAD_PIECE_IDS := [
	"straight_horizontal",
	"straight_positive",
	"straight_negative",
	"three_way",
	"plot_spur",
	"terminus",
	"entrance_forecourt",
	"turn_court",
]
const SPECIAL_ROAD_ORIENTATION_SIGNATURES := {
	"three_way": "north_east+north_west+south",
	"plot_spur": "trail_enters_south_east",
	"terminus": "terminus_opens_north_east",
	"entrance_forecourt": "approach_enters_north_east",
}

static var _exit_route_cache := {}


static func generate(
	stage_id: int,
	map_seed: int,
	world_size: Vector2,
	selected_specs: Array[Dictionary],
	spawn_anchor: Vector2,
	exit_zone: Rect2,
	capture_plot_availability_debug: bool = false
) -> Dictionary:
	var normalized_stage := maxi(1, stage_id)
	var safe_world_size := Vector2(maxf(1.0, world_size.x), maxf(1.0, world_size.y))
	var safe_spawn := _clamp_world_point(spawn_anchor, safe_world_size, 0.0)
	var safe_exit_zone := exit_zone
	var exit_center := _clamp_world_point(exit_zone.get_center(), safe_world_size, 0.0)
	var source := PlazaMapLayoutGenerator.generate(
		normalized_stage,
		map_seed,
		safe_world_size,
		selected_specs,
		safe_spawn,
		safe_exit_zone
	)
	var source_validation := source.get("validation", {}) as Dictionary
	if not bool(source_validation.get("valid", false)):
		return _rejected_layout("source_layout_invalid")

	# Use the exact R2 phase seeding and phase call counts. Only the road result
	# changes; plot/building/decor phases keep their independent RNG streams.
	var skeleton_rng := PlazaMapLayoutGenerator._build_phase_rng(normalized_stage, map_seed, "skeleton")
	var plot_rng := PlazaMapLayoutGenerator._build_phase_rng(normalized_stage, map_seed, "plots")
	var assignment_rng := PlazaMapLayoutGenerator._build_phase_rng(normalized_stage, map_seed, "assignment")
	var decor_rng := PlazaMapLayoutGenerator._build_phase_rng(normalized_stage, map_seed, "decor")
	var source_road := PlazaMapLayoutGenerator._build_main_road_graph(
		safe_spawn,
		exit_center,
		safe_world_size,
		skeleton_rng,
		map_seed
	)
	var road_result := _build_integrated_main_road_graph(source_road, safe_spawn, exit_center, safe_world_size)
	if not bool(road_result.get("valid", false)):
		return _rejected_layout(str(road_result.get("rejection_reason", "integrated_main_road_failed")))
	var road := road_result.get("road_graph", {}) as Dictionary
	var plot_assignments := PlazaMapLayoutGenerator._build_plot_assignments(assignment_rng, map_seed)
	var plot_result := _build_integrated_plots(
		road,
		safe_world_size,
		plot_rng,
		plot_assignments,
		selected_specs,
		capture_plot_availability_debug
	)
	var plot_debug_diagnostics := {}
	if capture_plot_availability_debug:
		plot_debug_diagnostics["plot_availability_debug"] = plot_result.get("availability_debug", [])
		plot_debug_diagnostics["plot_availability_context"] = plot_result.get("availability_context", {})
	if not bool(plot_result.get("valid", false)):
		return _rejected_layout(str(plot_result.get("rejection_reason", "integrated_plot_placement_failed")), plot_debug_diagnostics)
	var plots := _dictionary_array(plot_result.get("plots", []))
	var plot_route_plans := _dictionary_array(plot_result.get("route_plans", []))
	var buildings := PlazaMapLayoutGenerator._assign_buildings(selected_specs, plots, assignment_rng)
	_apply_r3_label_world_fit(buildings, safe_world_size)
	var building_blockers := PlazaMapLayoutGenerator._build_blocked_polygons(buildings, [])
	var branch_result := _append_integrated_plot_edges(
		road,
		plots,
		buildings,
		building_blockers,
		safe_world_size,
		plot_route_plans
	)
	if not bool(branch_result.get("valid", false)):
		return _rejected_layout(str(branch_result.get("rejection_reason", "integrated_plot_route_failed")), plot_debug_diagnostics)
	road = branch_result.get("road_graph", road) as Dictionary
	plots = _dictionary_array(branch_result.get("plots", plots))
	buildings = _dictionary_array(branch_result.get("buildings", buildings))
	var decor_clusters := PlazaMapLayoutGenerator._fill_unused_plots(plots, buildings, road, decor_rng)
	var decor_result := _repair_integrated_decor_clearance(plots, buildings, road, decor_clusters)
	if not bool(decor_result.get("valid", false)):
		return _rejected_layout(str(decor_result.get("rejection_reason", "integrated_decor_clearance_failed")), plot_debug_diagnostics)
	decor_clusters = _dictionary_array(decor_result.get("decor_clusters", decor_clusters))
	var phase_rng_tail_samples := {
		"skeleton": skeleton_rng.randi(),
		"plots": plot_rng.randi(),
		"assignment": assignment_rng.randi(),
		"decor": decor_rng.randi(),
	}
	var blocked_polygons := PlazaMapLayoutGenerator._build_blocked_polygons(buildings, decor_clusters)
	var walkable_corridors := PlazaMapLayoutGenerator._build_walkable_corridors(road)
	var walkable_hubs := _build_walkable_hub_manifest()
	for hub in walkable_hubs:
		walkable_corridors.append(hub.duplicate(true))
	var interaction_portals := PlazaMapLayoutGenerator._build_interaction_portals(buildings)
	var selected_types: Array[String] = []
	for spec in selected_specs:
		selected_types.append(str(spec.get("type", "")))
	var layout := {
		"schema_version": PlazaMapLayoutGenerator.SCHEMA_VERSION,
		"generator_version": GENERATOR_VERSION,
		"source_generator_version": PlazaMapLayoutGenerator.GENERATOR_VERSION,
		"source_layout_fingerprint": str(source.get("fingerprint", "")),
		"stage_id": normalized_stage,
		"map_seed": map_seed,
		"world_size": safe_world_size,
		"spawn_anchor": safe_spawn,
		"exit_zone": safe_exit_zone,
		"selected_building_types": selected_types,
		"road_graph": road,
		"plot_boundary_overlap_policy": PlazaMapLayoutGenerator.PLOT_BOUNDARY_OVERLAP_POLICY,
		"plot_assignment_signature": PlazaMapLayoutGenerator._plot_assignment_signature(plots),
		"plots": plots,
		"building_specs": buildings,
		"decor_clusters": decor_clusters,
		"blocked_polygons": blocked_polygons,
		"walkable_corridor_polygons": walkable_corridors,
		"walkable_hub_polygons": walkable_hubs,
		"interaction_portals": interaction_portals,
		"main_route_length_world": float(road.get("main_route_length_world", 0.0)),
		"road_art_exclusion_zones": [{
			"id": CENTRAL_PLAZA_EXCLUSION_ID,
			"kind": "approved_ground_plaza_surface",
			"polygon_world": CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD.duplicate(),
		}],
		"central_plaza_hub_contract": {
			"id": CENTRAL_PLAZA_HUB_CONTRACT_ID,
			"source_manifest_path": CENTRAL_PLAZA_HUB_MANIFEST_PATH,
			"polygon_sha256": _polygon_token(CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD).sha256_text(),
			"navigation_policy": "full_body_walkable_union_member",
			"road_render_policy": "no_straight_stamp_inside_hub",
		},
		"basis_endpoint_render_policy": "authored_special_or_physical_cap_overlap",
		"building_label_fit_policy": BUILDING_LABEL_FIT_POLICY,
		"straight_cap_overlap_world": STRAIGHT_CAP_OVERLAP_WORLD,
		"screen_vertical_road_render_policy": "forbidden_except_unbound_authored_three_way_arm",
		"road_basis_contract": _road_basis_contract(),
		"r2_semantic_invariants": {
			"selected_building_types": selected_types.duplicate(),
			"assignment_order": _building_type_order(buildings),
			"plot_class_order": _plot_class_order(plots),
			"phase_rng_draw_counts": {
				"skeleton_float": PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT * 2,
				"plots_float": PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT * 2,
				"assignment_int": selected_specs.size(),
				"decor_int_or_float": (PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT - selected_specs.size()) * 5,
			},
			"phase_rng_tail_samples": phase_rng_tail_samples,
			"coordinate_policy": "versioned_r3_authority_not_r2_byte_preservation",
		},
		"candidate_only": true,
		"production_connected": false,
	}
	layout["road_piece_bindings"] = _build_road_piece_bindings(layout)
	layout["road_piece_usage"] = _build_road_piece_usage(layout)
	layout["road_crossing_bindings"] = _build_internal_crossing_bindings(road)
	layout["fingerprint"] = build_fingerprint(layout)
	layout["validation"] = validate_layout(layout)
	if capture_plot_availability_debug:
		layout["plot_availability_debug"] = plot_debug_diagnostics.get("plot_availability_debug", [])
		layout["plot_availability_context"] = plot_debug_diagnostics.get("plot_availability_context", {})
	return layout


static func promote_layout(source_layout: Dictionary) -> Dictionary:
	# A0.4 intentionally removes post-generation coordinate promotion. Keeping a
	# fail-closed compatibility symbol makes stale A0.2/A0.3 callers observable.
	if source_layout.is_empty():
		return _rejected_layout("source_layout_missing")
	return _rejected_layout("post_generation_promotion_retired")


static func _road_basis_contract() -> Dictionary:
	return {
		"projection": "orthographic_oblique",
		"allowed_slopes": [-BASIS_SLOPE_MAGNITUDE, 0.0, BASIS_SLOPE_MAGNITUDE],
		"vertical_allowed": false,
		"authored_three_way_vertical_arm_allowed": true,
		"arbitrary_rotation_allowed": false,
		"art_orientation_source": "approved_runtime_png_alpha_geometry",
		"three_way_signature": "north_east+north_west+south",
		"terminus_signature": "terminus_opens_north_east",
		"plot_spur_signature": "trail_enters_south_east",
		"entrance_forecourt_signature": "approach_enters_north_east",
		"minimum_continuous_arm_run_world": {
			"three_way": THREE_WAY_ARM_RUN_WORLD,
			"terminus": TERMINUS_ARM_RUN_WORLD,
			"plot_spur": PLOT_SPUR_ARM_RUN_WORLD,
			"entrance_forecourt": ENTRANCE_FORECOURT_ARM_RUN_WORLD,
		},
	}


static func _build_integrated_main_road_graph(
	source_road: Dictionary,
	spawn_anchor: Vector2,
	exit_center: Vector2,
	world_size: Vector2
) -> Dictionary:
	var source_nodes := _dictionary_array(source_road.get("nodes", []))
	var nodes: Array[Dictionary] = [{
		"id": "spawn",
		"role": "spawn",
		"position": spawn_anchor,
	}]
	for index in range(PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT):
		var source_node := _find_by_id(source_nodes, "main_%d" % index)
		if source_node.is_empty():
			return {"valid": false, "rejection_reason": "source_main_node_missing:%d" % index}
		var source_position := _coerce_vector2(source_node.get("position", Vector2.INF))
		if not source_position.is_finite():
			return {"valid": false, "rejection_reason": "source_main_node_invalid:%d" % index}
		var authored_site := R3_MAIN_SITE_BY_SLOT[index]
		nodes.append({
			"id": "main_%d" % index,
			"role": "central_plaza_route_node",
			"position": authored_site,
		})
	nodes.append({
		"id": "exit",
		"role": "exit",
		"position": exit_center,
	})

	var ordered_ids: Array[String] = ["spawn"]
	for index in range(PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT):
		ordered_ids.append("main_%d" % index)
	ordered_ids.append("exit")
	var edges: Array[Dictionary] = []
	for index in range(ordered_ids.size() - 1):
		var from_id := ordered_ids[index]
		var to_id := ordered_ids[index + 1]
		var start := _coerce_vector2(_find_by_id(nodes, from_id).get("position", Vector2.INF))
		var finish := _coerce_vector2(_find_by_id(nodes, to_id).get("position", Vector2.INF))
		var polyline := _build_integrated_main_edge(start, finish, from_id, to_id, world_size)
		if polyline.size() < 2:
			return {"valid": false, "rejection_reason": "integrated_main_edge_failed:%s:%s" % [from_id, to_id]}
		edges.append({
			"id": "main_%s_to_%s" % [from_id, to_id],
			"kind": "main",
			"from": from_id,
			"to": to_id,
			"half_width_world": PlazaMapLayoutGenerator.ROAD_HALF_WIDTH_WORLD,
			"polyline_world": _split_polyline_at_central_plaza(polyline),
		})
	var secondary_result := _append_integrated_secondary_trunks(nodes, edges)
	if not bool(secondary_result.get("valid", false)):
		return secondary_result
	nodes = _dictionary_array(secondary_result.get("nodes", nodes))
	edges = _dictionary_array(secondary_result.get("edges", edges))
	var road := {
		"skeleton_variant": "%s:r3a06_walkable_hub_side_trees" % str(source_road.get("skeleton_variant", "")),
		"secondary_side": str(source_road.get("secondary_side", "")),
		"secondary_anchor_slots": (source_road.get("secondary_anchor_slots", []) as Array).duplicate(),
		"spawn_node_id": "spawn",
		"exit_node_id": "exit",
		"nodes": nodes,
		"edges": edges,
		"main_route_node_ids": ordered_ids,
		# The production composition budget is specifically spawn -> plaza. Later
		# plot junctions may turn without falsifying that player-facing spine gate.
		"main_spine_world": _vector2_array(edges[0].get("polyline_world", [])),
		"main_spine_turn_count": _polyline_basis_turn_count(_vector2_array(edges[0].get("polyline_world", []))),
		"main_spine_destination": "central_plaza",
	}
	var distance_result := _rebuild_main_route_distances(road)
	if not bool(distance_result.get("valid", false)):
		return distance_result
	road["nodes"] = distance_result.get("nodes", nodes)
	road["main_route_length_world"] = float(distance_result.get("route_length_world", 0.0))
	return {"valid": true, "road_graph": road}


static func _append_integrated_secondary_trunks(
	nodes: Array[Dictionary],
	edges: Array[Dictionary]
) -> Dictionary:
	for spec_value in R3_SECONDARY_NODE_SPECS:
		var spec: Dictionary = (spec_value as Dictionary).duplicate(true)
		nodes.append(spec)
	var secondary_half_width := PlazaMapLayoutGenerator._canonical_road_half_width("secondary")
	for spec_value in R3_SECONDARY_EDGE_SPECS:
		var spec := spec_value as Dictionary
		var start := _coerce_vector2(_find_by_id(nodes, str(spec.get("from", ""))).get("position", Vector2.INF))
		var finish := _coerce_vector2(_find_by_id(nodes, str(spec.get("to", ""))).get("position", Vector2.INF))
		var polyline: Array[Vector2] = []
		if bool(spec.get("root", false)):
			# Hub gates are authored topology. Do not let String.hash() choose which
			# of the two legal oblique decompositions escapes the hub: the other order
			# can make a large out-of-world detour before returning to the same node.
			polyline = _split_polyline_at_central_plaza(_build_basis_polyline(
				start,
				finish,
				str(spec.get("id", "")),
				bool(spec.get("negative_first", false))
			))
		else:
			polyline = _compact_polyline([start, finish] as Array[Vector2])
		if polyline.size() < 2:
			return {"valid": false, "rejection_reason": "secondary_trunk_polyline_invalid:%s" % str(spec.get("id", ""))}
		edges.append({
			"id": str(spec.get("id", "")),
			"kind": "secondary",
			"from": str(spec.get("from", "")),
			"to": str(spec.get("to", "")),
			"half_width_world": secondary_half_width,
			"polyline_world": polyline,
			"trunk_side": str(spec.get("trunk", "")),
		})
	return {"valid": true, "nodes": nodes, "edges": edges}


static func _build_integrated_main_edge(
	start: Vector2,
	finish: Vector2,
	from_id: String,
	to_id: String,
	_world_size: Vector2
) -> Array[Vector2]:
	var north_east := Vector2(2.0, -1.0).normalized()
	if from_id == "spawn":
		var start_port := start + north_east * TERMINUS_ARM_RUN_WORLD
		var result: Array[Vector2] = [start, start_port]
		_append_polyline(result, _build_basis_polyline(start_port, finish, "main_spawn_to_hub"))
		return _split_polyline_at_central_plaza(_compact_polyline(result))
	if to_id == "exit":
		return _split_polyline_at_central_plaza(_build_basis_polyline(start, finish, "main_hub_to_exit", true))
	# The R2-compatible main_i chain is a distance/assignment authority inside
	# the authored hub. It is deliberately not stamped as road art.
	return _compact_polyline([start, finish] as Array[Vector2])


static func _build_authored_site_reservations() -> Array[Dictionary]:
	var reservations: Array[Dictionary] = []
	for plot_class_value in R3_PLOT_SITE_BY_CLASS.keys():
		var plot_class := str(plot_class_value)
		var extents_value: Variant = PlazaMapLayoutGenerator.PLOT_BOUNDARY_EXTENTS_BY_CLASS.get(plot_class, Vector4(215.0, 110.0, 165.0, 25.0))
		var extents: Vector4 = extents_value
		var pivot: Vector2 = R3_PLOT_SITE_BY_CLASS.get(plot_class, Vector2.INF)
		var reserved_front_extent := maxf(extents.w, R3_PLOT_FORECOURT_FRONT_RESERVE_WORLD)
		reservations.append({
			"id": "reserved_plot_%s" % plot_class,
			"boundary_polygon_world": [
				pivot + Vector2(-extents.x - 22.0, -extents.z - 12.0),
				pivot + Vector2(extents.y + 22.0, -extents.z - 12.0),
				pivot + Vector2(extents.y + 22.0, reserved_front_extent + 12.0),
				pivot + Vector2(-extents.x - 22.0, reserved_front_extent + 12.0),
			],
		})
	return reservations


static func _build_integrated_plots(
	road: Dictionary,
	world_size: Vector2,
	rng: RandomNumberGenerator,
	plot_assignments: Array[Dictionary],
	selected_specs: Array[Dictionary],
	capture_availability_debug: bool = false
) -> Dictionary:
	var nodes := _dictionary_array(road.get("nodes", []))
	var plots: Array[Dictionary] = []
	var route_plans: Array[Dictionary] = []
	var committed_building_blockers: Array[Dictionary] = []
	var committed_route_blockers: Array[Dictionary] = []
	var availability_debug: Array[Dictionary] = []
	# Preserve the exact R2 plot-stream call count/order before solving. Placement
	# order is a deterministic constraint-solving detail and must not feed RNG.
	for _index in range(PlazaMapLayoutGenerator.PLOT_ROUTE_SLOTS.size()):
		rng.randf_range(-18.0, 18.0)
		rng.randf_range(-12.0, 12.0)
	var placement_indices: Array[int] = []
	for index in range(PlazaMapLayoutGenerator.PLOT_ROUTE_SLOTS.size()):
		placement_indices.append(index)
	placement_indices.sort_custom(func(left: int, right: int) -> bool:
		var left_class := str(plot_assignments[left].get("plot_class", "")) if left < plot_assignments.size() else ""
		var right_class := str(plot_assignments[right].get("plot_class", "")) if right < plot_assignments.size() else ""
		var left_priority := int(R3_PLOT_RESOLUTION_PRIORITY_BY_CLASS.get(left_class, 999))
		var right_priority := int(R3_PLOT_RESOLUTION_PRIORITY_BY_CLASS.get(right_class, 999))
		return left_priority < right_priority if left_priority != right_priority else left < right
	)
	for index in placement_indices:
		var archetype: Dictionary = plot_assignments[index] if index < plot_assignments.size() else {}
		var main_node_id := "main_%d" % index
		var plot_class := str(archetype.get("plot_class", ""))
		var branch_node_id := str(R3_PLOT_BRANCH_NODE_BY_CLASS.get(plot_class, ""))
		var main_node := _find_by_id(nodes, main_node_id)
		var branch_node := _find_by_id(nodes, branch_node_id)
		if main_node.is_empty():
			return {"valid": false, "rejection_reason": "integrated_plot_main_node_missing:%d" % index}
		if branch_node.is_empty():
			return {"valid": false, "rejection_reason": "integrated_plot_branch_node_missing:%s" % plot_class}
		# R3 owns seven outer-band reservations and aligns each local forecourt to
		# the road phase's H / +/-0.5 lattice. The R2 draws were consumed above.
		var plot_id := str(archetype.get("id", "plot_%d" % index))
		var branch_port := _coerce_vector2(branch_node.get("position", Vector2.INF))
		if str(branch_node.get("role", "")) == "road_piece_junction":
			branch_port += Vector2.DOWN * THREE_WAY_ARM_RUN_WORLD
		var authored_site_value: Variant = R3_PLOT_SITE_BY_CLASS.get(plot_class, Vector2.INF)
		if not (authored_site_value is Vector2) or not (authored_site_value as Vector2).is_finite():
			return {"valid": false, "rejection_reason": "integrated_plot_class_site_missing:%s" % plot_class}
		var resolved_candidate: Dictionary = {}
		var rejection_counts := {}
		for pivot in _build_plot_pivot_candidates(plot_class, selected_specs, branch_port):
			var availability_record := {}
			if capture_availability_debug:
				availability_record = {
					"plot_id": plot_id,
					"plot_class": plot_class,
					"route_slot_index": index,
					"pivot": pivot,
					"accepted": false,
					"dominant_rejection": "",
					"route_rejections": {},
				}
			if not _plot_pivot_inside_semantic_band(plot_class, pivot):
				rejection_counts["outside_semantic_band"] = int(rejection_counts.get("outside_semantic_band", 0)) + 1
				if capture_availability_debug:
					availability_record["dominant_rejection"] = "outside_semantic_band"
					availability_debug.append(availability_record)
				continue
			var candidate := _build_integrated_plot_record(
				plot_id,
				plot_class,
				index,
				main_node_id,
				branch_node_id,
				float(main_node.get("route_distance_world", 0.0)),
				pivot,
				selected_specs
			)
			var rejection_reason := _integrated_plot_candidate_rejection_reason(
				candidate,
				plots,
				road,
				selected_specs,
				world_size,
				committed_route_blockers
			)
			if rejection_reason == "":
				var matching_spec := _find_spec_by_plot_class(selected_specs, plot_class)
				var roster_envelope := _build_roster_building_footprint_envelope(selected_specs, candidate)
				var provisional_building: Dictionary = {}
				if not matching_spec.is_empty():
					provisional_building = PlazaMapLayoutGenerator._place_building_spec(matching_spec, candidate, -1)
				var route_contract := _build_plot_route_contract(candidate, branch_node, provisional_building)
				if capture_availability_debug:
					availability_record["branch_port"] = route_contract.get("branch_port", Vector2.INF)
					availability_record["destination"] = route_contract.get("destination", Vector2.INF)
					availability_record["pre_destination"] = route_contract.get("pre_destination", Vector2.INF)
				if not bool(route_contract.get("valid", false)):
					rejection_counts["route_contract_invalid"] = int(rejection_counts.get("route_contract_invalid", 0)) + 1
					if capture_availability_debug:
						availability_record["dominant_rejection"] = "route_contract_invalid"
						availability_debug.append(availability_record)
					continue
				var branch_arm_rejection := _authored_branch_arm_envelope_rejection_reason(route_contract, roster_envelope)
				if branch_arm_rejection != "":
					rejection_counts[branch_arm_rejection] = int(rejection_counts.get(branch_arm_rejection, 0)) + 1
					if capture_availability_debug:
						availability_record["dominant_rejection"] = branch_arm_rejection
						availability_debug.append(availability_record)
					continue
				var candidate_plots: Array[Dictionary] = plots.duplicate(true)
				candidate_plots.append(candidate)
				var candidate_blockers: Array[Dictionary] = committed_building_blockers.duplicate(true)
				candidate_blockers.append_array(committed_route_blockers)
				if roster_envelope.size() >= 3:
					candidate_blockers.append(_build_roster_envelope_blocker(plot_id, roster_envelope))
				candidate_blockers.append_array(_build_existing_road_route_blockers(
					road,
					branch_node_id,
					_coerce_vector2(branch_node.get("position", Vector2.INF))
				))
				var route_diagnostics := {}
				var routed := _route_basis_around_other_plots(
					_coerce_vector2(route_contract.get("branch_port", Vector2.INF)),
					_coerce_vector2(route_contract.get("destination", Vector2.INF)),
					float(route_contract.get("pre_destination_x", 0.0)),
					float(route_contract.get("half_width", 0.0)),
					candidate_plots,
					candidate_blockers,
					plot_id,
					world_size,
					_coerce_vector2(route_contract.get("pre_destination", Vector2.INF)),
					bool(route_contract.get("trim_final", false)),
					route_diagnostics
				)
				if routed.size() < 2:
					for route_rejection_value in route_diagnostics.keys():
						var route_rejection := "route:%s" % str(route_rejection_value)
						rejection_counts[route_rejection] = int(rejection_counts.get(route_rejection, 0)) + int(route_diagnostics.get(route_rejection_value, 0))
					if capture_availability_debug:
						availability_record["route_rejections"] = route_diagnostics.duplicate(true)
						availability_record["dominant_rejection"] = "route:%s" % _dominant_rejection_reason(route_diagnostics)
						availability_debug.append(availability_record)
					continue
				var route_plan: Dictionary = route_contract.duplicate(true)
				route_plan["routed_polyline_world"] = routed
				resolved_candidate = candidate
				route_plans.append(route_plan)
				if roster_envelope.size() >= 3:
					committed_building_blockers.append(_build_roster_envelope_blocker(plot_id, roster_envelope))
				committed_route_blockers.append_array(_build_route_corridor_blockers(route_plan))
				if capture_availability_debug:
					availability_record["accepted"] = true
					availability_record["dominant_rejection"] = "accepted"
					availability_debug.append(availability_record)
				break
			rejection_counts[rejection_reason] = int(rejection_counts.get(rejection_reason, 0)) + 1
			if capture_availability_debug:
				availability_record["dominant_rejection"] = rejection_reason
				availability_debug.append(availability_record)
		if resolved_candidate.is_empty():
			var rejected_result := {
				"valid": false,
				"rejection_reason": "integrated_plot_site_unresolved:%s:class=%s:branch=%s:rejections=%s" % [plot_id, plot_class, branch_node_id, JSON.stringify(rejection_counts)],
				"availability_debug": availability_debug,
			}
			if capture_availability_debug:
				rejected_result["availability_context"] = _build_plot_availability_context(
					plots,
					route_plans,
					committed_route_blockers
				)
			return rejected_result
		plots.append(resolved_candidate)
	plots.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("route_slot_index", -1)) < int(right.get("route_slot_index", -1))
	)
	route_plans.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("route_slot_index", -1)) < int(right.get("route_slot_index", -1))
	)
	var result := {"valid": true, "plots": plots, "route_plans": route_plans}
	if capture_availability_debug:
		result["availability_debug"] = availability_debug
		result["availability_context"] = _build_plot_availability_context(
			plots,
			route_plans,
			committed_route_blockers
		)
	return result


static func _build_plot_availability_context(
	plots: Array[Dictionary],
	route_plans: Array[Dictionary],
	committed_route_blockers: Array[Dictionary]
) -> Dictionary:
	var plot_records: Array[Dictionary] = []
	for plot in plots:
		var plot_record: Dictionary = plot.duplicate(true)
		plot_records.append(plot_record)
	var route_records: Array[Dictionary] = []
	for route_plan in route_plans:
		var route_record: Dictionary = route_plan.duplicate(true)
		route_record["full_polyline_world"] = _build_route_plan_polyline(route_plan)
		route_records.append(route_record)
	var corridor_records: Array[Dictionary] = []
	for blocker in committed_route_blockers:
		var corridor_record: Dictionary = blocker.duplicate(true)
		corridor_records.append(corridor_record)
	return {
		"committed_plots": plot_records,
		"committed_route_plans": route_records,
		"committed_route_blockers": corridor_records,
	}


static func _dominant_rejection_reason(counts: Dictionary) -> String:
	var result := "unknown"
	var best_count := -1
	for key_value in counts.keys():
		var key := str(key_value)
		var count := int(counts.get(key_value, 0))
		if count > best_count:
			result = key
			best_count = count
	return result


static func _build_plot_site_candidates(plot_class: String) -> Array[Vector2]:
	var authored_value: Variant = R3_PLOT_SITE_BY_CLASS.get(plot_class, null)
	var band_value: Variant = R3_PLOT_SITE_BAND_BY_CLASS.get(plot_class, null)
	if not (authored_value is Vector2) or not (band_value is Rect2):
		return []
	var authored := authored_value as Vector2
	var band := band_value as Rect2
	var ranked: Array[Dictionary] = [{"site": authored, "distance_squared": 0.0}]
	var y := ceilf(band.position.y / R3_PLOT_SITE_SEARCH_STEP_WORLD) * R3_PLOT_SITE_SEARCH_STEP_WORLD
	while y <= band.end.y + BASIS_EPSILON:
		var x := ceilf(band.position.x / R3_PLOT_SITE_SEARCH_STEP_WORLD) * R3_PLOT_SITE_SEARCH_STEP_WORLD
		while x <= band.end.x + BASIS_EPSILON:
			var site := Vector2(x, y)
			if not site.is_equal_approx(authored):
				ranked.append({"site": site, "distance_squared": site.distance_squared_to(authored)})
			x += R3_PLOT_SITE_SEARCH_STEP_WORLD
		y += R3_PLOT_SITE_SEARCH_STEP_WORLD
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_distance := float(left.get("distance_squared", INF))
		var right_distance := float(right.get("distance_squared", INF))
		if not is_equal_approx(left_distance, right_distance):
			return left_distance < right_distance
		var left_site := _coerce_vector2(left.get("site", Vector2.INF))
		var right_site := _coerce_vector2(right.get("site", Vector2.INF))
		if not is_equal_approx(left_site.y, right_site.y):
			return left_site.y < right_site.y
		return left_site.x < right_site.x
	)
	var result: Array[Vector2] = []
	var seen := {}
	for record in ranked:
		var site := _coerce_vector2(record.get("site", Vector2.INF))
		var token := _vector_token(site)
		if site.is_finite() and not seen.has(token):
			seen[token] = true
			result.append(site)
	return result


static func _build_plot_pivot_candidates(
	plot_class: String,
	selected_specs: Array[Dictionary],
	branch_port: Vector2
) -> Array[Vector2]:
	var authored_value: Variant = R3_PLOT_SITE_BY_CLASS.get(plot_class, null)
	if not (authored_value is Vector2):
		return []
	var authored := authored_value as Vector2
	var ranked: Array[Dictionary] = []
	var seen := {}
	for site in _build_plot_site_candidates(plot_class):
		var pivot := _align_plot_pivot_to_route_lattice(site, plot_class, selected_specs, branch_port)
		if not _plot_pivot_inside_semantic_band(plot_class, pivot):
			continue
		var token := _vector_token(pivot)
		if seen.has(token):
			continue
		seen[token] = true
		ranked.append({"pivot": pivot, "distance_squared": pivot.distance_squared_to(authored)})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_distance := float(left.get("distance_squared", INF))
		var right_distance := float(right.get("distance_squared", INF))
		if not is_equal_approx(left_distance, right_distance):
			return left_distance < right_distance
		var left_pivot := _coerce_vector2(left.get("pivot", Vector2.INF))
		var right_pivot := _coerce_vector2(right.get("pivot", Vector2.INF))
		if not is_equal_approx(left_pivot.y, right_pivot.y):
			return left_pivot.y < right_pivot.y
		return left_pivot.x < right_pivot.x
	)
	var result: Array[Vector2] = []
	for record in ranked:
		result.append(_coerce_vector2(record.get("pivot", Vector2.INF)))
	return result


static func _align_plot_pivot_to_route_lattice(
	authored_site: Vector2,
	plot_class: String,
	selected_specs: Array[Dictionary],
	branch_port: Vector2
) -> Vector2:
	var matching_spec := _find_spec_by_plot_class(selected_specs, plot_class)
	var raw_target := authored_site + Vector2(R3_DECOR_TRAIL_ANCHOR_OFFSET_X, 0.0)
	if not matching_spec.is_empty():
		var display_scale := maxf(0.0001, float(matching_spec.get("display_scale", 1.0)))
		raw_target = authored_site + _coerce_vector2(matching_spec.get("entrance_anchor_offset", Vector2.ZERO)) * display_scale
		raw_target += Vector2(-2.0, 1.0).normalized() * ENTRANCE_FORECOURT_ARM_RUN_WORLD
	else:
		raw_target += Vector2(-2.0, -1.0).normalized() * PLOT_SPUR_ARM_RUN_WORLD
	var aligned_target := Vector2(
		branch_port.x + roundf((raw_target.x - branch_port.x) / R3_ROUTE_GRID_X_WORLD) * R3_ROUTE_GRID_X_WORLD,
		branch_port.y + roundf((raw_target.y - branch_port.y) / R3_ROUTE_GRID_Y_WORLD) * R3_ROUTE_GRID_Y_WORLD
	)
	return authored_site + (aligned_target - raw_target)


static func _find_plot_by_class(plots: Array[Dictionary], plot_class: String) -> Dictionary:
	for plot in plots:
		if str(plot.get("plot_class", "")) == plot_class:
			return plot
	return {}


static func _plot_pivot_inside_semantic_band(plot_class: String, pivot: Vector2) -> bool:
	var band_value: Variant = R3_PLOT_SITE_BAND_BY_CLASS.get(plot_class, null)
	if not (band_value is Rect2) or not pivot.is_finite():
		return false
	var band := band_value as Rect2
	return (
		pivot.x >= band.position.x - BASIS_EPSILON
		and pivot.y >= band.position.y - BASIS_EPSILON
		and pivot.x <= band.end.x + BASIS_EPSILON
		and pivot.y <= band.end.y + BASIS_EPSILON
	)


static func _build_integrated_plot_record(
	plot_id: String,
	plot_class: String,
	route_slot_index: int,
	main_node_id: String,
	road_branch_node_id: String,
	main_route_distance_world: float,
	pivot: Vector2,
	selected_specs: Array[Dictionary]
) -> Dictionary:
	var extents_value: Variant = PlazaMapLayoutGenerator.PLOT_BOUNDARY_EXTENTS_BY_CLASS.get(plot_class, Vector4(150.0, 110.0, 120.0, 25.0))
	var extents: Vector4 = extents_value
	var front_extent := maxf(extents.w, R3_PLOT_FORECOURT_FRONT_RESERVE_WORLD)
	return {
		"id": plot_id,
		"plot_class": plot_class,
		"route_slot_index": route_slot_index,
		"main_node_id": main_node_id,
		"road_branch_node_id": road_branch_node_id,
		"main_route_distance_world": main_route_distance_world,
		"pivot_pos": pivot,
		"boundary_polygon_world": [
			pivot + Vector2(-extents.x, -extents.z),
			pivot + Vector2(extents.y, -extents.z),
			pivot + Vector2(extents.y, front_extent),
			pivot + Vector2(-extents.x, front_extent),
		],
		"approach_side": "lower_left",
		"occupied_by": "",
		"decor_cluster_id": "",
		"forecourt_reservation_polygon_world": _build_forecourt_reservation(pivot, plot_class, selected_specs),
		"forecourt_reserved_run_world": ENTRANCE_FORECOURT_ARM_RUN_WORLD,
	}


static func _build_plot_route_contract(
	plot: Dictionary,
	branch_node: Dictionary,
	building: Dictionary
) -> Dictionary:
	var plot_id := str(plot.get("id", ""))
	var main_node_id := str(plot.get("road_branch_node_id", plot.get("main_node_id", "")))
	var junction := _coerce_vector2(branch_node.get("position", Vector2.INF))
	var branch_port := junction
	if str(branch_node.get("role", "")) == "road_piece_junction":
		branch_port += Vector2.DOWN * THREE_WAY_ARM_RUN_WORLD
	var occupied := not building.is_empty()
	var destination := (
		_coerce_vector2(building.get("entrance_world_pos", Vector2.INF))
		if occupied
		else _coerce_vector2(plot.get("pivot_pos", Vector2.INF)) + Vector2(R3_DECOR_TRAIL_ANCHOR_OFFSET_X, 0.0)
	)
	var pre_destination := (
		destination + Vector2(-2.0, 1.0).normalized() * ENTRANCE_FORECOURT_ARM_RUN_WORLD
		if occupied
		else destination + Vector2(-2.0, -1.0).normalized() * PLOT_SPUR_ARM_RUN_WORLD
	)
	var edge_kind := "approach" if occupied else "trail"
	var node_id := "%s_%s" % [edge_kind, plot_id]
	var half_width := PlazaMapLayoutGenerator._canonical_road_half_width(edge_kind)
	return {
		"valid": plot_id != "" and main_node_id != "" and junction.is_finite() and destination.is_finite() and half_width > 0.0,
		"plot_id": plot_id,
		"route_slot_index": int(plot.get("route_slot_index", -1)),
		"main_node_id": main_node_id,
		"node_id": node_id,
		"edge_id": node_id,
		"edge_kind": edge_kind,
		"junction": junction,
		"branch_port": branch_port,
		"destination": destination,
		"pre_destination": pre_destination,
		"pre_destination_x": pre_destination.x,
		"half_width": half_width,
		"trim_final": occupied,
	}


static func _build_route_plan_polyline(route_plan: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = [_coerce_vector2(route_plan.get("junction", Vector2.INF))]
	_append_point(result, _coerce_vector2(route_plan.get("branch_port", Vector2.INF)))
	_append_polyline(
		result,
		_split_polyline_at_central_plaza(_vector2_array(route_plan.get("routed_polyline_world", [])))
	)
	return _compact_polyline(result)


static func _build_route_corridor_blockers(route_plan: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var polyline := _build_route_plan_polyline(route_plan)
	var half_width := float(route_plan.get("half_width", 0.0))
	if polyline.size() < 2 or half_width <= 0.0:
		return result
	for segment_index in range(polyline.size() - 1):
		var polygon := _segment_corridor_polygon(polyline[segment_index], polyline[segment_index + 1], half_width)
		if polygon.size() < 3:
			continue
		result.append({
			"id": "reserved_route:%s:%d" % [str(route_plan.get("plot_id", "")), segment_index],
			"owner_id": str(route_plan.get("plot_id", "")),
			"kind": "reserved_plot_route",
			"polygon_world": polygon,
		})
	return result


static func _build_existing_road_route_blockers(
	road: Dictionary,
	branch_node_id: String,
	branch_anchor: Vector2
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if branch_node_id == "" or not branch_anchor.is_finite():
		return result
	for edge in _dictionary_array(road.get("edges", [])):
		var edge_id := str(edge.get("id", ""))
		var polyline := _vector2_array(edge.get("polyline_world", []))
		if edge_id == "" or polyline.size() < 2:
			continue
		var incident := (
			str(edge.get("from", "")) == branch_node_id
			or str(edge.get("to", "")) == branch_node_id
		)
		for segment_index in range(polyline.size() - 1):
			var start := polyline[segment_index]
			var finish := polyline[segment_index + 1]
			if start.distance_to(finish) <= BASIS_EPSILON:
				continue
			result.append({
				"id": "reserved_road_centerline:%s:%d" % [edge_id, segment_index],
				"owner_id": edge_id,
				"kind": "forbidden_road_centerline",
				"start_world": start,
				"finish_world": finish,
				"allowed_anchor_world": branch_anchor if incident else Vector2.INF,
			})
	return result


static func _plot_route_contract_matches(stored: Dictionary, expected: Dictionary) -> bool:
	for key in ["plot_id", "main_node_id", "node_id", "edge_id", "edge_kind"]:
		if str(stored.get(key, "")) != str(expected.get(key, "")):
			return false
	for key in ["junction", "branch_port", "destination", "pre_destination"]:
		if not _coerce_vector2(stored.get(key, Vector2.INF)).is_equal_approx(_coerce_vector2(expected.get(key, Vector2.INF))):
			return false
	return (
		int(stored.get("route_slot_index", -1)) == int(expected.get("route_slot_index", -2))
		and is_equal_approx(float(stored.get("half_width", -1.0)), float(expected.get("half_width", -2.0)))
		and bool(stored.get("trim_final", false)) == bool(expected.get("trim_final", true))
	)


static func _integrated_plot_candidate_is_clear(
	candidate: Dictionary,
	placed_plots: Array[Dictionary],
	road: Dictionary,
	selected_specs: Array[Dictionary],
	world_size: Vector2,
	committed_route_blockers: Array[Dictionary] = []
) -> bool:
	return _integrated_plot_candidate_rejection_reason(candidate, placed_plots, road, selected_specs, world_size, committed_route_blockers) == ""


static func _integrated_plot_candidate_rejection_reason(
	candidate: Dictionary,
	placed_plots: Array[Dictionary],
	road: Dictionary,
	selected_specs: Array[Dictionary],
	world_size: Vector2,
	committed_route_blockers: Array[Dictionary] = []
) -> String:
	var boundary := _vector2_array(candidate.get("boundary_polygon_world", []))
	if boundary.size() < 3:
		return "boundary_invalid"
	for point in boundary:
		if point.x < 0.0 or point.y < 0.0 or point.x > world_size.x or point.y > world_size.y:
			return "boundary_outside_world"
	if _polygon_intersection_area(boundary, CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD) > 0.01:
		return "central_plaza_overlap"
	for placed_plot in placed_plots:
		if _polygon_intersection_area(boundary, _vector2_array(placed_plot.get("boundary_polygon_world", []))) > 0.01:
			return "plot_overlap:%s" % str(placed_plot.get("id", ""))
	var boundary_road_overlap := _first_road_corridor_intersection(boundary, road)
	if boundary_road_overlap != "":
		return "main_road_overlap:%s" % boundary_road_overlap
	for blocker in committed_route_blockers:
		if _polygon_intersection_area(boundary, _vector2_array(blocker.get("polygon_world", []))) > 0.01:
			return "committed_route_overlap:%s" % str(blocker.get("id", ""))
	var reservation := _vector2_array(candidate.get("forecourt_reservation_polygon_world", []))
	if not reservation.is_empty():
		for point in reservation:
			if point.x < 0.0 or point.y < 0.0 or point.x > world_size.x or point.y > world_size.y:
				return "forecourt_outside_world"
		if _polygon_intersection_area(reservation, CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD) > 0.01:
			return "forecourt_central_overlap"
	var matching_specs := _find_specs_by_plot_class(selected_specs, str(candidate.get("plot_class", "")))
	if matching_specs.is_empty():
		return ""
	for matching_spec in matching_specs:
		var placed_building := PlazaMapLayoutGenerator._place_building_spec(matching_spec, candidate, -1)
		_apply_r3_label_world_fit_to_building(placed_building, world_size)
		for rect_key in ["visual_rect", "label_rect_world"]:
			var rect_value: Variant = placed_building.get(rect_key, null)
			if not (rect_value is Rect2) or not _rect_inside_world(rect_value as Rect2, world_size):
				return "building_%s_outside_world" % rect_key
		var footprint := _vector2_array(placed_building.get("footprint_world_polygon", []))
		for point in footprint:
			if not PlazaMapLayoutGenerator._point_in_or_on_polygon(point, boundary):
				return "building_footprint_outside_plot"
		if _polygon_intersects_road_corridors(footprint, road):
			return "building_footprint_main_road_overlap"
	return ""


static func _apply_r3_label_world_fit(buildings: Array[Dictionary], world_size: Vector2) -> void:
	for building in buildings:
		_apply_r3_label_world_fit_to_building(building, world_size)


static func _apply_r3_label_world_fit_to_building(building: Dictionary, world_size: Vector2) -> void:
	var label_value: Variant = building.get("label_rect_world", null)
	if not (label_value is Rect2):
		return
	var label_rect := label_value as Rect2
	if label_rect.end.x <= world_size.x + BASIS_EPSILON:
		return
	var label_stem := _coerce_vector2(building.get("label_world_pos", Vector2.INF))
	if not label_stem.is_finite():
		return
	var left_position := label_stem + Vector2(
		-PlazaMapLayoutGenerator.LABEL_STEM_GAP_WORLD - label_rect.size.x,
		-label_rect.size.y * 0.5
	)
	var left_rect := Rect2(left_position, label_rect.size)
	if left_rect.position.x < -BASIS_EPSILON:
		return
	building["label_rect_world"] = left_rect


static func _authored_branch_arm_envelope_rejection_reason(
	route_contract: Dictionary,
	roster_envelope: Array[Vector2]
) -> String:
	if roster_envelope.size() < 3:
		return ""
	var junction := _coerce_vector2(route_contract.get("junction", Vector2.INF))
	var branch_port := _coerce_vector2(route_contract.get("branch_port", Vector2.INF))
	if not junction.is_finite() or not branch_port.is_finite() or junction.is_equal_approx(branch_port):
		return ""
	var arm_corridor := _segment_corridor_polygon(
		junction,
		branch_port,
		float(route_contract.get("half_width", 0.0))
	)
	if _polygon_intersection_area(arm_corridor, roster_envelope) > 0.01:
		return "authored_branch_arm_overlap:roster_building_envelope"
	return ""


static func _build_roster_building_footprint_envelope(
	selected_specs: Array[Dictionary],
	plot: Dictionary
) -> Array[Vector2]:
	var points := PackedVector2Array()
	for spec in _find_specs_by_plot_class(selected_specs, str(plot.get("plot_class", ""))):
		var placed := PlazaMapLayoutGenerator._place_building_spec(spec, plot, -1)
		for point in _vector2_array(placed.get("footprint_world_polygon", [])):
			points.append(point)
	if points.size() < 3:
		return []
	var hull: PackedVector2Array = Geometry2D.convex_hull(points)
	var result: Array[Vector2] = []
	for point in hull:
		result.append(point)
	return result


static func _build_roster_envelope_blocker(plot_id: String, envelope: Array[Vector2]) -> Dictionary:
	return {
		"id": "roster_building_envelope:%s" % plot_id,
		"owner_id": plot_id,
		"kind": "candidate_roster_building_envelope",
		"polygon_world": envelope.duplicate(),
	}


static func _find_spec_by_plot_class(selected_specs: Array[Dictionary], plot_class: String) -> Dictionary:
	for spec in selected_specs:
		if str(spec.get("plot_class", "")) == plot_class:
			return spec
	return {}


static func _find_specs_by_plot_class(selected_specs: Array[Dictionary], plot_class: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spec in selected_specs:
		if str(spec.get("plot_class", "")) == plot_class:
			result.append(spec)
	return result


static func _rect_inside_world(rect: Rect2, world_size: Vector2) -> bool:
	return rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= world_size.x and rect.end.y <= world_size.y


static func _polygon_intersects_road_corridors(polygon: Array[Vector2], road: Dictionary) -> bool:
	return _first_road_corridor_intersection(polygon, road) != ""


static func _first_road_corridor_intersection(polygon: Array[Vector2], road: Dictionary) -> String:
	for edge in _dictionary_array(road.get("edges", [])):
		var half_width := float(edge.get("half_width_world", 0.0))
		var polyline := _vector2_array(edge.get("polyline_world", []))
		for segment_index in range(polyline.size() - 1):
			if _polygon_intersection_area(polygon, _segment_corridor_polygon(polyline[segment_index], polyline[segment_index + 1], half_width)) > 0.01:
				return "%s[%d]" % [str(edge.get("id", "")), segment_index]
	return ""


static func _repair_integrated_decor_clearance(
	plots: Array[Dictionary],
	buildings: Array[Dictionary],
	road: Dictionary,
	decor_clusters: Array[Dictionary]
) -> Dictionary:
	var result: Array[Dictionary] = decor_clusters.duplicate(true)
	var placed: Array[Dictionary] = []
	var candidate_offsets: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(70.0, -55.0),
		Vector2(-70.0, -55.0),
		Vector2(0.0, -105.0),
		Vector2(105.0, -80.0),
		Vector2(-105.0, -80.0),
		Vector2(70.0, 20.0),
		Vector2(-70.0, 20.0),
		Vector2(0.0, 20.0),
	]
	for index in range(result.size()):
		var cluster: Dictionary = result[index].duplicate(true)
		var plot := _find_by_id(plots, str(cluster.get("plot_id", "")))
		if plot.is_empty():
			return {"valid": false, "rejection_reason": "decor_plot_missing:%s" % str(cluster.get("id", ""))}
		var original_anchor := _coerce_vector2(cluster.get("anchor_world", Vector2.INF))
		var plot_pivot := _coerce_vector2(plot.get("pivot_pos", Vector2.INF))
		var seed_jitter := original_anchor - plot_pivot
		var visual_value: Variant = cluster.get("visual_bounds_world", null)
		var visual_size := (visual_value as Rect2).size if visual_value is Rect2 else Vector2(160.0, 110.0)
		var found := false
		var candidate_anchors: Array[Vector2] = []
		for offset in candidate_offsets:
			candidate_anchors.append(plot_pivot + seed_jitter + offset)
		# The R2 six-offset helper was tuned to a different road graph. Search the
		# remaining authored parcel deterministically before rejecting it; this does
		# not consume the decor RNG stream or permit a footprint outside the parcel.
		var plot_bounds := _polygon_bounds(_vector2_array(plot.get("boundary_polygon_world", [])))
		var grid_y := plot_bounds.position.y + 60.0
		while grid_y <= plot_bounds.end.y - 24.0 + BASIS_EPSILON:
			var grid_x := plot_bounds.position.x + 78.0
			while grid_x <= plot_bounds.end.x - 78.0 + BASIS_EPSILON:
				var grid_anchor := Vector2(grid_x, grid_y)
				if not candidate_anchors.has(grid_anchor):
					candidate_anchors.append(grid_anchor)
				grid_x += 20.0
			grid_y += 20.0
		for anchor in candidate_anchors:
			var footprint := PlazaMapLayoutGenerator._decor_footprint(anchor)
			if not PlazaMapLayoutGenerator._decor_candidate_is_clear(
				footprint,
				_vector2_array(plot.get("boundary_polygon_world", [])),
				buildings,
				placed,
				road
			):
				continue
			cluster["anchor_world"] = anchor
			cluster["sort_anchor_world"] = anchor
			cluster["footprint_world_polygon"] = footprint
			cluster["visual_bounds_world"] = Rect2(anchor - Vector2(visual_size.x * 0.5, visual_size.y), visual_size)
			found = true
			break
		if not found:
			return {"valid": false, "rejection_reason": "decor_clearance_unresolved:%s" % str(cluster.get("id", ""))}
		result[index] = cluster
		placed.append(cluster)
	return {"valid": true, "decor_clusters": result}


static func _build_forecourt_reservation(
	pivot: Vector2,
	plot_class: String,
	selected_specs: Array[Dictionary]
) -> Array[Vector2]:
	for spec in selected_specs:
		if str(spec.get("plot_class", "")) != plot_class:
			continue
		var display_scale := maxf(0.0001, float(spec.get("display_scale", 1.0)))
		var entrance := pivot + _coerce_vector2(spec.get("entrance_anchor_offset", Vector2.ZERO)) * display_scale
		var normal := _coerce_vector2(spec.get("entrance_normal", Vector2(-1.0, 0.5))).normalized()
		var clearance_value: Variant = spec.get("road_side_clearance", {})
		var clearance: Dictionary = clearance_value as Dictionary if clearance_value is Dictionary else {}
		return PlazaMapLayoutGenerator._oriented_approach_polygon(
			entrance,
			normal,
			maxf(1.0, float(clearance.get("cross_width", 120.0))),
			maxf(ENTRANCE_FORECOURT_ARM_RUN_WORLD, float(clearance.get("approach_depth", ENTRANCE_FORECOURT_ARM_RUN_WORLD)))
		)
	return []


static func _append_integrated_plot_edges(
	road: Dictionary,
	plots: Array[Dictionary],
	buildings: Array[Dictionary],
	building_blockers: Array[Dictionary],
	world_size: Vector2,
	route_plans: Array[Dictionary]
) -> Dictionary:
	var nodes := _dictionary_array(road.get("nodes", []))
	var edges := _dictionary_array(road.get("edges", []))
	if route_plans.size() != plots.size():
		return {"valid": false, "rejection_reason": "integrated_plot_route_plan_count_mismatch:%d:%d" % [route_plans.size(), plots.size()]}
	for plot_index in range(plots.size()):
		var plot := plots[plot_index]
		var plot_id := str(plot.get("id", ""))
		var main_node_id := str(plot.get("road_branch_node_id", plot.get("main_node_id", "")))
		var main_node := _find_by_id(nodes, main_node_id)
		if main_node.is_empty():
			return {"valid": false, "rejection_reason": "plot_main_node_missing:%s" % plot_id}
		var building_index := PlazaMapLayoutGenerator._find_building_index_by_plot(buildings, plot_id)
		var building: Dictionary = buildings[building_index] if building_index >= 0 else {}
		var expected_contract := _build_plot_route_contract(plot, main_node, building)
		var route_plan: Dictionary = route_plans[plot_index]
		if not bool(expected_contract.get("valid", false)) or not _plot_route_contract_matches(route_plan, expected_contract):
			return {"valid": false, "rejection_reason": "integrated_plot_route_plan_contract_mismatch:%s" % plot_id}
		var node_id := str(expected_contract.get("node_id", ""))
		var edge_id := str(expected_contract.get("edge_id", ""))
		var edge_kind := str(expected_contract.get("edge_kind", ""))
		var destination := _coerce_vector2(expected_contract.get("destination", Vector2.INF))
		var half_width := float(expected_contract.get("half_width", 0.0))
		var trim_final := bool(expected_contract.get("trim_final", false))
		if not destination.is_finite() or half_width <= 0.0:
			return {"valid": false, "rejection_reason": "plot_branch_contract_invalid:%s" % plot_id}
		var routed := _vector2_array(route_plan.get("routed_polyline_world", []))
		if routed.size() < 2:
			return {"valid": false, "rejection_reason": "integrated_plot_route_plan_missing:%s" % plot_id}
		var final_rejection := _polyline_route_rejection_reason(routed, half_width, plots, building_blockers, plot_id, world_size, trim_final)
		if final_rejection != "":
			return {"valid": false, "rejection_reason": "integrated_plot_route_plan_stale:%s:%s" % [plot_id, final_rejection]}
		# A 60-world south arm is indivisible only at an authored three-way node.
		# Terminal turn courts start the branch at the node itself; manufacturing
		# the same arm there would create an uncovered screen-vertical stub.
		var polyline := _build_route_plan_polyline(route_plan)
		nodes.append({
			"id": node_id,
			"role": "plot_approach" if building_index >= 0 else "decor_trail_end",
			"plot_id": plot_id,
			"position": destination,
		})
		edges.append({
			"id": edge_id,
			"kind": edge_kind,
			"from": main_node_id,
			"to": node_id,
			"plot_id": plot_id,
			"half_width_world": half_width,
			"polyline_world": polyline,
		})
		if building_index >= 0:
			plots[plot_index]["approach_anchor_world"] = destination
			plots[plot_index]["approach_edge_id"] = edge_id
			buildings[building_index]["approach_edge_id"] = edge_id
		else:
			plots[plot_index]["trail_anchor_world"] = destination
			plots[plot_index]["trail_edge_id"] = edge_id
	road["nodes"] = nodes
	road["edges"] = edges
	return {"valid": true, "road_graph": road, "plots": plots, "buildings": buildings}


static func _split_polyline_at_central_plaza(polyline: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for segment_index in range(polyline.size() - 1):
		var start := polyline[segment_index]
		var finish := polyline[segment_index + 1]
		_append_point(result, start)
		var intersections: Array[Dictionary] = []
		var delta := finish - start
		var length_squared := delta.length_squared()
		if length_squared > BASIS_EPSILON * BASIS_EPSILON:
			for edge_index in range(CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD.size()):
				var hit: Variant = Geometry2D.segment_intersects_segment(
					start,
					finish,
					CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD[edge_index],
					CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD[(edge_index + 1) % CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD.size()]
				)
				if not (hit is Vector2):
					continue
				var amount := clampf(((hit as Vector2) - start).dot(delta) / length_squared, 0.0, 1.0)
				if amount <= BASIS_EPSILON or amount >= 1.0 - BASIS_EPSILON:
					continue
				intersections.append({"amount": amount, "point": hit as Vector2})
		intersections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("amount", 0.0)) < float(b.get("amount", 0.0)))
		for record in intersections:
			_append_point(result, _coerce_vector2(record.get("point", Vector2.INF)))
		_append_point(result, finish)
	return _compact_polyline(result)


static func _clamp_world_point(point: Vector2, world_size: Vector2, margin: float) -> Vector2:
	return Vector2(
		clampf(point.x, margin, maxf(margin, world_size.x - margin)),
		clampf(point.y, margin, maxf(margin, world_size.y - margin))
	)


static func validate_layout(layout: Dictionary) -> Dictionary:
	var violations: Array[Dictionary] = []
	if str(layout.get("generator_version", "")) != GENERATOR_VERSION:
		_add_violation(violations, "invalid_generator_version", str(layout.get("generator_version", "")))
	if str(layout.get("source_generator_version", "")) != PlazaMapLayoutGenerator.GENERATOR_VERSION:
		_add_violation(violations, "source_generator_version_mismatch", str(layout.get("source_generator_version", "")))
	var fingerprint_value: Variant = layout.get("fingerprint", null)
	if not (fingerprint_value is String) or (fingerprint_value as String).length() != 64:
		_add_violation(violations, "layout_fingerprint_invalid", str(fingerprint_value))
	elif (fingerprint_value as String) != build_fingerprint(layout):
		_add_violation(violations, "layout_fingerprint_mismatch", "stored fingerprint does not bind promoted geometry")
	if not bool(layout.get("candidate_only", false)) or bool(layout.get("production_connected", true)):
		_add_violation(violations, "candidate_boundary_mismatch", "R3-A0.6 must remain production-disconnected")
	if str(layout.get("building_label_fit_policy", "")) != BUILDING_LABEL_FIT_POLICY:
		_add_violation(violations, "building_label_fit_policy_mismatch", str(layout.get("building_label_fit_policy", "")))
	var source_fingerprint_value: Variant = layout.get("source_layout_fingerprint", null)
	if not (source_fingerprint_value is String) or (source_fingerprint_value as String).length() != 64:
		_add_violation(violations, "source_fingerprint_invalid", str(source_fingerprint_value))
	var semantic_value: Variant = layout.get("r2_semantic_invariants", null)
	var semantic: Dictionary = semantic_value as Dictionary if semantic_value is Dictionary else {}
	var selected_types: Array[String] = []
	var selected_value: Variant = layout.get("selected_building_types", null)
	if selected_value is Array:
		for selected_type_value in selected_value as Array:
			selected_types.append(str(selected_type_value))
	var buildings_for_semantics := _dictionary_array(layout.get("building_specs", []))
	var plots_for_semantics := _dictionary_array(layout.get("plots", []))
	var expected_phase_counts := {
		"skeleton_float": PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT * 2,
		"plots_float": PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT * 2,
		"assignment_int": selected_types.size(),
		"decor_int_or_float": (PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT - selected_types.size()) * 5,
	}
	if semantic.is_empty() or semantic.get("selected_building_types", []) != selected_types or semantic.get("assignment_order", []) != _building_type_order(buildings_for_semantics) or semantic.get("plot_class_order", []) != _plot_class_order(plots_for_semantics) or semantic.get("phase_rng_draw_counts", {}) != expected_phase_counts or str(semantic.get("coordinate_policy", "")) != "versioned_r3_authority_not_r2_byte_preservation":
		_add_violation(violations, "r2_semantic_invariant_mismatch", str(semantic))
	var exit_value: Variant = layout.get("exit_zone", null)
	if not semantic.is_empty() and source_fingerprint_value is String and exit_value is Rect2 and layout.get("stage_id", null) is int and layout.get("map_seed", null) is int and layout.get("world_size", null) is Vector2 and layout.get("spawn_anchor", null) is Vector2:
		var rebuilt_source := PlazaMapLayoutGenerator.generate(
			int(layout.get("stage_id", 0)),
			int(layout.get("map_seed", 0)),
			_coerce_vector2(layout.get("world_size", Vector2.ZERO)),
			buildings_for_semantics,
			_coerce_vector2(layout.get("spawn_anchor", Vector2.ZERO)),
			exit_value as Rect2
		)
		if str(rebuilt_source.get("fingerprint", "")) != str(source_fingerprint_value):
			_add_violation(violations, "source_fingerprint_rebuild_mismatch", str(rebuilt_source.get("fingerprint", "")))
		var expected_phase_tails := _build_expected_r2_phase_rng_tail_samples(
			int(layout.get("stage_id", 0)),
			int(layout.get("map_seed", 0)),
			_coerce_vector2(layout.get("world_size", Vector2.ZERO)),
			buildings_for_semantics,
			_coerce_vector2(layout.get("spawn_anchor", Vector2.ZERO)),
			exit_value as Rect2
		)
		if semantic.get("phase_rng_tail_samples", {}) != expected_phase_tails:
			_add_violation(violations, "r2_phase_rng_tail_mismatch", str(semantic.get("phase_rng_tail_samples", {})))
	var road_value: Variant = layout.get("road_graph", null)
	if not (road_value is Dictionary):
		_add_violation(violations, "road_graph_invalid", "missing dictionary")
		return {"valid": false, "violations": violations, "metrics": {}}
	var road := road_value as Dictionary
	var nodes := _dictionary_array(road.get("nodes", []))
	var edges := _dictionary_array(road.get("edges", []))
	var slope_counts := {"horizontal": 0, "vertical": 0, "positive": 0, "negative": 0}
	var arbitrary_segments := 0
	var authored_special_vertical_segments := 0
	for edge in edges:
		var edge_id := str(edge.get("id", ""))
		var edge_kind := str(edge.get("kind", ""))
		var from_node := _find_by_id(nodes, str(edge.get("from", "")))
		var to_node := _find_by_id(nodes, str(edge.get("to", "")))
		var polyline := _vector2_array(edge.get("polyline_world", []))
		if polyline.size() < 2 or from_node.is_empty() or to_node.is_empty():
			_add_violation(violations, "road_edge_polyline_invalid", edge_id)
			continue
		if not polyline[0].is_equal_approx(_coerce_vector2(from_node.get("position", Vector2.INF))) or not polyline[polyline.size() - 1].is_equal_approx(_coerce_vector2(to_node.get("position", Vector2.INF))):
			_add_violation(violations, "road_edge_endpoint_mismatch", edge_id)
		for segment_index in range(polyline.size() - 1):
			# The convex hub polygon, not a hidden road stamp, owns both rendering
			# and navigation for semantic main links wholly inside the plaza.
			if edge_kind == "main" and _segment_is_inside_or_on_central_hub(polyline[segment_index], polyline[segment_index + 1]):
				continue
			var basis := classify_segment(polyline[segment_index], polyline[segment_index + 1])
			if basis == "":
				arbitrary_segments += 1
				_add_violation(violations, "road_segment_outside_oblique_basis", "%s:%d" % [edge_id, segment_index])
			else:
				slope_counts[basis] = int(slope_counts.get(basis, 0)) + 1
				if basis == "vertical":
					if _vertical_segment_is_authored_special_arm(edge, segment_index, nodes):
						authored_special_vertical_segments += 1
					else:
						_add_violation(violations, "screen_vertical_road_segment_forbidden", "%s:%d" % [edge_id, segment_index])
	var spine_value: Variant = road.get("main_spine_world", null)
	var spine := _vector2_array(spine_value)
	var stored_spine_turn_count := int(road.get("main_spine_turn_count", -1))
	var rebuilt_spine_turn_count := _polyline_basis_turn_count(spine)
	if spine.size() < 2 or stored_spine_turn_count != rebuilt_spine_turn_count:
		_add_violation(violations, "main_spine_contract_mismatch", "%d:%d" % [stored_spine_turn_count, rebuilt_spine_turn_count])
	elif stored_spine_turn_count > MAX_MAIN_SPINE_TURN_COUNT:
		_add_violation(violations, "main_spine_turn_budget_exceeded", str(stored_spine_turn_count))
	var exclusion_zones := _dictionary_array(layout.get("road_art_exclusion_zones", []))
	if exclusion_zones.size() != 1 or str(exclusion_zones[0].get("id", "")) != CENTRAL_PLAZA_EXCLUSION_ID or _vector2_array(exclusion_zones[0].get("polygon_world", [])) != CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD:
		_add_violation(violations, "central_plaza_exclusion_contract_mismatch", str(exclusion_zones))
	var walkable_hubs := _dictionary_array(layout.get("walkable_hub_polygons", []))
	var expected_walkable_hubs := _build_walkable_hub_manifest()
	var hub_contract := layout.get("central_plaza_hub_contract", {}) as Dictionary
	var expected_hub_polygon_sha := _polygon_token(CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD).sha256_text()
	if walkable_hubs != expected_walkable_hubs:
		_add_violation(violations, "central_plaza_walkable_hub_manifest_mismatch", str(walkable_hubs))
	if (
		str(hub_contract.get("id", "")) != CENTRAL_PLAZA_HUB_CONTRACT_ID
		or str(hub_contract.get("source_manifest_path", "")) != CENTRAL_PLAZA_HUB_MANIFEST_PATH
		or str(hub_contract.get("polygon_sha256", "")) != expected_hub_polygon_sha
		or str(hub_contract.get("navigation_policy", "")) != "full_body_walkable_union_member"
		or str(hub_contract.get("road_render_policy", "")) != "no_straight_stamp_inside_hub"
	):
		_add_violation(violations, "central_plaza_walkable_hub_contract_mismatch", str(hub_contract))
	var plot_exclusion_overlap_count := 0
	var forecourt_exclusion_overlap_count := 0
	var missing_forecourt_reservation_count := 0
	var plot_outside_semantic_band_count := 0
	for plot in _dictionary_array(layout.get("plots", [])):
		var plot_id := str(plot.get("id", ""))
		var plot_class := str(plot.get("plot_class", ""))
		var pivot := _coerce_vector2(plot.get("pivot_pos", Vector2.INF))
		if not _plot_pivot_inside_semantic_band(plot_class, pivot):
			plot_outside_semantic_band_count += 1
			_add_violation(violations, "plot_outside_semantic_band", "%s:%s:%s" % [plot_id, plot_class, pivot])
		if _polygon_intersection_area(
			_vector2_array(plot.get("boundary_polygon_world", [])),
			CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD
		) > 0.01:
			plot_exclusion_overlap_count += 1
			_add_violation(violations, "plot_overlaps_central_plaza_exclusion", plot_id)
		if str(plot.get("occupied_by", "")) == "":
			continue
		var reservation := _vector2_array(plot.get("forecourt_reservation_polygon_world", []))
		if reservation.size() < 3 or float(plot.get("forecourt_reserved_run_world", 0.0)) + BASIS_EPSILON < ENTRANCE_FORECOURT_ARM_RUN_WORLD:
			missing_forecourt_reservation_count += 1
			_add_violation(violations, "entrance_forecourt_reservation_missing", plot_id)
		elif _polygon_intersection_area(reservation, CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD) > 0.01:
			forecourt_exclusion_overlap_count += 1
			_add_violation(violations, "entrance_forecourt_overlaps_central_plaza_exclusion", plot_id)
	var signature_metrics := _validate_canonical_node_signatures(nodes, edges, road, violations)
	_validate_promoted_topology(nodes, edges, road, violations)
	var usage_value: Variant = layout.get("road_piece_usage", null)
	var usage: Dictionary = usage_value as Dictionary if usage_value is Dictionary else {}
	var binding_value: Variant = layout.get("road_piece_bindings", null)
	var bindings := _dictionary_array(binding_value)
	var expected_bindings := _build_road_piece_bindings(layout)
	if bindings != expected_bindings:
		_add_violation(violations, "road_piece_binding_mismatch", "stored bindings must be derived from actual road geometry")
	var special_binding_inside_exclusion_count := 0
	for binding in expected_bindings:
		if str(binding.get("role", "")) == "basis_segment":
			continue
		var anchor := _coerce_vector2(binding.get("anchor_world", Vector2.INF))
		if anchor.is_finite() and _point_strictly_inside_polygon(anchor, CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD):
			special_binding_inside_exclusion_count += 1
			_add_violation(
				violations,
				"road_special_inside_central_plaza_exclusion",
				str(binding.get("id", ""))
			)
	var expected_usage := _build_road_piece_usage(layout)
	if usage != expected_usage:
		_add_violation(violations, "road_piece_usage_mismatch", "stored usage must be derived from actual road geometry")
	var direction_compatible_usage := _build_direction_compatible_usage(expected_bindings, violations)
	var turn_court_edge_kind_counts := {"main": 0, "secondary": 0, "trail": 0, "approach": 0, "other": 0}
	for binding in expected_bindings:
		if str(binding.get("asset_id", "")) != "turn_court":
			continue
		var turn_edge_kind := str(binding.get("edge_kind", ""))
		if ["main", "secondary"].has(turn_edge_kind):
			turn_court_edge_kind_counts[turn_edge_kind] = int(turn_court_edge_kind_counts.get(turn_edge_kind, 0)) + 1
		else:
			turn_court_edge_kind_counts[turn_edge_kind if turn_court_edge_kind_counts.has(turn_edge_kind) else "other"] = int(turn_court_edge_kind_counts.get(turn_edge_kind if turn_court_edge_kind_counts.has(turn_edge_kind) else "other", 0)) + 1
			_add_violation(violations, "turn_court_edge_kind_forbidden", "%s:%s" % [str(binding.get("id", "")), turn_edge_kind])
	for asset_id_value in ROAD_PIECE_IDS:
		var asset_id := str(asset_id_value)
		if int(usage.get(asset_id, 0)) <= 0:
			_add_violation(violations, "approved_road_piece_unused", asset_id)
		if int(direction_compatible_usage.get(asset_id, 0)) <= 0:
			_add_violation(violations, "approved_road_piece_direction_unused", asset_id)
	var expected_crossings := _build_internal_crossing_bindings(road)
	if _dictionary_array(layout.get("road_crossing_bindings", [])) != expected_crossings:
		_add_violation(violations, "road_crossing_binding_mismatch", "internal crossings must be explicitly derived from physical polylines")
	if not expected_crossings.is_empty():
		_add_violation(violations, "non_node_road_crossing_remaining", str(expected_crossings.size()))
	var turn_court_count := _binding_count_by_asset(expected_bindings, "turn_court")
	if turn_court_count > MAX_ROAD_TURN_COURT_COUNT:
		_add_violation(violations, "road_turn_court_budget_exceeded", "%d>%d" % [turn_court_count, MAX_ROAD_TURN_COURT_COUNT])
	var corridors := _dictionary_array(layout.get("walkable_corridor_polygons", []))
	var expected_corridors := _build_walkable_corridors(edges)
	for hub in expected_walkable_hubs:
		expected_corridors.append(hub.duplicate(true))
	if _manifest_geometry_token(corridors) != _manifest_geometry_token(expected_corridors):
		_add_violation(violations, "walkable_corridor_manifest_mismatch", "road basis geometry drift")
	# Reuse the mature R2 plot/building/decor/clearance/no-tunnel validators,
	# but never disguise R3 as the R2 generator or filter violations by name.
	# Only the exact R2 road graph shape is intentionally delegated here.
	var geometry_validation := PlazaMapLayoutGenerator.validate_candidate_geometry(layout, GENERATOR_VERSION)
	if not bool(geometry_validation.get("valid", false)):
		for source_violation in _dictionary_array(geometry_validation.get("violations", [])):
			_add_violation(
				violations,
				"r2_geometry_contract_failed",
				"%s:%s" % [str(source_violation.get("code", "")), str(source_violation.get("detail", ""))]
			)
	return {
		"valid": violations.is_empty(),
		"violations": violations,
		"metrics": {
			"edge_count": edges.size(),
			"segment_count": int(slope_counts.get("horizontal", 0)) + int(slope_counts.get("vertical", 0)) + int(slope_counts.get("positive", 0)) + int(slope_counts.get("negative", 0)) + arbitrary_segments,
			"arbitrary_segment_count": arbitrary_segments,
			"slope_counts": slope_counts,
			"road_piece_usage": usage.duplicate(true),
			"authored_special_vertical_segment_count": authored_special_vertical_segments,
			"screen_vertical_straight_binding_count": _binding_count_by_asset(expected_bindings, "straight_vertical"),
			"main_spine_turn_count": stored_spine_turn_count,
			"central_plaza_exclusion_zone_count": exclusion_zones.size(),
			"central_plaza_walkable_hub_count": walkable_hubs.size(),
			"plot_exclusion_overlap_count": plot_exclusion_overlap_count,
			"forecourt_exclusion_overlap_count": forecourt_exclusion_overlap_count,
			"missing_forecourt_reservation_count": missing_forecourt_reservation_count,
			"plot_outside_semantic_band_count": plot_outside_semantic_band_count,
			"special_binding_inside_exclusion_count": special_binding_inside_exclusion_count,
			"direction_compatible_usage": direction_compatible_usage.duplicate(true),
			"node_signature_counts": signature_metrics.get("signature_counts", {}).duplicate(true),
			"terminus_signature_count": int(signature_metrics.get("terminus_signature_count", 0)),
			"plot_spur_signature_count": int(signature_metrics.get("plot_spur_signature_count", 0)),
			"forecourt_signature_count": int(signature_metrics.get("forecourt_signature_count", 0)),
			"forecourt_arm_below_required_count": _count_short_role_arms(nodes, edges, "plot_approach", ENTRANCE_FORECOURT_ARM_RUN_WORLD),
			"three_way_signature_count": int(signature_metrics.get("three_way_signature_count", 0)),
			"effective_degree_four_count": int(signature_metrics.get("effective_degree_four_count", 0)),
			"minimum_art_arm_run_world": float(signature_metrics.get("minimum_art_arm_run_world", 0.0)),
			"minimum_art_arm_to_half_piece_ratio": float(signature_metrics.get("minimum_art_arm_to_half_piece_ratio", 0.0)),
			"internal_crossing_count": _dictionary_array(layout.get("road_crossing_bindings", [])).size(),
			"turn_court_count": turn_court_count,
			"shared_secondary_trunk_edge_count": edges.filter(func(edge: Dictionary) -> bool: return str(edge.get("kind", "")) == "secondary").size(),
			"upper_secondary_trunk_edge_count": edges.filter(func(edge: Dictionary) -> bool: return str(edge.get("kind", "")) == "secondary" and str(edge.get("trunk_side", "")) == "upper").size(),
			"lower_secondary_trunk_edge_count": edges.filter(func(edge: Dictionary) -> bool: return str(edge.get("kind", "")) == "secondary" and str(edge.get("trunk_side", "")) == "lower").size(),
			"southeast_secondary_trunk_edge_count": edges.filter(func(edge: Dictionary) -> bool: return str(edge.get("kind", "")) == "secondary" and str(edge.get("trunk_side", "")).begins_with("southeast")).size(),
			"turn_court_edge_kind_counts": turn_court_edge_kind_counts,
		},
	}


static func _build_expected_r2_phase_rng_tail_samples(
	stage_id: int,
	map_seed: int,
	world_size: Vector2,
	selected_specs: Array[Dictionary],
	spawn_anchor: Vector2,
	exit_zone: Rect2
) -> Dictionary:
	var skeleton_rng := PlazaMapLayoutGenerator._build_phase_rng(stage_id, map_seed, "skeleton")
	var plot_rng := PlazaMapLayoutGenerator._build_phase_rng(stage_id, map_seed, "plots")
	var assignment_rng := PlazaMapLayoutGenerator._build_phase_rng(stage_id, map_seed, "assignment")
	var decor_rng := PlazaMapLayoutGenerator._build_phase_rng(stage_id, map_seed, "decor")
	var assignments := PlazaMapLayoutGenerator._build_plot_assignments(assignment_rng, map_seed)
	var source_road := PlazaMapLayoutGenerator._build_main_road_graph(
		spawn_anchor,
		exit_zone.get_center(),
		world_size,
		skeleton_rng,
		map_seed
	)
	var source_plots := PlazaMapLayoutGenerator._build_plots(source_road, world_size, plot_rng, assignments)
	var source_buildings := PlazaMapLayoutGenerator._assign_buildings(selected_specs, source_plots, assignment_rng)
	PlazaMapLayoutGenerator._append_plot_approach_edges(source_road, source_plots, source_buildings, world_size)
	PlazaMapLayoutGenerator._fill_unused_plots(source_plots, source_buildings, source_road, decor_rng)
	return {
		"skeleton": skeleton_rng.randi(),
		"plots": plot_rng.randi(),
		"assignment": assignment_rng.randi(),
		"decor": decor_rng.randi(),
	}


static func build_fingerprint(layout: Dictionary) -> String:
	var parts: Array[String] = [
		"generator=%s" % str(layout.get("generator_version", "")),
		"source_generator=%s" % str(layout.get("source_generator_version", "")),
		"source_fingerprint=%s" % str(layout.get("source_layout_fingerprint", "")),
		"stage=%d" % int(layout.get("stage_id", 0)),
		"seed=%d" % int(layout.get("map_seed", 0)),
		"main_route_length=%.3f" % float(layout.get("main_route_length_world", -1.0)),
	]
	var road := layout.get("road_graph", {}) as Dictionary
	parts.append("spine_turns:%d" % int(road.get("main_spine_turn_count", -1)))
	for point in _vector2_array(road.get("main_spine_world", [])):
		parts.append("spine_point:%s" % _vector_token(point))
	parts.append("cap_policy:%s:%.3f" % [str(layout.get("basis_endpoint_render_policy", "")), float(layout.get("straight_cap_overlap_world", -1.0))])
	parts.append("label_fit_policy:%s" % str(layout.get("building_label_fit_policy", "")))
	parts.append("vertical_policy:%s" % str(layout.get("screen_vertical_road_render_policy", "")))
	for exclusion in _dictionary_array(layout.get("road_art_exclusion_zones", [])):
		parts.append("exclusion:%s:%s" % [str(exclusion.get("id", "")), _polygon_token(_vector2_array(exclusion.get("polygon_world", [])))])
	var hub_contract := layout.get("central_plaza_hub_contract", {}) as Dictionary
	parts.append("hub_contract:%s:%s:%s:%s:%s" % [
		str(hub_contract.get("id", "")),
		str(hub_contract.get("source_manifest_path", "")),
		str(hub_contract.get("polygon_sha256", "")),
		str(hub_contract.get("navigation_policy", "")),
		str(hub_contract.get("road_render_policy", "")),
	])
	for hub in _dictionary_array(layout.get("walkable_hub_polygons", [])):
		parts.append("hub:%s:%s:%s:%s:%d:%.3f:%s" % [
			str(hub.get("id", "")),
			str(hub.get("edge_id", "")),
			str(hub.get("edge_kind", "")),
			str(hub.get("cap_style", "")),
			int(hub.get("segment_index", -1)),
			float(hub.get("half_width_world", -1.0)),
			str(hub.get("source_contract_id", "")),
		])
		parts.append("hub_polygon:%s" % _polygon_token(_vector2_array(hub.get("polygon_world", []))))
	for node in _dictionary_array(road.get("nodes", [])):
		parts.append("node:%s:%s:%s:%s:%s:%.3f" % [
			str(node.get("id", "")),
			str(node.get("role", "")),
			str(node.get("plot_id", "")),
			str(node.get("trunk", "")),
			_vector_token(_coerce_vector2(node.get("position", Vector2.ZERO))),
			float(node.get("route_distance_world", -1.0)),
		])
	for edge in _dictionary_array(road.get("edges", [])):
		parts.append("edge:%s:%s:%s:%s:%s:%s:%.3f" % [str(edge.get("id", "")), str(edge.get("kind", "")), str(edge.get("from", "")), str(edge.get("to", "")), str(edge.get("plot_id", "")), str(edge.get("trunk_side", "")), float(edge.get("half_width_world", -1.0))])
		for point in _vector2_array(edge.get("polyline_world", [])):
			parts.append("point:%s" % _vector_token(point))
	var usage := layout.get("road_piece_usage", {}) as Dictionary
	for asset_id_value in ROAD_PIECE_IDS:
		var asset_id := str(asset_id_value)
		parts.append("piece:%s:%d" % [asset_id, int(usage.get(asset_id, 0))])
	for binding in _dictionary_array(layout.get("road_piece_bindings", [])):
		parts.append("binding:%s:%s:%s:%s:%d:%s:%s:%s:%s:%.3f" % [
			str(binding.get("id", "")),
			str(binding.get("asset_id", "")),
			str(binding.get("role", "")),
			str(binding.get("edge_id", binding.get("node_id", ""))),
			int(binding.get("segment_index", -1)),
			_vector_token(_coerce_vector2(binding.get("start_world", binding.get("anchor_world", Vector2.ZERO)))),
			_vector_token(_coerce_vector2(binding.get("finish_world", binding.get("anchor_world", Vector2.ZERO)))),
			str(binding.get("orientation_signature", str(binding.get("basis", "")))),
			str(binding.get("edge_kind", "")),
			float(binding.get("target_width_world", 0.0)),
		])
	for crossing in _dictionary_array(layout.get("road_crossing_bindings", [])):
		parts.append("crossing:%s:%s:%s:%s" % [
			str(crossing.get("id", "")),
			_vector_token(_coerce_vector2(crossing.get("anchor_world", Vector2.ZERO))),
			str(crossing.get("orientation_signature", "")),
			str(crossing.get("edge_ids", [])),
		])
	var semantic_value: Variant = layout.get("r2_semantic_invariants", {})
	var semantic: Dictionary = semantic_value as Dictionary if semantic_value is Dictionary else {}
	parts.append("r2_semantic:%s:%s:%s:%s:%s:%s" % [
		str(semantic.get("selected_building_types", [])),
		str(semantic.get("assignment_order", [])),
		str(semantic.get("plot_class_order", [])),
		str(semantic.get("phase_rng_draw_counts", {})),
		str(semantic.get("phase_rng_tail_samples", {})),
		str(semantic.get("coordinate_policy", "")),
	])
	parts.append("payload=%s" % PlazaMapLayoutGenerator.build_fingerprint(layout))
	return "\n".join(PackedStringArray(parts)).sha256_text()


static func classify_segment(start: Vector2, finish: Vector2) -> String:
	if not start.is_finite() or not finish.is_finite():
		return ""
	var delta := finish - start
	if delta.length_squared() <= BASIS_EPSILON * BASIS_EPSILON:
		return ""
	if absf(delta.x) <= BASIS_EPSILON:
		return "vertical"
	if absf(delta.y) <= BASIS_EPSILON:
		return "horizontal"
	var slope := delta.y / delta.x
	if absf(slope - BASIS_SLOPE_MAGNITUDE) <= BASIS_EPSILON:
		return "positive"
	if absf(slope + BASIS_SLOPE_MAGNITUDE) <= BASIS_EPSILON:
		return "negative"
	return ""


static func classify_directed_segment(start: Vector2, finish: Vector2) -> String:
	var basis := classify_segment(start, finish)
	var delta := finish - start
	match basis:
		"horizontal":
			return "east" if delta.x > 0.0 else "west"
		"vertical":
			return "south" if delta.y > 0.0 else "north"
		"positive":
			return "south_east" if delta.x > 0.0 else "north_west"
		"negative":
			return "north_east" if delta.x > 0.0 else "south_west"
	return ""


static func _align_main_nodes_to_plaza_spine(
	nodes: Array[Dictionary],
	main_ids: Array[String]
) -> Dictionary:
	var spawn := _find_by_id(nodes, "spawn")
	var exit := _find_by_id(nodes, "exit")
	var first_main := _find_by_id(nodes, "main_0")
	var last_main := _find_by_id(nodes, "main_%d" % (PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT - 1))
	if spawn.is_empty() or exit.is_empty() or first_main.is_empty() or last_main.is_empty():
		return {"valid": false, "rejection_reason": "main_spine_anchor_missing"}
	var spawn_position := _coerce_vector2(spawn.get("position", Vector2.INF))
	var exit_position := _coerce_vector2(exit.get("position", Vector2.INF))
	var first_x := _coerce_vector2(first_main.get("position", Vector2.INF)).x
	var last_x := _coerce_vector2(last_main.get("position", Vector2.INF)).x
	var first_intersections := _polygon_y_intersections_at_x(CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD, first_x)
	var last_intersections := _polygon_y_intersections_at_x(CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD, last_x)
	if first_intersections.size() < 2 or last_intersections.size() < 2:
		return {"valid": false, "rejection_reason": "central_plaza_spine_gate_missing"}
	# The entrance reaches the lower-left plaza rim; the exit leaves from the
	# upper-right rim. Both outside legs therefore read as ground-hugging NE runs.
	var left_gate := Vector2(first_x, first_intersections[first_intersections.size() - 1])
	var right_gate := Vector2(last_x, last_intersections[0])
	var spine: Array[Vector2] = []
	_append_polyline(spine, _build_basis_polyline(spawn_position, left_gate, "plaza_spine_entry"))
	_append_polyline(spine, _build_basis_polyline(left_gate, right_gate, "plaza_spine_surface"))
	_append_polyline(spine, _build_basis_polyline(right_gate, exit_position, "plaza_spine_exit"))
	spine = _compact_polyline(spine)
	if spine.size() < 2:
		return {"valid": false, "rejection_reason": "main_spine_polyline_invalid"}
	var turn_count := _polyline_basis_turn_count(spine)
	if turn_count > MAX_MAIN_SPINE_TURN_COUNT:
		return {"valid": false, "rejection_reason": "main_spine_turn_budget_exceeded:%d" % turn_count}
	# The spine is a road-art authority, never a plot authority. R2 main nodes are
	# consumed by plot/building/decor placement and must remain byte-identical.
	# Moving them to the authored plaza spine would invalidate every approved
	# placement and blocker even though the RNG payload itself did not change.
	for node_id in main_ids:
		if _find_by_id(nodes, node_id).is_empty():
			return {"valid": false, "rejection_reason": "main_spine_slot_missing:%s" % node_id}
	return {
		"valid": true,
		"nodes": nodes.duplicate(true),
		"main_spine_world": spine,
		"turn_count": turn_count,
	}


static func _polygon_y_intersections_at_x(polygon: Array[Vector2], x: float) -> Array[float]:
	var result: Array[float] = []
	for index in range(polygon.size()):
		var start := polygon[index]
		var finish := polygon[(index + 1) % polygon.size()]
		if x < minf(start.x, finish.x) - BASIS_EPSILON or x > maxf(start.x, finish.x) + BASIS_EPSILON:
			continue
		if absf(finish.x - start.x) <= BASIS_EPSILON:
			continue
		var amount := (x - start.x) / (finish.x - start.x)
		if amount < -BASIS_EPSILON or amount > 1.0 + BASIS_EPSILON:
			continue
		var y := lerpf(start.y, finish.y, clampf(amount, 0.0, 1.0))
		if result.is_empty() or not result.any(func(value: float) -> bool: return is_equal_approx(value, y)):
			result.append(y)
	result.sort()
	return result


static func _point_on_x_monotonic_polyline(polyline: Array[Vector2], x: float) -> Vector2:
	for index in range(polyline.size() - 1):
		var start := polyline[index]
		var finish := polyline[index + 1]
		if x < minf(start.x, finish.x) - BASIS_EPSILON or x > maxf(start.x, finish.x) + BASIS_EPSILON:
			continue
		if absf(finish.x - start.x) <= BASIS_EPSILON:
			continue
		var amount := (x - start.x) / (finish.x - start.x)
		return start.lerp(finish, clampf(amount, 0.0, 1.0))
	return Vector2.INF


static func _polyline_basis_turn_count(polyline: Array[Vector2]) -> int:
	var previous := ""
	var turns := 0
	for index in range(polyline.size() - 1):
		var direction := classify_directed_segment(polyline[index], polyline[index + 1])
		if direction == "":
			continue
		if previous != "" and direction != previous:
			turns += 1
		previous = direction
	return turns


static func _build_art_measured_road_graph(
	source_road: Dictionary,
	source_nodes: Array[Dictionary],
	source_edges: Array[Dictionary],
	plots: Array[Dictionary],
	blockers: Array[Dictionary],
	world_size: Vector2
) -> Dictionary:
	if not world_size.is_finite() or world_size.x <= 0.0 or world_size.y <= 0.0:
		return {"valid": false, "rejection_reason": "world_size_invalid"}
	var road: Dictionary = source_road.duplicate(true)
	var nodes: Array[Dictionary] = source_nodes.duplicate(true)
	var main_ids: Array[String] = ["spawn"]
	for index in range(PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT):
		main_ids.append("main_%d" % index)
	main_ids.append("exit")
	var spine_result := _align_main_nodes_to_plaza_spine(nodes, main_ids)
	if not bool(spine_result.get("valid", false)):
		return {"valid": false, "rejection_reason": str(spine_result.get("rejection_reason", "main_spine_build_failed"))}
	nodes = spine_result.get("nodes", nodes)
	var main_spine_world := _vector2_array(spine_result.get("main_spine_world", []))
	var main_spine_turn_count := int(spine_result.get("turn_count", -1))
	var anchor_slots_value: Variant = road.get("secondary_anchor_slots", null)
	if not (anchor_slots_value is Array) or (anchor_slots_value as Array).size() != 2:
		return {"valid": false, "rejection_reason": "secondary_anchor_slots_invalid"}
	var anchor_slots := anchor_slots_value as Array
	var attachment_specs: Array[Dictionary] = [
		{"id": "secondary_attach_left", "pair_start": "main_%d" % int(anchor_slots[0]), "side": "left"},
		{"id": "secondary_attach_right", "pair_finish": "main_%d" % int(anchor_slots[1]), "side": "right"},
	]
	for spec_index in range(attachment_specs.size()):
		var spec := attachment_specs[spec_index]
		var pair_start := str(spec.get("pair_start", ""))
		var pair_finish := str(spec.get("pair_finish", ""))
		if pair_start == "":
			var finish_index := main_ids.find(pair_finish)
			if finish_index <= 0:
				return {"valid": false, "rejection_reason": "secondary_attachment_pair_invalid"}
			pair_start = main_ids[finish_index - 1]
		else:
			var start_index := main_ids.find(pair_start)
			if start_index < 0 or start_index + 1 >= main_ids.size():
				return {"valid": false, "rejection_reason": "secondary_attachment_pair_invalid"}
			pair_finish = main_ids[start_index + 1]
		var start_node := _find_by_id(nodes, pair_start)
		var finish_node := _find_by_id(nodes, pair_finish)
		if start_node.is_empty() or finish_node.is_empty():
			return {"valid": false, "rejection_reason": "secondary_attachment_endpoint_missing"}
		var start_position := _coerce_vector2(start_node.get("position", Vector2.INF))
		var finish_position := _coerce_vector2(finish_node.get("position", Vector2.INF))
		if not start_position.is_finite() or not finish_position.is_finite():
			return {"valid": false, "rejection_reason": "secondary_attachment_endpoint_invalid"}
		var attachment_id := str(spec.get("id", ""))
		var attachment_position := start_position.lerp(finish_position, 0.5)
		nodes.append({
			"id": attachment_id,
			"role": "road_piece_junction",
			"position": attachment_position,
			"secondary_side": str(spec.get("side", "")),
		})
		attachment_specs[spec_index]["pair_start"] = pair_start
		attachment_specs[spec_index]["pair_finish"] = pair_finish

	var route_ids: Array[String] = []
	for pair_index in range(main_ids.size() - 1):
		var pair_start_id := main_ids[pair_index]
		var pair_finish_id := main_ids[pair_index + 1]
		if route_ids.is_empty():
			route_ids.append(pair_start_id)
		for attachment in attachment_specs:
			if str(attachment.get("pair_start", "")) == pair_start_id and str(attachment.get("pair_finish", "")) == pair_finish_id:
				route_ids.append(str(attachment.get("id", "")))
		route_ids.append(pair_finish_id)
	var main_half_width := 42.0
	for source_edge in source_edges:
		if str(source_edge.get("kind", "")) == "main":
			main_half_width = float(source_edge.get("half_width_world", main_half_width))
			break
	var edges: Array[Dictionary] = []
	for route_index in range(route_ids.size() - 1):
		var from_id := route_ids[route_index]
		var to_id := route_ids[route_index + 1]
		var start := _coerce_vector2(_find_by_id(nodes, from_id).get("position", Vector2.INF))
		var finish := _coerce_vector2(_find_by_id(nodes, to_id).get("position", Vector2.INF))
		var from_role := str(_find_by_id(nodes, from_id).get("role", ""))
		var to_role := str(_find_by_id(nodes, to_id).get("role", ""))
		var polyline := _build_main_art_polyline(start, finish, from_id == "spawn" or from_role == "road_piece_junction", to_role == "road_piece_junction", "r3_main_%s_to_%s" % [from_id, to_id])
		if polyline.size() < 2:
			return {"valid": false, "rejection_reason": "main_art_route_failed:%s:%s" % [from_id, to_id]}
		edges.append({
			"id": "r3_main_%s_to_%s" % [from_id, to_id],
			"kind": "main",
			"from": from_id,
			"to": to_id,
			"half_width_world": main_half_width,
			"polyline_world": polyline,
		})

	for source_edge_value in source_edges:
		var source_edge: Dictionary = source_edge_value.duplicate(true)
		if str(source_edge.get("kind", "")) == "main":
			continue
		var from_id := str(source_edge.get("from", ""))
		var to_id := str(source_edge.get("to", ""))
		if str(source_edge.get("id", "")).begins_with("secondary_from_main_"):
			from_id = "secondary_attach_left"
		elif str(source_edge.get("id", "")).begins_with("secondary_to_main_"):
			to_id = "secondary_attach_right"
		source_edge["from"] = from_id
		source_edge["to"] = to_id
		var rebuilt := _build_nonmain_art_polyline(source_edge, nodes, plots, blockers, world_size)
		if rebuilt.size() < 2:
			return {"valid": false, "rejection_reason": "nonmain_art_route_failed:%s" % str(source_edge.get("id", ""))}
		source_edge["polyline_world"] = rebuilt
		edges.append(source_edge)
	road["nodes"] = nodes
	road["edges"] = edges
	road["main_route_node_ids"] = route_ids
	road["secondary_attachment_node_ids"] = ["secondary_attach_left", "secondary_attach_right"]
	road["main_spine_world"] = main_spine_world
	road["main_spine_turn_count"] = main_spine_turn_count
	road["main_spine_destination"] = "central_plaza_and_exit"
	return {"valid": true, "road_graph": road}


static func _build_main_art_polyline(
	start: Vector2,
	finish: Vector2,
	start_has_art_port: bool,
	finish_has_art_port: bool,
	edge_id: String
) -> Array[Vector2]:
	if not start.is_finite() or not finish.is_finite() or start.is_equal_approx(finish):
		return []
	var north_east := Vector2(2.0, -1.0).normalized()
	var north_west := Vector2(-2.0, -1.0).normalized()
	var start_port := start + north_east * (TERMINUS_ARM_RUN_WORLD if start_has_art_port and start.x < 200.0 else THREE_WAY_ARM_RUN_WORLD) if start_has_art_port else start
	var finish_port := finish + north_west * THREE_WAY_ARM_RUN_WORLD if finish_has_art_port else finish
	var result: Array[Vector2] = [start]
	_append_point(result, start_port)
	_append_polyline(result, _build_basis_polyline(start_port, finish_port, "%s_middle" % edge_id))
	_append_point(result, finish)
	return _compact_polyline(result)


static func _build_nonmain_art_polyline(
	edge: Dictionary,
	nodes: Array[Dictionary],
	plots: Array[Dictionary],
	blockers: Array[Dictionary],
	world_size: Vector2
) -> Array[Vector2]:
	var source := _vector2_array(edge.get("polyline_world", []))
	if source.size() < 2:
		return []
	var from_id := str(edge.get("from", ""))
	var to_id := str(edge.get("to", ""))
	var start := _coerce_vector2(_find_by_id(nodes, from_id).get("position", Vector2.INF))
	var finish := _coerce_vector2(_find_by_id(nodes, to_id).get("position", Vector2.INF))
	if not start.is_finite() or not finish.is_finite():
		return []
	var kind := str(edge.get("kind", ""))
	if kind == "secondary" and str(edge.get("id", "")) == "secondary_hub_span":
		return _build_basis_polyline(start, finish, str(edge.get("id", "")))
	var start_role := str(_find_by_id(nodes, from_id).get("role", ""))
	var finish_role := str(_find_by_id(nodes, to_id).get("role", ""))
	var start_port := start
	if start_role == "road_piece_junction":
		start_port = start + Vector2.DOWN * THREE_WAY_ARM_RUN_WORLD
	var finish_port := finish
	if finish_role == "road_piece_junction":
		finish_port = finish + Vector2.DOWN * THREE_WAY_ARM_RUN_WORLD
	elif finish_role == "decor_trail_end":
		finish_port = finish + Vector2(-2.0, -1.0).normalized() * PLOT_SPUR_ARM_RUN_WORLD
	elif finish_role == "plot_approach":
		finish_port = finish + Vector2(-2.0, 1.0).normalized() * ENTRANCE_FORECOURT_ARM_RUN_WORLD
	var result: Array[Vector2] = [start]
	_append_point(result, start_port)
	if kind == "secondary":
		var preferred_lane_x := float(source[1].x) if start_role == "road_piece_junction" and source.size() > 2 else float(source[source.size() - 2].x) if finish_role == "road_piece_junction" and source.size() > 2 else float(finish.x if start_role == "road_piece_junction" else start.x)
		var secondary_route := _route_basis_around_other_plots(
			start_port,
			finish,
			preferred_lane_x,
			float(edge.get("half_width_world", 0.0)),
			plots,
			blockers,
			"",
			world_size,
			finish_port if finish_role == "road_piece_junction" else Vector2.INF
		)
		if secondary_route.is_empty():
			return []
		_append_polyline(result, secondary_route)
		return _compact_polyline(result)
	if kind == "approach":
		var approach_route := _route_basis_around_other_plots(
			start_port,
			finish,
			float(source[1].x) if source.size() > 2 else float(finish_port.x),
			float(edge.get("half_width_world", 0.0)),
			plots,
			blockers,
			str(edge.get("plot_id", "")),
			world_size,
			finish_port,
			true
		)
		if approach_route.is_empty():
			return []
		_append_polyline(result, approach_route)
		return _compact_polyline(result)
	if kind == "trail" and source.size() > 2:
		var trail_route := _route_basis_around_other_plots(
			start_port,
			finish,
			float(source[1].x),
			float(edge.get("half_width_world", 0.0)),
			plots,
			blockers,
			str(edge.get("plot_id", "")),
			world_size,
			finish_port,
			false
		)
		if trail_route.is_empty():
			return []
		_append_polyline(result, trail_route)
		_append_point(result, finish)
		return _compact_polyline(result)
	_append_polyline(result, _build_basis_polyline(start_port, finish_port, "%s_middle" % str(edge.get("id", ""))))
	_append_point(result, finish)
	return _compact_polyline(result)


static func _route_basis_around_other_plots(
	start: Vector2,
	destination: Vector2,
	preferred_lane_x: float,
	half_width: float,
	plots: Array[Dictionary],
	blockers: Array[Dictionary],
	owned_plot_id: String,
	world_size: Vector2,
	pre_destination: Vector2 = Vector2.INF,
	trim_final_segment: bool = false,
	diagnostics: Dictionary = {}
) -> Array[Vector2]:
	if not start.is_finite() or not destination.is_finite() or half_width <= 0.0:
		diagnostics["route_contract_invalid"] = int(diagnostics.get("route_contract_invalid", 0)) + 1
		return []
	var turn_target := pre_destination if pre_destination.is_finite() else destination
	var routed := _route_basis_grid(
		start,
		turn_target,
		preferred_lane_x,
		half_width,
		plots,
		blockers,
		owned_plot_id,
		world_size,
		diagnostics
	)
	if routed.is_empty():
		return []
	if pre_destination.is_finite():
		_append_point(routed, destination)
	routed = _compact_polyline(routed)
	var final_rejection := _polyline_route_rejection_reason(routed, half_width, plots, blockers, owned_plot_id, world_size, trim_final_segment)
	if final_rejection != "":
		diagnostics[final_rejection] = int(diagnostics.get(final_rejection, 0)) + 1
		return []
	return routed


static func _route_basis_grid(
	start: Vector2,
	finish: Vector2,
	preferred_lane_x: float,
	half_width: float,
	plots: Array[Dictionary],
	blockers: Array[Dictionary],
	owned_plot_id: String,
	world_size: Vector2,
	diagnostics: Dictionary
) -> Array[Vector2]:
	# Most authored sites admit a short H / +/-0.5 route. Prove those compact
	# candidates first; the bounded lattice search is only an obstacle fallback.
	# This keeps both generation time and the eventual retained draw count tied to
	# the visible road rather than to a search-grid ladder.
	var best_direct: Array[Vector2] = []
	var best_direct_length := INF
	for direct_value in _build_horizontal_oblique_variants(start, finish):
		var direct: Array[Vector2] = _vector2_array(direct_value)
		if _polyline_route_rejection_reason(direct, half_width, plots, blockers, owned_plot_id, world_size, false) == "":
			var direct_length := _polyline_length(direct)
			if direct_length < best_direct_length - BASIS_EPSILON:
				best_direct = direct
				best_direct_length = direct_length
	if not best_direct.is_empty():
		diagnostics["direct_basis_route"] = int(diagnostics.get("direct_basis_route", 0)) + 1
		return best_direct
	var raw_x := (finish.x - start.x) / R3_ROUTE_GRID_X_WORLD
	var raw_y := (finish.y - start.y) / R3_ROUTE_GRID_Y_WORLD
	var target := Vector2i(roundi(raw_x), roundi(raw_y))
	if absf(raw_x - float(target.x)) > BASIS_EPSILON or absf(raw_y - float(target.y)) > BASIS_EPSILON:
		diagnostics["route_lattice_mismatch"] = int(diagnostics.get("route_lattice_mismatch", 0)) + 1
		return []
	# The old FIFO treated a 480-world stride as the same cost as a 40-world
	# stride. It therefore preferred fewer search edges even when that meant a
	# 1,200-world visual detour away from a nearby plot. A* prices every edge by
	# its real world length; preferred_lane_x is only the deterministic tie-break.
	var open: Array[Dictionary] = []
	var start_score := start.distance_to(finish)
	_route_heap_push(open, {
		"node": Vector2i.ZERO,
		"score": start_score,
		"lane_distance": absf(start.x - preferred_lane_x),
		"travel_cost": 0.0,
	})
	var travel_costs := {Vector2i.ZERO: 0.0}
	var came_from := {Vector2i.ZERO: Vector2i(2147483647, 2147483647)}
	var closed := {}
	var rejection_counts := {}
	var expansions := 0
	while not open.is_empty() and expansions < R3_ROUTE_MAX_EXPANSIONS:
		var current_record := _route_heap_pop(open)
		var current: Vector2i = current_record.get("node", Vector2i(2147483647, 2147483647))
		if closed.has(current):
			continue
		var current_cost := float(travel_costs.get(current, INF))
		if float(current_record.get("travel_cost", INF)) > current_cost + BASIS_EPSILON:
			continue
		closed[current] = true
		expansions += 1
		if current == target:
			var reversed: Array[Vector2] = []
			var step := current
			while step != Vector2i(2147483647, 2147483647):
				reversed.append(start + Vector2(float(step.x) * R3_ROUTE_GRID_X_WORLD, float(step.y) * R3_ROUTE_GRID_Y_WORLD))
				step = came_from.get(step, Vector2i(2147483647, 2147483647)) as Vector2i
			reversed.reverse()
			return _compress_basis_path(reversed)
		# Prefer long legal basis runs. Unit-only expansion produced a 40-world
		# ladder when approximating vertical displacement: geometrically valid but
		# visually indistinguishable from the rejected scaffold composition.
		var neighbors: Array[Vector2i] = []
		for stride in [12, 8, 6, 4, 2, 1]:
			for delta in [
				Vector2i(stride, 0), Vector2i(-stride, 0),
				Vector2i(stride, stride), Vector2i(stride, -stride),
				Vector2i(-stride, stride), Vector2i(-stride, -stride),
			]:
				neighbors.append(current + delta)
		neighbors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.distance_squared_to(target) < b.distance_squared_to(target)
		)
		var current_world := start + Vector2(float(current.x) * R3_ROUTE_GRID_X_WORLD, float(current.y) * R3_ROUTE_GRID_Y_WORLD)
		for next in neighbors:
			if closed.has(next):
				continue
			var next_world := start + Vector2(float(next.x) * R3_ROUTE_GRID_X_WORLD, float(next.y) * R3_ROUTE_GRID_Y_WORLD)
			var candidate_cost := current_cost + current_world.distance_to(next_world)
			if candidate_cost >= float(travel_costs.get(next, INF)) - BASIS_EPSILON:
				continue
			var rejection := _polyline_route_rejection_reason(
				[current_world, next_world] as Array[Vector2],
				half_width,
				plots,
				blockers,
				owned_plot_id,
				world_size,
				false
			)
			if rejection != "":
				rejection_counts[rejection] = int(rejection_counts.get(rejection, 0)) + 1
				continue
			came_from[next] = current
			travel_costs[next] = candidate_cost
			_route_heap_push(open, {
				"node": next,
				"score": candidate_cost + next_world.distance_to(finish),
				"lane_distance": absf(next_world.x - preferred_lane_x),
				"travel_cost": candidate_cost,
			})
	for key in rejection_counts:
		diagnostics[key] = int(diagnostics.get(key, 0)) + int(rejection_counts.get(key, 0))
	diagnostics["route_grid_exhausted"] = int(diagnostics.get("route_grid_exhausted", 0)) + 1
	return []


static func _route_heap_push(heap: Array[Dictionary], record: Dictionary) -> void:
	heap.append(record)
	var child := heap.size() - 1
	while child > 0:
		var parent := floori(float(child - 1) / 2.0)
		if not _route_heap_record_precedes(heap[child], heap[parent]):
			break
		var swap: Dictionary = heap[parent]
		heap[parent] = heap[child]
		heap[child] = swap
		child = parent


static func _route_heap_pop(heap: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = heap[0]
	var tail: Dictionary = heap.pop_back()
	if heap.is_empty():
		return result
	heap[0] = tail
	var parent := 0
	while true:
		var left := parent * 2 + 1
		if left >= heap.size():
			break
		var right := left + 1
		var child := left
		if right < heap.size() and _route_heap_record_precedes(heap[right], heap[left]):
			child = right
		if not _route_heap_record_precedes(heap[child], heap[parent]):
			break
		var swap: Dictionary = heap[parent]
		heap[parent] = heap[child]
		heap[child] = swap
		parent = child
	return result


static func _route_heap_record_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_score := float(left.get("score", INF))
	var right_score := float(right.get("score", INF))
	if not is_equal_approx(left_score, right_score):
		return left_score < right_score
	var left_lane := float(left.get("lane_distance", INF))
	var right_lane := float(right.get("lane_distance", INF))
	if not is_equal_approx(left_lane, right_lane):
		return left_lane < right_lane
	var left_cost := float(left.get("travel_cost", INF))
	var right_cost := float(right.get("travel_cost", INF))
	if not is_equal_approx(left_cost, right_cost):
		return left_cost < right_cost
	var left_node: Vector2i = left.get("node", Vector2i(2147483647, 2147483647))
	var right_node: Vector2i = right.get("node", Vector2i(2147483647, 2147483647))
	return left_node.y < right_node.y if left_node.y != right_node.y else left_node.x < right_node.x


static func _compress_basis_path(points: Array[Vector2]) -> Array[Vector2]:
	if points.size() <= 2:
		return points
	var result: Array[Vector2] = [points[0]]
	var previous_direction := classify_directed_segment(points[0], points[1])
	for index in range(1, points.size() - 1):
		var next_direction := classify_directed_segment(points[index], points[index + 1])
		if next_direction != previous_direction:
			result.append(points[index])
		previous_direction = next_direction
	result.append(points[points.size() - 1])
	return _compact_polyline(result)


static func _build_horizontal_oblique_variants(start: Vector2, finish: Vector2) -> Array[Array]:
	var result: Array[Array] = []
	if start.is_equal_approx(finish):
		return result
	var delta_y := finish.y - start.y
	if absf(delta_y) <= BASIS_EPSILON:
		result.append([start, finish] as Array[Vector2])
		return result
	var shifts: Array[float] = [0.0]
	for step in range(1, 9):
		shifts.append(float(step) * -120.0)
		shifts.append(float(step) * 120.0)
	for slope in [BASIS_SLOPE_MAGNITUDE, -BASIS_SLOPE_MAGNITUDE]:
		var oblique_delta_x := delta_y / float(slope)
		var exact_start_x := finish.x - oblique_delta_x
		for shift in shifts:
			var oblique_start := Vector2(exact_start_x + shift, start.y)
			var oblique_finish := Vector2(oblique_start.x + oblique_delta_x, finish.y)
			_append_unique_polyline_candidate(result, _compact_polyline([start, oblique_start, oblique_finish, finish] as Array[Vector2]))
		# Keep the zero-leading-horizontal form early even when its derived shift is
		# not a 120-world multiple; it is the shortest legal D -> H alternative.
		var start_aligned_finish := Vector2(start.x + oblique_delta_x, finish.y)
		_append_unique_polyline_candidate(result, _compact_polyline([start, start_aligned_finish, finish] as Array[Vector2]))
	return result


static func _append_unique_polyline_candidate(result: Array[Array], candidate: Array[Vector2]) -> void:
	if candidate.size() < 2:
		return
	for existing_value in result:
		var existing: Array = existing_value as Array
		if existing == candidate:
			return
	result.append(candidate)


static func _polyline_route_rejection_reason(
	polyline: Array[Vector2],
	half_width: float,
	plots: Array[Dictionary],
	blockers: Array[Dictionary],
	owned_plot_id: String,
	world_size: Vector2,
	trim_final_segment: bool
) -> String:
	for segment_index in range(polyline.size() - 1):
		var start := polyline[segment_index]
		var finish := polyline[segment_index + 1]
		if _segment_enters_central_plaza_interior(start, finish):
			return "central_plaza_route_overlap"
		if trim_final_segment and segment_index == polyline.size() - 2:
			finish = finish.move_toward(start, half_width + 1.0)
		var corridor := _segment_corridor_polygon(start, finish, half_width)
		if corridor.is_empty():
			continue
		for point in corridor:
			if point.x < -BASIS_EPSILON or point.y < -BASIS_EPSILON or point.x > world_size.x + BASIS_EPSILON or point.y > world_size.y + BASIS_EPSILON:
				return "corridor_outside_world"
		for plot in plots:
			if str(plot.get("id", "")) == owned_plot_id:
				continue
			if _polygon_intersection_area(corridor, _vector2_array(plot.get("boundary_polygon_world", []))) > 0.01:
				return "plot_overlap:%s" % str(plot.get("id", ""))
		for blocker in blockers:
			if str(blocker.get("kind", "")) == "forbidden_road_centerline":
				var road_start := _coerce_vector2(blocker.get("start_world", Vector2.INF))
				var road_finish := _coerce_vector2(blocker.get("finish_world", Vector2.INF))
				if not road_start.is_finite() or not road_finish.is_finite():
					return "blocker_contract_invalid:%s" % str(blocker.get("id", ""))
				var intersection_value: Variant = Geometry2D.segment_intersects_segment(
					start,
					finish,
					road_start,
					road_finish
				)
				if intersection_value is Vector2:
					var intersection := intersection_value as Vector2
					if _point_strictly_inside_polygon(intersection, CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD):
						continue
					var allowed_anchor := _coerce_vector2(blocker.get("allowed_anchor_world", Vector2.INF))
					if allowed_anchor.is_finite() and intersection.distance_to(allowed_anchor) <= BASIS_EPSILON:
						continue
					return "blocker_overlap:%s" % str(blocker.get("id", ""))
				continue
			if _polygon_intersection_area(corridor, _vector2_array(blocker.get("polygon_world", []))) > 0.01:
				return "blocker_overlap:%s" % str(blocker.get("id", ""))
	return ""


static func _polygon_intersection_area(left: Array[Vector2], right: Array[Vector2]) -> float:
	if left.size() < 3 or right.size() < 3:
		return 0.0
	if not _polygon_bounds(left).intersects(_polygon_bounds(right), true):
		return 0.0
	var total := 0.0
	for polygon in Geometry2D.intersect_polygons(PackedVector2Array(left), PackedVector2Array(right)):
		total += absf(_packed_polygon_signed_area(polygon))
	return total


static func _polygon_bounds(polygon: Array[Vector2]) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var minimum := polygon[0]
	var maximum := polygon[0]
	for point in polygon:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


static func _packed_polygon_signed_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var twice_area := 0.0
	for index in range(polygon.size()):
		var current := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		twice_area += current.x * next.y - next.x * current.y
	return twice_area * 0.5


static func _validate_canonical_node_signatures(
	nodes: Array[Dictionary],
	edges: Array[Dictionary],
	road: Dictionary,
	violations: Array[Dictionary]
) -> Dictionary:
	var signature_counts := {}
	var terminus_count := 0
	var plot_spur_count := 0
	var forecourt_count := 0
	var three_way_count := 0
	var effective_degree_four_count := 0
	var minimum_art_arm_run_world := INF
	var minimum_art_arm_to_half_piece_ratio := INF
	for node in nodes:
		var node_id := str(node.get("id", ""))
		var arms := _outgoing_arm_records_at_node(node_id, edges)
		var directions: Array[String] = []
		for arm in arms:
			directions.append(str(arm.get("direction", "")))
		directions.sort()
		var signature := "+".join(PackedStringArray(directions))
		signature_counts[signature] = int(signature_counts.get(signature, 0)) + 1
		if arms.size() >= 4:
			effective_degree_four_count += 1
		var role := str(node.get("role", ""))
		if node_id == str(road.get("spawn_node_id", "")):
			terminus_count += 1
			_validate_art_arm_contract(node_id, arms, ["north_east"], TERMINUS_ARM_RUN_WORLD, "canonical_terminus_signature_mismatch", violations)
			var terminus_metrics := _measure_art_arm_extent(arms, "terminus")
			minimum_art_arm_run_world = minf(minimum_art_arm_run_world, float(terminus_metrics.get("minimum_run_world", INF)))
			minimum_art_arm_to_half_piece_ratio = minf(minimum_art_arm_to_half_piece_ratio, float(terminus_metrics.get("minimum_ratio", INF)))
		elif role == "decor_trail_end":
			plot_spur_count += 1
			_validate_art_arm_contract(node_id, arms, ["north_west"], PLOT_SPUR_ARM_RUN_WORLD, "canonical_plot_spur_signature_mismatch", violations)
			var spur_metrics := _measure_art_arm_extent(arms, "plot_spur")
			minimum_art_arm_run_world = minf(minimum_art_arm_run_world, float(spur_metrics.get("minimum_run_world", INF)))
			minimum_art_arm_to_half_piece_ratio = minf(minimum_art_arm_to_half_piece_ratio, float(spur_metrics.get("minimum_ratio", INF)))
		elif role == "plot_approach":
			forecourt_count += 1
			_validate_art_arm_contract(node_id, arms, ["south_west"], ENTRANCE_FORECOURT_ARM_RUN_WORLD, "canonical_forecourt_signature_mismatch", violations)
			var forecourt_metrics := _measure_art_arm_extent(arms, "entrance_forecourt")
			minimum_art_arm_run_world = minf(minimum_art_arm_run_world, float(forecourt_metrics.get("minimum_run_world", INF)))
			minimum_art_arm_to_half_piece_ratio = minf(minimum_art_arm_to_half_piece_ratio, float(forecourt_metrics.get("minimum_ratio", INF)))
		elif role == "road_piece_junction":
			three_way_count += 1
			_validate_art_arm_contract(node_id, arms, ["north_east", "north_west", "south"], THREE_WAY_ARM_RUN_WORLD, "canonical_three_way_signature_mismatch", violations)
			var three_way_metrics := _measure_art_arm_extent(arms, "three_way")
			minimum_art_arm_run_world = minf(minimum_art_arm_run_world, float(three_way_metrics.get("minimum_run_world", INF)))
			minimum_art_arm_to_half_piece_ratio = minf(minimum_art_arm_to_half_piece_ratio, float(three_way_metrics.get("minimum_ratio", INF)))
	if effective_degree_four_count > 0:
		_add_violation(violations, "effective_degree_four_junction_remaining", str(effective_degree_four_count))
	return {
		"signature_counts": signature_counts,
		"terminus_signature_count": terminus_count,
		"plot_spur_signature_count": plot_spur_count,
		"forecourt_signature_count": forecourt_count,
		"three_way_signature_count": three_way_count,
		"effective_degree_four_count": effective_degree_four_count,
		"minimum_art_arm_run_world": minimum_art_arm_run_world if is_finite(minimum_art_arm_run_world) else 0.0,
		"minimum_art_arm_to_half_piece_ratio": minimum_art_arm_to_half_piece_ratio if is_finite(minimum_art_arm_to_half_piece_ratio) else 0.0,
	}


static func _measure_art_arm_extent(arms: Array[Dictionary], asset_id: String) -> Dictionary:
	var directional_art_reach := float(SPECIAL_ROAD_TARGET_WIDTH_WORLD.get(asset_id, 0.0)) * 0.5
	if asset_id == "three_way":
		directional_art_reach = float(SPECIAL_ROAD_TARGET_WIDTH_WORLD.get(asset_id, 0.0)) * THREE_WAY_SOUTH_ARM_REACH_PER_TARGET_WIDTH
	var minimum_run := INF
	for arm in arms:
		minimum_run = minf(minimum_run, float(arm.get("run_world", 0.0)))
	return {
		"minimum_run_world": minimum_run if is_finite(minimum_run) else 0.0,
		"minimum_ratio": minimum_run / directional_art_reach if is_finite(minimum_run) and directional_art_reach > 0.0 else 0.0,
	}


static func _count_short_role_arms(
	nodes: Array[Dictionary],
	edges: Array[Dictionary],
	role: String,
	minimum_run_world: float
) -> int:
	var count := 0
	for node in nodes:
		if str(node.get("role", "")) != role:
			continue
		for arm in _outgoing_arm_records_at_node(str(node.get("id", "")), edges):
			if float(arm.get("run_world", 0.0)) + BASIS_EPSILON < minimum_run_world:
				count += 1
	return count


static func _validate_art_arm_contract(
	node_id: String,
	arms: Array[Dictionary],
	expected_directions: Array[String],
	minimum_run_world: float,
	violation_code: String,
	violations: Array[Dictionary]
) -> void:
	var actual_directions: Array[String] = []
	for arm in arms:
		actual_directions.append(str(arm.get("direction", "")))
	actual_directions.sort()
	var sorted_expected: Array[String] = expected_directions.duplicate()
	sorted_expected.sort()
	if actual_directions != sorted_expected:
		_add_violation(violations, violation_code, "%s:%s" % [node_id, "+".join(PackedStringArray(actual_directions))])
		return
	for arm in arms:
		if float(arm.get("run_world", 0.0)) + BASIS_EPSILON < minimum_run_world:
			_add_violation(
				violations,
				"road_piece_arm_run_too_short",
				"%s:%s:%.3f<%.3f" % [node_id, str(arm.get("direction", "")), float(arm.get("run_world", 0.0)), minimum_run_world]
			)


static func _outgoing_arm_records_at_node(node_id: String, edges: Array[Dictionary]) -> Array[Dictionary]:
	var arms: Array[Dictionary] = []
	for edge in edges:
		var polyline := _vector2_array(edge.get("polyline_world", []))
		if polyline.size() < 2:
			continue
		var oriented: Array[Vector2] = []
		if str(edge.get("from", "")) == node_id:
			oriented = polyline
		elif str(edge.get("to", "")) == node_id:
			for index in range(polyline.size() - 1, -1, -1):
				oriented.append(polyline[index])
		if oriented.size() < 2:
			continue
		var direction := classify_directed_segment(oriented[0], oriented[1])
		if direction == "":
			continue
		var run_world := 0.0
		for segment_index in range(oriented.size() - 1):
			if classify_directed_segment(oriented[segment_index], oriented[segment_index + 1]) != direction:
				break
			run_world += oriented[segment_index].distance_to(oriented[segment_index + 1])
		arms.append({
			"edge_id": str(edge.get("id", "")),
			"direction": direction,
			"run_world": run_world,
		})
	arms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var direction_a := str(a.get("direction", ""))
		var direction_b := str(b.get("direction", ""))
		if direction_a != direction_b:
			return direction_a < direction_b
		return str(a.get("edge_id", "")) < str(b.get("edge_id", ""))
	)
	return arms


static func _validate_promoted_topology(
	nodes: Array[Dictionary],
	edges: Array[Dictionary],
	road: Dictionary,
	violations: Array[Dictionary]
) -> void:
	var route_ids: Array[String] = []
	for node_id_value in road.get("main_route_node_ids", []) as Array:
		route_ids.append(str(node_id_value))
	var expected_route_ids: Array[String] = ["spawn"]
	for index in range(PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT):
		expected_route_ids.append("main_%d" % index)
	expected_route_ids.append("exit")
	if route_ids != expected_route_ids:
		_add_violation(violations, "r3_main_route_topology_mismatch", "node_count=%d" % route_ids.size())
	if str(road.get("spawn_node_id", "")) != "spawn" or str(road.get("exit_node_id", "")) != "exit":
		_add_violation(violations, "r3_main_route_topology_mismatch", "endpoint_ids")
	var expected_nodes := {
		"spawn": {"role": "spawn", "plot_id": "", "trunk": ""},
		"exit": {"role": "exit", "plot_id": "", "trunk": ""},
	}
	for index in range(PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT):
		var main_id := "main_%d" % index
		expected_nodes[main_id] = {"role": "central_plaza_route_node", "plot_id": "", "trunk": "", "position": R3_MAIN_SITE_BY_SLOT[index]}
	for spec_value in R3_SECONDARY_NODE_SPECS:
		var spec := spec_value as Dictionary
		expected_nodes[str(spec.get("id", ""))] = {"role": str(spec.get("role", "")), "plot_id": "", "trunk": str(spec.get("trunk", "")), "position": _coerce_vector2(spec.get("position", Vector2.INF))}
	for edge in edges:
		var edge_kind := str(edge.get("kind", ""))
		if not ["approach", "trail"].has(edge_kind):
			continue
		var edge_id := str(edge.get("id", ""))
		var plot_id := str(edge.get("plot_id", ""))
		var role := "plot_approach" if edge_kind == "approach" else "decor_trail_end"
		expected_nodes[edge_id] = {"role": role, "plot_id": plot_id, "trunk": ""}
	var main_edge_count := 0
	var secondary_edge_count := 0
	var branch_edge_count := 0
	for edge in edges:
		match str(edge.get("kind", "")):
			"main": main_edge_count += 1
			"secondary": secondary_edge_count += 1
			"approach", "trail": branch_edge_count += 1
	for index in range(maxi(0, route_ids.size() - 1)):
		if _find_directed_edge(edges, route_ids[index], route_ids[index + 1], "main").is_empty():
			_add_violation(violations, "r3_main_route_topology_mismatch", "%s->%s" % [route_ids[index], route_ids[index + 1]])
	if main_edge_count != maxi(0, route_ids.size() - 1):
		_add_violation(violations, "r3_main_route_topology_mismatch", "edge_count=%d" % main_edge_count)
	if branch_edge_count != PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT:
		_add_violation(violations, "r3_branch_topology_mismatch", "edge_count=%d" % branch_edge_count)
	var expected_secondary_edges := {}
	for spec_value in R3_SECONDARY_EDGE_SPECS:
		var spec := spec_value as Dictionary
		expected_secondary_edges[str(spec.get("id", ""))] = [str(spec.get("from", "")), str(spec.get("to", "")), str(spec.get("trunk", ""))]
	if secondary_edge_count != expected_secondary_edges.size():
		_add_violation(violations, "r3_secondary_topology_mismatch", "edge_count=%d" % secondary_edge_count)
	for edge_id_value in expected_secondary_edges.keys():
		var edge_id := str(edge_id_value)
		var expected_pair := expected_secondary_edges.get(edge_id, []) as Array
		var edge := _find_by_id(edges, edge_id)
		if edge.is_empty() or str(edge.get("kind", "")) != "secondary" or str(edge.get("from", "")) != str(expected_pair[0]) or str(edge.get("to", "")) != str(expected_pair[1]) or str(edge.get("trunk_side", "")) != str(expected_pair[2]):
			_add_violation(violations, "r3_secondary_topology_mismatch", edge_id)
	if nodes.size() != expected_nodes.size() or edges.size() != expected_route_ids.size() - 1 + expected_secondary_edges.size() + PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT:
		_add_violation(violations, "r3_road_topology_size_mismatch", "nodes=%d edges=%d" % [nodes.size(), edges.size()])
	var seen_nodes := {}
	for node in nodes:
		var node_id := str(node.get("id", ""))
		var expected_value: Variant = expected_nodes.get(node_id, null)
		var expected: Dictionary = expected_value as Dictionary if expected_value is Dictionary else {}
		var expected_position_value: Variant = expected.get("position", null)
		var position_mismatch := expected_position_value is Vector2 and not _coerce_vector2(node.get("position", Vector2.INF)).is_equal_approx(expected_position_value as Vector2)
		if expected.is_empty() or seen_nodes.has(node_id) or str(node.get("role", "")) != str(expected.get("role", "")) or str(node.get("plot_id", "")) != str(expected.get("plot_id", "")) or str(node.get("trunk", "")) != str(expected.get("trunk", "")) or position_mismatch:
			_add_violation(violations, "r3_road_topology_node_mismatch", node_id)
		seen_nodes[node_id] = true
	var adjacency := {}
	for node in nodes:
		adjacency[str(node.get("id", ""))] = []
	for edge in edges:
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		if not adjacency.has(from_id) or not adjacency.has(to_id):
			_add_violation(violations, "r3_road_endpoint_missing", str(edge.get("id", "")))
			continue
		(adjacency[from_id] as Array).append(to_id)
		(adjacency[to_id] as Array).append(from_id)
	var pending: Array[String] = [str(road.get("spawn_node_id", ""))]
	var visited := {}
	while not pending.is_empty():
		var node_id: String = pending.pop_back()
		if visited.has(node_id):
			continue
		visited[node_id] = true
		for neighbor_value in adjacency.get(node_id, []) as Array:
			var neighbor := str(neighbor_value)
			if not visited.has(neighbor):
				pending.append(neighbor)
	if visited.size() != nodes.size():
		_add_violation(violations, "r3_road_graph_disconnected", "%d/%d" % [visited.size(), nodes.size()])


static func _append_polyline(target: Array[Vector2], source: Array[Vector2]) -> void:
	for point in source:
		_append_point(target, point)


static func _append_point(target: Array[Vector2], point: Vector2) -> void:
	if target.is_empty() or not target[target.size() - 1].is_equal_approx(point):
		target.append(point)


static func _build_basis_polyline(
	start: Vector2,
	finish: Vector2,
	edge_id: String,
	reverse_basis_order: bool = false
) -> Array[Vector2]:
	if start.is_equal_approx(finish):
		return []
	var delta := finish - start
	if absf(delta.y) <= BASIS_EPSILON:
		return _compact_polyline([start, finish])
	# Exact oblique-coordinate decomposition. Two +/-0.5 basis legs span every
	# finite displacement without the old 2*abs(dy) one-sided excursion. The two
	# legal orders are both exposed to the collision-aware caller; direct callers
	# receive a deterministic order from the edge id.
	var positive_run_x := delta.x * 0.5 + delta.y
	var negative_run_x := delta.x * 0.5 - delta.y
	var positive_delta := Vector2(positive_run_x, positive_run_x * BASIS_SLOPE_MAGNITUDE)
	var negative_delta := Vector2(negative_run_x, -negative_run_x * BASIS_SLOPE_MAGNITUDE)
	var negative_first := reverse_basis_order
	if not reverse_basis_order:
		negative_first = posmod(edge_id.hash(), 2) != 0
	var middle := start + (negative_delta if negative_first else positive_delta)
	return _compact_polyline([start, middle, finish])


static func _rebuild_main_route_distances(road: Dictionary) -> Dictionary:
	var nodes := _dictionary_array(road.get("nodes", []))
	var edges := _dictionary_array(road.get("edges", []))
	var ordered_ids: Array[String] = []
	var ordered_value: Variant = road.get("main_route_node_ids", null)
	if ordered_value is Array:
		for node_id_value in ordered_value as Array:
			if node_id_value is String:
				ordered_ids.append(node_id_value as String)
	if ordered_ids.size() < PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT + 2:
		return {"valid": false, "rejection_reason": "main_route_node_ids_invalid"}
	var distance_by_node := {"spawn": 0.0}
	var cumulative := 0.0
	for index in range(ordered_ids.size() - 1):
		var from_id := ordered_ids[index]
		var to_id := ordered_ids[index + 1]
		var edge := _find_directed_edge(edges, from_id, to_id, "main")
		if edge.is_empty():
			return {"valid": false, "rejection_reason": "main_edge_missing:%s:%s" % [from_id, to_id]}
		var polyline := _vector2_array(edge.get("polyline_world", []))
		cumulative += _polyline_length(polyline)
		distance_by_node[to_id] = cumulative
	for node_index in range(nodes.size()):
		var node: Dictionary = nodes[node_index].duplicate(true)
		var node_id := str(node.get("id", ""))
		if distance_by_node.has(node_id):
			node["route_distance_world"] = float(distance_by_node.get(node_id, 0.0))
		nodes[node_index] = node
	return {"valid": true, "nodes": nodes, "route_length_world": cumulative, "distance_by_node": distance_by_node}


static func _apply_route_distances(layout: Dictionary, distance_by_node: Dictionary) -> void:
	var plots := _dictionary_array(layout.get("plots", []))
	var distance_by_plot := {}
	for plot_index in range(plots.size()):
		var plot: Dictionary = plots[plot_index].duplicate(true)
		var distance := float(distance_by_node.get(str(plot.get("main_node_id", "")), -1.0))
		plot["main_route_distance_world"] = distance
		distance_by_plot[str(plot.get("id", ""))] = distance
		plots[plot_index] = plot
	layout["plots"] = plots
	for key in ["building_specs", "decor_clusters"]:
		var records := _dictionary_array(layout.get(key, []))
		for record_index in range(records.size()):
			var record: Dictionary = records[record_index].duplicate(true)
			record["main_route_distance_world"] = float(distance_by_plot.get(str(record.get("plot_id", "")), -1.0))
			records[record_index] = record
		layout[key] = records


static func _build_road_piece_usage(layout: Dictionary) -> Dictionary:
	var usage := {
		"straight_horizontal": 0,
		"straight_positive": 0,
		"straight_negative": 0,
		"three_way": 0,
		"plot_spur": 0,
		"terminus": 0,
		"entrance_forecourt": 0,
		"turn_court": 0,
	}
	for binding in _build_road_piece_bindings(layout):
		var asset_id := str(binding.get("asset_id", ""))
		if usage.has(asset_id):
			usage[asset_id] = int(usage.get(asset_id, 0)) + 1
	return usage


static func _build_direction_compatible_usage(
	bindings: Array[Dictionary],
	violations: Array[Dictionary]
) -> Dictionary:
	var usage := {
		"straight_horizontal": 0,
		"straight_positive": 0,
		"straight_negative": 0,
		"three_way": 0,
		"plot_spur": 0,
		"terminus": 0,
		"entrance_forecourt": 0,
		"turn_court": 0,
	}
	for binding in bindings:
		var asset_id := str(binding.get("asset_id", ""))
		var compatible := false
		if asset_id.begins_with("straight_"):
			compatible = str(binding.get("basis", "")) == asset_id.trim_prefix("straight_")
		elif SPECIAL_ROAD_ORIENTATION_SIGNATURES.has(asset_id):
			compatible = str(binding.get("orientation_signature", "")) == str(SPECIAL_ROAD_ORIENTATION_SIGNATURES[asset_id])
		elif asset_id == "turn_court":
			compatible = str(binding.get("orientation_signature", "")) == "rotation_symmetric_degree_two"
		if not compatible:
			_add_violation(
				violations,
				"road_piece_orientation_incompatible",
				"%s:%s:%s" % [str(binding.get("id", "")), asset_id, str(binding.get("orientation_signature", binding.get("basis", "")))]
			)
			continue
		if usage.has(asset_id):
			usage[asset_id] = int(usage.get(asset_id, 0)) + 1
	return usage


static func _build_road_piece_bindings(layout: Dictionary) -> Array[Dictionary]:
	var bindings: Array[Dictionary] = []
	var turn_anchor_tokens := {}
	var road := layout.get("road_graph", {}) as Dictionary
	var nodes := _dictionary_array(road.get("nodes", []))
	var edges := _dictionary_array(road.get("edges", []))
	for edge in edges:
		var edge_id := str(edge.get("id", ""))
		var edge_kind := str(edge.get("kind", ""))
		var polyline := _vector2_array(edge.get("polyline_world", []))
		for segment_index in range(polyline.size() - 1):
			var basis := classify_segment(polyline[segment_index], polyline[segment_index + 1])
			var straight_asset_id := ""
			if basis == "horizontal":
				straight_asset_id = "straight_horizontal"
			elif basis == "positive":
				straight_asset_id = "straight_positive"
			elif basis == "negative":
				straight_asset_id = "straight_negative"
			if straight_asset_id == "":
				continue
			var fragments := _segment_exterior_fragments(
				polyline[segment_index],
				polyline[segment_index + 1]
			)
			for fragment_index in range(fragments.size()):
				var fragment := fragments[fragment_index]
				var fragment_start := _coerce_vector2(fragment.get("start_world", Vector2.INF))
				var fragment_finish := _coerce_vector2(fragment.get("finish_world", Vector2.INF))
				var binding_id := "%s_segment_%d_%s" % [edge_id, segment_index, straight_asset_id]
				if fragments.size() != 1 or not fragment_start.is_equal_approx(polyline[segment_index]) or not fragment_finish.is_equal_approx(polyline[segment_index + 1]):
					binding_id = "%s_fragment_%d" % [binding_id, fragment_index]
				bindings.append({
					"id": binding_id,
					"asset_id": straight_asset_id,
					"role": "basis_segment",
					"edge_id": edge_id,
					"segment_index": segment_index,
					"basis": basis,
					"start_world": fragment_start,
					"finish_world": fragment_finish,
				})
				if edge_kind == "secondary":
					for fragment_endpoint in [fragment_start, fragment_finish]:
						if _point_on_central_plaza_boundary(fragment_endpoint):
							_append_turn_court_binding(
								bindings,
								turn_anchor_tokens,
								fragment_endpoint,
								edge_id,
								segment_index,
								edge_kind
							)
		for point_index in range(1, polyline.size() - 1):
			var previous_basis := classify_segment(polyline[point_index - 1], polyline[point_index])
			var next_basis := classify_segment(polyline[point_index], polyline[point_index + 1])
			if previous_basis == "" or next_basis == "" or previous_basis == next_basis:
				continue
			var turn_anchor := polyline[point_index]
			if PlazaMapLayoutGenerator._point_in_or_on_polygon(turn_anchor, CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD):
				continue
			if _turn_is_covered_by_authored_special_arm(turn_anchor, nodes):
				continue
			# The bright paved court belongs only to main/secondary streets. Dirt
			# trails overlap softly, while approach bends must be removed by layout
			# structure rather than silently promoted to a plaza-grade surface.
			if not ["main", "secondary"].has(edge_kind):
				continue
			_append_turn_court_binding(bindings, turn_anchor_tokens, turn_anchor, edge_id, point_index, edge_kind)
		if edge_kind == "approach" and not polyline.is_empty():
			var approach_node_id := str(edge.get("to", ""))
			var approach_outward := _single_node_arm_direction(approach_node_id, edges)
			bindings.append({
				"id": "%s_forecourt" % edge_id,
				"asset_id": "entrance_forecourt",
				"role": "building_forecourt",
				"edge_id": edge_id,
				"node_id": approach_node_id,
				"segment_index": maxi(0, polyline.size() - 2),
				"anchor_world": polyline[polyline.size() - 1],
				"orientation_signature": "approach_enters_%s" % _opposite_direction(approach_outward),
			})
		elif edge_kind == "trail" and not polyline.is_empty():
			var trail_node_id := str(edge.get("to", ""))
			var trail_outward := _single_node_arm_direction(trail_node_id, edges)
			bindings.append({
				"id": "%s_spur" % edge_id,
				"asset_id": "plot_spur",
				"role": "decor_plot_spur",
				"edge_id": edge_id,
				"node_id": trail_node_id,
				"segment_index": maxi(0, polyline.size() - 2),
				"anchor_world": polyline[polyline.size() - 1],
				"orientation_signature": "trail_enters_%s" % _opposite_direction(trail_outward),
			})
	for node in nodes:
		var node_id := str(node.get("id", ""))
		if str(node.get("role", "")) == "road_piece_junction":
			bindings.append({
				"id": "%s_three_way" % node_id,
				"asset_id": "three_way",
				"role": "branch_junction",
				"node_id": node_id,
				"anchor_world": _coerce_vector2(node.get("position", Vector2.ZERO)),
				"orientation_signature": _node_orientation_signature(node_id, edges),
			})
		elif str(node.get("role", "")) == "road_turn_node":
			_append_turn_court_binding(
				bindings,
				turn_anchor_tokens,
				_coerce_vector2(node.get("position", Vector2.ZERO)),
				"",
				-1,
				str(node.get("turn_court_edge_kind", "junction"))
			)
	for terminus_id in [str(road.get("spawn_node_id", ""))]:
		var terminus_node := _find_by_id(nodes, terminus_id)
		if not terminus_node.is_empty():
			bindings.append({
				"id": "%s_terminus" % terminus_id,
				"asset_id": "terminus",
				"role": "route_terminus",
				"node_id": terminus_id,
				"anchor_world": _coerce_vector2(terminus_node.get("position", Vector2.ZERO)),
				"orientation_signature": "terminus_opens_%s" % _single_node_arm_direction(terminus_id, edges),
			})
	for gate_node_id in ["main_0", "main_%d" % (PlazaMapLayoutGenerator.REQUIRED_PLOT_COUNT - 1)]:
		var gate_node := _find_by_id(nodes, gate_node_id)
		if gate_node.is_empty():
			continue
		bindings.append({
			"id": "%s_central_plaza_forecourt" % gate_node_id,
			"asset_id": "entrance_forecourt",
			"role": "central_plaza_forecourt",
			"node_id": gate_node_id,
			"anchor_world": _coerce_vector2(gate_node.get("position", Vector2.ZERO)),
			"orientation_signature": SPECIAL_ROAD_ORIENTATION_SIGNATURES["entrance_forecourt"],
		})
	return bindings


static func _turn_is_covered_by_authored_special_arm(point: Vector2, nodes: Array[Dictionary]) -> bool:
	for node in nodes:
		if str(node.get("role", "")) != "road_piece_junction":
			continue
		var anchor := _coerce_vector2(node.get("position", Vector2.INF))
		if not anchor.is_finite():
			continue
		if point.distance_to(anchor) <= THREE_WAY_ARM_RUN_WORLD + STRAIGHT_CAP_OVERLAP_WORLD + BASIS_EPSILON:
			return true
	return false


static func _append_turn_court_binding(
	bindings: Array[Dictionary],
	seen_tokens: Dictionary,
	anchor: Vector2,
	edge_id: String,
	point_index: int,
	edge_kind: String
) -> void:
	if not anchor.is_finite():
		return
	if not ["main", "secondary"].has(edge_kind):
		return
	var token := _vector_token(anchor)
	if seen_tokens.has(token):
		return
	seen_tokens[token] = true
	var target_width_world := 168.0
	if edge_kind == "secondary" or edge_kind == "junction":
		target_width_world = 132.0
	bindings.append({
		"id": "turn_court_%s" % token.replace(",", "_").replace("-", "m").replace(".", "p"),
		"asset_id": "turn_court",
		"role": "degree_two_turn_court",
		"edge_id": edge_id,
		"edge_kind": edge_kind,
		"segment_index": point_index,
		"anchor_world": anchor,
		"orientation_signature": "rotation_symmetric_degree_two",
		"target_width_world": target_width_world,
	})


static func _segment_enters_central_plaza_interior(start: Vector2, finish: Vector2) -> bool:
	if start.is_equal_approx(finish):
		return false
	var cuts: Array[float] = [0.0, 1.0]
	var delta := finish - start
	var length_squared := delta.length_squared()
	for index in range(CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD.size()):
		var intersection: Variant = Geometry2D.segment_intersects_segment(
			start,
			finish,
			CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD[index],
			CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD[(index + 1) % CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD.size()]
		)
		if not (intersection is Vector2):
			continue
		var amount := clampf(((intersection as Vector2) - start).dot(delta) / length_squared, 0.0, 1.0)
		var duplicate := false
		for existing in cuts:
			if is_equal_approx(existing, amount):
				duplicate = true
				break
		if not duplicate:
			cuts.append(amount)
	cuts.sort()
	for index in range(cuts.size() - 1):
		if cuts[index + 1] - cuts[index] <= 0.000001:
			continue
		var midpoint := start.lerp(finish, (cuts[index] + cuts[index + 1]) * 0.5)
		if _point_strictly_inside_polygon(midpoint, CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD):
			return true
	return false


static func _segment_exterior_fragments(start: Vector2, finish: Vector2) -> Array[Dictionary]:
	var fragments: Array[Dictionary] = []
	if not start.is_finite() or not finish.is_finite() or start.is_equal_approx(finish):
		return fragments
	var cuts: Array[float] = [0.0, 1.0]
	var delta := finish - start
	var length_squared := delta.length_squared()
	for index in range(CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD.size()):
		var intersection: Variant = Geometry2D.segment_intersects_segment(
			start,
			finish,
			CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD[index],
			CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD[(index + 1) % CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD.size()]
		)
		if not (intersection is Vector2):
			continue
		var amount := clampf(((intersection as Vector2) - start).dot(delta) / length_squared, 0.0, 1.0)
		if not cuts.any(func(existing: float) -> bool: return is_equal_approx(existing, amount)):
			cuts.append(amount)
	cuts.sort()
	for index in range(cuts.size() - 1):
		if cuts[index + 1] - cuts[index] <= BASIS_EPSILON:
			continue
		var midpoint := start.lerp(finish, (cuts[index] + cuts[index + 1]) * 0.5)
		if _point_strictly_inside_polygon(midpoint, CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD):
			continue
		var fragment_start := start.lerp(finish, cuts[index])
		var fragment_finish := start.lerp(finish, cuts[index + 1])
		if fragment_start.distance_squared_to(fragment_finish) <= BASIS_EPSILON * BASIS_EPSILON:
			continue
		fragments.append({
			"start_world": fragment_start,
			"finish_world": fragment_finish,
		})
	return fragments


static func _point_on_central_plaza_boundary(point: Vector2) -> bool:
	if not point.is_finite():
		return false
	for index in range(CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD.size()):
		var closest := Geometry2D.get_closest_point_to_segment(
			point,
			CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD[index],
			CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD[(index + 1) % CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD.size()]
		)
		if closest.distance_squared_to(point) <= BASIS_EPSILON * BASIS_EPSILON:
			return true
	return false


static func _segment_is_inside_or_on_central_hub(start: Vector2, finish: Vector2) -> bool:
	return (
		PlazaMapLayoutGenerator._point_in_or_on_polygon(start, CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD)
		and PlazaMapLayoutGenerator._point_in_or_on_polygon(finish, CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD)
	)


static func _point_strictly_inside_polygon(point: Vector2, polygon: Array[Vector2]) -> bool:
	if not Geometry2D.is_point_in_polygon(point, PackedVector2Array(polygon)):
		return false
	for index in range(polygon.size()):
		var closest := Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])
		if closest.distance_squared_to(point) <= BASIS_EPSILON * BASIS_EPSILON:
			return false
	return true


static func _vertical_segment_is_authored_special_arm(
	edge: Dictionary,
	segment_index: int,
	nodes: Array[Dictionary]
) -> bool:
	var polyline := _vector2_array(edge.get("polyline_world", []))
	if segment_index < 0 or segment_index + 1 >= polyline.size():
		return false
	if polyline[segment_index].distance_to(polyline[segment_index + 1]) > THREE_WAY_ARM_RUN_WORLD + BASIS_EPSILON:
		return false
	var from_node := _find_by_id(nodes, str(edge.get("from", "")))
	var to_node := _find_by_id(nodes, str(edge.get("to", "")))
	var touches_from := segment_index == 0 and _is_authored_three_way_node(from_node)
	var touches_to := segment_index == polyline.size() - 2 and _is_authored_three_way_node(to_node)
	return touches_from or touches_to


static func _is_authored_three_way_node(node: Dictionary) -> bool:
	if str(node.get("role", "")) != "road_piece_junction":
		return false
	var node_id := str(node.get("id", ""))
	for spec_value in R3_SECONDARY_NODE_SPECS:
		var spec := spec_value as Dictionary
		if str(spec.get("id", "")) == node_id:
			return str(spec.get("role", "")) == "road_piece_junction"
	return false


static func _binding_count_by_asset(bindings: Array[Dictionary], asset_id: String) -> int:
	var count := 0
	for binding in bindings:
		if str(binding.get("asset_id", "")) == asset_id:
			count += 1
	return count


static func _node_orientation_signature(node_id: String, edges: Array[Dictionary]) -> String:
	var directions: Array[String] = []
	for arm in _outgoing_arm_records_at_node(node_id, edges):
		directions.append(str(arm.get("direction", "")))
	directions.sort()
	return "+".join(PackedStringArray(directions))


static func _single_node_arm_direction(node_id: String, edges: Array[Dictionary]) -> String:
	var arms := _outgoing_arm_records_at_node(node_id, edges)
	return str(arms[0].get("direction", "")) if arms.size() == 1 else ""


static func _opposite_direction(direction: String) -> String:
	var opposites := {
		"north": "south",
		"north_east": "south_west",
		"east": "west",
		"south_east": "north_west",
		"south": "north",
		"south_west": "north_east",
		"west": "east",
		"north_west": "south_east",
	}
	return str(opposites.get(direction, ""))


static func _count_branch_junctions(road: Dictionary) -> int:
	var degrees := {}
	for edge in _dictionary_array(road.get("edges", [])):
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		degrees[from_id] = int(degrees.get(from_id, 0)) + 1
		degrees[to_id] = int(degrees.get(to_id, 0)) + 1
	var count := 0
	for degree in degrees.values():
		if int(degree) >= 3:
			count += 1
	return count


static func _build_internal_crossing_bindings(road: Dictionary) -> Array[Dictionary]:
	var node_positions := {}
	var nodes := _dictionary_array(road.get("nodes", []))
	var edges := _dictionary_array(road.get("edges", []))
	var crossings: Array[Dictionary] = []
	for node in nodes:
		node_positions[_vector_token(_coerce_vector2(node.get("position", Vector2.INF)))] = true
		if str(node.get("role", "")) != "main_plot_junction":
			continue
		var node_id := str(node.get("id", ""))
		var arms := _outgoing_arm_records_at_node(node_id, edges)
		var directions: Array[String] = []
		var edge_ids: Array[String] = []
		for arm in arms:
			directions.append(str(arm.get("direction", "")))
			edge_ids.append(str(arm.get("edge_id", "")))
		directions.sort()
		edge_ids.sort()
		crossings.append({
			"id": "graph_basis_overlap_%s" % node_id,
			"kind": "graph_basis_overlap",
			"anchor_world": node.get("position", Vector2.ZERO),
			"orientation_signature": "+".join(PackedStringArray(directions)),
			"edge_ids": edge_ids,
			"represented_by_asset_id": "",
			"representation_policy": "explicit_basis_overlap_requires_vulkan_approval",
		})
	var point_records := {}
	for edge in edges:
		var polyline := _vector2_array(edge.get("polyline_world", []))
		for point_index in range(1, polyline.size() - 1):
			var point := polyline[point_index]
			var key := _vector_token(point)
			if node_positions.has(key) or _point_strictly_inside_polygon(point, CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD):
				continue
			if not point_records.has(key):
				point_records[key] = {"point": point, "directions": [], "edge_ids": []}
			var record := point_records[key] as Dictionary
			var directions := record.get("directions", []) as Array
			for neighbor in [polyline[point_index - 1], polyline[point_index + 1]]:
				var direction := classify_directed_segment(point, neighbor)
				if direction != "" and not directions.has(direction):
					directions.append(direction)
			var edge_ids := record.get("edge_ids", []) as Array
			var edge_id := str(edge.get("id", ""))
			if not edge_ids.has(edge_id):
				edge_ids.append(edge_id)
			record["directions"] = directions
			record["edge_ids"] = edge_ids
			point_records[key] = record
	# A crossing need not be authored as a shared polyline vertex. Detect actual
	# segment intersections too; otherwise two stamped straight pieces can cross
	# silently while the graph-level census remains GREEN.
	for left_edge_index in range(edges.size()):
		var left_edge := edges[left_edge_index]
		var left_polyline := _vector2_array(left_edge.get("polyline_world", []))
		for right_edge_index in range(left_edge_index + 1, edges.size()):
			var right_edge := edges[right_edge_index]
			var right_polyline := _vector2_array(right_edge.get("polyline_world", []))
			for left_segment_index in range(left_polyline.size() - 1):
				for right_segment_index in range(right_polyline.size() - 1):
					var intersection_value: Variant = Geometry2D.segment_intersects_segment(
						left_polyline[left_segment_index],
						left_polyline[left_segment_index + 1],
						right_polyline[right_segment_index],
						right_polyline[right_segment_index + 1]
					)
					if not (intersection_value is Vector2):
						continue
					var intersection := intersection_value as Vector2
					var intersection_key := _vector_token(intersection)
					if node_positions.has(intersection_key) or _point_strictly_inside_polygon(intersection, CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD):
						continue
					if not point_records.has(intersection_key):
						point_records[intersection_key] = {"point": intersection, "directions": [], "edge_ids": []}
					var intersection_record := point_records[intersection_key] as Dictionary
					var intersection_directions := intersection_record.get("directions", []) as Array
					for endpoint in [
						left_polyline[left_segment_index],
						left_polyline[left_segment_index + 1],
						right_polyline[right_segment_index],
						right_polyline[right_segment_index + 1],
					]:
						if (endpoint as Vector2).is_equal_approx(intersection):
							continue
						var intersection_direction := classify_directed_segment(intersection, endpoint as Vector2)
						if intersection_direction != "" and not intersection_directions.has(intersection_direction):
							intersection_directions.append(intersection_direction)
					var intersection_edge_ids := intersection_record.get("edge_ids", []) as Array
					for edge_id_value in [str(left_edge.get("id", "")), str(right_edge.get("id", ""))]:
						if not intersection_edge_ids.has(edge_id_value):
							intersection_edge_ids.append(edge_id_value)
					intersection_record["directions"] = intersection_directions
					intersection_record["edge_ids"] = intersection_edge_ids
					point_records[intersection_key] = intersection_record
	var keys: Array[String] = []
	for key_value in point_records.keys():
		keys.append(str(key_value))
	keys.sort()
	for key in keys:
		var record := point_records[key] as Dictionary
		var directions: Array[String] = []
		for direction_value in record.get("directions", []) as Array:
			directions.append(str(direction_value))
		directions.sort()
		var edge_ids: Array[String] = []
		for edge_id_value in record.get("edge_ids", []) as Array:
			edge_ids.append(str(edge_id_value))
		edge_ids.sort()
		if directions.size() < 3 or edge_ids.size() < 2:
			continue
		crossings.append({
			"id": "internal_crossing_%s" % key.replace(",", "_").replace("-", "m").replace(".", "p"),
			"kind": "internal_basis_overlap",
			"anchor_world": record.get("point", Vector2.ZERO),
			"orientation_signature": "+".join(PackedStringArray(directions)),
			"edge_ids": edge_ids,
			"represented_by_asset_id": "",
			"representation_policy": "explicit_basis_overlap_requires_vulkan_approval",
		})
	return crossings


static func _build_walkable_corridors(edges: Array[Dictionary]) -> Array[Dictionary]:
	var corridors: Array[Dictionary] = []
	for edge in edges:
		var half_width := float(edge.get("half_width_world", 0.0))
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
				"cap_style": "square",
				"polygon_world": _segment_corridor_polygon(start, finish, half_width),
			})
	return corridors


static func _build_walkable_hub_manifest() -> Array[Dictionary]:
	return [{
		"id": CENTRAL_PLAZA_HUB_ID,
		"edge_id": CENTRAL_PLAZA_HUB_ID,
		"edge_kind": "hub",
		"segment_index": 0,
		"half_width_world": 1.0,
		"cap_style": "authored_polygon",
		"source_contract_id": CENTRAL_PLAZA_HUB_CONTRACT_ID,
		"polygon_world": CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD.duplicate(),
	}]


static func _segment_corridor_polygon(start: Vector2, finish: Vector2, half_width: float) -> Array[Vector2]:
	var delta := finish - start
	if delta.length_squared() <= 0.0001:
		return []
	var tangent := delta.normalized()
	var normal := Vector2(-tangent.y, tangent.x) * half_width
	var capped_start := start - tangent * half_width
	var capped_finish := finish + tangent * half_width
	return [capped_start + normal, capped_finish + normal, capped_finish - normal, capped_start - normal]


static func _manifest_geometry_token(records: Array[Dictionary]) -> String:
	var tokens: Array[String] = []
	for record in records:
		tokens.append("%s:%s:%d:%.3f" % [str(record.get("id", "")), str(record.get("edge_id", "")), int(record.get("segment_index", -1)), float(record.get("half_width_world", -1.0))])
		for point in _vector2_array(record.get("polygon_world", [])):
			tokens.append(_vector_token(point))
	return "|".join(PackedStringArray(tokens))


static func _find_directed_edge(edges: Array[Dictionary], from_id: String, to_id: String, kind: String) -> Dictionary:
	for edge in edges:
		if str(edge.get("from", "")) == from_id and str(edge.get("to", "")) == to_id and str(edge.get("kind", "")) == kind:
			return edge
	return {}


static func _find_by_id(records: Array[Dictionary], wanted_id: String) -> Dictionary:
	for record in records:
		if str(record.get("id", "")) == wanted_id:
			return record
	return {}


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item in value as Array:
		if item is Dictionary:
			result.append(item as Dictionary)
	return result


static func _building_type_order(buildings: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for building in buildings:
		result.append(str(building.get("type", "")))
	return result


static func _plot_class_order(plots: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for plot in plots:
		result.append(str(plot.get("plot_class", "")))
	return result


static func _vector2_array(value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
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
	return Vector2.INF


static func _polyline_length(polyline: Array[Vector2]) -> float:
	var total := 0.0
	for index in range(polyline.size() - 1):
		total += polyline[index].distance_to(polyline[index + 1])
	return total


static func _compact_polyline(points: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point in points:
		if not result.is_empty() and result[result.size() - 1].is_equal_approx(point):
			continue
		result.append(point)
	return result


static func _vector_token(value: Vector2) -> String:
	return "%.3f,%.3f" % [value.x, value.y]


static func _polygon_token(points: Array[Vector2]) -> String:
	var tokens: Array[String] = []
	for point in points:
		tokens.append(_vector_token(point))
	return ";".join(PackedStringArray(tokens))


static func _add_violation(violations: Array[Dictionary], code: String, detail: String) -> void:
	violations.append({"code": code, "detail": detail})


static func _rejected_layout(reason: String, diagnostics: Dictionary = {}) -> Dictionary:
	var result := {
		"generator_version": GENERATOR_VERSION,
		"candidate_only": true,
		"production_connected": false,
		"validation": {
			"valid": false,
			"violations": [{"code": "promotion_rejected", "detail": reason}],
			"metrics": {},
		},
		"fingerprint": "",
	}
	for key in diagnostics:
		result[key] = diagnostics[key]
	return result
