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
const WORLD_RECT := Rect2(0.0, 0.0, 692.0, 2400.0)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_map_cloud_wall"
const PAPER_COLOR := Color("f1dfb8")
const SENTINEL_COLOR := Color("d21f5b")
const PUBLIC_PIXEL_EPSILON := 0.012
const SENTINEL_PIXEL_EPSILON := 0.035
const MAXIMUM_INTERNAL_BOUNDARY_MEAN_DELTA := 0.065
const MAXIMUM_MOVED_JOIN_MEAN_DELTA := 0.060

var _failure := ""


class CloudWallProbeCanvas:
	extends Node2D

	var cloud_layer: Object
	var cloud_model: Dictionary = {}
	var camera_model: Dictionary = {}
	var reveal_visual: Dictionary = {}

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(GAME_SIZE)), PAPER_COLOR, true)
		var zoom := float(camera_model.get("render_zoom_multiplier", 1.0))
		var offset: Vector2 = camera_model.get("offset", Vector2.ZERO)
		draw_set_transform(offset, 0.0, Vector2.ONE * zoom)
		draw_line(Vector2(346.0, 2100.0), Vector2(346.0, 700.0), SENTINEL_COLOR, 18.0)
		for point in [Vector2(346.0, 2100.0), Vector2(346.0, 1400.0), Vector2(346.0, 700.0)]:
			draw_circle(point, 34.0, SENTINEL_COLOR)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		cloud_layer.draw(self, cloud_model, camera_model, reveal_visual)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("tower_map_cloud_wall_visual_qa requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("tower_map_cloud_wall_visual_qa requires Vulkan")
		return
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create cloud-wall visual QA output directory")
		return
	var catalog := TowerMapScrollAssetCatalog.new()
	var prewarm: Dictionary = catalog.prewarm_all()
	if not bool(prewarm.get("ready", false)):
		_fail("cloud-wall visual QA requires the production asset prewarm")
		return
	var resolutions: Dictionary = {}
	for asset_key in catalog.get_asset_keys():
		resolutions[asset_key] = catalog.get_cached_resolution(asset_key)
	var cloud_layer := TowerAscentMapCloudLayer.new()
	var cloud_model := cloud_layer.build(
		[
			{"floor": 1, "segment_floor": 1, "world_position": Vector2(346.0, 2100.0)},
			{"floor": 2, "segment_floor": 2, "world_position": Vector2(346.0, 1400.0)},
			{"floor": 3, "segment_floor": 3, "world_position": Vector2(346.0, 700.0)},
		],
		WORLD_RECT,
		83521,
		80.0,
		resolutions,
		1.0
	)
	if not TowerAscentMapCloudLayer.merged_region_contract_holds(cloud_model):
		_fail("production builder did not expose the approved merged wall")
		return
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := CloudWallProbeCanvas.new()
	canvas.cloud_layer = cloud_layer
	canvas.cloud_model = cloud_model
	viewport.add_child(canvas)
	var zooms := {
		"minimum": TowerAscentMapCameraModel.minimum_fit_all_zoom(VIEWPORT_RECT, WORLD_RECT),
		"default_1x": 1.0,
		"maximum": TowerAscentTuning.TEMP_MAP_WHEEL_ZOOM_MAX,
	}
	var default_locked: Image
	var default_revealed: Image
	for label in ["minimum", "default_1x", "maximum"]:
		canvas.camera_model = _camera_model(float(zooms[label]), 1600.0)
		canvas.reveal_visual = _steady_visual(1)
		var locked_image := await _capture(canvas, viewport)
		if not _save(locked_image, output_dir.path_join("cloud_wall_%s.png" % label)):
			_fail("%s merged-wall capture failed" % label)
			return
		canvas.reveal_visual = _steady_visual(999)
		var revealed_image := await _capture(canvas, viewport)
		if label == "default_1x":
			default_locked = locked_image
			default_revealed = revealed_image
			if not _save(revealed_image, output_dir.path_join("cloud_wall_revealed_1x.png")):
				_fail("revealed reverse-leg capture failed")
				return
		if not _assert_sentinel_and_public_pixels(
			locked_image,
			revealed_image,
			canvas.camera_model,
			label
		):
			return
	if default_locked == null or default_revealed == null:
		_fail("default wall/control pair was not captured")
		return
	var initial_state := TowerAscentMapCloudLayer.wall_visual_state(
		cloud_model,
		_steady_visual(1)
	)
	var internal_boundary_delta := _row_mean_delta(
		default_locked,
		_world_y_to_framebuffer(1050.0, _camera_model(1.0, 1600.0))
	)
	if internal_boundary_delta > MAXIMUM_INTERNAL_BOUNDARY_MEAN_DELTA:
		_fail("retired per-floor band edge reappeared at an internal boundary: %.5f" % internal_boundary_delta)
		return
	canvas.camera_model = _camera_model(1.0, 1200.0)
	canvas.reveal_visual = {
		"revealed_floor": 1,
		"target_floor": 2,
		"pending": true,
		"progress": 0.5,
		"drift_time_sec": 1.0,
	}
	var midpoint_image := await _capture(canvas, viewport)
	if not _save(midpoint_image, output_dir.path_join("cloud_wall_reveal_mid.png")):
		_fail("mid-reveal merged-wall capture failed")
		return
	canvas.reveal_visual = _steady_visual(2)
	var moved_image := await _capture(canvas, viewport)
	if not _save(moved_image, output_dir.path_join("cloud_wall_revealed_floor_2.png")):
		_fail("moved-boundary capture failed")
		return
	var moved_state := TowerAscentMapCloudLayer.wall_visual_state(
		cloud_model,
		_steady_visual(2)
	)
	var boundary_delta := (
		float(initial_state.get("boundary_y", 0.0))
		- float(moved_state.get("boundary_y", 0.0))
	)
	if boundary_delta <= 0.001:
		_fail("revealing floor two did not move the wall boundary upward")
		return
	var moved_join_y := _world_y_to_framebuffer(
		(moved_state.get("dissolve_rect", Rect2()) as Rect2).position.y,
		canvas.camera_model
	)
	var moved_join_delta := _row_mean_delta(moved_image, moved_join_y)
	if moved_join_delta > MAXIMUM_MOVED_JOIN_MEAN_DELTA:
		_fail("moved dissolve/interior join has a visible seam: %.5f" % moved_join_delta)
		return
	print(
		"[TowerMapCloudWallVisualQA] internal_boundary_delta=%.5f moved_boundary_world=%.3f moved_join_delta=%.5f"
		% [internal_boundary_delta, boundary_delta, moved_join_delta]
	)
	print("[TowerMapCloudWallVisualQA] output=%s zooms=%s" % [output_dir, zooms])
	print("tower_map_cloud_wall_visual_qa: ok")
	get_root().remove_child(viewport)
	viewport.free()
	canvas = null
	cloud_layer = null
	await process_frame
	await process_frame
	quit(0)


func _assert_sentinel_and_public_pixels(
	locked_image: Image,
	revealed_image: Image,
	camera_model: Dictionary,
	label: String
) -> bool:
	var locked_point := _world_to_framebuffer(Vector2(346.0, 1400.0), camera_model)
	var locked_pixel := locked_image.get_pixelv(_clamped_pixel(locked_point))
	var revealed_locked_pixel := revealed_image.get_pixelv(_clamped_pixel(locked_point))
	if _rgb_delta(revealed_locked_pixel, SENTINEL_COLOR) > SENTINEL_PIXEL_EPSILON:
		_fail("%s reverse leg did not expose the locked sentinel" % label)
		return false
	if _rgb_delta(locked_pixel, SENTINEL_COLOR) <= 0.12:
		_fail("%s wall no longer conceals the locked sentinel" % label)
		return false
	var public_point := _world_to_framebuffer(Vector2(346.0, 1800.0), camera_model)
	var public_pixel := locked_image.get_pixelv(_clamped_pixel(public_point))
	var public_control := revealed_image.get_pixelv(_clamped_pixel(public_point))
	var public_delta := _rgb_delta(public_pixel, public_control)
	if public_delta > PUBLIC_PIXEL_EPSILON:
		_fail("%s wall leaked pixels onto the completed public floor: %.5f" % [label, public_delta])
		return false
	print(
		"[TowerMapCloudWallVisualQA] zoom=%s value=%.6f locked_sentinel_delta=%.5f public_delta=%.5f"
		% [
			label,
			float(camera_model.get("render_zoom_multiplier", 0.0)),
			_rgb_delta(locked_pixel, SENTINEL_COLOR),
			public_delta,
		]
	)
	return true


func _row_mean_delta(image: Image, framebuffer_y: int) -> float:
	var y := clampi(framebuffer_y, 1, GAME_SIZE.y - 1)
	var total := 0.0
	var samples := 0
	for x in range(670, 1350, 2):
		total += _rgb_delta(image.get_pixel(x, y - 1), image.get_pixel(x, y))
		samples += 1
	return total / float(maxi(1, samples))


func _camera_model(zoom: float, center_y: float = 1200.0) -> Dictionary:
	return {
		"render_zoom_multiplier": zoom,
		"zoom_multiplier": zoom,
		"offset": Vector2(GAME_SIZE) * 0.5 - Vector2(346.0, center_y) * zoom,
	}


func _steady_visual(revealed_floor: int) -> Dictionary:
	return {
		"revealed_floor": revealed_floor,
		"target_floor": 0,
		"pending": false,
		"progress": 0.0,
		"drift_time_sec": 0.0,
	}


func _world_y_to_framebuffer(world_y: float, camera_model: Dictionary) -> int:
	return int(round(
		world_y * float(camera_model.get("render_zoom_multiplier", 1.0))
		+ float((camera_model.get("offset", Vector2.ZERO) as Vector2).y)
	))


func _world_to_framebuffer(point: Vector2, camera_model: Dictionary) -> Vector2:
	return (
		point * float(camera_model.get("render_zoom_multiplier", 1.0))
		+ (camera_model.get("offset", Vector2.ZERO) as Vector2)
	)


func _clamped_pixel(point: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(round(point.x)), 0, GAME_SIZE.x - 1),
		clampi(int(round(point.y)), 0, GAME_SIZE.y - 1)
	)


func _capture(canvas: CanvasItem, viewport: SubViewport) -> Image:
	canvas.queue_redraw()
	for _frame_index in range(3):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != GAME_SIZE:
		return null
	return image


func _save(image: Image, path: String) -> bool:
	return (
		image != null
		and not image.is_empty()
		and image.get_size() == GAME_SIZE
		and image.save_png(path) == OK
	)


func _rgb_delta(left: Color, right: Color) -> float:
	return (
		absf(left.r - right.r)
		+ absf(left.g - right.g)
		+ absf(left.b - right.b)
	) / 3.0


func _fail(message: String) -> void:
	if _failure.is_empty():
		_failure = message
	push_error(message)
	quit(1)
