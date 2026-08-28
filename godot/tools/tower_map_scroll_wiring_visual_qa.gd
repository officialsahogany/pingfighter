extends SceneTree

const TowerMapOverlayVisualQa := preload(
	"res://tools/tower_ascent_map_overlay_visual_qa.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentRecordStore := preload(
	"res://scripts/tower_ascent/tower_ascent_record_store.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerMapScrollAssetCatalog := preload(
	"res://scripts/tower_ascent/tower_map_scroll_asset_catalog.gd"
)

const GAME_SIZE := Vector2i(2020, 1246)
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(GAME_SIZE))
const OUTPUT_DIR := "res://.godot/codex_captures/tower_map_scroll_route_refine"
const GAMEPLAY_ZOOM_NAME := "01_live_gameplay_cover_zoom.png"
const GAMEPLAY_COMPARE_NAME := "02_approved_human_vs_gameplay_cover_zoom.png"
const HUMAN_LOWER_NAME := "03_live_m_key_overlay_floor01.png"
const HUMAN_STATES_NAME := "04_live_m_key_overlay_three_route_states.png"
const BOUNDARY_NAME := "05_live_m_key_overlay_realm_boundary.png"
const IMMORTAL_NAME := "06_live_immortal_transition.png"
const MISSING_NAME := "07_live_missing_band_procedural_fallback.png"
const HUMAN_COMPARE_NAME := "08_approved_human_vs_m_key_overlay.png"
const IMMORTAL_COMPARE_NAME := "09_approved_immortal_vs_live.png"
const BAND_SEAM_FULLSCREEN_NAME := "10_live_fullscreen_band_seams.png"
const BAND_SEAM_LIVE_ZOOM_NAME := "11_live_band_seam_zoom.png"
const BAND_SEAM_COMPARE_NAME := "12_band_seam_before_after_probe.png"
const BAND_SEAM_BEFORE_STACK_NAME := "13_band_seam_before_stack.png"
const BAND_SEAM_AFTER_STACK_NAME := "14_band_seam_after_stack.png"
const BAND_SEAM_BOTTOM_NAME := "15_live_map_bottom.png"
const EDGE_CULL_FRAME_NAME := "16_live_edge_cull_frame.png"
const EDGE_CULL_DETAIL_NAME := "17_live_edge_cull_detail.png"
const BAND_SEAM_BRIGHT_LUMA_THRESHOLD := 200.0
const BAND_SEAM_MIN_GUTTER_WIDTH_PX := 2
const BAND_SEAM_EXPECTED_PRODUCTION_CHUNK_COUNT := 21
const BAND_SEAM_EXPECTED_PRODUCTION_SEAM_COUNT := 20
const BAND_SEAM_EXPECTED_CROSSFADE_WORLD_PX := 16.0
const BAND_SEAM_BASELINE_REFLECTED_TAIL_WORLD_PX := 56.0
const BAND_SEAM_FOLD_COMPARISON_ZOOM := 2.15

const HUMAN_BAND_PATHS := [
	"res://assets/sprites/tower/map_scroll/human_realm_01_mountain_rev2.png",
	"res://assets/sprites/tower/map_scroll/human_realm_02_village_rev2.png",
	"res://assets/sprites/tower/map_scroll/human_realm_03_river_rev2.png",
]
const IMMORTAL_BAND_PATHS := [
	"res://assets/sprites/tower/map_scroll/immortal_realm_01_islands_rev2.png",
	"res://assets/sprites/tower/map_scroll/immortal_realm_02_cloud_cranes_rev2.png",
	"res://assets/sprites/tower/map_scroll/immortal_realm_03_pavilions_rev2.png",
]

