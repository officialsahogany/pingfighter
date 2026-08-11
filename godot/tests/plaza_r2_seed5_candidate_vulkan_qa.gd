extends SceneTree

# Workspace-only R2-A visual candidate. This deliberately does not instantiate
# PlazaScene or mutate its R1 production bridge. The board consumes the new
# pure projection/layout APIs, approved building manifests, and ignored tmp
# decor prototypes, then emits paired Vulkan captures with a RED counterproof.

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaMapLayoutGenerator := preload("res://scripts/plaza/plaza_map_layout_generator.gd")
const PlazaMapProjection := preload("res://scripts/plaza/plaza_map_projection.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const WORLD_SIZE := Vector2(2400.0, 1500.0)
const SPAWN_ANCHOR := Vector2(120.0, 666.0)
const EXIT_ZONE := Rect2(Vector2(2250.0, 596.0), Vector2(120.0, 92.0))
const STAGE_ID := 1
const MAP_SEED := 5
const MAX_LANDMARK_GAP_WORLD := 360.0
const SAFE_INSETS := {
	"left": 72.0,
	"top": 72.0,
	"right": 360.0,
	"bottom": 120.0,
}
const EXPECTED_SAFE_RECT := Rect2(72.0, 72.0, 1588.0, 1054.0)
const OUTPUT_DIR := "res://.tmp/plaza_r2_seed5_candidate"
const ENGINE_LOG_PATH := "res://.godot/codex_logs/plaza_r2_seed5_candidate.engine.log"
const PIXEL_DIFF_EPSILON := 0.035
const MIN_CHANGED_PIXELS_PER_ROI := 64
const MIN_PLOT_ANCHOR_Y_SPAN_RATIO := 0.30
const MIN_ANCHOR_BBOX_OCCUPANCY_RATIO := 0.18
const MIN_VISUAL_Y_SPAN_RATIO := 0.42
const BAND_OCCUPANCY_LUMA_THRESHOLD := 0.07
const BAND_OCCUPANCY_SATURATION_THRESHOLD := 0.05
const MIN_OUTER_BAND_OCCUPANCY_RATIO := 0.02
const MIN_OUTER_BAND_DECOR_DELTA_PIXELS := 128

const DECOR_ROLE_BY_CLUSTER_TYPE := {
	"market_stalls": "market",
	"cloth_awning_cluster": "market",
	"small_vendor_court": "market",
	"stone_lantern_gate": "wayfinder",
	"stone_marker_cluster": "wayfinder",
	"guardian_tree_grove": "pine",
	"spirit_tree_cluster": "pine",
	"boundary_pines": "pine",
	"quiet_pond": "pond",
	"jade_rock_garden": "pond",
	"crossroad_lanterns": "supply",
	"seal_stone_court": "supply",
	"bench_and_lanterns": "supply",
}

const COMPATIBLE_CLUSTER_TYPES_BY_ROLE := {
	"wayfinder": ["stone_lantern_gate", "stone_marker_cluster"],
	"market": ["market_stalls", "cloth_awning_cluster", "small_vendor_court"],
	"pond": ["quiet_pond", "jade_rock_garden"],
	"pine": ["guardian_tree_grove", "spirit_tree_cluster", "boundary_pines"],
	"supply": ["crossroad_lanterns", "seal_stone_court", "bench_and_lanterns"],
}

const DECOR_ROLE_SPECS := [
	{
		"role": "wayfinder",
		"relative_path": "tmp/imagegen/plaza_r2_decor/plaza_hwangyeok_decor_wayfinder_lantern_v1_alpha.png",
		"size_axis": "height",
		"target_screen_px": 60.0,
		"approved_screen_range": Vector2(50.0, 65.0),
		"hierarchy": 1,
	},
	{
		"role": "market",
		"relative_path": "tmp/imagegen/plaza_r2_decor/plaza_hwangyeok_decor_market_stall_double_v1_alpha.png",
		"size_axis": "height",
		"target_screen_px": 104.0,
		"approved_screen_range": Vector2(95.0, 110.0),
		"hierarchy": 3,
	},
	{
		"role": "pond",
		"relative_path": "tmp/imagegen/plaza_r2_decor/plaza_hwangyeok_decor_rock_pond_v1_alpha.png",
		"size_axis": "width",
		"target_screen_px": 160.0,
		"approved_screen_range": Vector2(145.0, 170.0),
		"hierarchy": 2,
	},
	{
		"role": "pine",
		"relative_path": "tmp/imagegen/plaza_r2_decor/plaza_hwangyeok_decor_pine_lantern_waymarker_v1_alpha.png",
		"size_axis": "height",
		"target_screen_px": 138.0,
		"approved_screen_range": Vector2(125.0, 145.0),
		"hierarchy": 4,
	},
	{
		"role": "supply",
		"relative_path": "tmp/imagegen/plaza_r2_decor/plaza_hwangyeok_decor_supply_rest_v1_alpha.png",
		"size_axis": "height",
		"target_screen_px": 82.0,
		"approved_screen_range": Vector2(72.0, 90.0),
		"hierarchy": 1,
	},
]


class CandidateStructureCanvas:
	extends Node2D

	var view_size := Vector2.ZERO
	var safe_rect := Rect2()
	var map_content_rect := Rect2()
	var projection := {}
	var layout := {}


	func configure(
		p_view_size: Vector2,
		p_safe_rect: Rect2,
		p_map_content_rect: Rect2,
		p_projection: Dictionary,
		p_layout: Dictionary
	) -> void:
		view_size = p_view_size
		safe_rect = p_safe_rect
		map_content_rect = p_map_content_rect
		projection = p_projection.duplicate(true)
		layout = p_layout.duplicate(true)
		queue_redraw()


	func _draw() -> void:
		# These fields are structural candidate art only. They are intentionally
		# recorded as such in metrics and cannot sign off final ground/road art.
		draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.010, 0.009, 0.008, 1.0))
		draw_rect(safe_rect, Color(0.075, 0.061, 0.043, 1.0))
		draw_rect(safe_rect.grow(-3.0), Color(0.025, 0.023, 0.019, 1.0))
		draw_rect(map_content_rect, Color(0.055, 0.049, 0.038, 1.0))
		_draw_parchment_grain()
		_draw_plots()
		_draw_roads()
		_draw_frame_bands()


	func _draw_parchment_grain() -> void:
		var grain_rect := map_content_rect.grow(-2.0)
		var line_color := Color(0.17, 0.135, 0.085, 0.17)
		for index in range(22):
			var fraction := (float(index) + 0.5) / 22.0
			var y := grain_rect.position.y + grain_rect.size.y * fraction
			var wave := sin(float(index) * 1.73) * 16.0
			draw_line(
				Vector2(grain_rect.position.x + 10.0, y),
				Vector2(grain_rect.end.x - 10.0, y + wave),
				line_color,
				1.0,
				true
			)


	func _draw_plots() -> void:
		var plots_value: Variant = layout.get("plots", [])
		if not (plots_value is Array):
			return
		for plot_value in plots_value as Array:
			if not (plot_value is Dictionary):
				continue
			var plot := plot_value as Dictionary
			var polygon := _project_world_points(plot.get("boundary_polygon_world", []))
			if polygon.size() < 3:
				continue
			var occupied := str(plot.get("occupied_by", "")) != ""
			var fill := Color(0.115, 0.095, 0.062, 0.54) if occupied else Color(0.083, 0.079, 0.066, 0.48)
			var stroke := Color(0.53, 0.38, 0.16, 0.58) if occupied else Color(0.24, 0.43, 0.38, 0.52)
			draw_colored_polygon(polygon, fill)
			var closed := polygon.duplicate()
			closed.append(polygon[0])
			draw_polyline(closed, stroke, 1.5, true)


	func _draw_roads() -> void:
		var road_graph_value: Variant = layout.get("road_graph", {})
		if not (road_graph_value is Dictionary):
			return
		var edges_value: Variant = (road_graph_value as Dictionary).get("edges", [])
		if not (edges_value is Array):
			return
		var projection_scale := float(projection.get("projection_scale", 1.0))
		for edge_value in edges_value as Array:
			if not (edge_value is Dictionary):
				continue
			var edge := edge_value as Dictionary
			var points := _project_world_points(edge.get("polyline_world", []))
			if points.size() < 2:
				continue
			var half_width := maxf(1.0, float(edge.get("half_width_world", 24.0)))
			var road_width := half_width * 2.0 * projection_scale
			var is_main := str(edge.get("kind", "")) == "main"
			var border_color := Color(0.015, 0.014, 0.013, 1.0)
			var road_color := Color(0.105, 0.098, 0.082, 1.0) if is_main else Color(0.083, 0.079, 0.068, 1.0)
			draw_polyline(points, border_color, road_width + 11.0, true)
			draw_polyline(points, road_color, road_width, true)
			draw_polyline(points, Color(0.34, 0.25, 0.12, 0.34), 1.5, true)


	func _draw_frame_bands() -> void:
		var right_x := safe_rect.end.x
		draw_rect(Rect2(Vector2(right_x, 0.0), Vector2(view_size.x - right_x, view_size.y)), Color(0.018, 0.017, 0.016, 1.0))
		draw_rect(Rect2(Vector2.ZERO, Vector2(view_size.x, safe_rect.position.y)), Color(0.016, 0.014, 0.012, 1.0))
		draw_rect(Rect2(Vector2(0.0, safe_rect.end.y), Vector2(view_size.x, view_size.y - safe_rect.end.y)), Color(0.016, 0.014, 0.012, 1.0))
		draw_line(Vector2(right_x, 0.0), Vector2(right_x, view_size.y), Color(0.42, 0.30, 0.12, 0.72), 2.0)
		draw_line(Vector2(0.0, safe_rect.position.y), Vector2(view_size.x, safe_rect.position.y), Color(0.42, 0.30, 0.12, 0.62), 2.0)
		draw_line(Vector2(0.0, safe_rect.end.y), Vector2(view_size.x, safe_rect.end.y), Color(0.42, 0.30, 0.12, 0.62), 2.0)


	func _project_world_points(value: Variant) -> PackedVector2Array:
		var world_points := PackedVector2Array()
		if value is PackedVector2Array:
			world_points = value as PackedVector2Array
		elif value is Array:
			for point_value in value as Array:
				if point_value is Vector2:
					world_points.append(point_value as Vector2)
		return PlazaMapProjection.project_polygon(world_points, projection)


