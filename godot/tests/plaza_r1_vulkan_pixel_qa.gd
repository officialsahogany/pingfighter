extends SceneTree

# R1 retained-plaza render seal. This is intentionally windowed-only: the
# acceptance surface is the real Vulkan CanvasItem composition, not a state
# proxy that can stay GREEN while ADD or relative z is visually broken.
#
# Eight fail-closed captures use the production result-screen owner:
#   A. glow strength 0, fixed tick
#   B. glow strength 1 with the production-owned ADD materials, same tick
#   C. the same bound SignEmissive/WindowGlow materials forced to MIX
#   D. an opaque root-plane cover, equivalent to restoring PlazaScene's old
#      root fill above the z=-1 retained host
#   E. a street-visible high-z child that still inherits host visibility
#   F. the real degenerate-size caller path hiding that child
#   G. the real bank-interior caller path hiding that child
#   H. the real plaza-exit caller path keeping that child hidden

const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StageClearResultPlazaSceneHandler := preload("res://scripts/core/stage_clear_result_plaza_scene_handler.gd")
const BattlePsoPrewarmer := preload("res://scripts/core/battle_pso_prewarmer.gd")

const VIEW_SIZE := Vector2i(1280, 720)
const OUTPUT_DIR := "res://.tmp/plaza_r1_vulkan"
const ENGINE_LOG_PATH := "res://.godot/codex_logs/plaza_r1_vulkan_pixel.engine.log"
const FIXED_MAP_SEED := 918273
const FIXED_TICKS_MSEC := 424200
const STEADY_FRAME_COUNT := 8
const EXPECTED_CAPTURE_COUNT := 8
const EXPECTED_CAPTURE_SLUGS := [
	"a_glow_strength_0",
	"b_glow_strength_1_add",
	"c_glow_strength_1_mix_counterproof",
	"d_root_fill_cover_counterproof",
	"e_lifecycle_street_visible",
	"f_lifecycle_degenerate_hidden",
	"g_lifecycle_interior_hidden",
	"h_lifecycle_exit_hidden",
]
const RGB_DIFF_EPSILON := 0.012
const LUMA_POSITIVE_EPSILON := 0.002
const STRONG_MASK_ALPHA := 0.15
const SUPPORT_MASK_ALPHA := 0.005
const SUPPORT_DILATION_PX := 2
const UNDERLAY_COLOR := Color(0.025, 0.035, 0.085, 1.0)
const HOST_FILL_SENTINEL_COLOR := Color(0.075, 0.105, 0.135, 1.0)
const ROOT_COVER_COLOR := Color(0.62, 0.075, 0.11, 1.0)
const LIFECYCLE_SENTINEL_COLOR := Color(0.07, 0.86, 0.33, 1.0)
const LIFECYCLE_SENTINEL_RECT := Rect2(34.0, 36.0, 96.0, 64.0)

