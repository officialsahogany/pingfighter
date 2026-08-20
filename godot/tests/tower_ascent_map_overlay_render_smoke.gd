extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentMapOverlayLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_map_overlay_localization.gd"
)
const TowerAscentTransitionFadeState := preload(
	"res://scripts/tower_ascent/tower_ascent_transition_fade_state.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAscentMapPathGeometry := preload(
	"res://scripts/tower_ascent/tower_ascent_map_path_geometry.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_graph_state_model_survives_camera_crop()
	_verify_fullscreen_projection_and_existing_art_slots()
	_verify_live_resolution_map_uses_tracked_zoom()
	_verify_tracked_camera_boundaries()
	_verify_seeded_curve_geometry_preserves_connections()
	_verify_map_cache_and_six_beat_transition_contract()
	_verify_live_viewport_owns_fullscreen_rect()
	_verify_localization_catalog()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("tower_ascent_map_overlay_render_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_graph_state_model_survives_camera_crop() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-overlay-render",
		"map_seed": 83521,
	}), "map-overlay render fixture must begin")
	var nodes := flow.get_graph_nodes()
	var skipped_slot_id := ""
	for node in nodes:
		if str(node.get("boss_slot_id", "")).is_empty():
			continue
		if str(node.get("id", "")) != flow.get_current_node_id():
			skipped_slot_id = str(node.get("boss_slot_id", ""))
			break
	if not skipped_slot_id.is_empty():
		flow.call("_mark_boss_slot_skipped_in_graph", skipped_slot_id)
	flow.handle_input(_key_event(KEY_M))
	_expect(flow.get_phase_name() == "MAP_OVERLAY", "M must project the dedicated map-overlay phase")
	nodes = flow.get_graph_nodes()
	_expect(nodes.size() == 25, "the camera map must retain the complete generated graph model")
	var visible_kinds: Dictionary = {}
	var has_current := false
	var has_completed := false
	var has_vanished := false
	for node in nodes:
		var kind_label := TowerAscentMapOverlayLocalization.node_kind_label(
			str(node.get("kind", "")),
			bool(node.get("enraged", false))
		)
		visible_kinds[kind_label] = true
		has_current = has_current or str(node.get("id", "")) == flow.get_current_node_id()
		has_completed = has_completed or bool(node.get("completed", false))
		has_vanished = has_vanished or bool(node.get("skipped", false))
	for required_label in ["전투", "광폭화", "상점", "수련장", "파계승", "수호의 샘터", "휴식"]:
		_expect(visible_kinds.has(required_label), "the graph model must retain node kind: %s" % required_label)
	_expect(has_current, "the overlay graph must contain the current player node")
	_expect(has_completed, "the overlay graph must distinguish a completed node")
	_expect(has_vanished, "the overlay graph must preserve a vanished skipped boss marker")
	var locked_hints: Array = flow.get_locked_phase_hints()
	_expect(locked_hints.size() == 1, "the human-realm overlay must preserve the locked phase-2 hint")
	if not locked_hints.is_empty():
		_expect(int((locked_hints[0] as Dictionary).get("floor_start", 0)) == 10 and int((locked_hints[0] as Dictionary).get("floor_end", 0)) == 12, "the locked hint must identify floors 10 through 12 without disclosing their nodes")


func _verify_localization_catalog() -> void:
	var required_keys := [
		TowerAscentMapOverlayLocalization.KEY_TITLE,
		TowerAscentMapOverlayLocalization.KEY_CLOSE_HINT,
		TowerAscentMapOverlayLocalization.KEY_REALM_HUMAN,
		TowerAscentMapOverlayLocalization.KEY_REALM_IMMORTAL,
		TowerAscentMapOverlayLocalization.KEY_REALM_IMMORTAL_LOCKED,
		TowerAscentMapOverlayLocalization.KEY_ENTER_IMMORTAL,
		TowerAscentMapOverlayLocalization.KEY_NODE_GUARDIAN_SPRING,
		TowerAscentMapOverlayLocalization.KEY_STATE_CURRENT,
		TowerAscentMapOverlayLocalization.KEY_STATE_COMPLETED,
		TowerAscentMapOverlayLocalization.KEY_STATE_UNVISITED,
		TowerAscentMapOverlayLocalization.KEY_STATE_VANISHED,
		TowerAscentMapOverlayLocalization.KEY_STATE_LOCKED,
	]
	var registered := TowerAscentMapOverlayLocalization.get_registered_keys()
	for key in required_keys:
		_expect(registered.has(key), "map-overlay localization must register %s" % key)
	_expect(TowerAscentMapOverlayLocalization.text(TowerAscentMapOverlayLocalization.KEY_TITLE) == "지도", "the Korean overlay title must be exactly 지도")
	for text_value in TowerAscentMapOverlayLocalization.TEXT_BY_LOCALE.get(
		LanguageSettings.LANGUAGE_KOREAN,
		{}
	).values():
		_expect(not str(text_value).contains("—"), "new Korean map copy must not contain an em dash")
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_ENGLISH)
	_expect(TowerAscentMapOverlayLocalization.text(TowerAscentMapOverlayLocalization.KEY_TITLE) == "지도", "missing translations must fall back to Korean map copy")
	_expect(TowerAscentMapOverlayLocalization.get_missing_translation_locales().has(LanguageSettings.LANGUAGE_ENGLISH), "the map catalog must report untranslated supported locales")
	LanguageSettings.set_test_locale_override("")


