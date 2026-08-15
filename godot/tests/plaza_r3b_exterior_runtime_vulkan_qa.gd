extends SceneTree

# Windowed-only R3-B actual-art seal. A/B/C use the real Smasher sprite around
# the real bank sort anchor; D/E/F repeat it with the real Onimaru companion.
# C/F restore the behind position and mutate only the actual direct sibling to
# z=1, so A->C and D->F pixel deltas are non-proxy Y-sort counterproofs. G/H
# move the full 2D camera on both axes and seal the minimap camera/player delta.

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaMapProjection := preload("res://scripts/plaza/plaza_map_projection.gd")
const PlazaMapRoadSkeletonR3 := preload("res://scripts/plaza/plaza_map_road_skeleton_r3.gd")
const PlazaR3EnvironmentLayoutCompiler := preload("res://scripts/plaza/plaza_r3_environment_layout_compiler.gd")
const PlazaR3ExteriorRetainedHost := preload("res://scripts/plaza/plaza_r3_exterior_retained_host.gd")
const PlazaR3MinimapCanvas := preload("res://scripts/plaza/plaza_r3_minimap_canvas.gd")
const PlazaR3MinimapProjection := preload("res://scripts/plaza/plaza_r3_minimap_projection.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const WORLD_SIZE := Vector2(2400.0, 1500.0)
const SPAWN_ANCHOR := Vector2(120.0, 666.0)
const EXIT_ZONE := Rect2(2250.0, 596.0, 120.0, 92.0)
const SAFE_INSETS := {"left": 72.0, "top": 72.0, "right": 360.0, "bottom": 120.0}
const MINIMAP_RECT := Rect2(1690.0, 80.0, 250.0, 174.0)
const MAP_SEED := 4
const OUTPUT_DIR := "res://.tmp/plaza_r3b_exterior_runtime_vulkan"
const ENGINE_LOG_PATH := "res://.godot/codex_logs/plaza_r3b_exterior_runtime_vulkan.engine.log"
const MIN_OCCLUSION_CHANGED_PIXELS := 48
const MIN_MOTION_CHANGED_PIXELS := 80
const MIN_MINIMAP_CHANGED_PIXELS := 16
const PIXEL_EPSILON := 0.025

var _failures: Array[String] = []
var _layout: Dictionary = {}
var _plan: Dictionary = {}
var _compiled_minimap: Dictionary = {}
var _projection: Dictionary = {}
var _host: Control = null
var _minimap: Control = null
var _bank: Dictionary = {}
var _bank_anchor := Vector2.ZERO
var _captures: Array[Dictionary] = []
var _images: Dictionary = {}
var _pixel_metrics: Dictionary = {}
var _window_metrics: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("plaza_r3b_exterior_runtime_vulkan_qa: CANDIDATE-ONLY; production_connected=false")
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
	await _capture_actor_sequence()
	await _capture_camera_sequence()
	_verify_pixels()
	_verify_evidence_files()
	_verify_engine_log_proves_vulkan()
	_write_report()
	_finish()


func _require_windowed_vulkan() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	var rendering_method := RenderingServer.get_current_rendering_method().to_lower()
	var driver_name := _get_user_arg_value("--plaza-r3b-rendering-driver=").to_lower()
	if display_name.contains("headless"):
		_failures.append("R3-B exterior QA requires a windowed display server")
	if rendering_method != "mobile":
		_failures.append("R3-B exterior QA requires rendering method mobile, got %s" % rendering_method)
	if driver_name != "vulkan":
		_failures.append("R3-B exterior QA requires --plaza-r3b-rendering-driver=vulkan")
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
	_expect(bool((_layout.get("validation", {}) as Dictionary).get("valid", false)), "seed 4 R3 layout must validate")
	_plan = PlazaR3EnvironmentLayoutCompiler.compile_layout(_layout)
	var approved := PlazaR3EnvironmentLayoutCompiler.validate_plan(_plan, _layout, true)
	_expect(bool(approved.get("valid", false)), "user-approved R3 environment plan must validate for rendering")
	_bank = _find_building("bank")
	_expect(not _bank.is_empty(), "seed 4 must contain the bank")
	if _bank.is_empty():
		return false
	_bank_anchor = _bank.get("sort_anchor_world", Vector2.ZERO) as Vector2
	var safe_rect := PlazaMapProjection.derive_safe_rect(Vector2(VIEW_SIZE), SAFE_INSETS)
	_projection = PlazaMapProjection.build_snapshot(WORLD_SIZE, safe_rect, _bank_anchor, 1.65)
	_expect(PlazaMapProjection.is_valid_snapshot(_projection), "bank-centered zoomed projection must validate")
	_compiled_minimap = PlazaR3MinimapProjection.compile_layout(_layout, str(_layout.get("fingerprint", "")))
	_expect(bool(_compiled_minimap.get("valid", false)), "R3 minimap static records must compile once")
	var visual_config := _build_visual_config()
	_expect(bool(visual_config.get("valid", false)), "real player and guardian textures must load")
	if not _failures.is_empty():
		return false
	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(VIEW_SIZE)
	background.color = Color(0.01, 0.01, 0.014, 1.0)
	background.z_index = -2000
	root.add_child(background)
	_host = PlazaR3ExteriorRetainedHost.new()
	_host.name = "R3BExteriorActualArtHost"
	root.add_child(_host)
	_expect(bool(_host.call("bind_scene", _layout, _plan, visual_config, _projection)), "actual retained host must bind")
	_minimap = PlazaR3MinimapCanvas.new()
	_minimap.name = "R3BMinimap"
	root.add_child(_minimap)
	return _failures.is_empty()


func _capture_actor_sequence() -> void:
	var guardian_far := _bank_anchor + Vector2(430.0, 260.0)
	var player_far := _bank_anchor + Vector2(-430.0, 260.0)
	var player_behind := _bank_anchor + Vector2(0.0, -14.0)
	var player_front := _bank_anchor + Vector2(0.0, 14.0)
	_expect(_sync(player_behind, guardian_far, _projection, 1000), "A player-behind state must sync")
	_expect(bool((_host.call("get_sort_contract_status") as Dictionary).get("valid", false)), "A must use the GREEN actual tree")
	await _capture("a_player_behind")
	_expect(_sync(player_front, guardian_far, _projection, 1000), "B player-front state must sync")
	await _capture("b_player_front")
	_expect(_sync(player_behind, guardian_far, _projection, 1000), "C must reset the exact A state")
	var player_item := _host.call("get_player_item_for_test") as Node2D
	_expect(player_item != null, "C must mutate the actual player direct sibling")
	if player_item != null:
		player_item.z_index = 1
	var player_red := _host.call("get_sort_contract_status") as Dictionary
	_expect(not bool(player_red.get("valid", true)), "C player z=1 must turn the actual-tree contract RED")
	await _capture("c_player_z1_counterproof")
	_expect(_sync(player_behind, guardian_far, _projection, 1000), "valid sync must restore player mutation left in place")
	_expect(bool((_host.call("get_sort_contract_status") as Dictionary).get("valid", false)), "player actual tree must restore GREEN")

	var guardian_behind := _bank_anchor + Vector2(0.0, -14.0)
	var guardian_front := _bank_anchor + Vector2(0.0, 14.0)
	_expect(_sync(player_far, guardian_behind, _projection, 1000), "D guardian-behind state must sync")
	await _capture("d_guardian_behind")
	_expect(_sync(player_far, guardian_front, _projection, 1000), "E guardian-front state must sync")
	await _capture("e_guardian_front")
	_expect(_sync(player_far, guardian_behind, _projection, 1000), "F must reset the exact D state")
	var guardian_item := _host.call("get_guardian_item_for_test") as Node2D
	_expect(guardian_item != null, "F must mutate the actual guardian direct sibling")
	if guardian_item != null:
		guardian_item.z_index = 1
	var guardian_red := _host.call("get_sort_contract_status") as Dictionary
	_expect(not bool(guardian_red.get("valid", true)), "F guardian z=1 must turn the actual-tree contract RED")
	await _capture("f_guardian_z1_counterproof")
	_expect(_sync(player_far, guardian_behind, _projection, 1000), "valid sync must restore guardian mutation left in place")
	_expect(bool((_host.call("get_sort_contract_status") as Dictionary).get("valid", false)), "guardian actual tree must restore GREEN")


func _capture_camera_sequence() -> void:
	var hub_center := _hub_center()
	var safe_rect := PlazaMapProjection.derive_safe_rect(Vector2(VIEW_SIZE), SAFE_INSETS)
	var projection_g := PlazaMapProjection.build_snapshot(WORLD_SIZE, safe_rect, hub_center, 1.35)
	var projection_h := PlazaMapProjection.build_snapshot(WORLD_SIZE, safe_rect, hub_center + Vector2(120.0, 80.0), 1.35)
	_expect(_sync(hub_center, hub_center + Vector2(-80.0, 0.0), projection_g, 1200), "G two-axis camera baseline must sync")
	await _capture("g_camera_xy_before")
	_expect(_sync(hub_center + Vector2(120.0, 80.0), hub_center + Vector2(40.0, 80.0), projection_h, 1200), "H two-axis camera movement must sync")
	await _capture("h_camera_xy_after")
	var snapshot_g := PlazaR3MinimapProjection.project_compiled(_compiled_minimap, MINIMAP_RECT, hub_center, hub_center + Vector2(-80.0, 0.0), projection_g.get("visible_world_rect", Rect2()) as Rect2)
	var snapshot_h := PlazaR3MinimapProjection.project_compiled(_compiled_minimap, MINIMAP_RECT, hub_center + Vector2(120.0, 80.0), hub_center + Vector2(40.0, 80.0), projection_h.get("visible_world_rect", Rect2()) as Rect2)
	var rect_g := snapshot_g.get("camera_screen_rect", Rect2()) as Rect2
	var rect_h := snapshot_h.get("camera_screen_rect", Rect2()) as Rect2
	_expect(rect_h.position.x > rect_g.position.x and rect_h.position.y > rect_g.position.y, "minimap camera rectangle must visibly move on both axes")


func _sync(player_world: Vector2, guardian_world: Vector2, projection: Dictionary, ticks_msec: int) -> bool:
	if not bool(_host.call("sync_dynamic", {
		"player_world_position": player_world,
		"guardian_world_position": guardian_world,
		"ticks_msec": ticks_msec,
		"player_moving": false,
		"player_facing": 1,
	}, projection)):
		return false
	var snapshot := PlazaR3MinimapProjection.project_compiled(
		_compiled_minimap,
		MINIMAP_RECT,
		player_world,
		guardian_world,
		projection.get("visible_world_rect", Rect2()) as Rect2
	)
	return bool(_minimap.call("sync_snapshot", snapshot, true))


func _verify_pixels() -> void:
	for slug in ["a_player_behind", "b_player_front", "c_player_z1_counterproof", "d_guardian_behind", "e_guardian_front", "f_guardian_z1_counterproof", "g_camera_xy_before", "h_camera_xy_after"]:
		_expect(_images.has(slug), "capture %s must exist before pixel verification" % slug)
	if _images.size() != 8:
		return
	var bank_screen := PlazaMapProjection.world_rect_to_screen(_bank.get("visual_rect", Rect2()) as Rect2, _projection)
	var bank_roi := _clip_rect_to_image(Rect2i(bank_screen.grow(8.0)), _images.get("a_player_behind") as Image)
	var player_motion := _count_changed_pixels(_images.get("a_player_behind") as Image, _images.get("b_player_front") as Image, bank_roi)
	var player_order := _count_changed_pixels(_images.get("a_player_behind") as Image, _images.get("c_player_z1_counterproof") as Image, bank_roi)
	var guardian_motion := _count_changed_pixels(_images.get("d_guardian_behind") as Image, _images.get("e_guardian_front") as Image, bank_roi)
	var guardian_order := _count_changed_pixels(_images.get("d_guardian_behind") as Image, _images.get("f_guardian_z1_counterproof") as Image, bank_roi)
	var minimap_roi := _clip_rect_to_image(Rect2i(MINIMAP_RECT.grow(3.0)), _images.get("g_camera_xy_before") as Image)
	var minimap_changed := _count_changed_pixels(_images.get("g_camera_xy_before") as Image, _images.get("h_camera_xy_after") as Image, minimap_roi)
	_pixel_metrics = {
		"bank_roi": [bank_roi.position.x, bank_roi.position.y, bank_roi.size.x, bank_roi.size.y],
		"player_motion_changed_pixels": player_motion,
		"player_z_order_changed_pixels": player_order,
		"guardian_motion_changed_pixels": guardian_motion,
		"guardian_z_order_changed_pixels": guardian_order,
		"minimap_xy_changed_pixels": minimap_changed,
	}
	_expect(player_motion >= MIN_MOTION_CHANGED_PIXELS, "real player behind/front capture must be non-vacuous, got %d" % player_motion)
	_expect(player_order >= MIN_OCCLUSION_CHANGED_PIXELS, "same-position player z counterproof must change bank overlap pixels, got %d" % player_order)
	_expect(guardian_motion >= MIN_MOTION_CHANGED_PIXELS, "real guardian behind/front capture must be non-vacuous, got %d" % guardian_motion)
	_expect(guardian_order >= MIN_OCCLUSION_CHANGED_PIXELS, "same-position guardian z counterproof must change bank overlap pixels, got %d" % guardian_order)
	_expect(minimap_changed >= MIN_MINIMAP_CHANGED_PIXELS, "two-axis camera/player movement must change minimap pixels, got %d" % minimap_changed)


func _build_visual_config() -> Dictionary:
	var player := PlazaAssetLoader.load_player_textures("smasher")
	var path := LingpetCatalog.get_visual_path("onimaru", "companion_walk")
	var guardian_value: Variant = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if not bool(player.get("has_sprite", false)) or not (guardian_value is Texture2D):
		return {"valid": false}
	return {
		"valid": true,
		"player_textures": player,
		"guardian_enabled": true,
		"guardian_texture": guardian_value as Texture2D,
		"guardian_grid_cols": roundi(LingpetCatalog.get_visual_layout_value("onimaru", "companion_walk_cols", 5.0)),
		"guardian_grid_rows": roundi(LingpetCatalog.get_visual_layout_value("onimaru", "companion_walk_rows", 5.0)),
		"guardian_frame_count": roundi(LingpetCatalog.get_visual_layout_value("onimaru", "companion_walk_frame_count", 25.0)),
		"guardian_draw_size_world": LingpetCatalog.get_visual_layout_value("onimaru", "companion_walk_draw_size", 92.0),
	}


func _find_building(building_type: String) -> Dictionary:
	for building in _dictionary_array(_layout.get("building_specs", [])):
		if str(building.get("type", "")) == building_type:
			return building
	return {}


func _hub_center() -> Vector2:
	var hubs := _dictionary_array(_layout.get("walkable_hub_polygons", []))
	if hubs.is_empty():
		return Vector2.INF
	var polygon := hubs[0].get("polygon_world", PackedVector2Array()) as PackedVector2Array
	var total := Vector2.ZERO
	for point in polygon:
		total += point
	return total / float(maxi(1, polygon.size()))


func _capture(slug: String) -> Image:
	await RenderingServer.frame_post_draw
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
	_images[slug] = image
	return image


func _prepare_output_directory() -> bool:
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_failures.append("failed to create output directory")
		return false
	for filename in DirAccess.get_files_at(output_dir):
		if DirAccess.remove_absolute(output_dir.path_join(str(filename))) != OK:
			_failures.append("failed to remove stale evidence: %s" % filename)
	return _failures.is_empty()


func _verify_evidence_files() -> void:
	_expect(_captures.size() == 8, "R3-B Vulkan seal requires exact eight captures")
	var actual: Array[String] = []
	for filename in DirAccess.get_files_at(ProjectSettings.globalize_path(OUTPUT_DIR)):
		if str(filename).get_extension().to_lower() == "png":
			actual.append(str(filename))
	actual.sort()
	_expect(actual == ["a_player_behind.png", "b_player_front.png", "c_player_z1_counterproof.png", "d_guardian_behind.png", "e_guardian_front.png", "f_guardian_z1_counterproof.png", "g_camera_xy_before.png", "h_camera_xy_after.png"], "evidence directory must contain exact A-H PNGs")


func _verify_engine_log_proves_vulkan() -> void:
	var engine_log := FileAccess.get_file_as_string(ENGINE_LOG_PATH)
	var has_banner := engine_log.contains("Vulkan ") and engine_log.contains("Forward Mobile")
	_window_metrics["engine_log_has_vulkan_mobile_banner"] = has_banner
	_expect(has_banner, "engine log must contain the real Vulkan Forward Mobile banner")


func _write_report() -> void:
	var report := {
		"schema": "plaza_r3b_exterior_runtime_vulkan_qa_v1",
		"pass": _failures.is_empty(),
		"failure_count": _failures.size(),
		"failures": _failures,
		"candidate_only": true,
		"production_connected": false,
		"map_seed": MAP_SEED,
		"layout_fingerprint": str(_layout.get("fingerprint", "")),
		"environment_plan_fingerprint": str(_plan.get("fingerprint", "")),
		"building_shadow_decision": "none; approved plot pads plus actor-only contact shadows",
		"window": _window_metrics,
		"captures": _captures,
		"pixel_metrics": _pixel_metrics,
	}
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("metrics.json"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to write metrics")
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()


func _count_changed_pixels(first: Image, second: Image, roi: Rect2i) -> int:
	var changed := 0
	for y in range(roi.position.y, roi.end.y):
		for x in range(roi.position.x, roi.end.x):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if absf(a.r - b.r) > PIXEL_EPSILON or absf(a.g - b.g) > PIXEL_EPSILON or absf(a.b - b.b) > PIXEL_EPSILON:
				changed += 1
	return changed


func _clip_rect_to_image(rect: Rect2i, image: Image) -> Rect2i:
	return rect.intersection(Rect2i(0, 0, image.get_width(), image.get_height()))


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item in value as Array:
		if item is Dictionary:
			result.append(item as Dictionary)
	return result


func _get_user_arg_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty() and (_captures.size() != 8 or _pixel_metrics.is_empty()):
		_failures.append("run ended before durable R3-B pixel evidence completed")
		_write_report()
	if _failures.is_empty():
		print("plaza_r3b_exterior_runtime_vulkan_qa: ok")
		print("plaza_r3b_exterior_runtime_vulkan_qa: evidence=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