var _failure := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("Tower map-scroll wiring visual QA requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("Tower map-scroll wiring visual QA requires Vulkan")
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("Tower map-scroll capture directory could not be created")
		return
	if OS.get_cmdline_user_args().has("--band-seam-only"):
		await _run_band_seam_only(output_dir)
		return
	if OS.get_cmdline_user_args().has("--edge-cull-only"):
		await _run_edge_cull_only(output_dir)
		return

	var record_path := "user://tower_map_scroll_wiring_%d.cfg" % Time.get_ticks_usec()
	var store := TowerAscentRecordStore.new()
	store.set_save_path(record_path)
	var seeded := store.record_clear(
		9,
		TowerAscentRecordStore.ENDING_STANDARD,
		false,
		"tower-map-scroll-wiring:seed"
	)
	if not bool(seeded.get("accepted", false)):
		_fail("Realm-boundary fixture could not seed the prior clear")
		return
	var gameplay_fixture := _create_fixture("tower-map-scroll-gameplay-zoom", record_path)
	if gameplay_fixture.is_empty() or not _prepare_gameplay_zoom_fixture(gameplay_fixture):
		return
	var gameplay_flow: Object = gameplay_fixture["flow"]
	var gameplay_renderer := TowerAscentFlowRenderer.new()
	var gameplay_model := gameplay_renderer.build_fullscreen_map_model(
		gameplay_flow,
		VIEWPORT_RECT
	)
	var gameplay_camera: Dictionary = gameplay_model.get("camera", {})
	var expected_gameplay_zoom := maxf(
		float(gameplay_model.get("minimum_cover_zoom", 0.0)),
		TowerAscentTuning.TEMP_MAP_CAMERA_ZOOM
	)
	if (
		gameplay_flow.get_phase_name() != "MAP_TRANSITION"
		or not is_equal_approx(
			float(gameplay_camera.get("render_zoom_multiplier", 0.0)),
			expected_gameplay_zoom
		)
	):
		_fail("Primary capture did not reach the viewport-derived cover-safe gameplay zoom")
		return
	var gameplay_world_rect: Rect2 = gameplay_model.get("world_rect", Rect2())
	if not is_equal_approx(gameplay_world_rect.size.x, 692.0):
		_fail("Primary capture stretched the approved 692px scroll world")
		return
	var gameplay_image := await _capture(
		gameplay_fixture["canvas"],
		gameplay_fixture["viewport"]
	)
	if not _save(gameplay_image, output_dir.path_join(GAMEPLAY_ZOOM_NAME)):
		_fail("Primary cover-safe gameplay capture failed")
		return
	if not _save_candidate_live_compare(
		HUMAN_BAND_PATHS,
		gameplay_image,
		output_dir.path_join(GAMEPLAY_COMPARE_NAME)
	):
		_fail("Approved-versus-gameplay cover comparison could not be saved")
		return
	await _dispose_fixture(gameplay_fixture)

	var fixture := _create_fixture("tower-map-scroll-live", record_path)
	if fixture.is_empty():
		return
	var flow: Object = fixture["flow"]
	var canvas: CanvasItem = fixture["canvas"]
	var viewport: SubViewport = fixture["viewport"]
	var renderer := TowerAscentFlowRenderer.new()
	var lower_image := await _capture(canvas, viewport)
	if not _save(lower_image, output_dir.path_join(HUMAN_LOWER_NAME)):
		_fail("Human lower-floor capture failed")
		return

	var middle_node_id := _node_id_for_floor(flow, 5)
	if middle_node_id.is_empty() or not _decorate_three_route_states(flow, middle_node_id):
		_fail("Three-state route fixture could not be constructed")
		return
	var state_counts := _route_state_counts(flow, renderer)
	print("[TowerMapScrollWiringVisualQA] route_state_probe=%s" % str(state_counts))
	if (
		int(state_counts.get(TowerMapScrollAssetCatalog.ROUTE_BRUSH_UNSELECTED, 0)) <= 0
		or int(state_counts.get(TowerMapScrollAssetCatalog.ROUTE_BRUSH_AVAILABLE, 0)) <= 0
		or int(state_counts.get(TowerMapScrollAssetCatalog.ROUTE_BRUSH_COMPLETED_GOLD, 0)) <= 0
	):
		_fail("The live route frame does not contain all three approved brush states")
		return
	var human_states_image := await _capture(canvas, viewport)
	if not _save(human_states_image, output_dir.path_join(HUMAN_STATES_NAME)):
		_fail("Human three-route-state capture failed")
		return

	var boundary_node_id := _node_id_for_floor(flow, 9)
	if boundary_node_id.is_empty():
		_fail("Realm-boundary fixture could not locate floor 9")
		return
	flow.set("_current_node_id", boundary_node_id)
	flow.set("_available_route_target_ids", [])
	flow.set("_route_target_ids", [])
	var boundary_image := await _capture(canvas, viewport)
	if not _save(boundary_image, output_dir.path_join(BOUNDARY_NAME)):
		_fail("Realm-boundary capture failed")
		return

	flow.close_map_overlay()
	var judgment: Dictionary = flow.begin_floor_nine_resolution(
		"tower-map-scroll-wiring:floor09",
		Callable(),
		canvas,
		fixture["registry"]
	)
	if not bool(judgment.get("accepted", false)):
		_fail("Realm-boundary judgment fixture failed")
		return
	var choice: Dictionary = flow.choose_ending_route("continue")
	if not bool(choice.get("accepted", false)) or flow.get_active_graph_phase_index() != 1:
		_fail("Immortal-realm graph transition fixture failed")
		return
	flow.set_transition_progress_for_qa(0.5)
	var immortal_model := renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	if (
		str(immortal_model.get("realm_kind", "")) != TowerMapScrollAssetCatalog.REALM_IMMORTAL
		or not bool((immortal_model.get("scroll_background", {}) as Dictionary).get("ready", false))
	):
		_fail("Immortal-realm live model did not bind approved bands")
		return
	var immortal_image := await _capture(canvas, viewport)
	if not _save(immortal_image, output_dir.path_join(IMMORTAL_NAME)):
		_fail("Immortal-realm capture failed")
		return
	if not _save_candidate_live_compare(
		HUMAN_BAND_PATHS,
		human_states_image,
		output_dir.path_join(HUMAN_COMPARE_NAME)
	):
		_fail("Human approved-versus-live comparison could not be saved")
		return
	if not _save_candidate_live_compare(
		IMMORTAL_BAND_PATHS,
		immortal_image,
		output_dir.path_join(IMMORTAL_COMPARE_NAME)
	):
		_fail("Immortal approved-versus-live comparison could not be saved")
		return
	await _dispose_fixture(fixture)

	var missing_fixture := _create_missing_band_fixture()
	if missing_fixture.is_empty():
		return
	var missing_flow: Object = missing_fixture["flow"]
	var missing_renderer := TowerAscentFlowRenderer.new()
	var missing_model := missing_renderer.build_fullscreen_map_model(
		missing_flow,
		VIEWPORT_RECT
	)
	var missing_background: Dictionary = missing_model.get("scroll_background", {})
	if (
		bool(missing_background.get("ready", true))
		or str(missing_background.get("reason", "")) != "band_unavailable"
	):
		_fail("Missing-band fixture did not select the procedural fallback")
		return
	var missing_image := await _capture(
		missing_fixture["canvas"],
		missing_fixture["viewport"]
	)
	if not _save(missing_image, output_dir.path_join(MISSING_NAME)):
		_fail("Missing-band procedural fallback capture failed")
		return
	await _dispose_fixture(missing_fixture)

	if FileAccess.file_exists(record_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(record_path))
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	print("[TowerMapScrollWiringVisualQA] output=%s" % output_dir)
	print("[TowerMapScrollWiringVisualQA] captures=9 primary_zoom=%0.2f world_width=%0.1f size=%dx%d route_states=%s fallback=procedural" % [
		float(gameplay_camera.get("render_zoom_multiplier", 0.0)),
		gameplay_world_rect.size.x,
		GAME_SIZE.x,
		GAME_SIZE.y,
		str(state_counts),
	])
	print("tower_map_scroll_wiring_visual_qa: ok")
	quit(0)


func _run_band_seam_only(output_dir: String) -> void:
	var fixture := _create_fixture("tower-map-band-seam-visual-qa", "", true)
	if fixture.is_empty():
		return
	var flow: Object = fixture["flow"]
	var canvas: CanvasItem = fixture["canvas"]
	var viewport: SubViewport = fixture["viewport"]
	var renderer := TowerAscentFlowRenderer.new()
	var fullscreen_image := await _capture(canvas, viewport)
	var seam_model := renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	if not _save(fullscreen_image, output_dir.path_join(BAND_SEAM_FULLSCREEN_NAME)):
		_fail("Band-seam fullscreen capture failed")
		return
	if not _save_live_seam_zoom(
		fullscreen_image,
		seam_model,
		output_dir.path_join(BAND_SEAM_LIVE_ZOOM_NAME)
	):
		_fail("Band-seam live zoom capture failed")
		return
	if not _save_live_map_bottom(
		fullscreen_image,
		seam_model,
		output_dir.path_join(BAND_SEAM_BOTTOM_NAME)
	):
		_fail("Band-seam live bottom capture failed")
		return
	var seam_probe := _build_band_seam_probe(seam_model)
	if not bool(seam_probe.get("ready", false)):
		_fail("Band-seam before/after measurement probe failed")
		return
	var minimum_pixel_scale := float(seam_probe.get("minimum_pixel_scale", -1.0))
	var maximum_pixel_scale := float(seam_probe.get("maximum_pixel_scale", -1.0))
	var crossfade_world_px := float(seam_probe.get("maximum_crossfade_world_px", -1.0))
	var source_guard_world_px := float(seam_probe.get("maximum_source_guard_world_px", -1.0))
	var reflected_tail_world_px := float(
		seam_probe.get("maximum_reflected_tail_world_px", -1.0)
	)
	var baseline_fold_screen_px := (
		BAND_SEAM_BASELINE_REFLECTED_TAIL_WORLD_PX * BAND_SEAM_FOLD_COMPARISON_ZOOM
	)
	var candidate_fold_screen_px := (
		reflected_tail_world_px * BAND_SEAM_FOLD_COMPARISON_ZOOM
	)
	if (
		not is_equal_approx(crossfade_world_px, BAND_SEAM_EXPECTED_CROSSFADE_WORLD_PX)
		or candidate_fold_screen_px >= baseline_fold_screen_px - 0.001
	):
		_fail(
			"Band-seam fold width must retain the 16px crossfade and improve on the 56px baseline"
		)
		return
	print(
		"[TowerMapBandFoldWidthQA] zoom=%.2f crossfade_world_px=%.1f source_guard_world_px=%.1f reflected_tail_world_px=%.1f candidate_screen_px=%.1f baseline_screen_px=%.1f improvement_px=%.1f improvement_pct=%.1f"
			% [
				BAND_SEAM_FOLD_COMPARISON_ZOOM,
				crossfade_world_px,
				source_guard_world_px,
				reflected_tail_world_px,
				candidate_fold_screen_px,
				baseline_fold_screen_px,
				baseline_fold_screen_px - candidate_fold_screen_px,
				(
					baseline_fold_screen_px - candidate_fold_screen_px
				) / baseline_fold_screen_px * 100.0,
			]
	)
	print(
		"[TowerMapBandArtScaleVisualQA] samples=%d minimum_scale=%.3f maximum_scale=%.3f"
			% [
				int(seam_probe.get("pixel_scale_sample_count", 0)),
				minimum_pixel_scale,
				maximum_pixel_scale,
			]
	)
	if absf(minimum_pixel_scale - 1.0) > 0.03 or absf(maximum_pixel_scale - 1.0) > 0.03:
		_fail(
			"Band art vertical pixel scale must stay at 1.0 across entries, bodies, and tails"
		)
		return
	var before_stack := seam_probe.get("before_image", null) as Image
	var after_stack := seam_probe.get("after_image", null) as Image
	if (
		not _save_any_size(before_stack, output_dir.path_join(BAND_SEAM_BEFORE_STACK_NAME))
		or not _save_any_size(after_stack, output_dir.path_join(BAND_SEAM_AFTER_STACK_NAME))
		or not _save_band_seam_compare(
			before_stack,
			after_stack,
			int(seam_probe.get("worst_seam_y", -1)),
			output_dir.path_join(BAND_SEAM_COMPARE_NAME)
		)
	):
		_fail("Band-seam measurement captures could not be saved")
		return
	var worst_hard_after_jump := 0.0
	var total_after_gutter_px := 0
	var maximum_after_gutter_px := 0
	for seam_variant in seam_probe.get("seams", []):
		var seam := seam_variant as Dictionary
		print(
			"[TowerMapBandSeamVisualQA] seam=%02d floor=%02d kind=%s before_jump=%0.2f after_jump=%0.2f before_gutter=%d@%d after_gutter=%d@%d"
				% [
					int(seam.get("index", -1)),
					int(seam.get("floor", -1)),
					str(seam.get("kind", "unknown")),
					float(seam.get("before_jump", -1.0)),
					float(seam.get("after_jump", -1.0)),
					int(seam.get("before_gutter", -1)),
					int(seam.get("before_gutter_offset", -999)),
					int(seam.get("after_gutter", -1)),
					int(seam.get("after_gutter_offset", -999)),
				]
		)
		total_after_gutter_px += int(seam.get("after_gutter", -1))
		maximum_after_gutter_px = maxi(
			maximum_after_gutter_px,
			int(seam.get("after_gutter", -1))
		)
		if str(seam.get("kind", "")) == "hard":
			worst_hard_after_jump = maxf(
				worst_hard_after_jump,
				float(seam.get("after_jump", INF))
			)
	if total_after_gutter_px != 0:
		_fail("Band-seam probe retained %d bright gutter pixels" % total_after_gutter_px)
		return
	if worst_hard_after_jump > 3.0:
		_fail(
			"Band-seam probe retained a hard luminance jump of %.2f"
				% worst_hard_after_jump
		)
		return
	print(
		"[TowerMapBandGutterBandQA] searched_seams=%d total_after_px=%d maximum_after_px=%d worst_hard_after_jump=%.2f"
			% [
				int((seam_probe.get("seams", []) as Array).size()),
				total_after_gutter_px,
				maximum_after_gutter_px,
				worst_hard_after_jump,
			]
	)
	await _dispose_fixture(fixture)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	print(
		"[TowerMapBandSeamVisualQA] output=%s captures=6 seams=%d"
			% [output_dir, int((seam_probe.get("seams", []) as Array).size())]
	)
	print("tower_map_band_seam_visual_qa: ok")
	quit(0)


func _run_edge_cull_only(output_dir: String) -> void:
	var fixture := _create_fixture("tower-map-edge-cull-visual-qa")
	if fixture.is_empty():
		return
	var flow: Object = fixture["flow"]
	var renderer := TowerAscentFlowRenderer.new()
	var initial_model := renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var initial_camera: Dictionary = initial_model.get("camera", {})
	var target_zoom := clampf(
		TowerAscentTuning.TEMP_MAP_CAMERA_ZOOM,
		float(initial_camera.get("minimum_fit_all_zoom", 1.0)),
		float(initial_camera.get("maximum_zoom", TowerAscentTuning.TEMP_MAP_CAMERA_ZOOM))
	)
	var drag_state: Object = flow.get("_map_drag_state")
	var best_requested_offset := Vector2.ZERO
	var best_score := -1
	for edge_variant in initial_model.get("edges", []):
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		var focus_world := (
			(edge.get("from_position", Vector2.ZERO) as Vector2)
			+ (edge.get("to_position", Vector2.ZERO) as Vector2)
		) * 0.5
		var requested_offset := VIEWPORT_RECT.get_center() - focus_world * target_zoom
		drag_state.call("apply_zoom_override", target_zoom, requested_offset)
		var frame_model := renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
		var frame_stats := _route_edge_cull_stats(renderer, flow, frame_model)
		var frame_score := (
			int(frame_stats.get("partial_edge_count", 0)) * 100000
			+ int(frame_stats.get("segment_intersection_visible_segments", 0))
			- int(frame_stats.get("endpoint_and_visible_segments", 0))
		)
		if frame_score > best_score:
			best_score = frame_score
			best_requested_offset = requested_offset
	if best_score < 0:
		_fail("Edge-cull QA could not evaluate the production overlay")
		return
	drag_state.call("apply_zoom_override", target_zoom, best_requested_offset)
	var model := renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var stats := _route_edge_cull_stats(renderer, flow, model)
	if int(stats.get("partial_edge_count", 0)) <= 0:
		_fail("Edge-cull QA could not find an offscreen-endpoint route crossing the viewport")
		return
	var image := await _capture(fixture["canvas"], fixture["viewport"])
	if not _save(image, output_dir.path_join(EDGE_CULL_FRAME_NAME)):
		_fail("Edge-cull production frame could not be saved")
		return
	var detail := _edge_cull_detail_crop(
		image,
		stats.get("first_partial_edge", {}) as Dictionary
	)
	if not _save_any_size(detail, output_dir.path_join(EDGE_CULL_DETAIL_NAME)):
		_fail("Edge-cull detail crop could not be saved")
		return
	await _dispose_fixture(fixture)
	print(
		"[TowerMapEdgeCullVisualQA] zoom=%.6f offset=%s partial_edges=%d endpoint_and_edges=%d segment_intersection_edges=%d renderer_edges=%d missed_edges=%d"
			% [
				target_zoom,
				str((model.get("camera", {}) as Dictionary).get("offset", Vector2.ZERO)),
				int(stats.get("partial_edge_count", -1)),
				int(stats.get("endpoint_and_drawn_edges", -1)),
				int(stats.get("segment_intersection_drawn_edges", -1)),
				int(stats.get("renderer_drawn_edges", -1)),
				int(stats.get("renderer_missed_partial_edges", -1)),
			]
	)
	print(
		"[TowerMapEdgeCullBudget] path_draw_call_budget=%d brush_segment_budget=%d endpoint_and_visible_segments=%d segment_intersection_visible_segments=%d renderer_visible_segments=%d"
			% [
				int(stats.get("path_draw_call_budget", -1)),
				int(stats.get("path_brush_draw_call_budget", -1)),
				int(stats.get("endpoint_and_visible_segments", -1)),
				int(stats.get("segment_intersection_visible_segments", -1)),
				int(stats.get("renderer_visible_segments", -1)),
			]
	)
	if int(stats.get("renderer_missed_partial_edges", 0)) > 0:
		_fail("Segment-crossing routes were dropped by endpoint-only culling")
		return
	if (
		int(stats.get("renderer_visible_segments", 0))
		> int(stats.get("path_brush_draw_call_budget", -1))
	):
		_fail("Visible route brushes exceeded the cached brush-segment budget")
		return
	print("[TowerMapEdgeCullVisualQA] output=%s captures=2 size=%dx%d" % [
		output_dir,
		GAME_SIZE.x,
		GAME_SIZE.y,
	])
	print("tower_map_edge_cull_visual_qa: ok")
	quit(0)


func _route_edge_cull_stats(
	renderer: Object,
	flow: Object,
	model: Dictionary
) -> Dictionary:
	var camera: Dictionary = model.get("camera", {})
	var route_history: Array = flow.get_route_history()
	var active_candidate_ids: Array = flow.get_route_target_ids()
	var current_node_id := str(flow.get_current_node_id())
	var endpoint_and_drawn_edges := 0
	var segment_intersection_drawn_edges := 0
	var renderer_drawn_edges := 0
	var endpoint_and_visible_segments := 0
	var segment_intersection_visible_segments := 0
	var renderer_visible_segments := 0
	var partial_edge_count := 0
	var renderer_missed_partial_edges := 0
	var first_partial_edge := {}
	for edge_variant in model.get("edges", []):
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		var asset_key: String = renderer.resolve_route_brush_asset_key(
			edge,
			route_history,
			active_candidate_ids,
			current_node_id
		)
		var completed := asset_key == TowerMapScrollAssetCatalog.ROUTE_BRUSH_COMPLETED_GOLD
		var from_screen := _edge_camera_screen_point(
			camera,
			edge.get("from_position", Vector2.ZERO) as Vector2
		)
		var to_screen := _edge_camera_screen_point(
			camera,
			edge.get("to_position", Vector2.ZERO) as Vector2
		)
		var endpoint_and_draws := completed or (
			VIEWPORT_RECT.has_point(from_screen)
			and VIEWPORT_RECT.has_point(to_screen)
		)
		var segment_intersection_draws := completed or _edge_segment_intersects_rect(
			from_screen,
			to_screen,
			VIEWPORT_RECT
		)
		var renderer_draws: bool = renderer.should_draw_route_edge_in_view(
			edge,
			asset_key,
			VIEWPORT_RECT,
			camera
		)
		var quads: Array = edge.get(
			"completed_brush_quads" if completed else "brush_quads",
			[]
		)
		var visible_segments := _visible_route_brush_segment_count(quads, camera)
		if endpoint_and_draws:
			endpoint_and_drawn_edges += 1
			endpoint_and_visible_segments += visible_segments
		if segment_intersection_draws:
			segment_intersection_drawn_edges += 1
			segment_intersection_visible_segments += visible_segments
		if renderer_draws:
			renderer_drawn_edges += 1
			renderer_visible_segments += visible_segments
		if segment_intersection_draws and not endpoint_and_draws and not completed:
			partial_edge_count += 1
			if first_partial_edge.is_empty():
				first_partial_edge = {
					"from_screen": from_screen,
					"to_screen": to_screen,
				}
			if not renderer_draws:
				renderer_missed_partial_edges += 1
	var debug_state: Dictionary = renderer.get_render_cache_debug_state()
	return {
		"endpoint_and_drawn_edges": endpoint_and_drawn_edges,
		"segment_intersection_drawn_edges": segment_intersection_drawn_edges,
		"renderer_drawn_edges": renderer_drawn_edges,
		"endpoint_and_visible_segments": endpoint_and_visible_segments,
		"segment_intersection_visible_segments": segment_intersection_visible_segments,
		"renderer_visible_segments": renderer_visible_segments,
		"partial_edge_count": partial_edge_count,
		"renderer_missed_partial_edges": renderer_missed_partial_edges,
		"first_partial_edge": first_partial_edge,
		"path_draw_call_budget": int(debug_state.get("path_draw_call_budget", -1)),
		"path_brush_draw_call_budget": int(
			debug_state.get("path_brush_draw_call_budget", -1)
		),
	}


func _edge_camera_screen_point(camera: Dictionary, point: Vector2) -> Vector2:
	var zoom := maxf(
		0.001,
		float(camera.get("render_zoom_multiplier", camera.get("zoom_multiplier", 1.0)))
	)
	return point * zoom + (camera.get("offset", Vector2.ZERO) as Vector2)


func _edge_segment_intersects_rect(from_pos: Vector2, to_pos: Vector2, rect: Rect2) -> bool:
	if rect.has_point(from_pos) or rect.has_point(to_pos):
		return true
	var top_left: Vector2 = rect.position
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_right: Vector2 = rect.end
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	return (
		Geometry2D.segment_intersects_segment(from_pos, to_pos, top_left, top_right) != null
		or Geometry2D.segment_intersects_segment(from_pos, to_pos, top_right, bottom_right) != null
		or Geometry2D.segment_intersects_segment(from_pos, to_pos, bottom_right, bottom_left) != null
		or Geometry2D.segment_intersects_segment(from_pos, to_pos, bottom_left, top_left) != null
	)


func _visible_route_brush_segment_count(quads: Array, camera: Dictionary) -> int:
	var count := 0
	for quad_variant in quads:
		if not (quad_variant is Dictionary):
			continue
		var points: PackedVector2Array = (quad_variant as Dictionary).get(
			"points",
			PackedVector2Array()
		)
		var screen_points := PackedVector2Array()
		for point in points:
			screen_points.append(_edge_camera_screen_point(camera, point))
		if _edge_points_bounds(screen_points).intersects(VIEWPORT_RECT):
			count += 1
	return count


func _edge_points_bounds(points: PackedVector2Array) -> Rect2:
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


func _edge_cull_detail_crop(image: Image, edge: Dictionary) -> Image:
	if image == null or image.is_empty() or edge.is_empty():
		return Image.new()
	var from_screen: Vector2 = edge.get("from_screen", VIEWPORT_RECT.get_center())
	var to_screen: Vector2 = edge.get("to_screen", VIEWPORT_RECT.get_center())
	var anchor := VIEWPORT_RECT.get_center()
	var top_left: Vector2 = VIEWPORT_RECT.position
	var top_right := Vector2(VIEWPORT_RECT.end.x, VIEWPORT_RECT.position.y)
	var bottom_right: Vector2 = VIEWPORT_RECT.end
	var bottom_left := Vector2(VIEWPORT_RECT.position.x, VIEWPORT_RECT.end.y)
	for boundary in [
		[top_left, top_right],
		[top_right, bottom_right],
		[bottom_right, bottom_left],
		[bottom_left, top_left],
	]:
		var intersection: Variant = Geometry2D.segment_intersects_segment(
			from_screen,
			to_screen,
			boundary[0] as Vector2,
			boundary[1] as Vector2
		)
		if intersection is Vector2:
			anchor = intersection as Vector2
			break
	var crop_size := Vector2i(560, 320)
	var crop_position := Vector2i(
		clampi(int(round(anchor.x)) - crop_size.x / 2, 0, GAME_SIZE.x - crop_size.x),
		clampi(int(round(anchor.y)) - crop_size.y / 2, 0, GAME_SIZE.y - crop_size.y)
	)
	var detail := image.get_region(Rect2i(crop_position, crop_size))
	detail.resize(crop_size.x * 2, crop_size.y * 2, Image.INTERPOLATE_NEAREST)
	return detail


func _create_fixture(
	run_id: String,
	record_path: String = "",
	load_raw_band_sources: bool = false
) -> Dictionary:
	var flow := TowerAscentFlowOwner.new()
	if not record_path.is_empty():
		flow.set_record_store_path_for_tests(record_path)
	if load_raw_band_sources:
		# PNG promotion is intentionally materialized by the editor after landing.
		# The isolated Vulkan lane must nevertheless measure the exact source bytes
		# under review instead of a same-path imported cache from the parent commit.
		flow.set("_map_scroll_asset_catalog", _create_raw_band_source_catalog())
	var registry := TowerMapOverlayVisualQa.CaptureRegistry.new(flow)
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := TowerMapOverlayVisualQa.ProductionScreenCanvas.new(registry)
	viewport.add_child(canvas)
	if not flow.open_map_overlay(canvas, registry, {
		"run_id": run_id,
		"current_stage": 4,
		"map_seed": 83521,
	}):
		_fail("Production map surface could not open for %s" % run_id)
		return {}
	flow.set_map_overlay_fade_progress_for_qa(1.0)
	return {
		"flow": flow,
		"registry": registry,
		"viewport": viewport,
		"canvas": canvas,
	}


func _create_raw_band_source_catalog() -> RefCounted:
	var canonical := TowerMapScrollAssetCatalog.new()
	var raw_band_paths := {}
	for asset_key in (
		TowerMapScrollAssetCatalog.HUMAN_BAND_ASSET_KEYS
		+ TowerMapScrollAssetCatalog.IMMORTAL_BAND_ASSET_KEYS
	):
		raw_band_paths[canonical.resolve_declared_path(asset_key)] = true
	return TowerMapScrollAssetCatalog.new(
		func(path: String) -> bool:
			return (
				FileAccess.file_exists(path)
				if raw_band_paths.has(path)
				else ResourceLoader.exists(path, "Texture2D")
			),
		func(path: String) -> Resource:
			return (
				_load_raw_png_texture(path)
				if raw_band_paths.has(path)
				else ResourceLoader.load(path, "Texture2D")
			)
	)


func _load_raw_png_texture(path: String) -> Texture2D:
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _prepare_gameplay_zoom_fixture(fixture: Dictionary) -> bool:
	var flow: Object = fixture.get("flow", null)
	if flow == null:
		_fail("Gameplay zoom fixture has no flow owner")
		return false
	var source_id := _node_id_for_floor(flow, 4)
	if source_id.is_empty():
		_fail("Gameplay zoom fixture could not locate its source floor")
		return false
	var target_ids: Array = flow.call("_outgoing_target_ids", source_id)
	if target_ids.is_empty():
		_fail("Gameplay zoom fixture has no outgoing route")
		return false
	flow.set("_current_node_id", source_id)
	flow.set("_route_source_node_id", source_id)
	flow.set("_route_target_ids", target_ids.duplicate())
	flow.call("_refresh_route_target_cache")
	flow.close_map_overlay()
	flow.call("_finish_map_overlay_close")
	flow.call("_resolve_route_target", str(target_ids[0]))
	if flow.get_phase_name() != "MAP_TRANSITION":
		_fail("Gameplay zoom fixture did not enter the production map transition")
		return false
	flow.set_transition_progress_for_qa(_gameplay_zoom_progress())
	return true


func _gameplay_zoom_progress() -> float:
	var battle := TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
	var map_in := TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
	return (battle + map_in) / _transition_duration_sec()


func _transition_duration_sec() -> float:
	return (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)


func _create_missing_band_fixture() -> Dictionary:
	var canonical := TowerMapScrollAssetCatalog.new()
	var missing_path := canonical.resolve_declared_path(
		TowerMapScrollAssetCatalog.HUMAN_BAND_ASSET_KEYS[1]
	)
	var missing_catalog := TowerMapScrollAssetCatalog.new(
		func(path: String) -> bool:
			return path != missing_path and ResourceLoader.exists(path, "Texture2D"),
		func(path: String) -> Resource:
			return ResourceLoader.load(path, "Texture2D")
	)
	var flow := TowerAscentFlowOwner.new()
	flow.set("_map_scroll_asset_catalog", missing_catalog)
	var registry := TowerMapOverlayVisualQa.CaptureRegistry.new(flow)
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := TowerMapOverlayVisualQa.ProductionScreenCanvas.new(registry)
	viewport.add_child(canvas)
	if not flow.open_map_overlay(canvas, registry, {
		"run_id": "tower-map-scroll-missing-band",
		"current_stage": 4,
		"map_seed": 83521,
	}):
		_fail("Missing-band production map surface could not open")
		return {}
	flow.set_map_overlay_fade_progress_for_qa(1.0)
	return {
		"flow": flow,
		"registry": registry,
		"viewport": viewport,
		"canvas": canvas,
	}


func _node_id_for_floor(flow: Object, floor_number: int) -> String:
	for node_variant in flow.get_graph_nodes():
		if node_variant is Dictionary and int((node_variant as Dictionary).get("floor", 0)) == floor_number:
			return str((node_variant as Dictionary).get("id", ""))
	return ""


func _decorate_three_route_states(flow: Object, current_node_id: String) -> bool:
	var outgoing: Array = flow.call("_outgoing_target_ids", current_node_id)
	if outgoing.is_empty():
		return false
	var completed_edge: Dictionary = {}
	for edge_variant in flow.get_graph_edges():
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		if str(edge.get("to", "")) == current_node_id:
			completed_edge = edge
			break
	if completed_edge.is_empty():
		return false
	flow.set("_current_node_id", current_node_id)
	flow.set("_route_source_node_id", current_node_id)
	flow.set("_route_target_ids", outgoing.duplicate())
	flow.set("_available_route_target_ids", outgoing.duplicate())
	var route_history: Array = flow.get("_route_history")
	route_history.clear()
	route_history.append({
		"from": str(completed_edge.get("from", "")),
		"to": str(completed_edge.get("to", "")),
	})
	return true


func _route_state_counts(flow: Object, renderer: Object) -> Dictionary:
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var counts: Dictionary = {}
	for edge_variant in model.get("edges", []):
		if not (edge_variant is Dictionary):
			continue
		var asset_key: String = renderer.resolve_route_brush_asset_key(
			edge_variant as Dictionary,
			flow.get_route_history(),
			flow.get_route_target_ids(),
			flow.get_current_node_id()
		)
		counts[asset_key] = int(counts.get(asset_key, 0)) + 1
	return counts


func _capture(canvas: CanvasItem, viewport: SubViewport) -> Image:
	canvas.queue_redraw()
	for _frame_index in range(6):
		await process_frame
	return viewport.get_texture().get_image()


func _save(image: Image, path: String) -> bool:
	return (
		image != null
		and not image.is_empty()
		and image.get_size() == GAME_SIZE
		and image.save_png(path) == OK
	)


func _save_any_size(image: Image, path: String) -> bool:
	return image != null and not image.is_empty() and image.save_png(path) == OK


func _save_live_seam_zoom(image: Image, model: Dictionary, output_path: String) -> bool:
	var background: Dictionary = model.get("scroll_background", {})
	var draw_chunks: Array = background.get("draw_chunks", [])
	var content_rect: Rect2 = model.get("content_rect", Rect2())
	var camera: Dictionary = model.get("camera", {})
	var camera_offset: Vector2 = camera.get("offset", Vector2.ZERO)
	var camera_zoom := float(camera.get("render_zoom_multiplier", 1.0))
	var chosen_y := -1.0
	var closest_distance := INF
	for chunk_index in range(1, draw_chunks.size()):
		var chunk := draw_chunks[chunk_index] as Dictionary
		var chunk_rect: Rect2 = chunk.get("paper_rect", chunk.get("rect", Rect2()))
		var projected_y := chunk_rect.position.y * camera_zoom + camera_offset.y
		if projected_y < content_rect.position.y + 48.0 or projected_y > content_rect.end.y - 48.0:
			continue
		var distance := absf(projected_y - content_rect.get_center().y)
		if distance < closest_distance:
			closest_distance = distance
			chosen_y = projected_y
	if chosen_y < 0.0:
		return false
	var crop_rect := Rect2i(
		Vector2i(
			maxi(0, int(floor(content_rect.position.x))),
			maxi(0, int(floor(chosen_y)) - 48)
		),
		Vector2i(
			mini(image.get_width(), int(ceil(content_rect.end.x)))
				- maxi(0, int(floor(content_rect.position.x))),
			96
		)
	)
	crop_rect.size.y = mini(crop_rect.size.y, image.get_height() - crop_rect.position.y)
	if crop_rect.size.x <= 0 or crop_rect.size.y <= 0:
		return false
	var zoom := image.get_region(crop_rect)
	zoom.resize(zoom.get_width() * 2, zoom.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return _save_any_size(zoom, output_path)


func _save_live_map_bottom(image: Image, model: Dictionary, output_path: String) -> bool:
	var content_rect: Rect2 = model.get("content_rect", Rect2())
	var crop_height := mini(192, int(floor(content_rect.size.y)))
	var crop_rect := Rect2i(
		Vector2i(
			maxi(0, int(floor(content_rect.position.x))),
			maxi(0, int(floor(content_rect.end.y)) - crop_height)
		),
		Vector2i(
			mini(image.get_width(), int(ceil(content_rect.end.x)))
				- maxi(0, int(floor(content_rect.position.x))),
			crop_height
		)
	)
	crop_rect.size.y = mini(crop_rect.size.y, image.get_height() - crop_rect.position.y)
	if crop_rect.size.x <= 0 or crop_rect.size.y <= 0:
		return false
	var bottom := image.get_region(crop_rect)
	bottom.resize(bottom.get_width() * 2, bottom.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return _save_any_size(bottom, output_path)


func _build_band_seam_probe(model: Dictionary) -> Dictionary:
	var background: Dictionary = model.get("scroll_background", {})
	var draw_chunks: Array = background.get("draw_chunks", [])
	var tiles: Array = background.get("tiles", [])
	if draw_chunks.size() != BAND_SEAM_EXPECTED_PRODUCTION_CHUNK_COUNT or tiles.is_empty():
		return {"ready": false}
	var tile_rect: Rect2 = (tiles[0] as Dictionary).get("rect", Rect2())
	var map_scale := tile_rect.size.x / 692.0
	if map_scale <= 0.0:
		return {"ready": false}
	var stack_world_rect: Rect2 = background.get("world_rect", Rect2())
	var stack_size := Vector2i(
		int(round(stack_world_rect.size.x / map_scale)),
		int(round(stack_world_rect.size.y / map_scale))
	)
	var before_image := _compose_band_stack(draw_chunks, stack_world_rect, map_scale, false)
	var after_image := _compose_band_stack(draw_chunks, stack_world_rect, map_scale, true)
	if before_image.is_empty() or after_image.is_empty() or before_image.get_size() != stack_size or after_image.get_size() != stack_size:
		return {"ready": false}
	var before_rows := _measure_row_luma(before_image)
	var after_rows := _measure_row_luma(after_image)
	var before_details := _measure_row_detail(before_image)
	var after_details := _measure_row_detail(after_image)
	var pixel_scale_probe := _measure_band_art_pixel_scales(draw_chunks, map_scale)
	if not bool(pixel_scale_probe.get("ready", false)):
		return {"ready": false}
	var maximum_crossfade_world_px := 0.0
	var maximum_source_guard_world_px := 0.0
	var maximum_reflected_tail_world_px := 0.0
	for chunk_variant in draw_chunks:
		var measured_chunk := chunk_variant as Dictionary
		maximum_crossfade_world_px = maxf(
			maximum_crossfade_world_px,
			float(measured_chunk.get("alpha_ramp_world_px", 0.0)) / map_scale
		)
		maximum_source_guard_world_px = maxf(
			maximum_source_guard_world_px,
			float(measured_chunk.get("source_edge_guard_world_px", 0.0)) / map_scale
		)
		maximum_reflected_tail_world_px = maxf(
			maximum_reflected_tail_world_px,
			float(measured_chunk.get("reflected_tail_world_px", 0.0)) / map_scale
		)
	var seams: Array[Dictionary] = []
	var worst_jump := -1.0
	var worst_seam_y := -1
	for chunk_index in range(1, draw_chunks.size()):
		var chunk := draw_chunks[chunk_index] as Dictionary
		var chunk_rect: Rect2 = chunk.get("paper_rect", chunk.get("rect", Rect2()))
		var seam_y := int(round((chunk_rect.position.y - stack_world_rect.position.y) / map_scale))
		if seam_y <= 0 or seam_y >= before_rows.size():
			continue
		var before_jump := absf(float(before_rows[seam_y]) - float(before_rows[seam_y - 1]))
		var after_jump := absf(float(after_rows[seam_y]) - float(after_rows[seam_y - 1]))
		var search_radius := maxi(
			1,
			int(round(float(chunk.get("alpha_ramp_world_px", 0.0)) / map_scale))
		)
		var before_gutter := _measure_bright_gutter_band(
			before_rows,
			before_details,
			seam_y,
			search_radius
		)
		var after_gutter := _measure_bright_gutter_band(
			after_rows,
			after_details,
			seam_y,
			search_radius
		)
		var seam := {
			"index": chunk_index,
			"floor": int(chunk.get("floor", -1)),
			"kind": "hard" if before_jump >= 20.0 else "soft",
			"y": seam_y,
			"before_jump": before_jump,
			"after_jump": after_jump,
			"before_gutter": int(before_gutter.get("width", 0)),
			"before_gutter_offset": int(before_gutter.get("center_offset", 0)),
			"after_gutter": int(after_gutter.get("width", 0)),
			"after_gutter_offset": int(after_gutter.get("center_offset", 0)),
		}
		seams.append(seam)
		if before_jump > worst_jump:
			worst_jump = before_jump
			worst_seam_y = seam_y
	return {
		"ready": seams.size() == BAND_SEAM_EXPECTED_PRODUCTION_SEAM_COUNT,
		"before_image": before_image,
		"after_image": after_image,
		"seams": seams,
		"worst_seam_y": worst_seam_y,
		"minimum_pixel_scale": float(pixel_scale_probe.get("minimum_scale", -1.0)),
		"maximum_pixel_scale": float(pixel_scale_probe.get("maximum_scale", -1.0)),
		"pixel_scale_sample_count": int(pixel_scale_probe.get("sample_count", 0)),
		"maximum_crossfade_world_px": maximum_crossfade_world_px,
		"maximum_source_guard_world_px": maximum_source_guard_world_px,
		"maximum_reflected_tail_world_px": maximum_reflected_tail_world_px,
	}


func _compose_band_stack(
	draw_chunks: Array,
	stack_world_rect: Rect2,
	map_scale: float,
	crossfade: bool
) -> Image:
	var stack_size := Vector2i(
		int(round(stack_world_rect.size.x / map_scale)),
		int(round(stack_world_rect.size.y / map_scale))
	)
	var stack := Image.create(stack_size.x, stack_size.y, false, Image.FORMAT_RGBA8)
	stack.fill(Color("f1dfb8"))
	var resize_cache := {}
	if crossfade:
		for chunk_variant in draw_chunks:
			var chunk := chunk_variant as Dictionary
			var draw_rect := _normalized_chunk_rect(
				chunk.get("paper_rect", chunk.get("rect", Rect2())),
				stack_world_rect,
				map_scale
			)
			var paper := _resized_texture_region(
				chunk.get("paper_texture", null) as Texture2D,
				chunk.get("paper_source_rect", Rect2(0.0, 0.0, 1.0, 1.0)),
				draw_rect.size,
				resize_cache
			)
			if not paper.is_empty():
				stack.blit_rect(paper, Rect2i(Vector2i.ZERO, paper.get_size()), draw_rect.position)
	for chunk_variant in draw_chunks:
		var chunk := chunk_variant as Dictionary
		var source_rect: Rect2 = chunk.get("normalized_source_rect", Rect2(0.0, 0.0, 1.0, 1.0))
		var chunk_world_rect: Rect2 = chunk.get("rect", Rect2())
		if crossfade:
			var tail_target := _normalized_chunk_rect(
				chunk.get("seam_tail_rect", Rect2()),
				stack_world_rect,
				map_scale
			)
			var tail := _resized_texture_region(
				chunk.get("texture", null) as Texture2D,
				chunk.get("seam_tail_source_rect", Rect2()),
				tail_target.size,
				resize_cache
			)
			if not tail.is_empty():
				tail = tail.duplicate()
				tail.flip_y()
				stack.blit_rect(
					tail,
					Rect2i(Vector2i.ZERO, tail.get_size()),
					tail_target.position
				)
			var entry_target := _normalized_chunk_rect(
				chunk.get("seam_entry_rect", Rect2()),
				stack_world_rect,
				map_scale
			)
			var entry := _resized_texture_region(
				chunk.get("texture", null) as Texture2D,
				chunk.get("seam_entry_source_rect", Rect2()),
				entry_target.size,
				resize_cache
			)
			if not entry.is_empty():
				entry = entry.duplicate()
				entry.flip_y()
				var entry_mask := _vertical_alpha_mask(
					entry.get_width(),
					entry.get_height(),
					entry.get_height()
				)
				stack.blend_rect_mask(
					entry,
					entry_mask,
					Rect2i(Vector2i.ZERO, entry.get_size()),
					entry_target.position
				)
		else:
			chunk_world_rect = chunk.get("paper_rect", chunk_world_rect)
			source_rect = chunk.get("paper_source_rect", source_rect)
		var target_rect := _normalized_chunk_rect(
			chunk_world_rect,
			stack_world_rect,
			map_scale
		)
		var band := _resized_texture_region(
			chunk.get("texture", null) as Texture2D,
			source_rect,
			target_rect.size,
			resize_cache
		)
		if band.is_empty():
			return Image.new()
		stack.blit_rect(band, Rect2i(Vector2i.ZERO, band.get_size()), target_rect.position)
	return stack


func _normalized_chunk_rect(rect: Rect2, stack_world_rect: Rect2, map_scale: float) -> Rect2i:
	return Rect2i(
		Vector2i(
			int(round((rect.position.x - stack_world_rect.position.x) / map_scale)),
			int(round((rect.position.y - stack_world_rect.position.y) / map_scale))
		),
		Vector2i(
			int(round(rect.size.x / map_scale)),
			int(round(rect.size.y / map_scale))
		)
	)


func _resized_texture_region(
	texture: Texture2D,
	normalized_source_rect: Rect2,
	target_size: Vector2i,
	resize_cache: Dictionary
) -> Image:
	if texture == null or target_size.x <= 0 or target_size.y <= 0:
		return Image.new()
	var cache_key := "%s|%s|%s" % [texture.resource_path, str(normalized_source_rect), str(target_size)]
	if resize_cache.has(cache_key):
		return resize_cache[cache_key] as Image
	var source := texture.get_image()
	if source == null or source.is_empty():
		return Image.new()
	if source.is_compressed() and source.decompress() != OK:
		return Image.new()
	source.convert(Image.FORMAT_RGBA8)
	var source_rect := Rect2i(
		Vector2i(
			int(round(normalized_source_rect.position.x * source.get_width())),
			int(round(normalized_source_rect.position.y * source.get_height()))
		),
		Vector2i(
			int(round(normalized_source_rect.size.x * source.get_width())),
			int(round(normalized_source_rect.size.y * source.get_height()))
		)
	)
	var resized := source.get_region(source_rect)
	resized.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	resize_cache[cache_key] = resized
	return resized


func _measure_band_art_pixel_scales(draw_chunks: Array, map_scale: float) -> Dictionary:
	var minimum_scale := INF
	var maximum_scale := -INF
	var sample_count := 0
	for chunk_variant in draw_chunks:
		var chunk := chunk_variant as Dictionary
		var texture := chunk.get("texture", null) as Texture2D
		var body_size := _normalized_chunk_rect(
			chunk.get("rect", Rect2()),
			Rect2(Vector2.ZERO, Vector2.ZERO),
			map_scale
		).size
		var body_scale := _estimate_texture_region_pixel_vertical_scale(
			texture,
			chunk.get("normalized_source_rect", Rect2()),
			body_size
		)
		if body_scale < 0.0:
			return {"ready": false}
		minimum_scale = minf(minimum_scale, body_scale)
		maximum_scale = maxf(maximum_scale, body_scale)
		sample_count += 1
		var entry_rect: Rect2 = chunk.get("seam_entry_rect", Rect2())
		if entry_rect.has_area():
			var entry_size := Vector2i(
				int(round(entry_rect.size.x / map_scale)),
				int(round(entry_rect.size.y / map_scale))
			)
			var entry_scale := _estimate_texture_region_pixel_vertical_scale(
				texture,
				chunk.get("seam_entry_source_rect", Rect2()),
				entry_size
			)
			if entry_scale < 0.0:
				return {"ready": false}
			minimum_scale = minf(minimum_scale, entry_scale)
			maximum_scale = maxf(maximum_scale, entry_scale)
			sample_count += 1
		var tail_rect: Rect2 = chunk.get("seam_tail_rect", Rect2())
		if tail_rect.has_area():
			var tail_size := Vector2i(
				int(round(tail_rect.size.x / map_scale)),
				int(round(tail_rect.size.y / map_scale))
			)
			var tail_scale := _estimate_texture_region_pixel_vertical_scale(
				texture,
				chunk.get("seam_tail_source_rect", Rect2()),
				tail_size
			)
			if tail_scale < 0.0:
				return {"ready": false}
			minimum_scale = minf(minimum_scale, tail_scale)
			maximum_scale = maxf(maximum_scale, tail_scale)
			sample_count += 1
	return {
		"ready": sample_count == draw_chunks.size() * 3 - 2,
		"minimum_scale": minimum_scale,
		"maximum_scale": maximum_scale,
		"sample_count": sample_count,
	}


func _estimate_texture_region_pixel_vertical_scale(
	texture: Texture2D,
	normalized_source_rect: Rect2,
	target_size: Vector2i
) -> float:
	if texture == null or target_size.x <= 0 or target_size.y <= 0:
		return -1.0
	var source := texture.get_image()
	if source == null or source.is_empty():
		return -1.0
	if source.is_compressed() and source.decompress() != OK:
		return -1.0
	source.convert(Image.FORMAT_RGBA8)
	var source_rect := Rect2i(
		Vector2i(
			int(round(normalized_source_rect.position.x * source.get_width())),
			int(round(normalized_source_rect.position.y * source.get_height()))
		),
		Vector2i(
			int(round(normalized_source_rect.size.x * source.get_width())),
			int(round(normalized_source_rect.size.y * source.get_height()))
		)
	)
	if (
		source_rect.position.x < 0
		or source_rect.position.y < 0
		or source_rect.end.x > source.get_width()
		or source_rect.end.y > source.get_height()
		or not source_rect.has_area()
	):
		return -1.0
	var source_region := source.get_region(source_rect)
	var source_density := float(source_region.get_width()) / float(target_size.x)
	if source_density <= 0.0:
		return -1.0
	var natural_height := maxi(2, int(round(float(source_region.get_height()) / source_density)))
	var preview_width := 24
	var source_preview := source_region.duplicate()
	source_preview.resize(preview_width, natural_height, Image.INTERPOLATE_LANCZOS)
	var rendered_preview := source_region.duplicate()
	rendered_preview.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	rendered_preview.resize(preview_width, target_size.y, Image.INTERPOLATE_LANCZOS)
	var best_scale := -1.0
	var best_error := INF
	for scale_step in range(76):
		var candidate_scale := 0.80 + float(scale_step) * 0.01
		if int(round(float(natural_height - 1) * candidate_scale)) >= rendered_preview.get_height():
			continue
		var error_sum := 0.0
		var sample_total := 0
		for source_y in range(1, natural_height - 1):
			var target_y := int(round(float(source_y) * candidate_scale))
			for x in range(preview_width):
				var expected: Color = source_preview.get_pixel(x, source_y)
				var observed: Color = rendered_preview.get_pixel(x, target_y)
				error_sum += (
					absf(expected.r - observed.r)
					+ absf(expected.g - observed.g)
					+ absf(expected.b - observed.b)
				) / 3.0
				sample_total += 1
		var fill_error := absf(
			float(rendered_preview.get_height() - 1)
				- float(natural_height - 1) * candidate_scale
		) / float(maxi(1, rendered_preview.get_height() - 1))
		var mean_error := error_sum / float(maxi(1, sample_total)) + fill_error * 0.05
		if mean_error < best_error:
			best_error = mean_error
			best_scale = candidate_scale
	return best_scale


func _measure_row_luma(image: Image) -> PackedFloat32Array:
	var row_sample := image.duplicate()
	row_sample.resize(1, image.get_height(), Image.INTERPOLATE_LANCZOS)
	var rows := PackedFloat32Array()
	rows.resize(image.get_height())
	for y in range(image.get_height()):
		var pixel: Color = row_sample.get_pixel(0, y)
		rows[y] = (0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b) * 255.0
	return rows


func _measure_row_detail(image: Image) -> PackedFloat32Array:
	var sample := image.duplicate()
	sample.resize(64, image.get_height(), Image.INTERPOLATE_LANCZOS)
	var rows := PackedFloat32Array()
	rows.resize(image.get_height())
	for y in range(image.get_height()):
		var mean := 0.0
		for x in range(sample.get_width()):
			var pixel: Color = sample.get_pixel(x, y)
			mean += 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b
		mean /= float(sample.get_width())
		var variance := 0.0
		for x in range(sample.get_width()):
			var pixel: Color = sample.get_pixel(x, y)
			var luma := 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b
			variance += (luma - mean) * (luma - mean)
		rows[y] = sqrt(variance / float(sample.get_width())) * 255.0
	return rows


func _vertical_alpha_mask(width: int, height: int, fade_height: int) -> Image:
	var mask := Image.create(1, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		var alpha := clampf(float(y) / float(maxi(1, fade_height)), 0.0, 1.0)
		mask.set_pixel(0, y, Color(1.0, 1.0, 1.0, alpha))
	mask.resize(width, height, Image.INTERPOLATE_NEAREST)
	return mask


func _measure_bright_gutter_band(
	rows: PackedFloat32Array,
	details: PackedFloat32Array,
	seam_y: int,
	search_radius: int
) -> Dictionary:
	var minimum_y := maxi(0, seam_y - search_radius)
	var maximum_y := mini(rows.size(), seam_y + search_radius + 1)
	var local_luma: Array[float] = []
	for y in range(minimum_y, maximum_y):
		local_luma.append(float(rows[y]))
	local_luma.sort()
	var local_reference := (
		float(local_luma[int(floor(float(local_luma.size() - 1) * 0.25))])
		if not local_luma.is_empty()
		else BAND_SEAM_BRIGHT_LUMA_THRESHOLD
	)
	var adaptive_threshold := maxf(
		BAND_SEAM_BRIGHT_LUMA_THRESHOLD,
		local_reference + 12.0
	)
	var run_start := -1
	var best_start := -1
	var best_end := -1
	for y in range(minimum_y, maximum_y + 1):
		var bright := (
			y < maximum_y
			and float(rows[y]) >= adaptive_threshold
			and float(details[y]) <= 18.0
		)
		if bright and run_start < 0:
			run_start = y
		elif not bright and run_start >= 0:
			if y - run_start > best_end - best_start:
				best_start = run_start
				best_end = y
			run_start = -1
	if best_start < 0 or best_end - best_start < BAND_SEAM_MIN_GUTTER_WIDTH_PX:
		return {"width": 0, "center_offset": 0}
	return {
		"width": best_end - best_start,
		"center_offset": int(round((best_start + best_end - 1) * 0.5)) - seam_y,
	}


func _save_band_seam_compare(
	before_image: Image,
	after_image: Image,
	seam_y: int,
	output_path: String
) -> bool:
	if seam_y < 0:
		return false
	var crop_y := clampi(seam_y - 64, 0, before_image.get_height() - 128)
	var crop_rect := Rect2i(0, crop_y, before_image.get_width(), 128)
	var before_crop := before_image.get_region(crop_rect)
	var after_crop := after_image.get_region(crop_rect)
	before_crop.resize(before_crop.get_width() * 2, before_crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
	after_crop.resize(after_crop.get_width() * 2, after_crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var compare := Image.create(
		before_crop.get_width() * 2,
		before_crop.get_height(),
		false,
		Image.FORMAT_RGBA8
	)
	compare.blit_rect(before_crop, Rect2i(Vector2i.ZERO, before_crop.get_size()), Vector2i.ZERO)
	compare.blit_rect(
		after_crop,
		Rect2i(Vector2i.ZERO, after_crop.get_size()),
		Vector2i(before_crop.get_width(), 0)
	)
	return _save_any_size(compare, output_path)


func _save_candidate_live_compare(
	band_paths: Array,
	live_image: Image,
	output_path: String
) -> bool:
	var contact := Image.create(692, 960, false, Image.FORMAT_RGBA8)
	contact.fill(Color("f1dfb8"))
	for index in range(band_paths.size()):
		var band := Image.load_from_file(ProjectSettings.globalize_path(str(band_paths[index])))
		if band == null or band.is_empty() or band.get_size() != Vector2i(692, 320):
			return false
		band.convert(Image.FORMAT_RGBA8)
		contact.blit_rect(band, Rect2i(Vector2i.ZERO, band.get_size()), Vector2i(0, index * 320))
	var contact_size := Vector2i(
		int(round(692.0 * float(GAME_SIZE.y) / 960.0)),
		GAME_SIZE.y
	)
	contact.resize(contact_size.x, contact_size.y, Image.INTERPOLATE_LANCZOS)
	var comparison := Image.create(GAME_SIZE.x * 2, GAME_SIZE.y, false, Image.FORMAT_RGBA8)
	comparison.fill(Color("f1dfb8"))
	var live_copy := live_image.duplicate()
	live_copy.convert(Image.FORMAT_RGBA8)
	comparison.blit_rect(
		contact,
		Rect2i(Vector2i.ZERO, contact.get_size()),
		Vector2i((GAME_SIZE.x - contact_size.x) / 2, 0)
	)
	comparison.blit_rect(
		live_copy,
		Rect2i(Vector2i.ZERO, live_copy.get_size()),
		Vector2i(GAME_SIZE.x, 0)
	)
	return comparison.save_png(output_path) == OK


func _dispose_fixture(fixture: Dictionary) -> void:
	var flow: Object = fixture.get("flow", null)
	if flow != null and flow.has_method("is_map_overlay_active") and flow.is_map_overlay_active():
		flow.close_map_overlay()
	if flow != null and flow.has_method("is_active") and flow.is_active():
		flow.call("_finish_vertical_slice")
	var viewport := fixture.get("viewport", null) as SubViewport
	if viewport != null:
		get_root().remove_child(viewport)
		viewport.free()
	await process_frame
	await process_frame


func _fail(message: String) -> void:
	if _failure.is_empty():
		_failure = message
	push_error(message)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	quit(1)