func _verify_fullscreen_projection_and_existing_art_slots() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-overlay-fullscreen",
		"map_seed": 83521,
	}), "fullscreen map fixture must begin")
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(1280.0, 800.0))
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, viewport_rect)
	_expect(model.get("viewport_rect", Rect2()) == viewport_rect, "fullscreen model must preserve the full screen rect")
	_expect((model.get("nodes", []) as Array).size() == flow.get_graph_nodes().size(), "fullscreen map must project every disclosed node")
	_expect((model.get("floor_bands", []) as Array).size() == 9, "human-realm castle must expose one visible tier per active floor")
	_expect(str(model.get("realm_kind", "")) == "human_realm", "phase-1 fullscreen projection must own the human-realm treatment")
	_expect((model.get("locked_phase_hints", []) as Array).size() == 1, "phase-1 fullscreen projection must carry the 10 through 12 lock hint")
	var content_rect: Rect2 = model.get("content_rect", Rect2())
	var world_rect: Rect2 = model.get("world_rect", Rect2())
	var min_node_y := INF
	var max_node_y := -INF
	for node_variant in model.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var world_position: Vector2 = node.get("world_position", Vector2.ZERO)
		var art_rect: Rect2 = node.get("world_art_rect", Rect2())
		var art_path := str(node.get("art_path", ""))
		_expect(world_rect.grow(0.1).has_point(world_position), "every node center must remain inside the tracked map world")
		_expect(art_rect.size.x >= 18.0 and art_rect.size.y >= 18.0, "every node must own a readable art slot")
		_expect(not art_path.is_empty() and FileAccess.file_exists(art_path), "every node art slot must reuse an existing asset: %s" % art_path)
		min_node_y = minf(min_node_y, world_position.y)
		max_node_y = maxf(max_node_y, world_position.y)
	_expect(min_node_y < world_rect.get_center().y and max_node_y > world_rect.get_center().y, "the castle route world must ascend from bottom to top")
	_expect(world_rect.size.y >= content_rect.size.y * 2.0, "v1.13 must replace full disclosure with at least a 2x tall camera world")
	for art_path in renderer.get_node_art_asset_paths():
		_expect(FileAccess.file_exists(art_path), "the node-art catalog must never reserve a missing draw path: %s" % art_path)


func _verify_live_resolution_map_uses_tracked_zoom() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-overlay-live-resolution",
		"map_seed": 83521,
	}), "live-resolution map fixture must begin")
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var reference_model: Dictionary = renderer.build_fullscreen_map_model(
		flow,
		Rect2(Vector2.ZERO, Vector2(1280.0, 800.0))
	)
	var live_model: Dictionary = renderer.build_fullscreen_map_model(
		flow,
		Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	)
	var expected_scale := 1246.0 / 800.0
	var art_scale := float(live_model.get("art_size", 0.0)) / maxf(
		1.0,
		float(reference_model.get("art_size", 0.0))
	)
	var reference_lane_span := _world_node_x_span(reference_model)
	var live_lane_span := _world_node_x_span(live_model)
	var lane_scale := live_lane_span / maxf(1.0, reference_lane_span)
	_expect(float(live_model.get("art_size", 0.0)) > 34.0, "2020x1246 node art must not stop at the old 34px absolute cap")
	_expect(live_lane_span > 660.0, "2020x1246 node lanes must use the actual source min/max instead of half of the capped span")
	_expect(absf(art_scale - expected_scale) <= 0.04, "node art must scale with the live viewport height")
	_expect(absf(lane_scale - expected_scale) <= 0.06, "node lane span must scale with the live viewport height")
	var live_content: Rect2 = live_model.get("content_rect", Rect2())
	var live_world: Rect2 = live_model.get("world_rect", Rect2())
	var visible_world: Rect2 = (live_model.get("camera", {}) as Dictionary).get(
		"visible_world_rect",
		Rect2()
	)
	_expect(float(live_model.get("zoom_scale", 0.0)) >= 2.0, "the tracked map zoom must stay at or above 2x")
	_expect(live_world.size.y >= live_content.size.y * 2.0, "the map world must be cropped vertically instead of fitted into one screen")
	_expect(is_equal_approx(visible_world.size.y, live_content.size.y), "the camera window must match the live map content height")
	var visible_node_count := 0
	for node_variant in live_model.get("nodes", []):
		if node_variant is Dictionary:
			if visible_world.has_point((node_variant as Dictionary).get("world_position", Vector2.ZERO)):
				visible_node_count += 1
	_expect(visible_node_count > 0 and visible_node_count < (live_model.get("nodes", []) as Array).size(), "v1.13 camera must reveal only a cropped subset of the graph")