var _failures: Array[String] = []
var _capture_paths: Array[String] = []
var _capture_timings: Dictionary = {}
var _timing_metrics: Dictionary = {}
var _pixel_metrics: Dictionary = {}
var _viewport: SubViewport = null
var _owner: Control = null
var _handler: Object = null
var _scene: Control = null
var _host: Control = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _require_windowed_vulkan_mobile():
		_finish()
		return
	if not _prepare_output_directory():
		_finish()
		return

	ProjectResourceLoader.clear_caches()
	PlazaScene.reset_prewarm_assets_for_test()
	BattlePsoPrewarmer.reset_hwangyeok_gpu_prewarm_for_test()
	_build_viewport_fixture()
	_handler = StageClearResultPlazaSceneHandler.new()
	var prewarm_started_usec := Time.get_ticks_usec()
	var cache_only_ready := bool(_handler.ensure_assets_ready(1, _owner))
	_timing_metrics["blocking_resource_cache_prewarm_usec"] = Time.get_ticks_usec() - prewarm_started_usec
	_expect(not cache_only_ready, "Texture2D cache completion alone must not satisfy the Vulkan GPU prewarm seal")
	var gpu_prewarm_started_usec := Time.get_ticks_usec()
	var gpu_prewarm_guard := 0
	var prewarm_nontransparent_pixels := 0
	while not BattlePsoPrewarmer.is_hwangyeok_gpu_prewarm_complete() and gpu_prewarm_guard < 16:
		BattlePsoPrewarmer.run_hwangyeok_gpu_prewarm_step(_owner)
		await RenderingServer.frame_post_draw
		var gpu_prewarmer := _owner.get_node_or_null(BattlePsoPrewarmer.HWANGYEOK_ONLY_NODE_NAME)
		if gpu_prewarmer != null and prewarm_nontransparent_pixels == 0:
			var instance_status: Dictionary = gpu_prewarmer.call("get_hwangyeok_instance_status")
			if bool(instance_status.get("retained_draw_issued", false)):
				_expect(int(instance_status.get("in_bounds_layer_count", 0)) == 21, "Vulkan GPU prewarm must place all 21 retained layers inside its SubViewport")
				var prewarm_image: Image = gpu_prewarmer.call("get_hwangyeok_render_image_for_test")
				prewarm_nontransparent_pixels = _count_nontransparent_pixels(prewarm_image, 0.01)
		gpu_prewarm_guard += 1
	_timing_metrics["gpu_prewarm_to_ready_usec"] = Time.get_ticks_usec() - gpu_prewarm_started_usec
	_timing_metrics["gpu_prewarm_nontransparent_pixels"] = prewarm_nontransparent_pixels
	var gpu_prewarm_status := BattlePsoPrewarmer.get_hwangyeok_gpu_prewarm_status()
	_timing_metrics["gpu_prewarm_post_draw_flush_count"] = int(gpu_prewarm_status.get("post_draw_flush_count", 0))
	_expect(prewarm_nontransparent_pixels > 200, "Hwangyeok GPU prewarm SubViewport readback must contain rendered building pixels")
	var prewarm_ok := bool(_handler.ensure_assets_ready(1, _owner))
	_expect(prewarm_ok, "production plaza owner must complete its composed prewarm before first draw")
	if not prewarm_ok:
		_write_report()
		_finish()
		return

	var spawn_request_usec := Time.get_ticks_usec()
	_timing_metrics["spawn_request_usec"] = spawn_request_usec
	var spawned := bool(_handler.spawn_scene(
		_owner,
		{
			"current_stage": 1,
			"map_seed": FIXED_MAP_SEED,
			"full_layout_for_test": true,
			"play_arrival_transition": false,
		},
		Callable()
	))
	var spawn_return_usec := Time.get_ticks_usec()
	_timing_metrics["spawn_return_usec"] = spawn_return_usec
	_timing_metrics["spawn_call_usec"] = spawn_return_usec - spawn_request_usec
	_expect(spawned, "StageClearResultPlazaSceneHandler.spawn_scene must create the production plaza")
	_scene = _owner.get_node_or_null("PlazaScene") as Control
	_expect(_scene != null, "production spawn must attach PlazaScene to the supplied owner")
	if _scene == null:
		_write_report()
		_finish()
		return

	_scene.call("set_map_world_ticks_msec_for_test", FIXED_TICKS_MSEC)
	_handler.update(0.0)
	await RenderingServer.frame_post_draw
	var first_post_draw_usec := Time.get_ticks_usec()
	_verify_engine_log_proves_vulkan()
	_timing_metrics["first_post_draw_usec"] = first_post_draw_usec
	_timing_metrics["spawn_to_first_post_draw_usec"] = first_post_draw_usec - spawn_request_usec
	_timing_metrics["spawn_return_to_first_post_draw_usec"] = first_post_draw_usec - spawn_return_usec
	await _collect_steady_post_draw_timings(first_post_draw_usec)

	_host = _scene.get_node_or_null("PlazaMapWorldHost") as Control
	_expect(_host != null, "production PlazaScene must own PlazaMapWorldHost")
	if _host == null:
		_write_report()
		_finish()
		return
	_verify_production_z_and_fill_state()

	# Disable only the animated floor painting so A/B/C have a deterministic
	# opaque host-owned backdrop. Building specs, textures, owner sync, z, and
	# bound materials remain the production path.
	_scene.call("set_map_world_fill_fixture_for_test", false, HOST_FILL_SENTINEL_COLOR)
	_scene.call("set_map_world_glow_strength_for_test", 0.0)
	_scene.call("set_map_world_ticks_msec_for_test", FIXED_TICKS_MSEC)
	_handler.update(0.0)

	var mask_started_usec := Time.get_ticks_usec()
	var layer_statuses: Array[Dictionary] = _scene.call("get_map_world_layer_statuses_for_test")
	var strong_mask := _build_projected_glow_mask(layer_statuses, STRONG_MASK_ALPHA)
	var support_mask := _build_projected_glow_mask(layer_statuses, SUPPORT_MASK_ALPHA)
	var dilated_support := _dilate_mask(support_mask, SUPPORT_DILATION_PX)
	var building_pixels := _build_projected_building_pixels(layer_statuses)
	_timing_metrics["mask_authored_png_load_and_projection_usec"] = Time.get_ticks_usec() - mask_started_usec
	_expect(strong_mask.size() > 200, "projected production glow mask must contain strong-alpha pixels")
	_expect(support_mask.size() >= strong_mask.size(), "full glow support must contain the strong mask")
	_expect(building_pixels.size() > strong_mask.size(), "building ROI must extend beyond the emissive mask")

	var image_a: Image = await _capture("a_glow_strength_0")
	var camera_a := _current_camera_x()
	_scene.call("set_map_world_glow_strength_for_test", 1.0)
	_scene.call("set_map_world_ticks_msec_for_test", FIXED_TICKS_MSEC)
	_handler.update(0.0)
	var image_b: Image = await _capture("b_glow_strength_1_add")
	var camera_b := _current_camera_x()
	_expect(is_equal_approx(camera_a, camera_b), "A/B capture must retain the same production camera")
	_expect(_last_host_tick() == FIXED_TICKS_MSEC, "A/B capture must retain the injected fixed map-world tick")
	_expect(_all_actual_glow_materials_use(CanvasItemMaterial.BLEND_MODE_ADD), "B capture must use the actual production-owned ADD materials")
	_pixel_metrics["fixed_fixture"] = {
		"camera_a": camera_a,
		"camera_b": camera_b,
		"ticks_msec": _last_host_tick(),
		"production_add_bound": _all_actual_glow_materials_use(CanvasItemMaterial.BLEND_MODE_ADD),
	}

	var forced_mix_count := _set_actual_glow_blend_mode(CanvasItemMaterial.BLEND_MODE_MIX)
	_expect(forced_mix_count > 0, "counterproof must mutate actual bound emissive CanvasItemMaterials")
	var image_c: Image = await _capture("c_glow_strength_1_mix_counterproof")
	var camera_c := _current_camera_x()
	_expect(is_equal_approx(camera_b, camera_c), "ADD/MIX counterproof must retain the same production camera")
	_expect(_all_actual_glow_materials_use(CanvasItemMaterial.BLEND_MODE_MIX), "C capture must bind MIX to every actual glow sprite material")

	if image_a != null and image_b != null and image_c != null:
		_verify_add_pixel_delta(image_a, image_b, image_c, strong_mask, dilated_support, building_pixels)

	# Restore production ADD, then put an opaque sibling at the PlazaScene root
	# plane. State remains active, but the z=-1 host and its fill sentinel must
	# disappear exactly as they would if the old root opaque fill came back.
	var restored_add_count := _set_actual_glow_blend_mode(CanvasItemMaterial.BLEND_MODE_ADD)
	_expect(restored_add_count == forced_mix_count, "counterproof cleanup must restore every mutated glow material to ADD")
	var cover := _attach_root_fill_counterproof()
	var image_d: Image = await _capture("d_root_fill_cover_counterproof")
	if image_a != null and image_b != null and image_d != null:
		_verify_root_fill_counterproof(image_a, image_b, image_d, strong_mask)
	var covered_host_status: Dictionary = _scene.call("get_map_world_host_status_for_test")
	_expect(bool(covered_host_status.get("active", false)), "root-fill counterproof must leave retained host state active")
	_expect(bool(covered_host_status.get("visible", false)), "root-fill counterproof must hide pixels without falsifying host visibility state")
	if cover != null:
		cover.queue_free()
		await process_frame

	await _verify_production_lifecycle_pixels(image_b)

	_verify_evidence_files()
	_write_report()
	_finish()


