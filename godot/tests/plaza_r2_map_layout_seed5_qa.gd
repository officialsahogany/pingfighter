extends SceneTree

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaMapLayoutGenerator := preload("res://scripts/plaza/plaza_map_layout_generator.gd")

const WORLD_SIZE := Vector2(2400.0, 1500.0)
const SPAWN_ANCHOR := Vector2(120.0, 666.0)
const EXIT_ZONE := Rect2(Vector2(2250.0, 596.0), Vector2(120.0, 92.0))
const SEED5_TYPES := ["bank", "shop"]
const MIN_SEED_DELTA_RMS_WORLD := 32.0
const MIN_SINGLE_PLOT_DELTA_WORLD := 48.0

var _failures: Array[String] = []


func _init() -> void:
	_run_candidate_data_plane_qa()
	if _failures.is_empty():
		print("plaza_r2_map_layout_seed5_qa: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _run_candidate_data_plane_qa() -> void:
	var selected_specs: Array[Dictionary] = PlazaAssetLoader.build_hwangyeok_building_specs(
		1,
		5,
		false,
		false
	)
	_expect(_building_types(selected_specs) == SEED5_TYPES, "stage 1 seed 5 must preserve the existing bank + shop selection contract")
	var input_positions := _snapshot_input_positions(selected_specs)

	var layout := PlazaMapLayoutGenerator.generate(
		1,
		5,
		WORLD_SIZE,
		selected_specs,
		SPAWN_ANCHOR,
		EXIT_ZONE
	)
	var repeated := PlazaMapLayoutGenerator.generate(
		1,
		5,
		WORLD_SIZE,
		selected_specs,
		SPAWN_ANCHOR,
		EXIT_ZONE
	)
	var different_seed := PlazaMapLayoutGenerator.generate(
		1,
		6,
		WORLD_SIZE,
		selected_specs,
		SPAWN_ANCHOR,
		EXIT_ZONE
	)

	_expect(bool(layout.get("candidate_only", false)), "R2-A layout must declare itself candidate-only")
	_expect(not bool(layout.get("production_connected", true)), "R2-A layout must not pretend to be connected to production")
	_expect(int(layout.get("schema_version", 0)) == PlazaMapLayoutGenerator.SCHEMA_VERSION, "layout must expose its schema version")
	_expect(str(layout.get("generator_version", "")) == PlazaMapLayoutGenerator.GENERATOR_VERSION, "layout must expose its generator version")
	_expect(layout.get("world_size", Vector2.ZERO) == WORLD_SIZE, "layout generation must stay in the fixed 2400 x 1500 world")
	_expect(layout.get("spawn_anchor", Vector2.ZERO) == SPAWN_ANCHOR, "layout must preserve the caller-owned spawn anchor")
	_expect(layout.get("exit_zone", Rect2()) == EXIT_ZONE, "layout must preserve the caller-owned exit zone")
	_expect(_snapshot_input_positions(selected_specs) == input_positions, "candidate generation must not mutate the R1 input specs")
	_expect(_building_types(_dictionary_array(layout.get("building_specs", []))) == SEED5_TYPES, "R2-A placement must preserve selected building type order")

	var plots := _dictionary_array(layout.get("plots", []))
	var buildings := _dictionary_array(layout.get("building_specs", []))
	var decor_clusters := _dictionary_array(layout.get("decor_clusters", []))
	_expect(plots.size() == 7, "seed 5 must generate seven semantic plots")
	_expect(buildings.size() == 2, "seed 5 must place its two selected buildings")
	_expect(decor_clusters.size() == 5, "seed 5 must fill all five unused plots with decor clusters")
	_verify_unused_plot_decor_bijection(plots, decor_clusters)
	_verify_authored_geometry_transform(buildings)
	_verify_decor_authored_geometry(decor_clusters)
	_verify_label_anchor_formula(buildings)
	_verify_walkable_corridor_contract(layout)
	_verify_generator_owned_keys(layout)
	_verify_plot_class_slot_contract(plots)
	_expect(str(layout.get("plot_boundary_overlap_policy", "")) == PlazaMapLayoutGenerator.PLOT_BOUNDARY_OVERLAP_POLICY, "layout must publish the positive-area plot overlap policy")

	var validation := _as_dictionary(layout.get("validation", {}))
	if not bool(validation.get("valid", false)):
		print("plaza_r2_map_layout_seed5_qa: seed5_plot_debug=", _plot_debug_rows(plots))
	_expect(bool(validation.get("valid", false)), "unmodified seed 5 layout must pass the production-independent geometry validator: %s" % [validation.get("violations", [])])
	var different_validation := _as_dictionary(different_seed.get("validation", {}))
	if not bool(different_validation.get("valid", false)):
		print("plaza_r2_map_layout_seed5_qa: seed6_plot_debug=", _plot_debug_rows(_dictionary_array(different_seed.get("plots", []))))
	_expect(bool(different_validation.get("valid", false)), "seed 6 comparison layout must also satisfy the same geometry validator: %s" % [different_validation.get("violations", [])])
	var metrics := _as_dictionary(validation.get("metrics", {}))
	var max_gap := float(metrics.get("max_landmark_gap_world", INF))
	_expect(max_gap <= PlazaMapLayoutGenerator.MAX_LANDMARK_GAP_WORLD + 0.01, "seed 5 main-route landmark gap must be <= 360 world units (got %.3f)" % max_gap)
	_expect(int(metrics.get("unused_plot_count", -1)) == 5, "validator must independently count five unused seed 5 plots")
	_expect(float(metrics.get("plot_y_span_ratio", 0.0)) >= PlazaMapLayoutGenerator.MIN_PLOT_Y_SPAN_RATIO, "seed 5 plot pivots must span the 2D map vertically")
	_expect(int(metrics.get("upper_plot_count", 0)) >= PlazaMapLayoutGenerator.MIN_UPPER_LOWER_PLOT_COUNT, "seed 5 must place at least two plots in the upper map band")
	_expect(int(metrics.get("lower_plot_count", 0)) >= PlazaMapLayoutGenerator.MIN_UPPER_LOWER_PLOT_COUNT, "seed 5 must place at least two plots in the lower map band")
	_expect(float(metrics.get("structural_bbox_height_ratio", 0.0)) >= PlazaMapLayoutGenerator.MIN_STRUCTURAL_BBOX_HEIGHT_RATIO, "road + parcel structure must occupy at least 60% of world height")
	_expect(float(metrics.get("content_anchor_bbox_area_ratio", 0.0)) >= PlazaMapLayoutGenerator.MIN_CONTENT_ANCHOR_AREA_RATIO, "building + decor anchors must occupy a material 2D area")
	_expect(int(metrics.get("secondary_cycle_rank", 0)) >= 1, "structural road graph must contain a real secondary cycle")

	var fingerprint := str(layout.get("fingerprint", ""))
	_expect(fingerprint.length() == 64, "candidate fingerprint must be a concrete SHA-256 digest")
	_expect(fingerprint == str(repeated.get("fingerprint", "")), "same stage + seed + fixed world must reproduce the exact layout fingerprint")
	_expect(fingerprint != str(different_seed.get("fingerprint", "")), "a different layout seed must alter road/plot/decor geometry")
	_verify_fingerprint_geometry_counterproof(layout, fingerprint)
	_verify_fixed_world_size_counterproof(selected_specs, layout)
	_expect(_building_types(_dictionary_array(different_seed.get("building_specs", []))) == SEED5_TYPES, "layout RNG changes must not consume or alter the preselected building set")
	var road := _as_dictionary(layout.get("road_graph", {}))
	var different_road := _as_dictionary(different_seed.get("road_graph", {}))
	_expect(str(road.get("skeleton_variant", "")) != "", "road graph must expose its concrete seeded skeleton variant")
	_expect(str(road.get("skeleton_variant", "")) != str(different_road.get("skeleton_variant", "")), "seed 5 and seed 6 must select different structural road motifs")
	_expect(str(road.get("secondary_side", "")) != str(different_road.get("secondary_side", "")) or road.get("secondary_anchor_slots", []) != different_road.get("secondary_anchor_slots", []), "seed 5 and seed 6 must materially change the secondary cycle side or anchor pair")
	_expect(_road_edge_kind_count(road, "secondary") == 3, "seed 5 must expose the three real edges of its secondary cycle")
	_expect(_road_edge_kind_count(road, "trail") == 5, "five unused plots must expose five noninteractive visible trails")
	_expect(_selected_building_slot_change_count(buildings, _dictionary_array(different_seed.get("building_specs", []))) >= 1, "seed 5 -> 6 must move at least one selected building to a different semantic route slot")
	var seed_delta := _paired_plot_delta_metrics(plots, _dictionary_array(different_seed.get("plots", [])))
	_expect(float(seed_delta.get("rms_world", 0.0)) >= MIN_SEED_DELTA_RMS_WORLD, "seed 5 -> 6 plot-anchor RMS must be visually material (got %.3f, need %.3f)" % [float(seed_delta.get("rms_world", 0.0)), MIN_SEED_DELTA_RMS_WORLD])
	_expect(float(seed_delta.get("max_world", 0.0)) >= MIN_SINGLE_PLOT_DELTA_WORLD, "at least one seed 5 -> 6 plot anchor must move >= 48 world units (got %.3f)" % float(seed_delta.get("max_world", 0.0)))

	_verify_missing_decor_counterproof(layout)
	_verify_disconnected_exit_counterproof(layout)
	_verify_footprint_overlap_counterproof(layout)
	_verify_building_decor_overlap_counterproof(layout)
	_verify_decor_overlap_counterproof(layout)
	_verify_plot_boundary_counterproof(layout)
	_verify_plot_overlap_counterproof(layout)
	_verify_road_core_counterproof(layout)
	_verify_road_shoulder_only_counterproof(layout)
	_verify_canonical_road_width_counterproof(layout)
	_verify_road_plot_boundary_counterproof(layout)
	_verify_blocked_manifest_counterproof(layout)
	_verify_selected_contract_counterproof(layout)
	_verify_selected_roster_corpus(selected_specs)
	_verify_consumed_type_counterproofs(layout)
	_verify_label_anchor_counterproof(layout)
	_verify_reverse_label_collision_counterproof(layout)
	_verify_decor_label_collision_counterproof(layout)
	_verify_walkable_manifest_counterproof(layout)
	_verify_route_scalar_counterproof(layout, max_gap)
	_verify_edge_endpoint_counterproof(layout)
	_verify_main_route_extra_edge_counterproof(layout)
	_verify_orphan_road_counterproof(layout)
	_verify_collapsed_footprint_counterproof(layout)
	_verify_authored_closure_counterproof(layout)
	_verify_non_finite_geometry_counterproof(layout)
	_verify_vertical_flatten_counterproof(layout)
	_verify_secondary_cycle_counterproof(layout)
	_verify_exact_secondary_topology_counterproof(layout)
	_verify_trail_disconnect_counterproof(layout)
	print("plaza_r2_map_layout_seed5_qa: metrics max_gap=%.3f seed_delta_rms=%.3f seed_delta_max=%.3f plot_y_ratio=%.3f upper=%d lower=%d structural_h=%.3f anchor_area=%.3f cycle=%d" % [max_gap, float(seed_delta.get("rms_world", 0.0)), float(seed_delta.get("max_world", 0.0)), float(metrics.get("plot_y_span_ratio", 0.0)), int(metrics.get("upper_plot_count", 0)), int(metrics.get("lower_plot_count", 0)), float(metrics.get("structural_bbox_height_ratio", 0.0)), float(metrics.get("content_anchor_bbox_area_ratio", 0.0)), int(metrics.get("secondary_cycle_rank", 0))])


func _plot_debug_rows(plots: Array[Dictionary]) -> Array[String]:
	var rows: Array[String] = []
	for plot in plots:
		var boundary := _vector2_array(plot.get("boundary_polygon_world", []))
		var minimum := Vector2(INF, INF)
		var maximum := Vector2(-INF, -INF)
		for point in boundary:
			minimum.x = minf(minimum.x, point.x)
			minimum.y = minf(minimum.y, point.y)
			maximum.x = maxf(maximum.x, point.x)
			maximum.y = maxf(maximum.y, point.y)
		rows.append("%s@%s bounds=%s/%s occ=%s" % [str(plot.get("id", "")), plot.get("pivot_pos", Vector2.ZERO), minimum, maximum - minimum, str(plot.get("occupied_by", ""))])
	return rows


func _verify_unused_plot_decor_bijection(
	plots: Array[Dictionary],
	decor_clusters: Array[Dictionary]
) -> void:
	var decor_counts := {}
	for decor in decor_clusters:
		var plot_id := str(decor.get("plot_id", ""))
		decor_counts[plot_id] = int(decor_counts.get(plot_id, 0)) + 1
	var unused_count := 0
	for plot in plots:
		var plot_id := str(plot.get("id", ""))
		if str(plot.get("occupied_by", "")) == "":
			unused_count += 1
			_expect(int(decor_counts.get(plot_id, 0)) == 1, "unused plot %s must own exactly one visible decor cluster" % plot_id)
		else:
			_expect(int(decor_counts.get(plot_id, 0)) == 0, "occupied plot %s must not also receive filler decor" % plot_id)
	_expect(unused_count == 5, "seed 5 must leave exactly five semantic plots unused")


func _verify_authored_geometry_transform(buildings: Array[Dictionary]) -> void:
	for building in buildings:
		var building_type := str(building.get("type", "building"))
		var pivot: Vector2 = building.get("pivot_pos", Vector2.ZERO)
		var display_scale := float(building.get("display_scale", 0.0))
		var source_size: Vector2 = building.get("source_size", Vector2.ZERO)
		var origin_pivot: Vector2 = building.get("origin_pivot", Vector2.ZERO)
		var visual_rect: Rect2 = building.get("visual_rect", Rect2())
		var expected_visual := Rect2(pivot - origin_pivot * display_scale, source_size * display_scale)
		_expect(visual_rect.is_equal_approx(expected_visual), "%s visual rect must use pivot - origin * scale and source size * scale" % building_type)
		var source_footprint := _vector2_array(building.get("footprint_polygon", []))
		var world_footprint := _vector2_array(building.get("footprint_world_polygon", []))
		_expect(source_footprint.size() == world_footprint.size() and source_footprint.size() == 4, "%s footprint transform must preserve all four authored vertices" % building_type)
		_expect(_polygon_area_abs(source_footprint) > 1.0 and _polygon_area_abs(world_footprint) > 1.0, "%s authored and world footprints must both have positive area" % building_type)
		for index in range(mini(source_footprint.size(), world_footprint.size())):
			var expected := pivot + source_footprint[index] * display_scale
			_expect(world_footprint[index].is_equal_approx(expected), "%s footprint vertex %d must use pivot + source-px offset * display_scale" % [building_type, index])
		var entrance_offset: Vector2 = building.get("entrance_anchor_offset", Vector2.ZERO)
		var entrance_world: Vector2 = building.get("entrance_world_pos", Vector2.ZERO)
		_expect(entrance_world.is_equal_approx(pivot + entrance_offset * display_scale), "%s entrance must consume its separately authored source-px offset" % building_type)
		var label_anchor: Vector2 = building.get("label_anchor", Vector2.ZERO)
		var label_source_pixels: Vector2 = building.get("label_anchor_source_pixels", Vector2.ZERO)
		_expect(label_anchor.is_equal_approx(label_source_pixels - origin_pivot), "%s label source pixel must resolve to the authored pivot-relative stem" % building_type)
		_expect((building.get("label_world_pos", Vector2.ZERO) as Vector2).is_equal_approx(pivot + label_anchor * display_scale), "%s label stem must derive from its authored source offset" % building_type)
		var sort_anchor: Vector2 = building.get("sort_anchor", Vector2.ZERO)
		var expected_sort := pivot + sort_anchor * display_scale
		_expect((building.get("sort_anchor_world", Vector2.ZERO) as Vector2).is_equal_approx(expected_sort), "%s sort anchor must derive from its authored source offset" % building_type)
		_expect(is_equal_approx(float(building.get("y_sort_anchor", INF)), expected_sort.y), "%s y-sort scalar must equal the derived sort anchor y" % building_type)
		var clearance := _vector2_array(building.get("road_side_clearance_polygon_world", []))
		var interaction := _vector2_array(building.get("interaction_polygon_world", []))
		_expect(clearance.size() == 4, "%s must expose a four-point map-world road clearance polygon" % building_type)
		_expect(interaction.size() == 4, "%s must expose a four-point map-world interaction polygon" % building_type)
		var normal: Vector2 = building.get("entrance_normal", Vector2.ZERO)
		var clearance_value: Variant = building.get("road_side_clearance", {})
		var clearance_source: Dictionary = clearance_value as Dictionary if clearance_value is Dictionary else {}
		var cross_width := float(clearance_source.get("cross_width", 0.0))
		var approach_depth := float(clearance_source.get("approach_depth", 0.0))
		var expected_clearance := _oriented_approach_polygon_for_qa(entrance_world, normal, cross_width, approach_depth)
		var expected_interaction := _oriented_approach_polygon_for_qa(entrance_world, normal, minf(cross_width, 120.0), minf(approach_depth, 78.0))
		_expect(_polygons_equal_approx(clearance, expected_clearance), "%s road clearance must derive from entrance normal and authored clearance dimensions" % building_type)
		_expect(_polygons_equal_approx(interaction, expected_interaction), "%s interaction polygon must derive from the same authored entrance contract" % building_type)
		_expect((building.get("interaction_rect", Rect2()) as Rect2).is_equal_approx(_polygon_aabb_for_qa(interaction)), "%s interaction rect must be the exact interaction-polygon AABB" % building_type)


func _verify_decor_authored_geometry(decor_clusters: Array[Dictionary]) -> void:
	for decor in decor_clusters:
		var decor_id := str(decor.get("id", "decor"))
		var anchor: Vector2 = decor.get("anchor_world", Vector2.ZERO)
		_expect(_polygons_equal_approx(_vector2_array(decor.get("footprint_world_polygon", [])), _decor_footprint_for_qa(anchor)), "%s footprint must derive exactly from its anchor" % decor_id)
		_expect((decor.get("sort_anchor_world", Vector2.ZERO) as Vector2).is_equal_approx(anchor), "%s sort anchor must equal its authored anchor" % decor_id)
		var visual: Rect2 = decor.get("visual_bounds_world", Rect2())
		_expect(Vector2(visual.get_center().x, visual.end.y).is_equal_approx(anchor), "%s visual bottom-center must equal its authored anchor" % decor_id)


func _verify_label_anchor_formula(buildings: Array[Dictionary]) -> void:
	for building in buildings:
		var building_type := str(building.get("type", "building"))
		var stem_value: Variant = building.get("label_world_pos", null)
		var rect_value: Variant = building.get("label_rect_world", null)
		_expect(stem_value is Vector2 and rect_value is Rect2, "%s must expose typed label stem and rect geometry" % building_type)
		if not (stem_value is Vector2 and rect_value is Rect2):
			continue
		var stem := stem_value as Vector2
		var rect := rect_value as Rect2
		var display_name := str(building.get("display_name", building_type))
		var expected_size := Vector2(clampf(36.0 + float(display_name.length()) * 26.0, 114.0, 192.0), PlazaMapLayoutGenerator.LABEL_HEIGHT_WORLD)
		var expected_position := stem + Vector2(PlazaMapLayoutGenerator.LABEL_STEM_GAP_WORLD, -expected_size.y * 0.5)
		_expect(rect.position.is_equal_approx(expected_position), "%s label rect must start exactly 12 world units right of its authored stem" % building_type)
		_expect(rect.size.is_equal_approx(expected_size), "%s label rect must use the deterministic display-name size contract" % building_type)


func _verify_walkable_corridor_contract(layout: Dictionary) -> void:
	var road := _as_dictionary(layout.get("road_graph", {}))
	var corridors := _dictionary_array(layout.get("walkable_corridor_polygons", []))
	var corridor_by_id := {}
	for corridor in corridors:
		corridor_by_id[str(corridor.get("id", ""))] = corridor
	var expected_segment_count := 0
	var joint_sample_count := 0
	for edge in _dictionary_array(road.get("edges", [])):
		var edge_id := str(edge.get("id", ""))
		var edge_kind := str(edge.get("kind", ""))
		var half_width := float(edge.get("half_width_world", 0.0))
		var canonical_value: Variant = PlazaMapLayoutGenerator.ROAD_HALF_WIDTH_BY_KIND.get(edge_kind, null)
		_expect(canonical_value is float and is_equal_approx(half_width, float(canonical_value)), "%s must consume the canonical %s road half-width" % [edge_id, edge_kind])
		var polyline := _vector2_array(edge.get("polyline_world", []))
		expected_segment_count += maxi(0, polyline.size() - 1)
		for segment_index in range(polyline.size() - 1):
			var corridor_id := "%s_segment_%d" % [edge_id, segment_index]
			_expect(corridor_by_id.has(corridor_id), "%s must derive one walkable polygon from every edge segment" % corridor_id)
			if not corridor_by_id.has(corridor_id):
				continue
			var corridor_value: Variant = corridor_by_id.get(corridor_id, {})
			var corridor: Dictionary = corridor_value as Dictionary if corridor_value is Dictionary else {}
			_expect(str(corridor.get("cap_style", "")) == PlazaMapLayoutGenerator.WALKABLE_CAP_STYLE, "%s must declare square caps" % corridor_id)
			var expected_finish := polyline[segment_index + 1]
			if edge_kind == "approach" and segment_index == polyline.size() - 2:
				expected_finish = expected_finish.move_toward(polyline[segment_index], half_width + 1.0)
			var expected_polygon := _square_cap_corridor(polyline[segment_index], expected_finish, half_width)
			_expect(_polygons_equal_approx(_vector2_array(corridor.get("polygon_world", [])), expected_polygon), "%s geometry must be derived from the edge and authored width, including square caps" % corridor_id)
		for joint_index in range(1, polyline.size() - 1):
			var adjacent: Array[Dictionary] = []
			for segment_index in [joint_index - 1, joint_index]:
				var corridor_value: Variant = corridor_by_id.get("%s_segment_%d" % [edge_id, segment_index], {})
				if corridor_value is Dictionary:
					adjacent.append(corridor_value as Dictionary)
			var sample_radius := half_width * 0.72
			for direction_value in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				var direction: Vector2 = direction_value
				var sample: Vector2 = polyline[joint_index] + direction * sample_radius
				var covered := false
				for corridor in adjacent:
					if _point_in_or_on_polygon(sample, _vector2_array(corridor.get("polygon_world", []))):
						covered = true
						break
				_expect(covered, "%s joint %d must not expose a flat-cap turning wedge" % [edge_id, joint_index])
				joint_sample_count += 1
	_expect(corridors.size() == expected_segment_count, "walkable manifest must contain exactly one entry per edge segment")
	_expect(joint_sample_count > 0, "seed 5 must exercise at least one multi-segment square-cap road joint")


func _verify_generator_owned_keys(layout: Dictionary) -> void:
	for forbidden_key in ["viewport_size", "render_size", "safe_rect", "fit_scale", "map_safe_rect"]:
		_expect(not layout.has(forbidden_key), "layout cache/data contract must not accept screen-derived key %s" % forbidden_key)
	var road := _as_dictionary(layout.get("road_graph", {}))
	for forbidden_key in ["viewport_size", "render_size", "safe_rect", "fit_scale", "map_safe_rect"]:
		_expect(not road.has(forbidden_key), "road generation must remain viewport-independent (%s)" % forbidden_key)


func _verify_plot_class_slot_contract(plots: Array[Dictionary]) -> void:
	var landmark_slots: Array[int] = []
	for plot in plots:
		var plot_class := str(plot.get("plot_class", ""))
		var slot_index := int(plot.get("route_slot_index", -1))
		if plot_class == "edge_large":
			_expect(slot_index == 6, "edge_large must own the reserved right-edge slot 6")
		elif ["rear_landmark_large", "intersection_large"].has(plot_class):
			_expect([2, 4].has(slot_index), "%s must use one of the two seeded landmark slots" % plot_class)
			landmark_slots.append(slot_index)
	landmark_slots.sort()
	_expect(landmark_slots == [2, 4], "rear/intersection landmark classes must consume slots 2 and 4 exactly once")


func _verify_fingerprint_geometry_counterproof(layout: Dictionary, expected_fingerprint: String) -> void:
	_expect(PlazaMapLayoutGenerator.build_fingerprint(layout) == expected_fingerprint, "stored fingerprint must equal a fresh full-geometry digest")
	var mutations: Array[Dictionary] = []

	var road_width := layout.duplicate(true)
	var road := _as_dictionary(road_width.get("road_graph", {}))
	var edges_value: Variant = road.get("edges", [])
	if edges_value is Array and not (edges_value as Array).is_empty():
		var edge := ((edges_value as Array)[0] as Dictionary).duplicate(true)
		edge["half_width_world"] = float(edge.get("half_width_world", 0.0)) + 1.0
		(edges_value as Array)[0] = edge
		road["edges"] = edges_value
		road_width["road_graph"] = road
	mutations.append({"label": "road_half_width", "layout": road_width})
	var road_polyline := layout.duplicate(true)
	road = _as_dictionary(road_polyline.get("road_graph", {}))
	edges_value = road.get("edges", [])
	if edges_value is Array and not (edges_value as Array).is_empty():
		var edge := ((edges_value as Array)[0] as Dictionary).duplicate(true)
		var polyline := _vector2_array(edge.get("polyline_world", []))
		if not polyline.is_empty():
			polyline[0] += Vector2(1.0, 0.0)
		edge["polyline_world"] = polyline
		(edges_value as Array)[0] = edge
		road["edges"] = edges_value
		road_polyline["road_graph"] = road
	mutations.append({"label": "road_polyline", "layout": road_polyline})

	var node_ownership := layout.duplicate(true)
	road = _as_dictionary(node_ownership.get("road_graph", {}))
	var nodes_value: Variant = road.get("nodes", [])
	if nodes_value is Array:
		for index in range((nodes_value as Array).size()):
			var node_value: Variant = (nodes_value as Array)[index]
			if not (node_value is Dictionary) or str((node_value as Dictionary).get("plot_id", "")) == "":
				continue
			var node := (node_value as Dictionary).duplicate(true)
			node["plot_id"] = "%s_mutated" % str(node.get("plot_id", ""))
			(nodes_value as Array)[index] = node
			break
		road["nodes"] = nodes_value
		node_ownership["road_graph"] = road
	mutations.append({"label": "road_node_plot_id", "layout": node_ownership})

	var plot_boundary := layout.duplicate(true)
	var plots_value: Variant = plot_boundary.get("plots", [])
	if plots_value is Array and not (plots_value as Array).is_empty():
		var plot := ((plots_value as Array)[0] as Dictionary).duplicate(true)
		var boundary := _vector2_array(plot.get("boundary_polygon_world", []))
		if not boundary.is_empty():
			boundary[0] += Vector2(1.0, 0.0)
		plot["boundary_polygon_world"] = boundary
		(plots_value as Array)[0] = plot
		plot_boundary["plots"] = plots_value
	mutations.append({"label": "plot_boundary", "layout": plot_boundary})

	for field_name in ["visual_rect", "interaction_rect", "label_world_pos", "footprint_world_polygon", "road_side_clearance_polygon_world"]:
		var building_geometry := layout.duplicate(true)
		var buildings_value: Variant = building_geometry.get("building_specs", [])
		if buildings_value is Array and not (buildings_value as Array).is_empty():
			var building := ((buildings_value as Array)[0] as Dictionary).duplicate(true)
			if ["visual_rect", "interaction_rect"].has(field_name):
				var rect: Rect2 = building.get(field_name, Rect2())
				rect.position.x += 1.0
				building[field_name] = rect
			elif field_name == "label_world_pos":
				building[field_name] = (building.get(field_name, Vector2.ZERO) as Vector2) + Vector2(1.0, 0.0)
			else:
				var polygon := _vector2_array(building.get(field_name, []))
				if not polygon.is_empty():
					polygon[0] += Vector2(1.0, 0.0)
				building[field_name] = polygon
			(buildings_value as Array)[0] = building
			building_geometry["building_specs"] = buildings_value
		mutations.append({"label": "building_%s" % field_name, "layout": building_geometry})

	for field_name in ["visual_bounds_world", "footprint_world_polygon"]:
		var decor_geometry := layout.duplicate(true)
		var decor_value: Variant = decor_geometry.get("decor_clusters", [])
		if decor_value is Array and not (decor_value as Array).is_empty():
			var decor := ((decor_value as Array)[0] as Dictionary).duplicate(true)
			if field_name == "visual_bounds_world":
				var bounds: Rect2 = decor.get(field_name, Rect2())
				bounds.position.x += 1.0
				decor[field_name] = bounds
			else:
				var footprint := _vector2_array(decor.get(field_name, []))
				if not footprint.is_empty():
					footprint[0] += Vector2(1.0, 0.0)
				decor[field_name] = footprint
			(decor_value as Array)[0] = decor
			decor_geometry["decor_clusters"] = decor_value
		mutations.append({"label": "decor_%s" % field_name, "layout": decor_geometry})

	var blocker_geometry := layout.duplicate(true)
	var blockers_value: Variant = blocker_geometry.get("blocked_polygons", [])
	if blockers_value is Array and not (blockers_value as Array).is_empty():
		var blocker := ((blockers_value as Array)[0] as Dictionary).duplicate(true)
		var polygon := _vector2_array(blocker.get("polygon_world", []))
		if not polygon.is_empty():
			polygon[0] += Vector2(1.0, 0.0)
		blocker["polygon_world"] = polygon
		(blockers_value as Array)[0] = blocker
		blocker_geometry["blocked_polygons"] = blockers_value
	mutations.append({"label": "blocked_polygon", "layout": blocker_geometry})

	var walkable_geometry := layout.duplicate(true)
	var corridors_value: Variant = walkable_geometry.get("walkable_corridor_polygons", [])
	if corridors_value is Array and not (corridors_value as Array).is_empty():
		var corridor := ((corridors_value as Array)[0] as Dictionary).duplicate(true)
		var polygon := _vector2_array(corridor.get("polygon_world", []))
		if not polygon.is_empty():
			polygon[0] += Vector2(1.0, 0.0)
		corridor["polygon_world"] = polygon
		(corridors_value as Array)[0] = corridor
		walkable_geometry["walkable_corridor_polygons"] = corridors_value
	mutations.append({"label": "walkable_corridor", "layout": walkable_geometry})

	var portal_geometry := layout.duplicate(true)
	var portals_value: Variant = portal_geometry.get("interaction_portals", [])
	if portals_value is Array and not (portals_value as Array).is_empty():
		var portal := ((portals_value as Array)[0] as Dictionary).duplicate(true)
		var polygon := _vector2_array(portal.get("polygon_world", []))
		if not polygon.is_empty():
			polygon[0] += Vector2(1.0, 0.0)
		portal["polygon_world"] = polygon
		(portals_value as Array)[0] = portal
		portal_geometry["interaction_portals"] = portals_value
	mutations.append({"label": "interaction_portal", "layout": portal_geometry})

	for mutation in mutations:
		var mutated_layout := _as_dictionary(mutation.get("layout", {}))
		var mutated_fingerprint := PlazaMapLayoutGenerator.build_fingerprint(mutated_layout)
		_expect(mutated_fingerprint.length() == 64 and mutated_fingerprint != expected_fingerprint, "%s mutation must alter the full-geometry digest" % str(mutation.get("label", "mutation")))
	_expect(mutations.size() == 14, "fingerprint counterproof must cover fourteen representative consumed geometry and ownership mutations")


func _verify_fixed_world_size_counterproof(selected_specs: Array[Dictionary], layout: Dictionary) -> void:
	var mutated := layout.duplicate(true)
	mutated["world_size"] = Vector2(2399.0, 1500.0)
	var mutated_validation := PlazaMapLayoutGenerator.validate_layout(mutated)
	_expect(not bool(mutated_validation.get("valid", true)), "validator must reject any noncanonical map world size")
	_expect(_has_violation(mutated_validation, "world_size_contract_mismatch"), "mutated world size must report world_size_contract_mismatch")

	var generated := PlazaMapLayoutGenerator.generate(
		1,
		5,
		Vector2(2399.0, 1500.0),
		selected_specs,
		SPAWN_ANCHOR,
		EXIT_ZONE
	)
	var generated_validation := _as_dictionary(generated.get("validation", {}))
	_expect(not bool(generated_validation.get("valid", true)), "public generation must fail closed when a viewport-derived world size is supplied")
	_expect(_has_violation(generated_validation, "world_size_contract_mismatch"), "public generation mismatch must report world_size_contract_mismatch")


func _verify_missing_decor_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var decor_value: Variant = corrupted.get("decor_clusters", [])
	if decor_value is Array and not (decor_value as Array).is_empty():
		(decor_value as Array).remove_at(0)
	corrupted["decor_clusters"] = decor_value
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "removing decor from an unused plot must turn the same validator RED")
	_expect(_has_violation(validation, "unused_plot_unfilled"), "missing-decor counterproof must report unused_plot_unfilled")