var _failures: Array[String] = []
var _projection := {}
var _layout := {}
var _selected_specs: Array[Dictionary] = []
var _asset_records: Dictionary = {}
var _board_root: Node2D = null
var _structure_canvas: CandidateStructureCanvas = null
var _decor_nodes: Array[Sprite2D] = []
var _decor_draw_records: Array[Dictionary] = []
var _building_layer_records: Array[Dictionary] = []
var _capture_records: Array[Dictionary] = []
var _roi_metrics: Array[Dictionary] = []
var _band_occupancy_metrics: Array[Dictionary] = []
var _spatial_metrics := {}
var _actual_content_metrics := {}
var _decor_compatibility_metrics := {}
var _off_max_landmark_gap_world := INF
var _on_max_landmark_gap_world := INF
var _window_metrics := {}
var _missing_asset_counterproof_pass := false
var _stale_evidence_excluded := false
var _structure_metrics := {
	"dark_parchment": "code_native_structure_candidate_only",
	"road_and_plot_geometry": "code_native_structure_candidate_only",
	"final_ground_art_approved": false,
	"final_road_art_approved": false,
}
var _add_material: CanvasItemMaterial = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("plaza_r2_seed5_candidate_vulkan_qa: WORKSPACE-ONLY; tmp prototype absence is a hard failure; production_connected=false")
	if not _prepare_output_directory():
		_write_report()
		_finish()
		return
	if not await _require_windowed_vulkan_mobile():
		_write_report()
		_finish()
		return
	if not _load_workspace_decor_assets():
		_write_report()
		_finish()
		return
	if not _build_candidate_data():
		_write_report()
		_finish()
		return

	_build_fixture()
	if _board_root == null:
		_write_report()
		_finish()
		return

	_set_decor_visible(false)
	await _settle_frames(3)
	var off_image := await _capture("decor_off")
	_set_decor_visible(true)
	await _settle_frames(3)
	var on_image := await _capture("decor_on")
	if off_image != null and on_image != null:
		_verify_decor_pixel_deltas(off_image, on_image)
	_verify_evidence_contract()
	_verify_engine_log_proves_vulkan()
	_write_report()
	_finish()