func _require_windowed_vulkan_mobile() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	if display_name.contains("headless"):
		_failures.append("plaza_r1_vulkan_pixel_qa requires a windowed display server; headless is a hard failure")
		return false
	var rendering_method := RenderingServer.get_current_rendering_method().to_lower()
	if rendering_method != "mobile":
		_failures.append("plaza_r1_vulkan_pixel_qa requires rendering method mobile, got %s" % rendering_method)
		return false
	var adapter_api_version := RenderingServer.get_video_adapter_api_version()
	# Godot consumes its engine flags before GDScript can inspect them. The
	# windowed runner repeats the selected driver after `--`; the live adapter
	# API/version and rendering method below remain independently recorded.
	var driver_name := _get_user_arg_value("--plaza-rendering-driver=").to_lower()
	if driver_name != "vulkan":
		_failures.append("plaza_r1_vulkan_pixel_qa requires --plaza-rendering-driver=vulkan after `--`, got '%s' (adapter API %s)" % [driver_name, adapter_api_version])
		return false
	_timing_metrics["display_server"] = display_name
	_timing_metrics["rendering_method"] = rendering_method
	_timing_metrics["rendering_driver"] = driver_name
	_timing_metrics["video_adapter_api_version"] = adapter_api_version
	_timing_metrics["video_adapter"] = RenderingServer.get_video_adapter_name()
	return true


func _verify_engine_log_proves_vulkan() -> void:
	var engine_log := FileAccess.get_file_as_string(ENGINE_LOG_PATH)
	var has_vulkan_banner := engine_log.contains("Vulkan ") and engine_log.contains("Forward Mobile")
	_timing_metrics["engine_log_path"] = ProjectSettings.globalize_path(ENGINE_LOG_PATH)
	_timing_metrics["engine_log_has_vulkan_mobile_banner"] = has_vulkan_banner
	_expect(has_vulkan_banner, "engine log must prove the live window actually started Vulkan Forward Mobile")


func _get_user_arg_value(prefix: String) -> String:
	for arg_value in OS.get_cmdline_user_args():
		var arg := str(arg_value)
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""


func _prepare_output_directory() -> bool:
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		_failures.append("failed to create evidence directory %s (error %d)" % [output_dir, mkdir_error])
		return false
	for slug in [
		"a_glow_strength_0.png",
		"b_glow_strength_1_add.png",
		"c_glow_strength_1_mix_counterproof.png",
		"d_root_fill_cover_counterproof.png",
		"e_lifecycle_street_visible.png",
		"f_lifecycle_degenerate_hidden.png",
		"g_lifecycle_interior_hidden.png",
		"h_lifecycle_exit_hidden.png",
		"metrics.json",
	]:
		var path := output_dir.path_join(slug)
		if FileAccess.file_exists(path):
			var remove_error := DirAccess.remove_absolute(path)
			if remove_error != OK:
				_failures.append("failed to remove stale evidence %s (error %d)" % [path, remove_error])
				return false
	return true


func _build_viewport_fixture() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "PlazaR1VulkanViewport"
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	_owner = Control.new()
	_owner.name = "StageClearResultProductionOwner"
	_owner.position = Vector2.ZERO
	_owner.size = Vector2(VIEW_SIZE)
	_viewport.add_child(_owner)
	var underlay := ColorRect.new()
	underlay.name = "UnderlyingResultStackSentinel"
	underlay.position = Vector2.ZERO
	underlay.size = Vector2(VIEW_SIZE)
	underlay.color = UNDERLAY_COLOR
	underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underlay.z_index = 0
	_owner.add_child(underlay)


func _collect_steady_post_draw_timings(first_post_draw_usec: int) -> void:
	var intervals: Array[int] = []
	var request_to_post_draw: Array[int] = []
	var previous_post_draw_usec := first_post_draw_usec
	for _frame_index in range(STEADY_FRAME_COUNT):
		_scene.call("set_map_world_ticks_msec_for_test", FIXED_TICKS_MSEC)
		_handler.update(0.0)
		var request_usec := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		var post_draw_usec := Time.get_ticks_usec()
		intervals.append(post_draw_usec - previous_post_draw_usec)
		request_to_post_draw.append(post_draw_usec - request_usec)
		previous_post_draw_usec = post_draw_usec
	_timing_metrics["steady_post_draw_interval_usec"] = intervals
	_timing_metrics["steady_request_to_post_draw_usec"] = request_to_post_draw
	_timing_metrics["steady_frame_count"] = STEADY_FRAME_COUNT
	_expect(intervals.size() == STEADY_FRAME_COUNT, "timing probe must retain every steady post-draw interval")
	for interval_usec in intervals:
		_expect(interval_usec > 0, "steady post-draw intervals must be positive")


func _verify_production_z_and_fill_state() -> void:
	var host_status: Dictionary = _scene.call("get_map_world_host_status_for_test")
	_expect(_scene.z_index == 1200, "production StageClearResult plaza root must stay at z=1200")
	_expect(_host.get_parent() == _scene, "retained map host must be owned directly by PlazaScene")
	_expect(_host.z_as_relative, "retained map host z=-1 must remain relative to PlazaScene")
	_expect(_host.z_index == -1, "retained map host must stay one plane below PlazaScene")
	_expect(_scene.z_index + _host.z_index == 1199, "relative host effective z must resolve to 1199")
	_expect(bool(host_status.get("active", false)), "first production sync must activate the retained map host")
	_expect(bool(host_status.get("visible", false)), "first production sync must make the retained map host visible")
	_expect(_host.size.is_equal_approx(_scene.size), "host render_size must equal the fitted plaza root size")
	_expect(not _host.size.is_equal_approx(Vector2(VIEW_SIZE)), "wide fixture must distinguish fitted render_size from engine viewport size")


func _capture(slug: String) -> Image:
	if _viewport == null or _scene == null:
		_failures.append("capture %s requested without a live production viewport" % slug)
		return null
	_scene.queue_redraw()
	_host.queue_redraw()
	var request_usec := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	var post_draw_usec := Time.get_ticks_usec()
	var readback_started_usec := Time.get_ticks_usec()
	var image: Image = _viewport.get_texture().get_image()
	var readback_usec := Time.get_ticks_usec() - readback_started_usec
	if image == null or image.is_empty():
		_failures.append("capture %s returned an empty viewport image" % slug)
		return null
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(slug + ".png"))
	var save_started_usec := Time.get_ticks_usec()
	var save_error := image.save_png(output_path)
	var save_usec := Time.get_ticks_usec() - save_started_usec
	if save_error != OK:
		_failures.append("capture %s failed to persist %s (error %d)" % [slug, output_path, save_error])
		return image
	_capture_paths.append(output_path)
	_capture_timings[slug] = {
		"request_to_post_draw_usec": post_draw_usec - request_usec,
		"get_image_readback_usec": readback_usec,
		"png_save_usec": save_usec,
		"size": [image.get_width(), image.get_height()],
		"path": output_path,
	}
	print("plaza_r1_vulkan_pixel_qa: evidence %s" % output_path)
	return image