func _verify_disconnected_exit_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var road := _as_dictionary(corrupted.get("road_graph", {}))
	var edges_value: Variant = road.get("edges", [])
	if edges_value is Array:
		var edges := edges_value as Array
		for index in range(edges.size() - 1, -1, -1):
			var edge_value: Variant = edges[index]
			if edge_value is Dictionary and str((edge_value as Dictionary).get("kind", "")) == "main" and str((edge_value as Dictionary).get("to", "")) == "exit":
				edges.remove_at(index)
				break
		road["edges"] = edges
	corrupted["road_graph"] = road
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "removing the final main-road edge must turn the same validator RED")
	_expect(_has_violation(validation, "exit_disconnected"), "broken-road counterproof must report exit_disconnected")


func _verify_footprint_overlap_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var buildings_value: Variant = corrupted.get("building_specs", [])
	if buildings_value is Array:
		var buildings := buildings_value as Array
		var bank_polygon: Array[Vector2] = []
		var shop_index := -1
		for index in range(buildings.size()):
			var building_value: Variant = buildings[index]
			if not (building_value is Dictionary):
				continue
			var building := building_value as Dictionary
			match str(building.get("type", "")):
				"bank":
					bank_polygon = _vector2_array(building.get("footprint_world_polygon", []))
				"shop":
					shop_index = index
		if shop_index >= 0 and not bank_polygon.is_empty():
			var shop := (buildings[shop_index] as Dictionary).duplicate(true)
			shop["footprint_world_polygon"] = bank_polygon.duplicate()
			buildings[shop_index] = shop
		corrupted["building_specs"] = buildings
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "overlapping bank/shop footprints must turn the same validator RED")
	_expect(_has_violation(validation, "building_footprint_overlap"), "overlap counterproof must report building_footprint_overlap")