func _require_windowed_vulkan_mobile() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	if display_name.contains("headless"):
		_failures.append("R2-A candidate QA requires a windowed display server")
		return false
	var rendering_method := RenderingServer.get_current_rendering_method().to_lower()
	if rendering_method != "mobile":
		_failures.append("R2-A candidate QA requires rendering method mobile, got %s" % rendering_method)
		return false
	var driver_name := _get_user_arg_value("--plaza-r2-rendering-driver=").to_lower()
	if driver_name != "vulkan":
		_failures.append("R2-A candidate QA requires --plaza-r2-rendering-driver=vulkan after `--`, got '%s'" % driver_name)
		return false

	root.content_scale_size = VIEW_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = VIEW_SIZE
	await process_frame
	await process_frame
	var live_size := root.size
	_window_metrics = {
		"display_server": display_name,
		"rendering_method": rendering_method,
		"rendering_driver": driver_name,
		"video_adapter_api_version": RenderingServer.get_video_adapter_api_version(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"requested_size": [VIEW_SIZE.x, VIEW_SIZE.y],
		"live_window_size": [live_size.x, live_size.y],
	}
	_expect(live_size == VIEW_SIZE, "live window content must be exactly 2020 x 1246, got %s" % live_size)
	return _failures.is_empty()


func _prepare_output_directory() -> bool:
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		_failures.append("failed to create R2-A evidence directory %s (error %d)" % [output_dir, mkdir_error])
		return false
	for filename in ["decor_off.png", "decor_on.png", "metrics.json"]:
		var path := output_dir.path_join(filename)
		if FileAccess.file_exists(path):
			var remove_error := DirAccess.remove_absolute(path)
			if remove_error != OK:
				_failures.append("failed to remove stale R2-A evidence %s (error %d)" % [path, remove_error])
				return false
	_stale_evidence_excluded = true
	for stale_name in ["decor_off.png", "decor_on.png", "metrics.json"]:
		if FileAccess.file_exists(output_dir.path_join(stale_name)):
			_stale_evidence_excluded = false
			_failures.append("stale R2-A evidence survived cleanup: %s" % stale_name)
	return _stale_evidence_excluded


func _load_workspace_decor_assets() -> bool:
	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var workspace_root := project_root.get_base_dir()
	var missing_counterproof_path := workspace_root.path_join("tmp/imagegen/plaza_r2_decor/__missing_r2_fail_closed_counterproof__.png")
	_missing_asset_counterproof_pass = _load_workspace_prototype_image(missing_counterproof_path) == null
	_expect(_missing_asset_counterproof_pass, "an absent tmp prototype must return null instead of a fallback texture")
	for spec_value in DECOR_ROLE_SPECS:
		var role_spec := (spec_value as Dictionary).duplicate(true)
		var relative_path := str(role_spec.get("relative_path", ""))
		var absolute_path := workspace_root.path_join(relative_path)
		if not FileAccess.file_exists(absolute_path):
			_failures.append("workspace-only decor prototype missing: %s" % absolute_path)
			continue
		var image := _load_workspace_prototype_image(absolute_path)
		if image == null:
			_failures.append("workspace-only decor prototype failed to decode: %s" % absolute_path)
			continue
		var used_rect := image.get_used_rect()
		if not used_rect.has_area():
			_failures.append("workspace-only decor prototype has an empty alpha bbox: %s" % absolute_path)
			continue
		var corners := [
			image.get_pixel(0, 0).a,
			image.get_pixel(image.get_width() - 1, 0).a,
			image.get_pixel(0, image.get_height() - 1).a,
			image.get_pixel(image.get_width() - 1, image.get_height() - 1).a,
		]
		for alpha_value in corners:
			_expect(float(alpha_value) <= 0.001, "%s prototype corners must remain transparent" % str(role_spec.get("role", "")))
		var texture := ImageTexture.create_from_image(image)
		role_spec["absolute_path"] = absolute_path
		role_spec["image_size"] = Vector2i(image.get_width(), image.get_height())
		role_spec["used_rect"] = used_rect
		role_spec["texture"] = texture
		role_spec["sha256"] = FileAccess.get_sha256(absolute_path)
		_asset_records[str(role_spec.get("role", ""))] = role_spec
	return _failures.is_empty() and _asset_records.size() == DECOR_ROLE_SPECS.size()


func _load_workspace_prototype_image(absolute_path: String) -> Image:
	if not FileAccess.file_exists(absolute_path):
		return null
	var image := Image.new()
	if image.load(absolute_path) != OK or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


func _build_candidate_data() -> bool:
	var safe_rect := PlazaMapProjection.derive_safe_rect(Vector2(VIEW_SIZE), SAFE_INSETS)
	_expect(_rect_equal_approx(safe_rect, EXPECTED_SAFE_RECT), "explicit candidate safe insets must derive Rect2(72,72,1588,1054)")
	_projection = PlazaMapProjection.build_snapshot(WORLD_SIZE, safe_rect)
	_expect(PlazaMapProjection.is_valid_snapshot(_projection), "R2-A full-map projection snapshot must be valid")
	if not PlazaMapProjection.is_valid_snapshot(_projection):
		return false

	_selected_specs = PlazaAssetLoader.build_hwangyeok_building_specs(STAGE_ID, MAP_SEED, false, false)
	var selected_types: Array[String] = []
	for spec in _selected_specs:
		selected_types.append(str(spec.get("type", "")))
	_expect(selected_types == ["bank", "shop"], "stage 1 seed 5 must retain exact bank + shop selection, got %s" % [selected_types])
	_layout = PlazaMapLayoutGenerator.generate(
		STAGE_ID,
		MAP_SEED,
		WORLD_SIZE,
		_selected_specs,
		SPAWN_ANCHOR,
		EXIT_ZONE
	)
	var validation_value: Variant = _layout.get("validation", {})
	var validation: Dictionary = validation_value as Dictionary if validation_value is Dictionary else {}
	var metrics_value: Variant = validation.get("metrics", {})
	var metrics: Dictionary = metrics_value as Dictionary if metrics_value is Dictionary else {}
	_expect(bool(validation.get("valid", false)), "seed 5 layout generator validation must be GREEN: %s" % [validation.get("violations", [])])
	_expect(bool(_layout.get("candidate_only", false)), "R2-A layout must remain candidate_only")
	_expect(not bool(_layout.get("production_connected", true)), "R2-A layout must remain production-disconnected")
	var road_graph_value: Variant = _layout.get("road_graph", {})
	var road_graph: Dictionary = road_graph_value as Dictionary if road_graph_value is Dictionary else {}
	_expect(str(road_graph.get("skeleton_variant", "")) != "", "R2-A layout must publish its deterministic road skeleton variant")
	_expect(str(_layout.get("plot_assignment_signature", "")) != "", "R2-A layout must publish its plot assignment signature")
	_expect(int(metrics.get("building_count", -1)) == 2, "seed 5 layout must contain exactly two buildings")
	_expect(int(metrics.get("unused_plot_count", -1)) == 5, "seed 5 layout must contain exactly five unused plots")
	_expect(int(metrics.get("decor_cluster_count", -1)) == 5, "seed 5 layout must contain exactly five decor clusters")
	_verify_layout_2d_spread()
	_on_max_landmark_gap_world = float(metrics.get("max_landmark_gap_world", INF))
	_expect(_on_max_landmark_gap_world <= MAX_LANDMARK_GAP_WORLD + 0.01, "decor-on max landmark gap must be <= 360 world")
	_off_max_landmark_gap_world = _compute_max_landmark_gap(false)
	_expect(_off_max_landmark_gap_world > MAX_LANDMARK_GAP_WORLD + 0.01, "decor-off must be a real RED counterproof with max gap > 360 world")
	return _failures.is_empty()


func _build_fixture() -> void:
	RenderingServer.set_default_clear_color(Color(0.005, 0.005, 0.005, 1.0))
	_board_root = Node2D.new()
	_board_root.name = "PlazaR2Seed5CandidateBoard"
	root.add_child(_board_root)

	var safe_rect := _projection.get("safe_rect", Rect2()) as Rect2
	var map_content_rect := PlazaMapProjection.get_map_content_screen_rect(_projection)
	_structure_canvas = CandidateStructureCanvas.new()
	_structure_canvas.name = "CodeNativeCandidateStructure"
	_structure_canvas.z_index = 0
	_board_root.add_child(_structure_canvas)
	_structure_canvas.configure(Vector2(VIEW_SIZE), safe_rect, map_content_rect, _projection, _layout)

	_add_material = CanvasItemMaterial.new()
	_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_build_building_visuals()
	_build_decor_visuals()
	_build_board_labels()


func _build_building_visuals() -> void:
	var buildings_value: Variant = _layout.get("building_specs", [])
	if not (buildings_value is Array):
		_failures.append("layout building_specs must be an array")
		return
	for building_value in buildings_value as Array:
		if not (building_value is Dictionary):
			continue
		var building := building_value as Dictionary
		var building_type := str(building.get("type", ""))
		var world_rect_value: Variant = building.get("visual_rect", Rect2())
		var world_rect: Rect2 = world_rect_value as Rect2 if world_rect_value is Rect2 else Rect2()
		var screen_rect := PlazaMapProjection.world_rect_to_screen(world_rect, _projection)
		var sort_anchor_value: Variant = building.get("sort_anchor_world", Vector2.ZERO)
		var sort_anchor: Vector2 = sort_anchor_value as Vector2 if sort_anchor_value is Vector2 else Vector2.ZERO
		var container := Node2D.new()
		container.name = "Building_%s" % building_type
		container.z_index = clampi(200 + int(round(PlazaMapProjection.world_to_screen(sort_anchor, _projection).y)), 200, 2300)
		_board_root.add_child(container)
		var layer_specs := [
			{"name": "base", "key": "base_texture", "color": Color.WHITE, "add": false},
			{"name": "sign_emissive", "key": "sign_texture", "color": building.get("sign_glow_color", Color.WHITE), "strength": float(building.get("sign_glow_strength", 1.0)), "add": true},
			{"name": "window_glow_mask", "key": "window_texture", "color": building.get("window_glow_color", Color.WHITE), "strength": float(building.get("window_glow_strength", 1.0)), "add": true},
		]
		for layer_index in range(layer_specs.size()):
			var layer_spec: Dictionary = layer_specs[layer_index]
			var texture_value: Variant = building.get(str(layer_spec.get("key", "")), null)
			if not (texture_value is Texture2D):
				_failures.append("%s is missing retained %s Texture2D" % [building_type, str(layer_spec.get("name", ""))])
				continue
			var texture := texture_value as Texture2D
			var sprite := Sprite2D.new()
			sprite.name = str(layer_spec.get("name", ""))
			sprite.texture = texture
			sprite.centered = false
			sprite.position = screen_rect.position
			sprite.scale = Vector2(
				screen_rect.size.x / maxf(1.0, texture.get_width()),
				screen_rect.size.y / maxf(1.0, texture.get_height())
			)
			sprite.rotation = 0.0
			sprite.flip_h = false
			sprite.flip_v = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.z_index = layer_index
			if bool(layer_spec.get("add", false)):
				var color_value: Variant = layer_spec.get("color", Color.WHITE)
				var tint: Color = color_value as Color if color_value is Color else Color.WHITE
				tint *= maxf(0.0, float(layer_spec.get("strength", 1.0)))
				sprite.modulate = tint
				sprite.material = _add_material
			container.add_child(sprite)
			_building_layer_records.append({
				"building_type": building_type,
				"layer": str(layer_spec.get("name", "")),
				"screen_rect": screen_rect,
				"additive": bool(layer_spec.get("add", false)),
				"rotation": sprite.rotation,
				"flip_h": sprite.flip_h,
				"flip_v": sprite.flip_v,
			})


func _build_decor_visuals() -> void:
	var clusters_value: Variant = _layout.get("decor_clusters", [])
	if not (clusters_value is Array):
		_failures.append("layout decor_clusters must be an array")
		return
	var clusters: Array[Dictionary] = []
	for cluster_value in clusters_value as Array:
		if cluster_value is Dictionary:
			clusters.append(cluster_value as Dictionary)
	clusters.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return float(left.get("main_route_distance_world", 0.0)) < float(right.get("main_route_distance_world", 0.0))
	)
	_expect(clusters.size() == DECOR_ROLE_SPECS.size(), "candidate board requires exactly five ordered unused-plot clusters")
	var assigned_roles := {}
	for index in range(mini(clusters.size(), DECOR_ROLE_SPECS.size())):
		var cluster := clusters[index]
		var slot := "U%d" % index
		var cluster_type := str(cluster.get("cluster_type", ""))
		var role_spec := _find_compatible_role_spec(cluster_type, assigned_roles)
		if role_spec.is_empty():
			_failures.append("%s cluster type '%s' has no unassigned compatible decor role" % [slot, cluster_type])
			continue
		var role := str(role_spec.get("role", ""))
		var compatible := _is_role_compatible(role, cluster_type)
		_expect(compatible, "%s role %s must be compatible with generator cluster type %s" % [slot, role, cluster_type])
		assigned_roles[role] = true
		var asset_value: Variant = _asset_records.get(role, {})
		if not (asset_value is Dictionary):
			_failures.append("missing loaded asset record for %s" % role)
			continue
		var asset := asset_value as Dictionary
		var texture_value: Variant = asset.get("texture", null)
		var used_rect_value: Variant = asset.get("used_rect", Rect2i())
		if not (texture_value is Texture2D) or not (used_rect_value is Rect2i):
			_failures.append("invalid loaded asset record for %s" % role)
			continue
		var texture := texture_value as Texture2D
		var used_rect_i := used_rect_value as Rect2i
		var used_rect := Rect2(used_rect_i)
		var axis := str(role_spec.get("size_axis", "height"))
		var source_extent := used_rect.size.x if axis == "width" else used_rect.size.y
		var target_screen_px := float(role_spec.get("target_screen_px", 1.0))
		var pixel_scale := target_screen_px / maxf(1.0, source_extent)
		var anchor_value: Variant = cluster.get("anchor_world", Vector2.ZERO)
		var anchor_world: Vector2 = anchor_value as Vector2 if anchor_value is Vector2 else Vector2.ZERO
		var anchor_screen := PlazaMapProjection.world_to_screen(anchor_world, _projection)
		var source_anchor := Vector2(used_rect.get_center().x, used_rect.end.y)
		var sprite := Sprite2D.new()
		sprite.name = "%s_%s" % [slot, role]
		sprite.texture = texture
		sprite.centered = false
		sprite.position = anchor_screen - source_anchor * pixel_scale
		sprite.scale = Vector2.ONE * pixel_scale
		sprite.rotation = 0.0
		sprite.flip_h = false
		sprite.flip_v = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.z_index = clampi(200 + int(round(anchor_screen.y)), 200, 2300)
		sprite.visible = false
		_board_root.add_child(sprite)
		_decor_nodes.append(sprite)
		var alpha_screen_rect := Rect2(
			sprite.position + used_rect.position * pixel_scale,
			used_rect.size * pixel_scale
		)
		var approved_range_value: Variant = role_spec.get("approved_screen_range", Vector2.ZERO)
		var approved_range: Vector2 = approved_range_value as Vector2 if approved_range_value is Vector2 else Vector2.ZERO
		var actual_axis_px := alpha_screen_rect.size.x if axis == "width" else alpha_screen_rect.size.y
		_expect(actual_axis_px >= approved_range.x - 0.01 and actual_axis_px <= approved_range.y + 0.01, "%s must stay inside its approved display-size range" % role)
		_expect(is_zero_approx(sprite.rotation) and not sprite.flip_h and not sprite.flip_v, "%s must not rotate or mirror" % role)
		_decor_draw_records.append({
			"slot": slot,
			"role": role,
			"plot_id": str(cluster.get("plot_id", "")),
			"generator_cluster_id": str(cluster.get("id", "")),
			"generator_cluster_type": cluster_type,
			"compatible": compatible,
			"main_route_distance_world": float(cluster.get("main_route_distance_world", 0.0)),
			"anchor_world": anchor_world,
			"anchor_screen": anchor_screen,
			"alpha_screen_rect": alpha_screen_rect,
			"size_axis": axis,
			"target_screen_px": target_screen_px,
			"actual_axis_px": actual_axis_px,
			"approved_screen_range": approved_range,
			"hierarchy": int(role_spec.get("hierarchy", 0)),
			"rotation": sprite.rotation,
			"flip_h": sprite.flip_h,
			"flip_v": sprite.flip_v,
		})
	_expect(assigned_roles.size() == DECOR_ROLE_SPECS.size(), "cluster compatibility assignment must consume each of the five decor roles exactly once")