func _build_projected_glow_mask(layer_statuses: Array[Dictionary], alpha_threshold: float) -> Dictionary:
	var mask := {}
	for visual_index in range(layer_statuses.size()):
		var status := layer_statuses[visual_index]
		if not bool(status.get("active", false)):
			continue
		var visual := _host.get_node_or_null("BuildingVisual%d" % visual_index)
		if visual == null:
			_failures.append("active retained BuildingVisual%d is missing" % visual_index)
			continue
		for binding in [
			["SignEmissive", "sign_render_rect"],
			["WindowGlow", "window_render_rect"],
		]:
			var sprite := visual.get_node_or_null(str(binding[0])) as Sprite2D
			var local_rect: Rect2 = status.get(str(binding[1]), Rect2())
			if sprite == null or not sprite.visible or sprite.texture == null or local_rect.size.x <= 0.0 or local_rect.size.y <= 0.0:
				continue
			# Do not inspect the imported VRAM texture here. Its BPTC/ASTC GPU
			# readback can expose block-decoded alpha as broadly opaque and turn
			# the non-mask control ROI into an empty, vacuous gate. The bound
			# sprite's resource_path is the authored 512px runtime PNG; use that
			# alpha while retaining the actual live sprite projection rect.
			var authored_path := sprite.texture.resource_path
			var texture_image := Image.load_from_file(ProjectSettings.globalize_path(authored_path))
			if texture_image == null or texture_image.is_empty():
				_failures.append("%s authored mask PNG unavailable at %s" % [str(binding[0]), authored_path])
				continue
			if texture_image.get_size() != Vector2i(512, 512):
				_failures.append("%s authored runtime mask must stay 512x512, got %s at %s" % [str(binding[0]), texture_image.get_size(), authored_path])
				continue
			_add_projected_texture_alpha(mask, texture_image, local_rect, alpha_threshold)
	return mask


func _add_projected_texture_alpha(mask: Dictionary, texture_image: Image, local_rect: Rect2, alpha_threshold: float) -> void:
	var capture_rect := Rect2(_scene.position + local_rect.position, local_rect.size)
	var x_min := clampi(int(floor(capture_rect.position.x)), 0, VIEW_SIZE.x - 1)
	var y_min := clampi(int(floor(capture_rect.position.y)), 0, VIEW_SIZE.y - 1)
	var x_max := clampi(int(ceil(capture_rect.end.x)), 0, VIEW_SIZE.x)
	var y_max := clampi(int(ceil(capture_rect.end.y)), 0, VIEW_SIZE.y)
	for y in range(y_min, y_max):
		var local_v := (float(y) + 0.5 - capture_rect.position.y) / capture_rect.size.y
		var source_y := clampi(int(floor(local_v * float(texture_image.get_height()))), 0, texture_image.get_height() - 1)
		for x in range(x_min, x_max):
			var local_u := (float(x) + 0.5 - capture_rect.position.x) / capture_rect.size.x
			var source_x := clampi(int(floor(local_u * float(texture_image.get_width()))), 0, texture_image.get_width() - 1)
			if texture_image.get_pixel(source_x, source_y).a >= alpha_threshold:
				mask[_pixel_key(x, y)] = true


func _build_projected_building_pixels(layer_statuses: Array[Dictionary]) -> Dictionary:
	var pixels := {}
	for status in layer_statuses:
		if not bool(status.get("active", false)):
			continue
		var local_rect: Rect2 = status.get("base_render_rect", Rect2())
		var capture_rect := Rect2(_scene.position + local_rect.position, local_rect.size)
		_add_rect_pixels(pixels, capture_rect)
	return pixels


func _add_rect_pixels(pixels: Dictionary, rect: Rect2) -> void:
	var x_min := clampi(int(floor(rect.position.x)), 0, VIEW_SIZE.x - 1)
	var y_min := clampi(int(floor(rect.position.y)), 0, VIEW_SIZE.y - 1)
	var x_max := clampi(int(ceil(rect.end.x)), 0, VIEW_SIZE.x)
	var y_max := clampi(int(ceil(rect.end.y)), 0, VIEW_SIZE.y)
	for y in range(y_min, y_max):
		for x in range(x_min, x_max):
			pixels[_pixel_key(x, y)] = true


func _dilate_mask(source: Dictionary, radius: int) -> Dictionary:
	var dilated := source.duplicate()
	for key_value in source.keys():
		var key := int(key_value)
		var x := key % VIEW_SIZE.x
		var y := floori(float(key) / float(VIEW_SIZE.x))
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				var sample_x := x + offset_x
				var sample_y := y + offset_y
				if sample_x >= 0 and sample_x < VIEW_SIZE.x and sample_y >= 0 and sample_y < VIEW_SIZE.y:
					dilated[_pixel_key(sample_x, sample_y)] = true
	return dilated