func _verify_building_decor_overlap_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var bank := _find_dictionary_by_field(_dictionary_array(corrupted.get("building_specs", [])), "type", "bank")
	var bank_polygon := _vector2_array(bank.get("footprint_world_polygon", []))
	var decor_value: Variant = corrupted.get("decor_clusters", [])
	if decor_value is Array and not (decor_value as Array).is_empty() and not bank_polygon.is_empty():
		var decor := ((decor_value as Array)[0] as Dictionary).duplicate(true)
		decor["footprint_world_polygon"] = bank_polygon.duplicate()
		(decor_value as Array)[0] = decor
		corrupted["decor_clusters"] = decor_value
		_replace_blocked_polygon(corrupted, "decor", str(decor.get("id", "")), bank_polygon)
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "moving decor onto a building must turn the same validator RED")
	_expect(_has_violation(validation, "building_decor_footprint_overlap"), "building/decor counterproof must report building_decor_footprint_overlap")


func _verify_decor_overlap_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var decor_value: Variant = corrupted.get("decor_clusters", [])
	if decor_value is Array and (decor_value as Array).size() >= 2:
		var first := (decor_value as Array)[0] as Dictionary
		var first_polygon := _vector2_array(first.get("footprint_world_polygon", []))
		var second := ((decor_value as Array)[1] as Dictionary).duplicate(true)
		second["footprint_world_polygon"] = first_polygon.duplicate()
		(decor_value as Array)[1] = second
		corrupted["decor_clusters"] = decor_value
		_replace_blocked_polygon(corrupted, "decor", str(second.get("id", "")), first_polygon)
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "overlapping two decor blockers must turn the same validator RED")
	_expect(_has_violation(validation, "decor_footprint_overlap"), "decor/decor counterproof must report decor_footprint_overlap")