func _find_compatible_role_spec(cluster_type: String, assigned_roles: Dictionary) -> Dictionary:
	var required_role := str(DECOR_ROLE_BY_CLUSTER_TYPE.get(cluster_type, ""))
	if required_role == "" or assigned_roles.has(required_role):
		return {}
	for role_spec_value in DECOR_ROLE_SPECS:
		var role_spec := role_spec_value as Dictionary
		var role := str(role_spec.get("role", ""))
		if role == required_role and _is_role_compatible(role, cluster_type):
			return role_spec
	return {}


func _is_role_compatible(role: String, cluster_type: String) -> bool:
	var compatible_types_value: Variant = COMPATIBLE_CLUSTER_TYPES_BY_ROLE.get(role, [])
	return (
		str(DECOR_ROLE_BY_CLUSTER_TYPE.get(cluster_type, "")) == role
		and compatible_types_value is Array
		and (compatible_types_value as Array).has(cluster_type)
	)


func _build_board_labels() -> void:
	_add_label(
		"R2-A  /  STAGE 1  /  SEED 5  /  WORKSPACE CANDIDATE",
		Vector2(92.0, 13.0),
		Vector2(1500.0, 46.0),
		27,
		Color(0.88, 0.76, 0.50, 1.0)
	)
	var validation_value: Variant = _layout.get("validation", {})
	var validation: Dictionary = validation_value as Dictionary if validation_value is Dictionary else {}
	var metrics_value: Variant = validation.get("metrics", {})
	var metrics: Dictionary = metrics_value as Dictionary if metrics_value is Dictionary else {}
	var role_lines: Array[String] = []
	for record in _decor_draw_records:
		role_lines.append("%s  %s" % [str(record.get("slot", "")), str(record.get("role", "")).to_upper()])
	var side_text := "FULL MAP FIT\n\nBUILDINGS      %d\nUNUSED PLOTS   %d\nDECOR ROLES    %d\nMAX GAP        %.1f W\n\n%s\n\nNO ROTATE\nNO MIRROR" % [
		int(metrics.get("building_count", 0)),
		int(metrics.get("unused_plot_count", 0)),
		int(metrics.get("decor_cluster_count", 0)),
		float(metrics.get("max_landmark_gap_world", 0.0)),
		"\n".join(role_lines),
	]
	_add_label(side_text, Vector2(1690.0, 112.0), Vector2(290.0, 620.0), 18, Color(0.79, 0.74, 0.63, 1.0))
	_add_label(
		"STRUCTURE ONLY: dark parchment / road / plot geometry are code-native candidates, not approved final art.   PRODUCTION CONNECTED: NO",
		Vector2(88.0, 1147.0),
		Vector2(1860.0, 48.0),
		16,
		Color(0.66, 0.58, 0.45, 1.0)
	)


func _add_label(text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.z_index = 3000
	_board_root.add_child(label)


func _set_decor_visible(visible: bool) -> void:
	for sprite in _decor_nodes:
		if is_instance_valid(sprite):
			sprite.visible = visible


func _settle_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		if _structure_canvas != null:
			_structure_canvas.queue_redraw()
		await RenderingServer.frame_post_draw


func _capture(slug: String) -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("capture %s returned an empty window image" % slug)
		return null
	_expect(image.get_size() == VIEW_SIZE, "%s capture must be exact 2020 x 1246, got %s" % [slug, image.get_size()])
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(slug + ".png"))
	var save_error := image.save_png(output_path)
	_expect(save_error == OK, "capture %s must save successfully (error %d)" % [slug, save_error])
	if save_error == OK:
		_capture_records.append({
			"slug": slug,
			"path": output_path,
			"size": [image.get_width(), image.get_height()],
			"sha256": FileAccess.get_sha256(output_path),
			"visible_decor_count": _decor_nodes.filter(func(node: Sprite2D) -> bool: return node.visible).size(),
		})
		print("plaza_r2_seed5_candidate_vulkan_qa: evidence %s" % output_path)
	return image


