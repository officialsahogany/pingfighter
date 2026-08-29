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
const BAND_SEAM_Z13_DIR_NAME := "z13_tileable_wrap"
const BAND_SEAM_FULLSCREEN_NAME := "10_z13_live_fullscreen.png"
const BAND_SEAM_STACK_NAME := "11_z13_composed_full_stack.png"
const BAND_SEAM_SAME_ART_PROBE_NAME := "12_z13_same_art_river_butt_probe.png"
const BAND_SEAM_DIFFERENT_ART_PROBE_PATTERN := (
	"13_z13_different_art_forward_%02d.png"
)
const BAND_SEAM_LIVE_FRAME_PATTERN := "14_z13_live_move_%02d.png"
const BAND_SEAM_LIVE_CONTACT_NAME := "19_z13_live_move_contact_sheet.png"
const EDGE_CULL_FRAME_NAME := "16_live_edge_cull_frame.png"
const EDGE_CULL_DETAIL_NAME := "17_live_edge_cull_detail.png"
const BAND_SEAM_BRIGHT_LUMA_THRESHOLD := 200.0
const BAND_SEAM_GUTTER_LOCAL_LUMA_DELTA := 12.0
const BAND_SEAM_GUTTER_MAX_DETAIL := 18.0
const BAND_SEAM_MIN_GUTTER_WIDTH_PX := 2
const BAND_SEAM_EXPECTED_PRODUCTION_CHUNK_COUNT := 21
const BAND_SEAM_EXPECTED_PRODUCTION_SEAM_COUNT := 20
const BAND_SEAM_EXPECTED_SAME_ART_SEAM_COUNT := 9
const BAND_SEAM_EXPECTED_DIFFERENT_ART_SEAM_COUNT := 11
const BAND_SEAM_EXPECTED_FORWARD_DISSOLVE_WORLD_PX := 16.0
const BAND_SEAM_BASELINE_REFLECTED_TAIL_WORLD_PX := 56.0
const BAND_SEAM_FOLD_COMPARISON_ZOOM := 2.15
const BAND_SEAM_GUTTER_SEARCH_RADIUS_PX := 32
const BAND_SEAM_MIRROR_CORRELATION_RADIUS_PX := 8
const BAND_SEAM_MIRROR_CONTROL_OFFSET_PX := 48
const BAND_SEAM_MIRROR_MEAN_EXCESS_LIMIT := 0.10
const BAND_SEAM_MIRROR_P95_EXCESS_LIMIT := 0.20
# Z12's accepted reflected-A counterfactual reported a raw row-mean jump of
# 0.00. Keep that historical acceptance pinned: this Vulkan gate measures the
# captured framebuffer rows directly and must never subtract a candidate-made
# "expected" source delta to manufacture a zero.
const BAND_SEAM_REFLECTED_A_RAW_ROW_MEAN_JUMP := 0.0
const BAND_SEAM_REFLECTED_A_RAW_ROW_MEAN_EPSILON := 0.01
const BAND_SEAM_LIVE_FRAME_COUNT := 5
const BAND_SEAM_LIVE_FRAME_STEP_SCREEN_PX := 16.2
const BAND_SEAM_LIVE_FRAME_PHASE_ORIGIN_PX := 0.1
const BAND_SEAM_LIVE_FRAME_STEP_EPSILON_PX := 0.25
const BAND_SEAM_LIVE_INTEGER_PHASE_EPSILON := 0.01
const BAND_SEAM_LIVE_MIN_PHASE_SEPARATION := 0.05
const BAND_SEAM_LIVE_SAMPLE_X_INSET_PX := 96
const BAND_SEAM_LIVE_SAMPLE_RADIUS_PX := 48
const BAND_SEAM_LIVE_MIN_SAMPLE_WIDTH_PX := 512
const BAND_SEAM_LIVE_MIN_CHANGED_SAMPLE_RATIO := 0.25
const BAND_SEAM_LIVE_MAX_ALIGNED_CROP_RGB_MAE := 1.0
const BAND_SEAM_LIVE_MAX_RAW_JUMP_RANGE := 0.05
const BAND_SEAM_PHASE_START_CONTROL_RADIUS_PX := 4
const BAND_SEAM_MOTION_SAMPLE_SIZE := Vector2i(256, 158)
const BAND_SEAM_RIVER_ASSET_KEY := "human_realm_03_river_rev2"

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
	var rendering_driver := RenderingServer.get_current_rendering_driver_name().to_lower()
	var rendering_method := RenderingServer.get_current_rendering_method().to_lower()
	if rendering_driver != "vulkan" or rendering_method != "mobile":
		_fail(
			"Tower map-scroll wiring visual QA requires Vulkan Mobile, got %s/%s"
				% [rendering_driver, rendering_method]
		)
		return
	print(
		"[TowerMapVulkanProvenanceQA] driver=%s method=%s adapter=%s api=%s rendering_device=true"
			% [
				rendering_driver,
				rendering_method,
				RenderingServer.get_video_adapter_name(),
				RenderingServer.get_video_adapter_api_version(),
			]
	)
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
	# Never let a partial or older run satisfy artifact provenance. Each process
	# writes a fresh evidence set; prior captures remain untouched for comparison.
	var timestamp_usec := int(Time.get_unix_time_from_system() * 1000000.0)
	var z13_run_name := "run_%d_%d" % [OS.get_process_id(), timestamp_usec]
	var z13_output_dir := (
		output_dir.path_join(BAND_SEAM_Z13_DIR_NAME).path_join(z13_run_name)
	)
	if DirAccess.dir_exists_absolute(z13_output_dir):
		_fail("Z13 band-seam capture run directory already exists")
		return
	if DirAccess.make_dir_recursive_absolute(z13_output_dir) != OK:
		_fail("Z13 band-seam capture directory could not be created")
		return
	var import_probe := _probe_imported_band_source_freshness()
	if not bool(import_probe.get("ready", false)):
		_fail(
			"Z13 production Vulkan QA blocked by stale or unavailable imported bands: %s"
				% str(import_probe)
		)
		return
	print(
		"[TowerMapBandImportFreshnessQA] assets=%d source_and_dest_md5_match=true loader=production_imported_texture"
			% int(import_probe.get("asset_count", 0))
	)
	var fixture := _create_fixture("tower-map-band-seam-visual-qa")
	if fixture.is_empty():
		return
	var flow: Object = fixture["flow"]
	var canvas: CanvasItem = fixture["canvas"]
	var viewport: SubViewport = fixture["viewport"]
	var renderer: Object = flow.get("_renderer")
	if renderer == null or not renderer.has_method("build_fullscreen_map_model"):
		await _dispose_fixture(fixture)
		_fail("Z13 band-seam fixture could not locate the production renderer")
		return
	var fullscreen_image := await _capture(canvas, viewport)
	var seam_model: Dictionary = renderer.call(
		"build_fullscreen_map_model",
		flow,
		VIEWPORT_RECT
	)
	if not _save(fullscreen_image, z13_output_dir.path_join(BAND_SEAM_FULLSCREEN_NAME)):
		await _dispose_fixture(fixture)
		_fail("Band-seam fullscreen capture failed")
		return
	var seam_probe := _build_band_seam_probe(seam_model)
	if not bool(seam_probe.get("ready", false)):
		await _dispose_fixture(fixture)
		_fail("Z13 band-seam measurement probe failed: %s" % str(seam_probe))
		return
	var stack_image := seam_probe.get("stack_image", null) as Image
	if not _save_any_size(
		stack_image,
		z13_output_dir.path_join(BAND_SEAM_STACK_NAME)
	):
		await _dispose_fixture(fixture)
		_fail("Z13 composed band stack could not be saved")
		return
	var same_art_seams: Array = seam_probe.get("same_art_seams", [])
	var different_art_seams: Array = seam_probe.get("different_art_seams", [])
	var river_seam := _find_lowest_same_art_river_seam(same_art_seams)
	if river_seam.is_empty():
		await _dispose_fixture(fixture)
		_fail("Z13 could not select the same-art river probe")
		return
	if not _save_band_seam_probe(
		stack_image,
		int(river_seam.get("probe_y", -1)),
		z13_output_dir.path_join(BAND_SEAM_SAME_ART_PROBE_NAME)
	):
		await _dispose_fixture(fixture)
		_fail("Z13 same-art CPU diagnostic probe could not be saved")
		return
	var minimum_pixel_scale := float(seam_probe.get("minimum_pixel_scale", -1.0))
	var maximum_pixel_scale := float(seam_probe.get("maximum_pixel_scale", -1.0))
	print(
		"[TowerMapBandArtScaleCpuDiagnostic] samples=%d minimum_scale=%.3f maximum_scale=%.3f"
			% [
				int(seam_probe.get("pixel_scale_sample_count", 0)),
				minimum_pixel_scale,
				maximum_pixel_scale,
			]
	)
	var same_summary := _summarize_band_seams(same_art_seams)
	var different_summary := _summarize_band_seams(different_art_seams)
	for seam_variant in seam_probe.get("seams", []):
		var seam := seam_variant as Dictionary
		print(
			"[TowerMapBandSeamCpuDiagnostic] seam=%02d floor=%02d class=%s previous=%s current=%s join_raw=%.4f join_expected=%.4f join_excess=%.4f wrap_offset=%d wrap_raw=%.4f wrap_expected=%.4f wrap_excess=%.4f phase_start_raw=%.4f gutter=%d@%d mirror=%.4f control=%.4f mirror_excess=%.4f"
				% [
					int(seam.get("index", -1)),
					int(seam.get("floor", -1)),
					str(seam.get("seam_class", "unknown")),
					str(seam.get("previous_asset_key", "")),
					str(seam.get("asset_key", "")),
					float(seam.get("join_jump", -1.0)),
					float(seam.get("expected_join_jump", -1.0)),
					float(seam.get("join_jump_excess", -1.0)),
					int(seam.get("wrap_offset_px", -1)),
					float(seam.get("wrap_jump", -1.0)),
					float(seam.get("expected_wrap_jump", -1.0)),
					float(seam.get("wrap_jump_excess", -1.0)),
					float(seam.get("phase_jump", -1.0)),
					int(seam.get("gutter", -1)),
					int(seam.get("gutter_offset", -999)),
					float(seam.get("mirror_correlation", -1.0)),
					float(seam.get("mirror_control", -1.0)),
					float(seam.get("mirror_excess", -1.0)),
				]
		)
	print(
		"[TowerMapBandSeamCpuSummary] class=same_art_butt seams=%d mirror_mean=%.4f control_mean=%.4f excess_mean=%.4f excess_p95=%.4f max_join_raw=%.4f max_join_excess=%.4f max_wrap_raw=%.4f max_wrap_expected=%.4f max_wrap_excess=%.4f gutter_total=%d gutter_max=%d"
			% [
				same_art_seams.size(),
				float(seam_probe.get("same_mirror_mean", -1.0)),
				float(seam_probe.get("same_mirror_control_mean", -1.0)),
				float(seam_probe.get("same_mirror_excess_mean", INF)),
				float(seam_probe.get("same_mirror_excess_p95", INF)),
				float(same_summary.get("worst_join_jump", INF)),
				float(same_summary.get("worst_join_excess", INF)),
				float(same_summary.get("worst_wrap_jump", INF)),
				float(same_summary.get("worst_expected_wrap_jump", INF)),
				float(same_summary.get("worst_wrap_excess", INF)),
				int(same_summary.get("total_gutter_px", -1)),
				int(same_summary.get("maximum_gutter_px", -1)),
			]
	)
	print(
		"[TowerMapBandSeamCpuSummary] class=different_art_forward seams=%d max_join_raw=%.4f max_phase_start_raw=%.4f max_join_excess=%.4f gutter_total=%d gutter_max=%d"
			% [
				different_art_seams.size(),
				float(different_summary.get("worst_join_jump", INF)),
				float(different_summary.get("worst_phase_jump", INF)),
				float(different_summary.get("worst_join_excess", INF)),
				int(different_summary.get("total_gutter_px", -1)),
				int(different_summary.get("maximum_gutter_px", -1)),
			]
	)
	var baseline_fold_screen_px := (
		BAND_SEAM_BASELINE_REFLECTED_TAIL_WORLD_PX * BAND_SEAM_FOLD_COMPARISON_ZOOM
	)
	print(
		"[TowerMapBandFoldWidthCpuDiagnostic] zoom=%.2f same_reflected_world_px=0.0 same_reflected_screen_px=0.0 baseline_reflected_world_px=%.1f baseline_screen_px=%.1f improvement_px=%.1f improvement_pct=100.0 different_forward_dissolve_native_world_px=%.1f projected_span_source=vulkan_snapped_entry_rect"
			% [
				BAND_SEAM_FOLD_COMPARISON_ZOOM,
				BAND_SEAM_BASELINE_REFLECTED_TAIL_WORLD_PX,
				baseline_fold_screen_px,
				baseline_fold_screen_px,
				BAND_SEAM_EXPECTED_FORWARD_DISSOLVE_WORLD_PX,
			]
	)
	print(
		"[TowerMapBandGutterCpuDiagnostic] same_total_px=%d same_maximum_px=%d different_total_px=%d different_maximum_px=%d combined_total_px=%d"
			% [
				int(same_summary.get("total_gutter_px", -1)),
				int(same_summary.get("maximum_gutter_px", -1)),
				int(different_summary.get("total_gutter_px", -1)),
				int(different_summary.get("maximum_gutter_px", -1)),
				int(same_summary.get("total_gutter_px", -1))
					+ int(different_summary.get("total_gutter_px", -1)),
			]
	)
	print(
		"[TowerMapBandCpuDiagnosticOnly] art_scale_within_1x=%s gutter_zero=%s mirror_within_historical_limits=%s acceptance_source=vulkan_framebuffer"
			% [
				str(
					absf(minimum_pixel_scale - 1.0) <= 0.03
					and absf(maximum_pixel_scale - 1.0) <= 0.03
				),
				str(
					int(same_summary.get("total_gutter_px", -1)) == 0
					and int(different_summary.get("total_gutter_px", -1)) == 0
				),
				str(
					float(seam_probe.get("same_mirror_excess_mean", INF))
						<= BAND_SEAM_MIRROR_MEAN_EXCESS_LIMIT
					and float(seam_probe.get("same_mirror_excess_p95", INF))
						<= BAND_SEAM_MIRROR_P95_EXCESS_LIMIT
				),
			]
	)
	print(
		"[TowerMapBandRiverButtCpuDiagnostic] seam=%d floor=%d wrap_offset=%d mirror=%.4f control=%.4f excess=%.4f join_raw=%.4f join_excess=%.4f wrap_raw=%.4f wrap_expected=%.4f wrap_excess=%.4f gutter=%d"
			% [
				int(river_seam.get("index", -1)),
				int(river_seam.get("floor", -1)),
				int(river_seam.get("wrap_offset_px", -1)),
				float(river_seam.get("mirror_correlation", -1.0)),
				float(river_seam.get("mirror_control", -1.0)),
				float(river_seam.get("mirror_excess", -1.0)),
				float(river_seam.get("join_jump", -1.0)),
				float(river_seam.get("join_jump_excess", -1.0)),
				float(river_seam.get("wrap_jump", -1.0)),
				float(river_seam.get("expected_wrap_jump", -1.0)),
				float(river_seam.get("wrap_jump_excess", -1.0)),
				int(river_seam.get("gutter", -1)),
			]
	)
	var different_vulkan_probe := await _capture_different_art_forward_probes(
		fixture,
		renderer,
		different_art_seams,
		z13_output_dir
	)
	print(
		"[TowerMapBandDifferentForwardVulkanQA] zoom=%.3f frames=%d seams=%d worst_entry_body_raw_row_mean_jump=%.4f worst_phase_start_hard_jump_excess=%.4f maximum_snapped_span_error_px=%.4f framebuffer_gutter_total_px=%d framebuffer_gutter_maximum_px=%d"
			% [
				float(different_vulkan_probe.get("zoom", -1.0)),
				int(different_vulkan_probe.get("frame_count", 0)),
				int(different_vulkan_probe.get("seam_count", 0)),
				float(different_vulkan_probe.get("worst_entry_body_raw_row_mean_jump", INF)),
				float(different_vulkan_probe.get("worst_phase_start_hard_jump_excess", INF)),
				float(different_vulkan_probe.get("maximum_snapped_span_error_px", INF)),
				int(different_vulkan_probe.get("framebuffer_gutter_total_px", -1)),
				int(different_vulkan_probe.get("framebuffer_gutter_maximum_px", -1)),
			]
	)
	if not bool(different_vulkan_probe.get("ready", false)):
		await _dispose_fixture(fixture)
		_fail(
			"Z13 live 2.15x different-art forward capture failed: %s"
				% str(different_vulkan_probe)
		)
		return
	var motion_probe := await _capture_live_seam_motion(
		fixture,
		renderer,
		river_seam,
		z13_output_dir
	)
	if not bool(motion_probe.get("ready", false)):
		await _dispose_fixture(fixture)
		_fail("Z13 live 2.15x seam-motion capture failed: %s" % str(motion_probe))
		return
	print(
		"[TowerMapBandLiveMotionQA] seed=83521 zoom=%.3f frames=%d asset=%s floor=%d seam=%d projected_y=%s projected_step_px=%s camera_raster_phases=%s boundary_raster_phases=%s changed_sample_px=%s changed_sample_ratio=%s aligned_crop_rgb_mae=%s raw_row_mean_jump=%s raw_mean_abs_luma_jump=%s raw_p95_abs_luma_jump=%s"
			% [
				float(motion_probe.get("zoom", -1.0)),
				int(motion_probe.get("frame_count", -1)),
				str(river_seam.get("asset_key", "")),
				int(river_seam.get("floor", -1)),
				int(river_seam.get("index", -1)),
				str(motion_probe.get("projected_y", [])),
				str(motion_probe.get("projected_step_px", [])),
				str(motion_probe.get("camera_raster_phases", [])),
				str(motion_probe.get("raster_phases", [])),
				str(motion_probe.get("changed_sample_px", [])),
				str(motion_probe.get("changed_sample_ratio", [])),
				str(motion_probe.get("aligned_crop_rgb_mae", [])),
				str(motion_probe.get("raw_row_mean_jump", [])),
				str(motion_probe.get("raw_mean_abs_luma_jump", [])),
				str(motion_probe.get("raw_p95_abs_luma_jump", [])),
			]
	)
	print(
		"[TowerMapBandProjectedSeamVulkanQA] metric=raw_abs_row_mean_luma reflected_A=%.4f epsilon=%.4f worst=%.4f range=%.4f frames=%d"
			% [
				BAND_SEAM_REFLECTED_A_RAW_ROW_MEAN_JUMP,
				BAND_SEAM_REFLECTED_A_RAW_ROW_MEAN_EPSILON,
				float(motion_probe.get("worst_raw_row_mean_jump", INF)),
				float(motion_probe.get("raw_row_mean_jump_range", INF)),
				int(motion_probe.get("frame_count", 0)),
			]
	)
	print(
		"[TowerMapBandFramebufferVisualQA] native_framebuffer_px=true framebuffer_y_scale=1.0 gutter_luma_range=0..255 gutter_bright_floor=%.1f gutter_local_luma_delta=%.1f gutter_detail_max=%.1f gutter_search_radius_px=%d gutter_min_width_px=%d same_gutter_total_px=%d same_gutter_maximum_px=%d different_gutter_total_px=%d different_gutter_maximum_px=%d mirror_radius_px=%d mirror_control_offset_px=%d mirror_mean_excess_limit=%.2f mirror_p95_excess_limit=%.2f same_mirror_excess_mean=%.4f same_mirror_excess_p95=%.4f"
			% [
				BAND_SEAM_BRIGHT_LUMA_THRESHOLD,
				BAND_SEAM_GUTTER_LOCAL_LUMA_DELTA,
				BAND_SEAM_GUTTER_MAX_DETAIL,
				BAND_SEAM_GUTTER_SEARCH_RADIUS_PX,
				BAND_SEAM_MIN_GUTTER_WIDTH_PX,
				int(motion_probe.get("framebuffer_gutter_total_px", -1)),
				int(motion_probe.get("framebuffer_gutter_maximum_px", -1)),
				int(different_vulkan_probe.get("framebuffer_gutter_total_px", -1)),
				int(different_vulkan_probe.get("framebuffer_gutter_maximum_px", -1)),
				BAND_SEAM_MIRROR_CORRELATION_RADIUS_PX,
				BAND_SEAM_MIRROR_CONTROL_OFFSET_PX,
				BAND_SEAM_MIRROR_MEAN_EXCESS_LIMIT,
				BAND_SEAM_MIRROR_P95_EXCESS_LIMIT,
				float(motion_probe.get("framebuffer_mirror_excess_mean", INF)),
				float(motion_probe.get("framebuffer_mirror_excess_p95", INF)),
			]
	)
	await _dispose_fixture(fixture)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	var direct_vulkan_artifact_count := (
		1 + different_art_seams.size() + BAND_SEAM_LIVE_FRAME_COUNT
	)
	var artifact_count := direct_vulkan_artifact_count + 3
	var different_art_capture_names: Array[String] = []
	for capture_seam_variant in different_art_seams:
		var capture_seam := capture_seam_variant as Dictionary
		different_art_capture_names.append(
			BAND_SEAM_DIFFERENT_ART_PROBE_PATTERN % int(capture_seam.get("index", -1))
		)
	var motion_capture_names: Array[String] = []
	for frame_index in range(BAND_SEAM_LIVE_FRAME_COUNT):
		motion_capture_names.append(BAND_SEAM_LIVE_FRAME_PATTERN % frame_index)
	print(
		"[TowerMapBandSeamVisualQA] output=%s artifacts=%d direct_vulkan_artifacts=%d fullscreen_frames=1 same_art_motion_frames=%d different_art_forward_frames=%d cpu_diagnostics=2 derived_contact_sheets=1 chunks=%d same_art_butt=%d different_art_forward=%d reflected_tails=0"
			% [
				z13_output_dir,
				artifact_count,
				direct_vulkan_artifact_count,
				BAND_SEAM_LIVE_FRAME_COUNT,
				different_art_seams.size(),
				int(seam_probe.get("draw_chunk_count", -1)),
				same_art_seams.size(),
				different_art_seams.size(),
			]
	)
	print(
		"[TowerMapBandCaptureList] run_dir=%s fullscreen=%s different_art_vulkan_crops=%s same_art_motion_frames=%s cpu_diagnostic_files=%s,%s derived_contact_sheet=%s"
			% [
				z13_output_dir,
				BAND_SEAM_FULLSCREEN_NAME,
				str(different_art_capture_names),
				str(motion_capture_names),
				BAND_SEAM_STACK_NAME,
				BAND_SEAM_SAME_ART_PROBE_NAME,
				BAND_SEAM_LIVE_CONTACT_NAME,
			]
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


func _probe_imported_band_source_freshness() -> Dictionary:
	var catalog := TowerMapScrollAssetCatalog.new()
	var asset_keys: Array[String] = []
	asset_keys.assign(
		TowerMapScrollAssetCatalog.HUMAN_BAND_ASSET_KEYS
			+ TowerMapScrollAssetCatalog.IMMORTAL_BAND_ASSET_KEYS
	)
	var missing: Array[String] = []
	var stale: Array[String] = []
	var unavailable: Array[String] = []
	var source_md5_pattern := RegEx.new()
	var dest_md5_pattern := RegEx.new()
	if (
		source_md5_pattern.compile("source_md5=\"([0-9a-fA-F]{32})\"") != OK
		or dest_md5_pattern.compile("dest_md5=\"([0-9a-fA-F]{32})\"") != OK
	):
		return {"ready": false, "reason": "md5_pattern"}
	for asset_key in asset_keys:
		var source_path := catalog.resolve_declared_path(asset_key)
		var import_sidecar_path := source_path + ".import"
		var import_config := ConfigFile.new()
		if import_config.load(import_sidecar_path) != OK:
			missing.append("%s:import_sidecar" % asset_key)
			continue
		var dest_files: Array[String] = []
		var dest_files_value: Variant = import_config.get_value("deps", "dest_files", [])
		if dest_files_value is Array:
			for dest_file_variant in (dest_files_value as Array):
				if not (dest_file_variant is String) or str(dest_file_variant).is_empty():
					missing.append("%s:dest_files" % asset_key)
					dest_files.clear()
					break
				dest_files.append(str(dest_file_variant))
		elif dest_files_value is PackedStringArray:
			for dest_file in (dest_files_value as PackedStringArray):
				if dest_file.is_empty():
					missing.append("%s:dest_files" % asset_key)
					dest_files.clear()
					break
				dest_files.append(dest_file)
		if dest_files.is_empty():
			if not missing.has("%s:dest_files" % asset_key):
				missing.append("%s:dest_files" % asset_key)
			continue
		var remap_membership_valid := true
		var remap_path_count := 0
		for remap_key in import_config.get_section_keys("remap"):
			if not remap_key.begins_with("path"):
				continue
			remap_path_count += 1
			var remap_path := str(import_config.get_value("remap", remap_key, ""))
			if remap_path.is_empty() or not dest_files.has(remap_path):
				remap_membership_valid = false
				break
		if not remap_membership_valid or remap_path_count <= 0:
			unavailable.append("%s:remap_dest_membership" % asset_key)
			continue
		# Every platform product in dest_files belongs to one import digest. Derive
		# that sidecar from the declared aggregate instead of selecting one renderer
		# format (BPTC/ASTC) and incorrectly treating its file hash as dest_md5.
		var import_digest_path := ""
		var shared_digest_path := true
		for dest_file in dest_files:
			var candidate_digest_path := _import_digest_path(dest_file)
			if candidate_digest_path.is_empty():
				shared_digest_path = false
				break
			if import_digest_path.is_empty():
				import_digest_path = candidate_digest_path
			elif candidate_digest_path != import_digest_path:
				shared_digest_path = false
				break
		if (
			not shared_digest_path
			or import_digest_path.is_empty()
			or not FileAccess.file_exists(import_digest_path)
		):
			missing.append("%s:import_product" % asset_key)
			continue
		var missing_dest_product := false
		for dest_file in dest_files:
			var dest_access := FileAccess.open(dest_file, FileAccess.READ)
			if dest_access == null or dest_access.get_length() <= 0:
				missing_dest_product = true
				break
		if missing_dest_product:
			missing.append("%s:import_product" % asset_key)
			continue
		var digest_text := FileAccess.get_file_as_string(import_digest_path)
		var digest_match := source_md5_pattern.search(digest_text)
		var dest_digest_match := dest_md5_pattern.search(digest_text)
		if digest_match == null or dest_digest_match == null:
			missing.append("%s:import_md5" % asset_key)
			continue
		var imported_source_md5 := digest_match.get_string(1).to_lower()
		var current_source_md5 := FileAccess.get_md5(source_path).to_lower()
		if current_source_md5.is_empty() or imported_source_md5 != current_source_md5:
			stale.append(asset_key)
			continue
		var imported_dest_md5 := dest_digest_match.get_string(1).to_lower()
		# Godot hashes multi-format imports as the concatenation of every declared
		# destination in [deps].dest_files order. The digest is not the MD5 of the
		# selected BPTC (or ASTC) product by itself.
		var current_dest_md5 := _aggregate_files_md5(dest_files).to_lower()
		if current_dest_md5.is_empty() or imported_dest_md5 != current_dest_md5:
			unavailable.append("%s:import_product_md5" % asset_key)
			continue
		var texture := ResourceLoader.load(source_path, "Texture2D") as Texture2D
		if texture == null:
			unavailable.append(asset_key)
	return {
		"ready": missing.is_empty() and stale.is_empty() and unavailable.is_empty(),
		"asset_count": asset_keys.size(),
		"missing": missing,
		"stale": stale,
		"unavailable": unavailable,
	}


func _aggregate_files_md5(paths: Array[String]) -> String:
	if paths.is_empty():
		return ""
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_MD5) != OK:
		return ""
	for path in paths:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() <= 0:
			return ""
		var remaining := file.get_length()
		while remaining > 0:
			var block: PackedByteArray = file.get_buffer(mini(1024 * 1024, remaining))
			if block.is_empty():
				return ""
			if hashing.update(block) != OK:
				return ""
			remaining -= block.size()
	return hashing.finish().hex_encode()


