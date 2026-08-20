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
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const GAME_SIZE := Vector2i(2020, 1246)
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(GAME_SIZE))
const PHYSICS_HZ := 72
const PHYSICS_DELTA_SEC := 1.0 / float(PHYSICS_HZ)
const ZOOM_BOUNDARY_SCALE_EPSILON := 0.0002
const ZOOM_BOUNDARY_CENTER_EPSILON_PX := 0.25
const OUTPUT_DIR := "res://.godot/codex_captures/tower_map_camera_tracking"
const LOWER_NAME := "map_camera_floor01_lower.png"
const MIDDLE_NAME := "map_camera_floor05_middle.png"
const UPPER_NAME := "map_camera_floor09_upper.png"
const CROSSING_NAME := "map_camera_curve_crossing_zoom4.png"
const STRIP_NAME := "map_camera_walker_zoom_full_transition_strip.png"
const ZOOM_STRIP_NAME := "map_camera_walker_zoom_intro_dense_strip.png"

var _failure := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("camera tracking visual QA requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("camera tracking visual QA requires Vulkan")
		return
	if int(Engine.physics_ticks_per_second) != PHYSICS_HZ:
		_fail("camera tracking visual QA requires the production 72 Hz physics clock")
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("camera tracking output directory could not be created")
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
	if not flow.open_map_overlay(canvas, registry, {
		"run_id": "map-camera-visual-evidence",
		"current_stage": 4,
		"map_seed": 83521,
	}):
		_fail("camera tracking visual fixture could not open the production map surface")
		return
	flow.set_map_overlay_fade_progress_for_qa(1.0)
	var original_node_id := flow.get_current_node_id()
	var middle_node_id := _node_id_for_floor(flow, 5)
	var upper_node_id := _node_id_for_floor(flow, 9)
	if middle_node_id.is_empty() or upper_node_id.is_empty():
		_fail("camera tracking fixture could not locate middle/top nodes")
		return
	flow.set("_current_node_id", original_node_id)
	var lower_image := await _capture(canvas, viewport)
	if not _save(lower_image, output_dir.path_join(LOWER_NAME)):
		_fail("lower-boundary capture failed")
		return
	flow.set("_current_node_id", middle_node_id)
	var middle_image := await _capture(canvas, viewport)
	if not _save(middle_image, output_dir.path_join(MIDDLE_NAME)):
		_fail("middle-floor capture failed")
		return
	var crossing_point := _find_curve_crossing(flow)
	if crossing_point.x < 0.0 or not _save_crossing_zoom(
		middle_image,
		crossing_point,
		output_dir.path_join(CROSSING_NAME)
	):
		_fail("visible curve crossing could not be captured")
		return
	flow.set("_current_node_id", upper_node_id)
	var upper_image := await _capture(canvas, viewport)
	if not _save(upper_image, output_dir.path_join(UPPER_NAME)):
		_fail("upper-boundary capture failed")
		return
	var transition_source_id := _node_id_for_floor(flow, 4)
	flow.set("_current_node_id", transition_source_id)
	flow.set("_route_source_node_id", transition_source_id)
	flow.set("_route_target_ids", flow.call("_outgoing_target_ids", transition_source_id))
	flow.call("_refresh_route_target_cache")
	flow.close_map_overlay()
	flow.call("_finish_map_overlay_close")
	var transition_target := _choose_noncombat_target(flow)
	if transition_target.is_empty():
		_fail("six-beat fixture has no route target")
		return
	flow.call("_resolve_route_target", transition_target)
	var strip_frames: Array[Image] = []
	for overall_progress in _full_transition_sample_progresses():
		flow.set_transition_progress_for_qa(overall_progress)
		strip_frames.append(await _capture(canvas, viewport))
	var zoom_frames: Array[Image] = []
	for zoom_tick in range(0, PHYSICS_HZ + 1, 6):
		flow.set_transition_progress_for_qa(
			(_zoom_start_elapsed_sec() + float(zoom_tick) * PHYSICS_DELTA_SEC)
				/ _transition_duration_sec()
		)
		zoom_frames.append(await _capture(canvas, viewport))
	flow.call("_complete_map_transition")
	strip_frames.append(await _capture(canvas, viewport))
	if not _save_grid_strip(
		strip_frames,
		4,
		Vector2i(505, 312),
		output_dir.path_join(STRIP_NAME)
	):
		_fail("full transition tracking strip could not be saved")
		return
	if not _save_grid_strip(
		zoom_frames,
		5,
		Vector2i(404, 249),
		output_dir.path_join(ZOOM_STRIP_NAME)
	):
		_fail("dense 72 Hz intro zoom strip could not be saved")
		return

	var live_result: Dictionary = await _run_live_traversal(registry, canvas)
	if not bool(live_result.get("accepted", false)):
		_fail("live traversal failed: %s" % str(live_result.get("reason", "unknown")))
		return
	print("[TowerMapCameraTrackingVisualQA] captures=6 overview_frames=%d zoom_frames=%d live_transitions=%d physics_ticks=%d zoom_ticks=%d max_boundary_scale_delta=%0.6f max_boundary_center_delta_px=%0.3f" % [
		strip_frames.size(),
		zoom_frames.size(),
		int(live_result.get("transitions", 0)),
		int(live_result.get("physics_ticks", 0)),
		int(live_result.get("zoom_ticks", 0)),
		float(live_result.get("max_boundary_scale_delta", INF)),
		float(live_result.get("max_boundary_center_delta_px", INF)),
	])
	print("[TowerMapCameraTrackingVisualQA] output=%s" % output_dir)
	print("tower_map_camera_tracking_visual_qa: ok")
	_cleanup_flow(flow)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	get_root().remove_child(viewport)
	viewport.free()
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


func _save(image: Image, path: String) -> bool:
	return (
		image != null
		and not image.is_empty()
		and image.get_size() == GAME_SIZE
		and image.save_png(path) == OK
	)


func _node_id_for_floor(flow: Object, floor_number: int) -> String:
	for node_variant in flow.get_graph_nodes():
		if node_variant is Dictionary and int((node_variant as Dictionary).get("floor", 0)) == floor_number:
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
			if str(node.get("id", "")) != target_id:
				continue
			if str(node.get("kind", "")) in TowerAscentMapGenerator.NONCOMBAT_NODE_KINDS:
				return target_id
	return fallback


func _find_curve_crossing(flow: Object) -> Vector2:
	var renderer := TowerAscentFlowRenderer.new()
	var model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
	var edges: Array = model.get("edges", [])
	var content: Rect2 = model.get("content_rect", Rect2()).grow(-40.0)
	var camera: Dictionary = model.get("camera", {})
	var camera_offset: Vector2 = camera.get(
		"offset",
		Vector2.ZERO
	)
	var camera_zoom_multiplier := maxf(1.0, float(camera.get("zoom_multiplier", 1.0)))
	var art_clearance := float(model.get("art_size", 0.0)) * 0.34
	var positions: Dictionary = model.get("position_by_id", {})
	for first_index in range(edges.size()):
		if not (edges[first_index] is Dictionary):
			continue
		var first := edges[first_index] as Dictionary
		for second_index in range(first_index + 1, edges.size()):
			if not (edges[second_index] is Dictionary):
				continue
			var second := edges[second_index] as Dictionary
			var first_points: PackedVector2Array = first.get("path_points", PackedVector2Array())
			var second_points: PackedVector2Array = second.get("path_points", PackedVector2Array())
			for first_point_index in range(1, first_points.size()):
				for second_point_index in range(1, second_points.size()):
					var crossing := _segment_intersection(
						first_points[first_point_index - 1],
						first_points[first_point_index],
						second_points[second_point_index - 1],
						second_points[second_point_index]
					)
					if crossing.x < 0.0:
						continue
					var screen_crossing := crossing * camera_zoom_multiplier + camera_offset
					if not content.has_point(screen_crossing):
						continue
					var clears_nodes := true
					for node_position in positions.values():
						if crossing.distance_to(node_position) < art_clearance:
							clears_nodes = false
							break
					if clears_nodes:
						return screen_crossing
	return Vector2(-1.0, -1.0)


func _segment_intersection(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Vector2:
	var first_delta := b - a
	var second_delta := d - c
	var denominator := first_delta.cross(second_delta)
	if absf(denominator) <= 0.001:
		return Vector2(-1.0, -1.0)
	var offset := c - a
	var first_ratio := offset.cross(second_delta) / denominator
	var second_ratio := offset.cross(first_delta) / denominator
	if first_ratio <= 0.01 or first_ratio >= 0.99 or second_ratio <= 0.01 or second_ratio >= 0.99:
		return Vector2(-1.0, -1.0)
	return a + first_delta * first_ratio


func _save_crossing_zoom(image: Image, point: Vector2, path: String) -> bool:
	var half_size := Vector2i(110, 110)
	var center := Vector2i(point.round())
	var bounds := Rect2i(center - half_size, half_size * 2).intersection(
		Rect2i(Vector2i.ZERO, GAME_SIZE)
	)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return false
	var zoom := image.get_region(bounds)
	zoom.resize(bounds.size.x * 4, bounds.size.y * 4, Image.INTERPOLATE_NEAREST)
	return zoom.save_png(path) == OK


func _full_transition_sample_progresses() -> PackedFloat32Array:
	var battle := TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
	var map_in := TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
	var zoom := TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
	var travel := TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
	var vanish := TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
	var map_out := TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	var total := battle + map_in + zoom + travel + vanish + map_out
	return PackedFloat32Array([
		battle * 0.5 / total,
		(battle + map_in * 0.5) / total,
		(battle + map_in + zoom * 0.5) / total,
		(battle + map_in + zoom + travel * 0.5) / total,
		(battle + map_in + zoom + travel + vanish * 0.5) / total,
		(battle + map_in + zoom + travel + vanish + map_out * 0.5) / total,
	])


func _save_grid_strip(
	frames: Array[Image],
	columns: int,
	cell_size: Vector2i,
	path: String
) -> bool:
	if frames.is_empty() or columns <= 0:
		return false
	var rows := ceili(float(frames.size()) / float(columns))
	var strip := Image.create(
		cell_size.x * columns,
		cell_size.y * rows,
		false,
		Image.FORMAT_RGBA8
	)
	strip.fill(Color("17110d"))
	for frame_index in range(frames.size()):
		var frame := frames[frame_index].duplicate()
		frame.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
		frame.convert(Image.FORMAT_RGBA8)
		var destination := Vector2i(
			(frame_index % columns) * cell_size.x,
			(frame_index / columns) * cell_size.y
		)
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, cell_size), destination)
	return strip.save_png(path) == OK


