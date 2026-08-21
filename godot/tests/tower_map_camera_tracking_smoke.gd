extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentMapPathGeometry := preload(
	"res://scripts/tower_ascent/tower_ascent_map_path_geometry.gd"
)
const TowerAscentMapCameraModel := preload(
	"res://scripts/tower_ascent/tower_ascent_map_camera_model.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_fullscreen_pillar_extent_and_approved_band()
	_verify_seeded_curves_and_connection_identity()
	_verify_camera_boundaries_and_static_path_cache()
	_verify_transition_camera_uses_physics_clock_curve()
	_verify_intro_zoom_handoff_and_boundaries()
	_verify_polygon_dot_contract()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_map_camera_tracking_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_fullscreen_pillar_extent_and_approved_band() -> void:
	var flow := _new_flow("fullscreen-pillar-extent", 83521)
	var renderer := TowerAscentFlowRenderer.new()
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var panel_rect: Rect2 = model.get("panel_rect", Rect2())
	var safe_content_bounds: Rect2 = model.get("safe_content_bounds", Rect2())
	var content_rect: Rect2 = model.get("content_rect", Rect2())
	var world_rect: Rect2 = model.get("world_rect", Rect2())
	var expected_outer_margin := minf(VIEWPORT_RECT.size.x, VIEWPORT_RECT.size.y) * TowerAscentTuning.TEMP_MAP_OUTER_MARGIN_RATIO
	_expect(panel_rect == VIEWPORT_RECT, "fullscreen map paper must reach every edge of the actual screen viewport")
	_expect(safe_content_bounds == VIEWPORT_RECT.grow(-expected_outer_margin), "fullscreen expansion must preserve the established safe content bounds")
	_expect(safe_content_bounds.encloses(content_rect), "map paths, nodes, plaques, and camera crop must stay inside the established content bounds")
	_expect(is_equal_approx(world_rect.size.x, 692.0), "fullscreen expansion must not stretch the approved 692px scroll band")
	for floor_variant in model.get("floor_bands", []):
		if floor_variant is Dictionary:
			_expect(((floor_variant as Dictionary).get("rect", Rect2()) as Rect2).size.is_equal_approx(Vector2(692.0, 320.0)), "every approved floor band must remain 692x320")
	var camera: Dictionary = model.get("camera", {})
	var visible_world_rect: Rect2 = camera.get("visible_world_rect", Rect2())
	for target_id in flow.get_route_target_ids():
		var target_position: Vector2 = (model.get("position_by_id", {}) as Dictionary).get(target_id, Vector2.INF)
		_expect(visible_world_rect.grow(0.1).has_point(target_position), "each active route candidate must remain visible after fullscreen expansion: %s" % target_id)
	var playfield_rect := Rect2(Vector2.ZERO, Vector2(760.0, 750.0))
	var playfield_model: Dictionary = TowerAscentFlowRenderer.new().build_fullscreen_map_model(flow, playfield_rect)
	_expect(playfield_model.get("panel_rect", Rect2()) == playfield_rect, "reverse viewport leg must follow its supplied viewport instead of a hard-coded screen size")
	_expect(is_equal_approx(float((playfield_model.get("world_rect", Rect2()) as Rect2).size.x), 692.0), "reverse viewport leg must also preserve the approved band width")


func _verify_seeded_curves_and_connection_identity() -> void:
	var flow := _new_flow("camera-seed", 83521)
	var renderer := TowerAscentFlowRenderer.new()
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var source_connections := TowerAscentMapPathGeometry.connection_signature(
		flow.get_graph_edges()
	)
	var projected_connections := TowerAscentMapPathGeometry.connection_signature(
		model.get("edges", [])
	)
	_expect(source_connections == projected_connections, "presentation paths must preserve the generated connection list byte-for-byte")
	var first_signature := TowerAscentMapPathGeometry.curve_signature(model.get("edges", []))
	var repeated_signature := TowerAscentMapPathGeometry.curve_signature(
		renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT).get("edges", [])
	)
	_expect(not first_signature.is_empty() and first_signature == repeated_signature, "the same map seed must reproduce the same curve signature")
	var other_seed_edges := TowerAscentMapPathGeometry.build(
		model.get("edges", []),
		83522,
		float(model.get("art_size", 0.0)),
		TowerAscentTuning.TEMP_MAP_PATH_CURVE_MIN_RATIO,
		TowerAscentTuning.TEMP_MAP_PATH_CURVE_MAX_RATIO,
		TowerAscentTuning.TEMP_MAP_PATH_CURVE_SKEW_RATIO,
		TowerAscentTuning.TEMP_MAP_PATH_ENDPOINT_CLEARANCE_RATIO,
		TowerAscentTuning.TEMP_MAP_PATH_SAMPLE_MIN,
		TowerAscentTuning.TEMP_MAP_PATH_SAMPLE_MAX
	)
	_expect(first_signature != TowerAscentMapPathGeometry.curve_signature(other_seed_edges), "a different map seed must change presentation curvature")
	_expect(source_connections == TowerAscentMapPathGeometry.connection_signature(other_seed_edges), "changing presentation seed must not change graph connections")