func _verify_add_pixel_delta(
	image_a: Image,
	image_b: Image,
	image_c: Image,
	strong_mask: Dictionary,
	dilated_support: Dictionary,
	building_pixels: Dictionary
) -> void:
	var ab_mask := _compare_on_keys(image_a, image_b, strong_mask)
	var bc_mask := _compare_on_keys(image_b, image_c, strong_mask)
	var ab_building_outside := _compare_outside_support(image_a, image_b, building_pixels, dilated_support)
	var bc_building_outside := _compare_outside_support(image_b, image_c, building_pixels, dilated_support)
	var scene_rect := Rect2i(Vector2i(_scene.position), Vector2i(_scene.size))
	var ab_scene_outside := _compare_rect_outside_support(image_a, image_b, scene_rect, dilated_support)
	var bc_scene_outside := _compare_rect_outside_support(image_b, image_c, scene_rect, dilated_support)
	_pixel_metrics["a_vs_b_glow_mask"] = ab_mask
	_pixel_metrics["b_add_vs_c_mix_glow_mask"] = bc_mask
	_pixel_metrics["a_vs_b_building_nonmask"] = ab_building_outside
	_pixel_metrics["b_vs_c_building_nonmask"] = bc_building_outside
	_pixel_metrics["a_vs_b_scene_outside_mask"] = ab_scene_outside
	_pixel_metrics["b_vs_c_scene_outside_mask"] = bc_scene_outside
	_pixel_metrics["strong_mask_pixel_count"] = strong_mask.size()
	_pixel_metrics["support_mask_pixel_count"] = dilated_support.size()
	_expect(int(ab_building_outside.get("sample_pixels", 0)) > 0, "A/B building non-mask control ROI must contain real sample pixels")
	_expect(int(bc_building_outside.get("sample_pixels", 0)) > 0, "B/C building non-mask control ROI must contain real sample pixels")

	var ab_changed := int(ab_mask.get("changed_pixels", 0))
	var ab_positive := int(ab_mask.get("positive_luma_pixels", 0))
	var minimum_ab_changed := maxi(64, int(ceil(float(strong_mask.size()) * 0.02)))
	_expect(ab_changed >= minimum_ab_changed, "production strength 1 ADD must change projected glow-mask pixels versus strength 0 (%d < %d)" % [ab_changed, minimum_ab_changed])
	_expect(ab_positive > int(float(ab_changed) * 0.55), "ADD must brighten a majority of its changed mask pixels (%d/%d)" % [ab_positive, ab_changed])
	_expect(float(ab_mask.get("signed_luma_delta", 0.0)) > 1.0, "strength 1 ADD must have positive aggregate luminance over strength 0")

	var bc_changed := int(bc_mask.get("changed_pixels", 0))
	var minimum_bc_changed := maxi(32, int(ceil(float(strong_mask.size()) * 0.01)))
	_expect(bc_changed >= minimum_bc_changed, "production ADD must be visibly different from forced MIX on the same bound masks (%d < %d)" % [bc_changed, minimum_bc_changed])
	_expect(float(bc_mask.get("absolute_rgb_delta", 0.0)) > 1.0, "ADD/MIX mask delta must carry non-trivial RGB energy")

	_expect(float(ab_building_outside.get("changed_ratio", 1.0)) < 0.01, "A/B building pixels outside emissive support must remain stable")
	_expect(float(bc_building_outside.get("changed_ratio", 1.0)) < 0.01, "B/C building pixels outside emissive support must remain stable")
	# Root actor/UI art can advance independently from the fixed map tick. It is
	# still bounded: a material test that repaints the whole plaza cannot hide
	# behind that small legitimate surface.
	_expect(float(ab_scene_outside.get("changed_ratio", 1.0)) < 0.03, "A/B pixels outside glow support must stay globally stable")
	_expect(float(bc_scene_outside.get("changed_ratio", 1.0)) < 0.03, "B/C pixels outside glow support must stay globally stable")


func _compare_on_keys(first: Image, second: Image, keys: Dictionary) -> Dictionary:
	var changed_pixels := 0
	var positive_luma_pixels := 0
	var signed_luma_delta := 0.0
	var absolute_rgb_delta := 0.0
	for key_value in keys.keys():
		var key := int(key_value)
		var x := key % VIEW_SIZE.x
		var y := floori(float(key) / float(VIEW_SIZE.x))
		var first_pixel := first.get_pixel(x, y)
		var second_pixel := second.get_pixel(x, y)
		var rgb_delta := _rgb_distance(first_pixel, second_pixel)
		var luma_delta := _luminance(second_pixel) - _luminance(first_pixel)
		absolute_rgb_delta += rgb_delta
		signed_luma_delta += luma_delta
		if rgb_delta > RGB_DIFF_EPSILON:
			changed_pixels += 1
		if luma_delta > LUMA_POSITIVE_EPSILON:
			positive_luma_pixels += 1
	return {
		"sample_pixels": keys.size(),
		"changed_pixels": changed_pixels,
		"changed_ratio": float(changed_pixels) / maxf(1.0, float(keys.size())),
		"positive_luma_pixels": positive_luma_pixels,
		"signed_luma_delta": signed_luma_delta,
		"absolute_rgb_delta": absolute_rgb_delta,
	}


func _compare_outside_support(first: Image, second: Image, candidates: Dictionary, support: Dictionary) -> Dictionary:
	var sample_count := 0
	var changed_count := 0
	for key_value in candidates.keys():
		var key := int(key_value)
		if support.has(key):
			continue
		var x := key % VIEW_SIZE.x
		var y := floori(float(key) / float(VIEW_SIZE.x))
		sample_count += 1
		if _rgb_distance(first.get_pixel(x, y), second.get_pixel(x, y)) > RGB_DIFF_EPSILON:
			changed_count += 1
	return {
		"sample_pixels": sample_count,
		"changed_pixels": changed_count,
		"changed_ratio": float(changed_count) / maxf(1.0, float(sample_count)),
	}


func _compare_rect_outside_support(first: Image, second: Image, rect: Rect2i, support: Dictionary) -> Dictionary:
	var sample_count := 0
	var changed_count := 0
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO, VIEW_SIZE))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			var key := _pixel_key(x, y)
			if support.has(key):
				continue
			sample_count += 1
			if _rgb_distance(first.get_pixel(x, y), second.get_pixel(x, y)) > RGB_DIFF_EPSILON:
				changed_count += 1
	return {
		"sample_pixels": sample_count,
		"changed_pixels": changed_count,
		"changed_ratio": float(changed_count) / maxf(1.0, float(sample_count)),
	}


func _set_actual_glow_blend_mode(blend_mode: int) -> int:
	var changed_count := 0
	for visual in _host.get_children():
		if not str(visual.name).begins_with("BuildingVisual"):
			continue
		for child_name in ["SignEmissive", "WindowGlow"]:
			var sprite := visual.get_node_or_null(child_name) as Sprite2D
			if sprite == null or not (sprite.material is CanvasItemMaterial):
				continue
			var material := sprite.material as CanvasItemMaterial
			material.blend_mode = blend_mode
			changed_count += 1
	_host.queue_redraw()
	_scene.queue_redraw()
	return changed_count


func _all_actual_glow_materials_use(blend_mode: int) -> bool:
	var inspected_count := 0
	for visual in _host.get_children():
		if not str(visual.name).begins_with("BuildingVisual"):
			continue
		for child_name in ["SignEmissive", "WindowGlow"]:
			var sprite := visual.get_node_or_null(child_name) as Sprite2D
			if sprite == null or not (sprite.material is CanvasItemMaterial):
				continue
			inspected_count += 1
			if (sprite.material as CanvasItemMaterial).blend_mode != blend_mode:
				return false
	return inspected_count > 0


func _attach_root_fill_counterproof() -> ColorRect:
	var cover := ColorRect.new()
	cover.name = "R1RootOpaqueFillCounterproof"
	cover.position = Vector2.ZERO
	cover.size = _scene.size
	cover.color = ROOT_COVER_COLOR
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.z_as_relative = true
	cover.z_index = 0
	_scene.add_child(cover)
	_expect(_scene.z_index + cover.z_index == 1200, "counterproof cover must occupy the former root-fill plane above effective host z=1199")
	return cover