func _verify_plot_boundary_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var plots_value: Variant = corrupted.get("plots", [])
	if plots_value is Array:
		for index in range((plots_value as Array).size()):
			var plot_value: Variant = (plots_value as Array)[index]
			if not (plot_value is Dictionary) or str((plot_value as Dictionary).get("occupied_by", "")) != "bank":
				continue
			var plot := (plot_value as Dictionary).duplicate(true)
			var pivot: Vector2 = plot.get("pivot_pos", Vector2.ZERO)
			plot["boundary_polygon_world"] = [
				pivot + Vector2(0.0, -8.0),
				pivot + Vector2(8.0, 0.0),
				pivot + Vector2(0.0, 8.0),
				pivot + Vector2(-8.0, 0.0),
			]
			(plots_value as Array)[index] = plot
			break
		corrupted["plots"] = plots_value
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "shrinking an occupied plot away from its authored footprint must turn the validator RED")
	_expect(_has_violation(validation, "building_outside_plot_boundary"), "plot-boundary counterproof must report building_outside_plot_boundary")


func _verify_plot_overlap_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var plots_value: Variant = corrupted.get("plots", [])
	if plots_value is Array and (plots_value as Array).size() >= 2:
		var first := (plots_value as Array)[0] as Dictionary
		var second := ((plots_value as Array)[1] as Dictionary).duplicate(true)
		second["boundary_polygon_world"] = _vector2_array(first.get("boundary_polygon_world", [])).duplicate()
		(plots_value as Array)[1] = second
		corrupted["plots"] = plots_value
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "overlapping two semantic parcel boundaries must turn the validator RED")
	_expect(_has_violation(validation, "plot_boundary_overlap"), "plot-overlap counterproof must enforce forbid_positive_area")


func _verify_road_core_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var bank := _find_dictionary_by_field(_dictionary_array(corrupted.get("building_specs", [])), "type", "bank")
	var bank_polygon := _vector2_array(bank.get("footprint_world_polygon", []))
	var road := _as_dictionary(corrupted.get("road_graph", {}))
	var edges_value: Variant = road.get("edges", [])
	if edges_value is Array and not (edges_value as Array).is_empty() and not bank_polygon.is_empty():
		var edge := ((edges_value as Array)[0] as Dictionary).duplicate(true)
		var polyline := _vector2_array(edge.get("polyline_world", []))
		if polyline.size() >= 2:
			edge["polyline_world"] = [polyline[0], _polygon_centroid(bank_polygon), polyline[polyline.size() - 1]]
			(edges_value as Array)[0] = edge
			road["edges"] = edges_value
			corrupted["road_graph"] = road
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "routing a main-road core through the bank must turn the validator RED")
	_expect(_has_violation(validation, "road_corridor_blocked"), "road counterproof must report road_corridor_blocked using the authored edge half-width")


func _verify_road_shoulder_only_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var road := _as_dictionary(corrupted.get("road_graph", {}))
	var target_edge: Dictionary = {}
	for edge in _dictionary_array(road.get("edges", [])):
		if str(edge.get("kind", "")) == "main" and _vector2_array(edge.get("polyline_world", [])).size() >= 2:
			target_edge = edge
			break
	var decor_value: Variant = corrupted.get("decor_clusters", [])
	if not target_edge.is_empty() and decor_value is Array and not (decor_value as Array).is_empty():
		var polyline := _vector2_array(target_edge.get("polyline_world", []))
		var start := polyline[0]
		var finish := polyline[1]
		var tangent := (finish - start).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var half_width := float(target_edge.get("half_width_world", 0.0))
		var blocker_half_size := 5.0
		var blocker_center := start.lerp(finish, 0.5) + normal * (half_width - blocker_half_size * 2.0)
		var shoulder_only_polygon: Array[Vector2] = [
			blocker_center - tangent * blocker_half_size - normal * blocker_half_size,
			blocker_center + tangent * blocker_half_size - normal * blocker_half_size,
			blocker_center + tangent * blocker_half_size + normal * blocker_half_size,
			blocker_center - tangent * blocker_half_size + normal * blocker_half_size,
		]
		var minimum_centerline_distance := INF
		for point in shoulder_only_polygon:
			minimum_centerline_distance = minf(minimum_centerline_distance, point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, finish)))
		_expect(minimum_centerline_distance > 0.5, "shoulder-only counterproof blocker must not touch the road centreline")
		var decor := ((decor_value as Array)[0] as Dictionary).duplicate(true)
		decor["anchor_world"] = blocker_center
		decor["sort_anchor_world"] = blocker_center
		decor["footprint_world_polygon"] = shoulder_only_polygon
		decor["visual_bounds_world"] = Rect2(blocker_center - Vector2(45.0, 60.0), Vector2(90.0, 70.0))
		(decor_value as Array)[0] = decor
		corrupted["decor_clusters"] = decor_value
		_replace_blocked_polygon(corrupted, "decor", str(decor.get("id", "")), shoulder_only_polygon)
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "a blocker touched only by the authored road shoulder must turn RED")
	_expect(_has_violation(validation, "road_corridor_blocked"), "shoulder-only counterproof must prove full edge half-width clearance, not centreline-only clearance")


func _verify_canonical_road_width_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var road := _as_dictionary(corrupted.get("road_graph", {}))
	var edges_value: Variant = road.get("edges", [])
	if edges_value is Array:
		for index in range((edges_value as Array).size()):
			var edge := ((edges_value as Array)[index] as Dictionary).duplicate(true)
			edge["half_width_world"] = 0.1
			(edges_value as Array)[index] = edge
		road["edges"] = edges_value
		corrupted["road_graph"] = road
		corrupted["walkable_corridor_polygons"] = _derive_walkable_corridors_for_qa(road)
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "self-consistently shrinking road edges and their walkable polygons must still turn RED")
	_expect(_has_violation(validation, "road_half_width_contract_mismatch"), "canonical-width counterproof must not accept a tautological edge/corridor shrink")