func _import_digest_path(imported_texture_path: String) -> String:
	for suffix in [
		".bptc.ctex",
		".astc.ctex",
		".s3tc.ctex",
		".etc2.ctex",
		".ctex",
	]:
		if imported_texture_path.ends_with(suffix):
			return imported_texture_path.trim_suffix(suffix) + ".md5"
	return ""


func _create_fixture(run_id: String, record_path: String = "") -> Dictionary:
	var flow := TowerAscentFlowOwner.new()
	if not record_path.is_empty():
		flow.set_record_store_path_for_tests(record_path)
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
		return {
			"ready": false,
			"reason": "chunk_count",
			"draw_chunks": draw_chunks.size(),
			"tiles": tiles.size(),
		}
	var tile_rect: Rect2 = (tiles[0] as Dictionary).get("rect", Rect2())
	var map_scale := tile_rect.size.x / 692.0
	if map_scale <= 0.0:
		return {"ready": false, "reason": "map_scale"}
	var stack_world_rect: Rect2 = background.get("world_rect", Rect2())
	var stack_size := Vector2i(
		int(round(stack_world_rect.size.x / map_scale)),
		int(round(stack_world_rect.size.y / map_scale))
	)
	var stack_image := _compose_band_stack(draw_chunks, stack_world_rect, map_scale)
	if stack_image.is_empty() or stack_image.get_size() != stack_size:
		return {
			"ready": false,
			"reason": "compose",
			"actual_size": stack_image.get_size(),
			"expected_size": stack_size,
		}
	var rows := _measure_row_luma(stack_image)
	var details := _measure_row_detail(stack_image)
	var mirror_sample := stack_image.duplicate()
	mirror_sample.resize(128, stack_image.get_height(), Image.INTERPOLATE_LANCZOS)
	var pixel_scale_probe := _measure_band_art_pixel_scales(draw_chunks, map_scale)
	var seams: Array[Dictionary] = []
	var same_art_seams: Array[Dictionary] = []
	var different_art_seams: Array[Dictionary] = []
	var same_mirror_values: Array[float] = []
	var same_control_values: Array[float] = []
	var same_excess_values: Array[float] = []
	for chunk_index in range(1, draw_chunks.size()):
		var previous_chunk := draw_chunks[chunk_index - 1] as Dictionary
		var chunk := draw_chunks[chunk_index] as Dictionary
		var previous_asset_key := str(previous_chunk.get("asset_key", ""))
		var asset_key := str(chunk.get("asset_key", ""))
		var seam_class := (
			"same_art_butt"
			if previous_asset_key == asset_key
			else "different_art_forward"
		)
		var expected_seam_kind := (
			"same_asset_butt"
			if seam_class == "same_art_butt"
			else "cross_asset_forward"
		)
		var declared_seam_kind := str(chunk.get("seam_kind", ""))
		if declared_seam_kind != expected_seam_kind:
			return {
				"ready": false,
				"reason": "seam_kind",
				"index": chunk_index,
				"expected": expected_seam_kind,
				"actual": declared_seam_kind,
			}
		var raw_forward_dissolve_world_px := float(
			chunk.get("forward_dissolve_world_px", -1.0)
		)
		var raw_body_source_phase_world_px := float(
			chunk.get("body_source_phase_world_px", -1.0)
		)
		var forward_dissolve_world_px := raw_forward_dissolve_world_px / map_scale
		var body_source_phase_world_px := raw_body_source_phase_world_px / map_scale
		var entry_rect: Rect2 = chunk.get("seam_entry_rect", Rect2())
		var entry_source_rect: Rect2 = chunk.get("seam_entry_source_rect", Rect2())
		if seam_class == "same_art_butt":
			var previous_paper_rect: Rect2 = previous_chunk.get("paper_rect", Rect2())
			var expected_body_source_phase_world_px := fposmod(
				float(previous_chunk.get("body_source_phase_world_px", 0.0))
					+ previous_paper_rect.size.y,
				tile_rect.size.y
			)
			if (
				not is_zero_approx(forward_dissolve_world_px)
				or not is_equal_approx(
					raw_body_source_phase_world_px,
					expected_body_source_phase_world_px
				)
				or entry_rect.has_area()
				or entry_source_rect.has_area()
			):
				return {
					"ready": false,
					"reason": "same_art_phase",
					"index": chunk_index,
					"expected_phase": expected_body_source_phase_world_px / map_scale,
					"actual_phase": body_source_phase_world_px,
				}
		else:
			if (
				not is_equal_approx(
					forward_dissolve_world_px,
					BAND_SEAM_EXPECTED_FORWARD_DISSOLVE_WORLD_PX
				)
				or not is_equal_approx(
					body_source_phase_world_px,
					forward_dissolve_world_px
				)
				or not entry_rect.has_area()
				or not entry_source_rect.has_area()
			):
				return {
					"ready": false,
					"reason": "different_art_phase",
					"index": chunk_index,
					"forward_dissolve_world_px": forward_dissolve_world_px,
					"body_source_phase_world_px": body_source_phase_world_px,
				}
		if (
			chunk.has("reflected_tail_world_px")
			or chunk.has("seam_tail_rect")
			or chunk.has("seam_tail_source_rect")
		):
			return {
				"ready": false,
				"reason": "tail_key_restored",
				"index": chunk_index,
			}
		var chunk_rect: Rect2 = chunk.get("paper_rect", chunk.get("rect", Rect2()))
		var previous_source_rect: Rect2 = previous_chunk.get(
			"normalized_source_rect",
			Rect2()
		)
		var next_previous_wrap_v := floorf(previous_source_rect.position.y) + 1.0
		var has_internal_previous_wrap := (
			previous_source_rect.has_area()
			and next_previous_wrap_v > previous_source_rect.position.y + 0.000001
			and next_previous_wrap_v
				< previous_source_rect.position.y + previous_source_rect.size.y - 0.000001
		)
		var seam_y := int(round((chunk_rect.position.y - stack_world_rect.position.y) / map_scale))
		var join_delta := INF
		if seam_y > 0 and seam_y < rows.size():
			join_delta = float(rows[seam_y]) - float(rows[seam_y - 1])
		var expected_join_delta := _expected_band_seam_native_delta(
			previous_chunk,
			chunk,
			seam_class,
			map_scale
		)
		var join_jump := absf(join_delta)
		var expected_join_jump := absf(expected_join_delta)
		var join_jump_excess := (
			absf(join_delta - expected_join_delta)
			if (
				not is_inf(join_delta)
				and not is_nan(join_delta)
				and not is_inf(expected_join_delta)
				and not is_nan(expected_join_delta)
			)
			else INF
		)
		var phase_jump := 0.0
		if seam_class == "different_art_forward":
			var phase_y := int(round(
				(entry_rect.position.y - stack_world_rect.position.y) / map_scale
			))
			phase_jump = (
				absf(float(rows[phase_y]) - float(rows[phase_y - 1]))
				if phase_y > 0 and phase_y < rows.size()
				else INF
			)
		var wrap_offset_px := 0
		var wrap_y := -1
		var wrap_jump := 0.0
		var expected_wrap_jump := 0.0
		var wrap_jump_excess := 0.0
		var probe_y := seam_y
		var probe_world_y := chunk_rect.position.y
		if seam_class == "same_art_butt":
			wrap_offset_px = int(round(body_source_phase_world_px))
			wrap_y = seam_y - wrap_offset_px
			var wrap_delta := INF
			if wrap_y > 0 and wrap_y < rows.size():
				wrap_delta = float(rows[wrap_y]) - float(rows[wrap_y - 1])
			var expected_wrap_delta := _expected_same_art_wrap_delta(
				previous_chunk,
				wrap_offset_px,
				map_scale
			)
			wrap_jump = absf(wrap_delta)
			expected_wrap_jump = absf(expected_wrap_delta)
			wrap_jump_excess = (
				absf(wrap_delta - expected_wrap_delta)
				if (
					not is_inf(wrap_delta)
					and not is_nan(wrap_delta)
					and not is_inf(expected_wrap_delta)
					and not is_nan(expected_wrap_delta)
				)
				else INF
			)
			probe_y = wrap_y
			probe_world_y = chunk_rect.position.y - raw_body_source_phase_world_px
		var gutter := {"width": -1, "center_offset": 0}
		if probe_y >= 0 and probe_y < rows.size():
			gutter = _measure_bright_gutter_band(
				rows,
				details,
				probe_y,
				BAND_SEAM_GUTTER_SEARCH_RADIUS_PX
			)
		var mirror_correlation := _measure_seam_mirror_correlation(
			mirror_sample,
			probe_y,
			BAND_SEAM_MIRROR_CORRELATION_RADIUS_PX
		)
		var mirror_control := -1.0
		var mirror_excess := -1.0
		if seam_class == "same_art_butt":
			var controls: Array[float] = []
			for control_y in [
				probe_y - BAND_SEAM_MIRROR_CONTROL_OFFSET_PX,
				probe_y + BAND_SEAM_MIRROR_CONTROL_OFFSET_PX,
			]:
				var control_y_index := int(control_y)
				var control := _measure_seam_mirror_correlation(
					mirror_sample,
					control_y_index,
					BAND_SEAM_MIRROR_CORRELATION_RADIUS_PX
				)
				if control >= -0.999:
					controls.append(control)
			if controls.size() == 2 and mirror_correlation >= -0.999:
				mirror_control = _mean_float_values(controls)
				mirror_excess = mirror_correlation - mirror_control
			else:
				mirror_control = INF
				mirror_excess = INF
		var seam := {
			"index": chunk_index,
			"floor": int(chunk.get("floor", -1)),
			"seam_class": seam_class,
			"previous_asset_key": previous_asset_key,
			"asset_key": asset_key,
			"y": seam_y,
			"world_y": chunk_rect.position.y,
			"phase_start_world_y": (
				entry_rect.position.y
				if seam_class == "different_art_forward"
				else NAN
			),
			"probe_y": probe_y,
			"probe_world_y": probe_world_y,
			"wrap_y": wrap_y,
			"wrap_offset_px": wrap_offset_px,
			"wrap_jump": wrap_jump,
			"expected_wrap_jump": expected_wrap_jump,
			"wrap_jump_excess": wrap_jump_excess,
			"join_jump": join_jump,
			"expected_join_jump": expected_join_jump,
			"join_jump_excess": join_jump_excess,
			"phase_jump": phase_jump,
			# A continuous source can have a natural adjacent-row gradient. Compare
			# the rendered join against that native continuation so reflected A's 0.00
			# seal means zero discontinuity excess, not an artificially flat picture.
			"maximum_jump": maxf(join_jump_excess, wrap_jump_excess),
			"gutter": int(gutter.get("width", 0)),
			"gutter_offset": int(gutter.get("center_offset", 0)),
			"mirror_correlation": mirror_correlation,
			"mirror_control": mirror_control,
			"mirror_excess": mirror_excess,
			"forward_dissolve_world_px": forward_dissolve_world_px,
			"body_source_phase_world_px": body_source_phase_world_px,
			"has_internal_previous_wrap": has_internal_previous_wrap,
		}
		seams.append(seam)
		if seam_class == "same_art_butt":
			same_art_seams.append(seam)
			same_mirror_values.append(mirror_correlation)
			same_control_values.append(mirror_control)
			same_excess_values.append(mirror_excess)
		else:
			different_art_seams.append(seam)
	return {
		"ready": (
			seams.size() == BAND_SEAM_EXPECTED_PRODUCTION_SEAM_COUNT
			and same_art_seams.size() == BAND_SEAM_EXPECTED_SAME_ART_SEAM_COUNT
			and different_art_seams.size()
				== BAND_SEAM_EXPECTED_DIFFERENT_ART_SEAM_COUNT
		),
		"stack_image": stack_image,
		"draw_chunk_count": draw_chunks.size(),
		"seams": seams,
		"same_art_seams": same_art_seams,
		"different_art_seams": different_art_seams,
		"minimum_pixel_scale": float(pixel_scale_probe.get("minimum_scale", -1.0)),
		"maximum_pixel_scale": float(pixel_scale_probe.get("maximum_scale", -1.0)),
		"pixel_scale_sample_count": int(pixel_scale_probe.get("sample_count", 0)),
		"same_mirror_mean": _mean_float_values(same_mirror_values),
		"same_mirror_control_mean": _mean_float_values(same_control_values),
		"same_mirror_excess_mean": _mean_float_values(same_excess_values),
		"same_mirror_excess_p95": _percentile_float_values(same_excess_values, 0.95),
	}


