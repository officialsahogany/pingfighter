extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerMapScrollAssetCatalog := preload(
	"res://scripts/tower_ascent/tower_map_scroll_asset_catalog.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const GAME_SIZE := Vector2i(2020, 1246)
const VIEW_RECT := Rect2(Vector2.ZERO, Vector2(GAME_SIZE))
const OUTPUT_DIR := "res://.godot/codex_captures/tower_map_scroll_x4"
const DETAIL_CROP := Rect2i(520, 170, 720, 420)
const SEAM_CROP_WIDTH := 1200
const SEAM_CROP_HEIGHT := 40

var _failure := ""


class SourceBitmapCatalog:
	extends RefCounted

	var use_x4 := false
	var resolution_by_key: Dictionary = {}

	func _init(use_x4_value: bool) -> void:
		use_x4 = use_x4_value

	func prewarm_all() -> Dictionary:
		var ready_count := 0
		for asset_key in TowerMapScrollAssetCatalog.ASSET_SPECS.keys():
			var path := str(
				(TowerMapScrollAssetCatalog.ASSET_SPECS[asset_key] as Dictionary).get(
					"path",
					""
				)
			)
			if not use_x4:
				path = path.replace("_x4.png", ".png")
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			var texture := ImageTexture.create_from_image(image) if image != null else null
			resolution_by_key[asset_key] = {
				"asset_key": asset_key,
				"source": "source_bitmap_qa",
				"path": path,
				"texture": texture,
				"ready": texture != null,
				"cached": true,
			}
			if texture != null:
				ready_count += 1
		return {
			"ready": ready_count == TowerMapScrollAssetCatalog.ASSET_SPECS.size(),
			"entry_count": resolution_by_key.size(),
			"expected_count": TowerMapScrollAssetCatalog.ASSET_SPECS.size(),
		}

	func get_cached_resolution(asset_key: String) -> Dictionary:
		return (resolution_by_key.get(asset_key, {}) as Dictionary).duplicate(false)

	func get_debug_state() -> Dictionary:
		return {
			"entry_count": resolution_by_key.size(),
			"expected_count": TowerMapScrollAssetCatalog.ASSET_SPECS.size(),
			"ready_count": resolution_by_key.size(),
		}

	func clear_cache() -> void:
		resolution_by_key.clear()


class MapCanvas:
	extends Node2D

	var flow: Object

	func _draw() -> void:
		if flow != null:
			flow.draw_fullscreen_map(self, VIEW_RECT, {})


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("tower_map_scroll_x4_visual_qa requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("tower_map_scroll_x4_visual_qa requires Vulkan")
		return
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create x4 visual QA output directory")
		return
	var viewport := SubViewport.new()
	viewport.size = GAME_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := MapCanvas.new()
	viewport.add_child(canvas)

	# Production x4 is deliberately first in this fresh process so the timing
	# includes catalog disk load and first GPU upload rather than a warmed cache.
	var cold_start_usec := Time.get_ticks_usec()
	var production_walking := _new_walking_flow(null)
	if production_walking == null:
		_fail("production walking flow did not begin")
		return
	canvas.flow = production_walking
	var after_walking := await _capture(canvas, viewport)
	var cold_first_frame_ms := float(Time.get_ticks_usec() - cold_start_usec) / 1000.0
	var warm_start_usec := Time.get_ticks_usec()
	var _warm_walking := await _capture(canvas, viewport)
	var warm_frame_ms := float(Time.get_ticks_usec() - warm_start_usec) / 1000.0
	if not _save(after_walking, output_dir.path_join("walking_zoom_x4_vram.png")):
		_fail("could not save x4 walking capture")
		return

	var raw_x4_walking_flow := _new_walking_flow(SourceBitmapCatalog.new(true))
	canvas.flow = raw_x4_walking_flow
	var raw_x4_walking := await _capture(canvas, viewport)
	var original_walking_flow := _new_walking_flow(SourceBitmapCatalog.new(false))
	canvas.flow = original_walking_flow
	var before_walking := await _capture(canvas, viewport)
	if not _assert_geometry_identity(production_walking, original_walking_flow):
		return
	if not _save(before_walking, output_dir.path_join("walking_zoom_original.png")):
		_fail("could not save original walking capture")
		return
	if not _save_pair_crop(
		before_walking,
		after_walking,
		DETAIL_CROP,
		output_dir.path_join("walking_zoom_before_after_crop.png")
	):
		return
	if not _save_pair_crop(
		raw_x4_walking,
		after_walking,
		DETAIL_CROP,
		output_dir.path_join("walking_zoom_x4_raw_vs_vram_crop.png")
	):
		return
	var walking_compression_diff := _mean_abs_rgb_diff(
		raw_x4_walking,
		after_walking,
		DETAIL_CROP
	)

	var production_overview := _new_overlay_flow(null, canvas)
	if production_overview == null:
		_fail("production overview flow did not open")
		return
	canvas.flow = production_overview
	var overview_x4 := await _capture(canvas, viewport)
	if not _save(overview_x4, output_dir.path_join("overview_x4_mipmapped.png")):
		_fail("could not save x4 overview")
		return
	if not await _capture_seam_triplet(
		production_overview,
		canvas,
		viewport,
		output_dir.path_join("seam_triplet_overview.png")
	):
		return
	var original_overview_flow := _new_overlay_flow(SourceBitmapCatalog.new(false), canvas)
	canvas.flow = original_overview_flow
	var overview_original := await _capture(canvas, viewport)
	if not _save_pair_crop(
		overview_original,
		overview_x4,
		DETAIL_CROP,
		output_dir.path_join("overview_before_after_crop.png")
	):
		return
	if not await _capture_seam_triplet(
		original_overview_flow,
		canvas,
		viewport,
		output_dir.path_join("seam_triplet_overview_original.png")
	):
		return
	var raw_x4_overview_flow := _new_overlay_flow(SourceBitmapCatalog.new(true), canvas)
	canvas.flow = raw_x4_overview_flow
	var overview_x4_raw := await _capture(canvas, viewport)
	if not _save_pair_crop(
		overview_x4_raw,
		overview_x4,
		DETAIL_CROP,
		output_dir.path_join("overview_x4_raw_no_mips_vs_vram_mips_crop.png")
	):
		return

	canvas.flow = production_overview
	for _index in range(2):
		production_overview.handle_input(_wheel(VIEW_RECT.get_center(), true))
		await _redraw(canvas)
	var middle_image := await _capture(canvas, viewport)
	if not _save(middle_image, output_dir.path_join("middle_zoom_x4.png")):
		_fail("could not save middle zoom")
		return
	if not await _capture_seam_triplet(
		production_overview,
		canvas,
		viewport,
		output_dir.path_join("seam_triplet_middle.png")
	):
		return
	canvas.flow = original_overview_flow
	for _index in range(2):
		original_overview_flow.handle_input(_wheel(VIEW_RECT.get_center(), true))
		await _redraw(canvas)
	if not await _capture_seam_triplet(
		original_overview_flow,
		canvas,
		viewport,
		output_dir.path_join("seam_triplet_middle_original.png")
	):
		return
	canvas.flow = production_overview
	for _index in range(32):
		production_overview.handle_input(_wheel(VIEW_RECT.get_center(), true))
		await _redraw(canvas)
	var maximum_vram := await _capture(canvas, viewport)
	if not _save(maximum_vram, output_dir.path_join("maximum_wheel_x4_vram.png")):
		_fail("could not save maximum wheel capture")
		return
	if not _save_crop(
		maximum_vram,
		DETAIL_CROP,
		output_dir.path_join("maximum_wheel_x4_crop.png")
	):
		return

	var raw_x4_maximum_flow := _new_overlay_flow(SourceBitmapCatalog.new(true), canvas)
	canvas.flow = raw_x4_maximum_flow
	for _index in range(34):
		raw_x4_maximum_flow.handle_input(_wheel(VIEW_RECT.get_center(), true))
		await _redraw(canvas)
	var maximum_raw := await _capture(canvas, viewport)
	if not _save_pair_crop(
		maximum_raw,
		maximum_vram,
		DETAIL_CROP,
		output_dir.path_join("maximum_wheel_x4_raw_vs_vram_crop.png")
	):
		return
	var maximum_compression_diff := _mean_abs_rgb_diff(
		maximum_raw,
		maximum_vram,
		DETAIL_CROP
	)

	print(
		"[TowerMapScrollX4VisualQA] cold_first_frame_ms=%.3f warm_frame_ms=%.3f"
		% [cold_first_frame_ms, warm_frame_ms]
	)
	print(
		"[TowerMapScrollX4VisualQA] compression_mean_abs walking=%.6f maximum=%.6f"
		% [walking_compression_diff, maximum_compression_diff]
	)
	print("[TowerMapScrollX4VisualQA] output=%s" % output_dir)
	print("tower_map_scroll_x4_visual_qa: ok")
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	get_root().remove_child(viewport)
	viewport.free()
	canvas = null
	await process_frame
	await process_frame
	quit(0)


func _new_walking_flow(catalog_override: Object) -> Object:
	var flow := TowerAscentFlowOwner.new()
	if catalog_override != null:
		flow.set("_map_scroll_asset_catalog", catalog_override)
	if not flow.begin_vertical_slice(null, Callable(), {
		"run_id": "tower-map-scroll-x4-walking",
		"map_seed": 83521,
	}):
		return null
	var targets: Array[String] = flow.get_route_target_ids()
	if targets.is_empty():
		return null
	flow.call("_resolve_route_target", targets[0])
	var elapsed := (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
	)
	flow.set_transition_progress_for_qa(elapsed / _transition_duration_sec())
	return flow


func _new_overlay_flow(catalog_override: Object, owner: Object) -> Object:
	var flow := TowerAscentFlowOwner.new()
	if catalog_override != null:
		flow.set("_map_scroll_asset_catalog", catalog_override)
	if not flow.open_map_overlay(owner, null, {
		"run_id": "tower-map-scroll-x4-overview",
		"map_seed": 83521,
	}):
		return null
	flow.set_map_overlay_fade_progress_for_qa(1.0)
	return flow


func _transition_duration_sec() -> float:
	return (
		TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
		+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
	)


func _capture(canvas: CanvasItem, viewport: SubViewport) -> Image:
	await _redraw(canvas)
	await _redraw(canvas)
	var texture := viewport.get_texture()
	if texture == null:
		return null
	var image := texture.get_image()
	if image != null and image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _redraw(canvas: CanvasItem) -> void:
	canvas.queue_redraw()
	await process_frame


func _last_model(flow: Object) -> Dictionary:
	var renderer: Object = flow.get("_renderer")
	return renderer.get("_last_fullscreen_model") as Dictionary


func _assert_geometry_identity(after_flow: Object, before_flow: Object) -> bool:
	var after_model := _last_model(after_flow)
	var before_model := _last_model(before_flow)
	var after_nodes: Array = after_model.get("nodes", [])
	var before_nodes: Array = before_model.get("nodes", [])
	if after_nodes.size() != before_nodes.size():
		_fail("x4 candidate changed node count")
		return false
	for index in range(after_nodes.size()):
		var after_node := after_nodes[index] as Dictionary
		var before_node := before_nodes[index] as Dictionary
		if (
			str(after_node.get("id", "")) != str(before_node.get("id", ""))
			or not (after_node.get("world_position", Vector2.ZERO) as Vector2).is_equal_approx(
				before_node.get("world_position", Vector2.ZERO) as Vector2
			)
		):
			_fail("x4 candidate moved a node or anchor")
			return false
	var after_camera: Dictionary = after_model.get("camera", {})
	var before_camera: Dictionary = before_model.get("camera", {})
	if (
		not (after_camera.get("offset", Vector2.ZERO) as Vector2).is_equal_approx(
			before_camera.get("offset", Vector2.ZERO) as Vector2
		)
		or not is_equal_approx(
			float(after_camera.get("render_zoom_multiplier", 0.0)),
			float(before_camera.get("render_zoom_multiplier", 0.0))
		)
	):
		_fail("x4 candidate changed camera geometry")
		return false
	return true


func _capture_seam_triplet(
	flow: Object,
	canvas: CanvasItem,
	viewport: SubViewport,
	path: String
) -> bool:
	var model := _last_model(flow)
	var original_camera: Dictionary = model.get("camera", {})
	var original_zoom := float(original_camera.get("render_zoom_multiplier", 1.0))
	var original_offset: Vector2 = original_camera.get("offset", Vector2.ZERO)
	var background: Dictionary = model.get("scroll_background", {})
	var seam_world_ys: Array[float] = []
	var tiles: Array = background.get("tiles", [])
	for index in range(tiles.size() - 1):
		var tile_rect: Rect2 = (tiles[index] as Dictionary).get("rect", Rect2())
		seam_world_ys.append(tile_rect.end.y)
	if seam_world_ys.size() < 3:
		_fail("fewer than three consecutive tile seams exist")
		return false
	var output := Image.create(
		SEAM_CROP_WIDTH,
		SEAM_CROP_HEIGHT * 3,
		false,
		Image.FORMAT_RGBA8
	)
	var source_x := (GAME_SIZE.x - SEAM_CROP_WIDTH) / 2
	var first_seam_index := maxi(0, (seam_world_ys.size() - 3) / 2)
	var drag_state: Object = flow.get("_map_drag_state")
	for index in range(3):
		var seam_world_y := seam_world_ys[first_seam_index + index]
		var requested_offset := Vector2(
			original_offset.x,
			VIEW_RECT.get_center().y - seam_world_y * original_zoom
		)
		drag_state.apply_zoom_override(original_zoom, requested_offset)
		var image := await _capture(canvas, viewport)
		var adjusted_camera: Dictionary = _last_model(flow).get("camera", {})
		var screen_y := int(round(
			seam_world_y * float(adjusted_camera.get("render_zoom_multiplier", 1.0))
			+ (adjusted_camera.get("offset", Vector2.ZERO) as Vector2).y
		))
		if image == null or screen_y < SEAM_CROP_HEIGHT / 2 or screen_y >= GAME_SIZE.y - SEAM_CROP_HEIGHT / 2:
			_fail("a selected tile seam could not be centered inside the Vulkan view")
			return false
		var source_rect := Rect2i(
			source_x,
			screen_y - SEAM_CROP_HEIGHT / 2,
			SEAM_CROP_WIDTH,
			SEAM_CROP_HEIGHT
		)
		output.blit_rect(image, source_rect, Vector2i(0, index * SEAM_CROP_HEIGHT))
	drag_state.apply_zoom_override(original_zoom, original_offset)
	await _redraw(canvas)
	return output.save_png(path) == OK


func _save_pair_crop(left: Image, right: Image, crop: Rect2i, path: String) -> bool:
	if left == null or right == null:
		_fail("pair crop received a null image")
		return false
	var output := Image.create(crop.size.x * 2, crop.size.y, false, Image.FORMAT_RGBA8)
	output.blit_rect(left, crop, Vector2i.ZERO)
	output.blit_rect(right, crop, Vector2i(crop.size.x, 0))
	if output.save_png(path) != OK:
		_fail("could not save pair crop: %s" % path)
		return false
	return true


func _save_crop(image: Image, crop: Rect2i, path: String) -> bool:
	var output := Image.create(crop.size.x, crop.size.y, false, Image.FORMAT_RGBA8)
	output.blit_rect(image, crop, Vector2i.ZERO)
	if output.save_png(path) != OK:
		_fail("could not save crop: %s" % path)
		return false
	return true


func _mean_abs_rgb_diff(left: Image, right: Image, crop: Rect2i) -> float:
	var total := 0.0
	var samples := 0
	for y in range(crop.position.y, crop.end.y, 2):
		for x in range(crop.position.x, crop.end.x, 2):
			var a := left.get_pixel(x, y)
			var b := right.get_pixel(x, y)
			total += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			samples += 3
	return total / float(maxi(1, samples))


func _save(image: Image, path: String) -> bool:
	return image != null and image.get_size() == GAME_SIZE and image.save_png(path) == OK


func _wheel(position: Vector2, zoom_in: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if zoom_in else MOUSE_BUTTON_WHEEL_DOWN
	event.position = position
	event.factor = 1.0
	event.pressed = true
	return event


func _fail(message: String) -> void:
	if not _failure.is_empty():
		return
	_failure = message
	push_error(message)
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	quit(1)
