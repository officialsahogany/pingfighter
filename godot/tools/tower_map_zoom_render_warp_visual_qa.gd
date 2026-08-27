extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentMapGenerator := preload(
	"res://scripts/tower_ascent/tower_ascent_map_generator.gd"
)
const TowerAscentMapCloudLayer := preload(
	"res://scripts/tower_ascent/tower_ascent_map_cloud_layer.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const GAME_SIZE := Vector2i(2020, 1246)
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(GAME_SIZE))
const PHYSICS_HZ := 72
const PHYSICS_DELTA_SEC := 1.0 / float(PHYSICS_HZ)
const FRAME_COUNT := 10
const FIRST_TRAVEL_TICK := 24
const OUTPUT_ROOT := "res://.godot/codex_captures/tower_map_zoom_render_warp"
const FRACTION_EPSILON := 0.0001

var _failures: Array[String] = []


class MapCanvas:
	extends Node2D

	var flow: Object

	func _init(flow_owner: Object) -> void:
		flow = flow_owner

	func _draw() -> void:
		flow.draw_fullscreen_map(
			self,
			Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0)),
			{}
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("zoom-render-warp visual QA requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("zoom-render-warp visual QA requires Vulkan")
		return
	if int(Engine.physics_ticks_per_second) != PHYSICS_HZ:
		_fail("zoom-render-warp visual QA requires the production 72 Hz clock")
		return
	var evidence_label := _argument_value("evidence-label", "after")
	var expect_snapped := _argument_value("expect-snapped", "true") == "true"
	var output_dir := ProjectSettings.globalize_path(
		OUTPUT_ROOT.path_join(evidence_label)
	)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create zoom-render-warp evidence directory")
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := MapCanvas.new(flow)
	viewport.add_child(canvas)
	if not flow.begin_vertical_slice(null, Callable(), {
		"run_id": "tower-map-zoom-render-warp-" + evidence_label,
		"map_seed": 83521,
	}):
		_fail("could not enter the production Tower flow")
		return
	var source_id := flow.get_current_node_id()
	if source_id.is_empty():
		_fail("production flow did not expose its current route source")
		return
	var target_id := _choose_noncombat_target(flow)
	if target_id.is_empty():
		_fail("transition fixture has no route target")
		return
	flow.call("_resolve_route_target", target_id)
	if flow.get_phase_name() != "MAP_TRANSITION":
		_fail("route selection did not enter MAP_TRANSITION")
		return
	var renderer: Object = flow.get("_renderer")
	var frames: Array[Image] = []
	var metrics: Array[Dictionary] = []
	var previous_zoom := -INF
	var previous_travel := -INF
	for frame_index in range(FRAME_COUNT):
		var travel_tick := FIRST_TRAVEL_TICK + frame_index
		var elapsed := _travel_start_elapsed_sec() + float(travel_tick) * PHYSICS_DELTA_SEC
		flow.set_transition_progress_for_qa(elapsed / _transition_duration_sec())
		var image := await _capture(canvas, viewport)
		if image == null or image.is_empty():
			_fail("frame %d capture failed" % frame_index)
			return
		var frame_path := output_dir.path_join("frame_%02d.png" % frame_index)
		if image.save_png(frame_path) != OK:
			_fail("frame %d save failed" % frame_index)
			return
		frames.append(image)
		var model: Dictionary = renderer.build_fullscreen_map_model(flow, VIEWPORT_RECT)
		var camera: Dictionary = model.get("camera", {})
		var transition: Dictionary = flow.get_map_transition_visual_model()
		var draw_rects := _first_visible_background_rects(renderer, model)
		var target_rect: Rect2 = draw_rects.get("target_rect", Rect2())
		var source_rect: Rect2 = draw_rects.get("source_rect", Rect2())
		var target_fraction := _rect_edge_fraction(target_rect)
		var source_fraction := _rect_edge_fraction(source_rect)
		var primitive_counts := (
			TowerAscentMapCloudLayer.get_last_vertical_alpha_primitive_debug_state()
		)
		var zoom := float(camera.get("render_zoom_multiplier", 0.0))
		var travel := float(transition.get("travel_progress", 0.0))
		_expect(zoom > previous_zoom, "frame %d zoom must advance" % frame_index)
		_expect(travel > previous_travel, "frame %d walker travel must advance" % frame_index)
		if expect_snapped:
			_expect(
				target_fraction <= FRACTION_EPSILON,
				"frame %d background target rect must be pixel-aligned" % frame_index
			)
			_expect(
				source_fraction <= FRACTION_EPSILON,
				"frame %d background source rect must be texel-aligned" % frame_index
			)
		var frame_metrics := {
			"frame": frame_index,
			"travel_tick": travel_tick,
			"segment": str(transition.get("segment", "")),
			"travel_progress": travel,
			"render_zoom_multiplier": zoom,
			"camera_offset": _vector_json(camera.get("offset", Vector2.ZERO)),
			"target_rect": _rect_json(target_rect),
			"source_rect": _rect_json(source_rect),
			"target_max_edge_fraction": target_fraction,
			"source_max_edge_fraction": source_fraction,
			"cloud_rect_path_a": int(primitive_counts.get("rect_path_a", 0)),
			"cloud_polygon_path_b": int(primitive_counts.get("polygon_path_b", 0)),
		}
		metrics.append(frame_metrics)
		print("[TowerMapZoomRenderWarpFrame] %s" % JSON.stringify(frame_metrics))
		previous_zoom = zoom
		previous_travel = travel
	if not _save_contact_sheet(frames, output_dir.path_join("sequence_10_frames.png")):
		_fail("10-frame contact sheet could not be saved")
		return
	var metrics_path := output_dir.path_join("metrics.json")
	var metrics_file := FileAccess.open(metrics_path, FileAccess.WRITE)
	if metrics_file == null:
		_fail("metrics file could not be opened")
		return
	metrics_file.store_string(JSON.stringify({
		"evidence_label": evidence_label,
		"expect_snapped": expect_snapped,
		"frame_count": metrics.size(),
		"frames": metrics,
	}, "  "))
	metrics_file.close()
	_expect(metrics.size() == FRAME_COUNT, "all ten consecutive frames must be measured")
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		_cleanup(flow, viewport)
		quit(1)
		return
	print(
		"[TowerMapZoomRenderWarpVisualQA] label=%s frames=%d output=%s"
		% [evidence_label, metrics.size(), output_dir]
	)
	print("tower_map_zoom_render_warp_visual_qa: ok")
	_cleanup(flow, viewport)
	canvas = null
	flow = null
	await process_frame
	await process_frame
	quit(0)


func _first_visible_background_rects(renderer: Object, model: Dictionary) -> Dictionary:
	var camera: Dictionary = model.get("camera", {})
	var zoom := float(camera.get("render_zoom_multiplier", 1.0))
	var offset: Vector2 = camera.get("offset", Vector2.ZERO)
	var clip_rect: Rect2 = model.get("camera_view_rect", VIEWPORT_RECT)
	var scroll: Dictionary = model.get("scroll_background", {})
	for chunk_variant in scroll.get("draw_chunks", scroll.get("tiles", [])):
		if not (chunk_variant is Dictionary):
			continue
		var chunk := chunk_variant as Dictionary
		var texture := chunk.get("paper_texture", null) as Texture2D
		var world_target: Rect2 = chunk.get("paper_rect", chunk.get("rect", Rect2()))
		if texture == null or not world_target.has_area():
			continue
		var projected := Rect2(world_target.position * zoom + offset, world_target.size * zoom)
		var visible := projected.intersection(clip_rect)
		if not visible.has_area():
			continue
		var normalized_source: Rect2 = chunk.get(
			"paper_source_rect",
			Rect2(0.0, 0.0, 1.0, 1.0)
		)
		var texture_size := texture.get_size()
		var relative_position := (visible.position - projected.position) / projected.size
		var relative_size := visible.size / projected.size
		var source_rect := Rect2(
			texture_size * (
				normalized_source.position
				+ normalized_source.size * relative_position
			),
			texture_size * normalized_source.size * relative_size
		)
		return {
			"target_rect": renderer.snap_scroll_background_rect(visible),
			"source_rect": renderer.snap_scroll_background_rect(source_rect),
		}
	return {}


func _capture(canvas: CanvasItem, viewport: SubViewport) -> Image:
	canvas.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	return viewport.get_texture().get_image()


func _save_contact_sheet(frames: Array[Image], path: String) -> bool:
	if frames.size() != FRAME_COUNT:
		return false
	var cell_size := Vector2i(404, 249)
	var sheet := Image.create(cell_size.x * 5, cell_size.y * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("17110d"))
	for index in range(frames.size()):
		var frame := frames[index].duplicate()
		frame.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
		frame.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(
			frame,
			Rect2i(Vector2i.ZERO, cell_size),
			Vector2i(index % 5, index / 5) * cell_size
		)
	return sheet.save_png(path) == OK


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


func _travel_start_elapsed_sec() -> float:
	return (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
	)


func _transition_duration_sec() -> float:
	return (
		_travel_start_elapsed_sec()
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)


func _rect_edge_fraction(rect: Rect2) -> float:
	return maxf(
		maxf(_scalar_fraction(rect.position.x), _scalar_fraction(rect.position.y)),
		maxf(_scalar_fraction(rect.end.x), _scalar_fraction(rect.end.y))
	)


func _scalar_fraction(value: float) -> float:
	return absf(value - roundf(value))


func _rect_json(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"w": rect.size.x,
		"h": rect.size.y,
	}


func _vector_json(value: Variant) -> Dictionary:
	var vector: Vector2 = value if value is Vector2 else Vector2.ZERO
	return {"x": vector.x, "y": vector.y}


func _argument_value(key: String, fallback: String) -> String:
	var prefix := "--%s=" % key
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.substr(prefix.length())
	return fallback


func _cleanup(flow: Object, viewport: SubViewport) -> void:
	if flow != null and flow.has_method("is_active") and bool(flow.is_active()):
		flow.call("_finish_vertical_slice")
	if viewport != null:
		get_root().remove_child(viewport)
		viewport.free()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _fail(message: String) -> void:
	push_error(message)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	quit(1)