func _compose_band_stack(
	draw_chunks: Array,
	stack_world_rect: Rect2,
	map_scale: float
) -> Image:
	var stack_size := Vector2i(
		int(round(stack_world_rect.size.x / map_scale)),
		int(round(stack_world_rect.size.y / map_scale))
	)
	var stack := Image.create(stack_size.x, stack_size.y, false, Image.FORMAT_RGBA8)
	stack.fill(Color("f1dfb8"))
	var resize_cache := {}
	for chunk_variant in draw_chunks:
		var paper_chunk := chunk_variant as Dictionary
		var paper_target := _normalized_chunk_rect(
			paper_chunk.get("paper_rect", paper_chunk.get("rect", Rect2())),
			stack_world_rect,
			map_scale
		)
		var paper := _resized_texture_region(
			paper_chunk.get("paper_texture", null) as Texture2D,
			paper_chunk.get("paper_source_rect", Rect2(0.0, 0.0, 1.0, 1.0)),
			paper_target.size,
			resize_cache
		)
		if paper.is_empty():
			return Image.new()
		stack.blit_rect(
			paper,
			Rect2i(Vector2i.ZERO, paper.get_size()),
			paper_target.position
		)
	for chunk_variant in draw_chunks:
		var chunk := chunk_variant as Dictionary
		var source_rect: Rect2 = chunk.get("normalized_source_rect", Rect2(0.0, 0.0, 1.0, 1.0))
		var chunk_world_rect: Rect2 = chunk.get("rect", Rect2())
		var target_rect := _normalized_chunk_rect(
			chunk_world_rect,
			stack_world_rect,
			map_scale
		)
		var band := _resized_texture_region(
			chunk.get("source_texture", chunk.get("texture", null)) as Texture2D,
			source_rect,
			target_rect.size,
			resize_cache
		)
		if band.is_empty():
			return Image.new()
		stack.blit_rect(band, Rect2i(Vector2i.ZERO, band.get_size()), target_rect.position)
		var entry_rect: Rect2 = chunk.get("seam_entry_rect", Rect2())
		if entry_rect.has_area():
			var entry_target := _normalized_chunk_rect(
				entry_rect,
				stack_world_rect,
				map_scale
			)
			var entry := _resized_texture_region(
				chunk.get("source_texture", chunk.get("texture", null)) as Texture2D,
				chunk.get("seam_entry_source_rect", Rect2()),
				entry_target.size,
				resize_cache
			)
			if entry.is_empty():
				return Image.new()
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
	var cache_key := "%d|%s|%s" % [
		texture.get_instance_id(),
		str(normalized_source_rect),
		str(target_size),
	]
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
	if (
		not source_rect.has_area()
		or source_rect.position.x < 0
		or source_rect.end.x > source.get_width()
	):
		return Image.new()
	var resized: Image
	if source_rect.position.y >= 0 and source_rect.end.y <= source.get_height():
		resized = source.get_region(source_rect)
	else:
		# The production band wrapper repeats V. Reconstruct the same modulo request
		# from the raw source image so a body phase such as 16/320 + 1.0 never
		# becomes transparent padding in the offline pixel probe.
		resized = Image.create(
			source_rect.size.x,
			source_rect.size.y,
			false,
			Image.FORMAT_RGBA8
		)
		var remaining_height := source_rect.size.y
		var destination_y := 0
		var source_y := posmod(source_rect.position.y, source.get_height())
		while remaining_height > 0:
			var copy_height := mini(remaining_height, source.get_height() - source_y)
			resized.blit_rect(
				source,
				Rect2i(
					Vector2i(source_rect.position.x, source_y),
					Vector2i(source_rect.size.x, copy_height)
				),
				Vector2i(0, destination_y)
			)
			remaining_height -= copy_height
			destination_y += copy_height
			source_y = 0
	resized.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	resize_cache[cache_key] = resized
	return resized


