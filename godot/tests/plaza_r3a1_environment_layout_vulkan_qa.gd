extends SceneTree

# Windowed-only R3-A1.1 visual seal. Seed 4 is a real production-selection layout
# that consumes both semantic extension assets. Capture A retains ground and
# buildings but hides compiled roads/pads/decor; B enables the exact immutable
# plan, proving each approved role by a local pixel delta without touching R1.
# Local seam ratios remain diagnostic. The test first requires the technical
# composition gates (no vertical roads/plaza crossing/exposed end caps, material
# hierarchy, and <=4-turn spine), then emits the whole-map A/B evidence for the
# separate human composition judgment.

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaMapProjection := preload("res://scripts/plaza/plaza_map_projection.gd")
const PlazaMapRoadSkeletonR3 := preload("res://scripts/plaza/plaza_map_road_skeleton_r3.gd")
const PlazaR3EnvironmentLayoutCompiler := preload("res://scripts/plaza/plaza_r3_environment_layout_compiler.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const WORLD_SIZE := Vector2(2400.0, 1500.0)
const SPAWN_ANCHOR := Vector2(120.0, 666.0)
const EXIT_ZONE := Rect2(Vector2(2250.0, 596.0), Vector2(120.0, 92.0))
const MAP_SEED := 4
const SAFE_INSETS := {"left": 72.0, "top": 72.0, "right": 360.0, "bottom": 120.0}
const OUTPUT_DIR := "res://.tmp/plaza_r3a1_environment_layout"
const ENGINE_LOG_PATH := "res://.godot/codex_logs/plaza_r3a1_environment_layout.engine.log"
const MIN_ROLE_CHANGED_PIXELS := 48
const PIXEL_EPSILON := 0.025
const MAX_OVERLAP_DARK_PIXEL_RATIO := 0.25
const OVERLAP_DARK_LUMINANCE_8BIT := 45.0

var _failures: Array[String] = []
var _layout := {}
var _plan := {}
var _projection := {}
var _environment_nodes: Array[CanvasItem] = []
var _role_records: Array[Dictionary] = []
var _environment_nodes_by_asset_id := {}
var _captures: Array[Dictionary] = []
var _role_metrics: Array[Dictionary] = []
var _overlap_metrics: Array[Dictionary] = []
var _composition_visual_metrics := {}
var _outside_delta_metrics := {}
var _window_metrics := {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("plaza_r3a1_environment_layout_vulkan_qa: CANDIDATE-ONLY; production_connected=false")
	if not _prepare_output_directory():
		_finish()
		return
	if not await _require_windowed_vulkan():
		_write_report()
		_finish()
		return
	if not _build_candidate():
		_write_report()
		_finish()
		return
	_set_environment_visible(false)
	await _settle_frames(3)
	var image_a := await _capture("a_environment_off")
	if image_a != null:
		await _verify_isolated_role_pixel_deltas(image_a)
	_set_environment_visible(true)
	await _settle_frames(3)
	var image_b := await _capture("b_environment_on")
	if image_a != null and image_b != null:
		_verify_outside_pixel_delta(image_a, image_b)
		_verify_overlap_pixel_support(image_a, image_b)
	_verify_evidence_files()
	_verify_engine_log_proves_vulkan()
	_write_report()
	_finish()


func _require_windowed_vulkan() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	var rendering_method := RenderingServer.get_current_rendering_method().to_lower()
	var driver_name := _get_user_arg_value("--plaza-r3a1-rendering-driver=").to_lower()
	if display_name.contains("headless"):
		_failures.append("R3-A1 environment QA requires a windowed display server")
	if rendering_method != "mobile":
		_failures.append("R3-A1 environment QA requires rendering method mobile, got %s" % rendering_method)
	if driver_name != "vulkan":
		_failures.append("R3-A1 environment QA requires --plaza-r3a1-rendering-driver=vulkan")
	root.content_scale_size = VIEW_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = VIEW_SIZE
	await process_frame
	await process_frame
	_window_metrics = {
		"display_server": display_name,
		"rendering_method": rendering_method,
		"rendering_driver": driver_name,
		"video_adapter_api_version": RenderingServer.get_video_adapter_api_version(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"requested_size": [VIEW_SIZE.x, VIEW_SIZE.y],
		"live_window_size": [root.size.x, root.size.y],
	}
	_expect(root.size == VIEW_SIZE, "live window must be exact 2020x1246")
	return _failures.is_empty()


func _build_candidate() -> bool:
	var specs := PlazaAssetLoader.build_hwangyeok_building_specs(1, MAP_SEED, false, false)
	_layout = PlazaMapRoadSkeletonR3.generate(1, MAP_SEED, WORLD_SIZE, specs, SPAWN_ANCHOR, EXIT_ZONE)
	_expect(bool((_layout.get("validation", {}) as Dictionary).get("valid", false)), "seed 4 R3-A0.6 layout must validate")
	_plan = PlazaR3EnvironmentLayoutCompiler.compile_layout(_layout)
	var plan_validation := _plan.get("validation", {}) as Dictionary
	_expect(not bool(plan_validation.get("valid", true)), "seed 4 R3-A1 must remain fail-closed until whole-road composition receives approval")
	_expect(not _has_violation(plan_validation, "road_special_orientation_unrepresentable"), "seed 4 special road sprites must match authored directions")
	_expect(_has_violation(plan_validation, "road_network_composition_unapproved"), "seed 4 must expose the whole-road composition blocker before visual capture")
	_expect(not _has_violation(plan_validation, "screen_vertical_road_treatment_missing"), "seed 4 must remove screen-vertical road art")
	_expect(not _has_violation(plan_validation, "central_plaza_exclusion_contract_missing"), "seed 4 must publish the authored central-plaza exclusion")
	_expect(not _has_violation(plan_validation, "central_plaza_road_crossing"), "seed 4 road art must stop at the central-plaza rim")
	_expect(not _has_violation(plan_validation, "central_plaza_forecourt_count_mismatch"), "seed 4 must retain exact two plaza-rim forecourts")
	_expect(not _has_violation(plan_validation, "basis_endcap_treatment_missing"), "seed 4 must leave zero exposed straight-piece endpoints")
	_expect(not _has_violation(plan_validation, "basis_cap_overlap_contract_invalid"), "seed 4 must use fixed cap-depth overlap on every straight continuation")
	_expect(not _has_violation(plan_validation, "road_material_hierarchy_invalid"), "seed 4 must consume the approved road material hierarchy")
	_expect(not _has_violation(plan_validation, "main_spine_turn_budget_exceeded"), "seed 4 main spine must stay within four turns")
	var decor_ids: Array[String] = []
	for record in _dictionary_array(_plan.get("decor_draws", [])):
		if not decor_ids.has(str(record.get("asset_id", ""))):
			decor_ids.append(str(record.get("asset_id", "")))
	_expect(decor_ids.has("ritual_stone_garden") and decor_ids.has("stone_lantern_rest"), "visual seed must naturally consume both new semantic decor assets")
	var safe_rect := PlazaMapProjection.derive_safe_rect(Vector2(VIEW_SIZE), SAFE_INSETS)
	_projection = PlazaMapProjection.build_snapshot(WORLD_SIZE, safe_rect)
	_expect(PlazaMapProjection.is_valid_snapshot(_projection), "full-map projection must validate")
	var evaluation_validation := PlazaR3EnvironmentLayoutCompiler.validate_plan(_plan, _layout, true)
	_expect(bool(evaluation_validation.get("valid", false)), "visual evaluation may bypass only the explicit composition approval decision, got %s" % [evaluation_validation.get("violations", [])])
	if not _failures.is_empty():
		return false

	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(VIEW_SIZE)
	background.color = Color(0.015, 0.013, 0.018, 1.0)
	background.z_index = -2000
	root.add_child(background)
	var board := Node2D.new()
	board.name = "R3A1Board"
	root.add_child(board)
	_add_draw_record(board, _plan.get("ground_draw", {}) as Dictionary, -1000, false)
	for record in _dictionary_array(_plan.get("road_draws", [])):
		_add_draw_record(board, record, -800, true)
	for record in _dictionary_array(_plan.get("plot_pad_draws", [])):
		_add_draw_record(board, record, -600, true)
	var sort_root := Node2D.new()
	sort_root.name = "WorldYSort"
	sort_root.y_sort_enabled = true
	board.add_child(sort_root)
	for record in _dictionary_array(_plan.get("decor_draws", [])):
		_add_sorted_draw_record(sort_root, record)
	_add_buildings(sort_root)
	return _failures.is_empty()


func _add_draw_record(parent: Node, record: Dictionary, z_index: int, environment: bool) -> void:
	var texture := _load_texture(str(record.get("texture_path", "")))
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = str(record.get("id", ""))
	sprite.texture = texture
	sprite.centered = false
	var projection_scale := float(_projection.get("projection_scale", 1.0))
	var anchor_world := record.get("world_position", Vector2.ZERO) as Vector2
	var source_anchor := record.get("source_anchor_pixels", Vector2.ZERO) as Vector2
	var world_scale := record.get("world_scale", Vector2.ONE) as Vector2
	sprite.position = PlazaMapProjection.world_to_screen(anchor_world, _projection) - source_anchor * world_scale * projection_scale
	sprite.scale = world_scale * projection_scale
	sprite.modulate = record.get("modulate", Color.WHITE) as Color if record.get("modulate", null) is Color else Color.WHITE
	sprite.rotation = 0.0
	sprite.flip_h = false
	sprite.flip_v = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = z_index
	parent.add_child(sprite)
	if environment:
		_register_environment_node(sprite, record)


func _add_sorted_draw_record(parent: Node2D, record: Dictionary) -> void:
	var texture := _load_texture(str(record.get("texture_path", "")))
	if texture == null:
		return
	var wrapper := Node2D.new()
	wrapper.name = str(record.get("id", ""))
	wrapper.position = PlazaMapProjection.world_to_screen(record.get("world_position", Vector2.ZERO) as Vector2, _projection)
	wrapper.z_index = 0
	parent.add_child(wrapper)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	var projection_scale := float(_projection.get("projection_scale", 1.0))
	var source_anchor := record.get("source_anchor_pixels", Vector2.ZERO) as Vector2
	var world_scale := record.get("world_scale", Vector2.ONE) as Vector2
	sprite.position = -source_anchor * world_scale * projection_scale
	sprite.scale = world_scale * projection_scale
	sprite.z_index = 0
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	wrapper.add_child(sprite)
	_register_environment_node(wrapper, record)


func _add_buildings(parent: Node2D) -> void:
	var add_material := CanvasItemMaterial.new()
	add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for building in _dictionary_array(_layout.get("building_specs", [])):
		var screen_rect := PlazaMapProjection.world_rect_to_screen(building.get("visual_rect", Rect2()) as Rect2, _projection)
		var anchor_screen := PlazaMapProjection.world_to_screen(building.get("sort_anchor_world", Vector2.ZERO) as Vector2, _projection)
		var wrapper := Node2D.new()
		wrapper.name = "Building_%s" % str(building.get("type", ""))
		wrapper.position = anchor_screen
		wrapper.z_index = 0
		parent.add_child(wrapper)
		for layer in [
			{"key": "base_texture", "add": false, "color": Color.WHITE, "strength": 1.0},
			{"key": "sign_texture", "add": true, "color": building.get("sign_glow_color", Color.WHITE), "strength": float(building.get("sign_glow_strength", 1.0))},
			{"key": "window_texture", "add": true, "color": building.get("window_glow_color", Color.WHITE), "strength": float(building.get("window_glow_strength", 1.0))},
		]:
			var texture_value: Variant = building.get(str(layer.get("key", "")), null)
			if not (texture_value is Texture2D):
				_failures.append("building layer missing Texture2D: %s:%s" % [building.get("type", ""), layer.get("key", "")])
				continue
			var sprite := Sprite2D.new()
			var texture := texture_value as Texture2D
			sprite.texture = texture
			sprite.centered = false
			sprite.position = screen_rect.position - anchor_screen
			sprite.scale = screen_rect.size / Vector2(texture.get_width(), texture.get_height())
			sprite.z_index = 0
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			if bool(layer.get("add", false)):
				sprite.material = add_material
				sprite.modulate = (layer.get("color", Color.WHITE) as Color) * float(layer.get("strength", 1.0))
			wrapper.add_child(sprite)


func _load_texture(path: String) -> Texture2D:
	var value: Variant = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if not (value is Texture2D):
		_failures.append("failed to load planned texture: %s" % path)
		return null
	return value as Texture2D


func _set_environment_visible(visible: bool) -> void:
	for asset_id_value in _environment_nodes_by_asset_id.keys():
		var asset_id := str(asset_id_value)
		var nodes_value: Variant = _environment_nodes_by_asset_id.get(asset_id, [])
		if nodes_value is Array:
			for node_value in nodes_value as Array:
				if node_value is CanvasItem:
					(node_value as CanvasItem).visible = visible


func _register_environment_node(item: CanvasItem, record: Dictionary) -> void:
	_environment_nodes.append(item)
	_role_records.append(record)
	var asset_id := str(record.get("asset_id", ""))
	var nodes_value: Variant = _environment_nodes_by_asset_id.get(asset_id, [])
	var nodes: Array = nodes_value as Array if nodes_value is Array else []
	nodes.append(item)
	_environment_nodes_by_asset_id[asset_id] = nodes


func _verify_isolated_role_pixel_deltas(baseline: Image) -> void:
	var seen_ids := {}
	for record in _role_records:
		seen_ids[str(record.get("asset_id", ""))] = true
	var ordered_ids: Array[String] = []
	for record in _dictionary_array(_plan.get("road_draws", [])):
		var road_asset_id := str(record.get("asset_id", ""))
		if road_asset_id != "" and not ordered_ids.has(road_asset_id):
			ordered_ids.append(road_asset_id)
	for asset_id in ["plot_pad_large", "plot_pad_small", "ritual_stone_garden", "stone_lantern_rest", "market", "pine", "pond", "supply", "wayfinder"]:
		if seen_ids.has(asset_id) and not ordered_ids.has(asset_id):
			ordered_ids.append(asset_id)
	ordered_ids.sort()
	for asset_id in ordered_ids:
		_set_environment_visible(false)
		var nodes_value: Variant = _environment_nodes_by_asset_id.get(asset_id, [])
		var nodes: Array = nodes_value as Array if nodes_value is Array else []
		for node_value in nodes:
			if node_value is CanvasItem:
				(node_value as CanvasItem).visible = true
		await _settle_frames(2)
		var isolated := root.get_texture().get_image()
		var changed := 0
		var rois: Array[Array] = []
		for record in _role_records:
			if str(record.get("asset_id", "")) != asset_id:
				continue
			var world_rect := record.get("world_rect", Rect2()) as Rect2
			var screen_rect := PlazaMapProjection.world_rect_to_screen(world_rect, _projection)
			var roi := _clip_rect_to_image(Rect2i(screen_rect.grow(2.0)), baseline)
			changed += _count_changed_pixels(baseline, isolated, roi)
			rois.append([roi.position.x, roi.position.y, roi.size.x, roi.size.y])
		_role_metrics.append({"asset_id": asset_id, "instance_count": nodes.size(), "rois": rois, "isolated_changed_pixels": changed})
		_expect(changed >= MIN_ROLE_CHANGED_PIXELS, "isolated asset %s needs a non-vacuous GPU pixel delta, got %d" % [asset_id, changed])
	_set_environment_visible(false)
	_expect(not seen_ids.has("straight_vertical"), "visual seed must never draw the retired screen-vertical road asset")
	var observed_material_classes := {}
	for record in _dictionary_array(_plan.get("road_draws", [])):
		if str(record.get("role", "")) == "basis_segment":
			observed_material_classes[str(record.get("road_material_class", ""))] = true
	for material_class in ["ceremonial_jade_gold_pavers", "trimless_stone", "compacted_earth_gravel"]:
		_expect(observed_material_classes.has(material_class), "visual seed must draw road material class %s" % material_class)
	for asset_id in ["plot_pad_large", "plot_pad_small", "ritual_stone_garden", "stone_lantern_rest"]:
		_expect(seen_ids.has(asset_id), "visual seed must draw required environment role %s" % asset_id)


func _verify_outside_pixel_delta(image_a: Image, image_b: Image) -> void:
	var content_rect := Rect2i(PlazaMapProjection.get_map_content_screen_rect(_projection))
	var approved_bleed_rois: Array[Rect2i] = []
	for record in _dictionary_array(_plan.get("road_draws", [])):
		if not bool(record.get("exit_world_bleed", false)):
			continue
		var screen_rect := PlazaMapProjection.world_rect_to_screen(record.get("world_rect", Rect2()) as Rect2, _projection)
		approved_bleed_rois.append(_clip_rect_to_image(Rect2i(screen_rect.grow(2.0)), image_a))
	var approved_exit_bleed_changed := 0
	var forbidden_outside_changed := 0
	for y in range(image_a.get_height()):
		for x in range(image_a.get_width()):
			if content_rect.has_point(Vector2i(x, y)):
				continue
			if not _pixel_changed(image_a.get_pixel(x, y), image_b.get_pixel(x, y)):
				continue
			var inside_approved_exit_bleed := false
			for bleed_roi in approved_bleed_rois:
				if bleed_roi.has_point(Vector2i(x, y)):
					inside_approved_exit_bleed = true
					break
			if inside_approved_exit_bleed:
				approved_exit_bleed_changed += 1
			else:
				forbidden_outside_changed += 1
	_expect(approved_bleed_rois.size() == 1, "visual seed must expose exactly one fingerprint-bound exit bleed ROI")
	_expect(approved_exit_bleed_changed > 0, "the approved exit bleed must produce a non-vacuous outside-content pixel delta")
	_expect(forbidden_outside_changed == 0, "environment toggle must not change pixels outside map content and the approved exit bleed, got %d" % forbidden_outside_changed)
	_outside_delta_metrics = {
		"approved_exit_bleed_roi_count": approved_bleed_rois.size(),
		"approved_exit_bleed_changed_pixels": approved_exit_bleed_changed,
		"forbidden_outside_changed_pixels": forbidden_outside_changed,
	}


func _verify_overlap_pixel_support(image_a: Image, image_b: Image) -> void:
	var overlap_records := _dictionary_array(_plan.get("road_overlap_records", []))
	var compiled_metrics := _plan.get("road_composition_metrics", {}) as Dictionary
	_expect(overlap_records.size() == int(compiled_metrics.get("explicit_basis_overlap_count", -1)), "pixel overlap records must exactly match compiled non-node crossings")
	var supported := 0
	var seam_clean := 0
	for overlap in overlap_records:
		var anchor := PlazaMapProjection.world_to_screen(overlap.get("anchor_world", Vector2.ZERO) as Vector2, _projection)
		var roi := _clip_rect_to_image(Rect2i(Vector2i(anchor) - Vector2i(5, 5), Vector2i(11, 11)), image_a)
		var changed := _count_changed_pixels(image_a, image_b, roi)
		var dark_pixels := _count_dark_pixels(image_b, roi)
		var dark_ratio := float(dark_pixels) / float(maxi(1, roi.get_area()))
		if changed >= 9:
			supported += 1
		if dark_ratio <= MAX_OVERLAP_DARK_PIXEL_RATIO:
			seam_clean += 1
		_overlap_metrics.append({
			"id": str(overlap.get("id", "")),
			"kind": str(overlap.get("kind", "")),
			"orientation_signature": str(overlap.get("orientation_signature", "")),
			"roi": [roi.position.x, roi.position.y, roi.size.x, roi.size.y],
			"changed_pixels": changed,
			"dark_pixels": dark_pixels,
			"dark_pixel_ratio": dark_ratio,
		})
	_expect(supported == overlap_records.size(), "every explicit overlap must show road pixels in its local ROI, supported=%d/%d" % [supported, overlap_records.size()])
	_composition_visual_metrics = {
		"primary_verdict": "PENDING_manual_whole_map_composition_review",
		"screen_vertical_segment_count": int(compiled_metrics.get("screen_vertical_segment_count", -1)),
		"screen_vertical_world_length": float(compiled_metrics.get("screen_vertical_world_length", -1.0)),
		"central_plaza_exclusion_contract_present": bool(compiled_metrics.get("central_plaza_exclusion_contract_present", false)),
		"central_plaza_crossing_count": int(compiled_metrics.get("central_plaza_crossing_count", -1)),
		"central_plaza_forecourt_count": int(compiled_metrics.get("central_plaza_forecourt_count", -1)),
		"basis_endpoint_without_special_cover_count": int(compiled_metrics.get("basis_endpoint_without_special_cover_count", -1)),
		"basis_cap_overlap_contract_valid": bool(compiled_metrics.get("basis_cap_overlap_contract_valid", false)),
		"road_width_hierarchy_valid": bool(compiled_metrics.get("road_width_hierarchy_valid", false)),
		"road_material_hierarchy_valid": bool(compiled_metrics.get("road_material_hierarchy_valid", false)),
		"authored_main_spine_turn_count": int(compiled_metrics.get("authored_main_spine_turn_count", -1)),
		"rendered_spawn_to_plaza_turn_count": int(compiled_metrics.get("rendered_spawn_to_plaza_turn_count", -1)),
		"overlap_supported": supported,
		"overlap_record_count": overlap_records.size(),
		"overlap_zero_contract_valid": overlap_records.is_empty() and int(compiled_metrics.get("explicit_basis_overlap_count", -1)) == 0,
		"local_seam_clean": seam_clean,
		"local_seam_failure_count": overlap_records.size() - seam_clean,
	}
	_expect(int(compiled_metrics.get("screen_vertical_segment_count", -1)) == 0, "captured plan must contain zero screen-vertical straight-road draws")
	_expect(bool(compiled_metrics.get("central_plaza_exclusion_contract_present", false)), "captured plan must bind the central-plaza exclusion")
	_expect(int(compiled_metrics.get("central_plaza_crossing_count", -1)) == 0, "captured plan must contain zero central-plaza road crossings")
	_expect(int(compiled_metrics.get("central_plaza_forecourt_count", -1)) == 2, "captured plan must render exact two plaza-rim forecourts")
	_expect(int(compiled_metrics.get("basis_endpoint_without_special_cover_count", -1)) == 0, "captured plan must contain zero exposed straight-piece endpoints")
	_expect(bool(compiled_metrics.get("basis_cap_overlap_contract_valid", false)), "captured plan must preserve fixed cap-depth overlap")
	_expect(bool(compiled_metrics.get("road_material_hierarchy_valid", false)), "captured plan must retain the approved material hierarchy")
	_expect(int(compiled_metrics.get("rendered_spawn_to_plaza_turn_count", 999)) <= PlazaMapRoadSkeletonR3.MAX_MAIN_SPINE_TURN_COUNT, "captured rendered spawn-to-plaza main route must stay within four turns")


func _count_dark_pixels(image: Image, roi: Rect2i) -> int:
	var dark := 0
	for y in range(roi.position.y, roi.end.y):
		for x in range(roi.position.x, roi.end.x):
			var color := image.get_pixel(x, y)
			var luminance_8bit := (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) * 255.0
			if luminance_8bit < OVERLAP_DARK_LUMINANCE_8BIT:
				dark += 1
	return dark


func _count_changed_pixels(a: Image, b: Image, roi: Rect2i) -> int:
	var changed := 0
	for y in range(roi.position.y, roi.end.y):
		for x in range(roi.position.x, roi.end.x):
			if _pixel_changed(a.get_pixel(x, y), b.get_pixel(x, y)):
				changed += 1
	return changed


func _pixel_changed(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) > PIXEL_EPSILON or absf(a.g - b.g) > PIXEL_EPSILON or absf(a.b - b.b) > PIXEL_EPSILON


func _clip_rect_to_image(rect: Rect2i, image: Image) -> Rect2i:
	return rect.intersection(Rect2i(0, 0, image.get_width(), image.get_height()))


func _capture(slug: String) -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("capture %s returned an empty image" % slug)
		return null
	var path := OUTPUT_DIR.path_join("%s.png" % slug)
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		_failures.append("capture %s save failed: %d" % [slug, error])
		return null
	_captures.append({"slug": slug, "path": path, "size": [image.get_width(), image.get_height()], "sha256": FileAccess.get_sha256(path)})
	return image


func _settle_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await RenderingServer.frame_post_draw


func _prepare_output_directory() -> bool:
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		_failures.append("failed to create output directory: %s" % output_dir)
		return false
	for filename in DirAccess.get_files_at(output_dir):
		if DirAccess.remove_absolute(output_dir.path_join(str(filename))) != OK:
			_failures.append("failed to remove stale evidence: %s" % filename)
	return _failures.is_empty()


func _verify_evidence_files() -> void:
	_expect(_captures.size() == 2, "R3-A1 visual seal requires exact A/B captures")
	var actual: Array[String] = []
	for filename in DirAccess.get_files_at(ProjectSettings.globalize_path(OUTPUT_DIR)):
		if str(filename).get_extension().to_lower() == "png":
			actual.append(str(filename))
	actual.sort()
	_expect(actual == ["a_environment_off.png", "b_environment_on.png"], "evidence directory must contain exact A/B PNGs")


func _verify_engine_log_proves_vulkan() -> void:
	var engine_log := FileAccess.get_file_as_string(ENGINE_LOG_PATH)
	var has_banner := engine_log.contains("Vulkan ") and engine_log.contains("Forward Mobile")
	_window_metrics["engine_log_has_vulkan_mobile_banner"] = has_banner
	_expect(has_banner, "engine log must contain the real Vulkan Forward Mobile banner")


func _write_report() -> void:
	var report := {
		"schema": "plaza_r3a1_environment_layout_vulkan_qa_v1",
		"pass": _failures.is_empty(),
		"failure_count": _failures.size(),
		"failures": _failures,
		"candidate_only": true,
		"production_connected": false,
		"map_seed": MAP_SEED,
		"layout_fingerprint": str(_layout.get("fingerprint", "")),
		"environment_plan_fingerprint": str(_plan.get("fingerprint", "")),
		"window": _window_metrics,
		"captures": _captures,
		"role_pixel_metrics": _role_metrics,
		"overlap_pixel_metrics": _overlap_metrics,
		"road_composition_visual_metrics": _composition_visual_metrics,
		"outside_content_delta_metrics": _outside_delta_metrics,
		"compiled_road_composition_metrics": _plan.get("road_composition_metrics", {}),
	}
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("metrics.json"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to write metrics: %s" % path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item in value as Array:
		if item is Dictionary:
			result.append(item as Dictionary)
	return result


func _has_violation(result: Dictionary, code: String) -> bool:
	for violation in _dictionary_array(result.get("violations", [])):
		if str(violation.get("code", "")) == code:
			return true
	return false


func _get_user_arg_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty() and (_captures.size() != 2 or _role_metrics.is_empty()):
		_failures.append("run ended before durable A/B pixel evidence completed")
		_write_report()
	if _failures.is_empty():
		print("plaza_r3a1_environment_layout_vulkan_qa: ok")
		print("plaza_r3a1_environment_layout_vulkan_qa: evidence=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