func _world_node_x_span(model: Dictionary) -> float:
	var min_x := INF
	var max_x := -INF
	for node_variant in model.get("nodes", []):
		if not (node_variant is Dictionary):
			continue
		var position: Vector2 = (node_variant as Dictionary).get("world_position", Vector2.ZERO)
		min_x = minf(min_x, position.x)
		max_x = maxf(max_x, position.x)
	return 0.0 if not is_finite(min_x) or not is_finite(max_x) else max_x - min_x


func _verify_tracked_camera_boundaries() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-camera-boundaries",
		"map_seed": 83521,
	}), "camera-boundary fixture must begin")
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	var lower_model: Dictionary = renderer.build_fullscreen_map_model(flow, viewport_rect)
	var lower_camera: Dictionary = lower_model.get("camera", {})
	var lower_content: Rect2 = lower_model.get("content_rect", Rect2())
	var lower_world: Rect2 = lower_model.get("world_rect", Rect2())
	var lower_padding := float(lower_model.get("art_size", 0.0)) * TowerAscentTuning.TEMP_MAP_CAMERA_BOUNDARY_ART_PADDING_RATIO
	var lower_offset := float((lower_camera.get("offset", Vector2.ZERO) as Vector2).y)
	_expect(bool(lower_camera.get("at_lower_boundary", false)), "floor 1 must clamp at the lower camera boundary")
	_expect(is_equal_approx(lower_world.end.y + lower_padding + lower_offset, lower_content.end.y), "the lower clamp must expose no empty space below the map world")
	var middle_node_id := ""
	for node_variant in flow.get_graph_nodes():
		if node_variant is Dictionary and int((node_variant as Dictionary).get("floor", 0)) == 5:
			middle_node_id = str((node_variant as Dictionary).get("id", ""))
			break
	flow.set("_current_node_id", middle_node_id)
	var middle_model: Dictionary = renderer.build_fullscreen_map_model(flow, viewport_rect)
	var middle_camera: Dictionary = middle_model.get("camera", {})
	var middle_content: Rect2 = middle_model.get("content_rect", Rect2())
	var middle_focus: Vector2 = middle_camera.get("focus_screen_position", Vector2.ZERO)
	_expect(not bool(middle_camera.get("at_lower_boundary", true)) and not bool(middle_camera.get("at_upper_boundary", true)), "a middle floor must use free camera tracking")
	_expect(absf(middle_focus.y - middle_content.get_center().y) <= 0.1, "a middle-floor character must stay vertically centered")

	var top_node_id := ""
	var top_floor := -1
	for node_variant in flow.get_graph_nodes():
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var floor_number := int(node.get("floor", 0))
		if floor_number > top_floor:
			top_floor = floor_number
			top_node_id = str(node.get("id", ""))
	flow.set("_current_node_id", top_node_id)
	var upper_model: Dictionary = renderer.build_fullscreen_map_model(flow, viewport_rect)
	var upper_camera: Dictionary = upper_model.get("camera", {})
	var upper_content: Rect2 = upper_model.get("content_rect", Rect2())
	var upper_world: Rect2 = upper_model.get("world_rect", Rect2())
	var upper_padding := float(upper_model.get("art_size", 0.0)) * TowerAscentTuning.TEMP_MAP_CAMERA_BOUNDARY_ART_PADDING_RATIO
	var upper_offset := float((upper_camera.get("offset", Vector2.ZERO) as Vector2).y)
	_expect(bool(upper_camera.get("at_upper_boundary", false)), "the final floor must clamp at the upper camera boundary")
	_expect(is_equal_approx(upper_world.position.y - upper_padding + upper_offset, upper_content.position.y), "the upper clamp must expose no empty space above the map world")