func _measure_band_art_pixel_scales(draw_chunks: Array, map_scale: float) -> Dictionary:
	var minimum_scale := INF
	var maximum_scale := -INF
	var sample_count := 0
	var expected_sample_count := 0
	for chunk_variant in draw_chunks:
		var chunk := chunk_variant as Dictionary
		var texture := chunk.get("source_texture", chunk.get("texture", null)) as Texture2D
		expected_sample_count += 1
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
			expected_sample_count += 1
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
	return {
		"ready": sample_count == expected_sample_count,
		"minimum_scale": minimum_scale,
		"maximum_scale": maximum_scale,
		"sample_count": sample_count,
		"expected_sample_count": expected_sample_count,
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
		or source_rect.end.x > source.get_width()
		or not source_rect.has_area()
	):
		return -1.0
	if source_rect.position.y < 0 or source_rect.end.y > source.get_height():
		# Runtime V repeats. Pixel density depends on the requested span, not on
		# where the modulo split lands in the source image.
		var source_density := float(source_rect.size.x) / float(target_size.x)
		if source_density <= 0.0:
			return -1.0
		var natural_height := float(source_rect.size.y) / source_density
		return float(target_size.y) / natural_height
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


func _expected_band_seam_native_delta(
	previous_chunk: Dictionary,
	chunk: Dictionary,
	seam_class: String,
	map_scale: float
) -> float:
	var before_chunk := previous_chunk if seam_class == "same_art_butt" else chunk
	var before_rect: Rect2 = (
		before_chunk.get("rect", Rect2())
		if seam_class == "same_art_butt"
		else chunk.get("seam_entry_rect", Rect2())
	)
	var before_source_rect: Rect2 = (
		before_chunk.get("normalized_source_rect", Rect2())
		if seam_class == "same_art_butt"
		else chunk.get("seam_entry_source_rect", Rect2())
	)
	var after_rect: Rect2 = chunk.get("rect", Rect2())
	var after_source_rect: Rect2 = chunk.get("normalized_source_rect", Rect2())
	if (
		not before_rect.has_area()
		or not before_source_rect.has_area()
		or not after_rect.has_area()
		or not after_source_rect.has_area()
	):
		return INF
	var before_texture := before_chunk.get(
		"source_texture",
		before_chunk.get("texture", null)
	) as Texture2D
	var after_texture := chunk.get(
		"source_texture",
		chunk.get("texture", null)
	) as Texture2D
	var resize_cache := {}
	var before_image := _resized_texture_region(
		before_texture,
		before_source_rect,
		Vector2i(
			int(round(before_rect.size.x / map_scale)),
			int(round(before_rect.size.y / map_scale))
		),
		resize_cache
	)
	var after_image := _resized_texture_region(
		after_texture,
		after_source_rect,
		Vector2i(
			int(round(after_rect.size.x / map_scale)),
			int(round(after_rect.size.y / map_scale))
		),
		resize_cache
	)
	if before_image.is_empty() or after_image.is_empty():
		return INF
	return (
		_image_row_luma(after_image, 0)
		- _image_row_luma(before_image, before_image.get_height() - 1)
	)


func _expected_same_art_wrap_delta(
	previous_chunk: Dictionary,
	wrap_offset_px: int,
	map_scale: float
) -> float:
	var previous_rect: Rect2 = previous_chunk.get("rect", Rect2())
	var previous_source_rect: Rect2 = previous_chunk.get("normalized_source_rect", Rect2())
	var texture := previous_chunk.get(
		"source_texture",
		previous_chunk.get("texture", null)
	) as Texture2D
	if (
		texture == null
		or not previous_rect.has_area()
		or not previous_source_rect.has_area()
		or wrap_offset_px <= 0
	):
		return INF
	var body := _resized_texture_region(
		texture,
		previous_source_rect,
		Vector2i(
			int(round(previous_rect.size.x / map_scale)),
			int(round(previous_rect.size.y / map_scale))
		),
		{}
	)
	if body.is_empty():
		return INF
	var wrap_local_y := body.get_height() - wrap_offset_px
	if wrap_local_y <= 0 or wrap_local_y >= body.get_height():
		return INF
	return (
		_image_row_luma(body, wrap_local_y)
		- _image_row_luma(body, wrap_local_y - 1)
	)


func _image_row_luma(image: Image, row_y: int) -> float:
	if image == null or image.is_empty() or row_y < 0 or row_y >= image.get_height():
		return INF
	var row := image.get_region(Rect2i(0, row_y, image.get_width(), 1))
	row.resize(1, 1, Image.INTERPOLATE_LANCZOS)
	var pixel: Color = row.get_pixel(0, 0)
	return (0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b) * 255.0


func _measure_seam_mirror_correlation(
	image: Image,
	seam_y: int,
	radius: int
) -> float:
	if (
		image == null
		or image.is_empty()
		or radius <= 0
		or seam_y - radius < 0
		or seam_y + radius > image.get_height()
	):
		return -1.0
	var top_values := PackedFloat32Array()
	var bottom_values := PackedFloat32Array()
	for distance in range(radius):
		var top_y := seam_y - 1 - distance
		var bottom_y := seam_y + distance
		for x in range(8, image.get_width() - 8):
			var top: Color = image.get_pixel(x, top_y)
			var bottom: Color = image.get_pixel(x, bottom_y)
			top_values.append(0.2126 * top.r + 0.7152 * top.g + 0.0722 * top.b)
			bottom_values.append(
				0.2126 * bottom.r + 0.7152 * bottom.g + 0.0722 * bottom.b
			)
	if top_values.is_empty() or top_values.size() != bottom_values.size():
		return -1.0
	var top_mean := 0.0
	var bottom_mean := 0.0
	for index in range(top_values.size()):
		top_mean += float(top_values[index])
		bottom_mean += float(bottom_values[index])
	top_mean /= float(top_values.size())
	bottom_mean /= float(bottom_values.size())
	var covariance := 0.0
	var top_variance := 0.0
	var bottom_variance := 0.0
	for index in range(top_values.size()):
		var top_delta := float(top_values[index]) - top_mean
		var bottom_delta := float(bottom_values[index]) - bottom_mean
		covariance += top_delta * bottom_delta
		top_variance += top_delta * top_delta
		bottom_variance += bottom_delta * bottom_delta
	var denominator := sqrt(top_variance * bottom_variance)
	return covariance / denominator if denominator > 0.000001 else 0.0


func _mean_float_values(values: Array[float]) -> float:
	if values.is_empty():
		return INF
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _percentile_float_values(values: Array[float], percentile: float) -> float:
	if values.is_empty():
		return INF
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var index := clampi(
		int(ceil(float(sorted_values.size() - 1) * clampf(percentile, 0.0, 1.0))),
		0,
		sorted_values.size() - 1
	)
	return float(sorted_values[index])