func _verify_road_plot_boundary_counterproof(layout: Dictionary) -> void:
	for edge_kind in ["secondary", "approach"]:
		var corrupted := layout.duplicate(true)
		var road := _as_dictionary(corrupted.get("road_graph", {}))
		var target_edge: Dictionary = {}
		for edge in _dictionary_array(road.get("edges", [])):
			if str(edge.get("kind", "")) == edge_kind and _vector2_array(edge.get("polyline_world", [])).size() >= 2:
				target_edge = edge
				break
		var plots_value: Variant = corrupted.get("plots", [])
		if not target_edge.is_empty() and plots_value is Array:
			var polyline := _vector2_array(target_edge.get("polyline_world", []))
			var corridor := _square_cap_corridor(polyline[0], polyline[1], float(target_edge.get("half_width_world", 0.0)))
			for index in range((plots_value as Array).size()):
				var plot := ((plots_value as Array)[index] as Dictionary).duplicate(true)
				if edge_kind != "secondary" and str(plot.get("id", "")) == str(target_edge.get("plot_id", "")):
					continue
				plot["boundary_polygon_world"] = corridor
				(plots_value as Array)[index] = plot
				break
			corrupted["plots"] = plots_value
		var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
		_expect(not bool(validation.get("valid", true)), "%s square-cap corridor over a foreign semantic parcel must turn RED" % edge_kind)
		_expect(_has_violation(validation, "road_plot_boundary_overlap"), "%s parcel counterproof must report road_plot_boundary_overlap" % edge_kind)


func _verify_blocked_manifest_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var blockers_value: Variant = corrupted.get("blocked_polygons", [])
	if blockers_value is Array and not (blockers_value as Array).is_empty():
		(blockers_value as Array).remove_at(0)
		corrupted["blocked_polygons"] = blockers_value
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "dropping a derived navigation blocker must turn the validator RED")
	_expect(_has_violation(validation, "blocked_polygon_manifest_mismatch"), "blocked-manifest counterproof must report blocked_polygon_manifest_mismatch")


func _verify_selected_contract_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	corrupted["selected_building_types"] = ["shop", "bank"]
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "reordering the caller-owned selected type contract must turn the validator RED")
	_expect(_has_violation(validation, "selected_building_contract_mismatch"), "selected-type counterproof must report selected_building_contract_mismatch")


func _verify_selected_roster_corpus(_seed5_specs: Array[Dictionary]) -> void:
	var full_specs := PlazaAssetLoader.build_hwangyeok_building_specs(1, 5, true, false)
	_expect(full_specs.size() == 7, "loader-owned full-layout fixture must expose all seven known manifests")
	if full_specs.size() != 7:
		return
	var bank_spec := _find_dictionary_by_field(full_specs, "type", "bank")
	var optional_specs: Array[Dictionary] = []
	for spec in full_specs:
		if str(spec.get("type", "")) != "bank":
			optional_specs.append(spec)
	_expect(not bank_spec.is_empty() and optional_specs.size() == 6, "roster corpus fixture must identify one bank plus six optional buildings by type, never by manifest index")
	if bank_spec.is_empty() or optional_specs.size() != 6:
		return
	var corpus_count := 0
	var maximum_visual_end_x := 0.0
	var maximum_label_end_x := 0.0
	# Bank is mandatory. Exhaust every subset of one through four optional
	# buildings for all three seeded structural motifs: 56 * 3 = 168 layouts.
	for map_seed in [5, 6, 7]:
		for mask in range(1, 1 << 6):
			var optional_count := 0
			for optional_index in range(6):
				if (mask & (1 << optional_index)) != 0:
					optional_count += 1
			if optional_count < 1 or optional_count > 4:
				continue
			var roster: Array[Dictionary] = [bank_spec.duplicate(true)]
			for optional_index in range(6):
				if (mask & (1 << optional_index)) != 0:
					roster.append(optional_specs[optional_index].duplicate(true))
			var selected_types := _building_types(roster)
			var label := "seed=%d roster=%s" % [map_seed, selected_types]
			var candidate := PlazaMapLayoutGenerator.generate(1, map_seed, WORLD_SIZE, roster, SPAWN_ANCHOR, EXIT_ZONE)
			var validation := _as_dictionary(candidate.get("validation", {}))
			_expect(bool(validation.get("valid", false)), "%s must pass geometry/collision/road validation: %s" % [label, validation.get("violations", [])])
			_expect(_building_types(_dictionary_array(candidate.get("building_specs", []))) == selected_types, "%s must preserve exact caller order/count" % label)
			_expect(selected_types.count("bank") == 1, "%s must contain bank exactly once" % label)
			var seen := {}
			for building_type in selected_types:
				_expect(PlazaMapLayoutGenerator.KNOWN_BUILDING_TYPES.has(building_type), "%s contains unknown type %s" % [label, building_type])
				_expect(not seen.has(building_type), "%s contains duplicate type %s" % [label, building_type])
				seen[building_type] = true
			var candidate_buildings := _dictionary_array(candidate.get("building_specs", []))
			_verify_plot_class_slot_contract(_dictionary_array(candidate.get("plots", [])))
			_verify_authored_geometry_transform(candidate_buildings)
			_verify_decor_authored_geometry(_dictionary_array(candidate.get("decor_clusters", [])))
			for building in candidate_buildings:
				var visual: Rect2 = building.get("visual_rect", Rect2())
				var label_rect: Rect2 = building.get("label_rect_world", Rect2())
				maximum_visual_end_x = maxf(maximum_visual_end_x, visual.end.x)
				maximum_label_end_x = maxf(maximum_label_end_x, label_rect.end.x)
				_expect(visual.position.x >= -0.01 and visual.position.y >= -0.01 and visual.end.x <= WORLD_SIZE.x + 0.01 and visual.end.y <= WORLD_SIZE.y + 0.01, "%s building visual must remain inside the fixed world" % label)
				_expect(label_rect.position.x >= -0.01 and label_rect.position.y >= -0.01 and label_rect.end.x <= WORLD_SIZE.x + 0.01 and label_rect.end.y <= WORLD_SIZE.y + 0.01, "%s right-growing label must remain inside the fixed world" % label)
				if str(building.get("plot_class", "")) == "edge_large":
					_expect(int(building.get("route_slot_index", -1)) == 6, "%s edge_large building must stay in slot 6" % label)
			corpus_count += 1
	_expect(corpus_count == 168, "roster corpus must cover all 56 legal subsets across all three structural motifs")
	print("plaza_r2_map_layout_seed5_qa: corpus=168 max_visual_end_x=%.3f max_label_end_x=%.3f world_right=%.3f" % [maximum_visual_end_x, maximum_label_end_x, WORLD_SIZE.x])
	for rejected_count in [6, 7]:
		var rejected_roster: Array[Dictionary] = [bank_spec.duplicate(true)]
		for index in range(mini(rejected_count - 1, optional_specs.size())):
			rejected_roster.append(optional_specs[index].duplicate(true))
		var rejected := PlazaMapLayoutGenerator.generate(1, 5, WORLD_SIZE, rejected_roster, SPAWN_ANCHOR, EXIT_ZONE)
		var rejected_validation := _as_dictionary(rejected.get("validation", {}))
		_expect(not bool(rejected_validation.get("valid", true)), "%d-building implicit roster must be rejected by the public production generator" % rejected_count)
		_expect(_has_violation(rejected_validation, "selected_building_roster_invalid"), "%d-building rejection must name selected_building_roster_invalid" % rejected_count)

	for invalid_types in [
		["bank", "bank"],
		["shop", "gacha"],
		["bank", "unknown_hall"],
	]:
		var base_roster: Array[Dictionary] = [bank_spec.duplicate(true), optional_specs[0].duplicate(true)]
		var corrupted_layout := PlazaMapLayoutGenerator.generate(1, 5, WORLD_SIZE, base_roster, SPAWN_ANCHOR, EXIT_ZONE)
		corrupted_layout["selected_building_types"] = invalid_types
		var invalid_validation := PlazaMapLayoutGenerator.validate_layout(corrupted_layout)
		_expect(not bool(invalid_validation.get("valid", true)), "duplicate, missing-bank, and unknown rosters must each turn RED")
		_expect(_has_violation(invalid_validation, "selected_building_roster_invalid"), "invalid roster must report selected_building_roster_invalid: %s" % [invalid_types])


func _verify_consumed_type_counterproofs(layout: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	for bad_schema in ["1", 1.0, {}, NAN]:
		var corrupted := layout.duplicate(true)
		corrupted["schema_version"] = bad_schema
		cases.append({"label": "schema_version=%s" % [bad_schema], "layout": corrupted})

	var selected_non_string := layout.duplicate(true)
	var selected_value: Variant = selected_non_string.get("selected_building_types", [])
	if selected_value is Array and not (selected_value as Array).is_empty():
		var untyped_selected: Array = []
		for selected_item in selected_value as Array:
			untyped_selected.append(selected_item)
		untyped_selected[0] = {"not": "a string"}
		selected_non_string["selected_building_types"] = untyped_selected
	cases.append({"label": "selected_non_string", "layout": selected_non_string})

	var top_scalar_dictionary := layout.duplicate(true)
	top_scalar_dictionary["main_route_length_world"] = {"bad": 1}
	cases.append({"label": "top_scalar_dictionary", "layout": top_scalar_dictionary})

	for bad_half_width in [{"bad": 1}, NAN]:
		var bad_road := layout.duplicate(true)
		var road := _as_dictionary(bad_road.get("road_graph", {}))
		var edges_value: Variant = road.get("edges", [])
		if edges_value is Array and not (edges_value as Array).is_empty():
			var edge := ((edges_value as Array)[0] as Dictionary).duplicate(true)
			edge["half_width_world"] = bad_half_width
			(edges_value as Array)[0] = edge
			road["edges"] = edges_value
			bad_road["road_graph"] = road
		cases.append({"label": "edge_half_width=%s" % [bad_half_width], "layout": bad_road})

	var bad_plot_scalar := layout.duplicate(true)
	var bad_plots_value: Variant = bad_plot_scalar.get("plots", [])
	if bad_plots_value is Array and not (bad_plots_value as Array).is_empty():
		var bad_plot := ((bad_plots_value as Array)[0] as Dictionary).duplicate(true)
		bad_plot["main_route_distance_world"] = {"bad": 1}
		(bad_plots_value as Array)[0] = bad_plot
		bad_plot_scalar["plots"] = bad_plots_value
	cases.append({"label": "plot_scalar_dictionary", "layout": bad_plot_scalar})

	for building_corruption in ["pivot_wrong_type", "rect_wrong_type", "polygon_wrong_type"]:
		var bad_building_layout := layout.duplicate(true)
		var buildings_value: Variant = bad_building_layout.get("building_specs", [])
		if buildings_value is Array and not (buildings_value as Array).is_empty():
			var bad_building := ((buildings_value as Array)[0] as Dictionary).duplicate(true)
			match building_corruption:
				"pivot_wrong_type":
					bad_building["pivot_pos"] = {"bad": 1}
				"rect_wrong_type":
					bad_building["visual_rect"] = Vector2.ZERO
				"polygon_wrong_type":
					bad_building["footprint_world_polygon"] = ["bad"]
			(buildings_value as Array)[0] = bad_building
			bad_building_layout["building_specs"] = buildings_value
		cases.append({"label": building_corruption, "layout": bad_building_layout})

	for case in cases:
		var validation := PlazaMapLayoutGenerator.validate_layout(_as_dictionary(case.get("layout", {})))
		_expect(not bool(validation.get("valid", true)), "%s must fail closed without coercion" % str(case.get("label", "case")))
		_expect(_has_violation(validation, "consumed_field_invalid"), "%s must report consumed_field_invalid" % str(case.get("label", "case")))


func _verify_label_anchor_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var buildings_value: Variant = corrupted.get("building_specs", [])
	if buildings_value is Array and not (buildings_value as Array).is_empty():
		var building := ((buildings_value as Array)[0] as Dictionary).duplicate(true)
		var rect: Rect2 = building.get("label_rect_world", Rect2())
		rect.position.x += 1.0
		building["label_rect_world"] = rect
		(buildings_value as Array)[0] = building
		corrupted["building_specs"] = buildings_value
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "moving a label rect one pixel away from its authored stem formula must turn RED")
	_expect(_has_violation(validation, "label_rect_anchor_contract_mismatch"), "label formula counterproof must report label_rect_anchor_contract_mismatch")