func _verify_decor_pixel_deltas(off_image: Image, on_image: Image) -> void:
	_expect(_decor_draw_records.size() == 5, "pixel QA requires exact five decor draw records")
	for record in _decor_draw_records:
		var rect_value: Variant = record.get("alpha_screen_rect", Rect2())
		var rect: Rect2 = rect_value as Rect2 if rect_value is Rect2 else Rect2()
		var roi := _rect2_to_clamped_rect2i(rect.grow(4.0), off_image.get_size())
		var changed_pixels := 0
		var luma_delta_sum := 0.0
		var rgb_delta_sum := 0.0
		for y in range(roi.position.y, roi.end.y):
			for x in range(roi.position.x, roi.end.x):
				var before := off_image.get_pixel(x, y)
				var after := on_image.get_pixel(x, y)
				var rgb_delta := _rgb_distance(before, after)
				if rgb_delta > PIXEL_DIFF_EPSILON:
					changed_pixels += 1
					rgb_delta_sum += rgb_delta
					luma_delta_sum += _luminance(after) - _luminance(before)
		var required_changed := maxi(MIN_CHANGED_PIXELS_PER_ROI, int(round(float(roi.size.x * roi.size.y) * 0.02)))
		_expect(changed_pixels >= required_changed, "%s ROI must have a non-vacuous decor off/on delta (%d/%d)" % [str(record.get("slot", "")), changed_pixels, required_changed])
		_roi_metrics.append({
			"slot": str(record.get("slot", "")),
			"role": str(record.get("role", "")),
			"roi": [roi.position.x, roi.position.y, roi.size.x, roi.size.y],
			"roi_area": roi.size.x * roi.size.y,
			"required_changed_pixels": required_changed,
			"changed_pixels": changed_pixels,
			"changed_fraction": float(changed_pixels) / maxf(1.0, float(roi.size.x * roi.size.y)),
			"rgb_delta_sum": rgb_delta_sum,
			"luma_delta_sum": luma_delta_sum,
		})
	_verify_map_outer_band_occupancy(off_image, on_image)


func _verify_evidence_contract() -> void:
	_expect(_capture_records.size() == 2, "R2-A evidence must retain exact decor_off/decor_on captures")
	var slugs: Array[String] = []
	for capture in _capture_records:
		slugs.append(str(capture.get("slug", "")))
		_expect(str(capture.get("sha256", "")).length() == 64, "%s capture must retain a SHA-256" % str(capture.get("slug", "")))
	_expect(slugs == ["decor_off", "decor_on"], "R2-A capture order must be exact decor_off then decor_on")
	if _capture_records.size() == 2:
		_expect(int(_capture_records[0].get("visible_decor_count", -1)) == 0, "decor_off must render zero prototype sprites")
		_expect(int(_capture_records[1].get("visible_decor_count", -1)) == 5, "decor_on must render exact five prototype sprites")
	_expect(_roi_metrics.size() == 5, "all five unused-plot ROIs must retain pixel metrics")
	_expect(_band_occupancy_metrics.size() == 2, "decor_on must retain upper/lower map-band occupancy metrics")
	_expect(_building_layer_records.size() == 6, "bank + shop must render exact 2 x 3 retained layers")
	_verify_decor_role_compatibility()
	_verify_actual_content_aabb()
	for layer in _building_layer_records:
		_expect(is_zero_approx(float(layer.get("rotation", INF))), "building layers must not rotate")
		_expect(not bool(layer.get("flip_h", true)) and not bool(layer.get("flip_v", true)), "building layers must not mirror")


func _verify_decor_role_compatibility() -> void:
	var catalog := _evaluate_decor_semantic_catalog()
	_expect(bool(catalog.get("valid", false)), "every generator cluster_type must have one exact compatible prototype role")
	var actual := _evaluate_decor_role_compatibility(_decor_draw_records)
	_expect(bool(actual.get("valid", false)), "all five decor assets must match their generator cluster_type compatibility group")
	_expect(int(actual.get("compatible_count", 0)) == 5, "actual decor compatibility must be exact 5/5")
	for record in _decor_draw_records:
		_expect(bool(record.get("compatible", false)), "%s decor_draw must publish compatible=true" % str(record.get("slot", "")))

	var mismatched_records: Array[Dictionary] = []
	for record in _decor_draw_records:
		mismatched_records.append(record.duplicate(true))
	if mismatched_records.size() >= 2:
		var first_role := str(mismatched_records[0].get("role", ""))
		mismatched_records[0]["role"] = str(mismatched_records[1].get("role", ""))
		mismatched_records[1]["role"] = first_role
	var counterproof := _evaluate_decor_role_compatibility(mismatched_records)
	var counterproof_red_pass := not bool(counterproof.get("valid", true)) and int(counterproof.get("incompatible_count", 0)) >= 2
	_expect(counterproof_red_pass, "swapping the first two assigned roles must produce a non-vacuous compatibility RED counterproof")
	_decor_compatibility_metrics = {
		"assignment_basis": "generator_cluster_type_compatibility_not_route_slot_order",
		"semantic_catalog": catalog,
		"actual": actual,
		"counterproof_expected_verdict": "RED",
		"counterproof_swapped_slots": ["U0", "U1"],
		"counterproof": counterproof,
		"counterproof_red_pass": counterproof_red_pass,
	}


func _evaluate_decor_semantic_catalog() -> Dictionary:
	var generator_types: Array[String] = []
	var kinds_by_plot_class_value: Variant = PlazaMapLayoutGenerator.DECOR_KINDS_BY_PLOT_CLASS
	if kinds_by_plot_class_value is Dictionary:
		var plot_class_keys: Array = (kinds_by_plot_class_value as Dictionary).keys()
		plot_class_keys.sort()
		for plot_class_key_value in plot_class_keys:
			var kinds_value: Variant = (kinds_by_plot_class_value as Dictionary).get(plot_class_key_value, [])
			if not (kinds_value is Array):
				continue
			for cluster_type_value in kinds_value as Array:
				var cluster_type := str(cluster_type_value)
				if not generator_types.has(cluster_type):
					generator_types.append(cluster_type)
	generator_types.sort()
	var unmapped_types: Array[String] = []
	var reverse_catalog_mismatches: Array[String] = []
	var mapped_roles := {}
	for cluster_type in generator_types:
		var role := str(DECOR_ROLE_BY_CLUSTER_TYPE.get(cluster_type, ""))
		if role == "":
			unmapped_types.append(cluster_type)
			continue
		mapped_roles[role] = true
		var reverse_types_value: Variant = COMPATIBLE_CLUSTER_TYPES_BY_ROLE.get(role, [])
		if not (reverse_types_value is Array) or not (reverse_types_value as Array).has(cluster_type):
			reverse_catalog_mismatches.append(cluster_type)
	var extra_mapped_types: Array[String] = []
	for cluster_type_value in DECOR_ROLE_BY_CLUSTER_TYPE.keys():
		var cluster_type := str(cluster_type_value)
		if not generator_types.has(cluster_type):
			extra_mapped_types.append(cluster_type)
	extra_mapped_types.sort()
	var expected_roles: Array[String] = []
	for role_spec_value in DECOR_ROLE_SPECS:
		var role := str((role_spec_value as Dictionary).get("role", ""))
		if role != "" and not expected_roles.has(role):
			expected_roles.append(role)
	expected_roles.sort()
	var actual_roles: Array[String] = []
	for role_value in mapped_roles.keys():
		actual_roles.append(str(role_value))
	actual_roles.sort()
	return {
		"valid": (
			not generator_types.is_empty()
			and unmapped_types.is_empty()
			and reverse_catalog_mismatches.is_empty()
			and extra_mapped_types.is_empty()
			and actual_roles == expected_roles
		),
		"generator_cluster_types": generator_types,
		"direct_mapping_count": DECOR_ROLE_BY_CLUSTER_TYPE.size(),
		"mapped_roles": actual_roles,
		"expected_roles": expected_roles,
		"unmapped_types": unmapped_types,
		"reverse_catalog_mismatches": reverse_catalog_mismatches,
		"extra_mapped_types": extra_mapped_types,
	}