func _summarize_band_seams(seams: Array) -> Dictionary:
	if seams.is_empty():
		return {
			"worst_jump": INF,
			"worst_join_jump": INF,
			"worst_join_excess": INF,
			"worst_wrap_jump": INF,
			"worst_expected_wrap_jump": INF,
			"worst_wrap_excess": INF,
			"worst_phase_jump": INF,
			"total_gutter_px": -1,
			"maximum_gutter_px": -1,
		}
	var worst_jump := 0.0
	var worst_join_jump := 0.0
	var worst_join_excess := 0.0
	var worst_wrap_jump := 0.0
	var worst_expected_wrap_jump := 0.0
	var worst_wrap_excess := 0.0
	var worst_phase_jump := 0.0
	var total_gutter_px := 0
	var maximum_gutter_px := 0
	for seam_variant in seams:
		var seam := seam_variant as Dictionary
		worst_jump = maxf(worst_jump, float(seam.get("maximum_jump", INF)))
		worst_join_jump = maxf(worst_join_jump, float(seam.get("join_jump", INF)))
		worst_join_excess = maxf(
			worst_join_excess,
			float(seam.get("join_jump_excess", INF))
		)
		worst_wrap_jump = maxf(worst_wrap_jump, float(seam.get("wrap_jump", INF)))
		worst_expected_wrap_jump = maxf(
			worst_expected_wrap_jump,
			float(seam.get("expected_wrap_jump", INF))
		)
		worst_wrap_excess = maxf(
			worst_wrap_excess,
			float(seam.get("wrap_jump_excess", INF))
		)
		worst_phase_jump = maxf(worst_phase_jump, float(seam.get("phase_jump", INF)))
		var gutter_px := int(seam.get("gutter", -1))
		total_gutter_px += gutter_px
		maximum_gutter_px = maxi(maximum_gutter_px, gutter_px)
	return {
		"worst_jump": worst_jump,
		"worst_join_jump": worst_join_jump,
		"worst_join_excess": worst_join_excess,
		"worst_wrap_jump": worst_wrap_jump,
		"worst_expected_wrap_jump": worst_expected_wrap_jump,
		"worst_wrap_excess": worst_wrap_excess,
		"worst_phase_jump": worst_phase_jump,
		"total_gutter_px": total_gutter_px,
		"maximum_gutter_px": maximum_gutter_px,
	}


func _find_lowest_same_art_river_seam(seams: Array) -> Dictionary:
	var selected := {}
	var selected_world_y := -INF
	for seam_variant in seams:
		var seam := seam_variant as Dictionary
		if (
			str(seam.get("asset_key", "")) != BAND_SEAM_RIVER_ASSET_KEY
			or not bool(seam.get("has_internal_previous_wrap", false))
		):
			continue
		var world_y := float(seam.get("world_y", -INF))
		if world_y > selected_world_y:
			selected = seam
			selected_world_y = world_y
	return selected


func _save_band_seam_probe(image: Image, seam_y: int, output_path: String) -> bool:
	if image == null or image.is_empty() or seam_y < 0 or image.get_height() < 128:
		return false
	var crop_y := clampi(seam_y - 64, 0, image.get_height() - 128)
	var crop := image.get_region(Rect2i(0, crop_y, image.get_width(), 128))
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return _save_any_size(crop, output_path)


func _capture_different_art_forward_probes(
	fixture: Dictionary,
	renderer: Object,
	seams: Array,
	output_dir: String
) -> Dictionary:
	var flow: Object = fixture.get("flow", null)
	var canvas: CanvasItem = fixture.get("canvas", null) as CanvasItem
	var viewport: SubViewport = fixture.get("viewport", null) as SubViewport
	var drag_state: Object = flow.get("_map_drag_state") if flow != null else null
	if (
		flow == null
		or canvas == null
		or viewport == null
		or renderer == null
		or drag_state == null
		or not drag_state.has_method("apply_zoom_override")
		or seams.size() != BAND_SEAM_EXPECTED_DIFFERENT_ART_SEAM_COUNT
	):
		return {"ready": false, "reason": "fixture_or_seam_count"}
	var initial_model: Dictionary = renderer.call(
		"build_fullscreen_map_model",
		flow,
		VIEWPORT_RECT
	)
	var initial_background: Dictionary = initial_model.get("scroll_background", {})
	var initial_chunks: Array = initial_background.get("draw_chunks", [])
	var world_rect: Rect2 = initial_background.get("world_rect", Rect2())
	if not world_rect.has_area():
		return {"ready": false, "reason": "world_geometry"}
	var target_zoom := BAND_SEAM_FOLD_COMPARISON_ZOOM
	var focus_world_x := world_rect.get_center().x
	var probes: Array[Dictionary] = []
	var worst_entry_body_raw_row_mean_jump := 0.0
	var worst_phase_start_hard_jump_excess := 0.0
	var maximum_snapped_span_error_px := 0.0
	var framebuffer_gutter_total_px := 0
	var framebuffer_gutter_maximum_px := 0
	for seam_variant in seams:
		var seam := seam_variant as Dictionary
		var seam_index := int(seam.get("index", -1))
		if seam_index <= 0 or seam_index >= initial_chunks.size():
			return {
				"ready": false,
				"reason": "initial_chunk_index",
				"seam": seam_index,
			}
		var initial_chunk := initial_chunks[seam_index] as Dictionary
		var initial_body_rect: Rect2 = initial_chunk.get("rect", Rect2())
		if not initial_body_rect.has_area():
			return {"ready": false, "reason": "initial_body", "seam": seam_index}
		var requested_offset := VIEWPORT_RECT.get_center() - Vector2(
			focus_world_x,
			initial_body_rect.position.y
		) * target_zoom
		drag_state.call("apply_zoom_override", target_zoom, requested_offset)
		var frame_model: Dictionary = renderer.call(
			"build_fullscreen_map_model",
			flow,
			VIEWPORT_RECT
		)
		var camera: Dictionary = frame_model.get("camera", {})
		var actual_zoom := float(camera.get("render_zoom_multiplier", -1.0))
		var actual_offset: Vector2 = camera.get("offset", Vector2(INF, INF))
		if not is_equal_approx(actual_zoom, target_zoom) or not actual_offset.is_finite():
			return {
				"ready": false,
				"reason": "camera",
				"seam": seam_index,
				"zoom": actual_zoom,
				"offset": actual_offset,
			}
		var projection := _resolve_different_art_frame_projection(
			renderer,
			frame_model,
			seam
		)
		if not bool(projection.get("ready", false)):
			return {
				"ready": false,
				"reason": "frame_projection",
				"seam": seam_index,
				"projection": projection,
			}
		var entry_body_row := int(projection.get("entry_body_row", -1))
		var phase_start_row := int(projection.get("phase_start_row", -1))
		var content_rect: Rect2 = frame_model.get("content_rect", VIEWPORT_RECT)
		if (
			phase_start_row < int(ceil(content_rect.position.y)) + 64
			or entry_body_row > int(floor(content_rect.end.y)) - 64
		):
			return {
				"ready": false,
				"reason": "seam_visibility",
				"seam": seam_index,
				"entry_body_row": entry_body_row,
				"phase_start_row": phase_start_row,
			}
		var frame := await _capture_next_draw(canvas, viewport)
		var entry_body_probe := _measure_projected_seam_frame(
			frame,
			entry_body_row,
			content_rect
		)
		var phase_start_probe := _measure_projected_phase_start_frame(
			frame,
			phase_start_row,
			content_rect
		)
		if (
			not bool(entry_body_probe.get("ready", false))
			or not bool(phase_start_probe.get("ready", false))
		):
			return {
				"ready": false,
				"reason": "projected_seam_crop",
				"seam": seam_index,
				"entry_body_probe": entry_body_probe,
				"phase_start_probe": phase_start_probe,
			}
		var entry_body_visuals := _measure_framebuffer_seam_visuals(
			frame,
			entry_body_row,
			content_rect,
			false
		)
		var phase_start_visuals := _measure_framebuffer_seam_visuals(
			frame,
			phase_start_row,
			content_rect,
			false
		)
		if (
			not bool(entry_body_visuals.get("ready", false))
			or not bool(phase_start_visuals.get("ready", false))
		):
			return {
				"ready": false,
				"reason": "framebuffer_visual_probe",
				"seam": seam_index,
				"entry_body_visuals": entry_body_visuals,
				"phase_start_visuals": phase_start_visuals,
			}
		if not _save_different_art_vulkan_probe(
			frame,
			phase_start_row,
			entry_body_row,
			content_rect,
			output_dir.path_join(BAND_SEAM_DIFFERENT_ART_PROBE_PATTERN % seam_index)
		):
			return {"ready": false, "reason": "probe_save", "seam": seam_index}
		var forward_span_px := float(entry_body_row - phase_start_row)
		var snapped_entry_span_px := float(projection.get("snapped_entry_span_px", NAN))
		var span_error_px := absf(forward_span_px - snapped_entry_span_px)
		var probe := {
			"seam": seam_index,
			"floor": int(seam.get("floor", -1)),
			"previous_asset_key": str(seam.get("previous_asset_key", "")),
			"asset_key": str(seam.get("asset_key", "")),
			"entry_body_row": entry_body_row,
			"phase_start_row": phase_start_row,
			"native_entry_span": float(projection.get("native_entry_span", NAN)),
			"forward_span_px": forward_span_px,
			"snapped_entry_span_px": snapped_entry_span_px,
			"snapped_span_error_px": span_error_px,
			"entry_body_raw_row_mean_jump": float(
				entry_body_probe.get("raw_row_mean_jump", INF)
			),
			"entry_body_raw_mean_abs_luma_jump": float(
				entry_body_probe.get("raw_mean_abs_luma_jump", INF)
			),
			"entry_body_raw_p95_abs_luma_jump": float(
				entry_body_probe.get("raw_p95_abs_luma_jump", INF)
			),
			"phase_start_raw_row_mean_jump": float(
				phase_start_probe.get("raw_row_mean_jump", INF)
			),
			"phase_start_control_max": float(
				phase_start_probe.get("local_control_max", INF)
			),
			"phase_start_hard_jump_excess": float(
				phase_start_probe.get("hard_jump_excess", INF)
			),
			"entry_body_gutter_px": int(entry_body_visuals.get("gutter", -1)),
			"phase_start_gutter_px": int(phase_start_visuals.get("gutter", -1)),
		}
		probes.append(probe)
		worst_entry_body_raw_row_mean_jump = maxf(
			worst_entry_body_raw_row_mean_jump,
			float(probe.get("entry_body_raw_row_mean_jump", INF))
		)
		worst_phase_start_hard_jump_excess = maxf(
			worst_phase_start_hard_jump_excess,
			float(probe.get("phase_start_hard_jump_excess", INF))
		)
		maximum_snapped_span_error_px = maxf(maximum_snapped_span_error_px, span_error_px)
		for gutter_px in [
			int(probe.get("entry_body_gutter_px", -1)),
			int(probe.get("phase_start_gutter_px", -1)),
		]:
			framebuffer_gutter_total_px += int(gutter_px)
			framebuffer_gutter_maximum_px = maxi(
				framebuffer_gutter_maximum_px,
				int(gutter_px)
			)
		print(
			"[TowerMapBandDifferentForwardVulkanFrameQA] seam=%02d floor=%02d previous=%s current=%s zoom=%.3f phase_start_row=%d entry_body_row=%d native_entry_span=%.1f snapped_span_px=%.1f span_error_px=%.4f entry_body_raw_row_mean_jump=%.4f phase_start_raw_row_mean_jump=%.4f phase_start_control_max=%.4f phase_start_hard_jump_excess=%.4f entry_body_gutter_px=%d phase_start_gutter_px=%d"
				% [
					seam_index,
					int(probe.get("floor", -1)),
					str(probe.get("previous_asset_key", "")),
					str(probe.get("asset_key", "")),
					actual_zoom,
					phase_start_row,
					entry_body_row,
					float(probe.get("native_entry_span", NAN)),
					snapped_entry_span_px,
					span_error_px,
					float(probe.get("entry_body_raw_row_mean_jump", INF)),
					float(probe.get("phase_start_raw_row_mean_jump", INF)),
					float(probe.get("phase_start_control_max", INF)),
					float(probe.get("phase_start_hard_jump_excess", INF)),
					int(probe.get("entry_body_gutter_px", -1)),
					int(probe.get("phase_start_gutter_px", -1)),
				]
		)
	var result := {
		"ready": false,
		"zoom": target_zoom,
		"frame_count": probes.size(),
		"seam_count": seams.size(),
		"probes": probes,
		"worst_entry_body_raw_row_mean_jump": worst_entry_body_raw_row_mean_jump,
		"worst_phase_start_hard_jump_excess": worst_phase_start_hard_jump_excess,
		"maximum_snapped_span_error_px": maximum_snapped_span_error_px,
		"framebuffer_gutter_total_px": framebuffer_gutter_total_px,
		"framebuffer_gutter_maximum_px": framebuffer_gutter_maximum_px,
	}
	if probes.size() != BAND_SEAM_EXPECTED_DIFFERENT_ART_SEAM_COUNT:
		result["reason"] = "frame_count"
		return result
	if maximum_snapped_span_error_px > BAND_SEAM_LIVE_FRAME_STEP_EPSILON_PX:
		result["reason"] = "snapped_entry_span"
		return result
	if (
		worst_entry_body_raw_row_mean_jump
		> BAND_SEAM_REFLECTED_A_RAW_ROW_MEAN_JUMP
			+ BAND_SEAM_REFLECTED_A_RAW_ROW_MEAN_EPSILON
	):
		result["reason"] = "entry_body_raw_discontinuity_exceeds_reflected_A"
		return result
	if worst_phase_start_hard_jump_excess > BAND_SEAM_REFLECTED_A_RAW_ROW_MEAN_EPSILON:
		result["reason"] = "phase_start_hard_jump"
		return result
	if framebuffer_gutter_maximum_px != 0:
		result["reason"] = "framebuffer_gutter"
		return result
	result["ready"] = true
	return result