func _verify_reverse_label_collision_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var buildings_value: Variant = corrupted.get("building_specs", [])
	if buildings_value is Array and (buildings_value as Array).size() >= 2:
		var earlier := (buildings_value as Array)[0] as Dictionary
		var later := ((buildings_value as Array)[1] as Dictionary).duplicate(true)
		var target_visual: Rect2 = earlier.get("visual_rect", Rect2())
		var label_rect: Rect2 = later.get("label_rect_world", Rect2())
		label_rect.position = target_visual.get_center() - label_rect.size * 0.5
		later["label_rect_world"] = label_rect
		later["label_world_pos"] = label_rect.position - Vector2(PlazaMapLayoutGenerator.LABEL_STEM_GAP_WORLD, -label_rect.size.y * 0.5)
		(buildings_value as Array)[1] = later
		corrupted["building_specs"] = buildings_value
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "later building label over earlier building visual must turn RED")
	_expect(_has_violation(validation, "label_rect_visual_overlap"), "reverse-order label collision must report label_rect_visual_overlap")


func _verify_decor_label_collision_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var buildings_value: Variant = corrupted.get("building_specs", [])
	var decor := _dictionary_array(corrupted.get("decor_clusters", []))[0] if not _dictionary_array(corrupted.get("decor_clusters", [])).is_empty() else {}
	if buildings_value is Array and not (buildings_value as Array).is_empty() and not decor.is_empty():
		var building := ((buildings_value as Array)[0] as Dictionary).duplicate(true)
		var target_visual: Rect2 = decor.get("visual_bounds_world", Rect2())
		var label_rect: Rect2 = building.get("label_rect_world", Rect2())
		label_rect.position = target_visual.get_center() - label_rect.size * 0.5
		building["label_rect_world"] = label_rect
		building["label_world_pos"] = label_rect.position - Vector2(PlazaMapLayoutGenerator.LABEL_STEM_GAP_WORLD, -label_rect.size.y * 0.5)
		(buildings_value as Array)[0] = building
		corrupted["building_specs"] = buildings_value
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "building label over decor must turn RED")
	_expect(_has_violation(validation, "label_rect_decor_visual_overlap") or _has_violation(validation, "label_rect_decor_footprint_overlap"), "decor label collision must report a decor-specific label violation")


func _verify_walkable_manifest_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var corridors_value: Variant = corrupted.get("walkable_corridor_polygons", [])
	if corridors_value is Array and not (corridors_value as Array).is_empty():
		var corridor := ((corridors_value as Array)[0] as Dictionary).duplicate(true)
		var polygon := _vector2_array(corridor.get("polygon_world", []))
		if not polygon.is_empty():
			polygon[0] += Vector2(1.0, 0.0)
			corridor["polygon_world"] = polygon
		(corridors_value as Array)[0] = corridor
		corrupted["walkable_corridor_polygons"] = corridors_value
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "changing an edge-derived square-cap corridor must turn RED")
	_expect(_has_violation(validation, "walkable_corridor_manifest_mismatch"), "walkable counterproof must report walkable_corridor_manifest_mismatch")


func _verify_route_scalar_counterproof(layout: Dictionary, expected_max_gap: float) -> void:
	var corrupted := layout.duplicate(true)
	corrupted["main_route_length_world"] = float(corrupted.get("main_route_length_world", 0.0)) + 100.0
	var road := _as_dictionary(corrupted.get("road_graph", {}))
	road["main_route_length_world"] = float(road.get("main_route_length_world", 0.0)) + 100.0
	corrupted["road_graph"] = road
	for collection_key in ["plots", "building_specs", "decor_clusters"]:
		var collection_value: Variant = corrupted.get(collection_key, [])
		if not (collection_value is Array):
			continue
		for index in range((collection_value as Array).size()):
			var item_value: Variant = (collection_value as Array)[index]
			if not (item_value is Dictionary):
				continue
			var item := (item_value as Dictionary).duplicate(true)
			item["main_route_distance_world"] = float(item.get("main_route_distance_world", 0.0)) + 100.0
			(collection_value as Array)[index] = item
		corrupted[collection_key] = collection_value
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "self-consistent fake route scalars must not override measured road geometry")
	_expect(_has_violation(validation, "main_route_length_mismatch"), "route-scalar counterproof must report main_route_length_mismatch")
	_expect(_has_violation(validation, "route_distance_mismatch"), "route-scalar counterproof must report route_distance_mismatch")
	var metrics := _as_dictionary(validation.get("metrics", {}))
	_expect(is_equal_approx(float(metrics.get("max_landmark_gap_world", INF)), expected_max_gap), "landmark max-gap metric must remain derived from polyline geometry when stored scalars are corrupted")


func _verify_edge_endpoint_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var road := _as_dictionary(corrupted.get("road_graph", {}))
	var edges_value: Variant = road.get("edges", [])
	if edges_value is Array and not (edges_value as Array).is_empty():
		var edge := ((edges_value as Array)[0] as Dictionary).duplicate(true)
		var polyline := _vector2_array(edge.get("polyline_world", []))
		if polyline.size() >= 2:
			polyline[0] += Vector2(25.0, 0.0)
			edge["polyline_world"] = polyline
			(edges_value as Array)[0] = edge
			road["edges"] = edges_value
			corrupted["road_graph"] = road
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "detaching an edge polyline from its named node must turn the validator RED")
	_expect(_has_violation(validation, "road_edge_endpoint_mismatch"), "edge-endpoint counterproof must report road_edge_endpoint_mismatch")


func _verify_main_route_extra_edge_counterproof(layout: Dictionary) -> void:
	var road := _as_dictionary(layout.get("road_graph", {}))
	var nodes := _dictionary_array(road.get("nodes", []))
	var spawn := _find_dictionary_by_field(nodes, "id", "spawn")
	var main_2 := _find_dictionary_by_field(nodes, "id", "main_2")
	var spawn_position: Vector2 = spawn.get("position", Vector2.ZERO)
	var main_2_position: Vector2 = main_2.get("position", Vector2.ZERO)

	var self_loop := layout.duplicate(true)
	var self_road := _as_dictionary(self_loop.get("road_graph", {}))
	var self_edges_value: Variant = self_road.get("edges", [])
	if self_edges_value is Array:
		(self_edges_value as Array).append({
			"id": "main_spawn_self_counterproof",
			"kind": "main",
			"from": "spawn",
			"to": "spawn",
			"half_width_world": PlazaMapLayoutGenerator.ROAD_HALF_WIDTH_BY_KIND["main"],
			"polyline_world": [spawn_position, spawn_position],
		})
		self_road["edges"] = self_edges_value
		self_loop["road_graph"] = self_road
		self_loop["walkable_corridor_polygons"] = _derive_walkable_corridors_for_qa(self_road)
	var self_validation := PlazaMapLayoutGenerator.validate_layout(self_loop)
	_expect(not bool(self_validation.get("valid", true)), "an extra canonical-width main self-loop must turn RED even when walkable geometry is synchronized")
	_expect(_has_violation(self_validation, "main_route_topology_mismatch"), "main self-loop must report main_route_topology_mismatch")
	_expect(_has_violation(self_validation, "road_edge_segment_degenerate"), "zero-length self-loop must report road_edge_segment_degenerate")
	_expect(_has_violation(self_validation, "walkable_corridor_invalid"), "zero-area derived corridor must report walkable_corridor_invalid")

	var chord := layout.duplicate(true)
	var chord_road := _as_dictionary(chord.get("road_graph", {}))
	var chord_edges_value: Variant = chord_road.get("edges", [])
	if chord_edges_value is Array:
		(chord_edges_value as Array).append({
			"id": "main_spawn_to_main_2_counterproof",
			"kind": "main",
			"from": "spawn",
			"to": "main_2",
			"half_width_world": PlazaMapLayoutGenerator.ROAD_HALF_WIDTH_BY_KIND["main"],
			"polyline_world": [spawn_position, main_2_position],
		})
		chord_road["edges"] = chord_edges_value
		chord["road_graph"] = chord_road
		chord["walkable_corridor_polygons"] = _derive_walkable_corridors_for_qa(chord_road)
	var chord_validation := PlazaMapLayoutGenerator.validate_layout(chord)
	_expect(not bool(chord_validation.get("valid", true)), "an extra nondegenerate main chord must turn RED even when cycle rank and walkable geometry remain valid")
	_expect(_has_violation(chord_validation, "main_route_topology_mismatch"), "extra main chord must report main_route_topology_mismatch")


func _verify_orphan_road_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var road := _as_dictionary(corrupted.get("road_graph", {}))
	var nodes_value: Variant = road.get("nodes", [])
	var edges_value: Variant = road.get("edges", [])
	var orphan_start := Vector2(260.0, 44.0)
	var orphan_finish := Vector2(420.0, 44.0)
	if nodes_value is Array and edges_value is Array:
		(nodes_value as Array).append({
			"id": "trail_orphan_start_counterproof",
			"role": "decor_trail_end",
			"plot_id": "orphan_plot_counterproof",
			"position": orphan_start,
		})
		(nodes_value as Array).append({
			"id": "trail_orphan_finish_counterproof",
			"role": "decor_trail_end",
			"plot_id": "orphan_plot_counterproof",
			"position": orphan_finish,
		})
		(edges_value as Array).append({
			"id": "trail_orphan_counterproof",
			"kind": "trail",
			"from": "trail_orphan_start_counterproof",
			"to": "trail_orphan_finish_counterproof",
			"plot_id": "orphan_plot_counterproof",
			"half_width_world": PlazaMapLayoutGenerator.ROAD_HALF_WIDTH_BY_KIND["trail"],
			"polyline_world": [orphan_start, orphan_finish],
		})
		road["nodes"] = nodes_value
		road["edges"] = edges_value
		corrupted["road_graph"] = road
		corrupted["walkable_corridor_polygons"] = _derive_walkable_corridors_for_qa(road)
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "a nondegenerate orphan trail with synchronized walkable geometry must turn RED")
	_expect(_has_violation(validation, "road_topology_mismatch"), "orphan-trail counterproof must report road_topology_mismatch")
	_expect(not _has_violation(validation, "road_edge_segment_degenerate"), "orphan-trail counterproof must remain nondegenerate")
	_expect(not _has_violation(validation, "walkable_corridor_invalid"), "orphan-trail counterproof must carry a positive-area synchronized corridor")


