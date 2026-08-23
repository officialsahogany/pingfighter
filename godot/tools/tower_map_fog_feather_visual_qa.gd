extends SceneTree

const TowerAscentMapCameraModel := preload(
	"res://scripts/tower_ascent/tower_ascent_map_camera_model.gd"
)
const TowerAscentMapCloudLayer := preload(
	"res://scripts/tower_ascent/tower_ascent_map_cloud_layer.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerMapScrollAssetCatalog := preload(
	"res://scripts/tower_ascent/tower_map_scroll_asset_catalog.gd"
)

const GAME_SIZE := Vector2i(2020, 1246)
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(GAME_SIZE))
const WORLD_RECT := Rect2(0.0, 0.0, 2020.0, 2000.0)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_map_fog_feather"
const PAPER_COLOR := Color("f1dfb8")
const SENTINEL_COLOR := Color("30271f")
const OUTSIDE_CONTROL_EPSILON := 0.012
const MAX_ADJACENT_EDGE_DELTA := 0.067
const MINIMUM_FULL_EDGE_DELTA := 0.050
const MINIMUM_WAVE_SPREAD_PX := 2.0

var _failure := ""


class FogProbeCanvas:
	extends Node2D

	var cloud_layer: Object
	var cloud_model: Dictionary = {}
	var camera_model: Dictionary = {}
	var reveal_visual: Dictionary = {}
	var view_size := Vector2.ZERO
	var sentinel_rect := Rect2()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, view_size), PAPER_COLOR, true)
		var zoom := float(camera_model.get("render_zoom_multiplier", 1.0))
		var offset: Vector2 = camera_model.get("offset", Vector2.ZERO)
		draw_set_transform(offset, 0.0, Vector2.ONE * zoom)
		draw_line(
			Vector2(sentinel_rect.position.x - 120.0, sentinel_rect.get_center().y),
			Vector2(sentinel_rect.end.x + 120.0, sentinel_rect.get_center().y),
			SENTINEL_COLOR,
			8.0
		)
		draw_rect(sentinel_rect, SENTINEL_COLOR, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		cloud_layer.draw(self, cloud_model, camera_model, reveal_visual)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("tower_map_fog_feather_visual_qa requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("tower_map_fog_feather_visual_qa requires Vulkan")
		return
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create fog feather visual QA output directory")
		return
	var cloud_layer := TowerAscentMapCloudLayer.new()
	var model := cloud_layer.build(
		[
			{"floor": 2, "segment_floor": 2, "world_position": Vector2(640.0, 900.0)},
			{"floor": 2, "segment_floor": 2, "world_position": Vector2(1380.0, 1100.0)},
		],
		WORLD_RECT,
		83521,
		80.0,
		_dummy_bitmap_resolutions(),
		1.0
	)
	var fog_model := _fog_only_model(model)
	var fog_spec := _first_fog_spec(fog_model)
	var floor_rect: Rect2 = _first_floor_rect(fog_model)
	if fog_spec.is_empty() or floor_rect.size.x <= 0.0:
		_fail("production fog builder did not expose an inspectable floor")
		return
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := FogProbeCanvas.new()
	canvas.cloud_layer = cloud_layer
	canvas.cloud_model = fog_model
	canvas.view_size = Vector2(GAME_SIZE)
	canvas.sentinel_rect = Rect2(
		floor_rect.get_center() - Vector2(30.0, 24.0),
		Vector2(60.0, 48.0)
	)
	viewport.add_child(canvas)
	var zooms := {
		"minimum": TowerAscentMapCameraModel.minimum_fit_all_zoom(
			VIEWPORT_RECT,
			WORLD_RECT
		),
		"default_1x": 1.0,
		"maximum": TowerAscentTuning.TEMP_MAP_WHEEL_ZOOM_MAX,
	}
	for label in ["minimum", "default_1x", "maximum"]:
		var zoom := float(zooms[label])
		var camera_model := _camera_model(zoom)
		canvas.camera_model = camera_model
		canvas.reveal_visual = _locked_visual()
		var locked_image := await _capture(canvas, viewport)
		if not _save(
			locked_image,
			output_dir.path_join("fog_feather_%s.png" % label)
		):
			_fail("%s locked fog capture failed" % label)
			return
		canvas.reveal_visual = _revealed_visual()
		var revealed_image := await _capture(canvas, viewport)
		if label == "default_1x" and not _save(
			revealed_image,
			output_dir.path_join("fog_revealed_1x.png")
		):
			_fail("revealed fog reverse-leg capture failed")
			return
		if not _assert_pixels(
			locked_image,
			revealed_image,
			canvas,
			camera_model,
			fog_spec,
			floor_rect,
			label
		):
			return
	print("[TowerMapFogFeatherVisualQA] output=%s resolution=%s" % [
		output_dir,
		GAME_SIZE,
	])
	print("tower_map_fog_feather_visual_qa: ok")
	get_root().remove_child(viewport)
	viewport.free()
	canvas = null
	cloud_layer = null
	await process_frame
	await process_frame
	quit(0)


func _assert_pixels(
	locked_image: Image,
	revealed_image: Image,
	canvas: CanvasItem,
	camera_model: Dictionary,
	fog_spec: Dictionary,
	floor_rect: Rect2,
	label: String
) -> bool:
	var core_points: PackedVector2Array = fog_spec.get(
		"core_points",
		PackedVector2Array()
	)
	var top_points: PackedVector2Array = fog_spec.get(
		"top_feather_points",
		PackedVector2Array()
	)
	var edge_count := int(core_points.size() * 0.5)
	if edge_count < 3 or top_points.size() != edge_count * 2:
		_fail("%s fog geometry does not expose paired cached edges" % label)
		return false
	var center_index := int(edge_count * 0.5)
	var outer_frame := _world_to_framebuffer(
		top_points[center_index],
		canvas,
		camera_model
	)
	var core_frame := _world_to_framebuffer(
		core_points[center_index],
		canvas,
		camera_model
	)
	var scan_x := clampi(int(round(outer_frame.x)), 0, GAME_SIZE.x - 1)
	var scan_start := clampi(
		int(floor(minf(outer_frame.y, core_frame.y))) - 3,
		0,
		GAME_SIZE.y - 1
	)
	var scan_end := clampi(
		int(ceil(maxf(outer_frame.y, core_frame.y))) + 3,
		0,
		GAME_SIZE.y - 1
	)
	var maximum_adjacent_delta := 0.0
	for y in range(scan_start + 1, scan_end + 1):
		maximum_adjacent_delta = maxf(
			maximum_adjacent_delta,
			_rgb_delta(
				locked_image.get_pixel(scan_x, y - 1),
				locked_image.get_pixel(scan_x, y)
			)
		)
	if maximum_adjacent_delta > MAX_ADJACENT_EDGE_DELTA:
		_fail("%s fog edge retains a hard adjacent-row step: %.5f" % [
			label,
			maximum_adjacent_delta,
		])
		return false
	var outside_y := clampi(scan_start, 0, GAME_SIZE.y - 1)
	var outside_locked := locked_image.get_pixel(scan_x, outside_y)
	var outside_revealed := revealed_image.get_pixel(scan_x, outside_y)
	var outside_delta := _rgb_delta(outside_locked, outside_revealed)
	if outside_delta > OUTSIDE_CONTROL_EPSILON:
		_fail("%s fog changed parchment outside the organic band: %.5f" % [
			label,
			outside_delta,
		])
		return false
	var core_probe_y := clampi(scan_end, 0, GAME_SIZE.y - 1)
	var full_edge_delta := _rgb_delta(
		locked_image.get_pixel(scan_x, core_probe_y),
		outside_locked
	)
	if full_edge_delta < MINIMUM_FULL_EDGE_DELTA:
		_fail("%s fog edge probe did not reach the near-opaque core: %.5f" % [
			label,
			full_edge_delta,
		])
		return false
	var sentinel_frame := _world_to_framebuffer(
		floor_rect.get_center(),
		canvas,
		camera_model
	)
	var sentinel_x := clampi(int(round(sentinel_frame.x)), 0, GAME_SIZE.x - 1)
	var sentinel_y := clampi(int(round(sentinel_frame.y)), 0, GAME_SIZE.y - 1)
	var locked_sentinel := locked_image.get_pixel(sentinel_x, sentinel_y)
	var revealed_sentinel := revealed_image.get_pixel(sentinel_x, sentinel_y)
	var fog_color: Color = fog_spec.get(
		"color",
		TowerAscentMapCloudLayer.FOG_COVER_COLOR
	)
	if _rgb_delta(locked_sentinel, fog_color) > 0.060:
		_fail("%s locked core no longer conceals the node sentinel: %s" % [
			label,
			locked_sentinel,
		])
		return false
	if _rgb_delta(revealed_sentinel, SENTINEL_COLOR) > 0.025:
		_fail("%s revealed-floor reverse leg did not expose the sentinel: %s" % [
			label,
			revealed_sentinel,
		])
		return false
	var wave_min_y := INF
	var wave_max_y := -INF
	for ratio in [0.25, 0.5, 0.75]:
		var sample_index := clampi(int(round(float(edge_count - 1) * ratio)), 0, edge_count - 1)
		var boundary_frame := _world_to_framebuffer(
			top_points[sample_index],
			canvas,
			camera_model
		)
		wave_min_y = minf(wave_min_y, boundary_frame.y)
		wave_max_y = maxf(wave_max_y, boundary_frame.y)
	var wave_spread := wave_max_y - wave_min_y
	if wave_spread < MINIMUM_WAVE_SPREAD_PX:
		_fail("%s fog top boundary collapsed back to a straight box: %.3fpx" % [
			label,
			wave_spread,
		])
		return false
	print(
		"[TowerMapFogFeatherVisualQA] zoom=%s value=%.6f adjacent_delta=%.5f full_delta=%.5f outside_delta=%.5f wave_spread=%.3f"
		% [
			label,
			float(camera_model.get("render_zoom_multiplier", 0.0)),
			maximum_adjacent_delta,
			full_edge_delta,
			outside_delta,
			wave_spread,
		]
	)
	return true


func _dummy_bitmap_resolutions() -> Dictionary:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var result: Dictionary = {}
	for asset_key in TowerMapScrollAssetCatalog.CLOUD_ASSET_KEYS:
		result[asset_key] = {
			"ready": true,
			"texture": texture,
			"world_size": Vector2i(256, 128),
			"expected_texture_size": Vector2i(4, 4),
		}
	return result


func _fog_only_model(model: Dictionary) -> Dictionary:
	var floors: Array[Dictionary] = []
	for floor_variant in model.get("floors", []):
		if not (floor_variant is Dictionary):
			continue
		var floor_spec := (floor_variant as Dictionary).duplicate(true)
		var fog_specs: Array[Dictionary] = []
		for spec_variant in floor_spec.get("bitmap_specs", []):
			if spec_variant is Dictionary and str(
				(spec_variant as Dictionary).get("kind", "")
			) == "fog":
				fog_specs.append((spec_variant as Dictionary).duplicate(true))
		floor_spec["bitmap_specs"] = fog_specs
		floors.append(floor_spec)
	return {
		"floors": floors,
		"render_mode": "bitmap",
		"bitmap_assets": {},
	}


func _first_fog_spec(model: Dictionary) -> Dictionary:
	for floor_variant in model.get("floors", []):
		if not (floor_variant is Dictionary):
			continue
		for spec_variant in (floor_variant as Dictionary).get("bitmap_specs", []):
			if spec_variant is Dictionary and str(
				(spec_variant as Dictionary).get("kind", "")
			) == "fog":
				return spec_variant as Dictionary
	return {}


func _first_floor_rect(model: Dictionary) -> Rect2:
	for floor_variant in model.get("floors", []):
		if floor_variant is Dictionary:
			return (floor_variant as Dictionary).get("floor_rect", Rect2())
	return Rect2()


func _camera_model(zoom: float) -> Dictionary:
	return {
		"render_zoom_multiplier": zoom,
		"zoom_multiplier": zoom,
		"offset": Vector2(GAME_SIZE) * 0.5 - WORLD_RECT.get_center() * zoom,
	}


func _locked_visual() -> Dictionary:
	return {
		"revealed_floor": 1,
		"target_floor": 0,
		"pending": false,
		"progress": 0.0,
		"drift_time_sec": 0.0,
	}


func _revealed_visual() -> Dictionary:
	return {
		"revealed_floor": 999,
		"target_floor": 0,
		"pending": false,
		"progress": 0.0,
		"drift_time_sec": 0.0,
	}


func _world_to_framebuffer(
	world_point: Vector2,
	canvas: CanvasItem,
	camera_model: Dictionary
) -> Vector2:
	var zoom := float(camera_model.get("render_zoom_multiplier", 1.0))
	var offset: Vector2 = camera_model.get("offset", Vector2.ZERO)
	var canvas_point := world_point * zoom + offset
	return canvas.get_global_transform_with_canvas() * canvas_point


func _capture(canvas: CanvasItem, viewport: SubViewport) -> Image:
	canvas.queue_redraw()
	for _frame_index in range(3):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != GAME_SIZE:
		return null
	return image


func _rgb_delta(left: Color, right: Color) -> float:
	return maxf(
		absf(left.r - right.r),
		maxf(absf(left.g - right.g), absf(left.b - right.b))
	)


func _save(image: Image, path: String) -> bool:
	return (
		image != null
		and not image.is_empty()
		and image.get_size() == GAME_SIZE
		and image.save_png(path) == OK
	)


func _fail(message: String) -> void:
	if _failure.is_empty():
		_failure = message
	push_error(message)
	quit(1)