func _verify_root_fill_counterproof(
	glow_off_image: Image,
	production_image: Image,
	covered_image: Image,
	strong_mask: Dictionary
) -> void:
	var scene_rect := Rect2i(Vector2i(_scene.position), Vector2i(_scene.size)).intersection(Rect2i(Vector2i.ZERO, VIEW_SIZE))
	# Vulkan's sRGB framebuffer may not round-trip a draw Color to the same
	# numeric RGB triplet. Derive the flat sentinel/cover colors from each
	# capture's modal in-scene pixel instead of comparing to linear literals.
	var production_modal := _find_modal_color(production_image, scene_rect)
	var covered_modal := _find_modal_color(covered_image, scene_rect)
	var production_fill_color: Color = production_modal.get("color", Color.TRANSPARENT)
	var covered_fill_color: Color = covered_modal.get("color", Color.TRANSPARENT)
	var fill_sentinel_keys := {}
	for y in range(scene_rect.position.y, scene_rect.end.y):
		for x in range(scene_rect.position.x, scene_rect.end.x):
			if _rgb_distance(production_image.get_pixel(x, y), production_fill_color) <= 3.1 / 255.0:
				fill_sentinel_keys[_pixel_key(x, y)] = true
	var visible_glow_keys := _build_positive_changed_keys(glow_off_image, production_image, strong_mask)
	var sentinel_covered_matches := _count_color_matches(covered_image, fill_sentinel_keys, covered_fill_color, 3.1 / 255.0)
	var raw_mask_covered_matches := _count_color_matches(covered_image, strong_mask, covered_fill_color, 3.1 / 255.0)
	var raw_mask_cover_delta := _compare_on_keys(production_image, covered_image, strong_mask)
	var visible_mask_covered_matches := _count_color_matches(covered_image, visible_glow_keys, covered_fill_color, 3.1 / 255.0)
	var visible_mask_cover_delta := _compare_on_keys(production_image, covered_image, visible_glow_keys)
	_pixel_metrics["root_cover_counterproof"] = {
		"production_modal_color_rgb8": _color_to_rgb8_array(production_fill_color),
		"production_modal_pixel_count": int(production_modal.get("count", 0)),
		"covered_modal_color_rgb8": _color_to_rgb8_array(covered_fill_color),
		"covered_modal_pixel_count": int(covered_modal.get("count", 0)),
		"fill_sentinel_pixels_before_cover": fill_sentinel_keys.size(),
		"fill_sentinel_pixels_matching_cover_after": sentinel_covered_matches,
		"fill_sentinel_cover_ratio": float(sentinel_covered_matches) / maxf(1.0, float(fill_sentinel_keys.size())),
		"raw_strong_mask_pixels": strong_mask.size(),
		"raw_strong_mask_pixels_matching_cover_after": raw_mask_covered_matches,
		"raw_strong_mask_cover_ratio": float(raw_mask_covered_matches) / maxf(1.0, float(strong_mask.size())),
		"raw_strong_mask_delta": raw_mask_cover_delta,
		"visible_glow_pixels": visible_glow_keys.size(),
		"visible_glow_pixels_matching_cover_after": visible_mask_covered_matches,
		"visible_glow_cover_ratio": float(visible_mask_covered_matches) / maxf(1.0, float(visible_glow_keys.size())),
		"visible_glow_delta": visible_mask_cover_delta,
	}
	_expect(fill_sentinel_keys.size() > 10000, "production capture must expose a large opaque host-fill sentinel surface")
	_expect(strong_mask.size() > 200, "root-cover leg must retain the non-vacuous raw authored strong mask")
	_expect(visible_glow_keys.size() > 0, "root-cover leg must expose positive A-to-B glow pixels inside the raw strong mask")
	_expect(int(covered_modal.get("count", 0)) > int(float(scene_rect.get_area()) * 0.5), "root-plane counterproof must produce an opaque flat cover over most of the plaza")
	_expect(_rgb_distance(production_fill_color, covered_fill_color) > 0.1, "root cover modal color must differ from the production host-fill sentinel")
	_expect(sentinel_covered_matches > int(float(fill_sentinel_keys.size()) * 0.95), "root-plane cover must hide at least 95% of the host fill sentinel")
	_expect(visible_mask_covered_matches >= int(ceil(float(visible_glow_keys.size()) * 0.95)), "root-plane cover must hide at least 95% of production-visible glow pixels")
	_expect(int(visible_mask_cover_delta.get("changed_pixels", 0)) >= int(ceil(float(visible_glow_keys.size()) * 0.95)), "root-plane cover must visibly replace at least 95% of production-visible glow pixels")