func _verify_camera_boundaries_and_static_path_cache() -> void:
	var flow := _new_flow("camera-bounds", 83521)
	var renderer := TowerAscentFlowRenderer.new()
	var lower_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	_verify_boundary(lower_model, "lower")
	var middle_id := _node_id_for_floor(flow, 5)
	flow.set("_current_node_id", middle_id)
	var middle_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var middle_camera: Dictionary = middle_model.get("camera", {})
	_expect(not bool(middle_camera.get("at_lower_boundary", true)) and not bool(middle_camera.get("at_upper_boundary", true)), "middle floor must leave both clamps")
	_expect(absf((middle_camera.get("focus_screen_position", Vector2.ZERO) as Vector2).y - (middle_model.get("content_rect", Rect2()) as Rect2).get_center().y) <= 0.1, "middle-floor focus must stay vertically centered")
	var top_id := _node_id_for_floor(flow, 9)
	flow.set("_current_node_id", top_id)
	var upper_model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	_verify_boundary(upper_model, "upper")
	var cache_state: Dictionary = renderer.get_render_cache_debug_state()
	_expect(int(cache_state.get("fullscreen_build_count", 0)) == 1, "dynamic camera focus must reuse the static fullscreen projection")
	_expect(int(cache_state.get("path_build_count", 0)) == 1, "dynamic camera focus must reuse one dotted-path cache")
	_expect(int(cache_state.get("path_dot_count", 0)) > 0, "dotted-path cache must contain geometry")


func _verify_transition_camera_uses_physics_clock_curve() -> void:
	var flow := _new_flow("camera-transition", 83521)
	var renderer := TowerAscentFlowRenderer.new()
	renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var targets: Array[String] = flow.get_route_target_ids()
	_expect(not targets.is_empty(), "transition fixture must expose a route target")
	if targets.is_empty():
		return
	flow.call("_resolve_route_target", targets[0])
	var focus_positions := PackedVector2Array()
	var transition_path_build_count := -1
	for progress in [0.35, 0.50, 0.65]:
		flow.set_transition_progress_for_qa(progress)
		var model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
		var marker: Dictionary = model.get("transition_marker", {})
		var camera: Dictionary = model.get("camera", {})
		var focus_world: Vector2 = camera.get("focus_world_position", Vector2.ZERO)
		var marker_world: Vector2 = marker.get("world_position", Vector2.ONE)
		_expect(focus_world.is_equal_approx(marker_world), "camera and walker must consume the same eased transition position")
		_expect((model.get("content_rect", Rect2()) as Rect2).grow(-1.0).has_point(camera.get("focus_screen_position", Vector2.ZERO)), "walker focus must stay inside the tracked crop")
		focus_positions.append(focus_world)
		var current_build_count := int(renderer.get_render_cache_debug_state().get("path_build_count", 0))
		if transition_path_build_count < 0:
			transition_path_build_count = current_build_count
		else:
			_expect(current_build_count == transition_path_build_count, "transition ticks must not rebuild dotted paths")
	_expect(focus_positions.size() == 3 and focus_positions[0] != focus_positions[1] and focus_positions[1] != focus_positions[2], "physics-clock progress must move the tracked camera through distinct curve positions")