func _resolve_different_art_frame_projection(
	renderer: Object,
	frame_model: Dictionary,
	seam: Dictionary
) -> Dictionary:
	var background: Dictionary = frame_model.get("scroll_background", {})
	var draw_chunks: Array = background.get("draw_chunks", [])
	var tiles: Array = background.get("tiles", [])
	var seam_index := int(seam.get("index", -1))
	if seam_index <= 0 or seam_index >= draw_chunks.size() or tiles.is_empty():
		return {"ready": false, "reason": "chunk_index"}
	var previous_chunk := draw_chunks[seam_index - 1] as Dictionary
	var chunk := draw_chunks[seam_index] as Dictionary
	if (
		str(chunk.get("seam_kind", "")) != "cross_asset_forward"
		or str(previous_chunk.get("asset_key", ""))
			!= str(seam.get("previous_asset_key", ""))
		or str(chunk.get("asset_key", "")) != str(seam.get("asset_key", ""))
	):
		return {"ready": false, "reason": "chunk_identity"}
	var body_rect: Rect2 = chunk.get("rect", Rect2())
	var entry_rect: Rect2 = chunk.get("seam_entry_rect", Rect2())
	var tile_rect: Rect2 = (tiles[0] as Dictionary).get("rect", Rect2())
	var map_scale := tile_rect.size.x / 692.0
	if not body_rect.has_area() or not entry_rect.has_area() or map_scale <= 0.0:
		return {"ready": false, "reason": "chunk_geometry"}
	var native_entry_span := entry_rect.size.y / map_scale
	if not is_equal_approx(
		native_entry_span,
		BAND_SEAM_EXPECTED_FORWARD_DISSOLVE_WORLD_PX
	):
		return {
			"ready": false,
			"reason": "native_entry_span",
			"actual": native_entry_span,
		}
	var camera: Dictionary = frame_model.get("camera", {})
	var projected_entry := _project_snapped_scroll_rect(renderer, camera, entry_rect)
	var projected_body := _project_snapped_scroll_rect(renderer, camera, body_rect)
	if not projected_entry.has_area() or not projected_body.has_area():
		return {"ready": false, "reason": "projected_geometry"}
	if not is_equal_approx(projected_entry.end.y, projected_body.position.y):
		return {
			"ready": false,
			"reason": "snapped_join_ownership",
			"entry_end_y": projected_entry.end.y,
			"body_start_y": projected_body.position.y,
		}
	return {
		"ready": true,
		"phase_start_row": int(round(projected_entry.position.y)),
		"entry_body_row": int(round(projected_body.position.y)),
		"snapped_entry_span_px": projected_entry.size.y,
		"native_entry_span": native_entry_span,
	}


func _project_snapped_scroll_rect(
	renderer: Object,
	camera: Dictionary,
	world_rect: Rect2
) -> Rect2:
	if renderer == null or not renderer.has_method("snap_scroll_background_rect"):
		return Rect2()
	var zoom := float(camera.get("render_zoom_multiplier", -1.0))
	var offset: Vector2 = camera.get("offset", Vector2(INF, INF))
	if zoom <= 0.0 or not offset.is_finite() or not world_rect.has_area():
		return Rect2()
	var projected := Rect2(
		world_rect.position * zoom + offset,
		world_rect.size * zoom
	)
	var snapped: Rect2 = renderer.call("snap_scroll_background_rect", projected)
	return snapped


func _capture_live_seam_motion(
	fixture: Dictionary,
	renderer: Object,
	river_seam: Dictionary,
	output_dir: String
) -> Dictionary:
	var flow: Object = fixture.get("flow", null)
	var canvas := fixture.get("canvas", null) as CanvasItem
	var viewport := fixture.get("viewport", null) as SubViewport
	var drag_state: Object = flow.get("_map_drag_state") if flow != null else null
	if (
		flow == null
		or canvas == null
		or viewport == null
		or renderer == null
		or drag_state == null
		or not drag_state.has_method("apply_zoom_override")
	):
		return {"ready": false, "reason": "fixture"}
	var initial_model: Dictionary = renderer.call(
		"build_fullscreen_map_model",
		flow,
		VIEWPORT_RECT
	)
	var background: Dictionary = initial_model.get("scroll_background", {})
	var world_rect: Rect2 = background.get("world_rect", Rect2())
	var initial_projection := _resolve_same_art_frame_projection(
		renderer,
		initial_model,
		river_seam
	)
	var seam_world_y := float(initial_projection.get("wrap_world_y", NAN))
	if (
		not world_rect.has_area()
		or not bool(initial_projection.get("ready", false))
		or is_nan(seam_world_y)
	):
		return {"ready": false, "reason": "world_geometry"}
	var focus_world_x := world_rect.get_center().x
	var target_zoom := BAND_SEAM_FOLD_COMPARISON_ZOOM
	var frames: Array[Image] = []
	var seam_crops: Array[Image] = []
	var frame_probes: Array[Dictionary] = []
	var projected_y := PackedFloat32Array()
	var camera_projected_y := PackedFloat32Array()
	var camera_raster_phases := PackedFloat32Array()
	var seam_rows := PackedInt32Array()
	var raster_phases := PackedFloat32Array()
	var actual_offsets: Array[Vector2] = []
	for frame_index in range(BAND_SEAM_LIVE_FRAME_COUNT):
		var screen_shift := (
			(float(frame_index) - float(BAND_SEAM_LIVE_FRAME_COUNT - 1) * 0.5)
			* BAND_SEAM_LIVE_FRAME_STEP_SCREEN_PX
			+ BAND_SEAM_LIVE_FRAME_PHASE_ORIGIN_PX
		)
		var desired_screen_position := VIEWPORT_RECT.get_center() + Vector2(0.0, screen_shift)
		var requested_offset := desired_screen_position - Vector2(
			focus_world_x,
			seam_world_y
		) * target_zoom
		drag_state.call("apply_zoom_override", target_zoom, requested_offset)
		var frame_model: Dictionary = renderer.call(
			"build_fullscreen_map_model",
			flow,
			VIEWPORT_RECT
		)
		var camera: Dictionary = frame_model.get("camera", {})
		var actual_zoom := float(camera.get("render_zoom_multiplier", -1.0))
		var actual_offset: Vector2 = camera.get("offset", Vector2(INF, INF))
		if not is_equal_approx(actual_zoom, target_zoom) or not actual_offset.is_finite():
			return {
				"ready": false,
				"reason": "camera",
				"frame": frame_index,
				"zoom": actual_zoom,
				"offset": actual_offset,
			}
		var actual_camera_projected_y := seam_world_y * actual_zoom + actual_offset.y
		var camera_raster_phase := fposmod(actual_camera_projected_y, 1.0)
		var frame_projection := _resolve_same_art_frame_projection(
			renderer,
			frame_model,
			river_seam
		)
		if not bool(frame_projection.get("ready", false)):
			return {
				"ready": false,
				"reason": "frame_projection",
				"frame": frame_index,
				"projection": frame_projection,
			}
		var actual_projected_y := float(frame_projection.get("boundary_y", NAN))
		var seam_row := int(frame_projection.get("seam_row", -1))
		var raster_phase := float(frame_projection.get("raster_phase", NAN))
		var content_rect: Rect2 = frame_model.get("content_rect", VIEWPORT_RECT)
		if (
			is_nan(actual_projected_y)
			or seam_row < int(ceil(content_rect.position.y)) + 64
			or seam_row > int(floor(content_rect.end.y)) - 64
		):
			return {
				"ready": false,
				"reason": "seam_visibility",
				"frame": frame_index,
				"projected_y": actual_projected_y,
			}
		var frame := await _capture_next_draw(canvas, viewport)
		var frame_probe := _measure_projected_seam_frame(
			frame,
			seam_row,
			content_rect
		)
		if not bool(frame_probe.get("ready", false)):
			return {
				"ready": false,
				"reason": "projected_seam_crop",
				"frame": frame_index,
				"probe": frame_probe,
			}
		var frame_visuals := _measure_framebuffer_seam_visuals(
			frame,
			seam_row,
			content_rect,
			true
		)
		if not bool(frame_visuals.get("ready", false)):
			return {
				"ready": false,
				"reason": "framebuffer_visual_probe",
				"frame": frame_index,
				"probe": frame_visuals,
			}
		frame_probe["gutter"] = int(frame_visuals.get("gutter", -1))
		frame_probe["mirror_correlation"] = float(
			frame_visuals.get("mirror_correlation", -1.0)
		)
		frame_probe["mirror_control"] = float(frame_visuals.get("mirror_control", -1.0))
		frame_probe["mirror_excess"] = float(frame_visuals.get("mirror_excess", INF))
		print(
			"[TowerMapBandProjectedSeamFrameQA] frame=%d camera_projected_y=%.4f exact_boundary_y=%.4f raster_phase=%.4f seam_row=%d crop=%s raw_row_mean_jump=%.4f raw_mean_abs_luma_jump=%.4f raw_p95_abs_luma_jump=%.4f gutter=%d mirror=%.4f control=%.4f mirror_excess=%.4f"
				% [
					frame_index,
					actual_camera_projected_y,
					actual_projected_y,
					raster_phase,
					int(frame_probe.get("seam_row", -1)),
					str(frame_probe.get("sample_rect", Rect2i())),
					float(frame_probe.get("raw_row_mean_jump", INF)),
					float(frame_probe.get("raw_mean_abs_luma_jump", INF)),
					float(frame_probe.get("raw_p95_abs_luma_jump", INF)),
					int(frame_probe.get("gutter", -1)),
					float(frame_probe.get("mirror_correlation", -1.0)),
					float(frame_probe.get("mirror_control", -1.0)),
					float(frame_probe.get("mirror_excess", INF)),
				]
		)
		if not _save(
			frame,
			output_dir.path_join(BAND_SEAM_LIVE_FRAME_PATTERN % frame_index)
		):
			return {"ready": false, "reason": "frame_save", "frame": frame_index}
		frames.append(frame)
		seam_crops.append(frame_probe.get("crop", null) as Image)
		frame_probes.append(frame_probe)
		projected_y.append(actual_projected_y)
		camera_projected_y.append(actual_camera_projected_y)
		camera_raster_phases.append(camera_raster_phase)
		seam_rows.append(seam_row)
		raster_phases.append(raster_phase)
		actual_offsets.append(actual_offset)
	if camera_raster_phases.size() != BAND_SEAM_LIVE_FRAME_COUNT:
		return {"ready": false, "reason": "camera_phase_count"}
	for phase_index in range(camera_raster_phases.size()):
		var phase := float(camera_raster_phases[phase_index])
		if (
			phase <= BAND_SEAM_LIVE_INTEGER_PHASE_EPSILON
			or phase >= 1.0 - BAND_SEAM_LIVE_INTEGER_PHASE_EPSILON
		):
			return {
				"ready": false,
				"reason": "integer_camera_phase",
				"frame": phase_index,
				"camera_raster_phases": camera_raster_phases,
			}
		for previous_phase_index in range(phase_index):
			var phase_distance := absf(
				phase - float(camera_raster_phases[previous_phase_index])
			)
			phase_distance = minf(phase_distance, 1.0 - phase_distance)
			if phase_distance < BAND_SEAM_LIVE_MIN_PHASE_SEPARATION:
				return {
					"ready": false,
					"reason": "duplicate_camera_phase",
					"frame": phase_index,
					"camera_raster_phases": camera_raster_phases,
				}
	if not _save_live_motion_contact_sheet(
		frames,
		seam_rows,
		output_dir.path_join(BAND_SEAM_LIVE_CONTACT_NAME)
	):
		return {"ready": false, "reason": "contact_save"}
	var projected_step_px := PackedFloat32Array()
	var camera_projected_step_px := PackedFloat32Array()
	for frame_index in range(1, projected_y.size()):
		var projected_step := (
			float(projected_y[frame_index]) - float(projected_y[frame_index - 1])
		)
		var camera_projected_step := (
			float(camera_projected_y[frame_index])
				- float(camera_projected_y[frame_index - 1])
		)
		projected_step_px.append(projected_step)
		camera_projected_step_px.append(camera_projected_step)
		if (
			absf(camera_projected_step - BAND_SEAM_LIVE_FRAME_STEP_SCREEN_PX)
			> BAND_SEAM_LIVE_FRAME_STEP_EPSILON_PX
			or projected_step <= 0.0
		):
			return {
				"ready": false,
				"reason": "projected_step",
				"projected_y": projected_y,
				"projected_step_px": projected_step_px,
				"camera_projected_y": camera_projected_y,
				"camera_projected_step_px": camera_projected_step_px,
				"offsets": actual_offsets,
			}
	var changed_sample_px := PackedInt32Array()
	var changed_sample_ratio := PackedFloat32Array()
	var aligned_crop_rgb_mae := PackedFloat32Array()
	for frame_index in range(1, frames.size()):
		var changed := _count_changed_sample_pixels(
			frames[frame_index - 1],
			frames[frame_index]
		)
		var changed_ratio := (
			float(changed)
			/ float(BAND_SEAM_MOTION_SAMPLE_SIZE.x * BAND_SEAM_MOTION_SAMPLE_SIZE.y)
		)
		var aligned_mae := _mean_abs_rgb_image_delta(
			seam_crops[frame_index - 1],
			seam_crops[frame_index]
		)
		changed_sample_px.append(changed)
		changed_sample_ratio.append(changed_ratio)
		aligned_crop_rgb_mae.append(aligned_mae)
		if changed_ratio < BAND_SEAM_LIVE_MIN_CHANGED_SAMPLE_RATIO:
			return {
				"ready": false,
				"reason": "insufficient_screen_motion",
				"frame": frame_index,
				"changed_sample_px": changed_sample_px,
				"changed_sample_ratio": changed_sample_ratio,
			}
		if aligned_mae > BAND_SEAM_LIVE_MAX_ALIGNED_CROP_RGB_MAE:
			return {
				"ready": false,
				"reason": "incoherent_seam_motion",
				"frame": frame_index,
				"aligned_crop_rgb_mae": aligned_crop_rgb_mae,
			}
	var raw_row_mean_jump := PackedFloat32Array()
	var raw_mean_abs_luma_jump := PackedFloat32Array()
	var raw_p95_abs_luma_jump := PackedFloat32Array()
	var worst_raw_row_mean_jump := 0.0
	var minimum_raw_row_mean_jump := INF
	var framebuffer_gutter_total_px := 0
	var framebuffer_gutter_maximum_px := 0
	var framebuffer_mirror_values: Array[float] = []
	var framebuffer_mirror_control_values: Array[float] = []
	var framebuffer_mirror_excess_values: Array[float] = []
	for frame_probe in frame_probes:
		var raw_jump := float(frame_probe.get("raw_row_mean_jump", INF))
		raw_row_mean_jump.append(raw_jump)
		raw_mean_abs_luma_jump.append(
			float(frame_probe.get("raw_mean_abs_luma_jump", INF))
		)
		raw_p95_abs_luma_jump.append(
			float(frame_probe.get("raw_p95_abs_luma_jump", INF))
		)
		worst_raw_row_mean_jump = maxf(worst_raw_row_mean_jump, raw_jump)
		minimum_raw_row_mean_jump = minf(minimum_raw_row_mean_jump, raw_jump)
		var gutter_px := int(frame_probe.get("gutter", -1))
		framebuffer_gutter_total_px += gutter_px
		framebuffer_gutter_maximum_px = maxi(framebuffer_gutter_maximum_px, gutter_px)
		framebuffer_mirror_values.append(
			float(frame_probe.get("mirror_correlation", -1.0))
		)
		framebuffer_mirror_control_values.append(
			float(frame_probe.get("mirror_control", -1.0))
		)
		framebuffer_mirror_excess_values.append(
			float(frame_probe.get("mirror_excess", INF))
		)
	var raw_row_mean_jump_range := worst_raw_row_mean_jump - minimum_raw_row_mean_jump
	var framebuffer_mirror_mean := _mean_float_values(framebuffer_mirror_values)
	var framebuffer_mirror_control_mean := _mean_float_values(
		framebuffer_mirror_control_values
	)
	var framebuffer_mirror_excess_mean := _mean_float_values(
		framebuffer_mirror_excess_values
	)
	var framebuffer_mirror_excess_p95 := _percentile_float_values(
		framebuffer_mirror_excess_values,
		0.95
	)
	var result := {
		"ready": false,
		"zoom": target_zoom,
		"frame_count": frames.size(),
		"projected_y": projected_y,
		"projected_step_px": projected_step_px,
		"camera_projected_y": camera_projected_y,
		"camera_projected_step_px": camera_projected_step_px,
		"camera_raster_phases": camera_raster_phases,
		"seam_rows": seam_rows,
		"raster_phases": raster_phases,
		"actual_offsets": actual_offsets,
		"changed_sample_px": changed_sample_px,
		"changed_sample_ratio": changed_sample_ratio,
		"aligned_crop_rgb_mae": aligned_crop_rgb_mae,
		"raw_row_mean_jump": raw_row_mean_jump,
		"raw_mean_abs_luma_jump": raw_mean_abs_luma_jump,
		"raw_p95_abs_luma_jump": raw_p95_abs_luma_jump,
		"worst_raw_row_mean_jump": worst_raw_row_mean_jump,
		"raw_row_mean_jump_range": raw_row_mean_jump_range,
		"framebuffer_gutter_total_px": framebuffer_gutter_total_px,
		"framebuffer_gutter_maximum_px": framebuffer_gutter_maximum_px,
		"framebuffer_mirror_mean": framebuffer_mirror_mean,
		"framebuffer_mirror_control_mean": framebuffer_mirror_control_mean,
		"framebuffer_mirror_excess_mean": framebuffer_mirror_excess_mean,
		"framebuffer_mirror_excess_p95": framebuffer_mirror_excess_p95,
	}
	print(
		"[TowerMapBandProjectedSeamVulkanGate] frames=%d metric=raw_abs_row_mean_luma values=%s worst=%.4f reflected_A=%.4f epsilon=%.4f range=%.4f gutter_total_px=%d gutter_maximum_px=%d mirror_mean=%.4f mirror_control_mean=%.4f mirror_excess_mean=%.4f mirror_excess_p95=%.4f changed_ratio=%s aligned_crop_rgb_mae=%s"
			% [
				frames.size(),
				str(raw_row_mean_jump),
				worst_raw_row_mean_jump,
				BAND_SEAM_REFLECTED_A_RAW_ROW_MEAN_JUMP,
				BAND_SEAM_REFLECTED_A_RAW_ROW_MEAN_EPSILON,
				raw_row_mean_jump_range,
				framebuffer_gutter_total_px,
				framebuffer_gutter_maximum_px,
				framebuffer_mirror_mean,
				framebuffer_mirror_control_mean,
				framebuffer_mirror_excess_mean,
				framebuffer_mirror_excess_p95,
				str(changed_sample_ratio),
				str(aligned_crop_rgb_mae),
			]
	)
	if (
		worst_raw_row_mean_jump
		> BAND_SEAM_REFLECTED_A_RAW_ROW_MEAN_JUMP
			+ BAND_SEAM_REFLECTED_A_RAW_ROW_MEAN_EPSILON
	):
		result["reason"] = "raw_discontinuity_exceeds_reflected_A"
		return result
	if raw_row_mean_jump_range > BAND_SEAM_LIVE_MAX_RAW_JUMP_RANGE:
		result["reason"] = "raw_discontinuity_unstable_across_motion"
		return result
	if framebuffer_gutter_maximum_px != 0:
		result["reason"] = "framebuffer_gutter"
		return result
	if (
		framebuffer_mirror_excess_mean > BAND_SEAM_MIRROR_MEAN_EXCESS_LIMIT
		or framebuffer_mirror_excess_p95 > BAND_SEAM_MIRROR_P95_EXCESS_LIMIT
	):
		result["reason"] = "framebuffer_mirror_excess"
		return result
	result["ready"] = true
	return result