func _evaluate_decor_role_compatibility(records: Array[Dictionary]) -> Dictionary:
	var incompatible: Array[Dictionary] = []
	var compatible_count := 0
	for record in records:
		var slot := str(record.get("slot", ""))
		var role := str(record.get("role", ""))
		var cluster_type := str(record.get("generator_cluster_type", ""))
		if _is_role_compatible(role, cluster_type):
			compatible_count += 1
		else:
			incompatible.append({
				"slot": slot,
				"role": role,
				"generator_cluster_type": cluster_type,
			})
	return {
		"valid": records.size() == DECOR_ROLE_SPECS.size() and incompatible.is_empty(),
		"record_count": records.size(),
		"compatible_count": compatible_count,
		"incompatible_count": incompatible.size(),
		"incompatible": incompatible,
	}


func _verify_actual_content_aabb() -> void:
	var rects: Array[Rect2] = []
	for layer in _building_layer_records:
		if str(layer.get("layer", "")) != "base":
			continue
		var rect_value: Variant = layer.get("screen_rect", Rect2())
		if rect_value is Rect2 and (rect_value as Rect2).has_area():
			rects.append(rect_value as Rect2)
	for decor in _decor_draw_records:
		var rect_value: Variant = decor.get("alpha_screen_rect", Rect2())
		if rect_value is Rect2 and (rect_value as Rect2).has_area():
			rects.append(rect_value as Rect2)
	var content_aabb := _rect_union(rects)
	var map_content_rect := PlazaMapProjection.get_map_content_screen_rect(_projection)
	var y_span_ratio := content_aabb.size.y / maxf(1.0, map_content_rect.size.y) if content_aabb.has_area() else 0.0
	_actual_content_metrics = {
		"content_aabb_screen": _rect_to_array(content_aabb),
		"content_aabb_y_span_px": content_aabb.size.y,
		"map_content_height_px": map_content_rect.size.y,
		"content_aabb_y_span_ratio": y_span_ratio,
		"minimum_y_span_ratio": MIN_VISUAL_Y_SPAN_RATIO,
	}
	_expect(rects.size() == 7, "content AABB requires exact two building bases + five decor visuals")
	_expect(y_span_ratio >= MIN_VISUAL_Y_SPAN_RATIO, "actual rendered content AABB must span the map vertically (%.3f < %.3f)" % [y_span_ratio, MIN_VISUAL_Y_SPAN_RATIO])


func _verify_engine_log_proves_vulkan() -> void:
	var engine_log := FileAccess.get_file_as_string(ENGINE_LOG_PATH)
	var has_vulkan_banner := engine_log.contains("Vulkan ") and engine_log.contains("Forward Mobile")
	var script_error_count := 0
	var serious_error_count := 0
	for line_value in engine_log.split("\n"):
		var line := str(line_value).strip_edges()
		if line.begins_with("SCRIPT ERROR:"):
			script_error_count += 1
		elif line.begins_with("ERROR:") and not line.contains("Failed to read the root certificate store"):
			serious_error_count += 1
	_window_metrics["engine_log_path"] = ProjectSettings.globalize_path(ENGINE_LOG_PATH)
	_window_metrics["engine_log_has_vulkan_mobile_banner"] = has_vulkan_banner
	_window_metrics["engine_log_script_error_count"] = script_error_count
	_window_metrics["engine_log_serious_error_count"] = serious_error_count
	_expect(has_vulkan_banner, "engine log must prove Vulkan Forward Mobile")
	_expect(script_error_count == 0, "engine log must contain zero SCRIPT ERROR lines")
	_expect(serious_error_count == 0, "engine log must contain zero non-certificate ERROR lines")


func _compute_max_landmark_gap(include_decor: bool) -> float:
	var route_length := float(_layout.get("main_route_length_world", 0.0))
	var distances: Array[float] = [0.0, route_length]
	var buildings_value: Variant = _layout.get("building_specs", [])
	if buildings_value is Array:
		for building_value in buildings_value as Array:
			if building_value is Dictionary:
				distances.append(float((building_value as Dictionary).get("main_route_distance_world", 0.0)))
	if include_decor:
		var decor_value: Variant = _layout.get("decor_clusters", [])
		if decor_value is Array:
			for cluster_value in decor_value as Array:
				if cluster_value is Dictionary:
					distances.append(float((cluster_value as Dictionary).get("main_route_distance_world", 0.0)))
	distances.sort()
	var max_gap := 0.0
	for index in range(1, distances.size()):
		max_gap = maxf(max_gap, distances[index] - distances[index - 1])
	return max_gap


func _verify_layout_2d_spread() -> void:
	var plot_anchors: Array[Vector2] = []
	var landmark_anchors: Array[Vector2] = []
	var visual_rects: Array[Rect2] = []
	var plots_value: Variant = _layout.get("plots", [])
	if plots_value is Array:
		for plot_value in plots_value as Array:
			if not (plot_value is Dictionary):
				continue
			var pivot_value: Variant = (plot_value as Dictionary).get("pivot_pos", Vector2.INF)
			if pivot_value is Vector2 and (pivot_value as Vector2).is_finite():
				plot_anchors.append(pivot_value as Vector2)
	var buildings_value: Variant = _layout.get("building_specs", [])
	if buildings_value is Array:
		for building_value in buildings_value as Array:
			if not (building_value is Dictionary):
				continue
			var building := building_value as Dictionary
			var anchor_value: Variant = building.get("sort_anchor_world", Vector2.INF)
			if anchor_value is Vector2 and (anchor_value as Vector2).is_finite():
				landmark_anchors.append(anchor_value as Vector2)
			var rect_value: Variant = building.get("visual_rect", Rect2())
			if rect_value is Rect2 and (rect_value as Rect2).has_area():
				visual_rects.append(rect_value as Rect2)
	var decor_value: Variant = _layout.get("decor_clusters", [])
	if decor_value is Array:
		for cluster_value in decor_value as Array:
			if not (cluster_value is Dictionary):
				continue
			var cluster := cluster_value as Dictionary
			var anchor_value: Variant = cluster.get("anchor_world", Vector2.INF)
			if anchor_value is Vector2 and (anchor_value as Vector2).is_finite():
				landmark_anchors.append(anchor_value as Vector2)
			var rect_value: Variant = cluster.get("visual_bounds_world", Rect2())
			if rect_value is Rect2 and (rect_value as Rect2).has_area():
				visual_rects.append(rect_value as Rect2)
	var plot_bounds := _point_bounds(plot_anchors)
	var landmark_bounds := _point_bounds(landmark_anchors)
	var visual_union := _rect_union(visual_rects)
	var plot_y_span_ratio := plot_bounds.size.y / WORLD_SIZE.y if plot_bounds.has_area() else 0.0
	var plot_bbox_occupancy_ratio := plot_bounds.get_area() / (WORLD_SIZE.x * WORLD_SIZE.y) if plot_bounds.has_area() else 0.0
	var landmark_y_span_ratio := landmark_bounds.size.y / WORLD_SIZE.y if landmark_bounds.has_area() else 0.0
	var landmark_bbox_occupancy_ratio := landmark_bounds.get_area() / (WORLD_SIZE.x * WORLD_SIZE.y) if landmark_bounds.has_area() else 0.0
	var visual_y_span_ratio := visual_union.size.y / WORLD_SIZE.y if visual_union.has_area() else 0.0
	_spatial_metrics = {
		"plot_anchor_bounds_world": _rect_to_array(plot_bounds),
		"plot_anchor_y_span_ratio": plot_y_span_ratio,
		"plot_anchor_bbox_occupancy_ratio": plot_bbox_occupancy_ratio,
		"landmark_anchor_bounds_world": _rect_to_array(landmark_bounds),
		"landmark_anchor_y_span_ratio": landmark_y_span_ratio,
		"landmark_anchor_bbox_occupancy_ratio": landmark_bbox_occupancy_ratio,
		"visual_union_world": _rect_to_array(visual_union),
		"visual_y_span_ratio": visual_y_span_ratio,
		"thresholds": {
			"min_plot_anchor_y_span_ratio": MIN_PLOT_ANCHOR_Y_SPAN_RATIO,
			"min_anchor_bbox_occupancy_ratio": MIN_ANCHOR_BBOX_OCCUPANCY_RATIO,
			"min_visual_y_span_ratio": MIN_VISUAL_Y_SPAN_RATIO,
		},
	}
	_expect(plot_anchors.size() == 7, "2D spread gate requires exact seven plot pivots")
	_expect(landmark_anchors.size() == 7, "2D spread gate requires exact two building + five decor anchors")
	_expect(plot_y_span_ratio >= MIN_PLOT_ANCHOR_Y_SPAN_RATIO, "plot anchors must span upper/middle/lower map bands (%.3f < %.3f)" % [plot_y_span_ratio, MIN_PLOT_ANCHOR_Y_SPAN_RATIO])
	_expect(plot_bbox_occupancy_ratio >= MIN_ANCHOR_BBOX_OCCUPANCY_RATIO, "plot anchor bbox must occupy a non-vacuous 2D map area (%.3f < %.3f)" % [plot_bbox_occupancy_ratio, MIN_ANCHOR_BBOX_OCCUPANCY_RATIO])
	_expect(landmark_y_span_ratio >= MIN_PLOT_ANCHOR_Y_SPAN_RATIO, "building/decor anchors must span upper/middle/lower map bands (%.3f < %.3f)" % [landmark_y_span_ratio, MIN_PLOT_ANCHOR_Y_SPAN_RATIO])
	_expect(landmark_bbox_occupancy_ratio >= MIN_ANCHOR_BBOX_OCCUPANCY_RATIO, "building/decor anchor bbox must occupy a non-vacuous 2D map area (%.3f < %.3f)" % [landmark_bbox_occupancy_ratio, MIN_ANCHOR_BBOX_OCCUPANCY_RATIO])
	_expect(visual_y_span_ratio >= MIN_VISUAL_Y_SPAN_RATIO, "landmark visual union must occupy the map vertically (%.3f < %.3f)" % [visual_y_span_ratio, MIN_VISUAL_Y_SPAN_RATIO])