func _run_live_traversal(registry: Object, canvas: CanvasItem) -> Dictionary:
	var live_flow := TowerAscentFlowOwner.new()
	registry.set("flow_owner", live_flow)
	if not live_flow.begin_vertical_slice(null, Callable(), {
		"run_id": "map-camera-live-traversal",
		"current_stage": 4,
		"map_seed": 83521,
		"registry": registry,
	}):
		return {"accepted": false, "reason": "begin_failed"}
	var renderer := TowerAscentFlowRenderer.new()
	var transition_count := 0
	var physics_tick_count := 0
	var zoom_tick_count := 0
	var max_boundary_scale_delta := 0.0
	var max_boundary_center_delta_px := 0.0
	var expected_transition_ticks := ceili(_transition_duration_sec() * float(PHYSICS_HZ))
	while transition_count < 5:
		var target_id := _choose_noncombat_target(live_flow)
		if target_id.is_empty():
			break
		live_flow.call("_resolve_route_target", target_id)
		if live_flow.get_phase_name() != "MAP_TRANSITION":
			return {"accepted": false, "reason": "transition_not_started"}
		var transition_ticks := 0
		var transition_zoom_ticks := 0
		var previous_segment := ""
		var previous_camera: Dictionary = {}
		while live_flow.get_phase_name() == "MAP_TRANSITION" and transition_ticks < 420:
			await physics_frame
			live_flow.update_selective(PHYSICS_DELTA_SEC, canvas)
			canvas.queue_redraw()
			transition_ticks += 1
			physics_tick_count += 1
			if live_flow.get_phase_name() == "MAP_TRANSITION":
				var model: Dictionary = renderer.build_fullscreen_map_model(live_flow, VIEWPORT_RECT)
				var camera: Dictionary = model.get("camera", {})
				var visual_model: Dictionary = live_flow.get_map_transition_visual_model()
				var segment := str(visual_model.get("segment", ""))
				if segment == "camera_zoom_in":
					transition_zoom_ticks += 1
				if previous_segment == "camera_zoom_in" and segment == "travel":
					max_boundary_scale_delta = maxf(
						max_boundary_scale_delta,
						absf(
							float(camera.get("zoom_multiplier", 0.0))
								- float(previous_camera.get("zoom_multiplier", 0.0))
						)
					)
					max_boundary_center_delta_px = maxf(
						max_boundary_center_delta_px,
						(camera.get("focus_screen_position", Vector2.ZERO) as Vector2).distance_to(
							previous_camera.get("focus_screen_position", Vector2.ZERO)
						)
					)
				if not (model.get("content_rect", Rect2()) as Rect2).grow(-1.0).has_point(
					camera.get("focus_screen_position", Vector2(-1.0, -1.0))
				):
					return {"accepted": false, "reason": "walker_left_crop"}
				previous_segment = segment
				previous_camera = camera
		if transition_ticks >= 420:
			return {
				"accepted": false,
				"reason": "transition_timeout_progress_%0.3f" % live_flow.get_map_transition_progress(),
			}
		if transition_ticks != expected_transition_ticks:
			return {
				"accepted": false,
				"reason": "transition_tick_count_%d_expected_%d" % [
					transition_ticks,
					expected_transition_ticks,
				],
			}
		if transition_zoom_ticks != PHYSICS_HZ:
			return {
				"accepted": false,
				"reason": "zoom_tick_count_%d_expected_%d" % [
					transition_zoom_ticks,
					PHYSICS_HZ,
				],
			}
		zoom_tick_count += transition_zoom_ticks
		transition_count += 1
		if not live_flow.is_active():
			# Combat arrivals hand control back to the battle scene. The camera-only
			# live run treats that battle as immediately cleared, then resumes the
			# same generated graph so several floors can be watched in one window.
			live_flow.set("_active", true)
			if not bool(live_flow.call("_enter_route_aim")):
				break
		if live_flow.get_phase_name() == "NODE_MODAL":
			live_flow.debug_advance_to_route_aim()
		elif live_flow.get_phase_name() != "ROUTE_AIM":
			break
	var accepted := (
		transition_count >= 5
		and max_boundary_scale_delta <= ZOOM_BOUNDARY_SCALE_EPSILON
		and max_boundary_center_delta_px <= ZOOM_BOUNDARY_CENTER_EPSILON_PX
	)
	_cleanup_flow(live_flow)
	return {
		"accepted": accepted,
		"reason": "" if accepted else "live_gate_transitions_%d_scale_%0.6f_center_%0.3f_phase_%s_active_%s" % [
			transition_count,
			max_boundary_scale_delta,
			max_boundary_center_delta_px,
			live_flow.get_phase_name(),
			str(live_flow.is_active()),
		],
		"transitions": transition_count,
		"physics_ticks": physics_tick_count,
		"zoom_ticks": zoom_tick_count,
		"max_boundary_scale_delta": max_boundary_scale_delta,
		"max_boundary_center_delta_px": max_boundary_center_delta_px,
	}


func _zoom_start_elapsed_sec() -> float:
	return (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
	)


func _transition_duration_sec() -> float:
	return (
		_zoom_start_elapsed_sec()
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)


func _cleanup_flow(flow: Object) -> void:
	if flow != null and flow.has_method("is_active") and bool(flow.is_active()):
		flow.call("_finish_vertical_slice")


func _fail(message: String) -> void:
	_failure = message
	push_error(message)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	quit(1)
