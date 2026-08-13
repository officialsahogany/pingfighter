extends SceneTree

# Windowed Vulkan acceptance plate for the R2 environment art set.  This is an
# art gate, not an R3 production route: A=ground, B=ground+six roads,
# C=ground+roads+two plot pads, D=ground+roads+pads+five decor clusters.

const VIEW_SIZE := Vector2i(2020, 1246)
const MANIFEST_PATH := "res://assets/ui/plaza/environment/hwangyeok_r2/plaza_hwangyeok_r2_environment_manifest.json"
const OUTPUT_DIR := "res://.tmp/plaza_r2_environment_art_vulkan"
const ENGINE_LOG_PATH := "res://.godot/codex_logs/plaza_r2_environment_art_vulkan.engine.log"
const EXPECTED_ROAD_IDS := [
	"straight_positive",
	"straight_negative",
	"three_way",
	"plot_spur",
	"terminus",
	"entrance_forecourt",
]
const EXPECTED_PLOT_PAD_IDS := ["plot_pad_large", "plot_pad_small"]
const EXPECTED_DECOR_IDS := ["market", "pine", "pond", "supply", "wayfinder"]
const ROAD_CENTERS := [
	Vector2(330.0, 305.0),
	Vector2(760.0, 305.0),
	Vector2(1230.0, 305.0),
	Vector2(350.0, 645.0),
	Vector2(790.0, 645.0),
	Vector2(1250.0, 645.0),
]
const DECOR_CENTERS := [
	Vector2(225.0, 1000.0),
	Vector2(535.0, 1000.0),
	Vector2(845.0, 1000.0),
	Vector2(1155.0, 1000.0),
	Vector2(1465.0, 1000.0),
]
const PLOT_PAD_CENTERS := [Vector2(400.0, 915.0), Vector2(1050.0, 915.0)]
const ROAD_SCALE := 0.52
const PLOT_PAD_SCALE := 0.86
const DECOR_TARGET_HEIGHT := 205.0
const PIXEL_EPSILON := 0.025
const MIN_ASSET_CHANGED_PIXELS := 180
const MAX_OUTSIDE_CHANGE_RATIO := 0.002