func _verify_production_lifecycle_pixels(production_image: Image) -> void:
	var sentinel := ColorRect.new()
	sentinel.name = "R1LifecycleVisibilitySentinel"
	sentinel.position = LIFECYCLE_SENTINEL_RECT.position
	sentinel.size = LIFECYCLE_SENTINEL_RECT.size
	sentinel.color = LIFECYCLE_SENTINEL_COLOR
	sentinel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Absolute high z prevents the interior/result chrome from concealing a
	# missing host cleanup. Visibility still inherits PlazaMapWorldHost.
	sentinel.z_as_relative = false
	sentinel.z_index = 4095
	_host.add_child(sentinel)
	_scene.call("set_map_world_ticks_msec_for_test", FIXED_TICKS_MSEC)
	_handler.update(0.0)
	var street_status: Dictionary = _scene.call("get_map_world_host_status_for_test")
	_expect(bool(street_status.get("active", false)), "lifecycle street control must start with the production host active")
	_expect(bool(street_status.get("visible", false)), "lifecycle street control must start with the production host visible")
	var street_image: Image = await _capture("e_lifecycle_street_visible")
	if street_image == null:
		return
	var sentinel_rect := Rect2i(
		Vector2i(_scene.position + _host.position + sentinel.position),
		Vector2i(sentinel.size)
	).intersection(Rect2i(Vector2i.ZERO, VIEW_SIZE))
	var street_modal := _find_modal_color(street_image, sentinel_rect)
	var street_color: Color = street_modal.get("color", Color.TRANSPARENT)
	var street_keys := _build_color_match_keys(street_image, sentinel_rect, street_color, 3.1 / 255.0)
	_expect(street_keys.size() > 5000, "street lifecycle sentinel must expose a non-vacuous solid surface")
	_expect(_rgb_distance(street_color, LIFECYCLE_SENTINEL_COLOR) <= 3.1 / 255.0, "street lifecycle modal color must be the authored sentinel color")
	var sentinel_appearance_delta := _compare_on_keys(production_image, street_image, street_keys) if production_image != null else {}
	_expect(
		int(sentinel_appearance_delta.get("changed_pixels", 0)) >= int(ceil(float(street_keys.size()) * 0.95)),
		"attaching the lifecycle sentinel must visibly replace at least 95% of its control ROI"
	)

	# Prefer the real production geometry input at 1x1. Godot 4.6 currently
	# clamps SubViewport to 2x2, so keep the documented fallback: set the live
	# PlazaScene local rect to 1x1 and cross its real _draw() frame. Neither path
	# invokes the host API directly. Restore only the observation surface before
	# readback so a ghost remains visible at the same full-size sentinel keys.
	var original_size := _scene.size
	var original_position := _scene.position
	var original_clip_contents := _scene.clip_contents
	_scene.clip_contents = false
	_viewport.size = Vector2i.ONE
	# SubViewport visible_rect updates at the frame boundary on the live Vulkan
	# backend. Cross that boundary before the production owner samples it.
	await process_frame
	var minimum_viewport_size := _viewport.get_visible_rect().size
	var degenerate_route := "production_viewport_owner_update"
	var degenerate_route_scene_size := Vector2.ZERO
	if minimum_viewport_size.x <= 1.0 or minimum_viewport_size.y <= 1.0:
		_handler.update(0.0)
		degenerate_route_scene_size = _scene.size
	else:
		degenerate_route = "engine_clamped_root_draw_fallback"
	_viewport.size = VIEW_SIZE
	await process_frame
	_scene.position = original_position
	if degenerate_route == "production_viewport_owner_update":
		# Keep the fail-closed state, but restore the full observation rect without
		# resyncing the owner.
		_scene.size = original_size
	else:
		_scene.size = Vector2.ONE
		degenerate_route_scene_size = _scene.size
	_pixel_metrics["lifecycle_degenerate_input"] = {
		"minimum_viewport_visible_size": [minimum_viewport_size.x, minimum_viewport_size.y],
		"route": degenerate_route,
		"scene_size_at_route": [degenerate_route_scene_size.x, degenerate_route_scene_size.y],
	}
	var degenerate_image: Image = await _capture("f_lifecycle_degenerate_hidden")
	var degenerate_status: Dictionary = _scene.call("get_map_world_host_status_for_test")
	_expect(not bool(degenerate_status.get("active", true)), "degenerate production draw route must fail-close the retained host")
	_expect(not bool(degenerate_status.get("visible", true)), "degenerate production draw route must hide retained children")
	_verify_lifecycle_hidden("degenerate", street_image, degenerate_image, street_keys, street_color)

	_scene.size = original_size
	_scene.position = original_position
	_scene.clip_contents = original_clip_contents
	_scene.call("set_map_world_ticks_msec_for_test", FIXED_TICKS_MSEC)
	_handler.update(0.0)
	var restored_status: Dictionary = _scene.call("get_map_world_host_status_for_test")
	_expect(bool(restored_status.get("active", false)), "restoring the fitted scene size must reactivate the street through the owner")
	_expect(bool(restored_status.get("visible", false)), "restoring the fitted scene size must show retained children again")

	var building_specs: Array[Dictionary] = _scene.call("get_building_specs_for_test")
	var bank := _find_building_spec(building_specs, "bank")
	_expect(not bank.is_empty(), "lifecycle pixel seal requires the always-present bank")
	if not bank.is_empty():
		var interaction_rect: Rect2 = bank.get("interaction_rect", Rect2())
		_scene.call("set_player_pos_for_test", interaction_rect.get_center())
		_handler.update(1.0 / 60.0)
		var enter := InputEventKey.new()
		enter.pressed = true
		enter.keycode = KEY_ENTER
		_handler.handle_input(enter)
		_handler.update(10.0)
		var interior_scene_status: Dictionary = _scene.call("get_status")
		var interior_host_status: Dictionary = _scene.call("get_map_world_host_status_for_test")
		_expect(bool(interior_scene_status.get("interior_view_active", false)), "lifecycle pixel seal must enter the bank through handler KEY_ENTER")
		_expect(not bool(interior_host_status.get("active", true)), "bank interior must synchronously fail-close the host")
		_expect(not bool(interior_host_status.get("visible", true)), "bank interior must hide every retained child")
		var interior_image: Image = await _capture("g_lifecycle_interior_hidden")
		_verify_lifecycle_hidden("interior", street_image, interior_image, street_keys, street_color)

		_scene.call("close_menu_for_test", true)
		_scene.call("set_map_world_ticks_msec_for_test", FIXED_TICKS_MSEC)
		_handler.update(0.0)
		var returned_status: Dictionary = _scene.call("get_map_world_host_status_for_test")
		_expect(bool(returned_status.get("active", false)), "closing the interior must reactivate the street before exit")

	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	_handler.handle_input(escape)
	_handler.update(10.0)
	var exited_status: Dictionary = _scene.call("get_map_world_host_status_for_test")
	_expect(not bool(exited_status.get("active", true)), "completed plaza exit must keep the host inactive after update returns")
	_expect(not bool(exited_status.get("visible", true)), "completed plaza exit must keep every retained child hidden")
	var exit_image: Image = await _capture("h_lifecycle_exit_hidden")
	_verify_lifecycle_hidden("exit", street_image, exit_image, street_keys, street_color)

	if is_instance_valid(sentinel):
		sentinel.queue_free()
	_pixel_metrics["lifecycle_sentinel"] = {
		"street_modal_color_rgb8": _color_to_rgb8_array(street_color),
		"street_modal_pixel_count": int(street_modal.get("count", 0)),
		"street_sample_pixels": street_keys.size(),
		"appearance_delta": sentinel_appearance_delta,
	}


func _verify_lifecycle_hidden(
	leg: String,
	street_image: Image,
	hidden_image: Image,
	street_keys: Dictionary,
	street_color: Color
) -> void:
	if hidden_image == null:
		_failures.append("%s lifecycle capture is missing" % leg)
		return
	var remaining_matches := _count_color_matches(hidden_image, street_keys, street_color, 3.1 / 255.0)
	var delta := _compare_on_keys(street_image, hidden_image, street_keys)
	var sample_count := maxi(1, street_keys.size())
	_pixel_metrics["lifecycle_%s" % leg] = {
		"sample_pixels": street_keys.size(),
		"remaining_sentinel_pixels": remaining_matches,
		"remaining_ratio": float(remaining_matches) / float(sample_count),
		"street_to_hidden_delta": delta,
	}
	_expect(remaining_matches <= int(floor(float(street_keys.size()) * 0.01)), "%s lifecycle route must remove at least 99%% of the street sentinel" % leg)
	_expect(int(delta.get("changed_pixels", 0)) >= int(ceil(float(street_keys.size()) * 0.95)), "%s lifecycle route must visibly replace at least 95%% of street sentinel pixels" % leg)