func _verify_seeded_curve_geometry_preserves_connections() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-seeded-curves",
		"map_seed": 83521,
	}), "seeded-curve fixture must begin")
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var model: Dictionary = renderer.build_fullscreen_map_model(
		flow,
		Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	)
	var source_connections := TowerAscentMapPathGeometry.connection_signature(
		flow.get_graph_edges()
	)
	var projected_connections := TowerAscentMapPathGeometry.connection_signature(
		model.get("edges", [])
	)
	_expect(source_connections == projected_connections, "curve projection must preserve every generated from/to connection in order")
	var first_signature := TowerAscentMapPathGeometry.curve_signature(model.get("edges", []))
	var repeated_signature := TowerAscentMapPathGeometry.curve_signature(
		renderer.build_fullscreen_map_model(
			flow,
			Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
		).get("edges", [])
	)
	_expect(not first_signature.is_empty() and first_signature == repeated_signature, "the same map seed and graph must reproduce byte-identical curve geometry")
	var rebuilt_with_other_seed := TowerAscentMapPathGeometry.build(
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
	_expect(first_signature != TowerAscentMapPathGeometry.curve_signature(rebuilt_with_other_seed), "a different map seed must produce a different presentation curve")
	for edge_variant in model.get("edges", []):
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		var from_position: Vector2 = edge.get("from_position", Vector2.ZERO)
		var to_position: Vector2 = edge.get("to_position", Vector2.ZERO)
		var path_start: Vector2 = edge.get("path_start", from_position)
		var path_end: Vector2 = edge.get("path_end", to_position)
		_expect(path_start.distance_to(from_position) > float(model.get("art_size", 0.0)) * 0.5, "curves must clear the source node art")
		_expect(path_end.distance_to(to_position) > float(model.get("art_size", 0.0)) * 0.5, "curves must clear the destination node art")


func _verify_map_cache_and_six_beat_transition_contract() -> void:
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-overlay-cache-and-transition",
		"map_seed": 83521,
	}), "cache and transition fixture must begin")
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	renderer.build_fullscreen_map_model(flow, viewport_rect)
	renderer.build_fullscreen_map_model(flow, viewport_rect)
	var cache_state: Dictionary = renderer.get_render_cache_debug_state()
	_expect(int(cache_state.get("graph_build_count", 0)) == 1, "unchanged graph draws must reuse one cached graph model")
	_expect(int(cache_state.get("fullscreen_build_count", 0)) == 1, "unchanged viewport draws must reuse one cached fullscreen projection")
	_expect(int(cache_state.get("path_build_count", 0)) == 1, "unchanged map draws must not rebuild dotted path geometry per frame")
	_expect(int(cache_state.get("path_dot_count", 0)) > 0, "the cached route must contain polygon dots")
	_expect(int(cache_state.get("path_draw_call_budget", 0)) == int(cache_state.get("path_dot_count", 0)) * 2, "the dotted path draw-call budget must stay explicit")
	print(
		"tower_ascent_map_overlay_render_smoke: dotted_path_budget edges=%d dots=%d draw_calls=%d" % [
			(_model_edge_count(renderer, flow, viewport_rect)),
			int(cache_state.get("path_dot_count", 0)),
			int(cache_state.get("path_draw_call_budget", 0)),
		]
	)

	var target_ids: Array[String] = flow.get_route_target_ids()
	_expect(not target_ids.is_empty(), "transition fixture must expose a route target")
	if not target_ids.is_empty():
		var source_id := flow.get_current_node_id()
		var target_id := target_ids[0]
		flow.call("_resolve_route_target", target_id)
		_expect(flow.get_current_node_id() == source_id, "route selection must not promote the destination before arrival")
		renderer.build_fullscreen_map_model(flow, viewport_rect)
		var transition_cache_builds := int(
			renderer.get_render_cache_debug_state().get("fullscreen_build_count", 0)
		)
		flow.set_transition_progress_for_qa(0.5)
		var moving_model: Dictionary = renderer.build_fullscreen_map_model(flow, viewport_rect)
		var moving_marker: Dictionary = moving_model.get("transition_marker", {})
		var moving_camera: Dictionary = moving_model.get("camera", {})
		_expect(float(moving_marker.get("progress", 0.0)) > 0.0 and float(moving_marker.get("progress", 0.0)) < 1.0, "mid-transition marker must use the eased travel window")
		_expect((moving_marker.get("world_position", Vector2.ZERO) as Vector2).is_equal_approx(moving_camera.get("focus_world_position", Vector2.ONE)), "the tracked camera must consume the walker's curve position from the same physics-clock progress")
		_expect((moving_model.get("content_rect", Rect2()) as Rect2).grow(-1.0).has_point(moving_camera.get("focus_screen_position", Vector2.ZERO)), "the tracked transition walker must remain inside the visible map crop")
		var straight_midpoint := (moving_marker.get("from_position", Vector2.ZERO) as Vector2).lerp(
			moving_marker.get("to_position", Vector2.ZERO),
			float(moving_marker.get("progress", 0.0))
		)
		_expect((moving_marker.get("world_position", Vector2.ZERO) as Vector2).distance_to(straight_midpoint) > 1.0, "the transition walker must follow the cached curve instead of cutting across it")
		_expect(int(renderer.get_render_cache_debug_state().get("fullscreen_build_count", 0)) == transition_cache_builds, "transition progress must not rebuild the cached graph projection")
		flow.call("_complete_map_transition")
		_expect(flow.get_current_node_id() == target_id, "the destination must become current only when the map transition completes")

	var timeline := TowerAscentTransitionFadeState.new()
	timeline.begin_map_transition()
	var expected_total := (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)
	_expect(is_equal_approx(timeline.get_map_transition_duration_sec(), expected_total), "map transition duration must be the five visual beats in the tuning table")
	timeline.set_map_transition_progress_for_qa(0.0)
	var start_model: Dictionary = timeline.get_map_transition_visual_model()
	_expect(str(start_model.get("segment", "")) == TowerAscentTransitionFadeState.SEGMENT_BATTLE_FADE_OUT, "progress 0 must keep the battle visible for its fade-out")
	_expect(not bool(start_model.get("map_visible", true)) and is_zero_approx(float(start_model.get("blackout_alpha", -1.0))), "battle fade must start with no map and no blackout")
	timeline.set_map_transition_progress_for_qa(0.5)
	var middle_model: Dictionary = timeline.get_map_transition_visual_model()
	_expect(str(middle_model.get("segment", "")) == TowerAscentTransitionFadeState.SEGMENT_TRAVEL, "progress 0.5 must land in the travel beat")
	_expect(bool(middle_model.get("map_visible", false)) and float(middle_model.get("travel_progress", 0.0)) > 0.0, "travel beat must show the fullscreen map and eased walker")
	timeline.set_map_transition_progress_for_qa(1.0)
	var end_model: Dictionary = timeline.get_map_transition_visual_model()
	_expect(str(end_model.get("segment", "")) == TowerAscentTransitionFadeState.SEGMENT_MAP_FADE_OUT, "progress 1 must end on the map blackout beat")
	_expect(is_equal_approx(float(end_model.get("blackout_alpha", 0.0)), 1.0) and is_zero_approx(float(end_model.get("marker_alpha", 1.0))), "arrival must vanish before the fully black handoff")
	timeline.begin_node_modal_fade()
	_expect(is_zero_approx(timeline.get_node_modal_fade_progress()), "noncombat arrival surface must begin fully covered")
	timeline.update_node_modal_fade(TowerAscentTuning.TEMP_NODE_MODAL_FADE_IN_SEC)
	_expect(is_equal_approx(timeline.get_node_modal_fade_progress(), 1.0), "noncombat node fade must complete on its tuning duration")


func _model_edge_count(
	renderer: Object,
	flow: Object,
	viewport_rect: Rect2
) -> int:
	return (renderer.build_fullscreen_map_model(flow, viewport_rect).get("edges", []) as Array).size()


func _verify_live_viewport_owns_fullscreen_rect() -> void:
	var renderer := preload(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	).new()
	var canvas := Node2D.new()
	get_root().add_child(canvas)
	var fallback := Rect2(Vector2.ZERO, Vector2(73.0, 91.0))
	_expect(canvas.is_inside_tree(), "the viewport-sizing fixture must enter the scene tree")
	var resolved: Rect2 = renderer.resolve_fullscreen_rect(canvas, fallback)
	var live_rect := canvas.get_viewport_rect() if canvas.is_inside_tree() else Rect2()
	_expect(resolved == live_rect, "an in-tree map canvas must use the live viewport as the primary fullscreen size")
	_expect(resolved != fallback, "live viewport sizing must not collapse to a stale playfield/context fallback")
	get_root().remove_child(canvas)
	canvas.free()


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