func _verify_collapsed_footprint_counterproof(layout: Dictionary) -> void:
	var collapsed_building := layout.duplicate(true)
	var building_values: Variant = collapsed_building.get("building_specs", [])
	if building_values is Array and not (building_values as Array).is_empty():
		var building := ((building_values as Array)[0] as Dictionary).duplicate(true)
		var building_type := str(building.get("type", ""))
		var pivot: Vector2 = building.get("pivot_pos", Vector2.ZERO)
		var collapsed_source: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
		var collapsed_world: Array[Vector2] = [pivot, pivot, pivot, pivot]
		building["footprint_polygon"] = collapsed_source
		building["footprint_world_polygon"] = collapsed_world
		(building_values as Array)[0] = building
		collapsed_building["building_specs"] = building_values
		_replace_blocked_polygon(collapsed_building, "building", building_type, collapsed_world)
	var building_validation := PlazaMapLayoutGenerator.validate_layout(collapsed_building)
	_expect(not bool(building_validation.get("valid", true)), "synchronously collapsing authored, world, and blocked building footprints must turn RED")
	_expect(_has_violation(building_validation, "building_footprint_area_invalid"), "collapsed building must report building_footprint_area_invalid")
	_expect(_has_violation(building_validation, "blocked_polygon_area_invalid"), "collapsed building blocker must report blocked_polygon_area_invalid")
	_expect(not _has_violation(building_validation, "building_authored_transform_mismatch"), "collapsed building fixture must remain transform-consistent so area is the deciding gate")

	var collapsed_decor := layout.duplicate(true)
	var decor_values: Variant = collapsed_decor.get("decor_clusters", [])
	if decor_values is Array and not (decor_values as Array).is_empty():
		var decor := ((decor_values as Array)[0] as Dictionary).duplicate(true)
		var decor_id := str(decor.get("id", ""))
		var anchor: Vector2 = decor.get("anchor_world", Vector2.ZERO)
		var collapsed_world: Array[Vector2] = [anchor, anchor, anchor, anchor]
		decor["footprint_world_polygon"] = collapsed_world
		(decor_values as Array)[0] = decor
		collapsed_decor["decor_clusters"] = decor_values
		_replace_blocked_polygon(collapsed_decor, "decor", decor_id, collapsed_world)
	var decor_validation := PlazaMapLayoutGenerator.validate_layout(collapsed_decor)
	_expect(not bool(decor_validation.get("valid", true)), "synchronously collapsing decor and blocked footprints must turn RED")
	_expect(_has_violation(decor_validation, "decor_footprint_area_invalid"), "collapsed decor must report decor_footprint_area_invalid")
	_expect(_has_violation(decor_validation, "blocked_polygon_area_invalid"), "collapsed decor blocker must report blocked_polygon_area_invalid")

	var tiny_building := layout.duplicate(true)
	building_values = tiny_building.get("building_specs", [])
	if building_values is Array and not (building_values as Array).is_empty():
		var building := ((building_values as Array)[0] as Dictionary).duplicate(true)
		var building_type := str(building.get("type", ""))
		var pivot: Vector2 = building.get("pivot_pos", Vector2.ZERO)
		var scale := float(building.get("display_scale", 0.0))
		var tiny_source: Array[Vector2] = [Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0)]
		var tiny_world: Array[Vector2] = []
		for point in tiny_source:
			tiny_world.append(pivot + point * scale)
		building["footprint_polygon"] = tiny_source
		building["footprint_world_polygon"] = tiny_world
		(building_values as Array)[0] = building
		tiny_building["building_specs"] = building_values
		_replace_blocked_polygon(tiny_building, "building", building_type, tiny_world)
	var tiny_building_validation := PlazaMapLayoutGenerator.validate_layout(tiny_building)
	_expect(not bool(tiny_building_validation.get("valid", true)), "a synchronized nondegenerate but microscopic building footprint must turn RED")
	_expect(_has_violation(tiny_building_validation, "building_footprint_area_invalid"), "tiny building must report building_footprint_area_invalid")
	_expect(_has_violation(tiny_building_validation, "blocked_polygon_area_invalid"), "tiny building blocker must report blocked_polygon_area_invalid")
	_expect(not _has_violation(tiny_building_validation, "building_authored_transform_mismatch"), "tiny building fixture must remain authored-transform consistent")

	var tiny_decor := layout.duplicate(true)
	decor_values = tiny_decor.get("decor_clusters", [])
	if decor_values is Array and not (decor_values as Array).is_empty():
		var decor := ((decor_values as Array)[0] as Dictionary).duplicate(true)
		var decor_id := str(decor.get("id", ""))
		var anchor: Vector2 = decor.get("anchor_world", Vector2.ZERO)
		var tiny_world: Array[Vector2] = [anchor + Vector2(0.0, -0.25), anchor + Vector2(0.25, 0.0), anchor + Vector2(0.0, 0.25), anchor + Vector2(-0.25, 0.0)]
		decor["footprint_world_polygon"] = tiny_world
		(decor_values as Array)[0] = decor
		tiny_decor["decor_clusters"] = decor_values
		_replace_blocked_polygon(tiny_decor, "decor", decor_id, tiny_world)
	var tiny_decor_validation := PlazaMapLayoutGenerator.validate_layout(tiny_decor)
	_expect(not bool(tiny_decor_validation.get("valid", true)), "a synchronized nondegenerate but microscopic decor footprint must turn RED")
	_expect(_has_violation(tiny_decor_validation, "decor_footprint_area_invalid"), "tiny decor must report decor_footprint_area_invalid")
	_expect(_has_violation(tiny_decor_validation, "decor_authored_transform_mismatch"), "tiny decor must report decor_authored_transform_mismatch")
	_expect(_has_violation(tiny_decor_validation, "blocked_polygon_area_invalid"), "tiny decor blocker must report blocked_polygon_area_invalid")


func _verify_authored_closure_counterproof(layout: Dictionary) -> void:
	var building_cases: Array[Dictionary] = []

	var label_source := layout.duplicate(true)
	var buildings_value: Variant = label_source.get("building_specs", [])
	if buildings_value is Array and not (buildings_value as Array).is_empty():
		var building := ((buildings_value as Array)[0] as Dictionary).duplicate(true)
		var delta := Vector2(1.0, 0.0)
		building["label_anchor"] = (building.get("label_anchor", Vector2.ZERO) as Vector2) + delta
		building["label_world_pos"] = (building.get("label_world_pos", Vector2.ZERO) as Vector2) + delta * float(building.get("display_scale", 0.0))
		var label_rect: Rect2 = building.get("label_rect_world", Rect2())
		label_rect.position += delta * float(building.get("display_scale", 0.0))
		building["label_rect_world"] = label_rect
		(buildings_value as Array)[0] = building
		label_source["building_specs"] = buildings_value
	building_cases.append({"label": "label_source", "layout": label_source})

	var sort_anchor := layout.duplicate(true)
	buildings_value = sort_anchor.get("building_specs", [])
	if buildings_value is Array and not (buildings_value as Array).is_empty():
		var building := ((buildings_value as Array)[0] as Dictionary).duplicate(true)
		building["sort_anchor_world"] = (building.get("sort_anchor_world", Vector2.ZERO) as Vector2) + Vector2(1.0, 0.0)
		(buildings_value as Array)[0] = building
		sort_anchor["building_specs"] = buildings_value
	building_cases.append({"label": "sort_anchor", "layout": sort_anchor})

	var interaction_rect := layout.duplicate(true)
	buildings_value = interaction_rect.get("building_specs", [])
	if buildings_value is Array and not (buildings_value as Array).is_empty():
		var building := ((buildings_value as Array)[0] as Dictionary).duplicate(true)
		var rect: Rect2 = building.get("interaction_rect", Rect2())
		rect.position += Vector2(1.0, 0.0)
		building["interaction_rect"] = rect
		(buildings_value as Array)[0] = building
		interaction_rect["building_specs"] = buildings_value
	building_cases.append({"label": "interaction_rect", "layout": interaction_rect})

	var entrance_normal := layout.duplicate(true)
	buildings_value = entrance_normal.get("building_specs", [])
	if buildings_value is Array and not (buildings_value as Array).is_empty():
		var building := ((buildings_value as Array)[0] as Dictionary).duplicate(true)
		building["entrance_normal"] = Vector2(-0.75, 0.5)
		(buildings_value as Array)[0] = building
		entrance_normal["building_specs"] = buildings_value
	building_cases.append({"label": "entrance_normal", "layout": entrance_normal})

	var clearance_source := layout.duplicate(true)
	buildings_value = clearance_source.get("building_specs", [])
	if buildings_value is Array and not (buildings_value as Array).is_empty():
		var building := ((buildings_value as Array)[0] as Dictionary).duplicate(true)
		var clearance_value: Variant = building.get("road_side_clearance", {})
		var clearance: Dictionary = (clearance_value as Dictionary).duplicate(true) if clearance_value is Dictionary else {}
		clearance["cross_width"] = float(clearance.get("cross_width", 0.0)) + 1.0
		building["road_side_clearance"] = clearance
		(buildings_value as Array)[0] = building
		clearance_source["building_specs"] = buildings_value
	building_cases.append({"label": "clearance_source", "layout": clearance_source})

	for case in building_cases:
		var validation := PlazaMapLayoutGenerator.validate_layout(_as_dictionary(case.get("layout", {})))
		_expect(not bool(validation.get("valid", true)), "%s authored building derivation mutation must turn RED" % str(case.get("label", "building")))
		_expect(_has_violation(validation, "building_authored_transform_mismatch"), "%s mutation must report building_authored_transform_mismatch" % str(case.get("label", "building")))

	for field_name in ["sort_anchor_world", "visual_bounds_world"]:
		var corrupted := layout.duplicate(true)
		var decor_values: Variant = corrupted.get("decor_clusters", [])
		if decor_values is Array and not (decor_values as Array).is_empty():
			var decor := ((decor_values as Array)[0] as Dictionary).duplicate(true)
			if field_name == "sort_anchor_world":
				decor[field_name] = (decor.get(field_name, Vector2.ZERO) as Vector2) + Vector2(1.0, 0.0)
			else:
				var visual: Rect2 = decor.get(field_name, Rect2())
				visual.position += Vector2(1.0, 0.0)
				decor[field_name] = visual
			(decor_values as Array)[0] = decor
			corrupted["decor_clusters"] = decor_values
		var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
		_expect(not bool(validation.get("valid", true)), "decor %s derivation mutation must turn RED" % field_name)
		_expect(_has_violation(validation, "decor_authored_transform_mismatch"), "decor %s mutation must report decor_authored_transform_mismatch" % field_name)