func _resolve_same_art_frame_projection(
	renderer: Object,
	frame_model: Dictionary,
	seam: Dictionary
) -> Dictionary:
	var background: Dictionary = frame_model.get("scroll_background", {})
	var draw_chunks: Array = background.get("draw_chunks", [])
	var seam_index := int(seam.get("index", -1))
	if seam_index <= 0 or seam_index >= draw_chunks.size():
		return {"ready": false, "reason": "chunk_index"}
	var previous_chunk := draw_chunks[seam_index - 1] as Dictionary
	var chunk := draw_chunks[seam_index] as Dictionary
	var expected_asset_key := str(seam.get("asset_key", ""))
	if (
		str(chunk.get("seam_kind", "")) != "same_asset_butt"
		or str(previous_chunk.get("asset_key", "")) != expected_asset_key
		or str(chunk.get("asset_key", "")) != expected_asset_key
	):
		return {"ready": false, "reason": "chunk_identity"}
	var previous_body_rect: Rect2 = previous_chunk.get("rect", Rect2())
	var previous_source_rect: Rect2 = previous_chunk.get(
		"normalized_source_rect",
		Rect2()
	)
	var current_source_rect: Rect2 = chunk.get("normalized_source_rect", Rect2())
	if (
		not previous_body_rect.has_area()
		or not previous_source_rect.has_area()
		or not current_source_rect.has_area()
	):
		return {"ready": false, "reason": "source_geometry"}
	var source_start := previous_source_rect.position.y
	var source_span := previous_source_rect.size.y
	var expected_current_source_start := fposmod(source_start + source_span, 1.0)
	if not is_equal_approx(
		fposmod(current_source_rect.position.y, 1.0),
		expected_current_source_start
	):
		return {
			"ready": false,
			"reason": "source_phase_continuity",
			"expected": expected_current_source_start,
			"actual": current_source_rect.position.y,
		}
	var next_wrap_v := floorf(source_start) + 1.0
	if (
		source_span <= 0.0
		or next_wrap_v <= source_start + 0.000001
		or next_wrap_v >= source_start + source_span - 0.000001
	):
		return {
			"ready": false,
			"reason": "wrap_phase",
			"source_start": source_start,
			"source_span": source_span,
		}
	var wrap_t := (next_wrap_v - source_start) / source_span
	var wrap_world_y := lerpf(
		previous_body_rect.position.y,
		previous_body_rect.end.y,
		wrap_t
	)
	var camera: Dictionary = frame_model.get("camera", {})
	var projected_body := _project_snapped_scroll_rect(
		renderer,
		camera,
		previous_body_rect
	)
	if not projected_body.has_area():
		return {"ready": false, "reason": "projected_body"}
	var boundary_y := lerpf(
		projected_body.position.y,
		projected_body.end.y,
		wrap_t
	)
	# Image row N samples the framebuffer at N + 0.5. Select the first row whose
	# center is on or below the exact UV wrap; this remains correct when the
	# renderer rounded a negative body start and a positive body end separately.
	var seam_row := int(ceil(boundary_y - 0.5))
	return {
		"ready": true,
		"wrap_world_y": wrap_world_y,
		"boundary_y": boundary_y,
		"seam_row": seam_row,
		"raster_phase": fposmod(boundary_y - 0.5, 1.0),
		"wrap_t": wrap_t,
		"projected_body": projected_body,
	}


func _capture_next_draw(canvas: CanvasItem, viewport: SubViewport) -> Image:
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _count_changed_sample_pixels(before: Image, after: Image) -> int:
	if before == null or after == null or before.is_empty() or after.is_empty():
		return 0
	var before_sample := before.duplicate()
	var after_sample := after.duplicate()
	before_sample.resize(
		BAND_SEAM_MOTION_SAMPLE_SIZE.x,
		BAND_SEAM_MOTION_SAMPLE_SIZE.y,
		Image.INTERPOLATE_LANCZOS
	)
	after_sample.resize(
		BAND_SEAM_MOTION_SAMPLE_SIZE.x,
		BAND_SEAM_MOTION_SAMPLE_SIZE.y,
		Image.INTERPOLATE_LANCZOS
	)
	var changed := 0
	for y in range(before_sample.get_height()):
		for x in range(before_sample.get_width()):
			var first: Color = before_sample.get_pixel(x, y)
			var second: Color = after_sample.get_pixel(x, y)
			if (
				absf(first.r - second.r)
				+ absf(first.g - second.g)
				+ absf(first.b - second.b)
				> 0.01
			):
				changed += 1
	return changed