func _verify_intro_zoom_handoff_and_boundaries() -> void:
	var flow := _new_flow("camera-intro-handoff", 83521)
	var renderer := TowerAscentFlowRenderer.new()
	renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var targets: Array[String] = flow.get_route_target_ids()
	_expect(not targets.is_empty(), "camera-intro fixture must expose a route target")
	if targets.is_empty():
		return
	var target_id := targets[0]
	flow.call("_resolve_route_target", target_id)
	var total := _transition_duration_sec()
	var zoom_start_elapsed := (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
	)
	var zoom_end_elapsed := (
		zoom_start_elapsed + TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
	)
	var physics_tick_sec := 1.0 / 72.0
	var zoom_start := _model_at_elapsed(flow, renderer, zoom_start_elapsed, total)
	var zoom_mid := _model_at_elapsed(
		flow,
		renderer,
		zoom_start_elapsed + TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC * 0.5,
		total
	)
	var zoom_last_tick := _model_at_elapsed(
		flow,
		renderer,
		zoom_end_elapsed - physics_tick_sec,
		total
	)
	var travel_boundary := _model_at_elapsed(flow, renderer, zoom_end_elapsed, total)
	var travel_first_tick := _model_at_elapsed(
		flow,
		renderer,
		zoom_end_elapsed + physics_tick_sec,
		total
	)
	var start_camera: Dictionary = zoom_start.get("camera", {})
	var mid_camera: Dictionary = zoom_mid.get("camera", {})
	var last_camera: Dictionary = zoom_last_tick.get("camera", {})
	var boundary_camera: Dictionary = travel_boundary.get("camera", {})
	var first_tick_camera: Dictionary = travel_first_tick.get("camera", {})
	_expect(is_equal_approx(float(start_camera.get("zoom_multiplier", 0.0)), TowerAscentTuning.TEMP_MAP_CAMERA_INTRO_START_MULTIPLIER), "map reveal must hand the established camera scale into the intro")
	_expect(float(mid_camera.get("zoom_multiplier", 0.0)) > float(start_camera.get("zoom_multiplier", 1.0)), "intro midpoint must narrow the camera crop")
	_expect(is_equal_approx(float(boundary_camera.get("zoom_multiplier", 0.0)), TowerAscentTuning.TEMP_MAP_CAMERA_INTRO_END_MULTIPLIER), "travel must begin at the final intro scale")
	var last_zoom_delta := absf(
		float(boundary_camera.get("zoom_multiplier", 0.0))
			- float(last_camera.get("zoom_multiplier", 0.0))
	)
	_expect(last_zoom_delta <= 0.0002, "the final 72 Hz intro tick must ease into the travel scale without a zoom jump")
	var boundary_focus: Vector2 = boundary_camera.get("focus_screen_position", Vector2.ZERO)
	var last_focus: Vector2 = last_camera.get("focus_screen_position", Vector2.ZERO)
	var first_tick_focus: Vector2 = first_tick_camera.get("focus_screen_position", Vector2.ZERO)
	_expect(last_focus.distance_to(boundary_focus) <= 0.25, "camera center must be C0-continuous at intro completion")
	_expect(boundary_focus.distance_to(first_tick_focus) <= 0.25, "the first travel tick must inherit the intro camera without a center jump")
	var start_marker: Dictionary = zoom_start.get("transition_marker", {})
	var mid_marker: Dictionary = zoom_mid.get("transition_marker", {})
	var boundary_marker: Dictionary = travel_boundary.get("transition_marker", {})
	var first_tick_marker: Dictionary = travel_first_tick.get("transition_marker", {})
	_expect((start_marker.get("world_position", Vector2.ZERO) as Vector2).is_equal_approx(mid_marker.get("world_position", Vector2.ONE)), "walker must remain fixed at the source during intro zoom")
	_expect((mid_marker.get("world_position", Vector2.ZERO) as Vector2).is_equal_approx(boundary_marker.get("world_position", Vector2.ONE)), "travel boundary must begin from the same source point")
	_expect(is_zero_approx(float(boundary_marker.get("progress", -1.0))) and float(first_tick_marker.get("progress", 0.0)) > 0.0, "walker travel must start only after the zoom boundary")
	var target_position: Vector2 = (travel_boundary.get("position_by_id", {}) as Dictionary).get(target_id, Vector2.INF)
	_expect((boundary_camera.get("visible_world_rect", Rect2()) as Rect2).has_point(target_position), "final intro crop must keep the next destination visible")
	_expect(bool(boundary_camera.get("at_lower_boundary", false)), "floor 1 intro zoom must retain the lower boundary clamp")
	var top_flow := _new_flow("camera-intro-top-boundary", 83521)
	var top_id := _node_id_for_floor(top_flow, 9)
	top_flow.set("_current_node_id", top_id)
	var top_renderer := TowerAscentFlowRenderer.new()
	var top_model: Dictionary = top_renderer.build_fullscreen_map_model(top_flow, VIEWPORT_RECT)
	var top_focus: Vector2 = (top_model.get("position_by_id", {}) as Dictionary).get(top_id, Vector2.ZERO)
	var top_camera := TowerAscentMapCameraModel.build(
		top_model.get("content_rect", Rect2()),
		top_model.get("world_rect", Rect2()),
		top_focus,
		float(top_model.get("art_size", 0.0)) * TowerAscentTuning.TEMP_MAP_CAMERA_BOUNDARY_ART_PADDING_RATIO,
		TowerAscentTuning.TEMP_MAP_CAMERA_FOCUS_Y_RATIO,
		TowerAscentTuning.TEMP_MAP_CAMERA_INTRO_END_MULTIPLIER,
		1.0
	)
	_expect(bool(top_camera.get("at_upper_boundary", false)), "final intro crop must retain the top-floor boundary clamp")
	_expect((top_model.get("content_rect", Rect2()) as Rect2).grow(-1.0).has_point(top_camera.get("focus_screen_position", Vector2.ZERO)), "top-floor focus must remain inside the final intro crop")