func _verify_non_finite_geometry_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var buildings_value: Variant = corrupted.get("building_specs", [])
	if buildings_value is Array and not (buildings_value as Array).is_empty():
		var building := ((buildings_value as Array)[0] as Dictionary).duplicate(true)
		var polygon := _vector2_array(building.get("footprint_world_polygon", []))
		if not polygon.is_empty():
			polygon[0] = Vector2(NAN, polygon[0].y)
			building["footprint_world_polygon"] = polygon
			(buildings_value as Array)[0] = building
			corrupted["building_specs"] = buildings_value
			_replace_blocked_polygon(corrupted, "building", str(building.get("type", "")), polygon)
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "NaN inside an authored blocker must turn the validator RED without reaching polygon SAT")
	_expect(_has_violation(validation, "non_finite_geometry"), "non-finite counterproof must report non_finite_geometry")


func _verify_vertical_flatten_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var plots_value: Variant = corrupted.get("plots", [])
	if plots_value is Array:
		for index in range((plots_value as Array).size()):
			var plot := ((plots_value as Array)[index] as Dictionary).duplicate(true)
			var pivot: Vector2 = plot.get("pivot_pos", Vector2.ZERO)
			pivot.y = WORLD_SIZE.y * 0.5
			plot["pivot_pos"] = pivot
			(plots_value as Array)[index] = plot
		corrupted["plots"] = plots_value
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "flattening every plot pivot into one horizontal strip must turn the validator RED")
	_expect(_has_violation(validation, "map_vertical_distribution_compressed"), "flatten counterproof must report map_vertical_distribution_compressed")


func _verify_secondary_cycle_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var road := _as_dictionary(corrupted.get("road_graph", {}))
	var edges_value: Variant = road.get("edges", [])
	if edges_value is Array:
		for index in range((edges_value as Array).size() - 1, -1, -1):
			var edge_value: Variant = (edges_value as Array)[index]
			if edge_value is Dictionary and str((edge_value as Dictionary).get("id", "")) == "secondary_hub_span":
				(edges_value as Array).remove_at(index)
				break
		road["edges"] = edges_value
		corrupted["road_graph"] = road
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "removing the secondary hub span must destroy cycle rank and turn the validator RED")
	_expect(_has_violation(validation, "secondary_cycle_missing"), "secondary-cycle counterproof must report secondary_cycle_missing")


func _verify_exact_secondary_topology_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var road := _as_dictionary(corrupted.get("road_graph", {}))
	var edges_value: Variant = road.get("edges", [])
	if edges_value is Array:
		for index in range((edges_value as Array).size()):
			var edge_value: Variant = (edges_value as Array)[index]
			if not (edge_value is Dictionary) or str((edge_value as Dictionary).get("id", "")) != "secondary_hub_span":
				continue
			var edge := (edge_value as Dictionary).duplicate(true)
			var original_from := str(edge.get("from", ""))
			edge["from"] = str(edge.get("to", ""))
			edge["to"] = original_from
			var polyline := _vector2_array(edge.get("polyline_world", []))
			polyline.reverse()
			edge["polyline_world"] = polyline
			(edges_value as Array)[index] = edge
			break
		road["edges"] = edges_value
		corrupted["road_graph"] = road
		corrupted["walkable_corridor_polygons"] = _derive_walkable_corridors_for_qa(road)
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "preserving cycle rank while reversing the canonical secondary span must turn RED")
	_expect(_has_violation(validation, "secondary_cycle_contract_mismatch"), "exact-topology counterproof must report secondary_cycle_contract_mismatch")


func _verify_trail_disconnect_counterproof(layout: Dictionary) -> void:
	var corrupted := layout.duplicate(true)
	var road := _as_dictionary(corrupted.get("road_graph", {}))
	var edges_value: Variant = road.get("edges", [])
	if edges_value is Array:
		for index in range((edges_value as Array).size() - 1, -1, -1):
			var edge_value: Variant = (edges_value as Array)[index]
			if edge_value is Dictionary and str((edge_value as Dictionary).get("kind", "")) == "trail":
				(edges_value as Array).remove_at(index)
				break
		road["edges"] = edges_value
		corrupted["road_graph"] = road
	var validation := PlazaMapLayoutGenerator.validate_layout(corrupted)
	_expect(not bool(validation.get("valid", true)), "removing an unused-plot trail must disconnect that visible branch and turn RED")
	_expect(_has_violation(validation, "plot_trail_disconnected"), "trail counterproof must report plot_trail_disconnected")


func _derive_walkable_corridors_for_qa(road: Dictionary) -> Array[Dictionary]:
	var corridors: Array[Dictionary] = []
	for edge in _dictionary_array(road.get("edges", [])):
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
				"cap_style": PlazaMapLayoutGenerator.WALKABLE_CAP_STYLE,
				"polygon_world": _square_cap_corridor(start, finish, half_width),
			})
	return corridors


func _square_cap_corridor(start: Vector2, finish: Vector2, half_width: float) -> Array[Vector2]:
	var delta := finish - start
	if delta.length_squared() <= 0.0001:
		return []
	var tangent := delta.normalized()
	var normal := Vector2(-tangent.y, tangent.x) * half_width
	var capped_start := start - tangent * half_width
	var capped_finish := finish + tangent * half_width
	return [capped_start + normal, capped_finish + normal, capped_finish - normal, capped_start - normal]


func _oriented_approach_polygon_for_qa(entrance: Vector2, normal: Vector2, cross_width: float, depth: float) -> Array[Vector2]:
	if normal.length_squared() <= 0.0001:
		return []
	var safe_normal := normal.normalized()
	var tangent := Vector2(-safe_normal.y, safe_normal.x)
	var half_width := cross_width * 0.5
	var far_center := entrance + safe_normal * depth
	return [entrance - tangent * half_width, entrance + tangent * half_width, far_center + tangent * half_width, far_center - tangent * half_width]


func _polygon_aabb_for_qa(points: Array[Vector2]) -> Rect2:
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


func _decor_footprint_for_qa(anchor: Vector2) -> Array[Vector2]:
	return [anchor + Vector2(0.0, -54.0), anchor + Vector2(72.0, -18.0), anchor + Vector2(0.0, 18.0), anchor + Vector2(-72.0, -18.0)]


func _polygons_equal_approx(left: Array[Vector2], right: Array[Vector2]) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if not left[index].is_equal_approx(right[index]):
			return false
	return true


func _point_in_or_on_polygon(point: Vector2, polygon: Array[Vector2]) -> bool:
	if polygon.size() < 3:
		return false
	if Geometry2D.is_point_in_polygon(point, PackedVector2Array(polygon)):
		return true
	for index in range(polygon.size()):
		if Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()]).distance_squared_to(point) <= 0.0001:
			return true
	return false


func _paired_plot_delta_metrics(left: Array[Dictionary], right: Array[Dictionary]) -> Dictionary:
	var right_by_id := {}
	for plot in right:
		right_by_id[str(plot.get("id", ""))] = plot.get("pivot_pos", Vector2.ZERO)
	var squared_sum := 0.0
	var max_delta := 0.0
	var paired_count := 0
	for plot in left:
		var plot_id := str(plot.get("id", ""))
		if not right_by_id.has(plot_id):
			continue
		var left_position: Vector2 = plot.get("pivot_pos", Vector2.ZERO)
		var right_position: Vector2 = right_by_id.get(plot_id, Vector2.ZERO)
		var delta := left_position.distance_to(right_position)
		squared_sum += delta * delta
		max_delta = maxf(max_delta, delta)
		paired_count += 1
	return {
		"paired_count": paired_count,
		"rms_world": sqrt(squared_sum / float(paired_count)) if paired_count > 0 else 0.0,
		"max_world": max_delta,
	}


func _selected_building_slot_change_count(left: Array[Dictionary], right: Array[Dictionary]) -> int:
	var right_slots := {}
	for building in right:
		right_slots[str(building.get("type", ""))] = int(building.get("route_slot_index", -1))
	var changed := 0
	for building in left:
		var building_type := str(building.get("type", ""))
		if right_slots.has(building_type) and int(building.get("route_slot_index", -1)) != int(right_slots.get(building_type, -1)):
			changed += 1
	return changed


func _road_edge_kind_count(road: Dictionary, expected_kind: String) -> int:
	var count := 0
	for edge in _dictionary_array(road.get("edges", [])):
		if str(edge.get("kind", "")) == expected_kind:
			count += 1
	return count


func _replace_blocked_polygon(
	layout: Dictionary,
	kind: String,
	owner_id: String,
	polygon: Array[Vector2]
) -> void:
	var blockers_value: Variant = layout.get("blocked_polygons", [])
	if not (blockers_value is Array):
		return
	for index in range((blockers_value as Array).size()):
		var blocker_value: Variant = (blockers_value as Array)[index]
		if not (blocker_value is Dictionary):
			continue
		var blocker := blocker_value as Dictionary
		if str(blocker.get("kind", "")) != kind or str(blocker.get("owner_id", "")) != owner_id:
			continue
		var updated := blocker.duplicate(true)
		updated["polygon_world"] = polygon.duplicate()
		(blockers_value as Array)[index] = updated
		break
	layout["blocked_polygons"] = blockers_value


func _polygon_centroid(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var total := Vector2.ZERO
	for point in points:
		total += point
	return total / float(points.size())


func _polygon_area_abs(points: Array[Vector2]) -> float:
	if points.size() < 3:
		return 0.0
	var doubled_area := 0.0
	for index in range(points.size()):
		var current := points[index]
		var next := points[(index + 1) % points.size()]
		doubled_area += current.x * next.y - next.x * current.y
	return absf(doubled_area) * 0.5


func _find_dictionary_by_field(values: Array[Dictionary], field: String, expected: String) -> Dictionary:
	for value in values:
		if str(value.get(field, "")) == expected:
			return value
	return {}


func _snapshot_input_positions(specs: Array[Dictionary]) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for spec in specs:
		snapshot.append({
			"type": str(spec.get("type", "")),
			"pivot_pos": spec.get("pivot_pos", Vector2.ZERO),
			"visual_rect": spec.get("visual_rect", Rect2()),
			"interaction_rect": spec.get("interaction_rect", Rect2()),
			"y_sort_anchor": float(spec.get("y_sort_anchor", 0.0)),
		})
	return snapshot


func _building_types(specs: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for spec in specs:
		result.append(str(spec.get("type", "")))
	return result


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item in value as Array:
		if item is Dictionary:
			result.append(item as Dictionary)
	return result


func _vector2_array(value: Variant) -> Array[Vector2]:
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
	return result


func _as_dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _violation_codes(validation: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var violations_value: Variant = validation.get("violations", [])
	if not (violations_value is Array):
		return result
	for violation_value in violations_value as Array:
		if violation_value is Dictionary:
			result.append(str((violation_value as Dictionary).get("code", "")))
	return result


func _has_violation(validation: Dictionary, expected_code: String) -> bool:
	return _violation_codes(validation).has(expected_code)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