func _build_color_match_keys(image: Image, rect: Rect2i, expected: Color, tolerance: float) -> Dictionary:
	var keys := {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if _rgb_distance(image.get_pixel(x, y), expected) <= tolerance:
				keys[_pixel_key(x, y)] = true
	return keys


func _find_building_spec(specs: Array[Dictionary], building_type: String) -> Dictionary:
	for spec in specs:
		if str(spec.get("type", "")) == building_type:
			return spec
	return {}


func _build_positive_changed_keys(first: Image, second: Image, candidates: Dictionary) -> Dictionary:
	var visible := {}
	for key_value in candidates.keys():
		var key := int(key_value)
		var x := key % VIEW_SIZE.x
		var y := floori(float(key) / float(VIEW_SIZE.x))
		var first_pixel := first.get_pixel(x, y)
		var second_pixel := second.get_pixel(x, y)
		if (
			_rgb_distance(first_pixel, second_pixel) > RGB_DIFF_EPSILON
			and _luminance(second_pixel) - _luminance(first_pixel) > LUMA_POSITIVE_EPSILON
		):
			visible[key] = true
	return visible


func _find_modal_color(image: Image, rect: Rect2i) -> Dictionary:
	var counts := {}
	var best_key := 0
	var best_count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var pixel := image.get_pixel(x, y)
			var red := clampi(roundi(pixel.r * 255.0), 0, 255)
			var green := clampi(roundi(pixel.g * 255.0), 0, 255)
			var blue := clampi(roundi(pixel.b * 255.0), 0, 255)
			var key := (red << 16) | (green << 8) | blue
			var count := int(counts.get(key, 0)) + 1
			counts[key] = count
			if count > best_count:
				best_key = key
				best_count = count
	return {
		"color": Color(
			float((best_key >> 16) & 0xff) / 255.0,
			float((best_key >> 8) & 0xff) / 255.0,
			float(best_key & 0xff) / 255.0,
			1.0
		),
		"count": best_count,
	}


func _color_to_rgb8_array(color: Color) -> Array[int]:
	return [
		clampi(roundi(color.r * 255.0), 0, 255),
		clampi(roundi(color.g * 255.0), 0, 255),
		clampi(roundi(color.b * 255.0), 0, 255),
	]


func _count_color_matches(image: Image, keys: Dictionary, expected: Color, tolerance: float) -> int:
	var matches := 0
	for key_value in keys.keys():
		var key := int(key_value)
		var x := key % VIEW_SIZE.x
		var y := floori(float(key) / float(VIEW_SIZE.x))
		if _rgb_distance(image.get_pixel(x, y), expected) <= tolerance:
			matches += 1
	return matches


func _count_nontransparent_pixels(image: Image, alpha_threshold: float) -> int:
	if image == null or image.is_empty():
		return 0
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > alpha_threshold:
				count += 1
	return count


func _verify_evidence_files() -> void:
	_expect(_capture_paths.size() == EXPECTED_CAPTURE_COUNT, "all eight R1 pixel captures must persist (%d/%d)" % [_capture_paths.size(), EXPECTED_CAPTURE_COUNT])
	var seen_slugs := {}
	for path in _capture_paths:
		seen_slugs[path.get_file().get_basename()] = true
		if not FileAccess.file_exists(path):
			_failures.append("evidence PNG missing: %s" % path)
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() <= 0:
			_failures.append("evidence PNG unreadable or empty: %s" % path)
		if file != null:
			file.close()
	_expect(seen_slugs.size() == EXPECTED_CAPTURE_COUNT, "R1 evidence must contain eight unique capture slugs")
	for expected_slug in EXPECTED_CAPTURE_SLUGS:
		_expect(seen_slugs.has(expected_slug), "R1 evidence is missing exact capture slug %s" % expected_slug)


func _write_report() -> void:
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("metrics.json"))
	var report := {
		"schema": "plaza_r1_vulkan_pixel_seal_v1",
		"pass": _failures.is_empty(),
		"view_size": [VIEW_SIZE.x, VIEW_SIZE.y],
		"map_seed": FIXED_MAP_SEED,
		"full_layout": true,
		"fixed_ticks_msec": FIXED_TICKS_MSEC,
		"scene_z_index": _scene.z_index if _scene != null else null,
		"host_z_index": _host.z_index if _host != null else null,
		"host_z_as_relative": _host.z_as_relative if _host != null else null,
		"host_effective_z": (_scene.z_index + _host.z_index) if _scene != null and _host != null else null,
		"timing": _timing_metrics,
		"capture_timing": _capture_timings,
		"pixels": _pixel_metrics,
		"captures": _capture_paths,
		"failures": _failures,
	}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to open R1 metrics report: %s" % output_path)
		return
	file.store_string(JSON.stringify(report, "\t", false))
	file.close()
	if not FileAccess.file_exists(output_path):
		_failures.append("R1 metrics report missing after write: %s" % output_path)
		return
	var verify_file := FileAccess.open(output_path, FileAccess.READ)
	if verify_file == null or verify_file.get_length() <= 0:
		_failures.append("R1 metrics report is empty: %s" % output_path)
	if verify_file != null:
		verify_file.close()
	print("plaza_r1_vulkan_pixel_qa: metrics %s" % output_path)


func _current_camera_x() -> float:
	if _scene == null:
		return -1.0
	var status_value: Variant = _scene.call("get_status")
	return float((status_value as Dictionary).get("camera_x", -1.0)) if status_value is Dictionary else -1.0


func _last_host_tick() -> int:
	if _scene == null:
		return -1
	var status_value: Variant = _scene.call("get_map_world_host_status_for_test")
	return int((status_value as Dictionary).get("last_synced_ticks_msec", -1)) if status_value is Dictionary else -1


func _pixel_key(x: int, y: int) -> int:
	return y * VIEW_SIZE.x + x


func _rgb_distance(first: Color, second: Color) -> float:
	return absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)


func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _handler != null:
		_handler.free_scene()
	if _viewport != null and is_instance_valid(_viewport):
		_viewport.queue_free()
	ProjectResourceLoader.clear_caches()
	if _failures.is_empty():
		print("plaza_r1_vulkan_pixel_qa: ok")
		print("plaza_r1_vulkan_pixel_qa: evidence=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