func _verify_map_outer_band_occupancy(off_image: Image, on_image: Image) -> void:
	var content_rect := PlazaMapProjection.get_map_content_screen_rect(_projection).grow(-4.0)
	var content_roi := _rect2_to_clamped_rect2i(content_rect, on_image.get_size())
	var third_height := content_roi.size.y / 3
	var bands := [
		{
			"band": "upper",
			"rect": Rect2i(content_roi.position, Vector2i(content_roi.size.x, third_height)),
		},
		{
			"band": "lower",
			"rect": Rect2i(
				Vector2i(content_roi.position.x, content_roi.end.y - third_height),
				Vector2i(content_roi.size.x, third_height)
			),
		},
	]
	for band_value in bands:
		var band := band_value as Dictionary
		var rect_value: Variant = band.get("rect", Rect2i())
		var rect: Rect2i = rect_value as Rect2i if rect_value is Rect2i else Rect2i()
		var occupied_pixels := 0
		var decor_delta_pixels := 0
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var color := on_image.get_pixel(x, y)
				var saturation := maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))
				if _luminance(color) > BAND_OCCUPANCY_LUMA_THRESHOLD or saturation > BAND_OCCUPANCY_SATURATION_THRESHOLD:
					occupied_pixels += 1
				if _rgb_distance(off_image.get_pixel(x, y), color) > PIXEL_DIFF_EPSILON:
					decor_delta_pixels += 1
		var area := rect.size.x * rect.size.y
		var occupancy_ratio := float(occupied_pixels) / maxf(1.0, float(area))
		_band_occupancy_metrics.append({
			"band": str(band.get("band", "")),
			"roi": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"area": area,
			"occupied_pixels": occupied_pixels,
			"occupancy_ratio": occupancy_ratio,
			"decor_delta_pixels": decor_delta_pixels,
			"luma_threshold": BAND_OCCUPANCY_LUMA_THRESHOLD,
			"saturation_threshold": BAND_OCCUPANCY_SATURATION_THRESHOLD,
			"minimum_ratio": MIN_OUTER_BAND_OCCUPANCY_RATIO,
			"minimum_decor_delta_pixels": MIN_OUTER_BAND_DECOR_DELTA_PIXELS,
		})
		_expect(occupancy_ratio >= MIN_OUTER_BAND_OCCUPANCY_RATIO, "%s map-content band must have non-background occupancy (%.4f < %.4f)" % [str(band.get("band", "")), occupancy_ratio, MIN_OUTER_BAND_OCCUPANCY_RATIO])
		_expect(decor_delta_pixels >= MIN_OUTER_BAND_DECOR_DELTA_PIXELS, "%s map-content band must contain a rendered decor off/on delta (%d < %d)" % [str(band.get("band", "")), decor_delta_pixels, MIN_OUTER_BAND_DECOR_DELTA_PIXELS])


func _point_bounds(points: Array[Vector2]) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point = Vector2(minf(min_point.x, point.x), minf(min_point.y, point.y))
		max_point = Vector2(maxf(max_point.x, point.x), maxf(max_point.y, point.y))
	return Rect2(min_point, max_point - min_point)


func _rect_union(rects: Array[Rect2]) -> Rect2:
	if rects.is_empty():
		return Rect2()
	var result := rects[0]
	for index in range(1, rects.size()):
		result = result.merge(rects[index])
	return result


func _write_report() -> void:
	var validation_value: Variant = _layout.get("validation", {})
	var validation: Dictionary = validation_value as Dictionary if validation_value is Dictionary else {}
	var metrics_value: Variant = validation.get("metrics", {})
	var generator_metrics: Dictionary = metrics_value as Dictionary if metrics_value is Dictionary else {}
	var safe_rect: Rect2 = _projection.get("safe_rect", Rect2()) if _projection.get("safe_rect", null) is Rect2 else Rect2()
	var map_content_rect := PlazaMapProjection.get_map_content_screen_rect(_projection) if PlazaMapProjection.is_valid_snapshot(_projection) else Rect2()
	var asset_metrics: Array[Dictionary] = []
	for role_spec_value in DECOR_ROLE_SPECS:
		var role_spec := role_spec_value as Dictionary
		var role := str(role_spec.get("role", ""))
		var asset_value: Variant = _asset_records.get(role, {})
		var asset: Dictionary = asset_value as Dictionary if asset_value is Dictionary else {}
		var size_value: Variant = asset.get("image_size", Vector2i.ZERO)
		var image_size: Vector2i = size_value as Vector2i if size_value is Vector2i else Vector2i.ZERO
		var used_value: Variant = asset.get("used_rect", Rect2i())
		var used_rect: Rect2i = used_value as Rect2i if used_value is Rect2i else Rect2i()
		asset_metrics.append({
			"catalog_role": role,
			"compatible_cluster_types": COMPATIBLE_CLUSTER_TYPES_BY_ROLE.get(role, []),
			"workspace_relative_path": str(role_spec.get("relative_path", "")),
			"exists": not asset.is_empty(),
			"size": [image_size.x, image_size.y],
			"alpha_used_rect": [used_rect.position.x, used_rect.position.y, used_rect.size.x, used_rect.size.y],
			"sha256": str(asset.get("sha256", "")),
		})
	var report := {
		"schema": "plaza_r2_seed5_candidate_vulkan_qa_v1",
		"pass": _failures.is_empty(),
		"failure_count": _failures.size(),
		"workspace_only": true,
		"tmp_assets_required_fail_closed": true,
		"missing_tmp_asset_counterproof_pass": _missing_asset_counterproof_pass,
		"stale_evidence_excluded_before_capture": _stale_evidence_excluded,
		"candidate_only": bool(_layout.get("candidate_only", true)),
		"production_connected": bool(_layout.get("production_connected", false)),
		"stage_id": STAGE_ID,
		"map_seed": MAP_SEED,
		"world_size": [WORLD_SIZE.x, WORLD_SIZE.y],
		"safe_insets": SAFE_INSETS,
		"safe_rect": _rect_to_array(safe_rect),
		"map_content_screen_rect": _rect_to_array(map_content_rect),
		"projection_scale": float(_projection.get("projection_scale", 0.0)),
		"window": _window_metrics,
		"structure_art_boundary": _structure_metrics,
		"spatial_distribution": _spatial_metrics,
		"actual_rendered_content": _actual_content_metrics,
		"decor_role_compatibility": _decor_compatibility_metrics,
		"layout": {
			"generator_version": str(_layout.get("generator_version", "")),
			"fingerprint": str(_layout.get("fingerprint", "")),
			"skeleton_variant": str((_layout.get("road_graph", {}) as Dictionary).get("skeleton_variant", "")) if _layout.get("road_graph", null) is Dictionary else "",
			"plot_assignment_signature": str(_layout.get("plot_assignment_signature", "")),
			"selected_building_types": _layout.get("selected_building_types", []),
			"validation_valid": bool(validation.get("valid", false)),
			"validation_violations": validation.get("violations", []),
			"generator_metrics": generator_metrics,
			"decor_off_expected_visual_verdict": "RED",
			"decor_off_max_landmark_gap_world": _off_max_landmark_gap_world,
			"decor_on_max_landmark_gap_world": _on_max_landmark_gap_world,
			"max_gap_threshold_world": MAX_LANDMARK_GAP_WORLD,
		},
		"assets": asset_metrics,
		"decor_draws": _json_safe_decor_draw_records(),
		"building_layers": _json_safe_building_layer_records(),
		"roi_deltas": _roi_metrics,
		"map_outer_band_occupancy": _band_occupancy_metrics,
		"captures": _capture_records,
		"failures": _failures,
	}
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("metrics.json"))
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to open R2-A metrics report: %s" % output_path)
		return
	file.store_string(JSON.stringify(report, "\t", false))
	file.close()
	if not FileAccess.file_exists(output_path):
		_failures.append("R2-A metrics report missing after write: %s" % output_path)
		return
	print("plaza_r2_seed5_candidate_vulkan_qa: metrics %s" % output_path)


