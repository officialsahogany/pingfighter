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
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)
const TowerAscentMapCameraModel := preload(
	"res://scripts/tower_ascent/tower_ascent_map_camera_model.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const GAME_SIZE := Vector2i(2020, 1246)
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(GAME_SIZE))
const OUTPUT_DIR := "res://.godot/codex_captures/tower_map_drag_zoom_overlap"
const OUTPUT_NAME := "tower_map_drag_zoom_overlap_strip.png"
const SAMPLE_STEP := 32
const MIN_CHANGED_SAMPLES := 10


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("drag/zoom overlap visual QA requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("drag/zoom overlap visual QA requires Vulkan")
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("drag/zoom overlap output directory could not be created")
		return
	var flow := TowerAscentFlowOwner.new()
	var registry := TowerMapOverlayVisualQa.CaptureRegistry.new(flow)
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := TowerMapOverlayVisualQa.ProductionScreenCanvas.new(registry)
	viewport.add_child(canvas)
	var flow_context := {
		"run_id": "map-drag-zoom-overlap-visual-evidence",
		"current_stage": 4,
		"map_seed": 83521,
		"registry": registry,
	}
	var begin_context := flow_context.duplicate(false)
	begin_context.erase("registry")
	begin_context.erase("current_stage")
	if not flow.begin_vertical_slice(null, Callable(), begin_context):
		_fail("drag/zoom overlap fixture could not begin the production flow")
		return
	if not flow.open_map_overlay(canvas, registry, flow_context):
		_fail("drag/zoom overlap fixture could not open the production map")
		return
	flow.set_map_overlay_fade_progress_for_qa(1.0)
	var transition_source_id := _node_id_for_floor(flow, 4)
	if transition_source_id.is_empty():
		_fail("drag/zoom overlap fixture could not locate floor 4")
		return
	flow.set("_current_node_id", transition_source_id)
	flow.set("_route_source_node_id", transition_source_id)
	flow.set(
		"_route_target_ids",
		flow.call("_outgoing_target_ids", transition_source_id)
	)
	flow.call("_refresh_route_target_cache")
	flow.close_map_overlay()
	flow.call("_finish_map_overlay_close")
	var transition_target := _choose_noncombat_target(flow)
	if transition_target.is_empty():
		_fail("drag/zoom overlap fixture has no route target")
		return
	flow.call("_resolve_route_target", transition_target)
	if flow.get_phase_name() != "MAP_TRANSITION":
		_fail("drag/zoom overlap fixture did not enter MAP_TRANSITION")
		return
	var overlap_start_elapsed := (
		_zoom_end_elapsed_sec()
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC * 0.25
	)
	flow.set_transition_progress_for_qa(
		overlap_start_elapsed / _transition_duration_sec()
	)
	var press_position := VIEWPORT_RECT.get_center()
	var first_position := press_position + Vector2(48.0, 72.0)
	flow.handle_input(_mouse_button(press_position, true))
	flow.handle_input(_mouse_motion(first_position))
	var before_image := await _capture(canvas, viewport)
	var renderer: Object = flow.get("_renderer")
	var before_camera: Dictionary = renderer.get_last_fullscreen_camera_model()
	var before_zoom := float(before_camera.get("render_zoom_multiplier", 1.0))
	var before_anchor := (
		(before_camera.get("visible_world_rect", Rect2()) as Rect2).get_center()
	)
	if not bool(before_camera.get("horizontal_world_fits", false)):
		_fail("drag/zoom overlap fixture must begin with horizontal fit")
		return
	flow.set_transition_progress_for_qa(
		(
			overlap_start_elapsed
			+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC * 0.5
		) / _transition_duration_sec()
	)
	var second_delta := Vector2(24.0, 36.0)
	var second_position := first_position + second_delta
	flow.handle_input(_mouse_motion(second_position))
	var live_manual_offset: Vector2 = flow.get_map_camera_manual_offset()
	flow.handle_input(_mouse_button(second_position, false))
	var after_image := await _capture(canvas, viewport)
	var after_camera: Dictionary = renderer.get_last_fullscreen_camera_model()
	var after_zoom := float(after_camera.get("render_zoom_multiplier", before_zoom))
	var after_anchor := (
		(after_camera.get("visible_world_rect", Rect2()) as Rect2).get_center()
	)
	var actual_anchor_delta := after_anchor - before_anchor
	if is_equal_approx(before_zoom, after_zoom):
		_fail("drag/zoom overlap fixture did not advance automatic zoom")
		return
	if bool(after_camera.get("horizontal_world_fits", true)):
		_fail("drag/zoom overlap fixture must reopen horizontal range")
		return
	var previous_manual_offset: Vector2 = before_camera.get(
		"manual_camera_offset",
		live_manual_offset
	)
	var expected_manual_offset := TowerAscentMapCameraModel.cursor_anchored_offset(
		(before_camera.get("view_rect", VIEWPORT_RECT) as Rect2).get_center(),
		before_camera.get("offset", live_manual_offset),
		before_zoom,
		after_zoom
	)
	expected_manual_offset += (
		(live_manual_offset - previous_manual_offset)
		* (after_zoom / before_zoom)
	)
	var after_manual_offset: Vector2 = flow.get_map_camera_manual_offset()
	if not after_manual_offset.is_equal_approx(expected_manual_offset):
		_fail(
			"drag/zoom overlap lost live pan: manual=%s expected=%s"
			% [str(after_manual_offset), str(expected_manual_offset)]
		)
		return
	var changed_samples := _count_changed_samples(before_image, after_image)
	if changed_samples < MIN_CHANGED_SAMPLES:
		_fail("drag/zoom overlap capture did not visibly change enough pixels")
		return
	var output_path := output_dir.path_join(OUTPUT_NAME)
	if not _save_strip(before_image, after_image, output_path):
		_fail("drag/zoom overlap strip could not be saved")
		return
	print(
		"[TowerMapDragZoomOverlapVisualQA] drag=(48,72)+(24,36) horizontal_fit_before=true horizontal_fit_after=false before_zoom=%0.6f after_zoom=%0.6f actual_anchor_delta=%s manual=%s expected_manual=%s changed_samples=%d"
		% [
			before_zoom,
			after_zoom,
			str(actual_anchor_delta),
			str(after_manual_offset),
			str(expected_manual_offset),
			changed_samples,
		]
	)
	print("[TowerMapDragZoomOverlapVisualQA] output=%s" % output_path)
	print("tower_map_drag_zoom_overlap_visual_qa: ok")
	_cleanup(flow, viewport)
	canvas = null
	registry = null
	flow = null
	await process_frame
	await process_frame
	quit(0)


func _capture(canvas: CanvasItem, viewport: SubViewport) -> Image:
	canvas.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	return viewport.get_texture().get_image()


func _mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	return event


func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event


func _node_id_for_floor(flow: Object, floor_number: int) -> String:
	for node_variant in flow.get_graph_nodes():
		if (
			node_variant is Dictionary
			and int((node_variant as Dictionary).get("floor", 0)) == floor_number
		):
			return str((node_variant as Dictionary).get("id", ""))
	return ""


func _choose_noncombat_target(flow: Object) -> String:
	var fallback := ""
	for target_id in flow.get_route_target_ids():
		if fallback.is_empty():
			fallback = target_id
		for node_variant in flow.get_graph_nodes():
			if not (node_variant is Dictionary):
				continue
			var node := node_variant as Dictionary
			if (
				str(node.get("id", "")) == target_id
				and str(node.get("kind", ""))
					in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS
			):
				return target_id
	return fallback


func _count_changed_samples(before_image: Image, after_image: Image) -> int:
	if (
		before_image == null
		or after_image == null
		or before_image.is_empty()
		or after_image.is_empty()
		or before_image.get_size() != GAME_SIZE
		or after_image.get_size() != GAME_SIZE
	):
		return 0
	var changed := 0
	for y in range(0, GAME_SIZE.y, SAMPLE_STEP):
		for x in range(0, GAME_SIZE.x, SAMPLE_STEP):
			var before_pixel := before_image.get_pixel(x, y)
			var after_pixel := after_image.get_pixel(x, y)
			if (
				absf(before_pixel.r - after_pixel.r) > 0.02
				or absf(before_pixel.g - after_pixel.g) > 0.02
				or absf(before_pixel.b - after_pixel.b) > 0.02
			):
				changed += 1
	return changed


func _save_strip(before_image: Image, after_image: Image, path: String) -> bool:
	if before_image == null or after_image == null:
		return false
	var cell_size := Vector2i(GAME_SIZE.x / 2, GAME_SIZE.y / 2)
	var strip := Image.create(GAME_SIZE.x, cell_size.y, false, Image.FORMAT_RGBA8)
	strip.fill(Color("17110d"))
	for index in range(2):
		var frame := before_image.duplicate() if index == 0 else after_image.duplicate()
		frame.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
		frame.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(
			frame,
			Rect2i(Vector2i.ZERO, cell_size),
			Vector2i(index * cell_size.x, 0)
		)
	return strip.save_png(path) == OK


func _zoom_end_elapsed_sec() -> float:
	return (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
	)


func _transition_duration_sec() -> float:
	return (
		_zoom_end_elapsed_sec()
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)


func _cleanup(flow: Object, viewport: SubViewport) -> void:
	if flow != null and flow.has_method("is_active") and bool(flow.is_active()):
		flow.call("_finish_vertical_slice")
	if viewport != null:
		get_root().remove_child(viewport)
		viewport.free()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()


func _fail(message: String) -> void:
	push_error(message)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	quit(1)
