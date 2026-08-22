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