var _failures: Array[String] = []
var _asset_records: Dictionary = {}
var _board: Node2D = null
var _road_nodes: Array[Sprite2D] = []
var _plot_pad_nodes: Array[Sprite2D] = []
var _decor_nodes: Array[Sprite2D] = []
var _road_rois: Array[Rect2i] = []
var _plot_pad_rois: Array[Rect2i] = []
var _decor_rois: Array[Rect2i] = []
var _captures: Array[Dictionary] = []
var _road_metrics: Array[Dictionary] = []
var _plot_pad_metrics: Array[Dictionary] = []
var _decor_metrics: Array[Dictionary] = []
var _outside_metrics := {}
var _window_metrics := {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _prepare_output_directory():
		_write_metrics()
		_finish()
		return
	if not await _require_windowed_vulkan_mobile():
		_write_metrics()
		_finish()
		return
	if not _load_runtime_assets():
		_write_metrics()
		_finish()
		return
	_build_board()
	if _board == null:
		_write_metrics()
		_finish()
		return

	_set_group_visible(_road_nodes, false)
	_set_group_visible(_plot_pad_nodes, false)
	_set_group_visible(_decor_nodes, false)
	await _settle_frames(3)
	var ground_image := await _capture("a_ground")

	_set_group_visible(_road_nodes, true)
	await _settle_frames(3)
	var road_image := await _capture("b_roads")

	_set_group_visible(_plot_pad_nodes, true)
	await _settle_frames(3)
	var plot_pad_image := await _capture("c_plot_pads")

	_set_group_visible(_decor_nodes, true)
	await _settle_frames(3)
	var decor_image := await _capture("d_decor")

	if ground_image != null and road_image != null and plot_pad_image != null and decor_image != null:
		_verify_road_deltas(ground_image, road_image)
		_verify_plot_pad_deltas(road_image, plot_pad_image)
		_verify_decor_deltas(plot_pad_image, decor_image)
		_verify_outside_invariance(ground_image, road_image, plot_pad_image, decor_image)
	_verify_evidence_contract()
	_verify_engine_log()
	_write_metrics()
	_finish()


func _prepare_output_directory() -> bool:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if mkdir_error != OK:
		_failures.append("failed to create environment art evidence directory")
		return false
	for filename in ["a_ground.png", "b_roads.png", "c_plot_pads.png", "d_decor.png", "c_decor.png", "metrics.json"]:
		var absolute_path := absolute_dir.path_join(filename)
		if FileAccess.file_exists(absolute_path):
			var remove_error := DirAccess.remove_absolute(absolute_path)
			if remove_error != OK:
				_failures.append("failed to remove stale evidence %s" % filename)
				return false
	return true


func _require_windowed_vulkan_mobile() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	if display_name.contains("headless"):
		_failures.append("environment art QA requires a windowed display server")
		return false
	var rendering_method := RenderingServer.get_current_rendering_method().to_lower()
	if rendering_method != "mobile":
		_failures.append("environment art QA requires rendering method mobile, got %s" % rendering_method)
		return false
	var driver_arg := _get_user_arg_value("--plaza-r2-environment-rendering-driver=").to_lower()
	if driver_arg != "vulkan":
		_failures.append("environment art QA requires --plaza-r2-environment-rendering-driver=vulkan")
		return false

	root.content_scale_size = VIEW_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = VIEW_SIZE
	await process_frame
	await process_frame
	_window_metrics = {
		"display_server": display_name,
		"rendering_method": rendering_method,
		"rendering_driver_arg": driver_arg,
		"video_adapter_api_version": RenderingServer.get_video_adapter_api_version(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"requested_size": [VIEW_SIZE.x, VIEW_SIZE.y],
		"live_size": [root.size.x, root.size.y],
	}
	_expect(root.size == VIEW_SIZE, "live environment art window must be exactly 2020x1246")
	return _failures.is_empty()


func _load_runtime_assets() -> bool:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_failures.append("environment art manifest is missing")
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not (parsed is Dictionary):
		_failures.append("environment art manifest must parse as a dictionary")
		return false
	var manifest := parsed as Dictionary
	_expect(bool(manifest.get("candidate_only", false)), "environment art manifest must remain candidate_only")
	_expect(not bool(manifest.get("production_connected", true)), "environment art manifest must remain production-disconnected")
	var assets_value: Variant = manifest.get("assets", [])
	if not (assets_value is Array):
		_failures.append("environment art manifest assets must be an array")
		return false
	for asset_value in assets_value as Array:
		if not (asset_value is Dictionary):
			continue
		var asset := asset_value as Dictionary
		var asset_id := str(asset.get("asset_id", ""))
		var res_path := str(asset.get("res_path", ""))
		var texture_value: Variant = ResourceLoader.load(res_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
		if not (texture_value is Texture2D):
			_failures.append("environment art texture failed to load: %s" % asset_id)
			continue
		var image := Image.new()
		var image_error := image.load(ProjectSettings.globalize_path(res_path))
		if image_error != OK or image.is_empty():
			_failures.append("environment art PNG failed to decode: %s" % asset_id)
			continue
		image.convert(Image.FORMAT_RGBA8)
		_asset_records[asset_id] = {
			"kind": str(asset.get("kind", "")),
			"texture": texture_value as Texture2D,
			"image": image,
			"res_path": res_path,
			"sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(res_path)),
		}
	_expect(_asset_records.size() == 14, "environment art QA must load all 14 runtime textures")
	return _failures.is_empty()


func _build_board() -> void:
	RenderingServer.set_default_clear_color(Color(0.006, 0.006, 0.008, 1.0))
	_board = Node2D.new()
	_board.name = "PlazaR2EnvironmentArtBoard"
	root.add_child(_board)

	var ground_record_value: Variant = _asset_records.get("map_ground", {})
	if not (ground_record_value is Dictionary):
		_failures.append("map ground record is missing")
		return
	var ground_record := ground_record_value as Dictionary
	var ground_texture := ground_record.get("texture", null) as Texture2D
	var ground := Sprite2D.new()
	ground.name = "Ground"
	ground.texture = ground_texture
	ground.centered = true
	ground.position = Vector2(840.0, 594.0)
	ground.scale = Vector2(1.01, 1.01)
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ground.z_index = 0
	_board.add_child(ground)

	var right_band := ColorRect.new()
	right_band.name = "RightBand"
	right_band.position = Vector2(1660.0, 0.0)
	right_band.size = Vector2(360.0, 1246.0)
	right_band.color = Color(0.012, 0.011, 0.010, 1.0)
	right_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_band.z_index = 100
	_board.add_child(right_band)

	for index in range(EXPECTED_ROAD_IDS.size()):
		var asset_id: String = EXPECTED_ROAD_IDS[index]
		var center: Vector2 = ROAD_CENTERS[index]
		var sprite := _make_sprite(asset_id, center, Vector2.ONE * ROAD_SCALE, 10)
		if sprite == null:
			continue
		_board.add_child(sprite)
		_road_nodes.append(sprite)
		_road_rois.append(_sprite_canvas_rect(sprite).grow(4))

	for index in range(EXPECTED_DECOR_IDS.size()):
		var asset_id: String = EXPECTED_DECOR_IDS[index]
		var center: Vector2 = DECOR_CENTERS[index]
		var record := _asset_records.get(asset_id, {}) as Dictionary
		var image := record.get("image", null) as Image
		if image == null:
			continue
		var used_rect := image.get_used_rect()
		var uniform_scale := DECOR_TARGET_HEIGHT / maxf(1.0, float(used_rect.size.y))
		var sprite := _make_sprite(asset_id, center, Vector2.ONE * uniform_scale, 20)
		if sprite == null:
			continue
		_board.add_child(sprite)
		_decor_nodes.append(sprite)
		_decor_rois.append(_sprite_canvas_rect(sprite).grow(4))

	for index in range(EXPECTED_PLOT_PAD_IDS.size()):
		var asset_id: String = EXPECTED_PLOT_PAD_IDS[index]
		var center: Vector2 = PLOT_PAD_CENTERS[index]
		var sprite := _make_sprite(asset_id, center, Vector2.ONE * PLOT_PAD_SCALE, 15)
		if sprite == null:
			continue
		_board.add_child(sprite)
		_plot_pad_nodes.append(sprite)
		_plot_pad_rois.append(_sprite_canvas_rect(sprite).grow(4))

	_expect(_road_nodes.size() == 6, "environment art board must instantiate all six road pieces")
	_expect(_plot_pad_nodes.size() == 2, "environment art board must instantiate both plot pads")
	_expect(_decor_nodes.size() == 5, "environment art board must instantiate all five decor clusters")
	for roi in _road_rois + _plot_pad_rois + _decor_rois:
		_expect(Rect2i(Vector2i.ZERO, VIEW_SIZE).encloses(roi), "environment art sprite ROI must remain inside the live viewport: %s" % roi)


func _make_sprite(asset_id: String, center: Vector2, scale_value: Vector2, z_index_value: int) -> Sprite2D:
	var record_value: Variant = _asset_records.get(asset_id, {})
	if not (record_value is Dictionary):
		_failures.append("missing environment art record %s" % asset_id)
		return null
	var texture_value: Variant = (record_value as Dictionary).get("texture", null)
	if not (texture_value is Texture2D):
		_failures.append("missing environment art Texture2D %s" % asset_id)
		return null
	var sprite := Sprite2D.new()
	sprite.name = asset_id
	sprite.texture = texture_value as Texture2D
	sprite.centered = true
	sprite.position = center
	sprite.scale = scale_value
	sprite.rotation = 0.0
	sprite.flip_h = false
	sprite.flip_v = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_index = z_index_value
	return sprite


func _sprite_canvas_rect(sprite: Sprite2D) -> Rect2i:
	var texture := sprite.texture
	if texture == null:
		return Rect2i()
	var size := Vector2(texture.get_width(), texture.get_height()) * sprite.scale.abs()
	return Rect2i(Vector2i((sprite.position - size * 0.5).floor()), Vector2i(size.ceil()))


func _set_group_visible(nodes: Array[Sprite2D], visible_value: bool) -> void:
	for node in nodes:
		node.visible = visible_value


func _settle_frames(count: int) -> void:
	for _index in range(count):
		await process_frame
		await RenderingServer.frame_post_draw


func _capture(slug: String) -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("capture %s returned an empty image" % slug)
		return null
	image.convert(Image.FORMAT_RGBA8)
	_expect(Vector2i(image.get_width(), image.get_height()) == VIEW_SIZE, "capture %s must be 2020x1246" % slug)
	var res_path := "%s/%s.png" % [OUTPUT_DIR, slug]
	var save_error := image.save_png(ProjectSettings.globalize_path(res_path))
	_expect(save_error == OK, "capture %s must save successfully" % slug)
	if save_error == OK:
		_captures.append({"slug": slug, "res_path": res_path, "sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(res_path))})
	return image


func _verify_road_deltas(before: Image, after: Image) -> void:
	for index in range(_road_rois.size()):
		var changed := _count_changed_pixels(before, after, _road_rois[index])
		_road_metrics.append({"asset_id": EXPECTED_ROAD_IDS[index], "changed_pixels": changed, "roi": _rect_to_array(_road_rois[index])})
		_expect(changed >= MIN_ASSET_CHANGED_PIXELS, "road %s must visibly change at least %d pixels" % [EXPECTED_ROAD_IDS[index], MIN_ASSET_CHANGED_PIXELS])


func _verify_decor_deltas(before: Image, after: Image) -> void:
	for index in range(_decor_rois.size()):
		var changed := _count_changed_pixels(before, after, _decor_rois[index])
		_decor_metrics.append({"asset_id": EXPECTED_DECOR_IDS[index], "changed_pixels": changed, "roi": _rect_to_array(_decor_rois[index])})
		_expect(changed >= MIN_ASSET_CHANGED_PIXELS, "decor %s must visibly change at least %d pixels" % [EXPECTED_DECOR_IDS[index], MIN_ASSET_CHANGED_PIXELS])


func _verify_plot_pad_deltas(before: Image, after: Image) -> void:
	for index in range(_plot_pad_rois.size()):
		var changed := _count_changed_pixels(before, after, _plot_pad_rois[index])
		_plot_pad_metrics.append({"asset_id": EXPECTED_PLOT_PAD_IDS[index], "changed_pixels": changed, "roi": _rect_to_array(_plot_pad_rois[index])})
		_expect(changed >= MIN_ASSET_CHANGED_PIXELS, "plot pad %s must visibly change at least %d pixels" % [EXPECTED_PLOT_PAD_IDS[index], MIN_ASSET_CHANGED_PIXELS])


func _verify_outside_invariance(ground_image: Image, road_image: Image, plot_pad_image: Image, decor_image: Image) -> void:
	var road_outside := _count_changed_outside_rois(ground_image, road_image, _road_rois)
	var plot_pad_outside := _count_changed_outside_rois(road_image, plot_pad_image, _plot_pad_rois)
	var decor_outside := _count_changed_outside_rois(plot_pad_image, decor_image, _decor_rois)
	_outside_metrics = {
		"road": road_outside,
		"plot_pad": plot_pad_outside,
		"decor": decor_outside,
	}
	_expect(float(road_outside.get("ratio", 1.0)) <= MAX_OUTSIDE_CHANGE_RATIO, "road capture must keep pixels outside road ROIs invariant")
	_expect(float(plot_pad_outside.get("ratio", 1.0)) <= MAX_OUTSIDE_CHANGE_RATIO, "plot-pad capture must keep pixels outside plot-pad ROIs invariant")
	_expect(float(decor_outside.get("ratio", 1.0)) <= MAX_OUTSIDE_CHANGE_RATIO, "decor capture must keep pixels outside decor ROIs invariant")


func _count_changed_pixels(left: Image, right: Image, roi: Rect2i) -> int:
	var clipped := roi.intersection(Rect2i(Vector2i.ZERO, VIEW_SIZE))
	var changed := 0
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			if _color_delta(left.get_pixel(x, y), right.get_pixel(x, y)) > PIXEL_EPSILON:
				changed += 1
	return changed


func _count_changed_outside_rois(left: Image, right: Image, rois: Array[Rect2i]) -> Dictionary:
	var samples := 0
	var changed := 0
	for y in range(VIEW_SIZE.y):
		for x in range(VIEW_SIZE.x):
			var point := Vector2i(x, y)
			var inside := false
			for roi in rois:
				if roi.has_point(point):
					inside = true
					break
			if inside:
				continue
			samples += 1
			if _color_delta(left.get_pixel(x, y), right.get_pixel(x, y)) > PIXEL_EPSILON:
				changed += 1
	return {"sample_pixels": samples, "changed_pixels": changed, "ratio": float(changed) / maxf(1.0, float(samples))}


func _color_delta(left: Color, right: Color) -> float:
	return maxf(absf(left.r - right.r), maxf(absf(left.g - right.g), absf(left.b - right.b)))


func _verify_evidence_contract() -> void:
	var expected_slugs := ["a_ground", "b_roads", "c_plot_pads", "d_decor"]
	var expected_png_names := ["a_ground.png", "b_roads.png", "c_plot_pads.png", "d_decor.png"]
	var actual_slugs: Array[String] = []
	for record in _captures:
		actual_slugs.append(str(record.get("slug", "")))
	_expect(actual_slugs == expected_slugs, "environment art captures must be exact ordered A/B/C/D evidence")
	_expect(_road_metrics.size() == 6, "environment art metrics must cover six road pieces")
	_expect(_plot_pad_metrics.size() == 2, "environment art metrics must cover two plot pads")
	_expect(_decor_metrics.size() == 5, "environment art metrics must cover five decor clusters")
	var actual_png_names: Array[String] = []
	var evidence_dir := DirAccess.open(OUTPUT_DIR)
	if evidence_dir == null:
		_failures.append("environment art evidence directory must be readable")
	else:
		for filename in evidence_dir.get_files():
			if filename.ends_with(".png"):
				actual_png_names.append(filename)
		actual_png_names.sort()
		expected_png_names.sort()
		_expect(actual_png_names == expected_png_names, "environment art evidence must contain the exact four A/B/C/D PNGs")
	for record in _captures:
		var res_path := str(record.get("res_path", ""))
		_expect(FileAccess.file_exists(res_path), "capture evidence must exist: %s" % res_path)
		var evidence_file := FileAccess.open(res_path, FileAccess.READ)
		_expect(evidence_file != null and evidence_file.get_length() > 0, "capture evidence must be non-empty: %s" % res_path)


func _verify_engine_log() -> void:
	if not FileAccess.file_exists(ENGINE_LOG_PATH):
		_failures.append("environment art engine log is missing")
		return
	var log_text := FileAccess.get_file_as_string(ENGINE_LOG_PATH)
	_expect(log_text.contains("Vulkan "), "engine log must prove Vulkan")
	_expect(log_text.contains("Forward Mobile"), "engine log must prove Forward Mobile")
	_expect(not log_text.contains("SCRIPT ERROR"), "engine log must contain no SCRIPT ERROR")


func _write_metrics() -> void:
	var report := {
		"pass": _failures.is_empty(),
		"failure_count": _failures.size(),
		"failures": _failures,
		"candidate_only": true,
		"production_connected": false,
		"view_size": [VIEW_SIZE.x, VIEW_SIZE.y],
		"window": _window_metrics,
		"captures": _captures,
		"road_metrics": _road_metrics,
		"plot_pad_metrics": _plot_pad_metrics,
		"decor_metrics": _decor_metrics,
		"outside_metrics": _outside_metrics,
	}
	var absolute_path := ProjectSettings.globalize_path("%s/metrics.json" % OUTPUT_DIR)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to open environment art metrics.json")
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.flush()
	file.close()


func _get_user_arg_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _rect_to_array(rect: Rect2i) -> Array[int]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("plaza_r2_environment_art_vulkan_qa: ok")
		quit(0)
		return
	for failure in _failures:
		push_error("plaza_r2_environment_art_vulkan_qa: %s" % failure)
	quit(1)