func _json_safe_decor_draw_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for source in _decor_draw_records:
		var anchor_world_value: Variant = source.get("anchor_world", Vector2.ZERO)
		var anchor_screen_value: Variant = source.get("anchor_screen", Vector2.ZERO)
		var alpha_rect_value: Variant = source.get("alpha_screen_rect", Rect2())
		var range_value: Variant = source.get("approved_screen_range", Vector2.ZERO)
		var anchor_world: Vector2 = anchor_world_value as Vector2 if anchor_world_value is Vector2 else Vector2.ZERO
		var anchor_screen: Vector2 = anchor_screen_value as Vector2 if anchor_screen_value is Vector2 else Vector2.ZERO
		var alpha_rect: Rect2 = alpha_rect_value as Rect2 if alpha_rect_value is Rect2 else Rect2()
		var approved_range: Vector2 = range_value as Vector2 if range_value is Vector2 else Vector2.ZERO
		records.append({
			"slot": str(source.get("slot", "")),
			"role": str(source.get("role", "")),
			"plot_id": str(source.get("plot_id", "")),
			"generator_cluster_id": str(source.get("generator_cluster_id", "")),
			"generator_cluster_type": str(source.get("generator_cluster_type", "")),
			"compatible": bool(source.get("compatible", false)),
			"main_route_distance_world": float(source.get("main_route_distance_world", 0.0)),
			"anchor_world": [anchor_world.x, anchor_world.y],
			"anchor_screen": [anchor_screen.x, anchor_screen.y],
			"alpha_screen_rect": _rect_to_array(alpha_rect),
			"size_axis": str(source.get("size_axis", "")),
			"target_screen_px": float(source.get("target_screen_px", 0.0)),
			"actual_axis_px": float(source.get("actual_axis_px", 0.0)),
			"approved_screen_range": [approved_range.x, approved_range.y],
			"hierarchy": int(source.get("hierarchy", 0)),
			"rotation": float(source.get("rotation", INF)),
			"flip_h": bool(source.get("flip_h", true)),
			"flip_v": bool(source.get("flip_v", true)),
		})
	return records


func _json_safe_building_layer_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for source in _building_layer_records:
		var rect_value: Variant = source.get("screen_rect", Rect2())
		var rect: Rect2 = rect_value as Rect2 if rect_value is Rect2 else Rect2()
		records.append({
			"building_type": str(source.get("building_type", "")),
			"layer": str(source.get("layer", "")),
			"screen_rect": _rect_to_array(rect),
			"additive": bool(source.get("additive", false)),
			"rotation": float(source.get("rotation", INF)),
			"flip_h": bool(source.get("flip_h", true)),
			"flip_v": bool(source.get("flip_v", true)),
		})
	return records


func _get_user_arg_value(prefix: String) -> String:
	for arg_value in OS.get_cmdline_user_args():
		var arg := str(arg_value)
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""


func _rect2_to_clamped_rect2i(rect: Rect2, image_size: Vector2i) -> Rect2i:
	var x0 := clampi(int(floor(rect.position.x)), 0, image_size.x)
	var y0 := clampi(int(floor(rect.position.y)), 0, image_size.y)
	var x1 := clampi(int(ceil(rect.end.x)), x0, image_size.x)
	var y1 := clampi(int(ceil(rect.end.y)), y0, image_size.y)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


func _rect_to_array(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _rect_equal_approx(left: Rect2, right: Rect2) -> bool:
	return left.position.is_equal_approx(right.position) and left.size.is_equal_approx(right.size)


func _rgb_distance(first: Color, second: Color) -> float:
	return absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)


func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	# Guard against an interrupted async/script path accidentally printing the
	# success marker before the paired captures and five ROI seals exist.
	var added_completion_failure := false
	if _failures.is_empty() and _capture_records.size() != 2:
		_failures.append("R2-A run ended before exact decor_off/decor_on captures completed")
		added_completion_failure = true
	if _failures.is_empty() and _roi_metrics.size() != 5:
		_failures.append("R2-A run ended before all five ROI delta seals completed")
		added_completion_failure = true
	if _failures.is_empty() and _band_occupancy_metrics.size() != 2:
		_failures.append("R2-A run ended before upper/lower map-band pixel occupancy seals completed")
		added_completion_failure = true
	if _failures.is_empty() and _building_layer_records.size() != 6:
		_failures.append("R2-A run ended before bank + shop six-layer draw completed")
		added_completion_failure = true
	if _failures.is_empty() and _decor_compatibility_metrics.is_empty():
		_failures.append("R2-A run ended before decor role compatibility and RED counterproof completed")
		added_completion_failure = true
	if _failures.is_empty():
		var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
		var png_names: Array[String] = []
		for filename in DirAccess.get_files_at(output_dir):
			if str(filename).get_extension().to_lower() == "png":
				png_names.append(str(filename))
		png_names.sort()
		if png_names != ["decor_off.png", "decor_on.png"]:
			_failures.append("R2-A success requires exact decor_off.png + decor_on.png evidence, got %s" % [png_names])
			added_completion_failure = true
		for required_png in ["decor_off.png", "decor_on.png"]:
			var png_path := output_dir.path_join(required_png)
			var png_file := FileAccess.open(png_path, FileAccess.READ)
			if png_file == null or png_file.get_length() <= 0:
				_failures.append("R2-A success requires non-empty evidence file %s" % png_path)
				added_completion_failure = true
			if png_file != null:
				png_file.close()
	if _failures.is_empty():
		var metrics_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("metrics.json"))
		var metrics_text := FileAccess.get_file_as_string(metrics_path)
		var parsed_metrics: Variant = JSON.parse_string(metrics_text)
		if not (parsed_metrics is Dictionary):
			_failures.append("R2-A success requires a readable metrics.json dictionary")
			added_completion_failure = true
		else:
			var metrics_report := parsed_metrics as Dictionary
			var metric_failures_value: Variant = metrics_report.get("failures", [])
			var metric_failures: Array = metric_failures_value as Array if metric_failures_value is Array else ["invalid failures field"]
			if not bool(metrics_report.get("pass", false)) or int(metrics_report.get("failure_count", -1)) != 0 or not metric_failures.is_empty():
				_failures.append("R2-A success requires metrics pass=true, failure_count=0, and failures=[]")
				added_completion_failure = true
	if added_completion_failure:
		_write_report()
	if _board_root != null and is_instance_valid(_board_root):
		_board_root.queue_free()
	if _failures.is_empty():
		print("plaza_r2_seed5_candidate_vulkan_qa: ok")
		print("plaza_r2_seed5_candidate_vulkan_qa: evidence=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
		print("plaza_r2_seed5_candidate_vulkan_qa: workspace-only candidate, production-connected=false")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