func _model_at_elapsed(
	flow: Object,
	renderer: Object,
	elapsed_sec: float,
	total_sec: float
) -> Dictionary:
	flow.set_transition_progress_for_qa(elapsed_sec / total_sec)
	return renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)


func _transition_duration_sec() -> float:
	return (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)


func _verify_polygon_dot_contract() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_map_path_geometry.gd"
	)
	_expect(source.contains("_circle_polygon"), "dotted paths must cache circle polygons")
	_expect(not source.contains("draw_line("), "path geometry must not emulate round dots with repeated draw_line calls")


func _verify_boundary(model: Dictionary, boundary: String) -> void:
	var camera: Dictionary = model.get("camera", {})
	var content: Rect2 = model.get("content_rect", Rect2())
	var world: Rect2 = model.get("world_rect", Rect2())
	var offset := float((camera.get("offset", Vector2.ZERO) as Vector2).y)
	var padding := float(model.get("art_size", 0.0)) * TowerAscentTuning.TEMP_MAP_CAMERA_BOUNDARY_ART_PADDING_RATIO
	if boundary == "lower":
		_expect(bool(camera.get("at_lower_boundary", false)), "floor 1 must own the lower clamp")
		_expect(is_equal_approx(world.end.y + padding + offset, content.end.y), "lower clamp must reveal no empty world")
		return
	_expect(bool(camera.get("at_upper_boundary", false)), "top floor must own the upper clamp")
	_expect(is_equal_approx(world.position.y - padding + offset, content.position.y), "upper clamp must reveal no empty world")


func _new_flow(run_id: String, map_seed: int) -> Object:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": run_id,
		"map_seed": map_seed,
	}), "%s fixture must begin" % run_id)
	return flow


func _node_id_for_floor(flow: Object, floor_number: int) -> String:
	for node_variant in flow.get_graph_nodes():
		if node_variant is Dictionary and int((node_variant as Dictionary).get("floor", 0)) == floor_number:
			return str((node_variant as Dictionary).get("id", ""))
	return ""


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