func _measure_projected_seam_frame(
	frame: Image,
	seam_row: int,
	content_rect: Rect2
) -> Dictionary:
	if frame == null or frame.is_empty() or frame.get_size() != GAME_SIZE:
		return {"ready": false, "reason": "frame"}
	var content_start_x := clampi(int(ceil(content_rect.position.x)), 0, frame.get_width())
	var content_end_x := clampi(int(floor(content_rect.end.x)), 0, frame.get_width())
	var sample_start_x := content_start_x + BAND_SEAM_LIVE_SAMPLE_X_INSET_PX
	var sample_end_x := content_end_x - BAND_SEAM_LIVE_SAMPLE_X_INSET_PX
	if sample_end_x - sample_start_x < BAND_SEAM_LIVE_MIN_SAMPLE_WIDTH_PX:
		return {
			"ready": false,
			"reason": "sample_width",
			"content_rect": content_rect,
			"sample_width": sample_end_x - sample_start_x,
		}
	var crop_start_y := seam_row - BAND_SEAM_LIVE_SAMPLE_RADIUS_PX
	var crop_end_y := seam_row + BAND_SEAM_LIVE_SAMPLE_RADIUS_PX
	if seam_row <= 0 or crop_start_y < 0 or crop_end_y > frame.get_height():
		return {
			"ready": false,
			"reason": "sample_y",
			"seam_row": seam_row,
		}
	var above_luma_total := 0.0
	var below_luma_total := 0.0
	var absolute_luma_total := 0.0
	var absolute_luma_values: Array[float] = []
	for x in range(sample_start_x, sample_end_x):
		var above := _color_luma_255(frame.get_pixel(x, seam_row - 1))
		var below := _color_luma_255(frame.get_pixel(x, seam_row))
		var absolute_delta := absf(below - above)
		above_luma_total += above
		below_luma_total += below
		absolute_luma_total += absolute_delta
		absolute_luma_values.append(absolute_delta)
	var sample_count := sample_end_x - sample_start_x
	if sample_count <= 0:
		return {"ready": false, "reason": "sample_count"}
	var sample_rect := Rect2i(
		sample_start_x,
		crop_start_y,
		sample_count,
		crop_end_y - crop_start_y
	)
	return {
		"ready": true,
		"seam_row": seam_row,
		"sample_rect": sample_rect,
		"crop": frame.get_region(sample_rect),
		"raw_row_mean_jump": absf(
			below_luma_total / float(sample_count)
				- above_luma_total / float(sample_count)
		),
		"raw_mean_abs_luma_jump": absolute_luma_total / float(sample_count),
		"raw_p95_abs_luma_jump": _percentile_float_values(
			absolute_luma_values,
			0.95
		),
	}


func _measure_framebuffer_seam_visuals(
	frame: Image,
	seam_row: int,
	content_rect: Rect2,
	include_mirror: bool
) -> Dictionary:
	if frame == null or frame.is_empty() or frame.get_size() != GAME_SIZE:
		return {"ready": false, "reason": "frame"}
	var content_start_x := clampi(int(ceil(content_rect.position.x)), 0, frame.get_width())
	var content_end_x := clampi(int(floor(content_rect.end.x)), 0, frame.get_width())
	var sample_start_x := content_start_x + BAND_SEAM_LIVE_SAMPLE_X_INSET_PX
	var sample_end_x := content_end_x - BAND_SEAM_LIVE_SAMPLE_X_INSET_PX
	var sample_width := sample_end_x - sample_start_x
	if sample_width < BAND_SEAM_LIVE_MIN_SAMPLE_WIDTH_PX:
		return {
			"ready": false,
			"reason": "sample_width",
			"sample_width": sample_width,
		}
	var mirror_extent := (
		BAND_SEAM_MIRROR_CONTROL_OFFSET_PX
		+ BAND_SEAM_MIRROR_CORRELATION_RADIUS_PX
	)
	if (
		seam_row - BAND_SEAM_GUTTER_SEARCH_RADIUS_PX < 0
		or seam_row + BAND_SEAM_GUTTER_SEARCH_RADIUS_PX >= frame.get_height()
		or (
			include_mirror
			and (
				seam_row - mirror_extent < 0
				or seam_row + mirror_extent > frame.get_height()
			)
		)
	):
		return {
			"ready": false,
			"reason": "sample_y",
			"seam_row": seam_row,
		}
	# Preserve framebuffer Y exactly. Only X is reduced by the existing luma/detail
	# helpers, so gutter width, radius, and offset remain native framebuffer pixels.
	var gutter_crop := frame.get_region(Rect2i(
		sample_start_x,
		seam_row - BAND_SEAM_GUTTER_SEARCH_RADIUS_PX,
		sample_width,
		BAND_SEAM_GUTTER_SEARCH_RADIUS_PX * 2 + 1
	))
	var gutter_rows := _measure_row_luma(gutter_crop)
	var gutter_details := _measure_row_detail(gutter_crop)
	var gutter := _measure_bright_gutter_band(
		gutter_rows,
		gutter_details,
		BAND_SEAM_GUTTER_SEARCH_RADIUS_PX,
		BAND_SEAM_GUTTER_SEARCH_RADIUS_PX
	)
	var result := {
		"ready": true,
		"gutter": int(gutter.get("width", 0)),
		"gutter_offset": int(gutter.get("center_offset", 0)),
		"sample_width": sample_width,
		"framebuffer_y_scale": 1.0,
	}
	if not include_mirror:
		return result
	# Correlation and both local controls use the unscaled Vulkan framebuffer
	# crop. The result and excess thresholds are therefore dimensionless.
	var mirror_crop := frame.get_region(Rect2i(
		sample_start_x,
		seam_row - mirror_extent,
		sample_width,
		mirror_extent * 2
	))
	var local_seam_row := mirror_extent
	var mirror_correlation := _measure_seam_mirror_correlation(
		mirror_crop,
		local_seam_row,
		BAND_SEAM_MIRROR_CORRELATION_RADIUS_PX
	)
	var controls: Array[float] = []
	for control_row in [
		local_seam_row - BAND_SEAM_MIRROR_CONTROL_OFFSET_PX,
		local_seam_row + BAND_SEAM_MIRROR_CONTROL_OFFSET_PX,
	]:
		var control_row_index := int(control_row)
		var control := _measure_seam_mirror_correlation(
			mirror_crop,
			control_row_index,
			BAND_SEAM_MIRROR_CORRELATION_RADIUS_PX
		)
		if control < -0.999:
			return {"ready": false, "reason": "mirror_control_bounds"}
		controls.append(control)
	if mirror_correlation < -0.999 or controls.size() != 2:
		return {"ready": false, "reason": "mirror_bounds"}
	var mirror_control := _mean_float_values(controls)
	result["mirror_correlation"] = mirror_correlation
	result["mirror_control"] = mirror_control
	result["mirror_excess"] = mirror_correlation - mirror_control
	return result


func _measure_projected_phase_start_frame(
	frame: Image,
	seam_row: int,
	content_rect: Rect2
) -> Dictionary:
	var result := _measure_projected_seam_frame(frame, seam_row, content_rect)
	if not bool(result.get("ready", false)):
		return result
	var measured_seam_row := int(result.get("seam_row", -1))
	var sample_rect: Rect2i = result.get("sample_rect", Rect2i())
	var local_control_jumps: Array[float] = []
	for row_offset in range(
		-BAND_SEAM_PHASE_START_CONTROL_RADIUS_PX,
		BAND_SEAM_PHASE_START_CONTROL_RADIUS_PX + 1
	):
		if row_offset == 0:
			continue
		var below_row := measured_seam_row + row_offset
		if below_row <= 0 or below_row >= frame.get_height():
			return {"ready": false, "reason": "phase_control_bounds"}
		local_control_jumps.append(
			_raw_row_mean_luma_jump(
				frame,
				sample_rect.position.x,
				sample_rect.end.x,
				below_row
			)
		)
	var local_control_max := 0.0
	for control_jump in local_control_jumps:
		local_control_max = maxf(local_control_max, control_jump)
	result["local_control_jumps"] = local_control_jumps
	result["local_control_max"] = local_control_max
	# This is deliberately a separately named local hard-spike diagnostic. The
	# phase-start raw jump above remains intact; unlike the same-art acceptance
	# gate, this comparison only asks whether alpha=0 introduced a new spike above
	# the neighboring Vulkan row transitions in the same captured frame.
	result["hard_jump_excess"] = maxf(
		0.0,
		float(result.get("raw_row_mean_jump", INF)) - local_control_max
	)
	return result


func _raw_row_mean_luma_jump(
	frame: Image,
	sample_start_x: int,
	sample_end_x: int,
	below_row: int
) -> float:
	var sample_count := sample_end_x - sample_start_x
	if (
		frame == null
		or frame.is_empty()
		or sample_count <= 0
		or below_row <= 0
		or below_row >= frame.get_height()
	):
		return INF
	var above_luma_total := 0.0
	var below_luma_total := 0.0
	for x in range(sample_start_x, sample_end_x):
		above_luma_total += _color_luma_255(frame.get_pixel(x, below_row - 1))
		below_luma_total += _color_luma_255(frame.get_pixel(x, below_row))
	return absf(
		below_luma_total / float(sample_count)
			- above_luma_total / float(sample_count)
	)


func _save_different_art_vulkan_probe(
	frame: Image,
	phase_start_row: int,
	entry_body_row: int,
	content_rect: Rect2,
	output_path: String
) -> bool:
	if frame == null or frame.is_empty() or frame.get_size() != GAME_SIZE:
		return false
	var crop_start_x := clampi(
		int(ceil(content_rect.position.x)) + BAND_SEAM_LIVE_SAMPLE_X_INSET_PX,
		0,
		frame.get_width()
	)
	var crop_end_x := clampi(
		int(floor(content_rect.end.x)) - BAND_SEAM_LIVE_SAMPLE_X_INSET_PX,
		0,
		frame.get_width()
	)
	var crop_start_y := maxi(0, phase_start_row - 32)
	var crop_end_y := mini(
		frame.get_height(),
		entry_body_row + 33
	)
	if crop_end_x <= crop_start_x or crop_end_y <= crop_start_y:
		return false
	var crop := frame.get_region(Rect2i(
		crop_start_x,
		crop_start_y,
		crop_end_x - crop_start_x,
		crop_end_y - crop_start_y
	))
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return _save_any_size(crop, output_path)


func _color_luma_255(color: Color) -> float:
	return (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) * 255.0


func _mean_abs_rgb_image_delta(before: Image, after: Image) -> float:
	if (
		before == null
		or after == null
		or before.is_empty()
		or after.is_empty()
		or before.get_size() != after.get_size()
	):
		return INF
	var before_sample := before.duplicate()
	var after_sample := after.duplicate()
	before_sample.resize(512, 64, Image.INTERPOLATE_LANCZOS)
	after_sample.resize(512, 64, Image.INTERPOLATE_LANCZOS)
	var absolute_rgb_total := 0.0
	for y in range(before_sample.get_height()):
		for x in range(before_sample.get_width()):
			var first: Color = before_sample.get_pixel(x, y)
			var second: Color = after_sample.get_pixel(x, y)
			absolute_rgb_total += (
				absf(first.r - second.r)
				+ absf(first.g - second.g)
				+ absf(first.b - second.b)
			) / 3.0 * 255.0
	return absolute_rgb_total / float(
		before_sample.get_width() * before_sample.get_height()
	)


func _save_live_motion_contact_sheet(
	frames: Array[Image],
	seam_rows: PackedInt32Array,
	output_path: String
) -> bool:
	if frames.is_empty() or frames.size() != seam_rows.size():
		return false
	var crop_height := 192
	var contact := Image.create(
		GAME_SIZE.x,
		crop_height * frames.size(),
		false,
		Image.FORMAT_RGBA8
	)
	for frame_index in range(frames.size()):
		var frame := frames[frame_index]
		if frame == null or frame.is_empty() or frame.get_size() != GAME_SIZE:
			return false
		var crop_y := clampi(
			int(seam_rows[frame_index]) - crop_height / 2,
			0,
			frame.get_height() - crop_height
		)
		var crop := frame.get_region(Rect2i(0, crop_y, GAME_SIZE.x, crop_height))
		crop.convert(contact.get_format())
		contact.blit_rect(
			crop,
			Rect2i(Vector2i.ZERO, crop.get_size()),
			Vector2i(0, frame_index * crop_height)
		)
	return _save_any_size(contact, output_path)


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
		var alpha := clampf(
			float(y) / float(maxi(1, mini(height, fade_height) - 1)),
			0.0,
			1.0
		)
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
		local_reference + BAND_SEAM_GUTTER_LOCAL_LUMA_DELTA
	)
	var run_start := -1
	var best_start := -1
	var best_end := -1
	for y in range(minimum_y, maximum_y + 1):
		var bright := (
			y < maximum_y
			and float(rows[y]) >= adaptive_threshold
			and float(details[y]) <= BAND_SEAM_GUTTER_MAX_DETAIL
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
